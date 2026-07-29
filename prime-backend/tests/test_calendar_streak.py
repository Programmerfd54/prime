from datetime import date, timedelta

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import Group, GroupDay, GroupMember, HabitReport, User
from app.routers.misc import calendar_all, create_report
from app.team_day import backfill_group_days


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user() -> User:
    return User(
        email="streak@example.com",
        password_hash="hash",
        name="Streak User",
        nickname="streakuser",
        about=" ".join(["word"] * 50),
        region_code="77",
        city="Москва",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_calendar_all_uses_consecutive_streak() -> None:
    engine, session = await make_session()
    try:
        user = make_user()
        group = Group(
            name="Streak group",
            skill_id="morning-focus",
            region_code="77",
            status="active",
        )
        session.add_all([user, group])
        await session.flush()
        session.add(GroupMember(group_id=group.id, user_id=user.id))
        today = date.today()
        session.add_all(
            [
                HabitReport(
                    group_id=group.id,
                    user_id=user.id,
                    report_date=today,
                    status="ready",
                    content_text="Today",
                ),
                HabitReport(
                    group_id=group.id,
                    user_id=user.id,
                    report_date=today - timedelta(days=1),
                    status="ready",
                    content_text="Yesterday",
                ),
                HabitReport(
                    group_id=group.id,
                    user_id=user.id,
                    report_date=today - timedelta(days=2),
                    status="ready",
                    content_text="Two days ago",
                ),
                HabitReport(
                    group_id=group.id,
                    user_id=user.id,
                    report_date=today - timedelta(days=10),
                    status="ready",
                    content_text="Old gap",
                ),
            ]
        )
        await session.commit()
        # Grandfather historical reports as complete team days.
        await backfill_group_days(session)
        await session.commit()

        user.successful_days = 4
        user.prime_points = 4
        await session.commit()

        payload = await calendar_all(user, session)
        assert payload["successful_days"] == 4
        assert payload["current_streak"] == 3
        assert payload["best_streak"] == 3
        assert payload["cycle_pace_percent"] is not None
        assert isinstance(payload["insights"], list)
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_group_member_streak_resets_after_gap() -> None:
    engine, session = await make_session()
    try:
        user = make_user()
        group = Group(
            name="Member streak",
            skill_id="morning-focus",
            region_code="77",
            status="active",
        )
        session.add_all([user, group])
        await session.flush()
        membership = GroupMember(group_id=group.id, user_id=user.id)
        session.add(membership)
        await session.commit()

        await create_report(
            {"group_id": group.id, "status": "ready", "content_text": "Day 1"},
            user,
            session,
        )
        await session.refresh(membership)
        assert membership.streak == 1
        assert membership.best_streak == 1

        old_report = HabitReport(
            group_id=group.id,
            user_id=user.id,
            report_date=date.today() - timedelta(days=5),
            status="ready",
            content_text="Old",
        )
        session.add(old_report)
        session.add(
            GroupDay(
                group_id=group.id,
                day_date=date.today() - timedelta(days=5),
                status="complete",
                ready_count=1,
                member_count=1,
            )
        )
        await session.commit()

        await create_report(
            {"group_id": group.id, "status": "ready", "content_text": "Day 1 again"},
            user,
            session,
        )
        await session.refresh(membership)
        assert membership.streak == 1
        assert membership.best_streak == 1
    finally:
        await session.close()
        await engine.dispose()
