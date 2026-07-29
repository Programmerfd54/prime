"""Notification list, read state, device registration, and SSE stream."""
import asyncio
import json
import time

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import StreamingResponse

from ..db import SessionLocal, get_session
from ..deps import get_current_user
from ..models import DeviceToken, Notification, User, utcnow
from ..notifications import notification_payload

router = APIRouter(tags=["notifications"])


@router.get("/notifications")
async def list_notifications(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    rows = (
        await session.execute(
            select(Notification)
            .where(Notification.user_id == user.id)
            .order_by(Notification.created_at.desc())
            .limit(100)
        )
    ).scalars().all()
    unread_count = await session.scalar(
        select(func.count())
        .select_from(Notification)
        .where(
            Notification.user_id == user.id,
            Notification.read_at.is_(None),
        )
    )
    return {
        "items": [notification_payload(item) for item in rows],
        "unread_count": int(unread_count or 0),
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

    while True:
        try:
            async with SessionLocal() as session:
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

            now = time.monotonic()
            if now - last_heartbeat >= 15:
                yield ": heartbeat\n\n"
                last_heartbeat = now

            await asyncio.sleep(2)
        except asyncio.CancelledError:
            break


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
