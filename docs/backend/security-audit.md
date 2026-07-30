# Security audit handoff

Scope: FastAPI backend, Flutter HTTP/session client, uploads, Matrix
integration, Docker/web-server configuration and database migrations in this
repository. This is a source-and-test audit; no production credentials or
live infrastructure were used.

## 1. Attack surface

- authentication and password reset;
- JWT access and refresh sessions;
- user/group/direct-message authorization;
- REST, SSE and upload endpoints;
- Matrix media and encrypted integration tokens;
- local media/avatar storage;
- PostgreSQL, migrations, outbox and Docker deployment;
- Flutter cache, web CSP and token storage.

## 2. Verified findings

### Fixed high-impact paths

| Area | Attack chain | Control now in code |
|---|---|---|
| Token theft/replay | Steal an access token and reuse it after logout | `sid` session lookup, 15-minute cap, revoke on logout/password changes |
| Refresh replay | Reuse a rotated refresh token | SHA-256 token hashes, old-session revoke and one-time rotation |
| Password reset leakage | Read reset token from the forgot-password response | Response is generic; token is only passed to the mail task |
| IDOR media | Request another user's Matrix/local media ID | Message/report ownership and group/direct membership checks |
| Upload abuse | Send oversized, SVG/HTML or polyglot image data | bounded reads, type allowlists, Pillow verification/re-encode, metadata removal |
| Group escalation | Call operational team assembly as a normal member | moderator dependency and membership checks |
| Brute force | Rotate API workers to bypass an in-memory counter | database-backed rate-limit buckets |
| Secret exposure | Read Matrix token from the database | Fernet encryption at rest and separate Matrix password secret |

### Residual release blockers

1. The repository `.env` contains environment-specific values and is retained
   unchanged by request. It is not a production-safe secret store; production
   must inject rotated secrets from a manager.
2. PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)`, load latency percentiles and a live
   container scan were not available in this workspace. The code and SQLite
   suite pass, but that is not evidence of production capacity.
3. The realtime hub is process-local. Horizontal realtime fan-out requires a
   measured broker decision after observing connection count and queue lag.

## 3. Attack scenarios and expected result

Use only the local staging environment. A request with a revoked access token
to any protected route returns `401`; a valid token for user A requesting a
user-B-only media asset returns `404`; a sixth request in a configured rate
window returns `429`; a second use of a rotated refresh token returns `401`.
These behaviors are covered by `tests/test_security_sessions.py`,
`tests/test_media_security.py` and the auth/upload regression tests.

## 4. Fixes delivered

- migrations `0003_security_sessions_limits.sql` and
  `0004_private_media.sql`;
- access/refresh session lifecycle in `app/sessions.py` and `app/deps.py`;
- database rate limiting in `app/rate_limit.py`;
- private media pipeline in `app/media.py` and authenticated media routes;
- Matrix token encryption in `app/secret_box.py`;
- CSP/COOP/Corp, restrictive CORS, non-root Docker user and read-only
  production API container;
- Flutter secure refresh-token storage, rotation interceptor and user-scoped
  cache keys;
- CI checks for Bandit, pip-audit, Gitleaks and Trivy.

## 5. Final score

**78/100 — strong pre-production baseline, not production approval.**

The score includes implemented controls and subtracts for the retained local
`.env`, missing live PostgreSQL/load evidence and process-local realtime. The
remaining score is recovered by secret rotation, staging attack tests,
PostgreSQL plans/metrics and a production deployment review.
