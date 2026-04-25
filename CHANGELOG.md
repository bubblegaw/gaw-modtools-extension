# Changelog

All notable changes to this project are documented in this file.

## Worker [8.3.0] - 2026-04-25

Worker-only release; extension client code unchanged. Backward-compatible with v8.2.x clients.

### Added
- `safeJson()` body-size cap (256 KB default, 1 MB on firehose ingest endpoints) returns 413 on oversize payloads.
- KV-backed per-mod AI minute rate-limit (`ai_minute_<caller>_<bucket>`, 20/min, TTL 120s) on `/ai/score`, `/ai/grok-chat`, `/ai/ban-suggest`, `/ai/next-best-action`, `/ai/shadow-triage`.
- Per-provider circuit breaker (`cb_state_<provider>` in KV; opens at 5 failures in 60s, half-opens after 30s).
- AI strict-prefer fallback chain across `/ai/score`, `/ai/grok-chat`, `/ai/ban-suggest` — caller passes `prefer: 'claude'|'grok'|'llama'`; worker tries that provider first, then falls back in stable order with Llama always last. Response includes `provider` and `fallback_count`.
- Anthropic Claude 3.5 Haiku as a third AI provider (uses new `ANTHROPIC_API_KEY` worker secret).
- `discord_retry_queue` D1 table (migration 017) + `discordWebhookSend()` wrapper that enqueues failed webhook POSTs with exponential backoff (30s base, 6 attempts max).
- `discordRetryDrain()` runs on every cron tick; abandons rows after `max_attempts`.
- `/discord/retry/drain?force=1` (lead-only) for on-demand drain verification.
- Hot-path D1 indexes (migration 016): `actions(target_user, ts)`, `actions(action, ts)`, `actions(mod, ts)`, `actions(ts)`, `precedents(action, marked_at)`, `bot_feature_requests(status)`.

### Security / Reliability
- CORS allow-origin lockdown for `/admin/*`, `/bot/register-commands`, `/bot/mods/add`, `/bot/mods/remove` — only `https://greatawakening.win` and `https://www.greatawakening.win` accepted; non-allowlisted browser callers blocked at preflight + server-side gate (403).
- `/health` and `/dashboard/summary` now report the live `WORKER_VERSION` constant instead of stale hardcoded strings.
- `handleAiNextBestAction` and `handleAiShadowTriage` instrumented with circuit-breaker recording on xAI failures; multi-provider refactor for these structured-JSON handlers deferred to v8.3.1.

### Migrations
- **016_hot_path_indexes.sql** — pure CREATE INDEX IF NOT EXISTS, idempotent.
- **017_discord_retry_queue.sql** — new table with two partial indexes for the drain query.

## [8.2.7] - 2026-04-24

Based on: `8.2.6`

### Fixed
- Persisted mod-token state reliably across refresh/restart by syncing token writes between popup secure-save flow, background vault, and durable `chrome.storage.local`.
- Prevented partial token updates from clobbering existing secrets (lead-token writes no longer clear team-token state).
- Restored onboarding recovery behavior when token is truly missing, including reload-time prompt paths and 401-triggered recovery checks.
- Corrected Firehose auth to use the canonical team token getter (`workerModToken`) instead of an invalid settings key.
- Added session-to-local token recovery on content-script boot when legacy/session-only token state is detected.
- Fixed Settings panel render failures caused by invalid DOM IDs for dotted feature keys (for example `features.drawer`).

### Security / Reliability
- Background vault now falls back to durable local settings when session storage is empty after worker restart.
- Token relay update semantics now support field-preserving partial updates.
