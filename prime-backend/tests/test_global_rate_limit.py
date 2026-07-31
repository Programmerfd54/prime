import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.rate_limit import enforce as enforce_rate_limit
from app.rate_limit import record_failure as record_rate_limit_hit


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)


@pytest.mark.asyncio
async def test_rate_limit_enforces_after_threshold() -> None:
    engine, factory = await make_session()
    async with factory() as session:
        key = "api:test:ip:127.0.0.1"
        for _ in range(2):
            await enforce_rate_limit(session, key, limit=3, window_seconds=60, detail="limit")
            await record_rate_limit_hit(session, key, window_seconds=60)
        await enforce_rate_limit(session, key, limit=3, window_seconds=60, detail="limit")
        await record_rate_limit_hit(session, key, window_seconds=60)
        with pytest.raises(HTTPException) as exc:
            await enforce_rate_limit(session, key, limit=3, window_seconds=60, detail="limit")
        assert exc.value.status_code == 429
    await engine.dispose()
