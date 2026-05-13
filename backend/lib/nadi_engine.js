/**
 * Nadi (Pulse) Engine — backend JavaScript port of the Swift NadiEngine.
 *
 * Maps Apple Watch passive cardiovascular + autonomic signals to Ayurvedic
 * Nadi (pulse) qualities using an 11-signal weighted dosha classifier.
 *
 * Classical Nadi Pariksha examines pulse at the radial artery for three qualities:
 *   Sarpa Gati  (Vata)  — irregular, thin, fast
 *   Manduka Gati (Pitta) — jumping, bounding, moderate
 *   Hamsa Gati  (Kapha) — slow, steady, broad
 *
 * LIMITATION: Digital Nadi Monitoring is a complement to, NOT a replacement for,
 * traditional Nadi Pariksha. We track rhythm/rate/breath/temp/gait patterns that
 * PARALLEL what a Vaidya feels with three fingers.
 *
 * Research basis (v2):
 *   - AIIMS / CSIR-IGIB: Prakriti types have distinct HRV signatures
 *   - Rapolu 2017: HRV-cardiointervalography correlates with Vaidya pulse (k=0.78)
 *   - Joshi (Nadi Tarangini): pulse-waveform -> dosha classifier
 *
 * 11 input signals:
 *   HRV (0.30), RHR (0.15), Walk/RHR ratio (0.10), Respiration (0.15),
 *   Sleep (0.12), Wrist Temp (0.08), Gait (0.05), Cardiac Alerts (0.05),
 *   RMSSD (0.15), Sleep Apnea (0.05), Falls (0.03)
 */

import { getDefaultWeights } from "./engine_weights.js";

// ─── Population Baseline Defaults ───────────────────────────────────────────

const POPULATION_BASELINE = Object.freeze({
    avgHRV: 45.0,
    stdHRV: 12.0,
    avgRHR: 68.0,
    stdRHR: 6.0,
    avgResp: 15.0,
    sampleCount: 0,
});

// ─── Helpers ────────────────────────────────────────────────────────────────

function zScore(value, mean, std) {
    if (std <= 0) return 0;
    return (value - mean) / std;
}

/** Create a dosha vector object */
function dv(vata, pitta, kapha) {
    return { vata, pitta, kapha };
}

// ─── Per-Signal Dosha Mapping ───────────────────────────────────────────────

/** HRV: high z -> Vata (variable), low z -> Kapha (steady), mid -> Pitta */
function doshaForHRV(z) {
    if (z > 1.0) return dv(0.65, 0.25, 0.10);
    if (z > 0.3) return dv(0.45, 0.40, 0.15);
    if (z > -0.3) return dv(0.25, 0.55, 0.20);
    if (z > -1.0) return dv(0.20, 0.40, 0.40);
    return dv(0.15, 0.20, 0.65);
}

/** RHR: high z -> Vata/Pitta (rapid), low z -> Kapha (slow) */
function doshaForRHR(z) {
    if (z > 1.0) return dv(0.50, 0.40, 0.10);
    if (z > 0.3) return dv(0.40, 0.45, 0.15);
    if (z > -0.3) return dv(0.30, 0.45, 0.25);
    if (z > -1.0) return dv(0.20, 0.30, 0.50);
    return dv(0.10, 0.20, 0.70);
}

/** Walking/RHR ratio: ~1.5-1.8 balanced Pitta. >2 -> Vata, <1.3 -> Kapha */
function doshaForWalkRatio(r) {
    if (r >= 2.0) return dv(0.55, 0.35, 0.10);
    if (r >= 1.5) return dv(0.30, 0.55, 0.15);
    if (r >= 1.3) return dv(0.20, 0.40, 0.40);
    return dv(0.15, 0.20, 0.65);
}

/** Respiratory rate deviation: high -> Vata, mid -> Pitta, low -> Kapha */
function doshaForResp(rate, baseline) {
    const dev = rate - baseline;
    if (dev > 3) return dv(0.65, 0.25, 0.10);
    if (dev > 1) return dv(0.40, 0.45, 0.15);
    if (dev > -1) return dv(0.25, 0.55, 0.20);
    if (dev > -3) return dv(0.15, 0.40, 0.45);
    return dv(0.10, 0.20, 0.70);
}

