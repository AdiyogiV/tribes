import Foundation

/// Ojas (Vitality) Engine — v2 research-grounded composite.
///
/// Ojas in Ayurveda is the subtle essence of all seven Dhatus (tissues).
/// It represents overall vitality, immunity, and life force.
///
/// v2 derives Ojas from a transparent weighted sum of evidence-based vitality drivers:
///   PRIMARY CONTRIBUTORS (sum to 1.00 of base score)
///     HRV            35%    — Plews & Buchheit: gold-standard autonomic recovery marker
///     Sleep          22%    — duration + deep + REM architecture
///     Resting HR     18%    — cardiac efficiency / chronic stress proxy
///     Wrist Temp     10%    — illness / circadian phase / stress
///     Respiration     8%    — diurnal autonomic state
///     Activity        7%    — daily movement (steps + active energy blended)
///
///   MODIFIERS (added/subtracted from the base 0–100 score)
///     HR Recovery    ±5     — strong post-exertion drop boosts; sluggish penalizes
///     Stand Hours    ±4     — sedentary penalty / good distribution bonus
///     SpO₂           cap    — < 92 % caps the final score at 60
///     Daylight        ±5    — < 30 min penalty / ≥ 120 min bonus (circadian)
///     Audio           −5    — chronic env audio > 85 dB penalty
///     Mindfulness    +5     — ≥ 10 min mindful minutes
///     Cardiac Alerts −10    — any AFib / irregular rhythm / high-HR events today
///     Walking Steady −5     — < 0.4 fraction (Vata-imbalance gait)
///
/// All scores use PERSONAL baselines when available, population defaults otherwise.
/// Reliable when baseline.sampleDays ≥ 14.
struct OjasEngine {

    // MARK: - Public API

