/**
 * Vedic Mundane Yogas — Classical Planetary Combinations
 *
 * Detects yogas (special configurations) relevant to mundane astrology.
 * These are pattern-based — they depend on house positions and sign
 * placements, not precise orbs.
 *
 * Yogas detected:
 *   - Gajakesari Yoga    : Jupiter in kendra from Moon
 *   - Viparita Raja Yoga : Dusthana lord in another dusthana
 *   - Neechabhanga Raja  : Debilitation cancellation
 *   - Kendra-Trikona Raja: Kendra lord conjoins trikona lord
 *   - Graha Yuddha       : Planetary war (two planets within 1°)
 *
 * Pure math. No LLM. No cost.
 */

import {
    SIGNAL_STATUS,
    DEBILITATION,
    PLANET_RULERSHIP,
    calculateIntensity,
    mergeDomains,
    makeSignalId,
} from "./signal_types.js";

import { angularSeparation } from "./aspect_calculator.js";

// =============================================================================
// YOGA DETECTION
// =============================================================================

/**
 * Detect classical Vedic yogas relevant to mundane astrology.
 *
 * @param {Object} positions - Enriched planet positions (with .sign, .longitude)
 * @param {Object[]} signals - Mutable array to push new signals into
 * @param {string} date - ISO date string
 */
export function detectMundaneYogas(positions, signals, date) {
    const planetHouses = {};
    for (const [name, pos] of Object.entries(positions)) {
        if (!pos?.longitude) continue;
        planetHouses[name] = Math.floor(((pos.longitude % 360) + 360) % 360 / 30) + 1;
    }

    // Helper: Vedic house distance (inclusive counting).
    // Same house = 1, next = 2, etc. Moon(H1) → Jupiter(H4) = 4th from Moon.
    const houseDist = (p1, p2) => {
        const h1 = planetHouses[p1], h2 = planetHouses[p2];
        if (!h1 || !h2) return null;
        return ((h2 - h1 + 12) % 12) + 1;
    };

    const KENDRAS = new Set([1, 4, 7, 10]);

    detectGajakesari(planetHouses, houseDist, KENDRAS, signals, date);
    detectViparataRaja(planetHouses, signals, date);
    detectNeechabhanga(positions, planetHouses, KENDRAS, signals, date);
    detectKendraTrikonaRaja(planetHouses, signals, date);
    detectGrahaYuddha(positions, signals, date);
}

// ── GAJAKESARI YOGA ─────────────────────────────────────────────────────────
// Jupiter in kendra (1,4,7,10) from Moon.
// Mundane: collective wisdom, financial stability, strong governance.

function detectGajakesari(planetHouses, houseDist, KENDRAS, signals, date) {
    if (!planetHouses.Jupiter || !planetHouses.Moon) return;
    const dist = houseDist("Moon", "Jupiter");
    if (!KENDRAS.has(dist)) return;

    signals.push({
        id: makeSignalId("yoga", ["Jupiter", "Moon"], "gajakesari"),
        type: "yoga",
        planets: ["Jupiter", "Moon"],
        yogaName: "Gajakesari",
        status: SIGNAL_STATUS.ACTIVE,
        intensity: 7,
        domains: ["finance", "governance", "wisdom", "public-morale"],
        date,
        detail: {
            description: `Jupiter in H${planetHouses.Jupiter} is in kendra (${dist}th) from Moon in H${planetHouses.Moon}`,
            significance: "Collective wisdom, financial stability, strong governance",
        },
    });
}

// ── VIPARITA RAJA YOGA ──────────────────────────────────────────────────────
// 6th lord in 8th/12th, 8th lord in 6th/12th, 12th lord in 6th/8th.
// Mundane: victory through enemy's misfortune, crisis resolution.

function detectViparataRaja(planetHouses, signals, date) {
    // Kalpurush dusthana lords
    const DUSTHANA_LORDS = { 6: "Mercury", 8: "Mars", 12: "Jupiter" };

    for (const [fromH, lord] of Object.entries(DUSTHANA_LORDS)) {
        const h = planetHouses[lord];
        if (!h) continue;
        const otherDusthanas = [6, 8, 12].filter(d => d !== +fromH);
        if (!otherDusthanas.includes(h)) continue;

        signals.push({
            id: makeSignalId("yoga", [lord], `viparita-raja-H${fromH}in${h}`),
            type: "yoga",
            planets: [lord],
            yogaName: "Viparita Raja",
            status: SIGNAL_STATUS.ACTIVE,
            intensity: 6,
            domains: ["crisis-resolution", "hidden-advantage", "enemy-defeat"],
            date,
            detail: {
                description: `H${fromH} lord ${lord} in H${h} — dusthana lord in dusthana`,
                significance: "Victory through enemy's misfortune, crisis turning to advantage",
            },
        });
    }
}

