# GIGA-V7.3-THE-MEMORY

**Audience:** Claude Code session with blanket approval from Commander Cats.
**Target:** GAW ModTools v7.2.x -> v7.3.0.
**Hard prerequisite:** v7.1 (proposals/presence) AND v7.2 (corpus/embeddings/Vectorize index `gaw-modmail`) are both live, deployed, and stable in production for at least one clean shift. Deploy-verify (chunk 14) refuses to proceed if either piece of infra is missing.

---

## MISSION

Finish the decision-memory triad. v7.1 gave the team live consensus on active bans. v7.2 gave the team embedded corpus recall of past modmail. v7.3 closes the loop with (a) **two quieter proposal kinds** for the lower-heat decisions that still benefit from consensus — Propose Warning (silent, one-mod) and Propose Unban (two-mod, appeal-context-required); (b) **semantic precedent retrieval** on every Intel Drawer open so "what happened last time" returns fuzzy matches not just exact signatures; and (c) a **weekly Consensus Drift Report** that surfaces the rules the team disagrees on most, read-only to Discord. Everything rides on existing v7.1 proposals infra + v7.2 Vectorize embedding infra. No new auth flows. No new UI surface beyond what v7.1 already owns.

---

## DELIVERABLES

| Path | Purpose |
|---|---|
| `D:\AI\_PROJECTS\cloudflare-worker\migrations\010_memory.sql` | extend proposals `kind` check to include `warn`/`unban`; add `embedding_id` to `precedents` |
| `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js` | extend `/proposals/create` + `/proposals/vote` kind-dispatch; add `/precedent/semantic-find`; add precedent-backfill cron tick; add weekly drift-report cron tick |
| `D:\AI\_PROJECTS\cloudflare-worker\wrangler.jsonc` | add cron trigger `0 6 * * 0` (weekly drift report) |
| `D:\AI\_PROJECTS\modtools-ext\modtools.js` | `features.memory` flag, Propose Warning button (quiet), Propose Unban button (appeal_context required), Proposed Warnings lead-only view, drift-report status chip, drawer section 6 "Similar past cases" group |
| `D:\AI\_PROJECTS\modtools-ext\manifest.json` | version 7.3.0 |
| `D:\AI\_PROJECTS\gaw-mod-shared-flags\version.json` | 7.3.0 |
| `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md` | append v7.3 data category section |
| `D:\AI\_PROJECTS\setup-precedent-vectors.ps1` | creates Vectorize index `gaw-precedents` (dim=768, cosine) and kicks retroactive backfill (BOM+ASCII+4-step) |
| `D:\AI\_PROJECTS\verify-v7.3.ps1` | verification script incl. infra gate that refuses to proceed if v7.1/v7.2 infra missing (BOM+ASCII+4-step) |

---

## ACCEPTANCE CRITERIA (all must be checkable by `verify-v7.3.ps1`)

