"""groups routes — split from misc.py."""
from datetime import date, datetime, timedelta, timezone
import asyncio
import mimetypes
from pathlib import Path as FsPath
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import case, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import get_current_user
from ..matrix import (
    create_room,
    download_media,
    ensure_matrix_user,
    mxc_to_http,
    send_room_message,
    upload_media,
)
from ..models import (
    ChatMessage,
    ChatMessageReaction,
    DirectConversationRead,
    DirectMessage,
    FriendRequest,
    Friendship,
    Group,
    GroupCheckIn,
    GroupMember,
    HabitReport,
    PrimeEvent,
    ReportAttachment,
    User,
    WaitingRoomEntry,
    utcnow,
)
from ..regions import REGIONS
from ..schemas import GroupCheckInRequest, HealthResponse, parse_privacy_settings
from ..skills_catalog import SKILLS, skill_name
from ..nicknames import normalize_nickname
from ..regions import is_valid_region, region_name
from . import group_service as svc
from .group_service import (
    ALLOWED_DIRECT_DOCUMENT_TYPES,
    ALLOWED_DOCUMENT_TYPES,
    ALLOWED_MEDIA_PREFIXES,
    ALLOWED_REACTION_EMOJIS,
    MAX_DIRECT_FILE_BYTES,
    MAX_DIRECT_IMAGE_BYTES,
    MAX_MEDIA_BYTES,
    MIN_GROUP_MEMBERS,
    PARTIAL_GROUP_START_DELAY,
    REGION_EXPANSION_DELAY,
    WAITING_ROOM_SIZE,
    _activate_if_ready,
    _are_friends,
    _chat_message_payload,
    _chat_payloads,
    _create_friend_request_for_addressee,
    _create_group,
    _create_group_chat_message,
    _current_group_for_user,
    _direct_chat_inbox_items,
    _direct_conversation_key,
    _direct_message_payload,
    _fill_group_vacancies,
    _friend_ids_for_user,
    _friend_request_payload,
    _friendship_pair,
    _group_for_user_skill,
    _group_intro_body,
    _group_payload,
    _mark_direct_chat_read,
    _maybe_match_waiting_room,
    _public_user_payload,
    _reaction_payloads,
    _report_payload,
    _require_active_group,
    _sync_user_daily_progress,
    _team_pulse,
    _user_membership,
    _user_payload,
    waiting_room_payload,
)

router = APIRouter(tags=["groups"])

