import SwiftUI

/// Daily Insight — full-screen page, no scroll.
/// Shows today's essence theme and insight message.
struct InsightView: View {
    @EnvironmentObject private var cache: LocalCache

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 6) {
                Spacer(minLength: 2)

                if let theme = cache.insightTheme {
                    // Label
                    Text("✦ Today's Essence")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AuroTheme.primaryColor)

                    // Theme — big and bold
                    Text(theme)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AuroTheme.goldAccent)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)

                    // Message
                    if let message = cache.insightMessage {
                        Text(message)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textSecondary))
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                            .minimumScaleFactor(0.6)
                            .lineSpacing(2)
                            .padding(.horizontal, 8)
                    }
                } else {
                    // Empty state
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(AuroTheme.goldAccent.opacity(0.5))

                    Text("Daily Insight")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AuroTheme.textLight)

                    Text("Open Aurogram on your\nphone to generate today's insight")
                        .font(.system(size: 11))
                        .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    let cache = LocalCache()
    cache.insightTheme = "Inner Stillness"
    cache.insightMessage = "The cosmic winds favor reflection today. Mercury's transit through your 4th house invites you to look inward."
    return InsightView().environmentObject(cache)
}