/** Sleep: short/fragmented -> Vata, balanced -> Pitta, long/heavy -> Kapha */
function doshaForSleep(hours, deepMin, remMin) {
    if (hours < 6.0) {
        const lowDeep = (deepMin ?? 60) < 30;
        return dv(lowDeep ? 0.65 : 0.55, 0.30, lowDeep ? 0.05 : 0.15);
    }
    if (hours < 7.0) return dv(0.40, 0.45, 0.15);
    if (hours < 8.5) return dv(0.25, 0.50, 0.25);
    if (hours < 9.5) return dv(0.15, 0.40, 0.45);
    return dv(0.10, 0.20, 0.70);
}

/** Wrist-temp deviation: cold -> Vata, hot -> Pitta, stable -> Kapha */
function doshaForTemp(deviation) {
    if (deviation > 0.5) return dv(0.20, 0.65, 0.15);
    if (deviation > 0.1) return dv(0.25, 0.50, 0.25);
    if (deviation > -0.1) return dv(0.20, 0.40, 0.40);
    if (deviation > -0.5) return dv(0.50, 0.30, 0.20);
    return dv(0.65, 0.20, 0.15);
}

/** Gait: irregular -> Vata, smooth -> Kapha, balanced -> Pitta */
function doshaForGait(asymmetry, doubleSupport) {
    const irregularity = asymmetry + Math.max(0, doubleSupport - 0.30);
    if (irregularity > 0.20) return dv(0.65, 0.25, 0.10);
    if (irregularity > 0.10) return dv(0.40, 0.45, 0.15);
    if (irregularity > 0.04) return dv(0.25, 0.50, 0.25);
    return dv(0.15, 0.40, 0.45);
}

/** RMSSD/pNN50 beat-to-beat: high vagal -> Kapha, low -> Vata, mid -> Pitta */
function doshaForBeatToBeat(rmssd, pnn50) {
    if (rmssd >= 60 && pnn50 >= 0.05) return dv(0.20, 0.30, 0.50);
    if (rmssd >= 40 && pnn50 >= 0.03) return dv(0.20, 0.55, 0.25);
    if (rmssd >= 25) return dv(0.40, 0.45, 0.15);
    if (rmssd >= 15) return dv(0.60, 0.30, 0.10);
    return dv(0.75, 0.20, 0.05);
}

/** Sleep-apnea events -> Vata-affinity (Prana disturbance) */
function doshaForApnea(count) {
    if (count >= 5) return dv(0.75, 0.20, 0.05);
    if (count >= 2) return dv(0.60, 0.30, 0.10);
    return dv(0.45, 0.40, 0.15);
}

/** Cardiac alerts -> strong Vata-imbalance signal */
function doshaForAlerts(irregular, afibBurden, highHR) {
    const load = irregular + highHR + afibBurden * 50;
    if (load >= 5) return dv(0.75, 0.20, 0.05);
    if (load >= 2) return dv(0.60, 0.30, 0.10);
    if (load > 0) return dv(0.45, 0.40, 0.15);
    return dv(0.20, 0.40, 0.40);
}

// ─── Main Computation ───────────────────────────────────────────────────────

/**
 * Compute Nadi (dosha balance) from health signals.
 *
 * @param {object} signals - Health data from Firestore snapshot
 * @param {object} [baseline] - Personal baseline (null = population defaults)
 * @param {object} [weights] - Engine weights override (null = defaults)
 * @returns {object|null} NadiResult or null if insufficient data
 *
 * Signal keys expected:
 *   hrv, rmssd, pnn50, restingHR, walkingHR, respRate,
 *   sleepHours, deepSleepMins, remSleepMins, wristTemp,
 *   walkingAsymmetry, doubleSupport, irregularRhythmCount,
 *   afibBurden, highHRCount, sleepApneaCount, fallCount
 */
