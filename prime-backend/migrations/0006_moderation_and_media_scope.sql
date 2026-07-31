-- Moderation decisions, social-write restrictions, appeals, and upload scope tracking.

CREATE TABLE IF NOT EXISTS moderation_decisions (
    id VARCHAR(36) PRIMARY KEY,
    actor_user_id VARCHAR(36) NOT NULL,
    content_type VARCHAR(32) NOT NULL,
    content_id_or_draft_id VARCHAR(36),
    language VARCHAR(8),
    category VARCHAR(32) NOT NULL,
    confidence_band VARCHAR(16) NOT NULL,
    action VARCHAR(32) NOT NULL,
    policy_version VARCHAR(16) NOT NULL DEFAULT '1.0',
    detector_version VARCHAR(16) NOT NULL DEFAULT '1.0',
    normalized_content_hash VARCHAR(64),
    offense_id VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by VARCHAR(36),
    appeal_id VARCHAR(36),
    reversed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS ix_moderation_decisions_actor_created
    ON moderation_decisions (actor_user_id, created_at);
CREATE INDEX IF NOT EXISTS ix_moderation_decisions_offense
    ON moderation_decisions (offense_id);

CREATE TABLE IF NOT EXISTS user_restrictions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    scope VARCHAR(32) NOT NULL,
    reason_code VARCHAR(32) NOT NULL,
    source_decision_id VARCHAR(36) NOT NULL UNIQUE,
    starts_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revocation_reason VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS ix_user_restrictions_user_status_expires
    ON user_restrictions (user_id, status, expires_at);

CREATE TABLE IF NOT EXISTS moderation_appeals (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    decision_id VARCHAR(36) NOT NULL,
    explanation TEXT NOT NULL DEFAULT '',
    status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(36),
    resolution_reason VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS ix_moderation_appeals_user_status
    ON moderation_appeals (user_id, status);

CREATE TABLE IF NOT EXISTS media_uploads (
    id VARCHAR(36) PRIMARY KEY,
    owner_user_id VARCHAR(36) NOT NULL,
    media_url VARCHAR(512) NOT NULL,
    scope_type VARCHAR(32) NOT NULL,
    scope_id VARCHAR(36),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (media_url)
);

CREATE INDEX IF NOT EXISTS ix_media_uploads_owner_scope
    ON media_uploads (owner_user_id, scope_type, scope_id);
