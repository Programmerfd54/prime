"""User moderation restrictions and appeals."""

from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import record_audit
from ..db import get_session
from ..deps import get_current_auth_session, get_current_user, require_moderator_step_up
from ..models import ModerationAppeal, ModerationDecision, User, UserRestriction, utcnow
from ..moderation import active_social_write_restriction, restriction_payload

router = APIRouter(tags=["moderation"])
ops_router = APIRouter(tags=["ops-moderation"])


@router.get("/users/me/restriction")
async def my_restriction(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    restriction = await active_social_write_restriction(session, user.id)
    if restriction is None:
        return {"active": False}
    return {"active": True, **restriction_payload(restriction)}


@router.post("/moderation/appeals", status_code=status.HTTP_201_CREATED)
async def create_appeal(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    decision_id = str(payload.get("decision_id") or "").strip()
    explanation = str(payload.get("explanation") or "").strip()
    if not decision_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="decision_id обязателен")
    decision = await session.get(ModerationDecision, decision_id)
    if decision is None or decision.actor_user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Решение не найдено")
    existing = await session.scalar(
        select(ModerationAppeal).where(ModerationAppeal.decision_id == decision_id)
    )
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Апелляция уже подана")
    appeal = ModerationAppeal(
        id=str(uuid4()),
        user_id=user.id,
        decision_id=decision_id,
        explanation=explanation[:4000],
        status="PENDING",
    )
    session.add(appeal)
    decision.appeal_id = appeal.id
    session.add(decision)
    await record_audit(
        session,
        action="moderation.appeal.created",
        user_id=user.id,
        metadata={"decision_id": decision_id, "appeal_id": appeal.id},
    )
    await session.commit()
    return {"id": appeal.id, "status": appeal.status}


@ops_router.get("/ops/moderation/appeals")
async def list_appeals(
    user: User = Depends(require_moderator_step_up),
    session: AsyncSession = Depends(get_session),
) -> dict:
    rows = (
        await session.scalars(
            select(ModerationAppeal)
            .where(ModerationAppeal.status == "PENDING")
            .order_by(ModerationAppeal.created_at.asc())
            .limit(100)
        )
    ).all()
    return {
        "items": [
            {
                "id": row.id,
                "user_id": row.user_id,
                "decision_id": row.decision_id,
                "explanation": row.explanation,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@ops_router.post("/ops/moderation/appeals/{appeal_id}/resolve")
async def resolve_appeal(
    appeal_id: str,
    payload: dict,
    user: User = Depends(require_moderator_step_up),
    session: AsyncSession = Depends(get_session),
) -> dict:
    resolution = str(payload.get("resolution") or "").strip().upper()
    if resolution not in {"UPHOLD", "REVERSE", "ESCALATE"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Некорректное решение")
    appeal = await session.get(ModerationAppeal, appeal_id)
    if appeal is None or appeal.status != "PENDING":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Апелляция не найдена")
    appeal.status = resolution if resolution != "ESCALATE" else "ESCALATED"
    appeal.resolved_at = utcnow()
    appeal.resolved_by = user.id
    appeal.resolution_reason = str(payload.get("reason") or "")[:255]
    session.add(appeal)

    if resolution == "REVERSE":
        decision = await session.get(ModerationDecision, appeal.decision_id)
        if decision is not None:
            decision.reversed_at = utcnow()
            decision.reviewed_by = user.id
            session.add(decision)
        restriction = await session.scalar(
            select(UserRestriction).where(UserRestriction.source_decision_id == appeal.decision_id)
        )
        if restriction is not None and restriction.status == "ACTIVE":
            restriction.status = "REVOKED_ON_APPEAL"
            restriction.revoked_at = utcnow()
            restriction.revocation_reason = "appeal_reversed"
            session.add(restriction)

    await record_audit(
        session,
        action="moderation.appeal.resolved",
        user_id=user.id,
        metadata={"appeal_id": appeal_id, "resolution": resolution},
    )
    await session.commit()
    return {"id": appeal.id, "status": appeal.status}
