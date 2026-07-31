import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import AuditEvent, DeviceToken, User, UserRestriction
from app.routers.users import delete_me


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)


@pytest.mark.asyncio
async def test_delete_me_purges_tokens_and_restrictions() -> None:
    engine, factory = await make_session()
    async with factory() as session:
        user = User(
            email="delete@example.com",
            password_hash="hash",
            name="Delete",
            nickname="deleteuser",
            email_verified_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
        )
        session.add(user)
        await session.flush()
        session.add(DeviceToken(user_id=user.id, platform="ios", provider="apns", token="tok"))
        session.add(
            UserRestriction(
                id=str(__import__("uuid").uuid4()),
                user_id=user.id,
                scope="SOCIAL_WRITE",
                reason_code="PROFANITY_EN",
                source_decision_id="dec-1",
                starts_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
                expires_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc)
                + __import__("datetime").timedelta(hours=1),
                status="ACTIVE",
            )
        )
        await session.commit()
        await delete_me(user=user, session=session)
        tokens = (await session.scalars(select(DeviceToken).where(DeviceToken.user_id == user.id))).all()
        restrictions = (
            await session.scalars(select(UserRestriction).where(UserRestriction.user_id == user.id))
        ).all()
        audit = await session.scalar(select(AuditEvent).where(AuditEvent.action == "account.deleted"))
        assert tokens == []
        assert restrictions == []
        assert audit is not None
        assert user.is_active is False
    await engine.dispose()
