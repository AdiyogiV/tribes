import Foundation
import Combine

/// Local data cache for the watch app.
///
/// Stores data received from the phone (panchang, insight, profile)
/// and data generated on-watch (Nadi readings, sleep analysis).
/// Uses UserDefaults for persistence across app launches.
///
/// Observable so SwiftUI views react to data changes.
class LocalCache: ObservableObject {

    private let defaults = UserDefaults.standard
    private static let prefix = "auro_"

    // MARK: - Panchang Data (synced from phone)

    /// Today's Vedic date — e.g., "Chaitra Krishna Shashthi"
    @Published var vedicDate: String?

    /// Samvat year — e.g., "Vikram Samvat Raudri"
    @Published var samvatYear: String?

    /// Numeric Vedic date — e.g., "6/2/1/2083"
    @Published var vedicNumericDate: String?

    // MARK: - Profile Data (synced from phone)

    /// User's Prakriti type — e.g., "Vata-Pitta"
    @Published var prakritiType: String?

    /// Prakriti percentages
    @Published var prakritiVata: Int = 0
    @Published var prakritiPitta: Int = 0
    @Published var prakritiKapha: Int = 0

    // MARK: - Daily Insight (synced from phone)

    /// Today's insight theme — e.g., "Inner Stillness"
    @Published var insightTheme: String?

    /// Today's insight message (main text)
    @Published var insightMessage: String?

    // MARK: - Muhurat Data (synced from phone)

    /// Today's muhurat windows: [{ name, start, end, type }]
    @Published var muhuratWindows: [[String: String]] = []

    // MARK: - Sky Positions (synced from phone)

    /// Planet positions: [{ name, sign, signDegree, isRetro, nakshatra }]
    @Published var skyPositions: [[String: Any]] = []

    // MARK: - Nadi Data (generated on watch)

    /// Latest Nadi reading timestamp
    @Published var lastNadiReading: Date?

    /// Dominant dosha from pulse analysis
    @Published var nadiDominantDosha: String?

    /// HRV value (SDNN in ms)
    @Published var latestHRV: Double?

    /// Resting heart rate (BPM)
    @Published var latestRestingHR: Double?

    // MARK: - Ojas Data (computed from all signals)

    /// Latest Ojas vitality score (0–100)
    @Published var ojasScore: Int?

    /// Ojas summary word ("Vital", "Steady", etc.)
    @Published var ojasSummary: String?

    /// Agni type ("Sama", "Vishama", "Tikshna", "Manda")
    @Published var agniType: String?

    /// Last 7 days of Ojas scores for sparkline
    @Published var ojasHistory: [Int] = []

    /// Timestamp of last Ojas computation
    @Published var ojasComputedAt: Date?

    // MARK: - Recommendations (synced from phone after backend analysis)

    /// Dominant dosha from latest health analysis
    @Published var recsDosha: String?

    /// Recommendation items: [{ type: "food"|"activity"|"routine"|"urgent"|"ojas", text: "..." }]
    @Published var recsItems: [[String: String]] = []

    /// Day key the recommendations are based on
    @Published var recsBasedOn: String?

    // MARK: - Body Signals (from HealthKit)

    /// Sleep duration in hours (last night)
    @Published var sleepHours: Double?

    /// Deep sleep minutes (last night)
    @Published var deepSleepMinutes: Double?

    /// REM sleep minutes (last night)
    @Published var remSleepMinutes: Double?

    /// Wrist temperature deviation from baseline (°C)
    @Published var wristTempDeviation: Double?

    /// Respiratory rate (breaths/min)
    @Published var respiratoryRate: Double?

    /// VO2 Max (mL/kg/min)
    @Published var vo2Max: Double?

    /// Today's step count
    @Published var todaySteps: Int?

    /// HR recovery (bpm drop 1-min post-workout)
    @Published var hrRecovery: Double?

    /// Current heart rate (BPM)
    @Published var currentHeartRate: Double?

    /// Blood oxygen saturation (0.0–1.0)
    @Published var spO2: Double?

    /// Active energy burned today (kcal)
    @Published var activeEnergy: Double?

    /// Mindful minutes today
    @Published var mindfulMinutes: Double?

    /// Walking steadiness (0.0–1.0)
    @Published var walkingSteadiness: Double?

