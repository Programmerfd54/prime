import hashlib
import hmac
import logging
import asyncio
import random
from pathlib import Path
from uuid import uuid4
from urllib.parse import quote

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .models import LocalMediaAsset, User
from .secret_box import decrypt_secret, encrypt_secret


logger = logging.getLogger("prime.matrix")
_matrix_semaphore = asyncio.Semaphore(1)
_matrix_retry_attempts = 3
MAX_MATRIX_DOWNLOAD_BYTES = 100 * 1024 * 1024


def _settings():
    return get_settings()


def matrix_available() -> bool:
    settings = _settings()
    return bool(
        settings.matrix_enabled
        and settings.matrix_shared_secret
        and settings.matrix_token_encryption_key
        and settings.matrix_password_secret
    )


def _matrix_retry_delay(response: httpx.Response, attempt: int) -> float:
    retry_after = response.headers.get("retry-after")
    if retry_after:
        try:
            return max(0.5, min(float(retry_after), 3.0))
        except ValueError:
            pass
    try:
        retry_after_ms = response.json().get("retry_after_ms")
        if retry_after_ms is not None:
            return max(0.5, min(float(retry_after_ms) / 1000, 3.0))
    except Exception:
        pass
    return min(3.0, 1.2 * (attempt + 1)) + random.uniform(0.1, 0.4)


def _localpart(user: User) -> str:
    return f"prime_{user.id.replace('-', '')}"


def _password(user: User) -> str:
    settings = _settings()
    raw = f"{settings.matrix_password_secret}:{user.id}:matrix".encode()
    return hashlib.sha256(raw).hexdigest()


def _access_token(user: User) -> str | None:
    return decrypt_secret(user.matrix_access_token)


def _set_access_token(user: User, token: str | None) -> None:
    user.matrix_access_token = encrypt_secret(token) if token else None


async def migrate_legacy_tokens(session: AsyncSession) -> int:
    """Encrypt pre-existing plaintext Matrix tokens once a key is configured."""
    if not _settings().matrix_token_encryption_key:
        return 0
    rows = (
        await session.execute(
            select(User).where(
                User.matrix_access_token.is_not(None),
                ~User.matrix_access_token.startswith("v1:"),
            )
        )
    ).scalars().all()
    for user in rows:
        _set_access_token(user, user.matrix_access_token)
        session.add(user)
    if rows:
        await session.commit()
    return len(rows)


def _public_base_url() -> str:
    settings = _settings()
    return settings.matrix_public_base_url or settings.matrix_base_url


async def _store_local_media(
    user: User,
    session: AsyncSession,
    filename: str,
    content_type: str,
    data: bytes,
    scope_type: str = "owner",
    scope_id: str | None = None,
) -> str:
    storage_key = uuid4().hex
    directory = Path("uploads/private-media")
    directory.mkdir(parents=True, exist_ok=True)
    (directory / storage_key).write_bytes(data)
    asset = LocalMediaAsset(
        owner_user_id=user.id,
        storage_key=storage_key,
        content_type=content_type,
        filename=Path(filename).name[:500],
        size_bytes=len(data),
        scope_type=scope_type,
        scope_id=scope_id,
    )
    session.add(asset)
    await session.flush()
    return f"local://{asset.id}"


def mxc_to_http(mxc_url: str | None) -> str | None:
    if not mxc_url or not mxc_url.startswith("mxc://"):
        if mxc_url and mxc_url.startswith("local://"):
            return f"/api/v1/local-media/{quote(mxc_url.removeprefix('local://'), safe='')}"
        return mxc_url
    server_media = mxc_url.removeprefix("mxc://")
    if "/" not in server_media:
        return mxc_url
    server, media_id = server_media.split("/", 1)
    return f"/api/v1/media/{quote(server, safe='')}/{quote(media_id, safe='')}"


