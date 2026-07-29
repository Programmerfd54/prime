import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import FriendRequest, User
from app.routers.misc import cancel_friend_request, find_user_by_nickname


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int) -> User:
    return User(
        email=f"friend{index}@example.com",
        password_hash="hash",
        name=f"Friend {index}",
        nickname=f"friend{index}",
        about=" ".join(["слово"] * 50),
        region_code="66",
        age=25,
        profile_completed=True,
    )


@pytest.mark.asyncio
async def test_cancel_outgoing_friend_request() -> None:
    engine, session = await make_session()
    try:
        alice = make_user(1)
        bob = make_user(2)
        session.add_all([alice, bob])
        await session.flush()
        request = FriendRequest(
            requester_user_id=alice.id,
            addressee_user_id=bob.id,
            status="pending",
        )
        session.add(request)
        await session.commit()
        await session.refresh(request)

        lookup = await find_user_by_nickname("friend2", alice, session)
        assert lookup["has_pending_request"] is True
        assert lookup["pending_direction"] == "outgoing"
        assert lookup["pending_request_id"] == request.id

        result = await cancel_friend_request(request.id, alice, session)
        assert result["status"] == "cancelled"

        lookup_after = await find_user_by_nickname("friend2", alice, session)
        assert lookup_after["has_pending_request"] is False
        assert lookup_after["pending_request_id"] is None
    finally:
        await session.close()
        await engine.dispose()
