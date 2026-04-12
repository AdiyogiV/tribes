import SwiftUI

/// Vyayama (exercise) guidance — what movement to do based on current dosha period and balance.
/// Ayurveda recommends exercising to 50% capacity (until light sweat on forehead/armpits).
/// Exercise type varies by dosha period and personal constitution.
struct VyayamaView: View {
    @EnvironmentObject private var cache: LocalCache

    private var currentDosha: String { doshaForHour(Calendar.current.component(.hour, from: Date())) }
    private var dominant: String { cache.dominantPrakritiDosha }

    var body: some View {
        TabView {
            nowPage
            exercisePage
            rulesPage
        }
        .tabViewStyle(.verticalPage)
    }

    // MARK: - Page 1: What To Do Now

    private var nowPage: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let rec = exerciseForTime(hour: hour, dosha: dominant)

        return VStack(spacing: 6) {
            Text("VYAYAMA")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text(rec.emoji)
                .font(.system(size: 36))

            Text(rec.activity)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AuroTheme.doshaColor(currentDosha))

            Text(rec.intensity)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Text(rec.duration)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 2)

            Text("\(currentDosha.capitalized) period")
                .font(.system(size: 10))
                .foregroundColor(AuroTheme.doshaColor(currentDosha).opacity(0.6))
                .padding(.top, 4)
        }
    }

    // MARK: - Page 2: Dosha-Specific Exercises

    private var exercisePage: some View {
        VStack(spacing: 8) {
            Text("FOR YOUR DOSHA")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text(AuroTheme.doshaGlyph(dominant))
                .font(.system(size: 22))
                .foregroundColor(AuroTheme.doshaColor(dominant))

            let exercises = exercisesForDosha(dominant)
            ForEach(exercises, id: \.name) { ex in
                HStack(spacing: 8) {
                    Text(ex.emoji)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ex.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Text(ex.note)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Page 3: Ayurvedic Exercise Rules

    private var rulesPage: some View {
        VStack(spacing: 8) {
            Text("PRINCIPLES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            VStack(alignment: .leading, spacing: 8) {
                ruleRow("💧", "Stop at light sweat on forehead — that's 50% capacity")
                ruleRow("🌅", "Best time: 6–10am (Kapha period) for maximum benefit")
                ruleRow("🍽️", "Never exercise on a full stomach — wait 2-3 hours")
                ruleRow("👃", "Breathe through nose — if you need mouth, slow down")
                ruleRow("🧘", "Always end with a few minutes of stillness")
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Helpers

    private func ruleRow(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(emoji)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(1)
        }
    }

    private func doshaForHour(_ hour: Int) -> String {
        switch hour {
        case 2..<6, 14..<18: return "vata"
        case 6..<10, 18..<22: return "kapha"
        default: return "pitta"
        }
    }

    struct ExerciseRec {
        let emoji: String
        let activity: String
        let intensity: String
        let duration: String
    }

    private func exerciseForTime(hour: Int, dosha: String) -> ExerciseRec {
        let period = doshaForHour(hour)
        switch period {
        case "kapha":  // 6-10am, 6-10pm — best exercise time
            if hour < 12 {
                return doshaExerciseMorning(dosha)
            } else {
                return ExerciseRec(emoji: "🚶", activity: "Gentle Walk", intensity: "Light", duration: "15-20 min")
            }
        case "pitta":  // 10-2, 10-2 — avoid intense exercise
            if hour < 14 {
                return ExerciseRec(emoji: "🧘", activity: "Gentle Yoga", intensity: "Mild stretching only", duration: "10-15 min")
            } else {
                return ExerciseRec(emoji: "😴", activity: "Rest", intensity: "Pitta regeneration time", duration: "Sleep deeply")
            }
        default:  // vata — moderate, grounding
            if hour < 12 {
                return ExerciseRec(emoji: "🌿", activity: "Tai Chi / Yoga", intensity: "Slow, grounding", duration: "20-30 min")
            } else {
                return ExerciseRec(emoji: "🚶‍♂️", activity: "Nature Walk", intensity: "Gentle, contemplative", duration: "15-20 min")
            }
        }
    }

    private func doshaExerciseMorning(_ dosha: String) -> ExerciseRec {
        switch dosha.lowercased() {
        case "vata":
            return ExerciseRec(emoji: "🧘", activity: "Yoga & Walking", intensity: "Gentle, grounding", duration: "20-30 min")
        case "pitta":
            return ExerciseRec(emoji: "🏊", activity: "Swimming or Cycling", intensity: "Moderate, cooling", duration: "30-40 min")
        case "kapha":
            return ExerciseRec(emoji: "🏃", activity: "Running or HIIT", intensity: "Vigorous, energizing", duration: "30-45 min")
        default:
            return ExerciseRec(emoji: "🚶‍♂️", activity: "Brisk Walk", intensity: "Moderate", duration: "30 min")
        }
    }

    struct ExerciseItem: Hashable {
        let emoji: String
        let name: String
        let note: String
    }

    private func exercisesForDosha(_ dosha: String) -> [ExerciseItem] {
        switch dosha.lowercased() {
        case "vata":
            return [
                ExerciseItem(emoji: "🧘", name: "Gentle Yoga", note: "Grounding, slow flow"),
                ExerciseItem(emoji: "🚶", name: "Walking", note: "Nature, steady pace"),
                ExerciseItem(emoji: "🌊", name: "Swimming", note: "Warm water, gentle"),
                ExerciseItem(emoji: "💃", name: "Dance", note: "Rhythmic, joyful"),
            ]
        case "pitta":
            return [
                ExerciseItem(emoji: "🏊", name: "Swimming", note: "Cooling, moderate"),
                ExerciseItem(emoji: "🚴", name: "Cycling", note: "Steady, not competitive"),
                ExerciseItem(emoji: "🧘", name: "Yin Yoga", note: "Cooling, restorative"),
                ExerciseItem(emoji: "🌲", name: "Hiking", note: "Nature, shade preferred"),
            ]
        case "kapha":
            return [
                ExerciseItem(emoji: "🏃", name: "Running", note: "Vigorous, energizing"),
                ExerciseItem(emoji: "⚡", name: "HIIT", note: "Short, intense bursts"),
                ExerciseItem(emoji: "🏋️", name: "Weight Training", note: "Build strength, heat"),
                ExerciseItem(emoji: "🥊", name: "Martial Arts", note: "Stimulating, powerful"),
            ]
        default:
            return [
                ExerciseItem(emoji: "🚶‍♂️", name: "Brisk Walk", note: "Universal, daily"),
                ExerciseItem(emoji: "🧘", name: "Yoga", note: "All-dosha balance"),
                ExerciseItem(emoji: "🏊", name: "Swimming", note: "Full body, gentle"),
            ]
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.prakritiVata = 40
    cache.prakritiPitta = 35
    cache.prakritiKapha = 25
    return VyayamaView().environmentObject(cache)
}
