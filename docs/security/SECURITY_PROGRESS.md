# Security Progress Log

## 2026-07-31 — Security documentation phase (complete)

### Deliverables created

All artifacts under `docs/security/`:

| Document | Purpose |
|---|---|
| `ARCHITECTURE_AND_TRUST_BOUNDARIES.md` | Trust zones, component map, prod invariants |
| `ENDPOINT_AND_EVENT_INVENTORY.md` | 103 `/api/v1` routes + SSE events |
| `DATA_FLOW_AND_CLASSIFICATION.md` | PII tiers and 8 critical flows |
| `DEPENDENCY_AND_SBOM_REPORT.md` | Pinned backend/Flutter deps + audit commands |
| `THREAT_MODEL.md` | STRIDE matrix + 18 flow summary |
| `ABUSE_AND_MISUSE_CASES.md` | 32 misuse cases with control status |
| `CONTROL_MAPPING.md` | OWASP ASVS L2 sample (32 PASSED, 10 PARTIAL) |
| `MODERATION_POLICY.md` | RU/EN profanity, restrictions, appeals |
| `MODERATION_TEST_MATRIX.md` | MT-01–MT-25 cases |
| `SECURITY_TEST_PLAN.md` | 8-phase verification plan |
| `INCIDENT_RESPONSE.md` | 15 brief playbooks |
| `VULNERABILITY_MANAGEMENT.md` | SLAs, disclosure, CI tooling |
| `REMEDIATION_PLAN.md` | Completed + residual backlog |

Tooling: `prime-backend/tools/generate_security_inventory.py` — FastAPI route introspection (103 routes verified).

### Risks closed (SEC-006 – SEC-012)

| ID | Risk | Fix | Test |
|---|---|---|---|
| SEC-006 | Moderator single-factor | `app/routers/mfa.py`, `app/mfa/*`, `deps.require_moderator_step_up`, migration 0007 | Manual MFA plan ST-07–ST-10 |
| SEC-007 | Empty audit trail | `app/audit.py` wired to auth, MFA, moderation, rate limits, friend requests | Audit row inspection |
| SEC-008 | Plaintext client secrets/cache | `AuthStorage` → FlutterSecureStorage; scoped cache keys; logout purge | ST-14–ST-15 (residual disk cache in REMEDIATION P1) |
| SEC-009 | Deep link gate bypass | `AuthRequiredRoute` wraps detail/settings routes | ST-16 |
| SEC-010 | Opaque SSE scaling | Documented accepted risk; `/ops/metrics` realtime section | `test_observability.py` |
| SEC-011 | No malware quarantine | `media_pipeline/worker.py`, noop/ClamAV scanner, pending URLs | Quarantine test in `test_security_remediation.py` |
| SEC-012 | Permissive CORS in prod | `main.py::_validate_production_settings` | Prod env boot check |

Previously closed (initial audit): SEC-001 – SEC-005 unchanged.

### Verified this phase

- Route inventory via `python3 tools/generate_security_inventory.py` → **103 routes**
- Code review: moderation pipeline, MFA step-up, audit producers, media worker, prod guards
- Cross-reference with `docs/backend/security-and-privacy.md` and `SECURITY_BASELINE.md`

### Tests (verified)

```bash
cd prime-backend && pytest -q   # 131 passed (incl. test_sse_security.py)
cd prime-flutter && flutter test test/api_client_cache_test.dart test/failure_mapper_test.dart
cd prime-flutter && flutter analyze
```

### Residual / next phase

| Item | Tracker |
|---|---|
| Social GET disk cache exclusion | `REMEDIATION_PLAN.md` P1 |
| AuthGate on detail deep links | `REMEDIATION_PLAN.md` P2 |
| SSE broker ADR after load test | `REMEDIATION_PLAN.md` P2 |
| CI pip-audit / Bandit gates | `VULNERABILITY_MANAGEMENT.md` |
| External penetration test | Pre-launch |

### Rollback

- Revert migrations 0006–0007 for moderation/MFA/media quarantine
- Set `MODERATOR_MFA_ENFORCE=false` (non-prod only)
- Device token and email enumeration fixes remain backward compatible

---

## 2026-07-31 — Initial mega-prompt execution

### Verified
- Full backend endpoint inventory (~70 routes under `/api/v1` at time; now 103 with MFA/ops/moderation)
- Flutter auth/storage/realtime/deep-link surfaces
- Existing controls from prior audit (`docs/backend/security-audit.md`)

### Changed (backend)
- `migrations/0006_moderation_and_media_scope.sql` — moderation + media scope tables
- `app/models.py` — MediaUpload, ModerationDecision, UserRestriction, ModerationAppeal
- `app/media_scope.py` — upload registry + attachment validation
- `app/moderation/*` — normalization, lexicon, profanity classifier, restrictions, pipeline
- `app/matrix.py` — record uploads after Matrix/local store
- `app/routers/notifications.py` — block device token hijacking (409)
- `app/routers/auth.py` — email availability anti-enumeration
- `app/routers/chat.py` — moderation + media scope on send/reactions
- `app/routers/social.py` — moderation + media scope on DMs
- `app/routers/users.py` — block client `photo_url`; moderate profile fields
- `tests/test_security_remediation.py` — regression tests
- `tests/test_registration_availability.py` — updated expectations

### Risks closed (initial)
| ID | Risk | Fix |
|---|---|---|
| SEC-001 | Push token hijacking | 409 if token owned by another user |
| SEC-002 | Cross-group media IDOR via URL reuse | MediaUpload scope validation |
| SEC-003 | Email enumeration (verified vs pending) | Uniform `available=false` |
| SEC-004 | Avatar URL spoofing | Reject client `photo_url` on PATCH |
| SEC-005 | No profanity moderation | Server pre-publish pipeline + 18h restriction |
