# GIGA-V7.2-THE-ANTICIPATOR

**Audience:** Claude Code session with blanket approval from Commander Cats.
**Target:** GAW ModTools v7.1.x -> v7.2.0.
**Ships AFTER v7.1 is stable.** Hard dependency: `features.superMod` marker must exist in `modtools.js` before v7.2 deploy-verify runs. Refuse to ship otherwise.
**Small-team bias:** 2-5 mods. Worker-side corpus build runs silently; anticipation UI (`features.anticipator`) gates behind a flag so Commander dogfoods solo before enabling team-wide.

---

## MISSION

Turn the modmail archive into a memory the extension can draw from, then use it to predict the mod's next reply before they finish typing it. Three worker-side pipelines (crawler, embedder, intent tagger) run behind the existing `*/5 * * * *` cron and build a corpus with zero user-visible effect. Two client-side features (bootstrap-from-3-words ghost text, glowing-envelope pre-drafted reply) turn on only when `features.anticipator` flips true AND the corpus crosses a useful threshold AND the daily AI budget is not exhausted. Reject feedback feeds back into ranking weights so the system learns which historical cases the mod trusts.

---

## DELIVERABLES

| Path | Purpose |
|---|---|
| `D:\AI\_PROJECTS\modtools-ext\modtools.js` | typing-debounce helper, ghost-text overlay, status-bar envelope glow, drawer section 5 Accept/Edit/Reject flow, `features.anticipator` flag in DEFAULT_SETTINGS |
| `D:\AI\_PROJECTS\modtools-ext\manifest.json` | version 7.2.0 |
| `D:\AI\_PROJECTS\cloudflare-worker\gaw-mod-proxy-v2.js` | extended cron with three new branches (crawl/embed/tag), endpoints `/ai/bootstrap-draft`, `/ai/tag-thread`, `/ai/rag-search`, `/drafts/thread/write`, `/drafts/thread/read`, `/drafts/thread/reject`, AI budget sentinel `anticipator:budget:${todayUTC()}` |
| `D:\AI\_PROJECTS\cloudflare-worker\migrations\009_anticipator_corpus.sql` | `modmail_threads`, `modmail_messages`, `thread_drafts`, `draft_rejections` tables (IF NOT EXISTS — double-check v5.4.0 migration status) + added columns `embedding_id`, `intent`, `intent_confidence` |
| `D:\AI\_PROJECTS\cloudflare-worker\wrangler.toml` | bind Vectorize index `gaw-modmail`, ensure R2 bucket `gaw-mod-evidence` already bound from prior versions |
| `D:\AI\_PROJECTS\gaw-mod-shared-flags\version.json` | 7.2.0 |
| `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md` | append v7.2 data category section (historical corpus, embeddings, intent labels, draft_rejections) |
| `D:\AI\_PROJECTS\setup-vectorize.ps1` | create `gaw-modmail` Vectorize index (BOM+ASCII, 4-step ending) |
| `D:\AI\_PROJECTS\run-modmail-backfill.ps1` | manual trigger for initial crawl burst, pages N at a time (BOM+ASCII, 4-step ending) |
| `D:\AI\_PROJECTS\verify-v7.2.ps1` | verification script (BOM+ASCII, 4-step ending), checks `features.superMod` marker exists before running any v7.2 checks |

---

## ACCEPTANCE CRITERIA (all checkable by `verify-v7.2.ps1`)

- [ ] `verify-v7.2.ps1` grep-checks `modtools.js` for literal `features.superMod`; exits 2 with `PRECONDITION FAILED: v7.1 marker missing` if absent.
- [ ] `wrangler vectorize list` (or API equivalent called from the verify script) shows an index named `gaw-modmail` with `dimensions=768` and `metric=cosine`.
- [ ] Cron handler in `gaw-mod-proxy-v2.js` branches on `cron` expression: the existing bot-tick logic runs every tick; the three new branches (crawl / embed / tag) each run every tick but short-circuit if their respective KV cursor / queue is empty.
- [ ] `modmail:crawl:cursor` KV key exists after first cron tick. Value is a JSON `{nextPage:int, lastFetchTs:int}` or the sentinel string `"DONE"` once backfill completes.
- [ ] Each page fetch writes a structured audit log line: `[crawler] page=N fetched=M stored=M new_threads=X new_messages=Y duration_ms=Z`. Grep on `wrangler tail` output during an enabled test run confirms presence.
- [ ] R2 has at least one object under prefix `modmail/` after first successful crawl tick on a non-empty page.
- [ ] D1 `modmail_threads` and `modmail_messages` each have >0 rows after first crawl tick.
- [ ] Embedder branch increments: after N cron ticks where N * 20 exceeds `SELECT count(*) FROM modmail_messages WHERE embedding_id IS NULL`, the count reaches 0 (or plateaus as new messages stream in).
- [ ] Intent tagger branch: after N cron ticks, `SELECT count(*) FROM modmail_threads WHERE intent IS NULL` trends to 0.
- [ ] `features.anticipator` defaults to `false`. With it OFF, opening any modmail reply textarea and typing 10 words produces zero `/ai/bootstrap-draft` calls (verified by network-tab inspection).
- [ ] With `features.anticipator` ON, typing three words into a reply textarea and pausing 800 ms fires exactly one `/ai/bootstrap-draft` call with an `AbortController`; typing a fourth word before the call returns aborts it.
- [ ] Bootstrap ghost text renders as an absolute-positioned span with reduced opacity after the cursor position, in the same font as the textarea. Tab key accepts; any other key clears it.
- [ ] On new modmail thread arrival (sync path): `modmail_threads` row inserted AND `/ai/tag-thread` fires AND chip renders on thread row within next poll cycle. Chip class matches `gam-chip--intent-{appeal|complaint|crisis|spam|allycheckin|question|report|other}`.
- [ ] For a thread where `/ai/rag-search` returns `confidence > 0.80` AND `top3_similarity > 0.85` AND `intent NOT IN ('crisis','legal')`: a row is inserted into `thread_drafts` with `has_ai_draft=1`, status-bar envelope animates from envelope glyph to star-envelope glyph, and clicking envelope opens IntelDrawer on the thread with section 5 pre-populated.
- [ ] Section 5 pre-populated draft shows three "Why this draft" cited case IDs, each clickable to open IntelDrawer on that past thread (recursive nesting allowed — Backspace pops back).
- [ ] Accept button copies draft into the reply textarea (does NOT send). Edit button copies into textarea focused with caret at end. Reject button fires `/drafts/thread/reject` and records a `draft_rejections` row.
- [ ] Daily AI budget: setting `anticipator:budget:${todayUTC()}` to a value at or above `thresholds.ai.anticipator.dailyCeiling` (default $2 expressed in cents = 200) causes `/ai/bootstrap-draft`, `/ai/rag-search`, `/ai/tag-thread` and the embedder cron branch to all return `{rate_limited: true}` until UTC midnight. Extension surfaces a one-line `AI rate-limited` hint in the status bar.
- [ ] Every new AI prompt (bootstrap, tag, rag-search) wraps user-derived content in `<untrusted_user_content>...</untrusted_user_content>` — grep confirms in all three handler functions.
- [ ] Embedding model string is exactly `@cf/baai/bge-base-en-v1.5` in every `env.AI.run` call; grep shows no other embedding model invoked.
- [ ] Thresholds `thresholds.ai.drafts.high.confidence` (default 0.80) and `thresholds.ai.drafts.high.similarity` (default 0.85) are editable only by lead-token holders via the existing settings-gate path.
- [ ] `draft_rejections` rows are purged after 90 days by the existing evidence-retention cron (confirm by grep that retention job includes the new table).
- [ ] PRIVACY.md contains a new `## v7.2 data categories` heading covering: historical modmail corpus (R2 + D1, indefinite, audit-class), embeddings (Vectorize, lifecycle bound to corpus), intent labels (D1, lifecycle bound to corpus), draft rejections (D1, 90 days).
- [ ] `pwsh -File D:\AI\_PROJECTS\verify-v7.2.ps1` exits 0 with every check PASS.
- [ ] CWS ZIP builds under 215 KB compressed (v7.1 adds ~5 KB over v7.0; v7.2 adds ~8 KB for ghost-text overlay + envelope animation + drawer section 5 controls).

