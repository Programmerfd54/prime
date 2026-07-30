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

## Rollback

The `0002` migration is additive and has no destructive rollback. Roll back the
API image only after confirming it understands the old/new columns. Preserve
the migration ledger; never edit checksums by hand. Take a PostgreSQL backup
before production migration and restore it only through the approved database
runbook.

## Diagnosis

Check API health, request logs, PostgreSQL pool/locks, Matrix reachability and
the migration ledger. Run `tools/explain_hot_paths.sql` with representative
parameters and compare plans/latencies with the stored baseline.
