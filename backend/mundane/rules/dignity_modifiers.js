/**
 * Dignity & Strength Modifiers — Weight Adjustment System
 *
 * Source: Brihat Jataka (Ch.1), Saravali, Parashari principles
 *
 * Planetary dignity modifies the BASE WEIGHT of any effect.
 * A planet in its own sign amplifies its natural effects.
 * A debilitated planet's negative effects are amplified, positive effects weakened.
 *
 * This file provides the lookup tables and the modifier calculation.
 */

// ─── SIGN RULERSHIPS ─────────────────────────────────────────────────────
export const SIGN_RULERS = {
    Aries: "Mars", Taurus: "Venus", Gemini: "Mercury", Cancer: "Moon",
    Leo: "Sun", Virgo: "Mercury", Libra: "Venus", Scorpio: "Mars",
    Sagittarius: "Jupiter", Capricorn: "Saturn", Aquarius: "Saturn", Pisces: "Jupiter",
};

// ─── EXALTATION SIGNS ────────────────────────────────────────────────────
export const EXALTATION = {
    Sun: "Aries", Moon: "Taurus", Mars: "Capricorn", Mercury: "Virgo",
    Jupiter: "Cancer", Venus: "Pisces", Saturn: "Libra",
    Rahu: "Taurus", Ketu: "Scorpio", // Disputed but commonly used
};

// ─── DEBILITATION SIGNS ──────────────────────────────────────────────────
export const DEBILITATION = {
    Sun: "Libra", Moon: "Scorpio", Mars: "Cancer", Mercury: "Pisces",
    Jupiter: "Capricorn", Venus: "Virgo", Saturn: "Aries",
    Rahu: "Scorpio", Ketu: "Taurus",
};

// ─── MOOLATRIKONA SIGNS (stronger than own sign, weaker than exaltation)
export const MOOLATRIKONA = {
    Sun: "Leo", Moon: "Taurus", Mars: "Aries", Mercury: "Virgo",
    Jupiter: "Sagittarius", Venus: "Libra", Saturn: "Aquarius",
};

// ─── NATURAL FRIENDSHIPS (Naisargika Maitri) ─────────────────────────────
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
 * @param {string} planet
 * @param {string} sign
 * @returns {{ state: string, modifier: number, label: string }}
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

    // Check friendship with sign lord
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
 * Get retrograde modifier. Retrograde planets are stronger in mundane
 * (they're closer to Earth, appear brighter).
 * @param {boolean} isRetrograde
 * @returns {number} Modifier (1.0 or 1.2)
 */
export function getRetrogradeModifier(isRetrograde) {
    return isRetrograde ? 1.2 : 1.0;
}

/**
 * Get combustion modifier. Planet too close to Sun = weakened.
 * Classical distances vary; we use common values.
 * @param {string} planet
 * @param {number} sunDistance - degrees from Sun
 * @returns {number} Modifier
 */
export function getCombustionModifier(planet, sunDistance) {
    const thresholds = {
        Moon: 12, Mars: 17, Mercury: 14, Jupiter: 11, Venus: 10, Saturn: 15,
    };
    const threshold = thresholds[planet];
    if (!threshold) return 1.0; // Sun, Rahu, Ketu can't be combust
    if (sunDistance < threshold) return 0.6;
    return 1.0;
}

/**
 * Calculate combined strength modifier for a planet position.
 * @param {string} planet
 * @param {Object} position - { sign, isRetrograde, sunDistance, ... }
 * @returns {{ totalModifier: number, dignity: Object, details: string[] }}
 */
export function getStrengthModifier(planet, position) {
    const { sign, isRetrograde = false, sunDistance = 180 } = position;
    const details = [];

    const dignity = getDignity(planet, sign);
    details.push(dignity.label);
    let total = dignity.modifier;

    const retroMod = getRetrogradeModifier(isRetrograde);
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
 * Apply strength modifier to an array of effects.
 * Adjusts each effect's weight by the planet's modifier.
 * Also flips "pos" to "neg" (and vice versa) for debilitated planets.
 * @param {Object[]} effects
 * @param {number} modifier
 * @param {string} dignityState
 * @returns {Object[]}
 */
export function applyModifierToEffects(effects, modifier, dignityState) {
    return effects.map(e => {
        const adjusted = { ...e, originalWeight: e.weight, weight: Math.min(1.0, e.weight * modifier) };

        // Debilitated planets: positive effects become weaker, negative amplified
        if (dignityState === "debilitated") {
            if (e.dir === "pos") adjusted.weight = e.weight * 0.4;
            if (e.dir === "neg") adjusted.weight = Math.min(1.0, e.weight * 1.3);
        }
        // Exalted planets: positive effects amplified, negative softened
        if (dignityState === "exalted") {
            if (e.dir === "pos") adjusted.weight = Math.min(1.0, e.weight * 1.4);
            if (e.dir === "neg") adjusted.weight = e.weight * 0.6;
        }

        return adjusted;
    });
}
