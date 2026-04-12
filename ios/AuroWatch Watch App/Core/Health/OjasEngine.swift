import Foundation

/// Ojas (Vitality) Engine — computes Ayurvedic health scores from passive Apple Watch signals.
///
/// Ojas in Ayurveda is the subtle essence of all seven Dhatus (tissues).
/// It represents overall vitality, immunity, and life force.
///
/// This engine takes raw HealthKit data and produces:
///   1. Ojas Score (0–100) — composite vitality rating
///   2. Agni Type — metabolic pattern (Sama/Vishama/Tikshna/Manda)
///   3. Dhatu Signals — per-signal health status
///   4. Dosha Balance — how current state compares to Prakriti
///
/// Signals (13 total, weighted):
///   Sleep (25%) + HRV (20%) + SpO2 (10%) + Warmth (8%) + Breath (8%)
///   + Fitness (7%) + Movement (7%) + Recovery (5%) + Energy (5%)
///   + Mindful (5%)
///
/// All scores use PERSONAL baselines (not population averages).
/// Requires 5+ days of data for meaningful results; 14+ for reliability.
struct OjasEngine {

    // MARK: - Compute Ojas Score

    /// Compute overall Ojas (vitality) score from all available signals.
    /// Returns nil if insufficient data.
    static func computeOjas(signals: HealthSignals, baseline: HealthBaseline?) -> OjasResult? {
        // Need at least sleep or HRV to give a meaningful score
        guard signals.hrv != nil || signals.sleepDuration != nil else { return nil }

        let base = baseline ?? HealthBaseline.populationDefaults

        var contributors: [OjasContributor] = []
        var totalWeight: Double = 0
        var weightedSum: Double = 0

        // 1. Sleep quality (Nidra) — weight 25%
        if let sleep = signals.sleepDuration {
            let sleepHours = sleep / 3600.0
            let ideal: Double = 7.5 // hours
            let score = sleepScore(hours: sleepHours, deepMinutes: signals.deepSleepMinutes,
                                    remMinutes: signals.remSleepMinutes, ideal: ideal)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Sleep", signal: .sleep, score: score, status: status, weight: 0.25
            ))
            weightedSum += score * 0.25
            totalWeight += 0.25
        }

        // 2. Heart rhythm (Nadi) — weight 20%
        if let hrv = signals.hrv {
            let score = hrvScore(hrv: hrv, baseline: base.avgHRV, std: base.stdHRV)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Pulse", signal: .pulse, score: score, status: status, weight: 0.20
            ))
            weightedSum += score * 0.20
            totalWeight += 0.20
        }

        // 3. Blood Oxygen (Prana Vayu) — weight 10%
        if let spo2 = signals.spO2 {
            let score = spO2Score(spo2: spo2)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Oxygen", signal: .oxygen, score: score, status: status, weight: 0.10
            ))
            weightedSum += score * 0.10
            totalWeight += 0.10
        }

        // 4. Body warmth (Sparsha) — weight 8%
        if let temp = signals.wristTemp {
            let score = temperatureScore(deviation: temp)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Warmth", signal: .warmth, score: score, status: status, weight: 0.08
            ))
            weightedSum += score * 0.08
            totalWeight += 0.08
        }

        // 5. Breathing (Prana) — weight 8%
        if let resp = signals.respiratoryRate {
            let score = respiratoryScore(rate: resp, baseline: base.avgResp)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Breath", signal: .breath, score: score, status: status, weight: 0.08
            ))
            weightedSum += score * 0.08
            totalWeight += 0.08
        }

        // 6. Fitness (Bala) — weight 7%
        if let vo2 = signals.vo2Max {
            let score = vo2Score(vo2: vo2, baseline: base.avgVO2)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Fitness", signal: .fitness, score: score, status: status, weight: 0.07
            ))
            weightedSum += score * 0.07
            totalWeight += 0.07
        }

        // 7. Movement (Vyayama) — weight 7%
        if let steps = signals.steps {
            let score = movementScore(steps: steps)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Movement", signal: .movement, score: score, status: status, weight: 0.07
            ))
            weightedSum += score * 0.07
            totalWeight += 0.07
        }

        // 8. Recovery (Agni) — weight 5%
        if let recovery = signals.hrRecovery {
            let score = recoveryScore(drop: recovery)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Recovery", signal: .recovery, score: score, status: status, weight: 0.05
            ))
            weightedSum += score * 0.05
            totalWeight += 0.05
        }

        // 9. Active Energy (Agni) — weight 5%
        if let energy = signals.activeEnergy {
            let score = activeEnergyScore(kcal: energy)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Energy", signal: .energy, score: score, status: status, weight: 0.05
            ))
            weightedSum += score * 0.05
            totalWeight += 0.05
        }

        // 10. Mindfulness (Sattva) — weight 5%
        if let mindful = signals.mindfulMinutes, mindful > 0 {
            let score = mindfulScore(minutes: mindful)
            let status = signalStatus(score: score)
            contributors.append(OjasContributor(
                name: "Mindful", signal: .mindful, score: score, status: status, weight: 0.05
            ))
            weightedSum += score * 0.05
            totalWeight += 0.05
        }

        guard totalWeight > 0 else { return nil }

        // Normalize: redistribute weights proportionally to available signals
        let ojasScore = Int(round((weightedSum / totalWeight) * 100).clamped(to: 0...100))
        let agni = computeAgniType(signals: signals, baseline: base)
        let summary = ojasSummary(score: ojasScore)

        return OjasResult(
            score: ojasScore,
            summary: summary,
            agniType: agni,
            contributors: contributors,
            signalCount: contributors.count,
            isReliable: (baseline?.sampleDays ?? 0) >= 14,
            computedAt: .now
        )
    }

    // MARK: - Individual Signal Scoring (0.0–1.0)

    /// Sleep: optimal 7-8h, penalize <6h and >9.5h, reward deep sleep + REM.
    private static func sleepScore(hours: Double, deepMinutes: Double?, remMinutes: Double?, ideal: Double) -> Double {
        // Duration component (0.0–1.0)
        let durationScore: Double
        if hours < 4.0 {
            durationScore = 0.15
        } else if hours < 6.0 {
            durationScore = 0.3 + (hours - 4.0) / 2.0 * 0.3  // 0.3–0.6
        } else if hours <= 9.0 {
            // Optimal zone: peak at 7.5h
            let diff = abs(hours - ideal)
            durationScore = max(0.7, 1.0 - diff * 0.1)
        } else {
            // Oversleep (Kapha excess)
            durationScore = max(0.5, 1.0 - (hours - 9.0) * 0.15)
        }

        // Deep sleep bonus (0.0–0.10)
        let deepBonus: Double
        if let deep = deepMinutes {
            // 45-90 min deep sleep is ideal
            if deep >= 45 && deep <= 90 {
                deepBonus = 0.10
            } else if deep >= 30 {
                deepBonus = 0.05
            } else {
                deepBonus = 0.0
            }
        } else {
            deepBonus = 0.0
        }

        // REM bonus (0.0–0.05)
        let remBonus: Double
        if let rem = remMinutes {
            // 90-120 min REM is ideal
            if rem >= 60 && rem <= 120 {
                remBonus = 0.05
            } else if rem >= 30 {
                remBonus = 0.02
            } else {
                remBonus = 0.0
            }
        } else {
            remBonus = 0.0
        }

        return min(1.0, durationScore + deepBonus + remBonus)
    }

    /// HRV: near personal baseline is best. Too high or too low is a signal.
    private static func hrvScore(hrv: Double, baseline: Double, std: Double) -> Double {
        let effectiveStd = max(std, 5.0) // floor to avoid divide-by-near-zero
        let zScore = abs(hrv - baseline) / effectiveStd

        // Within 1 SD = excellent, 1-2 SD = moderate, >2 SD = concerning
        if zScore < 0.5 {
            return 0.95
        } else if zScore < 1.0 {
            return 0.85
        } else if zScore < 1.5 {
            return 0.70
        } else if zScore < 2.0 {
            return 0.55
        } else {
            return max(0.25, 0.55 - (zScore - 2.0) * 0.15)
        }
    }

    /// SpO2: 95-100% is healthy. Below 92% is concerning.
    private static func spO2Score(spo2: Double) -> Double {
        // spo2 comes as 0.0–1.0 from HealthKit
        let pct = spo2 > 1 ? spo2 : spo2 * 100 // normalize to %
        if pct >= 97 { return 0.95 }
        if pct >= 95 { return 0.85 }
        if pct >= 93 { return 0.65 }
        if pct >= 90 { return 0.40 }
        return 0.20 // dangerously low
    }

    /// Temperature: stable near baseline is ideal. Elevated = Pitta. Variable = Vata.
    private static func temperatureScore(deviation: Double) -> Double {
        let absDev = abs(deviation)
        if absDev < 0.2 {
            return 0.95  // very stable
        } else if absDev < 0.5 {
            return 0.80
        } else if absDev < 1.0 {
            return 0.60
        } else {
            return max(0.30, 0.60 - (absDev - 1.0) * 0.2)
        }
    }

    /// Respiratory rate: 12-20 is normal. Optimal 14-16.
    private static func respiratoryScore(rate: Double, baseline: Double) -> Double {
        if rate >= 12 && rate <= 20 {
            let deviation = abs(rate - baseline)
            if deviation < 1.5 {
                return 0.95
            } else if deviation < 3.0 {
                return 0.80
            } else {
                return 0.65
            }
        } else {
            return 0.40
        }
    }

    /// VO2 Max: higher is better, compare to personal trend.
    private static func vo2Score(vo2: Double, baseline: Double) -> Double {
        if baseline > 0 {
            let change = (vo2 - baseline) / baseline
            if change >= 0 { return min(1.0, 0.80 + change * 2.0) }  // improving
            if change > -0.05 { return 0.75 }  // stable
            return max(0.40, 0.75 + change * 3.0)  // declining
        }
        // Absolute scoring (no baseline)
        if vo2 >= 40 { return 0.90 }
        if vo2 >= 30 { return 0.75 }
        if vo2 >= 20 { return 0.55 }
        return 0.40
    }

    /// Movement: 5000-10000 steps is the sweet spot.
    private static func movementScore(steps: Int) -> Double {
        if steps >= 5000 && steps <= 12000 {
            return 0.90
        } else if steps >= 3000 {
            return 0.70
        } else if steps >= 1000 {
            return 0.50
        } else {
            return 0.30
        }
    }

    /// Heart rate recovery: higher drop = better fitness / Agni.
    private static func recoveryScore(drop: Double) -> Double {
        if drop >= 30 { return 0.95 }  // excellent
        if drop >= 20 { return 0.80 }  // good
        if drop >= 12 { return 0.65 }  // average
        return 0.40  // slow recovery
    }

    /// Active energy: 200-600 kcal active burn is healthy for most people.
    private static func activeEnergyScore(kcal: Double) -> Double {
        if kcal >= 200 && kcal <= 800 {
            return 0.90
        } else if kcal >= 100 {
            return 0.70
        } else if kcal >= 50 {
            return 0.50
        } else {
            return 0.30
        }
    }

    /// Mindfulness: any meditation is good. 10+ min is ideal.
    private static func mindfulScore(minutes: Double) -> Double {
        if minutes >= 20 { return 0.95 }  // excellent
        if minutes >= 10 { return 0.85 }  // good
        if minutes >= 5 { return 0.70 }   // some
        return 0.55  // brief
    }

    // MARK: - Agni Type

    /// Determine Agni (metabolic fire) type from signal patterns.
    static func computeAgniType(signals: HealthSignals, baseline: HealthBaseline) -> AgniType {
        // Vishama (irregular/Vata): erratic sleep + high HRV variance
        if let sleepOnset = signals.sleepOnsetHour {
            let onsetVariance = abs(sleepOnset - (baseline.avgSleepOnset ?? 22.5))
            if onsetVariance > 1.0 {
                return .vishama
            }
        }

        // Tikshna (sharp/Pitta): short sleep + elevated temp + high RHR
        let shortSleep = (signals.sleepDuration ?? 28800) < 21600  // < 6h
        let warmTemp = (signals.wristTemp ?? 0) > 0.4
        let fastHR = signals.restingHR != nil && signals.restingHR! > baseline.avgRHR * 1.08
        if (shortSleep && warmTemp) || (shortSleep && fastHR) {
            return .tikshna
        }

        // Manda (sluggish/Kapha): long sleep + low activity + slow recovery
        let longSleep = (signals.sleepDuration ?? 0) > 34200  // > 9.5h
        let lowSteps = (signals.steps ?? 5000) < 3000
        let slowRecovery = (signals.hrRecovery ?? 25) < 12
        if (longSleep && lowSteps) || (lowSteps && slowRecovery) {
            return .manda
        }

        // Sama (balanced): nothing stands out
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

/// Raw health signals from Apple Watch — input to OjasEngine.
struct HealthSignals {
    var hrv: Double?
    var restingHR: Double?
    var sleepDuration: TimeInterval?
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var sleepOnsetHour: Double?
    var wristTemp: Double?
    var respiratoryRate: Double?
    var vo2Max: Double?
    var walkingSteadiness: Double?
    var steps: Int?
    var hrRecovery: Double?
    var spO2: Double?
    var activeEnergy: Double?
    var mindfulMinutes: Double?
}

/// Personal health baselines computed from 14+ days of data.
struct HealthBaseline {
    var avgHRV: Double = 45.0
    var stdHRV: Double = 12.0
    var avgRHR: Double = 68.0
    var avgResp: Double = 15.0
    var avgVO2: Double = 35.0
    var avgSleepOnset: Double? = 22.5 // 10:30 PM
    var sampleDays: Int = 0

    static let populationDefaults = HealthBaseline()
}

/// Result of Ojas computation.
struct OjasResult {
    let score: Int            // 0–100
    let summary: String       // "Vital", "Steady", "Moderate", "Depleted", "Rest"
    let agniType: AgniType
    let contributors: [OjasContributor]
    let signalCount: Int
    let isReliable: Bool      // 14+ days of baseline data
    let computedAt: Date
}

/// One contributor to the Ojas score.
struct OjasContributor {
    let name: String          // "Sleep", "Pulse", "Warmth", etc.
    let signal: SignalType
    let score: Double         // 0.0–1.0
    let status: SignalStatus
    let weight: Double        // how much it contributes
}

enum SignalType: String {
    case sleep, pulse, warmth, breath, fitness, movement, recovery, oxygen, energy, mindful
}

enum SignalStatus: String {
    case good     // ≥ 0.75
    case moderate // 0.50–0.74
    case low      // < 0.50

    var label: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Fair"
        case .low: return "Low"
        }
    }
}

enum AgniType: String {
    case sama     = "Sama"      // balanced metabolism
    case vishama  = "Vishama"   // irregular (Vata-type)
    case tikshna  = "Tikshna"   // intense (Pitta-type)
    case manda    = "Manda"     // sluggish (Kapha-type)

    var description: String {
        switch self {
        case .sama:    return "Balanced digestion"
        case .vishama: return "Irregular rhythm"
        case .tikshna: return "Running intense"
        case .manda:   return "Sluggish metabolism"
        }
    }
}

// MARK: - Clamped Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
