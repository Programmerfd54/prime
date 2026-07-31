#!/usr/bin/env python3
"""Introspect FastAPI routes and emit a security endpoint inventory.

Usage:
    cd prime-backend
    python tools/generate_security_inventory.py
    python tools/generate_security_inventory.py --format markdown
    python tools/generate_security_inventory.py --format json --output /tmp/routes.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

# Minimal env so `app.main` imports without a real database.
os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://prime:prime@127.0.0.1:5432/prime",
)
os.environ.setdefault("JWT_SECRET_KEY", "inventory-script-dev-only-secret")

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from fastapi.routing import APIRoute  # noqa: E402

from app.main import app  # noqa: E402


def _auth_hint(route: APIRoute) -> str:
    path = route.path
    public_auth = {
        "/api/v1/auth/email-available",
        "/api/v1/auth/nickname-available/{nickname}",
        "/api/v1/auth/register",
        "/api/v1/auth/verify-email",
        "/api/v1/auth/resend-verification",
        "/api/v1/auth/login",
        "/api/v1/auth/forgot-password",
        "/api/v1/auth/reset-password",
    }
    if path in public_auth:
        return "public"
    if path.startswith("/api/v1/auth/mfa/"):
        return "moderator JWT + step-up"
    if path.startswith("/api/v1/auth/"):
        return "bearer JWT"
    if path in {"/api/v1/health", "/api/v1/regions", "/api/v1/skills", "/api/v1/achievements"}:
        return "public"
    if path.startswith("/api/v1/ops/"):
        return "moderator + step-up MFA"
    if "moderator" in path or path.startswith("/api/v1/dev/"):
        return "moderator or dev-only"
    if "{user_id}/avatar" in path:
        return "public avatar read"
    return "bearer JWT"


def collect_routes() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        methods = sorted(m for m in route.methods if m not in {"HEAD", "OPTIONS"})
        rows.append(
            {
                "methods": methods,
                "path": route.path,
                "name": route.name,
                "tags": list(route.tags),
                "auth": _auth_hint(route),
            }
        )
    rows.sort(key=lambda row: (row["path"], ",".join(row["methods"])))
    return rows


def collect_sse_events() -> list[dict[str, str]]:
    return [
        {"event": "notification", "source": "GET /api/v1/events/stream", "payload": "in-app notification row"},
        {"event": "direct_message", "source": "GET /api/v1/events/stream", "payload": "DM message metadata"},
        {"event": "direct_chat_read", "source": "GET /api/v1/events/stream", "payload": "read receipt"},
        {"event": "waiting_room_update", "source": "GET /api/v1/events/stream", "payload": "queue revision"},
        {"event": "group_update", "source": "GET /api/v1/events/stream", "payload": "membership / intro phase"},
        {"event": "group_chat_update", "source": "GET /api/v1/events/stream", "payload": "new group chat message"},
        {"event": "heartbeat", "source": "GET /api/v1/events/stream", "payload": "SSE keep-alive comment"},
    ]


def to_markdown(routes: list[dict[str, Any]], events: list[dict[str, str]]) -> str:
    lines = [
        "# Generated endpoint inventory",
        "",
        f"Total HTTP routes: **{len(routes)}**",
        "",
        "## `/api/v1` routes",
        "",
        "| Methods | Path | Tags | Auth |",
        "|---|---|---|---|",
    ]
    for row in routes:
        methods = ", ".join(row["methods"])
        tags = ", ".join(row["tags"]) or "—"
        lines.append(f"| {methods} | `{row['path']}` | {tags} | {row['auth']} |")

    lines.extend(
        [
            "",
            "## SSE events (`/api/v1/events/stream`)",
            "",
            "| Event | Payload |",
            "|---|---|",
        ]
    )
    for event in events:
        lines.append(f"| `{event['event']}` | {event['payload']} |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--format",
        choices=("json", "markdown"),
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Write to file instead of stdout",
    )
    args = parser.parse_args()

    routes = collect_routes()
    events = collect_sse_events()
    payload = {"route_count": len(routes), "routes": routes, "sse_events": events}

    if args.format == "json":
        text = json.dumps(payload, indent=2, ensure_ascii=False)
    else:
        text = to_markdown(routes, events)

    if args.output:
        args.output.write_text(text, encoding="utf-8")
        print(f"Wrote {args.output}", file=sys.stderr)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
