import SwiftUI

/// Digital Nadi Monitor — paged view (vertical swipe).
///   1. Snapshot:   gati + dosha + bars + harmony
///   2. Math:       multi-signal contributors with raw values
struct NadiMonitorView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var cache: LocalCache
    @EnvironmentObject private var syncManager: WatchSyncManager
    @State private var reading: NadiReading?
    @State private var baseline: NadiBaseline?
    @State private var isLoading = false

    /// Throttle: prevent duplicate phone syncs across tab switches.
    private static var lastPhoneSyncAt: Date?
    private static let minSyncInterval: TimeInterval = 30

    var body: some View {
        Group {
            if reading != nil {
                TabView {
                    snapshotPage
                    mathPage
                }
                .tabViewStyle(.verticalPage)
            } else if isLoading {
                loadingView
            } else if !health.isAuthorized {
                authPrompt
            } else {
                noDataView
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { refreshNadi() }
    }

    // MARK: - Snapshot Page

    private var snapshotPage: some View {
        GeometryReader { geo in
            VStack(spacing: 6) {
                Spacer(minLength: 2)
                if let r = reading {
                    Text("\(r.gati) Gati")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AuroTheme.doshaColor(r.dominant))

                    Text("\(r.dominant) Nadi")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AuroTheme.doshaColor(r.dominant).opacity(0.8))

                    VStack(spacing: 4) {
                        doshaBar("V", value: r.vata, color: AuroTheme.vataColor, width: geo.size.width - 24)
                        doshaBar("P", value: r.pitta, color: AuroTheme.pittaColor, width: geo.size.width - 24)
                        doshaBar("K", value: r.kapha, color: AuroTheme.kaphaColor, width: geo.size.width - 24)
                    }
                    .padding(.vertical, 2)

                    let hour = Calendar.current.component(.hour, from: .now)
                    let expectedDosha = VedicTimeCalculator.currentDosha(forHour: hour)
                    if r.dominant == expectedDosha {
                        Text("☀ In harmony")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Text("\(r.dominant) during \(expectedDosha) time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }

                    HStack(spacing: 14) {
                        rawStat(label: "HRV", value: String(format: "%.0f", r.hrv))
                        if let rhr = r.restingHR {
                            rawStat(label: "RHR", value: String(format: "%.0f", rhr))
                        }
                        rawStat(label: "conf",
                                value: "\(Int(r.confidence * 100))%",
                                tint: confidenceColor(r.confidence))
                    }
                }
                Spacer(minLength: 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Math Page (live calculation)

    private var mathPage: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                Text("HOW IT'S READ")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                    .tracking(1.5)
                    .padding(.top, 4)

                if let r = reading {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(r.contributors) { c in
                                contribRow(c, width: geo.size.width - 16)
                            }

                            Divider()
                                .background(Color.white.opacity(0.15))
                                .padding(.vertical, 3)

                            HStack(spacing: 6) {
                                mathDoshaTag("V", value: r.vata, color: AuroTheme.vataColor)
                                mathDoshaTag("P", value: r.pitta, color: AuroTheme.pittaColor)
                                mathDoshaTag("K", value: r.kapha, color: AuroTheme.kaphaColor)
                            }
                            Text("\(r.contributors.count) signals · \(Int(r.confidence * 100))% complete")
                                .font(.system(size: 9))
                                .foregroundColor(AuroTheme.textLight.opacity(0.35))
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func contribRow(_ c: NadiContributor, width: CGFloat) -> some View {
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
            HStack(spacing: 2) {
                miniBar(value: c.weightedVata, max: c.weight, color: AuroTheme.vataColor)
                miniBar(value: c.weightedPitta, max: c.weight, color: AuroTheme.pittaColor)
                miniBar(value: c.weightedKapha, max: c.weight, color: AuroTheme.kaphaColor)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func miniBar(value: Double, max maxWeight: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.7))
                    .frame(width: geo.size.width * (maxWeight > 0 ? value / maxWeight : 0))
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private func mathDoshaTag(_ label: String, value: Double, color: Color) -> some View {
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
        .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)))
    }

    // MARK: - Components

    private func doshaBar(_ label: String, value: Double, color: Color, width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 16)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.18))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.7))
                    .frame(width: max(0, (width - 60) * value), height: 10)
            }

            Text("\(Int(value * 100))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.85))
                .frame(width: 30, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func rawStat(label: String, value: String, tint: Color? = nil) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(tint ?? AuroTheme.textLight)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(AuroTheme.goldAccent)
            Text("Reading pulse...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textSecondary))
        }
    }

    private var authPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 32))
                .foregroundColor(AuroTheme.primaryColor)
            Text("Health Access\nNeeded")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AuroTheme.textLight)
                .multilineTextAlignment(.center)
        }
    }

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.system(size: 32))
                .foregroundColor(AuroTheme.primaryColor)
            Text("No Pulse Data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AuroTheme.textLight)
            Text("Wear your watch for a while")
                .font(.system(size: 11))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
        }
    }

    // MARK: - Helpers

    private func confidenceColor(_ c: Double) -> Color {
        if c >= 0.8 { return AuroTheme.kaphaColor }
        if c >= 0.5 { return AuroTheme.goldAccent }
        return AuroTheme.pittaColor
    }

    private func refreshNadi() {
        guard !isLoading else { return }
        if reading != nil { return }

        isLoading = true
        health.fetchLatestReadings()

        health.fetchHRVHistory(days: 14) { samples in
            DispatchQueue.main.async {
                self.baseline = NadiEngine.computeBaseline(hrvHistory: samples, restingHRHistory: nil)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

            let result = NadiEngine.analyze(signals: signals, baseline: baseline)
            reading = result
            isLoading = false

            if let r = result {
                cache.updateNadi(
                    dominantDosha: r.dominant,
                    hrv: r.hrv,
                    restingHR: r.restingHR
                )

                let now = Date()
                let shouldSync = Self.lastPhoneSyncAt == nil ||
                    now.timeIntervalSince(Self.lastPhoneSyncAt!) >= Self.minSyncInterval

                if shouldSync {
                    Self.lastPhoneSyncAt = now
                    syncManager.sendToPhone([
                        "type": "nadiReading",
                        "dominant": r.dominant,
                        "gati": r.gati,
                        "vata": r.vata,
                        "pitta": r.pitta,
                        "kapha": r.kapha,
                        "hrv": r.hrv,
                        "restingHR": r.restingHR as Any,
                        "baselineHRV": r.baselineHRV,
                        "confidence": r.confidence,
                        "signalCount": r.contributors.count,
                        "timestamp": r.timestamp.timeIntervalSince1970,
                        "baselineReliable": baseline?.isReliable ?? false,
                        "baselineSamples": baseline?.sampleCount ?? 0,
                    ])
                }
            }
        }
    }
}

#Preview {
    NadiMonitorView()
        .environmentObject(HealthKitManager())
        .environmentObject(LocalCache())
        .environmentObject(WatchSyncManager())
}
