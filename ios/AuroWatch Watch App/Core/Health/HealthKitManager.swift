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
    @Published var todayStandHours: Int?        // Apple stand hours today
    @Published var todayExerciseMinutes: Double? // Apple exercise minutes today
    @Published var latestWalkingHR: Double?     // walking HR average (bpm)

    // Blood Oxygen (Prana)
    @Published var latestSpO2: Double?          // 0.0–1.0 (e.g., 0.98 = 98%)

    // Active Energy (Agni)
    @Published var todayActiveEnergy: Double?   // kcal burned today

    // Mindfulness (Sattva)
    @Published var todayMindfulMinutes: Double?  // minutes of mindful sessions today

    // Environment / Circadian
    @Published var todayDaylightMinutes: Double?       // time in daylight today (minutes)
    @Published var latestEnvAudioExposure: Double?     // environmental audio exposure (dB)
    @Published var latestHeadphoneAudioExposure: Double? // headphone audio exposure (dB)

    // Cardiac events
    @Published var latestAFibBurden: Double?           // % time in AFib
    @Published var todayHighHRCount: Int?              // count of high HR events today
    @Published var todayLowHRCount: Int?               // count of low HR events today
    @Published var todayIrregularRhythmCount: Int?     // count of irregular rhythm events today
    @Published var todayECGCount: Int?                 // count of ECG samples today

    // Activity (more)
    @Published var todayBasalEnergy: Double?           // basal kcal burned today
    @Published var todayDistanceMeters: Double?        // walking/running distance today (meters)
    @Published var todayFlightsClimbed: Double?        // flights climbed today (count)
    @Published var todayStandMinutes: Double?          // actual stand minutes today
    @Published var todayWorkoutCount: Int?             // workouts done today
    @Published var todayWorkoutMinutes: Double?        // total workout duration today (minutes)

    // Gait / Mobility
    @Published var latestWalkingSpeed: Double?         // m/s
    @Published var latestWalkingStepLength: Double?    // cm
    @Published var latestWalkingDoubleSupport: Double? // 0–1 fraction
    @Published var latestWalkingAsymmetry: Double?     // 0–1 fraction
    @Published var latestStairAscentSpeed: Double?     // m/s
    @Published var latestStairDescentSpeed: Double?    // m/s
    @Published var latestSixMinuteWalk: Double?        // meters

    // Running
    @Published var latestRunningSpeed: Double?         // m/s
    @Published var latestRunningPower: Double?         // watts
    @Published var latestRunningStrideLength: Double?  // meters
    @Published var latestRunningGroundContact: Double? // ms
    @Published var latestRunningVerticalOsc: Double?   // cm

    // Body composition
    @Published var latestBodyMass: Double?             // kg
    @Published var latestBodyMassIndex: Double?        // count
    @Published var latestBodyFatPercentage: Double?    // 0–1 fraction
    @Published var latestLeanBodyMass: Double?         // kg
    @Published var latestHeight: Double?               // meters

    // Temperature (non-sleep)
    @Published var latestBodyTemperature: Double?      // °C

    // Beat-to-beat HRV (computed from HKHeartbeatSeriesSample RR intervals)
    @Published var latestRMSSD: Double?                // ms — root mean square of successive RR diffs
    @Published var latestPNN50: Double?                // 0–1 — fraction of NN50+ pairs
    @Published var latestRRSampleCount: Int?           // total RR pairs analyzed

    // Sleep disturbances (watchOS 11+)
    @Published var todaySleepApneaCount: Int?          // count of elevated breathing-disturbance samples

    // Environment (more)
    @Published var latestUVExposure: Double?           // count (UV index)

    // Audio exposure events (registered loud-sound alerts)
    @Published var todayEnvAudioEventCount: Int?
    @Published var todayHeadphoneAudioEventCount: Int?

    // Fall detection
    @Published var todayFallCount: Int?

    // Low cardio fitness event (Apple's low-VO₂ flag)
    @Published var todayLowCardioFitnessCount: Int?

    // Most recent workout details
    @Published var latestWorkoutType: String?          // localized workout type name
    @Published var latestWorkoutDuration: Double?      // seconds
    @Published var latestWorkoutEnergyKcal: Double?    // kcal
    @Published var latestWorkoutAvgHR: Double?         // bpm (avg during workout)
    @Published var latestWorkoutMaxHR: Double?         // bpm (max during workout)
    @Published var latestWorkoutDate: Date?            // when workout ended

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
    @Published var standHoursTimestamp: Date?
    @Published var exerciseMinutesTimestamp: Date?
    @Published var walkingHRTimestamp: Date?
    @Published var daylightTimestamp: Date?
    @Published var envAudioTimestamp: Date?
    @Published var headphoneAudioTimestamp: Date?
    @Published var afibTimestamp: Date?
    @Published var highHREventTimestamp: Date?
    @Published var lowHREventTimestamp: Date?
    @Published var irregularRhythmTimestamp: Date?
    @Published var ecgTimestamp: Date?
    @Published var basalEnergyTimestamp: Date?
    @Published var distanceTimestamp: Date?
    @Published var flightsTimestamp: Date?
    @Published var standMinutesTimestamp: Date?
    @Published var workoutTimestamp: Date?
    @Published var walkingSpeedTimestamp: Date?
    @Published var walkingStepLengthTimestamp: Date?
    @Published var walkingDoubleSupportTimestamp: Date?
    @Published var walkingAsymmetryTimestamp: Date?
    @Published var stairAscentTimestamp: Date?
    @Published var stairDescentTimestamp: Date?
    @Published var sixMinuteWalkTimestamp: Date?
    @Published var runningSpeedTimestamp: Date?
    @Published var runningPowerTimestamp: Date?
    @Published var runningStrideTimestamp: Date?
    @Published var runningGroundContactTimestamp: Date?
    @Published var runningVerticalOscTimestamp: Date?
    @Published var bodyMassTimestamp: Date?
    @Published var bmiTimestamp: Date?
    @Published var bodyFatTimestamp: Date?
    @Published var leanMassTimestamp: Date?
    @Published var heightTimestamp: Date?
    @Published var bodyTempTimestamp: Date?
    @Published var rmssdTimestamp: Date?
    @Published var pnn50Timestamp: Date?
    @Published var sleepApneaTimestamp: Date?
    @Published var uvExposureTimestamp: Date?
    @Published var envAudioEventTimestamp: Date?
    @Published var headphoneAudioEventTimestamp: Date?
    @Published var fallTimestamp: Date?
    @Published var lowCardioFitnessTimestamp: Date?
    @Published var latestWorkoutTimestamp: Date?

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

        // Activity rings extras
        if let t = HKCategoryType.categoryType(forIdentifier: .appleStandHour) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) { types.insert(t) }

        // Environment / circadian
        if #available(watchOS 10.0, *) {
            if let t = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) { types.insert(t) }
        }
        if let t = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) { types.insert(t) }

        // Cardiac events
        if let t = HKQuantityType.quantityType(forIdentifier: .atrialFibrillationBurden) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .highHeartRateEvent) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .lowHeartRateEvent) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .irregularHeartRhythmEvent) { types.insert(t) }
        types.insert(HKObjectType.electrocardiogramType())

        // Activity (more)
        if let t = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .appleStandTime) { types.insert(t) }
        types.insert(HKObjectType.workoutType())

        // Gait / Mobility
        if let t = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) { types.insert(t) }

        // Running
        if let t = HKQuantityType.quantityType(forIdentifier: .runningSpeed) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .runningPower) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .runningStrideLength) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation) { types.insert(t) }

        // Body composition
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .height) { types.insert(t) }

        // Body temperature (non-sleep)
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) { types.insert(t) }

        // Beat-to-beat (RR-interval) source for RMSSD / pNN50
        types.insert(HKSeriesType.heartbeat())

        // Sleep apnea events — iOS-only HealthKit category (.appleSleepingBreathingDisturbances).
        // Not available on watchOS; phone app must read this and sync the count down.

        // UV exposure (Tejas / Pitta provocation)
        if let t = HKQuantityType.quantityType(forIdentifier: .uvExposure) { types.insert(t) }

        // Audio exposure events
        if let t = HKCategoryType.categoryType(forIdentifier: .environmentalAudioExposureEvent) { types.insert(t) }
        if let t = HKCategoryType.categoryType(forIdentifier: .headphoneAudioExposureEvent) { types.insert(t) }

        // Fall detection
        if let t = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) { types.insert(t) }

        // Low cardio fitness flag
        if let t = HKCategoryType.categoryType(forIdentifier: .lowCardioFitnessEvent) { types.insert(t) }

        return types
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
                }
            }
        }
    }

    // MARK: - Fetch All (with completion tracking)

    /// Fetch all available health readings. Calls completion when all fetches done.
    func fetchAllReadings(completion: (() -> Void)? = nil) {
        let totalFetches = 55 // number of individual fetch calls
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
        fetchTodayStandHours(completion: onFetchDone)
        fetchTodayExerciseMinutes(completion: onFetchDone)
        fetchWalkingHR(completion: onFetchDone)
        fetchTodayDaylight(completion: onFetchDone)
        fetchEnvAudioExposure(completion: onFetchDone)
        fetchHeadphoneAudioExposure(completion: onFetchDone)

        // Cardiac events
        fetchAFibBurden(completion: onFetchDone)
        fetchTodayHighHRCount(completion: onFetchDone)
        fetchTodayLowHRCount(completion: onFetchDone)
        fetchTodayIrregularRhythmCount(completion: onFetchDone)
        fetchTodayECGCount(completion: onFetchDone)

        // Activity (more)
        fetchTodayBasalEnergy(completion: onFetchDone)
        fetchTodayDistance(completion: onFetchDone)
        fetchTodayFlightsClimbed(completion: onFetchDone)
        fetchTodayStandMinutes(completion: onFetchDone)
        fetchTodayWorkoutSummary(completion: onFetchDone)

        // Gait / mobility
        fetchWalkingSpeed(completion: onFetchDone)
        fetchWalkingStepLength(completion: onFetchDone)
        fetchWalkingDoubleSupport(completion: onFetchDone)
        fetchWalkingAsymmetry(completion: onFetchDone)
        fetchStairAscentSpeed(completion: onFetchDone)
        fetchStairDescentSpeed(completion: onFetchDone)
        fetchSixMinuteWalk(completion: onFetchDone)

        // Running
        fetchRunningSpeed(completion: onFetchDone)
        fetchRunningPower(completion: onFetchDone)
        fetchRunningStrideLength(completion: onFetchDone)
        fetchRunningGroundContact(completion: onFetchDone)
        fetchRunningVerticalOsc(completion: onFetchDone)

        // Body composition
        fetchBodyMass(completion: onFetchDone)
        fetchBodyMassIndex(completion: onFetchDone)
        fetchBodyFatPercentage(completion: onFetchDone)
        fetchLeanBodyMass(completion: onFetchDone)
        fetchHeight(completion: onFetchDone)

        // Body temperature (non-sleep)
        fetchBodyTemperature(completion: onFetchDone)

        // Beat-to-beat HRV (RMSSD / pNN50) — heartbeat series counts as one fetch
        fetchHeartbeatSeriesMetrics(completion: onFetchDone)

        // Sleep apnea / breathing disturbances (today)
        fetchTodaySleepApneaCount(completion: onFetchDone)

        // Environment + safety extras
        fetchUVExposure(completion: onFetchDone)
        fetchTodayEnvAudioEventCount(completion: onFetchDone)
        fetchTodayHeadphoneAudioEventCount(completion: onFetchDone)
        fetchTodayFallCount(completion: onFetchDone)
        fetchTodayLowCardioFitnessCount(completion: onFetchDone)

        // Most recent workout details
        fetchLatestWorkoutDetails(completion: onFetchDone)
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
            ("Energy", todayActiveEnergy), ("Mindful", todayMindfulMinutes),
            ("Stand", todayStandHours), ("Exercise", todayExerciseMinutes), ("WalkHR", latestWalkingHR),
            ("Daylight", todayDaylightMinutes), ("EnvAudio", latestEnvAudioExposure),
            ("HeadAudio", latestHeadphoneAudioExposure),
            ("AFib", latestAFibBurden), ("HighHR", todayHighHRCount), ("LowHR", todayLowHRCount),
            ("Irreg", todayIrregularRhythmCount), ("ECG", todayECGCount),
            ("Basal", todayBasalEnergy), ("Dist", todayDistanceMeters), ("Flights", todayFlightsClimbed),
            ("StandMin", todayStandMinutes), ("Workouts", todayWorkoutCount),
            ("WalkSpd", latestWalkingSpeed), ("StepLen", latestWalkingStepLength),
            ("DblSup", latestWalkingDoubleSupport), ("Asym", latestWalkingAsymmetry),
            ("StairUp", latestStairAscentSpeed), ("StairDn", latestStairDescentSpeed),
            ("6MWT", latestSixMinuteWalk),
            ("RunSpd", latestRunningSpeed), ("RunPwr", latestRunningPower),
            ("RunStr", latestRunningStrideLength), ("RunGC", latestRunningGroundContact),
            ("RunVO", latestRunningVerticalOsc),
            ("Mass", latestBodyMass), ("BMI", latestBodyMassIndex), ("Fat", latestBodyFatPercentage),
            ("Lean", latestLeanBodyMass), ("Height", latestHeight),
            ("BodyT", latestBodyTemperature)
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

    /// Fetch ALL heart rate readings since `since`. Returns timestamped pairs.
    /// This captures every sample Apple Watch recorded — no data loss.
    func fetchHeartRateReadings(
        since: Date,
        completion: @escaping ([TimestampedValue]) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchHistory(type: type, unit: bpm, since: since, completion: completion)
    }

    /// Fetch ALL HRV readings since `since`.
    func fetchHRVReadings(
        since: Date,
        completion: @escaping ([TimestampedValue]) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion([])
            return
        }
        fetchHistory(type: type, unit: HKUnit.secondUnit(with: .milli), since: since, completion: completion)
    }

    /// Fetch ALL SpO2 readings since `since`.
    func fetchSpO2Readings(
        since: Date,
        completion: @escaping ([TimestampedValue]) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion([])
            return
        }
        // HealthKit stores SpO2 as a fraction (0.0–1.0)
        fetchHistory(type: type, unit: HKUnit.percent(), since: since, completion: completion)
    }

    /// Fetch ALL respiratory rate readings since `since`.
    func fetchRespRateReadings(
        since: Date,
        completion: @escaping ([TimestampedValue]) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            completion([])
            return
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchHistory(type: type, unit: unit, since: since, completion: completion)
    }

    /// Fetch ALL resting HR readings since `since`.
    func fetchRestingHRReadings(
        since: Date,
        completion: @escaping ([TimestampedValue]) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion([])
            return
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchHistory(type: type, unit: bpm, since: since, completion: completion)
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

    // MARK: - Activity Rings Extras

    /// Fetch today's stand-hour count (Apple stand hours).
    func fetchTodayStandHours(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else {
            completion?()
            return
        }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, _ in
            // Stood = HKCategoryValueAppleStandHour.stood (rawValue 0)
            let stood = (samples as? [HKCategorySample])?.filter {
                $0.value == HKCategoryValueAppleStandHour.stood.rawValue
            }.count ?? 0
            DispatchQueue.main.async {
                self.todayStandHours = stood
                self.standHoursTimestamp = .now
            }
            completion?()
        }
        store.execute(query)
    }

    /// Fetch today's exercise minutes (cumulative).
    func fetchTodayExerciseMinutes(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion?()
            return
        }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                       options: .cumulativeSum) { _, stats, _ in
            let mins = stats?.sumQuantity()?.doubleValue(for: .minute())
            DispatchQueue.main.async {
                self.todayExerciseMinutes = mins
                self.exerciseMinutesTimestamp = .now
            }
            completion?()
        }
        store.execute(query)
    }

    /// Fetch the most recent walking heart-rate average.
    func fetchWalkingHR(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) else {
            completion?()
            return
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchMostRecentWithDate(type: type, unit: bpm) { value, date in
            DispatchQueue.main.async {
                self.latestWalkingHR = value
                self.walkingHRTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Environment / Circadian

    /// Fetch today's time-in-daylight (watchOS 10+).
    func fetchTodayDaylight(completion: (() -> Void)? = nil) {
        guard #available(watchOS 10.0, *),
              let type = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else {
            completion?()
            return
        }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                       options: .cumulativeSum) { _, stats, _ in
            let mins = stats?.sumQuantity()?.doubleValue(for: .minute())
            DispatchQueue.main.async {
                self.todayDaylightMinutes = mins
                self.daylightTimestamp = .now
            }
            completion?()
        }
        store.execute(query)
    }

    /// Fetch the most recent environmental audio exposure sample.
    func fetchEnvAudioExposure(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) else {
            completion?()
            return
        }
        let unit = HKUnit.decibelAWeightedSoundPressureLevel()
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestEnvAudioExposure = value
                self.envAudioTimestamp = date
            }
            completion?()
        }
    }

    /// Fetch the most recent headphone audio exposure sample.
    func fetchHeadphoneAudioExposure(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) else {
            completion?()
            return
        }
        let unit = HKUnit.decibelAWeightedSoundPressureLevel()
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestHeadphoneAudioExposure = value
                self.headphoneAudioTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Cardiac Events

    /// Fetch most recent atrial-fibrillation burden (% time in AFib).
    func fetchAFibBurden(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .atrialFibrillationBurden) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .percent()) { value, date in
            DispatchQueue.main.async {
                self.latestAFibBurden = value
                self.afibTimestamp = date
            }
            completion?()
        }
    }

    /// Count today's high heart rate events.
    func fetchTodayHighHRCount(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .highHeartRateEvent) else {
            completion?()
            return
        }
        countTodayCategory(type: type) { count, date in
            DispatchQueue.main.async {
                self.todayHighHRCount = count
                self.highHREventTimestamp = date
            }
            completion?()
        }
    }

    /// Count today's low heart rate events.
    func fetchTodayLowHRCount(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .lowHeartRateEvent) else {
            completion?()
            return
        }
        countTodayCategory(type: type) { count, date in
            DispatchQueue.main.async {
                self.todayLowHRCount = count
                self.lowHREventTimestamp = date
            }
            completion?()
        }
    }

    /// Count today's irregular rhythm events.
    func fetchTodayIrregularRhythmCount(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .irregularHeartRhythmEvent) else {
            completion?()
            return
        }
        countTodayCategory(type: type) { count, date in
            DispatchQueue.main.async {
                self.todayIrregularRhythmCount = count
                self.irregularRhythmTimestamp = date
            }
            completion?()
        }
    }

    /// Count today's ECG samples.
    func fetchTodayECGCount(completion: (() -> Void)? = nil) {
        let type = HKObjectType.electrocardiogramType()
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, _ in
            let count = samples?.count ?? 0
            let latest = (samples?.first as? HKSample)?.startDate
            DispatchQueue.main.async {
                self.todayECGCount = count
                self.ecgTimestamp = latest ?? .now
            }
            completion?()
        }
        store.execute(query)
    }

    // MARK: - Activity (more)

    /// Fetch today's basal (resting) energy burned.
    func fetchTodayBasalEnergy(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            completion?()
            return
        }
        sumTodayQuantity(type: type, unit: .kilocalorie()) { value, date in
            DispatchQueue.main.async {
                self.todayBasalEnergy = value
                self.basalEnergyTimestamp = date
            }
            completion?()
        }
    }

    /// Fetch today's walking + running distance (meters).
    func fetchTodayDistance(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            completion?()
            return
        }
        sumTodayQuantity(type: type, unit: .meter()) { value, date in
            DispatchQueue.main.async {
                self.todayDistanceMeters = value
                self.distanceTimestamp = date
            }
            completion?()
        }
    }

    /// Fetch today's flights climbed.
    func fetchTodayFlightsClimbed(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else {
            completion?()
            return
        }
        sumTodayQuantity(type: type, unit: .count()) { value, date in
            DispatchQueue.main.async {
                self.todayFlightsClimbed = value
                self.flightsTimestamp = date
            }
            completion?()
        }
    }

    /// Fetch today's actual stand minutes (different from stand-hour count).
    func fetchTodayStandMinutes(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else {
            completion?()
            return
        }
        sumTodayQuantity(type: type, unit: .minute()) { value, date in
            DispatchQueue.main.async {
                self.todayStandMinutes = value
                self.standMinutesTimestamp = date
            }
            completion?()
        }
    }

    /// Fetch today's workout count + total duration.
    func fetchTodayWorkoutSummary(completion: (() -> Void)? = nil) {
        let type = HKObjectType.workoutType()
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            let count = workouts.count
            let totalSec = workouts.reduce(0.0) { $0 + $1.duration }
            let mostRecent = workouts.first?.endDate
            DispatchQueue.main.async {
                self.todayWorkoutCount = count
                self.todayWorkoutMinutes = totalSec / 60.0
                self.workoutTimestamp = mostRecent ?? .now
            }
            completion?()
        }
        store.execute(query)
    }

    // MARK: - Gait / Mobility

    func fetchWalkingSpeed(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) else {
            completion?()
            return
        }
        let unit = HKUnit.meter().unitDivided(by: .second())
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestWalkingSpeed = value
                self.walkingSpeedTimestamp = date
            }
            completion?()
        }
    }

    func fetchWalkingStepLength(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .meterUnit(with: .centi)) { value, date in
            DispatchQueue.main.async {
                self.latestWalkingStepLength = value
                self.walkingStepLengthTimestamp = date
            }
            completion?()
        }
    }

    func fetchWalkingDoubleSupport(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .percent()) { value, date in
            DispatchQueue.main.async {
                self.latestWalkingDoubleSupport = value
                self.walkingDoubleSupportTimestamp = date
            }
            completion?()
        }
    }

    func fetchWalkingAsymmetry(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .percent()) { value, date in
            DispatchQueue.main.async {
                self.latestWalkingAsymmetry = value
                self.walkingAsymmetryTimestamp = date
            }
            completion?()
        }
    }

    func fetchStairAscentSpeed(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed) else {
            completion?()
            return
        }
        let unit = HKUnit.meter().unitDivided(by: .second())
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestStairAscentSpeed = value
                self.stairAscentTimestamp = date
            }
            completion?()
        }
    }

    func fetchStairDescentSpeed(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed) else {
            completion?()
            return
        }
        let unit = HKUnit.meter().unitDivided(by: .second())
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestStairDescentSpeed = value
                self.stairDescentTimestamp = date
            }
            completion?()
        }
    }

    func fetchSixMinuteWalk(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .meter()) { value, date in
            DispatchQueue.main.async {
                self.latestSixMinuteWalk = value
                self.sixMinuteWalkTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Running

    func fetchRunningSpeed(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .runningSpeed) else {
            completion?()
            return
        }
        let unit = HKUnit.meter().unitDivided(by: .second())
        fetchMostRecentWithDate(type: type, unit: unit) { value, date in
            DispatchQueue.main.async {
                self.latestRunningSpeed = value
                self.runningSpeedTimestamp = date
            }
            completion?()
        }
    }

    func fetchRunningPower(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .runningPower) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .watt()) { value, date in
            DispatchQueue.main.async {
                self.latestRunningPower = value
                self.runningPowerTimestamp = date
            }
            completion?()
        }
    }

    func fetchRunningStrideLength(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .runningStrideLength) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .meter()) { value, date in
            DispatchQueue.main.async {
                self.latestRunningStrideLength = value
                self.runningStrideTimestamp = date
            }
            completion?()
        }
    }

    func fetchRunningGroundContact(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .secondUnit(with: .milli)) { value, date in
            DispatchQueue.main.async {
                self.latestRunningGroundContact = value
                self.runningGroundContactTimestamp = date
            }
            completion?()
        }
    }

    func fetchRunningVerticalOsc(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .meterUnit(with: .centi)) { value, date in
            DispatchQueue.main.async {
                self.latestRunningVerticalOsc = value
                self.runningVerticalOscTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Body Composition

    func fetchBodyMass(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .gramUnit(with: .kilo)) { value, date in
            DispatchQueue.main.async {
                self.latestBodyMass = value
                self.bodyMassTimestamp = date
            }
            completion?()
        }
    }

    func fetchBodyMassIndex(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .count()) { value, date in
            DispatchQueue.main.async {
                self.latestBodyMassIndex = value
                self.bmiTimestamp = date
            }
            completion?()
        }
    }

    func fetchBodyFatPercentage(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .percent()) { value, date in
            DispatchQueue.main.async {
                self.latestBodyFatPercentage = value
                self.bodyFatTimestamp = date
            }
            completion?()
        }
    }

    func fetchLeanBodyMass(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .gramUnit(with: .kilo)) { value, date in
            DispatchQueue.main.async {
                self.latestLeanBodyMass = value
                self.leanMassTimestamp = date
            }
            completion?()
        }
    }

    func fetchHeight(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .height) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .meter()) { value, date in
            DispatchQueue.main.async {
                self.latestHeight = value
                self.heightTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Body Temperature (non-sleep)

    func fetchBodyTemperature(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .degreeCelsius()) { value, date in
            DispatchQueue.main.async {
                self.latestBodyTemperature = value
                self.bodyTempTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Beat-to-beat HRV (RMSSD / pNN50)

    /// Fetch the most recent HKHeartbeatSeriesSamples (last 24 h, up to 5 series)
    /// and compute time-domain HRV: RMSSD and pNN50.
    /// RMSSD = root mean square of successive RR-interval differences (in ms).
    /// pNN50 = fraction of successive RR pairs differing by > 50 ms.
    /// Both are gold-standard parasympathetic-tone markers (richer than the aggregated SDNN).
    func fetchHeartbeatSeriesMetrics(completion: (() -> Void)? = nil) {
        let type = HKSeriesType.heartbeat()
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 5,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, error in
            guard let self = self else { completion?(); return }
            if let error = error {
                AuroLog.error("Heartbeat-series fetch error: \(error.localizedDescription)", category: .health)
                completion?()
                return
            }
            guard let series = samples as? [HKHeartbeatSeriesSample], !series.isEmpty else {
                DispatchQueue.main.async {
                    self.latestRMSSD = nil
                    self.latestPNN50 = nil
                    self.latestRRSampleCount = 0
                }
                completion?()
                return
            }

            var rrIntervalsMs: [Double] = []
            let group = DispatchGroup()

            for series in series {
                group.enter()
                var beatTimes: [TimeInterval] = []
                let beatQuery = HKHeartbeatSeriesQuery(heartbeatSeries: series) { _, t, precededByGap, done, _ in
                    // Gaps invalidate the differential, but t itself is still relative to series start.
                    if !precededByGap { beatTimes.append(t) }
                    if done {
                        // Convert successive beat times to RR ms
                        let rr = zip(beatTimes.dropFirst(), beatTimes).map { ($0 - $1) * 1000.0 }
                        rrIntervalsMs.append(contentsOf: rr.filter { $0 > 200 && $0 < 2000 }) // physiological filter
                        group.leave()
                    }
                }
                self.store.execute(beatQuery)
            }

            group.notify(queue: .main) {
                guard rrIntervalsMs.count >= 5 else {
                    self.latestRMSSD = nil
                    self.latestPNN50 = nil
                    self.latestRRSampleCount = rrIntervalsMs.count
                    completion?()
                    return
                }
                // RMSSD
                let diffs = zip(rrIntervalsMs.dropFirst(), rrIntervalsMs).map { $0 - $1 }
                let meanSq = diffs.map { $0 * $0 }.reduce(0, +) / Double(diffs.count)
                let rmssd = sqrt(meanSq)
                // pNN50
                let nn50 = diffs.filter { abs($0) > 50 }.count
                let pnn50 = Double(nn50) / Double(diffs.count)

                self.latestRMSSD = rmssd
                self.latestPNN50 = pnn50
                self.latestRRSampleCount = rrIntervalsMs.count
                self.rmssdTimestamp = .now
                self.pnn50Timestamp = .now
                completion?()
            }
        }
        store.execute(query)
    }

    // MARK: - Sleep Apnea (watchOS 11+)

    /// Sleep apnea (`.appleSleepingBreathingDisturbances`) is iOS-only — the watch HealthKit
    /// API does not expose this category type. The phone app must read it and sync the count
    /// down to the watch via WatchSyncManager. This stub keeps the call site uniform.
    func fetchTodaySleepApneaCount(completion: (() -> Void)? = nil) {
        // No-op on watchOS; value is populated from phone-side sync when available.
        completion?()
    }

    // MARK: - UV / Audio events / Falls / Low fitness

    func fetchUVExposure(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .uvExposure) else {
            completion?()
            return
        }
        fetchMostRecentWithDate(type: type, unit: .count()) { value, date in
            DispatchQueue.main.async {
                self.latestUVExposure = value
                self.uvExposureTimestamp = date
            }
            completion?()
        }
    }

    func fetchTodayEnvAudioEventCount(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .environmentalAudioExposureEvent) else {
            completion?()
            return
        }
        countTodayCategory(type: type) { count, date in
            DispatchQueue.main.async {
                self.todayEnvAudioEventCount = count
                self.envAudioEventTimestamp = date
            }
            completion?()
        }
    }

    func fetchTodayHeadphoneAudioEventCount(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .headphoneAudioExposureEvent) else {
            completion?()
            return
        }
        countTodayCategory(type: type) { count, date in
            DispatchQueue.main.async {
                self.todayHeadphoneAudioEventCount = count
                self.headphoneAudioEventTimestamp = date
            }
            completion?()
        }
    }

    func fetchTodayFallCount(completion: (() -> Void)? = nil) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .numberOfTimesFallen) else {
            completion?()
            return
        }
        sumTodayQuantity(type: type, unit: .count()) { value, date in
            DispatchQueue.main.async {
                self.todayFallCount = value.map { Int($0) }
                self.fallTimestamp = date
            }
            completion?()
        }
    }

    func fetchTodayLowCardioFitnessCount(completion: (() -> Void)? = nil) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .lowCardioFitnessEvent) else {
            completion?()
            return
        }
        countTodayCategory(type: type) { count, date in
            DispatchQueue.main.async {
                self.todayLowCardioFitnessCount = count
                self.lowCardioFitnessTimestamp = date
            }
            completion?()
        }
    }

    // MARK: - Latest Workout Details (with avg/max HR via per-workout query)

    /// Fetch the most recent workout (any type, last 7 days) and its avg/max HR.
    func fetchLatestWorkoutDetails(completion: (() -> Void)? = nil) {
        let type = HKObjectType.workoutType()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1,
                                   sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self = self,
                  let workout = (samples as? [HKWorkout])?.first else {
                completion?()
                return
            }
            // Basic fields
            let typeName = self.workoutTypeName(workout.workoutActivityType)
            let duration = workout.duration
            let kcal: Double?
            if #available(watchOS 11.0, *) {
                let energyType = HKQuantityType(.activeEnergyBurned)
                kcal = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            } else {
                kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
            }

            // Query average + max heart rate during the workout window
            self.fetchHRStatsForWorkout(workout) { avgHR, maxHR in
                DispatchQueue.main.async {
                    self.latestWorkoutType = typeName
                    self.latestWorkoutDuration = duration
                    self.latestWorkoutEnergyKcal = kcal
                    self.latestWorkoutAvgHR = avgHR
                    self.latestWorkoutMaxHR = maxHR
                    self.latestWorkoutDate = workout.endDate
                    self.latestWorkoutTimestamp = workout.endDate
                }
                completion?()
            }
        }
        store.execute(query)
    }

    /// Private — get avg + max HR over the workout's time window.
    private func fetchHRStatsForWorkout(_ workout: HKWorkout, completion: @escaping (Double?, Double?) -> Void) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let query = HKStatisticsQuery(quantityType: hrType, quantitySamplePredicate: predicate,
                                       options: [.discreteAverage, .discreteMax]) { _, stats, _ in
            let unit = HKUnit.count().unitDivided(by: .minute())
            let avg = stats?.averageQuantity()?.doubleValue(for: unit)
            let max = stats?.maximumQuantity()?.doubleValue(for: unit)
            completion(avg, max)
        }
        store.execute(query)
    }

    /// Map HKWorkoutActivityType to a short readable label.
    private func workoutTypeName(_ t: HKWorkoutActivityType) -> String {
        switch t {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .hiking: return "Hike"
        case .swimming: return "Swim"
        case .mindAndBody, .flexibility: return "Mind/Body"
        case .pilates: return "Pilates"
        case .coreTraining: return "Core"
        case .dance: return "Dance"
        case .elliptical: return "Elliptical"
        case .rowing: return "Row"
        case .stairs: return "Stairs"
        case .other: return "Workout"
        default: return "Workout"
        }
    }

    // MARK: - Generic Helpers

    /// Count today's category samples (e.g., high-HR events).
    private func countTodayCategory(type: HKCategoryType, completion: @escaping (Int, Date?) -> Void) {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [sort]) { _, samples, _ in
            let count = samples?.count ?? 0
            let latest = (samples?.first as? HKSample)?.startDate
            completion(count, latest)
        }
        store.execute(query)
    }

    /// Sum a quantity-type's samples from today's start until now.
    private func sumTodayQuantity(type: HKQuantityType, unit: HKUnit, completion: @escaping (Double?, Date?) -> Void) {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                       options: .cumulativeSum) { _, stats, _ in
            let value = stats?.sumQuantity()?.doubleValue(for: unit)
            completion(value, .now)
        }
        store.execute(query)
    }

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
        fetchHistory(type: type, unit: unit, since: start, completion: completion)
    }

    /// Fetch all samples of `type` since a specific date.
    private func fetchHistory(type: HKQuantityType, unit: HKUnit, since start: Date, completion: @escaping ([TimestampedValue]) -> Void) {
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
