# Backend handoff index

- [baseline-before](baseline-before.md) and [baseline-after](baseline-after.md)
- [current architecture](current-architecture.md) and [request flows](request-flows.md)
- [data model](data-model.md), migrations and [matching](matching.md)
- [realtime/chat](realtime-and-chat.md), [attachments](attachments.md),
  [notifications](notifications.md)
- [scalability plan](scalability-plan.md), [security](security-and-privacy.md),
  [SLO/observability](slo-and-observability.md), [runbooks](runbooks.md)
- [API contract](api.md) and ADRs under `adr/`

The authoritative implementation and test handoff is:

- `prime-backend/app/models.py` — SQLAlchemy schema;
- `prime-backend/app/db.py` — compatibility bootstrap and migration ledger;
- `prime-backend/migrations/` — additive PostgreSQL migrations;
- `prime-backend/tests/` — existing and new regression tests;
- `prime-backend/deployment/` and `.github/workflows/backend-ci.yml` — deployment/CI.
