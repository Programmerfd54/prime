-- PRIME forward migration 0004: authenticated local media metadata.

CREATE TABLE IF NOT EXISTS local_media_assets (
    id VARCHAR(36) PRIMARY KEY,
    owner_user_id VARCHAR(36) NOT NULL,
    storage_key VARCHAR(128) NOT NULL UNIQUE,
    content_type VARCHAR(160) NOT NULL DEFAULT 'application/octet-stream',
    filename VARCHAR(500) NOT NULL DEFAULT '',
    size_bytes BIGINT NOT NULL DEFAULT 0,
    scope_type VARCHAR(32) NOT NULL DEFAULT 'owner',
    scope_id VARCHAR(36),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE local_media_assets ADD COLUMN IF NOT EXISTS scope_type VARCHAR(32) NOT NULL DEFAULT 'owner';
ALTER TABLE local_media_assets ADD COLUMN IF NOT EXISTS scope_id VARCHAR(36);

CREATE INDEX IF NOT EXISTS ix_local_media_assets_owner_created
    ON local_media_assets (owner_user_id, created_at);
CREATE INDEX IF NOT EXISTS ix_local_media_assets_scope
    ON local_media_assets (scope_type, scope_id);