- [ ] Feature flag `features.memory` exists in `DEFAULT_SETTINGS`, default `false`. Gates semantic-find (#3) and drift-report chip (#4) only. Warn + Unban proposals ride on existing `features.superMod` (v7.1).
- [ ] Migration 010 applied: `precedents.embedding_id TEXT` column exists (nullable). Proposals `kind` check constraint accepts `warn` and `unban` in addition to existing v7.1 kinds.
- [ ] Vectorize index `gaw-precedents` exists (dim=768, cosine) per `wrangler vectorize list`.
- [ ] `POST /proposals/create {kind:'warn', target, rule_ref, reason}` with valid mod token returns `{ok:true}`. Response contains `quiet:true`. Worker does NOT dispatch a Discord webhook and does NOT emit the SSE event `proposal:alert` (suppressed). It DOES emit `proposal:created` to SSE for the lead-only Proposed Warnings view.
- [ ] `POST /proposals/create {kind:'unban', target, appeal_context:'', reason}` returns 400 with error `appeal_context required`. Same call with non-empty `appeal_context` returns `{ok:true}`.
- [ ] `POST /proposals/vote` for a `kind:'warn'` proposal: single APPROVE vote from any mod transitions status to `executed`; execute path calls the existing modmail-reply pipeline with a structured warning body; worker inserts an audit-log entry `type='warn-executed'`.
- [ ] `POST /proposals/vote` for a `kind:'unban'` proposal: requires TWO distinct mod APPROVE votes to execute (consensus). Single approve leaves status `open`. After second approve, worker calls the existing unban pipeline AND auto-creates a profile note: `"Unban granted after consensus: {reason}, executed by {mod}"` (both reason and executing mod are server-substituted, not client-trusted).
- [ ] `POST /precedent/semantic-find {kind, subject_text}` with `features.memory=true` on client AND XAI_API_KEY + VECTORIZE bindings present on worker returns top-5 similars above threshold `0.75`. Cosine scores returned with each result. Empty result shape is `{ok:true, data:{similars:[], exact:[]}}`.
- [ ] Daily cap on `/precedent/semantic-find`: KV counter `bot:memory:semfind:${todayUTC()}` increments on every hit; at 1000 the endpoint returns `{ok:true, data:{similars:[], exact:[], degraded:'daily-cap', fallback:'exact-signature-only'}}` and does NOT invoke Workers AI or Vectorize. Client falls back to v7.0 exact-signature `/precedent/find`.
- [ ] Client debounce: `IntelDrawer.open()` for the SAME `{kind,id}` within 500ms does NOT issue a second `/precedent/semantic-find` call. Grep confirms a `_lastSemFindAt` map keyed on `${kind}:${id}` with 500ms gate.
- [ ] Drawer section 6 renders manual/exact-signature precedents first under heading `Past cases (exact)`, then a second group `Similar past cases (AI)` with cosine-score badge per row. When `similars.length === 0 && !degraded`, the AI group is simply not rendered. When `degraded === 'daily-cap'`, a `<em class="gam-muted">AI retrieval paused — daily cap reached. Exact matches only.</em>` line renders in place of the AI group.
- [ ] Backfill cron: on each scheduled tick, up to 50 precedent rows with `embedding_id IS NULL` get embedded via Workers AI `@cf/baai/bge-base-en-v1.5`, inserted into Vectorize `gaw-precedents` with id = `precedent:${id}`, and their row updated with `embedding_id='precedent:${id}'`. Logs one line `[cron] precedent-backfill done=N` per tick.
- [ ] Weekly drift cron `0 6 * * 0` runs: scans proposals with `created_at >= now - 7d`, groups by `rule_ref`, computes `disagreement = (vetoed + punted) / total_voted`, flags `disagreement > thresholds.drift.weekly_threshold` (default 0.30, lead-settable). For each flagged rule picks 3 most-contested proposals and posts one Discord message. If no rules flagged, posts `"🧭 Consensus Drift Report — Week of {date}. No significant drift this week (N proposals reviewed)."` Never posts to modmail. Never writes a drift-report row to D1.
- [ ] Drift threshold `thresholds.drift.weekly_threshold` is editable only in lead-mod settings pane (renders disabled for non-lead mods). Worker re-validates lead token on write; non-lead writes are 401.
- [ ] Extension exposes a **Proposed Warnings** view accessible only when `isLeadMod()` returns true AND a drift-report status chip in the status bar that shows unread drift-report count (SSE pushed `drift:posted` event increments, click opens the Discord permalink). Non-lead mods see neither.
- [ ] XSS: precedent section 6 renderer and drift-report chip tooltip both build DOM via `el()` only. Grep in `modtools.js` finds zero `innerHTML = ` inside any function whose name matches `renderSemantic|renderDrift|renderProposedWarn|renderUnbanProposal`.
- [ ] Warning proposals are **quiet**: no `new Audio(...).play()` call, no `statusBarAlert(...)` call, no `chrome.notifications.create(...)` call is reachable on the code path where `proposal.kind === 'warn'`. Unit-test stub `_gamTestQuietWarn()` asserts all three are not invoked when a warn SSE event arrives.
- [ ] Ban, unban, remove, lock proposals DO continue to alert per v7.1 (audible + status bar). Grep confirms the quiet gate is `if (proposal.kind !== 'warn')` around the alert path, not a generic silence.
- [ ] `gaw-dashboard\public\PRIVACY.md` contains new `## v7.3 data categories` section covering warn/unban proposals, precedent embeddings (indefinite retention, with precedent row), and drift reports (Discord-only, not stored).
- [ ] `pwsh -File D:\AI\_PROJECTS\verify-v7.3.ps1` exits 0 with every check PASS. Exits `2` if v7.1 `proposals` table is missing OR v7.2 Vectorize index `gaw-modmail` has zero vectors.
- [ ] CWS ZIP builds under 215 KB compressed (v7.2 baseline ~200 KB per architect estimate; v7.3 adds ~10 KB gzip).

---

## BAKED-IN DESIGN DECISIONS (not up for re-litigation)

1. **Warn is quiet by design.** This is the one exception to v7.1's "every proposal pings the team" rule. Warnings are low-heat, high-volume moderation touches; audible chime on every one would train the team to ignore the chime on bans. Rationale: the team already coordinates warnings in Discord by messaging each other; the proposal surface is for the lead to batch-review in the Proposed Warnings view at their own pace. If this turns out wrong in production, v7.3.1 can un-silence with a one-line gate change.
2. **Unban requires two-mod consensus.** Reversing a ban is a bigger deal than issuing one. One mod can ban unilaterally through the normal flow; reversing that ban via the proposal surface requires a second mod to concur. This prevents a single mod with access from quietly undoing a ban another mod placed.
3. **Unban `appeal_context` is worker-hard-validated.** Client-side validation is advisory. The worker rejects `kind:'unban'` proposals with empty/whitespace `appeal_context` at 400. This forces the proposer to paste the user's actual appeal message (or a real reason) before the vote even starts, so the second mod is voting on concrete grounds, not a vibes-based "yeah sure unban them."
4. **Semantic retrieval is piggyback, not replacement.** v7.0's exact-signature `/precedent/find` stays. v7.3 adds `/precedent/semantic-find` that runs in parallel on drawer open. Section 6 renders both groups, exact first. If the daily cap trips or XAI_API_KEY is unset or Vectorize is down, semantic returns empty and the drawer still shows exact matches — same UX as v7.0.
5. **Cost-cap via KV counter.** Same pattern as v7.0's `bot:grok:budget:${todayUTC()}`. Estimated ~$0.002/drawer-open (1 embedding + 1 Vectorize query); 1000/day = ~$2/day hard ceiling. Over cap, endpoint returns degraded response, client shows a muted note, nothing errors.
6. **Debounce 500ms per `${kind}:${id}` on client.** Prevents a flurry of identical calls if a mod rapid-closes-and-reopens the drawer on the same subject. Per-subject, not global — opening a drawer on User A immediately after closing one on User B is not debounced.
7. **Vectorize index `gaw-precedents` is separate from v7.2's `gaw-modmail`.** Different content, different lifecycle (precedents are mod-authored; modmail is raw corpus), different retention (precedent embeddings live forever with their row; modmail embeddings follow corpus retention policy). Sharing the index would conflate them and make the cosine threshold meaningless.
8. **Backfill cron is opportunistic, not batch.** 50 rows/tick with existing cron cadence (~5 min). Historical precedent corpus is small (<5k rows in the worst case at current team velocity); finishes in hours, not days. No new scheduled trigger for backfill — piggybacks on the existing sniper/enrichment tick.
9. **Drift report is the one weekly-cron addition.** `0 6 * * 0` (Sunday 06:00 UTC ≈ Saturday late-evening US). Picked so the report lands in Discord when the team is about to start the new week's shifts, not mid-shift.
10. **Drift report is read-only.** No stored drift-report table. No auto-rule-adjustment. No "click here to apply the fix." Pure surfacing of disagreement, with proposal IDs + voting-mod names so the team can discuss in Discord. If the team wants action, they take it manually — v7.3 is a mirror, not a legislator.
11. **Drift threshold is lead-settable.** Default 0.30 (30% disagreement rate flags a rule). Stored at `thresholds.drift.weekly_threshold`, editable only via the lead-mod settings pane. Non-lead UI renders the input disabled with a tooltip.
12. **`features.memory` gates only the AI-inference parts.** Warn + Unban proposals ride on `features.superMod` (v7.1). This keeps the flag matrix small: if a mod has v7.1 on, they get warn/unban proposals automatically. `features.memory` is the kill-switch specifically for semantic-find + drift-chip (the parts that cost money / may feel surveillance-y to the team).

---

## CHUNK 1 — migration 010: proposals kind extension + precedent embedding_id

File: `D:\AI\_PROJECTS\cloudflare-worker\migrations\010_memory.sql`:

```sql
-- v7.3 memory layer:
--   (a) allow proposals.kind to include 'warn' and 'unban' (was: 'ban','remove','lock' in v7.1).
--   (b) add precedents.embedding_id for Vectorize cross-reference.

-- D1 (SQLite) does not support ALTER TABLE ... ADD CONSTRAINT. Rebuild via table-swap.
-- NOTE: we rely on v7.1's proposals schema existing. verify-v7.3 gates on this.

CREATE TABLE IF NOT EXISTS proposals_v73_tmp (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL CHECK (kind IN ('ban','remove','lock','warn','unban')),
  target TEXT NOT NULL,
  rule_ref TEXT,
  reason TEXT,
  appeal_context TEXT,                 -- required when kind='unban' (worker-validated)
  status TEXT NOT NULL DEFAULT 'open', -- open | executed | vetoed | punted | expired
  proposed_by TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  executed_at INTEGER,
  executed_by TEXT,
  vote_count_approve INTEGER NOT NULL DEFAULT 0,
  vote_count_veto    INTEGER NOT NULL DEFAULT 0,
  vote_count_punt    INTEGER NOT NULL DEFAULT 0
);

INSERT INTO proposals_v73_tmp
  (id, kind, target, rule_ref, reason, status, proposed_by, created_at, expires_at,
   executed_at, executed_by, vote_count_approve, vote_count_veto, vote_count_punt)
SELECT
  id, kind, target, rule_ref, reason, status, proposed_by, created_at, expires_at,
  executed_at, executed_by, vote_count_approve, vote_count_veto, vote_count_punt
FROM proposals;

DROP TABLE proposals;
ALTER TABLE proposals_v73_tmp RENAME TO proposals;

CREATE INDEX IF NOT EXISTS idx_proposals_status_created ON proposals(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_proposals_target        ON proposals(target);
CREATE INDEX IF NOT EXISTS idx_proposals_rule_ref      ON proposals(rule_ref);

-- Precedent embedding cross-reference.
ALTER TABLE precedents ADD COLUMN embedding_id TEXT;
CREATE INDEX IF NOT EXISTS idx_precedents_embedding_id ON precedents(embedding_id);
```

**Success condition:** `npx wrangler d1 execute gaw-audit --remote --file=migrations/010_memory.sql` completes without error. `SELECT sql FROM sqlite_master WHERE name='proposals'` returned row contains `'warn','unban'` inside the CHECK clause. `SELECT embedding_id FROM precedents LIMIT 1` succeeds (returns NULL for pre-existing rows).
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 2 — `setup-precedent-vectors.ps1` + wrangler cron

File: `D:\AI\_PROJECTS\setup-precedent-vectors.ps1`. BOM + ASCII only, 4-step ending (log-to-clipboard, ECG beep, Read-Host). No `<placeholder>` syntax — prompts via `Read-Host`.

Script flow:
1. Preflight: confirm `node` + `pwsh`/`powershell` version + `wrangler.jsonc` at `D:\AI\_PROJECTS\cloudflare-worker\wrangler.jsonc`.
2. `$Idx = 'gaw-precedents'`; `npx --yes wrangler@latest vectorize create $Idx --dimensions=768 --metric=cosine`.
3. Check idempotently — if `vectorize list` already shows the index, skip create, log `[SKIP] index already exists`.
4. Apply D1 migration 010 via `npx --yes wrangler@latest d1 execute gaw-audit --remote --file=migrations\010_memory.sql`.
5. Patch `wrangler.jsonc` in-memory (safe JSONC-aware parse — strip line comments, JSON.parse, round-trip) to add:
   - a new vectorize binding `PRECEDENTS_INDEX` pointing at `gaw-precedents` (alongside the existing v7.2 `MODMAIL_INDEX`).
   - a new cron trigger string `0 6 * * 0` (check for duplicate before appending).
6. `npx --yes wrangler@latest deploy` to ship the new binding + cron.
7. Kick backfill: `curl -X POST -H "x-lead-token: <prompt>" https://<worker>/cron/precedent-backfill-kick` (this is a dev-only endpoint added in chunk 7 that drains up to 200 rows on demand for the initial fill).
8. Structured final report: index created Y/N, vectors present N, cron triggers present N, D1 migration applied Y/N.
9. Mandatory 4-step ending per Commander's powershell.md.

Parse-check the file with `[System.Management.Automation.Language.Parser]::ParseFile`. Parse errors = regenerate from scratch.

**Success condition:** `pwsh -File D:\AI\_PROJECTS\setup-precedent-vectors.ps1` runs clean against live Cloudflare account. `wrangler vectorize list` shows BOTH `gaw-modmail` (from v7.2) and `gaw-precedents`. `wrangler.jsonc` contains cron string `"0 6 * * 0"`. Deploy succeeds. Log copied to clipboard, ECG beep plays.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 3 — worker `/proposals/create` extension for kind='warn' (QUIET)

File: `gaw-mod-proxy-v2.js`. Locate v7.1's `handleProposalsCreate`. Add kind-dispatch branches.

```js
// Inside handleProposalsCreate, AFTER basic auth + body parse:
const kind = String(body.kind || '').toLowerCase();
const VALID_KINDS = ['ban','remove','lock','warn','unban'];
if (!VALID_KINDS.includes(kind)) return jsonResponse({ok:false, error:'unknown kind'}, 400);

// Auto-expiry per kind (v7.1: ban=24h, remove=12h, lock=12h).
const EXPIRY_HOURS = { ban:24, remove:12, lock:12, warn:48, unban:8 };
const expires_at = Date.now() + EXPIRY_HOURS[kind] * 3600 * 1000;

// kind='unban' hard validation (see chunk 4). kind='warn' below.
if (kind === 'warn') {
  if (!body.target || !body.rule_ref) {
    return jsonResponse({ok:false, error:'warn requires target+rule_ref'}, 400);
  }
}

// ... insert into proposals table (existing v7.1 logic, now with expires_at per-kind) ...

// SSE fanout: v7.1 sent 'proposal:created' + 'proposal:alert'. v7.3 splits:
//   - 'proposal:created'  ALWAYS fires (feeds the Proposed Warnings view + main feed).
//   - 'proposal:alert'    only fires when kind !== 'warn' (THE quiet exception).
publishSse(env, 'proposal:created', proposalRow);
if (kind !== 'warn') {
  publishSse(env, 'proposal:alert', proposalRow);
}

// Discord webhook: v7.1 posts every proposal. v7.3 suppresses for warn.
if (kind !== 'warn' && env.DISCORD_PROPOSAL_WEBHOOK) {
  await postDiscordProposal(env, proposalRow);  // existing v7.1 fn
}

return jsonResponse({ ok:true, data: { ...proposalRow, quiet: (kind === 'warn') } });
```

**Success condition:** curl `POST /proposals/create {kind:'warn', target:'testuser', rule_ref:'R1', reason:'minor'}` returns `{ok:true, data:{..., quiet:true}}`. Worker logs show `publishSse proposal:created` fired once and `proposal:alert` NOT fired. Discord webhook NOT called (verifiable by the mock-webhook endpoint or by leaving DISCORD_PROPOSAL_WEBHOOK unset in staging).
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 4 — worker `/proposals/create` extension for kind='unban' (APPEAL_CONTEXT REQUIRED)

File: `gaw-mod-proxy-v2.js`. Same handler, additional branch.

```js
if (kind === 'unban') {
  if (!body.target) return jsonResponse({ok:false, error:'unban requires target'}, 400);
  const ctx = String(body.appeal_context || '').trim();
  if (!ctx) return jsonResponse({ok:false, error:'appeal_context required'}, 400);
  if (ctx.length < 10) return jsonResponse({ok:false, error:'appeal_context too short (min 10 chars)'}, 400);
  if (ctx.length > 4000) return jsonResponse({ok:false, error:'appeal_context too long (max 4000 chars)'}, 400);
  // Persist appeal_context in its dedicated column (added by migration 010).
  body.appeal_context = ctx;
}
```

Insert statement gains `appeal_context`:
```js
await env.AUDIT_DB.prepare(
  `INSERT INTO proposals (kind, target, rule_ref, reason, appeal_context, status, proposed_by, created_at, expires_at)
   VALUES (?, ?, ?, ?, ?, 'open', ?, ?, ?)`
).bind(kind, body.target, body.rule_ref || null, body.reason || null,
       body.appeal_context || null, mod, Date.now(), expires_at).run();
```

Consensus gate (two-mod requirement) lives in `/proposals/vote` — see chunk 5. Create endpoint just stores the row.

**Success condition:** curl `POST /proposals/create {kind:'unban', target:'u', appeal_context:''}` returns 400 `appeal_context required`. Same with `appeal_context:'short'` returns 400 `appeal_context too short`. Same with a 20-char context returns `{ok:true}` and the row persists in D1 with `appeal_context` populated.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 5 — worker `/proposals/vote` execute-dispatch for warn + unban

File: `gaw-mod-proxy-v2.js`. Locate v7.1's `handleProposalsVote`. Keep the vote-tally logic; extend the "should we execute?" gate per kind, and the execute dispatch.

```js
// After tallying votes, determine whether to execute.
const kind = proposal.kind;
let shouldExecute = false;
let reasonMark = '';

if (kind === 'warn') {
  // v7.3: single approve executes. (Warnings are low-heat; lead can veto via the Proposed Warnings view.)
  if (proposal.vote_count_approve >= 1 && proposal.vote_count_veto === 0) {
    shouldExecute = true; reasonMark = 'single-approve';
  }
} else if (kind === 'unban') {
  // v7.3: TWO distinct mods must approve. Distinctness enforced by v7.1's unique (proposal_id, mod) vote constraint.
  if (proposal.vote_count_approve >= 2 && proposal.vote_count_veto === 0) {
    shouldExecute = true; reasonMark = 'two-mod-consensus';
  }
} else {
  // ban/remove/lock — v7.1 rules unchanged.
  // (existing v7.1 logic preserved as-is)
}

if (shouldExecute) {
  await env.AUDIT_DB.prepare(
    `UPDATE proposals SET status='executed', executed_at=?, executed_by=? WHERE id=?`
  ).bind(Date.now(), mod, proposal.id).run();

  if (kind === 'warn') {
    // Reuse the existing modmail-reply pipeline. Structured body template.
    const warnBody = `Your account has received a warning from the mod team.\n\nRule: ${proposal.rule_ref}\nNotes: ${proposal.reason || '(none)'}\n\nThis is a one-time warning. Continued violations may result in removal or ban. Reply to this modmail if you have questions.`;
    await executeModmailReply(env, { target: proposal.target, body: warnBody, source: 'proposal-warn', proposal_id: proposal.id });
    await insertAudit(env, { type:'warn-executed', subject: proposal.target, actor: mod, extra: JSON.stringify({proposal_id: proposal.id, rule_ref: proposal.rule_ref}) });
  } else if (kind === 'unban') {
    // Reuse the existing unban pipeline.
    await executeUnban(env, { target: proposal.target, source: 'proposal-unban', proposal_id: proposal.id });
    // Server-substituted auto-note: reason + executing mod are worker-side, not client-trusted.
    const noteBody = `Unban granted after consensus: ${proposal.reason || proposal.appeal_context || '(no reason given)'}, executed by ${mod}`;
    await appendProfileNote(env, { username: proposal.target, author: 'system', body: noteBody });
    await insertAudit(env, { type:'unban-executed', subject: proposal.target, actor: mod, extra: JSON.stringify({proposal_id: proposal.id, reason_mark: reasonMark}) });
  }

  publishSse(env, 'proposal:executed', { id: proposal.id, kind, executed_by: mod });
}
```

**Success condition:** Integration test (verify script check): create a `kind:'warn'` proposal via curl, vote approve once — GET `/proposals/list` returns that proposal's status as `executed`. Create a `kind:'unban'` proposal, vote approve once — status still `open`. Vote approve a second time from a DIFFERENT mod token — status becomes `executed`. Target profile now has a system note containing `"Unban granted after consensus"` + the executing mod's username. Audit log contains `warn-executed` + `unban-executed` entries.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 6 — worker `/precedent/semantic-find` + cost-cap + fallback

File: `gaw-mod-proxy-v2.js`. New handler:

```js
async function handlePrecedentSemanticFind(request, env) {
  const auth = checkModToken(request, env); if (auth) return auth;
  if (!env.PRECEDENTS_INDEX) return jsonResponse({ ok:true, data:{ similars:[], exact:[], degraded:'no-index' } });
  if (!env.AI) return jsonResponse({ ok:true, data:{ similars:[], exact:[], degraded:'no-ai-binding' } });

  const body = await request.json();
  const kind = String(body.kind || '');
  const subjectText = String(body.subject_text || '').trim();
  if (!kind || !subjectText) return jsonResponse({ ok:false, error:'kind+subject_text required' }, 400);

  // Daily cap via KV (same pattern as v7.0 grok budget).
  const capKey = `bot:memory:semfind:${todayUTC()}`;
  const used = parseInt((await env.MOD_KV.get(capKey)) || '0', 10) || 0;
  const cap  = parseInt(env.MEMORY_SEMFIND_DAILY_CAP || '1000', 10);
  if (used >= cap) {
    return jsonResponse({ ok:true, data:{ similars:[], exact:[], degraded:'daily-cap', fallback:'exact-signature-only' } });
  }

  // Truncate subject text to keep embedding cost bounded (bge-base max 512 tokens ~ 2000 chars).
  const text = subjectText.slice(0, 2000);

  let embedding;
  try {
    const r = await env.AI.run('@cf/baai/bge-base-en-v1.5', { text: [text] });
    embedding = r.data && r.data[0];
    if (!embedding || embedding.length !== 768) throw new Error('bad embedding shape');
  } catch (e) {
    return jsonResponse({ ok:true, data:{ similars:[], exact:[], degraded:'embed-fail' } });
  }

  let matches;
  try {
    const q = await env.PRECEDENTS_INDEX.query(embedding, { topK: 5, returnMetadata: true });
    matches = (q.matches || []).filter(m => typeof m.score === 'number' && m.score >= 0.75);
  } catch (e) {
    return jsonResponse({ ok:true, data:{ similars:[], exact:[], degraded:'vectorize-fail' } });
  }

  // Hydrate full precedent rows for each match id.
  const ids = matches.map(m => (m.id || '').replace(/^precedent:/, '')).filter(Boolean);
  let rows = [];
  if (ids.length) {
    const placeholders = ids.map(() => '?').join(',');
    const rs = await env.AUDIT_DB.prepare(
      `SELECT id, kind, signature, title, rule_ref, action, reason, source_ref, authored_by, marked_at
       FROM precedents WHERE kind=? AND id IN (${placeholders})`
    ).bind(kind, ...ids).all();
    const byId = Object.fromEntries((rs.results || []).map(r => [String(r.id), r]));
    rows = matches
      .map(m => {
        const rawId = (m.id || '').replace(/^precedent:/, '');
        const row = byId[rawId];
        if (!row) return null;
        return { ...row, score: Number(m.score.toFixed(3)) };
      })
      .filter(Boolean);
  }

  // Increment KV counter for cost tracking (~1 embedding + 1 vectorize query).
  await env.MOD_KV.put(capKey, String(used + 1), { expirationTtl: 90000 });

  return jsonResponse({ ok:true, data: { similars: rows, exact: [], score_threshold: 0.75 } });
}
```

Router case:
```js
case '/precedent/semantic-find': return await handlePrecedentSemanticFind(request, env);
```

**Success condition:** curl `POST /precedent/semantic-find {kind:'User', subject_text:'multiple alt accounts evading ban'}` with a populated index returns `{ok:true, data:{similars:[{..., score:0.8x}, ...], score_threshold:0.75}}` with 0-5 rows. Setting KV counter to 1000 returns `degraded:'daily-cap'`. Unsetting XAI/AI binding returns `degraded:'no-ai-binding'`. Bad subject_text = empty returns 400.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 7 — precedent backfill cron tick + dev-only kick endpoint

File: `gaw-mod-proxy-v2.js`. Add `precedentBackfillTick(env)` and wire into the existing `scheduled(controller, env, ctx)` hook alongside the v7.2 modmail enrichment tick.

```js
async function precedentBackfillTick(env) {
  if (!env.PRECEDENTS_INDEX || !env.AI) return;
  const rs = await env.AUDIT_DB.prepare(
    `SELECT id, kind, signature, title, reason
     FROM precedents
     WHERE embedding_id IS NULL
     ORDER BY marked_at DESC
     LIMIT 50`
  ).all();
  const rows = rs.results || [];
  if (!rows.length) return;

  let done = 0;
  for (const row of rows) {
    try {
      const text = [row.title, row.reason].filter(Boolean).join(' — ').slice(0, 2000);
      if (!text) continue;
      const r = await env.AI.run('@cf/baai/bge-base-en-v1.5', { text: [text] });
      const emb = r.data && r.data[0];
      if (!emb || emb.length !== 768) continue;
      const vid = `precedent:${row.id}`;
      await env.PRECEDENTS_INDEX.upsert([{
        id: vid,
        values: emb,
        metadata: { kind: row.kind, signature: row.signature }
      }]);
      await env.AUDIT_DB.prepare(`UPDATE precedents SET embedding_id=? WHERE id=?`).bind(vid, row.id).run();
      done++;
    } catch (e) {
      console.error('[cron] precedent-backfill row', row.id, e);
    }
  }
  console.log(`[cron] precedent-backfill done=${done}`);
}

// Also add a mark-time hook so NEW precedents embed immediately instead of waiting
// for the next tick (minor latency win, same budget path).
async function embedPrecedentImmediate(env, row) {
  try { await precedentBackfillTick(env); /* drains including the new row */ }
  catch (e) { console.error('[precedent] embed-immediate', e); }
}
```

In `handlePrecedentMark` (from v7.0), fire-and-forget the immediate embed:
```js
ctx.waitUntil(embedPrecedentImmediate(env, { id: newId }));
```
(pass `ctx` through; if refactor too invasive, rely on next cron tick — not a blocker.)

Dev-only bulk-kick endpoint (lead-gated, for the initial fill):
```js
async function handlePrecedentBackfillKick(request, env) {
  const auth = checkLeadToken(request, env); if (auth) return auth;
  // Drain up to 4 batches (200 rows) in one call for initial fill.
  for (let i = 0; i < 4; i++) { await precedentBackfillTick(env); }
  return jsonResponse({ ok:true });
}
```
Route: `case '/cron/precedent-backfill-kick': return await handlePrecedentBackfillKick(request, env);`

Wire into scheduled():
```js
async scheduled(controller, env, ctx) {
  ctx.waitUntil(sniperTick(env).catch(e => console.error('[cron] sniperTick', e)));
  ctx.waitUntil(botCronTick(env).catch(e => console.error('[cron] botCronTick', e)));
  ctx.waitUntil(enrichmentDrainTick(env).catch(e => console.error('[cron] enrichmentDrainTick', e)));
  ctx.waitUntil(gawCrawlTick(env).catch(e => console.error('[cron] gawCrawlTick', e)));
  ctx.waitUntil(precedentBackfillTick(env).catch(e => console.error('[cron] precedent-backfill', e)));  // NEW
  // Weekly drift — only runs on the 0 6 * * 0 trigger; all crons share scheduled().
  // Gate on cron string match via controller.cron.
  if (controller.cron === '0 6 * * 0') {
    ctx.waitUntil(consensusDriftReportTick(env).catch(e => console.error('[cron] drift', e)));
  }
  console.log('[cron] tick at', new Date().toISOString(), 'pattern=', controller.cron);
}
```

**Success condition:** After running `/cron/precedent-backfill-kick` once against a freshly-migrated DB with N existing precedent rows, `SELECT COUNT(*) FROM precedents WHERE embedding_id IS NOT NULL` returns `MIN(N, 200)`. `wrangler vectorize list-vectors gaw-precedents` (or a semantic-find query) returns matches. Cron log shows `[cron] precedent-backfill done=<count>`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 8 — weekly consensus drift cron + Discord post

File: `gaw-mod-proxy-v2.js`. New `consensusDriftReportTick(env)`.

```js
async function consensusDriftReportTick(env) {
  if (!env.DISCORD_DRIFT_WEBHOOK && !env.DISCORD_PROPOSAL_WEBHOOK) return;  // no destination, silent no-op
  const webhook = env.DISCORD_DRIFT_WEBHOOK || env.DISCORD_PROPOSAL_WEBHOOK;

  const now = Date.now();
  const windowStart = now - 7 * 24 * 3600 * 1000;

  // Pull proposals touched in the window with any vote activity.
  const rs = await env.AUDIT_DB.prepare(
    `SELECT id, kind, target, rule_ref, status, vote_count_approve, vote_count_veto, vote_count_punt, created_at
     FROM proposals
     WHERE created_at >= ? AND (vote_count_approve + vote_count_veto + vote_count_punt) > 0`
  ).bind(windowStart).all();
  const proposals = rs.results || [];
  const reviewed = proposals.length;

  // Group by rule_ref. Ignore rows with null rule_ref (can't compute drift).
  const byRule = {};
  for (const p of proposals) {
    const rr = p.rule_ref || '__none__';
    if (rr === '__none__') continue;
    (byRule[rr] = byRule[rr] || []).push(p);
  }

  // Load threshold (lead-set) from KV; default 0.30.
  const thresh = parseFloat((await env.MOD_KV.get('thresholds:drift:weekly')) || '0.30');

  const flagged = [];
  for (const [rule, items] of Object.entries(byRule)) {
    let totalVoted = 0, vetoed = 0, punted = 0;
    for (const p of items) {
      const v = p.vote_count_approve + p.vote_count_veto + p.vote_count_punt;
      if (v > 0) totalVoted++;
      vetoed += (p.vote_count_veto > 0) ? 1 : 0;
      punted += (p.vote_count_punt > 0) ? 1 : 0;
    }
    if (totalVoted < 2) continue;  // insufficient sample
    const disagreement = (vetoed + punted) / totalVoted;
    if (disagreement > thresh) {
      // Pick 3 most-contested: sort by (veto+punt) desc.
      const top3 = items
        .map(p => ({ ...p, contest: p.vote_count_veto + p.vote_count_punt }))
        .sort((a,b) => b.contest - a.contest)
        .slice(0, 3);

      // Gather voter names for those 3 (proposal_votes table from v7.1).
      for (const p of top3) {
        const vrs = await env.AUDIT_DB.prepare(
          `SELECT mod, vote FROM proposal_votes WHERE proposal_id=?`
        ).bind(p.id).all();
        p.voters = (vrs.results || []).map(v => `${v.mod}:${v.vote}`).join(', ');
      }
      flagged.push({ rule, disagreement, total: totalVoted, top3 });
    }
  }

  const dateStr = new Date(now).toISOString().slice(0, 10);
  let body;
  if (!flagged.length) {
    body = `🧭 **Consensus Drift Report — Week of ${dateStr}**\nNo significant drift this week (${reviewed} proposals reviewed, threshold=${thresh}).`;
  } else {
    flagged.sort((a,b) => b.disagreement - a.disagreement);
    const top = flagged.slice(0, 5);  // cap the message length
    const lines = top.map(f => {
      const pct = Math.round(f.disagreement * 100);
      const ex = f.top3.map(p => `#${p.id} (${p.kind} ${p.target}) votes:[${p.voters || 'n/a'}]`).join(' | ');
      return `• **${f.rule}** — ${pct}% disagreement (${f.total} voted). Examples: ${ex}`;
    }).join('\n');
    body = `🧭 **Consensus Drift Report — Week of ${dateStr}**\nTeam disagreed on ${flagged.length} rule(s). Top:\n${lines}\n\n_Read-only surfacing. No stored report. Threshold=${thresh} (lead-settable)._`;
  }

  await fetch(webhook, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ content: body.slice(0, 1900) })  // Discord 2000-char cap safety
  });

  // Fan out an SSE event so the extension can bump the drift-report status chip.
  publishSse(env, 'drift:posted', { date: dateStr, flagged_count: flagged.length });
}
```

Lead-settable threshold endpoint:
```js
async function handleDriftThresholdSet(request, env) {
  const auth = checkLeadToken(request, env); if (auth) return auth;
  const body = await request.json();
  const v = parseFloat(body.value);
  if (!(v > 0 && v < 1)) return jsonResponse({ok:false, error:'value must be in (0,1)'}, 400);
  await env.MOD_KV.put('thresholds:drift:weekly', String(v));
  return jsonResponse({ ok:true, data: { value: v } });
}
```
Route: `case '/config/drift-threshold': return await handleDriftThresholdSet(request, env);`

**Success condition:** Manual cron invocation via `wrangler dev --test-scheduled` with a seeded test DB (5 proposals on rule R1 with 4 vetoes, 3 proposals on rule R2 with 0 vetoes) posts a Discord message naming R1 as the top-drift rule and not naming R2. With no flagged rules, posts the "No significant drift" line. POST `/config/drift-threshold {value:0.25}` with lead token persists; same call with mod token returns 401.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 9 — extension: Propose Warning button (QUIET UX)

File: `modtools.js`. Locate v7.1's "Propose Ban" button insertion site (grep `Propose Ban` or `proposals/create` call in the client). Add a sibling "Propose Warning" button on the same row.

```js
function renderProposeWarningBtn(target, rule_ref_default, hostEl) {
  if (!getSetting('features.superMod', false)) return;  // rides on v7.1 flag
  const btn = el('button', { cls: 'gam-propose-btn gam-propose-btn--warn', title: 'Propose Warning (quiet)' }, 'Warn');
  btn.addEventListener('click', async (e) => {
    e.stopPropagation();
    const rule_ref = await promptRuleRef(rule_ref_default);   // existing v7.1 helper
    if (!rule_ref) return;
    const reason = await promptShortReason();                 // existing v7.1 helper
    const r = await workerCall('/proposals/create', { kind:'warn', target, rule_ref, reason }, false);
    if (r && r.ok) {
      snack('Warning proposed (quiet)', 'info', 3000);        // subtle snack, no chime
    } else {
      snack('Propose warning failed: ' + (r && r.error), 'error');
    }
  });
  hostEl.appendChild(btn);
}
```

SSE handler for `proposal:created` must branch on kind. For `kind === 'warn'`:
- Do NOT call `statusBarAlert(...)`.
- Do NOT call `new Audio(...).play()`.
- Do NOT call `chrome.notifications.create(...)`.
- DO update the lead-only Proposed Warnings view's in-memory list (chunk 11).

```js
onSse('proposal:created', (ev) => {
  const p = ev.data || {};
  if (p.kind === 'warn') {
    // QUIET: lead-only view update, nothing else.
    if (isLeadMod()) updateProposedWarningsView(p);
    return;
  }
  // v7.1 non-quiet path unchanged for ban/remove/lock.
  statusBarAlert(`Proposal: ${p.kind} ${p.target}`, 'warn');
  playChime('proposal');
});
```

Inline unit stub (dev-only):
```js
function _gamTestQuietWarn() {
  const origAudio = window.Audio;
  const origAlert = window.statusBarAlert;
  let audioCalled = false, alertCalled = false;
  window.Audio = function() { audioCalled = true; return { play: () => {} }; };
  window.statusBarAlert = function() { alertCalled = true; };
  _dispatchSseFake('proposal:created', { kind:'warn', target:'testuser' });
  window.Audio = origAudio; window.statusBarAlert = origAlert;
  console.log('[v7.3] quiet-warn', audioCalled || alertCalled ? 'FAIL' : 'PASS');
}
if (localStorage.gam_dev === '1') _gamTestQuietWarn();
```

**Success condition:** With `features.superMod=true`, clicking the Warn button on a post row opens the rule+reason prompts and posts `/proposals/create {kind:'warn',...}`. A subtle snack appears. No chime plays. Status bar does NOT flash. Grep of `modtools.js` confirms the audio/notifications/statusBarAlert gate is `if (p.kind !== 'warn')` on the proposal:alert SSE path. `_gamTestQuietWarn` logs PASS.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 10 — extension: Propose Unban button + appeal_context modal

File: `modtools.js`. Add at the ban-related action sites (grep `openBanFlow` or the ban button click):

```js
function renderProposeUnbanBtn(target, hostEl) {
  if (!getSetting('features.superMod', false)) return;
  const btn = el('button', { cls: 'gam-propose-btn gam-propose-btn--unban', title: 'Propose Unban (requires 2-mod consensus)' }, 'Propose Unban');
  btn.addEventListener('click', async (e) => {
    e.stopPropagation();
    const appealModal = await openAppealContextModal(target);
    if (!appealModal.confirmed) return;
    if (!appealModal.context || appealModal.context.trim().length < 10) {
      snack('Appeal context too short (min 10 chars)', 'error');
      return;
    }
    const reason = await promptShortReason('Reason for unban (shown in auto-note)');
    const r = await workerCall('/proposals/create', {
      kind: 'unban',
      target,
      appeal_context: appealModal.context.trim(),
      reason
    }, false);
    if (r && r.ok) {
      snack('Unban proposed — needs one more mod to approve', 'info', 5000);
    } else {
      snack('Propose unban failed: ' + (r && r.error || 'unknown'), 'error');
    }
  });
  hostEl.appendChild(btn);
}

