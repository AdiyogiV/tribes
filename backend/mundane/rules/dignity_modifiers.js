/**
 * Dignity & Strength Modifiers — Weight Adjustment System
 *
 * REUSES existing constants from lib/ — single source of truth.
 * Adds mundane-specific modifier calculation on top.
 *
 * Source: Brihat Jataka (Ch.1), Saravali, Parashari principles
 */

import { PLANET_RULERSHIP } from "../../lib/constants.js";
import {
    EXALTATION as EXALT_DATA,
    DEBILITATION as DEBIL_DATA,
    MOOL_TRIKONA,
    COMBUSTION_ORBS,
} from "../../lib/signal_types.js";

// ─── Derived lookups from existing data ──────────────────────────────────

/** Sign → ruler (inverted from PLANET_RULERSHIP) */
export const SIGN_RULERS = {};
for (const [planet, signs] of Object.entries(PLANET_RULERSHIP)) {
    for (const sign of signs) SIGN_RULERS[sign] = planet;
}

/** Planet → exaltation sign (extracted from signal_types format) */
export const EXALTATION = {};
for (const [planet, data] of Object.entries(EXALT_DATA)) {
    EXALTATION[planet] = data.sign;
}

/** Planet → debilitation sign */
export const DEBILITATION = {};
for (const [planet, data] of Object.entries(DEBIL_DATA)) {
    DEBILITATION[planet] = data.sign;
}

/** Planet → moolatrikona sign */
export const MOOLATRIKONA = {};
for (const [planet, data] of Object.entries(MOOL_TRIKONA)) {
    MOOLATRIKONA[planet] = data.sign;
}

// ─── Natural friendships (not in existing lib — mundane needs these) ─────
export const FRIENDSHIPS = {
    Sun:     { friends: ["Moon", "Mars", "Jupiter"], neutral: ["Mercury"], enemies: ["Venus", "Saturn"] },
    Moon:    { friends: ["Sun", "Mercury"], neutral: ["Mars", "Jupiter", "Venus", "Saturn"], enemies: [] },
    Mars:    { friends: ["Sun", "Moon", "Jupiter"], neutral: ["Venus", "Saturn"], enemies: ["Mercury"] },
    Mercury: { friends: ["Sun", "Venus"], neutral: ["Mars", "Jupiter", "Saturn"], enemies: ["Moon"] },
    Jupiter: { friends: ["Sun", "Moon", "Mars"], neutral: ["Saturn"], enemies: ["Mercury", "Venus"] },
    Venus:   { friends: ["Mercury", "Saturn"], neutral: ["Mars", "Jupiter"], enemies: ["Sun", "Moon"] },
    Saturn:  { friends: ["Mercury", "Venus"], neutral: ["Jupiter"], enemies: ["Sun", "Moon", "Mars"] },
    Rahu:    { friends: ["Saturn", "Venus", "Mercury"], neutral: ["Jupiter"], enemies: ["Sun", "Moon", "Mars"] },
    Ketu:    { friends: ["Mars", "Jupiter"], neutral: ["Saturn", "Venus", "Mercury"], enemies: ["Sun", "Moon"] },
};

/**
 * Calculate the dignity state of a planet in a sign.
 */
export function getDignity(planet, sign) {
    if (EXALTATION[planet] === sign) {
        return { state: "exalted", modifier: 1.5, label: `${planet} exalted in ${sign}` };
    }
    if (DEBILITATION[planet] === sign) {
        return { state: "debilitated", modifier: 0.5, label: `${planet} debilitated in ${sign}` };
    }
    if (MOOLATRIKONA[planet] === sign) {
        return { state: "moolatrikona", modifier: 1.3, label: `${planet} in moolatrikona ${sign}` };
    }
    if (SIGN_RULERS[sign] === planet) {
        return { state: "own_sign", modifier: 1.2, label: `${planet} in own sign ${sign}` };
    }

    const signLord = SIGN_RULERS[sign];
    const rel = FRIENDSHIPS[planet];
    if (rel) {
        if (rel.friends.includes(signLord)) {
            return { state: "friend_sign", modifier: 1.1, label: `${planet} in friend's sign ${sign} (${signLord})` };
        }
        if (rel.enemies.includes(signLord)) {
            return { state: "enemy_sign", modifier: 0.8, label: `${planet} in enemy's sign ${sign} (${signLord})` };
        }
    }

    return { state: "neutral", modifier: 1.0, label: `${planet} neutral in ${sign}` };
}

/**
 * Retrograde modifier — retrograde planets are stronger in mundane
 * (closer to Earth, appear brighter).
 */
export function getRetrogradeModifier(isRetrograde) {
    return isRetrograde ? 1.2 : 1.0;
}

/**
 * Combustion modifier — reuses COMBUSTION_ORBS from signal_types.
 */
export function getCombustionModifier(planet, sunDistance) {
    const threshold = COMBUSTION_ORBS[planet];
    if (!threshold) return 1.0;
    if (sunDistance < threshold) return 0.6;
    return 1.0;
}

/**
 * Combined strength modifier for a planet position.
 */
export function getStrengthModifier(planet, position) {
    const { sign, isRetrograde = false, isRetro = false, sunDistance = 180 } = position;
    const details = [];
    const retro = isRetrograde || isRetro;

    const dignity = getDignity(planet, sign);
    details.push(dignity.label);
    let total = dignity.modifier;

    const retroMod = getRetrogradeModifier(retro);
    if (retroMod !== 1.0) {
        details.push(`${planet} retrograde (+20%)`);
        total *= retroMod;
    }

    const combustMod = getCombustionModifier(planet, sunDistance);
    if (combustMod !== 1.0) {
        details.push(`${planet} combust (-40%)`);
        total *= combustMod;
    }

    return { totalModifier: Math.round(total * 100) / 100, dignity, details };
}

/**
 * Apply strength modifier to effects array.
 * Adjusts weight and flips direction for debilitated/exalted.
 */
export function applyModifierToEffects(effects, modifier, dignityState) {
    return effects.map(e => {
        const adjusted = { ...e, originalWeight: e.weight, weight: Math.min(1.0, e.weight * modifier) };

        if (dignityState === "debilitated") {
            if (e.dir === "pos") adjusted.weight = e.weight * 0.4;
            if (e.dir === "neg") adjusted.weight = Math.min(1.0, e.weight * 1.3);
        }
        if (dignityState === "exalted") {
            if (e.dir === "pos") adjusted.weight = Math.min(1.0, e.weight * 1.4);
            if (e.dir === "neg") adjusted.weight = e.weight * 0.6;
        }

        return adjusted;
    });
}
