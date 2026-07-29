import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import User
from app.notifications import create_notification, notification_payload
from app.routers.notifications import list_notifications


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"notify{index}@example.com",
        password_hash="hash",
        name=f"Notify {index}",
        nickname=f"notify{index}",
        about=" ".join(["слово"] * 50),
        region_code="66",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_create_notification_persists_and_serializes() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        session.add(user)
        await session.flush()

        created = await create_notification(
            session,
            user.id,
            "system",
            "Тест",
            "Тело уведомления",
            {"foo": "bar"},
        )
        await session.commit()
        await session.refresh(created)

        assert created.user_id == user.id
        assert created.type == "system"
        assert created.read_at is None

        payload = notification_payload(created)
        assert payload["title"] == "Тест"
        assert payload["body"] == "Тело уведомления"
        assert payload["payload"] == {"foo": "bar"}
        assert payload["read"] is False
        assert payload["created_at"]
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_list_notifications_returns_items_and_unread_count() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        session.add(user)
        await session.flush()

        first = await create_notification(
            session,
            user.id,
            "friend_request",
            "Alice",
            "хочет добавить вас в друзья",
            {"request_id": "req-1"},
        )
        second = await create_notification(
            session,
            user.id,
            "match",
            "Команда готова",
            "Вы собраны в команду",
            {"group_id": "group-1"},
        )
        second.read_at = first.created_at
        session.add(second)
        await session.commit()

        result = await list_notifications(user, session)
        assert result["unread_count"] == 1
        assert len(result["items"]) == 2
        types = {item["type"] for item in result["items"]}
        assert types == {"match", "friend_request"}
        friend_item = next(
            item for item in result["items"] if item["type"] == "friend_request"
        )
        assert friend_item["payload"]["request_id"] == "req-1"
    finally:
        await session.close()
        await engine.dispose()
