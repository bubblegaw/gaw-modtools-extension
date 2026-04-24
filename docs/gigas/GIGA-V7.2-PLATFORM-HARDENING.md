# GIGA-V7.2-PLATFORM-HARDENING

**Audience:** Claude Code session with blanket approval from Commander Cats.
**Target:** GAW ModTools v7.1.x -> v7.2.0.
**Why this ships in the v7.2 slot:** Security + performance foundations must precede Team Productivity (v8.0). The previous v7.2 Anticipator draft has been moved to the v8.5 slot. v7.2 is now an infrastructure release: no new user-facing feature, but every subsequent feature GIGA depends on the primitives landed here.

---

## MISSION

Pay down the three root causes called out by the v7.1.2 master reports: **privilege concentration**, **runtime fragmentation**, and **state-truth duplication**. Land the performance foundation defined in `PERFORMANCE_STANDARDS.md` (CachedStore, DerivedIndexes, DomScheduler, MasterHeartbeat, regexCache, memoized trySelect) as the substrate. Then execute Voss's P0 security hardening list on top of that substrate: kill page-localStorage mirroring of sensitive state, route all worker auth through the background service worker, strip DOM-derived actor identity from every privileged write, add Death Row execution idempotency at client and DB level, replace every privileged `prompt()` with an extension-owned modal, stage-only invite claim with a popup claim button, fix the fragment leak in URL scrubbing, normalize worker error surfaces, make the SuperMod poller visibility-aware with exponential backoff, tighten the manifest CSP, remove the background storage-inventory log, and allowlist every URL the extension opens or copies. One D1 migration (`012_mod_tokens_and_dr_idempotency.sql`), one new admin endpoint (`/admin/import-tokens-from-kv`), and a `setup-mod-tokens.ps1` with the mandatory four-step ending. **Every behavior change gates behind `features.platformHardening` (default OFF).** Full modularization is explicitly deferred to v7.4.

---

## DELIVERABLES

| Path | Purpose |
|---|---|
| `D:\AI\_PROJECTS\modtools-ext\modtools.js` | v7.2 region containing CachedStore / DerivedIndexes / DomScheduler / MasterHeartbeat / regexCache / memoized trySelect; storage adapter with PAGE_SAFE_KEYS allowlist; background-relay-based workerCall; askTextModal and confirmModal helpers; `executing` Set on Death Row; scrubUrlForTelemetry; normalizeWorkerError; visibility+backoff-aware SuperMod poller; allowlistedUrl helper |
| `D:\AI\_PROJECTS\modtools-ext\background.js` | Secret vault in service-worker RAM + `chrome.storage.session`; `workerFetch` relay with endpoint allowlist; `setTokens` message handler; removal of the install-time storage-inventory console.log |
| `D:\AI\_PROJECTS\modtools-ext\popup.js` | `{type:'setTokens'}` message save; dedicated "Claim invite" button that reads `gam_pending_invite` from `chrome.storage.session`; no token repopulation into input values on load |
| `D:\AI\_PROJECTS\modtools-ext\manifest.json` | `content_security_policy.extension_pages` = `script-src 'self'; object-src 'self'; base-uri 'self';`; version bumped to 7.2.0 |
| `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js` | `lookupModFromToken(token)` via new `mod_tokens` D1 table; `requireMod(request)` helper; every privileged write ignores client-supplied `mod`, `gaw_user`, `last_editor`, `gawUsername`; `/admin/import-tokens-from-kv` one-shot admin endpoint (lead-gated); DR ban writes rely on DB unique-index guard for idempotency |
| `D:\AI\_PROJECTS\cloudflare-worker\migrations\012_mod_tokens_and_dr_idempotency.sql` | NEW. `mod_tokens` table + unique index on `actions(target_user, dr_scheduled_at)` for Death Row ban rows |
| `D:\AI\_PROJECTS\setup-mod-tokens.ps1` | NEW. Applies migration 012 + prompts to run `/admin/import-tokens-from-kv`. BOM+ASCII, PS5.1 safe, 4-step ending |
| `D:\AI\_PROJECTS\verify-v7-2.ps1` | NEW. All acceptance criteria as static grep + live curl checks. BOM+ASCII, PS5.1 safe, 4-step ending |
| `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md` | Append `## v7.2 platform hardening -- data movement` section explaining sensitive state left page localStorage |
| `D:\AI\_PROJECTS\GIGA-V8.5-THE-ANTICIPATOR.md` | RENAMED from the old v7.2 slot (done pre-GIGA) |
| `D:\AI\_PROJECTS\GIGA-V7.2-PLATFORM-HARDENING.md` | THIS GIGA |

---

## BAKED-IN DESIGN DECISIONS (not up for re-litigation)