function openAppealContextModal(target) {
  // Builds a modal via el() only. Fields: <textarea> for appeal_context (required, min 10 chars),
  //   <button> Confirm / Cancel. Returns Promise resolving to {confirmed, context}.
  //   Textarea placeholder: "Paste the user's appeal message or a concrete reason for this unban. Required."
  //   Client-side disables Confirm while textarea.value.trim().length < 10.
  // See chunk 13 XSS contract — no innerHTML.
  // ... implementation via el() only ...
}
```

SSE handler branch for `proposal:created` where `kind === 'unban'`:
- DOES alert (unban is a real decision — lead and peer mods want to know).
- Renders in the Proposed Unbans portion of the normal proposals list (piggyback on v7.1's view), with an "Approve to execute (1 more needed)" badge if `vote_count_approve === 1`.

**Success condition:** With `features.superMod=true`, clicking "Propose Unban" on a banned user's profile opens the appeal-context modal. Submitting empty / <10 char context disables Confirm. Submitting a valid context posts `/proposals/create {kind:'unban', appeal_context:<text>, ...}` and worker returns `{ok:true}`. Another mod sees the proposal in their proposals feed with audible alert (not quiet). Second mod's approve triggers execution and the target user's profile gains the system note.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 11 — extension: Proposed Warnings view + drift-report status chip

File: `modtools.js`. Two UI additions, both lead-only.

### Proposed Warnings view

Under the existing v7.1 proposals panel, add a tab `Proposed Warnings` visible only when `isLeadMod() === true`. Renders a list of `kind:'warn'` proposals sorted by `created_at DESC`, each row with:
- target username (clickable → opens Intel Drawer for that user)
- rule_ref chip
- reason (escaped)
- proposed_by + relative timestamp
- Actions: `Execute now` (approves + executes if status still open) and `Veto` (sets status='vetoed').

Populate via v7.1's SSE stream plus an initial `workerCall('/proposals/list', {kind:'warn', status:'open', limit:50})`.

Built with `el()` only. No `innerHTML`. Function named `renderProposedWarningsView` so the verify-script grep finds it for the XSS check.

### Drift-report status chip

In the status bar (existing v7.1 surface), add a chip:
```js
function renderDriftReportChip() {
  if (!getSetting('features.memory', false)) return;
  if (!isLeadMod()) return;
  const unread = getChromeLocal('gam_drift_unread_count', 0);
  const chip = el('button', {
    cls: `gam-chip gam-chip--drift ${unread > 0 ? 'gam-chip--drift-unread' : ''}`,
    title: unread > 0 ? `${unread} unread drift report(s) — click to view` : 'Drift reports up to date'
  }, `Drift${unread > 0 ? ` (${unread})` : ''}`);
  chip.addEventListener('click', () => {
    setChromeLocal('gam_drift_unread_count', 0);
    refreshDriftChip();
    window.open(getSetting('discord.modChannelPermalink', '#'), '_blank');
  });
  statusBarHostEl.appendChild(chip);
}

