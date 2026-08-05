from datetime import timedelta
import re

import pytest
from fastapi import BackgroundTasks, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import get_settings
from app.db import Base
from app.models import PasswordResetToken, User, utcnow
from app.routers.auth import _hash_reset_code, forgot_password, reset_password, verify_reset_code
from app.schemas import ForgotPasswordRequest, ResetPasswordRequest, VerifyResetCodeRequest
from app.security import hash_password, verify_password


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def _extract_reset_code(text_body: str) -> str:
    match = re.search(r"Код для приложения: (\d{6})", text_body)
    assert match is not None
    return match.group(1)


@pytest.mark.asyncio
async def test_forgot_verify_and_reset_password(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "password_reset_expose_token", True)
    engine, session = await make_session()
    try:
        user = User(
            email="reset@example.com",
            password_hash=hash_password("OldPass12"),
            name="Reset User",
            nickname="resetuser",
            about=" ".join(["слово"] * 50),
            region_code="66",
            age=25,
            profile_completed=True,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)

        tasks = BackgroundTasks()
        result = await forgot_password(
            ForgotPasswordRequest(email="reset@example.com"),
            session,
            background_tasks=tasks,
        )
        assert result["status"] == "ok"
        assert tasks.tasks
        text_body = tasks.tasks[0].kwargs["text_body"]
        code = _extract_reset_code(text_body)
        assert len(code) == 6

        verified = await verify_reset_code(
            VerifyResetCodeRequest(email="reset@example.com", code=code),
            session,
        )
        assert verified["valid"] is True

        await reset_password(
            ResetPasswordRequest(
                email="reset@example.com",
                code=code,
                new_password="NewPass34",
            ),
            session,
        )
        await session.refresh(user)
        assert verify_password("NewPass34", user.password_hash)

        used = await session.scalar(
            select(PasswordResetToken).where(
                PasswordResetToken.token_hash == _hash_reset_code(user.id, code)
            )
        )
        assert used is not None
        assert used.used_at is not None
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_forgot_password_respects_resend_cooldown(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "password_reset_resend_cooldown_seconds", 60)
    engine, session = await make_session()
    try:
        user = User(
            email="cooldown@example.com",
            password_hash=hash_password("OldPass12"),
            name="Cooldown User",
            nickname="cooldownuser",
        )
        session.add(user)
        await session.commit()

        first = await forgot_password(
            ForgotPasswordRequest(email="cooldown@example.com"),
            session,
        )
        assert first["status"] == "ok"
        assert first["resend_available_in_seconds"] == 60

        second = await forgot_password(
            ForgotPasswordRequest(email="cooldown@example.com"),
            session,
        )
        assert second["status"] == "ok"
        assert second["resend_available_in_seconds"] > 0
        assert second["resend_available_in_seconds"] <= 60
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_reset_rejects_expired_token() -> None:
    engine, session = await make_session()
    try:
        user = User(
            email="expired@example.com",
            password_hash=hash_password("OldPass12"),
            name="Expired",
            nickname="expireduser",
            about=" ".join(["слово"] * 50),
            region_code="66",
            age=25,
            profile_completed=True,
        )
        session.add(user)
        await session.flush()
        code = "123456"
        session.add(
            PasswordResetToken(
                user_id=user.id,
                token_hash=_hash_reset_code(user.id, code),
                expires_at=utcnow() - timedelta(minutes=1),
            )
        )
        await session.commit()

        with pytest.raises(HTTPException) as exc:
            await reset_password(
                ResetPasswordRequest(
                    email="expired@example.com",
                    code=code,
                    new_password="NewPass34",
                ),
                session,
            )
        assert exc.value.status_code == 400
    finally:
        await session.close()
        await engine.dispose()
