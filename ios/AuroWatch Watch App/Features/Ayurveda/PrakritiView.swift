import SwiftUI

/// Your birth constitution (Prakriti) — synced from phone.
/// Shows Vata/Pitta/Kapha percentages with dominant dosha and a brief description.
struct PrakritiView: View {
    @EnvironmentObject private var cache: LocalCache

    private var prakritiType: String { cache.prakritiType ?? "" }
    private var vata: Double { cache.prakritiVataPercent }
    private var pitta: Double { cache.prakritiPittaPercent }
    private var kapha: Double { cache.prakritiKaphaPercent }
    private var hasPrakriti: Bool { cache.hasPrakriti }

    var body: some View {
        if hasPrakriti {
            TabView {
                mainPage
                detailPage
            }
            .tabViewStyle(.verticalPage)
        } else {
            emptyState
        }
    }

    // MARK: - Page 1: Constitution Overview

    private var mainPage: some View {
        VStack(spacing: 6) {
            Text("PRAKRITI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            // Dominant dosha glyph
            Text(AuroTheme.doshaGlyph(dominant))
                .font(.system(size: 36))
                .foregroundColor(AuroTheme.doshaColor(dominant))

            Text(prakritiType.uppercased())
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AuroTheme.doshaColor(dominant))

            Text("Birth Constitution")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            // Three dosha bars
            VStack(spacing: 5) {
                doshaBar("Vata", pct: vata, color: AuroTheme.doshaColor("vata"))
                doshaBar("Pitta", pct: pitta, color: AuroTheme.doshaColor("pitta"))
                doshaBar("Kapha", pct: kapha, color: AuroTheme.doshaColor("kapha"))
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Page 2: What It Means

    private var detailPage: some View {
        VStack(spacing: 8) {
            Text("YOUR NATURE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text(doshaDescription(dominant))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Divider().background(Color.white.opacity(0.15))

            Text("Prakriti is your fixed birth constitution. It never changes. Use it as your baseline for all Ayurvedic guidance.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("PRAKRITI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)
            Text("Complete your\nPrakriti quiz\non the phone")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private var dominant: String { cache.dominantPrakritiDosha }

    private func doshaBar(_ name: String, pct: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
                .frame(width: 38, alignment: .leading)

            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: w * CGFloat(pct / 100.0), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(Int(pct))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func doshaDescription(_ dosha: String) -> String {
        switch dosha.lowercased() {
        case "vata":
            return "Creative, quick-thinking, and energetic. You thrive with warmth, routine, and grounding practices. Favor warm foods and calm environments."
        case "pitta":
            return "Sharp intellect, strong drive, and natural leadership. You thrive with cooling activities, moderate pace, and sweet/bitter foods."
        case "kapha":
            return "Steady, nurturing, and strong endurance. You thrive with stimulation, vigorous movement, and light/warm foods."
        default:
            return "A unique blend of all three doshas. Balance is your strength — maintain variety in diet, exercise, and routine."
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.prakritiType = "Vata-Pitta"
    cache.prakritiVata = 45
    cache.prakritiPitta = 35
    cache.prakritiKapha = 20
    return PrakritiView().environmentObject(cache)
}
