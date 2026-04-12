/**
 * Signal Engine — Cosmic Intelligence Agent (Phase 1)
 *
 * Extracts structured signals from raw sky positions.
 * A signal = "something notable or changed in the sky."
 *
 * This is the agent's "eyes" — pure math, zero LLM cost.
 *
 * Input:  sky positions (from sky_positions.js / Firestore)
 * Output: Signal[] — structured, typed, scored signals
 *
 * Two main functions:
 *   extractSignals(todayPositions, yesterdayPositions) → all active signals today
 *   diffSky(today, yesterday)                        → only what CHANGED since yesterday
 */

import {
    SIGNAL_TYPE,
    SIGNAL_STATUS,
    ASPECT_TYPE,
    EXALTATION,
    DEBILITATION,
    MOOL_TRIKONA,
    PLANET_RULERSHIP,
    NAVAGRAHA,
    calculateIntensity,
    mergeDomains,
    makeSignalId,
} from "../lib/signal_types.js";

import {
    findAllAspects,
    findCombustions,
    findEclipseProximity,
    findSpeedAnomalies,
    angularSeparation,
} from "../lib/aspect_calculator.js";

import {
    ZODIAC_SIGNS,
    getSignFromLongitude,
} from "../lib/constants.js";

import { getNakshatra } from "../lib/vedic_utils.js";
import { detectMundaneYogas } from "../lib/vedic_yogas.js";

// Only Navagraha — no Uranus, Neptune, Pluto
const NAVAGRAHA_SET = new Set(NAVAGRAHA);

/**
 * Filter positions to Navagraha only AND enrich with derived fields.
 * Firestore data only has { longitude, signDegree, isRetro }.
 * We need .sign and .nakshatra for ingresses, dignities, etc.
 */
function enrichPositions(positions) {
    if (!positions) return positions;
    return Object.fromEntries(
        Object.entries(positions)
            .filter(([p]) => NAVAGRAHA_SET.has(p))
            .map(([name, pos]) => {
                if (!pos || pos.longitude == null) return [name, pos];
                const nak = getNakshatra(pos.longitude);
                return [name, {
                    ...pos,
                    sign: pos.sign || getSignFromLongitude(pos.longitude),
                    signDegree: pos.signDegree ?? (pos.longitude % 30),
                    nakshatra: pos.nakshatra || nak.name,
                    nakshatraPada: pos.nakshatraPada || nak.pada,
                    nakshatraLord: pos.nakshatraLord || nak.lord,
                }];
            })
    );
}

// =============================================================================
// DIGNITY DETECTION
// =============================================================================

/**
 * Determine a planet's dignity in its current sign.
 * Returns: "exalted" | "debilitated" | "mool_trikona" | "own_sign" | null (ordinary)
 */
function getDignity(planetName, sign, signDegree = 15) {
    if (!planetName || !sign) return null;
    const s = sign.toLowerCase();

    // Exaltation
    const exalt = EXALTATION[planetName];
    if (exalt && exalt.sign.toLowerCase() === s) return "exalted";

    // Debilitation
    const debil = DEBILITATION[planetName];
    if (debil && debil.sign.toLowerCase() === s) return "debilitated";

    // Mool Trikona (check degree range)
    const mool = MOOL_TRIKONA[planetName];
    if (mool && mool.sign.toLowerCase() === s) {
        if (signDegree >= mool.from && signDegree <= mool.to) {
            return "mool_trikona";
        }
    }

    // Own sign
    const rulership = PLANET_RULERSHIP[planetName];
    if (rulership && rulership.some(r => r.toLowerCase() === s)) return "own_sign";

    return null;
}

// =============================================================================
// EXTRACT SIGNALS — All active signals for today
// =============================================================================

/**
 * Extract all active signals from today's sky positions.
 *
 * @param {Object} todayPositions - { planetName: { longitude, sign, signDegree, isRetro, nakshatra } }
 * @param {Object} [yesterdayPositions] - same format for yesterday. Enables applying/separating & speed detection.
 * @param {string} [dateStr] - "yyyy-MM-dd" date string for signal IDs
 * @returns {Object[]} Array of Signal objects
 */
