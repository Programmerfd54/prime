#!/usr/bin/env python3
"""Seed two friend-linked accounts for manual E2E (avatar, DM, product v2).

Usage:
  python3 tools/seed_e2e_pair.py --base-url http://127.0.0.1:8080/api/v1

Re-run is idempotent: existing users are logged in; friendship is ensured.
"""
from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request
from typing import Any

PASSWORD = "E2ePrime123!"
ABOUT = " ".join(["слово"] * 50)

USER_A = {
    "email": "e2e.alpha@example.com",
    "nickname": "e2ealpha",
    "name": "E2E Alpha",
}
USER_B = {
    "email": "e2e.beta@example.com",
    "nickname": "e2ebeta",
    "name": "E2E Beta",
}


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
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        raw = response.read()
        if not raw:
            return response.status, None
        return response.status, json.loads(raw.decode("utf-8"))


def api(
    base_url: str,
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
) -> Any:
    try:
        _, body = request_json(base_url, method, path, payload, token)
        return body
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {path} -> HTTP {exc.code}: {text[:500]}") from exc


def login_or_register(base_url: str, user: dict[str, str]) -> str:
    login = api(
        base_url,
        "POST",
        "/auth/login",
        {"email": user["email"], "password": PASSWORD, "developer_mode": False},
    )
    if isinstance(login, dict) and login.get("access_token"):
        return str(login["access_token"])

    registered = api(
        base_url,
        "POST",
        "/auth/register",
        {
            "email": user["email"],
            "password": PASSWORD,
            "name": user["name"],
            "nickname": user["nickname"],
        },
    )
    token = registered.get("access_token") if isinstance(registered, dict) else None
    if not token:
        raise RuntimeError(f"register failed for {user['email']}")
    return str(token)


def ensure_profile(base_url: str, token: str) -> None:
    api(
        base_url,
        "PATCH",
        "/users/me",
        {
            "about": ABOUT,
            "region_code": "77",
            "city": "Москва",
            "age": 28,
        },
        token=token,
    )


def ensure_friendship(base_url: str, token_a: str, token_b: str, nick_b: str) -> None:
    inbox_b = api(base_url, "GET", "/direct-chats", token=token_b)
    friends_b = {
        item.get("friend", {}).get("nickname")
        for item in (inbox_b or {}).get("conversations", [])
        if isinstance(inbox_b, dict)
    }
    if USER_A["nickname"] in friends_b:
        return

    api(
        base_url,
        "POST",
        "/friends/requests",
        {"nickname": nick_b},
        token=token_a,
    )
    pending = api(base_url, "GET", "/friends/requests", token=token_b)
    requests_list = pending.get("requests", []) if isinstance(pending, dict) else []
    for item in requests_list:
        if item.get("requester", {}).get("nickname") == USER_A["nickname"]:
            api(
                base_url,
                "POST",
                f"/friends/requests/{item['id']}/respond",
                {"accept": True},
                token=token_b,
            )
            return
    raise RuntimeError("friend request was not created or found")


def seed_preferences(base_url: str, token: str) -> None:
    api(
        base_url,
        "PATCH",
        "/users/me/preferences",
        {
            "goal": "betterMorning",
            "selected_skill_id": "morning-focus",
        },
        token=token,
    )
    api(
        base_url,
        "POST",
        "/users/me/favorites/morning-focus",
        token=token,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed E2E alpha/beta friend pair")
    parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8080/api/v1",
        help="API base including /api/v1",
    )
    parser.add_argument(
        "--skip-prefs",
        action="store_true",
        help="Skip onboarding prefs + favorites seed",
    )
    args = parser.parse_args()
    base_url = args.base_url.rstrip("/")

    token_a = login_or_register(base_url, USER_A)
    token_b = login_or_register(base_url, USER_B)
    ensure_profile(base_url, token_a)
    ensure_profile(base_url, token_b)
    ensure_friendship(base_url, token_a, token_b, USER_B["nickname"])
    if not args.skip_prefs:
        seed_preferences(base_url, token_a)
        seed_preferences(base_url, token_b)

    print("E2E pair ready\n")
    print("Device A (Alpha)")
    print(f"  email:    {USER_A['email']}")
    print(f"  password: {PASSWORD}")
    print(f"  nickname: @{USER_A['nickname']}")
    print("")
    print("Device B (Beta)")
    print(f"  email:    {USER_B['email']}")
    print(f"  password: {PASSWORD}")
    print(f"  nickname: @{USER_B['nickname']}")
    print("")
    print("Next: docs/prime-visual-redesign/11-E2E-QA-CHECKLIST.md")


if __name__ == "__main__":
    main()
