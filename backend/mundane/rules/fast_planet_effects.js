/**
 * Fast Planet Sign Effects — Brihat Samhita Rules Engine
 *
 * Effects of Mars, Sun, Venus, Mercury, and Moon transiting through each sign.
 * These are TRIGGERS on the slow-planet themes (days to weeks).
 *
 * Sources:
 *   - Brihat Samhita Ch.9 (Mars), Ch.10 (Sun), Ch.11 (Venus), Ch.12 (Mercury)
 *   - Moon effects from panchanga tradition
 *
 * Transit durations (approximate):
 *   Mars:    ~2 months per sign (1.88 year cycle; longer when retrograde)
 *   Sun:     ~1 month per sign (1 year cycle)
 *   Venus:   ~1 month per sign (faster, but retrograde ~40 days)
 *   Mercury: ~2-3 weeks per sign (fastest, frequent retrogrades)
 *   Moon:    ~2.3 days per sign (daily trigger — handled by nakshatra layer)
 */

// ─── MARS IN SIGNS ───────────────────────────────────────────────────────
// BS Ch.9: Kuja/Mangala effects
// Mars = war, fire, aggression, surgery, engineering, police, accidents

export const MARS_EFFECTS = {
    Aries: [
        { domain: "military", dir: "pos", desc: "Mars in own sign — military strength, bold action succeeds", weight: 0.8 },
        { domain: "government", dir: "mix", desc: "Aggressive leadership, quick but forceful decisions", weight: 0.6 },
    ],
    Taurus: [
        { domain: "economy", dir: "neg", desc: "Aggressive economic moves, hostile takeovers, trade wars", weight: 0.7 },
        { domain: "agriculture", dir: "neg", desc: "Land disputes, fires in agricultural areas", weight: 0.6 },
    ],
    Gemini: [
        { domain: "media", dir: "neg", desc: "Aggressive rhetoric in media, propaganda, heated debates", weight: 0.7 },
        { domain: "transport", dir: "neg", desc: "Transport accidents, road rage incidents", weight: 0.6 },
    ],
    Cancer: [
        { domain: "public_mood", dir: "neg", desc: "Mars DEBILITATED — domestic violence rises, emotional aggression", weight: 0.8 },
        { domain: "real_estate", dir: "neg", desc: "Property disputes, arson, construction accidents", weight: 0.7 },
    ],
    Leo: [
        { domain: "government", dir: "mix", desc: "Authoritarian enforcement, police action, executive orders", weight: 0.7 },
        { domain: "entertainment", dir: "neg", desc: "Violence in public events, stadium incidents", weight: 0.5 },
    ],
    Virgo: [
        { domain: "military", dir: "mix", desc: "Military precision operations, surgical strikes", weight: 0.7 },
        { domain: "health", dir: "neg", desc: "Surgical complications, medical emergencies rise", weight: 0.7 },
    ],
    Libra: [
        { domain: "foreign_affairs", dir: "neg", desc: "Diplomatic conflicts escalate, war threats", weight: 0.8 },
        { domain: "judiciary", dir: "neg", desc: "Legal battles intensify, aggressive litigation", weight: 0.6 },
    ],
    Scorpio: [
        { domain: "military", dir: "pos", desc: "Mars in own sign — military intelligence, covert operations succeed", weight: 0.8 },
        { domain: "crisis", dir: "neg", desc: "Hidden violence surfaces, underground explosions", weight: 0.7 },
    ],
    Sagittarius: [
        { domain: "religion", dir: "neg", desc: "Religious violence, militant extremism", weight: 0.7 },
        { domain: "foreign_affairs", dir: "neg", desc: "International military tensions, border clashes", weight: 0.7 },
    ],
    Capricorn: [
        { domain: "government", dir: "pos", desc: "Mars EXALTED — decisive governance, effective enforcement", weight: 0.8 },
        { domain: "infrastructure", dir: "pos", desc: "Major construction projects advance rapidly", weight: 0.7 },
    ],
    Aquarius: [
        { domain: "technology", dir: "neg", desc: "Cyberattacks, tech infrastructure targeted", weight: 0.7 },
        { domain: "social_movements", dir: "neg", desc: "Protests turn violent, revolution attempts", weight: 0.7 },
    ],
    Pisces: [
        { domain: "maritime", dir: "neg", desc: "Naval conflicts, maritime aggression, port fires", weight: 0.7 },
        { domain: "health", dir: "neg", desc: "Waterborne disease outbreaks, hospital crises", weight: 0.6 },
    ],
};

