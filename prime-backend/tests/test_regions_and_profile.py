import pytest
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import User
from app.regions import is_valid_region, region_name
from app.routers.users import update_me
from app.schemas import UpdateUserRequest


def profile_text(words: int = 50) -> str:
    return " ".join(f"word{i}" for i in range(words))


def test_moscow_and_moscow_region_are_different() -> None:
    assert region_name("77")
    assert region_name("50")
    assert region_name("77") != region_name("50")


def test_profile_requires_valid_region_nickname_without_about() -> None:
    payload = UpdateUserRequest(
        name="User",
        nickname="tester",
        about="",
        region_code="66",
        age=25,
    )
    assert payload.region_code == "66"
    assert payload.nickname == "tester"
    assert payload.about == ""
    assert payload.model_dump()["city"] == region_name("66")

    short_about = UpdateUserRequest(
        name="User",
        nickname="tester",
        about=profile_text(3),
        region_code="66",
        age=25,
    )
    assert len(short_about.about.split()) == 3

    try:
        UpdateUserRequest(
            name="User",
            nickname="tester",
            about="",
            region_code="MSK",
            age=25,
        )
    except ValidationError:
        pass
    else:
        raise AssertionError("invalid region must not be accepted")

    assert not is_valid_region("MSK")


def test_partial_about_only_update() -> None:
    payload = UpdateUserRequest(about=" ".join(f"word{i}" for i in range(50)))
    assert payload.about is not None
    assert len(payload.about.split()) == 50
    assert payload.name is None
    assert payload.nickname is None


def test_profile_requires_name_when_sent_empty() -> None:
    try:
        UpdateUserRequest(name="")
    except ValidationError:
        pass
    else:
        raise AssertionError("empty name must not be accepted when provided")


def test_profile_still_accepts_full_about() -> None:
    payload = UpdateUserRequest(
        name="User",
        nickname="tester",
        about=profile_text(),
        region_code="66",
        age=25,
    )
    assert len(payload.about.split()) == 50


@pytest.mark.asyncio
async def test_update_me_accepts_about_only_patch() -> None:
    """Regression: team-search sheet PATCHes only `about` before join queue."""
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)

    async with session_factory() as session:
        user = User(
            email="about-only@example.com",
            password_hash="hash",
            name="Team User",
            nickname="teamuser",
            about="short",
            region_code="66",
            city="Свердловская область",
            age=28,
            profile_completed=True,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)

        about = profile_text()
        updated = await update_me(UpdateUserRequest(about=about), user, session)
        assert updated.about == about
        assert updated.name == "Team User"
        assert updated.profile_completed is True

    await engine.dispose()
