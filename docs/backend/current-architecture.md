# Current backend architecture

PRIME is a FastAPI modular monolith. The Flutter client calls `/api/v1`; the
API validates a short-lived JWT against a revocable database session, executes
router and service helpers, and uses SQLAlchemy async sessions against
PostgreSQL in deployment (SQLite is used by the current unit tests). Matrix
Synapse is an optional external chat/media integration. Local media is stored
outside the public web tree and is served only through authenticated routes.

The runtime deliberately has no Redis or Kafka. Realtime remains an in-process
direct-message hub plus an SSE endpoint with database polling fallback; push
delivery records a redacted token fingerprint. Notification fan-out now uses a
database outbox worker, so retries do not block the request and pending work is
durable across API restarts.

Startup retains the historical idempotent schema bootstrap for compatibility,
then applies numbered PostgreSQL migrations through `schema_migrations`.
Migration `0005` adds revisioned team state, membership history, expiring
early-start proposals and the indexes used by the batched group overview.
Migration `0006` adds moderation decisions and private-media scope tracking.

The primary team read is `GET /groups/overview`. It returns preparation,
active-cycle and waiting-room state in one response. Its group-card path uses
five SQL statements for one or many groups; full personal progress remains on
the detail endpoint so list latency does not grow through N+1 queries.

The intended scale boundary is still one modular monolith plus PostgreSQL and
Matrix. A shared broker should be introduced only after the metrics in the
scalability plan show that the current design is the bottleneck; the outbox is
the current low-complexity durability boundary.
