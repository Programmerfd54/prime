"""Moderator-only operational metrics without a new infrastructure service."""

from datetime import timezone

from fastapi import APIRouter, Depends
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import engine, get_session
from ..deps import require_moderator_step_up
from ..direct_message_events import direct_message_hub
from ..models import OutboxEvent, User, utcnow
from ..observability import request_metrics_snapshot

router = APIRouter(tags=["operations"])


@router.get("/ops/metrics")
async def operational_metrics(
    user: User = Depends(require_moderator_step_up),
    session: AsyncSession = Depends(get_session),
) -> dict:
    pending, oldest, failed = (
        await session.execute(
            select(
                func.count(OutboxEvent.id),
                func.min(OutboxEvent.available_at),
                func.sum(
                    case(
                        (OutboxEvent.attempts > 0, 1),
                        else_=0,
                    )
                ),
            ).where(OutboxEvent.processed_at.is_(None))
        )
    ).one()
    now = utcnow()
    if oldest is not None and oldest.tzinfo is None:
        oldest = oldest.replace(tzinfo=timezone.utc)
    return {
        "requests": request_metrics_snapshot(),
        "realtime": {
            "sse_connections": direct_message_hub.active_connections,
            "subscribed_users": direct_message_hub.subscribed_users,
            "queued_events": direct_message_hub.queued_events,
        },
        "push_outbox": {
            "pending": int(pending or 0),
            "retrying": int(failed or 0),
            "oldest_lag_seconds": (
                max(0, int((now - oldest).total_seconds()))
                if oldest is not None
                else 0
            ),
        },
        "database_pool": engine.pool.status(),
    }
