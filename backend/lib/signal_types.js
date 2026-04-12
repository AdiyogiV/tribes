/**
 * Signal Types & Domain Mappings for Cosmic Intelligence Agent
 *
 * Defines what signals we extract from the sky and what domains they affect.
 * Pure constants — no LLM, no cost.
 */

// =============================================================================
// SIGNAL TYPE ENUM
// =============================================================================

export const SIGNAL_TYPE = {
    ASPECT: "aspect",
    INGRESS: "ingress",
    STATION: "station",         // retrograde/direct station
    DIGNITY: "dignity",         // planet enters exaltation/debilitation/own sign
    SPEED: "speed",             // planet unusually slow or fast
    ECLIPSE: "eclipse",         // Sun/Moon near Rahu-Ketu axis
    COMBUSTION: "combustion",   // planet too close to Sun
};

// =============================================================================
// SIGNAL STATUS
// =============================================================================

export const SIGNAL_STATUS = {
    FORMING: "forming",     // orb tightening, not yet peak
    ACTIVE: "active",       // near peak (within 1° for aspects)
    PEAKED: "peaked",       // exact, starting to separate
    FADING: "fading",       // separating but still within orb
    ENDED: "ended",         // outside orb
};

// =============================================================================
// ASPECT TYPES
// =============================================================================

export const ASPECT_TYPE = {
    CONJUNCTION: "conjunction",   // 0°
    SEXTILE: "sextile",         // 60°
    SQUARE: "square",           // 90°
    TRINE: "trine",             // 120°
    OPPOSITION: "opposition",    // 180°
};

export const ASPECT_ANGLES = {
    [ASPECT_TYPE.CONJUNCTION]: 0,
    [ASPECT_TYPE.SEXTILE]: 60,
    [ASPECT_TYPE.SQUARE]: 90,
    [ASPECT_TYPE.TRINE]: 120,
    [ASPECT_TYPE.OPPOSITION]: 180,
};

// =============================================================================
// ORBS — how far from exact an aspect can be and still count
// =============================================================================

/**
 * Orbs by aspect type. Tighter orb = stronger signal.
 * Luminaries (Sun/Moon) get wider orbs. Outer planets get tighter.
 */
export const DEFAULT_ORBS = {
    [ASPECT_TYPE.CONJUNCTION]: 10,
    [ASPECT_TYPE.OPPOSITION]: 8,
    [ASPECT_TYPE.TRINE]: 8,
    [ASPECT_TYPE.SQUARE]: 7,
    [ASPECT_TYPE.SEXTILE]: 6,
};

// Luminary bonus orb (added when Sun or Moon is involved)
export const LUMINARY_ORB_BONUS = 2;

// =============================================================================
// PLANET WEIGHTS — slow/outer planets carry more predictive weight
// =============================================================================

export const PLANET_WEIGHT = {
    Sun: 5,
    Moon: 3,        // fast, lots of aspects daily — lower weight per aspect
    Mars: 6,
    Mercury: 4,
    Jupiter: 8,
    Venus: 5,
    Saturn: 9,      // slowest visible planet, strongest mundane impact
    Rahu: 7,        // shadow planet, karmic significance
    Ketu: 7,
};

/** The nine Vedic planets (Navagraha). No outer planets. */
export const NAVAGRAHA = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];

// =============================================================================
// VEDIC SPECIAL ASPECTS — house-based aspects unique to Vedic astrology
// Mars: 4th & 8th, Jupiter: 5th & 9th, Saturn: 3rd & 10th
// =============================================================================

export const VEDIC_SPECIAL_ASPECTS = {
    Mars: [4, 8],       // 90° and 210° (approximately)
    Jupiter: [5, 9],    // 120° and 240°
    Saturn: [3, 10],    // 60° and 270°
    Rahu: [5, 9],       // aspects like Jupiter
    Ketu: [5, 9],       // aspects like Jupiter
};

// =============================================================================
// DOMAIN MAPPINGS — what each planet/aspect pattern signifies in the world
// =============================================================================

