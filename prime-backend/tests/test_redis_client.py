import sys
from types import SimpleNamespace

import pytest

from app import redis_client


class _FakeRedisClient:
    async def ping(self) -> bool:
        return True

    async def aclose(self) -> None:
        return None


@pytest.fixture(autouse=True)
def _reset_cached_client(monkeypatch):
    monkeypatch.setattr(redis_client, "_redis", None)
    monkeypatch.setattr(redis_client, "_redis_retry_after", 0.0)
    monkeypatch.setattr(
        redis_client,
        "get_settings",
        lambda: SimpleNamespace(redis_url="redis://prime-redis:6379/0"),
    )


def _install_fake_redis(monkeypatch, captured: dict) -> None:
    class _Redis:
        @staticmethod
        def from_url(url: str, **kwargs):
            captured["url"] = url
            captured["kwargs"] = kwargs
            return _FakeRedisClient()

    monkeypatch.setitem(sys.modules, "redis.asyncio", SimpleNamespace(Redis=_Redis))


@pytest.mark.asyncio
async def test_regular_redis_client_keeps_short_command_timeout(monkeypatch) -> None:
    captured: dict = {}
    _install_fake_redis(monkeypatch, captured)

    client = await redis_client.get_redis()

    assert client is not None
    assert captured["kwargs"]["socket_connect_timeout"] == 2
    assert captured["kwargs"]["socket_timeout"] == 2


@pytest.mark.asyncio
async def test_pubsub_client_has_no_idle_read_timeout(monkeypatch) -> None:
    captured: dict = {}
    _install_fake_redis(monkeypatch, captured)

    client = await redis_client.create_redis_pubsub_client()

    assert client is not None
    assert captured["kwargs"]["socket_connect_timeout"] == 2
    assert captured["kwargs"]["socket_timeout"] is None
