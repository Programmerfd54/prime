from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app import matrix, media_scope, object_storage


class _FakeS3:
    def __init__(self) -> None:
        self.put_calls: list[dict] = []
        self.delete_calls: list[dict] = []

    def put_object(self, **kwargs):
        self.put_calls.append(kwargs)

    def delete_object(self, **kwargs):
        self.delete_calls.append(kwargs)

    def generate_presigned_url(self, _operation, *, Params, ExpiresIn):
        return f"https://media.example/{Params['Bucket']}/{Params['Key']}?ttl={ExpiresIn}"


@pytest.mark.asyncio
async def test_s3_store_sign_and_owner_scoped_delete(monkeypatch):
    settings = object_storage.get_settings()
    monkeypatch.setattr(settings, "s3_enabled", True)
    monkeypatch.setattr(settings, "s3_endpoint_url", "http://minio:9000")
    monkeypatch.setattr(settings, "s3_public_endpoint_url", "https://media.example")
    monkeypatch.setattr(settings, "s3_access_key_id", "test-access")
    monkeypatch.setattr(settings, "s3_secret_access_key", "test-secret")
    monkeypatch.setattr(settings, "s3_bucket", "prime-media")
    monkeypatch.setattr(settings, "s3_presigned_url_expire_seconds", 900)
    fake = _FakeS3()
    monkeypatch.setattr(object_storage, "_s3_client", lambda public=False: fake)

    reference = await object_storage.store_media(
        data=b"safe-image",
        user_id="user-1",
        scope_type="group",
        filename="photo.jpg",
        content_type="image/jpeg",
    )

    assert reference.startswith("s3://prime-media/media/group/user-1/")
    assert fake.put_calls[0]["Body"] == b"safe-image"
    assert fake.put_calls[0]["ContentType"] == "image/jpeg"
    assert object_storage.presigned_download_url(reference).startswith(
        "https://media.example/prime-media/media/group/user-1/"
    )

    await object_storage.delete_media(reference, user_id="another-user")
    assert fake.delete_calls == []
    await object_storage.delete_media(reference, user_id="user-1")
    assert len(fake.delete_calls) == 1


@pytest.mark.asyncio
async def test_matrix_upload_prefers_s3_and_records_scope(monkeypatch):
    monkeypatch.setattr(matrix, "storage_configured", lambda: True)
    store = AsyncMock(return_value="s3://prime-media/media/direct/user-1/file.jpg")
    record = AsyncMock()
    monkeypatch.setattr(matrix, "store_media", store)
    monkeypatch.setattr(media_scope, "record_media_upload", record)
    user = SimpleNamespace(id="user-1")
    session = SimpleNamespace()

    result = await matrix.upload_media(
        user,
        session,
        "photo.jpg",
        "image/jpeg",
        b"image",
        "direct",
        "friend-1",
    )

    assert result.startswith("s3://")
    store.assert_awaited_once()
    record.assert_awaited_once_with(
        session,
        owner=user,
        media_url=result,
        scope_type="direct",
        scope_id="friend-1",
    )

