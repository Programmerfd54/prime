#!/usr/bin/env python3
import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        page.on("console", lambda msg: print("CONSOLE:", msg.type, msg.text))
        page.on("pageerror", lambda err: print("PAGEERROR:", err))
        await page.goto("http://127.0.0.1:5000", wait_until="domcontentloaded", timeout=60000)
        await page.wait_for_timeout(15000)
        print("title:", await page.title())
        print("body:", (await page.content())[:500])
        await browser.close()

asyncio.run(main())