onSse('drift:posted', (ev) => {
  const n = getChromeLocal('gam_drift_unread_count', 0) + 1;
  setChromeLocal('gam_drift_unread_count', n);
  refreshDriftChip();
});
```

Lead-only settings pane gains a numeric input for `thresholds.drift.weekly_threshold` (default 0.30, range 0.01-0.99). Disabled for non-lead mods. On change, calls `workerCall('/config/drift-threshold', {value})` with lead token.

**Success condition:** Lead mod sees the "Proposed Warnings" tab; non-lead mod does not (grep: the tab render is gated by `isLeadMod()`). Creating a warn proposal from another session pushes it into the lead's Proposed Warnings list without a chime. Drift chip appears only when `features.memory=true` AND lead. Triggering a fake `drift:posted` SSE event increments the unread count. Clicking the chip opens the configured Discord channel permalink and resets the count.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 12 — drawer section 6: "Similar past cases (AI)" group + debounce

File: `modtools.js`. Locate v7.0's drawer section-6 renderer (exact-signature precedent list). Extend per adapter.

Shared helpers:
```js
const _lastSemFindAt = new Map();   // key: `${kind}:${id}` -> ms epoch

async function semanticFindIfAllowed(kind, id, subjectText, signal) {
  if (!getSetting('features.memory', false)) return { similars: [], degraded: 'flag-off' };
  const key = `${kind}:${id}`;
  const last = _lastSemFindAt.get(key) || 0;
  if (Date.now() - last < 500) return { similars: [], degraded: 'debounce' };
  _lastSemFindAt.set(key, Date.now());
  const r = await workerCall('/precedent/semantic-find', { kind, subject_text: subjectText }, false, signal);
  if (!r || !r.ok) return { similars: [], degraded: 'worker-fail' };
  return r.data || { similars: [] };
}

