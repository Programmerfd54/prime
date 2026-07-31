"""18-hour SOCIAL_WRITE restriction management."""

from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import ModerationDecision, User, UserRestriction, utcnow

RESTRICTION_HOURS = 18
SCOPE_SOCIAL_WRITE = "SOCIAL_WRITE"


async def active_social_write_restriction(
    session: AsyncSession,
    user_id: str,
) -> UserRestriction | None:
    now = utcnow()
    row = await session.scalar(
        select(UserRestriction)
        .where(
            UserRestriction.user_id == user_id,
            UserRestriction.scope == SCOPE_SOCIAL_WRITE,
            UserRestriction.status == "ACTIVE",
            UserRestriction.expires_at > now,
        )
        .order_by(UserRestriction.expires_at.desc())
    )
    if row is None:
        return None
    return row


def restriction_payload(restriction: UserRestriction) -> dict:
    return {
        "scope": restriction.scope,
        "reason_code": restriction.reason_code,
        "decision_id": restriction.source_decision_id,
        "starts_at": restriction.starts_at.isoformat(),
        "expires_at": restriction.expires_at.isoformat(),
        "status": restriction.status,
    }


async def apply_profanity_restriction(
    session: AsyncSession,
    *,
    user: User,
    decision: ModerationDecision,
    reason_code: str,
    offense_id: str | None,
) -> UserRestriction | None:
    """Apply 18h restriction for high-confidence profanity; idempotent per offense."""
    if offense_id:
        existing_decision = await session.scalar(
            select(ModerationDecision).where(ModerationDecision.offense_id == offense_id)
        )
        if existing_decision is not None and existing_decision.id != decision.id:
            linked = await session.scalar(
                select(UserRestriction).where(
                    UserRestriction.source_decision_id == existing_decision.id
                )
            )
            return linked

    active = await active_social_write_restriction(session, user.id)
    if active is not None:
        return active

    now = utcnow()
    restriction = UserRestriction(
        id=str(uuid4()),
        user_id=user.id,
        scope=SCOPE_SOCIAL_WRITE,
        reason_code=reason_code,
        source_decision_id=decision.id,
        starts_at=now,
        expires_at=now + timedelta(hours=RESTRICTION_HOURS),
        status="ACTIVE",
    )
    session.add(restriction)
    await session.flush()
    return restriction
