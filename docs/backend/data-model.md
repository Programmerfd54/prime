# Current data model

The authoritative runtime model is `prime-backend/app/models.py`; the startup
bootstrap is in `prime-backend/app/db.py`, and forward SQL is in
`prime-backend/migrations/`.

Core tables:

- `users`, `password_reset_tokens`, `email_verification_codes`;
- `waiting_room_entries`, `groups`, `group_members`;
- `chat_messages`, `chat_message_reactions`;
- `friend_requests`, `friendships`, `direct_messages`,
  `direct_message_reactions`, `direct_conversation_reads`;
- `habit_reports`, `report_attachments`, `group_days`, `group_check_ins`;
- `notifications`, `device_tokens`, `prime_events`;
- `user_skill_favorites`, `custom_skills`.

Important constraints include unique queue membership per user/skill, unique
group membership, unique daily report/check-in, unique friendship pairs,
unique device tokens, and `(sender_user_id, client_id)` idempotency for direct
and group messages (NULL client IDs remain allowed for older clients).

The schema currently has few database foreign keys; most authorization and
referential checks are application-level. There is no refresh-token/session
table, outbox table, delivery receipt table, cycle/voting model, or shared event
log. These are explicit gaps, not implied features.
