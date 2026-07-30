"""Notification list, read state, device registration, and SSE stream."""
import asyncio
import json
import time
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import StreamingResponse

from ..db import SessionLocal, get_session
from ..deps import get_current_user
from ..direct_message_events import (
    DirectChatReadPush,
    DirectMessagePush,
    GroupChatUpdatePush,
    GroupUpdatePush,
    NotificationPush,
    WaitingRoomUpdatePush,
    direct_message_hub,
)
from ..models import DeviceToken, DirectMessage, Notification, User, utcnow
from ..notifications import notification_payload
from ..pagination import decode_cursor, encode_cursor

router = APIRouter(tags=["notifications"])


@router.get("/notifications")
async def list_notifications(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    before: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
) -> dict:
    # The router normally receives concrete values from FastAPI. These
    # fallbacks keep direct unit calls backwards-compatible with the old
    # two-argument helper signature.
    if not isinstance(before, str):
        before = None
    if not isinstance(limit, int):
        limit = 50
    filters = [Notification.user_id == user.id]
    if before is not None:
        try:
            before_created_at, before_id = decode_cursor(before)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Некорректный курсор",
            ) from None
        # SQLite's DateTime emulation returns naive values while PostgreSQL
        # returns timestamptz values. Keep the comparison type aligned without
        # changing the production schema.
        bind = session.get_bind()
        if bind.dialect.name == "sqlite":
            before_created_at = before_created_at.replace(tzinfo=None)
            before_key = before_created_at.strftime("%Y-%m-%d %H:%M:%S.") + f"{before_created_at.microsecond // 1000:03d}"
            created_key = func.strftime("%Y-%m-%d %H:%M:%f", Notification.created_at)
            filters.append(
                or_(
                    created_key < before_key,
                    and_(created_key == before_key, Notification.id < before_id),
                )
            )
        else:
            filters.append(
                or_(
                    Notification.created_at < before_created_at,
                    and_(
                        Notification.created_at == before_created_at,
                        Notification.id < before_id,
                    ),
                )
            )
    rows = (
        await session.execute(
            select(Notification)
            .where(*filters)
            .order_by(Notification.created_at.desc(), Notification.id.desc())
            .limit(limit + 1)
        )
    ).scalars().all()
    has_more = len(rows) > limit
    page = rows[:limit]
    unread_count = await session.scalar(
        select(func.count())
        .select_from(Notification)
        .where(
            Notification.user_id == user.id,
            Notification.read_at.is_(None),
        )
    )
    return {
        "items": [notification_payload(item) for item in page],
        "unread_count": int(unread_count or 0),
        "has_more": has_more,
        "next_before": (
            encode_cursor(page[-1].created_at, page[-1].id)
            if has_more and page
            else None
        ),
    }


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    notification = await session.scalar(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user.id,
        )
    )
    if notification is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Уведомление не найдено")
    if notification.read_at is None:
        notification.read_at = utcnow()
        session.add(notification)
        await session.commit()
    return {"status": "ok"}


