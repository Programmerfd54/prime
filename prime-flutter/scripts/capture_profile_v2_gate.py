#!/usr/bin/env python3
"""Capture Profile V2 visual gate screenshots (TZ §31)."""
from __future__ import annotations

import argparse
import asyncio
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "profile-v2" / "gate"
PASSWORD = "DemoPrime123!"

ACCOUNTS = {
    "filled": "demo-filled@example.com",
    "empty": "demo-empty@example.com",
}


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


async def open_tab(page, label: str) -> None:
    tab = page.get_by_text(label, exact=True)
    if await tab.count():
        await tab.first.click()
        await page.wait_for_timeout(2500)


async def capture(base_url: str, base_api: str) -> None:
    from playwright.async_api import async_playwright

    OUT.mkdir(parents=True, exist_ok=True)
    phone = {"width": 390, "height": 844}
    medium = {"width": 900, "height": 844}

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        for scenario, email in ACCOUNTS.items():
            ctx = await browser.new_context(viewport=phone)
            page = await ctx.new_page()
            await page.goto(base_url, wait_until="domcontentloaded", timeout=120_000)
            await page.wait_for_selector("flutter-view, flt-glass-pane", timeout=60_000)
            await page.wait_for_timeout(6000)
            token = api_login(base_api, email)
            await seed_auth(page, token)
            await page.reload(wait_until="domcontentloaded")
            await page.wait_for_timeout(8000)
            await open_tab(page, "Профиль")

            prefix = "01_own_filled" if scenario == "filled" else "02_own_empty"
            await page.screenshot(path=str(OUT / f"{prefix}.png"))
            print(f"wrote {OUT / f'{prefix}.png'}")

            if scenario == "filled":
                await page.screenshot(path=str(OUT / "06_analytics_filled.png"))
                # scroll to achievements if possible
                await page.mouse.wheel(0, 1200)
                await page.wait_for_timeout(1500)
                await page.screenshot(path=str(OUT / "08_achievements.png"))
            else:
                await page.screenshot(path=str(OUT / "07_analytics_empty.png"))

            await ctx.close()

        # Medium layout — filled profile
        ctx = await browser.new_context(viewport=medium)
        page = await ctx.new_page()
        await page.goto(base_url, wait_until="domcontentloaded", timeout=120_000)
        await page.wait_for_timeout(6000)
        await seed_auth(page, api_login(base_api, ACCOUNTS["filled"]))
        await page.reload(wait_until="domcontentloaded")
        await page.wait_for_timeout(8000)
        await open_tab(page, "Профиль")
        await page.screenshot(path=str(OUT / "09_web_medium.png"))
        print(f"wrote {OUT / '09_web_medium.png'}")
        await ctx.close()

        await browser.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    parser.add_argument("--api-url", default="http://127.0.0.1:8080/api/v1")
    args = parser.parse_args()
    asyncio.run(capture(args.base_url, args.api_url))


if __name__ == "__main__":
    main()
