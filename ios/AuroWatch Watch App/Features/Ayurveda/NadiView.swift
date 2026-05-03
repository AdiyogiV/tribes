import SwiftUI

/// Expanded Nadi (pulse) reading — shows the three pulse animals and current dominance.
/// In Ayurveda, Nadi Pariksha reads the radial pulse to detect dosha balance:
///   Vata pulse = Snake (Sarpa) — irregular, slithering, fast
///   Pitta pulse = Frog (Manduka) — jumping, sharp, bounding
///   Kapha pulse = Swan (Hamsa) — slow, graceful, steady
struct NadiView: View {
    @EnvironmentObject private var cache: LocalCache

    private var hasNadi: Bool { cache.hasNadi }
    private var dosha: String { cache.nadiDominantDosha ?? "" }
    private var hrv: Double { cache.hrvValue }
    private var rhr: Int { cache.restingHRInt }

    var body: some View {
        if hasNadi {
            TabView {
                pulsePage
                animalPage
                guidancePage
            }
            .tabViewStyle(.verticalPage)
        } else {
            emptyState
        }
    }

    // MARK: - Page 1: Current Pulse

    private var pulsePage: some View {
        VStack(spacing: 6) {
            Text("NADI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text(animalGlyph(dosha))
                .font(.system(size: 44))

            Text(dosha.capitalized)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AuroTheme.doshaColor(dosha))

            Text(gatiName(dosha))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(Int(hrv))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text("HRV ms")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                VStack(spacing: 2) {
                    Text("\(rhr)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text("RHR bpm")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Page 2: The Three Nadi Animals

    private var animalPage: some View {
        VStack(spacing: 8) {
            Text("THREE NADIS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            nadiRow("Vata", animal: "Sarpa", glyph: "🐍",
                    desc: "Snake — irregular, fast",
                    active: dosha.lowercased() == "vata")
            nadiRow("Pitta", animal: "Manduka", glyph: "🐸",
                    desc: "Frog — jumping, sharp",
                    active: dosha.lowercased() == "pitta")
            nadiRow("Kapha", animal: "Hamsa", glyph: "🦢",
                    desc: "Swan — slow, graceful",
                    active: dosha.lowercased() == "kapha")
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Page 3: What To Do

    private var guidancePage: some View {
        VStack(spacing: 8) {
            Text("GUIDANCE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text(AuroTheme.doshaGlyph(dosha))
                .font(.system(size: 24))
                .foregroundColor(AuroTheme.doshaColor(dosha))

            Text(nadiGuidance(dosha))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)

            Text("Based on your pulse pattern")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 4)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("NADI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)
            Text("🫀")
                .font(.system(size: 32))
            Text("Wear your watch\nfor a pulse reading")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func nadiRow(_ dosha: String, animal: String, glyph: String, desc: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Text(glyph)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(dosha) — \(animal)")
                    .font(.system(size: 13, weight: active ? .bold : .medium))
                    .foregroundColor(active ? AuroTheme.doshaColor(dosha) : .white.opacity(0.5))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(active ? .white.opacity(0.6) : .white.opacity(0.3))
            }

            Spacer()

            if active {
                Circle()
                    .fill(AuroTheme.doshaColor(dosha))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 3)
    }

    private func animalGlyph(_ dosha: String) -> String {
        switch dosha.lowercased() {
        case "vata": return "🐍"
        case "pitta": return "🐸"
        case "kapha": return "🦢"
        default: return "🫀"
        }
    }

    private func gatiName(_ dosha: String) -> String {
        switch dosha.lowercased() {
        case "vata": return "Sarpa Gati — Slithering"
        case "pitta": return "Manduka Gati — Jumping"
        case "kapha": return "Hamsa Gati — Gliding"
        default: return "Pulse Reading"
        }
    }

    private func nadiGuidance(_ dosha: String) -> String {
        switch dosha.lowercased() {
        case "vata":
            return "Your pulse is irregular and quick. Ground yourself with warm food, oil massage, and calm breathing. Avoid cold and wind."
        case "pitta":
            return "Your pulse is sharp and bounding. Cool down with sweet fruits, moonlight walks, and gentle pace. Avoid heat and spice."
        case "kapha":
            return "Your pulse is slow and steady. Energize with brisk movement, light meals, and stimulating spices like ginger."
        default:
            return "Check your pulse reading for personalized guidance."
        }
    }
}

#Preview {
    NadiView()
        .environmentObject({
            let c = LocalCache()
            c.nadiDominantDosha = "Vata"
            c.latestHRV = 42
            c.latestRestingHR = 68
            return c
        }())
}
