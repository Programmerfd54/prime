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
| Matching | `/groups/waiting-room*`, `/groups`, `/groups/current`, group detail |
| Group activity | check-in, intro/rules, reports/calendar, group chat |
| Social | friend requests, `/friends`, `/direct-chats*` |
| Notifications | `/notifications`, read endpoints, `/devices/register`, `/events/stream` |

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
