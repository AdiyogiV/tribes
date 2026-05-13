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

    /// Timestamped Ojas scores for granular charting: [{"s": score, "t": epochSeconds}]
    @Published var ojasHistory: [[String: Any]] = []

    /// Legacy flat history (kept for sparkline fallback)
    @Published var ojasHistoryFlat: [Int] = []

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

    /// Core Sleep minutes (last night)
    @Published var coreSleepMinutes: Double?

    /// Sleep onset hour as decimal hour (e.g., 22.5 = 10:30 PM)
    @Published var sleepOnsetHour: Double?

    /// Apple stand-hour count for today
    @Published var standHours: Int?

    /// Apple exercise minutes for today
    @Published var exerciseMinutes: Double?

    /// Walking heart-rate average (bpm)
    @Published var walkingHR: Double?

    /// Time spent in daylight today (minutes)
    @Published var daylightMinutes: Double?

    /// Environmental audio exposure (dB, A-weighted)
    @Published var envAudioExposure: Double?

    /// Headphone audio exposure (dB, A-weighted)
    @Published var headphoneAudioExposure: Double?

    // Cardiac events
    @Published var afibBurden: Double?
    @Published var todayHighHRCount: Int?
    @Published var todayLowHRCount: Int?
    @Published var todayIrregularRhythmCount: Int?
    @Published var todayECGCount: Int?

    // Activity (more)
    @Published var basalEnergy: Double?
    @Published var todayDistanceMeters: Double?
    @Published var todayFlightsClimbed: Double?
    @Published var todayStandMinutes: Double?
    @Published var todayWorkoutCount: Int?
    @Published var todayWorkoutMinutes: Double?

    // Gait / mobility
    @Published var walkingSpeed: Double?
    @Published var walkingStepLength: Double?
    @Published var walkingDoubleSupport: Double?
    @Published var walkingAsymmetry: Double?
    @Published var stairAscentSpeed: Double?
    @Published var stairDescentSpeed: Double?
    @Published var sixMinuteWalk: Double?

    // Running
    @Published var runningSpeed: Double?
    @Published var runningPower: Double?
    @Published var runningStrideLength: Double?
    @Published var runningGroundContact: Double?
    @Published var runningVerticalOsc: Double?

    // Body composition
    @Published var bodyMass: Double?
    @Published var bodyMassIndex: Double?
    @Published var bodyFatPercentage: Double?
    @Published var leanBodyMass: Double?
    @Published var height: Double?

    // Body temperature (non-sleep)
    @Published var bodyTemperature: Double?

    // Beat-to-beat HRV (HKHeartbeatSeriesSample-derived)
    @Published var latestRMSSD: Double?
    @Published var latestPNN50: Double?
    @Published var latestRRSampleCount: Int?

    // Sleep / respiration health
    @Published var todaySleepApneaCount: Int?

    // Environment exposure
    @Published var latestUVExposure: Double?
    @Published var todayEnvAudioEventCount: Int?
    @Published var todayHeadphoneAudioEventCount: Int?

    // Fall / cardio fitness alerts
    @Published var todayFallCount: Int?
    @Published var todayLowCardioFitnessCount: Int?

    // Latest workout details
    @Published var latestWorkoutType: String?
    @Published var latestWorkoutDuration: Double?
    @Published var latestWorkoutEnergyKcal: Double?
    @Published var latestWorkoutAvgHR: Double?
    @Published var latestWorkoutMaxHR: Double?
    @Published var latestWorkoutDate: Date?

    /// Batch of recent HR readings since last sync (timestamped).
    /// Populated by fetchHeartRateReadings(since:) for zero-loss capture.
    var recentHeartRateReadings: [TimestampedValue] = []

    /// Batch of recent HRV readings since last sync.
    var recentHRVReadings: [TimestampedValue] = []

    /// Batch of recent SpO2 readings since last sync.
    var recentSpO2Readings: [TimestampedValue] = []

    /// Batch of recent respiratory rate readings since last sync.
    var recentRespRateReadings: [TimestampedValue] = []

    /// Batch of recent resting HR readings since last sync.
    var recentRestingHRReadings: [TimestampedValue] = []

    /// When we last batch-synced HR readings to the phone.
    var lastHRBatchSync: Date {
        get { defaults.object(forKey: key("lastHRBatchSync")) as? Date ?? Date.distantPast }
        set { defaults.set(newValue, forKey: key("lastHRBatchSync")) }
    }

    /// When we last batch-synced other signals to the phone.
    var lastSignalBatchSync: Date {
        get { defaults.object(forKey: key("lastSignalBatchSync")) as? Date ?? Date.distantPast }
        set { defaults.set(newValue, forKey: key("lastSignalBatchSync")) }
    }

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
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            ojasHistory = decoded
        }
        if let data = defaults.data(forKey: key("ojasHistoryFlat")),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            ojasHistoryFlat = decoded
        }
        let ojasTs = defaults.double(forKey: key("ojasComputedAt"))
        ojasComputedAt = ojasTs > 0 ? Date(timeIntervalSince1970: ojasTs) : nil

        // Body signals
        sleepHours = defaults.object(forKey: key("sleepHours")) as? Double
        deepSleepMinutes = defaults.object(forKey: key("deepSleepMins")) as? Double
        remSleepMinutes = defaults.object(forKey: key("remSleepMins")) as? Double
        coreSleepMinutes = defaults.object(forKey: key("coreSleepMins")) as? Double
        sleepOnsetHour = defaults.object(forKey: key("sleepOnset")) as? Double
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
        standHours = defaults.object(forKey: key("standHours")) as? Int
        exerciseMinutes = defaults.object(forKey: key("exerciseMins")) as? Double
        walkingHR = defaults.object(forKey: key("walkingHR")) as? Double
        daylightMinutes = defaults.object(forKey: key("daylightMins")) as? Double
        envAudioExposure = defaults.object(forKey: key("envAudio")) as? Double
        headphoneAudioExposure = defaults.object(forKey: key("headAudio")) as? Double
        afibBurden = defaults.object(forKey: key("afib")) as? Double
        todayHighHRCount = defaults.object(forKey: key("highHRCount")) as? Int
        todayLowHRCount = defaults.object(forKey: key("lowHRCount")) as? Int
        todayIrregularRhythmCount = defaults.object(forKey: key("irregCount")) as? Int
        todayECGCount = defaults.object(forKey: key("ecgCount")) as? Int
        basalEnergy = defaults.object(forKey: key("basalEnergy")) as? Double
        todayDistanceMeters = defaults.object(forKey: key("distance")) as? Double
        todayFlightsClimbed = defaults.object(forKey: key("flights")) as? Double
        todayStandMinutes = defaults.object(forKey: key("standMins")) as? Double
        todayWorkoutCount = defaults.object(forKey: key("workoutCount")) as? Int
        todayWorkoutMinutes = defaults.object(forKey: key("workoutMins")) as? Double
        walkingSpeed = defaults.object(forKey: key("walkSpeed")) as? Double
        walkingStepLength = defaults.object(forKey: key("stepLen")) as? Double
        walkingDoubleSupport = defaults.object(forKey: key("dblSup")) as? Double
        walkingAsymmetry = defaults.object(forKey: key("asym")) as? Double
        stairAscentSpeed = defaults.object(forKey: key("stairUp")) as? Double
        stairDescentSpeed = defaults.object(forKey: key("stairDn")) as? Double
        sixMinuteWalk = defaults.object(forKey: key("sixMinWalk")) as? Double
        runningSpeed = defaults.object(forKey: key("runSpeed")) as? Double
        runningPower = defaults.object(forKey: key("runPower")) as? Double
        runningStrideLength = defaults.object(forKey: key("runStride")) as? Double
        runningGroundContact = defaults.object(forKey: key("runGC")) as? Double
        runningVerticalOsc = defaults.object(forKey: key("runVO")) as? Double
        bodyMass = defaults.object(forKey: key("bodyMass")) as? Double
        bodyMassIndex = defaults.object(forKey: key("bmi")) as? Double
        bodyFatPercentage = defaults.object(forKey: key("bodyFat")) as? Double
        leanBodyMass = defaults.object(forKey: key("leanMass")) as? Double
        height = defaults.object(forKey: key("height")) as? Double
        bodyTemperature = defaults.object(forKey: key("bodyTemp")) as? Double

        // Beat-to-beat HRV, env exposure, fall/cardio alerts, workout
        latestRMSSD = defaults.object(forKey: key("rmssd")) as? Double
        latestPNN50 = defaults.object(forKey: key("pnn50")) as? Double
        latestRRSampleCount = defaults.object(forKey: key("rrCount")) as? Int
        todaySleepApneaCount = defaults.object(forKey: key("apneaCount")) as? Int
        latestUVExposure = defaults.object(forKey: key("uvExposure")) as? Double
        todayEnvAudioEventCount = defaults.object(forKey: key("envAudioEvt")) as? Int
        todayHeadphoneAudioEventCount = defaults.object(forKey: key("headAudioEvt")) as? Int
        todayFallCount = defaults.object(forKey: key("fallCount")) as? Int
        todayLowCardioFitnessCount = defaults.object(forKey: key("lowFitCount")) as? Int
        latestWorkoutType = defaults.string(forKey: key("workoutType"))
        latestWorkoutDuration = defaults.object(forKey: key("workoutDur")) as? Double
        latestWorkoutEnergyKcal = defaults.object(forKey: key("workoutKcal")) as? Double
        latestWorkoutAvgHR = defaults.object(forKey: key("workoutAvgHR")) as? Double
        latestWorkoutMaxHR = defaults.object(forKey: key("workoutMaxHR")) as? Double
        let woTs = defaults.double(forKey: key("workoutDate"))
        latestWorkoutDate = woTs > 0 ? Date(timeIntervalSince1970: woTs) : nil

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
        restoreTimestamp("standTs", to: &standHoursTimestamp)
        restoreTimestamp("exerciseTs", to: &exerciseMinutesTimestamp)
        restoreTimestamp("walkHRTs", to: &walkingHRTimestamp)
        restoreTimestamp("daylightTs", to: &daylightTimestamp)
        restoreTimestamp("envAudioTs", to: &envAudioTimestamp)
        restoreTimestamp("headAudioTs", to: &headphoneAudioTimestamp)
        restoreTimestamp("afibTs", to: &afibTimestamp)
        restoreTimestamp("highHRTs", to: &highHREventTimestamp)
        restoreTimestamp("lowHRTs", to: &lowHREventTimestamp)
        restoreTimestamp("irregTs", to: &irregularRhythmTimestamp)
        restoreTimestamp("ecgTs", to: &ecgTimestamp)
        restoreTimestamp("basalTs", to: &basalEnergyTimestamp)
        restoreTimestamp("distTs", to: &distanceTimestamp)
        restoreTimestamp("flightsTs", to: &flightsTimestamp)
        restoreTimestamp("standMinTs", to: &standMinutesTimestamp)
        restoreTimestamp("workoutTs", to: &workoutTimestamp)
        restoreTimestamp("walkSpdTs", to: &walkingSpeedTimestamp)
        restoreTimestamp("stepLenTs", to: &walkingStepLengthTimestamp)
        restoreTimestamp("dblSupTs", to: &walkingDoubleSupportTimestamp)
        restoreTimestamp("asymTs", to: &walkingAsymmetryTimestamp)
        restoreTimestamp("stairUpTs", to: &stairAscentTimestamp)
        restoreTimestamp("stairDnTs", to: &stairDescentTimestamp)
        restoreTimestamp("sixMinTs", to: &sixMinuteWalkTimestamp)
        restoreTimestamp("runSpdTs", to: &runningSpeedTimestamp)
        restoreTimestamp("runPwrTs", to: &runningPowerTimestamp)
        restoreTimestamp("runStrTs", to: &runningStrideTimestamp)
        restoreTimestamp("runGCTs", to: &runningGroundContactTimestamp)
        restoreTimestamp("runVOTs", to: &runningVerticalOscTimestamp)
        restoreTimestamp("massTs", to: &bodyMassTimestamp)
        restoreTimestamp("bmiTs", to: &bmiTimestamp)
        restoreTimestamp("fatTs", to: &bodyFatTimestamp)
        restoreTimestamp("leanTs", to: &leanMassTimestamp)
        restoreTimestamp("heightTs", to: &heightTimestamp)
        restoreTimestamp("bodyTempTs", to: &bodyTempTimestamp)
        restoreTimestamp("rmssdTs", to: &rmssdTimestamp)
        restoreTimestamp("pnn50Ts", to: &pnn50Timestamp)
        restoreTimestamp("apneaTs", to: &sleepApneaTimestamp)
        restoreTimestamp("uvTs", to: &uvExposureTimestamp)
        restoreTimestamp("envAudioEvtTs", to: &envAudioEventTimestamp)
        restoreTimestamp("headAudioEvtTs", to: &headphoneAudioEventTimestamp)
        restoreTimestamp("fallTs", to: &fallTimestamp)
        restoreTimestamp("lowFitTs", to: &lowCardioFitnessTimestamp)
        restoreTimestamp("workoutDetailsTs", to: &latestWorkoutTimestamp)
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

        // Append timestamped entry (keep last 48 — ~24h at 30-min intervals)
        let entry: [String: Any] = ["s": result.score, "t": result.computedAt.timeIntervalSince1970]
        ojasHistory.append(entry)
        if ojasHistory.count > 48 { ojasHistory.removeFirst(ojasHistory.count - 48) }

        // Also maintain flat array for sparkline fallback
        ojasHistoryFlat.append(result.score)
        if ojasHistoryFlat.count > 48 { ojasHistoryFlat.removeFirst(ojasHistoryFlat.count - 48) }

        defaults.set(ojasScore, forKey: key("ojasScore"))
        defaults.set(ojasSummary, forKey: key("ojasSummary"))
        defaults.set(agniType, forKey: key("agniType"))
        defaults.set(result.computedAt.timeIntervalSince1970, forKey: key("ojasComputedAt"))
        if let encoded = try? JSONSerialization.data(withJSONObject: ojasHistory) {
            defaults.set(encoded, forKey: key("ojasHistory"))
        }
        if let encoded = try? JSONEncoder().encode(ojasHistoryFlat) {
            defaults.set(encoded, forKey: key("ojasHistoryFlat"))
        }
    }

    /// Compute and store Ojas from current body signals.
    /// Call this during every health refresh cycle for granular data.
    func computeAndStoreOjas(from health: HealthKitManager) {
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

        let healthBase = HealthBaseline.populationDefaults
        if let result = OjasEngine.computeOjas(signals: signals, baseline: healthBase) {
            updateOjas(result)
            AuroLog.ojasComputed(score: result.score, signalCount: result.signalCount, reliable: result.isReliable)
        }
    }

    /// Update ALL body signals from HealthKitManager readings.
    func updateBodySignals(from health: HealthKitManager) {
        sleepHours = health.lastSleepDuration.map { $0 / 3600.0 }
        deepSleepMinutes = health.lastDeepSleepMinutes
        remSleepMinutes = health.lastREMSleepMinutes
        coreSleepMinutes = health.lastCoreSleepMinutes
        sleepOnsetHour = health.lastSleepOnsetHour
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
        standHours = health.todayStandHours
        exerciseMinutes = health.todayExerciseMinutes
        walkingHR = health.latestWalkingHR
        daylightMinutes = health.todayDaylightMinutes
        envAudioExposure = health.latestEnvAudioExposure
        headphoneAudioExposure = health.latestHeadphoneAudioExposure

        afibBurden = health.latestAFibBurden
        todayHighHRCount = health.todayHighHRCount
        todayLowHRCount = health.todayLowHRCount
        todayIrregularRhythmCount = health.todayIrregularRhythmCount
        todayECGCount = health.todayECGCount

        basalEnergy = health.todayBasalEnergy
        todayDistanceMeters = health.todayDistanceMeters
        todayFlightsClimbed = health.todayFlightsClimbed
        todayStandMinutes = health.todayStandMinutes
        todayWorkoutCount = health.todayWorkoutCount
        todayWorkoutMinutes = health.todayWorkoutMinutes

        walkingSpeed = health.latestWalkingSpeed
        walkingStepLength = health.latestWalkingStepLength
        walkingDoubleSupport = health.latestWalkingDoubleSupport
        walkingAsymmetry = health.latestWalkingAsymmetry
        stairAscentSpeed = health.latestStairAscentSpeed
        stairDescentSpeed = health.latestStairDescentSpeed
        sixMinuteWalk = health.latestSixMinuteWalk

        runningSpeed = health.latestRunningSpeed
        runningPower = health.latestRunningPower
        runningStrideLength = health.latestRunningStrideLength
        runningGroundContact = health.latestRunningGroundContact
        runningVerticalOsc = health.latestRunningVerticalOsc

        bodyMass = health.latestBodyMass
        bodyMassIndex = health.latestBodyMassIndex
        bodyFatPercentage = health.latestBodyFatPercentage
        leanBodyMass = health.latestLeanBodyMass
        height = health.latestHeight

        bodyTemperature = health.latestBodyTemperature

        // Beat-to-beat HRV + new health signals
        latestRMSSD = health.latestRMSSD
        latestPNN50 = health.latestPNN50
        latestRRSampleCount = health.latestRRSampleCount
        todaySleepApneaCount = health.todaySleepApneaCount
        latestUVExposure = health.latestUVExposure
        todayEnvAudioEventCount = health.todayEnvAudioEventCount
        todayHeadphoneAudioEventCount = health.todayHeadphoneAudioEventCount
        todayFallCount = health.todayFallCount
        todayLowCardioFitnessCount = health.todayLowCardioFitnessCount
        latestWorkoutType = health.latestWorkoutType
        latestWorkoutDuration = health.latestWorkoutDuration
        latestWorkoutEnergyKcal = health.latestWorkoutEnergyKcal
        latestWorkoutAvgHR = health.latestWorkoutAvgHR
        latestWorkoutMaxHR = health.latestWorkoutMaxHR
        latestWorkoutDate = health.latestWorkoutDate

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
        standHoursTimestamp = health.standHoursTimestamp
        exerciseMinutesTimestamp = health.exerciseMinutesTimestamp
        walkingHRTimestamp = health.walkingHRTimestamp
        daylightTimestamp = health.daylightTimestamp
        envAudioTimestamp = health.envAudioTimestamp
        headphoneAudioTimestamp = health.headphoneAudioTimestamp
        afibTimestamp = health.afibTimestamp
        highHREventTimestamp = health.highHREventTimestamp
        lowHREventTimestamp = health.lowHREventTimestamp
        irregularRhythmTimestamp = health.irregularRhythmTimestamp
        ecgTimestamp = health.ecgTimestamp
        basalEnergyTimestamp = health.basalEnergyTimestamp
        distanceTimestamp = health.distanceTimestamp
        flightsTimestamp = health.flightsTimestamp
        standMinutesTimestamp = health.standMinutesTimestamp
        workoutTimestamp = health.workoutTimestamp
        walkingSpeedTimestamp = health.walkingSpeedTimestamp
        walkingStepLengthTimestamp = health.walkingStepLengthTimestamp
        walkingDoubleSupportTimestamp = health.walkingDoubleSupportTimestamp
        walkingAsymmetryTimestamp = health.walkingAsymmetryTimestamp
        stairAscentTimestamp = health.stairAscentTimestamp
        stairDescentTimestamp = health.stairDescentTimestamp
        sixMinuteWalkTimestamp = health.sixMinuteWalkTimestamp
        runningSpeedTimestamp = health.runningSpeedTimestamp
        runningPowerTimestamp = health.runningPowerTimestamp
        runningStrideTimestamp = health.runningStrideTimestamp
        runningGroundContactTimestamp = health.runningGroundContactTimestamp
        runningVerticalOscTimestamp = health.runningVerticalOscTimestamp
        bodyMassTimestamp = health.bodyMassTimestamp
        bmiTimestamp = health.bmiTimestamp
        bodyFatTimestamp = health.bodyFatTimestamp
        leanMassTimestamp = health.leanMassTimestamp
        heightTimestamp = health.heightTimestamp
        bodyTempTimestamp = health.bodyTempTimestamp
        rmssdTimestamp = health.rmssdTimestamp
        pnn50Timestamp = health.pnn50Timestamp
        sleepApneaTimestamp = health.sleepApneaTimestamp
        uvExposureTimestamp = health.uvExposureTimestamp
        envAudioEventTimestamp = health.envAudioEventTimestamp
        headphoneAudioEventTimestamp = health.headphoneAudioEventTimestamp
        fallTimestamp = health.fallTimestamp
        lowCardioFitnessTimestamp = health.lowCardioFitnessTimestamp
        latestWorkoutTimestamp = health.latestWorkoutTimestamp
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
        // Ayurveda signals
        if let v = ojasScore { payload["ojasScore"] = v }
        if let v = ojasSummary { payload["ojasSummary"] = v }
        if let v = agniType { payload["agniType"] = v }
        if let v = nadiDominantDosha { payload["nadiDosha"] = v }
        // Core vitals
        if let v = currentHeartRate { payload["heartRate"] = v }
        if let v = latestHRV { payload["hrv"] = v }
        if let v = latestRestingHR { payload["restingHR"] = v }
        if let v = spO2 { payload["spO2"] = v }
        if let v = respiratoryRate { payload["respRate"] = v }
        // Batch HR readings — every sample since last sync (zero data loss)
        if !recentHeartRateReadings.isEmpty {
            payload["heartRateReadings"] = recentHeartRateReadings.map {
                ["v": $0.value, "t": $0.date.timeIntervalSince1970]
            }
        }
        // Batch HRV readings
        if !recentHRVReadings.isEmpty {
            payload["hrvReadings"] = recentHRVReadings.map {
                ["v": $0.value, "t": $0.date.timeIntervalSince1970]
            }
        }
        // Batch SpO2 readings (HealthKit stores as fraction, multiply by 100)
        if !recentSpO2Readings.isEmpty {
            payload["spO2Readings"] = recentSpO2Readings.map {
                ["v": $0.value * 100.0, "t": $0.date.timeIntervalSince1970]
            }
        }
        // Batch respiratory rate readings
        if !recentRespRateReadings.isEmpty {
            payload["respRateReadings"] = recentRespRateReadings.map {
                ["v": $0.value, "t": $0.date.timeIntervalSince1970]
            }
        }
        // Batch resting HR readings
        if !recentRestingHRReadings.isEmpty {
            payload["restingHRReadings"] = recentRestingHRReadings.map {
                ["v": $0.value, "t": $0.date.timeIntervalSince1970]
            }
        }
        // Activity
        if let v = todaySteps { payload["steps"] = v }
        if let v = activeEnergy { payload["activeEnergy"] = v }
        if let v = mindfulMinutes { payload["mindfulMins"] = v }
        // Fitness
        if let v = vo2Max { payload["vo2Max"] = v }
        if let v = hrRecovery { payload["hrRecovery"] = v }
        if let v = walkingSteadiness { payload["walkingSteadiness"] = v }
        // Sleep
        if let v = sleepHours { payload["sleepHours"] = v }
        if let v = deepSleepMinutes { payload["deepSleepMins"] = v }
        if let v = remSleepMinutes { payload["remSleepMins"] = v }
        if let v = coreSleepMinutes { payload["coreSleepMins"] = v }
        if let v = sleepOnsetHour { payload["sleepOnset"] = v }
        // Activity rings extras
        if let v = standHours { payload["standHours"] = v }
        if let v = exerciseMinutes { payload["exerciseMins"] = v }
        if let v = walkingHR { payload["walkingHR"] = v }
        // Environment / circadian
        if let v = daylightMinutes { payload["daylightMins"] = v }
        if let v = envAudioExposure { payload["envAudio"] = v }
        if let v = headphoneAudioExposure { payload["headAudio"] = v }
        // Cardiac events
        if let v = afibBurden { payload["afibBurden"] = v }
        if let v = todayHighHRCount { payload["highHRCount"] = v }
        if let v = todayLowHRCount { payload["lowHRCount"] = v }
        if let v = todayIrregularRhythmCount { payload["irregCount"] = v }
        if let v = todayECGCount { payload["ecgCount"] = v }
        // Activity (more)
        if let v = basalEnergy { payload["basalEnergy"] = v }
        if let v = todayDistanceMeters { payload["distance"] = v }
        if let v = todayFlightsClimbed { payload["flights"] = v }
        if let v = todayStandMinutes { payload["standMins"] = v }
        if let v = todayWorkoutCount { payload["workoutCount"] = v }
        if let v = todayWorkoutMinutes { payload["workoutMins"] = v }
        // Gait / mobility
        if let v = walkingSpeed { payload["walkSpeed"] = v }
        if let v = walkingStepLength { payload["stepLen"] = v }
        if let v = walkingDoubleSupport { payload["dblSup"] = v }
        if let v = walkingAsymmetry { payload["asym"] = v }
        if let v = stairAscentSpeed { payload["stairUp"] = v }
        if let v = stairDescentSpeed { payload["stairDn"] = v }
        if let v = sixMinuteWalk { payload["sixMinWalk"] = v }
        // Running
        if let v = runningSpeed { payload["runSpeed"] = v }
        if let v = runningPower { payload["runPower"] = v }
        if let v = runningStrideLength { payload["runStride"] = v }
        if let v = runningGroundContact { payload["runGC"] = v }
        if let v = runningVerticalOsc { payload["runVO"] = v }
        // Body composition
        if let v = bodyMass { payload["bodyMass"] = v }
        if let v = bodyMassIndex { payload["bmi"] = v }
        if let v = bodyFatPercentage { payload["bodyFat"] = v }
        if let v = leanBodyMass { payload["leanMass"] = v }
        if let v = height { payload["height"] = v }
        // Body
        if let v = bodyTemperature { payload["bodyTemp"] = v }
        if let v = wristTempDeviation { payload["wristTemp"] = v }
        // Beat-to-beat HRV (HKHeartbeatSeriesSample-derived)
        if let v = latestRMSSD { payload["rmssd"] = v }
        if let v = latestPNN50 { payload["pnn50"] = v }
        if let v = latestRRSampleCount { payload["rrSamples"] = v }
        // Breathing / environment
        if let v = todaySleepApneaCount { payload["apneaCount"] = v }
        if let v = latestUVExposure { payload["uvExposure"] = v }
        if let v = todayEnvAudioEventCount { payload["envAudioEvents"] = v }
        if let v = todayHeadphoneAudioEventCount { payload["headAudioEvents"] = v }
        // Fall / cardio fitness alerts
        if let v = todayFallCount { payload["fallCount"] = v }
        if let v = todayLowCardioFitnessCount { payload["lowCardioFitCount"] = v }
        // Latest workout details
        if let v = latestWorkoutType { payload["workoutType"] = v }
        if let v = latestWorkoutDuration { payload["workoutDuration"] = v }
        if let v = latestWorkoutEnergyKcal { payload["workoutKcal"] = v }
        if let v = latestWorkoutAvgHR { payload["workoutAvgHR"] = v }
        if let v = latestWorkoutMaxHR { payload["workoutMaxHR"] = v }
        if let d = latestWorkoutDate { payload["workoutDate"] = d.timeIntervalSince1970 }
        if !ojasHistory.isEmpty { payload["ojasHistory"] = ojasHistory }
        if !ojasHistoryFlat.isEmpty { payload["ojasHistoryFlat"] = ojasHistoryFlat }
        payload["timestamp"] = Date.now.timeIntervalSince1970

        // Per-signal timestamps: when HealthKit actually recorded each metric.
        // Without these, the phone uses sync-time which creates misleading charts.
        var signalTimestamps: [String: Double] = [:]
        if let t = heartRateTimestamp { signalTimestamps["hr"] = t.timeIntervalSince1970 }
        if let t = hrvTimestamp { signalTimestamps["hrv"] = t.timeIntervalSince1970 }
        if let t = spO2Timestamp { signalTimestamps["spo2"] = t.timeIntervalSince1970 }
        if let t = respiratoryRateTimestamp { signalTimestamps["resp"] = t.timeIntervalSince1970 }
        if let t = stepsTimestamp { signalTimestamps["steps"] = t.timeIntervalSince1970 }
        if let t = activeEnergyTimestamp { signalTimestamps["energy"] = t.timeIntervalSince1970 }
        if let t = vo2MaxTimestamp { signalTimestamps["vo2"] = t.timeIntervalSince1970 }
        if let t = hrRecoveryTimestamp { signalTimestamps["recovery"] = t.timeIntervalSince1970 }
        if let t = walkingSteadinessTimestamp { signalTimestamps["steadiness"] = t.timeIntervalSince1970 }
        if let t = sleepTimestamp { signalTimestamps["sleep"] = t.timeIntervalSince1970 }
        if let t = wristTempTimestamp { signalTimestamps["temp"] = t.timeIntervalSince1970 }
        if let t = mindfulTimestamp { signalTimestamps["mindful"] = t.timeIntervalSince1970 }
        if !signalTimestamps.isEmpty {
            payload["signalTimestamps"] = signalTimestamps
        }

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
        defaults.set(coreSleepMinutes, forKey: key("coreSleepMins"))
        defaults.set(sleepOnsetHour, forKey: key("sleepOnset"))
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
        defaults.set(standHours, forKey: key("standHours"))
        defaults.set(exerciseMinutes, forKey: key("exerciseMins"))
        defaults.set(walkingHR, forKey: key("walkingHR"))
        defaults.set(daylightMinutes, forKey: key("daylightMins"))
        defaults.set(envAudioExposure, forKey: key("envAudio"))
        defaults.set(headphoneAudioExposure, forKey: key("headAudio"))
        defaults.set(afibBurden, forKey: key("afib"))
        defaults.set(todayHighHRCount, forKey: key("highHRCount"))
        defaults.set(todayLowHRCount, forKey: key("lowHRCount"))
        defaults.set(todayIrregularRhythmCount, forKey: key("irregCount"))
        defaults.set(todayECGCount, forKey: key("ecgCount"))
        defaults.set(basalEnergy, forKey: key("basalEnergy"))
        defaults.set(todayDistanceMeters, forKey: key("distance"))
        defaults.set(todayFlightsClimbed, forKey: key("flights"))
        defaults.set(todayStandMinutes, forKey: key("standMins"))
        defaults.set(todayWorkoutCount, forKey: key("workoutCount"))
        defaults.set(todayWorkoutMinutes, forKey: key("workoutMins"))
        defaults.set(walkingSpeed, forKey: key("walkSpeed"))
        defaults.set(walkingStepLength, forKey: key("stepLen"))
        defaults.set(walkingDoubleSupport, forKey: key("dblSup"))
        defaults.set(walkingAsymmetry, forKey: key("asym"))
        defaults.set(stairAscentSpeed, forKey: key("stairUp"))
        defaults.set(stairDescentSpeed, forKey: key("stairDn"))
        defaults.set(sixMinuteWalk, forKey: key("sixMinWalk"))
        defaults.set(runningSpeed, forKey: key("runSpeed"))
        defaults.set(runningPower, forKey: key("runPower"))
        defaults.set(runningStrideLength, forKey: key("runStride"))
        defaults.set(runningGroundContact, forKey: key("runGC"))
        defaults.set(runningVerticalOsc, forKey: key("runVO"))
        defaults.set(bodyMass, forKey: key("bodyMass"))
        defaults.set(bodyMassIndex, forKey: key("bmi"))
        defaults.set(bodyFatPercentage, forKey: key("bodyFat"))
        defaults.set(leanBodyMass, forKey: key("leanMass"))
        defaults.set(height, forKey: key("height"))
        defaults.set(bodyTemperature, forKey: key("bodyTemp"))

        // Beat-to-beat HRV + new signals
        defaults.set(latestRMSSD, forKey: key("rmssd"))
        defaults.set(latestPNN50, forKey: key("pnn50"))
        defaults.set(latestRRSampleCount, forKey: key("rrCount"))
        defaults.set(todaySleepApneaCount, forKey: key("apneaCount"))
        defaults.set(latestUVExposure, forKey: key("uvExposure"))
        defaults.set(todayEnvAudioEventCount, forKey: key("envAudioEvt"))
        defaults.set(todayHeadphoneAudioEventCount, forKey: key("headAudioEvt"))
        defaults.set(todayFallCount, forKey: key("fallCount"))
        defaults.set(todayLowCardioFitnessCount, forKey: key("lowFitCount"))
        defaults.set(latestWorkoutType, forKey: key("workoutType"))
        defaults.set(latestWorkoutDuration, forKey: key("workoutDur"))
        defaults.set(latestWorkoutEnergyKcal, forKey: key("workoutKcal"))
        defaults.set(latestWorkoutAvgHR, forKey: key("workoutAvgHR"))
        defaults.set(latestWorkoutMaxHR, forKey: key("workoutMaxHR"))
        if let d = latestWorkoutDate {
            defaults.set(d.timeIntervalSince1970, forKey: key("workoutDate"))
        }

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
        saveTimestamp(standHoursTimestamp, key: "standTs")
        saveTimestamp(exerciseMinutesTimestamp, key: "exerciseTs")
        saveTimestamp(walkingHRTimestamp, key: "walkHRTs")
        saveTimestamp(daylightTimestamp, key: "daylightTs")
        saveTimestamp(envAudioTimestamp, key: "envAudioTs")
        saveTimestamp(headphoneAudioTimestamp, key: "headAudioTs")
        saveTimestamp(afibTimestamp, key: "afibTs")
        saveTimestamp(highHREventTimestamp, key: "highHRTs")
        saveTimestamp(lowHREventTimestamp, key: "lowHRTs")
        saveTimestamp(irregularRhythmTimestamp, key: "irregTs")
        saveTimestamp(ecgTimestamp, key: "ecgTs")
        saveTimestamp(basalEnergyTimestamp, key: "basalTs")
        saveTimestamp(distanceTimestamp, key: "distTs")
        saveTimestamp(flightsTimestamp, key: "flightsTs")
        saveTimestamp(standMinutesTimestamp, key: "standMinTs")
        saveTimestamp(workoutTimestamp, key: "workoutTs")
        saveTimestamp(walkingSpeedTimestamp, key: "walkSpdTs")
        saveTimestamp(walkingStepLengthTimestamp, key: "stepLenTs")
        saveTimestamp(walkingDoubleSupportTimestamp, key: "dblSupTs")
        saveTimestamp(walkingAsymmetryTimestamp, key: "asymTs")
        saveTimestamp(stairAscentTimestamp, key: "stairUpTs")
        saveTimestamp(stairDescentTimestamp, key: "stairDnTs")
        saveTimestamp(sixMinuteWalkTimestamp, key: "sixMinTs")
        saveTimestamp(runningSpeedTimestamp, key: "runSpdTs")
        saveTimestamp(runningPowerTimestamp, key: "runPwrTs")
        saveTimestamp(runningStrideTimestamp, key: "runStrTs")
        saveTimestamp(runningGroundContactTimestamp, key: "runGCTs")
        saveTimestamp(runningVerticalOscTimestamp, key: "runVOTs")
        saveTimestamp(bodyMassTimestamp, key: "massTs")
        saveTimestamp(bmiTimestamp, key: "bmiTs")
        saveTimestamp(bodyFatTimestamp, key: "fatTs")
        saveTimestamp(leanMassTimestamp, key: "leanTs")
        saveTimestamp(heightTimestamp, key: "heightTs")
        saveTimestamp(bodyTempTimestamp, key: "bodyTempTs")
        saveTimestamp(rmssdTimestamp, key: "rmssdTs")
        saveTimestamp(pnn50Timestamp, key: "pnn50Ts")
        saveTimestamp(sleepApneaTimestamp, key: "apneaTs")
        saveTimestamp(uvExposureTimestamp, key: "uvTs")
        saveTimestamp(envAudioEventTimestamp, key: "envAudioEvtTs")
        saveTimestamp(headphoneAudioEventTimestamp, key: "headAudioEvtTs")
        saveTimestamp(fallTimestamp, key: "fallTs")
        saveTimestamp(lowCardioFitnessTimestamp, key: "lowFitTs")
        saveTimestamp(latestWorkoutTimestamp, key: "workoutDetailsTs")
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
