"""social routes — split from misc.py."""
from datetime import date, datetime, timedelta, timezone
import mimetypes
from pathlib import Path as FsPath
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, Response, UploadFile, status
from sqlalchemy import case, delete, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import get_current_user
from ..media import read_upload
from ..media_scope import validate_media_url_for_scope
from ..moderation import ModerationError, check_social_write_allowed, moderate_text_before_publish
from ..moderation.pipeline import moderation_http_error
from ..audit import record_audit
from ..rate_limit import enforce as enforce_rate_limit
from ..direct_message_events import DirectMessagePush, direct_message_hub
from ..notifications import create_notification
from ..pagination import decode_cursor, encode_cursor
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
    DirectMessageReaction,
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
    _direct_messages_payloads,
    _direct_reply_preview,
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

router = APIRouter(tags=["social"])

@router.get("/users/by-nickname/{nickname}")
async def find_user_by_nickname(
    nickname: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    normalized = normalize_nickname(nickname)
    if len(normalized) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=" ")
    found = await session.scalar(select(User).where(User.nickname == normalized))
    if found is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="  ")
    pending_request = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.status == "pending",
            or_(
                (FriendRequest.requester_user_id == user.id) & (FriendRequest.addressee_user_id == found.id),
                (FriendRequest.requester_user_id == found.id) & (FriendRequest.addressee_user_id == user.id),
            ),
        )
    )
    pending_direction = None
    if pending_request is not None:
        pending_direction = (
            "outgoing"
            if pending_request.requester_user_id == user.id
            else "incoming"
        )
    return {
        "user": _public_user_payload(found),
        "is_self": found.id == user.id,
        "is_friend": found.id != user.id and await _are_friends(session, user.id, found.id),
        "has_pending_request": pending_request is not None,
        "pending_request_id": pending_request.id if pending_request is not None else None,
        "pending_direction": pending_direction,
    }


async def _discover_item_payload(
    session: AsyncSession,
    viewer: User,
    found: User,
) -> dict:
    pending_request = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.status == "pending",
            or_(
                (FriendRequest.requester_user_id == viewer.id)
                & (FriendRequest.addressee_user_id == found.id),
                (FriendRequest.requester_user_id == found.id)
                & (FriendRequest.addressee_user_id == viewer.id),
            ),
        )
    )
    pending_direction = None
    if pending_request is not None:
        pending_direction = (
            "outgoing"
            if pending_request.requester_user_id == viewer.id
            else "incoming"
        )
    return {
        "user": _public_user_payload(found),
        "is_friend": await _are_friends(session, viewer.id, found.id),
        "has_pending_request": pending_request is not None,
        "pending_request_id": pending_request.id if pending_request is not None else None,
        "pending_direction": pending_direction,
    }


async def _discover_items_payload(
    session: AsyncSession,
    viewer: User,
    found_users: list[User],
) -> list[dict]:
    """Batch relationship state to avoid two queries per discover card."""
    ids = [item.id for item in found_users]
    if not ids:
        return []
    friends = (
        await session.execute(
            select(Friendship).where(
                or_(
                    (Friendship.user_low_id == viewer.id) & Friendship.user_high_id.in_(ids),
                    (Friendship.user_high_id == viewer.id) & Friendship.user_low_id.in_(ids),
                )
            )
        )
    ).scalars().all()
    friend_ids = {
        row.user_high_id if row.user_low_id == viewer.id else row.user_low_id
        for row in friends
    }
    pending = (
        await session.execute(
            select(FriendRequest).where(
                FriendRequest.status == "pending",
                or_(
                    (FriendRequest.requester_user_id == viewer.id) & FriendRequest.addressee_user_id.in_(ids),
                    (FriendRequest.addressee_user_id == viewer.id) & FriendRequest.requester_user_id.in_(ids),
                ),
            )
        )
    ).scalars().all()
    pending_by_user: dict[str, FriendRequest] = {}
    for row in pending:
        other_id = row.addressee_user_id if row.requester_user_id == viewer.id else row.requester_user_id
        pending_by_user[other_id] = row
    items = []
    for found in found_users:
        request = pending_by_user.get(found.id)
        items.append(
            {
                "user": _public_user_payload(found),
                "is_friend": found.id in friend_ids,
                "has_pending_request": request is not None,
                "pending_request_id": request.id if request is not None else None,
                "pending_direction": (
                    "outgoing" if request and request.requester_user_id == viewer.id else "incoming"
                ) if request else None,
            }
        )
    return items


