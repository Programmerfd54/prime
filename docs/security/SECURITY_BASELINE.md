# PRIME Security Baseline

Date: 2026-07-31  
Scope: `prime-backend`, `prime-flutter`, migrations, CI configs in this repository.

## Stack (verified from code)

| Layer | Technology |
|---|---|
| Mobile/Web client | Flutter (Android, Web; iOS scaffold present) |
| API | FastAPI, `/api/v1` |
| Auth | JWT access (≤15m) + refresh rotation, DB-backed sessions |
| Realtime | SSE `/events/stream` (process-local hub) |
| Chat media | Matrix MXC + local private media fallback |
| DB | PostgreSQL (prod) / SQLite (tests) |
| Push | APNs (iOS native), FCM (Android when configured) |

## Baseline checks run

| Check | Command | Status |
|---|---|---|
| Backend unit/integration tests | `pytest` in `prime-backend` | **PASSED** (127 tests) |
| Flutter analyze | `flutter analyze` | NOT_RUN |
| Flutter unit tests | `flutter test` (cache + failure_mapper) | **PASSED** (21 tests) |
| Dependency audit | pip-audit / CI | BLOCKED — run in CI pipeline |
| Secrets scan | Gitleaks (CI) | BLOCKED — run in CI pipeline |

## Trust boundaries

1. **Client ↔ API** — Bearer JWT; client is untrusted for authZ decisions.
2. **API ↔ DB** — parameterized SQLAlchemy; session revocation enforced server-side.
3. **API ↔ Matrix** — encrypted tokens at rest; media scoped by upload registry.
4. **API ↔ Push** — device tokens bound to registering user (no cross-account hijack).
5. **Moderation pipeline** — server-side pre-publish; fail-closed on high confidence.

## Controls in place (this audit)

- Session revoke + refresh rotation (`app/sessions.py`, `app/deps.py`)
- DB-backed rate limits on auth/upload (`app/rate_limit.py`)
- Upload validation + re-encode (`app/media.py`)
- Media upload scope registry + message attachment validation (`app/media_scope.py`)
- RU/EN profanity moderation + 18h `SOCIAL_WRITE` restriction (`app/moderation/`)
- Anti-enumeration on public email availability (`app/routers/auth.py`)
- Push token hijack prevention (`app/routers/notifications.py`)
- Client avatar URL spoofing blocked (`app/routers/users.py`)

## Evidence gaps (honest status)

- No live PostgreSQL load test in this workspace
- Process-local SSE hub — horizontal scale requires broker decision
- Production secret rotation not verified here
- Independent penetration test not performed in this session
