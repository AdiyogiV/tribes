import Foundation

/// Nadi (Pulse) analysis engine — v2 multi-signal classifier.
///
/// Maps Apple Watch passive cardiovascular + autonomic signals to Ayurvedic Nadi qualities.
///
/// Classical Nadi Pariksha examines pulse at the radial artery (wrist) for three qualities:
///   Sarpa Gati (Vata)  — irregular, thin, fast → high HRV variability, faster, fragmented
///   Manduka Gati (Pitta) — jumping, bounding, moderate → mid HRV, strong, focused
///   Hamsa Gati (Kapha)  — slow, steady, broad → low HRV variance, slow, smooth
///
/// LIMITATION: Digital Nadi Monitoring is a complement to, NOT a replacement for, traditional
/// Nadi Pariksha. We track rhythm/rate/breath/temp/gait patterns that PARALLEL what a Vaidya
/// feels with three fingers, but cannot replicate depth-perception or qualitative texture.
///
/// Research basis (v2):
///   - AIIMS / CSIR-IGIB: Prakriti types have distinct HRV signatures
///   - Rapolu 2017: HRV–cardiointervalography correlates with Vaidya pulse (k=0.78)
///   - Massin 2000: time-of-day HRV normalization
///   - Umetani 1998: age-stratified HRV norms
///   - Joshi (Nadi Tarangini): pulse-waveform → dosha classifier
///
/// v2 IMPROVEMENTS:
///   - 8 input signals instead of 2 (HRV, RHR, walking-HR ratio, respiration, sleep
///     fragmentation, wrist temp, gait quality, cardiac-alerts)
///   - Z-score normalization against personal baseline + std
///   - Confidence band based on signal completeness (0.0–1.0)
///   - Per-contributor breakdown so the calculation is fully transparent
struct NadiEngine {

    // MARK: - Public API

    /// Legacy 2-signal API — kept for callers that haven't migrated.
    /// Internally wraps the richer multi-signal API with everything else nil.
    static func analyze(
        hrv: Double?,
        restingHR: Double?,
        baseline: NadiBaseline?
    ) -> NadiReading? {
        let signals = NadiSignals(hrv: hrv, restingHR: restingHR)
        return analyze(signals: signals, baseline: baseline)
    }

