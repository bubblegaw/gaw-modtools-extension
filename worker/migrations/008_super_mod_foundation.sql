-- v7.1 super-mod foundation: drafts, proposals, claims.
-- All three tables ship together. Mod-token read/write except where noted; the
-- worker enforces gating -- these tables have no row-level auth.

CREATE TABLE IF NOT EXISTS drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action        TEXT NOT NULL,      -- ban | note | msg | (free-form action key)
  target        TEXT NOT NULL,      -- username | thread id | post id
  body          TEXT NOT NULL,      -- the draft text
  last_editor   TEXT NOT NULL,      -- token-verified mod username
  status        TEXT NOT NULL DEFAULT 'open',   -- open | handed_off | sent | abandoned
  handoff_note  TEXT,
  created_at    INTEGER NOT NULL,   -- ms epoch
  last_edit_at  INTEGER NOT NULL,   -- ms epoch; used for 24h TTL
  UNIQUE(action, target)            -- one live draft per action+target; UPSERT on PUT
);
CREATE INDEX IF NOT EXISTS idx_drafts_target         ON drafts(target);
CREATE INDEX IF NOT EXISTS idx_drafts_last_edit_at   ON drafts(last_edit_at DESC);
CREATE INDEX IF NOT EXISTS idx_drafts_last_editor    ON drafts(last_editor);

CREATE TABLE IF NOT EXISTS proposals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind          TEXT NOT NULL,      -- ban | remove_post | lock_thread
  target        TEXT NOT NULL,      -- username or post/thread id
  duration      TEXT,               -- for ban: 24h | 168h | perm; null for others
  reason        TEXT,
  proposer      TEXT NOT NULL,      -- token-verified mod username
  proposer_note TEXT,
  ai_note       TEXT,               -- <=120 char AI advisory
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending | executed | vetoed | punted | expired
  executor      TEXT,
  executed_at   INTEGER,
  created_at    INTEGER NOT NULL,
  alerted_at    INTEGER              -- set once when 1h auto-escalate fires
);
CREATE INDEX IF NOT EXISTS idx_proposals_status      ON proposals(status);
CREATE INDEX IF NOT EXISTS idx_proposals_created_at  ON proposals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_proposals_target      ON proposals(target);

CREATE TABLE IF NOT EXISTS claims (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  thread_id   TEXT NOT NULL UNIQUE,
  mod         TEXT NOT NULL,
  claimed_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_claims_expires_at ON claims(expires_at DESC);