---

## BAKED-IN DESIGN DECISIONS (from the spec — not up for re-litigation)

1. **Feature flag `features.anticipator` in DEFAULT_SETTINGS, default `false`.** Gates client-side features #4 (bootstrap) and #6 (glowing envelope) ONLY. Worker-side corpus pipelines (#1 crawler, #2 embedder, #3 intent tagger, #5 auto-tag-on-arrival) run unconditionally. Rationale: corpus must exist before the UI is flipped, or the UI flips to an empty well.
2. **Daily AI spend ceiling = $2/day, KV-backed.** Key `anticipator:budget:${todayUTC()}` (cents). Over cap: all three AI paths silently return `{rate_limited:true}`; embedder cron branch pauses (crawler + tagger still run — they have their own counters and are cheaper). Status bar shows `AI rate-limited`. Resets at UTC midnight by virtue of the key name.
3. **`<untrusted_user_content>` wrapper on every new AI prompt.** No exceptions. Applies to: partial_text in bootstrap, thread body in tagger, similar-cases contents in rag-search composition.
4. **Embedding model locked to `@cf/baai/bge-base-en-v1.5` (dim=768).** Model change = full reindex = v7.3+ concern. Vectorize index `gaw-modmail` metric `cosine`.
5. **Confidence cliffs for envelope glow:** grok confidence > 0.80 AND top-3 retrieval similarity > 0.85 AND intent NOT IN {crisis, legal}. Both thresholds configurable by lead-token holders via settings; defaults are hardcoded fallbacks if key missing.
6. **Reject feedback is lightweight, not ML.** `draft_rejections` stores `{thread_id, rejected_case_ids[], rejected_at, rejected_by}`. Ranking penalty: per cited case, `rejection_count` weights the top-3 retrieval cosine similarity down by `0.01 * rejection_count` (capped at 0.1). No gradient descent, no re-training — a running tally applied at query time.
7. **PRIVACY.md categories:**
   - Historical corpus (R2 `modmail/`, D1 `modmail_*`): indefinite retention, audit-class, same policy as existing evidence.
   - Embeddings (Vectorize `gaw-modmail`): lifecycle-bound to corpus; if corpus row purged, vector purged.
   - Intent labels (D1 columns on `modmail_threads`): lifecycle-bound to corpus.
   - `draft_rejections`: 90 days.
8. **Crawler conservative default: 1 page / 5 min.** Ceiling 288 pages/day. Every page fetch logged structurally for audit (page number, thread/message counts, duration). Configurable via KV `anticipator:crawl:pagesPerTick` (default 1, lead-token editable).
9. **v7.2 deploy-verify refuses if `features.superMod` marker is not present in `modtools.js`.** This is the v7.1 stability fence. Grep for the literal string; exit 2 if missing.
10. **Vectorize setup documented in `setup-vectorize.ps1`.** BOM + ASCII-only + 4-step ending. Single `npx --yes wrangler@latest vectorize create gaw-modmail --dimensions=768 --metric=cosine` invocation, idempotent (catches the "already exists" error and treats as success).
11. **AbortController parity with v7.0.** Bootstrap-draft uses a per-textarea `AbortController` attached to the textarea element; moving focus away or typing after the 800 ms debounce restarts aborts the in-flight fetch. Envelope RAG-search uses a per-thread-row AbortController; if the row is removed from the list before the call returns, abort.
12. **Ghost text uses the existing `el()` helper and textContent only — no innerHTML.** Overlay is a positioned `<span>` with `pointer-events: none` and `user-select: none`. Rendered from `response.continuation` (string) via `textContent`. Tab handler intercepts before the browser tab-cycle.
13. **No new precedent/intel/audit endpoints.** All existing v7.0 and v7.1 surfaces are untouched. Anticipator additions are six new endpoints (bootstrap-draft, tag-thread, rag-search, drafts/read, drafts/write, drafts/reject) plus extended cron behavior.

---

## CHUNK 1 — D1 migration `009_anticipator_corpus.sql`

File: `D:\AI\_PROJECTS\cloudflare-worker\migrations\009_anticipator_corpus.sql`.

**Precondition check (first thing the chunk does):** grep the prior migrations directory for existing `modmail_threads` / `modmail_messages` creation. v5.4.0 spec described these; if `005_*` or `006_*` already created them, skip the CREATE TABLE and emit only ALTER TABLE ADD COLUMN statements for the three new columns. If not, create them from scratch.

Schema:

