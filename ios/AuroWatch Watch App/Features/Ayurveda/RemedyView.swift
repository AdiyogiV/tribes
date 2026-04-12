import SwiftUI

/// Quick dosha-balancing remedies based on current Vikriti (imbalance).
/// Computes current dosha deviation from Prakriti and shows targeted fixes.
/// If no Prakriti data, falls back to Nadi dosha for general remedies.
struct RemedyView: View {
    @EnvironmentObject private var cache: LocalCache

    private var elevated: String { computeElevatedDosha() }
    private var hasData: Bool { cache.hasNadi || cache.hasPrakriti }

    var body: some View {
        if hasData {
            TabView {
                statusPage
                remediesPage
                teaPage
            }
            .tabViewStyle(.verticalPage)
        } else {
            emptyState
        }
    }

    // MARK: - Page 1: What's Elevated

    private var statusPage: some View {
        VStack(spacing: 6) {
            Text("REMEDY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text(AuroTheme.doshaGlyph(elevated))
                .font(.system(size: 36))
                .foregroundColor(AuroTheme.doshaColor(elevated))

            Text("\(elevated.capitalized) Elevated")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AuroTheme.doshaColor(elevated))

            Text(elevationCause(elevated))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.top, 4)
        }
    }

    // MARK: - Page 2: Quick Remedies

    private var remediesPage: some View {
        let remedies = remediesForDosha(elevated)
        return VStack(spacing: 8) {
            Text("QUICK FIXES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            ForEach(remedies, id: \.emoji) { r in
                HStack(spacing: 8) {
                    Text(r.emoji)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Text(r.detail)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Page 3: Tea Prescription

    private var teaPage: some View {
        let tea = teaForDosha(elevated)
        return VStack(spacing: 8) {
            Text("TEA REMEDY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text("🍵")
                .font(.system(size: 32))

            Text(tea.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AuroTheme.doshaColor(elevated))

            Text(tea.recipe)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)

            Text(tea.effect)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("REMEDY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)
            Text("🌿")
                .font(.system(size: 32))
            Text("Wear watch for\npulse reading first")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Compute Elevation

    private func computeElevatedDosha() -> String {
        // If we have Vikriti data (Prakriti + signals), use deviation
        let pV = cache.prakritiVata, pP = cache.prakritiPitta, pK = cache.prakritiKapha
        if (pV + pP + pK) > 0 {
            // Simple vikriti from available signals (similar to VikritiView logic)
            var v = pV, p = pP, k = pK

            if cache.hrvValue > 60 { v += 8 }
            else if cache.hrvValue > 0 && cache.hrvValue < 25 { k += 6 }

            if Double(cache.restingHRInt) > 75 { p += 5 }
            else if Double(cache.restingHRInt) > 0 && Double(cache.restingHRInt) < 55 { k += 5 }

            let total = v + p + k
            if total > 0 {
                let vPct = v * 100 / total, pPct = p * 100 / total, kPct = k * 100 / total
                // Find which shifted most from prakriti
                let vShift = vPct - pV, pShift = pPct - pP, kShift = kPct - pK
                let maxShift = max(vShift, pShift, kShift)
                if maxShift == vShift { return "vata" }
                if maxShift == pShift { return "pitta" }
                return "kapha"
            }
        }

        // Fallback to Nadi dosha
        return cache.activeDominantDosha
    }

    private func elevationCause(_ dosha: String) -> String {
        switch dosha {
        case "vata": return "Signs: anxiety, dry skin, restlessness, irregular digestion, light sleep"
        case "pitta": return "Signs: irritability, heat, acidity, skin rashes, sharp hunger"
        case "kapha": return "Signs: heaviness, lethargy, congestion, slow digestion, oversleeping"
        default: return ""
        }
    }

    // MARK: - Remedies

    struct Remedy {
        let emoji: String
        let title: String
        let detail: String
    }

    private func remediesForDosha(_ dosha: String) -> [Remedy] {
        switch dosha {
        case "vata":
            return [
                Remedy(emoji: "🫧", title: "Warm oil massage", detail: "Sesame oil on feet and scalp"),
                Remedy(emoji: "🥛", title: "Warm milk + nutmeg", detail: "Before bed, with a pinch of nutmeg"),
                Remedy(emoji: "🛁", title: "Warm bath", detail: "Add a few drops of lavender"),
                Remedy(emoji: "🧘", title: "Slow breathing", detail: "4-count inhale, 6-count exhale"),
            ]
        case "pitta":
            return [
                Remedy(emoji: "🥥", title: "Coconut water", detail: "Room temperature, sip slowly"),
                Remedy(emoji: "🌙", title: "Moonlight walk", detail: "10 min in cool evening air"),
                Remedy(emoji: "🥒", title: "Cucumber + mint", detail: "Cooling snack for internal heat"),
                Remedy(emoji: "🌿", title: "Aloe vera gel", detail: "1 tbsp before meals for acidity"),
            ]
        case "kapha":
            return [
                Remedy(emoji: "🫚", title: "Ginger tea", detail: "Fresh ginger + honey + lemon"),
                Remedy(emoji: "🏃", title: "Vigorous movement", detail: "15 min brisk walk or jumping"),
                Remedy(emoji: "🌶️", title: "Warming spices", detail: "Add turmeric + black pepper to food"),
                Remedy(emoji: "🍯", title: "Honey water", detail: "Warm (not hot) water + raw honey AM"),
            ]
        default:
            return []
        }
    }

    struct TeaInfo {
        let name: String
        let recipe: String
        let effect: String
    }

    private func teaForDosha(_ dosha: String) -> TeaInfo {
        switch dosha {
        case "vata":
            return TeaInfo(name: "Ashwagandha Chai",
                           recipe: "Warm milk, ½ tsp ashwagandha, pinch cinnamon, cardamom, jaggery",
                           effect: "Calms nerves, grounds energy, promotes deep sleep")
        case "pitta":
            return TeaInfo(name: "Rose Fennel Tea",
                           recipe: "Steep rose petals + fennel seeds in warm water, add rock sugar",
                           effect: "Cools internal heat, soothes digestion, calms anger")
        case "kapha":
            return TeaInfo(name: "Trikatu Brew",
                           recipe: "Hot water + ginger + black pepper + long pepper + honey (warm)",
                           effect: "Ignites Agni, clears congestion, breaks lethargy")
        default:
            return TeaInfo(name: "CCF Tea",
                           recipe: "Cumin + coriander + fennel seeds, steep 5 min",
                           effect: "Balances all three doshas, aids digestion")
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.prakritiVata = 40
    cache.prakritiPitta = 35
    cache.prakritiKapha = 25
    cache.nadiDominantDosha = "Vata"
    cache.latestHRV = 55
    cache.latestRestingHR = 72
    return RemedyView().environmentObject(cache)
}
