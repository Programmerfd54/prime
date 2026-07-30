# Backend baseline before the safe changes

Captured on 2026-07-30 in the repository workspace.

| Measurement | Result | Scope |
|---|---:|---|
| Backend pytest suite | 73 passed | SQLite in-memory, 6.29 s (`--durations=20`: 5.51 s) |
| PostgreSQL p50/p95/p99 | not captured | Docker/PostgreSQL socket was unavailable in this environment |
| Production RPS/error rate | not captured | No live production credentials or runtime were used |
| Postgres `EXPLAIN (ANALYZE, BUFFERS)` | not captured | See `prime-backend/tools/explain_hot_paths.sql` |

Static baseline findings from code tracing:

- waiting-room matching selected and locked the entire matching queue, then
  queried an existing group once per candidate;
- authenticated requests flushed `users.last_seen_at` on every request;
- group chat messages had no client idempotency key;
- notifications returned the newest 100 rows with no cursor;
- SSE fallback performed a database poll every second per connection and the
  in-process event hub was not cross-instance durable;
- chat/report uploads read up to 100 MB into process memory;
- schema changes were embedded in startup `create_db_schema()` statements with
  no migration ledger.

The numbers above are deliberately separated from production SLOs. To capture
the missing runtime baseline, start PostgreSQL and the API, then run:

```bash
cd prime-backend
python3 tools/load_test_prime.py --base-url http://localhost:8080/api/v1 \
  --health-total 200 --health-concurrency 20
psql "$DATABASE_URL" -f tools/explain_hot_paths.sql
```

Store the CSV/JSON and plan output with the commit before comparing the same
commands after rollout. Do not compare SQLite timings with production SLOs.