@router.post("/notifications/read-all")
async def mark_all_notifications_read(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    now = utcnow()
    await session.execute(
        update(Notification)
        .where(
            Notification.user_id == user.id,
            Notification.read_at.is_(None),
        )
        .values(read_at=now)
    )
    await session.commit()
    return {"status": "ok"}


@router.post("/devices/register")
async def register_device(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    token = str(payload.get("token") or "").strip()
    platform = str(payload.get("platform") or "").strip().lower()
    if platform not in {"ios", "android", "web"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Некорректная платформа",
        )
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Токен устройства обязателен",
        )

    existing = await session.scalar(select(DeviceToken).where(DeviceToken.token == token))
    if existing is None:
        existing = DeviceToken(user_id=user.id, platform=platform, token=token)
    else:
        existing.user_id = user.id
        existing.platform = platform
        existing.updated_at = utcnow()
    session.add(existing)
    await session.commit()
    return {"status": "ok"}


async def _notification_stream(user_id: str):
    seen_ids: set[str] | None = None
    last_heartbeat = time.monotonic()
    last_direct_message_at: datetime | None = None
    queue = direct_message_hub.subscribe(user_id)

    try:
        while True:
            try:
                push = await asyncio.wait_for(queue.get(), timeout=1.0)
                if isinstance(push, NotificationPush):
                    data = json.dumps(push.notification, ensure_ascii=False)
                    yield f"event: notification\ndata: {data}\n\n"
                    notification = push.notification
                    if notification.get("type") == "match" and not notification.get("read"):
                        try:
                            payload = notification.get("payload") or {}
                        except AttributeError:
                            payload = {}
                        if not isinstance(payload, dict):
                            payload = {}
                        group_id = payload.get("group_id", "")
                        match_data = json.dumps({"group_id": group_id}, ensure_ascii=False)
                        yield f"event: match\ndata: {match_data}\n\n"
                elif isinstance(push, DirectChatReadPush):
                    payload = json.dumps(
                        {
                            "friend_id": push.friend_id,
                            "read_at": push.read_at,
                        },
                        ensure_ascii=False,
                    )
                    yield f"event: direct_chat_read\ndata: {payload}\n\n"
                elif isinstance(push, WaitingRoomUpdatePush):
                    payload = json.dumps(
                        {"skill_id": push.skill_id},
                        ensure_ascii=False,
                    )
                    yield f"event: waiting_room_update\ndata: {payload}\n\n"
                elif isinstance(push, GroupUpdatePush):
                    payload = json.dumps(
                        {"group_id": push.group_id},
                        ensure_ascii=False,
                    )
                    yield f"event: group_update\ndata: {payload}\n\n"
                elif isinstance(push, GroupChatUpdatePush):
                    payload = json.dumps(
                        {"group_id": push.group_id},
                        ensure_ascii=False,
                    )
                    yield f"event: group_chat_update\ndata: {payload}\n\n"
                else:
                    payload = json.dumps(
                        {
                            "friend_id": push.friend_id,
                            "message_id": push.message_id,
                            "message": push.message,
                        },
                        ensure_ascii=False,
                    )
                    yield f"event: direct_message\ndata: {payload}\n\n"
                continue
            except asyncio.TimeoutError:
                pass

            try:
                async with SessionLocal() as session:
                    if last_direct_message_at is None:
                        last_direct_message_at = await session.scalar(
                            select(func.max(DirectMessage.created_at)).where(
                                DirectMessage.recipient_user_id == user_id
                            )
                        )
                        if last_direct_message_at is None:
                            last_direct_message_at = utcnow()

                    rows = (
                        await session.execute(
                            select(Notification)
                            .where(Notification.user_id == user_id)
                            .order_by(Notification.created_at.desc())
                            .limit(50)
                        )
                    ).scalars().all()

                    if seen_ids is None:
                        seen_ids = {item.id for item in rows}
                    else:
                        pending = [item for item in reversed(rows) if item.id not in seen_ids]
                        for item in pending:
                            seen_ids.add(item.id)
                            data = json.dumps(notification_payload(item), ensure_ascii=False)
                            yield f"event: notification\ndata: {data}\n\n"
                            if item.type == "match" and item.read_at is None:
                                try:
                                    payload = json.loads(item.payload or "{}")
                                except json.JSONDecodeError:
                                    payload = {}
                                group_id = payload.get("group_id", "")
                                match_data = json.dumps({"group_id": group_id}, ensure_ascii=False)
                                yield f"event: match\ndata: {match_data}\n\n"

                    new_direct = (
                        await session.execute(
                            select(DirectMessage)
                            .where(
                                DirectMessage.recipient_user_id == user_id,
                                DirectMessage.created_at > last_direct_message_at,
                            )
                            .order_by(DirectMessage.created_at.asc())
                        )
                    ).scalars().all()
                    for message in new_direct:
                        payload = json.dumps(
                            {
                                "friend_id": message.sender_user_id,
                                "message_id": message.id,
                            },
                            ensure_ascii=False,
                        )
                        yield f"event: direct_message\ndata: {payload}\n\n"
                        if message.created_at > last_direct_message_at:
                            last_direct_message_at = message.created_at

                now = time.monotonic()
                if now - last_heartbeat >= 15:
                    yield ": heartbeat\n\n"
                    last_heartbeat = now
            except asyncio.CancelledError:
                break
    finally:
        direct_message_hub.unsubscribe(user_id, queue)


@router.get("/events/stream")
async def events_stream(user: User = Depends(get_current_user)) -> StreamingResponse:
    return StreamingResponse(
        _notification_stream(user.id),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


__all__ = ["router"]
