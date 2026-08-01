"""Database-backed rate limiting without introducing Redis."""

from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from .models import RateLimitBucket, utcnow
from .redis_client import get_redis, mark_redis_unavailable


logger = logging.getLogger("prime.rate_limit")


def _as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def bucket_key(raw_key: str) -> str:
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


async def _upsert_attempt(session: AsyncSession, key: str, window_seconds: int) -> None:
    now = utcnow()
    values = {
        "key": bucket_key(key),
        "window_started_at": now,
        "attempts": 1,
        "updated_at": now,
    }
    dialect = session.get_bind().dialect.name
    if dialect == "postgresql":
        statement = pg_insert(RateLimitBucket).values(**values)
        statement = statement.on_conflict_do_update(
            index_elements=[RateLimitBucket.key],
            set_={
                "attempts": RateLimitBucket.attempts + 1,
                "updated_at": now,
            },
        )
    elif dialect == "sqlite":
        statement = sqlite_insert(RateLimitBucket).values(**values)
        statement = statement.on_conflict_do_update(
            index_elements=[RateLimitBucket.key],
            set_={
                "attempts": RateLimitBucket.attempts + 1,
                "updated_at": now,
            },
        )
    else:
        statement = None

    if statement is not None:
        await session.execute(statement)
    else:
        row = await session.scalar(
            select(RateLimitBucket).where(RateLimitBucket.key == values["key"])
        )
        if row is None:
            session.add(RateLimitBucket(**values))
        else:
            row.attempts += 1
            row.updated_at = now
    await session.flush()


async def record_failure(
    session: AsyncSession,
    raw_key: str,
    *,
    window_seconds: int,
) -> None:
    redis = await get_redis()
    if redis is not None:
        key = f"prime:rate-limit:{bucket_key(raw_key)}"
        try:
            attempts = await redis.incr(key)
            if attempts == 1:
                await redis.expire(key, window_seconds)
            return
        except Exception:
            # Redis is an acceleration layer, not a reason to reject an
            # otherwise valid request.  Preserve enforcement by falling back
            # to the durable database bucket when an established Redis
            # connection times out or disconnects under load.
            logger.warning("redis_rate_limit_record_using_database_fallback")
            await mark_redis_unavailable(redis)
    key = bucket_key(raw_key)
    now = utcnow()
    row = await session.scalar(select(RateLimitBucket).where(RateLimitBucket.key == key))
    if row is not None and now - _as_utc(row.window_started_at) >= timedelta(seconds=window_seconds):
        row.window_started_at = now
        row.attempts = 0
        row.updated_at = now
        await session.flush()
    await _upsert_attempt(session, raw_key, window_seconds)
    await session.commit()


async def enforce(
    session: AsyncSession,
    raw_key: str,
    *,
    limit: int,
    window_seconds: int,
    detail: str,
) -> None:
    redis = await get_redis()
    if redis is not None:
        try:
            attempts = int(await redis.get(f"prime:rate-limit:{bucket_key(raw_key)}") or 0)
            if attempts >= limit:
                raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=detail)
            return
        except HTTPException:
            raise
        except Exception:
            logger.warning("redis_rate_limit_enforce_using_database_fallback")
            await mark_redis_unavailable(redis)
    key = bucket_key(raw_key)
    now = utcnow()
    row = await session.scalar(select(RateLimitBucket).where(RateLimitBucket.key == key))
    if row is not None and now - _as_utc(row.window_started_at) >= timedelta(seconds=window_seconds):
        row.window_started_at = now
        row.attempts = 0
        row.updated_at = now
        await session.flush()
    if row is not None and row.attempts >= limit:
        await session.commit()
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=detail)
