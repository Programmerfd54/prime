from datetime import timedelta

import pytest
from fastapi import BackgroundTasks, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import get_settings
from app.db import Base
from app.models import EmailVerificationCode, User, utcnow
from app.routers import auth as auth_router
from app.routers.auth import login, register, resend_verification, verify_email
from app.schemas import (
    LoginRequest,
    RegisterRequest,
    ResendVerificationRequest,
    VerifyEmailRequest,
)
from app.security import decode_access_token


PASSWORD = "PrimePass12"


class _FakeRequest:
    """Stands in for starlette Request: routers only read request.client.host."""

    def __init__(self, host: str = "203.0.113.9") -> None:
        self.client = type("Client", (), {"host": host})()


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


@pytest.fixture(autouse=True)
def verification_settings(monkeypatch: pytest.MonkeyPatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "email_verification_expose_code", True)
    monkeypatch.setattr(settings, "email_verification_resend_cooldown_seconds", 60)
    monkeypatch.setattr(settings, "email_verification_max_attempts", 3)
    monkeypatch.setattr(settings, "auth_login_rate_limit_enabled", False)
    auth_router._login_failures.clear()
    auth_router._verification_failures.clear()
    return settings


def register_payload(email: str, nickname: str) -> RegisterRequest:
    return RegisterRequest(
        email=email,
        password=PASSWORD,
        name="Новый Пользователь",
        nickname=nickname,
    )


