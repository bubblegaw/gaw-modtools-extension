-- v7.1.2: team feature promotion + bug reports.
-- Two new tables. No row-level auth; worker enforces mod-token read / lead-token
-- write for team_features, mod-token write for bug_reports.

CREATE TABLE IF NOT EXISTS team_features (
  feature_key TEXT PRIMARY KEY,
  value       TEXT NOT NULL,       -- JSON-encoded value (true/false/string/number)
  set_by      TEXT NOT NULL,
  set_at      INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_team_features_set_at ON team_features(set_at DESC);

CREATE TABLE IF NOT EXISTS bug_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reported_by   TEXT NOT NULL,
  page_url      TEXT,
  version       TEXT,
  browser       TEXT,
  description   TEXT NOT NULL,
  snapshot_json TEXT,                      -- nullable when include_snapshot=false
  status        TEXT NOT NULL DEFAULT 'open',  -- open | triaged | fixed | wontfix
  triaged_at    INTEGER,
  triage_note   TEXT,
  created_at    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status     ON bug_reports(status);
CREATE INDEX IF NOT EXISTS idx_bug_reports_created_at ON bug_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_reporter   ON bug_reports(reported_by);
