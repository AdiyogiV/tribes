/**
 * क्रिया २ — दृक् गणित (Drik Ganita: Sky Observation)
 *
 * "First, observe where each graha stands in the zodiac."
 *
 * Reads positions from Firestore, enriches with nakshatra data,
 * computes Sun-planet distances for combustion, detects eclipse proximity.
 */

import { db } from "../../lib/firebase.js";
import { getNakshatra, getPanchanga } from "../../lib/vedic_utils.js";
import { findEclipseProximity } from "../../lib/aspect_calculator.js";
import { angularSeparation } from "../../lib/aspect_calculator.js";
import { ZODIAC_SIGNS } from "../../lib/constants.js";

/**
 * Load sky positions from Firestore for a date range.
 *
 * @param {string} [dateKey] - Specific date "YYYY-MM-DD". If null, uses today.
 * @returns {Object} { positions, panchang, dateRange }
 */
export async function loadSkyPositions(dateKey = null) {
    const doc = await db.collection("global_astro").doc("sky_positions").get();
    if (!doc.exists) throw new Error("No sky positions in Firestore. Run prefetchSkyPositions first.");

    const data = doc.data();
    const allPositions = data.positions || {};
    const allPanchang = data.panchang || {};

    const today = dateKey || new Date().toISOString().split("T")[0];
    const todayPositions = allPositions[today];

    if (!todayPositions) {
        throw new Error(`No positions for ${today}. Available: ${Object.keys(allPositions).sort().slice(-5).join(", ")}`);
    }

    return {
        positions: todayPositions,
        allPositions,
        panchang: allPanchang[today] || null,
        dateRange: data.dateRange,
        date: today,
    };
}

/**
 * Enrich raw positions with computed fields needed by the rules engine:
 * - sunDistance (for combustion)
 * - nakshatra data (name, pada, lord)
 * - sign name (if not already present)
 *
 * @param {Object} rawPositions - { planet: { longitude, sign, isRetro, ... } }
 * @returns {Object} Enriched positions
 */
export function enrichPositions(rawPositions) {
    const enriched = {};
    const sunLon = rawPositions.Sun?.longitude;

    for (const [planet, pos] of Object.entries(rawPositions)) {
        if (!pos || pos.longitude == null) continue;

        // Skip outer planets (not in Vedic Jyotish)
        if (["Uranus", "Neptune", "Pluto"].includes(planet)) continue;

        const lon = pos.longitude;
        const sign = pos.sign || ZODIAC_SIGNS[Math.floor(lon / 30)];
        const nak = getNakshatra(lon);

        enriched[planet] = {
            ...pos,
            sign,
            longitude: lon,
            isRetrograde: pos.isRetro || pos.isRetrograde || false,
            isRetro: pos.isRetro || pos.isRetrograde || false,
            sunDistance: sunLon != null ? angularSeparation(lon, sunLon) : 180,
            nakshatra: nak.name,
            nakshatraIndex: nak.index,
            nakshatraPada: nak.pada,
            nakshatraLord: nak.lord,
        };
    }

    return enriched;
}

/**
 * Detect active eclipse windows from position data.
 *
 * Uses the existing findEclipseProximity() from aspect_calculator.js
 * and converts results to the format our eclipse_effects.js expects.
 *
 * Also checks against known upcoming eclipses stored in Firestore.
 *
 * @param {Object} positions - enriched positions
 * @returns {Object[]} Active eclipse window objects
 */
export function detectActiveEclipses(positions) {
    const proximity = findEclipseProximity(positions);
    const eclipses = [];

    for (const prox of proximity) {
        if (prox.proximity === "imminent" || prox.proximity === "close") {
            eclipses.push({
                type: prox.eclipseType,
                sign: positions[prox.luminary]?.sign,
                durationMinutes: 120, // Default — refine with actual data later
                proximity: prox.proximity,
                orb: prox.orb,
            });
        }
    }

    return eclipses;
}

/**
 * Build a complete SkyState object ready for the rules engine.
 *
 * This is the MAIN ENTRY POINT for the mundane system.
 * Call this, then pass result to applyAllRules().
 *
 * @param {string} [dateKey] - "YYYY-MM-DD" or null for today
 * @returns {Object} SkyState { positions, activeEclipses, date, panchang, ... }
 */
export async function buildSkyState(dateKey = null) {
    const { positions: rawPositions, allPositions, panchang, date } = await loadSkyPositions(dateKey);

    const positions = enrichPositions(rawPositions);
    const activeEclipses = detectActiveEclipses(positions);

    // Get yesterday's positions for change detection
    const yesterday = new Date(date);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayKey = yesterday.toISOString().split("T")[0];
    const prevPositions = allPositions[yesterdayKey]
        ? enrichPositions(allPositions[yesterdayKey])
        : null;

    // Get panchanga from our own pure-math calculator
    const computedPanchanga = getPanchanga(positions, date);

    return {
        positions,
        prevPositions,
        activeEclipses,
        date,
        panchang: panchang || computedPanchanga,
        computedPanchanga,
    };
}

/**
 * Build sky state from RAW position data (no Firestore needed).
 * Useful for testing and backtesting.
 *
 * @param {Object} rawPositions - { planet: { longitude, sign, isRetro, ... } }
 * @param {string} date - "YYYY-MM-DD"
 * @param {Object[]} [activeEclipses] - Manual eclipse windows
 * @returns {Object} SkyState
 */
export function buildSkyStateFromRaw(rawPositions, date, activeEclipses = []) {
    const positions = enrichPositions(rawPositions);
    const eclipses = activeEclipses.length > 0
        ? activeEclipses
        : detectActiveEclipses(positions);
    const computedPanchanga = getPanchanga(positions, date);

    return {
        positions,
        prevPositions: null,
        activeEclipses: eclipses,
        date,
        panchang: computedPanchanga,
        computedPanchanga,
    };
}
