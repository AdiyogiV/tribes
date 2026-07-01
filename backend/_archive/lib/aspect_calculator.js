/**
 * Aspect Calculator for Cosmic Intelligence Agent
 *
 * Pure math: given planet positions (longitudes), calculates all active aspects,
 * determines if they're applying or separating, and computes orb tightness.
 *
 * Supports both Western geometric aspects AND Vedic house-based aspects (drishti).
 * For the signal engine we use Western geometric (degree-based) because we need
 * precise orbs, applying/separating detection, and peak timing.
 *
 * No LLM, no cost.
 */

import {
    ASPECT_TYPE,
    ASPECT_ANGLES,
    DEFAULT_ORBS,
    LUMINARY_ORB_BONUS,
    VEDIC_SPECIAL_ASPECTS,
    COMBUSTION_ORBS,
    COMBUSTION_ORBS_RETRO,
    ECLIPSE_ORB,
} from "./signal_types.js";

// Planets that are luminaries (get wider orbs)
const LUMINARIES = new Set(["Sun", "Moon"]);

// =============================================================================
// CORE ASPECT CALCULATION
// =============================================================================

/**
 * Normalize angle to 0-360 range.
 */
function normalize(deg) {
    return ((deg % 360) + 360) % 360;
}

/**
 * Calculate the shortest angular separation between two longitudes.
 * Always returns a positive value 0-180.
 */
export function angularSeparation(lon1, lon2) {
    const diff = Math.abs(normalize(lon1) - normalize(lon2));
    return diff > 180 ? 360 - diff : diff;
}

/**
 * Calculate the raw directional difference (lon2 - lon1) in 0-360 range.
 * Used for house-based aspects.
 */
function directionalDiff(lon1, lon2) {
    return normalize(lon2 - lon1);
}

/**
 * Get the effective orb for an aspect between two planets.
 * Luminaries get wider orbs.
 */
function getEffectiveOrb(planet1, planet2, aspectType) {
    let orb = DEFAULT_ORBS[aspectType] || 8;
    if (LUMINARIES.has(planet1) || LUMINARIES.has(planet2)) {
        orb += LUMINARY_ORB_BONUS;
    }
    return orb;
}

/**
 * Check if two planets form a specific aspect.
 * Returns aspect details or null.
 *
 * @param {string} planet1 - First planet name
 * @param {number} lon1 - First planet longitude (0-360)
 * @param {string} planet2 - Second planet name
 * @param {number} lon2 - Second planet longitude (0-360)
 * @param {string} aspectType - One of ASPECT_TYPE values
 * @returns {Object|null} { aspectType, orb, exactAngle } or null if not in orb
 */
function checkAspect(planet1, lon1, planet2, lon2, aspectType) {
    const targetAngle = ASPECT_ANGLES[aspectType];
    const separation = angularSeparation(lon1, lon2);
    const orbFromExact = Math.abs(separation - targetAngle);
    const maxOrb = getEffectiveOrb(planet1, planet2, aspectType);

    if (orbFromExact <= maxOrb) {
        return {
            aspectType,
            orb: Math.round(orbFromExact * 100) / 100,
            separation: Math.round(separation * 100) / 100,
            maxOrb,
        };
    }
    return null;
}

/**
 * Determine if an aspect is applying (getting tighter) or separating (getting looser).
 *
 * @param {number} lon1Today - Planet 1 longitude today
 * @param {number} lon2Today - Planet 2 longitude today
 * @param {number} lon1Yesterday - Planet 1 longitude yesterday
 * @param {number} lon2Yesterday - Planet 2 longitude yesterday
 * @param {string} aspectType - The aspect being checked
 * @returns {boolean} true if applying (orb getting tighter), false if separating
 */
export function isApplying(lon1Today, lon2Today, lon1Yesterday, lon2Yesterday, aspectType) {
    const targetAngle = ASPECT_ANGLES[aspectType];
    const todaySep = angularSeparation(lon1Today, lon2Today);
    const yesterdaySep = angularSeparation(lon1Yesterday, lon2Yesterday);

    const todayOrb = Math.abs(todaySep - targetAngle);
    const yesterdayOrb = Math.abs(yesterdaySep - targetAngle);

    return todayOrb < yesterdayOrb;
}

