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

        // — Heart —
        rows.append(SensorRow(id: "hr", name: "Heart Rate",
            value: cache.currentHeartRate.map { String(format: "%.0f", $0) },
            unit: "bpm", timestamp: cache.heartRateTimestamp))

        rows.append(SensorRow(id: "rhr", name: "Resting HR",
            value: cache.latestRestingHR.map { String(format: "%.0f", $0) },
            unit: "bpm", timestamp: cache.hrvTimestamp))

        rows.append(SensorRow(id: "walkhr", name: "Walking HR",
            value: cache.walkingHR.map { String(format: "%.0f", $0) },
            unit: "bpm", timestamp: cache.walkingHRTimestamp))

        rows.append(SensorRow(id: "hrv", name: "HRV (SDNN)",
            value: cache.latestHRV.map { String(format: "%.1f", $0) },
            unit: "ms", timestamp: cache.hrvTimestamp))

        rows.append(SensorRow(id: "rmssd", name: "RMSSD",
            value: cache.latestRMSSD.map { String(format: "%.1f", $0) },
            unit: "ms", timestamp: cache.rmssdTimestamp))

        rows.append(SensorRow(id: "pnn50", name: "pNN50",
            value: cache.latestPNN50.map { String(format: "%.1f", $0 * 100) },
            unit: "%", timestamp: cache.pnn50Timestamp))

        rows.append(SensorRow(id: "rrcount", name: "RR Pairs",
            value: cache.latestRRSampleCount.map { "\($0)" },
            unit: "today", timestamp: cache.rmssdTimestamp))

        rows.append(SensorRow(id: "recovery", name: "HR Recovery",
            value: cache.hrRecovery.map { String(format: "%.0f", $0) },
            unit: "bpm↓", timestamp: cache.hrRecoveryTimestamp))

        // — Breath / Oxygen —
        rows.append(SensorRow(id: "spo2", name: "Blood O₂",
            value: cache.spO2.map { spo2 in
                let pct = spo2 > 1 ? spo2 : spo2 * 100
                return String(format: "%.1f", pct)
            },
            unit: "%", timestamp: cache.spO2Timestamp))

        rows.append(SensorRow(id: "resp", name: "Resp Rate",
            value: cache.respiratoryRate.map { String(format: "%.1f", $0) },
            unit: "/min", timestamp: cache.respiratoryRateTimestamp))

        // — Sleep —
        rows.append(SensorRow(id: "sleep", name: "Sleep",
            value: cache.sleepHours.map { String(format: "%.1f", $0) },
            unit: "hrs", timestamp: cache.sleepTimestamp))

        rows.append(SensorRow(id: "deep", name: "Deep Sleep",
            value: cache.deepSleepMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.sleepTimestamp))

        rows.append(SensorRow(id: "rem", name: "REM Sleep",
            value: cache.remSleepMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.sleepTimestamp))

        rows.append(SensorRow(id: "core", name: "Core Sleep",
            value: cache.coreSleepMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.sleepTimestamp))

        rows.append(SensorRow(id: "onset", name: "Sleep Onset",
            value: cache.sleepOnsetHour.map { hr in
                let h = Int(hr) % 24
                let m = Int((hr - floor(hr)) * 60)
                let suffix = h >= 12 ? "PM" : "AM"
                let h12 = h % 12 == 0 ? 12 : h % 12
                return String(format: "%d:%02d %@", h12, m, suffix)
            },
            unit: "", timestamp: cache.sleepTimestamp))

        // — Body —
        rows.append(SensorRow(id: "temp", name: "Wrist Temp",
            value: cache.wristTempDeviation.map { temp in
                let sign = temp >= 0 ? "+" : ""
                return "\(sign)\(String(format: "%.2f", temp))"
            },
            unit: "°C", timestamp: cache.wristTempTimestamp))

        // — Movement / Activity —
        rows.append(SensorRow(id: "steps", name: "Steps",
            value: cache.todaySteps.map { "\($0)" },
            unit: "today", timestamp: cache.stepsTimestamp))

        rows.append(SensorRow(id: "energy", name: "Active Cal",
            value: cache.activeEnergy.map { String(format: "%.0f", $0) },
            unit: "kcal", timestamp: cache.activeEnergyTimestamp))

        rows.append(SensorRow(id: "exercise", name: "Exercise",
            value: cache.exerciseMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.exerciseMinutesTimestamp))

        rows.append(SensorRow(id: "stand", name: "Stand Hrs",
            value: cache.standHours.map { "\($0)" },
            unit: "hrs", timestamp: cache.standHoursTimestamp))

        rows.append(SensorRow(id: "vo2", name: "VO₂ Max",
            value: cache.vo2Max.map { String(format: "%.1f", $0) },
            unit: "mL/kg", timestamp: cache.vo2MaxTimestamp))

        rows.append(SensorRow(id: "steady", name: "Walk Steady",
            value: cache.walkingSteadiness.map { String(format: "%.0f", $0 * 100) },
            unit: "%", timestamp: cache.walkingSteadinessTimestamp))

        // — Environment / Mind —
        rows.append(SensorRow(id: "daylight", name: "Daylight",
            value: cache.daylightMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.daylightTimestamp))

        rows.append(SensorRow(id: "envaudio", name: "Env Audio",
            value: cache.envAudioExposure.map { String(format: "%.0f", $0) },
            unit: "dB", timestamp: cache.envAudioTimestamp))

        rows.append(SensorRow(id: "headaudio", name: "Headphone",
            value: cache.headphoneAudioExposure.map { String(format: "%.0f", $0) },
            unit: "dB", timestamp: cache.headphoneAudioTimestamp))

        rows.append(SensorRow(id: "envaudioevt", name: "Env Loud Evt",
            value: cache.todayEnvAudioEventCount.map { "\($0)" },
            unit: "today", timestamp: cache.envAudioEventTimestamp))

        rows.append(SensorRow(id: "headaudioevt", name: "Hp Loud Evt",
            value: cache.todayHeadphoneAudioEventCount.map { "\($0)" },
            unit: "today", timestamp: cache.headphoneAudioEventTimestamp))

        rows.append(SensorRow(id: "uv", name: "UV Index",
            value: cache.latestUVExposure.map { String(format: "%.1f", $0) },
            unit: "MED", timestamp: cache.uvExposureTimestamp))

        rows.append(SensorRow(id: "mindful", name: "Mindful",
            value: cache.mindfulMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.mindfulTimestamp))

        // — Cardiac Events —
        rows.append(SensorRow(id: "afib", name: "AFib Burden",
            value: cache.afibBurden.map { String(format: "%.1f", ($0 > 1 ? $0 : $0 * 100)) },
            unit: "%", timestamp: cache.afibTimestamp))

        rows.append(SensorRow(id: "highhr", name: "High HR",
            value: cache.todayHighHRCount.map { "\($0)" },
            unit: "events", timestamp: cache.highHREventTimestamp))

        rows.append(SensorRow(id: "lowhr", name: "Low HR",
            value: cache.todayLowHRCount.map { "\($0)" },
            unit: "events", timestamp: cache.lowHREventTimestamp))

        rows.append(SensorRow(id: "irreg", name: "Irreg Rhythm",
            value: cache.todayIrregularRhythmCount.map { "\($0)" },
            unit: "events", timestamp: cache.irregularRhythmTimestamp))

        rows.append(SensorRow(id: "ecg", name: "ECG Today",
            value: cache.todayECGCount.map { "\($0)" },
            unit: "scans", timestamp: cache.ecgTimestamp))

        rows.append(SensorRow(id: "apnea", name: "Sleep Apnea",
            value: cache.todaySleepApneaCount.map { "\($0)" },
            unit: "events", timestamp: cache.sleepApneaTimestamp))

        rows.append(SensorRow(id: "falls", name: "Falls",
            value: cache.todayFallCount.map { "\($0)" },
            unit: "today", timestamp: cache.fallTimestamp))

        rows.append(SensorRow(id: "lowfit", name: "Low Cardio Fit",
            value: cache.todayLowCardioFitnessCount.map { "\($0)" },
            unit: "alerts", timestamp: cache.lowCardioFitnessTimestamp))

        // — Activity (more) —
        rows.append(SensorRow(id: "basal", name: "Basal Cal",
            value: cache.basalEnergy.map { String(format: "%.0f", $0) },
            unit: "kcal", timestamp: cache.basalEnergyTimestamp))

        rows.append(SensorRow(id: "dist", name: "Distance",
            value: cache.todayDistanceMeters.map { String(format: "%.2f", $0 / 1000.0) },
            unit: "km", timestamp: cache.distanceTimestamp))

        rows.append(SensorRow(id: "flights", name: "Flights",
            value: cache.todayFlightsClimbed.map { String(format: "%.0f", $0) },
            unit: "today", timestamp: cache.flightsTimestamp))

        rows.append(SensorRow(id: "standmin", name: "Stand Min",
            value: cache.todayStandMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.standMinutesTimestamp))

        rows.append(SensorRow(id: "workouts", name: "Workouts",
            value: cache.todayWorkoutCount.map { "\($0)" },
            unit: "today", timestamp: cache.workoutTimestamp))

        rows.append(SensorRow(id: "workoutMins", name: "Workout Min",
            value: cache.todayWorkoutMinutes.map { String(format: "%.0f", $0) },
            unit: "min", timestamp: cache.workoutTimestamp))

        // — Latest Workout Detail —
        rows.append(SensorRow(id: "lastWoType", name: "Last Workout",
            value: cache.latestWorkoutType,
            unit: "", timestamp: cache.latestWorkoutTimestamp))

        rows.append(SensorRow(id: "lastWoDur", name: "Last Wo Dur",
            value: cache.latestWorkoutDuration.map { String(format: "%.0f", $0 / 60.0) },
            unit: "min", timestamp: cache.latestWorkoutTimestamp))

        rows.append(SensorRow(id: "lastWoKcal", name: "Last Wo Kcal",
            value: cache.latestWorkoutEnergyKcal.map { String(format: "%.0f", $0) },
            unit: "kcal", timestamp: cache.latestWorkoutTimestamp))

        rows.append(SensorRow(id: "lastWoAvgHR", name: "Last Wo Avg HR",
            value: cache.latestWorkoutAvgHR.map { String(format: "%.0f", $0) },
            unit: "bpm", timestamp: cache.latestWorkoutTimestamp))

        rows.append(SensorRow(id: "lastWoMaxHR", name: "Last Wo Max HR",
            value: cache.latestWorkoutMaxHR.map { String(format: "%.0f", $0) },
            unit: "bpm", timestamp: cache.latestWorkoutTimestamp))

        // — Gait / Mobility —
        rows.append(SensorRow(id: "walkspd", name: "Walk Speed",
            value: cache.walkingSpeed.map { String(format: "%.2f", $0) },
            unit: "m/s", timestamp: cache.walkingSpeedTimestamp))

        rows.append(SensorRow(id: "steplen", name: "Step Length",
            value: cache.walkingStepLength.map { String(format: "%.0f", $0) },
            unit: "cm", timestamp: cache.walkingStepLengthTimestamp))

        rows.append(SensorRow(id: "dblsup", name: "Dbl Support",
            value: cache.walkingDoubleSupport.map { String(format: "%.1f", ($0 > 1 ? $0 : $0 * 100)) },
            unit: "%", timestamp: cache.walkingDoubleSupportTimestamp))

        rows.append(SensorRow(id: "asym", name: "Asymmetry",
            value: cache.walkingAsymmetry.map { String(format: "%.1f", ($0 > 1 ? $0 : $0 * 100)) },
            unit: "%", timestamp: cache.walkingAsymmetryTimestamp))

        rows.append(SensorRow(id: "stairup", name: "Stair Up",
            value: cache.stairAscentSpeed.map { String(format: "%.2f", $0) },
            unit: "m/s", timestamp: cache.stairAscentTimestamp))

        rows.append(SensorRow(id: "stairdn", name: "Stair Down",
            value: cache.stairDescentSpeed.map { String(format: "%.2f", $0) },
            unit: "m/s", timestamp: cache.stairDescentTimestamp))

        rows.append(SensorRow(id: "6mwt", name: "6-Min Walk",
            value: cache.sixMinuteWalk.map { String(format: "%.0f", $0) },
            unit: "m", timestamp: cache.sixMinuteWalkTimestamp))

        // — Running —
        rows.append(SensorRow(id: "runspd", name: "Run Speed",
            value: cache.runningSpeed.map { String(format: "%.2f", $0) },
            unit: "m/s", timestamp: cache.runningSpeedTimestamp))

        rows.append(SensorRow(id: "runpwr", name: "Run Power",
            value: cache.runningPower.map { String(format: "%.0f", $0) },
            unit: "W", timestamp: cache.runningPowerTimestamp))

        rows.append(SensorRow(id: "runstride", name: "Run Stride",
            value: cache.runningStrideLength.map { String(format: "%.2f", $0) },
            unit: "m", timestamp: cache.runningStrideTimestamp))

        rows.append(SensorRow(id: "rungc", name: "Ground Contact",
            value: cache.runningGroundContact.map { String(format: "%.0f", $0) },
            unit: "ms", timestamp: cache.runningGroundContactTimestamp))

        rows.append(SensorRow(id: "runvo", name: "Vert Oscill",
            value: cache.runningVerticalOsc.map { String(format: "%.1f", $0) },
            unit: "cm", timestamp: cache.runningVerticalOscTimestamp))

        // — Body Composition —
        rows.append(SensorRow(id: "weight", name: "Weight",
            value: cache.bodyMass.map { String(format: "%.1f", $0) },
            unit: "kg", timestamp: cache.bodyMassTimestamp))

        rows.append(SensorRow(id: "bmi", name: "BMI",
            value: cache.bodyMassIndex.map { String(format: "%.1f", $0) },
            unit: "", timestamp: cache.bmiTimestamp))

        rows.append(SensorRow(id: "bodyfat", name: "Body Fat",
            value: cache.bodyFatPercentage.map { String(format: "%.1f", ($0 > 1 ? $0 : $0 * 100)) },
            unit: "%", timestamp: cache.bodyFatTimestamp))

        rows.append(SensorRow(id: "lean", name: "Lean Mass",
            value: cache.leanBodyMass.map { String(format: "%.1f", $0) },
            unit: "kg", timestamp: cache.leanMassTimestamp))

        rows.append(SensorRow(id: "height", name: "Height",
            value: cache.height.map { String(format: "%.0f", $0 * 100) },
            unit: "cm", timestamp: cache.heightTimestamp))

        // — Body Temperature —
        rows.append(SensorRow(id: "bodytemp", name: "Body Temp",
            value: cache.bodyTemperature.map { String(format: "%.1f", $0) },
            unit: "°C", timestamp: cache.bodyTempTimestamp))

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
