# Database migrations

The application currently has a historical, idempotent bootstrap in
`app/db.py`. It is retained for compatibility with existing installations.
New PostgreSQL changes live here as numbered SQL files and are applied once at
startup through the `schema_migrations` ledger, with a SHA-256 checksum.

`0002_hot_path_indexes.sql` is additive: it adds the group-message idempotency
key and composite indexes for queue matching, chat history, reports and
notifications. It is safe to run in a transaction and has no destructive
rollback. A future migration should use expand/contract for any rename or
removal.

`0003_security_sessions_limits.sql` adds refresh-session state, distributed
rate-limit buckets, audit events and the notification outbox. `0004_private_media.sql`
adds ownership/scope metadata for local private media. Both migrations are
additive and should be applied before serving the new API build.

The current test suite uses SQLite metadata creation and therefore does not
execute PostgreSQL migrations. CI and deployment must run the API startup (or
the migration smoke command documented in `docs/backend/runbooks.md`) against
PostgreSQL before serving traffic.
