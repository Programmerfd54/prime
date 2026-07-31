import asyncio

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.db import get_session
from app.direct_message_events import DirectMessagePush, direct_message_hub
from app.main import app
from app.models import AuthSession, User, utcnow
from app.routers import notifications as notifications_router
from app.sessions import issue_session, revoke_session
from tests.test_email_verification import make_session


class _FakeRequest:
    client = type("Client", (), {"host": "127.0.0.1"})()
    headers = {"user-agent": "sse-security-test"}


async def _verified_user(session, email: str, nickname: str) -> User:
    user = User(
        email=email,
        password_hash="hash",
        name=nickname,
        nickname=nickname,
        about=" ".join(["слово"] * 50),
        region_code="77",
        city="Москва",
        age=30,
        profile_completed=True,
        email_verified_at=utcnow(),
    )
    session.add(user)
    await session.flush()
    return user


@pytest.mark.asyncio
async def test_sse_requires_authentication() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/v1/events/stream")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_sse_hub_events_stay_scoped_to_subscriber() -> None:
    engine, session = await make_session()
    queue_a = None
    queue_b = None
    user_a = user_b = None
    try:
        user_a = await _verified_user(session, "sse-a@example.com", "sse-a")
        user_b = await _verified_user(session, "sse-b@example.com", "sse-b")
        await session.commit()

        queue_a = direct_message_hub.subscribe(user_a.id)
        queue_b = direct_message_hub.subscribe(user_b.id)

        direct_message_hub.publish(
            user_b.id,
            DirectMessagePush(
                friend_id="friend-1",
                message_id="msg-for-b",
                message={"body": "secret"},
            ),
        )
        direct_message_hub.publish(
            user_a.id,
            DirectMessagePush(
                friend_id="friend-2",
                message_id="msg-for-a",
                message={"body": "for-a"},
            ),
        )

        push_a = await asyncio.wait_for(queue_a.get(), timeout=1.0)
        assert push_a.message_id == "msg-for-a"

        push_b = await asyncio.wait_for(queue_b.get(), timeout=1.0)
        assert push_b.message_id == "msg-for-b"

        direct_message_hub.publish(
            user_b.id,
            DirectMessagePush(
                friend_id="friend-3",
                message_id="only-b",
                message={"body": "b-only"},
            ),
        )
        with pytest.raises(asyncio.TimeoutError):
            await asyncio.wait_for(queue_a.get(), timeout=0.05)
    finally:
        if queue_a is not None and user_a is not None:
            direct_message_hub.unsubscribe(user_a.id, queue_a)
        if queue_b is not None and user_b is not None:
            direct_message_hub.unsubscribe(user_b.id, queue_b)
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_notification_stream_closes_after_session_revoke(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    engine, session = await make_session()
    factory = async_sessionmaker(engine, expire_on_commit=False)
    monkeypatch.setattr(notifications_router, "SessionLocal", factory)
    try:
        user = await _verified_user(session, "sse-revoke@example.com", "sse-revoke")
        _access_token, _refresh = await issue_session(session, user, _FakeRequest())
        auth_row = await session.scalar(
            select(AuthSession).where(AuthSession.user_id == user.id)
        )
        assert auth_row is not None
        await session.commit()

        stream = notifications_router._notification_stream(user.id, auth_row.id)

        async def consume() -> list[str]:
            chunks: list[str] = []
            async for chunk in stream:
                chunks.append(chunk)
            return chunks

        task = asyncio.create_task(consume())
        await asyncio.sleep(0.05)
        await revoke_session(session, auth_row)
        await session.commit()
        chunks = await asyncio.wait_for(task, timeout=3.0)
        assert any(
            marker in chunk
            for chunk in chunks
            for marker in ("connected", "heartbeat")
        ) or chunks == []
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_sse_cors_allows_cache_control_preflight() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.options(
            "/api/v1/events/stream",
            headers={
                "Origin": "http://localhost:59704",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization,cache-control,accept",
            },
        )
    assert response.status_code == 200
    allow_headers = response.headers.get("access-control-allow-headers", "").lower()
    assert "cache-control" in allow_headers


@pytest.mark.asyncio
async def test_sse_rejects_revoked_token_on_connect() -> None:
    engine, session = await make_session()

    async def override_get_session():
        yield session

    app.dependency_overrides[get_session] = override_get_session
    try:
        user = await _verified_user(session, "sse-old@example.com", "sse-old")
        access_token, _refresh = await issue_session(session, user, _FakeRequest())
        auth_row = await session.scalar(select(AuthSession).where(AuthSession.user_id == user.id))
        assert auth_row is not None
        await revoke_session(session, auth_row)
        await session.commit()

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(
                "/api/v1/events/stream",
                headers={"Authorization": f"Bearer {access_token}"},
            )
        assert response.status_code == 401
    finally:
        app.dependency_overrides.clear()
        await session.close()
        await engine.dispose()
