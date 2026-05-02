/**
 * नक्षत्र फल — Nakshatra Phala (Star Transit Effects)
 *
 * When Saturn transits Pisces (2.5 years), it passes through 3 nakshatras:
 *   Purva Bhadrapada (Jupiter's nak) → institutional crisis
 *   Uttara Bhadrapada (Saturn's own nak) → deep structural change
 *   Revati (Mercury's nak) → communication/trade disruption
 *
 * Each nakshatra transit ~1 year for Saturn, ~5 months for Jupiter.
 * THIS is the natural "dasha" — timing encoded in the sky's movement.
 *
 * We only track slow planets (Saturn, Jupiter, Rahu, Ketu) because
 * their nakshatra transits create measurable themes. Fast planets
 * move through nakshatras too quickly for mundane significance.
 *
 * Sources: Brihat Samhita (implied), Phaladeepika, classical nakshatra
 * lordship system (Vimshottari order).
 *
 * REUSES: getNakshatra() from lib/vedic_utils.js
 *         getNakshatraMundane() for base descriptions
 */

import { getNakshatra, getNakshatraMundane } from "../../lib/vedic_utils.js";

/**
 * Nakshatra lords in Vimshottari order and their mundane significations.
 * The lord of the nakshatra COLORS the planet's expression.
 *
 * Saturn in a Saturn-lorded nakshatra = pure Saturnine effect (amplified)
 * Saturn in a Jupiter-lorded nakshatra = Saturn's restriction meets
 *   Jupiter's expansion = institutional reform
 */
const LORD_MODIFIERS = {
    Ketu:    { theme: "sudden endings, spiritual crisis, past karma surfacing", intensityMod: 1.1 },
    Venus:   { theme: "arts/luxury affected, women's issues, diplomatic tone", intensityMod: 1.0 },
    Sun:     { theme: "authority/leadership focus, government action", intensityMod: 1.1 },
    Moon:    { theme: "public emotion, masses, food/water/homeland", intensityMod: 1.0 },
    Mars:    { theme: "military trigger, violence, accidents, engineering", intensityMod: 1.2 },
    Rahu:    { theme: "deception, foreign influence, technology, obsession", intensityMod: 1.2 },
    Jupiter: { theme: "institutional, religious, legal, educational", intensityMod: 1.0 },
    Saturn:  { theme: "structural, chronic, labor, austerity, endurance", intensityMod: 1.1 },
    Mercury: { theme: "communication, trade, media, intellectual, youth", intensityMod: 1.0 },
};

/**
 * Specific mundane effects for slow planets in specific nakshatras.
 * Only the most significant combinations. For others, we compose
 * from planet-sign effect + lord modifier + base nakshatra meaning.
 *
 * Format: { "Planet:NakshatraName": effects[] }
 */
const SPECIFIC_NAKSHATRA_EFFECTS = {
    // ── Saturn in specific nakshatras ─────────────────────────────────
    "Saturn:Purva Bhadrapada": [
        { domain: "crisis", dir: "neg", desc: "Scorching transformation — institutions burn and rebuild", weight: 0.8 },
        { domain: "religion", dir: "neg", desc: "Religious institutions face ideological fire", weight: 0.7 },
    ],
    "Saturn:Uttara Bhadrapada": [
        { domain: "government", dir: "mix", desc: "Saturn in own nakshatra — deep structural reforms, endurance tested", weight: 0.9 },
        { domain: "economy", dir: "mix", desc: "Long-term economic restructuring, painful but lasting", weight: 0.8 },
    ],
    "Saturn:Revati": [
        { domain: "trade", dir: "neg", desc: "Trade routes disrupted, commercial journeys end badly", weight: 0.8 },
        { domain: "refugees", dir: "neg", desc: "Mass displacement, journey's end forced, compassion fatigue", weight: 0.7 },
    ],
    "Saturn:Pushya": [
        { domain: "government", dir: "pos", desc: "Saturn in own nakshatra — governance strengthened, nourishing order", weight: 0.8 },
        { domain: "agriculture", dir: "mix", desc: "Agricultural discipline, rationing, controlled distribution", weight: 0.7 },
    ],
    "Saturn:Anuradha": [
        { domain: "foreign_affairs", dir: "mix", desc: "Alliances tested under pressure, devoted partnerships survive", weight: 0.7 },
        { domain: "labor", dir: "neg", desc: "Organized labor unrest, unions vs corporations", weight: 0.7 },
    ],
    "Saturn:Shatabhisha": [
        { domain: "health", dir: "neg", desc: "Saturn in Rahu's nakshatra — mystery epidemics, isolated suffering", weight: 0.9 },
        { domain: "technology", dir: "mix", desc: "Technology restricts freedom, surveillance state tendencies", weight: 0.7 },
    ],

    // ── Jupiter in specific nakshatras ────────────────────────────────
    "Jupiter:Punarvasu": [
        { domain: "economy", dir: "pos", desc: "Jupiter in own nakshatra — renewal, return to prosperity", weight: 0.9 },
        { domain: "religion", dir: "pos", desc: "Spiritual renewal, religious harmony restored", weight: 0.8 },
    ],
    "Jupiter:Vishakha": [
        { domain: "government", dir: "pos", desc: "Jupiter in own nakshatra — triumphant leadership, goals achieved", weight: 0.8 },
        { domain: "foreign_affairs", dir: "pos", desc: "Diplomatic triumph, treaties that split old alliances", weight: 0.7 },
    ],
    "Jupiter:Pushya": [
        { domain: "public_mood", dir: "pos", desc: "Jupiter in Saturn's nakshatra — wisdom nurtures the masses", weight: 0.9 },
        { domain: "education", dir: "pos", desc: "Educational golden period, scholarship flourishes", weight: 0.8 },
    ],
    "Jupiter:Ardra": [
        { domain: "crisis", dir: "mix", desc: "Jupiter in Rahu's nakshatra — storms bring breakthroughs", weight: 0.7 },
        { domain: "research", dir: "pos", desc: "Scientific breakthroughs through destruction of old paradigms", weight: 0.7 },
    ],
    "Jupiter:Mula": [
        { domain: "religion", dir: "mix", desc: "Jupiter in Ketu's nakshatra — uprooting false beliefs, fundamentalism", weight: 0.8 },
        { domain: "crisis", dir: "neg", desc: "Fundamental structures destroyed to rebuild", weight: 0.7 },
    ],

    // ── Rahu in specific nakshatras ───────────────────────────────────
    "Rahu:Ardra": [
        { domain: "crisis", dir: "neg", desc: "Rahu in own nakshatra — maximum chaos, storms, catharsis", weight: 1.0 },
        { domain: "technology", dir: "mix", desc: "Technology revolution through destruction", weight: 0.8 },
    ],
    "Rahu:Shatabhisha": [
        { domain: "health", dir: "neg", desc: "Rahu in own nakshatra — mysterious mass illness, misdiagnosis", weight: 1.0 },
        { domain: "technology", dir: "pos", desc: "Healing technology breakthroughs, AI medicine", weight: 0.7 },
    ],
    "Rahu:Swati": [
        { domain: "trade", dir: "mix", desc: "Rahu in own nakshatra — trade winds shift, unconventional commerce", weight: 0.9 },
        { domain: "diplomacy", dir: "neg", desc: "Diplomatic deception, flexible alliances, betrayal", weight: 0.8 },
    ],
    "Rahu:Ashlesha": [
        { domain: "crisis", dir: "neg", desc: "Serpentine deception amplified — poison, manipulation, entrapment", weight: 0.9 },
        { domain: "media", dir: "neg", desc: "Media manipulation at peak, propaganda warfare", weight: 0.8 },
    ],

    // ── Ketu in specific nakshatras ───────────────────────────────────
    "Ketu:Ashwini": [
        { domain: "health", dir: "pos", desc: "Ketu in own nakshatra — healing breakthroughs, swift spiritual awakening", weight: 0.8 },
        { domain: "transport", dir: "neg", desc: "Transportation sudden failures, but also innovations", weight: 0.6 },
    ],
    "Ketu:Magha": [
        { domain: "government", dir: "neg", desc: "Ketu in own nakshatra — authority figures fall, ancestral reckoning", weight: 0.9 },
        { domain: "public_mood", dir: "mix", desc: "Past glory nostalgia, identity through ancestry", weight: 0.7 },
    ],
    "Ketu:Mula": [
        { domain: "crisis", dir: "neg", desc: "Ketu in own nakshatra — maximum uprooting, fundamental destruction", weight: 1.0 },
        { domain: "religion", dir: "mix", desc: "Spiritual liberation through loss, forced renunciation", weight: 0.8 },
    ],
};

