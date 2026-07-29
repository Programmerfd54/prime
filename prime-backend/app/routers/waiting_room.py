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
        empty = await waiting_room_payload(session, None, current_user_id=user.id)
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
        select(WaitingRoomEntry).where(WaitingRoomEntry.pair_code == invite_code)
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Сначала встаньте в очередь по этой привычке",
        )
    guest_entry.pair_code = invite_code
    session.add(guest_entry)
    await session.commit()
    return {
        "pair_code": invite_code,
        "skill_id": host_entry.skill_id,
        "paired": True,
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
    await session.execute(delete(WaitingRoomEntry).where(*filters))
    await session.commit()
    return None


