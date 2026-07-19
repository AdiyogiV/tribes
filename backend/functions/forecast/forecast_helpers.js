/**
 * forecast_helpers.js — shared, pure helpers for the unified forecast pipeline.
 *
 * These bridge the gap between what the live data stores actually hold and what
 * the pure `computeDaySignal()` engine expects. Two known impedance mismatches
 * are handled here, once, so the SENSE/NARRATE layers stay clean:
 *
 *   1. The global sky doc stores each planet's longitude under `longitude`, but
 *      `computeDaySignal` reads `fullDegree ?? full_degree ?? degree`. We map it.
 *   2. `getTransitBinduScore(planet, sign, av)` keys BAV by sign NAME
 *      (`{Aries: 3, ...}`), but the engine passes a numeric sign INDEX. We wrap
 *      it in an adapter that converts index → name so bindu gating actually
 *      amplifies instead of silently no-opping.
 *
 * Everything here is deterministic and side-effect free (no Firestore, no AI).
 */

import { DateTime } from "luxon";
import { ZODIAC_SIGNS } from "../../lib/constants.js";
import { nakshatraIndex, nakshatraIndexFromDegree } from "../../lib/nakshatras.js";
import { extractAscendantDegree } from "../../lib/astro_helpers.js";
import { getTransitBinduScore } from "../../lib/vedic_analysis.js";

/** All forecast date keys are anchored to the product's IST business day. */
export const FORECAST_ZONE = "Asia/Kolkata";

/** yyyy-MM-dd for a Luxon DateTime (IST). */
export function dayKey(dt) {
    return dt.setZone(FORECAST_ZONE).toFormat("yyyy-MM-dd");
}

/** yyyy-MM for a Luxon DateTime (IST) — the forecast doc id. */
export function monthKey(dt) {
    return dt.setZone(FORECAST_ZONE).toFormat("yyyy-MM");
}

/** Month key for a yyyy-MM-dd date string. */
export function monthKeyOf(dateStr) {
    return dateStr.slice(0, 7);
}

/** "today" in IST, at start of day. */
export function istToday() {
    return DateTime.now().setZone(FORECAST_ZONE).startOf("day");
}

/**
 * The rolling horizon of day-keys the forecast covers: today .. today+days.
 * @param {number} days  how many days ahead (inclusive of today).
 * @returns {string[]} yyyy-MM-dd strings.
 */
export function horizonDayKeys(days) {
    const start = istToday();
    const out = [];
    for (let i = 0; i < days; i++) out.push(dayKey(start.plus({ days: i })));
    return out;
}

/** Sign index (0-11) → canonical sign name (BAV key). */
export function signIndexToName(idx) {
    return idx != null && idx >= 0 && idx < 12 ? ZODIAC_SIGNS[idx] : null;
}

/** Sign name → index (0-11), or null. */
export function signNameToIndex(name) {
    if (!name) return null;
    const idx = ZODIAC_SIGNS.indexOf(String(name).trim());
    return idx >= 0 ? idx : null;
}

/**
 * Derive the natal inputs `computeDaySignal` needs from a user's stored
 * `astrologyData`. Returns nulls (not throws) for missing pieces so the engine
 * can gracefully skip the signals that depend on them.
 *
 * @param {Object} astro  users/{uid}.astrologyData
 * @returns {{ moonSignIndex:number|null, birthNakshatraIndex:number|null,
 *             ascendantDegree:number|null, ashtakavarga:Object|null }}
 */
export function deriveNatalInputs(astro) {
    if (!astro) {
        return { moonSignIndex: null, birthNakshatraIndex: null, ascendantDegree: null, ashtakavarga: null };
    }
    const moonSignIndex = signNameToIndex(astro.moonSign);
    const nakName = astro.moonNakshatra || astro.nakshatra;
    const bIdx = nakshatraIndex(nakName);
    return {
        moonSignIndex,
        birthNakshatraIndex: bIdx >= 0 ? bIdx : null,
        ascendantDegree: extractAscendantDegree(astro),
        ashtakavarga: astro.ashtakavarga || null,
    };
}

/**
 * Build the `dayPositions` object `computeDaySignal` expects for one date from
 * the global sky doc's `positions[date]` map. Maps `longitude → fullDegree` so
 * the engine can read the degree (gotcha #1).
 *
 * @param {Object} positionsForDate  skyDoc.positions[dateStr]
 * @returns {Object|null} { Sun: {fullDegree}, Moon: {fullDegree}, ... }
 */
export function toDayPositions(positionsForDate) {
    if (!positionsForDate) return null;
    const out = {};
    for (const [planet, data] of Object.entries(positionsForDate)) {
        if (!data) continue;
        const deg = data.fullDegree ?? data.longitude ?? data.full_degree ?? data.degree;
        if (deg == null) continue;
        out[planet] = { ...data, fullDegree: deg };
    }
    return out;
}

/**
 * The day's Moon nakshatra index (0-26). Prefer the precise Moon longitude from
 * the sky positions; fall back to the panchang nakshatra name.
 */
export function dayMoonNakshatra(positionsForDate, panchangForDate) {
    const moonDeg = positionsForDate?.Moon?.longitude ?? positionsForDate?.Moon?.fullDegree;
    if (moonDeg != null) {
        const idx = nakshatraIndexFromDegree(moonDeg);
        if (idx >= 0) return idx;
    }
    const idx = nakshatraIndex(panchangForDate?.nakshatra);
    return idx >= 0 ? idx : null;
}

/**
 * Adapter for `computeDaySignal`'s `binduFn` param (gotcha #2). The engine calls
 * `binduFn(planet, signIndex, ashtakavarga)`, but `getTransitBinduScore` keys
 * BAV by sign NAME. We convert the index → name so bindu strength actually
 * gates the transit. Returns the raw bindu count (0-8) or null.
 */
export function binduByIndex(planet, signIndex, ashtakavarga) {
    const signName = signIndexToName(signIndex);
    if (!signName) return null;
    const res = getTransitBinduScore(planet, signName, ashtakavarga);
    return res?.bindus ?? null;
}
