# Realtime and chat

The client uses SSE at `/events/stream`. Group-state events carry a monotonic
database `revision`, current `phase` and a semantic `reason`; queue events carry
their own revision. Flutter drops stale/duplicate events. The introduction and
rules screens use a ten-second poll only while SSE is disconnected, while the
waiting-room controller remains the bounded queue fallback.

The server-side direct-message hub is process-local with bounded queues. The
moderator `/ops/metrics` endpoint exposes current SSE connections, subscribed
users and queued events. The hub is useful for a single API process but does
not provide cross-instance delivery or replay after reconnect.

Messages are durable in PostgreSQL before the API response is considered
successful. Direct messages use `client_id` plus a unique index. Group messages
now have the same idempotency contract and pass a deterministic Matrix
transaction ID when a client key is present. The response includes `id`,
`event_id`, `client_id`, content metadata and reactions.

Phase transitions and check-ins write system messages to the group chat so
everyone sees the same history: participation confirmation, agreement opened,
cycle started, support requested, participant changed. Matrix failure keeps a
durable local chat record.

Remaining risks are Matrix network I/O inside parts of the group transaction,
no server-side chat receipt model, and no durable SSE replay cursor. These
should be addressed only when measured SLO/load evidence justifies the
operational cost.
