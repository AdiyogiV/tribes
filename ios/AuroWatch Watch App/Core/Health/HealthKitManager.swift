import Foundation
import HealthKit
import Combine

/// Manages HealthKit data access on the watch.
///
/// Reads ALL passive health signals for Ayurvedic analysis:
///   - Heart Rate Variability (SDNN) → Nadi rhythm (primary)
///   - Resting Heart Rate → Nadi speed
///   - Heart Rate → current pulse
///   - Sleep Analysis → Nidra (sleep quality, stages)
///   - Wrist Temperature → Sparsha (heat/Pitta indicator)
///   - Respiratory Rate → Prana Vayu (breath quality)
///   - VO2 Max → Ojas/Bala (vitality/fitness)
///   - Walking Steadiness → Mamsa/Asthi Dhatu (structural health)
///   - Step Count → Vyayama (daily movement)
///   - Heart Rate Recovery → Agni recovery speed
///   - Blood Oxygen (SpO2) → Prana Vayu (oxygen saturation)
///   - Active Energy Burned → Agni (metabolic fire)
///   - Mindful Minutes → Sattva (mental clarity)
///
/// Every reading carries a timestamp so the UI can show data freshness.
///
/// Architecture: thin HealthKit wrapper. Analysis logic lives in OjasEngine/NadiEngine.
class HealthKitManager: ObservableObject {

    let store = HKHealthStore()

    // MARK: - Published State

    @Published var isAuthorized = false

    // Core Nadi signals
    @Published var latestHRV: Double?          // SDNN in ms
    @Published var latestRestingHR: Double?     // BPM
    @Published var latestHeartRate: Double?     // BPM (current)

    // Sleep signals (Nidra)
    @Published var lastSleepDuration: TimeInterval?       // total sleep in seconds
    @Published var lastDeepSleepMinutes: Double?          // deep sleep minutes
    @Published var lastREMSleepMinutes: Double?           // REM sleep minutes
    @Published var lastCoreSleepMinutes: Double?          // core sleep minutes
    @Published var lastSleepOnsetHour: Double?            // hour of sleep start (e.g., 22.5 = 10:30 PM)

    // Temperature (Sparsha)
    @Published var latestWristTemp: Double?     // deviation from baseline in °C

    // Breath (Prana)
    @Published var latestRespiratoryRate: Double?  // breaths per minute

    // Vitality (Ojas/Bala)
    @Published var latestVO2Max: Double?           // mL/kg/min
    @Published var latestWalkingSteadiness: Double? // 0.0–1.0

    // Movement (Vyayama)
    @Published var todaySteps: Int?
    @Published var latestHRRecovery: Double?    // bpm drop 1-min post-workout

    // Blood Oxygen (Prana)
    @Published var latestSpO2: Double?          // 0.0–1.0 (e.g., 0.98 = 98%)

    // Active Energy (Agni)
    @Published var todayActiveEnergy: Double?   // kcal burned today

    // Mindfulness (Sattva)
    @Published var todayMindfulMinutes: Double?  // minutes of mindful sessions today

    // MARK: - Timestamps (when HealthKit sample was recorded)

    @Published var hrvTimestamp: Date?
    @Published var restingHRTimestamp: Date?
    @Published var heartRateTimestamp: Date?
    @Published var sleepTimestamp: Date?
    @Published var wristTempTimestamp: Date?
    @Published var respiratoryRateTimestamp: Date?
    @Published var vo2MaxTimestamp: Date?
    @Published var walkingSteadinessTimestamp: Date?
    @Published var stepsTimestamp: Date?
    @Published var hrRecoveryTimestamp: Date?
    @Published var spO2Timestamp: Date?
    @Published var activeEnergyTimestamp: Date?
    @Published var mindfulTimestamp: Date?

    /// Master timestamp — when fetchAllReadings was last called
    @Published var lastFetchTime: Date?

