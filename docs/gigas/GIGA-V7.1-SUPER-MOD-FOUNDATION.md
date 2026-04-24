# GIGA-V7.1-SUPER-MOD-FOUNDATION

**Audience:** Claude Code session with blanket approval from Commander Cats.
**Target:** GAW ModTools v7.0.x -> v7.1.0.
**Small-team bias:** 2-5 mods coordinating in Discord. v7.0 gave each operator the Intel Drawer; v7.1 gives the TEAM shared operational memory -- drafts survive a browser close, proposed bans get a second pair of eyes, and mods stop colliding on the same target. Polling-only (15s global tick); no WebSockets. Everything behind `features.superMod` (default OFF) so Commander dogfoods solo before rolling per-mod.

---

## MISSION

Ship the "super-mod foundation" -- the twelve smallest primitives that turn a solo Intel Drawer into a team-coordinated review surface. **Draft persistence** (Esc-save, cross-mod takeover, handoff). **Consensus** (Propose Ban + Propose Remove + Propose Lock, with audible chime, lead-token veto, auto-escalate cron). **Real-time presence** (who's online, who's viewing, collision warning, ghost claim, pre-drafted ban reply). Every feature falls through to v7.0 behavior when the flag is off, so a single bad chunk cannot harm live moderation. One D1 migration (`008_super_mod_foundation.sql`), four new endpoint families on the existing worker, one global 15-second poller on the extension, and a mandatory `setup-super-mod.ps1` with the 4-step ending.

---

## DELIVERABLES

| Path | Purpose |
|---|---|
| `D:\AI\_PROJECTS\modtools-ext\modtools.js` | `features.superMod` flag, global 15s poller, audible-chime Web Audio helper, Esc draft-save, cross-mod banner, Propose Ban/Remove/Lock UI, proposal review UI in drawer header, online chip, viewing banner, collision-warning modal, ghost-claim badge, ban-draft prefetch |
| `D:\AI\_PROJECTS\modtools-ext\manifest.json` | version 7.1.0 |
| `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js` | `/drafts/{write,read,list,handoff,delete}`, `/proposals/{create,vote,list,cancel}`, `/presence/viewing`, `/presence/heartbeat` (extend), `/claims/{write,release,list}`, cron extension for 1h proposal auto-escalate Discord ping |
| `D:\AI\_PROJECTS\cloudflare-worker\migrations\008_super_mod_foundation.sql` | `proposals`, `drafts`, `claims` tables + indexes |
| `D:\AI\_PROJECTS\gaw-mod-shared-flags\version.json` | 7.1.0 |
| `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md` | append v7.1 data category section |
| `D:\AI\_PROJECTS\setup-super-mod.ps1` | applies migration 008 to remote D1 (BOM+ASCII, 4-step ending) |
| `D:\AI\_PROJECTS\verify-v7-1.ps1` | verification script (BOM+ASCII, 4-step ending) |

---

## FEATURE -> CHUNK MAP

| # | Feature | Chunk |
|---|---|---|
| 1 | Esc saves draft to localStorage | 9 |
| 2 | Draft survives tab close / reload (rehydrate) | 10 |
| 3 | Cross-mod draft D1 table + takeover banner | 3, 11 |
| 4 | Hand off to team button | 12 |
| 5 | Propose Ban (modal + chime + Discord + AI note) | 4, 13, 15 |
| 6 | Propose Remove Post / Lock Thread | 4, 14 |
| 7 | Auto-escalate cron > 1h | 6 |
| 8 | Who's online chip | 7, 16 |
| 9 | "Mod X is reviewing Y" banner | 2, 17 |
| 10 | Collision warning before ban/remove/lock | 18 |
| 11 | Ghost claim on modmail thread open | 5, 19 |
| 12 | Pre-drafted ban reply on drawer open | 20 |

---

## ACCEPTANCE CRITERIA (all must be checkable by `verify-v7-1.ps1`)

- [ ] `features.superMod === false` (default) is a full no-op: every v7.1 entry point falls through to the v7.0/v7.0.1 behavior verified by v7.0 tests still passing byte-for-byte.
- [ ] Pressing Esc in any of `#mc-ban-msg`, `#mc-note-body`, `#mc-msg-body` with text in it writes `localStorage[gam_draft_{action}_{target}]` as a JSON blob with `{body, ts}` and closes the modal without sending. TTL 7 days enforced on read (any entry older than 7*86400000 ms is silently purged).
- [ ] Reopening the same action+target rehydrates the textarea from localStorage; successful send clears the entry; `verify-v7-1.ps1` check `L` sets a draft, reloads the mock page via node, and asserts rehydration.
- [ ] 2-second debounced `PUT /drafts/write` fires on every keystroke into a reply textarea (not per-keystroke -- trailing debounce). Payload `{action, target, body, last_editor}`. Grep confirms the debounce wraps the textarea input listener with a 2000 ms delay.
- [ ] Opening an action+target where another mod wrote a draft within the last 24h renders a banner `Mod X was drafting Nm ago -- [Take over]` built entirely with `el()`, no raw innerHTML of fetched text. Take-over reassigns `last_editor` via `PUT /drafts/write` and rehydrates the textarea.
- [ ] Draft entries auto-expire 24 h after last_edited_at (D1 index + cron purge).
- [ ] "Hand off to team" button on any open draft writes `PATCH /drafts/handoff {status:'handed_off', handoff_note}`; subsequent `/drafts/list` shows it with that status.
- [ ] "Propose Ban" button appears next to the normal Ban button (only when `features.superMod=true`). Modal has fields `{target, duration, reason, proposer_note}`. Submit creates D1 row `proposals {kind:'ban'}` via `POST /proposals/create`.
- [ ] Creating a proposal: (a) triggers audible chime on every online mod on their next 15s poll, (b) status-bar alert `[PROPOSE BAN] @target by @proposer -- [Review]`, (c) fires `/ai/next-best-action` with `kind:'ProposedBan'` generating `<=120-char` AI mod note cached in L1 Map, (d) POSTs to `DISCORD_WEBHOOK` lead channel.
- [ ] Second mod clicks Execute -> ban fires through the existing ban pipeline (no duplicated action code); proposal marked `executed` with `executor` + `executed_at`. Veto requires lead-token (mod-token returns 401). Punt (any mod) marks `punted`. All proposals auto-expire 4 h via a cron sweep if still `pending`.
- [ ] "Propose Remove Post" and "Propose Lock Thread" share the same table via `kind IN ('remove_post','lock_thread')`. Execute calls the existing remove/lock handlers respectively.
- [ ] Cron hits the proposals table every `*/5 * * * *` (existing cron schedule extended -- do not add a second schedule). Proposals `pending > 1h` Discord-ping lead channel exactly once (`alerted_at` flag prevents duplicate pings).
- [ ] Single global poller at 15s hits `/proposals/list?since=T` + `/presence/online` + `/drafts/list?mine=1` in ONE round of three parallel requests (not per-feature timers). Grep confirms exactly one `setInterval` for `superModPoller` with `15000` ms.
- [ ] "Who's online" chip `[N mods online]` in status bar updates from `/presence/online`. Clicking it opens a tooltip with usernames + `current_page` (last heartbeat path).
- [ ] `IntelDrawer.open` now also PUTs `/presence/viewing {kind, id, ts, mod}` (10-min TTL). Re-opening the same `{kind,id}` shown by another mod within TTL displays banner `Mod X is reviewing this -- opened Nm ago`. XSS: banner built with `el()`, never `innerHTML`.
- [ ] Before Ban, Remove, Lock, Execute: client checks `/presence/viewing` for the target; if another mod is viewing within TTL, modal warns `Mod X is reviewing this right now. Continue? [Yes, proceed] [No, wait]`.
- [ ] Opening a modmail thread PUTs `/claims/write {thread_id, mod, expires_at: now+600000}`. Other mods' `/claims/list` shows `Mod X on this, auto-releases in Nm`. Badge refreshes on every interaction within the thread.
- [ ] Opening a User drawer with `features.superMod=true` parallel-fires `/ai/next-best-action {kind:'User', extra:{intent:'ban_draft'}}` (re-uses the v7.0 endpoint, no new endpoint). Response cached in L1 Map keyed `banDraft:${user}`; when the Ban tab opens, its textarea pre-populates from cache if present. AbortController cancels if drawer closes first.
- [ ] Audible chime respects `features.audibleAlerts` (default `true`). Uses Web Audio API (no bundled audio file). Three-tone C-E-G rising 200 ms each.
- [ ] `setup-super-mod.ps1` applies migration 008 cleanly against the live `gaw-audit` D1; parse-checks clean on both `powershell.exe` and `pwsh.exe`; ends with the 4-step mandatory block (log buffer -> clipboard, E-C-G beep, Read-Host).
- [ ] `verify-v7-1.ps1` exits 0 with every check PASS.
- [ ] CWS ZIP builds under 210 KB compressed (v7.0 is ~147 KB; v7.1 adds ~8 KB gzip).
- [ ] `gaw-dashboard\public\PRIVACY.md` contains a new `## v7.1 data categories` heading covering proposals (30d), drafts (24h unsent, 7d sent), presence viewing (10-min TTL), claims (10-min TTL), plus an explicit note that Propose-action AI notes go through the existing `/ai/next-best-action` KV budget.