// ─── SUN IN SIGNS ────────────────────────────────────────────────────────
// BS Ch.10: Surya effects
//, authority, vitality, father, government, gold, health

export const SUN_EFFECTS = {
    Aries: [
        { domain: "government", dir: "pos", desc: "Sun EXALTED — ruler gains strength, new governmental year", weight: 0.8 },
        { domain: "public_mood", dir: "pos", desc: "National pride, collective confidence rises", weight: 0.7 },
    ],
    Taurus: [
        { domain: "economy", dir: "pos", desc: "Revenue collection strong, gold prices stable", weight: 0.6 },
        { domain: "agriculture", dir: "pos", desc: "Good growing season begins, crops thrive", weight: 0.6 },
    ],
    Gemini: [
        { domain: "media", dir: "pos", desc: "Government communications effective, key announcements", weight: 0.6 },
        { domain: "trade", dir: "pos", desc: "Trade policies clarified, commercial activity", weight: 0.5 },
    ],
    Cancer: [
        { domain: "public_mood", dir: "mix", desc: "Ruler focused on domestic issues, emotional leadership", weight: 0.6 },
        { domain: "real_estate", dir: "pos", desc: "Government housing initiatives, land reforms", weight: 0.5 },
    ],
    Leo: [
        { domain: "government", dir: "pos", desc: "Sun in own sign — ruler at peak authority, strong governance", weight: 0.8 },
        { domain: "diplomacy", dir: "pos", desc: "International prestige high, state visits succeed", weight: 0.7 },
    ],
    Virgo: [
        { domain: "health", dir: "pos", desc: "Government health initiatives, medical breakthroughs", weight: 0.6 },
        { domain: "labor", dir: "pos", desc: "Employment policies, worker welfare programs", weight: 0.5 },
    ],
    Libra: [
        { domain: "government", dir: "neg", desc: "Sun DEBILITATED — ruler weakened, loss of authority", weight: 0.8 },
        { domain: "foreign_affairs", dir: "neg", desc: "Diplomatic humiliation, unfavorable treaties", weight: 0.7 },
    ],
    Scorpio: [
        { domain: "crisis", dir: "mix", desc: "Government secrets revealed, power struggles intensify", weight: 0.7 },
        { domain: "taxation", dir: "pos", desc: "Tax reforms, government revenue initiatives", weight: 0.5 },
    ],
    Sagittarius: [
        { domain: "religion", dir: "pos", desc: "Government supports religious/educational institutions", weight: 0.6 },
        { domain: "judiciary", dir: "pos", desc: "Legal reforms, constitutional matters highlighted", weight: 0.6 },
    ],
    Capricorn: [
        { domain: "government", dir: "mix", desc: "Government restructuring, cold/austere leadership", weight: 0.7 },
        { domain: "economy", dir: "mix", desc: "Budget announcements, fiscal discipline", weight: 0.6 },
    ],
    Aquarius: [
        { domain: "technology", dir: "pos", desc: "Government tech initiatives, digital governance", weight: 0.6 },
        { domain: "social_movements", dir: "mix", desc: "Ruler engages with or opposes popular movements", weight: 0.5 },
    ],
    Pisces: [
        { domain: "government", dir: "neg", desc: "Ruler's authority dissolves, lack of direction", weight: 0.7 },
        { domain: "humanitarian", dir: "pos", desc: "Compassionate policies, foreign aid", weight: 0.6 },
    ],
};

