# Current data model

The authoritative runtime model is `prime-backend/app/models.py`; the startup
bootstrap is in `prime-backend/app/db.py`, and forward SQL is in
`prime-backend/migrations/`.

Core tables:

- `users`, `password_reset_tokens`, `email_verification_codes`;
- `waiting_room_entries`, `early_start_requests`,
  `early_start_confirmations`, `groups`, `group_members`,
  `group_membership_events`;
- `chat_messages`, `chat_message_reactions`;
- `friend_requests`, `friendships`, `direct_messages`,
  `direct_message_reactions`, `direct_conversation_reads`;
- `habit_reports`, `report_attachments`, `group_days`, `group_check_ins`;
- `notifications`, `device_tokens`, `outbox_events`, `prime_events`;
- `user_skill_favorites`, `custom_skills`.

Important constraints include unique queue membership per user/skill, unique
group membership, unique daily report/check-in, unique friendship pairs,
unique device tokens, and `(sender_user_id, client_id)` idempotency for direct
and group messages (NULL client IDs remain allowed for older clients).

`groups.revision` and `waiting_room_entries.revision` are monotonic state
versions used by realtime clients. `group_membership_events` is append-only:
every matched join, vacancy fill and manual change records actor, reason and
the active-state transition. Early-start confirmations are unique per
request/user and the request itself has a durable expiry/status.

The schema currently has few database foreign keys; most authorization and
referential checks are application-level. Refresh sessions and notification
outbox are durable. There is no delivery receipt table, dedicated cycle/voting
model, or shared cross-instance event log. These are explicit gaps, not
implied features.
