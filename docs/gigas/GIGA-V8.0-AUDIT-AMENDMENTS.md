# GIGA-V8.0 Audit Amendments

**Context:** Two additional master reports (observability audit + AI safety audit) landed after the v8.0 GIGA was drafted. These amendments are non-optional additions to the original `GIGA-V8.0-TEAM-PRODUCTIVITY.md`. The builder reads both files and satisfies both sets of constraints.

**Source:**
- `C:\Users\smoki\Downloads\modtools_observability_audit_report.md`
- `C:\Users\smoki\Downloads\modtools_ai_safety_audit_report.md`

---

## AMENDMENT A — Observability instrumentation (additive to every v8.0 chunk)

Every new worker call shipped by v8.0 MUST be instrumented. This is a cross-cutting requirement, not a separate chunk.

### A.1 Request correlation headers

`workerCall` (the dispatching one added in v7.2) gains three new headers on every call:
- `X-GAM-Request-Id` — `crypto.randomUUID()` per call
- `X-GAM-Session-Id` — one UUID per content-script boot, stored on `window.__v72.SESSION_ID`
- `X-GAM-Feature` — derived from path via `inferFeatureFromPath(path)` (e.g. `/proposals/*` → `proposal`, `/drafts/*` → `draft`, `/ai/*` → `ai`, `/audit/*` → `audit`, `/parked/*` → `parked`, `/shadow/*` → `shadow_queue`)

Flag gate: when `features.platformHardening=true`, these headers ship. Flag off, they don't. No new flag is introduced.

### A.2 Structured event emitter

Add `emitEvent(level, event, fields)` to `window.__v72` per the observability audit section 4.A. 500-entry ring buffer in `localStorage.gam_telemetry_buffer`. Used by:
- `worker_call.start` / `worker_call.finish` (auto-emitted from `workerCall`)
- Shadow Queue badge decisions (`shadow.pre_decide.{success,failure,abort}`)
- Park button lifecycle (`park.{create,resolve,cancel}`)
- Precedent-citing ban flow (`ban.{draft_generated,sent,verified,verify_failed}`)

Debug snapshot exporter pulls the ring buffer into bug reports.

### A.3 Metrics emission on every v8.0 AI call

Worker-side `/ai/shadow-triage` and `/ai/next-best-action` (extended) must emit structured JSON logs per the observability audit section 4.A:
```
{ts, level:'info', event, request_id, mod, path, status, latency_ms, model, provider, rate_limited}
```

Client-side records the equivalent via `emitEvent`. Both sides share the request_id so logs correlate.

---

## AMENDMENT B — AI safety guardrails (modifies Shadow Queue + Precedent Citation behavior)

### B.1 Shadow Queue — two-key commit, not one-key auto-pilot

The original v8.0 GIGA's Shadow Queue `Space`-to-confirm flow directly collides with the AI safety audit's #1 CRITICAL finding: *"AI may not directly finalize bans/removes/notes/watchlist writes without explicit human confirmation."*

**Replacement design:**

1. Badge renders on queue row (unchanged): `✓ APPROVE 92%` / `🗑 REMOVE 88%` / etc.
2. First `Space` keypress: **does NOT execute**. Instead, it expands the row inline to show the AI's evidence payload (see B.2). The action button becomes focused. The badge changes color to signal "ready to commit."
3. Second `Enter` keypress: commits the pre-decided action.
4. Any key other than Enter on the expanded row cancels and collapses.

This preserves the speed win (two keys instead of mouse-hunt-and-click) while satisfying the audit's explicit-human-confirmation-layer requirement.

### B.2 AI output schema — evidence-backed, not bare verdict

The `/ai/shadow-triage` endpoint MUST return:
```
{
  decision: 'APPROVE' | 'REMOVE' | 'WATCH' | 'DO_NOTHING',
  confidence: 0..1,
  evidence: [{source: 'comment' | 'post' | 'history', id: string, excerpt: string}, ...],  // REQUIRED, non-empty for non-DO_NOTHING
  counterarguments: [string],                                                               // alternate interpretations
  rule_refs: [string],                                                                      // cited rule IDs
  prompt_version: string,
  model: string,
  provider: string,
  rules_version: string,
  generated_at: number
}
```

Client-side: if `evidence` array is empty OR `confidence < 0.85`, the badge is suppressed. Item falls through to manual triage. NO silent-high-risk path.

`/ai/next-best-action` (extended v8.0 use) gets the same schema.

### B.3 Precedent citation must cite RULE + OUTCOME, never user ID

Already in the v8.0 GIGA but reinforced by audit: the precedent-citing ban message cites by **rule reference + outcome count**, NOT by prior user ID. The audit calls out user-ID citations as a doxxing vector. Ensure worker SQL for precedent lookup returns aggregate counts + rule refs, never usernames.

### B.4 Daily AI scoring cleanup (pre-existing CRITICAL surfaced by audit)

**This is pre-existing code, not v8.0 scope, but the audit's CRITICAL finding requires fix within the v8.0 ship window.**

Current behavior at `modtools.js:7414-7421` writes directly to watchlist on `risk >= 70`. Replace with `enqueueAiReview({username, aiRisk, aiReason, source:'daily-ai', model, promptVersion})` that lands in a new `ai_suspect` queue state. Human must explicitly promote to watchlist.

