import asyncio

from sqlalchemy import select

from app.db import SessionLocal
from app.models import User
from app.routers.group_service import _sync_user_daily_progress


async def main() -> None:
    changed = 0
    async with SessionLocal() as session:
        users = (await session.execute(select(User))).scalars().all()
        for user in users:
            before = (user.prime_points, user.successful_days)
            await _sync_user_daily_progress(session, user)
            after = (user.prime_points, user.successful_days)
            if before != after:
                changed += 1
        await session.commit()
    print(f"Recalculated daily progress for {changed} users")


if __name__ == "__main__":
    asyncio.run(main())
