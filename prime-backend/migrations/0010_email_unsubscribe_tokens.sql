-- PRIME forward migration 0010.
-- Opaque unsubscribe tokens (no PII in URLs).

CREATE TABLE IF NOT EXISTS email_unsubscribe_tokens (
    id VARCHAR(36) PRIMARY KEY,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    letter VARCHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_email_unsubscribe_tokens_user_id
    ON email_unsubscribe_tokens (user_id);
CREATE INDEX IF NOT EXISTS ix_email_unsubscribe_tokens_expires_at
    ON email_unsubscribe_tokens (expires_at);
CREATE INDEX IF NOT EXISTS ix_email_unsubscribe_tokens_active_hash
    ON email_unsubscribe_tokens (token_hash)
    WHERE used_at IS NULL;
