# Threat Model (STRIDE)

Date: 2026-07-31  
Method: STRIDE per trust boundary + 18 end-to-end flow summary.

## Assets

| ID | Asset | Owner |
|---|---|---|
| A1 | User accounts & sessions | Users |
| A2 | Chat/DM content | Users / groups |
| A3 | Media uploads | Users |
| A4 | Push device tokens | Users |
| A5 | Moderator privileges | Platform |
| A6 | Audit & moderation records | Platform |
| A7 | API availability & integrity | Platform |

## STRIDE matrix (by boundary)

| Boundary | S | T | R | I | D | E |
|---|---|---|---|---|---|---|
| TB-1 Client↔API | Stolen refresh token | JWT forgery (weak secret) | Log tampering N/A | IDOR via guessed IDs | Auth endpoint flood | Privilege via `is_moderator` without MFA |
| TB-2 API↔DB | Session fixation | SQL injection | Audit row deletion | Cross-tenant reads | DB exhaustion | ORM bypass |
| TB-3 Media scope | URL reuse across groups | Pending URL swap | Upload registry tampering | Read others' MXC/local media | Upload flood | Scope mismatch attach |
| TB-4 Matrix | Token theft at rest | MITM to Synapse | — | Room membership leak | Synapse DoS | Shared secret misuse |
| TB-5 Push | Token hijack on register | Fake FCM/APNs | — | Notification content leak | Push spam | Cross-account bind |
| TB-6 Moderator | Compromised laptop | Step-up bypass | Audit omission | Appeal PII exposure | Ops endpoint scrape | MFA not enforced |
| TB-7 Moderation | Evasion (leetspeak) | Policy downgrade | Decision repudiation | Profanity in logs | Pipeline bypass | Restriction not applied |
| TB-8 Realtime SSE | Subscribe with stolen JWT | Event injection | — | DM metadata leak | Connection exhaustion | Cross-user fan-out bug |

## Mitigations mapped

| Threat | Control | Code / config |
|---|---|---|
| Token theft | Short access TTL, refresh rotation, secure client storage | `config.py`, `AuthStorage` |
| IDOR media | `media_uploads` scope validation | `media_scope.py`, chat/social routers |
| Push hijack | 409 on cross-user token | `notifications.py` |
| Email enumeration | Uniform false on `/auth/email-available` | `auth.py` |
| Profanity | Pre-publish classifier + 18h restriction | `moderation/*` |
| Moderator abuse | TOTP/WebAuthn step-up, prod enforce | `mfa/*`, `deps.require_moderator_step_up` |
| Upload malware | Quarantine worker + ClamAV option | `media_pipeline/*` |
| DoS | Global + auth rate limits | `rate_limit_middleware.py`, `rate_limit.py` |
| CORS misconfig | Prod startup validation | `main.py::_validate_production_settings` |

---

## 18 flows summary

Each flow lists primary assets, trust boundary, top threat, and control status.

| # | Flow | Asset | Boundary | Top threat | Status |
|---|---|---|---|---|---|
| F-01 | Register + verify email | A1 | TB-1 | Enumeration, spam signup | **Mitigated** — rate limits, no pre-verify token |
| F-02 | Login + refresh + logout | A1 | TB-1 | Credential stuffing | **Mitigated** — DB rate limit, audit, rotation |
| F-03 | Password reset | A1 | TB-1 | Account takeover | **Mitigated** — uniform forgot response, session revoke |
| F-04 | Profile PATCH + avatar | A1, A3 | TB-1/7 | Spoofed avatar URL, toxic bio | **Mitigated** — strip `photo_url`, moderate text |
| F-05 | Waiting room matchmaking | A1 | TB-1 | Queue manipulation | **Partial** — server-side matching; dev endpoint gated |
| F-06 | Group membership actions | A1 | TB-2 | Non-member access | **Mitigated** — membership checks in routers |
| F-07 | Group chat send | A2, A3 | TB-3/7 | Cross-group media IDOR, profanity | **Mitigated** — scope + moderation |
| F-08 | Group chat read/sync | A2 | TB-2 | Non-member read | **Mitigated** — member query filters |
| F-09 | DM send/read | A2, A3 | TB-3/7 | Non-friend DM, toxic content | **Mitigated** — friendship gate + moderation |
| F-10 | Media upload (chat/DM/report) | A3 | TB-3 | Malware, oversized file | **Mitigated** — size/type checks, quarantine worker |
| F-11 | Media download | A3 | TB-3 | IDOR read | **Mitigated** — auth + scope on serve paths |
| F-12 | Friend request | A1 | TB-1 | Harassment spam | **Mitigated** — hourly rate limit, audit |
| F-13 | Push register/deliver | A4 | TB-5 | Token hijack | **Mitigated** — SEC-001 fix |
| F-14 | SSE subscribe + events | A2 | TB-8 | Cross-user events | **Mitigated** — per-user hub subscription |
| F-15 | Notifications list/read | A1 | TB-2 | Cross-user notifications | **Mitigated** — user_id filter |
| F-16 | Horizontal API scale | A7 | TB-8 | Split-brain SSE | **Accepted** — process-local hub; metrics in `/ops/metrics` |
| F-17 | Moderator appeal ops | A5, A6 | TB-6 | Privileged action without MFA | **Mitigated** — step-up when `MODERATOR_MFA_ENFORCE` |
| F-18 | Account deletion | A1 | TB-2 | Incomplete erasure | **Partial** — user row deleted; media/orphan review in REMEDIATION |

## Attack trees (selected)

### AT-1 Cross-group media reuse

1. Attacker uploads image to Group A → obtains `mxc://` or `local://` URL  
2. Attempts attach URL in Group B message  
3. **Blocked** at `validate_media_url_for_scope` (403)

### AT-2 Push token hijack

1. Attacker obtains victim device token  
2. Registers token on attacker account  
3. **Blocked** with 409; token remains bound to original user

### AT-3 Moderator session riding

1. Attacker steals moderator JWT  
2. Calls `/ops/moderation/appeals`  
3. **Blocked** when prod requires valid step-up session (`moderator_step_up_sessions`)

## Residual risks

See `RISK_REGISTER.md` SEC-008 (client disk cache), SEC-009 (detail route shell before AppGate), SEC-010 (SSE scale).

## Review cadence

- Per major feature touching TB-1, TB-3, or TB-6  
- Quarterly STRIDE refresh  
- After any SEC-*** incident
