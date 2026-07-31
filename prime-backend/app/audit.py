"""Structured security audit event writer."""

from __future__ import annotations

import json
from typing import Any
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from .models import AuditEvent


async def record_audit(
    session: AsyncSession,
    *,
    action: str,
    user_id: str | None = None,
    request_id: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> AuditEvent:
    event = AuditEvent(
        id=str(uuid4()),
        user_id=user_id,
        action=action,
        request_id=request_id,
        metadata_json=json.dumps(metadata or {}, ensure_ascii=False, default=str),
    )
    session.add(event)
    await session.flush()
    return event