    /// Compute overall Ojas from all available signals. Returns nil only if
    /// neither HRV nor sleep is available (the irreducible primaries).
    static func computeOjas(signals: HealthSignals, baseline: HealthBaseline?) -> OjasResult? {
        guard signals.hrv != nil || signals.sleepDuration != nil else { return nil }
        let base = baseline ?? HealthBaseline.populationDefaults

        // ── PRIMARY CONTRIBUTORS ─────────────────────────────────────────
        var contributors: [OjasContributor] = []
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        // 1. HRV — 35%
        if let hrv = signals.hrv {
            let s = hrvScore(hrv: hrv, baseline: base.avgHRV, std: base.stdHRV)
            let w = 0.35
            contributors.append(OjasContributor(
                name: "HRV",
                signal: .pulse,
                score: s,
                status: signalStatus(score: s),
                weight: w,
                rawDisplay: String(format: "%.0f ms", hrv),
                baselineDisplay: String(format: "base %.0f ± %.0f", base.avgHRV, base.stdHRV),
                explanation: "Z-score from personal baseline. Closer to your norm = better recovery."
            ))
            weightedSum += s * w; totalWeight += w
        }

        // 2. Sleep — 22%
        if let sleep = signals.sleepDuration {
            let hours = sleep / 3600.0
            let s = sleepScore(hours: hours, deepMinutes: signals.deepSleepMinutes, remMinutes: signals.remSleepMinutes, coreMinutes: signals.coreSleepMinutes)
            let w = 0.22
            let raw = String(format: "%.1f h", hours)
            let archParts: [String] = [
                signals.deepSleepMinutes.map { String(format: "deep %.0fm", $0) },
                signals.remSleepMinutes.map  { String(format: "rem %.0fm", $0) },
                signals.coreSleepMinutes.map { String(format: "core %.0fm", $0) }
            ].compactMap { $0 }
            contributors.append(OjasContributor(
                name: "Sleep",
                signal: .sleep,
                score: s,
                status: signalStatus(score: s),
                weight: w,
                rawDisplay: raw,
                baselineDisplay: archParts.isEmpty ? "ideal 7–8.5 h" : archParts.joined(separator: " · "),
                explanation: "Duration peaks at 7.5 h. Deep + REM + core architecture adds bonus."
            ))
            weightedSum += s * w; totalWeight += w
        }

        // 3. Resting HR — 18%
        if let rhr = signals.restingHR {
            let s = restingHRScore(rhr: rhr, baseline: base.avgRHR, std: base.stdRHR)
            let w = 0.18
            contributors.append(OjasContributor(
                name: "RHR",
                signal: .restingHR,
                score: s,
                status: signalStatus(score: s),
                weight: w,
                rawDisplay: String(format: "%.0f bpm", rhr),
                baselineDisplay: String(format: "base %.0f ± %.0f", base.avgRHR, base.stdRHR),
                explanation: "Lower than your baseline = better cardiac efficiency. Higher = stress/load."
            ))
            weightedSum += s * w; totalWeight += w
        }

        // 4. Wrist Temp — 10%
        if let temp = signals.wristTemp {
            let s = temperatureScore(deviation: temp)
            let w = 0.10
            contributors.append(OjasContributor(
                name: "Warmth",
                signal: .warmth,
                score: s,
                status: signalStatus(score: s),
                weight: w,
                rawDisplay: String(format: "%+.2f°C", temp),
                baselineDisplay: "vs your norm",
                explanation: "Stable wrist temp = no illness/stress signal. Drift = circadian or fever."
            ))
            weightedSum += s * w; totalWeight += w
        }

        // 5. Respiration — 8%
        if let resp = signals.respiratoryRate {
            let s = respiratoryScore(rate: resp, baseline: base.avgResp)
            let w = 0.08
            contributors.append(OjasContributor(
                name: "Breath",
                signal: .breath,
                score: s,
                status: signalStatus(score: s),
                weight: w,
                rawDisplay: String(format: "%.1f /min", resp),
                baselineDisplay: String(format: "base %.1f", base.avgResp),
                explanation: "12–20 normal; close to your baseline preferred. Drift up = stress."
            ))
            weightedSum += s * w; totalWeight += w
        }

        // 6. Activity blend — 7%
        let stepsScore = signals.steps.map { movementScore(steps: $0) }
        let energyScore = signals.activeEnergy.map { activeEnergyScore(kcal: $0) }
        if stepsScore != nil || energyScore != nil {
            let blended = [stepsScore, energyScore].compactMap { $0 }
            let s = blended.reduce(0, +) / Double(blended.count)
            let w = 0.07
            let stepsStr = signals.steps.map { "\($0) steps" }
            let kcalStr = signals.activeEnergy.map { String(format: "%.0f kcal", $0) }
            let raw = [stepsStr, kcalStr].compactMap { $0 }.joined(separator: " · ")
            contributors.append(OjasContributor(
                name: "Activity",
                signal: .movement,
                score: s,
                status: signalStatus(score: s),
                weight: w,
                rawDisplay: raw,
                baselineDisplay: "5–12k steps · 200–800 kcal",
                explanation: "Daily movement and active energy blended into a single Vyayama score."
            ))
            weightedSum += s * w; totalWeight += w
        }

        guard totalWeight > 0 else { return nil }

        // Base 0–100 score (renormalised over available primary weight)
        let baseScore = (weightedSum / totalWeight) * 100

        // ── MODIFIERS ────────────────────────────────────────────────────
        var modifiers: [OjasModifier] = []
        var modSum: Double = 0
        var ceiling: Double = 100

        // HR Recovery (±5)
        if let drop = signals.hrRecovery {
            let delta: Double
            if drop >= 25 { delta = 5 }
            else if drop >= 15 { delta = 2 }
            else if drop >= 8 { delta = -1 }
            else { delta = -5 }
            modifiers.append(OjasModifier(
                name: "HR Recovery",
                detail: String(format: "%.0f bpm drop", drop),
                delta: delta
            ))
            modSum += delta
        }

        // Stand hours (±4)
        if let stand = signals.standHours {
            let delta: Double
            if stand >= 12 { delta = 2 }
            else if stand >= 8 { delta = 0 }
            else if stand >= 5 { delta = -2 }
            else { delta = -4 }
            modifiers.append(OjasModifier(
                name: "Stand Hours",
                detail: "\(stand) h",
                delta: delta
            ))
            modSum += delta
        }

        // SpO₂ cap (< 92 % caps final score at 60)
        if let spo2 = signals.spO2 {
            let pct = spo2 > 1 ? spo2 : spo2 * 100
            if pct < 92 {
                ceiling = min(ceiling, 60)
                modifiers.append(OjasModifier(
                    name: "SpO₂ Cap",
                    detail: String(format: "%.0f%%", pct),
                    delta: 0,
                    note: "caps total at 60"
                ))
            } else if pct < 95 {
                modifiers.append(OjasModifier(
                    name: "SpO₂",
                    detail: String(format: "%.0f%%", pct),
                    delta: -2
                ))
                modSum += -2
            }
        }

        // Daylight (±5)
        if let daylight = signals.daylightMinutes {
            let delta: Double
            if daylight >= 120 { delta = 3 }
            else if daylight >= 60 { delta = 1 }
            else if daylight >= 30 { delta = 0 }
            else { delta = -5 }
            modifiers.append(OjasModifier(
                name: "Daylight",
                detail: String(format: "%.0f min", daylight),
                delta: delta
            ))
            modSum += delta
        }

        // Audio exposure (-5 if chronic > 85 dB)
        if let audio = signals.envAudioExposure, audio > 85 {
            let delta: Double = audio > 90 ? -5 : -2
            modifiers.append(OjasModifier(
                name: "Audio Load",
                detail: String(format: "%.0f dB", audio),
                delta: delta
            ))
            modSum += delta
        }

        // Mindfulness (+5)
        if let mindful = signals.mindfulMinutes, mindful > 0 {
            let delta: Double
            if mindful >= 20 { delta = 5 }
            else if mindful >= 10 { delta = 3 }
            else { delta = 1 }
            modifiers.append(OjasModifier(
                name: "Mindful",
                detail: String(format: "%.0f min", mindful),
                delta: delta
            ))
            modSum += delta
        }

        // Cardiac alerts (-10 if any)
        let irregular = signals.irregularRhythmCount ?? 0
        let afib = signals.afibBurden ?? 0
        let highHR = signals.highHRCount ?? 0
        if irregular > 0 || afib > 0 || highHR > 0 {
            let delta: Double = (afib > 0 ? -10 : -5)
            let detail = afib > 0
                ? String(format: "afib %.1f%%", afib * 100)
                : "\(irregular) irreg · \(highHR) high"
            modifiers.append(OjasModifier(
                name: "Cardiac Alerts",
                detail: detail,
                delta: delta
            ))
            modSum += delta
        }

        // Walking steadiness (-5 if < 0.4)
        if let steady = signals.walkingSteadiness, steady < 0.4 {
            modifiers.append(OjasModifier(
                name: "Gait Steadiness",
                detail: String(format: "%.0f%%", steady * 100),
                delta: -5
            ))
            modSum += -5
        }

        // Sleep apnea (-5 if 1-2 events, -10 if 3+ — chronic disturbance)
        if let apnea = signals.sleepApneaCount, apnea > 0 {
            let delta: Double = apnea >= 3 ? -10 : -5
            modifiers.append(OjasModifier(
                name: "Sleep Apnea",
                detail: "\(apnea) event\(apnea == 1 ? "" : "s")",
                delta: delta
            ))
            modSum += delta
        }

        // Falls (-10 if any — strong vata-imbalance / vitality penalty)
        if let falls = signals.fallCount, falls > 0 {
            modifiers.append(OjasModifier(
                name: "Falls",
                detail: "\(falls) today",
                delta: -10
            ))
            modSum += -10
        }

        // Low cardio fitness event (-3 if any)
        if let lowFit = signals.lowCardioFitnessCount, lowFit > 0 {
            modifiers.append(OjasModifier(
                name: "Low Cardio Fit",
                detail: "\(lowFit) alert\(lowFit == 1 ? "" : "s")",
                delta: -3
            ))
            modSum += -3
        }

        // RMSSD bonus (+3 if elevated parasympathetic vs population norm ~30 ms)
        // Beat-to-beat vagal tone is a deep vitality signal.
        if let rmssd = signals.rmssd, rmssd >= 50 {
            let delta: Double = rmssd >= 80 ? 5 : 3
            modifiers.append(OjasModifier(
                name: "Vagal Tone",
                detail: String(format: "RMSSD %.0f ms", rmssd),
                delta: delta
            ))
            modSum += delta
        } else if let rmssd = signals.rmssd, rmssd < 15 {
            // very low RMSSD = sympathetic dominance / chronic stress
            modifiers.append(OjasModifier(
                name: "Vagal Tone",
                detail: String(format: "RMSSD %.0f ms", rmssd),
                delta: -3
            ))
            modSum += -3
        }

        // UV over-exposure (-2 if MED > 6 — heavy sun load is pitta-aggravating)
        if let uv = signals.uvExposure, uv > 6 {
            modifiers.append(OjasModifier(
                name: "UV Load",
                detail: String(format: "%.1f MED", uv),
                delta: -2
            ))
            modSum += -2
        }

        // Heart Rate Stress — current HR / resting HR ratio (Nadi Pariksha proxy)
        if let hr = signals.heartRate, let rhr = signals.restingHR, rhr > 0 {
            let ratio = hr / rhr
            if ratio <= 1.10 {
                modifiers.append(OjasModifier(
                    name: "Pulse Calm",
                    detail: String(format: "%.0f bpm (%.1f× RHR)", hr, ratio),
                    delta: 2
                ))
                modSum += 2
            } else if ratio > 2.0 {
                modifiers.append(OjasModifier(
                    name: "Pulse Stress",
                    detail: String(format: "%.0f bpm (%.1f× RHR)", hr, ratio),
                    delta: -5
                ))
                modSum += -5
            } else if ratio > 1.5 {
                modifiers.append(OjasModifier(
                    name: "Pulse Elevated",
                    detail: String(format: "%.0f bpm (%.1f× RHR)", hr, ratio),
                    delta: -3
                ))
                modSum += -3
            }
        }

        // VO₂ Max — aerobic capacity / Prana reservoir
        if let vo2 = signals.vo2Max {
            let delta: Double
            if vo2 >= 50 { delta = 5 }
            else if vo2 >= 42 { delta = 3 }
            else if vo2 >= 35 { delta = 0 }
            else if vo2 >= 25 { delta = -2 }
            else { delta = -5 }
            if delta != 0 {
                modifiers.append(OjasModifier(
                    name: "Cardio Fitness",
                    detail: String(format: "%.1f mL/kg/min", vo2),
                    delta: delta
                ))
                modSum += delta
            }
        }

        // Exercise minutes — Vyayama (half-capacity effort is ideal in Ayurveda)
        if let exercise = signals.exerciseMinutes, exercise > 0 {
            let delta: Double
            if exercise > 150 { delta = -2 }
            else if exercise >= 20 { delta = 3 }
            else if exercise >= 10 { delta = 1 }
            else { delta = 0 }
            if delta != 0 {
                modifiers.append(OjasModifier(
                    name: "Exercise",
                    detail: String(format: "%.0f min", exercise),
                    delta: delta
                ))
                modSum += delta
            }
        }

        // PNN50 — parasympathetic strength (supplements RMSSD vagal tone)
        if let pnn = signals.pnn50 {
            if pnn >= 0.25 {
                modifiers.append(OjasModifier(
                    name: "Vagal PNN50",
                    detail: String(format: "%.1f%%", pnn * 100),
                    delta: 2
                ))
                modSum += 2
            } else if pnn < 0.03 {
                modifiers.append(OjasModifier(
                    name: "Vagal PNN50",
                    detail: String(format: "%.1f%%", pnn * 100),
                    delta: -2
                ))
                modSum += -2
            }
        }

        // Walking HR efficiency — cardiac recovery during movement
        if let whr = signals.walkingHR, let rhr = signals.restingHR, rhr > 0 {
            let ratio = whr / rhr
            if ratio < 1.3 {
                modifiers.append(OjasModifier(
                    name: "Walk Efficiency",
                    detail: String(format: "%.0f / %.0f bpm", whr, rhr),
                    delta: 3
                ))
                modSum += 3
            } else if ratio > 1.8 {
                modifiers.append(OjasModifier(
                    name: "Walk Efficiency",
                    detail: String(format: "%.0f / %.0f bpm", whr, rhr),
                    delta: -3
                ))
                modSum += -3
            }
        }

        // Gait asymmetry — structural Vata imbalance
        if let asym = signals.walkingAsymmetry, asym > 0.10 {
            modifiers.append(OjasModifier(
                name: "Gait Asymmetry",
                detail: String(format: "%.0f%%", asym * 100),
                delta: -2
            ))
            modSum += -2
        }

        // Gait double support — instability indicator
        if let dblSup = signals.walkingDoubleSupport, dblSup > 0.30 {
            modifiers.append(OjasModifier(
                name: "Gait Support",
                detail: String(format: "%.0f%% dbl", dblSup * 100),
                delta: -2
            ))
            modSum += -2
        }

        // Headphone audio — additional ear stress (separate from environmental)
        if let headphone = signals.headphoneAudioExposure, headphone > 85 {
            let delta: Double = headphone > 90 ? -3 : -1
            modifiers.append(OjasModifier(
                name: "Headphone Load",
                detail: String(format: "%.0f dB", headphone),
                delta: delta
            ))
            modSum += delta
        }

        // Low HR events — bradycardia (Kapha excess / cardiac concern)
        if let lowHR = signals.lowHRCount, lowHR > 0 {
            modifiers.append(OjasModifier(
                name: "Low HR Events",
                detail: "\(lowHR) alert\(lowHR == 1 ? "" : "s")",
                delta: -2
            ))
            modSum += -2
        }

        // Body temperature — fever = active illness = Ojas critically depleted
        if let temp = signals.bodyTemp {
            if temp > 38.0 {
                ceiling = min(ceiling, 55)
                modifiers.append(OjasModifier(
                    name: "Fever Cap",
                    detail: String(format: "%.1f°C", temp),
                    delta: 0,
                    note: "caps total at 55"
                ))
            } else if temp > 37.5 {
                modifiers.append(OjasModifier(
                    name: "Warm Temp",
                    detail: String(format: "%.1f°C", temp),
                    delta: -3
                ))
                modSum += -3
            }
        }

        // ── FINAL SCORE ──────────────────────────────────────────────────
        let preFinal = baseScore + modSum
        let finalScore = Int(round(min(ceiling, max(0, preFinal))))

        let agni = computeAgniType(signals: signals, baseline: base)
        let summary = ojasSummary(score: finalScore)

        return OjasResult(
            score: finalScore,
            baseScore: Int(round(baseScore)),
            summary: summary,
            agniType: agni,
            contributors: contributors,
            modifiers: modifiers,
            ceiling: Int(round(ceiling)),
            signalCount: contributors.count + modifiers.count,
            isReliable: (baseline?.sampleDays ?? 0) >= 14,
            computedAt: .now
        )
    }

