from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import pytest
from fastapi import HTTPException

from app.db import Base
from app.models import ChatMessage, ChatMessageReaction, Group, GroupMember, User
from app.routers.misc import chat_toggle_reaction


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"reaction{index}@example.com",
        password_hash="hash",
        name=f"Reaction User {index}",
        nickname=f"reaction{index}",
        about=" ".join(["word"] * 50),
        region_code="77",
        city="Москва",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_chat_reaction_toggle() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        sender = make_user(2)
        group = Group(
            name="Test group",
            skill_id="body-charge",
            region_code="77",
            status="active",
        )
        session.add_all([user, sender, group])
        await session.flush()
        session.add_all(
            [
                GroupMember(group_id=group.id, user_id=user.id),
                GroupMember(group_id=group.id, user_id=sender.id),
            ]
        )
        message = ChatMessage(
            group_id=group.id,
            sender_user_id=sender.id,
            sender_matrix_id="@sender:matrix",
            event_id="$reaction-test",
            body="Отчёт готов",
        )
        session.add(message)
        await session.commit()
        await session.refresh(message)

        added = await chat_toggle_reaction(message.id, {"emoji": "🔥"}, user, session)
        reactions = (await session.execute(select(ChatMessageReaction))).scalars().all()
        assert len(reactions) == 1
        assert added["reactions"] == [{"emoji": "🔥", "count": 1, "reacted_by_me": True}]

        removed = await chat_toggle_reaction(message.id, {"emoji": "🔥"}, user, session)
        reactions = (await session.execute(select(ChatMessageReaction))).scalars().all()
        assert reactions == []
        assert removed["reactions"] == []
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_chat_reaction_rejects_unknown_emoji() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        group = Group(name="Test group", skill_id="body-charge", region_code="77", status="active")
        session.add_all([user, group])
        await session.flush()
        session.add(GroupMember(group_id=group.id, user_id=user.id))
        message = ChatMessage(
            group_id=group.id,
            sender_user_id=user.id,
            sender_matrix_id="@user:matrix",
            event_id="$reaction-test-unknown",
            body="Отчёт готов",
        )
        session.add(message)
        await session.commit()
        await session.refresh(message)

        with pytest.raises(HTTPException) as exc:
            await chat_toggle_reaction(message.id, {"emoji": "🧨"}, user, session)
        assert exc.value.status_code == 400
    finally:
        await session.close()
        await engine.dispose()
