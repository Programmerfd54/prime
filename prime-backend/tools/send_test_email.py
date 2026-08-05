#!/usr/bin/env python3
"""Send one test letter through the same SMTP settings as the API.

Usage (from prime-backend/, with .env filled in):

    python3 tools/send_test_email.py you@gmail.com

Docker API container uses the same .env — restart after changing SMTP_*.
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.config import get_settings  # noqa: E402
from app.db import SessionLocal, create_db_schema  # noqa: E402
from app.email_templates import build_verification_email  # noqa: E402
from app.email_unsubscribe import LETTER_MARKETING, create_unsubscribe_link  # noqa: E402
from app.mailer import send_email, smtp_configured  # noqa: E402
from app.models import User  # noqa: E402
from app.security import hash_password  # noqa: E402


async def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 tools/send_test_email.py recipient@example.com", file=sys.stderr)
        return 2
    recipient = sys.argv[1].strip().lower()
    if not smtp_configured():
        print("SMTP is not configured. Set SMTP_HOST, SMTP_USERNAME, MAIL_FROM in .env", file=sys.stderr)
        return 1
    settings = get_settings()
    await create_db_schema()
    async with SessionLocal() as session:
        user = await session.get(User, "00000000-0000-0000-0000-000000000001")
        if user is None:
            user = User(
                id="00000000-0000-0000-0000-000000000001",
                email=recipient,
                password_hash=hash_password("unused"),
                name="Тест",
                nickname="testmail",
            )
            session.add(user)
            await session.commit()
        unsubscribe_url = await create_unsubscribe_link(
            session,
            user_id=user.id,
            letter=LETTER_MARKETING,
        )
    subject, text, html, _ = build_verification_email(
        name="Тест",
        code="123456",
        ttl_minutes=15,
        email=recipient,
        unsubscribe_url=unsubscribe_url,
    )
    ok = await send_email(
        to=recipient,
        subject=subject,
        text_body=text,
        html_body=html,
        list_unsubscribe_url=unsubscribe_url,
    )
    if ok:
        print(f"OK: sent test mail to {recipient} via {settings.smtp_host} as {settings.mail_from}")
        return 0
    print("FAILED: see logs/prime-api.log or run with LOG_LEVEL=DEBUG", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
