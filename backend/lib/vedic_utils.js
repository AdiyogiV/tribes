/**
 * Vedic Utilities — Panchanga & Nakshatra Calculator
 *
 * Pure math. No LLM. No network. No cost.
 *
 * All longitudes are sidereal (Lahiri ayanamsha already applied).
 *
 * Provides:
 *   getNakshatra(longitude)   → { index, name, pada, lord }
 *   getTithi(sunLon, moonLon) → { index, name, paksha }
 *   getPanchanga(positions)   → { tithi, nakshatra, yoga, karana, vara }
 */

// =============================================================================
// 27 NAKSHATRAS — each spans 13°20' (13.3333°)
// =============================================================================

const NAKSHATRAS = [
    { name: "Ashwini",       lord: "Ketu" },
    { name: "Bharani",       lord: "Venus" },
    { name: "Krittika",      lord: "Sun" },
    { name: "Rohini",        lord: "Moon" },
    { name: "Mrigashira",    lord: "Mars" },
    { name: "Ardra",         lord: "Rahu" },
    { name: "Punarvasu",     lord: "Jupiter" },
    { name: "Pushya",        lord: "Saturn" },
    { name: "Ashlesha",      lord: "Mercury" },
    { name: "Magha",         lord: "Ketu" },
    { name: "Purva Phalguni", lord: "Venus" },
    { name: "Uttara Phalguni", lord: "Sun" },
    { name: "Hasta",         lord: "Moon" },
    { name: "Chitra",        lord: "Mars" },
    { name: "Swati",         lord: "Rahu" },
    { name: "Vishakha",      lord: "Jupiter" },
    { name: "Anuradha",      lord: "Saturn" },
    { name: "Jyeshtha",      lord: "Mercury" },
    { name: "Mula",          lord: "Ketu" },
    { name: "Purva Ashadha", lord: "Venus" },
    { name: "Uttara Ashadha", lord: "Sun" },
    { name: "Shravana",      lord: "Moon" },
    { name: "Dhanishta",     lord: "Mars" },
    { name: "Shatabhisha",   lord: "Rahu" },
    { name: "Purva Bhadrapada", lord: "Jupiter" },
    { name: "Uttara Bhadrapada", lord: "Saturn" },
    { name: "Revati",        lord: "Mercury" },
];

// =============================================================================
// 30 TITHIS — each spans 12° of Moon-Sun separation
// =============================================================================

const TITHI_NAMES = [
    // Shukla Paksha (waxing, 1-15)
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima",
    // Krishna Paksha (waning, 16-30)
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Amavasya",
];

// =============================================================================
// 27 YOGAS — Sun + Moon longitude sum, each spans 13°20'
// =============================================================================

const YOGA_NAMES = [
    "Vishkumbha", "Priti", "Ayushman", "Saubhagya", "Shobhana",
    "Atiganda", "Sukarma", "Dhriti", "Shula", "Ganda",
    "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra",
    "Siddhi", "Vyatipata", "Variyan", "Parigha", "Shiva",
    "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma",
    "Indra", "Vaidhriti",
];

// =============================================================================
// NAKSHATRA CALCULATION
// =============================================================================

/**
 * Get the nakshatra for a given sidereal longitude.
 *
 * @param {number} longitude - sidereal longitude (0-360)
 * @returns {{ index: number, name: string, pada: number, lord: string, degree: number }}
 */
export function getNakshatra(longitude) {
    const lon = ((longitude % 360) + 360) % 360;
    const nakshatraSpan = 360 / 27; // 13.3333°
    const index = Math.floor(lon / nakshatraSpan);
    const posInNak = lon - index * nakshatraSpan;
    const pada = Math.floor(posInNak / (nakshatraSpan / 4)) + 1; // 1-4
    const nak = NAKSHATRAS[index];

    return {
        index: index + 1, // 1-based
        name: nak.name,
        pada,
        lord: nak.lord,
        degree: +(posInNak).toFixed(2),
    };
}

// =============================================================================
// TITHI (Lunar Day) CALCULATION
// =============================================================================

/**
 * Calculate tithi from Sun and Moon longitudes.
 * Tithi = (Moon - Sun) / 12, each tithi spans 12°.
 *
 * @param {number} sunLon - Sun's sidereal longitude
 * @param {number} moonLon - Moon's sidereal longitude
 * @returns {{ index: number, name: string, paksha: string, percent: number }}
 */
export function getTithi(sunLon, moonLon) {
    let diff = ((moonLon - sunLon) % 360 + 360) % 360;
    const index = Math.floor(diff / 12); // 0-29
    const percent = +((diff % 12) / 12 * 100).toFixed(0);
    const paksha = index < 15 ? "Shukla" : "Krishna";

    return {
        index: index + 1, // 1-30
        name: TITHI_NAMES[index],
        paksha,
        percent, // how far into the tithi (0-100)
    };
}

// =============================================================================
// YOGA CALCULATION
// =============================================================================

