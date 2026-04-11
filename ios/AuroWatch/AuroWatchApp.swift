import SwiftUI

/// Aurogram watchOS companion app.
///
/// Architecture:
///   AuroWatchApp (entry)
///   ├── Core/         — shared calculators, health, sync, cache
///   ├── Features/     — one folder per tab/screen
///   └── Complications — WidgetKit timeline providers
///
/// Data flow:
///   Phone (Flutter) → WatchConnectivity → WatchSyncManager → LocalCache
///   HealthKit → HealthKitManager → NadiEngine → LocalCache
///   LocalCache → Feature Views (via @EnvironmentObject)
@main
struct AuroWatchApp: App {
    @StateObject private var syncManager = WatchSyncManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var cache = LocalCache()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
                .environmentObject(healthManager)
                .environmentObject(cache)
                .onAppear {
                    syncManager.activate()
                    healthManager.requestAuthorization()
                }
        }
    }
}
