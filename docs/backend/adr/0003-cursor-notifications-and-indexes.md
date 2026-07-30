# ADR 0003: Keyset pagination for notifications

Status: accepted.

Use `(created_at,id)` as an opaque cursor. This avoids offset drift and gives a
stable order when timestamps collide. Composite indexes support the exact
filter/order shape; older clients can continue calling the endpoint without a
cursor.