export function computeNadi(signals, baseline, weights) {
    // HRV is the irreducible primary — without it, no Nadi analysis
    if (signals.hrv == null) return null;

    const base = baseline ?? POPULATION_BASELINE;
    const sw = weights?.nadi?.signalWeights ?? getDefaultWeights().nadi.signalWeights;

    const contributors = [];

    // ── 1. HRV deviation (weight 0.30) ──────────────────────────────────
    const hrvZ = zScore(signals.hrv, base.avgHRV, Math.max(base.stdHRV, 5.0));
    contributors.push({
        signal: "hrv",
        label: "HRV",
        raw: signals.hrv,
        doshaVector: doshaForHRV(hrvZ),
        weight: sw.hrv,
    });

    // ── 2. RHR deviation (weight 0.15) ──────────────────────────────────
    if (signals.restingHR != null) {
        const rhrZ = zScore(signals.restingHR, base.avgRHR, Math.max(base.stdRHR, 4.0));
        contributors.push({
            signal: "restingHR",
            label: "RHR",
            raw: signals.restingHR,
            doshaVector: doshaForRHR(rhrZ),
            weight: sw.restingHR,
        });
    }

    // ── 3. Walking-HR vs RHR ratio (weight 0.10) ────────────────────────
    if (signals.walkingHR != null && signals.restingHR != null && signals.restingHR > 0) {
        const ratio = signals.walkingHR / signals.restingHR;
        contributors.push({
            signal: "walkRatio",
            label: "Walk/Rest",
            raw: ratio,
            doshaVector: doshaForWalkRatio(ratio),
            weight: sw.walkRatio,
        });
    }

    // ── 4. Respiratory rate (weight 0.15) ────────────────────────────────
    if (signals.respRate != null) {
        contributors.push({
            signal: "respiration",
            label: "Breath",
            raw: signals.respRate,
            doshaVector: doshaForResp(signals.respRate, base.avgResp),
            weight: sw.respiration,
        });
    }

    // ── 5. Sleep architecture (weight 0.12) ─────────────────────────────
    if (signals.sleepHours != null) {
        contributors.push({
            signal: "sleep",
            label: "Sleep",
            raw: signals.sleepHours,
            doshaVector: doshaForSleep(
                signals.sleepHours,
                signals.deepSleepMins,
                signals.remSleepMins
            ),
            weight: sw.sleep,
        });
    }

    // ── 6. Wrist temp deviation (weight 0.08) ───────────────────────────
    if (signals.wristTemp != null) {
        contributors.push({
            signal: "wristTemp",
            label: "Warmth",
            raw: signals.wristTemp,
            doshaVector: doshaForTemp(signals.wristTemp),
            weight: sw.wristTemp,
        });
    }

    // ── 7. Gait quality (weight 0.05) ───────────────────────────────────
    if (signals.walkingAsymmetry != null || signals.doubleSupport != null) {
        const asym = signals.walkingAsymmetry ?? 0;
        const dbl = signals.doubleSupport ?? 0;
        contributors.push({
            signal: "gait",
            label: "Gait",
            raw: { asymmetry: asym, doubleSupport: dbl },
            doshaVector: doshaForGait(asym, dbl),
            weight: sw.gait,
        });
    }

    // ── 8. Cardiac alerts (weight 0.05) ─────────────────────────────────
    const irregular = signals.irregularRhythmCount ?? 0;
    const afib = signals.afibBurden ?? 0;
    const highHR = signals.highHRCount ?? 0;
    if (irregular > 0 || afib > 0 || highHR > 0) {
        contributors.push({
            signal: "cardiacAlerts",
            label: "Alerts",
            raw: { irregular, afib, highHR },
            doshaVector: doshaForAlerts(irregular, afib, highHR),
            weight: sw.cardiacAlerts,
        });
    }

    // ── 9. RMSSD beat-to-beat (weight 0.15) ─────────────────────────────
    if (signals.rmssd != null) {
        const pnn = signals.pnn50 ?? 0;
        contributors.push({
            signal: "rmssd",
            label: "RMSSD",
            raw: signals.rmssd,
            doshaVector: doshaForBeatToBeat(signals.rmssd, pnn),
            weight: sw.rmssd,
        });
    }

    // ── 10. Sleep apnea (weight 0.05) ───────────────────────────────────
    if (signals.sleepApneaCount != null && signals.sleepApneaCount > 0) {
        contributors.push({
            signal: "sleepApnea",
            label: "Apnea",
            raw: signals.sleepApneaCount,
            doshaVector: doshaForApnea(signals.sleepApneaCount),
            weight: sw.sleepApnea,
        });
    }

    // ── 11. Falls (weight 0.03) ─────────────────────────────────────────
    if (signals.fallCount != null && signals.fallCount > 0) {
        contributors.push({
            signal: "falls",
            label: "Falls",
            raw: signals.fallCount,
            doshaVector: dv(0.80, 0.15, 0.05),
            weight: sw.falls,
        });
    }

    // ── Aggregate weighted dosha proportions ────────────────────────────
    let vata = 0, pitta = 0, kapha = 0;
    let availableWeight = 0;

    for (const c of contributors) {
        vata += c.doshaVector.vata * c.weight;
        pitta += c.doshaVector.pitta * c.weight;
        kapha += c.doshaVector.kapha * c.weight;
        availableWeight += c.weight;
    }

    if (availableWeight <= 0) return null;

    // Normalize so V + P + K = 1.0
    const total = vata + pitta + kapha;
    if (total <= 0) return null;

    const vN = vata / total;
    const pN = pitta / total;
    const kN = kapha / total;

    // Confidence band (signal completeness against maximum 1.0 weight)
    const confidence = Math.min(1.0, availableWeight / 1.0);

    // Determine dominant + classical Gati name
    let dominant, gati;
    if (vN >= pN && vN >= kN) {
        dominant = "Vata";
        gati = "Sarpa";
    } else if (pN >= vN && pN >= kN) {
        dominant = "Pitta";
        gati = "Manduka";
    } else {
        dominant = "Kapha";
        gati = "Hamsa";
    }

    return {
        vata: round3(vN),
        pitta: round3(pN),
        kapha: round3(kN),
        dominant,
        gati,
        confidence: round3(confidence),
        signalCount: contributors.length,
        contributors: contributors.map((c) => ({
            signal: c.signal,
            label: c.label,
            weight: c.weight,
            doshaVector: {
                vata: round3(c.doshaVector.vata),
                pitta: round3(c.doshaVector.pitta),
                kapha: round3(c.doshaVector.kapha),
            },
        })),
        computedAt: new Date().toISOString(),
    };
}

