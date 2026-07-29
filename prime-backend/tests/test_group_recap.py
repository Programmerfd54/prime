from datetime import date, timedelta

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.group_progress import compute_team_milestones, compute_team_recap
from app.models import ChatMessage, ChatMessageReaction, Group, GroupCheckIn, GroupMember, HabitReport, User
from app.routers.misc import _group_payload


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"recap{index}@example.com",
        password_hash="hash",
        name=f"Recap User {index}",
        nickname=f"recap{index}",
        about=" ".join(["word"] * 50),
        region_code="77",
        city="Москва",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_team_recap_and_milestones_from_reports() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(i) for i in range(1, 4)]
        group = Group(
            name="Recap group",
            skill_id="morning-focus",
            region_code="77",
            status="active",
        )
        session.add_all([*users, group])
        await session.flush()
        member_ids = []
        for user in users:
            session.add(GroupMember(group_id=group.id, user_id=user.id))
            member_ids.append(user.id)
        today = date.today()
        yesterday = today - timedelta(days=1)
        session.add_all(
            [
                HabitReport(
                    group_id=group.id,
                    user_id=users[0].id,
                    report_date=today,
                    status="ready",
                    content_text="Today 1",
                    support_given=True,
                ),
                HabitReport(
                    group_id=group.id,
                    user_id=users[1].id,
                    report_date=today,
                    status="ready",
                    content_text="Today 2",
                ),
                HabitReport(
                    group_id=group.id,
                    user_id=users[2].id,
                    report_date=today,
                    status="ready",
                    content_text="Today 3",
                ),
                HabitReport(
                    group_id=group.id,
                    user_id=users[0].id,
                    report_date=yesterday,
                    status="ready",
                    content_text="Yesterday",
                ),
                GroupCheckIn(
                    group_id=group.id,
                    user_id=users[1].id,
                    kind="support",
                    check_in_date=today,
                ),
            ]
        )
        message = ChatMessage(
            group_id=group.id,
            sender_user_id=users[0].id,
            event_id="evt-recap-1",
            body="Поддержка",
        )
        session.add(message)
        await session.flush()
        session.add(
            ChatMessageReaction(
                message_id=message.id,
                user_id=users[2].id,
                emoji="👍",
            )
        )
        await session.commit()

        recap = await compute_team_recap(session, group.id, member_ids)
        assert recap["ready_reports"] == 4
        assert recap["best_day_count"] == 3
        assert recap["support_signals"] >= 2

        milestones = await compute_team_milestones(session, group.id, member_ids)
        by_id = {item["id"]: item for item in milestones["items"]}
        assert by_id["first_full_day"]["unlocked"] is True
        assert by_id["hundred_actions"]["current"] == 4
        assert by_id["week_together"]["current"] == 2

        payload = await _group_payload(session, group)
        assert payload["team_recap"]["ready_reports"] == 4
        assert len(payload["team_milestones"]["items"]) == 4
        assert payload["cycle_start_at"] == min(today, yesterday).isoformat()
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_recap_hidden_for_intro_groups() -> None:
    engine, session = await make_session()
    try:
        user = make_user(9)
        group = Group(
            name="Intro group",
            skill_id="morning-focus",
            region_code="77",
            status="introduction",
        )
        session.add_all([user, group])
        await session.flush()
        session.add(GroupMember(group_id=group.id, user_id=user.id))
        await session.commit()

        payload = await _group_payload(session, group)
        assert payload["team_recap"] is None
        assert payload["team_milestones"] is None
    finally:
        await session.close()
        await engine.dispose()
