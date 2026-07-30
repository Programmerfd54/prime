"""Small opaque keyset cursors shared by list endpoints."""

import base64
import binascii
import json
from datetime import datetime


def encode_cursor(created_at: datetime, item_id: str) -> str:
    raw = json.dumps(
        {"created_at": created_at.isoformat(), "id": item_id},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, str]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        created_at = datetime.fromisoformat(str(payload["created_at"]))
        item_id = str(payload["id"])
        if not item_id:
            raise ValueError
        return created_at, item_id
    except (
        KeyError,
        TypeError,
        ValueError,
        json.JSONDecodeError,
        UnicodeError,
        binascii.Error,
    ) as exc:
        raise ValueError("Invalid cursor") from exc