```sql
-- 009_anticipator_corpus.sql

CREATE TABLE IF NOT EXISTS modmail_threads (
  thread_id        TEXT PRIMARY KEY,
  subject          TEXT,
  subreddit        TEXT,
  author           TEXT,
  status           TEXT,
  created_at       INTEGER NOT NULL,
  last_message_at  INTEGER,
  message_count    INTEGER DEFAULT 0,
  embedding_id     TEXT,           -- added v7.2
  intent           TEXT,           -- added v7.2: appeal|complaint|crisis|spam|allycheckin|question|report|other
  intent_confidence REAL           -- added v7.2: [0,1]
);
CREATE INDEX IF NOT EXISTS idx_modmail_threads_intent ON modmail_threads(intent);
CREATE INDEX IF NOT EXISTS idx_modmail_threads_last_msg ON modmail_threads(last_message_at DESC);

CREATE TABLE IF NOT EXISTS modmail_messages (
  message_id    TEXT PRIMARY KEY,
  thread_id     TEXT NOT NULL,
  direction     TEXT NOT NULL,    -- 'inbound'|'outbound'
  author        TEXT,
  body          TEXT NOT NULL,
  sent_at       INTEGER NOT NULL,
  embedding_id  TEXT,              -- added v7.2
  FOREIGN KEY (thread_id) REFERENCES modmail_threads(thread_id)
);
CREATE INDEX IF NOT EXISTS idx_modmail_messages_thread ON modmail_messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_modmail_messages_embed_null ON modmail_messages(embedding_id) WHERE embedding_id IS NULL;

CREATE TABLE IF NOT EXISTS thread_drafts (
  thread_id       TEXT PRIMARY KEY,
  draft_body      TEXT NOT NULL,
  confidence      REAL NOT NULL,
  cited_case_ids  TEXT NOT NULL,   -- JSON array of thread_id strings
  has_ai_draft    INTEGER NOT NULL DEFAULT 1,
  created_at      INTEGER NOT NULL,
  generated_by    TEXT             -- grok model id
);

CREATE TABLE IF NOT EXISTS draft_rejections (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  thread_id          TEXT NOT NULL,
  rejected_case_ids  TEXT NOT NULL,   -- JSON array
  rejected_at        INTEGER NOT NULL,
  rejected_by        TEXT NOT NULL    -- token-verified mod username
);
CREATE INDEX IF NOT EXISTS idx_draft_rejections_case ON draft_rejections(rejected_case_ids);
CREATE INDEX IF NOT EXISTS idx_draft_rejections_at ON draft_rejections(rejected_at);

-- ALTER TABLE statements for the "already exists from v5.4.0" path:
-- These must be run manually if 009 detects prior modmail_* tables without v7.2 columns.
-- ALTER TABLE modmail_threads ADD COLUMN embedding_id TEXT;
-- ALTER TABLE modmail_threads ADD COLUMN intent TEXT;
-- ALTER TABLE modmail_threads ADD COLUMN intent_confidence REAL;
-- ALTER TABLE modmail_messages ADD COLUMN embedding_id TEXT;
```

**Success condition:** `wrangler d1 execute gaw-mod-audit --remote --file=migrations/009_anticipator_corpus.sql` exits 0. `PRAGMA table_info(modmail_threads)` shows `intent`, `embedding_id`, `intent_confidence` columns. `PRAGMA table_info(thread_drafts)` and `draft_rejections` return non-empty.
**If fails:** check for prior-migration column collision (v5.4.0); emit ALTER TABLE script instead; re-run.

---

## CHUNK 2 — Vectorize index + `setup-vectorize.ps1`

File: `D:\AI\_PROJECTS\setup-vectorize.ps1`. PowerShell 5.1+ compatible (no PS-7-only syntax without `#requires`). BOM prefix + ASCII-only strings + mandatory 4-step ending.

Script does:
1. Pre-flight: check Node on PATH, check `wrangler.toml` exists at `D:\AI\_PROJECTS\cloudflare-worker\wrangler.toml`.
2. Prompt via `Read-Host` for Cloudflare API token if not already present in `CLOUDFLARE_API_TOKEN` env var. Single-asterisk-on-paste warning note shown.
3. `npx --yes wrangler@latest vectorize create gaw-modmail --dimensions=768 --metric=cosine` — capture stdout/stderr; if the message contains `already exists`, treat as PASS.
4. Append to `wrangler.toml` (idempotent — grep for `[[vectorize]]` section first; only append if absent):
   ```toml
   [[vectorize]]
   binding = "VECTORIZE_MODMAIL"
   index_name = "gaw-modmail"
   ```
5. Final structured report with counts (`pre_existed`, `created`, `toml_appended`), `$log | Set-Clipboard`, E-C-G beep, `Read-Host 'Press Enter to exit'`.
6. Log persist: `D:\AI\_PROJECTS\logs\setup-vectorize-YYYYMMDD-HHMMSS.log`.

Post-write verification: run `[Parser]::ParseFile($path, [ref]$null, [ref]$errors)` twice — once on the raw Write output, once after BOM + ASCII sanitization. Zero errors required before declaring ready.

