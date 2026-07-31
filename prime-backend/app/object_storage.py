"""Small S3-compatible storage adapter used by direct upload endpoints.

The database keeps stable ``s3://bucket/key`` references.  API responses turn
them into short-lived signed HTTPS URLs, so MinIO credentials never reach a
client and changing the public storage hostname does not require a migration.
"""

from __future__ import annotations

import asyncio
import mimetypes
from functools import lru_cache
from pathlib import Path, PurePosixPath
from urllib.parse import quote, unquote, urlparse
from uuid import uuid4

from botocore.config import Config

from .config import get_settings


_ALLOWED_SCOPES = {"avatar", "group", "direct", "report", "owner"}


def storage_configured() -> bool:
    settings = get_settings()
    return bool(
        settings.s3_enabled
        and settings.s3_endpoint_url
        and settings.s3_access_key_id
        and settings.s3_secret_access_key
        and settings.s3_bucket
    )


@lru_cache(maxsize=2)
def _s3_client(public: bool = False):
    import boto3

    settings = get_settings()
    endpoint = (
        settings.s3_public_endpoint_url
        if public and settings.s3_public_endpoint_url
        else settings.s3_endpoint_url
    )
    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=settings.s3_access_key_id,
        aws_secret_access_key=settings.s3_secret_access_key,
        region_name=settings.s3_region,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def storage_reference(bucket: str, key: str) -> str:
    return f"s3://{quote(bucket, safe='')}/{quote(key, safe='/')}"


def parse_storage_reference(value: str | None) -> tuple[str, str] | None:
    if not value:
        return None
    parsed = urlparse(value)
    if parsed.scheme != "s3" or not parsed.netloc:
        return None
    key = unquote(parsed.path.lstrip("/"))
    bucket = unquote(parsed.netloc)
    if not key or ".." in PurePosixPath(key).parts:
        return None
    return bucket, key


def _safe_extension(filename: str, content_type: str) -> str:
    suffix = Path(filename).suffix.lower()
    if suffix and len(suffix) <= 10 and suffix[1:].isalnum():
        return suffix
    guessed = mimetypes.guess_extension(content_type.partition(";")[0].strip()) or ".bin"
    return ".jpg" if guessed == ".jpe" else guessed


def _store_media_sync(
    *,
    data: bytes,
    user_id: str,
    scope_type: str,
    filename: str,
    content_type: str,
) -> str:
    if not storage_configured():
        raise RuntimeError("S3 object storage is not configured")
    scope = scope_type if scope_type in _ALLOWED_SCOPES else "owner"
    settings = get_settings()
    key = f"media/{scope}/{user_id}/{uuid4().hex}{_safe_extension(filename, content_type)}"
    _s3_client().put_object(
        Bucket=settings.s3_bucket,
        Key=key,
        Body=data,
        ContentType=content_type,
        Metadata={"owner": user_id, "scope": scope},
    )
    return storage_reference(settings.s3_bucket, key)


async def store_media(**kwargs) -> str:
    return await asyncio.to_thread(_store_media_sync, **kwargs)


def presigned_download_url(value: str | None) -> str | None:
    parsed = parse_storage_reference(value)
    if parsed is None or not storage_configured():
        return value
    bucket, key = parsed
    settings = get_settings()
    if bucket != settings.s3_bucket:
        return value
    return _s3_client(public=True).generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=settings.s3_presigned_url_expire_seconds,
    )


def _delete_media_sync(value: str | None, *, user_id: str) -> None:
    parsed = parse_storage_reference(value)
    if parsed is None or not storage_configured():
        return
    bucket, key = parsed
    settings = get_settings()
    path = PurePosixPath(key)
    if (
        bucket != settings.s3_bucket
        or ".." in path.parts
        or len(path.parts) != 4
        or path.parts[0] != "media"
        or path.parts[2] != user_id
    ):
        return
    _s3_client().delete_object(Bucket=bucket, Key=key)


async def delete_media(value: str | None, *, user_id: str) -> None:
    await asyncio.to_thread(_delete_media_sync, value, user_id=user_id)

