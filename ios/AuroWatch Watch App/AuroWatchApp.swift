import SwiftUI
import WatchKit

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
///
/// Background data collection:
///   HealthKit observer queries → BackgroundHealthSync → sendToPhone
///   Background refresh (15 min) → fetch cumulative stats → sendToPhone
@main
struct AuroWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                    // Link cache so incoming phone data reaches the UI
                    syncManager.cache = cache
                    syncManager.activate()

                    // Store references for background access
                    appDelegate.healthManager = healthManager
                    appDelegate.cache = cache
                    appDelegate.syncManager = syncManager

                    // Request HealthKit access; on success, register background observers
                    healthManager.requestAuthorization()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if healthManager.isAuthorized {
                            BackgroundHealthSync.shared.registerObservers(
                                healthStore: healthManager.store,
                                health: healthManager,
                                cache: cache,
                                syncManager: syncManager
                            )
                            BackgroundHealthSync.shared.scheduleNextRefresh()
                        }
                    }

                    // Request fresh data from phone after phone has time to load sky
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        syncManager.requestSync()
                    }
                }
        }
    }
}

// MARK: - WKApplicationDelegate (handles background tasks)

class AppDelegate: NSObject, WKApplicationDelegate {

    /// Shared references set by AuroWatchApp.onAppear
    var healthManager: HealthKitManager?
    var cache: LocalCache?
    var syncManager: WatchSyncManager?

    /// Called when the system delivers background tasks.
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                AuroLog.info("Received background refresh task", category: .sync)
                if let health = healthManager, let cache = cache, let sync = syncManager {
                    BackgroundHealthSync.shared.handleBackgroundRefresh(
                        task: refreshTask,
                        health: health,
                        cache: cache,
                        syncManager: sync
                    )
                } else {
                    AuroLog.warn("Background refresh: managers not available", category: .sync)
                    BackgroundHealthSync.shared.scheduleNextRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompletedWithSnapshot(false)

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