export function extractSignals(todayPositions, yesterdayPositions = null, dateStr = null) {
    const signals = [];
    const date = dateStr || new Date().toISOString().split("T")[0];

    // Enrich positions: filter to Navagraha + derive sign/nakshatra from longitude
    const today = enrichPositions(todayPositions);
    const yesterday = enrichPositions(yesterdayPositions);

    // ── 1. ASPECTS ──────────────────────────────────────────────────────────
    const aspects = findAllAspects(today, yesterday);

    for (const asp of aspects) {
        const planets = [asp.planet1, asp.planet2];
        const status = getAspectStatus(asp.orb, asp.maxOrb, asp.applying);

        signals.push({
            id: makeSignalId(SIGNAL_TYPE.ASPECT, planets, asp.aspectType),
            type: SIGNAL_TYPE.ASPECT,
            planets,
            aspect: asp.aspectType,
            orb: asp.orb,
            maxOrb: asp.maxOrb,
            applying: asp.applying,
            status,
            intensity: calculateIntensity(planets, asp.orb, asp.maxOrb, { isVedic: asp.isVedicSpecial }),
            domains: mergeDomains(planets, asp.aspectType),
            date,
            detail: {
                planet1Sign: asp.planet1Sign,
                planet2Sign: asp.planet2Sign,
                planet1Retro: asp.planet1Retro,
                planet2Retro: asp.planet2Retro,
            },
        });
    }

    // ── 2. SIGN INGRESSES (today vs yesterday) ─────────────────────────────
    if (yesterday) {
        for (const [name, todayPos] of Object.entries(today)) {
            const yesterdayPos = yesterday[name];
            if (!yesterdayPos || !todayPos?.sign || !yesterdayPos?.sign) continue;

            if (todayPos.sign !== yesterdayPos.sign) {
                signals.push({
                    id: makeSignalId(SIGNAL_TYPE.INGRESS, [name], todayPos.sign),
                    type: SIGNAL_TYPE.INGRESS,
                    planets: [name],
                    fromSign: yesterdayPos.sign,
                    toSign: todayPos.sign,
                    status: SIGNAL_STATUS.ACTIVE,
                    intensity: calculateIntensity([name], 0, 1),
                    domains: mergeDomains([name]),
                    date,
                    detail: {
                        fromNakshatra: yesterdayPos.nakshatra,
                        toNakshatra: todayPos.nakshatra,
                        isRetro: todayPos.isRetro || false,
                    },
                });
            }
        }
    }

    // ── 3. RETROGRADE STATIONS (today vs yesterday) ─────────────────────────
    if (yesterday) {
        for (const [name, todayPos] of Object.entries(today)) {
            const yesterdayPos = yesterday[name];
            if (!yesterdayPos) continue;
            // Skip shadow planets (always "retrograde" in mean node calculation)
            if (name === "Rahu" || name === "Ketu") continue;

            const todayRetro = todayPos.isRetro || false;
            const yesterdayRetro = yesterdayPos.isRetro || false;

            if (todayRetro !== yesterdayRetro) {
                const stationType = todayRetro ? "retrograde" : "direct";
                signals.push({
                    id: makeSignalId(SIGNAL_TYPE.STATION, [name], stationType),
                    type: SIGNAL_TYPE.STATION,
                    planets: [name],
                    stationType,
                    status: SIGNAL_STATUS.ACTIVE,
                    intensity: calculateIntensity([name], 0, 1),
                    domains: mergeDomains([name]),
                    date,
                    detail: {
                        sign: todayPos.sign,
                        signDegree: todayPos.signDegree,
                        nakshatra: todayPos.nakshatra,
                    },
                });
            }
        }
    }

    // ── 4. DIGNITY SHIFTS (today vs yesterday) ──────────────────────────────
    if (yesterday) {
        for (const [name, todayPos] of Object.entries(today)) {
            const yesterdayPos = yesterday[name];
            if (!yesterdayPos || !todayPos?.sign || !yesterdayPos?.sign) continue;

            const todayDignity = getDignity(name, todayPos.sign, todayPos.signDegree);
            const yesterdayDignity = getDignity(name, yesterdayPos.sign, yesterdayPos.signDegree);

            if (todayDignity && todayDignity !== yesterdayDignity) {
                signals.push({
                    id: makeSignalId(SIGNAL_TYPE.DIGNITY, [name], todayDignity),
                    type: SIGNAL_TYPE.DIGNITY,
                    planets: [name],
                    dignity: todayDignity,
                    previousDignity: yesterdayDignity,
                    status: SIGNAL_STATUS.ACTIVE,
                    intensity: calculateIntensity([name], 0, 1),
                    domains: mergeDomains([name]),
                    date,
                    detail: {
                        sign: todayPos.sign,
                        signDegree: todayPos.signDegree,
                    },
                });
            }
        }
    }

    // ── 5. CURRENT DIGNITIES (always report, for context) ───────────────────
    for (const [name, pos] of Object.entries(today)) {
        if (!pos?.sign) continue;
        const dignity = getDignity(name, pos.sign, pos.signDegree);
        if (dignity === "exalted" || dignity === "debilitated") {
            // Only if not already reported as a shift
            const alreadyShifted = signals.some(
                s => s.type === SIGNAL_TYPE.DIGNITY && s.planets[0] === name
            );
            if (!alreadyShifted) {
                signals.push({
                    id: makeSignalId(SIGNAL_TYPE.DIGNITY, [name], `current-${dignity}`),
                    type: SIGNAL_TYPE.DIGNITY,
                    planets: [name],
                    dignity,
                    previousDignity: null,
                    status: SIGNAL_STATUS.ACTIVE,
                    intensity: calculateIntensity([name], 0, 1),
                    domains: mergeDomains([name]),
                    date,
                    detail: {
                        sign: pos.sign,
                        signDegree: pos.signDegree,
                        ongoing: true,
                    },
                });
            }
        }
    }

    // ── 5b. NAKSHATRA CHANGES (today vs yesterday) ────────────────────────
    if (yesterday) {
        for (const [name, todayPos] of Object.entries(today)) {
            // Only track slow planets for nakshatra changes (fast ones change too often)
            if (["Moon", "Sun", "Mercury", "Venus"].includes(name)) continue;
            const yesterdayPos = yesterday[name];
            if (!yesterdayPos || !todayPos?.nakshatra || !yesterdayPos?.nakshatra) continue;

            if (todayPos.nakshatra !== yesterdayPos.nakshatra) {
                signals.push({
                    id: makeSignalId("nakshatra", [name], todayPos.nakshatra),
                    type: "nakshatra",
                    planets: [name],
                    fromNakshatra: yesterdayPos.nakshatra,
                    toNakshatra: todayPos.nakshatra,
                    status: SIGNAL_STATUS.ACTIVE,
                    intensity: calculateIntensity([name], 0, 1),
                    domains: mergeDomains([name]),
                    date,
                    detail: {
                        sign: todayPos.sign,
                        signDegree: todayPos.signDegree,
                        isRetro: todayPos.isRetro || false,
                    },
                });
            }
        }
    }

    // ── 5c. MUTUAL RECEPTION (Parivartana Yoga) ─────────────────────────────
    // Two planets in each other's signs — powerful sign exchange
    {
        const planetNames = Object.keys(today).filter(
            n => PLANET_RULERSHIP[n] // only planets with rulerships
        );
        for (let i = 0; i < planetNames.length; i++) {
            for (let j = i + 1; j < planetNames.length; j++) {
                const p1 = planetNames[i];
                const p2 = planetNames[j];
                const pos1 = today[p1];
                const pos2 = today[p2];
                if (!pos1?.sign || !pos2?.sign) continue;

                const p1Rules = (PLANET_RULERSHIP[p1] || []).map(s => s.toLowerCase());
                const p2Rules = (PLANET_RULERSHIP[p2] || []).map(s => s.toLowerCase());

                const p1InP2Sign = p2Rules.includes(pos1.sign.toLowerCase());
                const p2InP1Sign = p1Rules.includes(pos2.sign.toLowerCase());

                if (p1InP2Sign && p2InP1Sign) {
                    signals.push({
                        id: makeSignalId("parivartana", [p1, p2]),
                        type: "parivartana",
                        planets: [p1, p2],
                        status: SIGNAL_STATUS.ACTIVE,
                        intensity: Math.min(10, calculateIntensity([p1, p2], 0, 1) + 1), // bonus for yoga
                        domains: mergeDomains([p1, p2]),
                        date,
                        detail: {
                            planet1Sign: pos1.sign,
                            planet2Sign: pos2.sign,
                            description: `${p1} in ${pos1.sign} (ruled by ${p2}) ↔ ${p2} in ${pos2.sign} (ruled by ${p1})`,
                        },
                    });
                }
            }
        }
    }

    // ── 5d. VEDIC MUNDANE YOGAS ──────────────────────────────────────────
    detectMundaneYogas(today, signals, date);

    // ── 6. COMBUSTIONS ──────────────────────────────────────────────────────
    const combustions = findCombustions(today);
    for (const comb of combustions) {
        signals.push({
            id: makeSignalId(SIGNAL_TYPE.COMBUSTION, [comb.planet]),
            type: SIGNAL_TYPE.COMBUSTION,
            planets: [comb.planet, "Sun"],
            orb: comb.orb,
            maxOrb: comb.maxOrb,
            severity: comb.severity,
            status: SIGNAL_STATUS.ACTIVE,
            intensity: comb.severity === "severe"
                ? calculateIntensity([comb.planet, "Sun"], 0, comb.maxOrb)
                : calculateIntensity([comb.planet, "Sun"], comb.orb, comb.maxOrb),
            domains: mergeDomains([comb.planet, "Sun"]),
            date,
            detail: { isRetro: comb.isRetro },
        });
    }

    // ── 7. STELLIUM DETECTION (3+ planets in same sign) ────────────────────
    const signGroups = {};
    for (const [planet, pos] of Object.entries(today)) {
        const sign = pos.sign;
        if (!sign) continue;
        if (!signGroups[sign]) signGroups[sign] = [];
        signGroups[sign].push(planet);
    }
    for (const [sign, planets] of Object.entries(signGroups)) {
        if (planets.length >= 3) {
            const house = ZODIAC_SIGNS.indexOf(sign) + 1;
            signals.push({
                id: makeSignalId(SIGNAL_TYPE.STELLIUM, planets, sign),
                type: SIGNAL_TYPE.STELLIUM,
                planets,
                sign,
                house,
                count: planets.length,
                // 3 planets = 7, 4 = 8, 5+ = 9
                intensity: Math.min(6 + planets.length, 10),
                status: SIGNAL_STATUS.ACTIVE,
                domains: mergeDomains(planets),
                date,
                detail: {
                    description: `${planets.length}-planet stellium in ${sign} (H${house}): ${planets.join(", ")}`,
                },
            });
        }
    }

    // ── 8. ECLIPSE PROXIMITY ────────────────────────────────────────────────
    const eclipses = findEclipseProximity(today);
    for (const ecl of eclipses) {
        signals.push({
            id: makeSignalId(SIGNAL_TYPE.ECLIPSE, [ecl.luminary, ecl.node]),
            type: SIGNAL_TYPE.ECLIPSE,
            planets: [ecl.luminary, ecl.node],
            eclipseType: ecl.eclipseType,
            proximity: ecl.proximity,
            orb: ecl.orb,
            status: ecl.proximity === "imminent" ? SIGNAL_STATUS.ACTIVE : SIGNAL_STATUS.FORMING,
            intensity: ecl.proximity === "imminent" ? 10 : ecl.proximity === "close" ? 8 : 5,
            domains: mergeDomains([ecl.luminary, ecl.node]),
            date,
        });
    }

    // ── 9. SPEED ANOMALIES ──────────────────────────────────────────────────
    if (yesterday) {
        const speedAnomalies = findSpeedAnomalies(today, yesterday);
        for (const sa of speedAnomalies) {
            signals.push({
                id: makeSignalId(SIGNAL_TYPE.SPEED, [sa.planet], sa.anomalyType),
                type: SIGNAL_TYPE.SPEED,
                planets: [sa.planet],
                anomalyType: sa.anomalyType,
                status: sa.anomalyType === "stationary" ? SIGNAL_STATUS.ACTIVE : SIGNAL_STATUS.FORMING,
                intensity: sa.anomalyType === "stationary" ? 9 : sa.anomalyType === "slow" ? 6 : 4,
                domains: mergeDomains([sa.planet]),
                date,
                detail: {
                    dailyMotion: sa.dailyMotion,
                    averageMotion: sa.averageMotion,
                    ratio: sa.ratio,
                    direction: sa.direction,
                },
            });
        }
    }

    // Sort: highest intensity first
    signals.sort((a, b) => b.intensity - a.intensity);

    return signals;
}

