CREATE TABLE IF NOT EXISTS viewer_users (
  username TEXT PRIMARY KEY COLLATE NOCASE NOT NULL,
  salt TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
