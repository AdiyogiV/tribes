import SwiftUI

/// Muhurat Timeline screen — Phase 2.
///
/// Will show:
///   - List of auspicious/inauspicious time windows today
///   - Progress bar for current window
///   - Haptic alert when a muhurat begins
///
/// Data: synced from phone (SkyPositionsService muhurat data).
struct MuhuratView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 28))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.3))
                Text("Muhurat Timeline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AuroTheme.primaryColor)
                Text("Coming in Phase 2")
                    .font(.system(size: 10))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
            }
            .padding(.top, 20)
        }
    }
}

#Preview {
    MuhuratView()
}
