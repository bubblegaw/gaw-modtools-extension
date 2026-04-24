# Changelog

All notable changes to this project are documented in this file.

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
