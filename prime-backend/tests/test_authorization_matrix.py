"""Authorization matrix — cross-user access must fail closed."""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.main import app
from app.models import Friendship, ModerationDecision, User, utcnow
from app.sessions import issue_session
from tests.test_email_verification import make_session


class _FakeRequest:
    client = type("Client", (), {"host": "127.0.0.1"})()
    headers = {"user-agent": "authz-matrix-test"}


async def _verified_user(
    session: AsyncSession,
    *,
    email: str,
    nickname: str,
    moderator: bool = False,
) -> tuple[User, str]:
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
        is_moderator=moderator,
    )
    session.add(user)
    await session.flush()
    token, _refresh = await issue_session(session, user, _FakeRequest())
    return user, token


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@asynccontextmanager
async def authz_context() -> AsyncIterator[dict]:
    engine, session = await make_session()
    user_a, token_a = await _verified_user(
        session, email="authz-a@example.com", nickname="authz-a"
    )
    user_b, token_b = await _verified_user(
        session, email="authz-b@example.com", nickname="authz-b"
    )
    mod, token_mod = await _verified_user(
        session,
        email="authz-mod@example.com",
        nickname="authz-mod",
        moderator=True,
    )
    await session.commit()

    async def override_get_session():
        yield session

    app.dependency_overrides[get_session] = override_get_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        try:
            yield {
                "session": session,
                "user_a": user_a,
                "user_b": user_b,
                "mod": mod,
                "token_a": token_a,
                "token_b": token_b,
                "token_mod": token_mod,
                "client": client,
            }
        finally:
            app.dependency_overrides.clear()
            await session.close()
            await engine.dispose()


@pytest.mark.asyncio
async def test_users_can_only_read_own_profile() -> None:
    async with authz_context() as ctx:
        client = ctx["client"]
        own = await client.get("/api/v1/users/me", headers=_auth(ctx["token_a"]))
        assert own.status_code == 200
        assert own.json()["id"] == ctx["user_a"].id

        foreign = await client.get("/api/v1/users/me", headers=_auth(ctx["token_b"]))
        assert foreign.status_code == 200
        assert foreign.json()["id"] == ctx["user_b"].id
        assert foreign.json()["id"] != ctx["user_a"].id


@pytest.mark.asyncio
async def test_direct_messages_require_friendship() -> None:
    async with authz_context() as ctx:
        client = ctx["client"]
        user_a = ctx["user_a"]
        user_b = ctx["user_b"]

        blocked = await client.get(
            f"/api/v1/direct-chats/{user_b.id}/messages",
            headers=_auth(ctx["token_a"]),
        )
        assert blocked.status_code == 404

        low, high = sorted((user_a.id, user_b.id))
        ctx["session"].add(Friendship(user_low_id=low, user_high_id=high))
        await ctx["session"].commit()

        allowed = await client.get(
            f"/api/v1/direct-chats/{user_b.id}/messages",
            headers=_auth(ctx["token_a"]),
        )
        assert allowed.status_code == 200


@pytest.mark.asyncio
async def test_user_cannot_respond_to_foreign_friend_request() -> None:
    async with authz_context() as ctx:
        client = ctx["client"]
        user_b = ctx["user_b"]

        created = await client.post(
            "/api/v1/friends/requests",
            headers=_auth(ctx["token_a"]),
            json={"nickname": user_b.nickname},
        )
        assert created.status_code in {200, 201}
        request_id = created.json().get("request_id")
        assert request_id

        hijack = await client.post(
            f"/api/v1/friends/requests/{request_id}/respond",
            headers=_auth(ctx["token_a"]),
            json={"accept": True},
        )
        assert hijack.status_code == 404


@pytest.mark.asyncio
async def test_non_moderator_cannot_access_ops_metrics() -> None:
    async with authz_context() as ctx:
        client = ctx["client"]
        response = await client.get(
            "/api/v1/ops/metrics",
            headers=_auth(ctx["token_a"]),
        )
        assert response.status_code == 403


@pytest.mark.asyncio
async def test_moderator_without_step_up_blocked_when_mfa_enforced(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.config import get_settings

    settings = get_settings()
    monkeypatch.setattr(settings, "moderator_mfa_enforce", True)

    async with authz_context() as ctx:
        client = ctx["client"]
        response = await client.get(
            "/api/v1/ops/metrics",
            headers=_auth(ctx["token_mod"]),
        )
        assert response.status_code == 403


@pytest.mark.asyncio
async def test_user_cannot_appeal_foreign_decision() -> None:
    async with authz_context() as ctx:
        session = ctx["session"]
        user_a = ctx["user_a"]
        client = ctx["client"]

        decision = ModerationDecision(
            id="decision-authz-1",
            actor_user_id=user_a.id,
            content_type="group_chat_message",
            category="PROFANITY",
            confidence_band="HIGH",
            action="REJECTED",
            policy_version="test",
            detector_version="test",
        )
        session.add(decision)
        await session.commit()

        foreign = await client.post(
            "/api/v1/moderation/appeals",
            headers=_auth(ctx["token_b"]),
            json={"decision_id": decision.id, "explanation": "not mine"},
        )
        assert foreign.status_code == 404

        own = await client.post(
            "/api/v1/moderation/appeals",
            headers=_auth(ctx["token_a"]),
            json={"decision_id": decision.id, "explanation": "mistake"},
        )
        assert own.status_code == 201


@pytest.mark.asyncio
async def test_anonymous_cannot_read_notifications() -> None:
    async with authz_context() as ctx:
        client = ctx["client"]
        response = await client.get("/api/v1/notifications")
        assert response.status_code == 401


@pytest.mark.asyncio
async def test_restriction_endpoint_scoped_to_current_user() -> None:
    async with authz_context() as ctx:
        client = ctx["client"]
        for token in (ctx["token_a"], ctx["token_b"]):
            response = await client.get(
                "/api/v1/users/me/restriction",
                headers=_auth(token),
            )
            assert response.status_code == 200
            assert response.json()["active"] is False
