# SLO and observability

The request middleware records a bounded in-process sample by normalized route
template. Moderator-only `GET /api/v1/ops/metrics` exposes:

- request count, 5xx rate, p50/p95/p99/max and active requests;
- active SSE connections, subscribed users and queued events;
- pending/retrying push outbox events and oldest lag;
- SQLAlchemy pool status.

The middleware also logs method/route/status/elapsed/request ID. Metrics reset
on process restart and are intentionally not a replacement for production
time-series storage. Distributed tracing, upload throughput and provider-side
push latency are not yet exported.

Use the request ID from `X-Request-ID` and structured error responses when
correlating a failure. Alert first on 5xx rate, p95 for
`/groups/overview`/reports, outbox lag and DB pool saturation. Persist these
metrics externally only after choosing the existing deployment's monitoring
target; no Redis/Kafka/Prometheus service was introduced without a measured
bottleneck.