function renderSemanticGroup(sectionEl, semData) {
  if (!semData) return;
  if (semData.degraded === 'daily-cap') {
    sectionEl.appendChild(el('div', { cls: 'gam-muted' }, 'AI retrieval paused — daily cap reached. Exact matches only.'));
    return;
  }
  if (!semData.similars || !semData.similars.length) return;  // quiet no-op
  const group = el('div', { cls: 'gam-precedent-group gam-precedent-group--ai' });
  group.appendChild(el('h4', { cls: 'gam-precedent-group-heading' }, 'Similar past cases (AI)'));
  for (const row of semData.similars) {
    const r = el('div', { cls: 'gam-precedent-row gam-precedent-row--ai' });
    r.appendChild(el('span', { cls: 'gam-precedent-title' }, String(row.title || '(untitled)')));
    if (row.rule_ref) r.appendChild(stateChip({ kind:'neutral', value: String(row.rule_ref) }));
    r.appendChild(el('span', { cls: 'gam-precedent-score', title: `cosine ${row.score}` }, `~${Math.round(row.score * 100)}%`));
    r.appendChild(el('span', { cls: 'gam-muted gam-precedent-meta' }, `${row.authored_by} • ${relativeTime(row.marked_at)}`));
    group.appendChild(r);
  }
  sectionEl.appendChild(group);
}
```

In each adapter's section-6 build:
```js
// Exact group first (v7.0 behavior).
const exactHeading = el('h4', { cls: 'gam-precedent-group-heading' }, 'Past cases (exact)');
sec6.appendChild(exactHeading);
if (exactPrecedents.length === 0) {
  sec6.appendChild(el('em', { cls: 'gam-muted' }, 'No exact-signature precedents yet.'));
} else {
  for (const p of exactPrecedents) sec6.appendChild(renderExactPrecedentRow(p));
}

