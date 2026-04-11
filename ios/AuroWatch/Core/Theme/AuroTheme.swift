import SwiftUI

/// Shared theme constants for the watch app.
/// Mirrors AppTheme.primaryColor and styling from the Flutter app.
enum AuroTheme {
    /// Primary brand color — warm brown, matches Flutter `AppTheme.primaryColor`.
    static let primaryColor = Color(red: 0.44, green: 0.33, blue: 0.24) // #70543D approx

    /// Gold accent for sun icon and highlights.
    static let goldAccent = Color(red: 1.0, green: 0.76, blue: 0.03) // #FFC107

    /// Day segment colors (warm oranges).
    static let dayStart = Color(red: 1.0, green: 0.65, blue: 0.15)  // FFA726
    static let dayEnd   = Color(red: 1.0, green: 0.44, blue: 0.26)  // FF7043

    /// Night segment colors (deep indigo).
    static let nightStart = Color(red: 0.36, green: 0.42, blue: 0.75) // 5C6BC0
    static let nightEnd   = Color(red: 0.16, green: 0.21, blue: 0.58) // 283593

    /// Dosha colors for health displays.
    static let vataColor  = Color(red: 0.40, green: 0.73, blue: 0.85) // light blue, airy
    static let pittaColor = Color(red: 0.93, green: 0.55, blue: 0.27) // warm orange, fiery
    static let kaphaColor = Color(red: 0.47, green: 0.75, blue: 0.45) // earthy green, stable

    /// Text opacity levels.
    static let textPrimary: Double = 0.85
    static let textSecondary: Double = 0.6
    static let textTertiary: Double = 0.4
}