---

## BAKED-IN DESIGN DECISIONS (from the pre-draft review -- not up for re-litigation)

1. **Feature flag `features.superMod` in `DEFAULT_SETTINGS`, default `false`.** Every v7.1 entry point checks the flag and falls through to v7.0.x. Commander flips his own key first, runs solo for a shift, then rolls per-mod. This is the ONE mechanism that makes "one-chance rollout" survivable.
2. **Reuse `handleAiNextBestAction` -- do NOT add a new AI endpoint.** The v7.0 endpoint already enforces the `bot:grok:budget:${todayUTC()}` KV budget, daily cap, and `<untrusted_user_content>` wrap. v7.1 adds two new `kind` values (`ProposedBan`, and implicit via `extra:{intent:'ban_draft'}`) and an action whitelist update for each. One endpoint, one budget, one audit trail.
3. **One migration file: `008_super_mod_foundation.sql`.** Three tables (`proposals`, `drafts`, `claims`) ship together or not at all. No partial rollout of the schema.
4. **Single global poller at 15 s.** Three parallel `workerCall`s in one tick. Not N polling timers. Debounce `/drafts/write` (2 s trailing) and every drawer fetch (500 ms minimum same-subject) independently -- those are *push* debounces, not polling.
5. **Token gating:**
   * Mod-token: `/drafts/*`, `/proposals/create`, `/proposals/vote` (action=Execute|Punt), `/proposals/list`, `/proposals/cancel` (own only), `/presence/viewing`, `/claims/*`.
   * Lead-token: `/proposals/vote` with action=Veto; auto-escalate Discord ping webhook.
   * Worker enforces; client never decides gating.
6. **XSS contract: `el()` with `textContent` children only for every fetched string.** Drawer header chip, cross-mod banner, viewing banner, claims badge, proposals list, online tooltip -- all built via `el()` node-by-node. No `innerHTML = template-literal-with-fetched-data` anywhere in v7.1 code paths. The `el()` helper warns on `html` keys; this is the enforcement backstop.
7. **AI prompt wrapping: every `extra.*` field and every proposal context field is wrapped in `<untrusted_user_content>` tags** before inclusion in the system prompt, per v5.8.1 precedent still in force.
8. **Audible alerts respect user preference.** `features.audibleAlerts` default true; Settings panel toggle; muted automatically when Document visibility is hidden for >5 minutes (stale tab).
9. **AbortController on every drawer fetch, including the new ban-draft prefetch.** `IntelDrawer._currentAbort` cancels in-flight AI calls when the drawer closes or subject changes.
10. **AbortController on every outbound action from a proposal review.** If the reviewing mod cancels mid-execute, the proposal remains `pending`, not `executed`.
11. **Draft storage layering:** localStorage for individual mod's own draft (free, no network). D1 `drafts` for cross-mod visibility. The two are kept in sync by the 2-second debounced PUT; conflicts resolve last-writer-wins with a visible `last_editor` field.
12. **Claim TTL 10 min, presence viewing TTL 10 min, draft TTL 24 h, proposal auto-expire 4 h, auto-escalate at 1 h, precedents indefinite (v7.0).** These are the five numbers; they do not appear as magic numbers in code -- define a `TTL` constant object in modtools.js and a matching `const TTL` object in the worker.
13. **Chrome storage key reused: `gam_settings_v7`** (same as v7.0). `features.superMod` lives inside that key. No new `gam_settings_v7_1` -- v7.1 is a strict feature superset.

---

## CHUNK 1 -- D1 migration `008_super_mod_foundation.sql`

File: `D:\AI\_PROJECTS\cloudflare-worker\migrations\008_super_mod_foundation.sql`. Template mirror of `007_precedents.sql`.

```sql
-- v7.1 super-mod foundation: drafts, proposals, claims.
-- All three tables ship together. Mod-token read/write except where noted; the
-- worker enforces gating -- these tables have no row-level auth.

CREATE TABLE IF NOT EXISTS drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action        TEXT NOT NULL,      -- ban | note | msg | (free-form action key)
  target        TEXT NOT NULL,      -- username | thread id | post id
  body          TEXT NOT NULL,      -- the draft text
  last_editor   TEXT NOT NULL,      -- token-verified mod username
  status        TEXT NOT NULL DEFAULT 'open',   -- open | handed_off | sent | abandoned
  handoff_note  TEXT,
  created_at    INTEGER NOT NULL,   -- ms epoch
  last_edit_at  INTEGER NOT NULL,   -- ms epoch; used for 24h TTL
  UNIQUE(action, target)            -- one live draft per action+target; UPSERT on PUT
);
CREATE INDEX IF NOT EXISTS idx_drafts_target         ON drafts(target);
CREATE INDEX IF NOT EXISTS idx_drafts_last_edit_at   ON drafts(last_edit_at DESC);
CREATE INDEX IF NOT EXISTS idx_drafts_last_editor    ON drafts(last_editor);

CREATE TABLE IF NOT EXISTS proposals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind          TEXT NOT NULL,      -- ban | remove_post | lock_thread
  target        TEXT NOT NULL,      -- username or post/thread id
  duration      TEXT,               -- for ban: 24h | 168h | perm; null for others
  reason        TEXT,
  proposer      TEXT NOT NULL,      -- token-verified mod username
  proposer_note TEXT,
  ai_note       TEXT,               -- <=120 char AI advisory
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending | executed | vetoed | punted | expired
  executor      TEXT,
  executed_at   INTEGER,
  created_at    INTEGER NOT NULL,
  alerted_at    INTEGER              -- set once when 1h auto-escalate fires
);
CREATE INDEX IF NOT EXISTS idx_proposals_status      ON proposals(status);
CREATE INDEX IF NOT EXISTS idx_proposals_created_at  ON proposals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_proposals_target      ON proposals(target);

CREATE TABLE IF NOT EXISTS claims (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  thread_id   TEXT NOT NULL UNIQUE,
  mod         TEXT NOT NULL,
  claimed_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_claims_expires_at ON claims(expires_at DESC);
```

