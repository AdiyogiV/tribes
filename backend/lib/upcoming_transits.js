/**
 * Upcoming Transit Scanner
 *
 * Scans pre-calculated sky positions to find significant transits
 * in the next N days: aspect perfections, sign ingresses, stations.
 *
 * Pure math. No LLM. No cost. This is the predictive edge.
 */

import { angularSeparation } from "../lib/aspect_calculator.js";
import { ASPECT_ANGLES } from "../lib/signal_types.js";
import { ZODIAC_SIGNS } from "../lib/constants.js";

const SLOW_PLANETS = ["Mars", "Jupiter", "Saturn", "Rahu", "Ketu"];
const ALL_PLANETS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];
const STATION_PLANETS = ["Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

/**
 * Scan future positions to find upcoming significant transits.
 *
 * Looks for:
 * - Aspects between slow planets that are perfecting (orb reaching minimum)
 * - Sign ingresses (planet entering a new sign)
 * - Stations (planet speed dropping near zero = retrograde/direct)
 *
 * @param {Object} allPositions - { date: { planet: { longitude, isRetro, ... } } }
 * @param {string[]} sortedDates - Sorted date strings
 * @param {number} todayIdx - Index of today in sortedDates
 * @param {number} daysAhead - How many days to look ahead
 * @returns {Object[]} Upcoming transit events, sorted by daysAway
 */
export function scanUpcomingTransits(allPositions, sortedDates, todayIdx, daysAhead) {
    const events = [];
    const endIdx = Math.min(todayIdx + daysAhead, sortedDates.length - 1);

    if (todayIdx < 0 || endIdx <= todayIdx) return events;

    // Pass 1: Day-by-day scan for ingresses and stations
    for (let d = todayIdx + 1; d <= endIdx; d++) {
        const date = sortedDates[d];
        const pos = allPositions[date];
        const prevPos = allPositions[sortedDates[d - 1]];
        if (!pos || !prevPos) continue;

        findIngresses(events, pos, prevPos, date, d - todayIdx);
        findStations(events, pos, prevPos, date, d - todayIdx);
    }

    // Pass 2: Track orb curves for slow planet aspect perfections
    findAspectPerfections(events, allPositions, sortedDates, todayIdx, endIdx);

    events.sort((a, b) => a.daysAway - b.daysAway);
    return events;
}

// ─── Sign Ingresses ─────────────────────────────────────────────────────────

function findIngresses(events, pos, prevPos, date, daysAway) {
    for (const planet of ALL_PLANETS) {
        if (!pos[planet]?.longitude || !prevPos[planet]?.longitude) continue;
        const prevSign = Math.floor(prevPos[planet].longitude / 30);
        const currSign = Math.floor(pos[planet].longitude / 30);
        if (prevSign !== currSign) {
            events.push({
                type: "ingress",
                date,
                planet,
                fromSign: ZODIAC_SIGNS[prevSign],
                toSign: ZODIAC_SIGNS[currSign],
                daysAway,
            });
        }
    }
}

// ─── Retrograde/Direct Stations ─────────────────────────────────────────────

function findStations(events, pos, prevPos, date, daysAway) {
    for (const planet of STATION_PLANETS) {
        if (!pos[planet]?.longitude || !prevPos[planet]?.longitude) continue;
        const wasRetro = prevPos[planet].isRetro || false;
        const isRetro = pos[planet].isRetro || false;
        if (wasRetro !== isRetro) {
            events.push({
                type: "station",
                date,
                planet,
                stationType: isRetro ? "retrograde" : "direct",
                sign: ZODIAC_SIGNS[Math.floor(pos[planet].longitude / 30)],
                daysAway,
            });
        }
    }
}

// ─── Aspect Perfections (slow planet pairs) ─────────────────────────────────

function findAspectPerfections(events, allPositions, sortedDates, todayIdx, endIdx) {
    for (let i = 0; i < SLOW_PLANETS.length; i++) {
        for (let j = i + 1; j < SLOW_PLANETS.length; j++) {
            const p1 = SLOW_PLANETS[i];
            const p2 = SLOW_PLANETS[j];
            // Rahu-Ketu are always opposite — skip
            if ((p1 === "Rahu" && p2 === "Ketu") || (p1 === "Ketu" && p2 === "Rahu")) continue;

            for (const [aspectName, targetAngle] of Object.entries(ASPECT_ANGLES)) {
                let prevOrb = null;
                for (let d = todayIdx; d <= endIdx; d++) {
                    const pos = allPositions[sortedDates[d]];
                    if (!pos?.[p1]?.longitude || !pos?.[p2]?.longitude) continue;

                    const sep = angularSeparation(pos[p1].longitude, pos[p2].longitude);
                    const orb = Math.abs(sep - targetAngle);

                    // Found a minimum (orb was decreasing, now increasing) within 10°
                    if (prevOrb !== null && orb > prevOrb && prevOrb < 10 && d > todayIdx) {
                        events.push({
                            type: "aspect_perfection",
                            date: sortedDates[d - 1],
                            planet1: p1,
                            planet2: p2,
                            aspect: aspectName,
                            orb: +prevOrb.toFixed(2),
                            daysAway: (d - 1) - todayIdx,
                        });
                        break; // only first perfection per pair per aspect
                    }
                    prevOrb = orb;
                }
            }
        }
    }
}
