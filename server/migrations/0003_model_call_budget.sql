-- One row is one file-analysis attempt; model_calls reserves its full work.
-- Existing rows retain IDs and count as one prior model call.
ALTER TABLE quota_requests ADD COLUMN model_calls INTEGER NOT NULL DEFAULT 1
 CHECK (model_calls BETWEEN 1 AND 3);