**Success condition:** `wrangler d1 execute gaw-audit --remote --file=migrations/008_super_mod_foundation.sql` exits 0. `wrangler d1 execute gaw-audit --remote --command="SELECT name FROM sqlite_master WHERE type='table' AND name IN ('drafts','proposals','claims');"` returns 3 rows.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 2 -- worker `/presence/viewing` endpoint

File: `gaw-mod-proxy-v2.js`. Extend the existing presence family (`handlePresencePing`, `handlePresenceOnline` at line ~468). Add:

```js
async function handlePresenceViewing(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  if (!body.kind || !body.id) return jsonResponse({ok:false, error:'kind+id required'}, 400);
  const mod = getModUsernameFromToken(request, env);
  const key = `presence:viewing:${body.kind}:${body.id}`;
  const rec = { mod, kind: body.kind, id: body.id, ts: Date.now() };
  await env.MOD_KV.put(key, JSON.stringify(rec), { expirationTtl: 600 }); // 10-min TTL
  // Also list current viewers for return (exclude self).
  const listKey = `presence:viewing:index:${body.kind}:${body.id}`;
  // Read a small index, append mod, re-write (best-effort; KV is eventually consistent).
  return jsonResponse({ ok: true, data: { viewer: rec } });
}

async function handlePresenceViewingGet(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const url = new URL(request.url);
  const kind = url.searchParams.get('kind');
  const id   = url.searchParams.get('id');
  if (!kind || !id) return jsonResponse({ok:false, error:'kind+id required'}, 400);
  const rec = await env.MOD_KV.get(`presence:viewing:${kind}:${id}`, 'json');
  return jsonResponse({ ok:true, data: rec });
}
```

Router cases:
```js
case '/presence/viewing':     return request.method === 'GET' ? await handlePresenceViewingGet(request, env) : await handlePresenceViewing(request, env);
```

**Success condition:** `curl -X POST /presence/viewing -d '{"kind":"User","id":"testuser"}'` with mod token returns `{ok:true,data:{viewer:{mod:<you>,ts:<ms>}}}`. Follow-up `curl /presence/viewing?kind=User&id=testuser` returns the same record until 600 s elapse. No token -> 401.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 3 -- worker `/drafts/*` endpoints

File: `gaw-mod-proxy-v2.js`.

```js
async function handleDraftWrite(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  for (const k of ['action','target','body']) if (typeof body[k] !== 'string') return jsonResponse({ok:false, error:`missing ${k}`}, 400);
  if (body.body.length > 8000) return jsonResponse({ok:false, error:'body too long'}, 413);
  const mod = getModUsernameFromToken(request, env);
  const now = Date.now();
  await env.AUDIT_DB.prepare(
    `INSERT INTO drafts (action, target, body, last_editor, status, created_at, last_edit_at)
     VALUES (?, ?, ?, ?, 'open', ?, ?)
     ON CONFLICT(action, target) DO UPDATE SET
       body=excluded.body, last_editor=excluded.last_editor, last_edit_at=excluded.last_edit_at, status='open'`
  ).bind(body.action, body.target, body.body, mod, now, now).run();
  return jsonResponse({ ok:true });
}

async function handleDraftRead(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const url = new URL(request.url);
  const action = url.searchParams.get('action');
  const target = url.searchParams.get('target');
  if (!action || !target) return jsonResponse({ok:false, error:'action+target required'}, 400);
  const rs = await env.AUDIT_DB.prepare(
    `SELECT action, target, body, last_editor, status, handoff_note, last_edit_at
     FROM drafts WHERE action=? AND target=? AND last_edit_at > ?`
  ).bind(action, target, Date.now() - 86400000).first();
  return jsonResponse({ ok:true, data: rs || null });
}

async function handleDraftList(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const url = new URL(request.url);
  const mine = url.searchParams.get('mine') === '1';
  const mod = getModUsernameFromToken(request, env);
  const cutoff = Date.now() - 86400000;
  const rs = mine
    ? await env.AUDIT_DB.prepare(`SELECT action,target,last_editor,status,last_edit_at FROM drafts WHERE last_editor=? AND last_edit_at>? ORDER BY last_edit_at DESC LIMIT 50`).bind(mod, cutoff).all()
    : await env.AUDIT_DB.prepare(`SELECT action,target,last_editor,status,last_edit_at FROM drafts WHERE last_edit_at>? ORDER BY last_edit_at DESC LIMIT 50`).bind(cutoff).all();
  return jsonResponse({ ok:true, data: rs.results || [] });
}

async function handleDraftHandoff(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  if (!body.action || !body.target) return jsonResponse({ok:false, error:'action+target required'}, 400);
  await env.AUDIT_DB.prepare(
    `UPDATE drafts SET status='handed_off', handoff_note=?, last_edit_at=? WHERE action=? AND target=?`
  ).bind(body.handoff_note || null, Date.now(), body.action, body.target).run();
  return jsonResponse({ ok:true });
}

async function handleDraftDelete(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  if (!body.action || !body.target) return jsonResponse({ok:false, error:'action+target required'}, 400);
  await env.AUDIT_DB.prepare(`DELETE FROM drafts WHERE action=? AND target=?`).bind(body.action, body.target).run();
  return jsonResponse({ ok:true });
}
```

Router cases:
```js
case '/drafts/write':    return await handleDraftWrite(request, env);
case '/drafts/read':     return await handleDraftRead(request, env);
case '/drafts/list':     return await handleDraftList(request, env);
case '/drafts/handoff':  return await handleDraftHandoff(request, env);
case '/drafts/delete':   return await handleDraftDelete(request, env);
```

**Success condition:** `curl POST /drafts/write {action:'ban', target:'u1', body:'hi'}` returns ok; follow-up `GET /drafts/read?action=ban&target=u1` returns the same body; `GET /drafts/list?mine=1` includes the entry. Second mod posts different body -> `last_editor` reflects that mod. `DELETE /drafts/delete` removes the row. 9000-char body returns 413.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 4 -- worker `/proposals/*` endpoints

File: `gaw-mod-proxy-v2.js`.

