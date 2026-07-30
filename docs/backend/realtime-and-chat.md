# Realtime and chat

The client uses SSE at `/events/stream`, one-second database polling fallback,
and a one-second open-chat sync controller. The server-side direct-message hub
is process-local with bounded queues; it is useful for a single API process but
does not provide cross-instance delivery or replay after reconnect.

Messages are durable in PostgreSQL before the API response is considered
successful. Direct messages use `client_id` plus a unique index. Group messages
now have the same idempotency contract and pass a deterministic Matrix
transaction ID when a client key is present. The response includes `id`,
`event_id`, `client_id`, content metadata and reactions.

Remaining risks are Matrix network I/O inside the group transaction, no
server-side receipt model, and no durable outbox/replay cursor. These should be
addressed with an outbox and worker only when the measured SLO/load evidence
justifies the operational cost.