/**
 * Compute personal baseline from historical data.
 *
 * @param {Array<{hrv: number}>} hrvHistory - At least 5 samples
 * @param {number[]} [rhrHistory] - Optional RHR samples
 * @param {number} [avgResp] - Average respiratory rate
 * @returns {object|null} Baseline object or null if insufficient data
 */
export function computeBaseline(hrvHistory, rhrHistory, avgResp) {
    if (!hrvHistory || hrvHistory.length < 5) return null;

    const hrvValues = hrvHistory.map((h) => (typeof h === "number" ? h : h.hrv));
    const avgHRV = hrvValues.reduce((a, b) => a + b, 0) / hrvValues.length;
    const varHRV =
        hrvValues.reduce((a, v) => a + Math.pow(v - avgHRV, 2), 0) /
        hrvValues.length;
    const stdHRV = Math.sqrt(varHRV);

    let avgRHR = 68.0,
        stdRHR = 6.0;
    if (rhrHistory && rhrHistory.length > 0) {
        avgRHR = rhrHistory.reduce((a, b) => a + b, 0) / rhrHistory.length;
        const varRHR =
            rhrHistory.reduce((a, v) => a + Math.pow(v - avgRHR, 2), 0) /
            rhrHistory.length;
        stdRHR = Math.sqrt(varRHR);
    }

    return {
        avgHRV: round3(avgHRV),
        stdHRV: round3(stdHRV),
        avgRHR: round3(avgRHR),
        stdRHR: round3(stdRHR),
        avgResp: avgResp ?? 15.0,
        sampleCount: hrvValues.length,
        computedAt: new Date().toISOString(),
    };
}

// ─── Utility ────────────────────────────────────────────────────────────────

function round3(n) {
    return Math.round(n * 1000) / 1000;
}
