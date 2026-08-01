"""Isolated media stress-test utility.

This tool intentionally supports direct database seeding.  Run it only against
a disposable database and object-storage bucket; never point it at production.
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import io
import json
import random
import statistics
import time
from collections import Counter
from datetime import timedelta
from pathlib import Path
from uuid import uuid4

import httpx
from jose import jwt
from PIL import Image
from sqlalchemy import func, insert, select


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def _load_token(user_id: str, session_id: str, *, hours: int = 2) -> str:
    """Issue a staging-only token long enough for a multi-stage test."""
    from app.config import get_settings
    from app.models import utcnow

    settings = get_settings()
    now = utcnow()
    payload = {
        "sub": user_id,
        "sid": session_id,
        "jti": str(uuid4()),
        "iat": now,
        "exp": now + timedelta(hours=hours),
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


async def seed(args: argparse.Namespace) -> int:
    from app.db import SessionLocal
    from app.models import AuthSession, Group, GroupMember, User, utcnow

    if args.users < 1 or args.members_per_group < 1:
        raise SystemExit("users and members-per-group must be positive")
    now = utcnow()
    expires_at = now + timedelta(hours=3)
    manifest: list[dict[str, str]] = []
    groups: list[dict] = []
    users: list[dict] = []
    memberships: list[dict] = []
    sessions: list[dict] = []

    for group_index in range((args.users + args.members_per_group - 1) // args.members_per_group):
        group_id = str(uuid4())
        groups.append(
            {
                "id": group_id,
                "name": f"Media load group {group_index}",
                "skill_id": "digital_detox",
                "region_code": "74",
                "reference_timezone": "Asia/Yekaterinburg",
                "is_cross_region": False,
                "status": "active",
                "max_members": args.members_per_group,
                "revision": 1,
                "updated_at": now,
            }
        )
        first = group_index * args.members_per_group
        last = min(first + args.members_per_group, args.users)
        for index in range(first, last):
            user_id = str(uuid4())
            auth_session_id = str(uuid4())
            users.append(
                {
                    "id": user_id,
                    "email": f"media-load-{index}@example.invalid",
                    "password_hash": "not-used-by-isolated-load-test",
                    "name": f"Media Load {index}",
                    "nickname": f"media_load_{index}",
                    "about": "Isolated media load-test account",
                    "region_code": "74",
                    "timezone": "Asia/Yekaterinburg",
                    "age": 25,
                    "profile_completed": True,
                    "prime_points": 0,
                    "successful_days": 0,
                    "can_create_custom_skills": False,
                    "streak_shields": 0,
                    "shield_pending": False,
                    "is_active": True,
                    "email_verified_at": now,
                    "marketing_emails_opt_in": False,
                    "privacy_settings": "{}",
                    "onboarding_preferences": "{}",
                    "is_moderator": False,
                    "updated_at": now,
                }
            )
            memberships.append(
                {
                    "id": str(uuid4()),
                    "group_id": group_id,
                    "user_id": user_id,
                    "role": "member",
                    "confirmed_participation": True,
                    "accepted_rules": True,
                    "active": True,
                    "streak": 0,
                    "best_streak": 0,
                }
            )
            refresh_hash = hashlib.sha256(f"media-load-{index}".encode()).hexdigest()
            sessions.append(
                {
                    "id": auth_session_id,
                    "user_id": user_id,
                    "refresh_token_hash": refresh_hash,
                    "expires_at": expires_at,
                    "last_used_at": now,
                    "user_agent": "isolated-media-load-test",
                    "ip_address": "127.0.0.1",
                }
            )
            manifest.append(
                {
                    "user_id": user_id,
                    "group_id": group_id,
                    "token": _load_token(user_id, auth_session_id),
                }
            )

    started = time.perf_counter()
    async with SessionLocal() as session:
        # Insert in bounded batches so the utility remains cheap even at 10k+
        # users and works with asyncpg's executemany path.
        for model, rows in (
            (Group, groups),
            (User, users),
            (GroupMember, memberships),
            (AuthSession, sessions),
        ):
            for offset in range(0, len(rows), args.batch_size):
                await session.execute(insert(model), rows[offset : offset + args.batch_size])
                await session.commit()

        counts = {
            "users": await session.scalar(select(func.count()).select_from(User)),
            "groups": await session.scalar(select(func.count()).select_from(Group)),
            "memberships": await session.scalar(select(func.count()).select_from(GroupMember)),
            "sessions": await session.scalar(select(func.count()).select_from(AuthSession)),
        }

    Path(args.output).write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")
    print(
        json.dumps(
            {
                "seeded": counts,
                "manifest": args.output,
                "elapsed_seconds": round(time.perf_counter() - started, 2),
            },
            ensure_ascii=False,
        )
    )
    return 0


def _image_payload() -> bytes:
    random_bytes = random.Random(20260801).randbytes(768 * 768 * 3)
    image = Image.frombytes("RGB", (768, 768), random_bytes)
    output = io.BytesIO()
    image.save(output, format="JPEG", quality=85, optimize=False)
    return output.getvalue()


def _payload_for(index: int, image: bytes, video: bytes, audio: bytes) -> tuple[str, bytes, str]:
    slot = index % 10
    if slot < 7:
        return f"report-{index}.jpg", image, "image/jpeg"
    if slot < 9:
        return f"report-{index}.mp4", video, "video/mp4"
    return f"report-{index}.m4a", audio, "audio/mp4"


async def upload(args: argparse.Namespace) -> int:
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    selected = manifest[args.start : args.start + args.count]
    if len(selected) != args.count:
        raise SystemExit(f"manifest only contains {len(selected)} requested records")

    image = _image_payload()
    video = bytes(args.video_bytes)
    audio = bytes(args.audio_bytes)
    payload_sizes = {"image": len(image), "video": len(video), "audio": len(audio)}
    queue: asyncio.Queue[tuple[int, dict] | None] = asyncio.Queue()
    for relative_index, entry in enumerate(selected):
        queue.put_nowait((args.start + relative_index, entry))
    for _ in range(args.concurrency):
        queue.put_nowait(None)

    latencies: list[float] = []
    statuses: Counter[int] = Counter()
    storage_schemes: Counter[str] = Counter()
    failure_samples: list[str] = []
    successful_bytes = 0
    completed = 0
    aborted = False
    lock = asyncio.Lock()
    started = time.perf_counter()
    timeout = httpx.Timeout(connect=15, read=args.request_timeout, write=args.request_timeout, pool=120)
    limits = httpx.Limits(max_connections=args.concurrency + 10, max_keepalive_connections=args.concurrency)

    async with httpx.AsyncClient(
        base_url=args.base_url.rstrip("/"),
        timeout=timeout,
        limits=limits,
        http2=False,
        trust_env=False,
    ) as client:

        async def worker() -> None:
            nonlocal aborted, completed, successful_bytes
            while True:
                item = await queue.get()
                if item is None:
                    queue.task_done()
                    return
                index, entry = item
                if aborted:
                    queue.task_done()
                    continue
                filename, content, content_type = _payload_for(index, image, video, audio)
                request_started = time.perf_counter()
                status_code = 0
                response_text = ""
                storage_scheme = ""
                try:
                    response = await client.post(
                        "/reports/upload",
                        headers={"Authorization": f"Bearer {entry['token']}"},
                        data={"group_id": entry["group_id"]},
                        files={"file": (filename, content, content_type)},
                    )
                    status_code = response.status_code
                    if status_code == 200:
                        body = response.json()
                        storage_url = str(body.get("storage_url") or "")
                        storage_scheme = storage_url.partition(":")[0] or "missing"
                    else:
                        response_text = response.text[:240]
                except Exception as exc:  # noqa: BLE001 - diagnostic CLI
                    response_text = f"{type(exc).__name__}: {exc}"

                elapsed_ms = (time.perf_counter() - request_started) * 1000
                async with lock:
                    completed += 1
                    latencies.append(elapsed_ms)
                    statuses[status_code] += 1
                    if status_code == 200:
                        successful_bytes += len(content)
                        storage_schemes[storage_scheme] += 1
                    elif len(failure_samples) < 20:
                        failure_samples.append(f"#{index} status={status_code} {response_text}")
                    failures = completed - statuses[200]
                    if completed >= args.abort_after and failures / completed > args.max_error_rate:
                        aborted = True
                    if completed % args.progress_every == 0:
                        print(
                            json.dumps(
                                {
                                    "progress": completed,
                                    "ok": statuses[200],
                                    "errors": failures,
                                    "elapsed_seconds": round(time.perf_counter() - started, 1),
                                }
                            ),
                            flush=True,
                        )
                queue.task_done()

        workers = [asyncio.create_task(worker()) for _ in range(args.concurrency)]
        await queue.join()
        await asyncio.gather(*workers)

    elapsed_seconds = time.perf_counter() - started
    result = {
        "requested": args.count,
        "completed": completed,
        "ok": statuses[200],
        "failed": completed - statuses[200],
        "aborted": aborted,
        "concurrency": args.concurrency,
        "elapsed_seconds": round(elapsed_seconds, 2),
        "requests_per_second": round(completed / elapsed_seconds, 2) if elapsed_seconds else 0,
        "latency_avg_ms": round(statistics.fmean(latencies), 1) if latencies else 0,
        "latency_p50_ms": round(percentile(latencies, 0.50), 1),
        "latency_p95_ms": round(percentile(latencies, 0.95), 1),
        "latency_p99_ms": round(percentile(latencies, 0.99), 1),
        "latency_max_ms": round(max(latencies), 1) if latencies else 0,
        "status_codes": dict(statuses),
        "storage_schemes": dict(storage_schemes),
        "successful_bytes": successful_bytes,
        "payload_sizes": payload_sizes,
        "failure_samples": failure_samples,
    }
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return 0 if not aborted and statuses[200] == args.count else 1


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    seed_parser = subparsers.add_parser("seed")
    seed_parser.add_argument("--users", type=int, default=10_000)
    seed_parser.add_argument("--members-per-group", type=int, default=5)
    seed_parser.add_argument("--batch-size", type=int, default=1_000)
    seed_parser.add_argument("--output", required=True)

    upload_parser = subparsers.add_parser("upload")
    upload_parser.add_argument("--base-url", required=True)
    upload_parser.add_argument("--manifest", required=True)
    upload_parser.add_argument("--start", type=int, default=0)
    upload_parser.add_argument("--count", type=int, required=True)
    upload_parser.add_argument("--concurrency", type=int, default=20)
    upload_parser.add_argument("--video-bytes", type=int, default=2 * 1024 * 1024)
    upload_parser.add_argument("--audio-bytes", type=int, default=256 * 1024)
    upload_parser.add_argument("--request-timeout", type=float, default=120)
    upload_parser.add_argument("--max-error-rate", type=float, default=0.05)
    upload_parser.add_argument("--abort-after", type=int, default=100)
    upload_parser.add_argument("--progress-every", type=int, default=500)

    args = parser.parse_args()
    if args.command == "seed":
        raise SystemExit(asyncio.run(seed(args)))
    raise SystemExit(asyncio.run(upload(args)))


if __name__ == "__main__":
    main()