    /// v2 multi-signal API — returns a fully-itemized NadiReading.
    /// Returns nil only if HRV is missing (HRV is the irreducible primary).
    static func analyze(signals: NadiSignals, baseline: NadiBaseline?) -> NadiReading? {
        guard let hrv = signals.hrv else { return nil }

        let base = baseline ?? NadiBaseline.populationDefaults
        var contributors: [NadiContributor] = []

        // ── 1. HRV deviation from personal baseline (weight 0.30) ─────────
        let hrvZ = zScore(hrv, mean: base.avgHRV, std: max(base.stdHRV, 5.0))
        let hrvDosha = doshaVectorForHRV(zScore: hrvZ)
        contributors.append(NadiContributor(
            signal: .hrv,
            label: "HRV",
            rawDisplay: String(format: "%.0f ms", hrv),
            baselineDisplay: String(format: "base %.0f · z%+.2f", base.avgHRV, hrvZ),
            doshaVector: hrvDosha,
            weight: 0.30
        ))

        // ── 2. RHR deviation (weight 0.15) ────────────────────────────────
        if let rhr = signals.restingHR {
            let rhrZ = zScore(rhr, mean: base.avgRHR, std: max(base.stdRHR, 4.0))
            let rhrDosha = doshaVectorForRHR(zScore: rhrZ)
            contributors.append(NadiContributor(
                signal: .restingHR,
                label: "RHR",
                rawDisplay: String(format: "%.0f bpm", rhr),
                baselineDisplay: String(format: "base %.0f · z%+.2f", base.avgRHR, rhrZ),
                doshaVector: rhrDosha,
                weight: 0.15
            ))
        }

        // ── 3. Walking-HR vs RHR ratio (weight 0.10) ──────────────────────
        if let walkHR = signals.walkingHR, let rhr = signals.restingHR, rhr > 0 {
            let ratio = walkHR / rhr
            let ratioDosha = doshaVectorForWalkRatio(ratio)
            contributors.append(NadiContributor(
                signal: .walkingHRRatio,
                label: "Walk/Rest",
                rawDisplay: String(format: "%.2fx", ratio),
                baselineDisplay: "ideal 1.5–1.8",
                doshaVector: ratioDosha,
                weight: 0.10
            ))
        }

        // ── 4. Respiratory rate (weight 0.15) ─────────────────────────────
        if let resp = signals.respiratoryRate {
            let respDosha = doshaVectorForResp(resp, baseline: base.avgResp)
            contributors.append(NadiContributor(
                signal: .respiration,
                label: "Breath",
                rawDisplay: String(format: "%.1f /min", resp),
                baselineDisplay: String(format: "base %.1f", base.avgResp),
                doshaVector: respDosha,
                weight: 0.15
            ))
        }

        // ── 5. Sleep architecture (weight 0.12) ───────────────────────────
        if let dur = signals.sleepDuration {
            let hours = dur / 3600.0
            let sleepDosha = doshaVectorForSleep(
                hours: hours,
                deepMin: signals.deepSleepMinutes,
                remMin: signals.remSleepMinutes
            )
            contributors.append(NadiContributor(
                signal: .sleep,
                label: "Sleep",
                rawDisplay: String(format: "%.1f h", hours),
                baselineDisplay: sleepBaselineDisplay(deep: signals.deepSleepMinutes, rem: signals.remSleepMinutes),
                doshaVector: sleepDosha,
                weight: 0.12
            ))
        }

        // ── 6. Wrist temperature deviation (weight 0.08) ──────────────────
        if let temp = signals.wristTempDeviation {
            let tempDosha = doshaVectorForTemp(deviation: temp)
            contributors.append(NadiContributor(
                signal: .wristTemp,
                label: "Warmth",
                rawDisplay: String(format: "%+.2f°C", temp),
                baselineDisplay: "vs your norm",
                doshaVector: tempDosha,
                weight: 0.08
            ))
        }

        // ── 7. Gait quality (weight 0.05) ─────────────────────────────────
        if signals.walkingAsymmetry != nil || signals.walkingDoubleSupport != nil {
            let asym = signals.walkingAsymmetry ?? 0
            let dbl = signals.walkingDoubleSupport ?? 0
            let gaitDosha = doshaVectorForGait(asymmetry: asym, doubleSupport: dbl)
            let raw = String(
                format: "asym %.0f%% · dbl %.0f%%",
                asym * 100, dbl * 100
            )
            contributors.append(NadiContributor(
                signal: .gait,
                label: "Gait",
                rawDisplay: raw,
                baselineDisplay: "smoother = steadier",
                doshaVector: gaitDosha,
                weight: 0.05
            ))
        }

        // ── 8. Cardiac alerts (weight 0.05) ───────────────────────────────
        let irregular = signals.irregularRhythmCount ?? 0
        let afib = signals.afibBurden ?? 0
        let highHR = signals.highHRCount ?? 0
        if irregular > 0 || afib > 0 || highHR > 0 {
            let alertsDosha = doshaVectorForAlerts(
                irregular: irregular,
                afibBurden: afib,
                highHR: highHR
            )
            let raw = "\(irregular) irreg · \(highHR) high"
            contributors.append(NadiContributor(
                signal: .cardiacAlerts,
                label: "Alerts",
                rawDisplay: raw,
                baselineDisplay: afib > 0 ? String(format: "afib %.1f%%", afib * 100) : "none = steady",
                doshaVector: alertsDosha,
                weight: 0.05
            ))
        }

        // ── 9. RMSSD / pNN50 — beat-to-beat parasympathetic state (weight 0.15)
        // RMSSD is a sharper parasympathetic marker than SDNN. High RMSSD = strong vagal tone
        // (Kapha-leaning recovery) when paired with healthy pNN50 > 5%. Very low RMSSD = Vata
        // depletion. Mid + steady = Pitta balance.
        if let rmssd = signals.rmssd {
            let pnn = signals.pnn50 ?? 0
            let rmssdDosha = doshaVectorForBeatToBeat(rmssd: rmssd, pnn50: pnn)
            contributors.append(NadiContributor(
                signal: .rmssd,
                label: "RMSSD",
                rawDisplay: String(format: "%.0f ms", rmssd),
                baselineDisplay: String(format: "pNN50 %.0f%%", pnn * 100),
                doshaVector: rmssdDosha,
                weight: 0.15
            ))
        }

        // ── 10. Sleep apnea events (weight 0.05) ───────────────────────────
        // Repeated breathing disturbances during sleep = Vata/Prana derangement (Apana shift).
        if let apnea = signals.sleepApneaCount, apnea > 0 {
            let apneaDosha = doshaVectorForApnea(count: apnea)
            contributors.append(NadiContributor(
                signal: .sleepApnea,
                label: "Apnea",
                rawDisplay: "\(apnea) events",
                baselineDisplay: "during sleep",
                doshaVector: apneaDosha,
                weight: 0.05
            ))
        }

        // ── 11. Falls (weight 0.03) ────────────────────────────────────────
        // Any fall = strong Vata-imbalance signal (motor instability).
        if let falls = signals.fallCount, falls > 0 {
            let fallDosha = DoshaVector(vata: 0.80, pitta: 0.15, kapha: 0.05)
            contributors.append(NadiContributor(
                signal: .falls,
                label: "Falls",
                rawDisplay: "\(falls) today",
                baselineDisplay: "stability",
                doshaVector: fallDosha,
                weight: 0.03
            ))
        }

        // ── Aggregate weighted dosha proportions ──────────────────────────
        var vata = 0.0, pitta = 0.0, kapha = 0.0
        var availableWeight = 0.0
        for c in contributors {
            vata  += c.doshaVector.vata  * c.weight
            pitta += c.doshaVector.pitta * c.weight
            kapha += c.doshaVector.kapha * c.weight
            availableWeight += c.weight
        }
        guard availableWeight > 0 else { return nil }

        // Normalize so V + P + K = 1.0
        let total = vata + pitta + kapha
        guard total > 0 else { return nil }
        let vN = vata / total
        let pN = pitta / total
        let kN = kapha / total

        // Confidence band (signal completeness against the maximum 1.0 weight)
        let confidence = min(1.0, availableWeight / 1.0)

        // Determine dominant + classical Gati name
        let dominant: String
        let gati: String
        if vN >= pN && vN >= kN {
            dominant = "Vata"; gati = "Sarpa"
        } else if pN >= vN && pN >= kN {
            dominant = "Pitta"; gati = "Manduka"
        } else {
            dominant = "Kapha"; gati = "Hamsa"
        }

        return NadiReading(
            vata: vN,
            pitta: pN,
            kapha: kN,
            dominant: dominant,
            gati: gati,
            hrv: hrv,
            restingHR: signals.restingHR,
            baselineHRV: base.avgHRV,
            confidence: confidence,
            contributors: contributors,
            timestamp: .now
        )
    }

