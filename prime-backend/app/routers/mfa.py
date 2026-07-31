"""Moderator MFA enrollment and step-up authentication."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import record_audit
from ..db import get_session
from ..deps import get_current_auth_session, get_current_user
from ..moderator_features import ensure_moderator_features_enabled
from ..mfa import (
    authentication_options,
    authentication_verify,
    confirm_totp,
    create_step_up,
    enroll_totp,
    registration_options,
    registration_verify,
    verify_backup_code,
    verify_totp,
)
from ..models import User

router = APIRouter(prefix="/auth/mfa", tags=["auth-mfa"])


def _require_moderator_user(user: User) -> User:
    ensure_moderator_features_enabled()
    if not user.is_moderator:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Недостаточно прав")
    return user


@router.post("/totp/enroll")
async def totp_enroll(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    _require_moderator_user(user)
    secret, uri = await enroll_totp(session, user)
    await session.commit()
    return {"otpauth_uri": uri}


@router.post("/totp/verify")
async def totp_verify(
    payload: dict,
    auth: tuple = Depends(get_current_auth_session),
    session: AsyncSession = Depends(get_session),
) -> dict:
    auth_session, user = auth
    _require_moderator_user(user)
    code = str(payload.get("code") or "").strip()
    if payload.get("confirm_enrollment"):
        backup_codes = await confirm_totp(session, user, code)
        await create_step_up(session, auth_session_id=auth_session.id, user=user, method="totp")
        await record_audit(session, action="mfa.totp.enrolled", user_id=user.id)
        await session.commit()
        return {"status": "enrolled", "backup_codes": backup_codes}
    if not await verify_totp(session, user, code):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный код")
    await create_step_up(session, auth_session_id=auth_session.id, user=user, method="totp")
    await record_audit(session, action="mfa.totp.step_up", user_id=user.id)
    await session.commit()
    return {"status": "ok"}


@router.post("/backup-code/verify")
async def backup_code_verify(
    payload: dict,
    auth: tuple = Depends(get_current_auth_session),
    session: AsyncSession = Depends(get_session),
) -> dict:
    auth_session, user = auth
    _require_moderator_user(user)
    code = str(payload.get("code") or "").strip()
    if not await verify_backup_code(session, user, code):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный код восстановления")
    await create_step_up(session, auth_session_id=auth_session.id, user=user, method="backup_code")
    await record_audit(session, action="mfa.backup_code.step_up", user_id=user.id)
    await session.commit()
    return {"status": "ok"}


@router.post("/webauthn/register/options")
async def webauthn_register_options(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    _require_moderator_user(user)
    return await registration_options(session, user)


@router.post("/webauthn/register/verify")
async def webauthn_register_verify(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    _require_moderator_user(user)
    await registration_verify(session, user, payload.get("credential") or {})
    await record_audit(session, action="mfa.webauthn.registered", user_id=user.id)
    await session.commit()
    return {"status": "registered"}


@router.post("/webauthn/authenticate/options")
async def webauthn_auth_options(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    _require_moderator_user(user)
    return await authentication_options(session, user)


@router.post("/webauthn/authenticate/verify")
async def webauthn_auth_verify(
    payload: dict,
    auth: tuple = Depends(get_current_auth_session),
    session: AsyncSession = Depends(get_session),
) -> dict:
    auth_session, user = auth
    _require_moderator_user(user)
    await authentication_verify(session, user, auth_session.id, payload.get("credential") or {})
    await record_audit(session, action="mfa.webauthn.step_up", user_id=user.id)
    await session.commit()
    return {"status": "ok"}