/**
 * Get nakshatra sub-theme effects for a slow planet.
 *
 * Strategy:
 * 1. Check for specific hardcoded effects (most significant combos)
 * 2. If none, compose from: lord modifier + base nakshatra meaning
 *
 * @param {string} planet - Saturn/Jupiter/Rahu/Ketu
 * @param {number} longitude - sidereal longitude
 * @returns {Object} { nakshatra, lord, effects[], theme, composedDesc }
 */
export function getNakshatraSubTheme(planet, longitude) {
    const nak = getNakshatra(longitude);
    const lordMod = LORD_MODIFIERS[nak.lord] || { theme: "", intensityMod: 1.0 };
    const baseMundane = getNakshatraMundane(nak.name);
    const specificKey = `${planet}:${nak.name}`;
    const specific = SPECIFIC_NAKSHATRA_EFFECTS[specificKey];

    // Compose a description if no specific entry
    const composedDesc = `${planet} in ${nak.name} (${nak.lord}'s nakshatra, pada ${nak.pada}): `
        + `${baseMundane}. Lord theme: ${lordMod.theme}`;

    return {
        planet,
        nakshatra: nak.name,
        nakshatraIndex: nak.index,
        pada: nak.pada,
        lord: nak.lord,
        lordTheme: lordMod.theme,
        intensityMod: lordMod.intensityMod,
        baseMundane,
        effects: specific || [],
        hasSpecificEffects: !!specific,
        composedDesc,
        ruleId: `${planet.toLowerCase()}_in_nak_${nak.name.toLowerCase().replace(/\s+/g, "_")}`,
    };
}

/**
 * Get all slow-planet nakshatra sub-themes from positions.
 *
 * @param {Object} positions - { planet: { longitude, sign, ... } }
 * @returns {Object[]} Array of sub-theme objects
 */
export function getSlowPlanetNakshatraThemes(positions) {
    const SLOW = ["Saturn", "Jupiter", "Rahu", "Ketu"];
    const themes = [];

    for (const planet of SLOW) {
        const pos = positions[planet];
        if (!pos?.longitude) continue;
        themes.push(getNakshatraSubTheme(planet, pos.longitude));
    }

    return themes;
}

/**
 * Format nakshatra themes as compact text for synthesis context.
 */
export function formatNakshatraContext(positions) {
    const themes = getSlowPlanetNakshatraThemes(positions);
    if (!themes.length) return "No slow-planet nakshatra themes.";

    return themes.map(t => {
        const specific = t.hasSpecificEffects
            ? t.effects.map(e => `  ${e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔"} ${e.desc}`).join("\n")
            : `  → ${t.composedDesc}`;
        return `${t.planet} in ${t.nakshatra} (pada ${t.pada}, lord: ${t.lord}):\n${specific}`;
    }).join("\n\n");
}
