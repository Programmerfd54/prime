from datetime import datetime, timezone

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import AuthSession, User
from app.security import create_access_token, decode_access_token_claims
from app.sessions import hash_refresh_token, issue_session, revoke_user_sessions


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


class FakeRequest:
    client = type("Client", (), {"host": "127.0.0.1"})()
    headers = {"user-agent": "security-test"}


def test_access_token_hard_cap_and_claims(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.config import get_settings

    settings = get_settings()
    monkeypatch.setattr(settings, "access_token_expire_minutes", 43200)
    claims = decode_access_token_claims(create_access_token("user-1"))
    now = datetime.now(timezone.utc).timestamp()
    assert claims["sub"] == "user-1"
    assert claims["sid"]
    assert claims["jti"]
    assert claims["iss"] == settings.jwt_issuer
    assert claims["aud"] == settings.jwt_audience
    assert 0 < claims["exp"] - now <= 15 * 60 + 2


@pytest.mark.asyncio
async def test_refresh_token_is_hashed_and_sessions_revoke() -> None:
    engine, session = await make_session()
    try:
        user = User(email="session@example.com", password_hash="hash", nickname="session-user")
        session.add(user)
        await session.flush()
        access_token, refresh_token = await issue_session(session, user, FakeRequest())
        await session.commit()
        assert access_token
        assert refresh_token
        row = await session.scalar(select(AuthSession).where(AuthSession.user_id == user.id))
        assert row is not None
        assert row.refresh_token_hash == hash_refresh_token(refresh_token)
        assert row.refresh_token_hash != refresh_token
        await revoke_user_sessions(session, user.id)
        await session.commit()
        await session.refresh(row)
        assert row.revoked_at is not None
    finally:
        await session.close()
        await engine.dispose()
