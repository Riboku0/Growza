CREATE TABLE IF NOT EXISTS quota_requests (
 id TEXT PRIMARY KEY,
 bucket TEXT NOT NULL,
 period TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT (unixepoch())
);
CREATE INDEX IF NOT EXISTS quota_period ON quota_requests(period,bucket);
