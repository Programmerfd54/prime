import json
from datetime import timedelta
from sqlalchemy import select

from sqlalchemy.ext.asyncio import AsyncSession

from .direct_message_events import NotificationPush, direct_message_hub
from .models import Notification, OutboxEvent, utcnow
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
                    "payload": payload or {},
                }
            ),
        )
    )
    direct_message_hub.publish_notification(
        user_id,
        NotificationPush(notification=notification_payload(notification)),
    )
    return notification


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
