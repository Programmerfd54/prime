-- PRIME forward migration 0003.
-- Server-side auth sessions, shared abuse counters, audit trail and outbox.

CREATE TABLE IF NOT EXISTS auth_sessions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    refresh_token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ,
    user_agent VARCHAR(512),
    ip_address VARCHAR(64)
);

CREATE INDEX IF NOT EXISTS ix_auth_sessions_user_active
    ON auth_sessions (user_id, revoked_at, expires_at);
CREATE INDEX IF NOT EXISTS ix_auth_sessions_refresh_hash
    ON auth_sessions (refresh_token_hash);

CREATE TABLE IF NOT EXISTS rate_limit_buckets (
    key VARCHAR(128) PRIMARY KEY,
    window_started_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_events (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36),
    action VARCHAR(80) NOT NULL,
    request_id VARCHAR(128),
    metadata_json TEXT NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_audit_events_user_created
    ON audit_events (user_id, created_at);
CREATE INDEX IF NOT EXISTS ix_audit_events_action_created
    ON audit_events (action, created_at);

CREATE TABLE IF NOT EXISTS outbox_events (
    id VARCHAR(36) PRIMARY KEY,
    topic VARCHAR(80) NOT NULL,
    aggregate_id VARCHAR(36),
    payload TEXT NOT NULL DEFAULT '{}',
    attempts INTEGER NOT NULL DEFAULT 0,
    available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_outbox_events_pending
    ON outbox_events (processed_at, available_at);
CREATE INDEX IF NOT EXISTS ix_outbox_events_topic
    ON outbox_events (topic);