@router.get("/users/discover")
async def discover_users(
    region_code: str | None = Query(default=None, max_length=8),
    cursor: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=50),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    normalized_region = region_code.strip() if region_code else None
    if normalized_region == "":
        normalized_region = None

    cursor_created_at = None
    cursor_id = None
    if cursor:
        try:
            cursor_created_at, cursor_id = decode_cursor(cursor)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Некорректный cursor",
            ) from exc

    query = (
        select(User)
        .where(
            User.id != user.id,
            User.is_active.is_(True),
            User.email_verified_at.is_not(None),
            User.nickname != "",
        )
        .order_by(User.created_at.desc(), User.id.desc())
        .limit(limit + 1)
    )
    if normalized_region is not None:
        query = query.where(User.region_code == normalized_region)
    if cursor_created_at is not None and cursor_id is not None:
        if session.get_bind().dialect.name == "sqlite":
            cursor_key = cursor_created_at.strftime("%Y-%m-%d %H:%M:%S")
            created_key = func.strftime("%Y-%m-%d %H:%M:%S", User.created_at)
            query = query.where(
                or_(
                    created_key < cursor_key,
                    (created_key == cursor_key) & (User.id < cursor_id),
                )
            )
        else:
            query = query.where(
                or_(
                    User.created_at < cursor_created_at,
                    (User.created_at == cursor_created_at) & (User.id < cursor_id),
                )
            )

    rows = (await session.execute(query)).scalars().all()
    has_more = len(rows) > limit
    page = rows[:limit]

    items = await _discover_items_payload(session, user, page)
    next_cursor = (
        encode_cursor(page[-1].created_at, page[-1].id)
        if has_more and page and page[-1].created_at is not None
        else None
    )

    return {"items": items, "next_cursor": next_cursor}


async def _create_friend_request_for_addressee(
    session: AsyncSession,
    requester: User,
    addressee: User,
) -> dict:
    if addressee.id == requester.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="  ")
    if await _are_friends(session, requester.id, addressee.id):
        return {"status": "accepted"}

    reverse = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.requester_user_id == addressee.id,
            FriendRequest.addressee_user_id == requester.id,
            FriendRequest.status == "pending",
        )
    )
    if reverse is not None:
        low, high = _friendship_pair(requester.id, addressee.id)
        session.add(Friendship(user_low_id=low, user_high_id=high))
        reverse.status = "accepted"
        session.add(reverse)
        await create_notification(
            session,
            addressee.id,
            "system",
            requester.name or requester.nickname,
            "принял(а) вашу заявку в друзья",
            {
                "friend_id": requester.id,
                "friend_nickname": requester.nickname,
            },
        )
        await session.commit()
        return {"status": "accepted"}

    existing = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.requester_user_id == requester.id,
            FriendRequest.addressee_user_id == addressee.id,
        )
    )
    if existing is None:
        existing = FriendRequest(requester_user_id=requester.id, addressee_user_id=addressee.id)
    elif existing.status != "pending":
        existing.status = "pending"
    session.add(existing)
    await session.flush()
    await create_notification(
        session,
        addressee.id,
        "friend_request",
        requester.name or requester.nickname,
        "хочет добавить вас в друзья",
        {
            "request_id": existing.id,
            "requester_id": requester.id,
            "requester_nickname": requester.nickname,
        },
    )
    await record_audit(
        session,
        action="friend_request.sent",
        user_id=requester.id,
        metadata={"addressee_id": addressee.id, "request_id": existing.id},
    )
    await session.commit()
    await session.refresh(existing)
    return {"status": existing.status, "request_id": existing.id}


@router.post("/friends/requests")
async def create_friend_request(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    nickname = normalize_nickname(str(payload.get("nickname") or ""))
    if len(nickname) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=" ")
    settings = get_settings()
    await enforce_rate_limit(
        session,
        f"friend_request:user:{user.id}",
        limit=settings.friend_request_rate_limit_attempts,
        window_seconds=settings.friend_request_rate_limit_window_seconds,
        detail="Слишком много приглашений. Попробуйте позже.",
    )
    addressee = await session.scalar(select(User).where(User.nickname == nickname))
    if addressee is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="  ")
    return await _create_friend_request_for_addressee(session, user, addressee)


