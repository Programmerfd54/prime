# Risk Register

Format: `SEC-### | asset | path | severity | status | fix | test`

| ID | Asset | Attack path | Severity | Status | Fix | Test |
|---|---|---|---|---|---|---|
| SEC-001 | Push tokens | Attacker registers victim FCM/APNs token on own account | High | **CLOSED** | Reject cross-user token rebind with 409 | `test_device_token_cannot_be_hijacked` |
| SEC-002 | Group chat media | Reuse MXC URL from group A in group B message | Medium-High | **CLOSED** | MediaUpload scope registry + validate on send | `test_media_url_requires_matching_upload_scope` |
| SEC-003 | Email addresses | `/auth/email-available` leaks verified vs pending | Medium | **CLOSED** | Uniform false for any existing email | `test_email_available_without_auth` |
| SEC-004 | Profile avatars | Client sets `photo_url` to another user's avatar path | Low-Medium | **CLOSED** | Strip `photo_url` from PATCH /me | Manual + schema |
| SEC-005 | Chat/profile text | Profanity published without restriction | High | **CLOSED** | Pre-publish moderation + 18h SOCIAL_WRITE | `test_high_confidence_profanity_applies_18h_restriction` |
| SEC-006 | Admin plane | Moderator uses single `is_moderator` flag, no MFA | Medium | **CLOSED** | TOTP/WebAuthn step-up; `require_moderator_step_up`; prod `MODERATOR_MFA_ENFORCE` | Manual ST-07–ST-10 (`SECURITY_TEST_PLAN.md`) |
| SEC-007 | Audit trail | `audit_events` never written | Low | **CLOSED** | `app/audit.py` + producers (auth, MFA, moderation, rate limit, friend requests) | Manual audit row query |
| SEC-008 | Flutter cache | Chat/friends cached in plaintext SharedPreferences | Medium | **CLOSED** | Tokens/profile in `FlutterSecureStorage`; user-scoped cache keys; logout clears auth keys. Residual: social GET disk cache — see `REMEDIATION_PLAN.md` P1 | `AuthStorage` migration paths; ST-14–ST-15 |
| SEC-009 | Deep links | Detail routes bypass AppGate on cold start | Medium | **CLOSED** | Tab/auth/onboarding routes delegate to `AppGate`; detail loaders require authenticated API (401 → session clear). Residual: UI shell flash — `REMEDIATION_PLAN.md` P2 | Manual ST-16 |
| SEC-010 | Realtime scale | SSE hub process-local | Info | **CLOSED** | Accepted architecture; `/ops/metrics` exposes SSE/outbox observability; broker ADR tracked post load test | `test_observability.py`; ops metrics manual |
| SEC-011 | Media pipeline | No async malware scan/quarantine worker | Medium | **CLOSED** | `app/media_pipeline/worker.py` quarantine batch; ClamAV optional (`MEDIA_SCANNER`); migration 0007 | `test_media_url_requires_matching_upload_scope` (quarantine path) |
| SEC-012 | CORS default | Localhost regex if env unset in prod | Low | **CLOSED** | `_validate_production_settings` rejects regex + empty origins in prod | Prod boot validation (`REMEDIATION_PLAN.md`) |

Residual score: SEC-001–SEC-012 closed for pre-production baseline; SEC-008/009/010 note documented follow-ups in `REMEDIATION_PLAN.md` (no open SEC IDs).

## Related artifacts

- Threat flows: `THREAT_MODEL.md` (F-01–F-18)
- Control evidence: `CONTROL_MAPPING.md`
- Test execution: `SECURITY_TEST_PLAN.md`
