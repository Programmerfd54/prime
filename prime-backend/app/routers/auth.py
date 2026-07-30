import hashlib
import hmac
import logging
import math
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import get_current_auth_session
from ..mailer import build_password_reset_email, build_verification_email, send_email
from ..models import AuthSession, EmailVerificationCode, PasswordResetToken, User, utcnow
from ..nicknames import validate_nickname
from ..rate_limit import enforce as enforce_rate_limit
from ..rate_limit import record_failure as record_rate_limit_failure
from ..schemas import (
    EmailAvailabilityResponse,
    ForgotPasswordRequest,
    LoginRequest,
    NicknameAvailabilityResponse,
    RefreshTokenRequest,
    RegisterRequest,
    RegistrationPendingResponse,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from ..security import hash_password, verify_password
from ..sessions import hash_refresh_token, issue_session, revoke_session, revoke_user_sessions


router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger("prime.auth")
# Compatibility handles for older unit fixtures; counters are now persisted
# in rate_limit_buckets and are never trusted for enforcement.
_login_failures: dict[str, list[float]] = {}
_verification_failures: dict[str, list[float]] = {}
def _fingerprint(value: str) -> str:
    return hashlib.sha256(value.strip().lower().encode("utf-8")).hexdigest()[:12]


def _login_rate_keys(request: Request, email: str, prefix: str = "auth") -> tuple[str, str]:
    client = request.client.host if request.client else "unknown"
    normalized_email = email.strip().lower()
    return (f"{prefix}:ip:{client}", f"{prefix}:email:{normalized_email}")


async def _enforce_auth_limit(
    session: AsyncSession,
    request: Request,
    email: str,
    *,
    detail: str,
) -> None:
    settings = get_settings()
    if not settings.auth_login_rate_limit_enabled:
        return
    for key in _login_rate_keys(request, email):
        await enforce_rate_limit(
            session,
            key,
            limit=settings.auth_login_rate_limit_attempts,
            window_seconds=settings.auth_login_rate_limit_window_seconds,
            detail=detail,
        )


async def _record_auth_failure(
    session: AsyncSession,
    request: Request,
    email: str,
) -> None:
    await _record_rate_limit_keys(
        session,
        _login_rate_keys(request, email),
        window_seconds=get_settings().auth_login_rate_limit_window_seconds,
    )


async def _record_rate_limit_keys(
    session: AsyncSession,
    keys: tuple[str, str],
    *,
    window_seconds: int,
) -> None:
    for key in keys:
        await record_rate_limit_failure(
            session,
            key,
            window_seconds=window_seconds,
        )


async def _issue_tokens(
    session: AsyncSession,
    user: User,
    request: Request,
) -> TokenResponse:
    access_token, refresh_token = await issue_session(session, user, request)
    await session.commit()
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _hash_verification_code(user_id: str, code: str) -> str:
    """Keyed digest: a leaked table cannot be brute-forced without the secret."""
    settings = get_settings()
    return hmac.new(
        settings.jwt_secret_key.encode("utf-8"),
        f"{user_id}:{code}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _expose_verification_code() -> bool:
    settings = get_settings()
    return settings.email_verification_expose_code or settings.enable_dev_tools


async def _seconds_until_resend_allowed(session: AsyncSession, user_id: str) -> int:
    settings = get_settings()
    cooldown = settings.email_verification_resend_cooldown_seconds
    if cooldown <= 0:
        return 0
    last_sent_at = await session.scalar(
        select(func.max(EmailVerificationCode.created_at)).where(
            EmailVerificationCode.user_id == user_id
        )
    )
    if last_sent_at is None:
        return 0
    elapsed = (utcnow() - _as_utc(last_sent_at)).total_seconds()
    return max(0, math.ceil(cooldown - elapsed))


async def _issue_verification_code(
    session: AsyncSession,
    user: User,
    background_tasks: BackgroundTasks,
) -> tuple[str, datetime]:
    """Invalidates outstanding codes, stores a fresh one, queues the email."""
    settings = get_settings()
    now = utcnow()
    await session.execute(
        update(EmailVerificationCode)
        .where(
            EmailVerificationCode.user_id == user.id,
            EmailVerificationCode.used_at.is_(None),
        )
        .values(used_at=now)
    )
    code = f"{secrets.randbelow(1_000_000):06d}"
    expires_at = now + timedelta(minutes=settings.email_verification_code_ttl_minutes)
    session.add(
        EmailVerificationCode(
            user_id=user.id,
            code_hash=_hash_verification_code(user.id, code),
            expires_at=expires_at,
        )
    )
    await session.commit()

    subject, text_body, html_body = build_verification_email(
        name=user.name,
        code=code,
        ttl_minutes=settings.email_verification_code_ttl_minutes,
    )
    background_tasks.add_task(
        send_email,
        to=user.email,
        subject=subject,
        text_body=text_body,
        html_body=html_body,
    )
    logger.info(
        "email_verification_code_issued",
        extra={
            "user_id": user.id,
            "expires_at": expires_at.isoformat(),
            # Local dev usually has no mail server, so the code goes to the log.
            "verification_code": code if _expose_verification_code() else None,
        },
    )
    return code, expires_at


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


@router.get("/nickname-available/{nickname}", response_model=NicknameAvailabilityResponse)
async def nickname_available(
    nickname: str,
    session: AsyncSession = Depends(get_session),
    request: Request = None,
) -> NicknameAvailabilityResponse:
    """Public pre-check used during signup — no auth required."""
    settings = get_settings()
    if request is not None and settings.auth_login_rate_limit_enabled:
        client = request.client.host if request.client else "unknown"
        await enforce_rate_limit(
            session,
            f"auth:lookup:ip:{client}",
            limit=60,
            window_seconds=settings.auth_login_rate_limit_window_seconds,
            detail="Слишком много запросов. Попробуйте позже.",
        )
    try:
        normalized = validate_nickname(nickname)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    owner = await session.scalar(select(User).where(User.nickname == normalized))
    return NicknameAvailabilityResponse(available=owner is None)


@router.get("/email-available", response_model=EmailAvailabilityResponse)
async def email_available(
    email: str,
    session: AsyncSession = Depends(get_session),
    request: Request = None,
) -> EmailAvailabilityResponse:
    """Public pre-check used during signup — no auth required."""
    settings = get_settings()
    normalized = email.strip().lower()
    if not normalized or "@" not in normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Введите корректный email",
        )
    if request is not None and settings.auth_login_rate_limit_enabled:
        client = request.client.host if request.client else "unknown"
        await enforce_rate_limit(
            session,
            f"auth:lookup:ip:{client}",
            limit=60,
            window_seconds=settings.auth_login_rate_limit_window_seconds,
            detail="Слишком много запросов. Попробуйте позже.",
        )
    user = await session.scalar(select(User).where(User.email == normalized))
    if user is None:
        return EmailAvailabilityResponse(available=True, pending_verification=False)
    if user.email_verified_at is not None:
        return EmailAvailabilityResponse(available=False, pending_verification=False)
    return EmailAvailabilityResponse(available=False, pending_verification=True)


@router.post(
    "/register",
    response_model=RegistrationPendingResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    payload: RegisterRequest,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_session),
    request: Request = None,
) -> RegistrationPendingResponse:
    """Creates an unverified account and emails a confirmation code.

    No access token is issued here: the client must call verify-email.
    """
    settings = get_settings()
    if request is not None:
        await _enforce_auth_limit(
            session,
            request,
            payload.email,
            detail="Слишком много регистраций. Попробуйте позже.",
        )
        await _record_rate_limit_keys(
            session,
            _login_rate_keys(request, payload.email, "register"),
            window_seconds=settings.auth_login_rate_limit_window_seconds,
        )
    existing = await session.scalar(select(User).where(User.email == payload.email))
    if existing is not None and existing.email_verified_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Аккаунт с такой почтой уже существует",
        )

    nickname = validate_nickname(payload.nickname)
    nickname_owner = await session.scalar(select(User).where(User.nickname == nickname))
    if nickname_owner is not None and (
        existing is None or nickname_owner.id != existing.id
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Никнейм уже занят",
        )

    if existing is None:
        user = User(
            email=payload.email,
            password_hash=hash_password(payload.password),
            name=payload.name.strip(),
            nickname=nickname,
        )
    else:
        # The address was never confirmed, so nobody owns it yet: let the
        # signup be restarted instead of dead-ending on a 409.
        user = existing
        user.password_hash = hash_password(payload.password)
        user.name = payload.name.strip()
        user.nickname = nickname
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
    code, expires_at = await _issue_verification_code(session, user, background_tasks)
    logger.info("user_registered", extra={"user_id": user.id})
    return RegistrationPendingResponse(
        email=user.email,
        expires_at=expires_at,
        resend_available_in_seconds=settings.email_verification_resend_cooldown_seconds,
        verification_code=code if _expose_verification_code() else None,
    )


