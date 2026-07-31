"""Public email endpoints (unsubscribe landing pages)."""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..email_unsubscribe import (
    LETTER_MARKETING,
    letter_label,
    parse_unsubscribe_token,
)
from ..models import User, utcnow

router = APIRouter(prefix="/email", tags=["email"])
logger = logging.getLogger("prime.email")


def _success_page(*, title: str, body: str, email: str, letter: str) -> str:
    letter_name = letter_label(letter)
    return f"""<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>{title} · ПРАЙМ</title>
    <style>
      body {{
        margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        background: #F4F2F8; color: #1A1524; padding: 32px 16px;
      }}
      .card {{
        max-width: 520px; margin: 0 auto; background: #fff; border-radius: 24px;
        padding: 32px; box-shadow: 0 12px 40px rgba(109,40,217,0.08);
      }}
      .badge {{
        display: inline-block; padding: 8px 14px; border-radius: 999px;
        background: linear-gradient(135deg, #8B5CF6, #6D28D9); color: #fff;
        font-size: 12px; font-weight: 700; letter-spacing: 2px;
      }}
      h1 {{ margin: 20px 0 12px; font-size: 28px; line-height: 1.2; }}
      p {{ margin: 0 0 12px; line-height: 1.65; color: #5C5468; }}
      .meta {{ font-size: 13px; color: #7C6B96; margin-top: 20px; }}
    </style>
  </head>
  <body>
    <div class="card">
      <div class="badge">ПРАЙМ</div>
      <h1>{title}</h1>
      <p>{body}</p>
      <p class="meta">Почта: {email}<br/>Письмо: {letter_name}</p>
    </div>
  </body>
</html>"""


@router.get("/unsubscribe", response_class=HTMLResponse)
async def unsubscribe_by_token(
    token: str = Query(min_length=8),
    session: AsyncSession = Depends(get_session),
) -> HTMLResponse:
    payload = parse_unsubscribe_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ссылка отписки недействительна или устарела",
        )

    user = await session.scalar(select(User).where(User.id == payload.user_id))
    if user is None or not user.is_active or user.email.lower() != payload.email:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Аккаунт не найден",
        )

    # Marketing opt-out applies to newsletter-style mail. Transactional signup
    # letters still include the link so users can opt out of future tips.
    if payload.letter in {LETTER_MARKETING, "signup_verification", "password_reset"}:
        user.marketing_emails_opt_in = False
        user.marketing_emails_unsubscribed_at = utcnow()
        session.add(user)
        await session.commit()
        logger.info(
            "marketing_unsubscribed",
            extra={"user_id": user.id, "letter": payload.letter},
        )

    html = _success_page(
        title="Вы отписались от рассылки",
        body=(
            "Мы больше не будем присылать новости, советы и подборки от ПРАЙМ "
            "на эту почту. Служебные письма — подтверждение входа, безопасность — "
            "могут приходить, когда это необходимо."
        ),
        email=user.email,
        letter=payload.letter,
    )
    return HTMLResponse(content=html, status_code=200)
