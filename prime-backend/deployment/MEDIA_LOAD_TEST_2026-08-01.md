# Isolated media load test — 2026-08-01

Final deployed commit: `0dd3121`.

The workload ran on the production VPS, but inside a disposable Docker network
with its own PostgreSQL, Redis, MinIO and API containers. It used test-only
credentials. Production accounts, tables, Redis keys and the production MinIO
bucket were never used.

## Workload

- 10,000 synthetic users
- 2,000 active groups with 5 members each
- one media upload from every synthetic user
- 70% JPEG images (446,201 bytes after generation)
- 20% MP4 payloads (2,097,152 bytes)
- 10% audio payloads (262,144 bytes)
- maximum request concurrency: 40
- test API: 2 Gunicorn/Uvicorn workers, capped at 1 CPU

The expected payload for 10,000 distinct users was 7,579,855,000 bytes
(approximately 7.06 GiB). Every successful response was checked to ensure its
storage URL used the `s3` scheme; no Matrix or local-filesystem fallback was
accepted.

## Staged results before the Redis fallback fix

| Stage | Requests | Concurrency | OK | Failed | Requests/s | p50 | p95 | p99 | Maximum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Cold functional check | 10 | 2 | 10 | 0 | 1.52 | 541 ms | 3,285 ms | 3,285 ms | 3,285 ms |
| Warm-up | 90 | 5 | 90 | 0 | 8.34 | 493 ms | 1,142 ms | 1,677 ms | 1,678 ms |
| 1,000 cumulative | 900 | 10 | 900 | 0 | 10.65 | 662 ms | 2,466 ms | 3,810 ms | 5,785 ms |
| 5,000 cumulative | 4,000 | 20 | 4,000 | 0 | 10.89 | 1,304 ms | 5,431 ms | 8,521 ms | 30,053 ms |
| 10,000 cumulative | 5,000 | 40 | 4,994 | 6 | 10.79 | 2,503 ms | 9,142 ms | 18,271 ms | 31,801 ms |

Increasing concurrency from 20 to 40 did not increase throughput. The API
reached roughly one full CPU core and requests queued, which raised latency.
There were no container restarts, OOM kills or object-storage fallbacks.

During the final stage, three requests returned HTTP 500 and three clients saw
a read error (0.12% of that stage). The server trace identified an operation-
level Redis timeout in the upload rate limiter. The Redis client had connected
successfully, so the existing connection-time fallback did not handle this
later timeout.

## Defects fixed

1. Rate-limit commands now catch Redis operation failures, retire the failed
   shared client and enforce the same limit through PostgreSQL. A controlled
   test paused Redis after the API had connected: 10/10 concurrent uploads
   still returned HTTP 200 and were stored in S3. The six originally failed
   user indices were retried successfully.
2. PostgreSQL schema bootstrap now takes a transaction-scoped advisory lock.
   This prevents two Gunicorn workers from racing to create the same table on
   a brand-new database. A clean PostgreSQL instance started one master and two
   workers, created 40 public tables and logged no duplicate-object errors.
3. Report uploads are recorded with the `report` media scope. Previously they
   were uploaded with the `group` scope and could be rejected when attached to
   a report.

The complete backend suite passed after the fixes: 153 tests.

## Final verification

After retries, the disposable database contained 10,010 media records and
10,000 distinct owners. MinIO contained 10,010 objects and reported about
7.0 GiB. The extra 10 objects were deliberate retry/fallback checks.

Observed peak test-container memory was approximately:

- API: 387 MiB
- MinIO: 464 MiB
- PostgreSQL: 149 MiB
- load generator: 65 MiB

System available memory stayed above approximately 1.4 GiB. Swap usage stayed
near 14 MiB. Disk use peaked at 46%. The external production health endpoint
continued returning HTTP 200, sampled at 0.21–0.27 seconds during peak load.

All disposable containers, volumes, networks, tokens, manifests, database rows
and test media were deleted. Disk use returned from 46% to 33% (38 GiB free),
and available memory returned to approximately 2.34 GiB.

Production API and worker were then deployed on image `0dd3121`. Web, API
health, regions, Matrix and the public APK returned HTTP 200. `/skills`
returned the expected HTTP 401 without authentication. No new traceback or
error was present in the API or worker logs.

## Interpretation and remaining limits

This proves that 10,000 distinct users can upload the tested media mix over
time at about 10–11 uploads/second on the current host while production stays
available. It does **not** prove 10,000 simultaneous uploads; the highest tested
request concurrency was 40.

At the tested mix, 10,000 uploads consume about 7.06 GiB. If 10,000 users each
upload once per day, the current 38 GiB of free local disk lasts only about five
days, and less when retaining a safe free-space margin. Before that usage
level, production media must move to external S3-compatible storage with
lifecycle rules, monitoring and backups.

The production gateway currently limits an HTTP request body to 10 MiB while
the backend accepts video/audio up to 100 MiB. The load test used 2 MiB videos.
On this 2-vCPU/4-GB host, blindly raising the gateway to 100 MiB would increase
OOM and denial-of-service risk because the API still reads uploads into memory.
Choose one of these production-safe paths before enabling large videos:

1. keep a 10 MiB client-side compression limit; or
2. use presigned direct-to-S3 multipart uploads, then let the API validate and
   attach the resulting object.

For sustained growth, direct-to-S3 upload, image/video compression, a media
retention policy and a larger host (at least 8 vCPU / 16 GiB for materially
higher concurrent activity) remain the next capacity steps.
