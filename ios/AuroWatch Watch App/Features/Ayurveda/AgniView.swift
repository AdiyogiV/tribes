import SwiftUI

/// Agni (digestive fire) — shows current type, optimal meal timing, and food guidance.
/// Agni types:
///   Sama — balanced, eat at regular times
///   Vishama — irregular (Vata), eat warm/small/frequent
///   Tikshna — sharp (Pitta), eat cooling/regular, don't skip meals
///   Manda — slow (Kapha), eat light/warm, skip or delay breakfast
struct AgniView: View {
    @EnvironmentObject private var cache: LocalCache

    private var agniType: String { cache.safeAgniType }

    var body: some View {
        TabView {
            statusPage
            mealTimingPage
            foodPage
        }
        .tabViewStyle(.verticalPage)
    }

    // MARK: - Page 1: Agni Status

    private var statusPage: some View {
        VStack(spacing: 6) {
            Text("AGNI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text("🔥")
                .font(.system(size: 40))

            Text(agniType.capitalized)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(agniColor)

            Text(agniSubtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Text(agniDescription)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
    }

    // MARK: - Page 2: When To Eat

    private var mealTimingPage: some View {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)

        return VStack(spacing: 8) {
            Text("MEAL TIMING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            // Current digestive window
            let window = digestiveWindow(hour: hour)
            Text(window.emoji)
                .font(.system(size: 28))

            Text(window.label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(window.color)

            Text(window.advice)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)

            // Agni-specific meal tip
            Text(agniMealTip)
                .font(.system(size: 11))
                .foregroundColor(agniColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Page 3: What To Eat

    private var foodPage: some View {
        VStack(spacing: 8) {
            Text("FOOD GUIDE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            // Favor section
            VStack(spacing: 4) {
                Text("FAVOR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green.opacity(0.7))
                    .tracking(1)
                Text(favorFoods)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Divider().background(Color.white.opacity(0.1))

            // Reduce section
            VStack(spacing: 4) {
                Text("REDUCE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange.opacity(0.7))
                    .tracking(1)
                Text(reduceFoods)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Digestive Window

    private struct DigestiveWindow {
        let emoji: String
        let label: String
        let advice: String
        let color: Color
    }

    private func digestiveWindow(hour: Int) -> DigestiveWindow {
        switch hour {
        case 6..<10:
            return DigestiveWindow(emoji: "🌅", label: "Light Breakfast",
                                   advice: "Agni is waking up. Eat light — fruit, warm porridge, or herbal tea.",
                                   color: .orange)
        case 10..<14:
            return DigestiveWindow(emoji: "☀️", label: "Main Meal",
                                   advice: "Agni is strongest now. This is your biggest meal — eat well, eat warm.",
                                   color: .yellow)
        case 14..<18:
            return DigestiveWindow(emoji: "🍵", label: "Light Snack",
                                   advice: "Agni is declining. Have a light snack if hungry — nuts, fruit, or tea.",
                                   color: .teal)
        case 18..<21:
            return DigestiveWindow(emoji: "🌙", label: "Early Dinner",
                                   advice: "Eat light and early. Soups, steamed vegetables, or kitchari. Finish by 7pm if possible.",
                                   color: Color(white: 0.6))
        default:
            return DigestiveWindow(emoji: "😴", label: "Fasting Window",
                                   advice: "Agni is resting. Avoid eating. Warm water or herbal tea only.",
                                   color: Color(white: 0.4))
        }
    }

    // MARK: - Agni-Specific Data

    private var agniColor: Color {
        switch agniType.lowercased() {
        case "sama": return .green
        case "vishama": return AuroTheme.doshaColor("vata")
        case "tikshna": return AuroTheme.doshaColor("pitta")
        case "manda": return AuroTheme.doshaColor("kapha")
        default: return .orange
        }
    }

    private var agniSubtitle: String {
        switch agniType.lowercased() {
        case "sama": return "Balanced Digestion"
        case "vishama": return "Irregular Digestion"
        case "tikshna": return "Sharp Digestion"
        case "manda": return "Slow Digestion"
        default: return "Digestive Fire"
        }
    }

    private var agniDescription: String {
        switch agniType.lowercased() {
        case "sama": return "Your digestion is balanced. Maintain regular meal times."
        case "vishama": return "Irregular appetite. Eat warm, small meals at consistent times."
        case "tikshna": return "Strong hunger, fast metabolism. Never skip meals. Eat cooling foods."
        case "manda": return "Slow digestion. Eat light, warm foods. Add ginger and spices."
        default: return "Understanding your digestive fire helps optimize nutrition."
        }
    }

    private var agniMealTip: String {
        switch agniType.lowercased() {
        case "vishama": return "Tip: Sip warm ginger water between meals"
        case "tikshna": return "Tip: Don't skip meals — keep blood sugar steady"
        case "manda": return "Tip: Start with a glass of warm lemon water"
        default: return "Tip: Eat your largest meal when the sun is highest"
        }
    }

    private var favorFoods: String {
        switch agniType.lowercased() {
        case "vishama": return "Warm soups, cooked grains, ghee, ginger tea, root vegetables, sweet fruits"
        case "tikshna": return "Cooling foods — cucumber, melon, coconut, mint, bitter greens, sweet fruits"
        case "manda": return "Light warm foods — ginger, pepper, leafy greens, honey, legumes, barley"
        default: return "Fresh seasonal foods, warm meals, variety of all six tastes"
        }
    }

    private var reduceFoods: String {
        switch agniType.lowercased() {
        case "vishama": return "Raw salads, cold drinks, dry crackers, beans, caffeine"
        case "tikshna": return "Spicy food, sour/fermented, alcohol, excess salt, fried food"
        case "manda": return "Heavy/oily food, dairy, sweets, cold drinks, large portions"
        default: return "Processed food, excess cold drinks, eating too late"
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.agniType = "Tikshna"
    return AgniView().environmentObject(cache)
}