1. **One feature flag: `features.platformHardening` in `DEFAULT_SETTINGS`, default `false`.** Every v7.2 behavior change falls through to the v7.1.2 legacy path when the flag is off. Commander flips his own key first, dogfoods one shift, then uses v7.1.2's team-promote mechanism to roll it.
2. **v7.2 region convention.** Every new class / helper lives inside `// --- v7.2 Platform Hardening BEGIN ---` and `// --- v7.2 Platform Hardening END ---` blocks in `modtools.js`. Grep scans in `verify-v7-2.ps1` target those regions specifically to enforce the zero-new-`setInterval`, zero-new-`MutationObserver`, zero-new-`innerHTML=${...}` rules without false-positives on legacy code.
3. **Modularization deferred.** Master reports call for a `core/api.js` + `core/state.js` split. v7.2 does NOT split files. Instead v7.2 builds the primitive API surface (`CachedStore`, `DerivedIndexes`, `DomScheduler`, `MasterHeartbeat`) inside `modtools.js` so that v7.4 Architecture Refactor can lift those classes into their own files with a mechanical copy, not a rewrite. Anything that looks like API-layer refactor is OUT OF SCOPE.
4. **Storage adapter uses a PAGE_SAFE_KEYS allowlist, not a SENSITIVE_KEYS blocklist.** Default-deny: if a key is not in the allowlist, it never enters page `localStorage`. Initial allowlist: `gam_fallback_mode`, `gam_schema_version`. Nothing else.
5. **`lsGet` / `lsSet` keep their signatures.** They become compatibility shims. Flag-on path routes through `CachedStore` + `chrome.storage.local`; flag-off path preserves v7.1.2 behavior byte-for-byte. Hot-path call sites are NOT rewritten in v7.2.
6. **Worker derives actor identity from the verified token ONLY.** New `lookupModFromToken(token)` reads the `mod_tokens` D1 table (migration 012). Every privileged handler uses `const mod = requireMod(request)`. Client-supplied `body.mod`, `body.gaw_user`, `body.last_editor`, `body.gawUsername` are ignored at parse time, BEFORE any business logic runs. The ignore happens with a destructuring pattern so the linter catches re-introductions.
7. **Death Row idempotency is two layers deep.** Client-side `executing` `Set<username>` prevents fire-on-rapid-poll. Server-side unique index on `actions(target_user, dr_scheduled_at)` for rows where `action_type = 'ban_deathrow'` makes duplicate writes impossible at DB level. If both guards somehow fire, DB wins and the client surfaces `already executed` via normalized error path.
8. **Invite claim is stage-only in content script.** URL detection writes to `chrome.storage.session` under `gam_pending_invite`, strips the param via `history.replaceState`, shows a "invite detected -- open popup" snack. Popup has a dedicated button that reads the session key, displays a confirm modal with code prefix/suffix, POSTs claim via the background relay, clears the session key. Zero ambient claim on page load alone.
9. **`askTextModal({title, label, placeholder, max, validate})` is the single modal primitive for every privileged `prompt()` replacement.** Built with `el()`, never `innerHTML`. Client-side validation runs before submit; server-side validation reinforces. Four call sites replaced: `popup.js:308-313` (invite target), `modtools.js:4432-4442` (title grant), `modtools.js:4474-4477` (flag severity + reason), `modtools.js:10161-10163` (bug report).
10. **`normalizeWorkerError(resp)` is the single UI-facing error-string source.** Returns `permission denied` for 401/403, `rate limited` for 429, `request timed out` for abort/timeout, `worker request failed` for everything else. Raw backend text goes to `console.warn` only. Every `snack(` and `alert(` call path that consumes a worker response routes through this helper.
11. **`scrubUrlForTelemetry(raw)` replaces `_bugReportScrubUrl`.** Strips `#fragment` unconditionally. Strict query allowlist: `page`, `sort`, `filter`. Every telemetry caller that previously used `_bugReportScrubUrl` migrates to this.
12. **`allowlistedUrl(raw, ALLOWED_ORIGINS)` gates every outbound URL open / clipboard copy.** Allowlist: `https://greatawakening.win`, `https://*.greatawakening.win`, `https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev`, `https://discord.com`, `https://github.com`. URLs failing the check are shown as plain text only.
13. **Background relay exposes a fixed endpoint allowlist.** `/presence/*`, `/drafts/*`, `/proposals/*`, `/claims/*`, `/audit/*`, `/features/*`, `/ai/next-best-action`, `/ai/analyze`, `/bug/report`, `/invite/claim`, `/admin/import-tokens-from-kv`, `/modmail/sync`. Anything else returns `{ok:false, status:0, error:'endpoint not allowed'}` WITHOUT dispatching.
14. **TLS 1.2+ is enforced on the worker side; the client just POSTs.** No client-side TLS pinning in MV3 (not supported).
15. **All existing `ALLOW_INNERHTML_REVIEW:` allowlist comments in legacy code remain.** v7.2 adds NO new `innerHTML = ${...}` assignments; the grep guard in `verify-v7-2.ps1` only fires on v7.2 region hits.

---

## ACCEPTANCE CRITERIA (all verifiable by `verify-v7-2.ps1`)

### From Grok master report -- "Top 10 Quick Wins" (verbatim)

- [ ] 1. Replace `prompt()` everywhere -- 6 hours, massive UX + security win.
- [ ] 2. Add visibility check to 15s poller -- 2 hours, reduces unnecessary token exposure.
- [ ] 3. Add Death Row execution guard -- 2 hours, prevents double bans.
- [ ] 4. Add CSP to manifest -- 1 hour, major security improvement.
- [ ] 5. Create constants file (remove magic numbers) -- 3 hours. *(v7.2 scope: add a `TTL` + `ALLOWED_ORIGINS` + `PAGE_SAFE_KEYS` constant block inside the v7.2 region; full constants-file extraction deferred to v7.4.)*
- [ ] 6. Add try/catch + user-friendly errors to all `workerCall` -- 4 hours. *(covered by `normalizeWorkerError` + background relay try/catch.)*
- [ ] 7. Clear intervals/observers on SPA navigation -- 3 hours. *(covered because MasterHeartbeat + DomScheduler own the single interval / single observer.)*
- [ ] 8. Add `AbortController` to hover requests -- 2 hours. *(already present in v7.1 hover path; v7.2 verification only reconfirms it survived the poller refactor.)*
- [ ] 9. Log every Death Row execution -- 2 hours (observability). *(covered via unique-index DB row + client console.info `[DR] executed ${user}`.)*
- [ ] 10. Scrub more aggressively in debug snapshots -- 1 hour. *(covered by `scrubUrlForTelemetry` fragment fix and allowlist.)*

### From GPT master report -- "Phase 0 -- Containment (48 hours)" (verbatim)

- [ ] Stop mirroring sensitive data to page `localStorage`.
- [ ] Strip DOM-derived actor identity from worker writes.
- [ ] Add background relay for worker auth headers.
- [ ] Convert invite claim to popup-only staged flow.
- [ ] Replace all privileged `prompt()` calls with extension-owned modal.
- [ ] Add Death Row `executing` guard.
- [ ] Make SuperMod poller visibility-aware + stop on token clear.
- [ ] Normalize worker error surfaces for UI.

### From GPT master report -- "Phase 1 -- Structural foundation (Week 1)" (in-scope subset)

- [ ] Storage adapter (safe vs sensitive split) -- implemented as PAGE_SAFE_KEYS allowlist in `modtools.js` v7.2 region.
- [ ] State store interface -- implemented as `CachedStore` + `DerivedIndexes` inside `modtools.js` v7.2 region (file extraction deferred to v7.4).

*All other Phase 1 items (`core/api.js`, `core/selectors.js`, `core/utils.js`, bundler setup, file extraction) are DEFERRED to the v7.4 Architecture Refactor GIGA. See OUT OF SCOPE.*

### Feature-specific criteria

