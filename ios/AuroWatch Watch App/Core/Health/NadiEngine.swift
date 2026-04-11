import Foundation

/// Nadi (Pulse) analysis engine.
///
/// Maps Apple Watch cardiovascular signals to Ayurvedic Nadi qualities.
///
/// Classical Nadi Pariksha examines pulse at the radial artery (wrist)
/// for three qualities:
///   Sarpa Gati (Vata)  — irregular, thin, fast → high HRV, variable, faster HR
///   Manduka Gati (Pitta) — jumping, bounding, moderate → moderate HRV, strong, moderate HR
///   Hamsa Gati (Kapha)  — slow, steady, broad → low HRV (regular), slow HR
///
/// LIMITATION: This is "Digital Nadi Monitoring" — a complement to, NOT replacement
/// for, traditional Nadi Pariksha. We track rhythm and rate patterns that
/// parallel what a Vaidya feels, but cannot replicate 3-finger depth perception.
///
/// Research basis:
///   - AIIMS studies: HRV differs significantly between Prakriti types
///   - CSIR-IGIB: Prakriti types have distinct physiological signatures
///   - CDAC Pune Nadi Tarangini: digital pulse → dosha classification
struct NadiEngine {

    /// Analyze current Nadi state from available signals.
    ///
    /// Returns nil if insufficient data (e.g., no HRV reading yet).
    static func analyze(
        hrv: Double?,
        restingHR: Double?,
        baseline: NadiBaseline?
    ) -> NadiReading? {
        // Need at least HRV for meaningful analysis
        guard let hrv = hrv else { return nil }

        let baselineHRV = baseline?.avgHRV ?? 45.0   // population median fallback
        let baselineRHR = baseline?.avgRHR ?? 68.0

        // Calculate relative deviations from personal baseline
        let hrvDeviation = (hrv - baselineHRV) / baselineHRV  // positive = higher than usual
        let rhrDeviation: Double
        if let rhr = restingHR {
            rhrDeviation = (rhr - baselineRHR) / baselineRHR
        } else {
            rhrDeviation = 0
        }

        // Score each dosha (0.0–1.0)
        // These weights are based on published HRV-Prakriti correlation studies
        var vataScore = 0.0
        var pittaScore = 0.0
        var kaphaScore = 0.0

        // HRV analysis (primary signal)
        // High HRV → Vata (high variability = irregular pulse)
        // Medium HRV → Pitta (moderate, consistent)
        // Low HRV → Kapha (very regular, steady pulse)
        if hrvDeviation > 0.15 {
            // HRV above baseline — Vata pulse characteristic
            vataScore += 0.4 + min(hrvDeviation * 0.5, 0.3)
            pittaScore += 0.2
            kaphaScore += 0.1
        } else if hrvDeviation < -0.15 {
            // HRV below baseline — could be Kapha (steady) or stressed Vata
            kaphaScore += 0.3 + min(abs(hrvDeviation) * 0.4, 0.3)
            pittaScore += 0.25
            vataScore += 0.15
        } else {
            // HRV near baseline — Pitta (balanced, moderate)
            pittaScore += 0.4
            vataScore += 0.2
            kaphaScore += 0.2
        }

        // Resting HR analysis (secondary signal)
        // Fast HR → Vata (rapid pulse)
        // Moderate HR → Pitta (strong, moderate)
        // Slow HR → Kapha (slow, steady)
        if rhrDeviation > 0.08 {
            vataScore += 0.2
            pittaScore += 0.1
        } else if rhrDeviation < -0.08 {
            kaphaScore += 0.2
            pittaScore += 0.05
        } else {
            pittaScore += 0.2
        }

        // Normalize to percentages
        let total = vataScore + pittaScore + kaphaScore
        guard total > 0 else { return nil }

        let vata = vataScore / total
        let pitta = pittaScore / total
        let kapha = kaphaScore / total

        // Determine dominant
        let dominant: String
        let gati: String
        if vata >= pitta && vata >= kapha {
            dominant = "Vata"
            gati = "Sarpa"  // snake-like
        } else if pitta >= vata && pitta >= kapha {
            dominant = "Pitta"
            gati = "Manduka"  // frog-like
        } else {
            dominant = "Kapha"
            gati = "Hamsa"  // swan-like
        }

        return NadiReading(
            vata: vata,
            pitta: pitta,
            kapha: kapha,
            dominant: dominant,
            gati: gati,
            hrv: hrv,
            restingHR: restingHR,
            baselineHRV: baselineHRV,
            timestamp: .now
        )
    }

    /// Compute personal baseline from historical HRV samples.
    /// Requires at least 7 days of data for reliable baseline.
    static func computeBaseline(hrvHistory: [HRVSample], restingHRHistory: [Double]?) -> NadiBaseline? {
        guard hrvHistory.count >= 5 else { return nil }  // minimum viable baseline

        let avgHRV = hrvHistory.map(\.value).reduce(0, +) / Double(hrvHistory.count)

        // Standard deviation for variability assessment
        let variance = hrvHistory.map(\.value).reduce(0) { $0 + pow($1 - avgHRV, 2) } / Double(hrvHistory.count)
        let stdHRV = sqrt(variance)

        let avgRHR: Double
        if let rhrHistory = restingHRHistory, !rhrHistory.isEmpty {
            avgRHR = rhrHistory.reduce(0, +) / Double(rhrHistory.count)
        } else {
            avgRHR = 68.0  // fallback
        }

        return NadiBaseline(
            avgHRV: avgHRV,
            stdHRV: stdHRV,
            avgRHR: avgRHR,
            sampleCount: hrvHistory.count,
            computedAt: .now
        )
    }
}

// MARK: - Data Models

/// A single Nadi analysis result.
struct NadiReading {
    /// Dosha proportions (0.0–1.0, sum to 1.0).
    let vata: Double
    let pitta: Double
    let kapha: Double

    /// Dominant dosha name.
    let dominant: String

    /// Classical Nadi Gati (movement type): Sarpa, Manduka, or Hamsa.
    let gati: String

    /// Raw signal values used for this reading.
    let hrv: Double
    let restingHR: Double?
    let baselineHRV: Double

    let timestamp: Date

    /// Display-friendly description.
    var description: String {
        "\(dominant) Nadi (\(gati) Gati)"
    }

    /// Whether this reading shows alignment with a given Prakriti.
    /// "Aligned" means the dominant Nadi matches the dominant Prakriti dosha.
    func isAligned(withPrakriti prakritiDominant: String?) -> Bool {
        guard let prakriti = prakritiDominant else { return false }
        return dominant.lowercased() == prakriti.lowercased()
    }
}

/// Personal cardiovascular baseline computed from historical data.
struct NadiBaseline {
    let avgHRV: Double      // average SDNN in ms
    let stdHRV: Double      // standard deviation of HRV
    let avgRHR: Double      // average resting heart rate
    let sampleCount: Int    // how many days of data
    let computedAt: Date

    /// Whether baseline has enough data for reliable analysis.
    var isReliable: Bool { sampleCount >= 14 }
}
