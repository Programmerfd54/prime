import io

import pytest
from fastapi import HTTPException, UploadFile
from starlette.datastructures import Headers

from app.media import read_upload


@pytest.mark.asyncio
async def test_svg_upload_is_rejected() -> None:
    file = UploadFile(
        filename="avatar.svg",
        file=io.BytesIO(b"<svg><script>alert(1)</script></svg>"),
        headers=Headers({"content-type": "image/svg+xml"}),
    )
    with pytest.raises(HTTPException) as error:
        await read_upload(file, max_bytes=1024, max_image_bytes=1024, allow_types={"image/jpeg"})
    assert error.value.status_code == 400


@pytest.mark.asyncio
async def test_oversized_upload_is_rejected_before_unbounded_read() -> None:
    file = UploadFile(
        filename="large.png",
        file=io.BytesIO(b"x" * 2049),
        headers=Headers({"content-type": "image/png"}),
    )
    with pytest.raises(HTTPException) as error:
        await read_upload(file, max_bytes=2048, max_image_bytes=2048, allow_types={"image/png"})
    assert error.value.status_code == 413
