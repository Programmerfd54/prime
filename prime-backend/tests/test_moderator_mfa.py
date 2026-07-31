import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.mfa import confirm_totp, create_step_up, enroll_totp, has_valid_step_up, verify_totp
from app.models import AuthSession, User


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)


@pytest.mark.asyncio
async def test_totp_enroll_and_step_up(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.config import get_settings

    settings = get_settings()
    monkeypatch.setattr(
        settings,
        "matrix_token_encryption_key",
        "dGVzdC1rZXktdGVzdC1rZXktdGVzdC1rZXktdGVzdGtlYXk=",
    )
    engine, factory = await make_session()
    async with factory() as session:
        mod = User(
            email="mod@example.com",
            password_hash="hash",
            name="Mod",
            nickname="moduser",
            is_moderator=True,
            email_verified_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
        )
        session.add(mod)
        await session.flush()
        secret, _ = await enroll_totp(session, mod)
        import pyotp

        code = pyotp.TOTP(secret).now()
        await confirm_totp(session, mod, code)
        auth_session = AuthSession(
            user_id=mod.id,
            refresh_token_hash="abc123",
            expires_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc)
            + __import__("datetime").timedelta(days=1),
        )
        session.add(auth_session)
        await session.flush()
        assert not await has_valid_step_up(session, auth_session.id, mod.id)
        code2 = pyotp.TOTP(secret).now()
        assert await verify_totp(session, mod, code2)
        await create_step_up(session, auth_session_id=auth_session.id, user=mod, method="totp")
        assert await has_valid_step_up(session, auth_session.id, mod.id)
    await engine.dispose()