/**
 * Each planet's mundane significations (what it rules in the world).
 * Used to tag signals with affected domains for prediction.
 */
export const PLANET_DOMAINS = {
    Sun: ["government", "authority", "leadership", "health", "vitality", "father"],
    Moon: ["public", "emotions", "women", "food", "water", "travel", "mother"],
    Mars: ["conflict", "military", "energy", "accidents", "surgery", "fire", "sports"],
    Mercury: ["communication", "trade", "media", "technology", "education", "youth"],
    Jupiter: ["law", "religion", "finance", "expansion", "wisdom", "teaching", "children"],
    Venus: ["arts", "diplomacy", "relationships", "luxury", "women", "entertainment", "beauty"],
    Saturn: ["restriction", "labor", "agriculture", "mining", "elderly", "disease", "delays"],
    Rahu: ["disruption", "technology", "foreign", "unconventional", "obsession", "illusion"],
    Ketu: ["spirituality", "detachment", "epidemics", "sudden-events", "loss", "liberation"],
    Uranus: ["revolution", "innovation", "electricity", "earthquakes", "sudden-change"],
    Neptune: ["oil", "ocean", "drugs", "deception", "spirituality", "dissolution"],
    Pluto: ["power", "transformation", "nuclear", "underground", "mass-events"],
};

/**
 * Aspect-type significations (what the geometric relationship implies)
 */
export const ASPECT_DOMAINS = {
    [ASPECT_TYPE.CONJUNCTION]: ["intensity", "merger", "new-cycle"],
    [ASPECT_TYPE.OPPOSITION]: ["tension", "awareness", "polarization"],
    [ASPECT_TYPE.TRINE]: ["harmony", "flow", "opportunity"],
    [ASPECT_TYPE.SQUARE]: ["friction", "action", "crisis"],
    [ASPECT_TYPE.SEXTILE]: ["cooperation", "opportunity", "growth"],
};

// =============================================================================
// DIGNITY DEFINITIONS — reused from vedic_analysis.js, kept here for isolation
// =============================================================================

export const EXALTATION = {
    Sun: { sign: "Aries", degree: 10 },
    Moon: { sign: "Taurus", degree: 3 },
    Mars: { sign: "Capricorn", degree: 28 },
    Mercury: { sign: "Virgo", degree: 15 },
    Jupiter: { sign: "Cancer", degree: 5 },
    Venus: { sign: "Pisces", degree: 27 },
    Saturn: { sign: "Libra", degree: 20 },
    Rahu: { sign: "Taurus", degree: 20 },
    Ketu: { sign: "Scorpio", degree: 20 },
};

export const DEBILITATION = {
    Sun: { sign: "Libra", degree: 10 },
    Moon: { sign: "Scorpio", degree: 3 },
    Mars: { sign: "Cancer", degree: 28 },
    Mercury: { sign: "Pisces", degree: 15 },
    Jupiter: { sign: "Capricorn", degree: 5 },
    Venus: { sign: "Virgo", degree: 27 },
    Saturn: { sign: "Aries", degree: 20 },
    Rahu: { sign: "Scorpio", degree: 20 },
    Ketu: { sign: "Taurus", degree: 20 },
};

export const MOOL_TRIKONA = {
    Sun: { sign: "Leo", from: 0, to: 20 },
    Moon: { sign: "Taurus", from: 3, to: 30 },
    Mars: { sign: "Aries", from: 0, to: 12 },
    Mercury: { sign: "Virgo", from: 15, to: 20 },
    Jupiter: { sign: "Sagittarius", from: 0, to: 10 },
    Venus: { sign: "Libra", from: 0, to: 15 },
    Saturn: { sign: "Aquarius", from: 0, to: 20 },
};

export const PLANET_RULERSHIP = {
    Sun: ["Leo"],
    Moon: ["Cancer"],
    Mars: ["Aries", "Scorpio"],
    Mercury: ["Gemini", "Virgo"],
    Jupiter: ["Sagittarius", "Pisces"],
    Venus: ["Taurus", "Libra"],
    Saturn: ["Capricorn", "Aquarius"],
    Rahu: ["Aquarius"],     // co-rules with Saturn (some traditions)
    Ketu: ["Scorpio"],      // co-rules with Mars (some traditions)
};

