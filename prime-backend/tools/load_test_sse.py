from __future__ import annotations

import argparse
import asyncio
import json
import statistics
import time
from pathlib import Path

import httpx


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


async def run(args: argparse.Namespace) -> int:
    tokens = json.loads(Path(args.token_file).read_text(encoding="utf-8"))
    if not isinstance(tokens, list) or not tokens:
        raise SystemExit("token file must contain a non-empty JSON array")

    connected = 0
    failures: list[str] = []
    connect_ms: list[float] = []
    lock = asyncio.Lock()
    timeout = httpx.Timeout(connect=args.connect_timeout, read=None, write=15, pool=30)
    limits = httpx.Limits(
        max_connections=args.connections + 20,
        max_keepalive_connections=0,
    )

    async with httpx.AsyncClient(
        timeout=timeout,
        limits=limits,
        http2=False,
        trust_env=False,
    ) as client:

        async def one(index: int) -> None:
            nonlocal connected
            if args.ramp_per_second > 0:
                await asyncio.sleep(index / args.ramp_per_second)
            started = time.perf_counter()
            token = str(tokens[index % len(tokens)])
            try:
                async with client.stream(
                    "GET",
                    args.url,
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Accept": "text/event-stream",
                    },
                ) as response:
                    if response.status_code != 200:
                        body = (await response.aread())[:200]
                        raise RuntimeError(f"HTTP {response.status_code}: {body!r}")
                    iterator = response.aiter_bytes()
                    first = await anext(iterator)
                    if not first:
                        raise RuntimeError("empty initial SSE frame")
                    elapsed = (time.perf_counter() - started) * 1000
                    async with lock:
                        connected += 1
                        connect_ms.append(elapsed)
                    deadline = time.monotonic() + args.hold_seconds
                    async for _chunk in iterator:
                        if time.monotonic() >= deadline:
                            break
            except Exception as exc:  # noqa: BLE001 - diagnostic CLI
                async with lock:
                    failures.append(f"#{index}: {type(exc).__name__}: {exc}")

        await asyncio.gather(*(one(index) for index in range(args.connections)))

    print(
        json.dumps(
            {
                "requested": args.connections,
                "connected": connected,
                "failed": len(failures),
                "connect_avg_ms": round(statistics.fmean(connect_ms), 1)
                if connect_ms
                else 0,
                "connect_p95_ms": round(percentile(connect_ms, 0.95), 1),
                "connect_max_ms": round(max(connect_ms), 1) if connect_ms else 0,
                "hold_seconds": args.hold_seconds,
            },
            ensure_ascii=False,
        )
    )
    for failure in failures[:20]:
        print(failure)
    return 0 if connected == args.connections and not failures else 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--token-file", required=True)
    parser.add_argument("--connections", type=int, required=True)
    parser.add_argument("--hold-seconds", type=float, default=30)
    parser.add_argument("--ramp-per-second", type=float, default=50)
    parser.add_argument("--connect-timeout", type=float, default=20)
    args = parser.parse_args()
    raise SystemExit(asyncio.run(run(args)))


if __name__ == "__main__":
    main()
