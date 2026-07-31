"""Security regression tests for remediation work."""

import pytest
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.media_scope import record_media_upload, validate_media_url_for_scope
from app.media_scope import record_media_upload, validate_media_url_for_scope
from app.models import DeviceToken, User, UserRestriction
from app.moderation import ModerationError, moderate_text_before_publish
from app.moderation.profanity import classify_text
from app.moderation.restrictions import RESTRICTION_HOURS, active_social_write_restriction
from app.routers.notifications import register_device


def make_user(index: int) -> User:
    return User(
        email=f"sec{index}@example.com",
        password_hash="hash",
        name=f"Sec {index}",
        nickname=f"secuser{index}",
        email_verified_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
    )


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    return engine, factory


@pytest.mark.asyncio
async def test_device_token_cannot_be_hijacked() -> None:
    engine, session_factory = await make_session()
    async with session_factory() as session:
        owner = make_user(1)
        attacker = make_user(2)
        session.add_all([owner, attacker])
        await session.flush()

        await register_device(
            {"token": "shared-device-token", "platform": "ios", "provider": "apns"},
            user=owner,
            session=session,
        )
        with pytest.raises(HTTPException) as exc:
            await register_device(
                {"token": "shared-device-token", "platform": "ios", "provider": "apns"},
                user=attacker,
                session=session,
            )
        assert exc.value.status_code == 409

        token = await session.scalar(
            select(DeviceToken).where(DeviceToken.token == "shared-device-token")
        )
        assert token is not None
        assert token.user_id == owner.id
    await engine.dispose()


@pytest.mark.asyncio
async def test_media_url_requires_matching_upload_scope() -> None:
    engine, session_factory = await make_session()
    async with session_factory() as session:
        user = make_user(3)
        session.add(user)
        await session.flush()

        await record_media_upload(
            session,
            owner=user,
            media_url="mxc://matrix.example/abc123",
            scope_type="group",
            scope_id="group-a",
        )
        await validate_media_url_for_scope(
            session,
            owner=user,
            media_url="mxc://matrix.example/abc123",
            scope_type="group",
            scope_id="group-a",
        )
        with pytest.raises(HTTPException) as exc:
            await validate_media_url_for_scope(
                session,
                owner=user,
                media_url="mxc://matrix.example/abc123",
                scope_type="group",
                scope_id="group-b",
            )
        assert exc.value.status_code == 403
    await engine.dispose()


def test_profanity_detects_english_high_confidence() -> None:
    result = classify_text("this is a fuck test")
    assert result.allowed is False
    assert result.confidence.value == "HIGH"


def test_profanity_allows_scunthorpe_safe_word() -> None:
    result = classify_text("classic assistant document")
    assert result.allowed is True


@pytest.mark.asyncio
async def test_high_confidence_profanity_applies_18h_restriction() -> None:
    engine, session_factory = await make_session()
    async with session_factory() as session:
        user = make_user(4)
        session.add(user)
        await session.flush()

        with pytest.raises(ModerationError) as exc:
            await moderate_text_before_publish(
                session,
                user=user,
                text="what the fuck",
                content_type="group_chat_message",
                offense_id="offense-1",
            )
        assert exc.value.code == "PROFANITY_REJECTED"

        restriction = await active_social_write_restriction(session, user.id)
        assert restriction is not None
        delta = restriction.expires_at - restriction.starts_at
        assert delta.total_seconds() == RESTRICTION_HOURS * 3600

        with pytest.raises(ModerationError) as blocked:
            await moderate_text_before_publish(
                session,
                user=user,
                text="hello again",
                content_type="group_chat_message",
            )
        assert blocked.value.code == "SOCIAL_WRITE_RESTRICTED"
    await engine.dispose()


@pytest.mark.asyncio
async def test_restriction_not_extended_by_blocked_attempt() -> None:
    engine, session_factory = await make_session()
    async with session_factory() as session:
        user = make_user(5)
        session.add(user)
        await session.flush()

        with pytest.raises(ModerationError):
            await moderate_text_before_publish(
                session,
                user=user,
                text="shit happens",
                content_type="direct_message",
                offense_id="offense-2",
            )
        first = await active_social_write_restriction(session, user.id)
        assert first is not None
        first_expires = first.expires_at

        with pytest.raises(ModerationError) as blocked:
            await moderate_text_before_publish(
                session,
                user=user,
                text="another fuck",
                content_type="direct_message",
                offense_id="offense-3",
            )
        assert blocked.value.code == "SOCIAL_WRITE_RESTRICTED"
        second = await active_social_write_restriction(session, user.id)
        assert second is not None
        assert second.expires_at == first_expires
        assert second.id == first.id
    await engine.dispose()
