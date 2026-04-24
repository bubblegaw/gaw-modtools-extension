-- ============================================================================
-- GAW ModTools Worker — Migration 004: Firehose (posts, comments, users, crawl)
-- ============================================================================
-- Apply with:
--   wrangler d1 execute AUDIT_DB --file=migrations/004_firehose.sql
-- ============================================================================

-- All posts we've ever seen. Captured BEFORE removal when possible.
CREATE TABLE IF NOT EXISTS gaw_posts (
  id              TEXT PRIMARY KEY,       -- GAW post ID
  slug            TEXT,                   -- URL slug
  title           TEXT,
  author          TEXT NOT NULL,
  community       TEXT NOT NULL,
  post_type       TEXT,                   -- text | link | image
  url             TEXT,                   -- external URL (link posts)
  body_md         TEXT,
  body_html       TEXT,
  score           INTEGER,
  comment_count   INTEGER,
  flair           TEXT,
  is_sticky       INTEGER DEFAULT 0,
  is_locked       INTEGER DEFAULT 0,
  is_removed      INTEGER DEFAULT 0,      -- flips to 1 when we detect removal
  is_deleted      INTEGER DEFAULT 0,
  created_at      INTEGER NOT NULL,
  captured_at     INTEGER NOT NULL,
  last_updated    INTEGER NOT NULL,
  version         INTEGER DEFAULT 1,       -- bump on meaningful re-capture
  captured_by     TEXT                     -- mod username who captured (for debug)
);
CREATE INDEX IF NOT EXISTS idx_gaw_posts_author    ON gaw_posts(author);
CREATE INDEX IF NOT EXISTS idx_gaw_posts_created   ON gaw_posts(created_at);
CREATE INDEX IF NOT EXISTS idx_gaw_posts_community ON gaw_posts(community);
CREATE INDEX IF NOT EXISTS idx_gaw_posts_removed   ON gaw_posts(is_removed) WHERE is_removed = 1;

CREATE VIRTUAL TABLE IF NOT EXISTS gaw_posts_fts USING fts5(
  title, body_md, author, community, content='gaw_posts', content_rowid='rowid'
);

CREATE TRIGGER IF NOT EXISTS gaw_posts_ai AFTER INSERT ON gaw_posts BEGIN
  INSERT INTO gaw_posts_fts(rowid, title, body_md, author, community)
  VALUES (new.rowid, new.title, new.body_md, new.author, new.community);
END;
CREATE TRIGGER IF NOT EXISTS gaw_posts_ad AFTER DELETE ON gaw_posts BEGIN
  INSERT INTO gaw_posts_fts(gaw_posts_fts, rowid, title, body_md, author, community)
  VALUES ('delete', old.rowid, old.title, old.body_md, old.author, old.community);
END;
CREATE TRIGGER IF NOT EXISTS gaw_posts_au AFTER UPDATE ON gaw_posts BEGIN
  INSERT INTO gaw_posts_fts(gaw_posts_fts, rowid, title, body_md, author, community)
  VALUES ('delete', old.rowid, old.title, old.body_md, old.author, old.community);
  INSERT INTO gaw_posts_fts(rowid, title, body_md, author, community)
  VALUES (new.rowid, new.title, new.body_md, new.author, new.community);
END;

-- All comments. Stored with parent chain for tree reconstruction.
CREATE TABLE IF NOT EXISTS gaw_comments (
  id           TEXT PRIMARY KEY,
  post_id      TEXT NOT NULL,
  parent_id    TEXT,                      -- NULL = top-level; else comment_id
  author       TEXT NOT NULL,
  body_md      TEXT,
  body_html    TEXT,
  score        INTEGER,
  depth        INTEGER DEFAULT 0,
  is_removed   INTEGER DEFAULT 0,
  is_deleted   INTEGER DEFAULT 0,
  created_at   INTEGER NOT NULL,
  captured_at  INTEGER NOT NULL,
  last_updated INTEGER NOT NULL,
  captured_by  TEXT
);
CREATE INDEX IF NOT EXISTS idx_gaw_comments_post    ON gaw_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_gaw_comments_author  ON gaw_comments(author);
CREATE INDEX IF NOT EXISTS idx_gaw_comments_created ON gaw_comments(created_at);
CREATE INDEX IF NOT EXISTS idx_gaw_comments_parent  ON gaw_comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_gaw_comments_removed ON gaw_comments(is_removed) WHERE is_removed = 1;

CREATE VIRTUAL TABLE IF NOT EXISTS gaw_comments_fts USING fts5(
  body_md, author, content='gaw_comments', content_rowid='rowid'
);
CREATE TRIGGER IF NOT EXISTS gaw_comments_ai AFTER INSERT ON gaw_comments BEGIN
  INSERT INTO gaw_comments_fts(rowid, body_md, author)
  VALUES (new.rowid, new.body_md, new.author);
END;
CREATE TRIGGER IF NOT EXISTS gaw_comments_ad AFTER DELETE ON gaw_comments BEGIN
  INSERT INTO gaw_comments_fts(gaw_comments_fts, rowid, body_md, author)
  VALUES ('delete', old.rowid, old.body_md, old.author);
END;
CREATE TRIGGER IF NOT EXISTS gaw_comments_au AFTER UPDATE ON gaw_comments BEGIN
  INSERT INTO gaw_comments_fts(gaw_comments_fts, rowid, body_md, author)
  VALUES ('delete', old.rowid, old.body_md, old.author);
  INSERT INTO gaw_comments_fts(rowid, body_md, author)
  VALUES (new.rowid, new.body_md, new.author);
END;

-- Users: aggregates maintained as a side effect of posts/comments ingestion,
-- plus explicit backfill via /gaw/users/upsert.
CREATE TABLE IF NOT EXISTS gaw_users (
  username       TEXT PRIMARY KEY,
  display_name   TEXT,
  registered_at  INTEGER,
  karma          INTEGER,
  post_count     INTEGER DEFAULT 0,
  comment_count  INTEGER DEFAULT 0,
  bio            TEXT,
  flairs_json    TEXT,
  first_seen_at  INTEGER NOT NULL,
  last_seen_at   INTEGER NOT NULL,
  last_updated   INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_gaw_users_last_seen ON gaw_users(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_gaw_users_karma     ON gaw_users(karma);

-- Per-community crawl cursor for server cron deltas.
CREATE TABLE IF NOT EXISTS gaw_crawl_state (
  community      TEXT PRIMARY KEY,
  last_post_id   TEXT,
  last_post_at   INTEGER,
  last_crawl_at  INTEGER NOT NULL,
  total_posts    INTEGER DEFAULT 0,
  errors_recent  INTEGER DEFAULT 0,
  notes          TEXT
);

-- Ingestion audit: every batch push logged (debug + ratelimit backstop).
CREATE TABLE IF NOT EXISTS gaw_ingest_audit (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  ts           INTEGER NOT NULL,
  kind         TEXT NOT NULL,         -- posts | comments | users
  source       TEXT NOT NULL,         -- client-firehose | server-cron
  actor        TEXT,                  -- mod username or 'cron'
  rows_in      INTEGER NOT NULL,
  rows_new     INTEGER DEFAULT 0,
  rows_updated INTEGER DEFAULT 0,
  duration_ms  INTEGER,
  error        TEXT
);
CREATE INDEX IF NOT EXISTS idx_gaw_ingest_ts ON gaw_ingest_audit(ts);
