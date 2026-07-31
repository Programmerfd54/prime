-- Cycle continuation votes after first 30-day cycle.
CREATE TABLE IF NOT EXISTS group_continuation_votes (
    id VARCHAR(36) PRIMARY KEY,
    group_id VARCHAR(36) NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    choice VARCHAR(40) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_group_continuation_vote UNIQUE (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_group_continuation_votes_group_id
    ON group_continuation_votes (group_id);