// Semantic group second, in parallel.
semanticFindIfAllowed(opts.kind, opts.id, buildSubjectText(opts, adapterData), signal)
  .then(semData => renderSemanticGroup(sec6, semData))
  .catch(() => {/* silent */});
```

Per-kind `buildSubjectText`:
- `User`: `username + " " + mostRecentNoteBody + " " + recentAuditTypes.join(" ")`
- `Thread`: `subject + " " + firstMessageBody.slice(0, 1000)`
- `Post`: `title + " " + body.slice(0, 1500)`
- `QueueItem`: delegate to Post builder + prepend `reportReasons.join(" ")`

**Success condition:** With `features.memory=true`, opening a User drawer on a user whose signature matches a past precedent (exact) renders both groups. Opening on a user with no exact match but semantically-similar history renders only the AI group (manual "Past cases (exact)" heading followed by the no-precedents em). Opening the same drawer twice within 500ms does NOT trigger a second `/precedent/semantic-find` (watch network tab; grep `_lastSemFindAt.set` call pattern). With `features.memory=false`, the AI group never appears; behavior matches v7.0.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 13 — PRIVACY.md append + manifest + version bump

File: `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md`. Append before the final "Changes" section:

```markdown
## v7.3 data categories

v7.3 adds three data flows, all built on v7.1 proposals infra and v7.2 embedding infra.

