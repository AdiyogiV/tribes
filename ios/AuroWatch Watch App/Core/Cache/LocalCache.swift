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
    }

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

    /// Update Nadi reading from on-watch analysis.
    func updateNadi(dominantDosha: String?, hrv: Double?, restingHR: Double?) {
        nadiDominantDosha = dominantDosha
        latestHRV = hrv
        latestRestingHR = restingHR
        lastNadiReading = .now
        save()
    }

    // MARK: - Helpers

    private func key(_ name: String) -> String {
        "\(Self.prefix)\(name)"
    }
}
