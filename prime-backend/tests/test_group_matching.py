from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import GroupMember, User, WaitingRoomEntry
from app.routers.misc import _maybe_match_waiting_room, waiting_room_payload


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int, region: str = "66") -> User:
    return User(
        email=f"user{index}@example.com",
        password_hash="hash",
        name=f"User {index}",
        nickname=f"user{index}",
        about=" ".join(["слово"] * 50),
        region_code=region,
        city="Свердловская область" if region == "66" else "Москва",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_same_people_can_have_one_group_per_different_skill() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index) for index in range(6)]
        session.add_all(users)
        await session.flush()
        for user in users:
            session.add_all(
                [
                    WaitingRoomEntry(
                        user_id=user.id,
                        skill_id="morning-focus",
                        region_code="66",
                    ),
                    WaitingRoomEntry(
                        user_id=user.id,
                        skill_id="digital-detox",
                        region_code="66",
                    ),
                ]
            )
        await session.flush()

        first = await _maybe_match_waiting_room(session, "morning-focus", "66")
        second = await _maybe_match_waiting_room(session, "digital-detox", "66")
        await session.commit()

        assert first is not None
        assert second is not None
        assert first.id != second.id
        memberships = (await session.execute(select(GroupMember))).scalars().all()
        assert len(memberships) == 12
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_local_region_has_priority_and_does_not_mix_without_consent() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(5)]
        outsider = make_user(99, "77")
        session.add_all([*users, outsider])
        await session.flush()
        for user in users:
            session.add(
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="morning-focus",
                    region_code="66",
                )
            )
        session.add(
            WaitingRoomEntry(
                user_id=outsider.id,
                skill_id="morning-focus",
                region_code="77",
            )
        )
        await session.flush()
        assert await _maybe_match_waiting_room(session, "morning-focus", "66") is None

        sixth = make_user(6, "66")
        session.add(sixth)
        await session.flush()
        session.add(
            WaitingRoomEntry(
                user_id=sixth.id,
                skill_id="morning-focus",
                region_code="66",
            )
        )
        await session.flush()
        group = await _maybe_match_waiting_room(session, "morning-focus", "66")
        assert group is not None
        assert group.region_code == "66"
        assert not group.is_cross_region
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_expansion_is_offered_after_fifteen_minutes() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        session.add(user)
        await session.flush()
        entry = WaitingRoomEntry(
            user_id=user.id,
            skill_id="morning-focus",
            region_code="66",
            created_at=datetime.now(timezone.utc) - timedelta(minutes=16),
        )
        session.add(entry)
        await session.flush()
        payload = await waiting_room_payload(session, entry)
        assert payload["can_expand_search"] is True
        assert payload["allow_other_regions"] is False
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_expansion_is_not_offered_before_fifteen_minutes() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        session.add(user)
        await session.flush()
        entry = WaitingRoomEntry(
            user_id=user.id,
            skill_id="morning-focus",
            region_code="66",
            created_at=datetime.now(timezone.utc) - timedelta(minutes=14),
        )
        session.add(entry)
        await session.flush()
        payload = await waiting_room_payload(session, entry)
        assert payload["can_expand_search"] is False
        assert payload["min_members"] == 3
        assert payload["partial_start_available_at"] is not None
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_partial_group_starts_after_twenty_four_hours_with_three_people() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        for user in users:
            session.add(
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="evening-ritual",
                    region_code="66",
                    created_at=datetime.now(timezone.utc) - timedelta(hours=24, minutes=1),
                )
            )
        await session.flush()

        group = await _maybe_match_waiting_room(session, "evening-ritual", "66")
        await session.commit()

        assert group is not None
        assert group.region_code == "66"
        assert not group.is_cross_region
        assert group.max_members == 3
        memberships = (await session.execute(select(GroupMember))).scalars().all()
        assert len(memberships) == 3
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_partial_group_does_not_start_with_two_people_after_twenty_four_hours() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(2)]
        session.add_all(users)
        await session.flush()
        for user in users:
            session.add(
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="evening-ritual",
                    region_code="66",
                    created_at=datetime.now(timezone.utc) - timedelta(hours=24, minutes=1),
                )
            )
        await session.flush()

        group = await _maybe_match_waiting_room(session, "evening-ritual", "66")
        assert group is None
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_partial_group_does_not_start_before_twelve_hours() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        for user in users:
            session.add(
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="evening-ritual",
                    region_code="66",
                    created_at=datetime.now(timezone.utc) - timedelta(hours=11, minutes=59),
                )
            )
        await session.flush()

        group = await _maybe_match_waiting_room(session, "evening-ritual", "66")
        assert group is None
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_partial_cross_region_group_requires_consent() -> None:
    engine, session = await make_session()
    try:
        local = make_user(1, "66")
        outsider_one = make_user(2, "77")
        outsider_two = make_user(3, "74")
        session.add_all([local, outsider_one, outsider_two])
        await session.flush()
        for user, region in [(local, "66"), (outsider_one, "77"), (outsider_two, "74")]:
            session.add(
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="evening-ritual",
                    region_code=region,
                    created_at=datetime.now(timezone.utc) - timedelta(hours=24, minutes=1),
                )
            )
        await session.flush()
        assert await _maybe_match_waiting_room(session, "evening-ritual", "66") is None

        entries = (await session.execute(select(WaitingRoomEntry))).scalars().all()
        for entry in entries:
            entry.allow_other_regions = True
            session.add(entry)
        await session.flush()

        group = await _maybe_match_waiting_room(session, "evening-ritual", "66")
        assert group is not None
        assert group.region_code is None
        assert group.is_cross_region
        assert group.max_members == 3
    finally:
        await session.close()
        await engine.dispose()
