import Foundation
import HealthKit
import Combine

/// Manages HealthKit data access on the watch.
///
/// Reads:
///   - Heart Rate Variability (SDNN) → primary Nadi signal
///   - Resting Heart Rate → pulse speed
///   - Heart Rate → current rate
///   - Blood Oxygen (SpO2) → Pranavaha Srotas (Phase 4)
///   - Respiratory Rate → Prana Vayu (Phase 4)
///   - Sleep Analysis → Nidra (Phase 2)
///   - Wrist Temperature → Pitta/Sparsha (Phase 3)
///   - VO2 Max → Ojas/Bala (Phase 4)
///   - Walking Steadiness → Mamsa Dhatu (Phase 4)
///
/// Architecture: thin HealthKit wrapper. Analysis logic lives in NadiEngine.
class HealthKitManager: ObservableObject {

    let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var latestHRV: Double?          // SDNN in ms
    @Published var latestRestingHR: Double?     // BPM
    @Published var latestHeartRate: Double?     // BPM (current)

    /// Types we read — start minimal, expand per phase.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        // Phase 1: Core Nadi signals
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(rhr)
        }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(hr)
        }

        // Phase 2: Sleep
        // types.insert(HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!)

        // Phase 3: Temperature, SpO2
        // types.insert(HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!)
        // types.insert(HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!)

        // Phase 4: VO2 Max, Respiratory Rate, Walking metrics
        // types.insert(HKQuantityType.quantityType(forIdentifier: .vo2Max)!)
        // types.insert(HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!)
        // types.insert(HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!)

        return types
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⌚🏥 HealthKit not available")
            return
        }

        store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
            }
            if let error = error {
                print("⌚🏥 Auth error: \(error.localizedDescription)")
            } else {
                print("⌚🏥 HealthKit authorized: \(success)")
                if success {
                    self.fetchLatestReadings()
                }
            }
        }
    }

    // MARK: - Data Fetching

    /// Fetch the most recent readings for Nadi analysis.
    func fetchLatestReadings() {
        fetchLatestHRV()
        fetchLatestRestingHR()
        fetchLatestHeartRate()
    }

    /// Fetch HRV (SDNN) — the primary Nadi signal.
    func fetchLatestHRV() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        fetchMostRecent(type: type, unit: HKUnit.secondUnit(with: .milli)) { value in
            DispatchQueue.main.async {
                self.latestHRV = value
            }
        }
    }

    /// Fetch resting heart rate.
    func fetchLatestRestingHR() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchMostRecent(type: type, unit: bpm) { value in
            DispatchQueue.main.async {
                self.latestRestingHR = value
            }
        }
    }

    /// Fetch current heart rate.
    func fetchLatestHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        fetchMostRecent(type: type, unit: bpm) { value in
            DispatchQueue.main.async {
                self.latestHeartRate = value
            }
        }
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
                print("⌚🏥 HRV history error: \(error.localizedDescription)")
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

    // MARK: - Generic Helpers

    private func fetchMostRecent(type: HKQuantityType, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                   sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                print("⌚🏥 Fetch error for \(type.identifier): \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            completion(sample.quantity.doubleValue(for: unit))
        }
        store.execute(query)
    }
}

// MARK: - Supporting Types

struct HRVSample {
    let value: Double  // SDNN in ms
    let date: Date
}