// =============================================================================
// VEDIC SPECIAL ASPECTS (House-based drishti)
// =============================================================================

/**
 * Check if planet1 has a Vedic special aspect on planet2.
 * Mars: 4th and 8th house aspects
 * Jupiter: 5th and 9th house aspects
 * Saturn: 3rd and 10th house aspects
 * Rahu/Ketu: 5th and 9th (like Jupiter)
 *
 * Returns the house distance if aspecting, null otherwise.
 *
 * IMPORTANT: Uses SIGN-BASED (whole-sign / rashi drishti) calculation.
 * Vedic special aspects are rashi drishti — they depend on which SIGN
 * the planet occupies, not the exact degree. A planet at 1° Aries and
 * 29° Aries both aspect the same signs.
 *
 * @param {string} planet1 - Aspecting planet
 * @param {number} lon1 - Aspecting planet longitude
 * @param {number} lon2 - Aspected planet longitude
 * @returns {number|null} House distance (3,4,5,8,9,10) or null
 */
export function checkVedicSpecialAspect(planet1, lon1, lon2) {
    const specialHouses = VEDIC_SPECIAL_ASPECTS[planet1];
    if (!specialHouses) return null;

    // Sign-based house distance (rashi drishti)
    const sign1 = Math.floor(normalize(lon1) / 30);
    const sign2 = Math.floor(normalize(lon2) / 30);
    const houseDist = ((sign2 - sign1 + 12) % 12) + 1;

    if (specialHouses.includes(houseDist)) {
        return houseDist;
    }
    return null;
}

// =============================================================================
// MAIN: FIND ALL ASPECTS
// =============================================================================

/**
 * Find ALL active aspects between all planet pairs for a given day.
 *
 * @param {Object} todayPositions - { planetName: { longitude, sign, signDegree, isRetro, nakshatra } }
 * @param {Object} [yesterdayPositions] - same format, for applying/separating detection. Optional.
 * @returns {Object[]} Array of aspect objects:
 *   {
 *     planet1, planet2, aspectType, orb, maxOrb, applying,
 *     isVedicSpecial, vedicHouse,
 *     planet1Sign, planet2Sign, planet1Retro, planet2Retro
 *   }
 */
