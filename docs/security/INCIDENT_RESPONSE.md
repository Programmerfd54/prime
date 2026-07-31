# Incident Response

Date: 2026-07-31  
On-call rotation: TBD · Escalation: Engineering lead → Security → Legal (PII breach)

## Severity definitions

| Level | Criteria | Response target |
|---|---|---|
| **SEV-1** | Active breach, mass data leak, prod down | 15 min acknowledge, 1h mitigate |
| **SEV-2** | Limited account compromise, moderation bypass | 1h acknowledge, 4h mitigate |
| **SEV-3** | Single-user issue, failed control in staging | Next business day |
| **SEV-4** | Near-miss, scan finding | Backlog |

## General workflow

1. **Detect** — alerts, user report, audit anomaly, CI finding  
2. **Triage** — assign SEV, incident commander  
3. **Contain** — revoke sessions, disable feature flag, block IP  
4. **Eradicate** — patch, rotate secrets  
5. **Recover** — restore service, verify metrics  
6. **Post-incident** — timeline, RISK_REGISTER update, tests added  

Tools: `audit_events`, `/ops/metrics`, request logs (`X-Request-ID`), PostgreSQL backups.

---

## 15 playbooks (brief)

### IR-01 — Suspected JWT secret compromise

**SEV:** 1 · **Triggers:** Secret in git, leaked env dump

1. Rotate `JWT_SECRET_KEY` in secret manager  
2. Deploy; all sessions invalidate on bad signature  
3. Force password reset for moderator accounts  
4. Run Gitleaks on history; notify users if tokens could be minted  

### IR-02 — Credential stuffing / login spike

**SEV:** 2 · **Triggers:** `auth.login.failed` surge, 429 on `/auth/login`

1. Confirm rate limits active (`AUTH_LOGIN_RATE_LIMIT_ENABLED`)  
2. Temporarily lower threshold via env  
3. Identify top IPs; edge block if needed  
4. No account lockout globally unless single-target abuse  

### IR-03 — Account takeover (single user)

**SEV:** 2 · **Triggers:** User report, foreign sessions

1. Revoke all `auth_sessions` for user  
2. Force password reset email  
3. Review `audit_events` for login IPs  
4. Unregister unknown `device_tokens`  

### IR-04 — IDOR / unauthorized data access

**SEV:** 2 · **Triggers:** Bug report, pen test finding

1. Reproduce with two test accounts  
2. Hotfix membership/scope check  
3. Query access logs for exploitation window  
4. Add regression test (see `test_security_remediation.py` pattern)  

### IR-05 — Cross-group media leak

**SEV:** 2 · **Triggers:** SEC-002 regression

1. Disable message send if needed  
2. Verify `media_uploads` integrity  
3. Patch `validate_media_url_for_scope`  
4. Notify affected groups if confirmed leak  

### IR-06 — Push notification abuse

**SEV:** 2 · **Triggers:** Wrong user receives push, token hijack reports

1. Check `device_tokens` for duplicate bindings  
2. Confirm 409 logic deployed  
3. Revoke suspicious tokens via `/devices/unregister` admin script  
4. Review outbox for anomalous payloads  

### IR-07 — SSE / realtime anomaly

**SEV:** 3 · **Triggers:** Users see wrong events, connection storm

1. Check `/ops/metrics` `realtime.sse_connections`  
2. Restart affected API instance (clears hub)  
3. Review subscription code in `direct_message_events.py`  
4. Plan broker if multi-instance  

### IR-08 — Moderation bypass / profanity wave

**SEV:** 2 · **Triggers:** Support tickets, lexicon gap

1. Capture offending strings (secure ticket)  
2. Emergency lexicon patch + deploy  
3. Apply manual restrictions via DB if needed  
4. Bump `POLICY_VERSION`  

### IR-09 — Malicious media upload

**SEV:** 2 · **Triggers:** ClamAV hit, user report

1. Set `MEDIA_SCANNER=clamav` if not already  
2. Quarantine affected `local_media_assets`  
3. Block `published_media_url` at serve layer  
4. Scan backups if worm suspected  

### IR-10 — Moderator account compromise

**SEV:** 1 · **Triggers:** Unauthorized appeal resolutions

1. Disable `is_moderator` flag for account  
2. Revoke sessions + step-up rows  
3. Review all `moderation.appeal.resolved` audit events  
4. Re-enroll MFA on recovery  

### IR-11 — Database breach / SQL injection suspicion

**SEV:** 1 · **Triggers:** WAF alert, unexpected DB queries

1. Snapshot logs; preserve evidence  
2. Rotate DB credentials  
3. Run query audit; confirm SQLAlchemy parameterization  
4. Legal notification assessment (PII)  

### IR-12 — DDoS / availability attack

**SEV:** 2 · **Triggers:** Latency SLO breach, 429/503 spike

1. Enable edge rate limiting / CDN challenge  
2. Tune `API_RATE_LIMIT_*`  
3. Scale API replicas (note SSE stickiness)  
4. Post-mortem capacity plan  

### IR-13 — Dependency CVE (critical)

**SEV:** 2 · **Triggers:** pip-audit, Dependabot

1. Assess exploitability in PRIME context  
2. Upgrade pin in `requirements.txt`  
3. Emergency deploy after pytest green  
4. Update `DEPENDENCY_AND_SBOM_REPORT.md`  

### IR-14 — CORS / misconfiguration exposure

**SEV:** 3 · **Triggers:** Prod boot failure, security scan

1. Verify `CORS_ALLOWED_ORIGINS` explicit list  
2. Confirm `CORS_ALLOW_ORIGIN_REGEX` empty in prod  
3. Redeploy with corrected env  

### IR-15 — Law enforcement / legal data request

**SEV:** 3 · **Triggers:** Subpoena, preservation request

1. Route to Legal; do not ad-hoc export  
2. Preserve `audit_events` and relevant rows  
3. Provide minimum necessary data with auth chain  

---

## Communication templates

**Internal (SEV-1/2):** `#incidents` — status, IC, ETA, customer impact  
**External:** Support macro — "We investigated unusual activity…" (Legal review)

## Post-incident review

Within 5 business days:

- Timeline with request IDs  
- Root cause category (code/config/process)  
- New SEC-### or close existing  
- Test added to `SECURITY_TEST_PLAN.md`  

## Contacts

| Role | Responsibility |
|---|---|
| Incident Commander | Coordinates playbook |
| Backend on-call | Patch, deploy, DB |
| Mobile on-call | Client fix, store comms |
| Moderation lead | Appeals, policy |
| Legal | Breach notification |
