import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.audit import record_audit
from app.db import Base
from app.models import AuditEvent, User


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    return engine, factory


@pytest.mark.asyncio
async def test_record_audit_persists_action() -> None:
    engine, factory = await make_session()
    async with factory() as session:
        user = User(
            email="audit@example.com",
            password_hash="x",
            name="Audit",
            nickname="audituser",
            email_verified_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
        )
        session.add(user)
        await session.flush()
        await record_audit(session, action="auth.login.success", user_id=user.id)
        await session.commit()
        row = await session.scalar(
            select(AuditEvent).where(AuditEvent.action == "auth.login.success")
        )
        assert row is not None
        assert row.user_id == user.id
    await engine.dispose()