    // MARK: - Per-signal Scoring (0.0–1.0)

    /// Sleep: optimal 7–8 h, penalize <6 h and >9.5 h, reward deep sleep + REM + core.
    private static func sleepScore(hours: Double, deepMinutes: Double?, remMinutes: Double?, coreMinutes: Double? = nil) -> Double {
        let durationScore: Double
        if hours < 4.0 {
            durationScore = 0.15
        } else if hours < 6.0 {
            durationScore = 0.30 + (hours - 4.0) / 2.0 * 0.30
        } else if hours <= 9.0 {
            let diff = abs(hours - 7.5)
            durationScore = max(0.70, 1.00 - diff * 0.10)
        } else {
            durationScore = max(0.50, 1.00 - (hours - 9.0) * 0.15)
        }
        let deepBonus: Double
        if let deep = deepMinutes {
            if deep >= 45 && deep <= 90 { deepBonus = 0.10 }
            else if deep >= 30 { deepBonus = 0.05 }
            else { deepBonus = 0 }
        } else { deepBonus = 0 }
        let remBonus: Double
        if let rem = remMinutes {
            if rem >= 60 && rem <= 120 { remBonus = 0.05 }
            else if rem >= 30 { remBonus = 0.02 }
            else { remBonus = 0 }
        } else { remBonus = 0 }
        let coreBonus: Double
        if let core = coreMinutes {
            if core >= 180 && core <= 300 { coreBonus = 0.03 }
            else if core >= 120 { coreBonus = 0.01 }
            else { coreBonus = 0 }
        } else { coreBonus = 0 }
        return min(1.0, durationScore + deepBonus + remBonus + coreBonus)
    }

