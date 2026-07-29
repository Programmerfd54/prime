from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

import pytest

from app.db import Base
from app.models import PrimeEvent, User
from app.routers.users import buy_streak_shield, use_streak_shield
from app.security import hash_password


async def _session() -> tuple[AsyncSession, any]:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    return factory(), engine


@pytest.mark.asyncio
async def test_buy_and_use_shield() -> None:
    session, engine = await _session()
    try:
        user = User(
            email="shield@test.local",
            password_hash=hash_password("password1"),
            nickname="shielduser",
            prime_points=10,
            streak_shields=0,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)

        bought = await buy_streak_shield(user, session)
        assert bought["streak_shields"] == 1
        assert bought["prime_points"] == 5

        await session.refresh(user)
        used = await use_streak_shield(user, session)
        assert used["streak_shields"] == 0
        assert used["shield_pending"] is True

        events = (
            await session.execute(
                select(PrimeEvent).where(PrimeEvent.user_id == user.id)
            )
        ).scalars().all()
        assert any(event.amount == -5 for event in events)
    finally:
        await engine.dispose()
