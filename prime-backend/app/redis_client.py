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


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
