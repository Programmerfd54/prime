from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import pytest

from app.db import Base
from app.models import ChatMessage, Group, GroupMember, User
from app.routers.chat import chat_send_message_new


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


@pytest.mark.asyncio
async def test_group_message_client_id_is_idempotent(monkeypatch) -> None:
    engine, session = await make_session()
    sends: list[str] = []

    async def fake_send_room_message(user, room_id, content, *, txn_id=None):
        sends.append(txn_id or "random")
        return f"$event-{len(sends)}"

    monkeypatch.setattr("app.routers.group_service.send_room_message", fake_send_room_message)
    try:
        user = User(
            email="chat-idempotency@example.com",
            password_hash="hash",
            name="Chat User",
            nickname="chat-idempotency",
            about=" ".join(["слово"] * 50),
            region_code="66",
            age=25,
            profile_completed=True,
        )
        group = Group(skill_id="body-charge", status="active", max_members=1)
        session.add_all([user, group])
        await session.flush()
        session.add(GroupMember(group_id=group.id, user_id=user.id, active=True))
        await session.flush()

        first = await chat_send_message_new(
            group.id,
            {"body": "один раз", "client_id": "mobile-123"},
            user,
            session,
        )
        second = await chat_send_message_new(
            group.id,
            {"body": "один раз", "client_id": "mobile-123"},
            user,
            session,
        )

        count = await session.scalar(select(func.count()).select_from(ChatMessage))
        assert first["id"] == second["id"]
        assert second["client_id"] == "mobile-123"
        assert count == 1
        assert sends == [f"prime-{user.id}-mobile-123"]
    finally:
        await session.close()
        await engine.dispose()
