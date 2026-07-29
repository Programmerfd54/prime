import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import User, UserSkillFavorite
from app.routers.users import (
    add_favorite,
    get_preferences,
    list_favorites,
    remove_favorite,
    update_preferences,
)
from app.schemas import UpdateOnboardingPreferencesRequest


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user() -> User:
    return User(
        email="prefs@example.com",
        password_hash="hash",
        name="Prefs User",
        nickname="prefsuser",
        about=" ".join(["word"] * 50),
        region_code="77",
        city="Москва",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_preferences_roundtrip_and_merge() -> None:
    engine, session = await make_session()
    try:
        user = make_user()
        session.add(user)
        await session.commit()
        await session.refresh(user)

        assert await get_preferences(user) == {}

        payload = UpdateOnboardingPreferencesRequest(
            goal="betterMorning",
            selected_skill_id="morning-focus",
            completed_at="2026-07-27T10:00:00+00:00",
        )
        saved = await update_preferences(payload, user, session)
        assert saved["goal"] == "betterMorning"
        assert saved["selected_skill_id"] == "morning-focus"

        await session.refresh(user)
        again = await get_preferences(user)
        assert again["goal"] == "betterMorning"

        patch = UpdateOnboardingPreferencesRequest(goal="socialize")
        merged = await update_preferences(patch, user, session)
        assert merged["goal"] == "socialize"
        assert merged["selected_skill_id"] == "morning-focus"
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_preferences_multi_goals_and_attempt_count() -> None:
    engine, session = await make_session()
    try:
        user = make_user()
        session.add(user)
        await session.commit()
        await session.refresh(user)

        payload = UpdateOnboardingPreferencesRequest(
            goals=["moveMore", "betterSleep", "readInsteadOfFeed"],
            habit_quit_count="3+",
            habit_attempt_count="4+",
            selected_skill_id="body-charge",
        )
        saved = await update_preferences(payload, user, session)
        assert saved["goal"] == "moveMore"
        assert saved["goals"] == [
            "moveMore",
            "betterSleep",
            "readInsteadOfFeed",
        ]
        assert saved["habit_quit_count"] == "3+"
        assert saved["habit_attempt_count"] == "4+"
        assert saved["selected_skill_id"] == "body-charge"
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_favorites_add_list_remove() -> None:
    engine, session = await make_session()
    try:
        user = make_user()
        session.add(user)
        await session.commit()
        await session.refresh(user)

        await add_favorite("digital-detox", user, session)
        listed = await list_favorites(user, session)
        assert listed["skill_ids"] == ["digital-detox"]

        await add_favorite("digital-detox", user, session)
        listed = await list_favorites(user, session)
        assert listed["skill_ids"] == ["digital-detox"]

        await remove_favorite("digital-detox", user, session)
        row = await session.scalar(
            select(UserSkillFavorite).where(UserSkillFavorite.user_id == user.id)
        )
        assert row is None
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_invalid_favorite_skill_rejected() -> None:
    engine, session = await make_session()
    try:
        user = make_user()
        session.add(user)
        await session.commit()
        await session.refresh(user)

        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc:
            await add_favorite("unknown-skill", user, session)
        assert exc.value.status_code == 400
    finally:
        await engine.dispose()
