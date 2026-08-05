"""Periodic cleanup for expired email unsubscribe tokens."""

from __future__ import annotations

import asyncio
import logging

from .config import get_settings
from .db import SessionLocal
from .email_unsubscribe import cleanup_expired_unsubscribe_tokens

logger = logging.getLogger("prime.email.cleanup")


async def run_email_unsubscribe_cleanup_worker(stop_event: asyncio.Event) -> None:
    settings = get_settings()
    interval = settings.email_unsubscribe_cleanup_interval_seconds
    while not stop_event.is_set():
        try:
            async with SessionLocal() as session:
                deleted = await cleanup_expired_unsubscribe_tokens(session)
            if deleted:
                logger.info(
                    "email_unsubscribe_tokens_cleaned",
                    extra={"deleted": deleted},
                )
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("email_unsubscribe_cleanup_failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=float(interval))
        except asyncio.TimeoutError:
            pass
