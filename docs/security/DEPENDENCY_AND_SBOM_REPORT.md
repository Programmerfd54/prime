# Dependency and SBOM Report

Date: 2026-07-31  
Scope: Direct runtime dependencies pinned in repository manifests.

## Backend (`prime-backend/requirements.txt`)

| Package | Version | Purpose | Security notes |
|---|---|---|---|
| fastapi | 0.118.3 | HTTP API framework | Keep current; review OpenAPI exposure (`API_DOCS_ENABLED=false` default) |
| uvicorn[standard] | 0.38.0 | ASGI server | Bind behind reverse proxy in prod |
| sqlalchemy[asyncio] | 2.0.45 | ORM + async DB | Parameterized queries |
| asyncpg | 0.31.0 | PostgreSQL driver | TLS to DB in prod |
| pydantic[email] | 2.13.2 | Validation | |
| pydantic-settings | 2.13.0 | Config | Secrets via env, not repo |
| python-jose[cryptography] | 3.5.0 | JWT | HS256 with strong `JWT_SECRET_KEY` |
| passlib[bcrypt] | 1.7.4 | Password hashing | |
| bcrypt | 4.0.1 | KDF | Pinned compat with passlib |
| python-json-logger | 4.1.0 | Structured logs | |
| python-multipart | 0.0.20 | Upload parsing | Size limits in handlers |
| httpx | 0.28.1 | Outbound HTTP | Matrix, push |
| h2 | 4.3.0 | HTTP/2 | httpx extra |
| cryptography | 49.0.0 | Fernet, WebAuthn crypto | Matrix token encryption |
| Pillow | 12.2.0 | Image validation/re-encode | Strips metadata |
| pyotp | 2.9.0 | Moderator TOTP | |
| webauthn | 2.2.0 | Passkey ceremonies | RP ID/origin from env |

### Backend transitive highlights

Run in CI: `pip-audit -r requirements.txt`. Transitive packages include `starlette`, `anyio`, `cffi`, `greenlet` (SQLAlchemy).

## Mobile / Web client (`prime-flutter/pubspec.yaml`)

| Package | Constraint | Purpose | Security notes |
|---|---|---|---|
| dio | ^5.7.0 | HTTP client | Auth refresh interceptor |
| flutter_secure_storage | ^10.3.1 | Token storage | Primary secret store |
| shared_preferences | ^2.3.3 | Preferences + API disk cache | Non-secret prefs; see SEC-008 |
| provider | ^6.1.2 | State | |
| image_picker / file_picker | ^1.1.2 / ^8.1.6 | Media pickers | Client-side only |
| http | ^1.2.2 | Secondary HTTP | |
| forui / shadcn_ui | pinned | UI | Supply-chain monitor |

Dev: `flutter_lints`, `flutter_test`, `flutter_launcher_icons`.

## Infrastructure (reference only)

Not vendored in repo; documented in `deployment/docker-compose.production.example.yml`:

- PostgreSQL 16
- Optional Matrix Synapse
- Optional ClamAV (`MEDIA_SCANNER=clamav`)

## SBOM generation commands

```bash
# Backend
cd prime-backend
pip install pip-audit cyclonedx-bom
pip-audit -r requirements.txt
cyclonedx-py requirements -i requirements.txt -o sbom-backend.cdx.json

# Flutter (Dart SBOM via pub)
cd prime-flutter
dart pub get
# Use org CI tool of choice; e.g. osv-scanner on pubspec.lock when lockfile committed
```

## Vulnerability monitoring

| Tool | Target | Frequency | Owner |
|---|---|---|---|
| pip-audit | Python deps | Every PR / weekly | Backend |
| Bandit | Python SAST | CI | Backend |
| Gitleaks | Secrets in git | CI | Platform |
| Trivy | Container images | Release | Platform |
| Dependabot / Renovate | Manifests | Weekly | Platform |

## Known dependency decisions

1. **Modular monolith** — no separate API gateway dependency; rate limiting is in-app (`rate_limit_middleware.py`).
2. **webauthn 2.x** — moderator passkeys; RP ID must match production domain.
3. **Pillow** — primary defense against malformed images before quarantine scan.
4. **No Redis** — rate limits and SSE are DB/process-local; reduces attack surface, limits scale.

## Last audit status

| Check | Status | Evidence |
|---|---|---|
| pip-audit | NOT_RUN (local) | Run in CI pipeline |
| Flutter pub outdated | NOT_RUN | Manual before release |
| License compliance | NOT_RUN | SBOM export pending |

See `VULNERABILITY_MANAGEMENT.md` for SLAs and `REMEDIATION_PLAN.md` for upgrade backlog.
