# Backend baseline after the safe changes

Captured on 2026-07-30 after implementation.

| Measurement | Result | Comparison |
|---|---:|---|
| Backend pytest suite | 116 passed in 10.56 s | 73 passed in 6.29 s before current workspace additions; SQLite only |
| Flutter focused product suite | 29 passed before the final countdown/native-push hardening | Re-run is required; the environment usage limit blocked the final repeat |
| Flutter `flutter analyze` | no compile errors; existing repository lint warnings remain | Full repository analysis; not a clean lint gate |
| Group overview SQL count | 5 statements for 1 or many groups | Legacy composition was at least 15 statements for the multi-group fixture |
| PostgreSQL p50/p95/p99 | not captured | The local API container was healthy, but the authenticated load run was blocked by the execution environment |
| PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` | not captured | Run `tools/explain_hot_paths.sql` on the target PostgreSQL dataset |

Implemented, test-covered changes:

- group chat retry returns one durable row for one sender/client key;
- notification keyset pagination returns stable pages without duplicate IDs;
- bounded matching and batched membership validation are represented in the
  production query path;
- model/migration definitions now expose the matching, chat, report and
  notification composite indexes;
- schema migration checksums are recorded in `schema_migrations` on PostgreSQL;
- access-presence writes are throttled and push logs use token fingerprints.
- refresh-token rotation/revocation, upload bounds/content validation, private
  media authorization and password-reset token redaction are covered by the
  added regression tests.
- early-start proposals are durable, expire after 15 minutes and fan out
  through notification rows, outbox, SSE and APNs/FCM transports;
- membership transitions are audited with explicit reasons, while overview
  detects inconsistent membership state;
- group and waiting-room revisions suppress stale realtime events;
- the active-group UI separates Today, Team and Progress and exposes member
  report/check-in states, support actions and personal impact.

The test-duration difference is not a performance regression claim: the
current worktree includes additional tests and the new regression tests add
database setup. The constant five-query overview count is a regression guard,
not a production latency claim. A real PostgreSQL before/after comparison
remains a deployment prerequisite, not a fabricated result.