    /// Compute personal baseline from historical HRV + optional RHR samples.
    /// Requires at least 5 days for a viable baseline; 14+ for "reliable".
    static func computeBaseline(hrvHistory: [HRVSample], restingHRHistory: [Double]?) -> NadiBaseline? {
        guard hrvHistory.count >= 5 else { return nil }
        let values = hrvHistory.map(\.value)
        let avgHRV = values.reduce(0, +) / Double(values.count)
        let varHRV = values.reduce(0) { $0 + pow($1 - avgHRV, 2) } / Double(values.count)
        let stdHRV = sqrt(varHRV)

        let avgRHR: Double
        let stdRHR: Double
        if let rh = restingHRHistory, !rh.isEmpty {
            avgRHR = rh.reduce(0, +) / Double(rh.count)
            let v = rh.reduce(0) { $0 + pow($1 - avgRHR, 2) } / Double(rh.count)
            stdRHR = sqrt(v)
        } else {
            avgRHR = 68.0
            stdRHR = 6.0
        }

        return NadiBaseline(
            avgHRV: avgHRV,
            stdHRV: stdHRV,
            avgRHR: avgRHR,
            stdRHR: stdRHR,
            avgResp: 15.0,
            sampleCount: hrvHistory.count,
            computedAt: .now
        )
    }

