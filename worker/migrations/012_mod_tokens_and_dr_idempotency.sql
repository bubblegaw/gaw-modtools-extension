-- ============================================================================
-- Migration 012: Mod tokens table + DR (dead-reckoning) idempotency index
-- ----------------------------------------------------------------------------
-- Adds:
--   1. mod_tokens table -- per-mod auth tokens, replacing single-shared-secret
--      model. Lead mods flagged via is_lead=1.
--   2. actions.dr_scheduled_at column -- records when a DR action was scheduled
--      so we can dedupe identical DR actions (same target + same schedule time).
--   3. Unique index on (target_user, dr_scheduled_at) for the actions table,
--      so re-submitting the same DR is a no-op at DB level.
--
-- Idempotency notes:
--   - CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS are safe to
--     re-run.
--   - ALTER TABLE ADD COLUMN is NOT idempotent in SQLite (no IF NOT EXISTS
--     supported for columns). The runner (setup-mod-tokens.ps1) swallows the
--     "duplicate column name" error on re-run.
-- ============================================================================

-- 1. mod_tokens table
CREATE TABLE IF NOT EXISTS mod_tokens (
    token TEXT PRIMARY KEY,
    mod_username TEXT NOT NULL,
    is_lead INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_mod_tokens_username ON mod_tokens(mod_username);

-- 2. actions.dr_scheduled_at column (idempotency key component for DR actions)
-- NOTE: SQLite has no "ADD COLUMN IF NOT EXISTS". Runner must tolerate the
-- "duplicate column name: dr_scheduled_at" error on re-run.
ALTER TABLE actions ADD COLUMN dr_scheduled_at INTEGER;

-- 3. Unique index enforcing DR idempotency:
--    (target_user, dr_scheduled_at) is unique when dr_scheduled_at IS NOT NULL.
--    SQLite treats NULL as distinct from every other NULL in unique indexes,
--    so rows with dr_scheduled_at IS NULL (i.e. non-DR actions) are ignored
--    by this constraint.
CREATE UNIQUE INDEX IF NOT EXISTS idx_actions_dr_idempotency
    ON actions(target_user, dr_scheduled_at)
    WHERE dr_scheduled_at IS NOT NULL;
