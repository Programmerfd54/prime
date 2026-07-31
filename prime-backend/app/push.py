"""Production push delivery through FCM HTTP v1 and APNs.

Device tokens are never logged. FCM can deliver Android, iOS and web tokens;
direct APNs is available for installations that register native APNs tokens.
"""

from __future__ import annotations

import asyncio
import base64
from datetime import datetime, timedelta, timezone
import json
import logging
from pathlib import Path
from typing import Any

import httpx
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .db import SessionLocal
from .models import DeviceToken

logger = logging.getLogger("prime.push")

_fcm_access_token: str | None = None
_fcm_access_token_expires_at: datetime | None = None
_fcm_token_lock = asyncio.Lock()
_apns_jwt: str | None = None
_apns_jwt_created_at: datetime | None = None
_apns_token_lock = asyncio.Lock()


def _b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _json_segment(value: dict[str, Any]) -> str:
    return _b64url(json.dumps(value, separators=(",", ":")).encode("utf-8"))


def _service_account() -> dict[str, Any]:
    settings = get_settings()
    raw = settings.fcm_service_account_json.strip()
    if raw:
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as error:
            raise RuntimeError("FCM_SERVICE_ACCOUNT_JSON is invalid JSON") from error
    elif settings.fcm_service_account_file.strip():
        path = Path(settings.fcm_service_account_file).expanduser()
        try:
            parsed = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise RuntimeError("FCM service-account file cannot be read") from error
    else:
        raise RuntimeError("FCM credentials are not configured")
    if not isinstance(parsed, dict):
        raise RuntimeError("FCM service account must be an object")
    return parsed


async def _fcm_oauth_token() -> tuple[str, str]:
    global _fcm_access_token, _fcm_access_token_expires_at
    now = datetime.now(timezone.utc)
    if (
        _fcm_access_token
        and _fcm_access_token_expires_at
        and _fcm_access_token_expires_at > now + timedelta(minutes=2)
    ):
        settings = get_settings()
        account = _service_account()
        return _fcm_access_token, settings.fcm_project_id or str(account.get("project_id") or "")

    async with _fcm_token_lock:
        now = datetime.now(timezone.utc)
        if (
            _fcm_access_token
            and _fcm_access_token_expires_at
            and _fcm_access_token_expires_at > now + timedelta(minutes=2)
        ):
            settings = get_settings()
            account = _service_account()
            return _fcm_access_token, settings.fcm_project_id or str(account.get("project_id") or "")

        account = _service_account()
        client_email = str(account.get("client_email") or "")
        private_key_pem = str(account.get("private_key") or "").replace("\\n", "\n")
        project_id = get_settings().fcm_project_id or str(account.get("project_id") or "")
        if not client_email or not private_key_pem or not project_id:
            raise RuntimeError("FCM service account is missing required fields")
        issued_at = int(now.timestamp())
        header = {"alg": "RS256", "typ": "JWT"}
        claims = {
            "iss": client_email,
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": "https://oauth2.googleapis.com/token",
            "iat": issued_at,
            "exp": issued_at + 3600,
        }
        unsigned = f"{_json_segment(header)}.{_json_segment(claims)}"
        private_key = serialization.load_pem_private_key(
            private_key_pem.encode("utf-8"),
            password=None,
        )
        signature = private_key.sign(
            unsigned.encode("ascii"),
            padding.PKCS1v15(),
            hashes.SHA256(),
        )
        assertion = f"{unsigned}.{_b64url(signature)}"
        timeout = get_settings().push_timeout_seconds
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                "https://oauth2.googleapis.com/token",
                data={
                    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    "assertion": assertion,
                },
            )
        response.raise_for_status()
        response_payload = response.json()
        _fcm_access_token = str(response_payload["access_token"])
        expires_in = int(response_payload.get("expires_in") or 3600)
        _fcm_access_token_expires_at = now + timedelta(seconds=expires_in)
        return _fcm_access_token, project_id


def _string_data(data: dict[str, Any]) -> dict[str, str]:
    result: dict[str, str] = {}
    for key, value in data.items():
        if value is None:
            continue
        if isinstance(value, (dict, list)):
            result[str(key)] = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        elif isinstance(value, bool):
            result[str(key)] = "true" if value else "false"
        else:
            result[str(key)] = str(value)
    return result