    // MARK: - Per-Signal Dosha Mapping

    /// HRV: high z → Vata (variable), low z → Kapha (steady), mid → Pitta (balanced).
    private static func doshaVectorForHRV(zScore z: Double) -> DoshaVector {
        if z > 1.0 {
            return DoshaVector(vata: 0.65, pitta: 0.25, kapha: 0.10)
        } else if z > 0.3 {
            return DoshaVector(vata: 0.45, pitta: 0.40, kapha: 0.15)
        } else if z > -0.3 {
            return DoshaVector(vata: 0.25, pitta: 0.55, kapha: 0.20)
        } else if z > -1.0 {
            return DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40)
        } else {
            return DoshaVector(vata: 0.15, pitta: 0.20, kapha: 0.65)
        }
    }

    /// RHR: high z → Vata/Pitta (rapid), low z → Kapha (slow).
    private static func doshaVectorForRHR(zScore z: Double) -> DoshaVector {
        if z > 1.0 {
            return DoshaVector(vata: 0.50, pitta: 0.40, kapha: 0.10)
        } else if z > 0.3 {
            return DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15)
        } else if z > -0.3 {
            return DoshaVector(vata: 0.30, pitta: 0.45, kapha: 0.25)
        } else if z > -1.0 {
            return DoshaVector(vata: 0.20, pitta: 0.30, kapha: 0.50)
        } else {
            return DoshaVector(vata: 0.10, pitta: 0.20, kapha: 0.70)
        }
    }

    /// Walking/RHR ratio: ~1.5–1.8 is balanced Pitta. >2 → Vata over-response, <1.3 → Kapha.
    private static func doshaVectorForWalkRatio(_ r: Double) -> DoshaVector {
        if r >= 2.0 {
            return DoshaVector(vata: 0.55, pitta: 0.35, kapha: 0.10)
        } else if r >= 1.5 {
            return DoshaVector(vata: 0.30, pitta: 0.55, kapha: 0.15)
        } else if r >= 1.3 {
            return DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40)
        } else {
            return DoshaVector(vata: 0.15, pitta: 0.20, kapha: 0.65)
        }
    }

    /// Respiratory rate: high → Vata, mid → Pitta, low → Kapha.
    private static func doshaVectorForResp(_ rate: Double, baseline: Double) -> DoshaVector {
        let dev = rate - baseline
        if dev > 3 {
            return DoshaVector(vata: 0.65, pitta: 0.25, kapha: 0.10)
        } else if dev > 1 {
            return DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15)
        } else if dev > -1 {
            return DoshaVector(vata: 0.25, pitta: 0.55, kapha: 0.20)
        } else if dev > -3 {
            return DoshaVector(vata: 0.15, pitta: 0.40, kapha: 0.45)
        } else {
            return DoshaVector(vata: 0.10, pitta: 0.20, kapha: 0.70)
        }
    }

    /// Sleep: short/fragmented → Vata, balanced → Pitta, long/heavy → Kapha.
    private static func doshaVectorForSleep(hours: Double, deepMin: Double?, remMin: Double?) -> DoshaVector {
        // Short sleep + low deep → Vata fragmentation
        if hours < 6.0 {
            let lowDeep = (deepMin ?? 60) < 30
            return DoshaVector(vata: lowDeep ? 0.65 : 0.55, pitta: 0.30, kapha: lowDeep ? 0.05 : 0.15)
        } else if hours < 7.0 {
            return DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15)
        } else if hours < 8.5 {
            return DoshaVector(vata: 0.25, pitta: 0.50, kapha: 0.25)
        } else if hours < 9.5 {
            return DoshaVector(vata: 0.15, pitta: 0.40, kapha: 0.45)
        } else {
            return DoshaVector(vata: 0.10, pitta: 0.20, kapha: 0.70)
        }
    }

    /// Wrist-temp deviation: cold → Vata, hot → Pitta, stable → Kapha.
    private static func doshaVectorForTemp(deviation t: Double) -> DoshaVector {
        if t > 0.5 {
            return DoshaVector(vata: 0.20, pitta: 0.65, kapha: 0.15)
        } else if t > 0.1 {
            return DoshaVector(vata: 0.25, pitta: 0.50, kapha: 0.25)
        } else if t > -0.1 {
            return DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40)
        } else if t > -0.5 {
            return DoshaVector(vata: 0.50, pitta: 0.30, kapha: 0.20)
        } else {
            return DoshaVector(vata: 0.65, pitta: 0.20, kapha: 0.15)
        }
    }

    /// Gait: irregular asymmetry / high double-support → Vata; smooth → Kapha; balanced → Pitta.
    private static func doshaVectorForGait(asymmetry: Double, doubleSupport: Double) -> DoshaVector {
        let irregularity = asymmetry + max(0, doubleSupport - 0.30) // double support >30% adds load
        if irregularity > 0.20 {
            return DoshaVector(vata: 0.65, pitta: 0.25, kapha: 0.10)
        } else if irregularity > 0.10 {
            return DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15)
        } else if irregularity > 0.04 {
            return DoshaVector(vata: 0.25, pitta: 0.50, kapha: 0.25)
        } else {
            return DoshaVector(vata: 0.15, pitta: 0.40, kapha: 0.45)
        }
    }

    /// Beat-to-beat HRV (RMSSD + pNN50): very high vagal tone → Kapha-leaning recovery,
    /// very low → Vata depletion, balanced mid → Pitta. pNN50 modulates: <2% suggests
    /// suppressed parasympathetic regardless of RMSSD magnitude.
    private static func doshaVectorForBeatToBeat(rmssd: Double, pnn50: Double) -> DoshaVector {
        // Population reference: RMSSD typically 20–80 ms (strongly age-dependent).
        if rmssd >= 60 && pnn50 >= 0.05 {
            return DoshaVector(vata: 0.20, pitta: 0.30, kapha: 0.50)
        } else if rmssd >= 40 && pnn50 >= 0.03 {
            return DoshaVector(vata: 0.20, pitta: 0.55, kapha: 0.25)
        } else if rmssd >= 25 {
            return DoshaVector(vata: 0.40, pitta: 0.45, kapha: 0.15)
        } else if rmssd >= 15 {
            return DoshaVector(vata: 0.60, pitta: 0.30, kapha: 0.10)
        } else {
            return DoshaVector(vata: 0.75, pitta: 0.20, kapha: 0.05)
        }
    }

    /// Sleep-apnea event load → Vata-affinity (Apana / Prana disturbance).
    private static func doshaVectorForApnea(count: Int) -> DoshaVector {
        if count >= 5 {
            return DoshaVector(vata: 0.75, pitta: 0.20, kapha: 0.05)
        } else if count >= 2 {
            return DoshaVector(vata: 0.60, pitta: 0.30, kapha: 0.10)
        } else {
            return DoshaVector(vata: 0.45, pitta: 0.40, kapha: 0.15)
        }
    }

    /// Cardiac alerts (irregular rhythm, AFib, high-HR events) → strong Vata-imbalance signal.
    private static func doshaVectorForAlerts(irregular: Int, afibBurden: Double, highHR: Int) -> DoshaVector {
        let load = Double(irregular) + Double(highHR) + afibBurden * 50
        if load >= 5 {
            return DoshaVector(vata: 0.75, pitta: 0.20, kapha: 0.05)
        } else if load >= 2 {
            return DoshaVector(vata: 0.60, pitta: 0.30, kapha: 0.10)
        } else if load > 0 {
            return DoshaVector(vata: 0.45, pitta: 0.40, kapha: 0.15)
        } else {
            return DoshaVector(vata: 0.20, pitta: 0.40, kapha: 0.40)
        }
    }

    // MARK: - Helpers

    private static func zScore(_ value: Double, mean: Double, std: Double) -> Double {
        guard std > 0 else { return 0 }
        return (value - mean) / std
    }

    private static func sleepBaselineDisplay(deep: Double?, rem: Double?) -> String {
        var parts: [String] = []
        if let d = deep { parts.append(String(format: "deep %.0fm", d)) }
        if let r = rem  { parts.append(String(format: "rem %.0fm", r)) }
        return parts.isEmpty ? "ideal 7–8.5 h" : parts.joined(separator: " · ")
    }
}

