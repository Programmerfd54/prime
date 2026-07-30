# Scalability plan and evidence gates

## Current tier

Keep one FastAPI modular monolith, PostgreSQL, Matrix and local deployment
volumes. Use the configured async DB pool, bounded matching, composite indexes,
cursor pagination and idempotency keys. Do not add Redis/Kafka/microservices
without evidence.

## Measure before scaling out

Capture endpoint p50/p95/p99, RPS, error rate, DB pool wait/usage, PostgreSQL
CPU/IO/locks, queue age, SSE connections, Matrix latency, upload throughput and
push latency. The SQL plans in `prime-backend/tools/explain_hot_paths.sql` must
be captured before and after index changes.

## Trigger examples

- Add a worker/outbox when durable event backlog or notification latency exceeds
  the agreed SLO while PostgreSQL and API CPU are healthy.
- Add a shared realtime broker when multiple API instances are required and
  SSE reconnect/replay loss is observed.
- Add read replicas only when read CPU/IO is the bottleneck and consistency
  requirements allow it.
- Partition/archive only after table growth and query plans show it is needed.

Every scale-out must include a rollback, load/soak evidence, and an updated
capacity estimate; architecture size is not itself a success metric.