// =============================================================================
// DIFF SKY — Only what changed since yesterday
// =============================================================================

/**
 * Returns only signals that represent CHANGES from yesterday.
 * This is what the agent primarily looks at — not everything, just what's new.
 *
 * @param {Object} todayPositions
 * @param {Object} yesterdayPositions
 * @param {string} [dateStr]
 * @returns {Object} { newSignals[], changedSignals[], summary }
 */
export function diffSky(todayPositions, yesterdayPositions, dateStr = null) {
    const allToday = extractSignals(todayPositions, yesterdayPositions, dateStr);
    const allYesterday = yesterdayPositions
        ? extractSignals(yesterdayPositions, null, dateStr) // no applying/separating for yesterday
        : [];

    const todayIds = new Set(allToday.map(s => s.id));
    const yesterdayIds = new Set(allYesterday.map(s => s.id));

    // New signals: in today but not yesterday
    const newSignals = allToday.filter(s => !yesterdayIds.has(s.id));

    // Changed signals: in both but with different status/orb
    const changedSignals = [];
    for (const todaySignal of allToday) {
        if (!yesterdayIds.has(todaySignal.id)) continue;
        const yesterdaySignal = allYesterday.find(s => s.id === todaySignal.id);
        if (!yesterdaySignal) continue;

        // Check if orb changed significantly (aspect tightened/loosened)
        if (todaySignal.type === SIGNAL_TYPE.ASPECT) {
            const orbChange = (yesterdaySignal.orb || 0) - (todaySignal.orb || 0);
            // Report if orb changed by >0.5° or status changed
            if (Math.abs(orbChange) > 0.5 || todaySignal.status !== yesterdaySignal.status) {
                changedSignals.push({
                    ...todaySignal,
                    previousOrb: yesterdaySignal.orb,
                    orbChange: Math.round(orbChange * 100) / 100,
                    previousStatus: yesterdaySignal.status,
                });
            }
        }
    }

    // Ended signals: in yesterday but not today (left orb)
    const endedSignals = allYesterday
        .filter(s => !todayIds.has(s.id))
        .map(s => ({ ...s, status: SIGNAL_STATUS.ENDED }));

    // Build a human-readable summary
    const summary = buildDiffSummary(newSignals, changedSignals, endedSignals);

    return {
        newSignals,
        changedSignals,
        endedSignals,
        allActiveSignals: allToday,
        summary,
        date: dateStr || new Date().toISOString().split("T")[0],
        stats: {
            totalActive: allToday.length,
            new: newSignals.length,
            changed: changedSignals.length,
            ended: endedSignals.length,
        },
    };
}

