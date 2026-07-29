from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import Group, User, WaitingRoomEntry
from app.routers.group_service import waiting_room_payload, waiting_room_stats_payload


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int, region: str = "66", *, online: bool = True) -> User:
    now = datetime.now(timezone.utc)
    return User(
        email=f"stats-user{index}@example.com",
        password_hash="hash",
        name=f"Stats User {index}",
        nickname=f"stats{index}",
        about=" ".join(["слово"] * 50),
        region_code=region,
        city="Свердловская область" if region == "66" else "Москва",
        age=25,
        profile_completed=True,
        last_seen_at=now if online else now - timedelta(hours=1),
    )


@pytest.mark.asyncio
async def test_waiting_room_payload_includes_live_stats_fields() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, "66", online=index % 2 == 0) for index in range(1, 5)]
        session.add_all(users)
        await session.flush()
        now = datetime.now(timezone.utc)
        for user in users:
            session.add(
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="morning-focus",
                    region_code="66",
                    created_at=now - timedelta(minutes=user.nickname[-1:].isdigit() and int(user.nickname[-1]) or 1),
                )
            )
        await session.flush()

        self_entry = (
            await session.execute(
                select(WaitingRoomEntry).where(WaitingRoomEntry.user_id == users[0].id)
            )
        ).scalar_one()
        payload = await waiting_room_payload(
            session,
            self_entry,
            current_user_id=users[0].id,
        )

        assert payload["people_waiting"] == 4
        assert payload["region_searching"] == 4
        assert payload["skill_searching"] == 4
        assert payload["online_in_pool"] == 2
        assert len(payload["slots"]) == 4
        assert payload["slots"][0]["letter"] == "S"
        assert payload["slots"][0]["region_code"] == "66"
        assert isinstance(payload["slots"][0]["region_color_seed"], int)
        assert payload["slots"][0]["joined_ago_seconds"] >= 0
        assert all(event["type"] == "joined" for event in payload["events"])
        assert len(payload["events"]) == 3
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_waiting_room_stats_endpoint_shape() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index, region) for index, region in enumerate(["66", "66", "77"], start=1)]
        session.add_all(users)
        await session.flush()
        for user in users:
            session.add(
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="morning-focus",
                    region_code=user.region_code,
                )
            )
        await session.flush()

        for index in range(4):
            session.add(
                Group(
                    name=f"Team {index}",
                    skill_id="morning-focus",
                    region_code="66",
                    status="introduction",
                    created_at=datetime.now(timezone.utc) - timedelta(hours=6 * (4 - index)),
                )
            )
        await session.flush()

        payload = await waiting_room_stats_payload(
            session,
            skill_id="morning-focus",
            region_code="66",
        )

        assert payload["region_code"] == "66"
        assert payload["region_name"] == "Свердловская область"
        assert payload["skill_id"] == "morning-focus"
        assert payload["region_searching"] == 2
        assert payload["skill_searching"] == 3
        assert payload["online_in_pool"] == 2
        assert payload["top_regions"] == [
            {"code": "66", "name": "Свердловская область", "count": 2},
            {"code": "77", "name": "Москва", "count": 1},
        ]
        assert payload["median_match_hours"] == 6.0
    finally:
        await session.close()
        await engine.dispose()