    // MARK: - Timestamps (when each reading was recorded)

    @Published var hrvTimestamp: Date?
    @Published var sleepTimestamp: Date?
    @Published var wristTempTimestamp: Date?
    @Published var respiratoryRateTimestamp: Date?
    @Published var vo2MaxTimestamp: Date?
    @Published var stepsTimestamp: Date?
    @Published var hrRecoveryTimestamp: Date?
    @Published var spO2Timestamp: Date?
    @Published var heartRateTimestamp: Date?
    @Published var activeEnergyTimestamp: Date?
    @Published var mindfulTimestamp: Date?
    @Published var walkingSteadinessTimestamp: Date?

    /// When health data was last fetched from HealthKit
    @Published var lastHealthFetch: Date?

    // MARK: - Signal History (7-day arrays for charts)

    @Published var hrvHistory: [Double] = []
    @Published var sleepHistory: [Double] = []       // hours per night
    @Published var deepSleepHistory: [Double] = []   // minutes per night
    @Published var remSleepHistory: [Double] = []    // minutes per night
    @Published var restingHRHistory: [Double] = []   // BPM per day
    @Published var respRateHistory: [Double] = []    // breaths/min per day
    @Published var spO2History: [Double] = []        // percentage per day
    @Published var stepsHistory: [Int] = []          // steps per day

    // MARK: - Init (restore from UserDefaults)

    init() {
        restore()
    }

    // MARK: - Persistence

    func save() {
        defaults.set(vedicDate, forKey: key("vedicDate"))
        defaults.set(samvatYear, forKey: key("samvatYear"))
        defaults.set(vedicNumericDate, forKey: key("vedicNumericDate"))
        if let encoded = try? JSONSerialization.data(withJSONObject: muhuratWindows) {
            defaults.set(encoded, forKey: key("muhurat"))
        }
        if let encoded = try? JSONSerialization.data(withJSONObject: skyPositions) {
            defaults.set(encoded, forKey: key("sky"))
        }
        defaults.set(prakritiType, forKey: key("prakritiType"))
        defaults.set(prakritiVata, forKey: key("prakritiVata"))
        defaults.set(prakritiPitta, forKey: key("prakritiPitta"))
        defaults.set(prakritiKapha, forKey: key("prakritiKapha"))
        defaults.set(insightTheme, forKey: key("insightTheme"))
        defaults.set(insightMessage, forKey: key("insightMessage"))
        defaults.set(nadiDominantDosha, forKey: key("nadiDosha"))
        defaults.set(latestHRV, forKey: key("latestHRV"))
        defaults.set(latestRestingHR, forKey: key("latestRHR"))
        if let date = lastNadiReading {
            defaults.set(date.timeIntervalSince1970, forKey: key("lastNadiTs"))
        }
    }