New D1 table `ai_suspect_queue` (add to migration 013):
```sql
CREATE TABLE IF NOT EXISTS ai_suspect_queue (
  username TEXT PRIMARY KEY,
  ai_risk INTEGER,
  ai_reason TEXT,
  source TEXT,
  model TEXT,
  prompt_version TEXT,
  enqueued_at INTEGER NOT NULL,
  reviewed_at INTEGER,
  reviewed_by TEXT,
  disposition TEXT  -- 'watched' | 'cleared' | 'banned' | 'ignored'
);
```

v8.0 Park button UI gains an optional filter to surface these suspects in the lead's review pool.

### B.5 AI output provenance stamp

Every AI response rendered to the mod UI must carry a "Why this?" affordance that reveals `{model, provider, prompt_version, rules_version, generated_at}` in a tooltip. Surfaces in drawer section 5, Shadow Queue badge hover, and ban-message draft header.

---

## AMENDMENT C — Post-build verification (builder must execute)

After all v8.0 chunks pass static verification, the builder MUST perform these integration checks before declaring SUCCESS. Commander explicitly requested these.

### C.1 Database integrity sweep

Run `wrangler d1 execute gaw-audit --remote --command=<SQL>` for each:

1. **Orphan check on proposals → mod_tokens:**
   ```sql
   SELECT COUNT(*) FROM proposals WHERE proposed_by NOT IN (SELECT mod_username FROM mod_tokens);
   ```
   Expected: 0 after import. Any non-zero = mod-token import incomplete.

2. **Foreign-key integrity across all v7.x tables:** sample a JOIN between every referencing pair, assert no broken references. Tables: `drafts`, `proposals`, `claims`, `team_features`, `bug_reports`, `mod_tokens`, `precedents`, v8.0 additions.

3. **Index presence:**
   ```sql
   SELECT name, sql FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%';
   ```
   Assert every table has the expected indexes from its migration file.

4. **Row count sanity:** each table should have a reasonable row count (not zero unless expected, not absurdly high).

5. **DR idempotency index validation:**
   ```sql
   SELECT sql FROM sqlite_master WHERE name='idx_actions_dr_idempotency';
   ```
   Must contain `WHERE dr_scheduled_at IS NOT NULL`.

Report format: table-of-tables with row count + index count + any anomalies.

### C.2 Multi-mod sync simulation

Using Commander's existing lead token (from environment or asking Commander to provide via setup script once on post-build), and a freshly-minted second-mod token imported via `/admin/import-tokens-from-kv`:

1. **Auto-DR propagation test:**
   - POST as token A: add a new auto-DR rule via `/pullPatternsFromCloud` / `/pushPatternsToCloud` (or whatever the v7.x endpoint shape is — grep for it).
   - GET as token B: verify the rule appears.
   - Reverse direction.

2. **Cross-mod draft test:**
   - POST as token A: write a draft via `/drafts/write`.
   - GET as token B: `/drafts/list` or `/drafts/read` — draft visible with `last_editor=mod_A`.
   - POST as token B: takeover via `/drafts/handoff`. Verify `last_editor=mod_B` on next read.

3. **Propose Ban end-to-end test:**
   - POST as token A: `/proposals/create` with `kind='ban', target='<testuser>'`.
   - GET as token B: `/proposals/list` — proposal visible, `status='pending'`.
   - POST as token B: `/proposals/vote` with `action='execute'`. (DO NOT actually execute a real ban — use a synthetic target username like `__test_user_xyz__` that's guaranteed not to exist.)
   - GET: proposal `status='executed'`.

4. **Park button end-to-end test:**
   - POST as token A: `/parked/create` with a synthetic subject.
   - GET as token B: `/parked/list` — item visible.
   - POST as token B: `/parked/resolve`.
   - Verify Discord webhook fired (if configured).

Report format: per-test PASS/FAIL with the curl command + HTTP response.

### C.3 Shadow Queue AI contract test

POST to `/ai/shadow-triage` with a synthetic payload. Assert response schema matches B.2: `decision`, `confidence`, `evidence[]`, `counterarguments[]`, `rule_refs[]`, `prompt_version`, `model`, `provider`, `rules_version`, `generated_at`. Assert `evidence` is non-empty for non-DO_NOTHING decisions. Assert `confidence` is a number in [0,1].

---

## Ordering

- AMENDMENTS A and B are BUILD-TIME additions woven into the existing 15-chunk v8.0 GIGA. No new chunks — extend existing chunks' acceptance criteria.
- AMENDMENT C runs POST-BUILD, before declaring SUCCESS. If any C-check fails, the build is marked PARTIAL with the failure noted.
- AMENDMENT B.4 (daily AI scoring cleanup) adds to migration 013 but does NOT block the v8.0 feature chunks — it's a parallel track that ships in the same release.

---

## Rollback story for v8.0

If any chunk fails 3x → standard escalation. If post-build C-checks fail → the ZIP is still built (rollbackable), but the report is PARTIAL and Commander decides whether to publish or wait for fixes.

Snapshots saved before v8.0 build:
- `modtools.js.v7.2.0.bak`
- `background.js.v7.2.0.bak`
- `popup.js.v7.2.0.bak`
- `manifest.json.v7.2.0.bak`
- `gaw-mod-proxy-v2.js.v7.2.0.bak`

To fully roll back: restore all five, revert v8.0-specific commits, revert version to 7.2.0, rebuild ZIP.