- **Quieter proposal kinds (`warn`, `unban`).** Same retention and shape as v7.1's `ban`/`remove`/`lock` proposals: stored in the `proposals` D1 table, kept indefinitely as part of the moderation audit record. `unban` proposals additionally store `appeal_context` (typically the user's appeal text or the proposer's rationale), required by the worker at creation time. Deletable by a lead mod via the same offboarding path as v7.0 precedents.

- **Precedent embeddings.** Each precedent entry (v7.0) gains an `embedding_id` cross-reference and a 768-dimension vector in the Cloudflare Vectorize index `gaw-precedents`. The vector is derived from the precedent's title + reason via Workers AI `@cf/baai/bge-base-en-v1.5` (on-platform; no content leaves Cloudflare). Retention matches the underlying precedent row (indefinite). Deleting a precedent removes its vector on the same operation.

- **Consensus drift reports.** Weekly Discord-only surfacing of rules where the team is voting inconsistently. Reports are generated from the existing `proposals` + `proposal_votes` tables; they are NOT stored in any new D1 table. The Discord message contains proposal IDs and voter usernames (already visible to all mods via the v7.1 proposals view). No drift-report history is retained server-side beyond Discord's own retention.
```

`D:\AI\_PROJECTS\modtools-ext\manifest.json` → `"version": "7.3.0"`.
`D:\AI\_PROJECTS\gaw-mod-shared-flags\version.json` → `"version": "7.3.0"`.

**Success condition:** `verify-v7.3.ps1` check passes: PRIVACY.md contains literal substring `## v7.3 data categories`; manifest version is `7.3.0`.
**If fails:** rewrite entire chunk from scratch.

---

## CHUNK 14 — verify-v7.3.ps1 + deploy infra gate

File: `D:\AI\_PROJECTS\verify-v7.3.ps1`. BOM + ASCII + 4-step ending. Parse-check before delivery.

Checks in order, each PASS/FAIL logged:

**Infra gate (FAILING EXITS WITH CODE 2, SKIPS REST):**
1. D1 query: `SELECT name FROM sqlite_master WHERE name='proposals' AND type='table'` returns a row. Fail: "v7.1 proposals table missing — deploy v7.1 first."
2. D1 query: `SELECT sql FROM sqlite_master WHERE name='proposals'` result string contains both `'warn'` and `'unban'`. Fail: "migration 010 not applied."
3. Vectorize: `npx wrangler vectorize list` output contains `gaw-modmail`. Fail: "v7.2 modmail index missing — deploy v7.2 first."
4. Vectorize: `npx wrangler vectorize list` output contains `gaw-precedents`. Fail: "run setup-precedent-vectors.ps1 first."
5. Vectorize gaw-modmail has >0 vectors (via a sample query). Fail: "v7.2 index empty — v7.2 not stable."

