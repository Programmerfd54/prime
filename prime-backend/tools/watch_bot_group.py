from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


@dataclass
class Bot:
    email: str
    nickname: str
    token: str = ""


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
        headers["Content-Type"] = "application/json; charset=utf-8"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        raw = response.read()
        if not raw:
            return response.status, None
        return response.status, json.loads(raw.decode("utf-8"))


def safe_request(
    base_url: str,
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
) -> Any | None:
    try:
        _, body = request_json(base_url, method, path, payload, token)
        return body
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace")
        print(f"{method} {path} -> HTTP {exc.code}: {text[:300]}", flush=True)
        return None
    except Exception as exc:  # noqa: BLE001 - diagnostic watcher
        print(f"{method} {path} -> {exc!r}", flush=True)
        return None


def login_bots(base_url: str, bots: list[Bot], password: str) -> None:
    for bot in bots:
        body = safe_request(
            base_url,
            "POST",
            "/auth/login",
            {"email": bot.email, "password": password, "developer_mode": False},
        )
        if not body or not body.get("access_token"):
            raise RuntimeError(f"Cannot login bot {bot.email}")
        bot.token = body["access_token"]
        print(f"logged in {bot.nickname}", flush=True)


def find_group(base_url: str, bot: Bot, skill_id: str) -> str | None:
    status = safe_request(
        base_url,
        "GET",
        f"/groups/waiting-room?skill_id={skill_id}",
        token=bot.token,
    )
    if isinstance(status, dict) and status.get("matched_group_id"):
        return str(status["matched_group_id"])

    groups = safe_request(base_url, "GET", "/groups", token=bot.token)
    if isinstance(groups, list):
        for group in groups:
            if group.get("skill_id") == skill_id:
                return str(group["id"])
    return None


def group_status(base_url: str, bot: Bot, group_id: str) -> str | None:
    group = safe_request(base_url, "GET", f"/groups/{group_id}", token=bot.token)
    if isinstance(group, dict):
        return str(group.get("status") or "")
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="https://api.inpr1me.ru/api/v1")
    parser.add_argument("--password", default="PrimeBot123")
    parser.add_argument("--skill-id", default="morning-focus")
    parser.add_argument("--nick-prefix", required=True)
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument("--poll-seconds", type=int, default=15)
    args = parser.parse_args()

    bots = [
        Bot(
            email=f"{args.nick_prefix}{i}@example.com",
            nickname=f"{args.nick_prefix}{i}",
        )
        for i in range(1, 6)
    ]
    login_bots(args.base_url, bots, args.password)

    deadline = time.time() + args.timeout_seconds
    group_id: str | None = None
    confirmed = False
    accepted = False
    intro_sent = False

    print(
        f"watching {args.skill_id}; waiting until group appears for {bots[0].nickname}",
        flush=True,
    )
    while time.time() < deadline:
        if group_id is None:
            group_id = find_group(args.base_url, bots[0], args.skill_id)
            if group_id:
                print(f"group found: {group_id}", flush=True)

        if group_id and not confirmed:
            for bot in bots:
                safe_request(
                    args.base_url,
                    "POST",
                    f"/groups/{group_id}/intro/continue",
                    token=bot.token,
                )
            confirmed = True
            print("bots confirmed participation", flush=True)

        if group_id and not accepted:
            for bot in bots:
                safe_request(
                    args.base_url,
                    "POST",
                    f"/groups/{group_id}/rules/accept",
                    token=bot.token,
                )
            accepted = True
            print("bots accepted rules", flush=True)

        if group_id and confirmed and accepted:
            status = group_status(args.base_url, bots[0], group_id)
            print(f"group {group_id} status={status}", flush=True)
            if status == "active" and not intro_sent:
                for index, bot in enumerate(bots, start=1):
                    safe_request(
                        args.base_url,
                        "POST",
                        f"/chat/{group_id}/messages",
                        {
                            "body": (
                                f"Привет! Я {bot.nickname}, тестовый участник #{index}. "
                                "Я в группе для проверки чата, отчётов, истории сообщений, "
                                "личных сообщений и начисления прайсов."
                            )
                        },
                        token=bot.token,
                    )
                intro_sent = True
                print("intro messages sent by all bots", flush=True)
                print(json.dumps({"group_id": group_id, "status": status}, ensure_ascii=False), flush=True)
                return

        time.sleep(args.poll_seconds)

    raise SystemExit("timeout: group did not become active")


if __name__ == "__main__":
    main()
