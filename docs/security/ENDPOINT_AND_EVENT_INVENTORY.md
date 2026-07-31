# Endpoint and Event Inventory

Date: 2026-07-31  
Regenerate: `cd prime-backend && python3 tools/generate_security_inventory.py`

Total HTTP routes under `/api/v1`: **103** (verified by introspection script).

## Auth (`/api/v1/auth`)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/auth/email-available` | Public | Anti-enumeration: existing emails → `available=false` |
| GET | `/auth/nickname-available/{nickname}` | Public | Registration UX |
| POST | `/auth/register` | Public | Rate-limited; issues verification code, no token |
| POST | `/auth/verify-email` | Public | Issues access + refresh tokens |
| POST | `/auth/resend-verification` | Public | Cooldown + attempt limits |
| POST | `/auth/login` | Public | DB-backed rate limit; audit on success/failure |
| POST | `/auth/forgot-password` | Public | Uniform response shape |
| POST | `/auth/reset-password` | Public | Revokes sessions on success |
| POST | `/auth/refresh` | Bearer | Rotating refresh in `auth_sessions` |
| POST | `/auth/logout` | Bearer | Revokes session + device unregister when possible |

## Moderator MFA (`/api/v1/auth/mfa`)

| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/auth/mfa/totp/enroll` | Moderator JWT | Returns `otpauth_uri` |
| POST | `/auth/mfa/totp/verify` | Moderator JWT | Enrollment confirm or step-up |
| POST | `/auth/mfa/backup-code/verify` | Moderator JWT | One-time backup codes |
| POST | `/auth/mfa/webauthn/register/options` | Moderator JWT | Passkey registration |
| POST | `/auth/mfa/webauthn/register/verify` | Moderator JWT | Stores credential |
| POST | `/auth/mfa/webauthn/authenticate/options` | Moderator JWT | Step-up challenge |
| POST | `/auth/mfa/webauthn/authenticate/verify` | Moderator JWT | Creates step-up session |

## Users (`/api/v1/users`)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/users/me` | Bearer | Current profile |
| PATCH | `/users/me` | Bearer | `photo_url` stripped; text moderated |
| DELETE | `/users/me` | Bearer | Account deletion |
| POST | `/users/me/avatar` | Bearer | Upload + re-encode |
| DELETE | `/users/me/avatar` | Bearer | |
| POST | `/users/me/password` | Bearer | Revokes other sessions |
| GET/PATCH | `/users/me/preferences` | Bearer | |
| GET | `/users/me/stats` | Bearer | |
| GET | `/users/me/prime-events` | Bearer | |
| GET/POST/DELETE | `/users/me/favorites/{skill_id}` | Bearer | |
| POST | `/users/me/shields/buy` | Bearer | |
| POST | `/users/me/shields/use` | Bearer | |
| GET | `/users/{user_id}/avatar/{filename}` | Public | Scoped filename validation |

## Catalog & media (`/api/v1`)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/health` | Public | Liveness |
| GET | `/regions` | Public | |
| GET | `/skills` | Public | Program catalog |
| POST | `/skills/custom` | Bearer | Custom habit creation |
| GET | `/achievements` | Public | |
| GET | `/media/{server_name}/{media_id}` | Bearer | Matrix proxy with membership check |
| GET | `/local-media/{asset_id}` | Bearer | Private asset read |
| GET | `/media/assets/{asset_id}/status` | Bearer | Quarantine scan status |

## Social & DMs

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/users/by-nickname/{nickname}` | Bearer | Discovery |
| GET | `/users/discover` | Bearer | |
| GET/POST | `/friends/requests` | Bearer | Rate-limited sends |
| POST/DELETE | `/friends/requests/{request_id}/...` | Bearer | Respond / cancel |
| GET | `/friends` | Bearer | |
| GET | `/direct-chats` | Bearer | Inbox |
| GET/POST | `/direct-chats/{friend_id}/messages` | Bearer | Moderation + media scope |
| POST | `/direct-chats/{friend_id}/upload` | Bearer | Quarantine pipeline |
| POST | `/direct-chats/{friend_id}/read` | Bearer | Read receipts |
| POST | `/direct-chats/messages/{message_id}/reactions` | Bearer | |

## Groups & waiting room

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/groups`, `/groups/current`, `/groups/overview` | Bearer | Membership filtered |
| GET | `/groups/membership-history` | Bearer | |
| GET | `/groups/{group_id}` | Bearer | Member-only |
| POST | `/groups/{group_id}/check-in` | Bearer | Daily report |
| POST | `/groups/{group_id}/support`, `/nudge`, `/vote` | Bearer | Team interactions |
| POST | `/groups/{group_id}/intro/*`, `/rules/accept`, `/confirm-participation` | Bearer | Onboarding flow |
| POST/GET/DELETE | `/groups/waiting-room/*` | Bearer | Matchmaking queue |
| POST | `/dev/groups/assemble-test-team` | Dev/moderator | Disabled when `ENABLE_DEV_TOOLS=false` |

## Chat (group)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/chat/{group_id}/messages` | Bearer | Member-only |
| POST | `/chat/{group_id}/messages` | Bearer | Moderation + media scope |
| POST | `/chat/sync` | Bearer | Incremental sync |
| POST | `/chat/send`, `/chat/send-image`, `/chat/upload` | Bearer | Legacy + upload paths |
| POST | `/chat/messages/{message_id}/reactions` | Bearer | |

## Notifications & devices

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/notifications` | Bearer | Keyset pagination |
| POST | `/notifications/{id}/read`, `/notifications/read-all` | Bearer | |
| POST | `/devices/register` | Bearer | Hijack prevention (409) |
| POST | `/devices/unregister` | Bearer | Logout cleanup |
| GET | `/events/stream` | Bearer | SSE (see below) |

## Reports

| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/reports/upload` | Bearer | Check-in photo |
| GET | `/reports/calendar`, `/reports/calendar/all` | Bearer | |
| POST | `/reports` | Bearer | Text report submission |

## Moderation & ops

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/users/me/restriction` | Bearer | Active `SOCIAL_WRITE` ban |
| POST | `/moderation/appeals` | Bearer | One appeal per decision |
| GET | `/ops/moderation/appeals` | Moderator + step-up | Pending queue |
| POST | `/ops/moderation/appeals/{id}/resolve` | Moderator + step-up | UPHOLD / REVERSE / ESCALATE |
| GET | `/ops/metrics` | Moderator + step-up | Request + SSE + outbox metrics |

## SSE event types (`GET /api/v1/events/stream`)

| Event | Trigger | Payload summary |
|---|---|---|
| `notification` | New in-app notification | Notification row JSON |
| `direct_message` | DM sent to subscriber | `friend_id`, `message_id`, optional body |
| `direct_chat_read` | Peer read DM thread | `friend_id`, `read_at` |
| `waiting_room_update` | Queue revision | `skill_id`, `revision`, `reason` |
| `group_update` | Membership/intro change | `group_id`, `phase`, `revision` |
| `group_chat_update` | New group chat message | `group_id` |
| `: heartbeat` | Every ~15s | SSE comment keep-alive |

## Middleware order (all routes)

1. CORS (`CORSMiddleware`)
2. Security headers (`security_headers_middleware`)
3. Global authenticated rate limit (`global_rate_limit_middleware`)
4. Request logging + metrics (`request_log_middleware`)

Auth-specific rate limits (login, register, upload, friend requests) are enforced inside route handlers via `app/rate_limit.py`.
