-- Team-state correctness, durable early-start proposals and push routing.
-- PostgreSQL migration; safe to run once after 0004_private_media.sql.

ALTER TABLE groups
    ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;

ALTER TABLE waiting_room_entries
    ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;

ALTER TABLE device_tokens
    ADD COLUMN IF NOT EXISTS provider VARCHAR(16) NOT NULL DEFAULT 'fcm';

CREATE TABLE IF NOT EXISTS group_membership_events (
    id VARCHAR(36) PRIMARY KEY,
    group_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    actor_user_id VARCHAR(36),
    event_type VARCHAR(40) NOT NULL,
    reason VARCHAR(80) NOT NULL,
    from_active BOOLEAN,
    to_active BOOLEAN,
    metadata_json TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_membership_events_group_created
    ON group_membership_events (group_id, created_at);
CREATE INDEX IF NOT EXISTS ix_membership_events_user_created
    ON group_membership_events (user_id, created_at);

CREATE TABLE IF NOT EXISTS early_start_requests (
    id VARCHAR(36) PRIMARY KEY,
    skill_id VARCHAR(120) NOT NULL,
    initiator_user_id VARCHAR(36) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    revision INTEGER NOT NULL DEFAULT 1,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_early_start_skill_status_expiry
    ON early_start_requests (skill_id, status, expires_at);

CREATE TABLE IF NOT EXISTS early_start_confirmations (
    id VARCHAR(36) PRIMARY KEY,
    request_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_early_start_confirmation UNIQUE (request_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_early_start_confirm_request_created
    ON early_start_confirmations (request_id, created_at);

CREATE INDEX IF NOT EXISTS ix_habit_reports_group_date_status
    ON habit_reports (group_id, report_date, status);
CREATE INDEX IF NOT EXISTS ix_group_check_ins_group_date
    ON group_check_ins (group_id, check_in_date);
