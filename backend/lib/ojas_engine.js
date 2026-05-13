/**
 * Ojas (Vitality) Engine — backend JavaScript port of the Swift OjasEngine.
 *
 * Ojas in Ayurveda is the subtle essence of all seven Dhatus (tissues).
 * It represents overall vitality, immunity, and life force.
 *
 * Derives Ojas from a transparent weighted sum of evidence-based vitality drivers:
 *
 *   PRIMARY CONTRIBUTORS (sum to 1.00 of base score)
 *     HRV            35%  — Plews & Buchheit: gold-standard autonomic recovery marker
 *     Sleep          22%  — duration + deep + REM architecture
 *     Resting HR     18%  — cardiac efficiency / chronic stress proxy
 *     Wrist Temp     10%  — illness / circadian phase / stress
 *     Respiration     8%  — diurnal autonomic state
 *     Activity        7%  — daily movement (steps + active energy blended)
 *
 *   MODIFIERS (added/subtracted from the base 0-100 score)
 *     HR Recovery    +/-5    — strong post-exertion drop boosts; sluggish penalizes
 *     Stand Hours    +/-4    — sedentary penalty / good distribution bonus
 *     SpO2           cap     — <92% caps the final score at 60
 *     Daylight       +/-5    — <30 min penalty / >=120 min bonus (circadian)
 *     Audio          -5      — chronic env audio >85 dB penalty
 *     Mindfulness    +5      — >=10 min mindful minutes
 *     Cardiac Alerts -10     — any AFib / irregular rhythm / high-HR events today
 *     Walking Steady -5      — <0.4 fraction (Vata-imbalance gait)
 *     Sleep Apnea    -5/-10  — breathing disturbance events
 *     Falls          -10     — strong vata-imbalance / vitality penalty
 *     Low Cardio Fit -3      — low fitness alert
 *     Vagal Tone     +/-5    — RMSSD bonus/penalty
 *     UV Load        -2      — heavy sun exposure
 *
 * All scores use PERSONAL baselines when available, population defaults otherwise.
 * Reliable when baseline sampleDays >= 14.
 */

import { getDefaultWeights } from "./engine_weights.js";

// ─── Population Baseline Defaults ───────────────────────────────────────────

const POPULATION_BASELINE = Object.freeze({
    avgHRV: 45.0,
    stdHRV: 12.0,
    avgRHR: 68.0,
    stdRHR: 6.0,
    avgResp: 15.0,
    avgVO2: 35.0,
    avgSleepOnset: 22.5,
    sampleDays: 0,
});

// ─── Per-signal Scoring Functions (0.0 - 1.0) ──────────────────────────────

/**
 * Sleep: optimal 7-8h, penalize <6h and >9.5h, reward deep sleep + REM.
 */
function sleepScore(hours, deepMinutes, remMinutes, coreMinutes) {
    let durationScore;
    if (hours < 4.0) {
        durationScore = 0.15;
    } else if (hours < 6.0) {
        durationScore = 0.30 + ((hours - 4.0) / 2.0) * 0.30;
    } else if (hours <= 9.0) {
        const diff = Math.abs(hours - 7.5);
        durationScore = Math.max(0.70, 1.00 - diff * 0.10);
    } else {
        durationScore = Math.max(0.50, 1.00 - (hours - 9.0) * 0.15);
    }

    let deepBonus = 0;
    if (deepMinutes != null) {
        if (deepMinutes >= 45 && deepMinutes <= 90) deepBonus = 0.10;
        else if (deepMinutes >= 30) deepBonus = 0.05;
    }

    let remBonus = 0;
    if (remMinutes != null) {
        if (remMinutes >= 60 && remMinutes <= 120) remBonus = 0.05;
        else if (remMinutes >= 30) remBonus = 0.02;
    }

    let coreBonus = 0;
    if (coreMinutes != null) {
        if (coreMinutes >= 180 && coreMinutes <= 300) coreBonus = 0.03;
        else if (coreMinutes >= 120) coreBonus = 0.01;
    }

    return Math.min(1.0, durationScore + deepBonus + remBonus + coreBonus);
}

