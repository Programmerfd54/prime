# Security Test Plan

Date: 2026-07-31  
Scope: Pre-production security verification for PRIME backend + Flutter client.

## Objectives

1. Verify SEC-001–SEC-012 remediations and regression tests pass
2. Validate authZ on representative IDOR paths
3. Confirm moderation, MFA, and audit wiring
4. Establish CI gates before production rollout

## Test environments

| Env | DB | Notes |
|---|---|---|
| Local | SQLite in pytest | Fast feedback; some PostgreSQL-specific paths skipped |
| CI | SQLite + optional Postgres job | Run full pytest |
| Staging | PostgreSQL | Manual MFA, ClamAV, push sandbox |

## Phase 1 — Automated backend (required)

```bash
cd prime-backend
pytest tests/test_security_remediation.py -v
pytest tests/test_registration_availability.py -v
pytest tests/test_observability.py -v
pytest tests/test_chat_idempotency.py -v
pytest  # full suite
```

| Area | Tests | Pass criteria |
|---|---|---|
| Push hijack | `test_security_remediation` | 409 on rebind |
| Media scope | same | 403 cross-scope |
| Profanity + restriction | same | 18h ban, no extend |
| Email enumeration | `test_registration_availability` | uniform false |
| Metrics | `test_observability` | Snapshot shape valid |

## Phase 2 — Static analysis (CI)

| Tool | Command | Pass criteria |
|---|---|---|
| Bandit | `bandit -r app/` | No high severity |
| pip-audit | `pip-audit -r requirements.txt` | No known critical CVEs |
| Gitleaks | CI workflow | No secrets |
| Flutter analyze | `flutter analyze` | No errors |

## Phase 3 — Manual authZ probes

Use two test users A and B in staging.

| # | Test | Request | Expected |
|---|---|---|---|
| ST-01 | Foreign group read | B → `GET /groups/{A_group}` | 403/404 |
| ST-02 | Foreign chat | B → `GET /chat/{A_group}/messages` | 403 |
| ST-03 | Foreign DM | B → `GET /direct-chats/{A}/messages` | 403/404 |
| ST-04 | Foreign avatar path | Guess filename | 404 |
| ST-05 | Moderator ops | Non-mod → `/ops/metrics` | 403 |
| ST-06 | Refresh after logout | Old refresh token | 401 |

## Phase 4 — Moderator MFA

| # | Test | Expected |
|---|---|---|
| ST-07 | Prod config dry-run | `APP_ENV=production` rejects missing MFA enforce |
| ST-08 | TOTP enroll + verify | Step-up session created |
| ST-09 | WebAuthn register/auth | Credential stored; step-up ok |
| ST-10 | Ops without step-up | 403 when enforce on |

## Phase 5 — Media pipeline

| # | Test | Expected |
|---|---|---|
| ST-11 | Upload → pending URL | Message attach blocked until clean |
| ST-12 | Worker promotes asset | `local://` URL in registry |
| ST-13 | ClamAV EICAR (if enabled) | `REJECTED` status |

## Phase 6 — Client security

```bash
cd prime-flutter
flutter test
flutter analyze
```

| # | Test | Expected |
|---|---|---|
| ST-14 | Token storage | Tokens in secure storage after login |
| ST-15 | Logout | Cache keys cleared; unauthorized handler fires |
| ST-16 | Deep link cold start | Unauthenticated → auth screen (not data leak) |
| ST-17 | `realtime_client_test` | SSE auth header present |

## Phase 7 — Load / abuse (staging)

| # | Test | Tool | Pass criteria |
|---|---|---|---|
| ST-18 | Login rate limit | Script 10 fails/min | 429 after threshold |
| ST-19 | Global API limit | `load_test_prime.py` | 429 without crash |
| ST-20 | SSE connections | 100 concurrent | Stable; memory bounded |

## Phase 8 — Endpoint inventory drift

```bash
cd prime-backend
python3 tools/generate_security_inventory.py --format json > /tmp/routes.json
# Compare route_count to ENDPOINT_AND_EVENT_INVENTORY.md
```

## Entry / exit criteria

**Entry:** Feature complete for security milestone; migrations 0006–0007 applied.

**Exit:**

- Phase 1 all green
- No unresolved Critical/High in pip-audit/Bandit
- ST-01–ST-06 manual sheet signed
- RISK_REGISTER SEC-001–SEC-012 reviewed
- `SECURITY_PROGRESS.md` updated

## Reporting

Failures filed as SEC-### or linked GitHub issue with:

- Reproduction steps
- Request ID from `X-Request-ID`
- Relevant `audit_events.action`

## Schedule

| When | Activity |
|---|---|
| Every PR | Phase 1 + 2 subset |
| Weekly | Full pytest + pip-audit |
| Pre-release | Phases 3–7 + penetration test (external) |
