/**
 * Slow Planet Sign Effects — Brihat Samhita Rules Engine
 *
 * Effects of Saturn, Jupiter, Rahu, and Ketu transiting through each sign.
 * These set the MACRO themes (months to years).
 *
 * Sources:
 *   - Brihat Samhita Ch.5 (Saturn), Ch.8 (Jupiter)
 *   - Phaladeepika, Saravali (Rahu/Ketu — not in original BS)
 *   - B.V. Raman's commentaries for modern application
 *
 * Each effect has:
 *   domain   — mundane house/topic area
 *   dir      — "pos" (positive), "neg" (negative), "mix" (mixed)
 *   desc     — one-line description for LLM context
 *   weight   — base intensity 0.1-1.0 (modified by dignity/speed at runtime)
 *
 * Transit durations (approximate):
 *   Saturn:  ~2.5 years per sign (29.5 year cycle)
 *   Jupiter: ~1 year per sign (11.86 year cycle)
 *   Rahu:    ~1.5 years per sign (18.6 year cycle, retrograde motion)
 *   Ketu:    ~1.5 years per sign (always opposite Rahu)
 */

// ─── SATURN IN SIGNS ─────────────────────────────────────────────────────
// BS Ch.5: Shanaishchara-chara (Saturn's Transit)
// Saturn = government, masses, agriculture, mines, death, discipline, delay

export const SATURN_EFFECTS = {
    Aries: [
        { domain: "government", dir: "neg", desc: "Authority weakened, rulers face opposition", weight: 0.8 },
        { domain: "military", dir: "neg", desc: "Army morale low, defense overspending", weight: 0.7 },
        { domain: "public_mood", dir: "neg", desc: "General restlessness, impatience in populace", weight: 0.7 },
    ],
    Taurus: [
        { domain: "economy", dir: "neg", desc: "Agricultural losses, food prices rise", weight: 0.9 },
        { domain: "banking", dir: "neg", desc: "Banking sector stress, currency instability", weight: 0.8 },
        { domain: "resources", dir: "neg", desc: "Scarcity of essential goods, hoarding", weight: 0.7 },
    ],
    Gemini: [
        { domain: "media", dir: "neg", desc: "Press restrictions, communication breakdowns", weight: 0.7 },
        { domain: "trade", dir: "neg", desc: "Trade agreements stall, commerce disrupted", weight: 0.8 },
        { domain: "transport", dir: "neg", desc: "Transport infrastructure failures, delays", weight: 0.7 },
    ],
    Cancer: [
        { domain: "public_mood", dir: "neg", desc: "Mass discontent, emotional unrest in populace", weight: 0.9 },
        { domain: "agriculture", dir: "neg", desc: "Crops fail, water-related disasters", weight: 0.8 },
        { domain: "real_estate", dir: "neg", desc: "Property market declines, housing crisis", weight: 0.7 },
    ],
    Leo: [
        { domain: "government", dir: "neg", desc: "Head of state under pressure, loss of prestige", weight: 0.9 },
        { domain: "entertainment", dir: "neg", desc: "Entertainment industry suffers restrictions", weight: 0.6 },
        { domain: "diplomacy", dir: "neg", desc: "Diplomatic failures, loss of international standing", weight: 0.7 },
    ],
    Virgo: [
        { domain: "health", dir: "neg", desc: "Epidemics, chronic illness rises, healthcare strain", weight: 0.8 },
        { domain: "labor", dir: "neg", desc: "Labor unrest, workers' strikes, unemployment", weight: 0.8 },
        { domain: "military", dir: "neg", desc: "Military scandals, defense mismanagement", weight: 0.6 },
    ],
    Libra: [
        { domain: "foreign_affairs", dir: "mix", desc: "Saturn exalted — firm but fair diplomacy, treaties enforced", weight: 0.8 },
        { domain: "judiciary", dir: "pos", desc: "Justice system strengthened, landmark rulings", weight: 0.7 },
        { domain: "trade", dir: "pos", desc: "International trade stabilizes under strict rules", weight: 0.7 },
    ],
    Scorpio: [
        { domain: "crisis", dir: "neg", desc: "Hidden scandals surface, institutional corruption exposed", weight: 0.9 },
        { domain: "taxation", dir: "neg", desc: "Tax burdens increase, financial secrets revealed", weight: 0.8 },
        { domain: "mortality", dir: "neg", desc: "Death toll events, mining disasters, underground crises", weight: 0.7 },
    ],
    Sagittarius: [
        { domain: "religion", dir: "neg", desc: "Religious institutions face scandal, dogma challenged", weight: 0.8 },
        { domain: "judiciary", dir: "neg", desc: "Legal system delays, justice denied", weight: 0.7 },
        { domain: "education", dir: "neg", desc: "Higher education funding cut, universities struggle", weight: 0.7 },
    ],
    Capricorn: [
        { domain: "government", dir: "mix", desc: "Saturn in own sign — stern governance, structural reforms", weight: 0.9 },
        { domain: "economy", dir: "mix", desc: "Austerity measures, painful but necessary restructuring", weight: 0.8 },
        { domain: "infrastructure", dir: "pos", desc: "Major infrastructure projects, long-term building", weight: 0.7 },
    ],
    Aquarius: [
        { domain: "technology", dir: "mix", desc: "Saturn in own sign — tech regulation, digital restrictions", weight: 0.8 },
        { domain: "social_movements", dir: "pos", desc: "Mass movements gain structure, organized protest", weight: 0.8 },
        { domain: "humanitarian", dir: "mix", desc: "Humanitarian crises but also organized relief", weight: 0.7 },
    ],
    Pisces: [
        { domain: "maritime", dir: "neg", desc: "Maritime trade disrupted, naval incidents, coastal flooding", weight: 0.8 },
        { domain: "religion", dir: "neg", desc: "Spiritual institutions face crisis, false prophets", weight: 0.7 },
        { domain: "refugees", dir: "neg", desc: "Refugee crises, exile of leaders, foreign imprisonment", weight: 0.8 },
        { domain: "health", dir: "neg", desc: "Waterborne diseases, hospital system strain", weight: 0.7 },
    ],
};

