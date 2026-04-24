-- Migration 013: v8.0 Team Productivity tables.
-- Ships together or not at all. Executed by Session C (setup script).
--
-- Tables:
--   1. shadow_triage_decisions -- AI pre-decide cache (Shadow Queue).
--      Retention: 7 days ephemeral (purged by teamProductivityCronTick).
--   2. parked_items -- "Park for Senior Review" queue (Park button).
--      Retention: 30 days after resolution.
--   3. ai_suspect_queue -- daily-AI-scan human-review gate (Amendment B.4).
--      Pre-existing CRIT from AI safety audit: daily AI scoring no longer
--      writes directly to watchlist; it enqueues here, human promotes.
--
-- All three are additive. No existing table is modified. No data loss
-- on re-run: CREATE TABLE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS.

-- ---- Shadow Queue decision cache ------------------------------------
CREATE TABLE IF NOT EXISTS shadow_triage_decisions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id      TEXT NOT NULL,              -- queue item id, post id, or comment id
  kind            TEXT NOT NULL,              -- 'queue' | 'post' | 'comment'
  decision        TEXT NOT NULL,              -- 'APPROVE' | 'REMOVE' | 'WATCH' | 'DO_NOTHING'
  confidence      REAL NOT NULL,              -- 0.0 .. 1.0 (client suppresses badge when < 0.85)
  reason          TEXT,                       -- <=240 chars, one-sentence summary
  evidence        TEXT,                       -- JSON array of {source,id,excerpt}; REQUIRED non-empty for non-DO_NOTHING
  counterarguments TEXT,                      -- JSON array of strings; alternate interpretations
  rule_refs       TEXT,                       -- JSON array of rule id strings
  prompt_version  TEXT,                       -- prompt template version ('shadow-triage-v1' etc.)
  ai_model        TEXT,                       -- 'grok-3-mini' etc.
  provider        TEXT,                       -- 'xai' etc.
  rules_version   TEXT,                       -- rules doc revision
  generated_at    INTEGER NOT NULL,           -- ms epoch (model-generation time)
  created_at      INTEGER NOT NULL,           -- ms epoch (row-insert time; used for 7d purge)
  UNIQUE(kind, subject_id)                    -- one live decision per subject (UPSERT on re-triage)
);
CREATE INDEX IF NOT EXISTS idx_shadow_created_at ON shadow_triage_decisions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shadow_kind       ON shadow_triage_decisions(kind);
CREATE INDEX IF NOT EXISTS idx_shadow_decision   ON shadow_triage_decisions(decision);

-- ---- Park for Senior Review ----------------------------------------
CREATE TABLE IF NOT EXISTS parked_items (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  kind               TEXT NOT NULL,           -- 'queue' | 'post' | 'comment' | 'user' | 'modmail'
  subject_id         TEXT NOT NULL,
  note               TEXT,                    -- parker's optional context, <=200 chars
  parker             TEXT NOT NULL,           -- token-verified mod username
  status             TEXT NOT NULL DEFAULT 'open',  -- 'open' | 'resolved' | 'discarded'
  resolved_by        TEXT,
  resolved_at        INTEGER,                 -- ms epoch
  resolution_action  TEXT,                    -- 'APPROVE' | 'REMOVE' | 'BAN' | 'DISCARD' | 'OTHER'
  resolution_reason  TEXT,                    -- <=240 chars
  created_at         INTEGER NOT NULL         -- ms epoch
);
CREATE INDEX IF NOT EXISTS idx_parked_status  ON parked_items(status);
CREATE INDEX IF NOT EXISTS idx_parked_kind    ON parked_items(kind);
CREATE INDEX IF NOT EXISTS idx_parked_parker  ON parked_items(parker);
CREATE INDEX IF NOT EXISTS idx_parked_created ON parked_items(created_at DESC);
-- Partial index used by the senior review popover (open items, newest first).
CREATE INDEX IF NOT EXISTS idx_parked_open_created
  ON parked_items(created_at DESC)
  WHERE status='open';

-- ---- AI Suspect review queue (Amendment B.4) -----------------------
-- Daily AI scoring used to write risk>=70 usernames straight to the
-- watchlist. The AI safety audit classified that as CRITICAL (silent AI
-- enforcement without human review). New behavior: write here instead,
-- human promotes via the Park review pool or a dedicated UI.
CREATE TABLE IF NOT EXISTS ai_suspect_queue (
  username        TEXT PRIMARY KEY,
  ai_risk         INTEGER,                    -- 0..100 (client-reported)
  ai_reason       TEXT,                       -- short model-provided justification
  source          TEXT,                       -- 'daily-ai' | 'scan-on-demand' | 'hover' etc.
  ai_model        TEXT,
  prompt_version  TEXT,
  enqueued_at     INTEGER NOT NULL,           -- ms epoch
  reviewed_at     INTEGER,
  reviewed_by     TEXT,
  disposition     TEXT                        -- 'watched' | 'cleared' | 'banned' | 'ignored'
);
CREATE INDEX IF NOT EXISTS idx_ai_suspect_enqueued  ON ai_suspect_queue(enqueued_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_suspect_disposition ON ai_suspect_queue(disposition);
-- Partial index: fast "pending review" lookup.
CREATE INDEX IF NOT EXISTS idx_ai_suspect_pending
  ON ai_suspect_queue(enqueued_at DESC)
  WHERE disposition IS NULL;