- [ ] `features.platformHardening === false` (default) is a full no-op: every v7.2 entry point falls through to v7.1.2 byte-for-byte. The v7.1 `verify-v7-1.ps1` still exits 0 with flag off.
- [ ] `chrome.storage.session.get('gam_pending_invite')` returns the invite code after URL-driven detection; NO claim request is issued until the popup "Claim invite" button is clicked and the confirm modal is accepted.
- [ ] Grep of `modtools.js` for `\bprompt\s*\(` returns zero hits inside privileged flows. (The verify script scans lines 4400-4500 and 10160-10180 plus the v7.2 region.)
- [ ] Grep of `modtools.js` v7.2 region for `innerHTML\s*=\s*.*\$\{` returns zero hits.
- [ ] Grep of `modtools.js` v7.2 region for `\bsetInterval\s*\(` returns zero hits (all recurring work hooks into `MasterHeartbeat.every`).
- [ ] Grep of `modtools.js` v7.2 region for `\bnew\s+MutationObserver\s*\(` returns zero hits (all observer work hooks into `DomScheduler.onProcess`).
- [ ] Grep of `modtools.js` for literal `'X-Mod-Token'` or `'X-Lead-Token'` inside content-script code returns zero hits. The only remaining occurrences are inside `background.js` (relay) and documentation strings.
- [ ] Grep of `background.js` for `chrome.storage.local.get(null)` returns zero hits (install-time inventory log removed).
- [ ] Grep of `modtools.js` v7.2 region for `window.open\s*\(` or `navigator.clipboard\.writeText` that is NOT preceded by an `allowlistedUrl(` call within 3 lines returns zero hits.
- [ ] Live endpoint smoke test: `POST /features/team/read` without any token returns HTTP 401 (regression protection).
- [ ] Live endpoint smoke test: `POST /drafts/write` with a valid mod token BUT body `{mod:'someone_else', target:'x', action:'note', body:'test'}` writes a row whose `last_editor` equals the TOKEN owner, not `'someone_else'`.
- [ ] Live endpoint smoke test: duplicate `POST /audit/log` writes with identical `(target_user, dr_scheduled_at)` for a Death Row ban return `{ok:false, error:'duplicate'}` on the second write.
- [ ] Worker sets `last_editor` / `actor` from `requireMod(request)`, never from the JSON body. Confirmed by grep of `gaw-mod-proxy-v2.js` for `body\.mod\b|body\.gaw_user\b|body\.last_editor\b|body\.gawUsername\b` returning zero hits outside an explicit `// IGNORED -- server derives from token` comment.
- [ ] `manifest.json` contains `content_security_policy.extension_pages` with `script-src 'self'; object-src 'self'; base-uri 'self';` and NO `'unsafe-eval'` / `'unsafe-inline'`.
- [ ] SuperMod poller skips its tick when `document.visibilityState === 'hidden'`. After a 429 response, the next tick delay follows `15s -> 30s -> 60s -> 120s (cap)`, and resets to 15s on next success. Verified by a mock test in `verify-v7-2.ps1` that drives a fake clock and asserts the delay sequence.
- [ ] `scrubUrlForTelemetry('https://greatawakening.win/foo?page=1&access_token=secret#state=abc')` returns `https://greatawakening.win/foo?page=1`.
- [ ] `normalizeWorkerError({status:401})` returns `permission denied`; `normalizeWorkerError({status:429})` returns `rate limited`; `normalizeWorkerError({timeout:true})` returns `request timed out`; `normalizeWorkerError({status:500})` returns `worker request failed`.
- [ ] Popup never repopulates raw tokens into input value fields. After save, `tokenInput.value` and `leadInput.value` are both `''`; status line reads `stored` / `not configured`.
- [ ] `allowlistedUrl('javascript:alert(1)', ALLOWED_ORIGINS)` returns `null`. `allowlistedUrl('https://evil.example.com/x', ALLOWED_ORIGINS)` returns `null`. `allowlistedUrl('https://discord.com/channels/foo', ALLOWED_ORIGINS)` returns the string.
- [ ] Endpoint allowlist enforcement: `chrome.runtime.sendMessage({type:'workerFetch', path:'/not-allowed', ...})` returns `{ok:false, error:'endpoint not allowed'}` without any outbound fetch.
- [ ] `setup-mod-tokens.ps1` applies migration 012 to the live `gaw-audit` D1 cleanly; parse-checks clean on BOTH `powershell.exe` AND `pwsh.exe`; ends with the mandatory four-step block (structured log -> `Set-Clipboard` -> E-C-G beep -> `Read-Host`).
- [ ] `verify-v7-2.ps1` exits 0 with every static + live check PASS.
- [ ] CWS ZIP build output under 215 KB compressed (v7.1.2 is ~155 KB; v7.2 adds ~6 KB for the primitive classes and helpers).
- [ ] `gaw-dashboard\public\PRIVACY.md` contains a new `## v7.2 platform hardening -- data movement` section that lists every `gam_*` key that moved out of page `localStorage` into `chrome.storage.local`.

### Performance Standards conformance (from `PERFORMANCE_STANDARDS.md` acceptance checklist)

- [ ] No new raw `localStorage.getItem` / `JSON.parse(localStorage...)` / `localStorage.setItem` / `JSON.stringify(...,localStorage)` in the v7.2 region. All persisted state uses `CachedStore` or the storage adapter.
- [ ] No new `MutationObserver` in the v7.2 region -- all consumers use `DomScheduler.onProcess(fn)`.
- [ ] No new `setInterval` or recurring `setTimeout` in the v7.2 region -- all consumers use `MasterHeartbeat.every(seconds, fn)`.
- [ ] Any per-user lookup over log / roster / watchlist / Death Row added in v7.2 uses a `DerivedIndexes` getter.
- [ ] Any regex used in a loop is cached via `compilePatternCached` or equivalent.
- [ ] `verify-v7-2.ps1` greps the v7.2 region for banned patterns and fails on any hit.

---

## SHIP ORDER

| Chunks | Phase |
|---|---|
| 0-2 | Performance foundation (CachedStore, DerivedIndexes, DomScheduler, MasterHeartbeat, regexCache, memoized trySelect). Regression test must pass after CHUNK 2 before security work begins. |
| 3-5 | Background relay + secret vault + popup token plumbing. After CHUNK 5 the content script can no longer attach auth headers directly. |
| 6-8 | Storage adapter + sensitive-key migration (`gam_mod_log`, `gam_users_roster`, `gam_deathrow`, `gam_watchlist`, `gam_user_notes`, `gam_profile_intel`, every `gam_draft_*`). |
| 9-11 | Actor identity removal (client side + worker side + migration 012 `mod_tokens`). |
| 12 | Death Row idempotency (client `executing` Set + worker unique index + DB-level reject). |
| 13 | `prompt()` replacement (4 sites + reusable `askTextModal`). |
| 14 | Invite claim stage-only + popup claim button. |
| 15 | URL scrubbing fragment fix + `normalizeWorkerError` + every snack/alert path using it. |
| 16 | Visibility-aware SuperMod poller + exponential backoff. |
| 17 | Manifest CSP tightening + remove background storage-inventory log + `allowlistedUrl` helper gating every `window.open` / clipboard copy. |
| 18 | `verify-v7-2.ps1` + `bump-version.ps1 -Version 7.2.0` + `build-chrome-store-zip.ps1`. |
| 19 | PRIVACY.md update + GIGA rename verification (v7.2 Anticipator -> v8.5, already done pre-GIGA). |

---

## CHUNK 0 -- Performance foundation, part 1: `CachedStore` + `regexCache` + memoized `trySelect`

File: `D:\AI\_PROJECTS\modtools-ext\modtools.js`. Insert inside the new `// --- v7.2 Platform Hardening BEGIN ---` block near the existing utilities section.

Paste the `CachedStore` class exactly as specified in `PERFORMANCE_STANDARDS.md` lines 43-60. Same for `regexCache` + `compilePatternCached` (standards lines 114-122) and the memoized `trySelect` (standards lines 129-144). Rule-list boot calls MUST pre-warm `regexCache` at rule-load time for both Auto-DR and Auto-Tard.

