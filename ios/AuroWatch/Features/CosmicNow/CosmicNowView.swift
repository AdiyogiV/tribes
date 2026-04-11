import SwiftUI

/// Hero screen — Vedic Clock with time and date details.
///
/// Shows:
///   1. Vedic analog clock (Ghati/Pala hands, Prahar segments)
///   2. Prahar name + number
///   3. Ghati · Pala readout
///   4. Vedic date (from panchang, synced from phone)
///   5. Samvat year (from panchang)
///
/// Updates every 24 seconds (1 Pala) via TimelineView.
struct CosmicNowView: View {
    @EnvironmentObject private var cache: LocalCache
    @Environment(\.isLuminanceReduced) private var isAlwaysOn

    var body: some View {
        // TimelineView updates at Pala intervals (24 seconds)
        TimelineView(.periodic(from: .now, by: 24)) { timeline in
            let now = timeline.date
            let vt = VedicTimeCalculator.calculate(from: now)
            let isDark = true // watchOS is always dark

            ScrollView {
                VStack(spacing: 4) {
                    // 1. Vedic Clock
                    GeometryReader { geo in
                        let clockSize = min(geo.size.width, geo.size.width) * 0.95
                        VedicClockView(date: now, isDark: isDark, size: clockSize)
                            .frame(maxWidth: .infinity)
                            .opacity(isAlwaysOn ? 0.6 : 1.0) // dim for Always-On
                    }
                    .aspectRatio(1, contentMode: .fit)

                    // 2. Prahar
                    Text("\(vt.praharName) Prahar \(vt.praharNumber)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AuroTheme.primaryColor.opacity(AuroTheme.textPrimary))

                    // 3. Ghati · Pala
                    Text("Ghati \(vt.ghati) · Pala \(vt.pala)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AuroTheme.primaryColor.opacity(AuroTheme.textPrimary))

                    // 4. Vedic Date (from synced panchang)
                    if let vedicDate = cache.vedicDate {
                        Text(vedicDate)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AuroTheme.primaryColor.opacity(AuroTheme.textSecondary))
                    }

                    // 5. Samvat Year
                    if let samvat = cache.samvatYear {
                        Text(samvat)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(AuroTheme.primaryColor.opacity(AuroTheme.textTertiary))
                    }

                    // 6. Numeric date (subtle)
                    if let numeric = cache.vedicNumericDate {
                        Text(numeric)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(AuroTheme.primaryColor.opacity(0.3))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.vedicDate = "Chaitra Krishna Shashthi"
    cache.samvatYear = "Vikram Samvat Raudri"
    cache.vedicNumericDate = "1/2/6/2083"

    return CosmicNowView()
        .environmentObject(cache)
}
