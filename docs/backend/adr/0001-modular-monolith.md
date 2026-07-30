# ADR 0001: Keep the modular monolith

Status: accepted.

The measured baseline does not prove a service-boundary bottleneck. Keep
FastAPI, PostgreSQL and Matrix in one deployment unit while improving query
bounds, indexes, idempotency and observability. Revisit only with load/soak and
database saturation evidence.