`lsGet(key, fallback)` and `lsSet(key, value)` signatures stay the same. Internal body:
- When `features.platformHardening` is `false`: preserve v7.1.2 behavior exactly.
- When `true`: delegate to the storage adapter (CHUNK 6) if `key` is in `SENSITIVE_KEYS`, or to `CachedStore` + `chrome.storage.local` if in `PAGE_SAFE_KEYS`.

**Success condition:** `node --check D:\AI\_PROJECTS\modtools-ext\modtools.js` exits 0. A unit-style check added to `verify-v7-2.ps1` loads `modtools.js` into jsdom, instantiates `CachedStore('test', {a:1})`, asserts `get('a') === 1`, mutates, asserts `dirty === true`, advances the fake clock 250ms, asserts `flush()` wrote to `localStorage`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 1 -- Performance foundation, part 2: `DerivedIndexes`

Same file, same region. Add a `DerivedIndexes` class exposing exactly the seven getters from `PERFORMANCE_STANDARDS.md` lines 66-73:

```
getUserHistory(username) -> entries[]   // Map<username, entry[]>
getBanCount(username)    -> number      // Map<username, number>
isWatched(username)      -> bool        // Set<username>
isDeathRowWaiting(username) -> bool     // Set<username>
getRosterRec(username)   -> rec|null    // Map<username, rec>
flagSeverityByUser.get(key) -> 'red'|'yellow'|'watch'|undefined
titlesByUser.get(key)    -> title[]|undefined
```

Rebuild is debounced same-tick as `CachedStore.flush` (250 ms). All map keys are lowercased. Rebuild triggers: any mutation of `gam_mod_log`, `gam_users_roster`, `gam_watchlist`, `gam_deathrow`, `gam_user_notes`.

Flag-off path: class is loaded but rebuild is never called; legacy linear scans remain in use.

**Success condition:** `node --check` exits 0. Verify script instantiates `DerivedIndexes` with a seeded mock store, asserts all seven getters return expected values, asserts `isDeathRowWaiting` is O(1) (Set.has), asserts `getUserHistory` is O(1) (Map.get).
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 2 -- Performance foundation, part 3: `DomScheduler` + `MasterHeartbeat` singletons

Same file, same region. Paste both classes exactly as specified in `PERFORMANCE_STANDARDS.md` lines 79-108. Expose singletons `window.__gam_dom_sched` and `window.__gam_heartbeat` for cross-call wiring.

