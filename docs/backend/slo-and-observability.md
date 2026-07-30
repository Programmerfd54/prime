# SLO and observability

The specification calls for latency p50/p95/p99, error rate, RPS, DB pool
wait/usage, query duration, queue lag, websocket/SSE connections, upload
throughput, push latency and saturation signals. The current request middleware
logs method/path/status/elapsed/request ID; metrics export and distributed
tracing are not yet implemented.

Use the request ID from `X-Request-ID` and structured error responses when
correlating a failure. Add dashboards only after a real runtime is available;
do not turn the SQLite test duration into a production SLO. Initial targets
should be agreed from measured traffic, then checked against the prompt's
critical-path targets during a staged rollout.