// =============================================================================
// HELPERS
// =============================================================================

/**
 * Determine aspect status based on orb and applying/separating.
 */
function getAspectStatus(orb, maxOrb, applying) {
    if (orb <= 1) {
        return applying === false ? SIGNAL_STATUS.PEAKED : SIGNAL_STATUS.ACTIVE;
    }
    if (applying === true) {
        return orb < maxOrb * 0.5 ? SIGNAL_STATUS.ACTIVE : SIGNAL_STATUS.FORMING;
    }
    if (applying === false) {
        return orb < maxOrb * 0.5 ? SIGNAL_STATUS.PEAKED : SIGNAL_STATUS.FADING;
    }
    // No applying data
    return orb < maxOrb * 0.3 ? SIGNAL_STATUS.ACTIVE : SIGNAL_STATUS.FORMING;
}

/**
 * Build a concise human-readable summary of sky changes.
 */
function buildDiffSummary(newSignals, changedSignals, endedSignals) {
    const parts = [];

    // New formations
    const newAspects = newSignals.filter(s => s.type === SIGNAL_TYPE.ASPECT);
    const newIngresses = newSignals.filter(s => s.type === SIGNAL_TYPE.INGRESS);
    const newStations = newSignals.filter(s => s.type === SIGNAL_TYPE.STATION);
    const newDignities = newSignals.filter(s => s.type === SIGNAL_TYPE.DIGNITY && s.previousDignity != null);
    const newEclipses = newSignals.filter(s => s.type === SIGNAL_TYPE.ECLIPSE);

    if (newAspects.length > 0) {
        const desc = newAspects.map(a => `${a.planets.join("-")} ${a.aspect} (${a.orb}°)`).join(", ");
        parts.push(`New aspects: ${desc}`);
    }

    if (newIngresses.length > 0) {
        const desc = newIngresses.map(i => `${i.planets[0]} → ${i.toSign}`).join(", ");
        parts.push(`Sign changes: ${desc}`);
    }

    if (newStations.length > 0) {
        const desc = newStations.map(s => `${s.planets[0]} goes ${s.stationType}`).join(", ");
        parts.push(`Stations: ${desc}`);
    }

    if (newDignities.length > 0) {
        const desc = newDignities.map(d => `${d.planets[0]} now ${d.dignity} in ${d.detail?.sign}`).join(", ");
        parts.push(`Dignity shifts: ${desc}`);
    }

    if (newEclipses.length > 0) {
        const desc = newEclipses.map(e => `${e.eclipseType} eclipse indicator (${e.proximity})`).join(", ");
        parts.push(`Eclipse: ${desc}`);
    }

    // Tightening aspects
    const tightening = changedSignals.filter(s => s.orbChange > 0);
    if (tightening.length > 0) {
        const desc = tightening.map(a => `${a.planets.join("-")} ${a.aspect} → ${a.orb}°`).join(", ");
        parts.push(`Tightening: ${desc}`);
    }

    // Ended
    if (endedSignals.length > 0) {
        const desc = endedSignals.slice(0, 3).map(s => s.id).join(", ");
        parts.push(`Ended (${endedSignals.length}): ${desc}${endedSignals.length > 3 ? "..." : ""}`);
    }

    return parts.length > 0 ? parts.join(". ") : "No significant changes.";
}

