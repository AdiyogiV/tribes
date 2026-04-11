import SwiftUI

/// Daily Insight screen — Phase 2.
///
/// Will show:
///   - Today's essence/theme (2-5 words)
///   - Main insight message (scrollable)
///   - Next muhurat window
///
/// Data: synced from phone via WatchConnectivity.
struct InsightView: View {
    @EnvironmentObject private var cache: LocalCache

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let theme = cache.insightTheme {
                    Text("Today's Essence")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(AuroTheme.primaryColor.opacity(0.5))

                    Text(theme)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AuroTheme.primaryColor)
                        .multilineTextAlignment(.center)

                    if let message = cache.insightMessage {
                        Divider().opacity(0.2)
                        Text(message)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(AuroTheme.primaryColor.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundColor(AuroTheme.primaryColor.opacity(0.3))
                        Text("Daily insight will appear here")
                            .font(.system(size: 11))
                            .foregroundColor(AuroTheme.primaryColor.opacity(0.5))
                        Text("Open Aurogram on your phone\nto generate today's insight")
                            .font(.system(size: 9))
                            .foregroundColor(AuroTheme.primaryColor.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.insightTheme = "Inner Stillness"
    cache.insightMessage = "The cosmic winds favor reflection today. Mercury's transit through your 4th house invites you to look inward."
    return InsightView().environmentObject(cache)
}
