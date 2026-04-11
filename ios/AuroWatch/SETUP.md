# AuroWatch — watchOS Setup Guide

All source files are ready. You need to create the Xcode target (can't be done from CLI).

## Step 1: Add watchOS Target in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Click the **Runner** project in the navigator (blue icon, top-left)
3. Bottom-left corner → click **+** to add a target
4. Choose **watchOS** → **App** → Next
5. Configure:
   - **Product Name**: `AuroWatch`
   - **Bundle Identifier**: `com.canay.dhaara.watchkitapp`
   - **Language**: Swift
   - **User Interface**: SwiftUI
   - **Watch Connectivity**: ✅ check this
   - **Include Notification Scene**: leave unchecked for now
6. Click **Finish**
7. When asked "Activate AuroWatch scheme?" → click **Activate**

## Step 2: Replace Generated Files with Our Code

Xcode created a new `AuroWatch/` folder with boilerplate files. Replace them:

1. In Xcode, **delete** all files inside the `AuroWatch` group that Xcode generated
   (AuroWatchApp.swift, ContentView.swift, Assets.xcassets — select and "Move to Trash")
2. Right-click the `AuroWatch` group → **Add Files to "Runner"...**
3. Navigate to `ios/AuroWatch/` and select **ALL files and folders**:
   - `AuroWatchApp.swift`
   - `ContentView.swift`
   - `Info.plist`
   - `AuroWatch.entitlements`
   - `Assets.xcassets/`
   - `Core/` (entire folder)
   - `Features/` (entire folder)
4. Make sure:
   - ✅ "Copy items if needed" is **unchecked** (files are already in place)
   - ✅ Target membership: **AuroWatch** is checked
   - ✅ "Create groups" is selected (not folder references)
5. Click **Add**

## Step 3: Add WatchBridge to Phone Target

1. Right-click the **Runner** group → **Add Files to "Runner"...**
2. Navigate to `ios/Runner/WatchBridge/`
3. Select `WatchSessionManager.swift`
4. Make sure target membership: **Runner** is checked
5. Click **Add**

## Step 4: Configure Target Settings

### AuroWatch target:
1. Select AuroWatch target → **General** tab:
   - **Deployment Target**: watchOS 10.0
   - **Bundle Identifier**: `com.canay.dhaara.watchkitapp`
2. **Signing & Capabilities** tab:
   - Add **HealthKit** capability (click + Capability)
   - Add **WatchConnectivity** (should be auto-added)
3. **Build Settings** → search "Info.plist":
   - Set to `AuroWatch/Info.plist`
4. **Build Settings** → search "Entitlements":
   - Set to `AuroWatch/AuroWatch.entitlements`

### Runner (phone) target:
1. Select Runner target → **Signing & Capabilities**:
   - No changes needed (WatchConnectivity doesn't require a capability)

## Step 5: Verify Build

1. Select the **AuroWatch** scheme (top toolbar dropdown)
2. Choose an Apple Watch simulator (e.g., Apple Watch Series 9 - 45mm)
3. Build and run (Cmd+R)
4. You should see the Vedic Clock screen on the watch simulator

## Step 6: Test on Real Device

1. Pair your Apple Watch with your development iPhone
2. Select your iPhone as the run destination
3. The watch app will auto-install on the paired watch
4. Open the app on the watch — you'll see the Vedic Clock

## File Structure

```
ios/
├── AuroWatch/                      ← watchOS app (all new)
│   ├── AuroWatchApp.swift          ← Entry point
│   ├── ContentView.swift           ← Tab navigation
│   ├── Info.plist                  ← Watch config + HealthKit usage
│   ├── AuroWatch.entitlements      ← HealthKit entitlement
│   ├── Assets.xcassets/            ← Watch app icon
│   ├── Core/
│   │   ├── VedicTime/
│   │   │   ├── VedicTimeCalculator.swift  ← Ported from Dart
│   │   │   └── VedicClockView.swift       ← Ported from CustomPainter
│   │   ├── Health/
│   │   │   ├── HealthKitManager.swift     ← HRV, HR queries
│   │   │   └── NadiEngine.swift           ← Pulse → dosha analysis
│   │   ├── Sync/
│   │   │   └── WatchSyncManager.swift     ← Receives from phone
│   │   ├── Cache/
│   │   │   └── LocalCache.swift           ← UserDefaults persistence
│   │   └── Theme/
│   │       └── AuroTheme.swift            ← Colors, constants
│   └── Features/
│       ├── CosmicNow/
│       │   └── CosmicNowView.swift        ← Hero screen (clock + date)
│       ├── NadiMonitor/
│       │   └── NadiMonitorView.swift      ← Pulse analysis screen
│       ├── Insight/
│       │   └── InsightView.swift          ← Phase 2 placeholder
│       ├── Muhurat/
│       │   └── MuhuratView.swift          ← Phase 2 placeholder
│       └── Notifications/
│           └── NotificationsView.swift    ← Phase 3 placeholder
├── Runner/
│   ├── AppDelegate.swift           ← Updated with WatchConnectivity
│   └── WatchBridge/
│       └── WatchSessionManager.swift  ← Phone-side WC manager
└── ...

lib/shared/services/
└── watch_service.dart              ← Flutter platform channel bridge
```

## Connecting Flutter to Watch

In your Dart code, use `WatchService` to send data:

```dart
import 'package:aurogram/shared/services/watch_service.dart';

// Initialize once at app startup
WatchService.instance.initialize();

// Send panchang when loaded
WatchService.instance.sendPanchang(samvatData);

// Send profile when Ayurveda data loads
WatchService.instance.sendProfile(
  prakritiType: profile.prakriti?.type,
  vata: profile.prakriti?.vata ?? 0,
  pitta: profile.prakriti?.pitta ?? 0,
  kapha: profile.prakriti?.kapha ?? 0,
);

// Send insight when generated
WatchService.instance.sendInsight(
  theme: insight.theme,
  message: insight.mainMessage,
);

// Listen for data FROM watch (Nadi readings)
WatchService.instance.onWatchData.listen((data) {
  // data['nadiDosha'], data['hrv'], data['restingHR']
});
```

## Next Phases

- **Phase 2**: Uncomment InsightView + MuhuratView tabs in ContentView.swift
- **Phase 3**: Uncomment NotificationsView, add sleep types to HealthKitManager
- **Phase 4**: Add Ojas/Dhatu/Srotas views, full Vikriti biometric integration
