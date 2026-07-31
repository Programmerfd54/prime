# API contract handoff

The route implementation is under `prime-backend/app/routers/`; the Flutter
client contract is in `prime-flutter/lib/data/api_client.dart`. OpenAPI is
available at `/openapi.json` only when `API_DOCS_ENABLED=true`.

For a checked-in contract snapshot, run this from `prime-backend` with the
same non-secret environment used by the target deployment:

```bash
python3 tools/export_openapi.py > ../docs/backend/openapi.json
```

Critical route groups:

| Group | Routes |
|---|---|
| Auth | `/auth/register`, `/verify-email`, `/login`, `/refresh`, `/logout`, password reset |
| Profile | `/users/me`, stats, preferences, favorites, avatar, shields |
| Matching | `/groups/waiting-room*`, `/groups/overview`, `/groups/current`, group detail |
| Group activity | check-in, one-tap support, intro/rules, reports/calendar, group chat |
| Social | friend requests, `/friends`, `/direct-chats*` |
| Notifications | `/notifications`, read endpoints, `/devices/register`, `/devices/unregister`, `/events/stream` |
| Operations | moderator-only `/ops/metrics` |

Media routes require a valid access token: `/media/{server}/{id}` is allowed
only for a matching group/direct/report record, `/local-media/{id}` applies the
same ownership or membership checks, and `/users/{id}/avatar/{filename}` serves
private avatars. The legacy `/uploads/avatars/{filename}` URL is retained as an
authenticated compatibility route; there is no public uploads mount.

Session responses include `access_token`, `token_type`, `expires_in` and a
`refresh_token`. Clients store the refresh token in platform secure storage,
rotate it through `/auth/refresh`, and call `/auth/logout` when the session
ends.

Compatibility changes in this handoff:

- `GET /notifications` accepts `limit` (1–100) and opaque `before`; response
  adds `has_more` and `next_before` while preserving existing fields.
- Group chat send accepts optional `client_id` (maximum 64 characters) and
  echoes it in the message payload. Retrying the same sender/key returns the
  original message.
- Errors preserve `detail` and add `error.code`, `error.message`,
  `error.requestId`, `error.retryable` and `error.fields`.

Team-cycle additions:

- `GET /groups/overview` is the Home/Groups read model. It returns `groups`,
  `active`, `preparing`, `waiting_room`, `membership_consistent` and a maximum
  `revision`. Group cards are assembled in five SQL queries regardless of the
  number of groups; recap, milestones and personal impact remain on group
  detail.
- `GET /groups/{id}` adds `revision`, `cycle_day`, current member
  `report_status`/`check_in_kind`, `my_today_report`, `team_day`,
  `team_pulse`, weekly recap/milestones and `personal_result`.
- `POST /groups/{id}/support` accepts `target_user_id` and optional `message`.
  It creates one durable `prime.support` chat event, an addressed notification
  and a revisioned realtime event. Sender/recipient has a ten-minute cooldown.
- `POST /groups/{id}/vote` is available only in `completed`/`voting` phases.
  Accepted choices are `continue_together`, `new_skill`, `harder` and
  `recovery`. The choice is audited, written to team chat and emitted as a
  revisioned group update.
- `POST /groups/{id}/intro/change` deactivates the old membership, writes
  membership history, immediately creates the new queue state and returns that
  state. The client does not need a page refresh.
- `GET /groups/membership-history` exposes the authenticated user's immutable
  join/leave/fill history for support and reconciliation.
- `POST /groups/waiting-room/early-start` creates or confirms a 15-minute
  proposal. The first call notifies the other eligible users with request ID,
  expiry, deep link and actions; three current confirmations atomically form a
  three-person group.
- Group and queue SSE messages carry `revision`, `phase` and `reason`. Clients
  ignore stale/duplicate revisions and poll preparation state only when SSE is
  disconnected.
