import pytest
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import ModerationAppeal, ModerationDecision, User, UserRestriction
from app.moderation import ModerationError, moderate_text_before_publish
from app.moderation.restrictions import active_social_write_restriction
from app.routers.moderation import create_appeal, resolve_appeal


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)


def user(idx: int) -> User:
    return User(
        email=f"appeal{idx}@example.com",
        password_hash="hash",
        name=f"User {idx}",
        nickname=f"appealuser{idx}",
        email_verified_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
        is_moderator=idx == 2,
    )


@pytest.mark.asyncio
async def test_appeal_and_reverse_lifts_restriction() -> None:
    engine, factory = await make_session()
    async with factory() as session:
        offender = user(1)
        mod = user(2)
        session.add_all([offender, mod])
        await session.flush()
        with pytest.raises(ModerationError):
            await moderate_text_before_publish(
                session,
                user=offender,
                text="what the fuck",
                content_type="group_chat_message",
                offense_id="appeal-offense-1",
            )
        decision = await session.scalar(
            select(ModerationDecision).where(ModerationDecision.actor_user_id == offender.id)
        )
        assert decision is not None
        assert await active_social_write_restriction(session, offender.id) is not None
        await create_appeal(
            {"decision_id": decision.id, "explanation": "false positive"},
            user=offender,
            session=session,
        )
        appeal = await session.scalar(select(ModerationAppeal))
        assert appeal is not None
        await resolve_appeal(
            appeal.id,
            {"resolution": "REVERSE", "reason": "test"},
            user=mod,
            session=session,
        )
        restriction = await active_social_write_restriction(session, offender.id)
        assert restriction is None
    await engine.dispose()