**Success condition:** Running the script produces either `created` or `pre_existed` status. `wrangler.toml` diff shows exactly the `[[vectorize]]` block added (no other changes). Log file written to `D:\AI\_PROJECTS\logs\`.
**If fails:** report the specific wrangler error; do not silently "best-effort" the toml edit if the index creation failed.

---

## CHUNK 3 — Crawler cron branch (worker)

File: `gaw-mod-proxy-v2.js`. Locate the existing `scheduled` export handler (the one containing the v7.x bot-tick logic and `bot:grok:budget` references). Add a new branch called unconditionally after the bot tick:

```js
// v7.2 anticipator: historical modmail crawler
await runCrawlerTick(env, ctx);
```

Implementation:

```js
async function runCrawlerTick(env, ctx) {
  const cursor = JSON.parse(await env.MOD_KV.get('modmail:crawl:cursor') || '{"nextPage":1,"lastFetchTs":0}');
  if (cursor === 'DONE' || (typeof cursor === 'string' && cursor === 'DONE')) return;
  const pagesPerTick = Number(await env.MOD_KV.get('anticipator:crawl:pagesPerTick') || '1');
  const start = Date.now();
  let fetched = 0, newThreads = 0, newMessages = 0;
  for (let i = 0; i < pagesPerTick; i++) {
    const page = cursor.nextPage + i;
    const resp = await fetch(`${env.REDDIT_BASE}/modmail/archive?page=${page}`, { headers: redditAuthHeaders(env) });
    if (!resp.ok) { console.log(`[crawler] page=${page} http=${resp.status} ABORT`); break; }
    const html = await resp.text();
    if (isEmptyArchivePage(html)) {
      await env.MOD_KV.put('modmail:crawl:cursor', JSON.stringify('DONE'));
      console.log(`[crawler] page=${page} EMPTY -> DONE`);
      return;
    }
    // R2 raw
    const threadId = extractThreadId(html) || `page-${page}`;
    await env.EVIDENCE.put(`modmail/${threadId}.html`, html, {
      httpMetadata: { contentType: 'text/html; charset=utf-8' }
    });
    const parsed = parseModmailArchivePage(html);  // {threads:[...], messages:[...]}
    for (const t of parsed.threads) {
      const r = await env.AUDIT_DB.prepare(
        `INSERT OR IGNORE INTO modmail_threads
         (thread_id, subject, subreddit, author, status, created_at, last_message_at, message_count)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(t.thread_id, t.subject, t.subreddit, t.author, t.status, t.created_at, t.last_message_at, t.message_count).run();
      if (r.meta.changes > 0) newThreads++;
    }
    for (const m of parsed.messages) {
      const r = await env.AUDIT_DB.prepare(
        `INSERT OR IGNORE INTO modmail_messages
         (message_id, thread_id, direction, author, body, sent_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      ).bind(m.message_id, m.thread_id, m.direction, m.author, m.body, m.sent_at).run();
      if (r.meta.changes > 0) newMessages++;
    }
    fetched++;
    console.log(`[crawler] page=${page} fetched=1 new_threads=${newThreads} new_messages=${newMessages}`);
  }
  const duration = Date.now() - start;
  console.log(`[crawler] tick fetched=${fetched} new_threads=${newThreads} new_messages=${newMessages} duration_ms=${duration}`);
  cursor.nextPage += fetched;
  cursor.lastFetchTs = Date.now();
  await env.MOD_KV.put('modmail:crawl:cursor', JSON.stringify(cursor));
}
```

Helpers `isEmptyArchivePage`, `extractThreadId`, `parseModmailArchivePage` live in a new file or appended to the worker. Parser is deliberately dumb — regex-based, no DOM. Oldest-first ordering is enforced by the `page=N` parameter; do not sort by date client-side.

**Success condition:** After three cron ticks, `modmail_threads` has >0 rows, R2 prefix `modmail/` has >0 objects, cursor KV key advances. `wrangler tail` shows `[crawler] tick` lines with plausible numbers.
**If fails:** dump the first 500 chars of the archive HTML to a worker log; adjust parser regex; re-run `run-modmail-backfill.ps1` to manually advance the cursor past the problem page.

---

## CHUNK 4 — Embedder cron branch

File: `gaw-mod-proxy-v2.js`. Add after `runCrawlerTick`:

```js
await runEmbedderTick(env, ctx);
```

Implementation:

```js
async function runEmbedderTick(env, ctx) {
  const budgetCents = Number(await env.MOD_KV.get(`anticipator:budget:${todayUTC()}`) || '0');
  const ceiling = Number(await env.MOD_KV.get('thresholds.ai.anticipator.dailyCeiling') || '200');
  if (budgetCents >= ceiling) { console.log('[embedder] rate_limited'); return; }

  const rows = await env.AUDIT_DB.prepare(
    `SELECT message_id, body FROM modmail_messages
     WHERE embedding_id IS NULL
     ORDER BY sent_at ASC
     LIMIT 20`
  ).all();
  if (!rows.results || rows.results.length === 0) return;

  let embedded = 0;
  for (const row of rows.results) {
    const safeBody = String(row.body || '').slice(0, 4096);
    const out = await env.AI.run('@cf/baai/bge-base-en-v1.5', { text: safeBody });
    const vector = out.data?.[0];
    if (!vector || vector.length !== 768) { continue; }
    const embeddingId = `msg:${row.message_id}`;
    await env.VECTORIZE_MODMAIL.upsert([{
      id: embeddingId,
      values: vector,
      metadata: { message_id: row.message_id }
    }]);
    await env.AUDIT_DB.prepare(
      `UPDATE modmail_messages SET embedding_id = ? WHERE message_id = ?`
    ).bind(embeddingId, row.message_id).run();
    embedded++;
  }
  // BGE on Workers AI is FREE tier; we still nudge the budget counter by 0 to record activity.
  console.log(`[embedder] embedded=${embedded}`);
}
```

Note: `@cf/baai/bge-base-en-v1.5` is free; no cents added. The rate-limit check is pre-emptive so if paid models (grok paths) exhaust the budget, we don't wastefully keep calling the free model either (since they share a daily-pause semantics for simplicity). If Commander prefers to keep embedder running past budget, a separate `anticipator:budget:embedder` key can be added in v7.3.

**Success condition:** `SELECT count(*) FROM modmail_messages WHERE embedding_id IS NULL` decreases by ~20 per tick until 0. Vectorize index `describe` shows vector count matching embedded message count.
**If fails:** inspect the `out.data` shape — Workers AI sometimes returns `{data:[[...]]}` vs `{data:[{values:[...]}]}`; adjust extraction. Log the first failed shape.

---

## CHUNK 5 — Intent tagger cron branch

File: `gaw-mod-proxy-v2.js`. Add after `runEmbedderTick`:

```js
await runIntentTaggerTick(env, ctx);
```

Implementation:

```js
async function runIntentTaggerTick(env, ctx) {
  const budgetCents = Number(await env.MOD_KV.get(`anticipator:budget:${todayUTC()}`) || '0');
  const ceiling = Number(await env.MOD_KV.get('thresholds.ai.anticipator.dailyCeiling') || '200');
  if (budgetCents >= ceiling) { console.log('[tagger] rate_limited'); return; }

  const rows = await env.AUDIT_DB.prepare(
    `SELECT t.thread_id, t.subject,
            (SELECT body FROM modmail_messages m
             WHERE m.thread_id = t.thread_id AND m.direction = 'inbound'
             ORDER BY m.sent_at ASC LIMIT 1) AS first_inbound_body
     FROM modmail_threads t
     WHERE t.intent IS NULL
     ORDER BY t.last_message_at DESC
     LIMIT 10`
  ).all();
  if (!rows.results || rows.results.length === 0) return;

  for (const row of rows.results) {
    const body = (row.first_inbound_body || row.subject || '').slice(0, 2000);
    const prompt = [
      'Classify the modmail below into exactly one label:',
      'appeal | complaint | crisis | spam | allycheckin | question | report | other.',
      'Reply with JSON {"intent":"<label>","confidence":<0..1>}.',
      '',
      '<untrusted_user_content>',
      body,
      '</untrusted_user_content>'
    ].join('\n');
    const resp = await callGrokChatThin(env, prompt);  // existing helper, reuse
    const parsed = safeParseIntentJson(resp);
    if (!parsed) { continue; }
    await env.AUDIT_DB.prepare(
      `UPDATE modmail_threads SET intent = ?, intent_confidence = ? WHERE thread_id = ?`
    ).bind(parsed.intent, parsed.confidence, row.thread_id).run();
    await incrementAiBudget(env, 1);  // ~1 cent per thin classifier call
  }
  console.log(`[tagger] tagged=${rows.results.length}`);
}
```

`callGrokChatThin` reuses the existing grok-chat path wrapped for minimal output. `safeParseIntentJson` validates the label is in the fixed set; anything else -> null (row stays unlabeled, retried next tick). Budget increment uses `env.MOD_KV` atomic counter pattern already used by v7.0's `/ai/next-best-action`.

**Success condition:** `SELECT count(*) FROM modmail_threads WHERE intent IS NOT NULL` grows monotonically. Sample queries `SELECT intent, count(*) FROM modmail_threads GROUP BY intent` return a plausible distribution (e.g. question + appeal + complaint dominate; crisis rare).
**If fails:** inspect the first 3 raw grok responses; tighten the prompt; if the model repeatedly wraps JSON in prose, add `Reply ONLY with the JSON. No prose.` and re-run.

---

## CHUNK 6 — Worker endpoint `/ai/rag-search`

File: `gaw-mod-proxy-v2.js`. New route handler `handleAiRagSearch(request, env, ctx)`. Mod-token gated (same as v7.0 `/ai/next-best-action`).

Contract:
- Input: `{ thread_id: string, body?: string }` — if `body` provided, embed it directly; else fetch the first inbound message of `thread_id` and embed that.
- Steps: budget check (return `{rate_limited:true}` if over); embed via bge; Vectorize `query` top-5 with `returnMetadata:true` and filter out any vector whose `thread_id` == input thread_id; apply the rejection-count ranking penalty (join `draft_rejections` by case id, subtract `0.01 * rejection_count` capped at 0.1 from similarity); take top 3 as cited cases; fetch those threads' outbound reply bodies from D1; compose a grok-3 prompt using `<untrusted_user_content>` around each citation; parse `{draft, confidence, cited_case_ids}`; return it.
- Output: `{ draft: string, confidence: number, cited_case_ids: string[], rate_limited?: boolean }`.

Prompt skeleton (only the content is author-controlled; the instructions are fixed):

```
You are drafting a moderator reply for a new modmail thread.
Below are three past threads where a moderator handled a similar case well.
Use them to inform tone and resolution, but write a fresh reply for the NEW thread.

NEW THREAD:
<untrusted_user_content>
${newThreadBody}
</untrusted_user_content>

SIMILAR PAST CASE 1 (thread_id=${c1.thread_id}):
USER SAID:
<untrusted_user_content>
${c1.inbound}
</untrusted_user_content>
MOD REPLIED:
<untrusted_user_content>
${c1.outbound}
</untrusted_user_content>

SIMILAR PAST CASE 2 (thread_id=${c2.thread_id}): ...
SIMILAR PAST CASE 3 (thread_id=${c3.thread_id}): ...

Reply with JSON {"draft":"<full reply text>","confidence":<0..1>,"cited_case_ids":["...","...","..."]}.
No prose outside the JSON.
```

**Success condition:** POST to `/ai/rag-search` with a known-similar body returns a `draft` that references the case tone. `cited_case_ids` are valid D1 thread_ids. Confidence is numeric.
**If fails:** check vectorize query shape; check that the inbound/outbound join returns both directions; if confidence comes back as string, coerce.

---

## CHUNK 7 — Worker endpoint `/ai/bootstrap-draft`

File: `gaw-mod-proxy-v2.js`. New route handler, mod-token gated.

Contract:
- Input: `{ partial_text: string, context: { thread_id?: string, user?: string } }`.
- Validation: `partial_text.split(/\s+/).filter(Boolean).length >= 3` — else 400 `{error:'min_3_words'}`.
- Steps: budget check; embed `partial_text` via bge; Vectorize top-5 on outbound mod replies only (filter metadata `direction:'outbound'`); take top-3 as context; grok-3-mini call with prompt "continue this moderator reply, guided by similar past cases — return only the continuation, starting at the cursor"; return `{continuation, confidence}`. Keep grok output under 80 tokens to stay cheap.
- Output: `{ continuation: string, confidence: number, rate_limited?: boolean }`.

Prompt:

```
A moderator is typing a reply. Here is what they have so far.
Continue the reply naturally — output ONLY the continuation text (no rephrasing of the partial).

PARTIAL:
<untrusted_user_content>
${partialText}
</untrusted_user_content>

SIMILAR PAST REPLIES (for tone reference only, not to quote):
1. <untrusted_user_content>${c1}</untrusted_user_content>
2. <untrusted_user_content>${c2}</untrusted_user_content>
3. <untrusted_user_content>${c3}</untrusted_user_content>

Reply with JSON {"continuation":"<text>","confidence":<0..1>}. No prose outside JSON.
Limit continuation to 80 tokens.
```

**Success condition:** POST with 3 words returns a plausible continuation under ~80 tokens. Confidence numeric. Budget counter increments by the call's cost.
**If fails:** if the model keeps echoing the partial, add `Do NOT repeat the partial. Start your text immediately after the partial's last character.` to the prompt.

---

## CHUNK 8 — Worker endpoints `/ai/tag-thread` + `/drafts/thread/*`

File: `gaw-mod-proxy-v2.js`.

`/ai/tag-thread` (mod-gated): input `{thread_id}`. Fetches first inbound body, runs the same classifier as CHUNK 5's tagger, writes `intent` / `intent_confidence` to D1. Also triggers — via `ctx.waitUntil` — an `/ai/rag-search` call with the thread body. If the rag-search comes back with `confidence > thresholds.ai.drafts.high.confidence` AND `top3_similarity > thresholds.ai.drafts.high.similarity` AND `intent NOT IN {crisis, legal}`, insert a row into `thread_drafts` with `has_ai_draft=1`.

`/drafts/thread/read` (mod-gated): input `{thread_id}` (path or query). Returns the row from `thread_drafts` including `cited_case_ids` as a parsed array, plus full bodies of the three cited threads (joined server-side) so the client can render "Why this draft" without extra roundtrips. Returns `{has_ai_draft:false}` if no row.

`/drafts/thread/write` (lead-gated): for manual draft insertion (rare, but needed for the verify-v7.2 test to seed a known-good draft). Input `{thread_id, draft_body, confidence, cited_case_ids}`.

`/drafts/thread/reject` (mod-gated): input `{thread_id, rejected_case_ids[]}`. Inserts a `draft_rejections` row. Also deletes the `thread_drafts` row for that thread (so the envelope stops glowing). Returns `{ok:true}`.

Top-3 similarity surfacing: `/ai/rag-search` response must include `top3_similarity` (the max of the three retrieved scores after penalty). Envelope-trigger logic in `/ai/tag-thread` reads both fields.

**Success condition:** POSTing `/ai/tag-thread` for a freshly-synced thread results in: an intent label written, and (for qualifying threads) a `thread_drafts` row appearing within ~5 seconds. `/drafts/thread/read` returns the composed payload. `/drafts/thread/reject` removes the `thread_drafts` row and adds `draft_rejections` row.
**If fails:** check `ctx.waitUntil` isn't being prematurely cancelled — if so, inline the rag-search await instead of deferring it.

---

## CHUNK 9 — Budget sentinel + daily ceiling helper

File: `gaw-mod-proxy-v2.js`. Single shared helper used by all three AI endpoints and the embedder / tagger cron branches:

```js
async function aiBudgetGateOrNull(env) {
  const today = todayUTC();
  const key = `anticipator:budget:${today}`;
  const cents = Number(await env.MOD_KV.get(key) || '0');
  const ceiling = Number(await env.MOD_KV.get('thresholds.ai.anticipator.dailyCeiling') || '200');
  if (cents >= ceiling) return { rate_limited: true, spent_cents: cents, ceiling_cents: ceiling };
  return null;
}

async function incrementAiBudget(env, cents) {
  const today = todayUTC();
  const key = `anticipator:budget:${today}`;
  const cur = Number(await env.MOD_KV.get(key) || '0');
  await env.MOD_KV.put(key, String(cur + cents), { expirationTtl: 60 * 60 * 48 });
}

function todayUTC() {
  const d = new Date();
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth()+1).padStart(2,'0')}-${String(d.getUTCDate()).padStart(2,'0')}`;
}
```

`expirationTtl` of 48h means the key auto-vanishes two days after creation — no manual cleanup needed. Daily ceiling default 200 cents ($2). Lead-token holders can PUT `thresholds.ai.anticipator.dailyCeiling` via the existing settings-update path (not a new endpoint).

Cost-table applied by callers (conservative cents-per-call estimates):
- `/ai/bootstrap-draft` (grok-3-mini, 80-token cap): 1 cent.
- `/ai/rag-search` (grok-3 with 3 citations): 3 cents.
- `/ai/tag-thread` (thin classifier): 1 cent.
- Embedder (bge, free tier): 0 cents (but still gated so embedder pauses on exhaustion).
- Intent-tagger cron branch: 1 cent per classified thread.

**Success condition:** With `MOD_KV.put('thresholds.ai.anticipator.dailyCeiling','10')` (10 cents = near-immediate exhaustion), three `/ai/bootstrap-draft` calls land: first two succeed, third returns `{rate_limited:true}`. Status bar in the extension shows `AI rate-limited`.
**If fails:** race on the `get`/`put` pair — two concurrent calls may both read the same cents value before either writes. For v7.2 accept the small over-shoot; v7.3 can introduce DO-backed atomic counters.

---

## CHUNK 10 — Extension: `features.anticipator` flag + settings scaffold

File: `modtools.js`. Locate `DEFAULT_SETTINGS` (grep for it). Add:

```js
features: {
  ...existing,
  anticipator: false,   // v7.2: gates ghost-text + glowing envelope
},
thresholds: {
  ...existing,
  ai: {
    ...existing.ai,
    drafts: {
      high: { confidence: 0.80, similarity: 0.85 }
    },
    anticipator: {
      dailyCeiling: 200,           // cents; lead-editable
      bootstrapDebounceMs: 800,
      bootstrapMinWords: 3,
    }
  }
},
```

`getSetting('features.anticipator', false)` is the single gate. Every client-side v7.2 code path checks this first and short-circuits when false.

Also add a status-bar line-item renderer: an envelope glyph (default state) that is hidden until `features.anticipator` is true AND the current `/modmail/inbox` poll has returned at least one thread with `has_ai_draft=1`. When those conditions are met, envelope glows (star variant). Click handler: find the first such thread and open `IntelDrawer.open({kind:'thread', id:thread.thread_id})`.

**Success condition:** With `features.anticipator` false, status bar has no envelope glyph. With `features.anticipator` true AND a seeded `thread_drafts` row matching the current inbox poll, envelope animates and click opens the drawer.
**If fails:** check the poll payload shape — if v7.1 doesn't include `has_ai_draft` in the thread list response, extend the `/modmail/inbox` handler in the worker to join `thread_drafts` and include the flag.

---

## CHUNK 11 — Extension: typing-debounce helper + ghost-text overlay

File: `modtools.js`. Single helper usable across all textareas, written once, called many times.

```js
function attachBootstrapGhostText(textarea, { thread_id, user } = {}) {
  if (!getSetting('features.anticipator', false)) return;
  if (textarea._gamGhostAttached) return;
  textarea._gamGhostAttached = true;

  const debounceMs = getSetting('thresholds.ai.anticipator.bootstrapDebounceMs', 800);
  const minWords = getSetting('thresholds.ai.anticipator.bootstrapMinWords', 3);

  let currentAbort = null;
  let ghostSpan = null;
  let timer = null;

  const clearGhost = () => {
    if (ghostSpan) { ghostSpan.remove(); ghostSpan = null; }
    if (currentAbort) { currentAbort.abort(); currentAbort = null; }
  };

  const fire = async () => {
    const partial = textarea.value;
    const wc = partial.split(/\s+/).filter(Boolean).length;
    if (wc < minWords) return;
    clearGhost();
    currentAbort = new AbortController();
    try {
      const resp = await workerCall('/ai/bootstrap-draft', {
        method: 'POST',
        body: JSON.stringify({ partial_text: partial, context: { thread_id, user } }),
        signal: currentAbort.signal,
      });
      if (!resp || resp.rate_limited || !resp.continuation) return;
      renderGhost(textarea, resp.continuation);
    } catch (e) {
      if (e.name !== 'AbortError') console.warn('[anticipator] bootstrap', e);
    }
  };

  textarea.addEventListener('input', () => {
    clearGhost();
    if (timer) clearTimeout(timer);
    timer = setTimeout(fire, debounceMs);
  });
  textarea.addEventListener('keydown', (e) => {
    if (e.key === 'Tab' && ghostSpan) {
      e.preventDefault();
      textarea.value = textarea.value + ghostSpan.textContent;
      clearGhost();
    } else if (e.key !== 'Shift' && e.key !== 'Meta' && e.key !== 'Control' && e.key !== 'Alt') {
      if (ghostSpan) clearGhost();
    }
  });
  textarea.addEventListener('blur', clearGhost);
}

