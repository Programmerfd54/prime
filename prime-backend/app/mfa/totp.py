"""Moderator MFA: TOTP, backup codes, WebAuthn, step-up sessions."""

from __future__ import annotations

import hashlib
import secrets
from datetime import timedelta
from uuid import uuid4

import pyotp
from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..models import (
    ModeratorBackupCode,
    ModeratorStepUpSession,
    ModeratorTotpSecret,
    User,
    utcnow,
)
from ..secret_box import decrypt_secret, encrypt_secret


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.strip().upper().encode("utf-8")).hexdigest()


def generate_backup_codes(count: int = 8) -> list[str]:
    return [secrets.token_hex(4).upper() for _ in range(count)]


async def enroll_totp(session: AsyncSession, user: User) -> tuple[str, str]:
    secret = pyotp.random_base32()
    existing = await session.get(ModeratorTotpSecret, user.id)
    if existing is None:
        existing = ModeratorTotpSecret(user_id=user.id, secret_encrypted=encrypt_secret(secret))
    else:
        existing.secret_encrypted = encrypt_secret(secret)
    session.add(existing)
    await session.flush()
    totp = pyotp.TOTP(secret)
    uri = totp.provisioning_uri(name=user.email, issuer_name=get_settings().webauthn_rp_name)
    return secret, uri


async def confirm_totp(session: AsyncSession, user: User, code: str) -> list[str]:
    row = await session.get(ModeratorTotpSecret, user.id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Сначала начните настройку TOTP")
    secret = decrypt_secret(row.secret_encrypted)
    if not secret or not pyotp.TOTP(secret).verify(code, valid_window=1):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный код")
    await session.execute(delete(ModeratorBackupCode).where(ModeratorBackupCode.user_id == user.id))
    codes = generate_backup_codes()
    for plain in codes:
        session.add(
            ModeratorBackupCode(
                id=str(uuid4()),
                user_id=user.id,
                code_hash=_hash_code(plain),
            )
        )
    await session.flush()
    return codes


async def verify_totp(session: AsyncSession, user: User, code: str) -> bool:
    row = await session.get(ModeratorTotpSecret, user.id)
    if row is None:
        return False
    secret = decrypt_secret(row.secret_encrypted)
    if not secret:
        return False
    return pyotp.TOTP(secret).verify(code, valid_window=1)


async def verify_backup_code(session: AsyncSession, user: User, code: str) -> bool:
    code_hash = _hash_code(code)
    row = await session.scalar(
        select(ModeratorBackupCode).where(
            ModeratorBackupCode.user_id == user.id,
            ModeratorBackupCode.code_hash == code_hash,
            ModeratorBackupCode.used_at.is_(None),
        )
    )
    if row is None:
        return False
    row.used_at = utcnow()
    session.add(row)
    await session.flush()
    return True


async def create_step_up(
    session: AsyncSession,
    *,
    auth_session_id: str,
    user: User,
    method: str,
) -> ModeratorStepUpSession:
    settings = get_settings()
    now = utcnow()
    step_up = ModeratorStepUpSession(
        id=str(uuid4()),
        auth_session_id=auth_session_id,
        user_id=user.id,
        method=method,
        verified_at=now,
        expires_at=now + timedelta(minutes=settings.moderator_step_up_ttl_minutes),
    )
    session.add(step_up)
    await session.flush()
    return step_up


async def has_valid_step_up(session: AsyncSession, auth_session_id: str, user_id: str) -> bool:
    now = utcnow()
    row = await session.scalar(
        select(ModeratorStepUpSession)
        .where(
            ModeratorStepUpSession.auth_session_id == auth_session_id,
            ModeratorStepUpSession.user_id == user_id,
            ModeratorStepUpSession.expires_at > now,
        )
        .order_by(ModeratorStepUpSession.expires_at.desc())
    )
    return row is not None