async def _send_fcm(device: DeviceToken, title: str, body: str, data: dict[str, Any]) -> bool:
    access_token, project_id = await _fcm_oauth_token()
    aps = {"sound": "default", "content-available": 1}
    if data.get("type") == "early_start_request":
        aps["category"] = "PRIME_EARLY_START"
    message = {
        "token": device.token,
        "notification": {"title": title, "body": body},
        "data": _string_data(data),
        "android": {
            "priority": "high",
            "notification": {
                "click_action": "PRIME_NOTIFICATION_OPEN",
                "channel_id": "prime_team",
            },
        },
        "apns": {
            "headers": {"apns-priority": "10"},
            "payload": {"aps": aps},
        },
        "webpush": {"headers": {"Urgency": "high"}},
    }
    async with httpx.AsyncClient(timeout=get_settings().push_timeout_seconds) as client:
        response = await client.post(
            f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"message": message},
        )
    if response.status_code in {400, 404} and (
        "UNREGISTERED" in response.text or "registration-token-not-registered" in response.text
    ):
        return False
    response.raise_for_status()
    return True


async def _apns_authorization() -> str:
    global _apns_jwt, _apns_jwt_created_at
    now = datetime.now(timezone.utc)
    if _apns_jwt and _apns_jwt_created_at and _apns_jwt_created_at > now - timedelta(minutes=50):
        return _apns_jwt
    async with _apns_token_lock:
        now = datetime.now(timezone.utc)
        if _apns_jwt and _apns_jwt_created_at and _apns_jwt_created_at > now - timedelta(minutes=50):
            return _apns_jwt
        settings = get_settings()
        private_key_pem = settings.apns_private_key.strip().replace("\\n", "\n")
        if not settings.apns_key_id or not settings.apns_team_id or not private_key_pem:
            raise RuntimeError("APNs credentials are not configured")
        header = {"alg": "ES256", "kid": settings.apns_key_id}
        claims = {"iss": settings.apns_team_id, "iat": int(now.timestamp())}
        unsigned = f"{_json_segment(header)}.{_json_segment(claims)}"
        private_key = serialization.load_pem_private_key(private_key_pem.encode("utf-8"), password=None)
        der_signature = private_key.sign(unsigned.encode("ascii"), ec.ECDSA(hashes.SHA256()))
        r_value, s_value = decode_dss_signature(der_signature)
        raw_signature = r_value.to_bytes(32, "big") + s_value.to_bytes(32, "big")
        _apns_jwt = f"{unsigned}.{_b64url(raw_signature)}"
        _apns_jwt_created_at = now
        return _apns_jwt


async def _send_apns(device: DeviceToken, title: str, body: str, data: dict[str, Any]) -> bool:
    settings = get_settings()
    if not settings.apns_bundle_id:
        raise RuntimeError("APNS_BUNDLE_ID is not configured")
    authorization = await _apns_authorization()
    host = "api.sandbox.push.apple.com" if settings.apns_use_sandbox else "api.push.apple.com"
    aps = {"alert": {"title": title, "body": body}, "sound": "default"}
    if data.get("type") == "early_start_request":
        aps["category"] = "PRIME_EARLY_START"
    payload = {**data, "aps": aps}
    async with httpx.AsyncClient(http2=True, timeout=settings.push_timeout_seconds) as client:
        response = await client.post(
            f"https://{host}/3/device/{device.token}",
            headers={
                "authorization": f"bearer {authorization}",
                "apns-topic": settings.apns_bundle_id,
                "apns-push-type": "alert",
                "apns-priority": "10",
            },
            json=payload,
        )
    if response.status_code == 410 or (
        response.status_code == 400 and "BadDeviceToken" in response.text
    ):
        return False
    response.raise_for_status()
    return True


async def send_push(
    user_id: str,
    title: str,
    body: str,
    data: dict | None = None,
    *,
    session: AsyncSession | None = None,
) -> None:
    payload = data or {}
    owns_session = session is None
    active_session = session
    if active_session is None:
        active_session = SessionLocal()
    try:
        tokens = (
            await active_session.execute(
                select(DeviceToken).where(DeviceToken.user_id == user_id)
            )
        ).scalars().all()
        errors: list[Exception] = []
        for device in tokens:
            try:
                valid = (
                    await _send_apns(device, title, body, payload)
                    if device.provider == "apns"
                    else await _send_fcm(device, title, body, payload)
                )
                if not valid:
                    await active_session.delete(device)
                    logger.info("push_token_removed user=%s platform=%s provider=%s", user_id, device.platform, device.provider)
            except Exception as error:
                errors.append(error)
                logger.warning(
                    "push_delivery_failed user=%s platform=%s provider=%s error=%s",
                    user_id,
                    device.platform,
                    device.provider,
                    type(error).__name__,
                )
        if owns_session:
            await active_session.commit()
        if errors:
            raise RuntimeError(f"push delivery failed for {len(errors)} device(s)") from errors[0]
    finally:
        if owns_session:
            await active_session.close()
