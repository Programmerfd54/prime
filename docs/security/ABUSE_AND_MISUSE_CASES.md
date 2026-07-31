# Abuse and Misuse Cases

Date: 2026-07-31  
Audience: Product, moderation, backend engineering.

## Legend

| Severity | Meaning |
|---|---|
| **Critical** | Immediate harm, legal exposure, or widespread compromise |
| **High** | Significant user harm or data leak |
| **Medium** | Nuisance, limited scope |
| **Low** | Edge case / UX abuse |

| Control status | Meaning |
|---|---|
| **Blocked** | Server rejects or contains abuse |
| **Detected** | Logged/audited; manual follow-up |
| **Partial** | Some paths mitigated |
| **Gap** | Documented residual risk |

---

## Authentication & identity

| ID | Misuse | Severity | Control status | Implementation |
|---|---|---|---|---|
| AM-01 | Credential stuffing on `/auth/login` | High | Blocked | DB rate limit 8/5min; audit `auth.login.failed` |
| AM-02 | Email enumeration via register | Medium | Blocked | `/auth/email-available` returns false for any existing email |
| AM-03 | Nickname squatting at scale | Low | Partial | Per-IP/email rate limits on register |
| AM-04 | Verification code brute force | Medium | Blocked | Max attempts per code; resend cooldown |
| AM-05 | Refresh token replay after logout | High | Blocked | `auth_sessions.revoked_at` checked on every request |
| AM-06 | Developer passwordless backdoor in prod | Critical | Blocked | `ENABLE_DEV_TOOLS` + prod startup guard |

## Social graph & harassment

| ID | Misuse | Severity | Control status | Implementation |
|---|---|---|---|---|
| AM-07 | Friend request spam | Medium | Blocked | 20/hour per user (`friend_request_rate_limit_*`) |
| AM-08 | DM non-friend | Medium | Blocked | Friendship required; loader returns not found |
| AM-09 | Public nickname discovery scraping | Medium | Partial | Authenticated `/users/discover`; global rate limit |
| AM-10 | Toxic language in chat/profile | High | Blocked | Profanity pipeline; 18h `SOCIAL_WRITE` on HIGH |
| AM-11 | Repeated profanity while restricted | Medium | Blocked | `SOCIAL_WRITE_RESTRICTED`; restriction not extended |
| AM-12 | Medium-confidence evasion text | Medium | Partial | Quarantine response; user must rephrase |

## Media & content

| ID | Misuse | Severity | Control status | Implementation |
|---|---|---|---|---|
| AM-13 | Attach another user's upload URL | High | Blocked | `media_uploads` owner + scope check |
| AM-14 | Attach Group A media in Group B | High | Blocked | SEC-002 remediation |
| AM-15 | Malware in image upload | High | Partial | Quarantine + noop/ClamAV scan worker |
| AM-16 | Oversized/decompression bomb | Medium | Blocked | Byte limits + Pillow re-encode |
| AM-17 | Avatar URL impersonation | Medium | Blocked | Client `photo_url` stripped on PATCH |
| AM-18 | Report/check-in photo abuse | Medium | Partial | Same upload pipeline; manual review queue TBD |

## Push & realtime

| ID | Misuse | Severity | Control status | Implementation |
|---|---|---|---|---|
| AM-19 | Steal victim push token | High | Blocked | 409 cross-user register |
| AM-20 | SSE connection exhaustion | Medium | Partial | Global rate limit; no per-connection cap yet |
| AM-21 | Subscribe to another user's stream | Critical | Blocked | JWT `sub` binds SSE subscription |

## Moderator & ops

| ID | Misuse | Severity | Control status | Implementation |
|---|---|---|---|---|
| AM-22 | Moderator JWT without step-up | High | Blocked (prod) | `MODERATOR_MFA_ENFORCE` |
| AM-23 | Appeal flooding | Low | Partial | One appeal per decision (409) |
| AM-24 | Dev test team assembly in prod | Medium | Blocked | `ENABLE_DEV_TOOLS=false` in prod |
| AM-25 | Scrape `/ops/metrics` | Low | Blocked | Moderator + step-up |

## Client-side misuse

| ID | Misuse | Severity | Control status | Implementation |
|---|---|---|---|---|
| AM-26 | Tampered JWT claims trusted client-side | High | Blocked | Server validates sid + DB session |
| AM-27 | Deep link to group without auth | Medium | Partial | API 401; UI may flash loader (SEC-009) |
| AM-28 | Extract chat from device backup | Medium | Gap | Disk cache for social GET still present (SEC-008) |
| AM-29 | Offline queue replay reports | Low | Partial | Server idempotency on reports where implemented |

## Platform & availability

| ID | Misuse | Severity | Control status | Implementation |
|---|---|---|---|---|
| AM-30 | API-wide DoS | High | Partial | 300 req/min per user/IP global limit |
| AM-31 | Upload flood | Medium | Blocked | Upload rate limit 30/5min |
| AM-32 | Password reset email flood | Medium | Blocked | 3/15min per email/IP |

## Response playbook cross-reference

| Misuse cluster | Incident playbook |
|---|---|
| AM-01, AM-05, AM-06 | IR-02 Credential abuse |
| AM-10–AM-12 | IR-08 Moderation surge |
| AM-13–AM-15 | IR-09 Malicious media |
| AM-19 | IR-10 Push anomaly |
| AM-22 | IR-11 Moderator compromise |

See `INCIDENT_RESPONSE.md` and `MODERATION_POLICY.md`.
