import json

import pytest
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import DeviceToken, OutboxEvent, User
from app.notifications import create_notification, notification_payload
from app.routers.notifications import (
    clear_notifications,
    delete_notification,
    list_notifications,
    register_device,
    unregister_device,
)


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


@pytest.mark.asyncio
async def test_list_notifications_uses_keyset_cursor_without_duplicates() -> None:
    engine, session = await make_session()
    try:
        user = make_user(2)
        session.add(user)
        await session.flush()
        for index in range(3):
            await create_notification(
                session,
                user.id,
                "system",
                f"Тест {index}",
                "Тело",
                {"index": index},
            )
        await session.commit()

        first_page = await list_notifications(user, session, None, 1)
        second_page = await list_notifications(
            user,
            session,
            first_page["next_before"],
            1,
        )
        first_id = first_page["items"][0]["id"]
        second_id = second_page["items"][0]["id"]
        assert first_page["has_more"] is True
        assert second_page["has_more"] is True
        assert first_id != second_id
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_list_notifications_rejects_invalid_cursor() -> None:
    engine, session = await make_session()
    try:
        user = make_user(3)
        session.add(user)
        await session.flush()
        with pytest.raises(HTTPException) as error:
            await list_notifications(user, session, "not-a-cursor", 50)
        assert error.value.status_code == 400
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_delete_notification_removes_row() -> None:
    engine, session = await make_session()
    try:
        user = make_user(6)
        session.add(user)
        await session.flush()
        created = await create_notification(
            session,
            user.id,
            "system",
            "Тест",
            "Тело",
            {},
        )
        await session.commit()

        await delete_notification(created.id, user=user, session=session)
        result = await list_notifications(user, session)
        assert result["items"] == []
        assert result["unread_count"] == 0
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_clear_notifications_removes_all_for_user() -> None:
    engine, session = await make_session()
    try:
        user = make_user(7)
        other = make_user(8)
        session.add_all([user, other])
        await session.flush()
        await create_notification(session, user.id, "system", "A", "a", {})
        await create_notification(session, user.id, "system", "B", "b", {})
        await create_notification(session, other.id, "system", "C", "c", {})
        await session.commit()

        result = await clear_notifications(user=user, session=session)
        assert result["deleted"] == 2
        mine = await list_notifications(user, session)
        theirs = await list_notifications(other, session)
        assert mine["items"] == []
        assert len(theirs["items"]) == 1
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_create_notification_publishes_realtime_push() -> None:
    from app.direct_message_events import NotificationPush, direct_message_hub

    engine, session = await make_session()
    try:
        user = make_user(4)
        session.add(user)
        await session.flush()

        queue = direct_message_hub.subscribe(user.id)
        created = await create_notification(
            session,
            user.id,
            "friend_request",
            "Alice",
            "хочет добавить вас в друзья",
            {"request_id": "req-live"},
        )
        await session.commit()

        push = queue.get_nowait()
        assert isinstance(push, NotificationPush)
        assert push.notification["id"] == created.id
        assert push.notification["type"] == "friend_request"
        assert push.notification["payload"]["request_id"] == "req-live"
        outbox = await session.scalar(
            select(OutboxEvent).where(OutboxEvent.aggregate_id == created.id)
        )
        assert outbox is not None
        outbox_payload = json.loads(outbox.payload)
        assert outbox_payload["payload"]["type"] == "friend_request"
    finally:
        direct_message_hub.unsubscribe(user.id, queue)
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_device_token_records_provider_and_unregisters_on_logout_path() -> None:
    engine, session = await make_session()
    try:
        user = make_user(5)
        session.add(user)
        await session.flush()

        await register_device(
            {
                "token": "apns-device-token",
                "platform": "ios",
                "provider": "apns",
            },
            user=user,
            session=session,
        )
        token = await session.scalar(
            select(DeviceToken).where(DeviceToken.token == "apns-device-token")
        )
        assert token is not None
        assert token.user_id == user.id
        assert token.provider == "apns"

        await unregister_device(
            {"token": "apns-device-token"},
            user=user,
            session=session,
        )
        removed = await session.scalar(
            select(DeviceToken).where(DeviceToken.token == "apns-device-token")
        )
        assert removed is None
    finally:
        await session.close()
        await engine.dispose()
