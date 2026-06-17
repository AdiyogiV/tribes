import Foundation

/// Pure Vedic time calculations — duplicated from `AuroWatch Widget` so this
/// iOS home-screen widget target can compile independently.
///
/// Vedic time units (sunrise to sunrise):
///   1 Day   = 60 Ghati  = 3600 Pala
///   1 Ghati = 24 minutes = 60 Pala
///   1 Pala  = 24 seconds
///
/// 8 Prahars (3-hour watches from sunrise):
///   1 Purvanha  (6–9 AM)    5 Pradosha  (6–9 PM)
///   2 Madhyanha (9–12 PM)   6 Nishitha  (9–12 AM)
///   3 Aparanha  (12–3 PM)   7 Triyama   (12–3 AM)
///   4 Sayanha   (3–6 PM)    8 Usha      (3–6 AM)
///
/// KNOWN LIMITATION: Uses hardcoded 6 AM sunrise.
struct VedicTimeCalculator {

    // MARK: - Constants

    static let sunriseHour = 6
    static let secondsPerGhati = 1440
    static let secondsPerPala = 24
    static let minutesPerPrahar = 180

    static let praharNames = [
        "Purvanha", "Madhyanha", "Aparanha", "Sayanha",
        "Pradosha", "Nishitha", "Triyama", "Usha",
    ]

    // MARK: - Computed Vedic Time

    static func calculate(from date: Date = .now) -> VedicTime {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let s = cal.component(.second, from: date)

        var secsFromSunrise = (h - sunriseHour) * 3600 + m * 60 + s
        if secsFromSunrise < 0 { secsFromSunrise += 86400 }

        let ghati = secsFromSunrise / secondsPerGhati
        let pala = (secsFromSunrise % secondsPerGhati) / secondsPerPala
        let minsFromSunrise = Double(secsFromSunrise) / 60.0
        let praharIndex = Int(minsFromSunrise / Double(minutesPerPrahar)) % 8

        return VedicTime(
            ghati: ghati,
            pala: pala,
            praharIndex: praharIndex,
            praharName: praharNames[praharIndex],
            praharNumber: praharIndex + 1,
            isDaytime: praharIndex < 4
        )
    }

    // MARK: - Moon phase

    /// Returns a moon emoji for the given date based on the synodic month.
    /// Approximate calculation — good enough for a widget glyph.
    static func moonEmoji(for date: Date = .now) -> String {
        // Reference new moon: 2000-01-06 18:14 UTC
        let referenceNewMoon: TimeInterval = 947182440
        let synodicSeconds: TimeInterval = 29.530588853 * 86400
        let diff = date.timeIntervalSince1970 - referenceNewMoon
        let phase = (diff.truncatingRemainder(dividingBy: synodicSeconds)) / synodicSeconds
        let normalized = phase < 0 ? phase + 1 : phase

        switch normalized {
        case ..<0.0625, 0.9375...: return "🌑"  // new
        case ..<0.1875:            return "🌒"  // waxing crescent
        case ..<0.3125:            return "🌓"  // first quarter
        case ..<0.4375:            return "🌔"  // waxing gibbous
        case ..<0.5625:            return "🌕"  // full
        case ..<0.6875:            return "🌖"  // waning gibbous
        case ..<0.8125:            return "🌗"  // last quarter
        default:                    return "🌘"  // waning crescent
        }
    }
}

// MARK: - VedicTime Model

struct VedicTime {
    let ghati: Int
    let pala: Int
    let praharIndex: Int
    let praharName: String
    let praharNumber: Int
    let isDaytime: Bool
}