@router.post("/verify-email", response_model=TokenResponse)
async def verify_email(
    request: Request,
    payload: VerifyEmailRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    """Confirms the signup code and issues the first access token."""
    settings = get_settings()
    verify_keys = _login_rate_keys(request, payload.email, "verify")
    for key in verify_keys:
        await enforce_rate_limit(
            session,
            key,
            limit=settings.auth_login_rate_limit_attempts,
            window_seconds=settings.auth_login_rate_limit_window_seconds,
            detail="Слишком много попыток подтверждения. Попробуйте позже.",
        )
    invalid = HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Код подтверждения недействителен или истёк",
    )

    user = await session.scalar(select(User).where(User.email == payload.email))
    if user is None or not user.is_active:
        for key in verify_keys:
            await record_rate_limit_failure(
                session,
                key,
                window_seconds=settings.auth_login_rate_limit_window_seconds,
            )
        raise invalid
    if user.email_verified_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Почта уже подтверждена. Войдите в аккаунт.",
        )

    row = await session.scalar(
        select(EmailVerificationCode)
        .where(
            EmailVerificationCode.user_id == user.id,
            EmailVerificationCode.used_at.is_(None),
        )
        .order_by(EmailVerificationCode.created_at.desc())
        .limit(1)
    )
    if row is None or _as_utc(row.expires_at) < utcnow():
        for key in verify_keys:
            await record_rate_limit_failure(
                session,
                key,
                window_seconds=settings.auth_login_rate_limit_window_seconds,
            )
        raise invalid
    if row.attempts >= settings.email_verification_max_attempts:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Слишком много попыток. Запросите новый код.",
        )

    expected = _hash_verification_code(user.id, payload.code)
    if not hmac.compare_digest(row.code_hash, expected):
        row.attempts += 1
        session.add(row)
        await session.commit()
        for key in verify_keys:
            await record_rate_limit_failure(
                session,
                key,
                window_seconds=settings.auth_login_rate_limit_window_seconds,
            )
        logger.info(
            "email_verification_failed",
            extra={"user_id": user.id, "attempts": row.attempts},
        )
        remaining = settings.email_verification_max_attempts - row.attempts
        detail = "Неверный код подтверждения"
        if remaining > 0:
            detail = f"{detail}. Осталось попыток: {remaining}"
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)

    now = utcnow()
    row.used_at = now
    user.email_verified_at = now
    session.add_all([row, user])
    await session.commit()
    logger.info("email_verified", extra={"user_id": user.id})
    return await _issue_tokens(session, user, request)