// ─── JUPITER IN SIGNS ────────────────────────────────────────────────────
// BS Ch.8: Brihaspati-chara (Jupiter's Transit)
// Jupiter = wisdom, law, prosperity, religion, expansion, children, teachers

export const JUPITER_EFFECTS = {
    Aries: [
        { domain: "military", dir: "pos", desc: "Righteous military action, defense modernization", weight: 0.7 },
        { domain: "government", dir: "pos", desc: "Bold leadership initiatives, new policies launched", weight: 0.7 },
        { domain: "sports", dir: "pos", desc: "Athletic achievements, sports events succeed", weight: 0.5 },
    ],
    Taurus: [
        { domain: "economy", dir: "pos", desc: "Economic growth, agricultural abundance", weight: 0.8 },
        { domain: "banking", dir: "pos", desc: "Financial institutions prosper, investments grow", weight: 0.7 },
        { domain: "culture", dir: "pos", desc: "Arts flourish, cultural heritage celebrated", weight: 0.6 },
    ],
    Gemini: [
        { domain: "media", dir: "pos", desc: "Intellectual discourse flourishes, publishing thrives", weight: 0.7 },
        { domain: "trade", dir: "pos", desc: "Trade agreements expand, commerce grows", weight: 0.7 },
        { domain: "education", dir: "pos", desc: "Educational initiatives succeed, scholarship", weight: 0.6 },
    ],
    Cancer: [
        { domain: "public_mood", dir: "pos", desc: "Jupiter EXALTED — masses prosper, general happiness", weight: 1.0 },
        { domain: "agriculture", dir: "pos", desc: "Bountiful harvests, water resources abundant", weight: 0.9 },
        { domain: "real_estate", dir: "pos", desc: "Property values rise, housing prosperity", weight: 0.8 },
        { domain: "religion", dir: "pos", desc: "Religious harmony, spiritual revival", weight: 0.8 },
    ],
    Leo: [
        { domain: "government", dir: "pos", desc: "Wise leadership, ruler gains respect", weight: 0.8 },
        { domain: "diplomacy", dir: "pos", desc: "Successful diplomacy, international prestige", weight: 0.7 },
        { domain: "entertainment", dir: "pos", desc: "Creative arts boom, celebrations", weight: 0.6 },
    ],
    Virgo: [
        { domain: "health", dir: "mix", desc: "Healthcare improvements but also health scares", weight: 0.6 },
        { domain: "education", dir: "pos", desc: "Practical education reforms, skill development", weight: 0.7 },
        { domain: "labor", dir: "pos", desc: "Employment opportunities increase, service sector grows", weight: 0.6 },
    ],
    Libra: [
        { domain: "foreign_affairs", dir: "pos", desc: "Peace treaties, diplomatic breakthroughs", weight: 0.8 },
        { domain: "judiciary", dir: "pos", desc: "Justice served, fair legal outcomes", weight: 0.7 },
        { domain: "trade", dir: "pos", desc: "International partnerships flourish", weight: 0.7 },
    ],
    Scorpio: [
        { domain: "research", dir: "pos", desc: "Scientific breakthroughs, deep investigation yields results", weight: 0.7 },
        { domain: "crisis", dir: "mix", desc: "Crises resolved through wisdom, institutional reform", weight: 0.6 },
        { domain: "insurance", dir: "pos", desc: "Insurance/inheritance matters resolve favorably", weight: 0.5 },
    ],
    Sagittarius: [
        { domain: "religion", dir: "pos", desc: "Jupiter in own sign — religious revival, dharma upheld", weight: 0.9 },
        { domain: "judiciary", dir: "pos", desc: "Legal system functions well, landmark judgments", weight: 0.8 },
        { domain: "education", dir: "pos", desc: "Universities thrive, philosophical discourse", weight: 0.8 },
    ],
    Capricorn: [
        { domain: "government", dir: "neg", desc: "Jupiter DEBILITATED — governance lacks wisdom", weight: 0.8 },
        { domain: "religion", dir: "neg", desc: "Religious hypocrisy exposed, moral decline", weight: 0.7 },
        { domain: "judiciary", dir: "neg", desc: "Justice delayed or corrupted", weight: 0.7 },
    ],
    Aquarius: [
        { domain: "technology", dir: "pos", desc: "Technological wisdom applied for social good", weight: 0.7 },
        { domain: "humanitarian", dir: "pos", desc: "Humanitarian causes succeed, collective welfare", weight: 0.7 },
        { domain: "social_movements", dir: "pos", desc: "Progressive reforms gain traction", weight: 0.6 },
    ],
    Pisces: [
        { domain: "religion", dir: "pos", desc: "Jupiter in own sign — deep spirituality, compassion", weight: 0.9 },
        { domain: "maritime", dir: "pos", desc: "Maritime prosperity, ocean resources", weight: 0.7 },
        { domain: "humanitarian", dir: "pos", desc: "Charitable institutions thrive, empathy rises", weight: 0.8 },
    ],
};

