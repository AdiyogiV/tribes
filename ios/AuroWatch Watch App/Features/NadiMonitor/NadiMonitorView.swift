import SwiftUI

/// Digital Nadi Monitor — full-screen page, no scroll.
/// Shows dosha state, proportion bars, raw signals, alignment.
struct NadiMonitorView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var cache: LocalCache
    @EnvironmentObject private var syncManager: WatchSyncManager
    @State private var reading: NadiReading?
    @State private var baseline: NadiBaseline?
    @State private var isLoading = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 6) {
                Spacer(minLength: 2)

                if let reading = reading {
                    nadiContent(reading, geo: geo)
                } else if isLoading {
                    loadingView
                } else if !health.isAuthorized {
                    authPrompt
                } else {
                    noDataView
                }

                Spacer(minLength: 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { refreshNadi() }
    }

    // MARK: - Nadi Content

    @ViewBuilder
    private func nadiContent(_ reading: NadiReading, geo: GeometryProxy) -> some View {
        // Gati + dosha
        Text("\(reading.gati) Gati")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(doshaColor(reading.dominant))

        Text("\(reading.dominant) Nadi")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(doshaColor(reading.dominant).opacity(0.8))

        // Dosha bars
        VStack(spacing: 4) {
            doshaBar("V", value: reading.vata, color: AuroTheme.vataColor, width: geo.size.width - 24)
            doshaBar("P", value: reading.pitta, color: AuroTheme.pittaColor, width: geo.size.width - 24)
            doshaBar("K", value: reading.kapha, color: AuroTheme.kaphaColor, width: geo.size.width - 24)
        }
        .padding(.vertical, 2)

        // Prahar context
        let hour = Calendar.current.component(.hour, from: .now)
        let expectedDosha = VedicTimeCalculator.currentDosha(forHour: hour)

        if reading.dominant == expectedDosha {
            Text("☀ In harmony")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
        } else {
            Text("\(reading.dominant) during \(expectedDosha) time")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
        }

        // Raw values
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(String(format: "%.0f", reading.hrv))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(AuroTheme.textLight)
                Text("HRV")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
            }
            if let rhr = reading.restingHR {
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", rhr))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(AuroTheme.textLight)
                    Text("RHR")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                }
            }
        }
    }

    // MARK: - Dosha Bar

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

    private func doshaColor(_ dosha: String) -> Color {
        switch dosha.lowercased() {
        case "vata":  return AuroTheme.vataColor
        case "pitta": return AuroTheme.pittaColor
        case "kapha": return AuroTheme.kaphaColor
        default:      return AuroTheme.primaryColor
        }
    }

    private func refreshNadi() {
        isLoading = true
        health.fetchLatestReadings()

        health.fetchHRVHistory(days: 14) { samples in
            DispatchQueue.main.async {
                self.baseline = NadiEngine.computeBaseline(hrvHistory: samples, restingHRHistory: nil)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let result = NadiEngine.analyze(
                hrv: health.latestHRV,
                restingHR: health.latestRestingHR,
                baseline: baseline
            )
            reading = result
            isLoading = false

            if let r = result {
                cache.updateNadi(
                    dominantDosha: r.dominant,
                    hrv: r.hrv,
                    restingHR: r.restingHR
                )
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
                    "timestamp": r.timestamp.timeIntervalSince1970,
                    "baselineReliable": baseline?.isReliable ?? false,
                    "baselineSamples": baseline?.sampleCount ?? 0,
                ])
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
