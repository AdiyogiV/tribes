import Foundation
import WatchConnectivity

/// Manages WatchConnectivity session on the PHONE side.
///
/// Bridges Flutter (Dart) ↔ Native Swift ↔ Apple Watch.
///
/// Flutter sends data via platform channel "com.canay.dhaara/watch":
///   - method: "sendPanchang"  → args: { vedicDate, samvatYear, vedicNumericDate }
///   - method: "sendProfile"   → args: { prakritiType, prakritiVata, prakritiPitta, prakritiKapha }
///   - method: "sendInsight"   → args: { theme, message }
///   - method: "isWatchPaired" → returns: bool
///
/// Watch sends data back (e.g., Nadi readings) → forwarded to Flutter via event channel.
class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    /// Callback for data received FROM watch (Nadi readings, etc.)
    var onWatchData: (([String: Any]) -> Void)?

    private var session: WCSession?

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Activate the WC session. Call from AppDelegate on launch.
    func activate() {
        guard WCSession.isSupported() else {
            print("📱 WatchConnectivity not supported on this device")
            return
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("📱 WatchConnectivity activating on phone...")
    }

    /// Whether a watch is paired and the app is installed.
    var isWatchAvailable: Bool {
        guard let session = session else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    // MARK: - Send to Watch

    /// Send panchang data to watch.
    func sendPanchang(_ data: [String: Any]) {
        var payload = data
        payload["type"] = "panchang"
        send(payload)
    }

    /// Send user profile (Prakriti) to watch.
    func sendProfile(_ data: [String: Any]) {
        var payload = data
        payload["type"] = "profile"
        send(payload)
    }

    /// Send daily insight to watch.
    func sendInsight(_ data: [String: Any]) {
        var payload = data
        payload["type"] = "insight"
        send(payload)
    }

    /// Send muhurat time windows to watch.
    func sendMuhurat(_ data: [String: Any]) {
        var payload = data
        payload["type"] = "muhurat"
        send(payload)
    }

    /// Send sky positions (planet data) to watch.
    func sendSky(_ data: [String: Any]) {
        var payload = data
        payload["type"] = "sky"
        if let planets = data["planets"] as? [[String: Any]] {
            print("📱 sendSky: \(planets.count) planets")
        }
        send(payload)
    }

    /// Send dosha-aware health recommendations to watch.
    func sendRecommendations(_ data: [String: Any]) {
        var payload = data
        payload["type"] = "recommendations"
        send(payload)
        print("📱 sendRecommendations: \(data["dosha"] ?? "unknown") dosha")
    }

    // MARK: - Internal

    private func send(_ data: [String: Any]) {
        guard let session = session else {
            print("📱 WC session not available")
            return
        }

        // Use applicationContext for latest-state delivery.
        // This ensures the watch gets the most recent data even if
        // it wasn't reachable when we sent it.
        do {
            // Merge with existing context to avoid overwriting other keys
            var context = session.applicationContext
            for (key, value) in data {
                context[key] = value
            }
            try session.updateApplicationContext(context)
            print("📱 Updated watch application context: \(data.keys.joined(separator: ", "))")
        } catch {
            print("📱 Failed to update watch context: \(error.localizedDescription)")
        }

        // Also send real-time if reachable (for immediate update)
        if session.isReachable {
            session.sendMessage(data, replyHandler: nil) { error in
                print("📱 Real-time send failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("📱 WC activation error: \(error.localizedDescription)")
        } else {
            print("📱 WC activated. Paired: \(session.isPaired), Watch app: \(session.isWatchAppInstalled)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WC session inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WC session deactivated — reactivating")
        session.activate()
    }

    /// Handle sync requests FROM watch.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let request = message["request"] as? String, request == "fullSync" {
            print("📱 Watch requested full sync")
            // Notify Flutter to send fresh data
            onWatchData?(["request": "fullSync"])

            // Wait briefly for Flutter to populate applicationContext,
            // then reply with whatever we have.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                var fullContext = session.applicationContext
                fullContext.removeValue(forKey: "type")
                print("📱 Replying to fullSync with keys: \(fullContext.keys.sorted().joined(separator: ", "))")
                replyHandler(fullContext)
            }
        } else {
            // Forward watch data (Nadi readings etc.) to Flutter
            onWatchData?(message)
            replyHandler(["status": "received"])
        }
    }

    /// Handle guaranteed-delivery data FROM watch.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let type = userInfo["type"] as? String ?? "unknown"
        let keys = userInfo.keys.sorted().joined(separator: ", ")
        print("📱 Received \(type) from watch (\(userInfo.count) keys): \(keys)")
        onWatchData?(userInfo)
    }
}
