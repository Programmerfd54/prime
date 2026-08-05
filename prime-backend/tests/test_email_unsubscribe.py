from datetime import timedelta

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import get_settings
from app.db import Base
from app.email_unsubscribe import (
    LETTER_MARKETING,
    build_unsubscribe_url,
    create_unsubscribe_link,
    hash_unsubscribe_token,
)
from app.main import app
from app.models import EmailUnsubscribeToken, User, utcnow
from app.security import hash_password


async def _make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    return engine, session_factory


@pytest.fixture(autouse=True)
def unsubscribe_settings(monkeypatch: pytest.MonkeyPatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "public_mail_base_url", "http://testserver")
    monkeypatch.setattr(settings, "email_unsubscribe_rate_limit_attempts", 100)
    return settings


@pytest.mark.asyncio
async def test_unsubscribe_success_page() -> None:
    engine, session_factory = await _make_session()
    try:
        async with session_factory() as session:
            user = User(
                email="reader@example.com",
                password_hash=hash_password("PrimePass12"),
                name="Reader",
                nickname="reader",
            )
            session.add(user)
            await session.commit()

            url = await create_unsubscribe_link(
                session,
                user_id=user.id,
                letter=LETTER_MARKETING,
            )
            raw_token = url.rsplit("/", 1)[-1]

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            app.dependency_overrides.clear()

            async def override_session():
                async with session_factory() as session:
                    yield session

            from app.db import get_session

            app.dependency_overrides[get_session] = override_session

            response = await client.get(f"/unsubscribe/{raw_token}")

        assert response.status_code == 200
        assert "Вы отписались от рассылки" in response.text
        assert "reader@example.com" in response.text
        assert response.headers.get("referrer-policy") == "no-referrer"

        async with session_factory() as session:
            refreshed = await session.scalar(select(User).where(User.id == user.id))
            assert refreshed is not None
            assert refreshed.marketing_emails_opt_in is False
            assert refreshed.marketing_emails_unsubscribed_at is not None
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()


@pytest.mark.asyncio
async def test_unsubscribe_already_used_page() -> None:
    engine, session_factory = await _make_session()
    try:
        async with session_factory() as session:
            user = User(
                email="again@example.com",
                password_hash=hash_password("PrimePass12"),
                name="Again",
                nickname="againuser",
            )
            session.add(user)
            await session.commit()

            url = await create_unsubscribe_link(
                session,
                user_id=user.id,
                letter=LETTER_MARKETING,
            )
            raw_token = url.rsplit("/", 1)[-1]

        transport = ASGITransport(app=app)

        async def override_session():
            async with session_factory() as session:
                yield session

        from app.db import get_session

        app.dependency_overrides[get_session] = override_session

        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            first = await client.get(f"/unsubscribe/{raw_token}")
            second = await client.get(f"/unsubscribe/{raw_token}")

        assert first.status_code == 200
        assert "Вы отписались" in first.text
        assert second.status_code == 200
        assert "Вы уже отписаны" in second.text
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()


@pytest.mark.asyncio
async def test_unsubscribe_expired_page() -> None:
    engine, session_factory = await _make_session()
    try:
        raw_token = "test-expired-token-value-1234567890"
        async with session_factory() as session:
            user = User(
                email="expired@example.com",
                password_hash=hash_password("PrimePass12"),
                name="Expired",
                nickname="expireduser",
            )
            session.add(user)
            await session.flush()
            session.add(
                EmailUnsubscribeToken(
                    token_hash=hash_unsubscribe_token(raw_token),
                    user_id=user.id,
                    letter=LETTER_MARKETING,
                    expires_at=utcnow() - timedelta(days=1),
                )
            )
            await session.commit()

        transport = ASGITransport(app=app)

        async def override_session():
            async with session_factory() as session:
                yield session

        from app.db import get_session

        app.dependency_overrides[get_session] = override_session

        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            response = await client.get(f"/unsubscribe/{raw_token}")

        assert response.status_code == 410
        assert "Ссылка больше не действует" in response.text
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()


@pytest.mark.asyncio
async def test_unsubscribe_already_opted_out_user() -> None:
    engine, session_factory = await _make_session()
    try:
        async with session_factory() as session:
            user = User(
                email="optout@example.com",
                password_hash=hash_password("PrimePass12"),
                name="Optout",
                nickname="optoutuser",
                marketing_emails_opt_in=False,
            )
            session.add(user)
            await session.commit()

            url = await create_unsubscribe_link(
                session,
                user_id=user.id,
                letter=LETTER_MARKETING,
            )
            raw_token = url.rsplit("/", 1)[-1]

        transport = ASGITransport(app=app)

        async def override_session():
            async with session_factory() as session:
                yield session

        from app.db import get_session

        app.dependency_overrides[get_session] = override_session

        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            response = await client.get(f"/unsubscribe/{raw_token}")

        assert response.status_code == 200
        assert "Вы уже отписаны от рассылки" in response.text
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()

    url = build_unsubscribe_url("abc123")
    assert url == "http://testserver/unsubscribe/abc123"
