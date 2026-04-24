-- v7.0 precedent memory. Lead-gated write/delete; mod-gated read via /precedent/find.
-- Authored-by stores the token-verified mod username so a lead can offboard a
-- departed mod's precedents via /precedent/delete {authored_by: "<mod>"}.

CREATE TABLE IF NOT EXISTS precedents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,               -- User | Thread | Post | QueueItem
  signature TEXT NOT NULL,          -- kind-specific hash (see drawer adapters)
  title TEXT NOT NULL,
  rule_ref TEXT,
  action TEXT NOT NULL,
  reason TEXT,
  source_ref TEXT,                  -- optional permalink / thing id
  authored_by TEXT NOT NULL,        -- token-verified mod username
  marked_at INTEGER NOT NULL        -- ms epoch
);

CREATE INDEX IF NOT EXISTS idx_precedents_kind_sig   ON precedents(kind, signature);
CREATE INDEX IF NOT EXISTS idx_precedents_marked_at  ON precedents(marked_at DESC);
CREATE INDEX IF NOT EXISTS idx_precedents_author     ON precedents(authored_by);
