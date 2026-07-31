# Production resource baseline

The production VPS currently has 2 vCPU and 4 GB RAM. Keep the service memory
limits in the main Compose file and apply the resource override together with
it:

```bash
docker compose \
  -f docker-compose.yml \
  -f deployment/docker-compose.resource-limits.override.yml \
  config
```

The override provides:

- `nofile=65535` for socket-heavy services;
- Docker JSON log rotation (`10m`, three files per container);
- a backup healthcheck that becomes unhealthy when the latest SQL dump is
  missing or older than two days.

`docker-daemon.production.json` contains equivalent daemon-wide defaults. It is
needed for the externally managed Traefik container, which is not created by
the PRIME Compose project. Validate it before installing:

```bash
dockerd --validate --config-file deployment/docker-daemon.production.json
```

## Backup verification

Creating a dump is not enough. At least after every infrastructure change,
restore `last/prime-latest.sql.gz` into a disposable PostgreSQL 16 instance and
verify the expected tables and row counts. Never test a restore over the live
database.

## Matrix

The application uses the Synapse instance for `matrix.inpr1me.ru`. The legacy
`matrix.prime-bot.dynv6.net` stack is separate and can remain disabled after its
`/matrix` directory has been archived. Traefik, its certificate dumper and the
Docker socket proxy must remain enabled because they route the live PRIME web
and API domains.

## Object storage

MinIO is S3-compatible but still uses the VPS disk. Moving media off-host only
requires replacing `S3_ENDPOINT_URL`, `S3_PUBLIC_ENDPOINT_URL`,
`S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, and `S3_BUCKET` with credentials
from an external S3-compatible provider. Do not commit those values.
