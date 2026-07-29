import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_response_includes_request_id_header() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.headers.get("x-request-id")


@pytest.mark.asyncio
async def test_incoming_request_id_is_echoed() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/api/v1/health",
            headers={"X-Request-ID": "test-correlation-123"},
        )
    assert response.status_code == 200
    assert response.headers.get("x-request-id") == "test-correlation-123"
