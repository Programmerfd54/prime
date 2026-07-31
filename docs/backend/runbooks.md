# Runbooks

## Local startup

```bash
cd prime-backend
cp .env.example .env
docker compose up -d --build
curl -fsS http://localhost:8080/api/v1/health
python3 -m pytest -q
```

The API startup applies the historical bootstrap and then checked-in
PostgreSQL migrations. Check the `schema_migrations` table before a rollout:

```sql
SELECT version, checksum, applied_at
FROM schema_migrations
ORDER BY version;
```

Expected versions for this handoff are `0002` through `0006`. A checksum
mismatch is a failed deployment: stop and restore the reviewed migration file,
never edit the ledger.

## Production rollout

1. Back up PostgreSQL and verify restore instructions on staging.
2. Inject secrets through the deployment environment; do not copy the local
   `.env` into production.
3. Pin `SYNAPSE_IMAGE`, build the API image and run the CI security jobs.
4. Start one API instance, wait for `/api/v1/health`, then verify
   `schema_migrations`.
5. Call moderator-only `/api/v1/ops/metrics`; confirm DB pool availability,
   zero outbox lag growth and no 5xx increase.
6. Exercise search → early start → confirmation → agreement → first report
   with three staging accounts, including an APNs device.
7. Run `tools/explain_hot_paths.sql` and the authenticated load tool against
   the staging dataset. Compare p95/p99 with the stored release baseline.
8. Shift traffic only after the smoke path and performance gates pass.

Required push configuration is documented in `.env.example`. FCM expects a
service-account JSON value supplied by the secret manager; APNs expects team
ID, key ID, bundle ID and the `.p8` private key. Never print tokens or private
keys during diagnosis.

## Rollback

Migrations `0002`–`0006` are additive and have no destructive rollback. Roll
back the API image only after confirming it understands the old/new columns.
Preserve the migration ledger; never edit checksums by hand. Take a PostgreSQL
backup before production migration and restore it only through the approved
database runbook.

## Diagnosis

Check API health, request logs, PostgreSQL pool/locks, Matrix reachability and
the migration ledger. Run `tools/explain_hot_paths.sql` with representative
parameters and compare plans/latencies with the stored baseline.

For delayed team updates, inspect `sse.active_connections`,
`sse.queued_events` and the client reconnect state. For missing device pushes,
inspect outbox count/oldest lag and provider status without logging the token.
For a missing group, use `/groups/membership-history` and the membership
consistency flag from `/groups/overview`; every deactivation must contain an
explicit reason.
