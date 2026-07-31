from __future__ import annotations

import argparse
import json
import statistics
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Any


@dataclass
class Result:
    name: str
    ok: bool
    status: int
    elapsed_ms: float
    error: str = ""


def request_json(
    base_url: str,
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
) -> tuple[int, Any]:
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        raw = response.read()
        if not raw:
            return response.status, None
        return response.status, json.loads(raw.decode("utf-8"))


def timed(name: str, fn) -> tuple[Result, Any]:
    start = time.perf_counter()
    try:
        status, body = fn()
        elapsed = (time.perf_counter() - start) * 1000
        return Result(name, 200 <= status < 300, status, elapsed), body
    except urllib.error.HTTPError as exc:
        elapsed = (time.perf_counter() - start) * 1000
        detail = exc.read().decode("utf-8", errors="replace")
        return Result(name, False, exc.code, elapsed, detail[:300]), None
    except Exception as exc:  # noqa: BLE001 - CLI diagnostic tool
        elapsed = (time.perf_counter() - start) * 1000
        return Result(name, False, 0, elapsed, repr(exc)), None


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    values = sorted(values)
    index = min(len(values) - 1, max(0, round((len(values) - 1) * p)))
    return values[index]


def run_health_load(base_url: str, total: int, concurrency: int) -> list[Result]:
    def one(i: int) -> Result:
        result, _ = timed("health", lambda: request_json(base_url, "GET", "/health"))
        return result

    results: list[Result] = []
    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = [pool.submit(one, i) for i in range(total)]
        for future in as_completed(futures):
            results.append(future.result())
    return results


def run_user_flow(base_url: str, users: int, concurrency: int) -> list[Result]:
    stamp = int(time.time())
    password = "PrimeLoad123"

    def one(i: int) -> list[Result]:
        nickname = f"load{stamp}_{i}"
        email = f"{nickname}@example.com"
        name = f"Load User {i}"
        results: list[Result] = []

        result, register_body = timed(
            "register",
            lambda: request_json(
                base_url,
                "POST",
                "/auth/register",
                {
                    "email": email,
                    "password": password,
                    "name": name,
                    "nickname": nickname,
                },
            ),
        )
        results.append(result)
        # Register only creates a pending account; the token comes from
        # verify-email, and ENABLE_DEV_TOOLS exposes the code to get there.
        code = (register_body or {}).get("verification_code")
        if not code:
            return results

        result, verify_body = timed(
            "verify_email",
            lambda: request_json(
                base_url,
                "POST",
                "/auth/verify-email",
                {"email": email, "code": code},
            ),
        )
        results.append(result)
        token = (verify_body or {}).get("access_token")
        if not token:
            return results

        result, _ = timed(
            "me",
            lambda: request_json(base_url, "GET", "/users/me", token=token),
        )
        results.append(result)

        encoded_nickname = urllib.parse.quote(nickname, safe="")
        result, _ = timed(
            "find_by_nickname",
            lambda: request_json(
                base_url,
                "GET",
                f"/users/by-nickname/{encoded_nickname}",
                token=token,
            ),
        )
        results.append(result)
        return results

    results: list[Result] = []
    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = [pool.submit(one, i) for i in range(users)]
        for future in as_completed(futures):
            results.extend(future.result())
    return results


