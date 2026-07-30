from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import User, WaitingRoomEntry
from app.routers.group_service import waiting_room_payload


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int, region: str = "66") -> User:
    now = datetime.now(timezone.utc)
    return User(
        email=f"pair-user{index}@example.com",
        password_hash="hash",
        name=f"Pair User {index}",
        nickname=f"pair{index}",
        about=" ".join(["слово"] * 50),
        region_code=region,
        city="Свердловская область" if region == "66" else "Москва",
        age=25,
        profile_completed=True,
        last_seen_at=now,
    )


@pytest.mark.asyncio
async def test_pair_group_counts_cross_region_members() -> None:
    """Friends who accept pair invites appear in host slots even from other regions."""
    engine, session = await make_session()
    try:
        host = make_user(1, "66")
        friend_one = make_user(2, "66")
        friend_two = make_user(3, "77")
        session.add_all([host, friend_one, friend_two])
        await session.flush()

        pair_code = "pair-test-code"
        host_entry = WaitingRoomEntry(
            user_id=host.id,
            skill_id="reading-chapter",
            region_code="66",
            pair_code=pair_code,
        )
        friend_one_entry = WaitingRoomEntry(
            user_id=friend_one.id,
            skill_id="reading-chapter",
            region_code="66",
            pair_code=pair_code,
        )
        friend_two_entry = WaitingRoomEntry(
            user_id=friend_two.id,
            skill_id="reading-chapter",
            region_code="66",
            pair_code=pair_code,
        )
        session.add_all([host_entry, friend_one_entry, friend_two_entry])
        await session.flush()

        payload = await waiting_room_payload(
            session,
            host_entry,
            current_user_id=host.id,
        )

        assert payload["people_waiting"] == 3
        assert len(payload["slots"]) == 3
        assert all(slot["letter"] for slot in payload["slots"])
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_pair_group_includes_two_accepted_friends() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(1, 4)]
        session.add_all(users)
        await session.flush()

        pair_code = "shared-invite"
        entries = []
        for user in users:
            entry = WaitingRoomEntry(
                user_id=user.id,
                skill_id="reading-chapter",
                region_code="66",
                pair_code=pair_code,
            )
            session.add(entry)
            entries.append(entry)
        await session.flush()

        payload = await waiting_room_payload(
            session,
            entries[0],
            current_user_id=users[0].id,
        )

        assert payload["people_waiting"] == 3
        assert len(payload["slots"]) == 3
    finally:
        await session.close()
        await engine.dispose()
