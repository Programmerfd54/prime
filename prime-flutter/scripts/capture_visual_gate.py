#!/usr/bin/env python3
"""Capture visual gate screenshots at 390x844 via headless Chromium."""
from __future__ import annotations

import argparse
import asyncio
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "prime-visual-redesign" / "gate-captures"
PASSWORD = "DemoPrime123!"

ACCOUNTS = {
    "filled": "demo-filled@example.com",
    "empty": "demo-empty@example.com",
}

SCREENS = [
    ("home", "Главная"),
    ("habits", "Привычки"),
    ("chats", "Чаты"),
    ("profile", "Профиль"),
]


def api_login(base_api: str, email: str) -> str:
    payload = json.dumps(
        {"email": email, "password": PASSWORD, "developer_mode": False}
    ).encode()
    req = urllib.request.Request(
        f"{base_api.rstrip('/')}/auth/login",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = json.loads(resp.read())
    token = body.get("access_token")
    if not token:
        raise RuntimeError(f"login failed for {email}")
    return str(token)


async def seed_auth(page, token: str) -> None:
    await page.evaluate(
        """(token) => {
          const keys = [
            'flutter.secure_storage.prime_access_token',
            'flutter_secure_storage.prime_access_token',
            'prime_access_token',
          ];
          for (const k of keys) {
            localStorage.setItem(k, token);
          }
          localStorage.setItem('flutter.prime_onboarding_done', 'true');
        }""",
        token,
    )


async def login_ui(page, email: str, base_api: str) -> None:
    try:
        token = api_login(base_api, email)
        await seed_auth(page, token)
        await page.reload(wait_until="domcontentloaded")
        await page.wait_for_timeout(8000)
        return
    except Exception as exc:
        print(f"api login inject failed: {exc}")
    link = page.get_by_text("Уже есть аккаунт? Войти")
    if await link.count():
        await link.first.click()
        await page.wait_for_timeout(1500)
    inputs = page.locator("input")
    count = await inputs.count()
    if count >= 2:
        await inputs.nth(0).fill(email)
        await inputs.nth(1).fill(PASSWORD)
        btn = page.get_by_text("Войти", exact=True)
        if await btn.count():
            await btn.first.click()
            await page.wait_for_timeout(6000)


async def open_tab(page, label: str) -> None:
    tab = page.get_by_text(label, exact=True)
    if await tab.count():
        await tab.first.click()
        await page.wait_for_timeout(2000)


async def capture(base_url: str, base_api: str) -> None:
    from playwright.async_api import async_playwright

    OUT.mkdir(parents=True, exist_ok=True)
    viewport = {"width": 390, "height": 844}

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        for scenario, email in ACCOUNTS.items():
            context = await browser.new_context(viewport=viewport)
            page = await context.new_page()
            await page.goto(base_url, wait_until="domcontentloaded", timeout=120_000)
            await page.wait_for_selector("flutter-view, flt-glass-pane", timeout=60_000)
            await page.wait_for_timeout(8000)
            await login_ui(page, email, base_api)
            await page.wait_for_timeout(8000)

            for slug, label in SCREENS:
                await open_tab(page, label)
                path = OUT / f"{scenario}_{slug}.png"
                await page.screenshot(path=str(path), full_page=False)
                print(f"wrote {path}")

            if scenario == "filled":
                await open_tab(page, "Привычки")
                card = page.locator('text=Утренний фокус').first
                if await card.count():
                    await card.click()
                    await page.wait_for_timeout(2500)
                    detail = OUT / f"{scenario}_habit_detail.png"
                    await page.screenshot(path=str(detail), full_page=False)
                    print(f"wrote {detail}")

            await context.close()
        await browser.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    parser.add_argument("--api-url", default="http://127.0.0.1:8080/api/v1")
    args = parser.parse_args()
    asyncio.run(capture(args.base_url, args.api_url))


if __name__ == "__main__":
    main()