function renderGhost(textarea, continuation) {
  // Build an absolute-positioned overlay span after the cursor. textContent only — no innerHTML.
  const rect = textarea.getBoundingClientRect();
  const span = el('span', {
    cls: 'gam-ghost-text',
    style: `position:absolute; top:${rect.top + window.scrollY}px; left:${rect.left + window.scrollX}px; width:${rect.width}px; padding:${getComputedStyle(textarea).padding}; font:${getComputedStyle(textarea).font}; color:#718096; opacity:.55; pointer-events:none; user-select:none; white-space:pre-wrap; z-index:2147483500;`,
  });
  // Prefix with the textarea's current value so the ghost renders AFTER the cursor.
  span.textContent = textarea.value + continuation;
  // The user's own text needs to be invisible in the overlay (only the continuation should "show");
  // simplest approach: leave user's text matching the textarea's own color so it double-paints;
  // the reduced opacity only affects the continuation via a nested span with higher opacity on the prefix.
  document.body.appendChild(span);
  textarea._gamGhostSpan = span;
}
```

Overlay rendering is the fiddliest part; acceptable refinements during implementation: canvas-measured caret position, MutationObserver on textarea scroll, nested span where only the continuation has `.55` opacity and the mirrored prefix is fully transparent. Ship the simplest version that looks right in Commander's dogfood session; iterate in v7.2.1 if needed.

Call sites: wherever the extension attaches to a modmail reply textarea (grep for existing `#mc-msg-body` handling; attach `attachBootstrapGhostText(textarea, {thread_id})` after the textarea is mounted).