// ── NEECHABHANGA RAJA YOGA ──────────────────────────────────────────────────
// Debilitated planet whose sign lord sits in a kendra from Lagna.
// Mundane: weakness transformed into strength, unexpected reversal.

function detectNeechabhanga(positions, planetHouses, KENDRAS, signals, date) {
    for (const [name, pos] of Object.entries(positions)) {
        if (!pos?.sign || !DEBILITATION[name]) continue;
        if (DEBILITATION[name].sign.toLowerCase() !== pos.sign.toLowerCase()) continue;

        // Planet IS debilitated. Find the lord of its debilitation sign.
        const debilSign = DEBILITATION[name].sign;
        const signLord = Object.entries(PLANET_RULERSHIP).find(
            ([, signs]) => signs.some(s => s.toLowerCase() === debilSign.toLowerCase())
        )?.[0];
        if (!signLord || !planetHouses[signLord]) continue;

        // Is sign lord in kendra from Lagna (H1)?
        if (!KENDRAS.has(planetHouses[signLord])) continue;

        signals.push({
            id: makeSignalId("yoga", [name, signLord], "neechabhanga"),
            type: "yoga",
            planets: [name, signLord],
            yogaName: "Neechabhanga Raja",
            status: SIGNAL_STATUS.ACTIVE,
            intensity: 7,
            domains: ["reversal", "underdog-victory", "unexpected-rise"],
            date,
            detail: {
                description: `${name} debilitated in ${pos.sign}, but its sign lord ${signLord} is in H${planetHouses[signLord]} (kendra)`,
                significance: "Weakness transformed into strength, unexpected reversal of fortune",
            },
        });
    }
}

// ── KENDRA/TRIKONA RAJA YOGA ────────────────────────────────────────────────
// Kendra lord conjunct trikona lord in the same house.
// Kalpurush: Kendra lords = Mars(1), Moon(4), Venus(7), Saturn(10)
//            Trikona lords = Mars(1), Sun(5), Jupiter(9)

function detectKendraTrikonaRaja(planetHouses, signals, date) {
    const kendraLords = ["Mars", "Moon", "Venus", "Saturn"];
    const trikonaLords = ["Mars", "Sun", "Jupiter"];

    for (const kl of kendraLords) {
        for (const tl of trikonaLords) {
            if (kl === tl) continue;  // Mars is both; skip self-pair
            const h1 = planetHouses[kl], h2 = planetHouses[tl];
            if (!h1 || !h2 || h1 !== h2) continue; // must share a house

            signals.push({
                id: makeSignalId("yoga", [kl, tl], "raja-yoga"),
                type: "yoga",
                planets: [kl, tl],
                yogaName: "Raja Yoga",
                status: SIGNAL_STATUS.ACTIVE,
                intensity: 8,
                domains: ["power", "authority", "governance", "prosperity"],
                date,
                detail: {
                    description: `Kendra lord ${kl} conjoins trikona lord ${tl} in H${h1}`,
                    significance: "Strong power combination — authority meets purpose",
                },
            });
        }
    }
}

// ── GRAHA YUDDHA (Planetary War) ────────────────────────────────────────────
// Two true planets within 1°. The brighter wins; the loser is weakened.
// Excludes Sun (combustion instead), Moon, Rahu, Ketu.

function detectGrahaYuddha(positions, signals, date) {
    const warPlanets = ["Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

    for (let i = 0; i < warPlanets.length; i++) {
        for (let j = i + 1; j < warPlanets.length; j++) {
            const p1 = warPlanets[i], p2 = warPlanets[j];
            const pos1 = positions[p1], pos2 = positions[p2];
            if (!pos1?.longitude || !pos2?.longitude) continue;

            const sep = angularSeparation(pos1.longitude, pos2.longitude);
            if (sep > 1.0) continue;

            signals.push({
                id: makeSignalId("yoga", [p1, p2], "graha-yuddha"),
                type: "yoga",
                planets: [p1, p2],
                yogaName: "Graha Yuddha",
                orb: +sep.toFixed(2),
                status: SIGNAL_STATUS.ACTIVE,
                intensity: 8,
                domains: [...new Set([...mergeDomains([p1]), ...mergeDomains([p2]), "conflict", "power-struggle"])],
                date,
                detail: {
                    description: `${p1} and ${p2} within ${sep.toFixed(2)}° — planetary war`,
                    significance: "Intense struggle between the domains ruled by both planets",
                },
            });
        }
    }
}