@router.get("/groups")
async def groups(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    result = await session.execute(
        select(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .where(GroupMember.user_id == user.id, GroupMember.active.is_(True))
        .order_by(Group.created_at.desc())
    )
    return [await _group_payload(session, group) for group in result.scalars().all()]


@router.get("/groups/current")
async def current_group(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict | None:
    group = await _current_group_for_user(session, user.id)
    if group is None:
        return None
    return await _group_payload(session, group)


@router.get("/groups/{group_id}")
async def get_group(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    membership = await _user_membership(session, group_id, user.id)
    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    return await _group_payload(session, group)


@router.post("/groups/{group_id}/check-in")
async def group_check_in(
    group_id: str,
    payload: GroupCheckInRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    await _user_membership(session, group_id, user.id)
    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    existing = await session.scalar(
        select(GroupCheckIn).where(
            GroupCheckIn.group_id == group_id,
            GroupCheckIn.user_id == user.id,
            GroupCheckIn.check_in_date == date.today(),
        )
    )
    if existing is None:
        session.add(
            GroupCheckIn(
                group_id=group_id,
                user_id=user.id,
                kind=payload.kind,
                check_in_date=date.today(),
            )
        )
    else:
        existing.kind = payload.kind
        session.add(existing)
    await session.commit()
    return await _group_payload(session, group)


@router.post("/groups/{group_id}/nudge")
async def group_nudge(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Remind the team that reports are still missing for today."""
    await _user_membership(session, group_id, user.id)
    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    if group.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Напоминание доступно только в активном цикле",
        )

    from ..team_day import team_day_payload
    from ..models import ChatMessage

    team_day = await team_day_payload(session, group)
    if team_day["status"] == "complete":
        return {"ok": True, "already_complete": True, "team_day": team_day}

    # Rate-limit: one nudge per user per day.
    today_start = datetime.combine(date.today(), datetime.min.time()).replace(
        tzinfo=timezone.utc
    )
    already = await session.scalar(
        select(ChatMessage.id).where(
            ChatMessage.group_id == group_id,
            ChatMessage.sender_user_id == user.id,
            ChatMessage.msgtype == "prime.nudge",
            ChatMessage.created_at >= today_start,
        )
    )
    if already is not None:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Вы уже напомнили команде сегодня",
        )

    waiting = team_day.get("waiting_for") or []
    remaining = max(0, int(team_day.get("member_count") or 0) - int(team_day.get("ready_count") or 0))
    names = ", ".join(
        (w.get("name") or w.get("nickname") or "участник") for w in waiting[:3]
    )
    if remaining <= 0:
        body = "Все отчёты на месте — день почти закрыт."
    elif names:
        body = f"⏳ Осталось {remaining} отчёт{'а' if remaining in (2, 3, 4) else 'ов'} до закрытия дня: {names}"
    else:
        body = f"⏳ Осталось {remaining} отчётов до закрытия дня"

    await _create_group_chat_message(
        session,
        group,
        user,
        body=body,
        msgtype="prime.nudge",
    )
    await session.commit()
    return {"ok": True, "already_complete": False, "team_day": team_day}


@router.post("/groups/{group_id}/intro/continue")
async def intro_continue(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    membership = await _user_membership(session, group_id, user.id)
    membership.confirmed_participation = True
    session.add(membership)
    await _activate_if_ready(session, group)
    await session.commit()
    await session.refresh(group)
    return await _group_payload(session, group)


@router.post("/groups/{group_id}/confirm-participation")
async def confirm_participation_alias(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await intro_continue(group_id, user, session)


@router.post("/groups/{group_id}/intro/change")
async def intro_change(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    group = await session.get(Group, group_id)
    if group is None or group.status not in {"introduction", "rules_pending"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Группу уже нельзя сменить")
    membership = await _user_membership(session, group_id, user.id)
    membership.active = False
    session.add(membership)
    if not is_valid_region(user.region_code):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Выберите область в профиле")
    existing_entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == group.skill_id,
        )
    )
    if existing_entry is None:
        session.add(
            WaitingRoomEntry(
                user_id=user.id,
                skill_id=group.skill_id,
                region_code=user.region_code,
            )
        )
    await _fill_group_vacancies(session, group)
    await session.commit()
    return await waiting_room_payload(session, None)


@router.post("/groups/{group_id}/rules/accept")
async def rules_accept(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    membership = await _user_membership(session, group_id, user.id)
    membership.confirmed_participation = True
    membership.accepted_rules = True
    session.add(membership)
    await _activate_if_ready(session, group)
    await session.commit()
    await session.refresh(group)
    return await _group_payload(session, group)


@router.post("/groups/{group_id}/accept-rules")
async def accept_rules_alias(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await rules_accept(group_id, user, session)


@router.post("/groups/{group_id}/vote")
async def vote(group_id: str, payload: dict, user: User = Depends(get_current_user)) -> dict:
    return {"group_id": group_id, "choice": payload.get("choice"), "accepted": True}


@router.post("/dev/groups/assemble-test-team")
async def assemble_test_team(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if not get_settings().enable_dev_tools:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dev tools are disabled")

    skill_id = payload.get("skill_id")
    if not skill_id:
        entry = await session.scalar(
            select(WaitingRoomEntry)
            .where(WaitingRoomEntry.user_id == user.id)
            .order_by(WaitingRoomEntry.created_at.asc())
        )
        skill_id = entry.skill_id if entry else None
    if skill_id not in {item["id"] for item in SKILLS}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Сначала выберите навык")

    existing_group = await _group_for_user_skill(session, user.id, skill_id)
    if existing_group is not None:
        return await _group_payload(session, existing_group)

    testers = (
        await session.execute(
            select(User)
            .where(
                or_(
                    User.email.in_([f"prime.tester{i}@example.com" for i in range(1, 7)]),
                    User.name.in_([f"tester{i}" for i in range(1, 7)]),
                )
            )
            .order_by(User.email.asc())
        )
    ).scalars().all()
    selected_testers = [item for item in testers if item.id != user.id][:5]
    if len(selected_testers) < 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нужно минимум 5 tester-аккаунтов",
        )

    group = await _create_group(
        session,
        skill_id,
        [user, *selected_testers],
        region_code=user.region_code,
        is_cross_region=False,
    )
    await session.execute(
        delete(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id.in_([user.id, *[item.id for item in selected_testers]]),
            WaitingRoomEntry.skill_id == skill_id,
        )
    )
    await session.commit()
    await session.refresh(group)
    return await _group_payload(session, group)