def run_friend_flow(base_url: str) -> list[Result]:
    stamp = int(time.time())
    password = "PrimeLoad123"
    a_nick = f"frienda{stamp}"
    b_nick = f"friendb{stamp}"
    results: list[Result] = []

    result, a = timed(
        "friend_register_a",
        lambda: request_json(
            base_url,
            "POST",
            "/auth/register",
            {
                "email": f"{a_nick}@example.com",
                "password": password,
                "name": "Friend A",
                "nickname": a_nick,
            },
        ),
    )
    results.append(result)
    result, b = timed(
        "friend_register_b",
        lambda: request_json(
            base_url,
            "POST",
            "/auth/register",
            {
                "email": f"{b_nick}@example.com",
                "password": password,
                "name": "Friend B",
                "nickname": b_nick,
            },
        ),
    )
    results.append(result)

    def verify(label: str, nickname: str, register_body: Any) -> str | None:
        code = (register_body or {}).get("verification_code")
        if not code:
            return None
        result, body = timed(
            label,
            lambda: request_json(
                base_url,
                "POST",
                "/auth/verify-email",
                {"email": f"{nickname}@example.com", "code": code},
            ),
        )
        results.append(result)
        return (body or {}).get("access_token")

    a_token = verify("friend_verify_a", a_nick, a)
    b_token = verify("friend_verify_b", b_nick, b)
    if not a_token or not b_token:
        return results

    result, _ = timed(
        "friend_request",
        lambda: request_json(
            base_url,
            "POST",
            "/friends/requests",
            {"nickname": b_nick},
            token=a_token,
        ),
    )
    results.append(result)

    result, requests_body = timed(
        "friend_requests_inbox",
        lambda: request_json(base_url, "GET", "/friends/requests", token=b_token),
    )
    results.append(result)

    result, notifications_body = timed(
        "notifications",
        lambda: request_json(base_url, "GET", "/notifications", token=b_token),
    )
    results.append(result)

    requests = (requests_body or {}).get("requests") or []
    notifications = (notifications_body or {}).get("requests") or []
    synced = (
        len(requests) == 1
        and len(notifications) == 1
        and requests[0]["id"] == notifications[0]["id"]
        and requests[0]["requester"]["nickname"] == a_nick
        and notifications[0]["requester"]["nickname"] == a_nick
    )
    results.append(Result("friend_notifications_synced", synced, 200 if synced else 500, 0))
    return results


def run_moderation_probe(base_url: str, nickname: str, password: str) -> list[Result]:
    email = f"loadmod+{nickname}@example.com"
    results: list[Result] = []
    _, register_body = timed(
        "moderation_register",
        lambda: request_json(
            base_url,
            "POST",
            "/auth/register",
            {"email": email, "password": password, "name": "Load", "nickname": nickname},
        ),
    )
    code = (register_body or {}).get("verification_code")
    if not code:
        return results
    _, verify_body = timed(
        "moderation_verify",
        lambda: request_json(base_url, "POST", "/auth/verify-email", {"email": email, "code": code}),
    )
    token = (verify_body or {}).get("access_token")
    if not token:
        return results
    result, _ = timed(
        "moderation_classify_path",
        lambda: request_json(
            base_url,
            "GET",
            "/users/me/restriction",
            token=token,
        ),
    )
    results.append(result)
    return results


def print_summary(results: list[Result]) -> None:
    by_name: dict[str, list[Result]] = {}
    for result in results:
        by_name.setdefault(result.name, []).append(result)

    print("name,total,ok,errors,avg_ms,p95_ms,max_ms")
    for name in sorted(by_name):
        items = by_name[name]
        latencies = [item.elapsed_ms for item in items]
        ok = sum(1 for item in items if item.ok)
        print(
            f"{name},{len(items)},{ok},{len(items)-ok},"
            f"{statistics.fmean(latencies):.1f},{percentile(latencies, 0.95):.1f},{max(latencies):.1f}"
        )

    failures = [item for item in results if not item.ok]
    if failures:
        print("\nfailures:")
        for item in failures[:20]:
            print(f"- {item.name}: status={item.status} elapsed={item.elapsed_ms:.1f}ms {item.error}")
        raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="https://api.inpr1me.ru/api/v1")
    parser.add_argument("--health-total", type=int, default=200)
    parser.add_argument("--health-concurrency", type=int, default=20)
    parser.add_argument("--users", type=int, default=30)
    parser.add_argument("--user-concurrency", type=int, default=10)
    parser.add_argument(
        "--moderation-probe",
        action="store_true",
        help="Run authenticated restriction endpoint probe after user flow.",
    )
    args = parser.parse_args()

    results: list[Result] = []
    results.extend(run_health_load(args.base_url, args.health_total, args.health_concurrency))
    if not args.health_only:
        results.extend(run_user_flow(args.base_url, args.users, args.user_concurrency))
        results.extend(run_friend_flow(args.base_url))
        if args.moderation_probe:
            results.extend(run_moderation_probe(args.base_url, "loadmoduser", "LoadTest123!"))
    print_summary(results)


if __name__ == "__main__":
    main()
