# Security and privacy

The API uses short-lived bearer JWT access tokens, rotating refresh sessions,
email verification, per-route membership checks and database-backed rate
limits. Error responses preserve the legacy `detail` field and add a
structured `error` object with request ID, retryability and fields.

Implemented controls:

- access JWTs carry `iss`, `aud`, `sid`, `jti`, `iat` and expire after at most
  15 minutes; refresh tokens are hashed in `auth_sessions`, rotated on use and
  revoked on logout, password change, password reset and account deletion;
- login, verification, registration, password reset and upload attempts use
  PostgreSQL/SQLite-backed buckets, so limits survive multiple API processes;
- Matrix access tokens are encrypted at rest with Fernet and Matrix passwords
  are derived from a separate secret; plaintext legacy tokens are migrated at
  startup and are not used for new writes;
- local media and avatars are outside the public static tree, read through
  authenticated ownership/membership checks, bounded by bytes, validated with
  Pillow and stripped of image metadata;
- CSP, `nosniff`, frame isolation, restrictive CORS and private/no-store media
  cache headers are applied by the API and web server;
- moderator-only operational endpoints and membership checks close the
  previously reachable group-management paths; keyset cursors and bounded
  limits protect list endpoints.
- device registrations are removed server-side on logout when reachable; iOS
  also unregisters from remote notifications and clears delivered team
  notifications locally, so an offline logout does not leave native delivery
  enabled on the signed-out installation.

Release prerequisites:

- replace every local `.env` secret with a secret-manager value before
  production; the repository `.env` is left untouched by this handoff;
- run migrations against PostgreSQL, enable HTTPS/HSTS at the edge, restrict
  CORS to the real app origins, and keep private media/database volumes out of
  public web roots;
- run the CI Bandit, pip-audit, Gitleaks and Trivy jobs and capture a real
  PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` plus load-test baseline before
  approving a production rollout.