```js
async function handleProposalCreate(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  if (!['ban','remove_post','lock_thread'].includes(body.kind)) return jsonResponse({ok:false, error:'bad kind'}, 400);
  if (!body.target) return jsonResponse({ok:false, error:'target required'}, 400);
  const mod = getModUsernameFromToken(request, env);
  const now = Date.now();
  const res = await env.AUDIT_DB.prepare(
    `INSERT INTO proposals (kind, target, duration, reason, proposer, proposer_note, ai_note, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(body.kind, body.target, body.duration || null, body.reason || null, mod, body.proposer_note || null, body.ai_note || null, now).run();
  return jsonResponse({ ok:true, data: { id: res.meta.last_row_id } });
}

async function handleProposalVote(request, env) {
  const body = await request.json();
  const action = body.action; // Execute | Veto | Punt
  if (!['Execute','Veto','Punt'].includes(action)) return jsonResponse({ok:false, error:'bad action'}, 400);
  if (action === 'Veto') {
    const lead = checkLeadToken(request, env); if (lead) return lead;  // lead-only
  } else {
    const auth = checkModToken(request, env); if (auth) return auth;
  }
  if (!body.id) return jsonResponse({ok:false, error:'id required'}, 400);
  const mod = getModUsernameFromToken(request, env);
  const nextStatus = action === 'Execute' ? 'executed' : action === 'Veto' ? 'vetoed' : 'punted';
  await env.AUDIT_DB.prepare(
    `UPDATE proposals SET status=?, executor=?, executed_at=? WHERE id=? AND status='pending'`
  ).bind(nextStatus, mod, Date.now(), body.id).run();
  return jsonResponse({ ok:true });
}

async function handleProposalList(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const url = new URL(request.url);
  const since = parseInt(url.searchParams.get('since') || '0', 10);
  const rs = await env.AUDIT_DB.prepare(
    `SELECT id, kind, target, duration, reason, proposer, proposer_note, ai_note, status, executor, executed_at, created_at
     FROM proposals WHERE created_at > ? AND status='pending' ORDER BY created_at DESC LIMIT 50`
  ).bind(since).all();
  return jsonResponse({ ok:true, data: rs.results || [] });
}

async function handleProposalCancel(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  const mod = getModUsernameFromToken(request, env);
  await env.AUDIT_DB.prepare(
    `UPDATE proposals SET status='expired' WHERE id=? AND proposer=? AND status='pending'`
  ).bind(body.id, mod).run();
  return jsonResponse({ ok:true });
}
```

Router cases:
```js
case '/proposals/create': return await handleProposalCreate(request, env);
case '/proposals/vote':   return await handleProposalVote(request, env);
case '/proposals/list':   return await handleProposalList(request, env);
case '/proposals/cancel': return await handleProposalCancel(request, env);
```

Proposal creation also fires a Discord lead-channel post inside the handler (best-effort, non-blocking):
```js
if (env.DISCORD_WEBHOOK) {
  ctx.waitUntil(fetch(env.DISCORD_WEBHOOK, {
    method:'POST', headers:{'content-type':'application/json'},
    body: JSON.stringify({ content: `[PROPOSE ${body.kind.toUpperCase()}] \`${body.target}\` by **${mod}** -- reason: ${body.reason || '(none)'}` })
  }));
}
```

**Success condition:** `curl POST /proposals/create {kind:'ban', target:'u1', reason:'x'}` returns `{ok:true,data:{id:N}}`. `curl POST /proposals/vote {id:N, action:'Veto'}` with MOD token returns 401; with LEAD token returns ok and row status becomes `vetoed`. Execute and Punt both work with mod token. List returns only `status='pending'` rows.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 5 -- worker `/claims/*` endpoints

File: `gaw-mod-proxy-v2.js`.

```js
async function handleClaimWrite(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  if (!body.thread_id) return jsonResponse({ok:false, error:'thread_id required'}, 400);
  const mod = getModUsernameFromToken(request, env);
  const now = Date.now();
  const expires = now + 600000; // 10 min
  await env.AUDIT_DB.prepare(
    `INSERT INTO claims (thread_id, mod, claimed_at, expires_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(thread_id) DO UPDATE SET
       mod=excluded.mod, claimed_at=excluded.claimed_at, expires_at=excluded.expires_at`
  ).bind(body.thread_id, mod, now, expires).run();
  return jsonResponse({ ok:true, data: { expires_at: expires } });
}

async function handleClaimRelease(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const body = await request.json();
  const mod = getModUsernameFromToken(request, env);
  await env.AUDIT_DB.prepare(`DELETE FROM claims WHERE thread_id=? AND mod=?`).bind(body.thread_id, mod).run();
  return jsonResponse({ ok:true });
}

async function handleClaimList(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  const rs = await env.AUDIT_DB.prepare(
    `SELECT thread_id, mod, claimed_at, expires_at FROM claims WHERE expires_at > ? ORDER BY claimed_at DESC LIMIT 100`
  ).bind(Date.now()).all();
  return jsonResponse({ ok:true, data: rs.results || [] });
}
```

Router cases:
```js
case '/claims/write':   return await handleClaimWrite(request, env);
case '/claims/release': return await handleClaimRelease(request, env);
case '/claims/list':    return await handleClaimList(request, env);
```

**Success condition:** Posting a claim returns `expires_at` = now+600000. Listing returns only non-expired. Posting by another mod overwrites the row (UPSERT). Releasing with wrong mod is a no-op.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 6 -- cron extension for 1h auto-escalate + 4h proposal expiry + draft purge

File: `gaw-mod-proxy-v2.js`. The existing `scheduled` handler runs every 5 minutes (`*/5 * * * *`). Extend it -- do NOT add a second schedule.

```js
async function superModCronTick(env, ctx) {
  const now = Date.now();
  // 1. Auto-escalate: proposals pending > 1h, not yet alerted -> Discord once.
  if (env.DISCORD_WEBHOOK) {
    const stale = await env.AUDIT_DB.prepare(
      `SELECT id, kind, target, proposer, created_at FROM proposals
       WHERE status='pending' AND alerted_at IS NULL AND created_at < ? LIMIT 20`
    ).bind(now - 3600000).all();
    for (const row of (stale.results || [])) {
      ctx.waitUntil(fetch(env.DISCORD_WEBHOOK, {
        method:'POST', headers:{'content-type':'application/json'},
        body: JSON.stringify({ content: `[LEAD ESCALATION] Proposal #${row.id} \`${row.kind}\` on \`${row.target}\` by **${row.proposer}** has been pending >1h.` })
      }));
      await env.AUDIT_DB.prepare(`UPDATE proposals SET alerted_at=? WHERE id=?`).bind(now, row.id).run();
    }
  }
  // 2. Expire proposals pending > 4h.
  await env.AUDIT_DB.prepare(
    `UPDATE proposals SET status='expired' WHERE status='pending' AND created_at < ?`
  ).bind(now - 4 * 3600000).run();
  // 3. Purge drafts whose last_edit_at > 24h ago.
  await env.AUDIT_DB.prepare(`DELETE FROM drafts WHERE last_edit_at < ?`).bind(now - 86400000).run();
  // 4. Purge claims whose expires_at passed > 1h ago (tombstone cleanup).
  await env.AUDIT_DB.prepare(`DELETE FROM claims WHERE expires_at < ?`).bind(now - 3600000).run();
}
```

Add call inside existing `scheduled` handler:
```js
export default {
  // ...existing...
  async scheduled(event, env, ctx) {
    // ...existing ticks...
    ctx.waitUntil(superModCronTick(env, ctx));
  }
};
```

**Success condition:** Manually insert a proposal with `created_at = Date.now() - 3700000`. Next cron tick within 5 minutes sends exactly one Discord message (verify by checking `alerted_at IS NOT NULL`). Drafts older than 24 h are gone from the table.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 7 -- extension `features.superMod` flag + global 15-second poller

File: `modtools.js`. Locate `DEFAULT_SETTINGS` (grep for the exact symbol). Add:
```js
features: {
  ...existing,
  superMod: false,          // v7.1 master flag; default OFF
  audibleAlerts: true       // v7.1 chime toggle
}
```

Add a global poller near the end of the bootstrap IIFE:
```js
const TTL = { CLAIM_MS:600000, VIEWING_MS:600000, DRAFT_MS:86400000, PROPOSAL_MS:4*3600000, ESCALATE_MS:3600000 };
let _smLastPollTs = 0;
let _smPoller = null;
function superModPollerStart() {
  if (!getSetting('features.superMod', false)) return;
  if (_smPoller) return;
  _smPoller = setInterval(async () => {
    if (document.visibilityState === 'hidden') return;   // skip when tab hidden
    const since = _smLastPollTs; _smLastPollTs = Date.now();
    try {
      const [props, online, myDrafts] = await Promise.all([
        workerCall('/proposals/list?since=' + since, null, false),
        workerCall('/presence/online', null, false),
        workerCall('/drafts/list?mine=1', null, false)
      ]);
      if (props && props.ok) superModHandleProposals(props.data || []);
      if (online && online.ok) superModRenderOnlineChip(online.data || []);
      if (myDrafts && myDrafts.ok) superModNoteMyDrafts(myDrafts.data || []);
    } catch (err) { /* swallow -- retried next tick */ }
  }, 15000);
}
function superModPollerStop() { if (_smPoller) { clearInterval(_smPoller); _smPoller = null; } }
```

Wire start/stop to the settings toggle; start on boot if flag is on.

**Success condition:** With `features.superMod=true`, `setInterval` reference exists and fires every 15s; network panel shows 3 parallel requests per tick. With flag off, no poller runs. Grep proves exactly one `setInterval` in superMod paths.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 8 -- extension audible-chime Web Audio helper

File: `modtools.js`. Add near `snack`:
```js
let _smAudio = null;
function superModChime() {
  if (!getSetting('features.audibleAlerts', true)) return;
  if (document.visibilityState === 'hidden') return;
  try {
    _smAudio = _smAudio || new (window.AudioContext || window.webkitAudioContext)();
    const ctx = _smAudio;
    [261.63, 329.63, 392.00].forEach((freq, i) => {
      const o = ctx.createOscillator(); const g = ctx.createGain();
      o.frequency.value = freq; o.type = 'sine';
      g.gain.value = 0.06;
      o.connect(g); g.connect(ctx.destination);
      o.start(ctx.currentTime + i * 0.2); o.stop(ctx.currentTime + i * 0.2 + 0.18);
    });
  } catch (e) { /* autoplay blocked -- silently skip */ }
}
```

Use from `superModHandleProposals` when a new proposal appears (diff the seen-set in L1 Map).

**Success condition:** Calling `superModChime()` from devtools produces a rising three-tone chime. With `features.audibleAlerts=false`, no sound. With document hidden, no sound (even if flag true).
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 9 -- Esc saves draft to localStorage (Feature 1)

File: `modtools.js`. Locate the reply textarea mount sites (`#mc-ban-msg`, `#mc-note-body`, `#mc-msg-body`).