**Code-grep checks:**
6. `modtools.js` contains `'features.memory': false` in DEFAULT_SETTINGS.
7. `modtools.js` contains `renderProposeWarningBtn` AND `renderProposeUnbanBtn` AND `renderProposedWarningsView` AND `renderDriftReportChip` AND `renderSemanticGroup`.
8. `modtools.js` contains `_lastSemFindAt` and the 500ms gate (regex: `Date\.now\(\)\s*-\s*last\s*<\s*500`).
9. `modtools.js` contains `if (p.kind !== 'warn')` or equivalent kind-specific alert gate (regex: `kind\s*!==\s*['"]warn['"]`).
10. `modtools.js` contains NO `innerHTML\s*=` in any function matching `renderSemanticGroup|renderDriftReportChip|renderProposedWarningsView|renderProposeUnbanBtn`.
11. `gaw-mod-proxy-v2.js` contains route strings `/precedent/semantic-find` and `/config/drift-threshold` and `/cron/precedent-backfill-kick`.
12. `gaw-mod-proxy-v2.js` contains `consensusDriftReportTick` and `precedentBackfillTick` and `handlePrecedentSemanticFind`.
13. `wrangler.jsonc` contains cron string `0 6 * * 0`.
14. `migrations/010_memory.sql` exists and contains `ALTER TABLE precedents ADD COLUMN embedding_id`.
15. `PRIVACY.md` contains `v7.3 data categories`.

**Live endpoint checks (need MOD_TOKEN + LEAD_TOKEN prompted via Read-Host, secure input):**
16. `POST /proposals/create {kind:'warn', target:'__verify_test__', rule_ref:'R0', reason:'verify'}` returns `{ok:true, data:{quiet:true}}`.
17. `POST /proposals/create {kind:'unban', target:'__verify_test__', appeal_context:''}` returns 400 with `appeal_context required`.
18. `POST /precedent/semantic-find {kind:'User', subject_text:'verify test'}` returns `{ok:true, data:{...}}`. Returns `degraded:'no-ai-binding'` if AI binding absent — acceptable PASS with warning.
19. `POST /config/drift-threshold {value:0.30}` with MOD token returns 401. With LEAD token returns `{ok:true}`.
20. CWS ZIP size < 215 KB.

Deploy sequence (printed at end of verify, not auto-run):
```
pwsh -File D:\AI\_PROJECTS\setup-precedent-vectors.ps1
pwsh -File D:\AI\_PROJECTS\bump-version.ps1 -Version 7.3.0 -Notes "v7.3 memory: warn+unban proposals, semantic precedent retrieval, weekly consensus drift report"
cd D:\AI\_PROJECTS\cloudflare-worker
npx --yes wrangler@latest deploy
cd D:\AI\_PROJECTS
pwsh -File D:\AI\_PROJECTS\build-chrome-store-zip.ps1
pwsh -File D:\AI\_PROJECTS\verify-v7.3.ps1
```

Mandatory 4-step ending:
- Structured report to console + `$log` buffer.
- `$log -join "`n" | Set-Clipboard; Write-Host '[log copied to clipboard]'`.
- E-C-G beep: `[Console]::Beep(659,160); Start-Sleep -Milliseconds 100; [Console]::Beep(523,160); Start-Sleep -Milliseconds 100; [Console]::Beep(784,800)`.
- `if (-not $NoPause) { Read-Host 'Press Enter to exit' }`.
- Persist log to `D:\AI\_PROJECTS\logs\verify-v7.3-$(Get-Date -Format yyyyMMdd-HHmmss).log`.

Parse-verify the final script with `[System.Management.Automation.Language.Parser]::ParseFile`. Zero errors or regenerate.

**Success condition:** `pwsh -File D:\AI\_PROJECTS\verify-v7.3.ps1` exits 0 with all 20 checks PASS against a fully-deployed v7.3 environment. Against an environment missing v7.1 or v7.2 infra, exits 2 on check 1/2/3 and refuses to run the later checks. Log lands in clipboard + log file, ECG beep plays.
**If fails:** rewrite entire chunk from scratch.

---

## VERIFICATION SCRIPT (Commander runs these in order)

> Prose instructions — do not paste this list verbatim into PowerShell. Run each command on its own.

First, confirm v7.1 and v7.2 are live in production. Open your Cloudflare dashboard and confirm the `gaw-modmail` Vectorize index has vectors and the `proposals` D1 table exists. If either is missing, stop and finish that rollout first.

Then run `pwsh -File D:\AI\_PROJECTS\setup-precedent-vectors.ps1` — it creates the `gaw-precedents` Vectorize index, applies migration 010, and kicks the initial backfill. Wait for the ECG beep, paste the clipboard log into chat if anything looks off.

Next run `pwsh -File D:\AI\_PROJECTS\bump-version.ps1 -Version 7.3.0 -Notes "v7.3 memory"`.

Then `cd D:\AI\_PROJECTS\cloudflare-worker` and `npx --yes wrangler@latest deploy`. This ships the worker with the new endpoints, cron triggers, and the `PRECEDENTS_INDEX` binding.

Then `cd D:\AI\_PROJECTS` and `pwsh -File D:\AI\_PROJECTS\build-chrome-store-zip.ps1` to produce the CWS ZIP.

Finally `pwsh -File D:\AI\_PROJECTS\verify-v7.3.ps1` — this is the single source of truth for "is v7.3 live." Exit code 0 = ship. Exit code 2 = infra prereq failed (v7.1 or v7.2 missing). Any other non-zero = fix before rollout.

---

## ROLLOUT PROTOCOL (Commander owns this)

1. Confirm v7.1 + v7.2 have been stable for at least one clean shift each. If either had an incident in the last 48h, hold v7.3.
2. Ship v7.3 to GitHub installer with `features.memory` flag default OFF. Warn/Unban proposals ride on `features.superMod` which is already on per-mod from v7.1.
3. Commander enables `features.memory` for himself only. Runs one full shift. Watches the drift-report Discord channel for the first Sunday cron fire.
4. If the semantic-find results feel wrong (too noisy, too narrow), adjust the `0.75` threshold in `gaw-mod-proxy-v2.js` (it's a literal for v7.3 — upgrade to a lead-settable KV value in v7.4 if needed).
5. If the weekly drift report is posting false positives, raise `thresholds.drift.weekly_threshold` via the lead settings pane (no redeploy needed — KV-backed).
6. After one clean week, tell each mod in Discord: "flip features.memory on." Warn/Unban already work for them.
7. v7.4 candidate items (explicitly out of scope for v7.3): lead-settable cosine threshold, per-rule drift history retention, warn-auto-escalation after N warnings.

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

## OUT OF SCOPE (v7.4+, each its own GIGA)

- Lead-settable cosine threshold for semantic-find (currently 0.75 literal).
- Per-rule drift history + trend chart on dashboard.
- Warn-auto-escalation after N warnings in a window.
- Semantic-find cross-kind (e.g., a Post drawer pulling similar User precedents).
- Mod-facing drift dashboard (currently Discord-only).
- Embedding model upgrade path (bge-base → bge-large or a larger model).
- Appeal-context LLM summarization before sending to second-mod-voter.
- Precedent auto-mark on high-consensus proposal executions (auto-ML the exemplars).
- Retire v7.1 fallback paths (v8.0 task).
