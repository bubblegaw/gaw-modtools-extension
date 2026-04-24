CREATE TABLE IF NOT EXISTS bot_mods (
  discord_id    TEXT PRIMARY KEY,
  gaw_username  TEXT,
  display_name  TEXT,
  role          TEXT NOT NULL DEFAULT 'mod',      -- mod | lead | observer
  added_at      INTEGER NOT NULL,
  added_by      TEXT,
  revoked_at    INTEGER
);
CREATE INDEX IF NOT EXISTS idx_bot_mods_active ON bot_mods(revoked_at) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS bot_feature_requests (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  proposer_id     TEXT NOT NULL,                  -- Discord snowflake
  proposer_name   TEXT,
  channel_id      TEXT NOT NULL,
  root_message_id TEXT,                           -- Discord message where /propose was used
  thread_id       TEXT,                           -- Discord thread (optional)
  summary_raw     TEXT NOT NULL,                  -- what the mod typed
  summary_refined TEXT,                           -- Grok's reflected-back version
  tech_spec       TEXT,                           -- Grok's technical flushing
  acceptance      TEXT,                           -- Grok's acceptance criteria
  status          TEXT NOT NULL DEFAULT 'draft',  -- draft | polling | approved | rejected | finalized | shipped | cancelled
  final_prompt    TEXT,                           -- the Claude Code-ready prompt once consensus hits
  created_at      INTEGER NOT NULL,
  finalized_at    INTEGER
);
CREATE INDEX IF NOT EXISTS idx_bot_fr_status   ON bot_feature_requests(status);
CREATE INDEX IF NOT EXISTS idx_bot_fr_proposer ON bot_feature_requests(proposer_id);

CREATE TABLE IF NOT EXISTS bot_polls (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  feature_id    INTEGER NOT NULL,
  message_id    TEXT NOT NULL,                    -- Discord poll message
  channel_id    TEXT NOT NULL,
  options_json  TEXT NOT NULL,                    -- JSON array of options ["ship as-is", "ship with tweaks", ...]
  expires_at    INTEGER NOT NULL,                 -- unix seconds
  quorum_min    INTEGER NOT NULL DEFAULT 2,
  status        TEXT NOT NULL DEFAULT 'open',     -- open | closed | expired
  resolution    TEXT,                             -- winning option id
  closed_at     INTEGER,
  FOREIGN KEY (feature_id) REFERENCES bot_feature_requests(id)
);
CREATE INDEX IF NOT EXISTS idx_bot_polls_status ON bot_polls(status);
CREATE INDEX IF NOT EXISTS idx_bot_polls_exp    ON bot_polls(expires_at) WHERE status = 'open';

CREATE TABLE IF NOT EXISTS bot_poll_votes (
  poll_id       INTEGER NOT NULL,
  voter_id      TEXT NOT NULL,
  choice_idx    INTEGER NOT NULL,
  voted_at      INTEGER NOT NULL,
  PRIMARY KEY (poll_id, voter_id),
  FOREIGN KEY (poll_id) REFERENCES bot_polls(id)
);

CREATE TABLE IF NOT EXISTS bot_conversations (
  thread_id     TEXT PRIMARY KEY,
  feature_id    INTEGER,                          -- NULL if not linked to a feature request
  messages_json TEXT NOT NULL DEFAULT '[]',       -- last 20 turns, rolling
  last_msg_at   INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_bot_conv_last ON bot_conversations(last_msg_at);

CREATE TABLE IF NOT EXISTS bot_ai_audit (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  ts            INTEGER NOT NULL,
  feature_id    INTEGER,
  interaction   TEXT NOT NULL,                    -- ask | propose | refine | poll | finalize | delegate-llama
  model         TEXT NOT NULL,                    -- grok-3-mini | grok-3 | @cf/meta/llama-3.3-70b-instruct | llama-fallback
  tokens_in     INTEGER,
  tokens_out    INTEGER,
  cost_cents    INTEGER NOT NULL DEFAULT 0,
  duration_ms   INTEGER,
  success       INTEGER NOT NULL DEFAULT 1,
  error         TEXT,
  actor_id      TEXT                              -- Discord user who triggered it
);
CREATE INDEX IF NOT EXISTS idx_bot_audit_ts    ON bot_ai_audit(ts);
CREATE INDEX IF NOT EXISTS idx_bot_audit_model ON bot_ai_audit(model);