// ─── RAHU IN SIGNS ───────────────────────────────────────────────────────
// Not in original BS. Based on Phaladeepika, Saravali, and B.V. Raman.
// Rahu = deception, foreign influence, technology, obsession, unconventional
// Rahu moves RETROGRADE — spends ~18 months per sign.

export const RAHU_EFFECTS = {
    Aries: [
        { domain: "military", dir: "neg", desc: "Unconventional warfare, terrorist threats, reckless aggression", weight: 0.8 },
        { domain: "public_mood", dir: "neg", desc: "Mass anger, mob mentality, identity confusion", weight: 0.7 },
    ],
    Taurus: [
        { domain: "economy", dir: "neg", desc: "Financial deception, Ponzi schemes, currency manipulation", weight: 0.8 },
        { domain: "agriculture", dir: "neg", desc: "Food contamination, GMO controversies", weight: 0.6 },
    ],
    Gemini: [
        { domain: "media", dir: "neg", desc: "Disinformation epidemic, deepfakes, media manipulation", weight: 0.9 },
        { domain: "technology", dir: "mix", desc: "Tech innovation but also cyber threats", weight: 0.7 },
    ],
    Cancer: [
        { domain: "public_mood", dir: "neg", desc: "Mass anxiety, paranoia, homeland security fears", weight: 0.8 },
        { domain: "real_estate", dir: "neg", desc: "Property fraud, housing bubbles", weight: 0.7 },
    ],
    Leo: [
        { domain: "government", dir: "neg", desc: "Power grabs, authoritarian tendencies, cult of personality", weight: 0.8 },
        { domain: "entertainment", dir: "mix", desc: "Entertainment obsession, celebrity scandals", weight: 0.6 },
    ],
    Virgo: [
        { domain: "health", dir: "neg", desc: "Mysterious illnesses, misdiagnosis, pharma scandals", weight: 0.8 },
        { domain: "labor", dir: "neg", desc: "Exploitation of workers, illegal labor practices", weight: 0.7 },
    ],
    Libra: [
        { domain: "foreign_affairs", dir: "neg", desc: "Deceptive diplomacy, broken treaties, espionage", weight: 0.8 },
        { domain: "judiciary", dir: "neg", desc: "Judicial corruption, false accusations", weight: 0.7 },
    ],
    Scorpio: [
        { domain: "crisis", dir: "neg", desc: "Rahu in co-ruled sign — deep conspiracies surface, power struggles", weight: 0.9 },
        { domain: "terrorism", dir: "neg", desc: "Underground threats, bioweapons, nuclear anxiety", weight: 0.8 },
    ],
    Sagittarius: [
        { domain: "religion", dir: "neg", desc: "Religious extremism, false gurus, cult activity", weight: 0.8 },
        { domain: "education", dir: "neg", desc: "Academic fraud, credential inflation", weight: 0.6 },
    ],
    Capricorn: [
        { domain: "government", dir: "neg", desc: "Institutional corruption, shadow governance", weight: 0.8 },
        { domain: "economy", dir: "neg", desc: "Economic manipulation by hidden actors", weight: 0.7 },
    ],
    Aquarius: [
        { domain: "technology", dir: "mix", desc: "Rahu in co-ruled sign — tech revolution AND tech chaos", weight: 0.9 },
        { domain: "social_movements", dir: "neg", desc: "Movements hijacked, revolutionary deception", weight: 0.7 },
        { domain: "public_mood", dir: "neg", desc: "Mass delusion, conspiracy theories go mainstream", weight: 0.8 },
    ],
    Pisces: [
        { domain: "religion", dir: "neg", desc: "Spiritual deception, false miracles, cult exploitation", weight: 0.8 },
        { domain: "refugees", dir: "neg", desc: "Human trafficking, refugee exploitation", weight: 0.7 },
        { domain: "maritime", dir: "neg", desc: "Maritime deception, smuggling, piracy", weight: 0.6 },
    ],
};

