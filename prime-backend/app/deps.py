from datetime import timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .db import get_session
from .models import AuthSession, User, utcnow
from .security import decode_access_token_claims


bearer = HTTPBearer(auto_error=False)


async def get_current_auth_session(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    session: AsyncSession = Depends(get_session),
) -> tuple[AuthSession, User]:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Требуется авторизация",
        )
    claims = decode_access_token_claims(credentials.credentials)
    user_id = claims.get("sub")
    session_id = claims.get("sid")
    if not isinstance(user_id, str) or not isinstance(session_id, str):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Недействительный токен",
        )
    auth_session = await session.scalar(
        select(AuthSession).where(
            AuthSession.id == session_id,
            AuthSession.user_id == user_id,
            AuthSession.revoked_at.is_(None),
            AuthSession.expires_at > utcnow(),
        )
    )
    if auth_session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Сессия истекла или отозвана",
        )
    user = await session.scalar(select(User).where(User.id == user_id))
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Пользователь не найден",
        )
    if user.email_verified_at is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Подтвердите почту, чтобы продолжить",
        )

    # Keep last_seen/session activity writes bounded without letting telemetry
    # failures break an otherwise valid authenticated request.
    try:
        now = utcnow()
        interval = get_settings().last_seen_write_interval_seconds
        last_seen = user.last_seen_at
        if last_seen is not None and last_seen.tzinfo is None:
            last_seen = last_seen.replace(tzinfo=timezone.utc)
        changed = False
        if last_seen is None or interval == 0 or now - last_seen >= timedelta(seconds=interval):
            user.last_seen_at = now
            changed = True
        if auth_session.last_used_at is None or now - auth_session.last_used_at >= timedelta(seconds=interval):
            auth_session.last_used_at = now
            changed = True
        if changed:
            session.add(user)
            session.add(auth_session)
            await session.flush()
    except Exception:
        pass
    return auth_session, user


async def get_current_user(
    current: tuple[AuthSession, User] = Depends(get_current_auth_session),
) -> User:
    return current[1]


async def require_moderator(
    user: User = Depends(get_current_user),
) -> User:
    if not user.is_moderator:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Недостаточно прав")
    return user
