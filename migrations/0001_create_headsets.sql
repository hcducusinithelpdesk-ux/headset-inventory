CREATE TABLE IF NOT EXISTS headsets (
  id TEXT PRIMARY KEY NOT NULL,
  asset_tag TEXT NOT NULL UNIQUE,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  serial_number TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'Available'
    CHECK (status IN ('Available', 'Issued', 'Defective')),
  assigned_to TEXT NOT NULL DEFAULT '',
  department TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_headsets_created_at ON headsets(created_at DESC);