@pytest.mark.asyncio
async def test_register_returns_pending_and_verify_issues_token() -> None:
    engine, session = await make_session()
    try:
        pending = await register(
            register_payload("newbie@example.com", "newbie"),
            BackgroundTasks(),
            session,
        )
        assert pending.status == "verification_required"
        assert pending.email == "newbie@example.com"
        code = pending.verification_code
        assert code is not None and len(code) == 6 and code.isdigit()

        user = await session.scalar(
            select(User).where(User.email == "newbie@example.com")
        )
        assert user is not None
        assert user.email_verified_at is None

        token = await verify_email(
            _FakeRequest(),
            VerifyEmailRequest(email="newbie@example.com", code=code),
            session,
        )
        assert decode_access_token(token.access_token) == user.id

        await session.refresh(user)
        assert user.email_verified_at is not None
        row = await session.scalar(
            select(EmailVerificationCode).where(
                EmailVerificationCode.user_id == user.id
            )
        )
        assert row is not None and row.used_at is not None
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_login_blocked_until_email_confirmed() -> None:
    engine, session = await make_session()
    try:
        pending = await register(
            register_payload("blocked@example.com", "blockeduser"),
            BackgroundTasks(),
            session,
        )

        with pytest.raises(HTTPException) as exc:
            await login(
                _FakeRequest(),
                LoginRequest(email="blocked@example.com", password=PASSWORD),
                session,
            )
        assert exc.value.status_code == 403

        await verify_email(
            _FakeRequest(),
            VerifyEmailRequest(email="blocked@example.com", code=pending.verification_code),
            session,
        )
        token = await login(
            _FakeRequest(),
            LoginRequest(email="blocked@example.com", password=PASSWORD),
            session,
        )
        assert token.access_token
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_wrong_code_counts_attempts_then_locks(
    verification_settings,
) -> None:
    engine, session = await make_session()
    try:
        await register(
            register_payload("wrong@example.com", "wronguser"),
            BackgroundTasks(),
            session,
        )
        for _ in range(verification_settings.email_verification_max_attempts):
            with pytest.raises(HTTPException) as exc:
                await verify_email(
                    _FakeRequest(),
                    VerifyEmailRequest(email="wrong@example.com", code="000000"),
                    session,
                )
            assert exc.value.status_code == 400

        with pytest.raises(HTTPException) as exc:
            await verify_email(
                _FakeRequest(),
                VerifyEmailRequest(email="wrong@example.com", code="000000"),
                session,
            )
        assert exc.value.status_code == 429

        user = await session.scalar(
            select(User).where(User.email == "wrong@example.com")
        )
        assert user is not None
        assert user.email_verified_at is None
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_expired_code_is_rejected() -> None:
    engine, session = await make_session()
    try:
        pending = await register(
            register_payload("expired@example.com", "expireduser"),
            BackgroundTasks(),
            session,
        )
        user = await session.scalar(
            select(User).where(User.email == "expired@example.com")
        )
        row = await session.scalar(
            select(EmailVerificationCode).where(
                EmailVerificationCode.user_id == user.id
            )
        )
        row.expires_at = utcnow() - timedelta(minutes=1)
        session.add(row)
        await session.commit()

        with pytest.raises(HTTPException) as exc:
            await verify_email(
                _FakeRequest(),
                VerifyEmailRequest(
                    email="expired@example.com",
                    code=pending.verification_code,
                ),
                session,
            )
        assert exc.value.status_code == 400
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_resend_respects_cooldown_and_invalidates_old_code(
    verification_settings,
) -> None:
    engine, session = await make_session()
    try:
        pending = await register(
            register_payload("resend@example.com", "resenduser"),
            BackgroundTasks(),
            session,
        )
        blocked = await resend_verification(
            ResendVerificationRequest(email="resend@example.com"),
            BackgroundTasks(),
            session,
        )
        assert blocked["resend_available_in_seconds"] > 0
        assert "verification_code" not in blocked

        monkeypatched_cooldown = 0
        verification_settings.email_verification_resend_cooldown_seconds = (
            monkeypatched_cooldown
        )
        resent = await resend_verification(
            ResendVerificationRequest(email="resend@example.com"),
            BackgroundTasks(),
            session,
        )
        new_code = resent["verification_code"]
        assert new_code != pending.verification_code

        with pytest.raises(HTTPException) as exc:
            await verify_email(
                _FakeRequest(),
                VerifyEmailRequest(
                    email="resend@example.com",
                    code=pending.verification_code,
                ),
                session,
            )
        assert exc.value.status_code == 400

        token = await verify_email(
            _FakeRequest(),
            VerifyEmailRequest(email="resend@example.com", code=new_code),
            session,
        )
        assert token.access_token
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_resend_is_silent_for_unknown_email() -> None:
    engine, session = await make_session()
    try:
        response = await resend_verification(
            ResendVerificationRequest(email="ghost@example.com"),
            BackgroundTasks(),
            session,
        )
        assert response["status"] == "ok"
        assert "verification_code" not in response
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_unverified_signup_can_be_restarted_but_verified_email_conflicts() -> None:
    engine, session = await make_session()
    try:
        first = await register(
            register_payload("retry@example.com", "retryuser"),
            BackgroundTasks(),
            session,
        )
        second = await register(
            register_payload("retry@example.com", "retryuser2"),
            BackgroundTasks(),
            session,
        )
        assert second.verification_code != first.verification_code

        user = await session.scalar(
            select(User).where(User.email == "retry@example.com")
        )
        assert user.nickname == "retryuser2"

        await verify_email(
            _FakeRequest(),
            VerifyEmailRequest(email="retry@example.com", code=second.verification_code),
            session,
        )

        with pytest.raises(HTTPException) as exc:
            await register(
                register_payload("retry@example.com", "retryuser3"),
                BackgroundTasks(),
                session,
            )
        assert exc.value.status_code == 409
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_http_signup_flow_over_asgi(monkeypatch: pytest.MonkeyPatch) -> None:
    """Covers what direct calls cannot: routing, response models, background send."""
    from httpx import ASGITransport, AsyncClient

    from app.db import get_session
    from app.main import app

    sent: list[str] = []

    async def fake_send_email(*, to, subject, text_body, html_body=None):
        sent.append(to)
        return True

    monkeypatch.setattr("app.routers.auth.send_email", fake_send_email)

    engine, session = await make_session()

    async def override_session():
        yield session

    app.dependency_overrides[get_session] = override_session
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            created = await client.post(
                "/api/v1/auth/register",
                json={
                    "email": "http@example.com",
                    "password": PASSWORD,
                    "name": "HTTP Тест",
                    "nickname": "httptest",
                },
            )
            assert created.status_code == 201
            body = created.json()
            assert body["status"] == "verification_required"
            assert "access_token" not in body
            code = body["verification_code"]

            blocked = await client.post(
                "/api/v1/auth/login",
                json={"email": "http@example.com", "password": PASSWORD},
            )
            assert blocked.status_code == 403

            wrong = await client.post(
                "/api/v1/auth/verify-email",
                json={"email": "http@example.com", "code": "000000"},
            )
            assert wrong.status_code == 400

            verified = await client.post(
                "/api/v1/auth/verify-email",
                json={"email": "http@example.com", "code": code},
            )
            assert verified.status_code == 200
            token = verified.json()["access_token"]

            me = await client.get(
                "/api/v1/users/me",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert me.status_code == 200
            assert me.json()["email_verified"] is True

        # The confirmation email is queued as a background task, so it is only
        # dispatched once the response has been returned.
        assert sent == ["http@example.com"]
    finally:
        app.dependency_overrides.clear()
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_verify_rejects_already_confirmed_account() -> None:
    engine, session = await make_session()
    try:
        pending = await register(
            register_payload("done@example.com", "doneuser"),
            BackgroundTasks(),
            session,
        )
        await verify_email(
            _FakeRequest(),
            VerifyEmailRequest(email="done@example.com", code=pending.verification_code),
            session,
        )
        with pytest.raises(HTTPException) as exc:
            await verify_email(
                _FakeRequest(),
                VerifyEmailRequest(
                    email="done@example.com",
                    code=pending.verification_code,
                ),
                session,
            )
        assert exc.value.status_code == 409
    finally:
        await session.close()
        await engine.dispose()
