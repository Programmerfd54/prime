from datetime import date, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.metrics_engine import best_consecutive_streak, current_consecutive_streak
from app.models import ChatMessage, Group, GroupDay, GroupMember, HabitReport, PrimeEvent, User
from app.routers.misc import create_report
from app.team_day import (
    TEAM_DAY_PRIME_REASON,
    award_team_day_primes,
    backfill_group_days,
    finalize_stale_group_days,
    recompute_group_day,
    team_completed_dates,
    team_pending_dates,
)


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"teamday{index}@example.com",
        password_hash="hash",
        name=f"Team Day {index}",
        nickname=f"teamday{index}",
        about=" ".join(["word"] * 50),
        region_code="77",
        city="Москва",
        age=25,
        profile_completed=True,
    )


async def make_team(session, *, size: int = 3, skill_id: str = "morning-focus"):
    users = [make_user(i) for i in range(size)]
    group = Group(
        name="Team day group",
        skill_id=skill_id,
        region_code="77",
        status="active",
        max_members=size,
    )
    session.add_all([*users, group])
    await session.flush()
    for user in users:
        session.add(GroupMember(group_id=group.id, user_id=user.id, active=True))
    await session.commit()
    return group, users


@pytest.mark.asyncio
async def test_partial_team_day_does_not_award_primes() -> None:
    engine, session = await make_session()
    try:
        group, users = await make_team(session, size=3)
        result = await create_report(
            {"group_id": group.id, "status": "ready", "content_text": "Alone"},
            users[0],
            session,
        )
        await session.refresh(users[0])

        assert result["reported"] is True
        assert result["completed"] is False
        assert result["prime_awarded"] is False
        assert result["team_day"]["status"] == "pending"
        assert result["team_day"]["ready_count"] == 1
        assert result["team_day"]["member_count"] == 3
        assert users[0].prime_points == 0
        assert users[0].successful_days == 0

        day = await session.scalar(
            select(GroupDay).where(
                GroupDay.group_id == group.id,
                GroupDay.day_date == date.today(),
            )
        )
        assert day is not None
        assert day.status == "pending"
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_full_team_day_awards_prime_to_everyone() -> None:
    engine, session = await make_session()
    try:
        group, users = await make_team(session, size=3)

        for i, user in enumerate(users):
            result = await create_report(
                {
                    "group_id": group.id,
                    "status": "ready",
                    "content_text": f"Done {i}",
                },
                user,
                session,
            )
            if i < 2:
                assert result["prime_awarded"] is False
                assert result["team_day"]["status"] == "pending"
            else:
                assert result["prime_awarded"] is True
                assert result["completed"] is True
                assert result["team_day"]["status"] == "complete"

        for user in users:
            await session.refresh(user)
            assert user.prime_points == 1
            assert user.successful_days == 1

        events = (
            await session.execute(
                select(PrimeEvent).where(
                    PrimeEvent.reason.like(f"{TEAM_DAY_PRIME_REASON}%")
                )
            )
        ).scalars().all()
        assert len(events) == 3

        system = (
            await session.execute(
                select(ChatMessage).where(ChatMessage.msgtype == "prime.system")
            )
        ).scalars().all()
        assert len(system) == 1
        assert "День закрыт" in system[0].body
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_neutral_day_does_not_break_streak() -> None:
    """User reported yesterday (pending/missed) should not reset streak."""
    completed = {date.today() - timedelta(days=2), date.today() - timedelta(days=3)}
    neutral = {date.today() - timedelta(days=1)}  # reported but team missed
    # Without neutral: streak would be 0 (gap yesterday)
    assert current_consecutive_streak(completed)[0] == 0
    # With neutral: streak bridges over yesterday
    streak, _ = current_consecutive_streak(completed, neutral=neutral)
    assert streak == 2

    best = best_consecutive_streak(
        {date.today() - timedelta(days=i) for i in (0, 2, 3)},
        neutral={date.today() - timedelta(days=1)},
    )
    assert best == 3


@pytest.mark.asyncio
async def test_finalize_stale_marks_pending_as_missed() -> None:
    engine, session = await make_session()
    try:
        group, users = await make_team(session, size=2)
        yesterday = date.today() - timedelta(days=1)
        session.add(
            GroupDay(
                group_id=group.id,
                day_date=yesterday,
                status="pending",
                ready_count=1,
                member_count=2,
            )
        )
        await session.commit()

        changed = await finalize_stale_group_days(session, group)
        await session.commit()
        assert changed == 1

        day = await session.scalar(
            select(GroupDay).where(
                GroupDay.group_id == group.id,
                GroupDay.day_date == yesterday,
            )
        )
        assert day is not None
        assert day.status == "missed"
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_backfill_grandfathers_historical_ready_reports() -> None:
    engine, session = await make_session()
    try:
        group, users = await make_team(session, size=2)
        past = date.today() - timedelta(days=5)
        session.add(
            HabitReport(
                group_id=group.id,
                user_id=users[0].id,
                report_date=past,
                status="ready",
                content_text="legacy",
            )
        )
        await session.commit()

        inserted = await backfill_group_days(session)
        await session.commit()
        assert inserted == 1

        day = await session.scalar(
            select(GroupDay).where(
                GroupDay.group_id == group.id,
                GroupDay.day_date == past,
            )
        )
        assert day is not None
        assert day.status == "complete"

        # Second run is idempotent
        assert await backfill_group_days(session) == 0
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_team_completed_and_pending_dates() -> None:
    engine, session = await make_session()
    try:
        group, users = await make_team(session, size=2)
        today = date.today()
        session.add(
            HabitReport(
                group_id=group.id,
                user_id=users[0].id,
                report_date=today,
                status="ready",
                content_text="partial",
            )
        )
        await session.commit()
        await recompute_group_day(session, group, today)
        await session.commit()

        pending = await team_pending_dates(session, users[0].id, group_id=group.id)
        completed = await team_completed_dates(session, users[0].id, group_id=group.id)
        assert today in pending
        assert today not in completed

        await create_report(
            {"group_id": group.id, "status": "ready", "content_text": "last"},
            users[1],
            session,
        )
        pending = await team_pending_dates(session, users[0].id, group_id=group.id)
        completed = await team_completed_dates(session, users[0].id, group_id=group.id)
        assert today not in pending
        assert today in completed
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_award_team_day_primes_is_idempotent() -> None:
    engine, session = await make_session()
    try:
        group, users = await make_team(session, size=2)
        today = date.today()
        for user in users:
            session.add(
                HabitReport(
                    group_id=group.id,
                    user_id=user.id,
                    report_date=today,
                    status="ready",
                    content_text="x",
                )
            )
        await session.commit()
        await recompute_group_day(session, group, today)

        first = await award_team_day_primes(session, group, today)
        second = await award_team_day_primes(session, group, today)
        await session.commit()
        assert set(first) == {users[0].id, users[1].id}
        assert second == []
    finally:
        await session.close()
        await engine.dispose()
