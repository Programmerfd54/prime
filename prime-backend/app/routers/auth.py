import hashlib
import logging
import secrets
import time
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..models import PasswordResetToken, User, utcnow
from ..nicknames import validate_nickname
from ..schemas import (
    ForgotPasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from ..security import create_access_token, hash_password, verify_password


router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger("prime.auth")
_login_failures: dict[str, list[float]] = {}


def _fingerprint(value: str) -> str:
    return hashlib.sha256(value.strip().lower().encode("utf-8")).hexdigest()[:12]


def _login_rate_key(request: Request, email: str) -> str:
    client = request.client.host if request.client else "unknown"
    return f"{client}:{email.strip().lower()}"


def _check_login_rate_limit(key: str) -> None:
    settings = get_settings()
    if not settings.auth_login_rate_limit_enabled:
        return

    now = time.monotonic()
    window_started_at = now - settings.auth_login_rate_limit_window_seconds
    recent = [
        item
        for item in _login_failures.get(key, [])
        if item >= window_started_at
    ]
    _login_failures[key] = recent
    if len(recent) >= settings.auth_login_rate_limit_attempts:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Слишком много попыток входа. Попробуйте позже.",
        )


def _record_login_failure(key: str) -> None:
    settings = get_settings()
    if not settings.auth_login_rate_limit_enabled:
        return
    _login_failures.setdefault(key, []).append(time.monotonic())


def _clear_login_failures(key: str) -> None:
    _login_failures.pop(key, None)


def _dev_passwordless_allowed(email: str) -> bool:
    settings = get_settings()
    if not settings.enable_dev_tools:
        return False
    allowed = {
        item.strip().lower()
        for item in settings.dev_passwordless_emails.split(",")
        if item.strip()
    }
    return email.lower() in allowed


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    existing = await session.scalar(select(User.id).where(User.email == payload.email))
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Аккаунт с такой почтой уже существует",
        )

    nickname = validate_nickname(payload.nickname)
    existing_nickname = await session.scalar(select(User.id).where(User.nickname == nickname))
    if existing_nickname is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Никнейм уже занят",
        )

    user = User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        name=payload.name.strip(),
        nickname=nickname,
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Аккаунт с такой почтой или никнеймом уже существует",
        ) from None

    await session.refresh(user)
    logger.info("user_registered", extra={"user_id": user.id})
    return TokenResponse(access_token=create_access_token(user.id))


@router.post("/login", response_model=TokenResponse)
async def login(
    request: Request,
    payload: LoginRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    rate_key = _login_rate_key(request, payload.email)
    _check_login_rate_limit(rate_key)

    user = await session.scalar(select(User).where(User.email == payload.email))
    password_ok = (
        user is not None
        and bool(payload.password)
        and verify_password(payload.password, user.password_hash)
    )
    dev_passwordless_ok = (
        user is not None
        and payload.developer_mode
        and _dev_passwordless_allowed(payload.email)
    )
    if user is None or not (password_ok or dev_passwordless_ok):
        _record_login_failure(rate_key)
        logger.info("login_failed", extra={"email_hash": _fingerprint(payload.email)})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверная почта или пароль",
        )

    _clear_login_failures(rate_key)
    logger.info(
        "login_success",
        extra={
            "user_id": user.id,
            "developer_mode": dev_passwordless_ok,
        },
    )
    return TokenResponse(access_token=create_access_token(user.id))


def _hash_reset_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


@router.post("/forgot-password")
async def forgot_password(
    payload: ForgotPasswordRequest,
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Always returns the same shape to avoid email enumeration."""
    settings = get_settings()
    response: dict = {
        "status": "ok",
        "message": (
            "Если аккаунт с этой почтой существует, "
            "используйте код восстановления для смены пароля."
        ),
    }
    user = await session.scalar(select(User).where(User.email == payload.email))
    if user is None:
        return response

    raw_token = secrets.token_urlsafe(32)
    expires_at = utcnow() + timedelta(minutes=settings.password_reset_token_ttl_minutes)
    session.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=_hash_reset_token(raw_token),
            expires_at=expires_at,
        )
    )
    await session.commit()
    logger.info(
        "password_reset_token_created",
        extra={
            "user_id": user.id,
            "expires_at": expires_at.isoformat(),
            "expose_token": settings.password_reset_expose_token,
        },
    )
    if settings.password_reset_expose_token or settings.enable_dev_tools:
        response["reset_token"] = raw_token
        response["expires_at"] = expires_at.isoformat()
    return response


@router.post("/reset-password")
async def reset_password(
    payload: ResetPasswordRequest,
    session: AsyncSession = Depends(get_session),
) -> dict:
    token_hash = _hash_reset_token(payload.token)
    row = await session.scalar(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
    )
    now = utcnow()
    if (
        row is None
        or row.used_at is not None
        or _as_utc(row.expires_at) < now
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Код восстановления недействителен или истёк",
        )
    user = await session.scalar(select(User).where(User.id == row.user_id))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Код восстановления недействителен или истёк",
        )
    user.password_hash = hash_password(payload.new_password)
    row.used_at = now
    session.add(user)
    session.add(row)
    await session.commit()
    logger.info("password_reset_success", extra={"user_id": user.id})
    return {"status": "ok"}
