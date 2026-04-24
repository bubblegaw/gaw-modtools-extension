-- ============================================================================
-- GAW ModTools Worker -- Migration 014: Claude Bridge chat history
-- ============================================================================
-- Backs /gm chat (Claude-powered conversational AI, per-mod + per-thread).
-- Rolling 24h retention; purged by botCronTick.
--
-- Apply with:
--   wrangler d1 execute AUDIT_DB --remote --file=migrations/014_bot_chat_history.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS bot_chat_history (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  discord_id   TEXT    NOT NULL,              -- Discord snowflake of the mod
  gaw_username TEXT,                          -- denormalized for log readability
  thread_id    TEXT,                          -- Discord channel/thread id (null = fresh convo outside a thread)
  role         TEXT    NOT NULL,              -- 'user' | 'assistant'
  content      TEXT    NOT NULL,              -- the message body
  created_at   INTEGER NOT NULL               -- unix seconds
);

-- Thread lookup (load prior turns in the current Discord thread for this mod).
CREATE INDEX IF NOT EXISTS idx_bot_chat_thread
  ON bot_chat_history(discord_id, thread_id, created_at);

-- Purge index (botCronTick deletes rows older than 24h).
CREATE INDEX IF NOT EXISTS idx_bot_chat_created
  ON bot_chat_history(created_at);