    /// HRV: near personal baseline = best. Z-score driven.
    private static func hrvScore(hrv: Double, baseline: Double, std: Double) -> Double {
        let effectiveStd = max(std, 5.0)
        let z = abs(hrv - baseline) / effectiveStd
        if z < 0.5 { return 0.95 }
        if z < 1.0 { return 0.85 }
        if z < 1.5 { return 0.70 }
        if z < 2.0 { return 0.55 }
        return max(0.25, 0.55 - (z - 2.0) * 0.15)
    }

    /// RHR: prefer near-baseline; reward small drops (better fitness), penalize large rises.
    private static func restingHRScore(rhr: Double, baseline: Double, std: Double) -> Double {
        let effectiveStd = max(std, 4.0)
        let z = (rhr - baseline) / effectiveStd
        if z <= -0.5 { return 0.95 }       // lower than baseline = excellent
        if z <= 0.3 { return 0.88 }        // near baseline
        if z <= 1.0 { return 0.70 }
        if z <= 2.0 { return 0.50 }
        return 0.30
    }

    /// Temperature deviation: stable near baseline = best.
    private static func temperatureScore(deviation: Double) -> Double {
        let absDev = abs(deviation)
        if absDev < 0.2 { return 0.95 }
        if absDev < 0.5 { return 0.80 }
        if absDev < 1.0 { return 0.60 }
        return max(0.30, 0.60 - (absDev - 1.0) * 0.20)
    }

