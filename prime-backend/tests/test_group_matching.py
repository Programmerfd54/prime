from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import GroupMember, User, WaitingRoomEntry
from app.routers.misc import _maybe_match_waiting_room, waiting_room_payload
from app.routers.group_service import REGION_EXPANSION_DELAY


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
async def test_search_auto_expands_to_all_russia_after_five_minutes() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        session.add(user)
        await session.flush()
        entry = WaitingRoomEntry(
            user_id=user.id,
            skill_id="morning-focus",
            region_code="66",
            created_at=datetime.now(timezone.utc) - REGION_EXPANSION_DELAY - timedelta(minutes=1),
        )
        session.add(entry)
        await session.flush()
        payload = await waiting_room_payload(session, entry)
        assert payload["allow_other_regions"] is True
        assert payload["can_expand_search"] is False
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_search_stays_local_before_five_minutes() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        session.add(user)
        await session.flush()
        entry = WaitingRoomEntry(
            user_id=user.id,
            skill_id="morning-focus",
            region_code="66",
            created_at=datetime.now(timezone.utc) - REGION_EXPANSION_DELAY + timedelta(minutes=1),
        )
        session.add(entry)
        await session.flush()
        payload = await waiting_room_payload(session, entry)
        assert payload["can_expand_search"] is False
        assert payload["allow_other_regions"] is False
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
async def test_early_start_available_with_three_people_in_queue() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        entries = []
        for user in users:
            entry = WaitingRoomEntry(
                user_id=user.id,
                skill_id="morning-focus",
                region_code="66",
            )
            session.add(entry)
            entries.append(entry)
        await session.flush()

        payload = await waiting_room_payload(session, entries[0])
        assert payload["can_start_early"] is True
        assert payload["people_waiting"] == 3
        assert payload["early_start_confirmed_count"] == 0
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_early_start_creates_group_after_three_confirmations() -> None:
    from app.routers.group_service import _create_group_from_early_start_entries

    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        now = datetime.now(timezone.utc)
        entries = []
        for index, user in enumerate(users):
            entry = WaitingRoomEntry(
                user_id=user.id,
                skill_id="morning-focus",
                region_code="66",
                pair_start_confirmed_at=now + timedelta(seconds=index),
            )
            session.add(entry)
            entries.append(entry)
        await session.flush()

        group = await _create_group_from_early_start_entries(session, entries)
        await session.commit()

        assert group is not None
        assert group.max_members == 3
        memberships = (await session.execute(select(GroupMember))).scalars().all()
        assert len(memberships) == 3
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_early_start_not_available_with_two_people() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(2)]
        session.add_all(users)
        await session.flush()
        entries = []
        for user in users:
            entry = WaitingRoomEntry(
                user_id=user.id,
                skill_id="morning-focus",
                region_code="66",
            )
            session.add(entry)
            entries.append(entry)
        await session.flush()

        payload = await waiting_room_payload(session, entries[0])
        assert payload["can_start_early"] is False
        assert payload["people_waiting"] == 2
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_early_start_partial_confirmation_visible_to_others() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        now = datetime.now(timezone.utc)
        entries = []
        for user in users:
            entry = WaitingRoomEntry(
                user_id=user.id,
                skill_id="morning-focus",
                region_code="66",
            )
            session.add(entry)
            entries.append(entry)
        entries[0].pair_start_confirmed_at = now
        await session.flush()

        initiator = await waiting_room_payload(session, entries[0])
        assert initiator["early_start_confirmed"] is True
        assert initiator["early_start_confirmed_count"] == 1
        assert initiator["early_start_waiting_others"] is True
        assert initiator["early_start_pending"] is False

        observer = await waiting_room_payload(session, entries[1])
        assert observer["early_start_confirmed"] is False
        assert observer["early_start_confirmed_count"] == 1
        assert observer["early_start_waiting_others"] is False
        assert observer["early_start_pending"] is True
        assert observer["can_start_early"] is True
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_early_start_leave_queue_clears_confirmation_count() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        now = datetime.now(timezone.utc)
        entries = []
        for user in users:
            entry = WaitingRoomEntry(
                user_id=user.id,
                skill_id="morning-focus",
                region_code="66",
            )
            session.add(entry)
            entries.append(entry)
        entries[0].pair_start_confirmed_at = now
        await session.flush()

        await session.delete(entries[0])
        await session.flush()

        observer = await waiting_room_payload(session, entries[1])
        assert observer["early_start_confirmed_count"] == 0
        assert observer["early_start_pending"] is False
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_waiting_room_empty_payload_includes_pending_group_match() -> None:
    from app.models import Group, GroupMember
    from app.routers.group_service import _pending_match_group_for_user, waiting_room_payload

    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        group = Group(
            name="Morning Focus",
            skill_id="morning-focus",
            region_code="66",
            status="introduction",
            max_members=3,
        )
        session.add(group)
        await session.flush()
        for user in users:
            session.add(
                GroupMember(
                    group_id=group.id,
                    user_id=user.id,
                    role="member",
                )
            )
        await session.flush()

        pending = await _pending_match_group_for_user(session, users[1].id)
        assert pending is not None
        assert pending.id == group.id

        payload = await waiting_room_payload(
            session,
            None,
            matched_group_id=pending.id,
            current_user_id=users[1].id,
        )
        assert payload["in_queue"] is False
        assert payload["matched_group_id"] == group.id
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_early_start_creates_memberships_for_all_three_users() -> None:
    from app.routers.group_service import _create_group_from_early_start_entries

    engine, session = await make_session()
    try:
        users = [make_user(index, "66") for index in range(3)]
        session.add_all(users)
        await session.flush()
        now = datetime.now(timezone.utc)
        entries = []
        for index, user in enumerate(users):
            entry = WaitingRoomEntry(
                user_id=user.id,
                skill_id="morning-focus",
                region_code="66",
                pair_start_confirmed_at=now + timedelta(seconds=index),
            )
            session.add(entry)
            entries.append(entry)
        await session.flush()

        group = await _create_group_from_early_start_entries(session, entries)
        await session.commit()

        memberships = (
            await session.execute(select(GroupMember).order_by(GroupMember.created_at.asc()))
        ).scalars().all()
        member_user_ids = {item.user_id for item in memberships}
        assert len(memberships) == 3
        assert member_user_ids == {user.id for user in users}
        assert group.max_members == 3

        remaining_entries = (
            await session.execute(select(WaitingRoomEntry))
        ).scalars().all()
        assert remaining_entries == []
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
