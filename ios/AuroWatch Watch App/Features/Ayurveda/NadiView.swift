import SwiftUI

/// Expanded Nadi (pulse) reading — shows the three pulse animals, dominance, AND
/// the live multi-signal calculation that produced the result.
///
/// Pages (vertical swipe):
///   1. Pulse:     animal glyph + dominant dosha + raw vitals
///   2. Animals:   the three classical Nadi types and which is active
///   3. Math:      live transparent contributor breakdown (signal × weight)
///   4. Guidance:  what to do based on the dominant pattern
struct NadiView: View {
    @EnvironmentObject private var cache: LocalCache
    @EnvironmentObject private var health: HealthKitManager

    @State private var reading: NadiReading?
    @State private var isComputing = false

    private var hasNadi: Bool { reading != nil || cache.hasNadi }
    private var dosha: String { reading?.dominant ?? cache.nadiDominantDosha ?? "" }

    var body: some View {
        Group {
            if hasNadi {
                TabView {
                    pulsePage
                    animalPage
                    mathPage
                    guidancePage
                }
                .tabViewStyle(.verticalPage)
            } else {
                emptyState
            }
        }
        .onAppear { computeIfNeeded() }
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
                    Text(reading.map { String(format: "%.0f", $0.hrv) } ?? "\(Int(cache.hrvValue))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text("HRV ms")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                VStack(spacing: 2) {
                    Text(reading?.restingHR.map { String(format: "%.0f", $0) } ?? "\(cache.restingHRInt)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text("RHR bpm")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                if let conf = reading?.confidence {
                    VStack(spacing: 2) {
                        Text("\(Int(conf * 100))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(confidenceColor(conf))
                        Text("conf %")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Page 2: Three Nadi Animals

    private var animalPage: some View {
        VStack(spacing: 8) {
            Text("THREE NADIS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            nadiRow("Vata", animal: "Sarpa", glyph: "🐍",
                    desc: "Snake — irregular, fast",
                    active: dosha.lowercased() == "vata",
                    proportion: reading?.vata)
            nadiRow("Pitta", animal: "Manduka", glyph: "🐸",
                    desc: "Frog — jumping, sharp",
                    active: dosha.lowercased() == "pitta",
                    proportion: reading?.pitta)
            nadiRow("Kapha", animal: "Hamsa", glyph: "🦢",
                    desc: "Swan — slow, graceful",
                    active: dosha.lowercased() == "kapha",
                    proportion: reading?.kapha)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Page 3: Live Math (transparent calculation)

    private var mathPage: some View {
        VStack(spacing: 4) {
            Text("HOW IT'S READ")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                .tracking(1.5)
                .padding(.top, 6)

            if let r = reading {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(r.contributors) { c in
                            mathRow(c)
                        }

                        Divider()
                            .background(Color.white.opacity(0.15))
                            .padding(.vertical, 3)

                        // Final V/P/K with weighted totals
                        HStack(spacing: 6) {
                            doshaTag("V", value: r.vata, color: AuroTheme.vataColor)
                            doshaTag("P", value: r.pitta, color: AuroTheme.pittaColor)
                            doshaTag("K", value: r.kapha, color: AuroTheme.kaphaColor)
                        }
                        .padding(.top, 2)

                        Text("\(r.contributors.count) signals · \(Int(r.confidence * 100))% complete")
                            .font(.system(size: 9))
                            .foregroundColor(AuroTheme.textLight.opacity(0.35))
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 12)
                }
            } else {
                Spacer()
                Text("Waiting for sensors")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func mathRow(_ c: NadiContributor) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(c.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.85))
                Spacer()
                Text(c.rawDisplay)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AuroTheme.textLight.opacity(0.55))
                Text("\(Int(c.weight * 100))%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.6))
            }
            // Per-signal V/P/K mini-bars
            HStack(spacing: 2) {
                miniBar(value: c.weightedVata, max: c.weight, color: AuroTheme.vataColor)
                miniBar(value: c.weightedPitta, max: c.weight, color: AuroTheme.pittaColor)
                miniBar(value: c.weightedKapha, max: c.weight, color: AuroTheme.kaphaColor)
            }
            Text(c.baselineDisplay)
                .font(.system(size: 8))
                .foregroundColor(AuroTheme.textLight.opacity(0.35))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func miniBar(value: Double, max maxWeight: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.7))
                    .frame(width: geo.size.width * (maxWeight > 0 ? value / maxWeight : 0))
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private func doshaTag(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text("\(Int(value * 100))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(AuroTheme.textLight.opacity(0.8))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.12))
        )
    }

    // MARK: - Page 4: What To Do

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

    // MARK: - Compute

    private func computeIfNeeded() {
        // If we already computed, don't redo (preserves contributors across page swipes).
        if reading != nil { return }
        if isComputing { return }
        isComputing = true

        let signals = NadiSignals(
            hrv: health.latestHRV,
            rmssd: health.latestRMSSD,
            pnn50: health.latestPNN50,
            restingHR: health.latestRestingHR,
            walkingHR: health.latestWalkingHR,
            respiratoryRate: health.latestRespiratoryRate,
            sleepDuration: health.lastSleepDuration,
            deepSleepMinutes: health.lastDeepSleepMinutes,
            remSleepMinutes: health.lastREMSleepMinutes,
            wristTempDeviation: health.latestWristTemp,
            walkingAsymmetry: health.latestWalkingAsymmetry,
            walkingDoubleSupport: health.latestWalkingDoubleSupport,
            irregularRhythmCount: health.todayIrregularRhythmCount,
            afibBurden: health.latestAFibBurden,
            highHRCount: health.todayHighHRCount,
            sleepApneaCount: health.todaySleepApneaCount,
            fallCount: health.todayFallCount
        )

        health.fetchHRVHistory(days: 14) { samples in
            DispatchQueue.main.async {
                let baseline = NadiEngine.computeBaseline(hrvHistory: samples, restingHRHistory: nil)
                self.reading = NadiEngine.analyze(signals: signals, baseline: baseline)
                self.isComputing = false
            }
        }
    }

    // MARK: - Helpers

    private func nadiRow(_ dosha: String, animal: String, glyph: String, desc: String, active: Bool, proportion: Double?) -> some View {
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

            if let p = proportion {
                Text("\(Int(p * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(AuroTheme.doshaColor(dosha).opacity(active ? 1.0 : 0.5))
            } else if active {
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

    private func confidenceColor(_ c: Double) -> Color {
        if c >= 0.8 { return AuroTheme.kaphaColor }
        if c >= 0.5 { return AuroTheme.goldAccent }
        return AuroTheme.pittaColor
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
        .environmentObject(HealthKitManager())
}
