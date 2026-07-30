-- PRIME forward migration 0002.
-- PostgreSQL only; applied by app/db.py after the legacy bootstrap.
-- All statements are additive and idempotent.

ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS client_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_message_sender_client_id
    ON chat_messages (sender_user_id, client_id);
CREATE INDEX IF NOT EXISTS ix_waiting_skill_region_created
    ON waiting_room_entries (skill_id, region_code, created_at);
CREATE INDEX IF NOT EXISTS ix_waiting_skill_expand_created
    ON waiting_room_entries (skill_id, allow_other_regions, created_at);
CREATE INDEX IF NOT EXISTS ix_group_members_user_active_group
    ON group_members (user_id, active, group_id);
CREATE INDEX IF NOT EXISTS ix_group_members_group_active_created
    ON group_members (group_id, active, created_at);
CREATE INDEX IF NOT EXISTS ix_chat_messages_group_created_id
    ON chat_messages (group_id, created_at, id);
CREATE INDEX IF NOT EXISTS ix_direct_messages_conversation_created_id
    ON direct_messages (conversation_key, created_at, id);
CREATE INDEX IF NOT EXISTS ix_habit_reports_user_date_status
    ON habit_reports (user_id, report_date, status);
CREATE INDEX IF NOT EXISTS ix_notifications_user_created_id
    ON notifications (user_id, created_at, id);
CREATE INDEX IF NOT EXISTS ix_notifications_user_read_created
    ON notifications (user_id, read_at, created_at);
CREATE INDEX IF NOT EXISTS ix_email_verification_user_used_created
    ON email_verification_codes (user_id, used_at, created_at);
