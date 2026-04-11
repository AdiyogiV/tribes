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
}
