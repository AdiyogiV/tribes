import SwiftUI
import WatchKit

/// Haptic-guided Pranayama (breathing exercise) for Apple Watch.
/// Selects a dosha-appropriate technique and guides with haptic taps:
///   Vata → Nadi Shodhana (alternate nostril, calming)
///   Pitta → Sheetali (cooling breath)
///   Kapha → Kapalabhati (energizing skull-shining breath)
///   Default → Box Breathing (4-4-4-4)
struct PranayamaView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var isBreathing = false
    @State private var phase: BreathPhase = .ready
    @State private var cycleCount = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?

    private let totalCycles = 5

    enum BreathPhase: String {
        case ready = "Ready"
        case inhale = "Inhale"
        case hold = "Hold"
        case exhale = "Exhale"
        case holdOut = "Hold Out"
        case complete = "Done"
    }

    private var technique: Technique { techniqueForDosha(cache.nadiDominantDosha ?? "") }

    var body: some View {
        TabView {
            breathingPage
            infoPage
        }
        .tabViewStyle(.verticalPage)
        .onDisappear { stopBreathing() }
    }

    // MARK: - Page 1: Breathing Exercise

    private var breathingPage: some View {
        VStack(spacing: 6) {
            Text(technique.name.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 100, height: 100)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)

                // Center content
                VStack(spacing: 2) {
                    if phase == .ready {
                        Text("🌬️")
                            .font(.system(size: 28))
                    } else if phase == .complete {
                        Text("✓")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text(phase.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(phaseColor)
                        Text("\(cycleCount)/\(totalCycles)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            if phase == .ready {
                Button(action: startBreathing) {
                    Text("Begin")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.teal))
                }
                .buttonStyle(.plain)
            } else if phase == .complete {
                Text("\(totalCycles) cycles complete")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Button(action: {
                    phase = .ready
                    cycleCount = 0
                    progress = 0
                }) {
                    Text("Again")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.teal)
                }
                .buttonStyle(.plain)
            } else {
                Text(phaseInstruction)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Page 2: Technique Info

    private var infoPage: some View {
        VStack(spacing: 8) {
            Text("TECHNIQUE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            Text(technique.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.teal)

            Text(technique.description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)

            Divider().background(Color.white.opacity(0.1))

            Text("Pattern: \(technique.patternLabel)")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))

            if let dosha = cache.nadiDominantDosha, !dosha.isEmpty {
                Text("Selected for \(dosha.capitalized) pulse")
                    .font(.system(size: 10))
                    .foregroundColor(AuroTheme.doshaColor(dosha).opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Breathing Engine

    private func startBreathing() {
        isBreathing = true
        cycleCount = 0
        runPhase(.inhale)
    }

    private func stopBreathing() {
        timer?.invalidate()
        timer = nil
        isBreathing = false
    }

    private func runPhase(_ next: BreathPhase) {
        phase = next
        progress = 0

        let duration: Double
        switch next {
        case .inhale: duration = technique.inhale
        case .hold: duration = technique.holdIn
        case .exhale: duration = technique.exhale
        case .holdOut: duration = technique.holdOut
        case .complete, .ready:
            stopBreathing()
            return
        }

        // Skip phases with 0 duration
        if duration <= 0 {
            advancePhase()
            return
        }

        // Haptic at start of phase
        WKInterfaceDevice.current().play(next == .inhale ? .start : (next == .exhale ? .stop : .click))

        // Animate progress over duration
        let steps = Int(duration * 10)
        var step = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            step += 1
            progress = Double(step) / Double(steps)
            if step >= steps {
                t.invalidate()
                advancePhase()
            }
        }
    }

    private func advancePhase() {
        switch phase {
        case .inhale:
            if technique.holdIn > 0 { runPhase(.hold) }
            else { runPhase(.exhale) }
        case .hold:
            runPhase(.exhale)
        case .exhale:
            if technique.holdOut > 0 { runPhase(.holdOut) }
            else { endCycle() }
        case .holdOut:
            endCycle()
        default:
            break
        }
    }

    private func endCycle() {
        cycleCount += 1
        if cycleCount >= totalCycles {
            phase = .complete
            progress = 1
            WKInterfaceDevice.current().play(.success)
            stopBreathing()
        } else {
            runPhase(.inhale)
        }
    }

    // MARK: - Phase Visuals

    private var phaseColor: Color {
        switch phase {
        case .inhale: return .teal
        case .hold, .holdOut: return .yellow.opacity(0.7)
        case .exhale: return .blue
        case .complete: return .green
        case .ready: return .white.opacity(0.3)
        }
    }

    private var phaseInstruction: String {
        switch phase {
        case .inhale: return "Breathe in slowly"
        case .hold: return "Hold gently"
        case .exhale: return "Release slowly"
        case .holdOut: return "Stay empty"
        default: return ""
        }
    }

    // MARK: - Techniques

    struct Technique {
        let name: String
        let description: String
        let inhale: Double    // seconds
        let holdIn: Double
        let exhale: Double
        let holdOut: Double
        var patternLabel: String {
            let parts = [inhale, holdIn, exhale, holdOut].map { "\(Int($0))" }
            return parts.joined(separator: "-")
        }
    }

    private func techniqueForDosha(_ dosha: String) -> Technique {
        switch dosha.lowercased() {
        case "vata":
            return Technique(name: "Nadi Shodhana",
                             description: "Alternate nostril breathing. Deeply calming, balances left and right energy channels. Grounds Vata's restless energy.",
                             inhale: 4, holdIn: 4, exhale: 6, holdOut: 0)
        case "pitta":
            return Technique(name: "Sheetali",
                             description: "Cooling breath. Inhale through curled tongue, exhale through nose. Cools Pitta's internal heat.",
                             inhale: 4, holdIn: 2, exhale: 6, holdOut: 0)
        case "kapha":
            return Technique(name: "Kapalabhati",
                             description: "Skull-shining breath. Quick forceful exhales with passive inhales. Energizes and clears Kapha stagnation.",
                             inhale: 2, holdIn: 0, exhale: 1, holdOut: 1)
        default:
            return Technique(name: "Box Breathing",
                             description: "Equal-ratio breathing for balance and focus. Universal technique suitable for all constitutions.",
                             inhale: 4, holdIn: 4, exhale: 4, holdOut: 4)
        }
    }
}

#Preview {
    PranayamaView()
        .environmentObject({
            let c = LocalCache()
            c.nadiDominantDosha = "Pitta"
            return c
        }())
}
