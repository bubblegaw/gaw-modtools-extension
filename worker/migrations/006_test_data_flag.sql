-- ============================================================================
-- Migration 006: Test-data flag column on all seedable tables
-- ----------------------------------------------------------------------------
-- Every row the seed endpoint inserts gets is_test=1. The flush endpoint
-- removes is_test=1 rows only, leaving genuine production data untouched.
-- Production reads do NOT filter by this column -- test rows are tagged
-- visibly in their text fields (title prefix [TEST], summary with TEST:, etc)
-- so UI dashboards show them inline during demo, and flushing wipes them.
-- ============================================================================

ALTER TABLE gaw_posts              ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE gaw_comments           ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE gaw_users              ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE modmail_threads        ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE modmail_messages       ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE modmail_meta           ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE bot_feature_requests   ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE bot_polls              ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE bot_poll_votes         ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE bot_commander_decisions ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE bot_ai_audit           ADD COLUMN is_test INTEGER DEFAULT 0;
ALTER TABLE actions                ADD COLUMN is_test INTEGER DEFAULT 0;