// ─── VENUS IN SIGNS ──────────────────────────────────────────────────────
// BS Ch.11: Shukra effects
// Venus = arts, women, luxury, diplomacy, agriculture, rain, beauty

export const VENUS_EFFECTS = {
    Aries: [
        { domain: "diplomacy", dir: "neg", desc: "Diplomatic impatience, beauty industry disrupted", weight: 0.5 },
        { domain: "culture", dir: "mix", desc: "Bold new art forms, controversial expression", weight: 0.5 },
    ],
    Taurus: [
        { domain: "economy", dir: "pos", desc: "Venus in own sign — luxury markets thrive, currency stable", weight: 0.7 },
        { domain: "agriculture", dir: "pos", desc: "Good rainfall, crops prosper", weight: 0.7 },
    ],
    Gemini: [
        { domain: "trade", dir: "pos", desc: "Trade flourishes, commercial partnerships", weight: 0.6 },
        { domain: "media", dir: "pos", desc: "Arts and media celebration, literary festivals", weight: 0.5 },
    ],
    Cancer: [
        { domain: "public_mood", dir: "pos", desc: "Domestic comfort, marriage celebrations, emotional harmony", weight: 0.6 },
        { domain: "agriculture", dir: "pos", desc: "Water resources abundant, good for crops", weight: 0.6 },
    ],
    Leo: [
        { domain: "entertainment", dir: "pos", desc: "Entertainment industry booms, celebrity culture", weight: 0.6 },
        { domain: "diplomacy", dir: "pos", desc: "Royal/state celebrations, cultural diplomacy", weight: 0.6 },
    ],
    Virgo: [
        { domain: "health", dir: "mix", desc: "Venus DEBILITATED — beauty/health industry struggles", weight: 0.6 },
        { domain: "economy", dir: "neg", desc: "Luxury markets decline, austerity in consumption", weight: 0.6 },
    ],
    Libra: [
        { domain: "foreign_affairs", dir: "pos", desc: "Venus in own sign — peace treaties, diplomatic breakthroughs", weight: 0.8 },
        { domain: "culture", dir: "pos", desc: "Arts renaissance, beauty celebrated", weight: 0.7 },
    ],
    Scorpio: [
        { domain: "crisis", dir: "neg", desc: "Scandals involving women/luxury, sexual misconduct exposed", weight: 0.7 },
        { domain: "economy", dir: "neg", desc: "Hidden financial losses in luxury/entertainment sectors", weight: 0.5 },
    ],
    Sagittarius: [
        { domain: "religion", dir: "pos", desc: "Art in service of faith, religious celebrations", weight: 0.5 },
        { domain: "foreign_affairs", dir: "pos", desc: "Cultural exchange programs, international arts", weight: 0.6 },
    ],
    Capricorn: [
        { domain: "economy", dir: "mix", desc: "Luxury meets austerity, practical beauty", weight: 0.5 },
        { domain: "culture", dir: "mix", desc: "Traditional arts revived, classical over modern", weight: 0.5 },
    ],
    Aquarius: [
        { domain: "technology", dir: "pos", desc: "Tech-art convergence, digital beauty, AI art", weight: 0.6 },
        { domain: "social_movements", dir: "pos", desc: "Women's movements gain momentum", weight: 0.6 },
    ],
    Pisces: [
        { domain: "culture", dir: "pos", desc: "Venus EXALTED — artistic golden age, music/cinema peak", weight: 0.8 },
        { domain: "humanitarian", dir: "pos", desc: "Compassionate giving, charity galas succeed", weight: 0.7 },
    ],
};

// ─── MERCURY IN SIGNS ────────────────────────────────────────────────────
// BS Ch.12: Budha effects
// Mercury = trade, communication, intellect, writing, youth, calculation