Add an `attachDraftPersistence(textareaEl, action, target)` helper, called immediately after each textarea is mounted:
```js
function attachDraftPersistence(ta, action, target) {
  if (!getSetting('features.superMod', false)) return;
  const key = `gam_draft_${action}_${target}`;
  // Rehydrate on mount (chunk 10 below uses the same storage).
  try {
    const raw = localStorage.getItem(key);
    if (raw) {
      const rec = JSON.parse(raw);
      if (rec && (Date.now() - (rec.ts || 0) < 7 * 86400000)) ta.value = rec.body || '';
      else localStorage.removeItem(key);
    }
  } catch {}
  // Save on Esc.
  ta.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    const body = ta.value || '';
    if (body.trim()) {
      try { localStorage.setItem(key, JSON.stringify({ body, ts: Date.now() })); } catch {}
      snack('draft saved (Esc)', 'info', 1500);
    }
  });
  // Also hook into existing send-success paths to clear the draft:
  ta.dataset.gamDraftKey = key;
}
function clearDraftFor(action, target) {
  try { localStorage.removeItem(`gam_draft_${action}_${target}`); } catch {}
}
```

Call `clearDraftFor(action, target)` from each send handler's success path (grep for existing `sendBanMessage`, `sendModmailReply`, `saveUserNote` or equivalents; add one line each).

**Success condition:** Type into `#mc-ban-msg`, press Esc -> modal closes, `localStorage.gam_draft_ban_<user>` contains `{body,ts}`. Open the same ban modal again -> textarea pre-populated. Send -> localStorage entry removed. An entry older than 7 d is silently purged on next rehydrate.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 10 -- draft rehydrate on tab close / reload (Feature 2)

File: `modtools.js`. This is free once CHUNK 9 is in place -- localStorage persists across tab close. Add one acceptance: on `window.addEventListener('beforeunload', ...)`, iterate every currently-mounted textarea with `dataset.gamDraftKey` and write its value to localStorage even without Esc. This catches accidental reloads.

```js
window.addEventListener('beforeunload', () => {
  document.querySelectorAll('textarea[data-gam-draft-key]').forEach(ta => {
    const key = ta.dataset.gamDraftKey;
    const body = ta.value || '';
    if (body.trim()) {
      try { localStorage.setItem(key, JSON.stringify({ body, ts: Date.now() })); } catch {}
    }
  });
});
```

**Success condition:** Type into `#mc-note-body`, Ctrl+R the page -> reopen the same note -> textarea re-populates. No Esc press required.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 11 -- cross-mod draft sync (Feature 3)

File: `modtools.js`. Extend `attachDraftPersistence` to also:
* On mount, `workerCall('/drafts/read?action=..&target=..')`. If a recent entry exists with `last_editor !== me` and `Date.now() - last_edit_at < 86400000`, render banner above the textarea: `Mod X was drafting Nm ago -- [Take over]` (built with `el()`). Clicking Take over calls `workerCall('/drafts/write', {action,target,body:<current textarea value>}, true)` and removes the banner.
* Add a 2-second debounced `input` listener that PUTs `/drafts/write` with the current body.

Debounce helper:
```js
function debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; }
const _draftPut = debounce((action, target, body) => {
  workerCall('/drafts/write', { action, target, body }, false);
}, 2000);
```

