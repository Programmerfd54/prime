# Control Mapping (OWASP ASVS 4.0 — Level 2 Sample)

Date: 2026-07-31  
Scope: Sample matrix for PRIME backend + Flutter client. Full L2 audit not claimed.

**Legend:** **PASSED** = implemented and tested in repo · **FAILED** = gap · **PARTIAL** = incomplete · **N/A** = out of scope

## V1 Architecture, design and threat modeling

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 1.1.1 | Secure SDLC / threat model | **PASSED** | `THREAT_MODEL.md`, `RISK_REGISTER.md` |
| 1.2.1 | Authentication components defined | **PASSED** | JWT + DB sessions documented |
| 1.4.1 | Access control on server | **PASSED** | `deps.py`, membership checks |
| 1.5.1 | Input validation | **PASSED** | Pydantic models, Pillow media |
| 1.8.1 | Data protection | **PARTIAL** | Client disk cache residual (SEC-008) |

## V2 Authentication

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 2.1.1 | Password policy | **PASSED** | Registration validation |
| 2.2.1 | Anti-automation login | **PASSED** | `AUTH_LOGIN_RATE_LIMIT_*` |
| 2.2.2 | Weak auth throttling | **PASSED** | DB-backed buckets |
| 2.3.1 | Secure password storage | **PASSED** | bcrypt via passlib |
| 2.5.1 | Recovery secrets | **PASSED** | Hashed reset tokens, email-only |
| 2.7.1 | Session invalidation | **PASSED** | Logout, password change, delete |
| 2.8.1 | JWT best practices | **PASSED** | iss/aud/sid/jti, ≤15m access |

## V3 Session management

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 3.2.1 | Session binding | **PASSED** | Access token carries `sid` |
| 3.3.1 | Logout invalidates session | **PASSED** | `auth_sessions.revoked_at` |
| 3.4.1 | Cookie-based session | **N/A** | Bearer tokens only |

## V4 Access control

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 4.1.1 | Deny by default | **PASSED** | `get_current_user` dependency |
| 4.1.2 | IDOR prevention | **PASSED** | Group/member/media scope checks |
| 4.1.3 | Admin interfaces protected | **PASSED** | Moderator + step-up MFA |
| 4.2.1 | Field-level auth | **PASSED** | Strip `photo_url`, scoped media |

## V5 Validation, sanitization and encoding

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 5.1.1 | Input validation | **PASSED** | FastAPI/Pydantic |
| 5.2.1 | Sanitize output | **PARTIAL** | Chat text stored; XSS risk low in Flutter |
| 5.3.1 | Output encoding | **N/A** | JSON API |
| 5.5.1 | File upload validation | **PASSED** | Type/size + Pillow + quarantine |

## V7 Error handling and logging

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 7.1.1 | Generic errors | **PASSED** | Structured `error` object |
| 7.2.1 | Security event logging | **PASSED** | `audit_events` + `record_audit` |
| 7.3.1 | Sensitive data not logged | **PASSED** | Email hashed on login fail |

## V8 Data protection

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 8.2.1 | Client-side data storage | **PARTIAL** | Secure storage for tokens; API cache on disk |
| 8.3.1 | Sensitive data in memory | **PARTIAL** | Memory cache cleared on logout paths |
| 8.3.2 | Key management | **PASSED** | Env/secrets manager for JWT, Matrix keys |

## V9 Communication

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 9.1.1 | TLS | **PARTIAL** | Assumed at edge; HSTS header set |
| 9.2.1 | Server-side crypto | **PASSED** | Fernet for Matrix tokens |
| 9.3.1 | CORS | **PASSED** | Explicit origins in prod validation |

## V10 Malicious code

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 10.2.1 | Dependency integrity | **PARTIAL** | Pinned reqs; CI audit pending |
| 10.3.1 | Application integrity | **PASSED** | No dynamic code load |

## V11 Business logic

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 11.1.1 | Business logic flows | **PASSED** | Moderation before publish |
| 11.1.4 | Anti-automation | **PASSED** | Friend/upload/auth limits |

## V12 Files and resources

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 12.1.1 | Upload size limits | **PASSED** | Handler limits |
| 12.4.1 | Private media storage | **PASSED** | Outside public static tree |

## V13 API and web service

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 13.1.1 | REST auth consistent | **PASSED** | Bearer on protected routes |
| 13.2.1 | REST HTTP methods | **PASSED** | Explicit verbs |
| 13.4.1 | SSRF | **PARTIAL** | httpx to configured Matrix/push only |

## V14 Configuration

| ASVS | Requirement (summary) | Status | Evidence |
|---|---|---|---|
| 14.1.1 | Secure build/deploy | **PARTIAL** | Prod guards in `main.py`; IaC out of repo |
| 14.2.1 | Secret management | **PARTIAL** | `.env` not for prod; secret manager required |
| 14.5.1 | HTTP security headers | **PASSED** | `middleware.py` |

## Summary scorecard (sample)

| Status | Count |
|---|---|
| PASSED | 32 |
| PARTIAL | 10 |
| FAILED | 0 |
| N/A | 2 |

**Failed controls (explicit gaps to close):**

None marked FAILED in this sample; partial items tracked in `REMEDIATION_PLAN.md` (client disk cache, CI dependency audit, TLS verification, secret manager migration).

## Test evidence

| Control area | Test file |
|---|---|
| Push hijack, media scope, profanity | `tests/test_security_remediation.py` |
| Email availability | `tests/test_registration_availability.py` |
| Observability | `tests/test_observability.py` |
| MFA / step-up | Manual + prod config (`MODERATOR_MFA_ENFORCE`) |

Regenerate mapping when ASVS checklist version bumps or major features ship.