export function findAllAspects(todayPositions, yesterdayPositions = null) {
    const aspects = [];
    const planetNames = Object.keys(todayPositions);

    for (let i = 0; i < planetNames.length; i++) {
        for (let j = i + 1; j < planetNames.length; j++) {
            const p1 = planetNames[i];
            const p2 = planetNames[j];

            const pos1 = todayPositions[p1];
            const pos2 = todayPositions[p2];

            if (pos1?.longitude == null || pos2?.longitude == null) continue;

            // Skip Rahu-Ketu pair — always in opposition by definition
            if ((p1 === "Rahu" && p2 === "Ketu") || (p1 === "Ketu" && p2 === "Rahu")) continue;

            // Check all five major aspect types
            for (const aspectType of Object.values(ASPECT_TYPE)) {
                const result = checkAspect(p1, pos1.longitude, p2, pos2.longitude, aspectType);
                if (!result) continue;

                // Determine applying/separating if we have yesterday's data
                let applying = null;
                if (yesterdayPositions) {
                    const yPos1 = yesterdayPositions[p1];
                    const yPos2 = yesterdayPositions[p2];
                    if (yPos1?.longitude != null && yPos2?.longitude != null) {
                        applying = isApplying(
                            pos1.longitude, pos2.longitude,
                            yPos1.longitude, yPos2.longitude,
                            aspectType
                        );
                    }
                }

                aspects.push({
                    planet1: p1,
                    planet2: p2,
                    aspectType: result.aspectType,
                    orb: result.orb,
                    maxOrb: result.maxOrb,
                    applying,
                    isVedicSpecial: false,
                    vedicHouse: null,
                    planet1Sign: pos1.sign,
                    planet2Sign: pos2.sign,
                    planet1Retro: pos1.isRetro || false,
                    planet2Retro: pos2.isRetro || false,
                });
            }

            // Check Vedic special aspects (both directions)
            const vedic1to2 = checkVedicSpecialAspect(p1, pos1.longitude, pos2.longitude);
            if (vedic1to2) {
                // Only add if not already covered by a standard aspect
                const alreadyCovered = aspects.some(a =>
                    a.planet1 === p1 && a.planet2 === p2 && a.isVedicSpecial === false
                );
                if (!alreadyCovered) {
                    aspects.push({
                        planet1: p1,
                        planet2: p2,
                        aspectType: `vedic_${vedic1to2}th`,
                        orb: 0,  // Vedic aspects are whole-sign, no orb
                        maxOrb: 15,
                        applying: null,
                        isVedicSpecial: true,
                        vedicHouse: vedic1to2,
                        planet1Sign: pos1.sign,
                        planet2Sign: pos2.sign,
                        planet1Retro: pos1.isRetro || false,
                        planet2Retro: pos2.isRetro || false,
                    });
                }
            }

            const vedic2to1 = checkVedicSpecialAspect(p2, pos2.longitude, pos1.longitude);
            if (vedic2to1) {
                const alreadyCovered = aspects.some(a =>
                    a.planet1 === p2 && a.planet2 === p1 && a.isVedicSpecial === false
                );
                if (!alreadyCovered) {
                    aspects.push({
                        planet1: p2,
                        planet2: p1,
                        aspectType: `vedic_${vedic2to1}th`,
                        orb: 0,
                        maxOrb: 15,
                        applying: null,
                        isVedicSpecial: true,
                        vedicHouse: vedic2to1,
                        planet1Sign: pos2.sign,
                        planet2Sign: pos1.sign,
                        planet1Retro: pos2.isRetro || false,
                        planet2Retro: pos1.isRetro || false,
                    });
                }
            }
        }
    }

    // Sort by orb tightness (tightest first = most significant)
    aspects.sort((a, b) => a.orb - b.orb);
    return aspects;
}

// =============================================================================
// COMBUSTION CHECK
// =============================================================================

/**
 * Check which planets are combust (too close to Sun).
 *
 * @param {Object} positions - { planetName: { longitude, isRetro, ... } }
 * @returns {Object[]} Array of combustion objects:
 *   { planet, orb, maxOrb, severity: "severe"|"moderate", isRetro }
 */
export function findCombustions(positions) {
    const sun = positions.Sun;
    if (!sun || sun.longitude == null) return [];

    const combustions = [];

    for (const [name, pos] of Object.entries(positions)) {
        if (name === "Sun" || name === "Rahu" || name === "Ketu") continue;
        if (pos?.longitude == null) continue;

        const sep = angularSeparation(sun.longitude, pos.longitude);
        const isRetro = pos.isRetro || false;

        // Get orb limit (retrograde planets may have tighter combustion orb)
        let maxOrb = COMBUSTION_ORBS[name];
        if (!maxOrb) continue; // outer planets don't combust

        if (isRetro && COMBUSTION_ORBS_RETRO[name]) {
            maxOrb = COMBUSTION_ORBS_RETRO[name];
        }

        if (sep <= maxOrb) {
            combustions.push({
                planet: name,
                orb: Math.round(sep * 100) / 100,
                maxOrb,
                severity: sep < maxOrb / 2 ? "severe" : "moderate",
                isRetro,
            });
        }
    }

    return combustions;
}

// =============================================================================
// ECLIPSE PROXIMITY CHECK
// =============================================================================

/**
 * Check if Sun or Moon is near Rahu/Ketu axis (eclipse indicator).
 *
 * @param {Object} positions - planet positions
 * @returns {Object[]} Array of eclipse proximity signals:
 *   { luminary, node, orb, eclipseType: "solar"|"lunar", proximity: "near"|"close"|"imminent" }
 */
