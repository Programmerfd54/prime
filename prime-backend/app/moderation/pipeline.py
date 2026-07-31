"""Pre-publish moderation pipeline."""

from __future__ import annotations

from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import record_audit
from ..models import ModerationDecision, User
from .profanity import ClassificationResult, ConfidenceBand, classify_text
from .restrictions import active_social_write_restriction, apply_profanity_restriction


class ModerationError(Exception):
    def __init__(
        self,
        *,
        code: str,
        message: str,
        expires_at: str | None = None,
        confidence: str | None = None,
    ) -> None:
        self.code = code
        self.message = message
        self.expires_at = expires_at
        self.confidence = confidence
        super().__init__(message)


async def check_social_write_allowed(session: AsyncSession, user: User) -> None:
    restriction = await active_social_write_restriction(session, user.id)
    if restriction is None:
        return
    raise ModerationError(
        code="SOCIAL_WRITE_RESTRICTED",
        message=(
            "Публикация временно ограничена. Отправка сообщений и комментариев "
            f"будет доступна {restriction.expires_at.isoformat()}."
        ),
        expires_at=restriction.expires_at.isoformat(),
    )


def moderation_http_error(exc: ModerationError) -> HTTPException:
    detail: dict = {"code": exc.code, "message": exc.message}
    if exc.expires_at:
        detail["expires_at"] = exc.expires_at
    if exc.confidence:
        detail["confidence"] = exc.confidence
    return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


async def moderate_text_before_publish(
    session: AsyncSession,
    *,
    user: User,
    text: str,
    content_type: str,
    offense_id: str | None = None,
    draft_id: str | None = None,
) -> ClassificationResult:
    await check_social_write_allowed(session, user)

    if not (text or "").strip():
        from .profanity import classify_text as _classify

        return _classify("")

    result = classify_text(text)
    if result.allowed:
        return result

    decision = ModerationDecision(
        id=str(uuid4()),
        actor_user_id=user.id,
        content_type=content_type,
        content_id_or_draft_id=draft_id,
        language=result.language.value if result.language else None,
        category=result.category or "PROFANITY",
        confidence_band=result.confidence.value,
        action="REJECTED" if result.confidence == ConfidenceBand.HIGH else "QUARANTINED",
        policy_version=result.policy_version,
        detector_version=result.detector_version,
        normalized_content_hash=result.normalized_hash,
        offense_id=offense_id,
    )
    session.add(decision)
    await session.flush()
    await record_audit(
        session,
        action="moderation.decision",
        user_id=user.id,
        metadata={
            "decision_id": decision.id,
            "category": decision.category,
            "confidence": decision.confidence_band,
            "action": decision.action,
        },
    )

    if result.confidence == ConfidenceBand.HIGH:
        await apply_profanity_restriction(
            session,
            user=user,
            decision=decision,
            reason_code=result.category or "PROFANITY_MIXED",
            offense_id=offense_id,
        )
        raise ModerationError(
            code="PROFANITY_REJECTED",
            message=(
                "Сообщение не опубликовано: система обнаружила ненормативную лексику. "
                f"Отправка сообщений будет доступна позже."
            ),
            confidence=result.confidence.value,
        )

    if result.confidence == ConfidenceBand.MEDIUM:
        raise ModerationError(
            code="PROFANITY_QUARANTINED",
            message=(
                "Мы не опубликовали текст, потому что он может нарушать правила общения. "
                "Измените формулировку или отправьте на проверку."
            ),
            confidence=result.confidence.value,
        )

    return result
