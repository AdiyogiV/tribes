import SwiftUI

/// Page 1: Ojas — bold vitality score, full-screen arc gauge.
/// Clean, glanceable. One number, one word, one pulse indicator.
/// Tap to drill into contributors.
struct OjasView: View {
    @EnvironmentObject private var cache: LocalCache
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var sync: WatchSyncManager

    @State private var ojasResult: OjasResult?
    @State private var nadiReading: NadiReading?
    @State private var showDetail = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let h = max(geo.size.height, 1)
                let arcSize = min(w, h) * 0.82

                ZStack {
                    if let result = ojasResult {
                        ojasContent(result, arcSize: arcSize, w: w, h: h)
                    } else if cache.ojasScore != nil {
                        cachedContent(arcSize: arcSize, w: w, h: h)
                    } else {
                        waitingView
                    }

                    // Loading indicator (top)
                    if isLoading {
                        VStack {
                            ProgressView()
                                .tint(AuroTheme.goldAccent.opacity(0.5))
                                .scaleEffect(0.7)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }

                    // Freshness indicator (bottom)
                    VStack {
                        Spacer()
                        freshnessLabel()
                            .padding(.bottom, 6)
                    }
                }
                .frame(width: w, height: h)
            }
            .ignoresSafeArea(.all)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showDetail) {
                OjasDetailView(result: ojasResult, nadi: nadiReading)
            }
            .onAppear { computeOjas() }
        }
    }

    // MARK: - Freshness Label

    @ViewBuilder
    private func freshnessLabel() -> some View {
        if let ts = ojasResult?.computedAt ?? cache.ojasComputedAt {
            Text(AuroTheme.timeAgo(ts))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(freshnessColor(ts))
        }
    }

    private func freshnessColor(_ date: Date) -> Color {
        let hrs = -date.timeIntervalSinceNow / 3600
        if hrs < 1 { return AuroTheme.kaphaColor.opacity(0.5) }
        if hrs < 6 { return AuroTheme.textLight.opacity(0.3) }
        return AuroTheme.pittaColor.opacity(0.5) // stale
    }

    // MARK: - Main Content

    @ViewBuilder
    private func ojasContent(_ result: OjasResult, arcSize: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // Background arc (track)
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: arcSize, height: arcSize)

            // Filled arc (score)
            Circle()
                .trim(from: 0.15, to: 0.15 + 0.70 * Double(result.score) / 100.0)
                .stroke(
                    ojasGradient(score: result.score),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: arcSize, height: arcSize)

            // Center: Score + Summary
            VStack(spacing: 2) {
                Text("\(result.score)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(ojasColor(score: result.score))

                Text(result.summary)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.85))

                // Nadi gati indicator
                if let nadi = nadiReading {
                    HStack(spacing: 4) {
                        Text(AuroTheme.nadiGlyph(nadi.gati))
                            .font(.system(size: 13))
                        Text(nadi.gati)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AuroTheme.doshaColor(nadi.dominant).opacity(0.9))
                    }
                    .padding(.top, 4)
                }
            }
            .position(x: w / 2, y: h / 2 - 4)
        }
        .onTapGesture { showDetail = true }
    }

    @ViewBuilder
    private func cachedContent(arcSize: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        let score = cache.ojasScore ?? 0
        let summary = cache.ojasSummary ?? "..."

        ZStack {
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: arcSize, height: arcSize)

            Circle()
                .trim(from: 0.15, to: 0.15 + 0.70 * Double(score) / 100.0)
                .stroke(
                    ojasGradient(score: score),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: arcSize, height: arcSize)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(ojasColor(score: score))
                Text(summary)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.85))
            }
            .position(x: w / 2, y: h / 2 - 4)
        }
        .onTapGesture { showDetail = true }
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(AuroTheme.goldAccent.opacity(0.6))
            Text("Ojas")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AuroTheme.textLight)
            Text("Wear your watch\novernight to begin")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Compute

    private func computeOjas() {
        isLoading = true
        AuroLog.info("Starting Ojas computation", category: .ojas)

        health.fetchAllReadings {
            let signals = HealthSignals(
                hrv: health.latestHRV,
                rmssd: health.latestRMSSD,
                pnn50: health.latestPNN50,
                restingHR: health.latestRestingHR,
                walkingHR: health.latestWalkingHR,
                sleepDuration: health.lastSleepDuration,
                deepSleepMinutes: health.lastDeepSleepMinutes,
                remSleepMinutes: health.lastREMSleepMinutes,
                sleepOnsetHour: health.lastSleepOnsetHour,
                wristTemp: health.latestWristTemp,
                respiratoryRate: health.latestRespiratoryRate,
                vo2Max: health.latestVO2Max,
                walkingSteadiness: health.latestWalkingSteadiness,
                walkingAsymmetry: health.latestWalkingAsymmetry,
                walkingDoubleSupport: health.latestWalkingDoubleSupport,
                steps: health.todaySteps,
                hrRecovery: health.latestHRRecovery,
                spO2: health.latestSpO2,
                activeEnergy: health.todayActiveEnergy,
                mindfulMinutes: health.todayMindfulMinutes,
                standHours: health.todayStandHours,
                daylightMinutes: health.todayDaylightMinutes,
                envAudioExposure: health.latestEnvAudioExposure,
                afibBurden: health.latestAFibBurden,
                highHRCount: health.todayHighHRCount,
                irregularRhythmCount: health.todayIrregularRhythmCount,
                sleepApneaCount: health.todaySleepApneaCount,
                fallCount: health.todayFallCount,
                lowCardioFitnessCount: health.todayLowCardioFitnessCount,
                uvExposure: health.latestUVExposure,
                heartRate: health.latestHeartRate,
                exerciseMinutes: health.todayExerciseMinutes,
                coreSleepMinutes: health.lastCoreSleepMinutes,
                headphoneAudioExposure: health.latestHeadphoneAudioExposure,
                lowHRCount: health.todayLowHRCount,
                bodyTemp: health.latestBodyTemperature
            )

            // Feed the same multi-signal set into Nadi v2.
            let nadiSignals = NadiSignals(
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
                    nadiReading = NadiEngine.analyze(signals: nadiSignals, baseline: baseline)

                    var healthBase = HealthBaseline.populationDefaults
                    if let b = baseline {
                        healthBase.avgHRV = b.avgHRV
                        healthBase.stdHRV = b.stdHRV
                        healthBase.avgRHR = b.avgRHR
                        healthBase.stdRHR = b.stdRHR
                        healthBase.sampleDays = b.sampleCount
                    }

                    ojasResult = OjasEngine.computeOjas(signals: signals, baseline: healthBase)
                    if let result = ojasResult {
                        AuroLog.ojasComputed(score: result.score, signalCount: result.signalCount, reliable: result.isReliable)
                        cache.updateOjas(result)
                        cache.updateBodySignals(from: health)
                        cache.appendDailyHistory()

                        if let nadi = nadiReading {
                            AuroLog.nadiAnalyzed(dominant: nadi.dominant, gati: nadi.gati, hrv: nadi.hrv, rhr: nadi.restingHR ?? 0)
                            cache.updateNadi(
                                dominantDosha: nadi.dominant,
                                hrv: nadi.hrv,
                                restingHR: nadi.restingHR
                            )
                        }
                    } else {
                        AuroLog.warn("Ojas computation returned nil", category: .ojas)
                    }

                    let payload = cache.healthPayload()
                    AuroLog.syncEvent("Sending health to phone", keys: Array(payload.keys))
                    sync.sendToPhone(payload)
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Styling

    private func ojasColor(score: Int) -> Color {
        switch score {
        case 75...100: return AuroTheme.goldAccent
        case 55..<75:  return AuroTheme.textLight
        case 40..<55:  return AuroTheme.pittaColor
        default:       return Color(red: 0.85, green: 0.45, blue: 0.45)
        }
    }

    private func ojasGradient(score: Int) -> AngularGradient {
        let color = ojasColor(score: score)
        return AngularGradient(
            colors: [color.opacity(0.3), color],
            center: .center,
            startAngle: .degrees(54),
            endAngle: .degrees(54 + 252 * Double(score) / 100.0)
        )
    }
}

// MARK: - Ojas Detail (paged drill-down)

/// Tapped from OjasView — paged vertical TabView for signal contributors + Nadi.
/// Each page fits the screen with no scrolling.
struct OjasDetailView: View {
    let result: OjasResult?
    let nadi: NadiReading?
    @Environment(\.dismiss) private var dismiss
    @State private var detailPage = 0

    var body: some View {
        TabView(selection: $detailPage) {
            // Page 0: Signal contributors (compact bars)
            signalsPage.tag(0)

            // Page 1: Live math — full transparency on the calculation
            mathPage.tag(1)

            // Page 2: Modifier ledger
            modifiersPage.tag(2)

            // Page 3 (optional): Nadi dosha breakdown
            if nadi != nil { nadiPage.tag(3) }

            // Last: Info footer
            infoPage.tag(nadi != nil ? 4 : 3)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Page 0: Signals

    private var signalsPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 0) {
                // Back + title
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Ojas")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 2)

                if let result = result {
                    // Score header — compact
                    Text("Ojas \(result.score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(ojasColor(score: result.score))
                        .padding(.bottom, 4)

                    // Contributors — icon + fill bar, no text labels
                    let available = min(result.contributors.count, maxSignalRows(height: h))
                    let rowH: CGFloat = min(22, (h - 80) / CGFloat(max(available, 1)))

                    VStack(spacing: 2) {
                        ForEach(Array(result.contributors.prefix(available).enumerated()), id: \.offset) { _, c in
                            signalRow(c, barWidth: w - 52, rowHeight: rowH)
                        }
                    }
                    .padding(.horizontal, 10)

                    Spacer(minLength: 0)
                }
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func signalRow(_ c: OjasContributor, barWidth: CGFloat, rowHeight: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: signalIcon(c.signal))
                .font(.system(size: 11))
                .foregroundColor(statusColor(c.status))
                .frame(width: 16)

            // Compact label
            Text(c.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(0.85))
                .frame(width: 50, alignment: .leading)

            // Score bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(statusColor(c.status).opacity(0.75))
                    .frame(width: max(barWidth, 1) * c.score, height: 6)
            }

            // Weight tag
            Text("\(Int(c.weight * 100))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(AuroTheme.textLight.opacity(0.4))
                .frame(width: 26, alignment: .trailing)
        }
        .frame(height: rowHeight)
    }

    private func maxSignalRows(height: CGFloat) -> Int {
        let available = height - 70
        let perRow: CGFloat = 22
        return max(Int(available / perRow), 4)
    }

    // MARK: - Page 1: Live Math (transparent calculation)

    private var mathPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 0) {
                Text("CALCULATION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                    .tracking(1.5)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                if let result = result {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(result.contributors) { c in
                                mathRow(c)
                            }

                            Divider()
                                .background(Color.white.opacity(0.15))
                                .padding(.vertical, 4)

                            // Base score line
                            HStack {
                                Text("Base")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AuroTheme.textLight.opacity(0.85))
                                Spacer()
                                Text("\(result.baseScore)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(AuroTheme.textLight)
                            }
                            .padding(.horizontal, 8)

                            // Modifier total
                            if !result.modifiers.isEmpty {
                                HStack {
                                    Text("Modifiers")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(AuroTheme.textLight.opacity(0.6))
                                    Spacer()
                                    Text(String(format: "%+d", result.modifierDelta))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundColor(result.modifierDelta >= 0
                                                         ? AuroTheme.kaphaColor
                                                         : AuroTheme.pittaColor)
                                }
                                .padding(.horizontal, 8)
                            }

                            if result.ceiling < 100 {
                                HStack {
                                    Text("Ceiling")
                                        .font(.system(size: 10))
                                        .foregroundColor(AuroTheme.pittaColor.opacity(0.7))
                                    Spacer()
                                    Text("≤ \(result.ceiling)")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(AuroTheme.pittaColor.opacity(0.7))
                                }
                                .padding(.horizontal, 8)
                            }

                            // Final
                            HStack {
                                Text("Ojas")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(ojasColor(score: result.score))
                                Spacer()
                                Text("\(result.score)")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(ojasColor(score: result.score))
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 2)
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            .frame(width: w, height: h)
        }
    }

    /// One math row showing: signal · raw · score × weight = contribution
    @ViewBuilder
    private func mathRow(_ c: OjasContributor) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: signalIcon(c.signal))
                    .font(.system(size: 9))
                    .foregroundColor(statusColor(c.status))
                    .frame(width: 12)
                Text(c.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.85))
                Spacer()
                Text(c.rawDisplay)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AuroTheme.textLight.opacity(0.6))
            }
            HStack(spacing: 3) {
                Text(String(format: "%.0f", c.score * 100))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AuroTheme.textLight.opacity(0.5))
                Text("×")
                    .font(.system(size: 8))
                    .foregroundColor(AuroTheme.textLight.opacity(0.3))
                Text("\(Int(c.weight * 100))%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AuroTheme.textLight.opacity(0.5))
                Text("=")
                    .font(.system(size: 8))
                    .foregroundColor(AuroTheme.textLight.opacity(0.3))
                Text(String(format: "%.1f", c.contribution))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(statusColor(c.status))
                Spacer()
            }
            .padding(.leading, 14)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }

    // MARK: - Page 2: Modifier Ledger

    private var modifiersPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 0) {
                Text("MODIFIERS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                    .tracking(1.5)
                    .padding(.top, 6)
                    .padding(.bottom, 6)

                if let result = result, !result.modifiers.isEmpty {
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(result.modifiers) { m in
                                modifierRow(m)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                    }
                } else {
                    Spacer()
                    Text("No modifiers applied")
                        .font(.system(size: 11))
                        .foregroundColor(AuroTheme.textLight.opacity(0.4))
                    Spacer()
                }
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func modifierRow(_ m: OjasModifier) -> some View {
        let isPositive = m.delta > 0
        let isCap = m.note != nil

        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(m.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.85))
                Text(m.note ?? m.detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AuroTheme.textLight.opacity(0.45))
            }
            Spacer()
            Text(isCap ? "cap" : String(format: "%+.0f", m.delta))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(
                    isCap ? AuroTheme.pittaColor :
                    (isPositive ? AuroTheme.kaphaColor : AuroTheme.pittaColor)
                )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Page 3: Nadi

    private var nadiPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            if let nadi = nadi {
                VStack(spacing: 10) {
                    Spacer(minLength: 8)

                    // Glyph + dosha name
                    Text(AuroTheme.nadiGlyph(nadi.gati))
                        .font(.system(size: 36))

                    Text(nadi.dominant)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AuroTheme.doshaColor(nadi.dominant))

                    Text(nadi.gati)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AuroTheme.textLight.opacity(0.5))

                    // Dosha proportion bars
                    VStack(spacing: 6) {
                        doshaBar("V", value: nadi.vata, color: AuroTheme.vataColor, barWidth: w - 64)
                        doshaBar("P", value: nadi.pitta, color: AuroTheme.pittaColor, barWidth: w - 64)
                        doshaBar("K", value: nadi.kapha, color: AuroTheme.kaphaColor, barWidth: w - 64)
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 8)
                }
                .frame(width: w, height: h)
            }
        }
    }

    @ViewBuilder
    private func doshaBar(_ label: String, value: Double, color: Color, barWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 14)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 7)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.65))
                    .frame(width: max(barWidth, 1) * value, height: 7)
            }

            Text("\(Int(value * 100))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(AuroTheme.textLight.opacity(0.35))
                .frame(width: 22, alignment: .trailing)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Page 2: Info

    private var infoPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                if let result = result {
                    // Agni type
                    VStack(spacing: 4) {
                        Text(result.agniType.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AuroTheme.goldAccent)
                        Text(result.agniType.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AuroTheme.textLight.opacity(0.6))
                    }

                    Spacer().frame(height: 16)

                    // Signal count
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 12))
                            .foregroundColor(AuroTheme.textLight.opacity(0.4))
                        Text("\(result.signalCount) signals")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AuroTheme.textLight.opacity(0.5))
                    }

                    if !result.isReliable {
                        Text("Improving with more data")
                            .font(.system(size: 10))
                            .foregroundColor(AuroTheme.pittaColor.opacity(0.6))
                    }

                    if let ts = result.computedAt as Date? {
                        Text(AuroTheme.timeAgo(ts))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AuroTheme.textLight.opacity(0.25))
                    }
                }

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - Helpers

    private func signalIcon(_ signal: SignalType) -> String {
        switch signal {
        case .sleep:      return "moon.fill"
        case .pulse:      return "waveform.path.ecg"
        case .restingHR:  return "heart.fill"
        case .warmth:     return "thermometer.medium"
        case .breath:     return "wind"
        case .fitness:    return "figure.run"
        case .movement:   return "figure.walk"
        case .recovery:   return "arrow.down.heart.fill"
        case .oxygen:     return "lungs.fill"
        case .energy:     return "flame.fill"
        case .mindful:    return "brain.head.profile"
        }
    }

    private func statusColor(_ status: SignalStatus) -> Color {
        switch status {
        case .good:     return AuroTheme.kaphaColor
        case .moderate: return AuroTheme.goldAccent
        case .low:      return AuroTheme.pittaColor
        }
    }

    private func ojasColor(score: Int) -> Color {
        switch score {
        case 75...100: return AuroTheme.goldAccent
        case 55..<75:  return AuroTheme.textLight
        case 40..<55:  return AuroTheme.pittaColor
        default:       return Color(red: 0.85, green: 0.45, blue: 0.45)
        }
    }
}

#Preview {
    OjasView()
        .environmentObject(LocalCache())
        .environmentObject(HealthKitManager())
}
