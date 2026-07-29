from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import pytest

from app.db import Base
from app.models import ChatMessage, Group, GroupMember, User
from app.routers import misc


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"intro{index}@example.com",
        password_hash="hash",
        name=f"Intro User {index}",
        nickname=f"intro{index}",
        about=f"Полное описание участника {index} " + " ".join(["слово"] * 50),
        region_code="74",
        city="Челябинская область",
        age=20 + index,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_group_activation_posts_member_intro_messages(monkeypatch) -> None:
    engine, session = await make_session()
    sent_events: list[dict] = []

    async def fake_create_room(owner: User, invitees: list[User], name: str) -> str:
        assert owner.nickname == "intro1"
        assert len(invitees) == 5
        assert "PRIME" in name
        return "!intro-room:matrix"

    async def fake_send_room_message(user: User, room_id: str, content: dict) -> str:
        sent_events.append({"user": user.nickname, "room_id": room_id, "content": content})
        return f"$intro-{len(sent_events)}"

    monkeypatch.setattr(misc, "create_room", fake_create_room)
    monkeypatch.setattr(misc, "send_room_message", fake_send_room_message)
    monkeypatch.setattr("app.routers.group_service.create_room", fake_create_room)
    monkeypatch.setattr("app.routers.group_service.send_room_message", fake_send_room_message)

    try:
        users = [make_user(index) for index in range(1, 7)]
        for user in users:
            user.matrix_user_id = f"@{user.nickname}:matrix"
            user.matrix_access_token = "token"
        group = Group(
            name="Intro group",
            skill_id="body-charge",
            region_code="74",
            status="rules_pending",
        )
        session.add_all([group, *users])
        await session.flush()
        for index, user in enumerate(users):
            session.add(
                GroupMember(
                    group_id=group.id,
                    user_id=user.id,
                    role="creator" if index == 0 else "member",
                    confirmed_participation=True,
                    accepted_rules=True,
                )
            )
        await session.flush()

        await misc._activate_if_ready(session, group)
        await session.commit()

        await session.refresh(group)
        messages = (await session.execute(select(ChatMessage))).scalars().all()
        assert group.status == "active"
        assert group.matrix_room_id == "!intro-room:matrix"
        assert len(messages) == 6
        assert len(sent_events) == 6
        assert messages[0].body.startswith("👋 Знакомство")
        assert "Intro User 1 (@intro1)" in messages[0].body
        assert "Челябинская область" in messages[0].body
        assert "Полное описание участника 1" in messages[0].body
    finally:
        await session.close()
        await engine.dispose()
