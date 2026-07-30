# ADR 0004: Durable group-message idempotency

Status: accepted.

Accept a client-generated key, persist it with a unique sender/key constraint,
and use it as the Matrix transaction ID. A retry returns the canonical row.
This closes duplicate UI/message creation without introducing a broker; a
future outbox is still needed for durable cross-instance event delivery.
