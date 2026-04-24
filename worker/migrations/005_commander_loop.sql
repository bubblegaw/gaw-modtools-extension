-- ============================================================================
-- GAW ModTools Worker -- Migration 005: Commander Review Loop
-- ============================================================================
-- Adds the amend/punt/approve/reject decision loop between auto-finalize and
-- the prompt actually reaching Claude Code. Status transitions:
--   polling -> commander_review -> (finalized | amended | polling | rejected)
-- ============================================================================

ALTER TABLE bot_feature_requests ADD COLUMN commander_comments  TEXT;
ALTER TABLE bot_feature_requests ADD COLUMN iteration_count     INTEGER DEFAULT 0;
ALTER TABLE bot_feature_requests ADD COLUMN commander_decided_at INTEGER;
ALTER TABLE bot_feature_requests ADD COLUMN review_message_id   TEXT;

-- Decision audit - every button press logged for accountability.
CREATE TABLE IF NOT EXISTS bot_commander_decisions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  feature_id   INTEGER NOT NULL,
  ts           INTEGER NOT NULL,
  decision     TEXT NOT NULL,             -- approve | amend | punt | reject
  iteration    INTEGER NOT NULL DEFAULT 0,
  comments     TEXT,                      -- only populated for amend/punt/reject
  commander_id TEXT,
  FOREIGN KEY (feature_id) REFERENCES bot_feature_requests(id)
);
CREATE INDEX IF NOT EXISTS idx_bot_decisions_feature ON bot_commander_decisions(feature_id);
CREATE INDEX IF NOT EXISTS idx_bot_decisions_ts      ON bot_commander_decisions(ts);
