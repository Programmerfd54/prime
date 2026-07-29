from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import pytest

from app.db import Base
from app.models import ChatMessage, Group, GroupMember, HabitReport, User
from app.routers.misc import calendar_all, create_report


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"report{index}@example.com",
        password_hash="hash",
        name=f"Report User {index}",
        nickname=f"report{index}",
        about=" ".join(["word"] * 50),
        region_code="77",
        city="Москва",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_ready_report_awards_one_prime_once_per_day() -> None:
    engine, session = await make_session()
    try:
        user = make_user(1)
        group = Group(
            name="Test group",
            skill_id="morning-focus",
            region_code="77",
            status="active",
        )
        session.add_all([user, group])
        await session.flush()
        membership = GroupMember(group_id=group.id, user_id=user.id)
        session.add(membership)
        await session.commit()

        first = await create_report(
            {"group_id": group.id, "status": "ready", "content_text": "Done"},
            user,
            session,
        )
        await session.refresh(user)
        await session.refresh(membership)

        assert first["reported"] is True
        assert first["completed"] is True
        assert first["prime_awarded"] is True
        assert user.prime_points == 1
        assert user.successful_days == 1
        assert membership.streak == 1
        assert membership.best_streak == 1

        second = await create_report(
            {"group_id": group.id, "status": "ready", "content_text": "Updated"},
            user,
            session,
        )
        await session.refresh(user)
        await session.refresh(membership)

        reports = (await session.execute(select(HabitReport))).scalars().all()
        chat_messages = (await session.execute(select(ChatMessage))).scalars().all()
        assert second["content_text"] == "Updated"
        assert len(reports) == 1
        # First submit: accepted + team-day complete system message; second: updated.
        assert any("Отчёт принят" in (m.body or "") for m in chat_messages)
        assert any("День закрыт" in (m.body or "") for m in chat_messages)
        assert any("Отчёт обновлён" in (m.body or "") for m in chat_messages)
        assert user.prime_points == 1
        assert user.successful_days == 1
        assert membership.streak == 1
        assert membership.best_streak == 1
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_ready_reports_in_multiple_groups_count_as_one_successful_day() -> None:
    engine, session = await make_session()
    try:
        user = make_user(4)
        focus = Group(
            name="Focus group",
            skill_id="morning-focus",
            region_code="77",
            status="active",
        )
        body = Group(
            name="Body group",
            skill_id="body-charge",
            region_code="77",
            status="active",
        )
        session.add_all([user, focus, body])
        await session.flush()
        focus_membership = GroupMember(group_id=focus.id, user_id=user.id)
        body_membership = GroupMember(group_id=body.id, user_id=user.id)
        session.add_all([focus_membership, body_membership])
        await session.commit()

        first = await create_report(
            {"group_id": focus.id, "status": "ready", "content_text": "Focus done"},
            user,
            session,
        )
        await session.refresh(user)
        await session.refresh(focus_membership)

        assert first["prime_awarded"] is True
        assert user.prime_points == 1
        assert user.successful_days == 1
        assert focus_membership.streak == 1

        second = await create_report(
            {"group_id": body.id, "status": "ready", "content_text": "Body done"},
            user,
            session,
        )
        await session.refresh(user)
        await session.refresh(body_membership)

        assert second["prime_awarded"] is True
        assert user.prime_points == 2
        assert user.successful_days == 1
        assert body_membership.streak == 1

        result = await calendar_all(user, session)
        assert len(result["days"]) == 1
        assert result["days"][0]["completed"] is True
        assert len(result["days"][0]["reports"]) == 2
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_not_ready_report_does_not_award_prime() -> None:
    engine, session = await make_session()
    try:
        user = make_user(2)
        group = Group(
            name="Test group",
            skill_id="digital-detox",
            region_code="77",
            status="active",
        )
        session.add_all([user, group])
        await session.flush()
        membership = GroupMember(group_id=group.id, user_id=user.id)
        session.add(membership)
        await session.commit()

        result = await create_report(
            {"group_id": group.id, "status": "not_ready", "content_text": ""},
            user,
            session,
        )
        await session.refresh(user)
        await session.refresh(membership)

        assert result["reported"] is False
        assert result["completed"] is False
        assert result["prime_awarded"] is False
        chat_messages = (await session.execute(select(ChatMessage))).scalars().all()
        assert chat_messages == []
        assert user.prime_points == 0
        assert user.successful_days == 0
        assert membership.streak == 0
        assert membership.best_streak == 0
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_global_calendar_counts_reports_across_all_skills_once_per_day() -> None:
    engine, session = await make_session()
    try:
        user = make_user(3)
        focus = Group(name="Focus", skill_id="morning-focus", region_code="77", status="active")
        body = Group(name="Body", skill_id="body-charge", region_code="77", status="active")
        session.add_all([user, focus, body])
        await session.flush()
        session.add_all(
            [
                GroupMember(group_id=focus.id, user_id=user.id),
                GroupMember(group_id=body.id, user_id=user.id),
            ]
        )
        await session.commit()

        # Solo teams: creating via create_report closes each team day.
        await create_report(
            {"group_id": focus.id, "status": "ready", "content_text": "Focus done"},
            user,
            session,
        )
        await create_report(
            {"group_id": body.id, "status": "ready", "content_text": "Body done"},
            user,
            session,
        )

        result = await calendar_all(user, session)

        assert result["tracking_start_date"] is not None
        assert len(result["days"]) == 1
        assert result["days"][0]["date"] == date.today().isoformat()
        assert result["days"][0]["completed"] is True
        assert result["days"][0]["reported"] is True
        assert len(result["days"][0]["reports"]) == 2
        assert {item["skill_id"] for item in result["days"][0]["reports"]} == {
            "morning-focus",
            "body-charge",
        }
    finally:
        await session.close()
        await engine.dispose()
