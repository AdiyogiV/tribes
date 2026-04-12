import SwiftUI

/// Shared theme constants for the watch app.
/// Mirrors AppTheme.primaryColor and styling from the Flutter app.
enum AuroTheme {
    /// Primary brand color — warm golden brown, bright enough for OLED.
    static let primaryColor = Color(red: 0.78, green: 0.62, blue: 0.44) // #C79E70 warm gold-brown

    /// Gold accent for sun icon and highlights.
    static let goldAccent = Color(red: 1.0, green: 0.84, blue: 0.40) // #FFD666 brighter gold

    /// Cream/warm white for primary text — high contrast on black OLED.
    static let textLight = Color(red: 0.95, green: 0.90, blue: 0.82) // #F2E6D1 warm cream

    /// Day segment colors (warm oranges).
    static let dayStart = Color(red: 1.0, green: 0.72, blue: 0.25)  // FFB840
    static let dayEnd   = Color(red: 1.0, green: 0.50, blue: 0.30)  // FF804D

    /// Night segment colors (deep indigo).
    static let nightStart = Color(red: 0.45, green: 0.52, blue: 0.82) // 7385D1
    static let nightEnd   = Color(red: 0.22, green: 0.28, blue: 0.65) // 3847A6

    /// Dosha colors for health displays — boosted for OLED.
    static let vataColor  = Color(red: 0.50, green: 0.80, blue: 0.92) // brighter sky blue
    static let pittaColor = Color(red: 1.0, green: 0.62, blue: 0.30)  // brighter orange
    static let kaphaColor = Color(red: 0.50, green: 0.82, blue: 0.50) // brighter green

    /// Text opacity levels — higher for OLED readability.
    static let textPrimary: Double = 1.0
    static let textSecondary: Double = 0.78
    static let textTertiary: Double = 0.55

    // MARK: - Shared Helpers

    /// Map a dosha name to its theme color.
    static func doshaColor(_ dosha: String) -> Color {
        switch dosha.lowercased() {
        case "vata":  return vataColor
        case "pitta": return pittaColor
        case "kapha": return kaphaColor
        default:      return primaryColor
        }
    }

    /// Map a Nadi gati (pulse type) to its glyph.
    static func nadiGlyph(_ gati: String) -> String {
        switch gati {
        case "Sarpa":   return "🐍"
        case "Manduka": return "🐸"
        case "Hamsa":   return "🦢"
        default:        return "◉"
        }
    }

    /// Map a dosha name to its Nadi glyph (convenience for views that have dosha, not gati).
    static func doshaGlyph(_ dosha: String) -> String {
        switch dosha.lowercased() {
        case "vata":  return "🐍"
        case "pitta": return "🐸"
        case "kapha": return "🦢"
        default:      return "◉"
        }
    }

    /// Human-readable relative time string.
    /// - Parameter style: `.short` → "5m", `.medium` → "5m ago", `.long` → "5 min ago"
    enum TimeAgoStyle { case short, medium, long }

    static func timeAgo(_ date: Date, style: TimeAgoStyle = .medium) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        switch style {
        case .short:
            if mins < 1 { return "now" }
            if mins < 60 { return "\(mins)m" }
            let hrs = mins / 60
            if hrs < 24 { return "\(hrs)h" }
            return "\(hrs / 24)d"
        case .medium:
            if mins < 1 { return "just now" }
            if mins < 60 { return "\(mins)m ago" }
            let hrs = mins / 60
            if hrs < 24 { return "\(hrs)h ago" }
            return "\(hrs / 24)d ago"
        case .long:
            if mins < 1 { return "just now" }
            if mins < 60 { return "\(mins) min ago" }
            let hrs = mins / 60
            if hrs < 24 { return "\(hrs)h ago" }
            return "\(hrs / 24)d ago"
        }
    }
}
