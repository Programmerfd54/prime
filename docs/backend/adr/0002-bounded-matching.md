# ADR 0002: Bound waiting-room matching

Status: accepted.

Lock at most `MATCH_CANDIDATE_SCAN_LIMIT` oldest candidates and recheck group
membership in one query. This prevents an unbounded lock/scan and N+1 query
amplification while keeping the existing transaction and pair-code behavior.
The trade-off is that a queue whose first bounded window is not eligible may
wait for a later trigger.
