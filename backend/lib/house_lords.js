/**
 * House Lords — Mundane Astrology Context
 *
 * In mundane (world) astrology, the Aries ingress chart (or Chaitra
 * Shukla Pratipada chart) sets the Ascendant for the year/quarter.
 * But for daily cosmic intelligence we use a FIXED Aries Ascendant
 * (natural zodiac) — this is standard in mundane Vedic astrology
 * when no specific national chart is available.
 *
 * Fixed Aries Ascendant means:
 *   H1 = Aries, H2 = Taurus, H3 = Gemini, ... H12 = Pisces
 *
 * This module computes:
 *   - Which house each planet occupies
 *   - Which houses each planet lords over
 *   - Summary text for LLM consumption (the real value)
 *
 * Pure math. No LLM. No cost.
 */

import {
    ZODIAC_SIGNS,
    PLANET_RULERSHIP,
    MUNDANE_HOUSES,
    SIGN_TO_HOUSE,
    getSignFromLongitude,
    getSignDegree,
} from "./constants.js";

/**
 * Get the house number for a given sign (fixed Aries ascendant).
 * @param {string} sign - Sign name (e.g., "Pisces")
 * @returns {number} House number 1-12
 */
export function getHouse(sign) {
    return SIGN_TO_HOUSE[sign?.toLowerCase()] || null;
}

/**
 * Get the houses a planet lords over.
 * @param {string} planet - Planet name
 * @returns {number[]} Array of house numbers
 */
export function getLordedHouses(planet) {
    const signs = PLANET_RULERSHIP[planet];
    if (!signs) return [];
    return signs.map(s => SIGN_TO_HOUSE[s.toLowerCase()]);
}

/**
 * Get mundane signification for a house.
 * @param {number} house - House number 1-12
 * @returns {string} Signification text
 */
export function getHouseSignification(house) {
    const h = MUNDANE_HOUSES[house];
    return h ? h.domain : "";
}

/** Derive sign from longitude if not provided. */
function getSignFromPos(pos) {
    if (pos?.sign) return pos.sign;
    return getSignFromLongitude(pos?.longitude) || null;
}

/** Derive sign degree from longitude if not provided. */
function getDegreeFromPos(pos) {
    if (pos?.signDegree != null) return pos.signDegree;
    return getSignDegree(pos?.longitude);
}

/**
 * Build a complete house lord context for the current sky.
 *
 * @param {Object} positions - { planetName: { longitude, sign?, signDegree?, isRetro?, ... } }
 * @returns {Object} { placements[], summary }
 */
export function buildHouseLordContext(positions) {
    const placements = [];

    for (const [planet, pos] of Object.entries(positions)) {
        if (!PLANET_RULERSHIP[planet]) continue;
        const sign = getSignFromPos(pos);
        if (!sign) continue;

        const signDegree = getDegreeFromPos(pos);
        const occupiedHouse = getHouse(sign);
        const lordedHouses = getLordedHouses(planet);

        placements.push({
            planet,
            sign,
            signDegree,
            isRetro: pos.isRetro || false,
            occupiedHouse,
            lordsOf: lordedHouses,
            lordSignifications: lordedHouses.map(h => ({
                house: h,
                meaning: MUNDANE_HOUSES[h]?.domain || "",
            })),
            occupiedSignification: MUNDANE_HOUSES[occupiedHouse]?.domain || "",
        });
    }

    // Sort by planet weight (heavy planets first for readability)
    const WEIGHT_ORDER = { Saturn: 0, Jupiter: 1, Rahu: 2, Ketu: 3, Mars: 4, Sun: 5, Venus: 6, Mercury: 7, Moon: 8 };
    placements.sort((a, b) => (WEIGHT_ORDER[a.planet] ?? 9) - (WEIGHT_ORDER[b.planet] ?? 9));

    const summary = buildSummaryText(placements);
    return { placements, summary };
}

/**
 * Build human-readable summary for LLM consumption.
 * Format: "Saturn (H10/H11 lord) in Pisces H12 — government/parliament in house of losses"
 */
function buildSummaryText(placements) {
    const lines = [];

    for (const p of placements) {
        const lordStr = p.lordsOf.map(h => `H${h}`).join("/");
        const retroStr = p.isRetro ? " ℞" : "";
        const degStr = p.signDegree != null ? ` ${p.signDegree.toFixed(1)}°` : "";
        const occupiedMeaning = p.occupiedSignification || "";
        const lordMeanings = p.lordSignifications
            .map(ls => `${ls.meaning}`)
            .join("; ");

        lines.push(
            `${p.planet}${retroStr} (${lordStr} lord) in ${p.sign}${degStr} [H${p.occupiedHouse}]` +
            `\n  → Lords of: ${lordMeanings}` +
            `\n  → Placed in: ${occupiedMeaning}`
        );
    }

    return lines.join("\n\n");
}
