"""Upload validation and bounded image normalization."""

from __future__ import annotations

import asyncio
import io
import mimetypes
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError


UPLOAD_CONCURRENCY = 4
upload_semaphore = asyncio.Semaphore(UPLOAD_CONCURRENCY)
PRIVATE_MEDIA_DIR = Path("uploads/private-media")
BLOCKED_TYPES = {
    "image/svg+xml",
    "text/html",
    "application/xhtml+xml",
    "application/xml",
    "text/xml",
}
SAFE_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


async def read_upload(
    file: UploadFile,
    *,
    max_bytes: int,
    max_image_bytes: int | None = None,
    allow_types: set[str] | None = None,
) -> tuple[bytes, str, str]:
    filename = Path(file.filename or f"{uuid4().hex}.bin").name[:500]
    content_type = (file.content_type or mimetypes.guess_type(filename)[0] or "application/octet-stream").lower()
    if content_type in BLOCKED_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Активные форматы файлов запрещены")
    if allow_types is not None and not (
        content_type in allow_types
        or content_type.startswith("image/")
        or content_type.startswith("video/")
        or content_type.startswith("audio/")
    ):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неподдерживаемый формат файла")

    async with upload_semaphore:
        chunks: list[bytes] = []
        total = 0
        while total <= max_bytes:
            chunk = await file.read(min(1024 * 1024, max_bytes + 1 - total))
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > max_bytes:
                break
        content = b"".join(chunks)

    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл пустой")
    if len(content) > max_bytes:
        raise HTTPException(status_code=status.HTTP_413_CONTENT_TOO_LARGE, detail="Файл слишком большой")
    if content_type.startswith("image/"):
        if max_image_bytes is not None and len(content) > max_image_bytes:
            raise HTTPException(status_code=status.HTTP_413_CONTENT_TOO_LARGE, detail="Изображение слишком большое")
        if content_type not in SAFE_IMAGE_TYPES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Этот формат изображения запрещён")
        content, content_type = normalize_image(content, content_type)
    return content, content_type, filename


def normalize_image(content: bytes, content_type: str) -> tuple[bytes, str]:
    try:
        with Image.open(io.BytesIO(content)) as image:
            image.verify()
        with Image.open(io.BytesIO(content)) as image:
            image.load()
            if image.mode not in {"RGB", "RGBA"}:
                image = image.convert("RGBA" if "transparency" in image.info else "RGB")
            output = io.BytesIO()
            if content_type == "image/jpeg":
                image.convert("RGB").save(output, format="JPEG", quality=88, optimize=True)
            elif content_type == "image/png":
                image.save(output, format="PNG", optimize=True)
            else:
                image.save(output, format="WEBP", quality=88, method=4)
            return output.getvalue(), content_type
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл не является корректным изображением") from error