@router.get("/friends/requests")
async def friend_requests(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    rows = (
        await session.execute(
            select(FriendRequest, User)
            .join(User, User.id == FriendRequest.requester_user_id)
            .where(
                FriendRequest.addressee_user_id == user.id,
                FriendRequest.status == "pending",
            )
            .order_by(FriendRequest.created_at.desc())
        )
    ).all()
    return {
        "requests": [_friend_request_payload(request, requester) for request, requester in rows],
        "unread_count": len(rows),
    }


@router.post("/friends/requests/{request_id}/respond")
async def respond_friend_request(
    request_id: str,
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    accepted = bool(payload.get("accept"))
    request = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.id == request_id,
            FriendRequest.addressee_user_id == user.id,
            FriendRequest.status == "pending",
        )
    )
    if request is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Заявка не найдена")
    request.status = "accepted" if accepted else "declined"
    session.add(request)
    if accepted:
        low, high = _friendship_pair(request.requester_user_id, request.addressee_user_id)
        friendship = await session.scalar(
            select(Friendship).where(
                Friendship.user_low_id == low,
                Friendship.user_high_id == high,
            )
        )
        if friendship is None:
            session.add(Friendship(user_low_id=low, user_high_id=high))
        requester = await session.scalar(
            select(User).where(User.id == request.requester_user_id)
        )
        if requester is not None:
            await create_notification(
                session,
                request.requester_user_id,
                "system",
                user.name or user.nickname,
                "принял(а) вашу заявку в друзья",
                {
                    "friend_id": user.id,
                    "friend_nickname": user.nickname,
                },
            )
    await session.commit()
    return {"status": request.status}


@router.delete("/friends/requests/{request_id}")
async def cancel_friend_request(
    request_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    request = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.id == request_id,
            FriendRequest.requester_user_id == user.id,
            FriendRequest.status == "pending",
        )
    )
    if request is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Заявка не найдена")
    await session.delete(request)
    await session.commit()
    return {"status": "cancelled"}


