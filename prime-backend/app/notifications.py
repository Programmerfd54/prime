import json
from collections.abc import Iterable
from datetime import timedelta
from sqlalchemy import select

from sqlalchemy.ext.asyncio import AsyncSession

from .direct_message_events import NotificationPush, direct_message_hub
from .models import GroupMember, Notification, OutboxEvent, utcnow
from .push import send_push


def notification_payload(notification: Notification) -> dict:
    try:
        payload = json.loads(notification.payload or "{}")
    except json.JSONDecodeError:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    return {
        "id": notification.id,
        "type": notification.type,
        "title": notification.title,
        "body": notification.body,
        "payload": payload,
        "read": notification.read_at is not None,
        "created_at": notification.created_at.isoformat(),
    }


async def create_notification(
    session: AsyncSession,
    user_id: str,
    type: str,
    title: str,
    body: str,
    payload: dict | None = None,
) -> Notification:
    push_payload = {
        **(payload or {}),
        "type": type,
    }
    notification = Notification(
        user_id=user_id,
        type=type,
        title=title,
        body=body,
        payload=json.dumps(payload or {}),
    )
    session.add(notification)
    await session.flush()
    session.add(
        OutboxEvent(
            topic="push.notification",
            aggregate_id=notification.id,
            payload=json.dumps(
                {
                    "user_id": user_id,
                    "title": title,
                    "body": body,
                    "payload": push_payload,
                }
            ),
        )
    )
    direct_message_hub.publish_notification(
        user_id,
        NotificationPush(notification=notification_payload(notification)),
    )
    return notification


async def notify_users(
    session: AsyncSession,
    user_ids: Iterable[str],
    *,
    type: str,
    title: str,
    body: str,
    payload: dict | None = None,
    exclude_user_id: str | None = None,
) -> None:
    seen: set[str] = set()
    for user_id in user_ids:
        if not user_id or user_id in seen:
            continue
        if exclude_user_id and user_id == exclude_user_id:
            continue
        seen.add(user_id)
        await create_notification(session, user_id, type, title, body, payload or {})


async def notify_group_members(
    session: AsyncSession,
    *,
    group_id: str,
    type: str,
    title: str,
    body: str,
    payload: dict | None = None,
    exclude_user_id: str | None = None,
) -> None:
    member_ids = list((
        await session.execute(
            select(GroupMember.user_id).where(
                GroupMember.group_id == group_id,
                GroupMember.active.is_(True),
            )
        )
    ).scalars().all())
    merged_payload = {
        "group_id": group_id,
        "deep_link": f"prime://groups/{group_id}",
        **(payload or {}),
    }
    await notify_users(
        session,
        member_ids,
        type=type,
        title=title,
        body=body,
        payload=merged_payload,
        exclude_user_id=exclude_user_id,
    )


def chat_message_preview(body: str, msgtype: str) -> str:
    text = (body or "").strip()
    if text:
        return text if len(text) <= 120 else f"{text[:117]}…"
    return {
        "m.image": "📷 Фото",
        "m.video": "🎬 Видео",
        "m.audio": "🎤 Аудио",
        "m.file": "📎 Файл",
        "prime.video_note": "🎥 Видеокружок",
    }.get(msgtype, "Новое сообщение")


async def process_outbox_once(session: AsyncSession, *, batch_size: int = 50) -> int:
    events = (
        await session.execute(
            select(OutboxEvent)
            .where(OutboxEvent.processed_at.is_(None), OutboxEvent.available_at <= utcnow())
            .order_by(OutboxEvent.created_at.asc())
            .with_for_update(skip_locked=True)
            .limit(batch_size)
        )
    ).scalars().all()
    processed = 0
    for event in events:
        try:
            payload = json.loads(event.payload or "{}")
            if event.topic == "push.notification":
                await send_push(
                    str(payload["user_id"]),
                    str(payload["title"]),
                    str(payload["body"]),
                    payload.get("payload") if isinstance(payload.get("payload"), dict) else {},
                    session=session,
                )
            event.processed_at = utcnow()
            event.last_error = None
            processed += 1
        except Exception as error:
            event.attempts += 1
            event.last_error = str(error)[:1000]
            event.available_at = utcnow() + timedelta(seconds=min(300, 2 ** min(event.attempts, 8)))
        session.add(event)
    if events:
        await session.commit()
    return processed