No behavior change yet. The retirement of the 6+ existing `MutationObserver`s (GPT report 3.2 #3) and 23 existing `setInterval`s (GPT report 3.3 #8) is deferred to the v7.3 Performance Pass. v7.2 ONLY provides the substrate and enforces that NEW code in the v7.2 region uses these singletons.

Boot order: `DomScheduler.observe(document.body)` runs once after DOMContentLoaded AND only when `features.platformHardening === true`. `MasterHeartbeat` starts its interval unconditionally (it's a gated dispatcher, not a consumer).

**Success condition:** `node --check` exits 0. Regression: run the existing v7.1 smoke tests with flag off; all pass byte-for-byte. Regression: run them with flag on; all still pass.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 3 -- `background.js` secret vault + `workerFetch` relay

File: `D:\AI\_PROJECTS\modtools-ext\background.js`. Implement exactly the pattern from `modtools_sec_audit_report.md` section 3.A + 3.B. Structure:

```
const WORKER_BASE = 'https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev';
const ALLOWED_ENDPOINTS = new Set([
  '/presence', '/drafts', '/proposals', '/claims', '/audit', '/features',
  '/ai/next-best-action', '/ai/analyze', '/bug/report', '/invite/claim',
  '/admin/import-tokens-from-kv', '/modmail/sync'
]);
let secretCache = { workerModToken: '', leadModToken: '' };

chrome.runtime.onStartup.addListener(loadSecrets);
chrome.runtime.onInstalled.addListener(loadSecrets);
async function loadSecrets() {
  const { gam_settings = {} } = await chrome.storage.session.get('gam_settings');
  secretCache.workerModToken = gam_settings.workerModToken || '';
  secretCache.leadModToken   = gam_settings.leadModToken   || '';
}

function pathAllowed(path) {
  for (const prefix of ALLOWED_ENDPOINTS) {
    if (path === prefix || path.startsWith(prefix + '/')) return true;
  }
  return false;
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id) return;                           // origin guard

  if (msg && msg.type === 'setTokens') {                                 // popup save
    secretCache = {
      workerModToken: msg.workerModToken || '',
      leadModToken:   msg.leadModToken   || ''
    };
    chrome.storage.session.set({ gam_settings: secretCache })
      .then(() => sendResponse({ ok: true }));
    return true;
  }

  if (msg && msg.type === 'workerFetch') {
    if (!pathAllowed(msg.path || '')) {
      sendResponse({ ok: false, status: 0, error: 'endpoint not allowed' });
      return;
    }
    (async () => {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 20000);
      try {
        const headers = new Headers(msg.headers || {});
        if (secretCache.workerModToken) headers.set('X-Mod-Token', secretCache.workerModToken);
        if (msg.asLead && secretCache.leadModToken) headers.set('X-Lead-Token', secretCache.leadModToken);
        if (msg.body !== undefined && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
        const r = await fetch(WORKER_BASE + msg.path, {
          method: msg.method || (msg.body === undefined ? 'GET' : 'POST'),
          headers,
          body: msg.body === undefined ? undefined : JSON.stringify(msg.body),
          signal: ctrl.signal
        });
        sendResponse({ ok: r.ok, status: r.status, text: await r.text() });
      } catch (e) {
        sendResponse({ ok: false, status: 0, error: String(e && e.message || e), timeout: (e && e.name === 'AbortError') });
      } finally {
        clearTimeout(timer);
      }
    })();
    return true;
  }
});
```

Remove the existing `chrome.storage.local.get(null, ...)` inventory console.log at `background.js:20-24`.

**Success condition:** `node --check background.js` exits 0. Verify script uses a puppeteer-less mock: load the extension into a headless Chromium via playwright, post a `workerFetch` to `/not-allowed` from a content-script context, assert the response is `{ok:false, status:0, error:'endpoint not allowed'}` and no network request fires. Post to an allowlisted path, assert the `X-Mod-Token` header is present on the outbound request.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 4 -- `popup.js` token plumbing

File: `D:\AI\_PROJECTS\modtools-ext\popup.js`.

Replace the existing save-token button handler with `saveTokensSecurely({workerModToken, leadModToken})` that validates `/^[A-Za-z0-9_-]{32,256}$/` and POSTs `{type:'setTokens', ...}` via `chrome.runtime.sendMessage`. Never write tokens to `chrome.storage.local` from popup.

Replace `renderStoredState(state)` to leave `tokenInput.value = ''` and `leadInput.value = ''` unconditionally; status line reads `stored` / `not configured` based on a boolean `state.hasTeamToken` / `state.hasLeadToken` returned by a new `{type:'tokensStatus'}` message to the background.

Add a **"Claim invite"** button wired to the handler specified in CHUNK 14 (stub returns here, full logic in CHUNK 14).

**Success condition:** `node --check popup.js` exits 0. Verify script loads popup into jsdom, calls `saveTokensSecurely` with valid tokens, asserts a `chrome.runtime.sendMessage` call with `{type:'setTokens', ...}`; then re-renders and asserts both input `.value` properties are `''`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 5 -- content-script `workerCall` replacement

File: `modtools.js`. Inside the v7.2 region, add:

```js
async function workerCall(path, body, asLead, extSignal) {
  if (!window.__gam_flags?.platformHardening) return __legacyWorkerCall(path, body, asLead, extSignal);  // flag-off fallback
  const r = await chrome.runtime.sendMessage({
    type: 'workerFetch',
    path,
    method: body === undefined ? 'GET' : 'POST',
    body,
    asLead: !!asLead
  });
  let data = null;
  try { data = JSON.parse(r.text || 'null'); } catch {}
  return { ok: !!r.ok, status: r.status || 0, data, text: r.text || '', error: r.error || '', timeout: !!r.timeout };
}
```

Rename the existing content-script `workerCall` to `__legacyWorkerCall` and leave it intact for the flag-off path. Every direct `fetch(WORKER_BASE + ...)` still present in content script paths gets redirected through `workerCall` -- but ONLY when flag is on. The legacy direct-fetch code remains in place, flag-gated.

**Success condition:** Grep of `modtools.js` for `'X-Mod-Token'` OR `'X-Lead-Token'` as string literals returns zero hits outside the `__legacyWorkerCall` body. `node --check` exits 0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 6 -- Storage adapter with PAGE_SAFE_KEYS allowlist

File: `modtools.js`, v7.2 region. Implement exactly the pattern from `modtools_sec_audit_report.md` section 2.F1 with a Map-backed in-memory cache:

```js
const PAGE_SAFE_KEYS = new Set(['gam_fallback_mode', 'gam_schema_version']);
const __memStore = new Map();

async function safeGet(key, fallback) {
  if (__memStore.has(key)) return __memStore.get(key);
  const out = await chrome.storage.local.get(key);
  const value = (key in out) ? out[key] : fallback;
  __memStore.set(key, value);
  return value;
}

async function safeSet(key, value) {
  __memStore.set(key, value);
  await chrome.storage.local.set({ [key]: value });
  if (PAGE_SAFE_KEYS.has(key)) {
    try { localStorage.setItem(key, JSON.stringify(value)); } catch {}
  }
}

async function safeRemove(key) {
  __memStore.delete(key);
  await chrome.storage.local.remove(key);
  try { localStorage.removeItem(key); } catch {}
}
```

**Success condition:** `node --check` exits 0. Verify script calls `safeSet('gam_mod_log', [...])`, asserts `localStorage.getItem('gam_mod_log') === null`, asserts `chrome.storage.local.get('gam_mod_log')` returns the array. Calls `safeSet('gam_schema_version', 7)` and asserts BOTH stores contain it.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 7 -- Migrate sensitive-key hot-path reads to the adapter

Same file. Wire `lsGet` / `lsSet` to dispatch on the flag:
- Flag off: existing v7.1.2 behavior, unchanged.
- Flag on: if `key` is one of the SENSITIVE_KEYS (`gam_mod_log`, `gam_users_roster`, `gam_deathrow`, `gam_watchlist`, `gam_user_notes`, `gam_profile_intel`, `gam_settings`, every `gam_draft_*`), route through `safeGet`/`safeSet`. All others still go through v7.1.2 page localStorage.

On first flag-on boot, `hydrateFromChromeStorage()` MUST also perform a one-shot `localStorage.removeItem(k)` sweep for every SENSITIVE_KEY it finds -- stale page-localStorage copies from pre-7.2 MUST NOT linger.

**Success condition:** Verify script, with flag on, calls `lsSet('gam_watchlist', [...])`, then runs `Object.keys(localStorage).filter(k => k.startsWith('gam_'))` and asserts the result contains only keys from `PAGE_SAFE_KEYS`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 8 -- Draft persistence leaves page localStorage

Same file. Every `gam_draft_*` key handler (the v7.1 `Esc`-save path lives around lines 10987-11079) routes through the storage adapter when flag on. Rehydrate path also routes through adapter. Flag-off path unchanged.

**Success condition:** With flag on, set a draft via the normal Esc handler; grep page `localStorage` for any `gam_draft_` key -- zero hits. `chrome.storage.local` contains the entry.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 9 -- Migration 012: `mod_tokens` table + DR idempotency index

File: `D:\AI\_PROJECTS\cloudflare-worker\migrations\012_mod_tokens_and_dr_idempotency.sql`.

```sql
-- v7.2 platform hardening: token -> mod mapping + Death Row idempotency.

CREATE TABLE IF NOT EXISTS mod_tokens (
  token         TEXT PRIMARY KEY,
  mod_username  TEXT NOT NULL,
  is_lead       INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL,
  last_used_at  INTEGER
);
CREATE INDEX IF NOT EXISTS idx_mod_tokens_mod ON mod_tokens(mod_username);

-- DR ban idempotency: at most one row per (target_user, dr_scheduled_at).
-- Partial unique index limited to Death Row ban rows so non-DR bans are unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS uidx_actions_dr_ban
  ON actions(target_user, dr_scheduled_at)
  WHERE action_type = 'ban_deathrow';
```

**Success condition:** `wrangler d1 execute gaw-audit --remote --file=migrations/012_mod_tokens_and_dr_idempotency.sql` exits 0. `SELECT name FROM sqlite_master WHERE name IN ('mod_tokens','uidx_actions_dr_ban');` returns 2 rows.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 10 -- Worker `lookupModFromToken` + `requireMod`

File: `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js`.

Add:

```js
async function lookupModFromToken(token, env) {
  if (!token) return null;
  const row = await env.DB.prepare(
    'SELECT mod_username, is_lead FROM mod_tokens WHERE token = ? LIMIT 1'
  ).bind(token).first();
  if (!row) return null;
  env.DB.prepare('UPDATE mod_tokens SET last_used_at = ? WHERE token = ?')
    .bind(Date.now(), token).run().catch(() => {});
  return { mod: row.mod_username, isLead: !!row.is_lead };
}

async function requireMod(request, env, { lead = false } = {}) {
  const modTok  = request.headers.get('X-Mod-Token') || '';
  const leadTok = request.headers.get('X-Lead-Token') || '';
  const modRec  = await lookupModFromToken(modTok, env);
  if (!modRec) return { err: jsonResponse({ ok:false, error:'permission denied' }, 401) };
  if (lead) {
    const leadRec = await lookupModFromToken(leadTok, env);
    if (!leadRec || !leadRec.isLead) return { err: jsonResponse({ ok:false, error:'permission denied' }, 403) };
  }
  return { mod: modRec.mod, isLead: modRec.isLead };
}
```

Add one-shot admin endpoint `/admin/import-tokens-from-kv` (lead-gated via `requireMod(..., {lead:true})`) that reads the existing `TEAM_TOKENS` KV namespace and upserts every `(token, mod_username, is_lead)` triple into `mod_tokens`. Idempotent: re-runs are safe.

**Success condition:** Live: `curl -X POST /admin/import-tokens-from-kv -H "X-Lead-Token: $LEAD"` returns `{ok:true, data:{imported:N}}`. `SELECT COUNT(*) FROM mod_tokens;` matches the KV count. Request without lead token returns 403. `requireMod` unit test against a mock env returns `{mod:'testuser', isLead:false}` for a valid token and `{err: Response(401)}` for an invalid one.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 11 -- Worker: ignore client-supplied identity on every privileged write

Same worker file. For every handler that currently reads `body.mod`, `body.gaw_user`, `body.last_editor`, `body.gawUsername`, `body.actor`:

1. Call `const auth = await requireMod(request, env); if (auth.err) return auth.err;` at the top.
2. Parse the body and IMMEDIATELY discard the identity fields with a destructuring pattern that leaves a marker:
   ```js
   const { mod: _ignoredMod, gaw_user: _ignoredGawUser, last_editor: _ignoredLastEditor, gawUsername: _ignoredGawUsername, actor: _ignoredActor, ...body } = await request.json();
   ```
3. Use `auth.mod` wherever actor identity is needed downstream.

Handlers to update: `/drafts/write`, `/drafts/handoff`, `/proposals/create`, `/proposals/vote`, `/proposals/cancel`, `/claims/write`, `/claims/release`, `/features/team/write`, `/audit/log`, `/modmail/sync`, `/bug/report`, `/presence/viewing`, `/invite/claim`.

Remove the client-supplied `mod` field from `smCall` in `modtools.js` (the v7.2 region replacement) -- the relay stops injecting it. Delete `getMyModUsername()`. `me()` remains for UI display ONLY; its result is never attached to an outbound body.

**Success condition:** Grep of `gaw-mod-proxy-v2.js` for `body\.mod\b|body\.gaw_user\b|body\.last_editor\b|body\.gawUsername\b` returns zero hits outside `_ignored*` destructuring patterns. Live test: POST `/drafts/write` with body `{mod:'someone_else', target:'x', action:'note', body:'hi'}` using a token that maps to `realmod`; SELECT from `drafts` shows `last_editor='realmod'`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 12 -- Death Row idempotency (client + server)

Client-side (`modtools.js`, v7.2 region): Add `const __drExecuting = new Set();` to the Death Row subsystem. Before firing a DR ban:

```js
if (__drExecuting.has(target)) return;    // already in flight
__drExecuting.add(target);
try {
  const r = await workerCall('/audit/log', { action_type:'ban_deathrow', target_user: target, dr_scheduled_at: scheduledAt, ...payload }, false);
  if (!r.ok) {
    const msg = normalizeWorkerError(r);
    if (r.status === 409 || (r.text || '').includes('duplicate')) console.info('[DR] already executed', target);
    else snack(msg, 'error');
  } else {
    console.info('[DR] executed', target);
  }
} finally {
  __drExecuting.delete(target);
}
```

Server-side: existing DR handler catches the UNIQUE-constraint violation from the partial index and returns `{ok:false, status:409, error:'duplicate'}`.

**Success condition:** Fire two `workerCall('/audit/log', ...)` with identical `(target_user, dr_scheduled_at)` from a test harness; second one returns `{ok:false, status:409, error:'duplicate'}`. Client test: rapid double-fire with the same `target` issues exactly one outbound request (observed via background relay log).
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 13 -- `askTextModal` + replace four `prompt()` sites

File: `modtools.js`, v7.2 region. Paste `askTextModal({title, label, placeholder, max, validate})` from `modtools_sec_audit_report.md` section 2.5 code sample. Built with `el()`, Esc cancels, Enter submits, validation fires before resolve.

Replace exactly four sites:
- `popup.js:308-313` -- invite target username. `validate: v => /^[A-Za-z0-9_-]{3,24}$/.test(v) ? '' : 'Username 3-24 chars.'`
- `modtools.js:4432-4442` -- title grant (custom title + expiry). Two sequential modals; if first returns null, bail.
- `modtools.js:4474-4477` -- flag severity + reason. Use the two-step pattern from Voss section 3.E.
- `modtools.js:10161-10163` -- bug report title + description.

Server-side: every endpoint that receives text from these flows re-validates length + shape and rejects with `400` on failure (belt-and-suspenders).

**Success condition:** Grep of `modtools.js` + `popup.js` for `\bprompt\s*\(` returns zero hits in lines belonging to the four flows (verify script scans the specific line ranges). A jsdom test drives `askTextModal`, types invalid input, asserts `err.textContent` fires before resolve.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 14 -- Invite claim: stage-only in content, claim-only in popup

Content script (`modtools.js`, v7.2 region):

```js
(async function stageInviteFromUrl() {
  if (!window.__gam_flags?.platformHardening) return __legacyInviteClaim();
  const m = location.search.match(/[?&]mt_invite=([^&]+)/);
  if (!m) return;
  const code = decodeURIComponent(m[1]);
  try { history.replaceState({}, '', location.pathname); } catch {}
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(code)) return;
  await chrome.storage.session.set({ gam_pending_invite: code });
  snack('Invite detected -- open the ModTools popup to review.', 'warn');
})();
```

Popup (`popup.js`): the "Claim invite" button handler reads `chrome.storage.session.get('gam_pending_invite')`, shows `confirmModal({title:'Claim team invite?', body:'Invite code: '+code.slice(0,12)+'...'+code.slice(-4)})`, on OK posts `workerFetch` to `/invite/claim` through the background relay, on success clears `gam_pending_invite`.

**Success condition:** With flag on, visit `https://greatawakening.win/?mt_invite=<16+char code>`; after page load, `chrome.storage.session.get('gam_pending_invite')` returns the code, `location.search` is empty, and NO network request to `/invite/claim` has fired. After clicking "Claim invite" in popup and confirming, exactly one request fires.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 15 -- URL scrubbing fix + `normalizeWorkerError`

File: `modtools.js`, v7.2 region. Paste exactly:

```js
function scrubUrlForTelemetry(raw) {
  try {
    const url = new URL(raw, location.href);
    url.hash = '';
    const allow = new Set(['page', 'sort', 'filter']);
    for (const key of [...url.searchParams.keys()]) if (!allow.has(key)) url.searchParams.delete(key);
    return url.origin + url.pathname + (url.search ? url.search : '');
  } catch { return location.origin + location.pathname; }
}

function normalizeWorkerError(resp) {
  if (!resp) return 'request failed';
  if (resp.timeout) return 'request timed out';
  if (resp.status === 401 || resp.status === 403) return 'permission denied';
  if (resp.status === 429) return 'rate limited';
  return 'worker request failed';
}
```

Replace every `_bugReportScrubUrl` call with `scrubUrlForTelemetry`. Every `snack(` / `alert(` call path that consumes a `workerCall` result routes the message through `normalizeWorkerError` when flag on. Raw backend text goes to `console.warn` only.

**Success condition:** `scrubUrlForTelemetry('https://greatawakening.win/foo?page=1&access_token=secret#state=abc')` returns `https://greatawakening.win/foo?page=1`. `normalizeWorkerError` returns exactly the four strings for the four status classes. Grep of v7.2 region confirms no raw `r.text` passed to `snack(` / `alert(`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 16 -- Visibility-aware SuperMod poller + exponential backoff

Same file. Replace the current `superModPoller` `setInterval(15000)` with a `MasterHeartbeat.every(N, fn)` subscription:

```js
let __smDelaySec = 15;
MH.every(1, () => {
  if (!window.__gam_flags?.platformHardening) return;
  if (document.visibilityState !== 'visible') return;               // skip hidden
  if (!__smLastTick || (Date.now() - __smLastTick) >= __smDelaySec * 1000) {
    __smLastTick = Date.now();
    superModTick().then(ok => {
      __smDelaySec = ok ? 15 : Math.min(120, __smDelaySec * 2);
    }).catch(() => { __smDelaySec = Math.min(120, __smDelaySec * 2); });
  }
});
```

`superModTick()` returns `true` on success, `false` on 429 / network error. On token clear (settings read returns empty workerModToken), the tick returns early WITHOUT resetting the delay and WITHOUT firing a request.

Flag-off path: the legacy `setInterval(superModPollerLegacy, 15000)` remains, unchanged.

**Success condition:** Fake-clock test: drive visibility `hidden`, advance clock 60s, assert zero calls. Switch to `visible`, assert one call. Force 429, observe next call at +30s, then +60s, then +120s, then +120s (cap). Force success, observe reset to 15s.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 17 -- Manifest CSP + background log removal + `allowlistedUrl`

File: `D:\AI\_PROJECTS\modtools-ext\manifest.json`. Add:

```json
"content_security_policy": {
  "extension_pages": "script-src 'self'; object-src 'self'; base-uri 'self';"
}
```

Bump `"version"` to `"7.2.0"`.

File: `background.js`. Delete the `chrome.storage.local.get(null, items => console.log('[gam] storage inventory', Object.keys(items)))` block at lines 20-24 (done in CHUNK 3; verify it's gone).

File: `modtools.js`, v7.2 region. Add:

```js
const ALLOWED_ORIGINS = new Set([
  'https://greatawakening.win',
  'https://gaw-mod-proxy.gaw-mods-a2f2d0e4.workers.dev',
  'https://discord.com',
  'https://github.com'
]);
function allowlistedUrl(raw) {
  try {
    const u = new URL(raw);
    if (u.protocol !== 'https:') return null;
    if (ALLOWED_ORIGINS.has(u.origin)) return u.toString();
    if (u.hostname.endsWith('.greatawakening.win')) return u.toString();
    return null;
  } catch { return null; }
}
```

Every v7.2-region call to `window.open(...)`, `chrome.tabs.create({url:...})`, or `navigator.clipboard.writeText(url)` gates through `allowlistedUrl` first. If it returns null, show the URL as plain text via `el('code', {}, raw)` instead.

**Success condition:** `manifest.json` CSP passes a `jq '.content_security_policy.extension_pages' manifest.json` check. Grep of `background.js` for `chrome.storage.local.get(null` returns zero hits. `allowlistedUrl('javascript:alert(1)')` returns null. `allowlistedUrl('https://mod.greatawakening.win/foo')` returns the string.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 18 -- `verify-v7-2.ps1` + bump + build

File: `D:\AI\_PROJECTS\verify-v7-2.ps1`. BOM+ASCII, PS 5.1 safe, four-step ending mandatory. Checks (in order):

Static (grep-based):
1. Extract the v7.2 region from `modtools.js`. Check for banned patterns (`setInterval(`, `new MutationObserver(`, `innerHTML\s*=\s*.*\$\{`). Zero hits.
2. `node --check` clean on `modtools.js`, `background.js`, `popup.js`, `gaw-mod-proxy-v2.js`.
3. `manifest.json` version === `7.2.0` and CSP present.
4. Grep `modtools.js` privileged flow line ranges for `prompt(`. Zero.
5. Grep `modtools.js` for `'X-Mod-Token'` / `'X-Lead-Token'` outside `__legacyWorkerCall`. Zero.
6. Grep `background.js` for `chrome.storage.local.get(null`. Zero.
7. Grep `gaw-mod-proxy-v2.js` for `body\.(mod|gaw_user|last_editor|gawUsername|actor)\b` outside `_ignored*` destructuring. Zero.
8. Grep every `window.open`, `chrome.tabs.create`, `clipboard.writeText` in the v7.2 region for a preceding `allowlistedUrl(` within 3 lines.
9. `CachedStore`, `DerivedIndexes`, `DomScheduler`, `MasterHeartbeat`, `regexCache`, memoized `trySelect` all present by name.

Live (curl-based, require worker already deployed):
10. `POST /features/team/read` with NO tokens -> 401.
11. `POST /drafts/write` with valid mod token, body `{mod:'someone_else', target:'__verify', action:'note', body:'x'}` -> 200; `SELECT last_editor FROM drafts WHERE target='__verify'` returns the token owner, NOT `'someone_else'`.
12. `POST /audit/log` twice with identical `(target_user, dr_scheduled_at)` and `action_type='ban_deathrow'` -> second returns 409 / duplicate.
13. `POST /admin/import-tokens-from-kv` with mod-only token -> 403; with lead token -> `{ok:true, data:{imported:N}}` with N matching KV count.
14. `GET /presence/viewing?kind=User&id=__verify` -> `{ok:true,data:null}` (regression test of existing endpoint).

Unit-style (jsdom + node):
15. `scrubUrlForTelemetry('https://greatawakening.win/foo?page=1&access_token=x#y')` === `'https://greatawakening.win/foo?page=1'`.
16. `normalizeWorkerError({status:401})` === `'permission denied'`; 429 -> `'rate limited'`; `{timeout:true}` -> `'request timed out'`; `{status:500}` -> `'worker request failed'`.
17. `allowlistedUrl('javascript:alert(1)')` === `null`.
18. Fake-clock SuperMod poller: hidden -> zero calls. Visible -> one call. 429 sequence -> delay 15, 30, 60, 120, 120. Success -> reset to 15.

Each check writes to `$log` buffer. End with mandatory four-step:
1. Structured final report.
2. `$log -join "\`n" | Set-Clipboard` + `[log copied to clipboard]`.
3. `[Console]::Beep(659,160); Start-Sleep -Milliseconds 100; [Console]::Beep(523,160); Start-Sleep -Milliseconds 100; [Console]::Beep(784,800)`.
4. `Read-Host 'Press Enter to exit'` (skip only on `-NoPause`).

Persist log to `D:\AI\_PROJECTS\logs\verify-v7-2-YYYYMMDD-HHMMSS.log`.

Build commands (Commander pastes these in order; NO wrangler deploy, NO git push, NO migration execution inside the script):
```
pwsh -File D:\AI\_PROJECTS\bump-version.ps1 -Version 7.2.0 -Notes "v7.2 Platform Hardening: perf foundation + P0 security. All behind features.platformHardening (default off)."
pwsh -File D:\AI\_PROJECTS\setup-mod-tokens.ps1
cd D:\AI\_PROJECTS\cloudflare-worker
npx --yes wrangler@latest deploy
cd D:\AI\_PROJECTS
pwsh -File D:\AI\_PROJECTS\build-chrome-store-zip.ps1
pwsh -File D:\AI\_PROJECTS\verify-v7-2.ps1
```

**Success condition:** `verify-v7-2.ps1` exits 0 with every check PASS. `$log` on clipboard. ECG beep plays. CWS ZIP < 215 KB compressed.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 19 -- PRIVACY.md update + rename verification

File: `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md`. Append (do NOT nuke prior content):

```
## v7.2 platform hardening -- data movement

As of v7.2, the following moderator state keys NO LONGER live in page-domain localStorage. They are stored in the extension's own chrome.storage.local area, readable only by the extension itself:

- gam_mod_log (moderator action history)
- gam_users_roster (team roster state)
- gam_deathrow (queued Death Row bans)
- gam_watchlist (watched users)
- gam_user_notes (per-user mod notes)
- gam_profile_intel (cached profile intel)
- gam_settings (extension settings, including worker tokens)
- gam_draft_* (Esc-saved reply drafts)

Only harmless UI preferences remain in page localStorage:

- gam_fallback_mode
- gam_schema_version

Worker authentication tokens (X-Mod-Token, X-Lead-Token) are held in the extension's service-worker memory and chrome.storage.session. They are never readable from the page.

This change reduces the risk that site-side JavaScript, a co-installed browser extension with matching host permissions, or a future page-level XSS could read moderator operational intelligence.
```

Verify the rename done pre-GIGA:
- `D:\AI\_PROJECTS\GIGA-V8.5-THE-ANTICIPATOR.md` exists.
- `D:\AI\_PROJECTS\GIGA-V7.2-THE-ANTICIPATOR.md` does NOT exist.

**Success condition:** `Test-Path GIGA-V8.5-THE-ANTICIPATOR.md` is true; `Test-Path GIGA-V7.2-THE-ANTICIPATOR.md` is false. PRIVACY.md contains the new heading.
**If fails:** rewrite entire chunk from scratch.

---

## VERIFICATION PROTOCOL (Commander runs these in order)

Exactly the build-commands block in CHUNK 18. All six steps must exit 0. The hardening surface only activates after Commander flips `features.platformHardening` in the extension Settings panel for his own install, then for additional mods via v7.1's one-click team promotion.

---

## ROLLOUT PROTOCOL (Commander owns this)

1. Ship v7.2 via GitHub auto-update. Flag default OFF means every mod sees byte-identical v7.1.2 behavior.
2. Commander enables `features.platformHardening` for himself only. Runs one full shift solo. Verifies: drafts still persist (now in chrome.storage.local), Esc-save still works, no auth headers visible in page-side DevTools network tab, no sensitive `gam_*` keys in page localStorage.
3. Commander uses v7.1's one-click team promote to enable the flag for one other mod. They verify a Propose Ban + Execute end-to-end still works. Server-side audit log attributes actions to the TOKEN owner regardless of DOM state.
4. After one clean shared shift, Commander rolls the flag to remaining mods.
5. After two weeks clean, v7.4 Architecture Refactor locks the flag ON by default and extracts `__legacyWorkerCall`, `legacy-invite-claim`, legacy storage paths into dead-code deletions.
6. At any point, flag-off restores v7.1.2 behavior instantly. No re-install needed.

---

## IF A CHUNK FAILS 3x, ESCALATE TO COMMANDER

Stop implementation. Produce one message:
1. Chunk number and name.
2. Three unified diffs (git-diff format) of the attempts and how each failed.
3. The specific acceptance-criterion line that did not pass.
4. One-sentence hypothesis of root cause.
5. Two proposed alternatives with tradeoffs.

Do not attempt a 4th autonomous rewrite.

---

## OUT OF SCOPE (each its own GIGA, or deferred)

Deferred to v7.3 Performance Pass:
- Retrofit the 6+ legacy `MutationObserver`s into `DomScheduler.onProcess` handlers.
- Retrofit the 23 legacy `setInterval` timers into `MasterHeartbeat.every` subscriptions.
- Migrate legacy linear scans over mod log / Death Row / watchlist / flags into `DerivedIndexes` getters.
- Bounded-concurrency Inbox Intel queue.
- Page router (boot only on relevant pages).
- Event delegation from a single document-level click handler.
- DOM-batching pass (fragments + join, retire iterative appendChild).

Deferred to v7.4 Architecture Refactor:
- Split `modtools.js` into `core/api.js`, `core/state.js`, `core/storage.js`, `core/selectors.js`, `core/utils.js`.
- Esbuild / Vite bundler path with MV3-safe output.
- Mount/unmount lifecycle for major UI subsystems.
- Delete `__legacyWorkerCall`, legacy storage paths, legacy invite-claim path.
- Dead-code removal of every flag-off branch.

Deferred to v7.5 Test Harness:
- Jest or Vitest setup + jsdom fixtures.
- Fetch mock layer + Chrome extension adapter mocks.
- First 12 high-ROI unit tests (computeWordScore, export scrubbing, selector learning, Death Row timing, worker timeout, roster counting, invite staging, SuperMod state machine, hover cache eviction, storage dirty-flush, dashboard HTML escaping, Auto-DR application logic).
- One end-to-end moderator flow.
- CI regression harness for destructive actions.

Deferred to v8.0 Team Productivity (already scheduled):
- Watchers / owners / incident-room team coordination.
- Queue-based modmail (six explicit queues).
- My Desk on `/u/me` (start-of-shift cockpit).
- Global command palette (Ctrl+K).
- Shared Discord-embedded proposal review.

Deferred to v8.5 The Anticipator (renamed from old v7.2 slot):
- Everything in the renamed `GIGA-V8.5-THE-ANTICIPATOR.md`.

Explicitly NOT in v7.2 (per master reports but out of this scope):
- Response signature verification (worker-side).
- Token rotation + short-lived scoped session tokens.
- Per-mod anomaly detection / abuse heuristics.
- Security-event ring buffer (v7.3 reliability pass).
- `innerHTML` surface-area reduction outside the v7.2 region.
- Host permission minimization.
- Schema versioning + migration framework (v8.0 if needed).
- Plugin / hook system (v8.5+).
