"""waiting-room routes — split from misc.py."""
from datetime import date, datetime, timedelta, timezone
import asyncio
import mimetypes
import secrets
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
    EarlyStartConfirmation,
    EarlyStartRequest,
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
from ..notifications import create_notification
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
    EARLY_START_REQUEST_TTL,
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
    _create_group_from_early_start_entries,
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
    _maybe_auto_expand_waiting_room_entry,
    _notify_waiting_room_pair_join,
    _notify_waiting_room_skill_pool,
    _notify_waiting_room_users,
    _pending_match_group_for_user,
    _public_user_payload,
    _reaction_payloads,
    _report_payload,
    _require_active_group,
    _sync_user_daily_progress,
    _team_pulse,
    _user_membership,
    _user_payload,
    waiting_room_payload,
    waiting_room_stats_payload,
)

router = APIRouter(tags=["waiting-room"])

@router.post("/groups/waiting-room")
async def join_waiting_room(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    skill_id = str(payload.get("skill_id") or "")
    if skill_id not in {item["id"] for item in SKILLS}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Выберите навык")
    if not is_valid_region(user.region_code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Сначала выберите область в профиле",
        )
    if len((user.about or "").split()) < 50:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Дополните рассказ о себе минимум до 50 слов — его увидят участники группы",
        )

    existing_group = await _group_for_user_skill(session, user.id, skill_id)
    if existing_group is not None:
        return await waiting_room_payload(
            session,
            None,
            matched_group_id=existing_group.id,
            current_user_id=user.id,
        )

    entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == skill_id,
        )
    )
    if entry is None:
        entry = WaitingRoomEntry(
            user_id=user.id,
            skill_id=skill_id,
            region_code=user.region_code,
        )
    else:
        entry.region_code = user.region_code
    session.add(entry)
    await session.flush()

    group = await _maybe_match_waiting_room(session, skill_id, user.region_code)
    await session.commit()
    if group is not None:
        return await waiting_room_payload(
            session,
            None,
            matched_group_id=group.id,
            current_user_id=user.id,
        )

    await session.refresh(entry)
    return await waiting_room_payload(session, entry, current_user_id=user.id)