**Success condition:** With `features.anticipator` true, typing "Hi thanks for" into a modmail reply textarea produces ghost text within ~1 second. Tab accepts. Typing a new character discards. Moving to a different reply textarea attaches a fresh instance; aborting the previous in-flight call.
**If fails:** if ghost text misaligns visually, leave the mechanic working and ship with a warning label in the drawer — alignment polish is v7.2.1.

---

## CHUNK 12 — Extension: intent chip on modmail rows

File: `modtools.js`. Extend the existing modmail-list row renderer. For each thread row, if the worker-returned thread has `intent` populated, prepend a `stateChip({kind:'intent', value: thread.intent})` to the existing chip row. Add CSS classes using the same palette family as v7.0 state chips:

```css
.gam-chip--intent-appeal      { background:var(--chip-bg-blue);   color:var(--chip-fg-blue); }
.gam-chip--intent-complaint   { background:var(--chip-bg-amber);  color:var(--chip-fg-amber); }
.gam-chip--intent-crisis      { background:var(--chip-bg-red);    color:#fff; animation: gam-chip-pulse 2s infinite; }
.gam-chip--intent-spam        { background:var(--chip-bg-neutral);color:var(--chip-fg-neutral); opacity:.7; }
.gam-chip--intent-allycheckin { background:var(--chip-bg-purple); color:var(--chip-fg-purple); }
.gam-chip--intent-question    { background:var(--chip-bg-blue);   color:var(--chip-fg-blue); }
.gam-chip--intent-report      { background:var(--chip-bg-amber);  color:var(--chip-fg-amber); }
.gam-chip--intent-other       { background:var(--chip-bg-neutral);color:var(--chip-fg-neutral); }
```

