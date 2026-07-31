"""Lazy Redis connection with a short fail-open retry window."""

import logging
import time

from .config import get_settings


logger = logging.getLogger("prime.redis")
_redis = None
_redis_retry_after = 0.0
_REDIS_RETRY_SECONDS = 5.0


async def get_redis():
    global _redis, _redis_retry_after
    if _redis is not None:
        return _redis
    if time.monotonic() < _redis_retry_after:
        return None
    settings = get_settings()
    if not settings.redis_url:
        return None
    client = None
    try:
        from redis.asyncio import Redis

        client = Redis.from_url(
            settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        await client.ping()
        _redis = client
        _redis_retry_after = 0.0
        logger.info("redis_connected")
        return _redis
    except Exception:
        if client is not None:
            try:
                await client.aclose()
            except Exception:
                pass
        _redis_retry_after = time.monotonic() + _REDIS_RETRY_SECONDS
        logger.warning("redis_unavailable_using_database_fallback")
        return None


async def create_redis_pubsub_client():
    """Create a dedicated Redis client for long-lived Pub/Sub reads.

    The regular client deliberately has a short command timeout so API calls
    fail open when Redis is unavailable.  Reusing that connection pool for
    Pub/Sub is incorrect: an idle subscription is expected to block while it
    waits for the next message, so a socket read timeout produces an endless
    reconnect/traceback loop.
    """
    settings = get_settings()
    if not settings.redis_url:
        return None
    try:
        from redis.asyncio import Redis

        return Redis.from_url(
            settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=None,
        )
    except Exception:
        logger.warning("redis_pubsub_client_unavailable")
        return None


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