// =============================================================================
// CONVENIENCE: Extract signals for a date range
// =============================================================================

/**
 * Extract signals for multiple consecutive days from a positions map.
 * Useful for batch analysis.
 *
 * @param {Object} positionsByDate - { "2026-04-11": { Sun: {...}, Moon: {...}, ... }, ... }
 * @param {string[]} sortedDates - dates in ascending order
 * @returns {Object} { byDate: { "2026-04-11": { signals, diff } }, timeline: Signal[] }
 */
export function extractSignalTimeline(positionsByDate, sortedDates) {
    const byDate = {};
    const timeline = [];

    for (let i = 0; i < sortedDates.length; i++) {
        const dateStr = sortedDates[i];
        const today = positionsByDate[dateStr];
        const yesterday = i > 0 ? positionsByDate[sortedDates[i - 1]] : null;

        if (!today) continue;

        const signals = extractSignals(today, yesterday, dateStr);
        const diff = yesterday ? diffSky(today, yesterday, dateStr) : null;

        byDate[dateStr] = { signals, diff };
        timeline.push(...signals.map(s => ({ ...s, timelineDate: dateStr })));
    }

    return { byDate, timeline };
}

// =============================================================================
// TOP SIGNALS — Quick summary of the most important signals
// =============================================================================

/**
 * Get the top N most significant signals, deduped by planet pair.
 * Used for the "Current Sky" summary view.
 *
 * @param {Object[]} signals - Array of signals from extractSignals()
 * @param {number} [limit=10] - Max signals to return
 * @returns {Object[]} Top signals sorted by intensity
 */
export function getTopSignals(signals, limit = 10) {
    // Dedupe: keep highest intensity per unique planet pair
    const seen = new Map();
    for (const signal of signals) {
        const key = [...signal.planets].sort().join("+"); // spread to avoid mutating original
        if (!seen.has(key) || seen.get(key).intensity < signal.intensity) {
            seen.set(key, signal);
        }
    }

    return [...seen.values()]
        .sort((a, b) => b.intensity - a.intensity)
        .slice(0, limit);
}
