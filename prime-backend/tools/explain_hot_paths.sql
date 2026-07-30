-- Run against a representative PostgreSQL dataset after migrations.
-- Replace bind values with realistic values; capture JSON output before/after.

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT id, user_id, created_at
FROM waiting_room_entries
WHERE skill_id = :skill_id
  AND region_code = :region_code
ORDER BY created_at ASC, id ASC
LIMIT 120
FOR UPDATE SKIP LOCKED;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT id, sender_user_id, body, created_at, client_id
FROM chat_messages
WHERE group_id = :group_id
  AND created_at < :before_created_at
ORDER BY created_at DESC, id DESC
LIMIT 51;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT id, type, title, body, read_at, created_at
FROM notifications
WHERE user_id = :user_id
  AND (
      created_at < :before_created_at
      OR (created_at = :before_created_at AND id < :before_id)
  )
ORDER BY created_at DESC, id DESC
LIMIT 51;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT id, body, created_at
FROM direct_messages
WHERE conversation_key = :conversation_key
ORDER BY created_at DESC, id DESC
LIMIT 51;
