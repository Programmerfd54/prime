"""Run database bootstrap and forward migrations once during deployment."""

import asyncio

from .db import create_db_schema, engine


async def main() -> None:
    try:
        await create_db_schema()
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
