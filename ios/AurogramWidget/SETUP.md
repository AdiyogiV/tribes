# iOS Home Screen Widget — Setup

The Swift sources, Info.plist and entitlements for the iPhone/iPad home-screen
widget live in this folder. They are **not yet a Xcode target** — you need to
add the target manually (pbxproj editing by hand is fragile).

## One-time Xcode setup

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Widget Extension**
   - Product Name: `AurogramWidget`
   - Bundle Identifier: `com.canay.dhaara.AurogramWidget`
   - Team: same as Runner
   - Language: Swift
   - Include Configuration Intent: **unchecked**
   - Embed in Application: **Runner**
3. When Xcode asks "Activate AurogramWidget scheme?", choose **Activate**.
4. In the new target's folder Xcode just created, **delete the auto-generated
   files** (`AurogramWidget.swift`, `AurogramWidgetBundle.swift`,
   `AurogramWidget.entitlements`, etc.). When prompted, choose **Move to
   Trash**.
5. In Finder, drag the four files from `ios/AurogramWidget/`
   (`AurogramWidgetBundle.swift`, `VedicDateHomeWidget.swift`,
   `VedicTimeCalculator.swift`, `Info.plist`, `AurogramWidget.entitlements`)
   into the new `AurogramWidget` group in the Xcode project navigator.
   - **Copy items if needed:** unchecked (already in place)
   - **Add to targets:** AurogramWidget only
6. Select the `AurogramWidget` target → **Build Settings** → set:
   - `Info.plist File` → `AurogramWidget/Info.plist`
   - `Code Signing Entitlements` →
     `AurogramWidget/AurogramWidget.entitlements`
   - `iOS Deployment Target` → 16.0 (matches Runner)

## Capabilities (both targets)

Both Runner and AurogramWidget need the same App Group:

1. Select **Runner** target → **Signing & Capabilities** → **+ Capability** →
   **App Groups**. Add `group.com.canay.dhaara.widget`.
2. Repeat on the **AurogramWidget** target.
3. On Apple Developer Portal, the App Group must exist for both bundle IDs:
   - `com.canay.dhaara`
   - `com.canay.dhaara.AurogramWidget`
   If you use automatic signing, Xcode provisions this for you. Otherwise add
   it manually in the portal and regenerate provisioning profiles.

## Why this design

- **App Group UserDefaults** is the only writable channel between the Flutter
  process and the widget extension process. Standard `NSUserDefaults` is
  sandboxed per process.
- Flutter calls the `com.canay.dhaara/widget` method channel from
  `WidgetDataService` (lib/shared/services/widget_data_service.dart). The
  channel handler in `Runner/AppDelegate.swift` writes panchang values to
  `UserDefaults(suiteName: kWidgetAppGroup)` and triggers
  `WidgetCenter.shared.reloadAllTimelines()` so the new data appears
  immediately.
- The widget timeline provider re-reads these keys every minute (60-entry
  timeline) so Ghati·Pala stays current without forcing a process wakeup
  every 24 seconds.
- Light/dark mode switches automatically via SwiftUI's `Environment(\.colorScheme)`
  — no extra plumbing needed (unlike Android, where the launcher caches views).

## Test plan

1. Build & run Runner on a device (widgets don't fully render in the
   simulator on older Xcode versions; use a device when possible).
2. Long-press home screen → **+** → search "Vedic Date" → add small or medium.
3. **Lock screen widget (iOS 16+):** lock the device, long-press the lock
   screen → **Customize** → tap the area under or above the clock → **+ Add
   Widgets** → search "Vedic Date" → pick the circular, rectangular or
   inline variant.
4. Open the app and let it load panchang data. The widget should update
   within a second (via `WidgetCenter.shared.reloadAllTimelines()`).
5. Toggle iOS Settings → Display & Brightness → Light/Dark. Home-screen
   widget should switch automatically. Lock-screen complications render in
   the system's monochrome/tinted style, so they ignore our color tokens.

## Supported widget families

| Family | Where | Notes |
|---|---|---|
| `.systemSmall` | Home screen | Compact date card |
| `.systemMedium` | Home screen | Full 3-column layout (mirrors Android) |
| `.accessoryCircular` | Lock screen / StandBy | Ghati + Pala, monochrome |
| `.accessoryRectangular` | Lock screen / StandBy | Vedic date + Prahar |
| `.accessoryInline` | Lock screen (above clock) | Single tinted line |

**Android note:** Lock-screen widgets are not available on Android (the API
was removed in Android 5.0). On Android the same data is exposed via the
existing home-screen widget only.

## Files in this folder

| File | Purpose |
|---|---|
| `AurogramWidgetBundle.swift` | `@main` widget bundle entry point |
| `VedicDateHomeWidget.swift` | Timeline provider + SwiftUI views (small & medium) |
| `VedicTimeCalculator.swift` | Pure Vedic time math (Ghati/Pala/Prahar, moon phase) |
| `Info.plist` | Widget extension Info.plist (extension point identifier) |
| `AurogramWidget.entitlements` | App Group capability |
| `SETUP.md` | This file |