@router.get("/groups/waiting-room")
async def waiting_room(
    skill_id: str | None = None,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if skill_id:
        group = await _group_for_user_skill(session, user.id, skill_id)
        if group is not None:
            return await waiting_room_payload(
                session,
                None,
                matched_group_id=group.id,
                current_user_id=user.id,
            )
        entry = await session.scalar(
            select(WaitingRoomEntry).where(
                WaitingRoomEntry.user_id == user.id,
                WaitingRoomEntry.skill_id == skill_id,
            )
        )
        if entry is not None:
            await _maybe_auto_expand_waiting_room_entry(session, entry)
            group = await _maybe_match_waiting_room(session, entry.skill_id, entry.region_code)
            if group is not None:
                await session.commit()
                return await waiting_room_payload(
                    session,
                    None,
                    matched_group_id=group.id,
                    current_user_id=user.id,
                )
        payload = await waiting_room_payload(
            session,
            entry,
            current_user_id=user.id,
        )
        await session.commit()
        return payload

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
    await session.commit()
    if not queues:
        pending_group = await _pending_match_group_for_user(session, user.id)
        empty = await waiting_room_payload(
            session,
            None,
            matched_group_id=pending_group.id if pending_group else None,
            current_user_id=user.id,
        )
        if pending_group is not None:
            empty["skill_id"] = pending_group.skill_id
            empty["skill_name"] = skill_name(pending_group.skill_id)
        empty["queues"] = []
        return empty
    result = dict(queues[0])
    result["queues"] = queues
    return result


@router.get("/groups/waiting-rooms")
async def waiting_rooms(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await waiting_room(None, user, session)


@router.post("/groups/waiting-room/expand")
async def expand_waiting_room_search(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    skill_id = str(payload.get("skill_id") or "")
    entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == skill_id,
        )
    )
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Очередь не найдена")
    created_at = entry.created_at
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc) < created_at + REGION_EXPANSION_DELAY:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Расширить поиск можно через {int(REGION_EXPANSION_DELAY.total_seconds() // 60)} мин после начала ожидания",
        )
    entry.allow_other_regions = bool(payload.get("allow", True))
    session.add(entry)
    group = await _maybe_match_waiting_room(session, skill_id, entry.region_code)
    await session.commit()
    if group is not None:
        return await waiting_room_payload(
            session,
            None,
            matched_group_id=group.id,
            current_user_id=user.id,
        )
    await session.refresh(entry)
    return await waiting_room_payload(session, entry, current_user_id=user.id)


@router.get("/groups/waiting-room/stats")
async def waiting_room_stats(
    skill_id: str = Query(...),
    region_code: str = Query(...),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if skill_id not in {item["id"] for item in SKILLS}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Выберите навык")
    if not is_valid_region(region_code):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Некорректный регион")
    return await waiting_room_stats_payload(
        session,
        skill_id=skill_id,
        region_code=region_code,
    )


@router.post("/groups/waiting-room/pair-invite")
async def waiting_room_pair_invite(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    skill_id = str(payload.get("skill_id") or "")
    entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == skill_id,
        )
    )
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Очередь не найдена")
    invite_code = entry.pair_code or secrets.token_urlsafe(8)
    entry.pair_code = invite_code
    session.add(entry)
    await session.commit()
    deep_link = f"prime://waiting-room/pair?code={invite_code}&skill_id={skill_id}"
    return {"invite_code": invite_code, "deep_link": deep_link}


@router.post("/groups/waiting-room/pair-invite/send")
async def waiting_room_pair_invite_send(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Send pair invites to specific friends via direct messages."""
    skill_id = str(payload.get("skill_id") or "")
    raw_ids = payload.get("user_ids") or []
    if not isinstance(raw_ids, list) or not raw_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Укажите user_ids",
        )
    user_ids = [str(uid) for uid in raw_ids if str(uid).strip()]
    if not user_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Укажите user_ids",
        )

    entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == skill_id,
        )
    )
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Очередь не найдена")

    invite_code = entry.pair_code or secrets.token_urlsafe(8)
    entry.pair_code = invite_code
    session.add(entry)

    friend_ids = set(await _friend_ids_for_user(session, user.id))
    sent: list[str] = []
    skipped: list[str] = []
    skill_label = skill_name(skill_id)
    for friend_id in user_ids:
        if friend_id == user.id or friend_id not in friend_ids:
            skipped.append(friend_id)
            continue
        conversation_key = _direct_conversation_key(user.id, friend_id)
        body = (
            f"Приглашаю в пару по привычке «{skill_label}». "
            f"Открой приглашение в чате, чтобы присоединиться."
        )
        session.add(
            DirectMessage(
                conversation_key=conversation_key,
                sender_user_id=user.id,
                recipient_user_id=friend_id,
                msgtype="prime.pair_invite",
                body=body,
                filename=invite_code,
                content_type=skill_id,
            )
        )
        await create_notification(
            session,
            friend_id,
            "direct_message",
            user.name or user.nickname,
            f"Приглашение в пару · «{skill_label}»",
            {
                "friend_id": user.id,
                "skill_id": skill_id,
                "deep_link": f"prime://waiting-room/pair?code={invite_code}&skill_id={skill_id}",
            },
        )
        sent.append(friend_id)

    await session.commit()
    deep_link = f"prime://waiting-room/pair?code={invite_code}&skill_id={skill_id}"
    return {
        "invite_code": invite_code,
        "deep_link": deep_link,
        "sent": sent,
        "skipped": skipped,
    }


@router.post("/groups/waiting-room/pair-join")
async def waiting_room_pair_join(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    invite_code = str(payload.get("invite_code") or "").strip()
    if not invite_code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Укажите invite_code")
    host_entry = await session.scalar(
        select(WaitingRoomEntry)
        .where(WaitingRoomEntry.pair_code == invite_code)
        .order_by(WaitingRoomEntry.created_at.asc())
        .limit(1)
    )
    if host_entry is None or host_entry.user_id == user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Приглашение не найдено")
    guest_entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == host_entry.skill_id,
        )
    )
    if guest_entry is None:
        guest_entry = WaitingRoomEntry(
            user_id=user.id,
            skill_id=host_entry.skill_id,
            region_code=host_entry.region_code,
        )
        session.add(guest_entry)
        await session.flush()
    else:
        guest_entry.region_code = host_entry.region_code
    guest_entry.pair_code = invite_code
    session.add(guest_entry)
    await session.flush()
    skill_label = skill_name(host_entry.skill_id) or "привычку"
    await create_notification(
        session,
        host_entry.user_id,
        "team_activity",
        "Пара собрана",
        f"@{user.nickname} принял приглашение · «{skill_label}»",
        {
            "skill_id": host_entry.skill_id,
            "deep_link": f"prime://waiting-room/pair?code={invite_code}&skill_id={host_entry.skill_id}",
        },
    )
    await _notify_waiting_room_pair_join(
        session,
        pair_code=invite_code,
        skill_id=host_entry.skill_id,
        joiner_user_id=user.id,
    )
    await session.commit()
    return {
        "pair_code": invite_code,
        "skill_id": host_entry.skill_id,
        "paired": True,
    }


@router.post("/groups/waiting-room/early-start")
@router.post("/groups/waiting-room/pair-start")
async def waiting_room_early_start(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Create/confirm a 15-minute proposal to start with three people."""
    skill_id = str(payload.get("skill_id") or "").strip()
    filters = [WaitingRoomEntry.user_id == user.id]
    if skill_id:
        filters.append(WaitingRoomEntry.skill_id == skill_id)
    entry = await session.scalar(
        select(WaitingRoomEntry)
        .where(*filters)
        .order_by(WaitingRoomEntry.created_at.asc())
        .limit(1)
    )
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Очередь не найдена")

    pool_entries = (
        await session.execute(
            select(WaitingRoomEntry)
            .where(WaitingRoomEntry.skill_id == entry.skill_id)
            .order_by(WaitingRoomEntry.created_at.asc())
        )
    ).scalars().all()
    if len(pool_entries) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для раннего старта нужно минимум 3 человека в очереди",
        )

    existing_group = await _group_for_user_skill(session, user.id, entry.skill_id)
    if existing_group is not None:
        return await waiting_room_payload(
            session,
            None,
            matched_group_id=existing_group.id,
            current_user_id=user.id,
        )

    now = utcnow()
    expired = (
        await session.execute(
            select(EarlyStartRequest).where(
                EarlyStartRequest.skill_id == entry.skill_id,
                EarlyStartRequest.status == "pending",
                EarlyStartRequest.expires_at <= now,
            )
        )
    ).scalars().all()
    for stale in expired:
        stale.status = "expired"
        stale.revision = int(stale.revision or 0) + 1
        session.add(stale)

    request = await session.scalar(
        select(EarlyStartRequest)
        .where(
            EarlyStartRequest.skill_id == entry.skill_id,
            EarlyStartRequest.status == "pending",
            EarlyStartRequest.expires_at > now,
        )
        .order_by(EarlyStartRequest.created_at.desc())
        .limit(1)
    )
    created_request = request is None
    if request is None:
        request = EarlyStartRequest(
            skill_id=entry.skill_id,
            initiator_user_id=user.id,
            status="pending",
            expires_at=now + EARLY_START_REQUEST_TTL,
        )
        session.add(request)
        for pool_entry in pool_entries:
            pool_entry.pair_start_confirmed_at = None
            pool_entry.revision = int(pool_entry.revision or 0) + 1
            session.add(pool_entry)
        await session.flush()

    confirmation = await session.scalar(
        select(EarlyStartConfirmation).where(
            EarlyStartConfirmation.request_id == request.id,
            EarlyStartConfirmation.user_id == user.id,
        )
    )
    confirmation_created = confirmation is None
    if confirmation is None:
        confirmation = EarlyStartConfirmation(
            request_id=request.id,
            user_id=user.id,
        )
        session.add(confirmation)
        entry.pair_start_confirmed_at = now
        entry.revision = int(entry.revision or 0) + 1
        request.revision = int(request.revision or 0) + 1
        session.add_all([entry, request])
        await session.flush()

    if created_request:
        skill_label = skill_name(entry.skill_id) or "привычку"
        deep_link = f"prime://waiting-room?skill_id={entry.skill_id}&early_start={request.id}"
        for candidate in pool_entries:
            if candidate.user_id == user.id:
                continue
            await create_notification(
                session,
                candidate.user_id,
                "early_start_request",
                f"{user.name or '@' + user.nickname} предлагает старт втроём",
                f"«{skill_label}» · уже 1 из 3 согласились · решение действует 15 минут",
                {
                    "request_id": request.id,
                    "skill_id": entry.skill_id,
                    "initiator_user_id": user.id,
                    "expires_at": request.expires_at.isoformat(),
                    "deep_link": deep_link,
                    "actions": ["confirm", "keep_waiting", "open_search"],
                },
            )

    confirmations = (
        await session.execute(
            select(EarlyStartConfirmation)
            .where(EarlyStartConfirmation.request_id == request.id)
            .order_by(EarlyStartConfirmation.created_at.asc())
        )
    ).scalars().all()
    entries_by_user = {item.user_id: item for item in pool_entries}
    confirmations = [
        item for item in confirmations if item.user_id in entries_by_user
    ]
    request.revision = int(request.revision or 0) + 1
    session.add(request)

    if len(confirmations) < 3:
        if confirmation_created and not created_request:
            skill_label = skill_name(entry.skill_id) or "привычку"
            deep_link = f"prime://waiting-room?skill_id={entry.skill_id}&early_start={request.id}"
            actor_label = user.name or f"@{user.nickname}"
            for candidate in pool_entries:
                if candidate.user_id == user.id:
                    continue
                await create_notification(
                    session,
                    candidate.user_id,
                    "early_start_request",
                    f"{actor_label} подтвердил ранний старт",
                    f"«{skill_label}» · {len(confirmations)} из 3 · осталось подтвердить",
                    {
                        "request_id": request.id,
                        "skill_id": entry.skill_id,
                        "initiator_user_id": user.id,
                        "expires_at": request.expires_at.isoformat(),
                        "deep_link": deep_link,
                        "actions": ["confirm", "keep_waiting", "open_search"],
                    },
                )
        await _notify_waiting_room_skill_pool(
            session,
            skill_id=entry.skill_id,
            reason="early_start_requested" if created_request else "early_start_confirmed",
        )
        await session.commit()
        payload_data = await waiting_room_payload(
            session,
            entry,
            current_user_id=user.id,
        )
        return {
            **payload_data,
            "started": False,
            "waiting_others_confirm": True,
            "waiting_partner_confirm": True,
            "early_start_confirmed_count": len(confirmations),
            "early_start_request_id": request.id,
            "early_start_expires_at": request.expires_at.isoformat(),
        }

    formed_user_ids = [item.user_id for item in confirmations[:3]]
    formed_entries = [
        entries_by_user[user_id]
        for user_id in formed_user_ids
        if user_id in entries_by_user
    ]
    group = await _create_group_from_early_start_entries(
        session,
        formed_entries,
    )
    request.status = "formed"
    request.revision = int(request.revision or 0) + 1
    session.add(request)
    await _notify_waiting_room_users(
        session,
        skill_id=entry.skill_id,
        user_ids=formed_user_ids,
        reason="early_start_formed",
    )
    await _notify_waiting_room_skill_pool(
        session,
        skill_id=entry.skill_id,
        reason="queue_changed",
    )
    await session.commit()
    return {
        **await waiting_room_payload(
            session,
            None,
            matched_group_id=group.id,
            current_user_id=user.id,
        ),
        "started": True,
        "matched_group_id": group.id,
    }


@router.delete("/groups/waiting-room", status_code=204)
async def leave_waiting_room(
    skill_id: str | None = None,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    filters = [WaitingRoomEntry.user_id == user.id]
    if skill_id:
        filters.append(WaitingRoomEntry.skill_id == skill_id)
    leaving_entries = (
        await session.execute(select(WaitingRoomEntry).where(*filters))
    ).scalars().all()
    skill_ids = {entry.skill_id for entry in leaving_entries}
    await session.execute(delete(WaitingRoomEntry).where(*filters))
    await session.flush()
    for pool_skill_id in skill_ids:
        await _notify_waiting_room_skill_pool(
            session,
            skill_id=pool_skill_id,
        )
    await session.commit()
    return None
