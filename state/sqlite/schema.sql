-- Multi-client control-plane SQLite schema.
-- JSONL files remain the canonical append-only source.
-- This database is a rebuildable mirror / query index.
-- Drop and re-import any time to rebuild from source JSONL.

CREATE TABLE IF NOT EXISTS clients (
  client_id   TEXT PRIMARY KEY,
  display_name TEXT,
  client_root TEXT,
  adapter_id  TEXT,
  last_import TEXT
);

CREATE TABLE IF NOT EXISTS events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id    TEXT    NOT NULL,
  source_file  TEXT    NOT NULL,
  source_line  INTEGER NOT NULL,
  event_type   TEXT    NOT NULL,
  timestamp    TEXT    NOT NULL,
  session_id   TEXT    NOT NULL,
  domain       TEXT,
  active_node  TEXT,
  payload_json TEXT    NOT NULL,
  imported_at  TEXT    NOT NULL,
  FOREIGN KEY (client_id) REFERENCES clients(client_id),
  UNIQUE (client_id, source_file, source_line)
);

CREATE TABLE IF NOT EXISTS imports (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id   TEXT NOT NULL,
  source_file TEXT NOT NULL,
  imported_at TEXT NOT NULL,
  lines_read  INTEGER NOT NULL DEFAULT 0,
  lines_imported INTEGER NOT NULL DEFAULT 0,
  lines_skipped  INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_events_client_id   ON events(client_id);
CREATE INDEX IF NOT EXISTS idx_events_event_type  ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_timestamp   ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_events_session_id  ON events(session_id);
