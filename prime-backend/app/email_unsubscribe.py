"""Opaque unsubscribe links embedded in outgoing mail."""
from __future__ import annotations

import hashlib
import secrets
from datetime import timedelta

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .models import EmailUnsubscribeToken, User, utcnow

# Letter ids identify the campaign / template in the unsubscribe link.
LETTER_SIGNUP_VERIFICATION = "signup_verification"
LETTER_PASSWORD_RESET = "password_reset"
LETTER_MARKETING = "marketing"

MARKETING_LETTERS = frozenset(
    {LETTER_MARKETING, LETTER_SIGNUP_VERIFICATION, LETTER_PASSWORD_RESET}
)


def letter_label(letter: str) -> str:
    return {
        LETTER_SIGNUP_VERIFICATION: "Подтверждение регистрации",
        LETTER_PASSWORD_RESET: "Восстановление пароля",
        LETTER_MARKETING: "Новости и советы ПРАЙМ",
    }.get(letter, "Рассылка ПРАЙМ")


def hash_unsubscribe_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def build_unsubscribe_url(raw_token: str) -> str:
    settings = get_settings()
    base = settings.public_mail_base_url.rstrip("/")
    return f"{base}/unsubscribe/{raw_token}"


async def create_unsubscribe_link(
    session: AsyncSession,
    *,
    user_id: str,
    letter: str,
) -> str:
    """Persist an opaque token and return the public unsubscribe URL."""
    settings = get_settings()
    raw_token = secrets.token_urlsafe(32)
    expires_at = utcnow() + timedelta(days=settings.email_unsubscribe_token_ttl_days)
    session.add(
        EmailUnsubscribeToken(
            token_hash=hash_unsubscribe_token(raw_token),
            user_id=user_id,
            letter=letter,
            expires_at=expires_at,
        )
    )
    await session.commit()
    return build_unsubscribe_url(raw_token)


async def lookup_unsubscribe_token(
    session: AsyncSession,
    raw_token: str,
) -> EmailUnsubscribeToken | None:
    token_hash = hash_unsubscribe_token(raw_token.strip())
    return await session.scalar(
        select(EmailUnsubscribeToken).where(EmailUnsubscribeToken.token_hash == token_hash)
    )


async def apply_marketing_unsubscribe(
    session: AsyncSession,
    *,
    user: User,
    token_row: EmailUnsubscribeToken,
) -> bool:
    """Mark token used and opt the user out of marketing mail. Returns False if already used."""
    if token_row.used_at is not None:
        return False
    now = utcnow()
    if token_row.letter in MARKETING_LETTERS:
        user.marketing_emails_opt_in = False
        user.marketing_emails_unsubscribed_at = now
        session.add(user)
    token_row.used_at = now
    session.add(token_row)
    await session.commit()
    return True


async def cleanup_expired_unsubscribe_tokens(session: AsyncSession) -> int:
    """Delete tokens that expired more than 7 days ago."""
    cutoff = utcnow() - timedelta(days=7)
    result = await session.execute(
        delete(EmailUnsubscribeToken).where(EmailUnsubscribeToken.expires_at < cutoff)
    )
    await session.commit()
    return int(result.rowcount or 0)
