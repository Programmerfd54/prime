from datetime import datetime, timezone

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import User
from app.routers.social import discover_users


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(
    index: int,
    *,
    region_code: str = "66",
    verified: bool = True,
    nickname: str | None = None,
) -> User:
    return User(
        email=f"discover{index}@example.com",
        password_hash="hash",
        name=f"User {index}",
        nickname=nickname or f"discover{index}",
        about=" ".join(["слово"] * 50),
        region_code=region_code,
        age=25,
        profile_completed=True,
        email_verified_at=datetime.now(timezone.utc) if verified else None,
    )


@pytest.mark.asyncio
async def test_discover_excludes_self_and_unverified() -> None:
    engine, session = await make_session()
    try:
        viewer = make_user(0, nickname="viewer")
        verified = make_user(1, region_code="66")
        unverified = make_user(2, verified=False)
        session.add_all([viewer, verified, unverified])
        await session.commit()
        await session.refresh(viewer)

        result = await discover_users(
            region_code=None,
            cursor=None,
            limit=30,
            user=viewer,
            session=session,
        )
        ids = {item["user"]["id"] for item in result["items"]}
        assert viewer.id not in ids
        assert verified.id in ids
        assert unverified.id not in ids
        assert result["items"][0]["user"]["email_verified"] is True
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_discover_filters_by_region() -> None:
    engine, session = await make_session()
    try:
        viewer = make_user(0, nickname="viewer")
        moscow = make_user(1, region_code="77")
        ekb = make_user(2, region_code="66")
        session.add_all([viewer, moscow, ekb])
        await session.commit()
        await session.refresh(viewer)

        result = await discover_users(
            region_code="77",
            cursor=None,
            limit=30,
            user=viewer,
            session=session,
        )
        ids = {item["user"]["id"] for item in result["items"]}
        assert moscow.id in ids
        assert ekb.id not in ids
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_discover_cursor_pagination() -> None:
    engine, session = await make_session()
    try:
        viewer = make_user(0, nickname="viewer")
        others = [make_user(i) for i in range(1, 5)]
        session.add(viewer)
        session.add_all(others)
        await session.commit()
        await session.refresh(viewer)

        first = await discover_users(
            region_code=None,
            cursor=None,
            limit=2,
            user=viewer,
            session=session,
        )
        assert len(first["items"]) == 2
        assert first["next_cursor"] is not None

        second = await discover_users(
            region_code=None,
            cursor=first["next_cursor"],
            limit=2,
            user=viewer,
            session=session,
        )
        assert len(second["items"]) == 2
        first_ids = {item["user"]["id"] for item in first["items"]}
        second_ids = {item["user"]["id"] for item in second["items"]}
        assert first_ids.isdisjoint(second_ids)
    finally:
        await session.close()
        await engine.dispose()
