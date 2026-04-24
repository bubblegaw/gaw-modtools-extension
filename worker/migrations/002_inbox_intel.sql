-- INBOX INTEL (v5.5.0) — modmail intelligence pipeline
-- Applies to the existing AUDIT_DB D1 binding.
-- Run with:  wrangler d1 execute AUDIT_DB --file=migrations/002_inbox_intel.sql
--
-- Design: one row per thread, one row per message, one meta row sidecar per
-- message (Llama enrichment), one audit row per significant action.
-- FTS virtual table mirrors message bodies for full-text search.

-- Threads: one row per modmail conversation
CREATE TABLE IF NOT EXISTS modmail_threads (
  thread_id         TEXT PRIMARY KEY,           -- e.g. "4eaTZ0vLa21"
  subject           TEXT NOT NULL,
  first_user        TEXT NOT NULL,              -- initiating username
  first_seen        INTEGER NOT NULL,           -- unix ms
  last_seen         INTEGER NOT NULL,
  message_count     INTEGER DEFAULT 1,
  status            TEXT DEFAULT 'new',         -- new|claimed|replied|awaiting|resolved|archived
  claimed_by        TEXT,
  claimed_at        INTEGER,
  resolved_at       INTEGER,
  resolved_by       TEXT,
  resolution_type   TEXT,                       -- appeal_granted|appeal_denied|warning|ban|spam|resolved|ignored
  is_archived       INTEGER DEFAULT 0,
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_threads_status    ON modmail_threads(status);
CREATE INDEX IF NOT EXISTS idx_threads_user      ON modmail_threads(first_user);
CREATE INDEX IF NOT EXISTS idx_threads_last_seen ON modmail_threads(last_seen DESC);

-- Messages: one row per individual mail in a thread
CREATE TABLE IF NOT EXISTS modmail_messages (
  message_id   TEXT PRIMARY KEY,                -- site's data-id (archive data-id)
  thread_id    TEXT NOT NULL,
  direction    TEXT NOT NULL,                   -- incoming|outgoing
  from_user    TEXT NOT NULL,
  to_user      TEXT,
  body_text    TEXT NOT NULL,
  body_html    TEXT,
  sent_at      INTEGER NOT NULL,
  captured_at  INTEGER NOT NULL,
  signature    TEXT,                            -- hash for dedup
  FOREIGN KEY(thread_id) REFERENCES modmail_threads(thread_id)
);

CREATE INDEX IF NOT EXISTS idx_messages_thread    ON modmail_messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_messages_signature ON modmail_messages(signature);
CREATE INDEX IF NOT EXISTS idx_messages_sent      ON modmail_messages(sent_at DESC);

-- Meta: Llama-extracted intelligence (sidecar to messages)
CREATE TABLE IF NOT EXISTS modmail_meta (
  message_id         TEXT PRIMARY KEY,
  intent             TEXT,                      -- appeal|complaint|question|report|abuse|spam|allycheckin|other
  tone_anger         INTEGER,                   -- 0-100
  tone_cooperation   INTEGER,
  tone_coherence     INTEGER,
  urgency            TEXT,                      -- low|medium|high|crisis
  language           TEXT DEFAULT 'en',
  summary_short      TEXT,                      -- <=80 char canonical summary
  entities_json      TEXT,
  flags_json         TEXT,
  sentiment_delta    INTEGER,
  enriched_at        INTEGER,
  enriched_model     TEXT,
  FOREIGN KEY(message_id) REFERENCES modmail_messages(message_id)
);

CREATE INDEX IF NOT EXISTS idx_meta_intent  ON modmail_meta(intent);
CREATE INDEX IF NOT EXISTS idx_meta_urgency ON modmail_meta(urgency);

-- FTS virtual table for body_text search (external content mode)
CREATE VIRTUAL TABLE IF NOT EXISTS modmail_fts USING fts5(
  message_id UNINDEXED,
  body_text,
  content='modmail_messages',
  content_rowid='rowid'
);

-- Audit: every enrichment + draft + admin action logged
CREATE TABLE IF NOT EXISTS modmail_audit (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  action       TEXT NOT NULL,                   -- enrich|draft|send|ban|archive|claim|resolve|sync
  thread_id    TEXT,
  message_id   TEXT,
  mod_user     TEXT,
  model        TEXT,
  tokens_in    INTEGER,
  tokens_out   INTEGER,
  cost_cents   INTEGER,
  success      INTEGER,
  error        TEXT,
  created_at   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_thread ON modmail_audit(thread_id);
CREATE INDEX IF NOT EXISTS idx_audit_mod    ON modmail_audit(mod_user);
CREATE INDEX IF NOT EXISTS idx_audit_action ON modmail_audit(action);