// MARK: - Data Models

/// Raw signals fed into NadiEngine. All optional — caller supplies what's available.
struct NadiSignals {
    var hrv: Double? = nil               // SDNN ms (aggregated)
    var rmssd: Double? = nil             // ms — beat-to-beat parasympathetic marker
    var pnn50: Double? = nil             // 0–1 fraction
    var restingHR: Double? = nil
    var walkingHR: Double? = nil
    var respiratoryRate: Double? = nil
    var sleepDuration: TimeInterval? = nil
    var deepSleepMinutes: Double? = nil
    var remSleepMinutes: Double? = nil
    var wristTempDeviation: Double? = nil
    var walkingAsymmetry: Double? = nil      // 0–1 fraction
    var walkingDoubleSupport: Double? = nil  // 0–1 fraction
    var irregularRhythmCount: Int? = nil
    var afibBurden: Double? = nil            // 0–1 fraction
    var highHRCount: Int? = nil
    var sleepApneaCount: Int? = nil          // elevated breathing-disturbance count last 24 h
    var fallCount: Int? = nil
}

/// Per-signal contribution to the Nadi reading — fully transparent for live UI display.
struct NadiContributor: Identifiable {
    let signal: NadiSignal
    let label: String
    let rawDisplay: String          // "42 ms"
    let baselineDisplay: String     // "base 45 · z-0.21"
    let doshaVector: DoshaVector    // V/P/K weights this signal contributes
    let weight: Double              // 0.0–1.0