async def download_media(user: User, server: str, media_id: str) -> tuple[bytes, str]:
    access_token = _access_token(user)
    if not matrix_available() or not access_token:
        raise RuntimeError("Matrix media is unavailable")
    settings = _settings()
    async with httpx.AsyncClient(base_url=settings.matrix_base_url, timeout=30) as client:
        async with client.stream(
            "GET",
            f"/_matrix/client/v1/media/download/{quote(server, safe='')}/{quote(media_id, safe='')}",
            headers={"Authorization": f"Bearer {access_token}"},
        ) as response:
            response.raise_for_status()
            chunks: list[bytes] = []
            total = 0
            async for chunk in response.aiter_bytes(1024 * 1024):
                total += len(chunk)
                if total > MAX_MATRIX_DOWNLOAD_BYTES:
                    raise ValueError("Matrix media response is too large")
                chunks.append(chunk)
            return b"".join(chunks), response.headers.get("content-type", "application/octet-stream")


async def _register_user(localpart: str, password: str) -> dict | None:
    settings = _settings()
    async with _matrix_semaphore:
        async with httpx.AsyncClient(
            base_url=settings.matrix_base_url,
            timeout=20,
        ) as client:
            for attempt in range(_matrix_retry_attempts):
                nonce_response = await client.get("/_synapse/admin/v1/register")
                if nonce_response.status_code == 429:
                    await asyncio.sleep(_matrix_retry_delay(nonce_response, attempt))
                    continue
                nonce_response.raise_for_status()
                nonce = nonce_response.json()["nonce"]
                msg = f"{nonce}\x00{localpart}\x00{password}\x00notadmin".encode()
                mac = hmac.new(
                    settings.matrix_shared_secret.encode(),
                    msg,
                    hashlib.sha1,
                ).hexdigest()
                response = await client.post(
                    "/_synapse/admin/v1/register",
                    json={
                        "nonce": nonce,
                        "username": localpart,
                        "password": password,
                        "admin": False,
                        "mac": mac,
                    },
                )
                if response.status_code == 200:
                    return response.json()
                if response.status_code == 400:
                    return None
                if response.status_code == 429:
                    await asyncio.sleep(_matrix_retry_delay(response, attempt))
                    continue
                response.raise_for_status()
            response.raise_for_status()
            return None


async def _login_user(localpart: str, password: str) -> dict:
    settings = _settings()
    async with _matrix_semaphore:
        async with httpx.AsyncClient(
            base_url=settings.matrix_base_url,
            timeout=20,
        ) as client:
            for attempt in range(_matrix_retry_attempts):
                response = await client.post(
                    "/_matrix/client/v3/login",
                    json={
                        "type": "m.login.password",
                        "identifier": {"type": "m.id.user", "user": localpart},
                        "password": password,
                    },
                )
                if response.status_code != 429:
                    response.raise_for_status()
                    return response.json()
                await asyncio.sleep(_matrix_retry_delay(response, attempt))
            response.raise_for_status()
            return response.json()


async def ensure_matrix_user(user: User, session: AsyncSession, *, strict: bool = False) -> User:
    if not matrix_available():
        return user

    if _access_token(user) and user.matrix_user_id:
        if user.matrix_access_token and not user.matrix_access_token.startswith("v1:"):
            _set_access_token(user, _access_token(user))
            session.add(user)
            await session.flush()
        return user

    localpart = _localpart(user)
    password = _password(user)
    try:
        login = await _register_user(localpart, password)
        if login is None:
            login = await _login_user(localpart, password)
    except Exception:
        logger.exception("matrix_user_setup_failed_using_local_fallback", extra={"user_id": user.id})
        if strict:
            raise
        return user

    user.matrix_user_id = login.get("user_id")
    _set_access_token(user, login.get("access_token"))
    session.add(user)
    await session.flush()
    return user