@router.post("/resend-verification")
async def resend_verification(
    payload: ResendVerificationRequest,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_session),
    request: Request = None,
) -> dict:
    """Always returns the same shape to avoid email enumeration."""
    settings = get_settings()
    if request is not None:
        for key in _login_rate_keys(request, payload.email, "resend"):
            await enforce_rate_limit(
                session,
                key,
                limit=3,
                window_seconds=settings.email_verification_resend_cooldown_seconds or 60,
                detail="Слишком много запросов. Попробуйте позже.",
            )
        await _record_rate_limit_keys(
            session,
            _login_rate_keys(request, payload.email, "resend"),
            window_seconds=settings.email_verification_resend_cooldown_seconds or 60,
        )
    response: dict = {
        "status": "ok",
        "message": (
            "Если регистрация не завершена, мы отправили новый код на эту почту."
        ),
        "resend_available_in_seconds": (
            settings.email_verification_resend_cooldown_seconds
        ),
        "code_ttl_minutes": settings.email_verification_code_ttl_minutes,
    }
    user = await session.scalar(select(User).where(User.email == payload.email))
    if user is None or not user.is_active or user.email_verified_at is not None:
        return response

    wait_seconds = await _seconds_until_resend_allowed(session, user.id)
    if wait_seconds > 0:
        response["resend_available_in_seconds"] = wait_seconds
        return response

    code, _ = await _issue_verification_code(session, user, background_tasks)
    if _expose_verification_code():
        response["verification_code"] = code
    return response