    /// Respiratory rate: 12–20 normal, optimal close to baseline.
    private static func respiratoryScore(rate: Double, baseline: Double) -> Double {
        if rate >= 12 && rate <= 20 {
            let dev = abs(rate - baseline)
            if dev < 1.5 { return 0.95 }
            if dev < 3.0 { return 0.80 }
            return 0.65
        }
        return 0.40
    }

    /// Movement: 5k–12k steps sweet spot.
    private static func movementScore(steps: Int) -> Double {
        if steps >= 5000 && steps <= 12000 { return 0.90 }
        if steps >= 3000 { return 0.70 }
        if steps >= 1000 { return 0.50 }
        return 0.30
    }

    /// Active energy: 200–800 kcal active = healthy.
    private static func activeEnergyScore(kcal: Double) -> Double {
        if kcal >= 200 && kcal <= 800 { return 0.90 }
        if kcal >= 100 { return 0.70 }
        if kcal >= 50 { return 0.50 }
        return 0.30
    }

    // MARK: - Agni Type

    static func computeAgniType(signals: HealthSignals, baseline: HealthBaseline) -> AgniType {
        // Vishama (Vata): erratic sleep onset
        if let sleepOnset = signals.sleepOnsetHour {
            let onsetVar = abs(sleepOnset - (baseline.avgSleepOnset ?? 22.5))
            if onsetVar > 1.0 { return .vishama }
        }
        // Tikshna (Pitta): short sleep + warm temp / fast HR
        let shortSleep = (signals.sleepDuration ?? 28800) < 21600
        let warmTemp = (signals.wristTemp ?? 0) > 0.4
        let fastHR = signals.restingHR != nil && signals.restingHR! > baseline.avgRHR * 1.08
        if (shortSleep && warmTemp) || (shortSleep && fastHR) { return .tikshna }
        // Manda (Kapha): long sleep + low activity / slow recovery
        let longSleep = (signals.sleepDuration ?? 0) > 34200
        let lowSteps = (signals.steps ?? 5000) < 3000
        let slowRecovery = (signals.hrRecovery ?? 25) < 12
        if (longSleep && lowSteps) || (lowSteps && slowRecovery) { return .manda }
        return .sama
    }