async def create_room(
    creator: User,
    invitees: list[User],
    name: str,
) -> str | None:
    creator_token = _access_token(creator)
    if not matrix_available() or not creator_token:
        return None

    settings = _settings()
    invites = [
        item.matrix_user_id
        for item in invitees
        if item.matrix_user_id and item.matrix_user_id != creator.matrix_user_id
    ]
    try:
        async with _matrix_semaphore:
            async with httpx.AsyncClient(
                base_url=settings.matrix_base_url,
                timeout=20,
            ) as client:
                response: httpx.Response | None = None
                for attempt in range(_matrix_retry_attempts):
                    response = await client.post(
                        "/_matrix/client/v3/createRoom",
                        headers={"Authorization": f"Bearer {creator_token}"},
                        json={
                            "preset": "private_chat",
                            "name": name,
                            "invite": invites,
                            "initial_state": [
                                {
                                    "type": "m.room.guest_access",
                                    "state_key": "",
                                    "content": {"guest_access": "forbidden"},
                                }
                            ],
                        },
                    )
                    if response.status_code != 429:
                        response.raise_for_status()
                        break
                    await asyncio.sleep(_matrix_retry_delay(response, attempt))
                if response is None:
                    return None
                response.raise_for_status()
                room_id = response.json().get("room_id")
    except Exception:
        logger.exception(
            "matrix_room_create_failed_using_local_history",
            extra={"user_id": creator.id},
        )
        return None
    if room_id:
        for invitee in invitees:
            if not _access_token(invitee):
                continue
            try:
                await join_room(invitee, room_id)
            except Exception:
                logger.exception(
                    "matrix_invitee_join_failed",
                    extra={"user_id": invitee.id, "room_id": room_id},
                )
    return room_id


async def join_room(user: User, room_id: str) -> None:
    user_token = _access_token(user)
    if not matrix_available() or not user_token:
        return
    settings = _settings()
    encoded_room_id = quote(room_id, safe="")
    async with httpx.AsyncClient(base_url=settings.matrix_base_url, timeout=10) as client:
        response = await client.post(
            f"/_matrix/client/v3/join/{encoded_room_id}",
            headers={"Authorization": f"Bearer {user_token}"},
            json={},
        )
        response.raise_for_status()


async def send_room_message(
    sender: User,
    room_id: str | None,
    content: dict,
    *,
    txn_id: str | None = None,
) -> str:
    sender_token = _access_token(sender)
    if not matrix_available() or not room_id or not sender_token:
        return f"local-{txn_id or uuid4().hex}"

    settings = _settings()
    txn_id = txn_id or uuid4().hex
    encoded_room_id = quote(room_id, safe="")
    try:
        async with httpx.AsyncClient(
            base_url=settings.matrix_base_url,
            timeout=10,
        ) as client:
            response = await client.put(
                f"/_matrix/client/v3/rooms/{encoded_room_id}/send/m.room.message/{txn_id}",
                headers={"Authorization": f"Bearer {sender_token}"},
                json=content,
            )
            if response.status_code == 403:
                await join_room(sender, room_id)
                response = await client.put(
                    f"/_matrix/client/v3/rooms/{encoded_room_id}/send/m.room.message/{txn_id}",
                    headers={"Authorization": f"Bearer {sender_token}"},
                    json=content,
                )
            response.raise_for_status()
            return response.json().get("event_id") or f"local-{uuid4()}"
    except Exception:
        logger.exception(
            "matrix_message_send_failed_using_local_history",
            extra={"user_id": sender.id, "room_id": room_id},
        )
        return f"local-{uuid4()}"


async def upload_media(
    user: User,
    session: AsyncSession,
    filename: str,
    content_type: str,
    data: bytes,
    scope_type: str = "owner",
    scope_id: str | None = None,
) -> str:
    user_token = _access_token(user)
    if not matrix_available() or not user_token:
        return await _store_local_media(
            user,
            session,
            filename,
            content_type,
            data,
            scope_type,
            scope_id,
        )

    settings = _settings()
    try:
        async with httpx.AsyncClient(
            base_url=settings.matrix_base_url,
            timeout=30,
        ) as client:
            response = await client.post(
                "/_matrix/media/v3/upload",
                params={"filename": filename},
                headers={
                    "Authorization": f"Bearer {user_token}",
                    "Content-Type": content_type,
                },
                content=data,
            )
            response.raise_for_status()
            return response.json()["content_uri"]
    except Exception:
        logger.exception(
            "matrix_media_upload_failed_using_local_storage",
            extra={"user_id": user.id},
        )
        return await _store_local_media(
            user,
            session,
            filename,
            content_type,
            data,
            scope_type,
            scope_id,
        )
