import pytest
from fastapi import BackgroundTasks
from httpx import ASGITransport, AsyncClient

from app.db import get_session
from app.main import app
from app.routers import auth as auth_router
from app.routers.auth import register, verify_email
from app.schemas import VerifyEmailRequest
from app.config import get_settings
from tests.test_email_verification import (
    _FakeRequest,
    make_session,
    register_payload,
)


@pytest.fixture(autouse=True)
def verification_settings(monkeypatch: pytest.MonkeyPatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "email_verification_expose_code", True)
    monkeypatch.setattr(settings, "auth_login_rate_limit_enabled", False)
    auth_router._login_failures.clear()
    auth_router._verification_failures.clear()
    return settings


@pytest.mark.asyncio
async def test_nickname_available_without_auth() -> None:
    engine, session = await make_session()
    try:
        pending = await register(
            register_payload("avail@example.com", "takennick"),
            BackgroundTasks(),
            session,
        )
        assert pending.verification_code

        async def override_get_session():
            yield session

        app.dependency_overrides[get_session] = override_get_session
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            free = await client.get("/api/v1/auth/nickname-available/freshnick")
            taken = await client.get("/api/v1/auth/nickname-available/takennick")
            own_pending = await client.get(
                "/api/v1/auth/nickname-available/takennick",
                params={"email": "avail@example.com"},
            )
            invalid = await client.get("/api/v1/auth/nickname-available/ab")

        assert free.status_code == 200
        assert free.json()["available"] is True
        assert taken.status_code == 200
        assert taken.json()["available"] is False
        assert own_pending.status_code == 200
        assert own_pending.json()["available"] is True
        assert invalid.status_code == 400
    finally:
        app.dependency_overrides.clear()
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_display_name_valid_without_auth() -> None:
    engine, session = await make_session()
    try:
        async def override_get_session():
            yield session

        app.dependency_overrides[get_session] = override_get_session
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            ok = await client.get(
                "/api/v1/auth/display-name-valid",
                params={"name": "Даниил"},
            )
            bad = await client.get(
                "/api/v1/auth/display-name-valid",
                params={"name": "хуй"},
            )

        assert ok.status_code == 200
        assert ok.json()["available"] is True
        assert bad.status_code == 400
    finally:
        app.dependency_overrides.clear()
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_email_available_without_auth() -> None:
    engine, session = await make_session()
    try:
        verified_email = "verified@example.com"
        pending = await register(
            register_payload(verified_email, "verifieduser"),
            BackgroundTasks(),
            session,
        )
        await verify_email(
            _FakeRequest(),
            VerifyEmailRequest(email=verified_email, code=pending.verification_code),
            session,
        )
        await register(
            register_payload("unverified@example.com", "unverifieduser"),
            BackgroundTasks(),
            session,
        )

        async def override_get_session():
            yield session

        app.dependency_overrides[get_session] = override_get_session
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            fresh = await client.get(
                "/api/v1/auth/email-available",
                params={"email": "new@example.com"},
            )
            pending_resp = await client.get(
                "/api/v1/auth/email-available",
                params={"email": "unverified@example.com"},
            )
            verified = await client.get(
                "/api/v1/auth/email-available",
                params={"email": verified_email},
            )

        assert fresh.status_code == 200
        assert fresh.json() == {"available": True, "pending_verification": False}
        assert pending_resp.status_code == 200
        assert pending_resp.json() == {
            "available": False,
            "pending_verification": False,
        }
        assert verified.status_code == 200
        assert verified.json() == {
            "available": False,
            "pending_verification": False,
        }
    finally:
        app.dependency_overrides.clear()
        await session.close()
        await engine.dispose()
