"""Public email endpoints (unsubscribe landing pages)."""
from __future__ import annotations

import logging
import re
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..email_unsubscribe import (
    apply_marketing_unsubscribe,
    lookup_unsubscribe_token,
)
from ..email_unsubscribe_pages import (
    already_unsubscribed_page,
    expired_page,
    invalid_page,
    success_page,
)
from ..models import User, utcnow
from ..rate_limit import enforce as enforce_rate_limit
from ..rate_limit import record_failure as record_rate_limit_failure

router = APIRouter(tags=["email-public"])
logger = logging.getLogger("prime.email")

_TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9_-]{16,128}$")
_REFERRER_POLICY = {"Referrer-Policy": "no-referrer"}


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _html_response(content: str, *, status_code: int = 200) -> HTMLResponse:
    return HTMLResponse(
        content=content,
        status_code=status_code,
        headers=_REFERRER_POLICY,
    )


async def _enforce_unsubscribe_rate_limit(session: AsyncSession, request: Request) -> None:
    settings = get_settings()
    client = request.client.host if request.client else "unknown"
    key = f"email:unsubscribe:ip:{client}"
    await enforce_rate_limit(
        session,
        key,
        limit=settings.email_unsubscribe_rate_limit_attempts,
        window_seconds=settings.email_unsubscribe_rate_limit_window_seconds,
        detail="Слишком много запросов. Попробуйте позже.",
    )
    await record_rate_limit_failure(
        session,
        key,
        window_seconds=settings.email_unsubscribe_rate_limit_window_seconds,
    )


async def _process_unsubscribe(
    *,
    token: str,
    session: AsyncSession,
    request: Request,
) -> HTMLResponse:
    await _enforce_unsubscribe_rate_limit(session, request)

    normalized = token.strip()
    if not _TOKEN_PATTERN.fullmatch(normalized):
        return _html_response(invalid_page(), status_code=400)

    token_row = await lookup_unsubscribe_token(session, normalized)
    if token_row is None:
        return _html_response(invalid_page(), status_code=404)

    if token_row.used_at is not None:
        user = await session.scalar(select(User).where(User.id == token_row.user_id))
        email = user.email if user is not None else "—"
        return _html_response(already_unsubscribed_page(email=email))

    if token_row.expires_at is not None and _as_utc(token_row.expires_at) < utcnow():
        return _html_response(expired_page(), status_code=410)

    user = await session.scalar(select(User).where(User.id == token_row.user_id))
    if user is None or not user.is_active:
        return _html_response(invalid_page(), status_code=404)

    if not user.marketing_emails_opt_in:
        if token_row.used_at is None:
            token_row.used_at = utcnow()
            session.add(token_row)
            await session.commit()
        return _html_response(already_unsubscribed_page(email=user.email))

    applied = await apply_marketing_unsubscribe(
        session,
        user=user,
        token_row=token_row,
    )
    if not applied:
        return _html_response(already_unsubscribed_page(email=user.email))

    logger.info(
        "marketing_unsubscribed",
        extra={"user_id": user.id, "letter": token_row.letter},
    )
    return _html_response(
        success_page(email=user.email, letter=token_row.letter),
    )


@router.get("/unsubscribe/{token}", response_class=HTMLResponse)
async def unsubscribe_by_token(
    token: str,
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> HTMLResponse:
    return await _process_unsubscribe(token=token, session=session, request=request)


@router.post("/unsubscribe/{token}", response_class=HTMLResponse)
async def unsubscribe_one_click(
    token: str,
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> HTMLResponse:
    """RFC 8058 one-click unsubscribe from List-Unsubscribe-Post."""
    return await _process_unsubscribe(token=token, session=session, request=request)