// ─── KETU IN SIGNS ───────────────────────────────────────────────────────
// Ketu = liberation, loss, spiritual insight, sudden events, past karma
// Always opposite Rahu. ~18 months per sign, retrograde.

export const KETU_EFFECTS = {
    Aries: [
        { domain: "military", dir: "mix", desc: "Sudden military events, unexpected heroism or defeat", weight: 0.7 },
        { domain: "public_mood", dir: "mix", desc: "Detachment from nationalism, identity questioning", weight: 0.6 },
    ],
    Taurus: [
        { domain: "economy", dir: "neg", desc: "Sudden financial losses, detachment from material security", weight: 0.7 },
        { domain: "agriculture", dir: "neg", desc: "Crop failures from unexpected causes", weight: 0.6 },
    ],
    Gemini: [
        { domain: "media", dir: "mix", desc: "Media outlets collapse or transform, old formats die", weight: 0.7 },
        { domain: "trade", dir: "neg", desc: "Trade routes suddenly disrupted", weight: 0.6 },
    ],
    Cancer: [
        { domain: "public_mood", dir: "neg", desc: "Emotional detachment, homeland nostalgia, displaced people", weight: 0.7 },
        { domain: "real_estate", dir: "neg", desc: "Property values drop suddenly", weight: 0.6 },
    ],
    Leo: [
        { domain: "government", dir: "neg", desc: "Sudden loss of leaders, abdication, power vacuum", weight: 0.8 },
        { domain: "entertainment", dir: "mix", desc: "Entertainment industry disruption, old stars fade", weight: 0.5 },
    ],
    Virgo: [
        { domain: "health", dir: "neg", desc: "Sudden health crises, diagnostic breakthroughs", weight: 0.7 },
        { domain: "labor", dir: "mix", desc: "Workers suddenly walk out, automation displaces labor", weight: 0.6 },
    ],
    Libra: [
        { domain: "foreign_affairs", dir: "neg", desc: "Alliances suddenly break, partnerships dissolve", weight: 0.7 },
        { domain: "judiciary", dir: "mix", desc: "Karmic justice — old cases resurface", weight: 0.6 },
    ],
    Scorpio: [
        { domain: "crisis", dir: "mix", desc: "Ketu co-rules Scorpio — deep transformation, spiritual awakening through crisis", weight: 0.8 },
        { domain: "mortality", dir: "neg", desc: "Sudden mass casualty events, natural disasters", weight: 0.7 },
    ],
    Sagittarius: [
        { domain: "religion", dir: "mix", desc: "Spiritual liberation, old religious orders dissolve", weight: 0.7 },
        { domain: "education", dir: "mix", desc: "Traditional education disrupted, alternative learning rises", weight: 0.6 },
    ],
    Capricorn: [
        { domain: "government", dir: "neg", desc: "Government structures suddenly fail or collapse", weight: 0.7 },
        { domain: "infrastructure", dir: "neg", desc: "Infrastructure failures, old buildings collapse", weight: 0.6 },
    ],
    Aquarius: [
        { domain: "technology", dir: "mix", desc: "Old technologies die suddenly, paradigm shifts", weight: 0.7 },
        { domain: "social_movements", dir: "mix", desc: "Movements lose steam or suddenly end", weight: 0.6 },
    ],
    Pisces: [
        { domain: "religion", dir: "pos", desc: "Ketu exalted — genuine spiritual awakening, mysticism", weight: 0.8 },
        { domain: "humanitarian", dir: "pos", desc: "Selfless service, detachment from material aid", weight: 0.7 },
    ],
};

/**
 * Get all slow-planet effects for current positions.
 * @param {Object} positions - { planet: { sign, ... } }
 * @returns {Object[]} Array of active effects with planet, sign, and effect data
 */
export function getSlowPlanetEffects(positions) {
    const TABLES = { Saturn: SATURN_EFFECTS, Jupiter: JUPITER_EFFECTS, Rahu: RAHU_EFFECTS, Ketu: KETU_EFFECTS };
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
                source: planet === "Rahu" || planet === "Ketu" ? "Phaladeepika/Saravali" : "Brihat Samhita",
            });
        }
    }

    return results;
}
