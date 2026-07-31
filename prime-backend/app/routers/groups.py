"""groups routes — split from misc.py."""
from datetime import date, datetime, timedelta, timezone
import asyncio
import json
import mimetypes
from pathlib import Path as FsPath
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import case, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import get_current_auth_session, get_current_user, require_dev_tools_user
from ..matrix import (
    create_room,
    download_media,
    ensure_matrix_user,
    mxc_to_http,
    send_room_message,
    upload_media,
)
from ..notifications import create_notification, notify_group_members as push_group_members
from ..models import (
    AuditEvent,
    ChatMessage,
    ChatMessageReaction,
    DirectConversationRead,
    DirectMessage,
    FriendRequest,
    Friendship,
    Group,
    GroupCheckIn,
    GroupMember,
    GroupMembershipEvent,
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
    _group_overview_payloads,
    _group_payload,
    _bump_group_revision,
    _record_membership_event,
    _mark_direct_chat_read,
    _maybe_match_waiting_room,
    _notify_group_members,
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
    limit: int = Query(default=20, ge=1, le=50),
) -> list[dict]:
    result = await session.execute(
        select(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .where(GroupMember.user_id == user.id, GroupMember.active.is_(True))
        .order_by(Group.created_at.desc())
        .limit(limit)
    )
    return await _group_overview_payloads(
        session,
        result.scalars().all(),
        current_user_id=user.id,
    )


@router.get("/groups/current")
async def current_group(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict | None:
    group = await _current_group_for_user(session, user.id)
    if group is None:
        return None
    return await _group_payload(session, group, current_user_id=user.id)


@router.get("/groups/overview")
async def groups_overview(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Single product read model for Groups/Home without client-side N+1 calls."""
    group_rows = (
        await session.execute(
            select(Group)
            .join(GroupMember, GroupMember.group_id == Group.id)
            .where(GroupMember.user_id == user.id, GroupMember.active.is_(True))
            .order_by(Group.created_at.desc())
        )
    ).scalars().all()
    group_payloads = await _group_overview_payloads(
        session,
        group_rows,
        current_user_id=user.id,
    )
    entries = (
        await session.execute(
            select(WaitingRoomEntry)
            .where(WaitingRoomEntry.user_id == user.id)
            .order_by(WaitingRoomEntry.created_at.asc())
        )
    ).scalars().all()
    queues = [
        await waiting_room_payload(session, entry, current_user_id=user.id)
        for entry in entries
    ]
    if queues:
        waiting = dict(queues[0])
        waiting["queues"] = queues
    else:
        waiting = await waiting_room_payload(
            session,
            None,
            matched_group_id=None,
            current_user_id=user.id,
        )
        waiting["queues"] = []

    dangling_memberships = int(
        await session.scalar(
            select(func.count())
            .select_from(GroupMember)
            .outerjoin(Group, Group.id == GroupMember.group_id)
            .where(
                GroupMember.user_id == user.id,
                GroupMember.active.is_(True),
                Group.id.is_(None),
            )
        )
        or 0
    )
    await session.commit()
    return {
        "groups": group_payloads,
        "active": [item for item in group_payloads if item["status"] == "active"],
        "preparing": [
            item
            for item in group_payloads
            if item["status"] in {"introduction", "rules_pending"}
        ],
        "waiting_room": waiting,
        "membership_consistent": dangling_memberships == 0,
        "revision": max(
            [item["revision"] for item in group_payloads]
            + [item.get("revision", 0) for item in queues]
            + [0]
        ),
    }


@router.get("/groups/membership-history")
async def membership_history(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    limit: int = Query(default=100, ge=1, le=200),
) -> dict:
    rows = (
        await session.execute(
            select(GroupMembershipEvent)
            .where(GroupMembershipEvent.user_id == user.id)
            .order_by(GroupMembershipEvent.created_at.desc())
            .limit(limit)
        )
    ).scalars().all()
    return {
        "items": [
            {
                "id": item.id,
                "group_id": item.group_id,
                "event_type": item.event_type,
                "reason": item.reason,
                "from_active": item.from_active,
                "to_active": item.to_active,
                "created_at": item.created_at.isoformat(),
            }
            for item in rows
        ]
    }


@router.post("/groups/membership/reconcile")
async def reconcile_membership(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    from .group_service import _record_membership_event

    dangling = (
        await session.execute(
            select(GroupMember)
            .outerjoin(Group, Group.id == GroupMember.group_id)
            .where(
                GroupMember.user_id == user.id,
                GroupMember.active.is_(True),
                Group.id.is_(None),
            )
        )
    ).scalars().all()
    fixed = 0
    for membership in dangling:
        membership.active = False
        session.add(membership)
        _record_membership_event(
            session,
            group_id=membership.group_id,
            user_id=user.id,
            event_type="left",
            reason="orphan_reconcile",
            actor_user_id=user.id,
            from_active=True,
            to_active=False,
        )
        fixed += 1
    await session.commit()
    remaining = int(
        await session.scalar(
            select(func.count())
            .select_from(GroupMember)
            .outerjoin(Group, Group.id == GroupMember.group_id)
            .where(
                GroupMember.user_id == user.id,
                GroupMember.active.is_(True),
                Group.id.is_(None),
            )
        )
        or 0
    )
    return {"fixed": fixed, "membership_consistent": remaining == 0}


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
    return await _group_payload(session, group, current_user_id=user.id)


@router.post("/groups/{group_id}/check-in")
async def group_check_in(
    group_id: str,
    payload: GroupCheckInRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    await _user_membership(session, group_id, user.id)
    from ..timezone_utils import group_today, team_day_window

    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    today = group_today(group)
    existing = await session.scalar(
        select(GroupCheckIn).where(
            GroupCheckIn.group_id == group_id,
            GroupCheckIn.user_id == user.id,
            GroupCheckIn.check_in_date == today,
        )
    )
    previous_kind = existing.kind if existing is not None else None
    if existing is None:
        session.add(
            GroupCheckIn(
                group_id=group_id,
                user_id=user.id,
                kind=payload.kind,
                check_in_date=today,
            )
        )
    else:
        existing.kind = payload.kind
        existing.created_at = utcnow()
        session.add(existing)
    if payload.kind in {"support", "hard"} and previous_kind != payload.kind:
        label = "нужна поддержка" if payload.kind == "support" else "сегодня сложно"
        await _create_group_chat_message(
            session,
            group,
            user,
            body=f"💜 @{user.nickname}: {label}. Команда рядом.",
            msgtype="prime.support_request",
        )
        member_ids = (
            await session.execute(
                select(GroupMember.user_id).where(
                    GroupMember.group_id == group.id,
                    GroupMember.active.is_(True),
                    GroupMember.user_id != user.id,
                )
            )
        ).scalars().all()
        for member_id in member_ids:
            await create_notification(
                session,
                member_id,
                "support_needed",
                f"@{user.nickname} просит поддержки",
                "Отправьте короткое сообщение — иногда этого достаточно, чтобы продолжить",
                {
                    "group_id": group.id,
                    "target_user_id": user.id,
                    "deep_link": f"prime://groups/{group.id}",
                },
            )
    _bump_group_revision(group)
    session.add(group)
    await session.commit()
    await _notify_group_members(
        session,
        group_id=group.id,
        reason="check_in_updated",
    )
    return await _group_payload(session, group, current_user_id=user.id)


@router.post("/groups/{group_id}/support")
async def support_member(
    group_id: str,
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    await _user_membership(session, group_id, user.id)
    group = await session.get(Group, group_id)
    if group is None or group.status != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Поддержка доступна в активном цикле")
    target_user_id = str(payload.get("target_user_id") or "")
    if not target_user_id or target_user_id == user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Выберите участника команды")
    await _user_membership(session, group_id, target_user_id)
    target = await session.get(User, target_user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Участник не найден")

    cooldown_start = utcnow() - timedelta(minutes=10)
    duplicate = await session.scalar(
        select(ChatMessage.id).where(
            ChatMessage.group_id == group_id,
            ChatMessage.sender_user_id == user.id,
            ChatMessage.msgtype == "prime.support",
            ChatMessage.filename == target_user_id,
            ChatMessage.created_at >= cooldown_start,
        )
    )
    if duplicate is not None:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Поддержка уже отправлена — дайте участнику немного времени",
        )
    raw_message = str(payload.get("message") or "").strip()
    message = raw_message[:280] or f"@{target.nickname}, ты не один. Команда рядом 💜"
    await _create_group_chat_message(
        session,
        group,
        user,
        body=message,
        msgtype="prime.support",
        filename=target_user_id,
    )
    await create_notification(
        session,
        target_user_id,
        "support_received",
        f"@{user.nickname} поддержал вас",
        message,
        {
            "group_id": group.id,
            "sender_user_id": user.id,
            "deep_link": f"prime://groups/{group.id}",
        },
    )
    _bump_group_revision(group)
    session.add(group)
    await session.commit()
    await _notify_group_members(session, group_id=group.id, reason="support_sent")
    return await _group_payload(session, group, current_user_id=user.id)


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
    from ..timezone_utils import effective_group_timezone, group_today, team_day_window
    from ..models import ChatMessage

    team_day = await team_day_payload(session, group)
    if team_day["status"] == "complete":
        return {"ok": True, "already_complete": True, "team_day": team_day}

    # Rate-limit: one nudge per user per team day.
    today = group_today(group)
    window = team_day_window(effective_group_timezone(group), today)
    today_start = window["day_start"]
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
    for waiting_member in waiting:
        target_id = str(waiting_member.get("user_id") or "")
        if not target_id or target_id == user.id:
            continue
        await create_notification(
            session,
            target_id,
            "team_nudge",
            "Команда ждёт ваш отчёт",
            f"@{user.nickname} мягко напомнил: день закрывается вместе",
            {
                "group_id": group.id,
                "deep_link": f"prime://groups/{group.id}",
            },
        )
    _bump_group_revision(group)
    session.add(group)
    await session.commit()
    await _notify_group_members(session, group_id=group.id, reason="team_nudge")
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
    newly_confirmed = not membership.confirmed_participation
    membership.confirmed_participation = True
    session.add(membership)
    if newly_confirmed:
        _bump_group_revision(group)
        session.add(group)
        await _create_group_chat_message(
            session,
            group,
            user,
            body=f"✅ @{user.nickname} подтвердил участие",
            msgtype="prime.system",
        )
    await _activate_if_ready(session, group)
    await session.commit()
    await session.refresh(group)
    if newly_confirmed:
        await push_group_members(
            session,
            group_id=group.id,
            type="team_activity",
            title=skill_name(group.skill_id) or group.name,
            body=f"@{user.nickname} подтвердил участие",
            exclude_user_id=user.id,
        )
    await _notify_group_members(
        session,
        group_id=group.id,
        reason="participation_confirmed",
    )
    return await _group_payload(session, group, current_user_id=user.id)


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
    if not is_valid_region(user.region_code):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Выберите область в профиле")
    membership = await _user_membership(session, group_id, user.id)
    membership.active = False
    session.add(membership)
    _record_membership_event(
        session,
        group_id=group.id,
        user_id=user.id,
        actor_user_id=user.id,
        event_type="left",
        reason="manual_change",
        from_active=True,
        to_active=False,
    )
    await _create_group_chat_message(
        session,
        group,
        user,
        body=f"↪️ @{user.nickname} сменил команду. Ищем замену.",
        msgtype="prime.system",
    )
    _bump_group_revision(group)
    session.add(group)
    existing_entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == group.skill_id,
        )
    )
    if existing_entry is None:
        existing_entry = WaitingRoomEntry(
            user_id=user.id,
            skill_id=group.skill_id,
            region_code=user.region_code,
        )
        session.add(existing_entry)
    else:
        existing_entry.region_code = user.region_code
        existing_entry.revision = int(existing_entry.revision or 0) + 1
        session.add(existing_entry)
    remaining_member_ids = (
        await session.execute(
            select(GroupMember.user_id).where(
                GroupMember.group_id == group.id,
                GroupMember.active.is_(True),
            )
        )
    ).scalars().all()
    for member_id in remaining_member_ids:
        await create_notification(
            session,
            member_id,
            "membership_changed",
            f"@{user.nickname} сменил команду",
            "Мы уже ищем нового участника — ваша команда сохранена",
            {"group_id": group.id, "deep_link": f"prime://groups/{group.id}"},
        )
    await _fill_group_vacancies(session, group)
    await session.flush()
    await session.commit()
    await session.refresh(existing_entry)
    await _notify_group_members(
        session,
        group_id=group.id,
        include_user_ids=[user.id],
        reason="membership_changed",
    )
    from ..direct_message_events import WaitingRoomUpdatePush, direct_message_hub
    direct_message_hub.publish_waiting_room_update(
        user.id,
        WaitingRoomUpdatePush(
            skill_id=group.skill_id,
            revision=int(existing_entry.revision or 0),
            reason="group_changed",
        ),
    )
    return await waiting_room_payload(
        session,
        existing_entry,
        current_user_id=user.id,
    )


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
    newly_accepted = not membership.accepted_rules
    membership.confirmed_participation = True
    membership.accepted_rules = True
    session.add(membership)
    if newly_accepted:
        _bump_group_revision(group)
        session.add(group)
        await _create_group_chat_message(
            session,
            group,
            user,
            body=f"🛡️ @{user.nickname} принял командный договор",
            msgtype="prime.system",
        )
    await _activate_if_ready(session, group)
    await session.commit()
    await session.refresh(group)
    if newly_accepted and group.status != "active":
        await push_group_members(
            session,
            group_id=group.id,
            type="team_activity",
            title=skill_name(group.skill_id) or group.name,
            body=f"@{user.nickname} принял командный договор",
            exclude_user_id=user.id,
        )
    if group.status == "active":
        await _notify_group_members(session, group_id=group.id, reason="cycle_started")
    else:
        await _notify_group_members(session, group_id=group.id, reason="rules_accepted")
    return await _group_payload(session, group, current_user_id=user.id)


@router.post("/groups/{group_id}/accept-rules")
async def accept_rules_alias(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await rules_accept(group_id, user, session)


@router.post("/groups/{group_id}/vote")
async def vote(
    group_id: str,
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Группа не найдена",
        )
    await _user_membership(session, group_id, user.id)
    if group.status not in {"completed", "voting"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Следующий шаг выбирается после завершения цикла",
        )
    aliases = {
        "yes": "continue_together",
        "accept": "continue_together",
        "no": "new_skill",
        "reject": "new_skill",
    }
    raw_choice = str(payload.get("choice") or "").strip().lower()
    choice = aliases.get(raw_choice, raw_choice)
    labels = {
        "continue_together": "продолжить этой командой",
        "new_skill": "выбрать новую привычку",
        "harder": "усложнить следующий цикл",
        "recovery": "взять неделю восстановления",
    }
    if choice not in labels:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Некорректный вариант голосования")
    from ..models import GroupContinuationVote

    existing_vote = await session.scalar(
        select(GroupContinuationVote).where(
            GroupContinuationVote.group_id == group.id,
            GroupContinuationVote.user_id == user.id,
        )
    )
    if existing_vote is None:
        session.add(
            GroupContinuationVote(
                group_id=group.id,
                user_id=user.id,
                choice=choice,
            )
        )
    else:
        existing_vote.choice = choice
        session.add(existing_vote)
    session.add(
        AuditEvent(
            user_id=user.id,
            action="group.continuation_choice",
            metadata_json=json.dumps(
                {"group_id": group.id, "choice": choice},
                ensure_ascii=False,
            ),
        )
    )
    await _create_group_chat_message(
        session,
        group,
        user,
        body=f"🧭 @{user.nickname} выбрал: {labels[choice]}",
        msgtype="prime.system",
    )
    _bump_group_revision(group)
    session.add(group)
    await session.commit()
    await session.refresh(group)
    votes = (
        await session.execute(
            select(GroupContinuationVote).where(
                GroupContinuationVote.group_id == group.id
            )
        )
    ).scalars().all()
    tally: dict[str, int] = {}
    for item in votes:
        tally[item.choice] = tally.get(item.choice, 0) + 1
    active_member_count = int(
        await session.scalar(
            select(func.count())
            .select_from(GroupMember)
            .where(
                GroupMember.group_id == group.id,
                GroupMember.active.is_(True),
            )
        )
        or 0
    )
    if active_member_count > 0 and len(votes) >= active_member_count:
        winner = max(tally.items(), key=lambda pair: pair[1])[0]
        if winner == "continue_together" and group.status == "voting":
            group.status = "active"
            _bump_group_revision(group)
            session.add(group)
            await session.commit()
            await session.refresh(group)
        elif winner == "new_skill" and group.status == "voting":
            group.status = "rotating"
            _bump_group_revision(group)
            session.add(group)
            await session.commit()
            await session.refresh(group)
    await _notify_group_members(
        session,
        group_id=group.id,
        reason="continuation_choice",
    )
    result = await _group_payload(session, group, current_user_id=user.id)
    result["continuation_choice"] = choice
    result["vote_tally"] = tally
    result["my_continuation_choice"] = choice
    return result


@router.post("/dev/groups/assemble-test-team")
async def assemble_test_team(
    payload: dict,
    user: User = Depends(require_dev_tools_user),
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
        return await _group_payload(session, existing_group, current_user_id=user.id)

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
    return await _group_payload(session, group, current_user_id=user.id)
