from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import DirectMessage, Friendship, User
from app.routers.misc import (
    _direct_chat_inbox_items,
    _direct_conversation_key,
    _mark_direct_chat_read,
)


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"inbox{index}@example.com",
        password_hash="hash",
        name=f"Inbox {index}",
        nickname=f"inbox{index}",
        about=" ".join(["слово"] * 50),
        region_code="66",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_direct_chat_inbox_last_message_and_unread() -> None:
    engine, session = await make_session()
    try:
        alice = make_user(1)
        bob = make_user(2)
        session.add_all([alice, bob])
        await session.flush()
        low, high = tuple(sorted((alice.id, bob.id)))
        session.add(Friendship(user_low_id=low, user_high_id=high))
        key = _direct_conversation_key(alice.id, bob.id)
        older = datetime.now(timezone.utc) - timedelta(minutes=10)
        newer = datetime.now(timezone.utc) - timedelta(minutes=1)
        session.add_all(
            [
                DirectMessage(
                    conversation_key=key,
                    sender_user_id=alice.id,
                    recipient_user_id=bob.id,
                    body="привет",
                    created_at=older,
                ),
                DirectMessage(
                    conversation_key=key,
                    sender_user_id=bob.id,
                    recipient_user_id=alice.id,
                    body="как дела",
                    created_at=newer,
                ),
            ]
        )
        await session.commit()

        inbox = await _direct_chat_inbox_items(session, alice)
        assert len(inbox) == 1
        assert inbox[0]["friend"]["id"] == bob.id
        assert inbox[0]["last_message"]["body"] == "как дела"
        assert inbox[0]["unread_count"] == 1

        await _mark_direct_chat_read(session, alice.id, bob.id)
        inbox_after = await _direct_chat_inbox_items(session, alice)
        assert inbox_after[0]["unread_count"] == 0
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_direct_chat_inbox_sorts_active_first() -> None:
    engine, session = await make_session()
    try:
        alice = make_user(10)
        bob = make_user(11)
        carol = make_user(12)
        session.add_all([alice, bob, carol])
        await session.flush()
        for friend in (bob, carol):
            low, high = tuple(sorted((alice.id, friend.id)))
            session.add(Friendship(user_low_id=low, user_high_id=high))
        session.add(
            DirectMessage(
                conversation_key=_direct_conversation_key(alice.id, bob.id),
                sender_user_id=bob.id,
                recipient_user_id=alice.id,
                body="есть чат",
                created_at=datetime.now(timezone.utc),
            )
        )
        await session.commit()

        inbox = await _direct_chat_inbox_items(session, alice)
        assert [item["friend"]["id"] for item in inbox] == [bob.id, carol.id]
        assert inbox[0]["last_message"]["body"] == "есть чат"
        assert inbox[1]["last_message"] is None
    finally:
        await session.close()
        await engine.dispose()