    // MARK: - Helpers

    private static func signalStatus(score: Double) -> SignalStatus {
        if score >= 0.75 { return .good }
        if score >= 0.50 { return .moderate }
        return .low
    }

    private static func ojasSummary(score: Int) -> String {
        switch score {
        case 85...100: return "Vital"
        case 70..<85:  return "Steady"
        case 55..<70:  return "Moderate"
        case 40..<55:  return "Depleted"
        default:       return "Rest"
        }
    }
}

// MARK: - Data Models

/// Raw health signals fed into OjasEngine. v2 includes modifier inputs.
/// All fields default to nil so callers supply only what they have.
struct HealthSignals {
    var hrv: Double? = nil
    var rmssd: Double? = nil
    var pnn50: Double? = nil
    var restingHR: Double? = nil
    var walkingHR: Double? = nil
    var sleepDuration: TimeInterval? = nil
    var deepSleepMinutes: Double? = nil
    var remSleepMinutes: Double? = nil
    var sleepOnsetHour: Double? = nil
    var wristTemp: Double? = nil
    var respiratoryRate: Double? = nil
    var vo2Max: Double? = nil
    var walkingSteadiness: Double? = nil
    var walkingAsymmetry: Double? = nil
    var walkingDoubleSupport: Double? = nil
    var steps: Int? = nil
    var hrRecovery: Double? = nil
    var spO2: Double? = nil
    var activeEnergy: Double? = nil
    var mindfulMinutes: Double? = nil
    var standHours: Int? = nil
    var daylightMinutes: Double? = nil
    var envAudioExposure: Double? = nil
    var afibBurden: Double? = nil
    var highHRCount: Int? = nil
    var irregularRhythmCount: Int? = nil
    var sleepApneaCount: Int? = nil
    var fallCount: Int? = nil
    var lowCardioFitnessCount: Int? = nil
    var uvExposure: Double? = nil
    var heartRate: Double? = nil
    var exerciseMinutes: Double? = nil
    var coreSleepMinutes: Double? = nil
    var headphoneAudioExposure: Double? = nil
    var lowHRCount: Int? = nil
    var bodyTemp: Double? = nil
}

