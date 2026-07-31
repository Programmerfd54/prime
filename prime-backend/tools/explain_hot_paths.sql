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

-- Batched /groups/overview member state.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT gm.group_id, gm.user_id, gm.role, gm.active, gm.created_at, u.nickname
FROM group_members gm
JOIN users u ON u.id = gm.user_id
WHERE gm.group_id = ANY(:group_ids)
  AND gm.active IS TRUE
ORDER BY gm.group_id, gm.created_at ASC;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT group_id, user_id, status, support_given
FROM habit_reports
WHERE group_id = ANY(:group_ids)
  AND report_date = CURRENT_DATE;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT group_id, user_id, kind, created_at
FROM group_check_ins
WHERE group_id = ANY(:group_ids)
  AND check_in_date = CURRENT_DATE
ORDER BY group_id, created_at DESC;
