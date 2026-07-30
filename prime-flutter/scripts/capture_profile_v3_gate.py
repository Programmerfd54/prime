#!/usr/bin/env python3
"""Capture Profile V3 visual gate screenshots (TZ §41)."""
from __future__ import annotations

import argparse
import asyncio
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "profile-v3" / "gate"
PASSWORD = "DemoPrime123!"

ACCOUNTS = {
    "filled": "demo-filled@example.com",
    "empty": "demo-empty@example.com",
    "matching": "demo-matching@example.com",
}

# Seeded friend of demo-filled (Даша, with photo)
PUBLIC_WITH_PHOTO_ID = "8d8aed3a-a495-4cfc-a61f-56a6b012186e"
# demo-empty — no avatar in seed
PUBLIC_NO_PHOTO_ID = "e9b9a056-23eb-420f-9c26-82b8fe9e12f2"


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


async def seed_onboarding(page) -> None:
    await page.evaluate(
        """() => {
          const raw = localStorage.getItem('flutter.shared_preferences') || '{}';
          const prefs = JSON.parse(raw);
          prefs['flutter.prime_onboarding_done'] = true;
          localStorage.setItem('flutter.shared_preferences', JSON.stringify(prefs));
        }"""
    )


async def login_ui(page, email: str, base_api: str) -> None:
    await seed_onboarding(page)
    link = page.get_by_text("Уже есть аккаунт? Войти")
    if await link.count():
        await link.first.click()
        await page.wait_for_timeout(1200)
    inputs = page.locator("input")
    count = await inputs.count()
    if count >= 2:
        await inputs.nth(0).fill(email)
        await inputs.nth(1).fill(PASSWORD)
        btn = page.get_by_text("Войти", exact=True)
        if await btn.count():
            await btn.first.click()
            await page.wait_for_timeout(8000)
            return
    raise RuntimeError(f"UI login failed for {email}")


async def open_bottom_tab(page, label: str) -> None:
    tab = page.get_by_text(label, exact=True)
    if await tab.count():
        await tab.first.click()
        await page.wait_for_timeout(2500)


async def open_profile_tab(page, label: str) -> None:
    tab = page.get_by_text(label, exact=True)
    if await tab.count():
        await tab.first.click()
        await page.wait_for_timeout(1500)


async def goto_public_profile(page, base_url: str, user_id: str) -> None:
    url = f"{base_url.rstrip('/')}/profile/{user_id}"
    await page.goto(url, wait_until="domcontentloaded")
    await page.wait_for_timeout(5000)


async def capture(base_url: str, base_api: str) -> None:
    from playwright.async_api import async_playwright

    OUT.mkdir(parents=True, exist_ok=True)
    phone = {"width": 390, "height": 844}
    medium = {"width": 900, "height": 844}

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        async def fresh_page(viewport: dict):
            ctx = await browser.new_context(viewport=viewport)
            page = await ctx.new_page()
            await page.goto(base_url, wait_until="domcontentloaded", timeout=120_000)
            await page.wait_for_selector("flutter-view, flt-glass-pane", timeout=60_000)
            await page.wait_for_timeout(4000)
            return ctx, page

        # 1–2: own filled overview + about
        ctx, page = await fresh_page(phone)
        await login_ui(page, ACCOUNTS["filled"], base_api)
        await open_bottom_tab(page, "Профиль")
        await page.screenshot(path=str(OUT / "01_own_filled_overview.png"))
        print(f"wrote {OUT / '01_own_filled_overview.png'}")
        await open_profile_tab(page, "Обзор")
        await page.screenshot(path=str(OUT / "02_own_about_filled.png"))
        print(f"wrote {OUT / '02_own_about_filled.png'}")
        await ctx.close()

        # 3: own completeness (empty account)
        ctx, page = await fresh_page(phone)
        await login_ui(page, ACCOUNTS["empty"], base_api)
        await open_bottom_tab(page, "Профиль")
        await open_profile_tab(page, "Обзор")
        await page.screenshot(path=str(OUT / "03_own_completeness.png"))
        print(f"wrote {OUT / '03_own_completeness.png'}")
        await ctx.close()

        # 4–8: public profile (friend with photo)
        ctx, page = await fresh_page(phone)
        await login_ui(page, ACCOUNTS["filled"], base_api)
        await goto_public_profile(page, base_url, PUBLIC_WITH_PHOTO_ID)
        await page.screenshot(path=str(OUT / "04_public_with_photo.png"))
        print(f"wrote {OUT / '04_public_with_photo.png'}")
        await open_profile_tab(page, "Обзор")
        await page.screenshot(path=str(OUT / "06_public_overview.png"))
        print(f"wrote {OUT / '06_public_overview.png'}")
        await open_profile_tab(page, "Совместимость")
        await page.screenshot(path=str(OUT / "07_public_compatibility.png"))
        print(f"wrote {OUT / '07_public_compatibility.png'}")
        more = page.get_by_label("Ещё")
        if await more.count():
            await more.last.click()
            await page.wait_for_timeout(900)
            await page.screenshot(path=str(OUT / "08_public_more_menu.png"))
            print(f"wrote {OUT / '08_public_more_menu.png'}")
        await ctx.close()

        # 5: public without photo
        ctx, page = await fresh_page(phone)
        await login_ui(page, ACCOUNTS["filled"], base_api)
        await goto_public_profile(page, base_url, PUBLIC_NO_PHOTO_ID)
        await page.screenshot(path=str(OUT / "05_public_no_photo.png"))
        print(f"wrote {OUT / '05_public_no_photo.png'}")
        await ctx.close()

        # 9–10: progress + achievements (21+ days)
        ctx, page = await fresh_page(phone)
        await login_ui(page, ACCOUNTS["filled"], base_api)
        await open_bottom_tab(page, "Профиль")
        await open_profile_tab(page, "Прогресс")
        await page.screenshot(path=str(OUT / "09_own_progress_21d.png"))
        print(f"wrote {OUT / '09_own_progress_21d.png'}")
        await open_profile_tab(page, "Достижения")
        await page.screenshot(path=str(OUT / "10_own_achievements.png"))
        print(f"wrote {OUT / '10_own_achievements.png'}")
        await ctx.close()

        # 11: compact phone
        ctx, page = await fresh_page({"width": 375, "height": 812})
        await login_ui(page, ACCOUNTS["filled"], base_api)
        await open_bottom_tab(page, "Профиль")
        await page.screenshot(path=str(OUT / "11_compact_phone.png"))
        print(f"wrote {OUT / '11_compact_phone.png'}")
        await ctx.close()

        # 12: web medium
        ctx, page = await fresh_page(medium)
        await login_ui(page, ACCOUNTS["filled"], base_api)
        await open_bottom_tab(page, "Профиль")
        await page.screenshot(path=str(OUT / "12_web_medium.png"))
        print(f"wrote {OUT / '12_web_medium.png'}")
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
