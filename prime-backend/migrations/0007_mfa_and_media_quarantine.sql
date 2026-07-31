-- MFA credentials and step-up sessions for moderators.

CREATE TABLE IF NOT EXISTS moderator_totp_secrets (
    user_id VARCHAR(36) PRIMARY KEY,
    secret_encrypted TEXT NOT NULL,
    enabled_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS moderator_backup_codes (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    code_hash VARCHAR(64) NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_moderator_backup_codes_user
    ON moderator_backup_codes (user_id);

CREATE TABLE IF NOT EXISTS webauthn_credentials (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    sign_count BIGINT NOT NULL DEFAULT 0,
    transports TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_webauthn_credentials_user
    ON webauthn_credentials (user_id);

CREATE TABLE IF NOT EXISTS moderator_step_up_sessions (
    id VARCHAR(36) PRIMARY KEY,
    auth_session_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    method VARCHAR(32) NOT NULL,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_moderator_step_up_auth_session
    ON moderator_step_up_sessions (auth_session_id, expires_at);

CREATE UNIQUE INDEX IF NOT EXISTS uq_moderation_appeals_decision
    ON moderation_appeals (decision_id);

ALTER TABLE local_media_assets
    ADD COLUMN IF NOT EXISTS processing_status VARCHAR(32) NOT NULL DEFAULT 'CLEAN';

ALTER TABLE local_media_assets
    ADD COLUMN IF NOT EXISTS published_media_url VARCHAR(512);

ALTER TABLE local_media_assets
    ADD COLUMN IF NOT EXISTS scan_attempts INTEGER NOT NULL DEFAULT 0;

ALTER TABLE local_media_assets
    ADD COLUMN IF NOT EXISTS last_scan_error TEXT;