export const MERCURY_EFFECTS = {
    Aries: [
        { domain: "media", dir: "mix", desc: "Quick but reckless communications, hasty announcements", weight: 0.5 },
        { domain: "trade", dir: "mix", desc: "Fast-moving deals, impulsive trade agreements", weight: 0.5 },
    ],
    Taurus: [
        { domain: "economy", dir: "pos", desc: "Sound financial communications, steady trade", weight: 0.6 },
        { domain: "trade", dir: "pos", desc: "Agricultural trade prospers, commodity markets stable", weight: 0.5 },
    ],
    Gemini: [
        { domain: "media", dir: "pos", desc: "Mercury in own sign — communication excellence, journalism thrives", weight: 0.7 },
        { domain: "trade", dir: "pos", desc: "Commercial innovation, new trade routes", weight: 0.7 },
    ],
    Cancer: [
        { domain: "media", dir: "mix", desc: "Emotional communication, populist rhetoric", weight: 0.5 },
        { domain: "education", dir: "mix", desc: "Education reforms debated, childhood focus", weight: 0.5 },
    ],
    Leo: [
        { domain: "government", dir: "pos", desc: "Government communications strong, royal proclamations", weight: 0.6 },
        { domain: "media", dir: "pos", desc: "Official media effective, state messaging works", weight: 0.5 },
    ],
    Virgo: [
        { domain: "trade", dir: "pos", desc: "Mercury EXALTED — commerce peaks, analytical precision", weight: 0.8 },
        { domain: "health", dir: "pos", desc: "Medical research breakthroughs, diagnostic advances", weight: 0.7 },
        { domain: "education", dir: "pos", desc: "Educational excellence, scholarship", weight: 0.6 },
    ],
    Libra: [
        { domain: "trade", dir: "pos", desc: "Trade diplomacy, commercial treaties", weight: 0.6 },
        { domain: "judiciary", dir: "pos", desc: "Legal communications clear, contracts honored", weight: 0.5 },
    ],
    Scorpio: [
        { domain: "media", dir: "neg", desc: "Investigative journalism exposes secrets, whistleblowers", weight: 0.6 },
        { domain: "crisis", dir: "mix", desc: "Intelligence communications, spy revelations", weight: 0.5 },
    ],
    Sagittarius: [
        { domain: "education", dir: "mix", desc: "Philosophical debate, academic disagreements", weight: 0.5 },
        { domain: "religion", dir: "mix", desc: "Religious texts reinterpreted, scriptural debates", weight: 0.5 },
    ],
    Capricorn: [
        { domain: "government", dir: "pos", desc: "Precise government communications, policy details", weight: 0.6 },
        { domain: "trade", dir: "mix", desc: "Trade regulated, commercial restrictions", weight: 0.5 },
    ],
    Aquarius: [
        { domain: "technology", dir: "pos", desc: "Tech innovation, software breakthroughs, AI advances", weight: 0.7 },
        { domain: "media", dir: "pos", desc: "Digital media innovation, new platforms", weight: 0.6 },
    ],
    Pisces: [
        { domain: "media", dir: "neg", desc: "Mercury DEBILITATED — misinformation, confused messaging", weight: 0.8 },
        { domain: "trade", dir: "neg", desc: "Trade deals fall through, commercial deception", weight: 0.7 },
        { domain: "education", dir: "neg", desc: "Educational standards decline, examination scandals", weight: 0.6 },
    ],
};

/**
 * Get all fast-planet effects for current positions.
 * Moon is not included here — handled by nakshatra layer.
 * @param {Object} positions - { planet: { sign, ... } }
 * @returns {Object[]}
 */
export function getFastPlanetEffects(positions) {
    const TABLES = {
        Mars: MARS_EFFECTS,
        Sun: SUN_EFFECTS,
        Venus: VENUS_EFFECTS,
        Mercury: MERCURY_EFFECTS,
    };
    const results = [];

    for (const [planet, table] of Object.entries(TABLES)) {
        const sign = positions[planet]?.sign;
        if (!sign || !table[sign]) continue;

        for (const effect of table[sign]) {
            results.push({
                planet,
                sign,
                ...effect,
                ruleId: `${planet.toLowerCase()}_in_${sign.toLowerCase()}`,
                source: "Brihat Samhita",
            });
        }
    }

    return results;
}
