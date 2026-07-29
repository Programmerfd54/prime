"""chat routes — split from misc.py."""
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
from . import group_service as svc
from .group_service import (
    ALLOWED_DOCUMENT_TYPES,
    ALLOWED_MEDIA_PREFIXES,
    ALLOWED_REACTION_EMOJIS,
    _maybe_award_chat_support,
    MAX_GROUP_FILE_BYTES,
    MAX_GROUP_IMAGE_BYTES,
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

router = APIRouter(tags=["chat"])

@router.get("/chat/{group_id}/messages")
async def chat_messages(
    group_id: str,
    before: datetime | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    await _require_active_group(session, group_id, user)
    filters = [ChatMessage.group_id == group_id]
    if before is not None:
        filters.append(ChatMessage.created_at < before)
    messages = (
        await session.execute(
            select(ChatMessage)
            .where(*filters)
            .order_by(ChatMessage.created_at.desc())
            .limit(limit + 1)
        )
    ).scalars().all()
    has_more = len(messages) > limit
    page = list(reversed(messages[:limit]))
    return {
        "messages": await _chat_payloads(session, page, user.id),
        "has_more": has_more,
        "next_before": page[0].created_at.isoformat() if has_more and page else None,
    }


@router.post("/chat/sync")
async def chat_sync(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await chat_messages(
        str(payload.get("group_id") or ""),
        None,
        50,
        user,
        session,
    )


@router.post("/chat/{group_id}/messages")
async def chat_send_message_new(
    group_id: str,
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    group = await _require_active_group(session, group_id, user)
    body = str(payload.get("body") or "").strip()
    msgtype = str(payload.get("msgtype") or "m.text")
    url = payload.get("url")
    allowed_types = {"m.text", "m.image", "m.video", "m.audio", "m.file", "prime.video_note"}
    if msgtype not in allowed_types:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неподдерживаемый тип сообщения")
    if not body and not url:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Сообщение пустое")

    message = await _create_group_chat_message(
        session,
        group,
        user,
        msgtype=msgtype,
        body=body,
        url=str(url) if url else None,
        filename=str(payload.get("filename") or "") or None,
        content_type=str(payload.get("content_type") or "") or None,
        size_bytes=int(payload["size_bytes"]) if payload.get("size_bytes") is not None else None,
        duration_ms=int(payload["duration_ms"]) if payload.get("duration_ms") is not None else None,
        thumbnail_url=str(payload.get("thumbnail_url") or "") or None,
    )
    await session.commit()
    await session.refresh(message)
    return _chat_message_payload(message, user)


@router.post("/chat/messages/{message_id}/reactions")
async def chat_toggle_reaction(
    message_id: str,
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    emoji = str(payload.get("emoji") or "").strip()
    if emoji not in ALLOWED_REACTION_EMOJIS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неподдерживаемая реакция")
    message = await session.get(ChatMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сообщение не найдено")
    await _require_active_group(session, message.group_id, user)
    existing = await session.scalar(
        select(ChatMessageReaction).where(
            ChatMessageReaction.message_id == message.id,
            ChatMessageReaction.user_id == user.id,
            ChatMessageReaction.emoji == emoji,
        )
    )
    if existing is None:
        session.add(ChatMessageReaction(message_id=message.id, user_id=user.id, emoji=emoji))
    else:
        await session.delete(existing)
    group = await session.get(Group, message.group_id)
    support_awarded = False
    if group is not None and existing is None:
        support_awarded = await _maybe_award_chat_support(
            session,
            message=message,
            supporter=user,
            emoji=emoji,
            group=group,
        )
        if support_awarded:
            author = await session.get(User, message.sender_user_id)
            if author is not None:
                await _sync_user_daily_progress(session, author)
    await session.commit()
    await session.refresh(message)
    sender_user = await session.get(User, message.sender_user_id)
    reactions = (
        await session.execute(
            select(ChatMessageReaction).where(ChatMessageReaction.message_id == message.id)
        )
    ).scalars().all()
    return _chat_message_payload(
        message,
        sender_user,
        reactions=reactions,
        current_user_id=user.id,
    ) | {"support_awarded": support_awarded}


@router.post("/chat/send")
async def chat_send_message_old(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await chat_send_message_new(str(payload.get("group_id") or ""), payload, user, session)


@router.post("/chat/send-image")
async def chat_send_image(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    data = {
        "body": "зображение",
        "msgtype": "m.image",
        "url": payload.get("mxc_url"),
    }
    return await chat_send_message_new(str(payload.get("group_id") or ""), data, user, session)


@router.post("/chat/upload")
async def chat_upload_media(
    file: UploadFile = File(...),
    group_id: str = Form(...),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    await _require_active_group(session, group_id, user)
    user = await ensure_matrix_user(user, session)
    content = await file.read(MAX_MEDIA_BYTES + 1)
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл пустой")
    if len(content) > MAX_MEDIA_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Файл больше 100 МБ")
    filename = file.filename or f"{uuid4().hex}.bin"
    content_type = file.content_type or "application/octet-stream"
    if content_type == "application/octet-stream":
        content_type = mimetypes.guess_type(filename)[0] or content_type
    is_image = content_type.startswith("image/")
    is_document = content_type in ALLOWED_DOCUMENT_TYPES
    if not content_type.startswith(ALLOWED_MEDIA_PREFIXES) and not is_document:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неподдерживаемый формат файла")
    if is_image and len(content) > MAX_GROUP_IMAGE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Изображение слишком большое. Максимальный размер — 10 МБ",
        )
    if is_document and len(content) > MAX_GROUP_FILE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Файл слишком большой. Максимальный размер — 25 МБ",
        )
    mxc_url = await upload_media(user, filename, content_type, content)
    await session.commit()
    return {
        "mxc_url": mxc_url,
        "url": mxc_to_http(mxc_url),
        "filename": filename,
        "content_type": content_type,
        "size_bytes": len(content),
    }


