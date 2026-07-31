"""Access/refresh session lifecycle and revocation helpers."""

from __future__ import annotations

import hashlib
import secrets
from datetime import timedelta

from fastapi import Request
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .models import AuthSession, User, utcnow
from .security import create_access_token
from .direct_message_events import SessionRevokedPush, direct_message_hub


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def issue_session(
    session: AsyncSession,
    user: User,
    request: Request | None = None,
) -> tuple[str, str]:
    refresh_token = secrets.token_urlsafe(48)
    auth_session = AuthSession(
        user_id=user.id,
        refresh_token_hash=hash_refresh_token(refresh_token),
        expires_at=utcnow() + timedelta(days=get_settings().refresh_token_expire_days),
        user_agent=(getattr(request, "headers", {}).get("user-agent", "")[:512] if request else None),
        ip_address=(request.client.host[:64] if request and request.client else None),
    )
    session.add(auth_session)
    await session.flush()
    return create_access_token(user.id, session_id=auth_session.id), refresh_token


async def revoke_session(session: AsyncSession, auth_session: AuthSession) -> None:
    auth_session.revoked_at = utcnow()
    session.add(auth_session)
    await session.flush()
    direct_message_hub.publish_session_revoked(
        auth_session.user_id,
        SessionRevokedPush(session_id=auth_session.id),
    )


async def revoke_user_sessions(session: AsyncSession, user_id: str) -> None:
    await session.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=utcnow())
    )
    direct_message_hub.publish_session_revoked(
        user_id,
        SessionRevokedPush(session_id="*"),
    )
