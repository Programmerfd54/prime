# Matching

The current matching flow is a bounded, transaction-local queue matcher. It
filters by skill and region, locks at most `MATCH_CANDIDATE_SCAN_LIMIT`
(default 120) rows with `SKIP LOCKED`, preserves pair codes, and chooses up to
six users. Existing active groups for the skill are checked in one indexed
join instead of one query per candidate. Queue rows and new membership rows are
changed in the same transaction.

This is still a request-triggered matcher: joining, status reads and expansion
can invoke it. It is not a background worker. Capacity is bounded deliberately;
if the first 120 oldest rows cannot form a valid group, the request returns
without scanning an unbounded queue. Monitor match latency, lock waits and
queue age before changing this limit.
