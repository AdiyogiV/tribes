import SwiftUI
import WatchKit

/// Mantra meditation — dosha-appropriate seed mantra with a simple timer.
/// Vedic seed mantras (Bija Mantras):
///   Vata → "Om" — the universal sound, grounding and stabilizing
///   Pitta → "Shrim" (Shreem) — lunar energy, cooling and nurturing
///   Kapha → "Hrim" (Hreem) — solar energy, purifying and energizing
struct MantraView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var isMeditating = false
    @State private var secondsElapsed = 0
    @State private var targetMinutes = 5
    @State private var ticker: Timer?
    @State private var breathScale: CGFloat = 1.0

    private var dominant: String {
        let d = cache.nadiDosha.lowercased()
        if !d.isEmpty { return d }
        let v = cache.prakritiVata, p = cache.prakritiPitta, k = cache.prakritiKapha
        if (v + p + k) == 0 { return "vata" }
        let m = max(v, p, k)
        if m == v { return "vata" }
        if m == p { return "pitta" }
        return "kapha"
    }

    var body: some View {
        TabView {
            meditationPage
            mantrasPage
        }
        .tabViewStyle(.verticalPage)
        .onDisappear { stop() }
    }

    // MARK: - Page 1: Meditation

    private var meditationPage: some View {
        let mantra = mantraForDosha(dominant)
        return VStack(spacing: 6) {
            if !isMeditating {
                // Pre-start
                Text("MANTRA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.5)

                Text(mantra.sanskrit)
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundColor(AuroTheme.doshaColor(dominant))

                Text(mantra.transliteration)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Text(mantra.meaning)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)

                // Duration picker
                HStack(spacing: 12) {
                    durationButton(3)
                    durationButton(5)
                    durationButton(10)
                }
                .padding(.top, 6)

                Button(action: start) {
                    Text("Begin")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AuroTheme.doshaColor(dominant)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                // Active meditation
                Spacer()

                ZStack {
                    // Pulsing circle
                    Circle()
                        .fill(AuroTheme.doshaColor(dominant).opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(breathScale)

                    Circle()
                        .fill(AuroTheme.doshaColor(dominant).opacity(0.08))
                        .frame(width: 70, height: 70)
                        .scaleEffect(breathScale * 0.9)

                    Text(mantra.sanskrit)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(AuroTheme.doshaColor(dominant))
                }

                Spacer()

                // Timer
                let mins = secondsElapsed / 60
                let secs = secondsElapsed % 60
                Text(String(format: "%d:%02d", mins, secs))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                let target = targetMinutes * 60
                if secondsElapsed >= target {
                    Text("Target reached ✓")
                        .font(.system(size: 11))
                        .foregroundColor(.green.opacity(0.7))
                }

                Button(action: stop) {
                    Text("End")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                Spacer()
            }
        }
    }

    // MARK: - Page 2: All Mantras

    private var mantrasPage: some View {
        VStack(spacing: 8) {
            Text("SEED MANTRAS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            mantraRow("vata", mantraForDosha("vata"))
            mantraRow("pitta", mantraForDosha("pitta"))
            mantraRow("kapha", mantraForDosha("kapha"))

            Divider().background(Color.white.opacity(0.1))

            Text("Repeat silently with each exhale. Let the vibration settle into stillness.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 10)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Timer

    private func start() {
        isMeditating = true
        secondsElapsed = 0
        WKInterfaceDevice.current().play(.start)

        // Breathing animation
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathScale = 1.15
        }

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsElapsed += 1
            // Gentle haptic every minute
            if secondsElapsed % 60 == 0 {
                WKInterfaceDevice.current().play(.click)
            }
            // Completion haptic
            if secondsElapsed == targetMinutes * 60 {
                WKInterfaceDevice.current().play(.success)
            }
        }
    }

    private func stop() {
        isMeditating = false
        ticker?.invalidate()
        ticker = nil
        breathScale = 1.0
    }

    // MARK: - Helpers

    private func durationButton(_ mins: Int) -> some View {
        Button(action: { targetMinutes = mins }) {
            Text("\(mins)m")
                .font(.system(size: 12, weight: targetMinutes == mins ? .bold : .medium))
                .foregroundColor(targetMinutes == mins ? AuroTheme.doshaColor(dominant) : .white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(targetMinutes == mins ? AuroTheme.doshaColor(dominant).opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func mantraRow(_ dosha: String, _ m: MantraInfo) -> some View {
        HStack(spacing: 8) {
            Text(AuroTheme.doshaGlyph(dosha))
                .font(.system(size: 16))
                .foregroundColor(AuroTheme.doshaColor(dosha))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(m.sanskrit)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(dosha == dominant ? AuroTheme.doshaColor(dosha) : .white.opacity(0.6))
                    Text("(\(m.transliteration))")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                }
                Text(m.meaning)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }

            Spacer()

            if dosha == dominant {
                Circle()
                    .fill(AuroTheme.doshaColor(dosha))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 3)
    }

    struct MantraInfo {
        let sanskrit: String
        let transliteration: String
        let meaning: String
    }

    private func mantraForDosha(_ dosha: String) -> MantraInfo {
        switch dosha.lowercased() {
        case "vata":
            return MantraInfo(sanskrit: "ॐ", transliteration: "Om",
                              meaning: "Universal sound. Grounding, stabilizing, connects to source.")
        case "pitta":
            return MantraInfo(sanskrit: "श्रीं", transliteration: "Shreem",
                              meaning: "Lunar energy. Cooling, nurturing, softens intensity.")
        case "kapha":
            return MantraInfo(sanskrit: "ह्रीं", transliteration: "Hreem",
                              meaning: "Solar energy. Purifying, energizing, dissolves stagnation.")
        default:
            return MantraInfo(sanskrit: "ॐ", transliteration: "Om",
                              meaning: "The universal seed mantra for all constitutions.")
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.nadiDosha = "Pitta"
    return MantraView().environmentObject(cache)
}
