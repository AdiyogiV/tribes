#!/usr/bin/env python
"""Full E2E: sign in with test phone+OTP, land in app, screenshot post-login."""
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
    page.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
    page.goto(URL, wait_until="domcontentloaded", timeout=60000)
    time.sleep(32)

    # phone
    page.mouse.click(670, 735); time.sleep(1)
    page.keyboard.type("7676767676", delay=60); time.sleep(1)
    page.mouse.click(640, 815)  # send code
    time.sleep(10)
    page.screenshot(path="/tmp/aw_f_otp.png")

    # OTP
    page.mouse.click(670, 747); time.sleep(1)
    page.keyboard.type("767676", delay=80); time.sleep(1)
    page.screenshot(path="/tmp/aw_f_otp_typed.png")
    page.mouse.click(640, 828)  # verify
    time.sleep(15)
    page.screenshot(path="/tmp/aw_f_post.png", full_page=False)

    print("---- auth/voice console ----")
    for l in logs:
        if any(k in l for k in ["auth", "", "Auth", "verif", "OTP", "checkRegistration", "voice", "Voice", "E2E", "ERROR", "error"]):
            print(l[:220])
    with open("/tmp/aw_full_console.log", "w") as f:
        f.write("\n".join(logs))
    browser.close()
print("done: /tmp/aw_f_otp.png /tmp/aw_f_otp_typed.png /tmp/aw_f_post.png")
