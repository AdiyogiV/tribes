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
/// Health sync cadence:
///   • Observers: Apple notifies when new heart rate / HRV arrives
///   • Ghati timer: Background refresh every ~24 min as safety net
///   • Manual: User can trigger via OjasView button
@main
struct AuroWatchApp: App {
    @StateObject private var syncManager = WatchSyncManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var cache = LocalCache()

    /// 1 Ghati = 24 minutes (Vedic time unit)
    private static let ghatiInterval: TimeInterval = 24 * 60

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
                .environmentObject(healthManager)
                .environmentObject(cache)
                .onAppear {
                    // Link cache so incoming phone data reaches the UI
                    syncManager.cache = cache

                    // Wire up background health → phone sync
                    healthManager.onBackgroundDataReady = { [weak syncManager, weak cache] in
                        guard let sync = syncManager, let c = cache else { return }
                        let payload = c.healthPayload()
                        // Only send if we have at least 2 real signals (not just timestamp)
                        if payload.count > 3 {
                            sync.sendToPhone(payload)
                            AuroLog.info("Background sync: sent \(payload.count) fields to phone", category: .health)
                        }
                    }

                    syncManager.activate()
                    healthManager.requestAuthorization()

                    // Request fresh data from phone
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        syncManager.requestSync()
                    }

                    // Schedule first ghati background refresh
                    Self.scheduleNextGhati()
                }
        }
        // Handle background tasks (ghati health refresh)
        .backgroundTask(.appRefresh("com.aurogram.health.ghati")) {
            await handleGhatiRefresh()
        }
    }

    // MARK: - Ghati Background Refresh

    /// Schedule the next background refresh ~24 minutes from now.
    static func scheduleNextGhati() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date.now.addingTimeInterval(ghatiInterval),
            userInfo: "ghati" as NSSecureCoding & NSObjectProtocol
        ) { error in
            if let error = error {
                AuroLog.error("Failed to schedule ghati refresh: \(error.localizedDescription)", category: .health)
            } else {
                AuroLog.debug("Ghati refresh scheduled in ~24 min", category: .health)
            }
        }
    }

    /// Called by watchOS when the ghati background task fires.
    private func handleGhatiRefresh() async {
        AuroLog.info("Ghati refresh fired — fetching health data", category: .health)

        // Fetch all health signals
        await withCheckedContinuation { continuation in
            healthManager.fetchAllReadings {
                continuation.resume()
            }
        }

        // Send to phone
        let payload = cache.healthPayload()
        if payload.count > 3 {
            syncManager.sendToPhone(payload)
            AuroLog.info("Ghati sync: sent \(payload.count) fields to phone", category: .health)
        }

        // Schedule next ghati
        Self.scheduleNextGhati()
    }
}
