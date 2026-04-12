import Foundation
import os.log

/// Centralized structured logging for AuroWatch.
///
/// Uses Apple's unified logging system (os.log) for proper log levels,
/// subsystem filtering, and persistence. All logs appear in Console.app
/// under subsystem "com.canay.dhaara.watch".
///
/// Usage:
///   AuroLog.info("HealthKit authorized", category: .health)
///   AuroLog.debug("HRV fetched: \(value)", category: .health)
///   AuroLog.error("Fetch failed: \(error)", category: .health)
enum AuroLog {
    // MARK: - Categories

    enum Category: String {
        case health   = "Health"
        case sync     = "Sync"
        case ojas     = "Ojas"
        case nadi     = "Nadi"
        case cache    = "Cache"
        case ui       = "UI"
        case general  = "General"
    }

    // MARK: - Loggers

    private static let subsystem = "com.canay.dhaara.watch"

    private static let loggers: [Category: Logger] = {
        var map = [Category: Logger]()
        for cat in [Category.health, .sync, .ojas, .nadi, .cache, .ui, .general] {
            map[cat] = Logger(subsystem: subsystem, category: cat.rawValue)
        }
        return map
    }()

    private static func logger(for category: Category) -> Logger {
        loggers[category] ?? Logger(subsystem: subsystem, category: category.rawValue)
    }

    // MARK: - Log Methods

    /// Informational — milestones, state changes.
    static func info(_ message: String, category: Category = .general) {
        logger(for: category).info("⌚ \(message, privacy: .public)")
    }

    /// Debug — verbose data for troubleshooting.
    static func debug(_ message: String, category: Category = .general) {
        logger(for: category).debug("⌚ \(message, privacy: .public)")
    }

    /// Warning — recoverable issue.
    static func warn(_ message: String, category: Category = .general) {
        logger(for: category).warning("⌚⚠️ \(message, privacy: .public)")
    }

    /// Error — something failed.
    static func error(_ message: String, category: Category = .general) {
        logger(for: category).error("⌚❌ \(message, privacy: .public)")
    }

    // MARK: - Convenience

    /// Log a health signal fetch result.
    static func healthFetch(_ signal: String, value: Double?, timestamp: Date?) {
        if let v = value {
            let ts = timestamp.map { timeAgo($0) } ?? "no ts"
            debug("\(signal): \(String(format: "%.1f", v)) (\(ts))", category: .health)
        } else {
            debug("\(signal): nil", category: .health)
        }
    }

    /// Log sync event with payload summary.
    static func syncEvent(_ action: String, keys: [String]) {
        info("\(action): \(keys.sorted().joined(separator: ", "))", category: .sync)
    }

    /// Log Ojas computation result.
    static func ojasComputed(score: Int, signalCount: Int, reliable: Bool) {
        info("Ojas computed: \(score)/100, \(signalCount) signals, reliable=\(reliable)", category: .ojas)
    }

    /// Log Nadi analysis result.
    static func nadiAnalyzed(dominant: String, gati: String, hrv: Double, rhr: Double) {
        info("Nadi: \(dominant) (\(gati)), HRV=\(String(format: "%.0f", hrv))ms, RHR=\(String(format: "%.0f", rhr))bpm", category: .nadi)
    }

    // MARK: - Helpers

    private static func timeAgo(_ date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs)h ago" }
        return "\(hrs / 24)d ago"
    }
}
