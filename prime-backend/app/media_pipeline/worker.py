"""Async media quarantine worker."""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path

from uuid import uuid4

from sqlalchemy import select

from ..config import get_settings
from ..db import SessionLocal
from ..media import normalize_image
from ..models import LocalMediaAsset, MediaUpload, utcnow
from .clamav_scanner import ClamAvScanner
from .noop_scanner import NoopScanner
from .scanner import ScanVerdict


logger = logging.getLogger("prime.media_pipeline")
MAX_SCAN_ATTEMPTS = 5


def _scanner():
    if get_settings().media_scanner.strip().lower() == "clamav":
        return ClamAvScanner()
    return NoopScanner()


async def process_asset_once(session, asset: LocalMediaAsset) -> None:
    path = Path("uploads/private-media") / asset.storage_key
    if not path.exists():
        asset.processing_status = "REJECTED"
        asset.last_scan_error = "file_missing"
        session.add(asset)
        return

    data = path.read_bytes()
    asset.processing_status = "SCANNING"
    asset.scan_attempts += 1
    session.add(asset)
    await session.flush()

    result = await _scanner().scan(data, content_type=asset.content_type)
    if result.verdict == ScanVerdict.INFECTED:
        asset.processing_status = "REJECTED"
        asset.last_scan_error = result.detail
        session.add(asset)
        return
    if result.verdict == ScanVerdict.ERROR:
        asset.last_scan_error = result.detail
        if asset.scan_attempts >= MAX_SCAN_ATTEMPTS:
            asset.processing_status = "REJECTED"
        else:
            asset.processing_status = "QUARANTINE"
        session.add(asset)
        return

    if asset.content_type.startswith("image/"):
        try:
            data, asset.content_type = normalize_image(data, asset.content_type)
            path.write_bytes(data)
        except Exception as exc:
            asset.processing_status = "POLICY_BLOCKED"
            asset.last_scan_error = str(exc)
            session.add(asset)
            return

    published = f"local://{asset.id}"
    asset.processing_status = "CLEAN"
    asset.published_media_url = published
    session.add(asset)

    pending_url = f"pending://{asset.id}"
    pending = await session.scalar(select(MediaUpload).where(MediaUpload.media_url == pending_url))
    if pending is not None:
        pending.media_url = published
        session.add(pending)
    else:
        existing = await session.scalar(select(MediaUpload).where(MediaUpload.media_url == published))
        if existing is None:
            session.add(
                MediaUpload(
                    id=str(uuid4()),
                    owner_user_id=asset.owner_user_id,
                    media_url=published,
                    scope_type=asset.scope_type,
                    scope_id=asset.scope_id,
                )
            )


async def process_quarantine_batch(session) -> int:
    assets = (
        await session.scalars(
            select(LocalMediaAsset)
            .where(LocalMediaAsset.processing_status.in_(("QUARANTINE", "SCANNING")))
            .order_by(LocalMediaAsset.created_at.asc())
            .limit(10)
        )
    ).all()
    for asset in assets:
        if asset.processing_status == "SCANNING" and asset.scan_attempts > 0:
            asset.processing_status = "QUARANTINE"
        await process_asset_once(session, asset)
    await session.commit()
    return len(assets)


async def run_media_worker(stop_event: asyncio.Event) -> None:
    while not stop_event.is_set():
        try:
            async with SessionLocal() as session:
                processed = await process_quarantine_batch(session)
                if processed:
                    logger.info("media_quarantine_processed", extra={"count": processed})
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("media_worker_failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=2.0)
        except asyncio.TimeoutError:
            pass
