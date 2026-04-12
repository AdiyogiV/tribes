import SwiftUI

/// Sensors — raw data from every Apple Watch sensor, split into pages.
/// No Ayurvedic interpretation — just the truth.
struct SensorsView: View {
    @EnvironmentObject private var cache: LocalCache
    @EnvironmentObject private var health: HealthKitManager
    @State private var isRefreshing = false
    @State private var page = 0

    private let rowsPerPage = 5

    var body: some View {
        let rows = buildSensorRows()
        let pages = rows.chunked(into: rowsPerPage)

        TabView(selection: $page) {
            ForEach(Array(pages.enumerated()), id: \.offset) { idx, group in
                sensorPage(group, pageIndex: idx, totalPages: pages.count, allRows: rows)
                    .tag(idx)
            }
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Sensor Page

    @ViewBuilder
    private func sensorPage(_ rows: [SensorRow], pageIndex: Int, totalPages: Int, allRows: [SensorRow]) -> some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let rowH: CGFloat = min(32, (h - 40) / CGFloat(max(rows.count, 1)))

            VStack(spacing: 0) {
                // Header on first page
                if pageIndex == 0 {
                    HStack {
                        Text("Sensors")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                            .textCase(.uppercase)
                            .tracking(1.5)
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .tint(AuroTheme.goldAccent.opacity(0.5))
                        } else {
                            Button { refresh() } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AuroTheme.goldAccent.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                    .padding(.horizontal, 6)
                }

                // Last page: signal count footer
                if pageIndex == totalPages - 1 {
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    ForEach(rows, id: \.id) { row in
                        sensorRow(row, rowHeight: rowH)
                    }
                }
                .padding(.horizontal, 6)

                if pageIndex == totalPages - 1 {
                    let available = allRows.filter { $0.hasValue }.count
                    Text("\(available)/\(allRows.count) signals")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AuroTheme.textLight.opacity(0.25))
                        .padding(.top, 4)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - Sensor Row

    @ViewBuilder
    private func sensorRow(_ row: SensorRow, rowHeight: CGFloat) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(row.hasValue ? AuroTheme.kaphaColor : Color.white.opacity(0.12))
                .frame(width: 5, height: 5)

            Text(row.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(row.hasValue ? 0.9 : 0.35))
                .lineLimit(1)

            Spacer()

            if let value = row.value {
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AuroTheme.textLight.opacity(0.85))
                Text(row.unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AuroTheme.textLight.opacity(0.3))
            } else {
                Text("—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AuroTheme.textLight.opacity(0.15))
            }
        }
        .frame(height: rowHeight)
        .padding(.horizontal, 2)
    }

    // MARK: - Build Rows

    private func buildSensorRows() -> [SensorRow] {
        var rows: [SensorRow] = []

        rows.append(SensorRow(id: "hr", name: "Heart Rate",
            value: cache.currentHeartRate.map { String(format: "%.0f", $0) },
            unit: "bpm", timestamp: cache.heartRateTimestamp))

        rows.append(SensorRow(id: "rhr", name: "Resting HR",
            value: cache.latestRestingHR.map { String(format: "%.0f", $0) },
            unit: "bpm", timestamp: cache.hrvTimestamp))

        rows.append(SensorRow(id: "hrv", name: "HRV (SDNN)",
            value: cache.latestHRV.map { String(format: "%.1f", $0) },
            unit: "ms", timestamp: cache.hrvTimestamp))

        rows.append(SensorRow(id: "spo2", name: "Blood O₂",
            value: cache.spO2.map { spo2 in
                let pct = spo2 > 1 ? spo2 : spo2 * 100
                return String(format: "%.1f", pct)
            },
            unit: "%", timestamp: cache.spO2Timestamp))

        rows.append(SensorRow(id: "sleep", name: "Sleep",
            value: cache.sleepHours.map { String(format: "%.1f", $0) },
            unit: "hrs", timestamp: cache.sleepTimestamp))

        rows.append(SensorRow(id: "deep", name: "Deep Sleep",
            value: cache.deepSleepMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.sleepTimestamp))

        rows.append(SensorRow(id: "rem", name: "REM Sleep",
            value: cache.remSleepMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.sleepTimestamp))

        rows.append(SensorRow(id: "temp", name: "Wrist Temp",
            value: cache.wristTempDeviation.map { temp in
                let sign = temp >= 0 ? "+" : ""
                return "\(sign)\(String(format: "%.2f", temp))"
            },
            unit: "°C", timestamp: cache.wristTempTimestamp))

        rows.append(SensorRow(id: "resp", name: "Resp Rate",
            value: cache.respiratoryRate.map { String(format: "%.1f", $0) },
            unit: "/min", timestamp: cache.respiratoryRateTimestamp))

        rows.append(SensorRow(id: "vo2", name: "VO₂ Max",
            value: cache.vo2Max.map { String(format: "%.1f", $0) },
            unit: "mL/kg", timestamp: cache.vo2MaxTimestamp))

        rows.append(SensorRow(id: "steps", name: "Steps",
            value: cache.todaySteps.map { "\($0)" },
            unit: "today", timestamp: cache.stepsTimestamp))

        rows.append(SensorRow(id: "energy", name: "Active Cal",
            value: cache.activeEnergy.map { String(format: "%.0f", $0) },
            unit: "kcal", timestamp: cache.activeEnergyTimestamp))

        rows.append(SensorRow(id: "recovery", name: "HR Recovery",
            value: cache.hrRecovery.map { String(format: "%.0f", $0) },
            unit: "bpm↓", timestamp: cache.hrRecoveryTimestamp))

        rows.append(SensorRow(id: "steady", name: "Walk Steady",
            value: cache.walkingSteadiness.map { String(format: "%.0f", $0 * 100) },
            unit: "%", timestamp: cache.walkingSteadinessTimestamp))

        rows.append(SensorRow(id: "mindful", name: "Mindful",
            value: cache.mindfulMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.mindfulTimestamp))

        return rows
    }

    // MARK: - Refresh

    private func refresh() {
        isRefreshing = true
        health.fetchAllReadings {
            DispatchQueue.main.async {
                cache.updateBodySignals(from: health)
                isRefreshing = false
            }
        }
    }
}

// MARK: - Data Model

struct SensorRow: Identifiable {
    let id: String
    let name: String
    let value: String?
    let unit: String
    var timestamp: Date?

    var hasValue: Bool { value != nil }
}

#Preview {
    SensorsView()
        .environmentObject(LocalCache())
        .environmentObject(HealthKitManager())
}
