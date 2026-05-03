import SwiftUI
import WatchKit

/// Abhyanga (self-massage) guide — dosha-specific oil recommendation + timer.
/// Traditional Ayurveda recommends daily oil massage before bathing:
///   Vata → Sesame oil (warming, grounding)
///   Pitta → Coconut oil (cooling, soothing)
///   Kapha → Mustard oil (stimulating, warming)
struct AbhyangaView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var timerActive = false
    @State private var secondsRemaining = 300  // 5 minutes
    @State private var ticker: Timer?

    private var dominant: String { cache.dominantPrakritiDosha }

    var body: some View {
        TabView {
            oilPage
            stepsPage
            timerPage
        }
        .tabViewStyle(.verticalPage)
        .onDisappear { stopTimer() }
    }

    // MARK: - Page 1: Your Oil

    private var oilPage: some View {
        let oil = oilForDosha(dominant)
        return VStack(spacing: 6) {
            Text("ABHYANGA")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text("🫧")
                .font(.system(size: 36))

            Text(oil.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AuroTheme.doshaColor(dominant))

            Text(oil.quality)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Text(oil.benefit)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.top, 4)

            Text("Best: morning before bath")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 4)
        }
    }

    // MARK: - Page 2: How To

    private var stepsPage: some View {
        VStack(spacing: 8) {
            Text("HOW TO")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            VStack(alignment: .leading, spacing: 10) {
                stepRow("1", "Warm the oil slightly (body temperature)")
                stepRow("2", "Start at scalp & face — circular motions")
                stepRow("3", "Long strokes on limbs, circles on joints")
                stepRow("4", "Clockwise circles on abdomen")
                stepRow("5", "Let oil soak 5-15 min, then bathe warm")
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Page 3: Timer

    private var timerPage: some View {
        VStack(spacing: 8) {
            Text("MASSAGE TIMER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: CGFloat(Double(secondsRemaining) / 300.0))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    let mins = secondsRemaining / 60
                    let secs = secondsRemaining % 60
                    Text(String(format: "%d:%02d", mins, secs))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("minutes")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            if !timerActive && secondsRemaining == 300 {
                Button(action: startTimer) {
                    Text("Start")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange))
                }
                .buttonStyle(.plain)
            } else if timerActive {
                Button(action: stopTimer) {
                    Text("Pause")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            } else if secondsRemaining == 0 {
                Text("Complete! ✓")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                Button(action: resetTimer) {
                    Text("Reset")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange.opacity(0.7))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    Button(action: startTimer) {
                        Text("Resume")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    Button(action: resetTimer) {
                        Text("Reset")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Timer Logic

    private func startTimer() {
        timerActive = true
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
                // Haptic at each minute mark
                if secondsRemaining % 60 == 0 && secondsRemaining > 0 {
                    WKInterfaceDevice.current().play(.click)
                }
                if secondsRemaining == 0 {
                    WKInterfaceDevice.current().play(.success)
                    stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timerActive = false
        ticker?.invalidate()
        ticker = nil
    }

    private func resetTimer() {
        stopTimer()
        secondsRemaining = 300
    }

    // MARK: - Helpers

    private func stepRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(1)
        }
    }

    struct OilInfo {
        let name: String
        let quality: String
        let benefit: String
    }

    private func oilForDosha(_ dosha: String) -> OilInfo {
        switch dosha.lowercased() {
        case "vata":
            return OilInfo(name: "Sesame Oil", quality: "Warming & Grounding",
                           benefit: "Calms nervous system, nourishes dry skin, reduces anxiety and joint stiffness")
        case "pitta":
            return OilInfo(name: "Coconut Oil", quality: "Cooling & Soothing",
                           benefit: "Reduces heat, calms inflammation, soothes sensitive skin and irritability")
        case "kapha":
            return OilInfo(name: "Mustard Oil", quality: "Stimulating & Warming",
                           benefit: "Breaks stagnation, improves circulation, reduces water retention and lethargy")
        default:
            return OilInfo(name: "Sesame Oil", quality: "Balancing",
                           benefit: "The classic Ayurvedic massage oil, suitable for most constitutions")
        }
    }
}

#Preview {
    AbhyangaView()
        .environmentObject({
            let c = LocalCache()
            c.prakritiVata = 45
            c.prakritiPitta = 30
            c.prakritiKapha = 25
            return c
        }())
}