In `attachDraftPersistence`:
```js
ta.addEventListener('input', () => { if (getSetting('features.superMod', false)) _draftPut(action, target, ta.value); });
```

Banner builder (XSS-safe):
```js
function renderCrossModBanner(ta, rec) {
  const banner = el('div', { cls: 'gam-crossmod-banner' },
    el('span', {}, 'Mod '),
    el('strong', {}, String(rec.last_editor || '')),
    el('span', {}, ` was drafting ${Math.max(1, Math.round((Date.now()-rec.last_edit_at)/60000))}m ago `),
    el('button', { cls: 'gam-crossmod-takeover' }, 'Take over')
  );
  banner.querySelector('.gam-crossmod-takeover').addEventListener('click', () => {
    workerCall('/drafts/write', { action: ta.dataset.gamAction, target: ta.dataset.gamTarget, body: ta.value || rec.body || '' }, false)
      .then(() => { banner.remove(); snack('draft taken over', 'success'); });
  });
  ta.parentNode.insertBefore(banner, ta);
}
```

**Success condition:** Mod A edits a note draft; 2 s later D1 has the row (verify via `/drafts/read`). Mod B opens the same note; banner appears naming Mod A with minute count. Click Take over -> banner removes, `last_editor` updates to Mod B. All rendered text is `textContent`, not `innerHTML`; grep proves no `innerHTML` on fetched `last_editor`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 12 -- Hand off to team button (Feature 4)

File: `modtools.js`. Add a `[Hand off to team]` button inside the existing Mod Console textarea action row for ban/note/msg tabs. Clicking opens a one-line prompt via an inline input (NOT a browser `prompt()` -- use an `el()`-built inline form). Submit calls `workerCall('/drafts/handoff', {action, target, handoff_note})` then clears the textarea and snacks `handed off`.

**Success condition:** Clicking Hand off writes `status='handed_off'` and `handoff_note` to D1. `/drafts/list` reflects the new status. Other mods see the handoff banner (same rendering path as CHUNK 11).
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 13 -- Propose Ban button + modal (Feature 5)

File: `modtools.js`. Find the normal Ban button render (grep for the function that emits it inside the Mod Console). Add a sibling button `[Propose Ban]` visible only when `features.superMod=true`.

Modal fields (built with `el()`): target (pre-filled, read-only), duration (select: 24h/168h/336h/720h/perm), reason (textarea), proposer_note (textarea, optional, <=500 chars).

Submit:
1. `workerCall('/proposals/create', {kind:'ban', target, duration, reason, proposer_note}, true)` (mod token).
2. On success id, fire in parallel:
   * `workerCall('/ai/next-best-action', {kind:'ProposedBan', id:target, context:{target,duration,reason,proposer_note}, extra:{wrap:'<untrusted_user_content>'}}, false)` -- cache response `ai_note` (trim to 120 chars) in L1 Map keyed `proposal:<id>`; subsequent PATCH to store on the row can be deferred; the client only needs it for the status bar render.
3. Dismiss the modal; snack `Proposal #N filed; waiting on second mod.`.

The AI call must wrap all free-text (`reason`, `proposer_note`) in `<untrusted_user_content>` on the worker side -- that's the existing `handleAiNextBestAction` behavior for the `context` field. Ensure the action whitelist for `kind='ProposedBan'` in `handleAiNextBestAction` accepts the returned `action` from a small enum: `{APPROVE_PROPOSAL, VETO_PROPOSAL, ASK_MORE_INFO, DO_NOTHING}`. Extending `VALID` inside `handleAiNextBestAction` is a one-line worker edit (add the enum key); verify check 5 below confirms it.

**Success condition:** Clicking Propose Ban opens the modal; submit creates a proposal row; AI note is generated within 5 s (or `DO_NOTHING` if budget out); status bar shows the alert for every other online mod on their next 15 s tick.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 14 -- Propose Remove Post / Propose Lock Thread (Feature 6)

File: `modtools.js`. Same pattern as CHUNK 13. Add `[Propose Remove]` next to the existing Remove button in the post-row Mod Console; add `[Propose Lock]` next to the existing Lock button in the thread header augmentation.

Re-use the submit helper from CHUNK 13 with `kind` parameterized. Modal fields for `remove_post`: target (post id), reason, proposer_note. For `lock_thread`: target (thread id), reason, proposer_note.

Also extend `handleAiNextBestAction.VALID` on the worker to accept `kind='ProposedRemove'` and `kind='ProposedLock'` with the same four-entry enum as ProposedBan.

**Success condition:** Both buttons appear when flag is on. Submitting Propose Remove creates a `kind='remove_post'` row; Propose Lock creates `kind='lock_thread'`. `/proposals/list` shows them.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 15 -- Proposal review UI in drawer header + chime (Feature 5/6 cont.)

File: `modtools.js`. `superModHandleProposals(list)`:
* Diff `list` against `L1.get('smSeenProposals')` -> find new ids -> for each, render a status-bar notification `[PROPOSE <KIND>] @target by @proposer -- [Review]` built via `el()`. Call `superModChime()` once per diff tick (not per new proposal).
* Clicking Review opens the matching drawer (User for ban, Post for remove_post, Thread for lock_thread) via `IntelDrawer.open({kind, id, extra:{proposal_id}})`.
* Drawer header renders a banner above section 1 when `extra.proposal_id` is present: `Proposal #N from @proposer: ai_note`. Three buttons: `[Execute]`, `[Punt]`, `[Veto (lead)]`. Veto button is rendered disabled for non-lead (client-side hint; worker enforces).
* Execute: confirms, then calls the matching existing action function (ban/remove/lock -- DO NOT duplicate action code). On success, calls `/proposals/vote {id, action:'Execute'}`. On action failure, leaves status `pending`.
* Punt/Veto: call `/proposals/vote` and close the drawer.

Update `L1.set('smSeenProposals', new Set(list.map(p => p.id)))` at the end of the handler.

**Success condition:** Mod A proposes ban on `u1`. Within 15 s, Mod B hears the chime, sees the status-bar alert, clicks Review -> User drawer for `u1` opens with the proposal banner and AI note. Click Execute -> ban fires via existing pipeline, proposal row status becomes `executed`. Subsequent polls no longer show it.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 16 -- "Who's online" chip in status bar (Feature 8)

File: `modtools.js`. In the status-bar render, add a chip: `👥 N mods online`. Populated from the poller's `/presence/online` response. Clicking the chip opens a tooltip (one `el()`-built panel) listing each mod's username + current_page (from presence heartbeat `page` field).

CSS:
```css
.gam-online-chip { cursor:pointer; user-select:none; }
.gam-online-tooltip { position:absolute; background:#1a202c; color:#e2e8f0; border:1px solid #2d3748; padding:8px 12px; border-radius:6px; box-shadow:0 4px 12px rgba(0,0,0,.5); z-index:2147483601; }
```

**Success condition:** With flag on and two browser profiles signed in as different mods, both chips show `2 mods online`. Clicking opens a tooltip listing both. The chip updates within 30 s of a mod closing their tab.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 17 -- "Mod X is reviewing Y" viewing banner (Feature 9)

