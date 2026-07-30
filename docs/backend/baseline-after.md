# Backend baseline after the safe changes

Captured on 2026-07-30 after implementation.

| Measurement | Result | Comparison |
|---|---:|---|
| Backend pytest suite | 85 passed in 11.18 s | 73 passed in 6.29 s before current workspace additions; SQLite only |
| Flutter `flutter analyze` | completed with existing infos/warnings, no new error | Full repository analysis; not a clean lint gate |
| PostgreSQL p50/p95/p99 | not captured | Docker/PostgreSQL remained unavailable |
| PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` | not captured | Run `tools/explain_hot_paths.sql` on the target dataset |

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

The test-duration difference is not a performance regression claim: the
current worktree includes additional existing/untracked tests and the new
regression tests add database setup. These timings cannot represent production
traffic. A real before/after performance comparison remains a deployment
prerequisite, not a fabricated result.
