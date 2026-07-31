# Remediation Plan

Date: 2026-07-31  
Status: Post–security documentation phase; tracks residual and next-mile items.

## Completed (this milestone)

| ID | Item | Fix reference | Tests |
|---|---|---|---|
| SEC-001 | Push token hijack | `app/routers/notifications.py` — 409 cross-user | `test_device_token_cannot_be_hijacked` |
| SEC-002 | Cross-group media IDOR | `app/media_scope.py` | `test_media_url_requires_matching_upload_scope` |
| SEC-003 | Email enumeration | `app/routers/auth.py` — uniform false | `test_email_available_without_auth` |
| SEC-004 | Avatar URL spoofing | `app/routers/users.py` — strip `photo_url` | Schema + manual |
| SEC-005 | Profanity moderation | `app/moderation/*` | `test_high_confidence_profanity_applies_18h_restriction` |
| SEC-006 | Moderator MFA | `app/routers/mfa.py`, `app/mfa/*`, `require_moderator_step_up` | Manual ST-07–ST-10 |
| SEC-007 | Audit trail | `app/audit.py` producers in auth/MFA/moderation/rate limit | DB query + manual |
| SEC-011 | Media quarantine | `app/media_pipeline/*`, migration 0007 | `test_media_url_requires_matching_upload_scope` |
| SEC-012 | CORS prod default | `app/main.py::_validate_production_settings` | Prod boot test |

## In progress / partial

| ID | Item | Current state | Next action | Target |
|---|---|---|---|---|
| SEC-008 | Flutter disk cache | Tokens in `FlutterSecureStorage`; social GET still `_saveCache` → SharedPreferences | Add `_diskCacheAllowed(path)` false for `/direct-chats`, `/friends`, message paths | P1 — 2026-08-15 |
| SEC-009 | Deep link auth shell | Detail routes render loaders; API enforces auth | Wrap detail routes in `AuthGate` widget delegating to AppGate when unauthenticated | P2 — 2026-08-30 |
| SEC-010 | SSE scale | Process-local hub; metrics exposed | Load test + broker ADR (Redis/NATS) | P2 — post load test |

## Planned hardening (no SEC ID yet)

| Priority | Item | Owner | Notes |
|---|---|---|---|
| P1 | CI pip-audit + Bandit gates | Platform | See `VULNERABILITY_MANAGEMENT.md` |
| P1 | Secret manager migration | Platform | Replace repo `.env` in prod |
| P1 | Run full `SECURITY_TEST_PLAN.md` | Backend | pytest + manual sheet |
| P2 | ClamAV in production compose | Platform | `MEDIA_SCANNER=clamav` |
| P2 | Account deletion media orphan sweep | Backend | F-18 partial |
| P2 | SSE per-connection rate limit | Backend | AM-20 |
| P3 | External penetration test | Security | Before public launch |
| P3 | OWASP ASVS full L2 audit | Security | Expand `CONTROL_MAPPING.md` |
| P3 | Flutter disk cache encryption | Mobile | Alternative to memory-only |

## Documentation deliverables (this phase)

| Document | Status |
|---|---|
| ARCHITECTURE_AND_TRUST_BOUNDARIES.md | Done |
| ENDPOINT_AND_EVENT_INVENTORY.md | Done |
| DATA_FLOW_AND_CLASSIFICATION.md | Done |
| DEPENDENCY_AND_SBOM_REPORT.md | Done |
| THREAT_MODEL.md | Done |
| ABUSE_AND_MISUSE_CASES.md | Done |
| CONTROL_MAPPING.md | Done |
| MODERATION_POLICY.md | Done |
| MODERATION_TEST_MATRIX.md | Done |
| SECURITY_TEST_PLAN.md | Done |
| INCIDENT_RESPONSE.md | Done |
| VULNERABILITY_MANAGEMENT.md | Done |
| REMEDIATION_PLAN.md | Done |
| `tools/generate_security_inventory.py` | Done |

## Verification commands

```bash
cd prime-backend
pytest tests/test_security_remediation.py tests/test_registration_availability.py -v
python3 tools/generate_security_inventory.py --format markdown
APP_ENV=production MODERATOR_MFA_ENFORCE=true CORS_ALLOWED_ORIGINS=https://app.example \
  CORS_ALLOW_ORIGIN_REGEX= python3 -c "from app.main import _validate_production_settings; _validate_production_settings(); print('prod guards ok')"
```

## Rollback notes

- Migrations 0006–0007: rollback scripts in `migrations/README.md` if moderation/MFA must be reverted
- MFA enforce off: set `MODERATOR_MFA_ENFORCE=false` (non-prod only)
- Media worker: stop worker task; assets remain in QUARANTINE without promotion

## Sign-off

| Role | Criteria | Date |
|---|---|---|
| Backend lead | SEC-001–007, 011–012 verified | TBD |
| Mobile lead | SEC-008/009 plan accepted | TBD |
| Security champion | Docs + test plan reviewed | 2026-07-31 |