    func restore() {
        vedicDate = defaults.string(forKey: key("vedicDate"))
        samvatYear = defaults.string(forKey: key("samvatYear"))
        vedicNumericDate = defaults.string(forKey: key("vedicNumericDate"))
        if let data = defaults.data(forKey: key("muhurat")),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            muhuratWindows = decoded
        }
        if let data = defaults.data(forKey: key("sky")),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            skyPositions = decoded
        }
        prakritiType = defaults.string(forKey: key("prakritiType"))
        prakritiVata = defaults.integer(forKey: key("prakritiVata"))
        prakritiPitta = defaults.integer(forKey: key("prakritiPitta"))
        prakritiKapha = defaults.integer(forKey: key("prakritiKapha"))
        insightTheme = defaults.string(forKey: key("insightTheme"))
        insightMessage = defaults.string(forKey: key("insightMessage"))
        nadiDominantDosha = defaults.string(forKey: key("nadiDosha"))
        latestHRV = defaults.object(forKey: key("latestHRV")) as? Double
        latestRestingHR = defaults.object(forKey: key("latestRHR")) as? Double
        let ts = defaults.double(forKey: key("lastNadiTs"))
        lastNadiReading = ts > 0 ? Date(timeIntervalSince1970: ts) : nil

        // Recommendations
        recsDosha = defaults.string(forKey: key("recsDosha"))
        recsBasedOn = defaults.string(forKey: key("recsBasedOn"))
        if let data = defaults.data(forKey: key("recsItems")),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            recsItems = decoded
        }

        // Ojas data
        ojasScore = defaults.object(forKey: key("ojasScore")) as? Int
        ojasSummary = defaults.string(forKey: key("ojasSummary"))
        agniType = defaults.string(forKey: key("agniType"))
        if let data = defaults.data(forKey: key("ojasHistory")),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            ojasHistory = decoded
        }
        let ojasTs = defaults.double(forKey: key("ojasComputedAt"))
        ojasComputedAt = ojasTs > 0 ? Date(timeIntervalSince1970: ojasTs) : nil

        // Body signals
        sleepHours = defaults.object(forKey: key("sleepHours")) as? Double
        deepSleepMinutes = defaults.object(forKey: key("deepSleepMins")) as? Double
        remSleepMinutes = defaults.object(forKey: key("remSleepMins")) as? Double
        wristTempDeviation = defaults.object(forKey: key("wristTemp")) as? Double
        respiratoryRate = defaults.object(forKey: key("respRate")) as? Double
        vo2Max = defaults.object(forKey: key("vo2Max")) as? Double
        todaySteps = defaults.object(forKey: key("todaySteps")) as? Int
        hrRecovery = defaults.object(forKey: key("hrRecovery")) as? Double
        currentHeartRate = defaults.object(forKey: key("heartRate")) as? Double
        spO2 = defaults.object(forKey: key("spO2")) as? Double
        activeEnergy = defaults.object(forKey: key("activeEnergy")) as? Double
        mindfulMinutes = defaults.object(forKey: key("mindfulMins")) as? Double
        walkingSteadiness = defaults.object(forKey: key("walkSteady")) as? Double

        // Timestamps
        restoreTimestamp("hrvTs", to: &hrvTimestamp)
        restoreTimestamp("sleepTs", to: &sleepTimestamp)
        restoreTimestamp("tempTs", to: &wristTempTimestamp)
        restoreTimestamp("respTs", to: &respiratoryRateTimestamp)
        restoreTimestamp("vo2Ts", to: &vo2MaxTimestamp)
        restoreTimestamp("stepsTs", to: &stepsTimestamp)
        restoreTimestamp("recoveryTs", to: &hrRecoveryTimestamp)
        restoreTimestamp("spo2Ts", to: &spO2Timestamp)
        restoreTimestamp("hrTs", to: &heartRateTimestamp)
        restoreTimestamp("energyTs", to: &activeEnergyTimestamp)
        restoreTimestamp("mindfulTs", to: &mindfulTimestamp)
        restoreTimestamp("steadyTs", to: &walkingSteadinessTimestamp)
        restoreTimestamp("lastHealthFetch", to: &lastHealthFetch)

        // Signal histories
        restoreDoubleArray("hrvHistory", to: &hrvHistory)
        restoreDoubleArray("sleepHistory", to: &sleepHistory)
        restoreDoubleArray("deepSleepHistory", to: &deepSleepHistory)
        restoreDoubleArray("remSleepHistory", to: &remSleepHistory)
        restoreDoubleArray("rhrHistory", to: &restingHRHistory)
        restoreDoubleArray("respHistory", to: &respRateHistory)
        restoreDoubleArray("spo2History", to: &spO2History)
        restoreIntArray("stepsHistory", to: &stepsHistory)
    }

    // MARK: - Update Methods

    /// Update panchang data from phone sync payload.
    func updatePanchang(_ data: [String: Any]) {
        vedicDate = data["vedicDate"] as? String
        samvatYear = data["samvatYear"] as? String
        vedicNumericDate = data["vedicNumericDate"] as? String
        save()
    }

    /// Update profile data from phone sync payload.
    func updateProfile(_ data: [String: Any]) {
        prakritiType = data["prakritiType"] as? String
        prakritiVata = data["prakritiVata"] as? Int ?? 0
        prakritiPitta = data["prakritiPitta"] as? Int ?? 0
        prakritiKapha = data["prakritiKapha"] as? Int ?? 0
        save()
    }

    /// Update daily insight from phone sync payload.
    func updateInsight(_ data: [String: Any]) {
        insightTheme = data["theme"] as? String
        insightMessage = data["message"] as? String
        save()
    }

    /// Update sky positions from phone sync payload.
    func updateSky(_ data: [String: Any]) {
        if let planets = data["planets"] as? [[String: Any]] {
            skyPositions = planets
        }
        save()
    }

    /// Update muhurat windows from phone sync payload.
    func updateMuhurat(_ data: [String: Any]) {
        if let windows = data["windows"] as? [[String: String]] {
            muhuratWindows = windows
        } else if let windows = data["windows"] as? [[String: Any]] {
            // Coerce to [String: String]
            muhuratWindows = windows.map { w in
                var converted: [String: String] = [:]
                for (k, v) in w { converted[k] = "\(v)" }
                return converted
            }
        }
        save()
    }

    /// Update health recommendations from phone (backend-generated).
    func updateRecommendations(_ data: [String: Any]) {
        recsDosha = data["dosha"] as? String
        recsBasedOn = data["basedOn"] as? String
        if let items = data["items"] as? [[String: Any]] {
            recsItems = items.map { item in
                var converted: [String: String] = [:]
                for (k, v) in item { converted[k] = "\(v)" }
                return converted
            }
        } else if let items = data["items"] as? [[String: String]] {
            recsItems = items
        }
        // Persist
        defaults.set(recsDosha, forKey: key("recsDosha"))
        defaults.set(recsBasedOn, forKey: key("recsBasedOn"))
        if let encoded = try? JSONSerialization.data(withJSONObject: recsItems) {
            defaults.set(encoded, forKey: key("recsItems"))
        }
    }

    /// Update Nadi reading from on-watch analysis.
    func updateNadi(dominantDosha: String?, hrv: Double?, restingHR: Double?) {
        nadiDominantDosha = dominantDosha
        latestHRV = hrv
        latestRestingHR = restingHR
        lastNadiReading = .now
        save()
    }

    /// Update Ojas score from OjasEngine computation.
    func updateOjas(_ result: OjasResult) {
        ojasScore = result.score
        ojasSummary = result.summary
        agniType = result.agniType.rawValue
        ojasComputedAt = result.computedAt

        // Append to history (keep last 7)
        var history = ojasHistory
        history.append(result.score)
        if history.count > 7 { history.removeFirst(history.count - 7) }
        ojasHistory = history

        defaults.set(ojasScore, forKey: key("ojasScore"))
        defaults.set(ojasSummary, forKey: key("ojasSummary"))
        defaults.set(agniType, forKey: key("agniType"))
        defaults.set(result.computedAt.timeIntervalSince1970, forKey: key("ojasComputedAt"))
        if let encoded = try? JSONEncoder().encode(ojasHistory) {
            defaults.set(encoded, forKey: key("ojasHistory"))
        }
    }

    /// Update ALL body signals from HealthKitManager readings.
    func updateBodySignals(from health: HealthKitManager) {
        sleepHours = health.lastSleepDuration.map { $0 / 3600.0 }
        deepSleepMinutes = health.lastDeepSleepMinutes
        remSleepMinutes = health.lastREMSleepMinutes
        wristTempDeviation = health.latestWristTemp
        respiratoryRate = health.latestRespiratoryRate
        vo2Max = health.latestVO2Max
        todaySteps = health.todaySteps
        hrRecovery = health.latestHRRecovery
        currentHeartRate = health.latestHeartRate
        spO2 = health.latestSpO2
        activeEnergy = health.todayActiveEnergy
        mindfulMinutes = health.todayMindfulMinutes
        walkingSteadiness = health.latestWalkingSteadiness

        // Timestamps
        hrvTimestamp = health.hrvTimestamp
        sleepTimestamp = health.sleepTimestamp
        wristTempTimestamp = health.wristTempTimestamp
        respiratoryRateTimestamp = health.respiratoryRateTimestamp
        vo2MaxTimestamp = health.vo2MaxTimestamp
        stepsTimestamp = health.stepsTimestamp
        hrRecoveryTimestamp = health.hrRecoveryTimestamp
        spO2Timestamp = health.spO2Timestamp
        heartRateTimestamp = health.heartRateTimestamp
        activeEnergyTimestamp = health.activeEnergyTimestamp
        mindfulTimestamp = health.mindfulTimestamp
        walkingSteadinessTimestamp = health.walkingSteadinessTimestamp
        lastHealthFetch = health.lastFetchTime

        saveBodySignals()
    }

    /// Legacy: Update body signals with explicit parameters.
    func updateBodySignals(
        sleepHrs: Double?, deepMins: Double?, tempDev: Double?,
        respRate: Double?, vo2: Double?, steps: Int?, recovery: Double?
    ) {
        sleepHours = sleepHrs
        deepSleepMinutes = deepMins
        wristTempDeviation = tempDev
        respiratoryRate = respRate
        vo2Max = vo2
        todaySteps = steps
        hrRecovery = recovery
        saveBodySignals()
    }

    /// Append today's values to history arrays (call once per day).
    func appendDailyHistory() {
        appendToHistory(&hrvHistory, value: latestHRV, key: "hrvHistory")
        appendToHistory(&sleepHistory, value: sleepHours, key: "sleepHistory")
        appendToHistory(&deepSleepHistory, value: deepSleepMinutes, key: "deepSleepHistory")
        appendToHistory(&remSleepHistory, value: remSleepMinutes, key: "remSleepHistory")
        appendToHistory(&restingHRHistory, value: latestRestingHR, key: "rhrHistory")
        appendToHistory(&respRateHistory, value: respiratoryRate, key: "respHistory")
        if let spo2Val = spO2 { appendToHistory(&spO2History, value: spo2Val * 100, key: "spo2History") }
        if let steps = todaySteps {
            var hist = stepsHistory
            hist.append(steps)
            if hist.count > 7 { hist.removeFirst(hist.count - 7) }
            stepsHistory = hist
            if let encoded = try? JSONEncoder().encode(stepsHistory) {
                defaults.set(encoded, forKey: key("stepsHistory"))
            }
        }
    }

    /// Build a health data payload to send to the phone.
    func healthPayload() -> [String: Any] {
        var payload: [String: Any] = ["type": "healthData"]
        if let v = ojasScore { payload["ojasScore"] = v }
        if let v = ojasSummary { payload["ojasSummary"] = v }
        if let v = agniType { payload["agniType"] = v }
        if let v = nadiDominantDosha { payload["nadiDosha"] = v }
        if let v = latestHRV { payload["hrv"] = v }
        if let v = latestRestingHR { payload["restingHR"] = v }
        if let v = sleepHours { payload["sleepHours"] = v }
        if let v = deepSleepMinutes { payload["deepSleepMins"] = v }
        if let v = remSleepMinutes { payload["remSleepMins"] = v }
        if let v = wristTempDeviation { payload["wristTemp"] = v }
        if let v = respiratoryRate { payload["respRate"] = v }
        if let v = vo2Max { payload["vo2Max"] = v }
        if let v = todaySteps { payload["steps"] = v }
        if let v = hrRecovery { payload["hrRecovery"] = v }
        if let v = spO2 { payload["spO2"] = v > 1 ? v : v * 100 } // always send as 0–100%
        if let v = activeEnergy { payload["activeEnergy"] = v }
        if let v = mindfulMinutes { payload["mindfulMins"] = v }
        if !ojasHistory.isEmpty { payload["ojasHistory"] = ojasHistory }
        payload["timestamp"] = Date.now.timeIntervalSince1970
        return payload
    }

    // MARK: - Computed Helpers (shared across views)

    /// SpO2 as 0–100 percentage (HealthKit may return 0.0–1.0 or 0–100).
    var spO2Percentage: Double {
        guard let v = spO2 else { return 0 }
        return v > 1 ? v : v * 100
    }

    /// Dominant dosha from Prakriti percentages. Falls back to "vata".
    var dominantPrakritiDosha: String {
        let v = prakritiVata, p = prakritiPitta, k = prakritiKapha
        guard (v + p + k) > 0 else { return "vata" }
        let m = max(v, p, k)
        if m == v { return "vata" }
        if m == p { return "pitta" }
        return "kapha"
    }

    /// Best-available dominant dosha: Nadi pulse → Prakriti → fallback "vata".
    var activeDominantDosha: String {
        if let nadi = nadiDominantDosha, !nadi.isEmpty {
            return nadi.lowercased()
        }
        return dominantPrakritiDosha
    }

    /// Whether the user has completed the Prakriti quiz.
    var hasPrakriti: Bool {
        let type = prakritiType ?? ""
        return !type.isEmpty && (prakritiVata + prakritiPitta + prakritiKapha) > 0
    }

    /// Whether we have a Nadi (pulse) reading.
    var hasNadi: Bool {
        !(nadiDominantDosha ?? "").isEmpty
    }

    /// Prakriti dosha percentages as Doubles (for SwiftUI bars/charts).
    var prakritiVataPercent: Double { Double(prakritiVata) }
    var prakritiPittaPercent: Double { Double(prakritiPitta) }
    var prakritiKaphaPercent: Double { Double(prakritiKapha) }

    /// Safe HRV value (0 if nil).
    var hrvValue: Double { latestHRV ?? 0 }

    /// Safe resting HR as Int (0 if nil).
    var restingHRInt: Int { Int(latestRestingHR ?? 0) }

    /// Safe agni type string (defaults to "Sama").
    var safeAgniType: String {
        let t = agniType ?? ""
        return t.isEmpty ? "Sama" : t
    }

    // MARK: - Private Helpers

    private func key(_ name: String) -> String {
        "\(Self.prefix)\(name)"
    }

    private func saveBodySignals() {
        defaults.set(sleepHours, forKey: key("sleepHours"))
        defaults.set(deepSleepMinutes, forKey: key("deepSleepMins"))
        defaults.set(remSleepMinutes, forKey: key("remSleepMins"))
        defaults.set(wristTempDeviation, forKey: key("wristTemp"))
        defaults.set(respiratoryRate, forKey: key("respRate"))
        defaults.set(vo2Max, forKey: key("vo2Max"))
        defaults.set(todaySteps, forKey: key("todaySteps"))
        defaults.set(hrRecovery, forKey: key("hrRecovery"))
        defaults.set(currentHeartRate, forKey: key("heartRate"))
        defaults.set(spO2, forKey: key("spO2"))
        defaults.set(activeEnergy, forKey: key("activeEnergy"))
        defaults.set(mindfulMinutes, forKey: key("mindfulMins"))
        defaults.set(walkingSteadiness, forKey: key("walkSteady"))

        // Save timestamps
        saveTimestamp(hrvTimestamp, key: "hrvTs")
        saveTimestamp(sleepTimestamp, key: "sleepTs")
        saveTimestamp(wristTempTimestamp, key: "tempTs")
        saveTimestamp(respiratoryRateTimestamp, key: "respTs")
        saveTimestamp(vo2MaxTimestamp, key: "vo2Ts")
        saveTimestamp(stepsTimestamp, key: "stepsTs")
        saveTimestamp(hrRecoveryTimestamp, key: "recoveryTs")
        saveTimestamp(spO2Timestamp, key: "spo2Ts")
        saveTimestamp(heartRateTimestamp, key: "hrTs")
        saveTimestamp(activeEnergyTimestamp, key: "energyTs")
        saveTimestamp(mindfulTimestamp, key: "mindfulTs")
        saveTimestamp(walkingSteadinessTimestamp, key: "steadyTs")
        saveTimestamp(lastHealthFetch, key: "lastHealthFetch")
    }

    private func saveTimestamp(_ date: Date?, key name: String) {
        if let d = date {
            defaults.set(d.timeIntervalSince1970, forKey: key(name))
        }
    }

    private func restoreTimestamp(_ name: String, to property: inout Date?) {
        let ts = defaults.double(forKey: key(name))
        property = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private func restoreDoubleArray(_ name: String, to property: inout [Double]) {
        if let data = defaults.data(forKey: key(name)),
           let decoded = try? JSONDecoder().decode([Double].self, from: data) {
            property = decoded
        }
    }

    private func restoreIntArray(_ name: String, to property: inout [Int]) {
        if let data = defaults.data(forKey: key(name)),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            property = decoded
        }
    }

    private func appendToHistory(_ history: inout [Double], value: Double?, key name: String) {
        guard let v = value else { return }
        history.append(v)
        if history.count > 7 { history.removeFirst(history.count - 7) }
        if let encoded = try? JSONEncoder().encode(history) {
            defaults.set(encoded, forKey: key(name))
        }
    }
}