    /// Completion tracking — how many fetches have returned
    @Published var fetchesCompleted: Int = 0
    @Published var fetchesTotal: Int = 0

    /// Types we read — all passive signals.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        // Core Nadi
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(t) }

        // Sleep (Nidra)
        if let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(t) }

        // Temperature (Sparsha)
        if let t = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) { types.insert(t) }

        // Breath (Prana)
        if let t = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) { types.insert(t) }

        // Vitality (Bala)
        if let t = HKQuantityType.quantityType(forIdentifier: .vo2Max) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness) { types.insert(t) }

        // Movement (Vyayama)
        if let t = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(t) }

        // Recovery (Agni)
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) { types.insert(t) }

        // Blood Oxygen (Prana)
        if let t = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(t) }

        // Active Energy (Agni)
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(t) }

        // Mindfulness (Sattva)
        if let t = HKCategoryType.categoryType(forIdentifier: .mindfulSession) { types.insert(t) }

        return types
    }

    // MARK: - Background Sync

    /// Callback invoked when background health data is ready to send.
    /// Set by AuroWatchApp to wire up sync → phone.
    var onBackgroundDataReady: (() -> Void)?

    /// Enable HealthKit background delivery for key signals.
    /// Apple wakes the app when new samples arrive — we re-fetch and notify.
    func enableBackgroundDelivery() {
        let bgTypes: [(HKObjectType, HKUpdateFrequency)] = [
            (HKQuantityType.quantityType(forIdentifier: .heartRate)!, .immediate),
            (HKQuantityType.quantityType(forIdentifier: .stepCount)!, .hourly),
            (HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!, .hourly),
            (HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!, .hourly),
            (HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!, .hourly),
        ]

        for (type, freq) in bgTypes {
            store.enableBackgroundDelivery(for: type, frequency: freq) { success, error in
                if let error = error {
                    AuroLog.error("BG delivery error for \(type.identifier): \(error.localizedDescription)", category: .health)
                } else if success {
                    AuroLog.debug("BG delivery enabled: \(type.identifier)", category: .health)
                }
            }
        }
    }

    /// Set up observer queries that fire when HealthKit receives new samples.
    /// Each observer triggers a full re-fetch + phone sync.
    func setupObservers() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Observe heart rate — fires ~every 5 min while watch is worn
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let query = HKObserverQuery(sampleType: hrType, predicate: nil) { [weak self] _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                AuroLog.debug("Observer: new heart rate → fetching all signals", category: .health)
                self?.fetchAllReadings {
                    self?.onBackgroundDataReady?()
                    completionHandler()
                }
            }
            store.execute(query)
        }

        // Observe HRV — fires ~once per day (after sleep analysis)
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                AuroLog.debug("Observer: new HRV → fetching all signals", category: .health)
                self?.fetchAllReadings {
                    self?.onBackgroundDataReady?()
                    completionHandler()
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            AuroLog.warn("HealthKit not available on this device", category: .health)
            return
        }

        store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
            }
            if let error = error {
                AuroLog.error("HealthKit auth error: \(error.localizedDescription)", category: .health)
            } else {
                AuroLog.info("HealthKit authorized: \(success)", category: .health)
                if success {
                    self.fetchAllReadings()
                    self.enableBackgroundDelivery()
                    self.setupObservers()
                }
            }
        }
    }

    // MARK: - Fetch All (with completion tracking)

    /// Fetch all available health readings. Calls completion when all fetches done.
    func fetchAllReadings(completion: (() -> Void)? = nil) {
        let totalFetches = 13 // number of individual fetch calls
        var completed = 0
        let lock = NSLock()
        let startTime = Date()

        AuroLog.info("Fetching all \(totalFetches) health signals...", category: .health)

        DispatchQueue.main.async {
            self.fetchesCompleted = 0
            self.fetchesTotal = totalFetches
            self.lastFetchTime = .now
        }

        let onFetchDone = {
            lock.lock()
            completed += 1
            let current = completed
            lock.unlock()
            DispatchQueue.main.async {
                self.fetchesCompleted = current
                if current >= totalFetches {
                    let elapsed = String(format: "%.1f", -startTime.timeIntervalSinceNow)
                    AuroLog.info("All \(totalFetches) fetches complete in \(elapsed)s", category: .health)
                    self.logSignalSummary()
                    completion?()
                }
            }
        }

        fetchLatestHRV(completion: onFetchDone)
        fetchLatestRestingHR(completion: onFetchDone)
        fetchLatestHeartRate(completion: onFetchDone)
        fetchSleepData(completion: onFetchDone)
        fetchWristTemperature(completion: onFetchDone)
        fetchRespiratoryRate(completion: onFetchDone)
        fetchVO2Max(completion: onFetchDone)
        fetchWalkingSteadiness(completion: onFetchDone)
        fetchTodaySteps(completion: onFetchDone)
        fetchHRRecovery(completion: onFetchDone)
        fetchSpO2(completion: onFetchDone)
        fetchTodayActiveEnergy(completion: onFetchDone)
        fetchTodayMindfulMinutes(completion: onFetchDone)
    }

    /// Log a summary of all available signals after a full fetch.
    private func logSignalSummary() {
        var available: [String] = []
        var missing: [String] = []
        let signals: [(String, Any?)] = [
            ("HRV", latestHRV), ("RHR", latestRestingHR), ("HR", latestHeartRate),
            ("Sleep", lastSleepDuration), ("Deep", lastDeepSleepMinutes), ("REM", lastREMSleepMinutes),
            ("Temp", latestWristTemp), ("Resp", latestRespiratoryRate), ("VO2", latestVO2Max),
            ("Steps", todaySteps), ("Recovery", latestHRRecovery), ("SpO2", latestSpO2),
            ("Energy", todayActiveEnergy), ("Mindful", todayMindfulMinutes)
        ]
        for (name, val) in signals {
            if val != nil { available.append(name) } else { missing.append(name) }
        }
        AuroLog.info("Signals available: \(available.joined(separator: ", ")) (\(available.count)/\(signals.count))", category: .health)
        if !missing.isEmpty {
            AuroLog.debug("Signals missing: \(missing.joined(separator: ", "))", category: .health)
        }
    }

    /// Fetch core Nadi signals only (lightweight).
    func fetchLatestReadings() {
        fetchLatestHRV()
        fetchLatestRestingHR()
        fetchLatestHeartRate()
    }

    // MARK: - Core Nadi Signals

    func fetchLatestHRV(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: HKUnit.secondUnit(with: .milli)) { value, date in
            DispatchQueue.main.async {
                self.latestHRV = value
                self.hrvTimestamp = date
            }
            completion?()
        }
    }

    func fetchLatestRestingHR(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion?()
            return
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchMostRecentWithDate(type: type, unit: bpm) { value, date in
            DispatchQueue.main.async {
                self.latestRestingHR = value
                self.restingHRTimestamp = date
            }
            completion?()
        }
    }

    func fetchLatestHeartRate(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion?()
            return
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchMostRecentWithDate(type: type, unit: bpm) { value, date in
            DispatchQueue.main.async {
                self.latestHeartRate = value
                self.heartRateTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Sleep (Nidra)

    /// Fetch last night's sleep stages and compute totals.
    func fetchSleepData(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion?()
            return
        }

        // Look back 24 hours for last night's sleep
        let now = Date.now
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, error in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                completion?()
                return
            }

            var totalSleep: TimeInterval = 0
            var deepMinutes: Double = 0
            var remMinutes: Double = 0
            var coreMinutes: Double = 0
            var earliestSleepStart: Date?
            var latestSleepEnd: Date?

            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0 // minutes

                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepMinutes += duration
                    totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remMinutes += duration
                    totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    coreMinutes += duration
                    totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    // Older devices that don't break down stages
                    coreMinutes += duration
                    totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                default:
                    break // awake, inBed — don't count
                }

                // Track earliest sleep onset
                let val = sample.value
                if val != HKCategoryValueSleepAnalysis.awake.rawValue &&
                   val != HKCategoryValueSleepAnalysis.inBed.rawValue {
                    if earliestSleepStart == nil || sample.startDate < earliestSleepStart! {
                        earliestSleepStart = sample.startDate
                    }
                    if latestSleepEnd == nil || sample.endDate > latestSleepEnd! {
                        latestSleepEnd = sample.endDate
                    }
                }
            }

            DispatchQueue.main.async {
                self.lastSleepDuration = totalSleep
                self.lastDeepSleepMinutes = deepMinutes
                self.lastREMSleepMinutes = remMinutes
                self.lastCoreSleepMinutes = coreMinutes
                self.sleepTimestamp = latestSleepEnd ?? earliestSleepStart

                if let onset = earliestSleepStart {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: onset)
                    self.lastSleepOnsetHour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
                }
            }
            completion?()
        }
        store.execute(query)
    }

    // MARK: - Temperature (Sparsha)

    func fetchWristTemperature(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .degreeCelsius()) { value, date in
            DispatchQueue.main.async {
                self.latestWristTemp = value
                self.wristTempTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Respiratory Rate (Prana)

    func fetchRespiratoryRate(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            completion?()
            return
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestRespiratoryRate = value
                self.respiratoryRateTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - VO2 Max (Bala)

    func fetchVO2Max(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            completion?()
            return
        }
        let unit = HKUnit(from: "mL/kg*min")
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestVO2Max = value
                self.vo2MaxTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Walking Steadiness (Dhatu)

    func fetchWalkingSteadiness(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .percent()) { value, date in
            DispatchQueue.main.async {
                self.latestWalkingSteadiness = value
                self.walkingSteadinessTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Steps (Vyayama)

    func fetchTodaySteps(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion?()
            return
        }

        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                       options: .cumulativeSum) { _, stats, _ in
            let steps = stats?.sumQuantity()?.doubleValue(for: .count())
            DispatchQueue.main.async {
                self.todaySteps = steps.map { Int($0) }
                self.stepsTimestamp = .now
            }
            completion?()
        }
        store.execute(query)
    }

    // MARK: - Heart Rate Recovery (Agni)

    func fetchHRRecovery(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) else {
            completion?()
            return
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchMostRecentWithDate(type: type, unit: bpm) { value, date in
            DispatchQueue.main.async {
                self.latestHRRecovery = value
                self.hrRecoveryTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Blood Oxygen (Prana)

    func fetchSpO2(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .percent()) { value, date in
            DispatchQueue.main.async {
                self.latestSpO2 = value
                self.spO2Timestamp = date
            }
            completion?()
        }
    }

    // MARK: - Active Energy (Agni)

    func fetchTodayActiveEnergy(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion?()
            return
        }

        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                       options: .cumulativeSum) { _, stats, _ in
            let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
            DispatchQueue.main.async {
                self.todayActiveEnergy = kcal
                self.activeEnergyTimestamp = .now
            }
            completion?()
        }
        store.execute(query)
    }

    // MARK: - Mindful Minutes (Sattva)

    func fetchTodayMindfulMinutes(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            completion?()
            return
        }

        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, _ in
            let totalMinutes = (samples as? [HKCategorySample])?.reduce(0.0) { sum, sample in
                sum + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            } ?? 0

            DispatchQueue.main.async {
                self.todayMindfulMinutes = totalMinutes > 0 ? totalMinutes : nil
                self.mindfulTimestamp = totalMinutes > 0 ? .now : nil
            }
            completion?()
        }
        store.execute(query)
    }

    // MARK: - Historical Data (for baseline calculation)

    /// Fetch HRV samples over a date range (for 14-day baseline).
    func fetchHRVHistory(days: Int = 14, completion: @escaping ([HRVSample]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion([])
            return
        }

        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                AuroLog.error("HRV history fetch error: \(error.localizedDescription)", category: .health)
                completion([])
                return
            }
            let unit = HKUnit.secondUnit(with: .milli)
            let results = (samples as? [HKQuantitySample])?.map { sample in
                HRVSample(
                    value: sample.quantity.doubleValue(for: unit),
                    date: sample.startDate
                )
            } ?? []
            completion(results)
        }
        store.execute(query)
    }

    /// Fetch daily sleep durations for the past N days (for trend/baseline).
    func fetchSleepHistory(days: Int = 7, completion: @escaping ([SleepDaySummary]) -> Void) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                completion([])
                return
            }

            // Group by night (sleep starting after 6 PM counts for that day)
            var dayBuckets: [String: SleepDaySummary] = [:]
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"

            for sample in samples {
                let val = sample.value
                guard val != HKCategoryValueSleepAnalysis.awake.rawValue,
                      val != HKCategoryValueSleepAnalysis.inBed.rawValue else { continue }

                // Assign to the date the sleep "belongs to" (before midnight → that date)
                let dateKey = fmt.string(from: sample.startDate)
                let mins = sample.endDate.timeIntervalSince(sample.startDate) / 60.0

                var summary = dayBuckets[dateKey] ?? SleepDaySummary(date: sample.startDate)
                summary.totalMinutes += mins
                if val == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                    summary.deepMinutes += mins
                }
                if val == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    summary.remMinutes += mins
                }
                dayBuckets[dateKey] = summary
            }

            let results = dayBuckets.values.sorted { $0.date < $1.date }
            completion(Array(results))
        }
        store.execute(query)
    }

    /// Fetch SpO2 history for the past N days.
    func fetchSpO2History(days: Int = 7, completion: @escaping ([TimestampedValue]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion([])
            return
        }
        fetchHistory(type: type, unit: .percent(), days: days, completion: completion)
    }

    /// Fetch resting HR history for the past N days.
    func fetchRestingHRHistory(days: Int = 7, completion: @escaping ([TimestampedValue]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion([])
            return
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchHistory(type: type, unit: bpm, days: days, completion: completion)
    }

    /// Fetch respiratory rate history for the past N days.
    func fetchRespiratoryHistory(days: Int = 7, completion: @escaping ([TimestampedValue]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            completion([])
            return
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchHistory(type: type, unit: unit, days: days, completion: completion)
    }

    // MARK: - Generic Helpers

    private func fetchMostRecentWithDate(type: HKQuantityType, unit: HKUnit, completion: @escaping (Double?, Date?) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                   sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                AuroLog.error("Fetch error for \(type.identifier): \(error.localizedDescription)", category: .health)
                completion(nil, nil)
                return
            }
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil, nil)
                return
            }
            completion(sample.quantity.doubleValue(for: unit), sample.startDate)
        }
        store.execute(query)
    }

    private func fetchHistory(type: HKQuantityType, unit: HKUnit, days: Int, completion: @escaping ([TimestampedValue]) -> Void) {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, _ in
            let results = (samples as? [HKQuantitySample])?.map { sample in
                TimestampedValue(
                    value: sample.quantity.doubleValue(for: unit),
                    date: sample.startDate
                )
            } ?? []
            completion(results)
        }
        store.execute(query)
    }
}

// MARK: - Supporting Types

struct HRVSample {
    let value: Double  // SDNN in ms
    let date: Date
}

struct SleepDaySummary {
    let date: Date
    var totalMinutes: Double = 0
    var deepMinutes: Double = 0
    var remMinutes: Double = 0
}

/// Generic timestamped value for historical data.
struct TimestampedValue {
    let value: Double
    let date: Date
}
