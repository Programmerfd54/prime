from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


PASSWORD = "PrimeBot123"
API_BASE_URL = "https://api.inpr1me.ru/api/v1"


ABOUT_WORDS = (
    "Я тестовый участник ПРАЙМ для проверки очередей групп чата правил отчётов "
    "уведомлений профиля статистики и поиска по всей России. Люблю спокойный ритм "
    "маленькие ежедневные действия честную обратную связь поддержку команды и понятные "
    "цели. В группе буду помогать проверить вступительное сообщение сохранение истории "
    "личные сообщения реакции начисление праймов и стабильность приложения на тесте."
)


@dataclass(frozen=True)
class QueuePlan:
    key: str
    skill_id: str
    region_code: str
    region_name: str
    prefix: str
    allow_other_regions: bool = False


PLANS: tuple[QueuePlan, ...] = (
    QueuePlan(
        key="che_live",
        skill_id="live-communication",
        region_code="74",
        region_name="Челябинская область",
        prefix="p23chelive",
    ),
    QueuePlan(
        key="che_focus",
        skill_id="morning-focus",
        region_code="74",
        region_name="Челябинская область",
        prefix="p23chefocus",
    ),
    QueuePlan(
        key="che_detox",
        skill_id="digital-detox",
        region_code="74",
        region_name="Челябинская область",
        prefix="p23chedetox",
    ),
    QueuePlan(
        key="msk_chapter",
        skill_id="one-chapter",
        region_code="77",
        region_name="Москва",
        prefix="p23mskchapter",
        allow_other_regions=True,
    ),
    QueuePlan(
        key="mo_body",
        skill_id="body-charge",
        region_code="50",
        region_name="Московская область",
        prefix="p23mobody",
        allow_other_regions=True,
    ),
    QueuePlan(
        key="spb_evening",
        skill_id="evening-ritual",
        region_code="78",
        region_name="Санкт-Петербург",
        prefix="p23spbevening",
        allow_other_regions=True,
    ),
)


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
    with urllib.request.urlopen(req, timeout=25) as response:
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
        print(f"{method} {path} -> HTTP {exc.code}: {text[:400]}", flush=True)
        return None
    except Exception as exc:  # noqa: BLE001 - test tool diagnostics
        print(f"{method} {path} -> {exc!r}", flush=True)
        return None


def bot_email(plan: QueuePlan, index: int) -> str:
    return f"{plan.prefix}{index:02d}@example.com"


def bot_nickname(plan: QueuePlan, index: int) -> str:
    return f"{plan.prefix}{index:02d}"


def login_or_register(base_url: str, plan: QueuePlan, index: int) -> str:
    email = bot_email(plan, index)
    nickname = bot_nickname(plan, index)
    login = safe_request(
        base_url,
        "POST",
        "/auth/login",
        {"email": email, "password": PASSWORD, "developer_mode": False},
    )
    if isinstance(login, dict) and login.get("access_token"):
        return str(login["access_token"])

    registered = safe_request(
        base_url,
        "POST",
        "/auth/register",
        {
            "email": email,
            "password": PASSWORD,
            "name": f"Бот {plan.region_name} {index}",
            "nickname": nickname,
        },
    )
    if not isinstance(registered, dict) or not registered.get("access_token"):
        raise RuntimeError(f"Cannot login/register {email}")
    return str(registered["access_token"])


def seed(base_url: str, count: int) -> None:
    for plan in PLANS:
        for index in range(1, count + 1):
            token = login_or_register(base_url, plan, index)
            nickname = bot_nickname(plan, index)
            safe_request(
                base_url,
                "PATCH",
                "/users/me",
                {
                    "name": f"Бот {plan.region_name} {index}",
                    "nickname": nickname,
                    "about": ABOUT_WORDS,
                    "city": plan.region_name,
                    "region_code": plan.region_code,
                    "age": 20 + index,
                },
                token=token,
            )
            status = safe_request(
                base_url,
                "POST",
                "/groups/waiting-room",
                {"skill_id": plan.skill_id},
                token=token,
            )
            print(
                json.dumps(
                    {
                        "bot": nickname,
                        "skill_id": plan.skill_id,
                        "region_code": plan.region_code,
                        "allow_other_regions": plan.allow_other_regions,
                        "queue_position": status.get("position") if isinstance(status, dict) else None,
                        "matched_group_id": status.get("matched_group_id") if isinstance(status, dict) else None,
                    },
                    ensure_ascii=False,
                ),
                flush=True,
            )


def find_group(base_url: str, token: str, skill_id: str) -> str | None:
    status = safe_request(base_url, "GET", f"/groups/waiting-room?skill_id={skill_id}", token=token)
    if isinstance(status, dict) and status.get("matched_group_id"):
        return str(status["matched_group_id"])

    groups = safe_request(base_url, "GET", "/groups", token=token)
    if isinstance(groups, list):
        for group in groups:
            if group.get("skill_id") == skill_id:
                return str(group["id"])
    return None


def accept_group(base_url: str, token: str, group_id: str) -> None:
    safe_request(base_url, "POST", f"/groups/{group_id}/intro/continue", token=token)
    safe_request(base_url, "POST", f"/groups/{group_id}/rules/accept", token=token)


def group_status(base_url: str, token: str, group_id: str) -> str | None:
    group = safe_request(base_url, "GET", f"/groups/{group_id}", token=token)
    if isinstance(group, dict):
        return str(group.get("status") or "")
    return None


def send_intro(base_url: str, token: str, group_id: str, nickname: str, index: int) -> None:
    safe_request(
        base_url,
        "POST",
        f"/chat/{group_id}/messages",
        {
            "body": (
                f"Привет! Я {nickname}, тестовый участник #{index}. "
                "Я здесь для проверки чата, вступительного сообщения, правил, отчётов, "
                "истории сообщений, реакций и личного общения."
            )
        },
        token=token,
    )


def watch(base_url: str, count: int, timeout_seconds: int, poll_seconds: int) -> None:
    tokens: dict[str, list[tuple[str, str]]] = {}
    for plan in PLANS:
        tokens[plan.key] = [
            (bot_nickname(plan, index), login_or_register(base_url, plan, index))
            for index in range(1, count + 1)
        ]

    done_intro: set[str] = set()
    deadline = time.time() + timeout_seconds
    print("watcher started", flush=True)
    while time.time() < deadline:
        for plan in PLANS:
            first_token = tokens[plan.key][0][1]
            group_id = find_group(base_url, first_token, plan.skill_id)
            if not group_id:
                continue

            for nickname, token in tokens[plan.key]:
                accept_group(base_url, token, group_id)

            status = group_status(base_url, first_token, group_id)
            print(
                json.dumps(
                    {"skill_id": plan.skill_id, "group_id": group_id, "status": status},
                    ensure_ascii=False,
                ),
                flush=True,
            )
            if status == "active" and group_id not in done_intro:
                for index, (nickname, token) in enumerate(tokens[plan.key], start=1):
                    send_intro(base_url, token, group_id, nickname, index)
                done_intro.add(group_id)
        time.sleep(poll_seconds)

    print("watcher finished by timeout", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default=API_BASE_URL)
    parser.add_argument("--count", type=int, default=4)
    parser.add_argument("--mode", choices=["seed", "watch"], default="seed")
    parser.add_argument("--timeout-seconds", type=int, default=24 * 60 * 60)
    parser.add_argument("--poll-seconds", type=int, default=15)
    args = parser.parse_args()

    if args.mode == "seed":
        seed(args.base_url, args.count)
    else:
        watch(args.base_url, args.count, args.timeout_seconds, args.poll_seconds)


if __name__ == "__main__":
    main()
