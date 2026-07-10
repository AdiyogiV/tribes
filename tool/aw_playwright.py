#!/usr/bin/env python
"""Autonomous Playwright harness for the Aurogram web app.
Boots the local release build, captures console logs + screenshot so we can
see the actual runtime state (Flutter renders to canvas, so we drive by
coordinates + read the console stream).
"""
import sys, time, json
from playwright.sync_api import sync_playwright

URL = "http://localhost:8100/"
OUT = "/tmp/aw_shot.png"
LOGS = "/tmp/aw_console.log"

logs = []

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            channel="chrome",
            args=[
                "--use-fake-ui-for-media-stream",
                "--use-fake-device-for-media-stream",
                "--autoplay-policy=no-user-gesture-required",
            ],
        )
        ctx = browser.new_context(
            permissions=["microphone"],
            viewport={"width": 1280, "height": 900},
        )
        page = ctx.new_page()
        page.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        page.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
        page.on("weberror", lambda e: logs.append(f"[weberror] {e}"))

        page.goto(URL, wait_until="domcontentloaded", timeout=60000)
        # Flutter web boot can take a while; poll for a settle.
        time.sleep(35)
        page.screenshot(path=OUT, full_page=False)
        # Dump any <flt-semantics> / accessibility placeholder presence.
        try:
            sem = page.eval_on_selector_all(
                "flt-semantics, flt-semantics-placeholder, [aria-label]",
                "els => els.map(e => (e.getAttribute('aria-label')||e.tagName)).slice(0,50)",
            )
        except Exception as e:
            sem = f"sem query failed: {e}"
        logs.append("SEMANTICS/ARIA: " + json.dumps(sem))
        with open(LOGS, "w") as f:
            f.write("\n".join(logs))
        print("screenshot:", OUT)
        print("console lines:", len(logs))
        print("---- last 40 console ----")
        print("\n".join(logs[-40:]))
        browser.close()

if __name__ == "__main__":
    run()
