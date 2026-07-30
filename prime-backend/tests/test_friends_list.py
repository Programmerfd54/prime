import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.models import Friendship, User
from app.routers.misc import friends, respond_friend_request


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def make_user(index: int, *, active: bool = True) -> User:
    return User(
        email=f"friend{index}@example.com",
        password_hash="hash",
        name=f"Friend {index}",
        nickname=f"friend{index}",
        about=" ".join(["слово"] * 50),
        region_code="66",
        age=25,
        profile_completed=True,
        is_active=active,
    )


@pytest.mark.asyncio
async def test_friends_list_excludes_deleted_accounts() -> None:
    engine, session = await make_session()
    try:
        alice = make_user(1)
        bob = make_user(2)
        deleted = make_user(3, active=False)
        deleted.name = "Удалённый аккаунт"
        deleted.nickname = "deleted_abc12345"
        session.add_all([alice, bob, deleted])
        await session.flush()
        session.add(
            Friendship(
                user_low_id=sorted((alice.id, bob.id))[0],
                user_high_id=sorted((alice.id, bob.id))[1],
            )
        )
        session.add(
            Friendship(
                user_low_id=sorted((alice.id, deleted.id))[0],
                user_high_id=sorted((alice.id, deleted.id))[1],
            )
        )
        await session.commit()

        result = await friends(alice, session)
        nicknames = {item["nickname"] for item in result["friends"]}
        assert nicknames == {"friend2"}
    finally:
        await session.close()
        await engine.dispose()


@pytest.mark.asyncio
async def test_accept_friend_request_notifies_requester() -> None:
    engine, session = await make_session()
    try:
        from app.models import FriendRequest

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

        result = await respond_friend_request(
            request.id,
            {"accept": True},
            bob,
            session,
        )
        assert result["status"] == "accepted"

        friends_for_alice = await friends(alice, session)
        assert len(friends_for_alice["friends"]) == 1
        assert friends_for_alice["friends"][0]["nickname"] == "friend2"
    finally:
        await session.close()
        await engine.dispose()