File: `modtools.js`. Modify `IntelDrawer.open`:
* Immediately after the shell mounts, `workerCall('/presence/viewing', {kind, id}, false)` (PUT).
* Also `workerCall('/presence/viewing?kind=..&id=..', null, false)` (GET) -- if the returned record's `mod` is another mod AND `ts > Date.now() - 600000`, insert a banner at the top of the drawer body: `Mod X is reviewing this -- opened Nm ago`.
* On drawer close, best-effort `workerCall('/presence/viewing', {kind, id, release:true}, false)` (add a release path on the worker later; for v7.1 it's sufficient to let the KV TTL expire).

**Success condition:** Mod A opens a User drawer for `u1`. Mod B opens the same drawer within 10 min -> banner appears naming Mod A. After 10 min with no re-open by A, the banner no longer appears for a fresh opener.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 18 -- collision warning before Ban / Remove / Lock / Execute (Feature 10)

File: `modtools.js`. Wrap each destructive action entry point:
```js
async function withCollisionCheck(kind, id, proceedFn) {
  if (!getSetting('features.superMod', false)) return proceedFn();
  const rec = await workerCall(`/presence/viewing?kind=${encodeURIComponent(kind)}&id=${encodeURIComponent(id)}`, null, false);
  const me = getMyModUsername();
  if (rec && rec.ok && rec.data && rec.data.mod && rec.data.mod !== me && (Date.now() - rec.data.ts < 600000)) {
    if (!await confirmModal(`${rec.data.mod} is reviewing this right now. Continue?`, 'Yes, proceed', 'No, wait')) return;
  }
  return proceedFn();
}
```

Apply to: `openBanFlow`, `removePost`, `lockThread`, proposal `Execute` (from CHUNK 15). `confirmModal` is a small `el()`-built yes/no; no `window.confirm`.

**Success condition:** Mod A has the User drawer for `u1` open. Mod B tries to ban `u1` -> confirm modal fires naming Mod A. Answering No cancels; answering Yes proceeds with the existing ban flow.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 19 -- ghost claim on modmail thread open (Feature 11)

File: `modtools.js`. Hook the modmail thread open (grep for the existing thread-open path). When a thread opens with `features.superMod=true`:
* `workerCall('/claims/write', {thread_id}, false)` on open.
* Every user interaction inside the thread (send message, archive, etc.) re-calls `/claims/write` to extend the 10-min TTL.
* Global poller's `/claims/list` (add to the CHUNK 7 poller tick) is matched against the currently-viewed thread; if another mod holds the claim, render a badge near the thread header: `Mod X on this, auto-releases in Nm` (built via `el()`).

**Success condition:** Mod A opens thread T; D1 `claims` row appears with Mod A. Mod B opens T -> badge appears naming Mod A. After 10 min without A interacting, badge disappears on B's next poll tick.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 20 -- pre-drafted ban reply on drawer open (Feature 12)

File: `modtools.js`. In `IntelDrawer.open` User-kind adapter, when `features.superMod=true`, parallel-fire (do NOT block drawer render):
```js
const abortCtrl = IntelDrawer._currentAbort;
workerCall('/ai/next-best-action', {
  kind:'User', id:opts.id, context:{ username: opts.id, recentActions: auditSlice },
  extra:{ intent:'ban_draft' }
}, false, { signal: abortCtrl.signal })
  .then(r => { if (r && r.ok && r.data && r.data.reason) L1.set('banDraft:' + opts.id, r.data.reason); })
  .catch(() => {});
```

In the existing `openBanFlow` for that user, before mounting `#mc-ban-msg`, check `L1.get('banDraft:' + user)`. If present AND textarea is empty AND no localStorage draft exists, pre-fill the textarea with the cached draft.

Extend `handleAiNextBestAction` to honor `extra.intent === 'ban_draft'`: when present, switch the system prompt to return a short ban-reply draft instead of the normal action+reason+confidence shape. The `VALID[kind]` whitelist continues to apply to the `action` field; the textbody is returned in `reason` (the only free-text field already permitted by the schema).

**Success condition:** Opening a User drawer for `u1` starts the ban-draft prefetch. Within 5 s, `L1.get('banDraft:u1')` is populated. Clicking Ban -> the textarea is pre-filled with that draft. Closing the drawer before the prefetch completes aborts the call.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 21 -- `setup-super-mod.ps1`

File: `D:\AI\_PROJECTS\setup-super-mod.ps1`. BOM + ASCII only. Parse-check on both `powershell.exe` and `pwsh.exe`. 4-step mandatory ending (log buffer, clipboard, E-C-G beep, Read-Host).

Skeleton follows `setup-precedents.ps1`:
```powershell
[CmdletBinding()]
param([switch]$NoPause)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Host "Requires PS 5.1+. Found $($PSVersionTable.PSVersion)" -ForegroundColor Red; exit 1 }
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$log = @()
function Say { param($t,$c='Cyan') Write-Host $t -ForegroundColor $c; $script:log += $t }

$RepoRoot = $PSScriptRoot
$Mig      = Join-Path $RepoRoot 'cloudflare-worker\migrations\008_super_mod_foundation.sql'
if (-not (Test-Path $Mig)) { Say "Migration not found: $Mig" Red; exit 2 }

$DB = Read-Host 'Enter D1 database name (default: gaw-audit)'
if (-not $DB) { $DB = 'gaw-audit' }

Say "Applying migration 008 to remote D1 [$DB]..." Cyan
$start = Get-Date
try {
  & npx --yes wrangler@latest d1 execute $DB --remote --file=$Mig
  if ($LASTEXITCODE -ne 0) { throw "wrangler exited $LASTEXITCODE" }
  Say "Migration applied in $(($end = Get-Date) - $start)" Green
} catch {
  Say "FAILED: $($_.Exception.Message)" Red; exit 2
}

# Verify tables exist.
Say "Verifying tables..." Cyan
& npx --yes wrangler@latest d1 execute $DB --remote --command="SELECT name FROM sqlite_master WHERE type='table' AND name IN ('drafts','proposals','claims');"
if ($LASTEXITCODE -ne 0) { Say "Verify failed" Red; exit 2 }

# Mandatory 4-step ending.
$logPath = "D:\AI\_PROJECTS\logs\setup-super-mod-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null
$log -join "`n" | Set-Content -Path $logPath -Encoding UTF8
$log -join "`n" | Set-Clipboard
Say "[log copied to clipboard]  ($logPath)" DarkGray
[Console]::Beep(659, 160); Start-Sleep -Milliseconds 100
[Console]::Beep(523, 160); Start-Sleep -Milliseconds 100
[Console]::Beep(784, 800)
if (-not $NoPause) { Read-Host 'Press Enter to exit' | Out-Null }
exit 0
```

Post-write, prepend UTF-8 BOM, strip non-ASCII, run `[System.Management.Automation.Language.Parser]::ParseFile` until `PARSE OK`. NO PS 7-only syntax (no ternary, no `??`, no `?.`).

**Success condition:** `pwsh -File D:\AI\_PROJECTS\setup-super-mod.ps1` with default Enter applies migration 008 and verifies 3 tables created. Log copied to clipboard. ECG beep plays. `powershell.exe -File ...` also parses and runs clean.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 22 -- PRIVACY.md v7.1 section

File: `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md`. Append before the final "Changes" section:

```markdown
## v7.1 data categories

v7.1 introduces four new transient data classes, all stored in the existing audit D1 or Cloudflare KV:

- **Proposals.** When a moderator clicks Propose Ban / Propose Remove / Propose Lock, a structured record is written to D1 `proposals` (kind, target, duration, reason, proposer, proposer_note, ai_note). Retained 30 days; auto-expired 4 hours after creation if no second mod acts. AI advisory notes use the existing `/ai/next-best-action` KV-budgeted path -- no new model traffic.

- **Drafts.** Textarea contents are synced to D1 `drafts` with a 2-second debounce so a second moderator can pick up an unfinished reply. Retention: 24 hours from last edit. Deleted on successful send.

- **Presence (viewing).** When a moderator opens the Intel Drawer for any subject, a 10-minute TTL record lands in Cloudflare KV (`presence:viewing:<kind>:<id>`) naming the viewing mod. Used to warn a second mod before a destructive action. Never exposed outside the mod team.

- **Claims.** When a moderator opens a modmail thread, a 10-minute TTL record in D1 `claims` marks that thread as being handled. Other moderators see a "Mod X on this" badge so two people don't reply simultaneously. TTL refreshes on every interaction; expired claims are purged hourly.

None of the above contain user PII beyond what is already present in the moderator's normal working surface (usernames, post/thread ids, reason text the mod typed).
```

**Success condition:** `verify-v7-1.ps1` check `PRIVACY.md contains "v7.1 data categories"` passes. File renders as valid Markdown.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 23 -- `verify-v7-1.ps1` + version bump + CWS ZIP

File: `D:\AI\_PROJECTS\verify-v7-1.ps1`. BOM + ASCII, 4-step ending, parse-check on both engines.

Checks, each logs PASS/FAIL:
1. `manifest.json` version === `7.1.0`.
2. `modtools.js` contains `features: {` section with `superMod` AND `audibleAlerts` keys.
3. `modtools.js` contains `function superModPollerStart(`, `function superModChime(`, `function attachDraftPersistence(`.
4. `modtools.js` contains exactly one `setInterval` call at `15000` tied to `superModPoller` (grep count == 1 on the specific combo).
5. `modtools.js` contains each of the 12 feature anchors: `gam_draft_`, `clearDraftFor(`, `beforeunload`, `gam-crossmod-banner`, `gam-crossmod-takeover`, `Propose Ban`, `Propose Remove`, `Propose Lock`, `gam-online-chip`, `is reviewing this`, `withCollisionCheck`, `banDraft:`.
6. `gaw-mod-proxy-v2.js` contains route strings `/drafts/write`, `/drafts/read`, `/drafts/list`, `/drafts/handoff`, `/drafts/delete`, `/proposals/create`, `/proposals/vote`, `/proposals/list`, `/proposals/cancel`, `/claims/write`, `/claims/release`, `/claims/list`, `/presence/viewing`.
7. `gaw-mod-proxy-v2.js` contains `superModCronTick(` AND `alerted_at`.
8. `migrations/008_super_mod_foundation.sql` exists AND contains `CREATE TABLE IF NOT EXISTS drafts`, `CREATE TABLE IF NOT EXISTS proposals`, `CREATE TABLE IF NOT EXISTS claims`.
9. `gaw-dashboard\public\PRIVACY.md` contains substring `v7.1 data categories`.
10. Live `POST /proposals/create` with mod token + valid body returns `{ok:true, data:{id:<n>}}`.
11. Live `POST /proposals/vote {id:<n>, action:'Veto'}` with MOD token returns 401.
12. Live `POST /proposals/vote {id:<n>, action:'Veto'}` with LEAD token returns `{ok:true}`.
13. Live `PUT /drafts/write` + `GET /drafts/read` round-trip returns the same body.
14. Live `POST /claims/write {thread_id:'t1'}` returns `expires_at` ~600000 ms after now.
15. Live `GET /presence/viewing?kind=User&id=test` returns either `{ok:true,data:null}` or a valid record.
16. CWS ZIP build output < 210 KB compressed.
17. `gam_settings_v7` unchanged (no new settings key).

Build commands (Commander pastes these in order):
```
pwsh -File D:\AI\_PROJECTS\bump-version.ps1 -Version 7.1.0 -Notes "v7.1 Super-Mod Foundation: 12 primitives for draft persistence, consensus proposals, and real-time presence. All behind features.superMod (default off)."
pwsh -File D:\AI\_PROJECTS\setup-super-mod.ps1
cd D:\AI\_PROJECTS\cloudflare-worker
npx --yes wrangler@latest deploy
cd D:\AI\_PROJECTS
pwsh -File D:\AI\_PROJECTS\build-chrome-store-zip.ps1
pwsh -File D:\AI\_PROJECTS\verify-v7-1.ps1
```

**Success condition:** `verify-v7-1.ps1` exits 0 with all 17 checks PASS. CWS ZIP produced under 210 KB. Clipboard contains full log. ECG beep plays.
**If fails:** rewrite entire chunk from scratch.

---

## VERIFICATION PROTOCOL (Commander runs these in order)

Exactly the build-commands block above. All six steps must exit 0. The super-mod surface only activates after Commander flips `features.superMod` in the extension Settings panel for his own install.

---

## ROLLOUT PROTOCOL (Commander owns this)

1. Ship v7.1 via GitHub auto-update. Flag default OFF means every mod sees byte-identical v7.0.x behavior.
2. Commander enables `features.superMod` for himself only. Runs one full shift solo. Drafts persist across reloads, Esc-save works, but no second mod is receiving chimes yet (nobody else has the flag on), so he validates the local-only half first.
3. Commander enables the flag for one other mod. They coordinate on one Propose Ban end-to-end. Both mods verify the chime, the proposal list, the Execute flow.
4. After one clean shared shift, Commander tells each remaining mod in Discord to flip the flag. Rolling per-mod enablement.
5. After two weeks clean, v7.2 locks the flag ON by default and removes the fallback branches (a v8.0 task deletes them outright).
6. At any point, flag-off restores v7.0.x behavior instantly -- no re-install needed.

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

## OUT OF SCOPE (v7.2+, each its own GIGA)

- WebSocket push (replaces polling once team size > 6).
- Draft search across all mods' live drafts (`/drafts/list?q=`).
- Multi-mod simultaneous editing with conflict resolution (true collaborative textarea).
- Per-rule proposal templates (one-click `[Propose Ban for Rule 3]`).
- Proposal voting with >2 mods (majority rule instead of single-execute).
- Mobile / tablet presence surface.
- Historical precedent surfacing inside the proposal modal (pull from v7.0 precedents).
- Deletion of v7.0/v7.1 fallback branches (v8.0 task).
- Watchers / owners / incident-room team coordination (deferred from v7.0).
- Queue-based modmail (six explicit queues) (deferred from v7.0).
- My Desk on `/u/me` (start-of-shift cockpit) (deferred from v7.0).
- Global command palette (Ctrl+K) (deferred from v7.0).