/**
 * HRV: near personal baseline = best. Z-score driven.
 */
function hrvScore(hrv, baselineAvg, baselineStd) {
    const effectiveStd = Math.max(baselineStd, 5.0);
    const z = Math.abs(hrv - baselineAvg) / effectiveStd;
    if (z < 0.5) return 0.95;
    if (z < 1.0) return 0.85;
    if (z < 1.5) return 0.70;
    if (z < 2.0) return 0.55;
    return Math.max(0.25, 0.55 - (z - 2.0) * 0.15);
}

/**
 * RHR: prefer near-baseline; reward small drops, penalize large rises.
 */
function restingHRScore(rhr, baselineAvg, baselineStd) {
    const effectiveStd = Math.max(baselineStd, 4.0);
    const z = (rhr - baselineAvg) / effectiveStd;
    if (z <= -0.5) return 0.95; // lower than baseline = excellent
    if (z <= 0.3) return 0.88;  // near baseline
    if (z <= 1.0) return 0.70;
    if (z <= 2.0) return 0.50;
    return 0.30;
}

/**
 * Temperature deviation: stable near baseline = best.
 */
function temperatureScore(deviation) {
    const absDev = Math.abs(deviation);
    if (absDev < 0.2) return 0.95;
    if (absDev < 0.5) return 0.80;
    if (absDev < 1.0) return 0.60;
    return Math.max(0.30, 0.60 - (absDev - 1.0) * 0.20);
}

/**
 * Respiratory rate: 12-20 normal, optimal close to baseline.
 */
function respiratoryScore(rate, baselineAvg) {
    if (rate >= 12 && rate <= 20) {
        const dev = Math.abs(rate - baselineAvg);
        if (dev < 1.5) return 0.95;
        if (dev < 3.0) return 0.80;
        return 0.65;
    }
    return 0.40;
}

/**
 * Movement: 5k-12k steps sweet spot.
 */
function movementScore(steps) {
    if (steps >= 5000 && steps <= 12000) return 0.90;
    if (steps >= 3000) return 0.70;
    if (steps >= 1000) return 0.50;
    return 0.30;
}

/**
 * Active energy: 200-800 kcal active = healthy.
 */
function activeEnergyScore(kcal) {
    if (kcal >= 200 && kcal <= 800) return 0.90;
    if (kcal >= 100) return 0.70;
    if (kcal >= 50) return 0.50;
    return 0.30;
}

// ─── Signal Status ──────────────────────────────────────────────────────────

function signalStatus(score) {
    if (score >= 0.75) return "good";
    if (score >= 0.50) return "moderate";
    return "low";
}

// ─── Ojas Summary ───────────────────────────────────────────────────────────

function ojasSummary(score) {
    if (score >= 85) return "Vital";
    if (score >= 70) return "Steady";
    if (score >= 55) return "Moderate";
    if (score >= 40) return "Depleted";
    return "Rest";
}

// ─── Agni Type Computation ──────────────────────────────────────────────────

/**
 * Determine Agni type from health signals and baseline.
 *
 * @param {object} signals - Health signal values
 * @param {object} baseline - Personal baseline
 * @returns {{ type: string, description: string }}
 */
function computeAgniType(signals, baseline) {
    // Vishama (Vata): erratic sleep onset
    if (signals.sleepOnsetHour != null) {
        const onsetVar = Math.abs(
            signals.sleepOnsetHour - (baseline.avgSleepOnset ?? 22.5)
        );
        if (onsetVar > 1.0) {
            return { type: "Vishama", description: "Irregular rhythm" };
        }
    }

    // Tikshna (Pitta): short sleep + warm temp / fast HR
    const sleepSec = signals.sleepDuration ?? 28800;
    const shortSleep = sleepSec < 21600; // < 6h
    const warmTemp = (signals.wristTemp ?? 0) > 0.4;
    const fastHR =
        signals.restingHR != null &&
        signals.restingHR > baseline.avgRHR * 1.08;
    if ((shortSleep && warmTemp) || (shortSleep && fastHR)) {
        return { type: "Tikshna", description: "Running intense" };
    }

    // Manda (Kapha): long sleep + low activity / slow recovery
    const longSleep = (signals.sleepDuration ?? 0) > 34200; // > 9.5h
    const lowSteps = (signals.steps ?? 5000) < 3000;
    const slowRecovery = (signals.hrRecovery ?? 25) < 12;
    if ((longSleep && lowSteps) || (lowSteps && slowRecovery)) {
        return { type: "Manda", description: "Sluggish metabolism" };
    }

    return { type: "Sama", description: "Balanced digestion" };
}

