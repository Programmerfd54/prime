import json

import pytest
from fastapi import HTTPException
from sqlalchemy import event, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import (
    AuditEvent,
    ChatMessage,
    Group,
    GroupMember,
    GroupMembershipEvent,
    Notification,
    OutboxEvent,
    User,
    WaitingRoomEntry,
)
from app.routers.groups import intro_change, support_member, vote
from app.routers.group_service import _group_overview_payloads, _group_payload
from app.routers.waiting_room import waiting_room_early_start


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"product{index}@example.com",
        password_hash="hash",
        name=f"Product User {index}",
        nickname=f"product{index}",
        about=" ".join(["слово"] * 50),
        region_code="77",
        city="Москва",
        age=24 + index,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_early_start_notifies_queue_and_forms_group_after_three_confirms() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index) for index in range(1, 4)]
        session.add_all(users)
        await session.flush()
        session.add_all(
            [
                WaitingRoomEntry(
                    user_id=user.id,
                    skill_id="morning-focus",
                    region_code="77",
                )
                for user in users
            ]
        )
        await session.commit()

        first = await waiting_room_early_start(
            {"skill_id": "morning-focus"},
            user=users[0],
            session=session,
        )
        assert first["started"] is False
        assert first["early_start_confirmed_count"] == 1
        assert 0 < first["early_start_seconds_remaining"] <= 15 * 60

        notifications = (
            await session.execute(
                select(Notification).where(
                    Notification.type == "early_start_request",
                )
            )
        ).scalars().all()
        assert {item.user_id for item in notifications} == {
            users[1].id,
            users[2].id,
        }
        notification_data = json.loads(notifications[0].payload)
        assert notification_data["request_id"] == first["early_start_request_id"]
        assert notification_data["actions"] == [
            "confirm",
            "keep_waiting",
            "open_search",
        ]
        assert notification_data["deep_link"].startswith("prime://waiting-room")
        outbox_count = len(
            (
                await session.execute(
                    select(OutboxEvent).where(
                        OutboxEvent.topic == "push.notification",
                    )
                )
            ).scalars().all()
        )
        assert outbox_count == 2

        second = await waiting_room_early_start(
            {"skill_id": "morning-focus"},
            user=users[1],
            session=session,
        )
        assert second["early_start_confirmed_count"] == 2
        third = await waiting_room_early_start(
            {"skill_id": "morning-focus"},
            user=users[2],
            session=session,
        )
        assert third["started"] is True
        assert third["matched_group_id"]

        memberships = (
            await session.execute(
                select(GroupMember).where(
                    GroupMember.group_id == third["matched_group_id"],
                    GroupMember.active.is_(True),
                )
            )
        ).scalars().all()
        history = (
            await session.execute(
                select(GroupMembershipEvent).where(
                    GroupMembershipEvent.group_id == third["matched_group_id"],
                )
            )
        ).scalars().all()
        assert len(memberships) == 3
        assert len(history) == 3
        assert all(event.reason == "matched" for event in history)
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_change_group_is_atomic_and_returns_new_search_state() -> None:
    engine, session = await make_session()
    try:
        users = [make_user(index) for index in range(10, 13)]
        group = Group(
            name="Morning team",
            skill_id="morning-focus",
            region_code="77",
            status="introduction",
            max_members=3,
        )
        session.add_all([group, *users])
        await session.flush()
        session.add_all(
            [
                GroupMember(
                    group_id=group.id,
                    user_id=user.id,
                    role="creator" if index == 0 else "member",
                )
                for index, user in enumerate(users)
            ]
        )
        await session.commit()
        original_revision = group.revision

        response = await intro_change(
            group.id,
            user=users[0],
            session=session,
        )
        assert response["in_queue"] is True
        assert response["skill_id"] == group.skill_id
        assert response["matched_group_id"] is None

        membership = await session.scalar(
            select(GroupMember).where(
                GroupMember.group_id == group.id,
                GroupMember.user_id == users[0].id,
            )
        )
        await session.refresh(group)
        event = await session.scalar(
            select(GroupMembershipEvent).where(
                GroupMembershipEvent.group_id == group.id,
                GroupMembershipEvent.user_id == users[0].id,
            )
        )
        queue_entry = await session.scalar(
            select(WaitingRoomEntry).where(
                WaitingRoomEntry.user_id == users[0].id,
                WaitingRoomEntry.skill_id == group.skill_id,
            )
        )
        remaining_notifications = (
            await session.execute(
                select(Notification).where(
                    Notification.type == "membership_changed",
                )
            )
        ).scalars().all()

        assert membership is not None and membership.active is False
        assert event is not None
        assert event.reason == "manual_change"
        assert event.from_active is True
        assert event.to_active is False
        assert queue_entry is not None
        assert group.revision > original_revision
        assert {item.user_id for item in remaining_notifications} == {
            users[1].id,
            users[2].id,
        }
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_one_tap_support_notifies_target_and_has_cooldown() -> None:
    engine, session = await make_session()
    try:
        sender, target = make_user(20), make_user(21)
        group = Group(
            name="Support team",
            skill_id="morning-focus",
            region_code="77",
            status="active",
            max_members=2,
        )
        session.add_all([group, sender, target])
        await session.flush()
        session.add_all(
            [
                GroupMember(group_id=group.id, user_id=sender.id, role="creator"),
                GroupMember(group_id=group.id, user_id=target.id),
            ]
        )
        await session.commit()
        original_revision = group.revision

        response = await support_member(
            group.id,
            {"target_user_id": target.id},
            user=sender,
            session=session,
        )
        await session.refresh(group)
        message = await session.scalar(
            select(ChatMessage).where(ChatMessage.msgtype == "prime.support")
        )
        notification = await session.scalar(
            select(Notification).where(
                Notification.user_id == target.id,
                Notification.type == "support_received",
            )
        )

        assert response["personal_result"]["support_given"] == 1
        assert message is not None
        assert message.filename == target.id
        assert f"@{target.nickname}" in message.body
        assert notification is not None
        assert group.revision > original_revision

        with pytest.raises(HTTPException) as duplicate:
            await support_member(
                group.id,
                {"target_user_id": target.id},
                user=sender,
                session=session,
            )
        assert duplicate.value.status_code == 429
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_group_overview_query_count_is_constant_across_multiple_groups() -> None:
    engine, session = await make_session()
    statements: list[str] = []

    def count_statement(*args) -> None:
        statements.append(str(args[2]))

    event.listen(engine.sync_engine, "before_cursor_execute", count_statement)
    try:
        current = make_user(30)
        teammates = [make_user(index) for index in range(31, 34)]
        groups = [
            Group(
                name=f"Team {index}",
                skill_id=f"skill-{index}",
                region_code="77",
                status="introduction",
                max_members=2,
            )
            for index in range(3)
        ]
        session.add_all([current, *teammates, *groups])
        await session.flush()
        for index, group in enumerate(groups):
            session.add_all(
                [
                    GroupMember(
                        group_id=group.id,
                        user_id=current.id,
                        role="creator",
                    ),
                    GroupMember(
                        group_id=group.id,
                        user_id=teammates[index].id,
                    ),
                ]
            )
        await session.commit()

        statements.clear()
        optimized = await _group_overview_payloads(
            session,
            groups,
            current_user_id=current.id,
        )
        optimized_queries = len(statements)

        statements.clear()
        legacy = [
            await _group_payload(
                session,
                group,
                current_user_id=current.id,
            )
            for group in groups
        ]
        legacy_queries = len(statements)

        assert len(optimized) == len(legacy) == 3
        assert optimized_queries == 5
        assert legacy_queries >= optimized_queries * 3
    finally:
        event.remove(engine.sync_engine, "before_cursor_execute", count_statement)
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_cycle_continuation_choice_is_validated_and_audited() -> None:
    engine, session = await make_session()
    try:
        user = make_user(40)
        group = Group(
            name="Completed team",
            skill_id="morning-focus",
            region_code="77",
            status="completed",
            max_members=1,
        )
        session.add_all([user, group])
        await session.flush()
        session.add(
            GroupMember(
                group_id=group.id,
                user_id=user.id,
                role="creator",
            )
        )
        await session.commit()

        response = await vote(
            group.id,
            {"choice": "recovery"},
            user=user,
            session=session,
        )
        audit = await session.scalar(
            select(AuditEvent).where(
                AuditEvent.user_id == user.id,
                AuditEvent.action == "group.continuation_choice",
            )
        )
        message = await session.scalar(
            select(ChatMessage).where(
                ChatMessage.group_id == group.id,
                ChatMessage.msgtype == "prime.system",
            )
        )

        assert response["continuation_choice"] == "recovery"
        assert audit is not None
        assert json.loads(audit.metadata_json) == {
            "group_id": group.id,
            "choice": "recovery",
        }
        assert message is not None
        assert "неделю восстановления" in message.body

        group.status = "active"
        await session.commit()
        with pytest.raises(HTTPException) as invalid_phase:
            await vote(
                group.id,
                {"choice": "harder"},
                user=user,
                session=session,
            )
        assert invalid_phase.value.status_code == 409
    finally:
        await session.close()
        await engine.dispose()
