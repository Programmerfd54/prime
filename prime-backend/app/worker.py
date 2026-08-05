"""Dedicated background worker process for notifications and media scans."""

import asyncio
import logging
import signal

from .logging_config import configure_logging
from .media_pipeline.worker import run_media_worker
from .email_unsubscribe_cleanup import run_email_unsubscribe_cleanup_worker
from .outbox_worker import run_outbox_worker
from .config import get_settings
from .db import engine
from .redis_client import close_redis


async def main() -> None:
    settings = get_settings()
    configure_logging(settings.log_level)
    logger = logging.getLogger("prime.worker")
    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    for name in ("SIGINT", "SIGTERM"):
        sig = getattr(signal, name, None)
        if sig is not None:
            try:
                loop.add_signal_handler(sig, stop_event.set)
            except NotImplementedError:
                pass
    tasks = [
        asyncio.create_task(run_outbox_worker(stop_event)),
        asyncio.create_task(run_media_worker(stop_event)),
        asyncio.create_task(run_email_unsubscribe_cleanup_worker(stop_event)),
    ]
    logger.info("prime_worker_started")
    try:
        await stop_event.wait()
    finally:
        stop_event.set()
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        await engine.dispose()
        await close_redis()
        logger.info("prime_worker_stopped")


if __name__ == "__main__":
    asyncio.run(main())
