import pytest
from pathlib import Path
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.media_pipeline.worker import process_quarantine_batch
from app.models import LocalMediaAsset, User


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)


@pytest.mark.asyncio
async def test_quarantine_asset_becomes_clean() -> None:
    engine, factory = await make_session()
    async with factory() as session:
        user = User(
            email="media@example.com",
            password_hash="hash",
            name="Media",
            nickname="mediauser",
            email_verified_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
        )
        session.add(user)
        await session.flush()
        asset = LocalMediaAsset(
            owner_user_id=user.id,
            storage_key="scanme",
            content_type="application/octet-stream",
            scope_type="group",
            scope_id="g1",
            processing_status="QUARANTINE",
        )
        session.add(asset)
        await session.commit()
        Path("uploads/private-media").mkdir(parents=True, exist_ok=True)
        Path("uploads/private-media/scanme").write_bytes(b"hello-safe-content")
        async with factory() as session2:
            count = await process_quarantine_batch(session2)
            assert count >= 1
            refreshed = await session2.get(LocalMediaAsset, asset.id)
            assert refreshed is not None
            assert refreshed.processing_status == "CLEAN"
            assert refreshed.published_media_url == f"local://{asset.id}"
    await engine.dispose()
