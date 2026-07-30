import asyncio
import logging

from .db import SessionLocal
from .notifications import process_outbox_once


logger = logging.getLogger("prime.outbox")


async def run_outbox_worker(stop_event: asyncio.Event) -> None:
    while not stop_event.is_set():
        try:
            async with SessionLocal() as session:
                await process_outbox_once(session)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("outbox_worker_failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=2.0)
        except asyncio.TimeoutError:
            pass