// =============================================================================
// COMBUSTION ORBS
// =============================================================================

export const COMBUSTION_ORBS = {
    Moon: 12,
    Mars: 17,
    Mercury: 14,
    Jupiter: 11,
    Venus: 10,
    Saturn: 15,
};

// Tighter orbs when retrograde
export const COMBUSTION_ORBS_RETRO = {
    Mercury: 12,
    Venus: 8,
};

// =============================================================================
// ECLIPSE PARAMETERS
// =============================================================================

/**
 * Eclipse orb — how close Sun/Moon must be to Rahu/Ketu axis.
 * Solar eclipse: Sun conjunct Rahu/Ketu within this orb
 * Lunar eclipse: Moon conjunct Rahu/Ketu within this orb (Full Moon near nodes)
 */
export const ECLIPSE_ORB = 18;  // degrees — traditional nodal orb for eclipse possibility

// =============================================================================
// INTENSITY CALCULATION HELPERS
// =============================================================================

/**
 * Calculate signal intensity (1-10) based on planet weights and orb tightness.
 *
 * Uses the MAX of planet weights (not average) so that heavy pairs
 * like Saturn-Jupiter don't get diluted. Adds a pair bonus when
 * BOTH planets are heavy (weight >= 7).
 *
 * @param {string[]} planets - planet names involved
 * @param {number} orb - degrees from exact (0 = exact)
 * @param {number} maxOrb - maximum orb for this aspect type
 * @param {Object} [opts] - options
 * @param {boolean} [opts.isVedic] - if true, cap intensity (vedic aspects are background, not acute)
 * @returns {number} 1-10 intensity
 */
export function calculateIntensity(planets, orb, maxOrb, opts = {}) {
    const weights = planets.map(p => PLANET_WEIGHT[p] || 5);
    const maxWeight = Math.max(...weights);
    const minWeight = Math.min(...weights);

    // Heavy pair bonus: both planets weight >= 7 (e.g., Saturn+Jupiter, Saturn+Rahu)
    const pairBonus = (weights.length >= 2 && minWeight >= 7) ? 1.5 : 0;

    // Base from heaviest planet + pair bonus
    const base = maxWeight + pairBonus;

    // Orb factor: exact = 1.0, at max orb = 0.15
    const orbFactor = maxOrb > 0 ? Math.max(0.15, 1 - (orb / maxOrb) * 0.85) : 1;

    // Scale to 1-10
    let raw = base * orbFactor;

    // Vedic aspects are always-on background conditions (whole-sign).
    // They're important but shouldn't outrank tight geometric aspects.
    // Cap at 6 so they provide context without drowning acute signals.
    if (opts.isVedic) {
        raw = Math.min(raw, 6);
    }

    return Math.round(Math.min(10, Math.max(1, raw)));
}

/**
 * Merge domains from multiple planets and an aspect type.
 * Returns deduplicated array.
 */
export function mergeDomains(planets, aspectType = null) {
    const domains = new Set();
    for (const planet of planets) {
        const pd = PLANET_DOMAINS[planet];
        if (pd) pd.forEach(d => domains.add(d));
    }
    if (aspectType && ASPECT_DOMAINS[aspectType]) {
        ASPECT_DOMAINS[aspectType].forEach(d => domains.add(d));
    }
    return [...domains];
}

/**
 * Generate a stable signal ID.
 * @param {string} type - signal type
 * @param {string[]} planets - sorted planet names
 * @param {string} [extra] - extra qualifier (aspect name, sign, etc.)
 * @returns {string} deterministic ID
 */
export function makeSignalId(type, planets, extra = "") {
    const sortedPlanets = [...planets].sort().join("-").toLowerCase();
    const suffix = extra ? `-${extra.toLowerCase().replace(/\s+/g, "-")}` : "";
    return `${type}:${sortedPlanets}${suffix}`;
}
