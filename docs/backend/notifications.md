# Notifications

In-app notifications are durable rows in `notifications`; device registrations
are in `device_tokens`. `GET /notifications` keeps the existing `items` and
`unread_count` fields and now supports `limit` plus an opaque `before` cursor
ordered by `(created_at DESC, id DESC)`.

Push delivery is currently a stub. Logs contain only a short SHA-256 token
fingerprint, never a token prefix. SSE emits notification and direct-message
events, but the current in-process hub and polling fallback are single-process
and do not guarantee replay across restart. A durable outbox/deduplication
worker is a planned follow-up, gated by measured push/SSE SLO pressure.
