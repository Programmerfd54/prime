import json

from sqlalchemy.ext.asyncio import AsyncSession

from .models import Notification
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
    await send_push(user_id, title, body, payload or {}, session=session)
    return notification