export function findEclipseProximity(positions) {
    const results = [];
    const sun = positions.Sun;
    const moon = positions.Moon;
    const rahu = positions.Rahu;
    const ketu = positions.Ketu;

    if (!sun || !rahu || !ketu) return results;

    // Solar eclipse: Sun near Rahu or Ketu
    for (const [nodeName, node] of [["Rahu", rahu], ["Ketu", ketu]]) {
        if (!node?.longitude) continue;

        if (sun?.longitude != null) {
            const sunNodeSep = angularSeparation(sun.longitude, node.longitude);
            if (sunNodeSep <= ECLIPSE_ORB) {
                results.push({
                    luminary: "Sun",
                    node: nodeName,
                    orb: Math.round(sunNodeSep * 100) / 100,
                    eclipseType: "solar",
                    proximity: sunNodeSep < 5 ? "imminent" : sunNodeSep < 10 ? "close" : "near",
                });
            }
        }

        if (moon?.longitude != null) {
            const moonNodeSep = angularSeparation(moon.longitude, node.longitude);
            if (moonNodeSep <= ECLIPSE_ORB) {
                results.push({
                    luminary: "Moon",
                    node: nodeName,
                    orb: Math.round(moonNodeSep * 100) / 100,
                    eclipseType: "lunar",
                    proximity: moonNodeSep < 5 ? "imminent" : moonNodeSep < 10 ? "close" : "near",
                });
            }
        }
    }

    return results;
}

// =============================================================================
// SPEED ANOMALY DETECTION
// =============================================================================

/**
 * Detect planets that are moving unusually slow or fast by comparing
 * today vs yesterday position change against average daily motion.
 *
 * @param {Object} todayPositions - today's positions
 * @param {Object} yesterdayPositions - yesterday's positions
 * @returns {Object[]} Speed anomaly signals:
 *   { planet, dailyMotion, averageMotion, ratio, anomalyType: "slow"|"fast"|"stationary" }
 */
export function findSpeedAnomalies(todayPositions, yesterdayPositions) {
    // Average daily motion in degrees (approximate)
    const AVG_DAILY_MOTION = {
        Sun: 1.0,
        Moon: 13.2,
        Mars: 0.52,
        Mercury: 1.38,
        Jupiter: 0.083,
        Venus: 1.2,
        Saturn: 0.034,
        Rahu: 0.053,    // always retrograde, ~3'/day
        Ketu: 0.053,
    };

    const anomalies = [];

    for (const [name, avg] of Object.entries(AVG_DAILY_MOTION)) {
        const today = todayPositions[name];
        const yesterday = yesterdayPositions[name];
        if (!today?.longitude || !yesterday?.longitude) continue;

        // Raw daily motion (handle retrograde — motion can be negative)
        let rawMotion = normalize(today.longitude) - normalize(yesterday.longitude);
        // Adjust for crossing 0°/360° boundary
        if (rawMotion > 180) rawMotion -= 360;
        if (rawMotion < -180) rawMotion += 360;

        const absoluteMotion = Math.abs(rawMotion);
        const ratio = avg > 0 ? absoluteMotion / avg : 1;

        // Stationary: less than 10% of average (approaching retrograde/direct station)
        if (ratio < 0.1 && name !== "Rahu" && name !== "Ketu") {
            anomalies.push({
                planet: name,
                dailyMotion: Math.round(absoluteMotion * 1000) / 1000,
                averageMotion: avg,
                ratio: Math.round(ratio * 100) / 100,
                anomalyType: "stationary",
                direction: rawMotion >= 0 ? "direct" : "retrograde",
            });
        }
        // Slow: less than 40% of average
        else if (ratio < 0.4 && name !== "Rahu" && name !== "Ketu") {
            anomalies.push({
                planet: name,
                dailyMotion: Math.round(absoluteMotion * 1000) / 1000,
                averageMotion: avg,
                ratio: Math.round(ratio * 100) / 100,
                anomalyType: "slow",
                direction: rawMotion >= 0 ? "direct" : "retrograde",
            });
        }
        // Fast: more than 160% of average
        else if (ratio > 1.6) {
            anomalies.push({
                planet: name,
                dailyMotion: Math.round(absoluteMotion * 1000) / 1000,
                averageMotion: avg,
                ratio: Math.round(ratio * 100) / 100,
                anomalyType: "fast",
                direction: rawMotion >= 0 ? "direct" : "retrograde",
            });
        }
    }

    return anomalies;
}
