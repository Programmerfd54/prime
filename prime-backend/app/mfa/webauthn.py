"""WebAuthn passkey registration and authentication for moderators."""

from __future__ import annotations

import json
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from webauthn import (
    generate_authentication_options,
    generate_registration_options,
    options_to_json,
    verify_authentication_response,
    verify_registration_response,
)
from webauthn.helpers.structs import (
    AuthenticatorSelectionCriteria,
    PublicKeyCredentialDescriptor,
    ResidentKeyRequirement,
    UserVerificationRequirement,
)

from ..config import get_settings
from ..models import User, WebAuthnCredential
from .totp import create_step_up


_challenges: dict[str, bytes] = {}


def _rp_config():
    settings = get_settings()
    return settings.webauthn_rp_id, settings.webauthn_rp_name, settings.webauthn_origin


async def registration_options(session: AsyncSession, user: User) -> dict:
    rp_id, rp_name, _ = _rp_config()
    existing = (
        await session.scalars(select(WebAuthnCredential).where(WebAuthnCredential.user_id == user.id))
    ).all()
    exclude = [
        PublicKeyCredentialDescriptor(id=bytes.fromhex(row.credential_id))
        for row in existing
        if row.credential_id
    ]
    options = generate_registration_options(
        rp_id=rp_id,
        rp_name=rp_name,
        user_id=user.id.encode("utf-8"),
        user_name=user.email,
        user_display_name=user.name or user.nickname,
        authenticator_selection=AuthenticatorSelectionCriteria(
            resident_key=ResidentKeyRequirement.PREFERRED,
            user_verification=UserVerificationRequirement.PREFERRED,
        ),
        exclude_credentials=exclude,
    )
    _challenges[user.id] = options.challenge
    return json.loads(options_to_json(options))


async def registration_verify(session: AsyncSession, user: User, credential: dict) -> None:
    _, _, origin = _rp_config()
    rp_id, _, _ = _rp_config()
    challenge = _challenges.pop(user.id, None)
    if challenge is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Сессия регистрации истекла")
    verification = verify_registration_response(
        credential=credential,
        expected_challenge=challenge,
        expected_rp_id=rp_id,
        expected_origin=origin,
    )
    cred_id_hex = verification.credential_id.hex()
    session.add(
        WebAuthnCredential(
            id=str(uuid4()),
            user_id=user.id,
            credential_id=cred_id_hex,
            public_key=verification.credential_public_key.hex(),
            sign_count=verification.sign_count,
            transports=",".join(getattr(credential.get("response", {}), "transports", []) or []),
        )
    )
    await session.flush()


async def authentication_options(session: AsyncSession, user: User) -> dict:
    rp_id, _, _ = _rp_config()
    creds = (
        await session.scalars(select(WebAuthnCredential).where(WebAuthnCredential.user_id == user.id))
    ).all()
    if not creds:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Passkey не настроен")
    allow = [PublicKeyCredentialDescriptor(id=bytes.fromhex(row.credential_id)) for row in creds]
    options = generate_authentication_options(
        rp_id=rp_id,
        allow_credentials=allow,
        user_verification=UserVerificationRequirement.PREFERRED,
    )
    _challenges[f"auth:{user.id}"] = options.challenge
    return json.loads(options_to_json(options))


async def authentication_verify(
    session: AsyncSession,
    user: User,
    auth_session_id: str,
    credential: dict,
) -> ModeratorStepUpSession:
    _, _, origin = _rp_config()
    rp_id, _, _ = _rp_config()
    challenge = _challenges.pop(f"auth:{user.id}", None)
    if challenge is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Сессия аутентификации истекла")
    cred_id = credential.get("id") or ""
    stored = await session.scalar(
        select(WebAuthnCredential).where(
            WebAuthnCredential.user_id == user.id,
            WebAuthnCredential.credential_id.contains(cred_id.replace("-", "")[:16]),
        )
    )
    if stored is None:
        creds = (
            await session.scalars(select(WebAuthnCredential).where(WebAuthnCredential.user_id == user.id))
        ).all()
        for row in creds:
            if row.credential_id.startswith(cred_id[:8]) or cred_id in row.credential_id:
                stored = row
                break
    if stored is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Passkey не найден")
    verification = verify_authentication_response(
        credential=credential,
        expected_challenge=challenge,
        expected_rp_id=rp_id,
        expected_origin=origin,
        credential_public_key=bytes.fromhex(stored.public_key),
        credential_current_sign_count=stored.sign_count,
    )
    stored.sign_count = verification.new_sign_count
    session.add(stored)
    return await create_step_up(session, auth_session_id=auth_session_id, user=user, method="webauthn")
