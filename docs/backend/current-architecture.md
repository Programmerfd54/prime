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
then applies numbered PostgreSQL migrations through `schema_migrations`. New
hot-path indexes and group-message idempotency are in migration `0002`.

The intended scale boundary is still one modular monolith plus PostgreSQL and
Matrix. A shared broker should be introduced only after the metrics in the
scalability plan show that the current design is the bottleneck; the outbox is
the current low-complexity durability boundary.