    var id: NadiSignal { signal }

    /// Weighted contribution: multiply each axis by weight.
    var weightedVata:  Double { doshaVector.vata  * weight }
    var weightedPitta: Double { doshaVector.pitta * weight }
    var weightedKapha: Double { doshaVector.kapha * weight }
}

enum NadiSignal: String, Hashable {
    case hrv, restingHR, walkingHRRatio, respiration
    case sleep, wristTemp, gait, cardiacAlerts
    case rmssd, sleepApnea, falls
}

/// Vector of three dosha proportions (sum to ≈1.0).
struct DoshaVector {
    let vata: Double
    let pitta: Double
    let kapha: Double
}

/// A single Nadi analysis result.
struct NadiReading {
    let vata: Double
    let pitta: Double
    let kapha: Double

    let dominant: String
    let gati: String

    let hrv: Double
    let restingHR: Double?
    let baselineHRV: Double

    /// Signal completeness 0.0–1.0 (1.0 = all 8 contributors available).
    let confidence: Double

    /// Per-signal breakdown for transparent UI.
    let contributors: [NadiContributor]

    let timestamp: Date

    var description: String { "\(dominant) Nadi (\(gati) Gati)" }

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
    let stdRHR: Double      // standard deviation of RHR
    let avgResp: Double     // typical respiratory rate
    let sampleCount: Int
    let computedAt: Date

    var isReliable: Bool { sampleCount >= 14 }

    static let populationDefaults = NadiBaseline(
        avgHRV: 45.0,
        stdHRV: 12.0,
        avgRHR: 68.0,
        stdRHR: 6.0,
        avgResp: 15.0,
        sampleCount: 0,
        computedAt: .distantPast
    )
}