// ─── Main Computation ───────────────────────────────────────────────────────

/**
 * Compute overall Ojas vitality score from health signals.
 *
 * @param {object} signals - Health data from Firestore snapshot
 * @param {object} [baseline] - Personal baseline (null = population defaults)
 * @param {object} [weights] - Engine weights override (null = defaults)
 * @returns {object|null} OjasResult or null if insufficient data
 *
 * Signal keys expected from Firestore healthSnapshot:
 *   hrv, restingHR, sleepHours, deepSleepMins, remSleepMins,
 *   wristTemp, respRate, steps, activeEnergy, hrRecovery,
 *   standHours, spO2, daylightMins, envAudioExposure,
 *   mindfulMins, irregularRhythmCount, afibBurden, highHRCount,
 *   walkingSteadiness, sleepApneaCount, fallCount,
 *   lowCardioFitnessCount, rmssd, uvExposure,
 *   sleepOnsetHour (optional),
 *   heartRate, vo2Max, exerciseMins, coreSleepMins, pnn50,
 *   walkingHR, walkingAsymmetry, doubleSupport,
 *   headphoneAudio, lowHRCount, bodyTemp
 */
export function computeOjas(signals, baseline, weights) {
    // Need at least HRV or sleep to compute anything meaningful
    if (signals.hrv == null && signals.sleepHours == null) return null;

    const base = baseline ?? POPULATION_BASELINE;
    const w = weights?.ojas?.primaryWeights ?? getDefaultWeights().ojas.primaryWeights;

    // ── PRIMARY CONTRIBUTORS ────────────────────────────────────────────
    const contributors = [];
    let weightedSum = 0;
    let totalWeight = 0;

    // 1. HRV — 35%
    if (signals.hrv != null) {
        const s = hrvScore(signals.hrv, base.avgHRV, base.stdHRV);
        const wt = w.hrv;
        contributors.push({
            name: "HRV",
            score: s,
            status: signalStatus(s),
            weight: wt,
            raw: signals.hrv,
        });
        weightedSum += s * wt;
        totalWeight += wt;
    }

    // 2. Sleep — 22%
    if (signals.sleepHours != null) {
        const s = sleepScore(
            signals.sleepHours,
            signals.deepSleepMins,
            signals.remSleepMins,
            signals.coreSleepMins
        );
        const wt = w.sleep;
        contributors.push({
            name: "Sleep",
            score: s,
            status: signalStatus(s),
            weight: wt,
            raw: signals.sleepHours,
        });
        weightedSum += s * wt;
        totalWeight += wt;
    }

    // 3. Resting HR — 18%
    if (signals.restingHR != null) {
        const s = restingHRScore(signals.restingHR, base.avgRHR, base.stdRHR);
        const wt = w.restingHR;
        contributors.push({
            name: "RHR",
            score: s,
            status: signalStatus(s),
            weight: wt,
            raw: signals.restingHR,
        });
        weightedSum += s * wt;
        totalWeight += wt;
    }

    // 4. Wrist Temp — 10%
    if (signals.wristTemp != null) {
        const s = temperatureScore(signals.wristTemp);
        const wt = w.wristTemp;
        contributors.push({
            name: "Warmth",
            score: s,
            status: signalStatus(s),
            weight: wt,
            raw: signals.wristTemp,
        });
        weightedSum += s * wt;
        totalWeight += wt;
    }

    // 5. Respiration — 8%
    if (signals.respRate != null) {
        const s = respiratoryScore(signals.respRate, base.avgResp);
        const wt = w.respiration;
        contributors.push({
            name: "Breath",
            score: s,
            status: signalStatus(s),
            weight: wt,
            raw: signals.respRate,
        });
        weightedSum += s * wt;
        totalWeight += wt;
    }

    // 6. Activity blend — 7%
    const stScore = signals.steps != null ? movementScore(signals.steps) : null;
    const aeScore =
        signals.activeEnergy != null ? activeEnergyScore(signals.activeEnergy) : null;
    if (stScore != null || aeScore != null) {
        const parts = [stScore, aeScore].filter((x) => x != null);
        const s = parts.reduce((a, b) => a + b, 0) / parts.length;
        const wt = w.activity;
        contributors.push({
            name: "Activity",
            score: s,
            status: signalStatus(s),
            weight: wt,
            raw: { steps: signals.steps, activeEnergy: signals.activeEnergy },
        });
        weightedSum += s * wt;
        totalWeight += wt;
    }

    if (totalWeight <= 0) return null;

    // Base 0-100 score (renormalized over available primary weight)
    const baseScore = (weightedSum / totalWeight) * 100;

    // ── MODIFIERS ───────────────────────────────────────────────────────
    const modifiers = [];
    let modSum = 0;
    let ceiling = 100;

    // HR Recovery (+/-5)
    if (signals.hrRecovery != null) {
        let delta;
        if (signals.hrRecovery >= 25) delta = 5;
        else if (signals.hrRecovery >= 15) delta = 2;
        else if (signals.hrRecovery >= 8) delta = -1;
        else delta = -5;
        modifiers.push({ name: "HR Recovery", delta, raw: signals.hrRecovery });
        modSum += delta;
    }

    // Stand hours (+/-4)
    if (signals.standHours != null) {
        let delta;
        if (signals.standHours >= 12) delta = 2;
        else if (signals.standHours >= 8) delta = 0;
        else if (signals.standHours >= 5) delta = -2;
        else delta = -4;
        modifiers.push({ name: "Stand Hours", delta, raw: signals.standHours });
        modSum += delta;
    }

    // SpO2 cap (< 92% caps final at 60)
    if (signals.spO2 != null) {
        const pct = signals.spO2 > 1 ? signals.spO2 : signals.spO2 * 100;
        if (pct < 92) {
            ceiling = Math.min(ceiling, 60);
            modifiers.push({
                name: "SpO2 Cap",
                delta: 0,
                raw: pct,
                note: "caps total at 60",
            });
        } else if (pct < 95) {
            modifiers.push({ name: "SpO2", delta: -2, raw: pct });
            modSum += -2;
        }
    }

    // Daylight (+/-5)
    if (signals.daylightMins != null) {
        let delta;
        if (signals.daylightMins >= 120) delta = 3;
        else if (signals.daylightMins >= 60) delta = 1;
        else if (signals.daylightMins >= 30) delta = 0;
        else delta = -5;
        modifiers.push({ name: "Daylight", delta, raw: signals.daylightMins });
        modSum += delta;
    }

    // Audio exposure (-5 if chronic > 85 dB)
    if (signals.envAudioExposure != null && signals.envAudioExposure > 85) {
        const delta = signals.envAudioExposure > 90 ? -5 : -2;
        modifiers.push({ name: "Audio Load", delta, raw: signals.envAudioExposure });
        modSum += delta;
    }

    // Mindfulness (+5)
    if (signals.mindfulMins != null && signals.mindfulMins > 0) {
        let delta;
        if (signals.mindfulMins >= 20) delta = 5;
        else if (signals.mindfulMins >= 10) delta = 3;
        else delta = 1;
        modifiers.push({ name: "Mindful", delta, raw: signals.mindfulMins });
        modSum += delta;
    }

    // Cardiac alerts (-10 if any)
    const irregular = signals.irregularRhythmCount ?? 0;
    const afib = signals.afibBurden ?? 0;
    const highHR = signals.highHRCount ?? 0;
    if (irregular > 0 || afib > 0 || highHR > 0) {
        const delta = afib > 0 ? -10 : -5;
        modifiers.push({
            name: "Cardiac Alerts",
            delta,
            raw: { irregular, afib, highHR },
        });
        modSum += delta;
    }

    // Walking steadiness (-5 if < 0.4)
    if (signals.walkingSteadiness != null && signals.walkingSteadiness < 0.4) {
        modifiers.push({
            name: "Gait Steadiness",
            delta: -5,
            raw: signals.walkingSteadiness,
        });
        modSum += -5;
    }

    // Sleep apnea (-5 if 1-2, -10 if 3+)
    if (signals.sleepApneaCount != null && signals.sleepApneaCount > 0) {
        const delta = signals.sleepApneaCount >= 3 ? -10 : -5;
        modifiers.push({
            name: "Sleep Apnea",
            delta,
            raw: signals.sleepApneaCount,
        });
        modSum += delta;
    }

    // Falls (-10 if any)
    if (signals.fallCount != null && signals.fallCount > 0) {
        modifiers.push({ name: "Falls", delta: -10, raw: signals.fallCount });
        modSum += -10;
    }

    // Low cardio fitness (-3)
    if (
        signals.lowCardioFitnessCount != null &&
        signals.lowCardioFitnessCount > 0
    ) {
        modifiers.push({
            name: "Low Cardio Fit",
            delta: -3,
            raw: signals.lowCardioFitnessCount,
        });
        modSum += -3;
    }

    // RMSSD / Vagal tone (+/-5)
    if (signals.rmssd != null) {
        if (signals.rmssd >= 50) {
            const delta = signals.rmssd >= 80 ? 5 : 3;
            modifiers.push({ name: "Vagal Tone", delta, raw: signals.rmssd });
            modSum += delta;
        } else if (signals.rmssd < 15) {
            modifiers.push({ name: "Vagal Tone", delta: -3, raw: signals.rmssd });
            modSum += -3;
        }
    }

    // UV over-exposure (-2 if MED > 6)
    if (signals.uvExposure != null && signals.uvExposure > 6) {
        modifiers.push({ name: "UV Load", delta: -2, raw: signals.uvExposure });
        modSum += -2;
    }

    // Heart Rate Stress — current HR / resting HR ratio (Nadi Pariksha proxy)
    if (signals.heartRate != null && signals.restingHR != null && signals.restingHR > 0) {
        const ratio = signals.heartRate / signals.restingHR;
        if (ratio <= 1.10) {
            modifiers.push({ name: "Pulse Calm", delta: 2, raw: { hr: signals.heartRate, ratio } });
            modSum += 2;
        } else if (ratio > 2.0) {
            modifiers.push({ name: "Pulse Stress", delta: -5, raw: { hr: signals.heartRate, ratio } });
            modSum += -5;
        } else if (ratio > 1.5) {
            modifiers.push({ name: "Pulse Elevated", delta: -3, raw: { hr: signals.heartRate, ratio } });
            modSum += -3;
        }
    }

    // VO₂ Max — aerobic capacity / Prana reservoir
    if (signals.vo2Max != null) {
        let delta;
        if (signals.vo2Max >= 50) delta = 5;
        else if (signals.vo2Max >= 42) delta = 3;
        else if (signals.vo2Max >= 35) delta = 0;
        else if (signals.vo2Max >= 25) delta = -2;
        else delta = -5;
        if (delta !== 0) {
            modifiers.push({ name: "Cardio Fitness", delta, raw: signals.vo2Max });
            modSum += delta;
        }
    }

    // Exercise minutes — Vyayama (half-capacity effort is ideal in Ayurveda)
    if (signals.exerciseMins != null && signals.exerciseMins > 0) {
        let delta;
        if (signals.exerciseMins > 150) delta = -2;
        else if (signals.exerciseMins >= 20) delta = 3;
        else if (signals.exerciseMins >= 10) delta = 1;
        else delta = 0;
        if (delta !== 0) {
            modifiers.push({ name: "Exercise", delta, raw: signals.exerciseMins });
            modSum += delta;
        }
    }

    // PNN50 — parasympathetic strength (supplements RMSSD vagal tone)
    if (signals.pnn50 != null) {
        if (signals.pnn50 >= 0.25) {
            modifiers.push({ name: "Vagal PNN50", delta: 2, raw: signals.pnn50 });
            modSum += 2;
        } else if (signals.pnn50 < 0.03) {
            modifiers.push({ name: "Vagal PNN50", delta: -2, raw: signals.pnn50 });
            modSum += -2;
        }
    }

    // Walking HR efficiency — cardiac recovery during movement
    if (signals.walkingHR != null && signals.restingHR != null && signals.restingHR > 0) {
        const ratio = signals.walkingHR / signals.restingHR;
        if (ratio < 1.3) {
            modifiers.push({ name: "Walk Efficiency", delta: 3, raw: { walkingHR: signals.walkingHR, ratio } });
            modSum += 3;
        } else if (ratio > 1.8) {
            modifiers.push({ name: "Walk Efficiency", delta: -3, raw: { walkingHR: signals.walkingHR, ratio } });
            modSum += -3;
        }
    }

    // Gait asymmetry — structural Vata imbalance
    if (signals.walkingAsymmetry != null && signals.walkingAsymmetry > 0.10) {
        modifiers.push({ name: "Gait Asymmetry", delta: -2, raw: signals.walkingAsymmetry });
        modSum += -2;
    }

    // Gait double support — instability indicator
    if (signals.doubleSupport != null && signals.doubleSupport > 0.30) {
        modifiers.push({ name: "Gait Support", delta: -2, raw: signals.doubleSupport });
        modSum += -2;
    }

    // Headphone audio — additional ear stress (separate from environmental)
    if (signals.headphoneAudio != null && signals.headphoneAudio > 85) {
        const delta = signals.headphoneAudio > 90 ? -3 : -1;
        modifiers.push({ name: "Headphone Load", delta, raw: signals.headphoneAudio });
        modSum += delta;
    }

    // Low HR events — bradycardia (Kapha excess / cardiac concern)
    if (signals.lowHRCount != null && signals.lowHRCount > 0) {
        modifiers.push({ name: "Low HR Events", delta: -2, raw: signals.lowHRCount });
        modSum += -2;
    }

    // Body temperature — fever = active illness = Ojas critically depleted
    if (signals.bodyTemp != null) {
        if (signals.bodyTemp > 38.0) {
            ceiling = Math.min(ceiling, 55);
            modifiers.push({ name: "Fever Cap", delta: 0, raw: signals.bodyTemp, note: "caps total at 55" });
        } else if (signals.bodyTemp > 37.5) {
            modifiers.push({ name: "Warm Temp", delta: -3, raw: signals.bodyTemp });
            modSum += -3;
        }
    }

    // ── FINAL SCORE ─────────────────────────────────────────────────────
    const preFinal = baseScore + modSum;
    const finalScore = Math.round(Math.min(ceiling, Math.max(0, preFinal)));

    // Agni type
    const sleepDurationSec = signals.sleepHours != null ? signals.sleepHours * 3600 : null;
    const agniSignals = {
        ...signals,
        sleepDuration: sleepDurationSec,
    };
    const agni = computeAgniType(agniSignals, base);

    return {
        score: finalScore,
        baseScore: Math.round(baseScore),
        summary: ojasSummary(finalScore),
        agniType: agni.type,
        agniDescription: agni.description,
        contributors,
        modifiers,
        ceiling: Math.round(ceiling),
        modifierDelta: Math.round(modSum),
        signalCount: contributors.length + modifiers.length,
        isReliable: (base.sampleDays ?? 0) >= 14,
        computedAt: new Date().toISOString(),
    };
}