/**
 * Calculate yoga from Sun and Moon longitudes.
 * Yoga = (Sun + Moon) / 13.333
 *
 * @param {number} sunLon
 * @param {number} moonLon
 * @returns {{ index: number, name: string }}
 */
export function getYoga(sunLon, moonLon) {
    const sum = ((sunLon + moonLon) % 360 + 360) % 360;
    const index = Math.floor(sum / (360 / 27));
    return {
        index: index + 1,
        name: YOGA_NAMES[index],
    };
}

// =============================================================================
// COMPLETE PANCHANGA
// =============================================================================

/**
 * Calculate Panchanga (five limbs) from planet positions.
 *
 * @param {Object} positions - { Sun: { longitude }, Moon: { longitude }, ... }
 * @param {string} dateStr - "YYYY-MM-DD"
 * @returns {Object} Complete Panchanga data
 */
export function getPanchanga(positions, dateStr) {
    const sun = positions.Sun;
    const moon = positions.Moon;

    if (!sun?.longitude == null || !moon?.longitude == null) {
        return null;
    }

    const sunLon = sun.longitude;
    const moonLon = moon.longitude;

    // Vara (weekday) — from the date
    const dayOfWeek = new Date(dateStr + "T12:00:00Z").getUTCDay();
    const VARA_NAMES = ["Ravivara", "Somavara", "Mangalavara", "Budhavara", "Guruvara", "Shukravara", "Shanivara"];
    const VARA_LORDS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

    const tithi = getTithi(sunLon, moonLon);
    const moonNakshatra = getNakshatra(moonLon);
    const yoga = getYoga(sunLon, moonLon);

    // Lunar phase description
    let lunarPhase;
    if (tithi.index === 15) lunarPhase = "Full Moon (Purnima)";
    else if (tithi.index === 30) lunarPhase = "New Moon (Amavasya)";
    else if (tithi.index < 15) lunarPhase = "Waxing (Shukla Paksha)";
    else lunarPhase = "Waning (Krishna Paksha)";

    return {
        date: dateStr,
        tithi,
        nakshatra: moonNakshatra,
        yoga,
        vara: {
            name: VARA_NAMES[dayOfWeek],
            lord: VARA_LORDS[dayOfWeek],
        },
        lunarPhase,
        // All planet nakshatras
        planetNakshatras: Object.fromEntries(
            Object.entries(positions)
                .filter(([, p]) => p?.longitude != null)
                .map(([name, p]) => [name, getNakshatra(p.longitude)])
        ),
    };
}

// =============================================================================
// MUNDANE NAKSHATRA SIGNIFICANCE
// =============================================================================

/**
 * Brief mundane significance of a nakshatra.
 * Used to inform predictions about the Moon's daily transit.
 */
const NAKSHATRA_MUNDANE = {
    "Ashwini":          "swift action, healing, new beginnings, transportation",
    "Bharani":          "restraint, transformation, moral crisis, endings before beginnings",
    "Krittika":         "purification, fire, military action, cutting through deception",
    "Rohini":           "prosperity, agriculture, growth, beauty, commerce",
    "Mrigashira":       "search, exploration, desire, investigation, curiosity",
    "Ardra":            "storms, destruction, tears, breakthroughs, catharsis",
    "Punarvasu":        "restoration, return, recovery, second chances, renewal",
    "Pushya":           "nourishment, protection, spiritual growth, governance, care",
    "Ashlesha":         "deception, poison, serpentine energy, manipulation, cunning",
    "Magha":            "authority, ancestors, power, legacy, throne, ceremony",
    "Purva Phalguni":   "pleasure, luxury, creativity, marriage, alliances",
    "Uttara Phalguni":  "patronage, contracts, agreements, social bonds, responsibility",
    "Hasta":            "skill, craftsmanship, dexterity, trade, manufacturing",
    "Chitra":           "architecture, design, beauty, illusion, glamour",
    "Swati":            "independence, trade winds, diplomacy, flexibility, scattering",
    "Vishakha":         "ambition, triumph, splitting, forks in the road, transformation",
    "Anuradha":         "friendship, alliances, devotion, international bonds, organization",
    "Jyeshtha":         "protection, elder authority, crisis management, defense",
    "Mula":             "uprooting, destruction of the old, fundamental change, investigation",
    "Purva Ashadha":    "invincibility, water, purification, declaration, confrontation",
    "Uttara Ashadha":   "final victory, leadership, unchallengeable, universal law",
    "Shravana":         "listening, learning, media, propaganda, communication, hearing",
    "Dhanishta":        "wealth, music, abundance, collective achievement",
    "Shatabhisha":      "healing, secrecy, hundred physicians, technology, isolation",
    "Purva Bhadrapada": "scorching, intensity, fire, idealism, transformation",
    "Uttara Bhadrapada":"depth, wisdom, stability, endurance, hidden knowledge",
    "Revati":           "completion, journey's end, nourishment, safe passage, compassion",
};

/**
 * Get mundane significance for a nakshatra name.
 */
export function getNakshatraMundane(name) {
    return NAKSHATRA_MUNDANE[name] || "";
}
