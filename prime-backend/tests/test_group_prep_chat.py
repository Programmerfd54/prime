from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import pytest
from fastapi import HTTPException

from app.db import Base
from app.models import ChatMessage, Group, GroupMember, User
from app.routers.chat import chat_messages, chat_send_message_new
from app.routers.group_service import _require_group_member_for_chat


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


@pytest.mark.asyncio
async def test_prep_chat_allowed_in_introduction() -> None:
    engine, session = await make_session()
    try:
        user = User(
            email="prep@example.com",
            password_hash="hash",
            name="Prep User",
            nickname="prepuser",
            about=" ".join(["слово"] * 50),
            region_code="66",
            age=25,
            profile_completed=True,
        )
        group = Group(
            skill_id="body-charge",
            status="introduction",
            max_members=3,
        )
        session.add_all([user, group])
        await session.flush()
        session.add(GroupMember(group_id=group.id, user_id=user.id, active=True))
        await session.flush()

        resolved = await _require_group_member_for_chat(session, group.id, user)
        assert resolved.id == group.id

        sent = await chat_send_message_new(
            group.id,
            {"body": "@prepuser привет", "client_id": "prep-1"},
            user,
            session,
        )
        assert sent["body"] == "@prepuser привет"

        listed = await chat_messages(group.id, None, 50, user, session)
        assert len(listed["messages"]) == 1

        count = await session.scalar(select(func.count()).select_from(ChatMessage))
        assert count == 1
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_prep_chat_rejects_media_during_introduction() -> None:
    engine, session = await make_session()
    try:
        user = User(
            email="prep2@example.com",
            password_hash="hash",
            name="Prep User 2",
            nickname="prepuser2",
            about=" ".join(["слово"] * 50),
            region_code="66",
            age=25,
            profile_completed=True,
        )
        group = Group(
            skill_id="body-charge",
            status="introduction",
            max_members=3,
        )
        session.add_all([user, group])
        await session.flush()
        session.add(GroupMember(group_id=group.id, user_id=user.id, active=True))
        await session.flush()

        with pytest.raises(HTTPException) as error:
            await chat_send_message_new(
                group.id,
                {"body": "photo", "msgtype": "m.image", "url": "mxc://x"},
                user,
                session,
            )
        assert "текстовые" in str(error.value.detail).lower()
    finally:
        await session.close()
        await engine.dispose()