@router.post("/login", response_model=TokenResponse)
async def login(
    request: Request,
    payload: LoginRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    await _enforce_auth_limit(
        session,
        request,
        payload.email,
        detail="Слишком много попыток входа. Попробуйте позже.",
    )

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
        await _record_auth_failure(session, request, payload.email)
        logger.info("login_failed", extra={"email_hash": _fingerprint(payload.email)})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверная почта или пароль",
        )

    if user.email_verified_at is None:
        # Credentials were correct, so this is not a failed attempt — the
        # signup simply was never confirmed. 403 tells the client to show
        # the confirmation step instead of a password error.
        logger.info("login_blocked_unverified", extra={"user_id": user.id})
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Подтвердите почту, чтобы войти. Запросите новый код.",
        )

    logger.info(
        "login_success",
        extra={
            "user_id": user.id,
            "developer_mode": dev_passwordless_ok,
        },
    )
    return await _issue_tokens(session, user, request)


def _hash_reset_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


@router.post("/forgot-password")
async def forgot_password(
    payload: ForgotPasswordRequest,
    session: AsyncSession = Depends(get_session),
    request: Request = None,
    background_tasks: BackgroundTasks = None,
) -> dict:
    """Always returns the same shape to avoid email enumeration."""
    settings = get_settings()
    if request is not None:
        for key in _login_rate_keys(request, payload.email, "reset"):
            await enforce_rate_limit(
                session,
                key,
                limit=settings.password_reset_rate_limit_attempts,
                window_seconds=settings.password_reset_rate_limit_window_seconds,
                detail="Слишком много запросов. Попробуйте позже.",
            )
        await _record_rate_limit_keys(
            session,
            _login_rate_keys(request, payload.email, "reset"),
            window_seconds=settings.password_reset_rate_limit_window_seconds,
        )
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
    subject, text_body, html_body = build_password_reset_email(
        name=user.name,
        token=raw_token,
        ttl_minutes=settings.password_reset_token_ttl_minutes,
    )
    if background_tasks is not None:
        background_tasks.add_task(
            send_email,
            to=user.email,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
        )
    logger.info(
        "password_reset_token_created",
        extra={
            "user_id": user.id,
            "expires_at": expires_at.isoformat(),
            "delivery": "email",
        },
    )
    return response


@router.post("/reset-password")
async def reset_password(
    payload: ResetPasswordRequest,
    session: AsyncSession = Depends(get_session),
    request: Request = None,
) -> dict:
    settings = get_settings()
    if request is not None:
        for key in _login_rate_keys(request, payload.token, "reset-token"):
            await enforce_rate_limit(
                session,
                key,
                limit=settings.password_reset_rate_limit_attempts,
                window_seconds=settings.password_reset_rate_limit_window_seconds,
                detail="Слишком много запросов. Попробуйте позже.",
            )
        await _record_rate_limit_keys(
            session,
            _login_rate_keys(request, payload.token, "reset-token"),
            window_seconds=settings.password_reset_rate_limit_window_seconds,
        )
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
    await revoke_user_sessions(session, user.id)
    session.add(user)
    session.add(row)
    await session.commit()
    logger.info("password_reset_success", extra={"user_id": user.id})
    return {"status": "ok"}


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    payload: RefreshTokenRequest,
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> TokenResponse:
    auth_session = await session.scalar(
        select(AuthSession).where(
            AuthSession.refresh_token_hash == hash_refresh_token(payload.refresh_token),
            AuthSession.revoked_at.is_(None),
            AuthSession.expires_at > utcnow(),
        ).with_for_update()
    )
    if auth_session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh-сессия недействительна",
        )
    user = await session.scalar(
        select(User).where(User.id == auth_session.user_id, User.is_active.is_(True))
    )
    if user is None:
        await session.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Пользователь не найден")
    await revoke_session(session, auth_session)
    return await _issue_tokens(session, user, request)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    current: tuple[AuthSession, User] = Depends(get_current_auth_session),
    session: AsyncSession = Depends(get_session),
) -> None:
    await revoke_session(session, current[0])
    await session.commit()