@router.get("/friends")
async def friends(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    friend_ids = await _friend_ids_for_user(session, user.id)
    if not friend_ids:
        return {"friends": []}
    rows = (
        await session.execute(
            select(User)
            .where(User.id.in_(friend_ids), User.is_active.is_(True))
            .order_by(User.name.asc())
        )
    ).scalars().all()
    return {"friends": [_user_payload(friend) for friend in rows]}


@router.get("/direct-chats")
async def list_direct_chats(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    limit: int = Query(default=100, ge=1, le=100),
) -> dict:
    return {"chats": await _direct_chat_inbox_items(session, user, limit)}


@router.post("/direct-chats/{friend_id}/read")
async def mark_direct_chat_read(
    friend_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if not await _are_friends(session, user.id, friend_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Друг не найден")
    last_read_at = await _mark_direct_chat_read(session, user.id, friend_id)
    return {"status": "ok", "last_read_at": last_read_at.isoformat()}


@router.get("/direct-chats/{friend_id}/messages")
async def direct_messages(
    friend_id: str,
    before: str | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if not await _are_friends(session, user.id, friend_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Друг не найден")
    filters = [DirectMessage.conversation_key == _direct_conversation_key(user.id, friend_id)]
    before_created_at = None
    before_id = None
    if before:
        try:
            before_created_at, before_id = decode_cursor(before)
        except ValueError:
            try:
                before_created_at = datetime.fromisoformat(before)
            except ValueError as error:
                raise HTTPException(status_code=400, detail="Некорректный курсор") from error
        filters.append(
            or_(
                DirectMessage.created_at < before_created_at,
                (DirectMessage.created_at == before_created_at) & (DirectMessage.id < (before_id or "")),
            )
        )
    messages = (
        await session.execute(
            select(DirectMessage)
            .where(*filters)
            .order_by(DirectMessage.created_at.desc(), DirectMessage.id.desc())
            .limit(limit + 1)
        )
    ).scalars().all()
    has_more = len(messages) > limit
    page = list(reversed(messages[:limit]))
    if before is None:
        await _mark_direct_chat_read(session, user.id, friend_id)
    peer_read = await session.scalar(
        select(DirectConversationRead).where(
            DirectConversationRead.user_id == friend_id,
            DirectConversationRead.friend_id == user.id,
        )
    )
    peer_last_read_at = peer_read.last_read_at if peer_read is not None else None
    payloads = await _direct_messages_payloads(
        session,
        page,
        user.id,
        peer_last_read_at=peer_last_read_at,
    )
    return {
        "messages": payloads,
        "has_more": has_more,
        "next_before": encode_cursor(page[0].created_at, page[0].id) if has_more and page else None,
        "peer_last_read_at": peer_last_read_at.isoformat() if peer_last_read_at else None,
    }


@router.post("/direct-chats/{friend_id}/upload")
async def direct_chat_upload_media(
    friend_id: str,
    file: UploadFile = File(...),
    request: Request = None,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if not await _are_friends(session, user.id, friend_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Друг не найден")
    if request is not None:
        from ..rate_limit import enforce as enforce_rate_limit
        from ..rate_limit import record_failure as record_rate_limit_failure
        settings = get_settings()
        keys = (
            f"upload:direct:user:{user.id}",
            f"upload:direct:ip:{request.client.host if request.client else 'unknown'}",
        )
        for key in keys:
            await enforce_rate_limit(session, key, limit=settings.upload_rate_limit_attempts, window_seconds=settings.upload_rate_limit_window_seconds, detail="Слишком много загрузок. Попробуйте позже.")
        for key in keys:
            await record_rate_limit_failure(session, key, window_seconds=settings.upload_rate_limit_window_seconds)
    user = await ensure_matrix_user(user, session)
    declared_type = (file.content_type or "").lower()
    read_limit = MAX_DIRECT_IMAGE_BYTES if declared_type.startswith("image/") else MAX_DIRECT_FILE_BYTES
    content, content_type, filename = await read_upload(
        file,
        max_bytes=read_limit,
        max_image_bytes=MAX_DIRECT_IMAGE_BYTES,
        allow_types=ALLOWED_DIRECT_DOCUMENT_TYPES,
    )
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл пустой")
    is_image = content_type.startswith("image/")
    max_bytes = MAX_DIRECT_IMAGE_BYTES if is_image else MAX_DIRECT_FILE_BYTES
    if len(content) > max_bytes:
        if is_image:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Изображение слишком большое. Максимальный размер — 10 МБ",
            )
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Файл слишком большой. Максимальный размер — 25 МБ",
        )
    if is_image:
        if content_type not in {
            "image/jpeg",
            "image/png",
            "image/webp",
        }:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Этот формат пока не поддерживается",
            )
    elif (
        not content_type.startswith(ALLOWED_MEDIA_PREFIXES)
        and content_type not in ALLOWED_DIRECT_DOCUMENT_TYPES
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Этот формат пока не поддерживается",
        )
    mxc_url = await upload_media(user, session, filename, content_type, content, "direct", friend_id)
    await session.commit()
    return {
        "mxc_url": mxc_url,
        "url": mxc_to_http(mxc_url),
        "filename": filename,
        "content_type": content_type,
        "size_bytes": len(content),
    }


@router.post("/direct-chats/{friend_id}/messages")
async def send_direct_message(
    friend_id: str,
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if not await _are_friends(session, user.id, friend_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Друг не найден")
    client_id = payload.get("client_id")
    client_id = str(client_id).strip() if client_id else None
    if client_id:
        existing = await session.scalar(
            select(DirectMessage).where(
                DirectMessage.sender_user_id == user.id,
                DirectMessage.client_id == client_id,
            )
        )
        if existing is not None:
            return _direct_message_payload(existing, current_user_id=user.id)
    body = str(payload.get("body") or "").strip()
    msgtype = str(payload.get("msgtype") or "m.text")
    media_url = payload.get("url") or payload.get("mxc_url")
    filename = payload.get("filename")
    content_type = payload.get("content_type")
    size_bytes = payload.get("size_bytes")
    allowed_types = {"m.text", "m.image", "m.file"}
    if msgtype not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Этот формат пока не поддерживается",
        )
    if msgtype == "m.text":
        if not body:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Сообщение пустое")
    elif not media_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Не удалось загрузить файл",
        )
    offense_id = f"{user.id}:{client_id}" if client_id else None
    if body:
        try:
            await moderate_text_before_publish(
                session,
                user=user,
                text=body,
                content_type="direct_message",
                offense_id=offense_id,
                draft_id=client_id,
            )
        except ModerationError as exc:
            raise moderation_http_error(exc) from exc
    if media_url:
        await validate_media_url_for_scope(
            session,
            owner=user,
            media_url=str(media_url),
            scope_type="direct",
            scope_id=friend_id,
        )
    if msgtype == "m.image" and not body:
        body = "Изображение"
    if msgtype == "m.file" and not body:
        body = str(filename or "Файл")
    reply_to_id = payload.get("reply_to_id")
    if reply_to_id:
        reply_to_id = str(reply_to_id)
        parent = await session.get(DirectMessage, reply_to_id)
        if parent is None or parent.conversation_key != _direct_conversation_key(user.id, friend_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Сообщение для ответа не найдено",
            )
    message = DirectMessage(
        conversation_key=_direct_conversation_key(user.id, friend_id),
        sender_user_id=user.id,
        recipient_user_id=friend_id,
        reply_to_id=reply_to_id,
        msgtype=msgtype,
        body=body,
        url=str(media_url) if media_url else None,
        filename=str(filename) if filename else None,
        content_type=str(content_type) if content_type else None,
        size_bytes=int(size_bytes) if size_bytes is not None else None,
        client_id=client_id,
    )
    session.add(message)
    try:
        await session.commit()
    except IntegrityError:
        # Concurrent retry with the same client_id raced us — return the winner.
        await session.rollback()
        if client_id:
            existing = await session.scalar(
                select(DirectMessage).where(
                    DirectMessage.sender_user_id == user.id,
                    DirectMessage.client_id == client_id,
                )
            )
            if existing is not None:
                return _direct_message_payload(existing, current_user_id=user.id)
        raise
    await session.refresh(message)
    recipient_payload = _direct_message_payload(message, current_user_id=friend_id)
    direct_message_hub.publish(
        friend_id,
        DirectMessagePush(
            friend_id=user.id,
            message_id=message.id,
            message=recipient_payload,
        ),
    )
    preview = body.strip() if body.strip() else (
        "📷 Фото" if msgtype == "m.image" else "📎 Файл"
    )
    await create_notification(
        session,
        friend_id,
        "direct_message",
        user.name or user.nickname,
        preview if len(preview) <= 120 else f"{preview[:117]}…",
        {
            "friend_id": user.id,
            "message_id": message.id,
            "deep_link": f"prime://chats/direct/{user.id}",
        },
    )
    return _direct_message_payload(message, current_user_id=user.id)


@router.post("/direct-chats/messages/{message_id}/reactions")
async def direct_toggle_reaction(
    message_id: str,
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    emoji = str(payload.get("emoji") or "").strip()
    if emoji not in ALLOWED_REACTION_EMOJIS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неподдерживаемая реакция")
    try:
        await check_social_write_allowed(session, user)
    except ModerationError as exc:
        raise moderation_http_error(exc) from exc
    message = await session.get(DirectMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сообщение не найдено")
    other_id = (
        message.recipient_user_id
        if message.sender_user_id == user.id
        else message.sender_user_id
    )
    if user.id not in {message.sender_user_id, message.recipient_user_id}:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сообщение не найдено")
    if not await _are_friends(session, user.id, other_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Сообщение не найдено")
    existing = await session.scalar(
        select(DirectMessageReaction).where(
            DirectMessageReaction.message_id == message.id,
            DirectMessageReaction.user_id == user.id,
            DirectMessageReaction.emoji == emoji,
        )
    )
    if existing is None:
        session.add(DirectMessageReaction(message_id=message.id, user_id=user.id, emoji=emoji))
    else:
        await session.delete(existing)
    await session.commit()
    await session.refresh(message)
    reactions = (
        await session.execute(
            select(DirectMessageReaction).where(DirectMessageReaction.message_id == message.id)
        )
    ).scalars().all()
    reply_preview = None
    if message.reply_to_id:
        parent = await session.get(DirectMessage, message.reply_to_id)
        reply_preview = _direct_reply_preview(parent)
    return _direct_message_payload(
        message,
        reactions=reactions,
        current_user_id=user.id,
        reply_preview=reply_preview,
    )
