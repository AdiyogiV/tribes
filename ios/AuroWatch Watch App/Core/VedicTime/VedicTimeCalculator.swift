import Foundation

/// Pure Vedic time calculations — ported from Dart `vedic_time_utils.dart`.
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
/// TODO: Integrate with backend muhurat data for actual sunrise/sunset.
struct VedicTimeCalculator {

    // MARK: - Constants

    /// Approximate sunrise hour (equinox average).
    static let sunriseHour = 6

    /// Seconds in one Ghati (24 minutes).
    static let secondsPerGhati = 1440

    /// Seconds in one Pala (24 seconds).
    static let secondsPerPala = 24

    /// Minutes in one Prahar (3 hours).
    static let minutesPerPrahar = 180

    static let praharNames = [
        "Purvanha",   // early morning (sunrise–9 AM)
        "Madhyanha",  // midday (9 AM–12 PM)
        "Aparanha",   // afternoon (12–3 PM)
        "Sayanha",    // evening (3–6 PM)
        "Pradosha",   // early night (6–9 PM)
        "Nishitha",   // midnight (9 PM–12 AM)
        "Triyama",    // late night (12–3 AM)
        "Usha",       // dawn (3–6 AM)
    ]

    /// Dosha dominance for each time period (Dinacharya).
    /// Index matches dosha clock: 0=Vata(2-6AM), 1=Kapha(6-10AM), etc.
    static let doshaClock: [(hours: ClosedRange<Int>, dosha: String)] = [
        (2...5,   "Vata"),    // early morning
        (6...9,   "Kapha"),   // morning
        (10...13, "Pitta"),   // midday
        (14...17, "Vata"),    // afternoon
        (18...21, "Kapha"),   // evening
        (22...25, "Pitta"),   // night (22-1 AM, wraps)
    ]

    // MARK: - Computed Vedic Time

    /// Full Vedic time snapshot for a given date.
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
            secondsFromSunrise: secsFromSunrise,
            ghatiFloat: Double(secsFromSunrise) / Double(secondsPerGhati),
            palaFloat: Double(secsFromSunrise % secondsPerGhati) / Double(secondsPerPala)
        )
    }

    /// Current dosha period name for a given hour.
    static func currentDosha(forHour hour: Int) -> String {
        let h = hour < 2 ? hour + 24 : hour // wrap midnight
        for period in doshaClock {
            if period.hours.contains(h) { return period.dosha }
        }
        return "Pitta" // fallback for 0-1 AM
    }

    /// Short display: "Ghati 42 · Pala 15"
    static func shortDisplay(from date: Date = .now) -> String {
        let vt = calculate(from: date)
        return "Ghati \(vt.ghati) · Pala \(vt.pala)"
    }

    /// Prahar display: "Aparanha Prahar 3"
    static func praharDisplay(from date: Date = .now) -> String {
        let vt = calculate(from: date)
        return "\(vt.praharName) Prahar \(vt.praharNumber)"
    }
}

// MARK: - VedicTime Model

/// Snapshot of Vedic time at a given moment.
struct VedicTime {
    /// Integer Ghati (0–59).
    let ghati: Int
    /// Integer Pala within current Ghati (0–59).
    let pala: Int
    /// Prahar index (0–7).
    let praharIndex: Int
    /// Prahar name (e.g., "Aparanha").
    let praharName: String
    /// Prahar number (1–8).
    let praharNumber: Int
    /// Total seconds from sunrise (for hand angle calculation).
    let secondsFromSunrise: Int
    /// Fractional Ghati (0.0–60.0) for clock hand positioning.
    let ghatiFloat: Double
    /// Fractional Pala (0.0–60.0) for clock hand positioning.
    let palaFloat: Double

    /// Whether it's daytime (Prahars 1–4) or night (5–8).
    var isDaytime: Bool { praharIndex < 4 }
}
