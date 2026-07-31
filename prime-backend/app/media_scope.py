"""Track upload scope and validate media URLs before message attachment."""

from __future__ import annotations

from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import LocalMediaAsset, MediaUpload, User


async def record_media_upload(
    session: AsyncSession,
    *,
    owner: User,
    media_url: str,
    scope_type: str,
    scope_id: str | None,
) -> None:
    url = media_url.strip()
    if not url:
        return
    existing = await session.scalar(select(MediaUpload).where(MediaUpload.media_url == url))
    if existing is not None:
        if existing.owner_user_id != owner.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Медиафайл принадлежит другому пользователю",
            )
        existing.scope_type = scope_type
        existing.scope_id = scope_id
        session.add(existing)
        return
    session.add(
        MediaUpload(
            id=str(uuid4()),
            owner_user_id=owner.id,
            media_url=url,
            scope_type=scope_type,
            scope_id=scope_id,
        )
    )
    await session.flush()


async def validate_media_url_for_scope(
    session: AsyncSession,
    *,
    owner: User,
    media_url: str | None,
    scope_type: str,
    scope_id: str | None,
) -> None:
    if not media_url:
        return
    url = media_url.strip()
    if not url:
        return
    record = await session.scalar(select(MediaUpload).where(MediaUpload.media_url == url))
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Сначала загрузите файл через защищённый upload",
        )
    if record.owner_user_id != owner.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Медиафайл принадлежит другому пользователю",
        )
    if record.scope_type != scope_type:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Медиафайл загружен для другого контекста",
        )
    if scope_id is not None and record.scope_id not in (None, scope_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Медиафайл загружен для другого контекста",
        )
    if url.startswith("pending://"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Файл ещё проверяется. Подождите завершения проверки.",
        )
    if url.startswith("local://"):
        asset_id = url.removeprefix("local://")
        asset = await session.get(LocalMediaAsset, asset_id)
        if asset is None or asset.processing_status != "CLEAN":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Файл ещё проверяется или отклонён.",
            )
