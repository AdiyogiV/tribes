import SwiftUI
import Charts

/// Dhatu — your body's signals, split into pages of ~4 signals each.
/// No scrolling — each page fits the screen. Tap any row to drill in.
struct DhatuView: View {
    @EnvironmentObject private var cache: LocalCache
    @EnvironmentObject private var health: HealthKitManager
    @State private var selectedSignal: DhatuSignal?
    @State private var page = 0

    private let signalsPerPage = 4

    var body: some View {
        NavigationStack {
            let signals = buildSignals()
            let pages = signals.chunked(into: signalsPerPage)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, group in
                    signalPage(group, pageIndex: idx, totalPages: pages.count)
                        .tag(idx)
                }

                // Last page: Dosha balance
                if cache.prakritiVata > 0 || cache.prakritiPitta > 0 || cache.prakritiKapha > 0 {
                    doshaPage
                        .tag(pages.count)
                }
            }
            .tabViewStyle(.verticalPage)
            .ignoresSafeArea(.all)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedSignal) { signal in
                DhatuDetailView(signal: signal, cache: cache)
            }
        }
    }

    // MARK: - Signal Page

    @ViewBuilder
    private func signalPage(_ signals: [DhatuSignal], pageIndex: Int, totalPages: Int) -> some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let rowH: CGFloat = min(40, (h - 44) / CGFloat(max(signals.count, 1)))

            VStack(spacing: 0) {
                // Header (only on first page)
                if pageIndex == 0 {
                    HStack {
                        Text("Body")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                            .textCase(.uppercase)
                            .tracking(1.5)
                        Spacer()
                        if let ts = cache.lastHealthFetch {
                            Text(AuroTheme.timeAgo(ts, style: .short))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(freshnessColor(ts))
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .padding(.horizontal, 8)
                }

                Spacer(minLength: 0)

                // Signal rows
                VStack(spacing: 2) {
                    ForEach(signals, id: \.id) { signal in
                        Button { selectedSignal = signal } label: {
                            signalRow(signal, rowHeight: rowH)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)

                Spacer(minLength: 0)
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - Signal Row

    @ViewBuilder
    private func signalRow(_ signal: DhatuSignal, rowHeight: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: signal.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(signal.color)
                .frame(width: 24)

            Text(signal.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AuroTheme.textLight)
                .lineLimit(1)

            Spacer()

            Text(signal.displayValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(signal.color)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(0.15))
        }
        .frame(height: rowHeight)
        .padding(.horizontal, 4)
    }

    // MARK: - Dosha Balance Page

    private var doshaPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 10) {
                Spacer()

                Text("Prakriti")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                    .textCase(.uppercase)
                    .tracking(1.0)

                // Stacked dosha bar
                let total = Double(cache.prakritiVata + cache.prakritiPitta + cache.prakritiKapha)

                HStack(spacing: 1) {
                    let vF = total > 0 ? Double(cache.prakritiVata) / total : 0
                    let pF = total > 0 ? Double(cache.prakritiPitta) / total : 0
                    let kF = total > 0 ? Double(cache.prakritiKapha) / total : 1

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AuroTheme.vataColor)
                        .frame(width: (w - 40) * vF, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AuroTheme.pittaColor)
                        .frame(width: (w - 40) * pF, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AuroTheme.kaphaColor)
                        .frame(width: (w - 40) * kF, height: 10)
                }
                .padding(.horizontal, 20)

                // Labels
                HStack {
                    Label("V \(cache.prakritiVata)", systemImage: "")
                        .foregroundColor(AuroTheme.vataColor)
                    Spacer()
                    Label("P \(cache.prakritiPitta)", systemImage: "")
                        .foregroundColor(AuroTheme.pittaColor)
                    Spacer()
                    Label("K \(cache.prakritiKapha)", systemImage: "")
                        .foregroundColor(AuroTheme.kaphaColor)
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - Build Signals

    private func buildSignals() -> [DhatuSignal] {
        var signals: [DhatuSignal] = []

        if let hr = cache.currentHeartRate {
            signals.append(DhatuSignal(
                id: "heartrate", name: "Heart", icon: "heart.fill",
                displayValue: "\(Int(hr)) bpm",
                color: hr >= 50 && hr <= 100 ? AuroTheme.pittaColor : Color(red: 0.85, green: 0.45, blue: 0.45),
                detail: "Current heart rate. Pulse speed indicates dosha activity.",
                ayurvedaName: "Hridaya Gati",
                dataSource: "Apple Watch optical sensor",
                timestamp: cache.heartRateTimestamp
            ))
        }

        let sleepVal: String
        let sleepColor: Color
        if let hrs = cache.sleepHours {
            sleepVal = String(format: "%.1fh", hrs)
            sleepColor = hrs >= 6.5 && hrs <= 9.0 ? AuroTheme.kaphaColor : AuroTheme.pittaColor
        } else {
            sleepVal = "—"
            sleepColor = AuroTheme.textLight.opacity(0.3)
        }
        signals.append(DhatuSignal(
            id: "sleep", name: "Sleep", icon: "moon.fill",
            displayValue: sleepVal, color: sleepColor,
            detail: sleepDetail(),
            ayurvedaName: "Nidra",
            dataSource: "Apple Watch accelerometer + heart rate",
            timestamp: cache.sleepTimestamp,
            historyKey: "sleep"
        ))

        let pulseVal = cache.latestHRV.map { String(format: "%.0f ms", $0) } ?? "—"
        let pulseColor = cache.latestHRV != nil ? AuroTheme.vataColor : AuroTheme.textLight.opacity(0.3)
        signals.append(DhatuSignal(
            id: "pulse", name: "HRV", icon: "waveform.path.ecg",
            displayValue: pulseVal, color: pulseColor,
            detail: "Heart Rate Variability — variation between heartbeats. Higher HRV means better recovery.",
            ayurvedaName: "Nadi Spandana",
            dataSource: "Apple Watch optical heart sensor",
            timestamp: cache.hrvTimestamp,
            historyKey: "hrv"
        ))

        if let spo2 = cache.spO2 {
            let pct = spo2 > 1 ? spo2 : spo2 * 100
            let spo2Color = pct >= 95 ? AuroTheme.kaphaColor :
                           (pct >= 90 ? AuroTheme.pittaColor : Color(red: 0.85, green: 0.45, blue: 0.45))
            signals.append(DhatuSignal(
                id: "oxygen", name: "Oxygen", icon: "lungs.fill",
                displayValue: String(format: "%.0f%%", pct),
                color: spo2Color,
                detail: "Blood oxygen saturation. Normal is 95-100%. Low SpO2 may indicate poor Prana flow.",
                ayurvedaName: "Prana Vayu",
                dataSource: "Apple Watch blood oxygen sensor",
                timestamp: cache.spO2Timestamp,
                historyKey: "spo2"
            ))
        }

        let tempVal: String
        let tempColor: Color
        if let temp = cache.wristTempDeviation {
            let sign = temp >= 0 ? "+" : ""
            tempVal = "\(sign)\(String(format: "%.1f", temp))°"
            tempColor = abs(temp) < 0.3 ? AuroTheme.kaphaColor :
                        (temp > 0 ? AuroTheme.pittaColor : AuroTheme.vataColor)
        } else {
            tempVal = "—"
            tempColor = AuroTheme.textLight.opacity(0.3)
        }
        signals.append(DhatuSignal(
            id: "warmth", name: "Warmth", icon: "thermometer.medium",
            displayValue: tempVal, color: tempColor,
            detail: "Wrist temperature deviation from baseline, measured during sleep.",
            ayurvedaName: "Sparsha / Ushna",
            dataSource: "Apple Watch wrist temperature sensor",
            timestamp: cache.wristTempTimestamp
        ))

        let breathVal = cache.respiratoryRate.map { String(format: "%.0f /m", $0) } ?? "—"
        let breathColor = cache.respiratoryRate != nil ? AuroTheme.vataColor : AuroTheme.textLight.opacity(0.3)
        signals.append(DhatuSignal(
            id: "breath", name: "Breath", icon: "wind",
            displayValue: breathVal, color: breathColor,
            detail: "Overnight breathing rate. Normal: 12-20 breaths/min.",
            ayurvedaName: "Prana Gati",
            dataSource: "Apple Watch accelerometer",
            timestamp: cache.respiratoryRateTimestamp,
            historyKey: "resp"
        ))

        let stepsVal = cache.todaySteps.map { formatSteps($0) } ?? "—"
        let stepsColor: Color
        if let s = cache.todaySteps {
            stepsColor = s >= 5000 ? AuroTheme.kaphaColor : AuroTheme.pittaColor
        } else {
            stepsColor = AuroTheme.textLight.opacity(0.3)
        }
        signals.append(DhatuSignal(
            id: "movement", name: "Steps", icon: "figure.walk",
            displayValue: stepsVal, color: stepsColor,
            detail: "Daily movement. Moderate activity supports all doshas.",
            ayurvedaName: "Vyayama",
            dataSource: "Apple Watch accelerometer + GPS",
            timestamp: cache.stepsTimestamp,
            historyKey: "steps"
        ))

        if let energy = cache.activeEnergy {
            signals.append(DhatuSignal(
                id: "energy", name: "Burn", icon: "flame.fill",
                displayValue: "\(Int(energy)) kcal",
                color: energy >= 200 ? AuroTheme.pittaColor : AuroTheme.textLight.opacity(0.5),
                detail: "Active calories burned. Reflects metabolic fire (Agni).",
                ayurvedaName: "Agni",
                dataSource: "Apple Watch heart rate + motion",
                timestamp: cache.activeEnergyTimestamp
            ))
        }

        if let vo2 = cache.vo2Max {
            signals.append(DhatuSignal(
                id: "fitness", name: "Fitness", icon: "figure.run",
                displayValue: String(format: "%.0f", vo2),
                color: vo2 >= 30 ? AuroTheme.kaphaColor : AuroTheme.pittaColor,
                detail: "VO2 Max — max oxygen during exercise. Reflects Ojas and Bala.",
                ayurvedaName: "Bala / Ojas",
                dataSource: "Apple Watch outdoor walk/run estimate",
                timestamp: cache.vo2MaxTimestamp
            ))
        }

        if let mindful = cache.mindfulMinutes, mindful > 0 {
            signals.append(DhatuSignal(
                id: "mindful", name: "Mindful", icon: "brain.head.profile",
                displayValue: "\(Int(mindful)) min",
                color: mindful >= 10 ? AuroTheme.kaphaColor : AuroTheme.goldAccent,
                detail: "Meditation minutes. Builds Sattva (mental clarity).",
                ayurvedaName: "Dhyana / Sattva",
                dataSource: "Apple Mindfulness app",
                timestamp: cache.mindfulTimestamp
            ))
        }

        if let rhr = cache.latestRestingHR {
            signals.append(DhatuSignal(
                id: "restinghr", name: "Rest HR", icon: "heart.text.square",
                displayValue: "\(Int(rhr)) bpm",
                color: rhr >= 50 && rhr <= 80 ? AuroTheme.kaphaColor : AuroTheme.pittaColor,
                detail: "Resting heart rate when calm. Lower is generally better.",
                ayurvedaName: "Vishranti Nadi",
                dataSource: "Apple Watch optical heart sensor",
                timestamp: cache.hrvTimestamp,
                historyKey: "rhr"
            ))
        }

        return signals
    }

    private func sleepDetail() -> String {
        var parts: [String] = []
        if let deep = cache.deepSleepMinutes {
            parts.append("Deep: \(Int(deep))m")
        }
        if let rem = cache.remSleepMinutes {
            parts.append("REM: \(Int(rem))m")
        }
        if !parts.isEmpty { parts.append("") }
        parts.append("Good sleep builds Ojas. Short sleep aggravates Pitta and Vata.")
        return parts.joined(separator: ". ")
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }

    private func freshnessColor(_ date: Date) -> Color {
        let hrs = -date.timeIntervalSinceNow / 3600
        if hrs < 1 { return AuroTheme.kaphaColor.opacity(0.6) }
        if hrs < 6 { return AuroTheme.textLight.opacity(0.35) }
        return AuroTheme.pittaColor.opacity(0.5)
    }
}

// MARK: - Array Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Data Model

struct DhatuSignal: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let displayValue: String
    let color: Color
    let detail: String
    var ayurvedaName: String = ""
    var dataSource: String = ""
    var timestamp: Date? = nil
    var historyKey: String? = nil
}

// MARK: - Dhatu Detail (paged drill-down)

struct DhatuDetailView: View {
    let signal: DhatuSignal
    let cache: LocalCache
    @Environment(\.dismiss) private var dismiss
    @State private var detailPage = 0

    var body: some View {
        TabView(selection: $detailPage) {
            // Page 0: Value + chart
            valuePage
                .tag(0)

            // Page 1: Ayurveda context
            contextPage
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Value Page

    private var valuePage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 6) {
                // Back header
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Body")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(signal.color.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                Spacer(minLength: 0)

                // Icon + Value
                Image(systemName: signal.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(signal.color)

                Text(signal.displayValue)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(signal.color)

                Text(signal.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.7))

                // Inline chart
                historyChart(width: w)

                if let ts = signal.timestamp {
                    Text(AuroTheme.timeAgo(ts))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AuroTheme.textLight.opacity(0.25))
                }

                Spacer(minLength: 0)
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - Context Page

    private var contextPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                if !signal.ayurvedaName.isEmpty {
                    Text(signal.ayurvedaName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AuroTheme.goldAccent)
                }

                Text(signal.detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textSecondary))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                if !signal.dataSource.isEmpty {
                    VStack(spacing: 2) {
                        Text("SOURCE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(AuroTheme.textLight.opacity(0.2))
                            .tracking(1.0)
                        Text(signal.dataSource)
                            .font(.system(size: 9))
                            .foregroundColor(AuroTheme.textLight.opacity(0.25))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(width: w, height: h)
        }
    }

    // MARK: - History Chart

    @ViewBuilder
    private func historyChart(width: CGFloat) -> some View {
        let data = historyData()
        if data.count >= 2 {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { idx, val in
                    LineMark(
                        x: .value("Day", idx),
                        y: .value("Val", val)
                    )
                    .foregroundStyle(signal.color.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                    AreaMark(
                        x: .value("Day", idx),
                        y: .value("Val", val)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [signal.color.opacity(0.2), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }

                if let last = data.last {
                    PointMark(
                        x: .value("Day", data.count - 1),
                        y: .value("Val", last)
                    )
                    .foregroundStyle(signal.color)
                    .symbolSize(24)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: width - 40, height: 36)
        }
    }

    private func historyData() -> [Double] {
        switch signal.historyKey {
        case "sleep": return cache.sleepHistory
        case "hrv":   return cache.hrvHistory
        case "rhr":   return cache.restingHRHistory
        case "resp":  return cache.respRateHistory
        case "spo2":  return cache.spO2History
        case "steps": return cache.stepsHistory.map { Double($0) }
        default:      return []
        }
    }
}

#Preview {
    DhatuView()
        .environmentObject(LocalCache())
        .environmentObject(HealthKitManager())
}