/// Personal health baselines computed from 14+ days of data.
struct HealthBaseline {
    var avgHRV: Double = 45.0
    var stdHRV: Double = 12.0
    var avgRHR: Double = 68.0
    var stdRHR: Double = 6.0
    var avgResp: Double = 15.0
    var avgVO2: Double = 35.0
    var avgSleepOnset: Double? = 22.5
    var sampleDays: Int = 0

    static let populationDefaults = HealthBaseline()
}

/// Result of Ojas computation.
struct OjasResult {
    let score: Int                   // final 0–100
    let baseScore: Int               // pre-modifier base
    let summary: String              // "Vital" etc.
    let agniType: AgniType
    let contributors: [OjasContributor]
    let modifiers: [OjasModifier]
    let ceiling: Int                 // applied ceiling (100 unless capped)
    let signalCount: Int
    let isReliable: Bool
    let computedAt: Date

    /// Convenient: total of modifier deltas applied to base.
    var modifierDelta: Int { modifiers.reduce(0) { $0 + Int(round($1.delta)) } }
}

/// One primary contributor to the Ojas score (with explanation for live UI).
struct OjasContributor: Identifiable {
    let name: String
    let signal: SignalType
    let score: Double             // 0.0–1.0
    let status: SignalStatus
    let weight: Double            // 0.0–1.0
    let rawDisplay: String        // "42 ms"
    let baselineDisplay: String   // "base 45 ± 12"
    let explanation: String       // human-readable why

    var id: String { name }

    /// Weighted contribution to final score on 0–100 scale.
    var contribution: Double { score * weight * 100 }
}

/// A modifier that adds/subtracts from the base score after primary contributors.
struct OjasModifier: Identifiable {
    let name: String
    let detail: String
    let delta: Double      // signed bonus/penalty in absolute points (0–100 scale)
    let note: String?

    init(name: String, detail: String, delta: Double, note: String? = nil) {
        self.name = name
        self.detail = detail
        self.delta = delta
        self.note = note
    }

    var id: String { name }
}

enum SignalType: String {
    case sleep, pulse, restingHR, warmth, breath, fitness, movement
    case recovery, oxygen, energy, mindful
}

enum SignalStatus: String {
    case good       // ≥ 0.75
    case moderate   // 0.50–0.74
    case low        // < 0.50

    var label: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Fair"
        case .low: return "Low"
        }
    }
}

enum AgniType: String {
    case sama     = "Sama"
    case vishama  = "Vishama"
    case tikshna  = "Tikshna"
    case manda    = "Manda"

    var description: String {
        switch self {
        case .sama:    return "Balanced digestion"
        case .vishama: return "Irregular rhythm"
        case .tikshna: return "Running intense"
        case .manda:   return "Sluggish metabolism"
        }
    }
}
