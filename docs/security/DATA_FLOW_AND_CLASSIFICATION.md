# Data Flow and Classification

Date: 2026-07-31  
Classification scheme: **Public**, **Internal**, **Confidential**, **Restricted**

## Classification levels

| Level | Definition | Examples | Storage / transit |
|---|---|---|---|
| **Public** | Safe to expose without authentication | Skill catalog, regions, health | CDN/API cache OK |
| **Internal** | Operational, non-PII | Metrics aggregates, policy versions | Logs, moderator tools |
| **Confidential** | PII or user-generated content | Email, nickname, chat text, avatars | Encrypted TLS; DB access controlled |
| **Restricted** | Auth secrets, credentials, moderation evidence | JWT refresh hashes, TOTP secrets, normalized profanity hashes | Encrypted at rest; minimal retention |

## Data inventory

| Data element | Class | Primary store | Client copy | Retention |
|---|---|---|---|---|
| Email, password hash | Confidential | `users` | Never | Until account deletion |
| Access JWT | Restricted | Client secure storage | FlutterSecureStorage | ≤15 min |
| Refresh token hash | Restricted | `auth_sessions` | FlutterSecureStorage | ≤30 days, rotated |
| Nickname, name, about | Confidential | `users` | Cached profile (secure storage) | Until deletion |
| Group chat messages | Confidential | `group_chat_messages` / Matrix | Memory + optional disk cache | Group lifecycle |
| Direct messages | Confidential | `direct_messages` | Memory + optional disk cache | Friendship lifecycle |
| Device push tokens | Restricted | `device_tokens` | OS push registry | Until unregister/logout |
| Avatar / report media | Confidential | Private uploads / Matrix MXC | Ephemeral picker bytes | User-controlled |
| Moderation decisions | Restricted | `moderation_decisions` | Not exposed to other users | Appeal + audit policy |
| Audit events | Internal | `audit_events` | None | Ops retention TBD |
| Matrix tokens | Restricted | `matrix_credentials` (encrypted) | Not on client | Until unlink |

## Critical flows

### F-01 Registration and verification

```
Client → POST /auth/register → users (unverified)
       → SMTP verification code (Confidential in transit)
       → POST /auth/verify-email → auth_sessions + JWT
```

Controls: rate limits, no token before verify, optional dev code exposure blocked in prod.

### F-02 Login and session rotation

```
Client → POST /auth/login → audit_events (success/fail)
       → JWT (sid) + refresh
Client → POST /auth/refresh → rotate refresh hash, revoke old sid row
Client → POST /auth/logout → revoke sid, unregister device
```

### F-03 Profile and avatar update

```
Client → PATCH /users/me (text fields) → moderation pipeline
       → POST /users/me/avatar → Pillow re-encode → private path
```

`photo_url` from client is rejected; only server-generated avatar URLs returned.

### F-04 Group chat publish

```
Client → POST /chat/upload → quarantine asset (pending:// URL)
Worker → scan → CLEAN → media_uploads scoped to group_id
Client → POST /chat/{group_id}/messages → moderate_text + validate_media_url_for_scope
       → SSE group_chat_update to members
```

### F-05 Direct message publish

Same moderation and media scope pattern with `scope_type=direct` and `scope_id=friend_id`.

### F-06 Push notification delivery

```
Event → outbox_worker → APNs/FCM using device_tokens
Client → POST /devices/register (409 if token owned by another user)
```

### F-07 Moderator appeal resolution

```
User → POST /moderation/appeals
Moderator (step-up MFA) → POST /ops/moderation/appeals/{id}/resolve
       → may revoke UserRestriction on REVERSE
       → audit_events
```

### F-08 Realtime SSE subscription

```
Client → GET /events/stream (Bearer)
Hub → fan-out typed events, heartbeat comments
```

Process-local queue; no cross-replica fan-out without infrastructure change.

## Client-side data handling

| Surface | Data | Class | Mitigation |
|---|---|---|---|
| FlutterSecureStorage | JWT, refresh, cached user JSON | Restricted / Confidential | OS keychain/Keystore |
| SharedPreferences | API response cache, onboarding flag | Confidential (residual) | User-scoped keys; cleared on logout for auth keys |
| In-memory `_memoryCache` | Friends, groups, DMs | Confidential | Cleared on `invalidateSocialCaches` / logout |
| Logs (client debug) | Network errors | Internal | Debug-only prints |

## Cross-border / third parties

| Processor | Data shared | DPA status |
|---|---|---|
| SMTP provider | Email address, verification/reset content | Required before prod |
| Apple APNs / Google FCM | Device token, notification payload | Platform ToS |
| Matrix Synapse (optional) | Chat content, MXC media | Self-hosted or vendor DPA |
| ClamAV (optional) | Media bytes in scan | Local sidecar |

## Logging and redaction

- Request logs include method, path, status, `request_id`; bodies are not logged by default.
- Auth failures log `email_hash` fingerprint, not raw email (`auth.py`).
- Moderation audit stores decision metadata, not raw message text (normalized hash only in `moderation_decisions`).

## Related documents

- Architecture: `ARCHITECTURE_AND_TRUST_BOUNDARIES.md`
- Threat model flows: `THREAT_MODEL.md`
- Moderation policy: `MODERATION_POLICY.md`
