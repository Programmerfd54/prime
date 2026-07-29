import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .db import SessionLocal
from .models import DeviceToken

logger = logging.getLogger("prime.push")


async def send_push(
    user_id: str,
    title: str,
    body: str,
    data: dict | None = None,
    *,
    session: AsyncSession | None = None,
) -> None:
    payload = data or {}
    if session is not None:
        tokens = (
            await session.execute(
                select(DeviceToken).where(DeviceToken.user_id == user_id)
            )
        ).scalars().all()
    else:
        async with SessionLocal() as owned_session:
            tokens = (
                await owned_session.execute(
                    select(DeviceToken).where(DeviceToken.user_id == user_id)
                )
            ).scalars().all()
    for device in tokens:
        logger.info(
            "push_stub user=%s platform=%s token=%s title=%r body=%r data=%s",
            user_id,
            device.platform,
            device.token[:12] + "...",
            title,
            body,
            payload,
        )
