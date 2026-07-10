#!/usr/bin/env python
"""E2E build: send code (no reCAPTCHA), screenshot OTP entry UI."""
import time
from playwright.sync_api import sync_playwright

URL = "http://localhost:8100/"
logs = []
with sync_playwright() as p:
    browser = p.chromium.launch(
        headless=True, channel="chrome",
        args=["--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream",
              "--autoplay-policy=no-user-gesture-required"],
    )
    ctx = browser.new_context(permissions=["microphone"],
                              viewport={"width": 1280, "height": 900})
    page = ctx.new_page()
    page.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
    page.goto(URL, wait_until="domcontentloaded", timeout=60000)
    time.sleep(32)
    page.mouse.click(670, 735)
    time.sleep(1)
    page.keyboard.type("7676767676", delay=60)
    time.sleep(1)
    page.mouse.click(640, 815)
    for i in range(4):
        time.sleep(4)
        page.screenshot(path=f"/tmp/aw_send_{i}.png")
    print("---- console tail ----")
    print("\n".join([l for l in logs if 'ERROR' in l or 'E2E' in l or 'verif' in l.lower() or 'code' in l.lower() or 'otp' in l.lower()][-15:]))
    print("---- generic tail ----")
    print("\n".join(logs[-8:]))
    browser.close()
print("done /tmp/aw_send_0..3.png")