Intent chip renders regardless of `features.anticipator` (the chip is read-only corpus surface — it doesn't spend AI budget at render time). This gives Commander visual confirmation that the tagger is working, even before enabling the anticipator flag.

The worker-side `/modmail/inbox` proxy response must include `intent` per thread — verify the existing handler; if it projects only a subset of columns, extend the SELECT.

**Success condition:** After the tagger has run enough ticks to label N threads, reloading the modmail list shows intent chips on exactly those N rows. Crisis-labeled rows pulse.
**If fails:** check that `/modmail/inbox` actually selects the `intent` column; grep the worker handler for the SELECT list and extend.

---

## CHUNK 13 — Extension: envelope glow + drawer section 5 Accept/Edit/Reject

File: `modtools.js`. Status bar glyph:

```css
.gam-statusbar-envelope { font-size:14px; margin-left:8px; transition: transform .2s; }
.gam-statusbar-envelope--glow { animation: gam-envelope-glow 2s infinite; filter: drop-shadow(0 0 4px #faf089); }
@keyframes gam-envelope-glow { 0%,100% { transform: scale(1); } 50% { transform: scale(1.15); } }
```

Render logic (inside the existing status-bar poll pass): if `features.anticipator` is true AND the latest `/modmail/inbox` response contains any thread with `has_ai_draft === 1`, render the envelope with the `.gam-statusbar-envelope--glow` class, glyph `[*]` (star-envelope composite). Else if there's any inbox thread at all, render plain envelope glyph `[M]`. Else hide.

Click handler: find first thread with `has_ai_draft === 1`; call `IntelDrawer.open({kind:'thread', id:thread.thread_id, seedData:{hasAiDraft:true}})`.

Drawer Section 5 extension: the existing section-5 renderer (v7.0 "What ModTools recommends") gets a new code branch — if `seedData.hasAiDraft === true` OR if `/drafts/thread/read` returns a live draft, render:

- Heading: "AI-drafted reply" (instead of "Next best action").
- Body: the `draft_body` shown in a textarea, editable in place.
- Under the draft: "Why this draft" block listing the three `cited_case_ids` as clickable chips. Clicking a chip calls `IntelDrawer.open({kind:'thread', id:citedId})` — drawer nesting via the existing v7.0 backspace-history stack.
- Footer buttons: `Accept` / `Edit` / `Reject`.
  - Accept: copies `draft_body` into the modmail reply textarea (locate via existing `#mc-msg-body` selector or its modern equivalent), closes drawer, focuses textarea. Does NOT send.
  - Edit: same as Accept but leaves drawer open and focuses the textarea with caret at the end.
  - Reject: fires `POST /drafts/thread/reject` with `{thread_id, rejected_case_ids}`. On success, closes drawer; envelope stops glowing next poll cycle.

All button text and chip content pass through `escapeHtml()` or are set via `textContent`. Grep must show no raw-innerHTML injection of `draft_body` or `cited_case_ids`.

**Success condition:** A thread seeded with a `thread_drafts` row causes the envelope to glow; click opens the drawer; Accept copies text into the reply field; Edit leaves drawer open; Reject removes the draft and the envelope stops glowing.
**If fails:** if the reply textarea selector has changed in v7.1 super-mod refactor, read `modtools.js` for the new selector and adapt; do not hardcode the old one blindly.

---

## CHUNK 14 — `run-modmail-backfill.ps1`

File: `D:\AI\_PROJECTS\run-modmail-backfill.ps1`. Manual-trigger script for the initial crawl burst (the conservative 1-page/5-min cron default would take weeks on a large archive; Commander can crank it briefly for the seed run).

Script does:
1. Pre-flight: Node, wrangler.toml present, prompt for Cloudflare API token if absent.
2. Prompt via `Read-Host`: "How many pages per cron tick during the backfill window? (default 5, max 20)". Validate integer in range.
3. `npx --yes wrangler@latest kv key put --binding=MOD_KV "anticipator:crawl:pagesPerTick" "<N>" --remote` (no angle brackets in the actual command — variable `$N` interpolated).
4. Prompt: "How many minutes to leave the high rate active? (default 60, max 180)". Validate.
5. Fire-and-forget schedule a reset: use a scheduled task or simply instruct the user to re-run with value 1 after the window. v7.2 does NOT automate the reset; script prints a reminder + stages a clipboard-ready reset command.
6. 4-step mandatory ending: structured report (pages-per-tick set, estimated pages/hour, reset reminder), `$log | Set-Clipboard`, E-C-G beep, `Read-Host 'Press Enter to exit'`.
7. Log persist: `D:\AI\_PROJECTS\logs\run-modmail-backfill-YYYYMMDD-HHMMSS.log`.

BOM + ASCII + parse-check both before and after BOM-sanitize.

**Success condition:** Running the script sets the KV key; `wrangler kv key get --binding=MOD_KV anticipator:crawl:pagesPerTick --remote` returns the chosen value.
**If fails:** if wrangler rejects the key name containing a colon in some PowerShell-quoting edge case, wrap in double quotes and verify the command with the parser.

---

## CHUNK 15 — `verify-v7.2.ps1`

File: `D:\AI\_PROJECTS\verify-v7.2.ps1`. BOM + ASCII + 4-step ending. PowerShell 5.1-compatible.

Script performs, in order (any failure short-circuits with exit 2 after the log summary):

1. **Precondition — v7.1 marker.** Read `D:\AI\_PROJECTS\modtools-ext\modtools.js`; grep for literal string `features.superMod`. If not found: `PRECONDITION FAILED: v7.1 marker missing — ship v7.1 before v7.2`, exit 2.
2. **Manifest version == 7.2.0.** Parse `modtools-ext/manifest.json`, assert `.version === "7.2.0"`.
3. **Vectorize index exists.** `npx --yes wrangler@latest vectorize list --json` — parse JSON, assert an item with `name == "gaw-modmail"` and `dimensions == 768` and `metric == "cosine"`.
4. **D1 migration applied.** `wrangler d1 execute gaw-mod-audit --remote --command "PRAGMA table_info(thread_drafts)"` — assert non-empty output. Repeat for `draft_rejections`, `modmail_threads` (must show `intent` and `embedding_id` columns), `modmail_messages`.
5. **KV cursor key exists after allowing a couple minutes.** `wrangler kv key get --binding=MOD_KV "modmail:crawl:cursor" --remote` — assert either a valid JSON with `nextPage` or the string `"DONE"`.
6. **Endpoint smoke tests.** Using a mod token from `$env:GAW_MOD_TOKEN`: POST `/ai/bootstrap-draft` with `{partial_text:"Thanks for reaching out about"}` — assert response has either `continuation` or `rate_limited:true`. POST `/ai/rag-search` with a known-seeded `thread_id` — assert the same. GET `/drafts/thread/read?thread_id=<SEED>` — assert structure.
7. **Rate-limit enforcement.** Temporarily set the ceiling low via `wrangler kv key put thresholds.ai.anticipator.dailyCeiling 0`; next bootstrap-draft call must return `{rate_limited:true}`. Restore ceiling to 200.
8. **Grep guards.** Grep `modtools.js` for `innerHTML = .*\$\{` inside the drawer section-5 and ghost-text blocks — must be zero hits. Grep for `@cf/baai/bge-base-en-v1.5` — must be present in worker. Grep worker for `<untrusted_user_content>` inside every AI handler (bootstrap-draft, rag-search, tag-thread).
9. **PRIVACY.md.** `gaw-dashboard\public\PRIVACY.md` contains literal `## v7.2 data categories`.
10. **CWS ZIP size.** Build the ZIP to `D:\AI\_PROJECTS\dist\gaw-modtools-v7.2.zip`, assert size < 215 KB.

Structured final report (per the PowerShell rule): PASS/FAIL per check, total runtime, any remediation hints on failure. `$log | Set-Clipboard`. E-C-G beep. `Read-Host 'Press Enter to exit'`. Log persisted to `D:\AI\_PROJECTS\logs\verify-v7.2-YYYYMMDD-HHMMSS.log`.

**Success condition:** All checks PASS, exit 0.
**If fails:** the exact check that failed is the next thing to fix; do not attempt to "best-effort pass" a check by loosening the assertion.

---

## CHUNK 16 — PRIVACY.md append

File: `D:\AI\_PROJECTS\gaw-dashboard\public\PRIVACY.md`. Append (do not overwrite) a new section:

```markdown
## v7.2 data categories

v7.2 introduces a historical modmail corpus plus derived artifacts that enable anticipatory assistance features.

### Historical modmail corpus
- **Raw HTML:** stored in R2 under `gaw-mod-evidence/modmail/{thread_id}.html`.
- **Parsed rows:** stored in D1 tables `modmail_threads` and `modmail_messages`.
- **Retention:** indefinite, treated as audit-class evidence under the same policy as post/comment evidence snapshots. Subject to right-of-erasure requests per the existing evidence-retention section above.
- **Access:** mod-token gated for read; ingestion is worker-only.

### Embeddings
- **Storage:** Cloudflare Vectorize index `gaw-modmail`, 768 dimensions, cosine metric, produced by `@cf/baai/bge-base-en-v1.5`.
- **Metadata per vector:** `{thread_id, message_id, direction, sent_at, intent}`.
- **Retention lifecycle:** bound to the corpus — if a modmail message row is purged from D1 for erasure, its embedding is deleted from Vectorize in the same operation.
- **Access:** worker-side only; no endpoint returns raw vectors.

### Intent labels
- **Storage:** D1 columns `modmail_threads.intent` and `modmail_threads.intent_confidence`.
- **Labels:** appeal, complaint, crisis, spam, allycheckin, question, report, other.
- **Model:** the existing grok-3 thin classifier; input wrapped in `<untrusted_user_content>`.
- **Retention lifecycle:** bound to the corpus.

### Draft rejections
- **Storage:** D1 table `draft_rejections` with columns `{thread_id, rejected_case_ids (JSON), rejected_at, rejected_by}`.
- **Purpose:** feedback signal to down-weight historical cases that repeatedly produce bad drafts.
- **Retention:** 90 days, purged automatically by the existing evidence-retention cron.
- **Access:** mod-token gated write path; lead-token required to read in bulk.

### Daily AI budget
- Tracked in KV `anticipator:budget:${UTC-date}` with 48-hour TTL.
- Daily ceiling default $2 (200 cents), lead-editable via `thresholds.ai.anticipator.dailyCeiling`.
- Exceeding the ceiling silently disables `/ai/bootstrap-draft`, `/ai/rag-search`, `/ai/tag-thread`, and the embedder cron branch until UTC midnight. The extension surfaces an `AI rate-limited` hint.
```

**Success condition:** The section exists verbatim; `verify-v7.2.ps1` check 9 passes.
**If fails:** straight-forward — re-append the section if a prior merge removed it.

---

## ROLLOUT PROTOCOL

1. Land CHUNK 1 (migration) + CHUNK 2 (Vectorize setup) first. Run `setup-vectorize.ps1` and apply `009_anticipator_corpus.sql`. No extension changes yet.
2. Land CHUNKS 3, 4, 5 (crawler + embedder + tagger cron branches) worker-side. Deploy. Watch `wrangler tail` for 30 minutes. Verify cursor advances, R2 fills, D1 rows appear, vectors appear, intents label. No extension changes yet — this phase is entirely silent to users.
3. Let the backfill run at the default 1-page/5-min rate for 24-48 hours, or run `run-modmail-backfill.ps1` briefly at 5-20 pages/tick to accelerate the seed. Verify corpus quality by eyeballing `SELECT intent, count(*) FROM modmail_threads GROUP BY intent` for plausible distribution.
4. Land CHUNKS 6, 7, 8, 9 (endpoints + budget helpers) worker-side. Deploy. Smoke-test endpoints manually with curl / the verify script. Corpus is now queryable but still invisible.
5. Land CHUNKS 10, 11, 12, 13 (extension) with `features.anticipator: false` by default. Deploy. Reload the extension. Confirm no anticipator behavior is visible.
6. Commander flips `features.anticipator` true for his own install via `chrome.storage.local.set`. Dogfood one modmail shift solo. Watch for: ghost text appearing at the right moment, envelope glow on high-confidence threads, intent chips on rows, Accept/Edit/Reject working.
7. After a clean solo shift: roll the flag out to the other 2-4 mods one at a time, each dogfooding a shift before the next flips.
8. If the daily $2 ceiling is hit regularly, Commander tunes `thresholds.ai.anticipator.dailyCeiling` up. If ghost-text quality is poor, tighten the grok prompt (CHUNK 7) without changing the interface.

---

## OUT OF SCOPE for v7.2 (explicitly deferred)

- Per-mod budget partitioning (whole team shares one daily pool in v7.2; v7.3 may split).
- Outbound-reply-only embedding filter in the embedder (v7.2 embeds everything; rag-search filters at query time by metadata direction).
- Model upgrade beyond `bge-base-en-v1.5` (v7.3+ concern — requires reindex).
- Full DO-backed atomic budget counter (v7.2 accepts small over-shoot on concurrent isolates).
- ML-based ranking (v7.2 uses rejection_count as a linear penalty; no gradient descent).
- Auto-send on Accept (v7.2 explicit: Accept copies text, the mod still hits send).
- j/k navigation inside drawer section 5 cited-cases chips (v7.3).
- Ghost-text alignment polish for textareas with custom fonts or scrollable containers (v7.2.1).

---

**End of GIGA-V7.2-THE-ANTICIPATOR.**
