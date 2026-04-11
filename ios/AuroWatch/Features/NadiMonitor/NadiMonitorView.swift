import SwiftUI

/// Digital Nadi Monitor screen.
///
/// Shows:
///   1. Current Nadi state (dominant dosha + Gati name)
///   2. Dosha proportion bars (V/P/K)
///   3. Raw signal values (HRV, RHR)
///   4. Prahar-aware context (which dosha SHOULD dominate now)
///   5. Alignment indicator (does current Nadi match Prakriti?)
///
/// Data: HRV + HR from HealthKitManager, analyzed by NadiEngine.
struct NadiMonitorView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var cache: LocalCache
    @State private var reading: NadiReading?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                Text("Nadi Monitor")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AuroTheme.primaryColor)

                if let reading = reading {
                    nadiContent(reading)
                } else if isLoading {
                    loadingView
                } else if !health.isAuthorized {
                    authPrompt
                } else {
                    noDataView
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .onAppear { refreshNadi() }
    }

    // MARK: - Nadi Content

    @ViewBuilder
    private func nadiContent(_ reading: NadiReading) -> some View {
        // Gati name + dosha
        VStack(spacing: 2) {
            Text("\(reading.gati) Gati")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(doshaColor(reading.dominant))

            Text("\(reading.dominant) Nadi")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(doshaColor(reading.dominant).opacity(0.7))
        }

        // Dosha bars
        VStack(spacing: 4) {
            doshaBar("V", value: reading.vata, color: AuroTheme.vataColor)
            doshaBar("P", value: reading.pitta, color: AuroTheme.pittaColor)
            doshaBar("K", value: reading.kapha, color: AuroTheme.kaphaColor)
        }
        .padding(.vertical, 4)

        // Prahar-aware context
        let hour = Calendar.current.component(.hour, from: .now)
        let expectedDosha = VedicTimeCalculator.currentDosha(forHour: hour)
        let vt = VedicTimeCalculator.calculate()

        VStack(spacing: 2) {
            Text("\(vt.praharName) · \(expectedDosha) Time")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.6))

            if reading.dominant == expectedDosha {
                Text("In harmony with the rhythm")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.green.opacity(0.7))
            } else {
                Text("\(reading.dominant) pulse during \(expectedDosha) time")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.orange.opacity(0.7))
            }
        }

        Divider().opacity(0.2)

        // Raw values
        HStack(spacing: 16) {
            VStack(spacing: 1) {
                Text(String(format: "%.0f", reading.hrv))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.7))
                Text("HRV ms")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
            }

            if let rhr = reading.restingHR {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", rhr))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(AuroTheme.primaryColor.opacity(0.7))
                    Text("RHR bpm")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
                }
            }
        }

        // Prakriti alignment
        if let prakriti = cache.prakritiType {
            let aligned = reading.isAligned(withPrakriti: prakriti.components(separatedBy: "-").first)
            HStack(spacing: 4) {
                Circle()
                    .fill(aligned ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(aligned ? "Aligned with \(prakriti)" : "Differs from \(prakriti) baseline")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.5))
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Dosha Bar

    private func doshaBar(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.6))
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 8)

            Text("\(Int(value * 100))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Reading pulse...")
                .font(.system(size: 11))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.5))
        }
        .padding(.top, 20)
    }

    private var authPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 28))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
            Text("Health access needed")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.6))
            Text("Open Settings → Health → Aurogram to enable heart data")
                .font(.system(size: 9))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.system(size: 28))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
            Text("No pulse data yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.6))
            Text("Wear your watch for a while.\nHRV is measured periodically.")
                .font(.system(size: 9))
                .foregroundColor(AuroTheme.primaryColor.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
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

        // Small delay to let HealthKit queries complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let result = NadiEngine.analyze(
                hrv: health.latestHRV,
                restingHR: health.latestRestingHR,
                baseline: nil  // TODO: compute from history once enough data
            )
            reading = result
            isLoading = false

            // Cache for sync to phone
            if let r = result {
                cache.updateNadi(
                    dominantDosha: r.dominant,
                    hrv: r.hrv,
                    restingHR: r.restingHR
                )
            }
        }
    }
}

#Preview {
    NadiMonitorView()
        .environmentObject(HealthKitManager())
        .environmentObject(LocalCache())
}
