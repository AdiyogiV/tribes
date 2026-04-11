import SwiftUI

/// Notification summary screen — Phase 3.
///
/// Will show:
///   - Unread message count
///   - Namaste count
///   - Recent activity summary
///   - Quick Namaste send button
///
/// Data: synced from phone notification counts.
struct NotificationsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 28))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.3))
                Text("Notifications")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AuroTheme.primaryColor)
                Text("Coming in Phase 3")
                    .font(.system(size: 10))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
            }
            .padding(.top, 20)
        }
    }
}

#Preview {
    NotificationsView()
}
