/**
 * Engine Weights — backend-tunable configuration for OjasEngine and NadiEngine.
 *
 * All weights and thresholds live here so they can be changed without
 * redeploying functions. A Firestore document `config/engineWeights`
 * can override any value at runtime (for A/B testing, gradual rollouts, etc.).
 *
 * Flow:
 *   1. Module exports DEFAULTS (hardcoded, always available)
 *   2. `loadWeights()` merges any Firestore overrides on top
 *   3. Engines call `getWeights()` — returns merged result, cached 5 min
 */

import { db } from "./firebase.js";
import { logger } from "firebase-functions";

// ─── Ojas Engine Defaults ───────────────────────────────────────────────────

const OJAS_PRIMARY_WEIGHTS = {
    hrv: 0.35,
    sleep: 0.22,
    restingHR: 0.18,
    wristTemp: 0.10,
    respiration: 0.08,
    activity: 0.07,
};

const OJAS_MODIFIER_LIMITS = {
    hrRecoveryMax: 5,
    standHoursMax: 4,
    spO2CeilingThreshold: 92,
    spO2CeilingValue: 60,
    daylightMax: 5,
    audioThreshold: 85,
    mindfulMax: 5,
    cardiacAlertPenalty: -10,
    gaitSteadinessThreshold: 0.4,
    sleepApneaPenalty: -5,
    sleepApneaSeverePenalty: -10,
    fallPenalty: -10,
    lowCardioFitPenalty: -3,
    vagalBonusHigh: 5,
    vagalBonusMid: 3,
    vagalPenalty: -3,
    uvPenalty: -2,
    // v2: new modifiers
    pulseCalm: 2,
    pulseElevated: -3,
    pulseStress: -5,
    vo2MaxElite: 5,
    vo2MaxGood: 3,
    vo2MaxLow: -2,
    vo2MaxPoor: -5,
    exerciseIdeal: 3,
    exerciseSome: 1,
    exerciseOver: -2,
    pnn50High: 2,
    pnn50Low: -2,
    walkEfficiencyGood: 3,
    walkEfficiencyPoor: -3,
    gaitAsymmetryPenalty: -2,
    gaitDoubleSupportPenalty: -2,
    headphoneLoudPenalty: -3,
    headphoneModPenalty: -1,
    lowHRPenalty: -2,
    feverCeilingValue: 55,
    feverThreshold: 38.0,
    warmTempPenalty: -3,
    warmTempThreshold: 37.5,
};

// ─── Nadi Engine Defaults ───────────────────────────────────────────────────

const NADI_SIGNAL_WEIGHTS = {
    hrv: 0.30,
    restingHR: 0.15,
    walkRatio: 0.10,
    respiration: 0.15,
    sleep: 0.12,
    wristTemp: 0.08,
    gait: 0.05,
    cardiacAlerts: 0.05,
    rmssd: 0.15,
    sleepApnea: 0.05,
    falls: 0.03,
};

// ─── Population Baseline Defaults ───────────────────────────────────────────

const POPULATION_BASELINE = {
    avgHRV: 45.0,
    stdHRV: 12.0,
    avgRHR: 68.0,
    stdRHR: 6.0,
    avgResp: 15.0,
    avgVO2: 35.0,
    avgSleepOnset: 22.5,
};

// ─── Assembled defaults ─────────────────────────────────────────────────────

const DEFAULTS = Object.freeze({
    ojas: {
        primaryWeights: { ...OJAS_PRIMARY_WEIGHTS },
        modifierLimits: { ...OJAS_MODIFIER_LIMITS },
    },
    nadi: {
        signalWeights: { ...NADI_SIGNAL_WEIGHTS },
    },
    baseline: { ...POPULATION_BASELINE },
    version: 1,
});

// ─── Runtime cache ──────────────────────────────────────────────────────────

let _cached = null;
let _cachedAt = 0;
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Load weights from Firestore, merged over defaults. Cached for 5 min.
 * Falls back to DEFAULTS if Firestore is unreachable.
 */
export async function getWeights() {
    const now = Date.now();
    if (_cached && now - _cachedAt < CACHE_TTL_MS) return _cached;

    try {
        const doc = await db.collection("config").doc("engineWeights").get();
        if (doc.exists) {
            const overrides = doc.data();
            _cached = deepMerge(DEFAULTS, overrides);
            _cachedAt = now;
            logger.debug("engineWeights: loaded overrides from Firestore");
            return _cached;
        }
    } catch (e) {
        logger.warn("engineWeights: Firestore read failed, using defaults", { error: String(e) });
    }

    _cached = DEFAULTS;
    _cachedAt = now;
    return _cached;
}

/**
 * Get defaults synchronously (no Firestore call). Use when you can't await.
 */
export function getDefaultWeights() {
    return DEFAULTS;
}

/**
 * Clear the cache (useful in tests or after updating config).
 */
export function clearWeightsCache() {
    _cached = null;
    _cachedAt = 0;
}

// ─── Utility ────────────────────────────────────────────────────────────────

function deepMerge(base, overrides) {
    if (!overrides || typeof overrides !== "object") return base;
    const result = { ...base };
    for (const key of Object.keys(overrides)) {
        if (
            typeof base[key] === "object" &&
            base[key] !== null &&
            !Array.isArray(base[key]) &&
            typeof overrides[key] === "object" &&
            overrides[key] !== null
        ) {
            result[key] = deepMerge(base[key], overrides[key]);
        } else {
            result[key] = overrides[key];
        }
    }
    return result;
}
