ALTER TABLE quota_requests ADD COLUMN ip_hash TEXT;
CREATE INDEX quota_ip_period ON quota_requests(period,ip_hash,bucket);
CREATE TABLE installations (
 id TEXT PRIMARY KEY,
 token_hash TEXT NOT NULL UNIQUE,
 expires_at INTEGER NOT NULL,
 created_at INTEGER NOT NULL DEFAULT (unixepoch())
);
CREATE INDEX installations_expiry ON installations(expires_at);
