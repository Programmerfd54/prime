from datetime import timedelta

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db import Base
from app.direct_message_events import direct_message_hub
from app.models import OutboxEvent, User, utcnow
from app.observability import (
    request_finished,
    request_metrics_snapshot,
    request_started,
    reset_request_metrics_for_test,
)
from app.routers.ops import operational_metrics


async def make_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    return engine, async_sessionmaker(engine, expire_on_commit=False)()


def moderator() -> User:
    return User(
        email="ops@example.com",
        password_hash="hash",
        name="Ops",
        nickname="ops-user",
        about=" ".join(["слово"] * 50),
        region_code="77",
        city="Москва",
        age=30,
        profile_completed=True,
        is_moderator=True,
    )


def test_request_metrics_keep_percentiles_and_error_rate() -> None:
    reset_request_metrics_for_test()
    for elapsed, status_code in [(10.0, 200), (20.0, 200), (100.0, 503)]:
        request_started()
        request_finished(
            method="GET",
            route="/api/v1/groups/overview",
            status_code=status_code,
            elapsed_ms=elapsed,
        )

    snapshot = request_metrics_snapshot()
    route = snapshot["routes"][0]
    assert snapshot["active_requests"] == 0
    assert route["total"] == 3
    assert route["errors_5xx"] == 1
    assert route["error_rate"] == 0.3333
    assert route["latency_ms"]["p50"] == 20.0
    assert route["latency_ms"]["p95"] == 100.0


@pytest.mark.asyncio
async def test_operational_metrics_expose_realtime_and_outbox_lag() -> None:
    engine, session = await make_session()
    queue = None
    try:
        user = moderator()
        session.add(user)
        session.add(
            OutboxEvent(
                topic="push.notification",
                attempts=2,
                available_at=utcnow() - timedelta(seconds=12),
            )
        )
        await session.commit()
        queue = direct_message_hub.subscribe(user.id)

        payload = await operational_metrics(user=user, session=session)

        assert payload["realtime"]["sse_connections"] >= 1
        assert payload["push_outbox"]["pending"] == 1
        assert payload["push_outbox"]["retrying"] == 1
        assert payload["push_outbox"]["oldest_lag_seconds"] >= 11
        assert isinstance(payload["database_pool"], str)
    finally:
        if queue is not None:
            direct_message_hub.unsubscribe(user.id, queue)
        await session.close()
        await engine.dispose()
