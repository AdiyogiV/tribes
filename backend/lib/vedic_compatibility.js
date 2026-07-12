/**
 * Vedic Compatibility Constants and Calculations
 *
 * This module provides:
 * 1. Universal Cosmic Match (Graha Maitri + Gana + Tara + Rashi) - Gender neutral
 * 2. Traditional Ashtakoot (8 kootas) - Uses gender when available
 */

import { normalizeDasha } from "./astro_helpers.js";

// =============================================================================
// NAKSHATRA DATA
// =============================================================================

// Canonical nakshatra names + spelling/index/degree helpers live in ONE place.
// Imported for internal use AND re-exported so existing importers
// (compatibility.js, scripts) keep working unchanged.
import {
    NAKSHATRAS,
    normalizeNakshatra,
    getNakshatraFromDegree,
} from "./nakshatras.js";
export { NAKSHATRAS, normalizeNakshatra, getNakshatraFromDegree };

/**
 * Yoni (Animal Symbol) for each Nakshatra - used for physical/instinctual compatibility
 * Each nakshatra has an animal symbol representing primal nature
 */
export const NAKSHATRA_YONI = {
    "Ashwini": { animal: "Horse", gender: "Male" },
    "Bharani": { animal: "Elephant", gender: "Male" },
    "Krittika": { animal: "Sheep", gender: "Female" },
    "Rohini": { animal: "Serpent", gender: "Male" },
    "Mrigashira": { animal: "Serpent", gender: "Female" },
    "Ardra": { animal: "Dog", gender: "Female" },
    "Punarvasu": { animal: "Cat", gender: "Female" },
    "Pushya": { animal: "Sheep", gender: "Male" },
    "Ashlesha": { animal: "Cat", gender: "Male" },
    "Magha": { animal: "Rat", gender: "Male" },
    "Purva Phalguni": { animal: "Rat", gender: "Female" },
    "Uttara Phalguni": { animal: "Cow", gender: "Male" },
    "Hasta": { animal: "Buffalo", gender: "Female" },
    "Chitra": { animal: "Tiger", gender: "Female" },
    "Swati": { animal: "Buffalo", gender: "Male" },
    "Vishakha": { animal: "Tiger", gender: "Male" },
    "Anuradha": { animal: "Deer", gender: "Female" },
    "Jyeshtha": { animal: "Deer", gender: "Male" },
    "Moola": { animal: "Dog", gender: "Male" },
    "Purva Ashadha": { animal: "Monkey", gender: "Male" },
    "Uttara Ashadha": { animal: "Mongoose", gender: "Male" },
    "Shravana": { animal: "Monkey", gender: "Female" },
    "Dhanishta": { animal: "Lion", gender: "Female" },
    "Shatabhisha": { animal: "Horse", gender: "Female" },
    "Purva Bhadrapada": { animal: "Lion", gender: "Male" },
    "Uttara Bhadrapada": { animal: "Cow", gender: "Female" },
    "Revati": { animal: "Elephant", gender: "Female" },
};

/**
 * Yoni compatibility matrix - defines natural attraction/repulsion between animals
 * 4 = Same animal (highly compatible), 3 = Friendly, 2 = Neutral, 1 = Enemies, 0 = Sworn enemies
 */
export const YONI_COMPATIBILITY = {
    "Horse": { "Horse": 4, "Elephant": 2, "Sheep": 2, "Serpent": 1, "Dog": 2, "Cat": 2, "Rat": 2, "Cow": 1, "Buffalo": 0, "Tiger": 2, "Deer": 3, "Monkey": 2, "Mongoose": 2, "Lion": 2 },
    "Elephant": { "Horse": 2, "Elephant": 4, "Sheep": 3, "Serpent": 2, "Dog": 2, "Cat": 2, "Rat": 2, "Cow": 2, "Buffalo": 3, "Tiger": 1, "Deer": 2, "Monkey": 2, "Mongoose": 2, "Lion": 0 },
    "Sheep": { "Horse": 2, "Elephant": 3, "Sheep": 4, "Serpent": 2, "Dog": 1, "Cat": 2, "Rat": 2, "Cow": 3, "Buffalo": 2, "Tiger": 1, "Deer": 2, "Monkey": 0, "Mongoose": 2, "Lion": 2 },
    "Serpent": { "Horse": 1, "Elephant": 2, "Sheep": 2, "Serpent": 4, "Dog": 2, "Cat": 1, "Rat": 2, "Cow": 2, "Buffalo": 2, "Tiger": 2, "Deer": 2, "Monkey": 2, "Mongoose": 0, "Lion": 2 },
    "Dog": { "Horse": 2, "Elephant": 2, "Sheep": 1, "Serpent": 2, "Dog": 4, "Cat": 2, "Rat": 2, "Cow": 2, "Buffalo": 2, "Tiger": 2, "Deer": 0, "Monkey": 2, "Mongoose": 2, "Lion": 2 },
    "Cat": { "Horse": 2, "Elephant": 2, "Sheep": 2, "Serpent": 1, "Dog": 2, "Cat": 4, "Rat": 0, "Cow": 2, "Buffalo": 2, "Tiger": 2, "Deer": 2, "Monkey": 2, "Mongoose": 2, "Lion": 2 },
    "Rat": { "Horse": 2, "Elephant": 2, "Sheep": 2, "Serpent": 2, "Dog": 2, "Cat": 0, "Rat": 4, "Cow": 2, "Buffalo": 2, "Tiger": 2, "Deer": 2, "Monkey": 3, "Mongoose": 2, "Lion": 2 },
    "Cow": { "Horse": 1, "Elephant": 2, "Sheep": 3, "Serpent": 2, "Dog": 2, "Cat": 2, "Rat": 2, "Cow": 4, "Buffalo": 3, "Tiger": 0, "Deer": 2, "Monkey": 2, "Mongoose": 2, "Lion": 2 },
    "Buffalo": { "Horse": 0, "Elephant": 3, "Sheep": 2, "Serpent": 2, "Dog": 2, "Cat": 2, "Rat": 2, "Cow": 3, "Buffalo": 4, "Tiger": 2, "Deer": 2, "Monkey": 2, "Mongoose": 2, "Lion": 2 },
    "Tiger": { "Horse": 2, "Elephant": 1, "Sheep": 1, "Serpent": 2, "Dog": 2, "Cat": 2, "Rat": 2, "Cow": 0, "Buffalo": 2, "Tiger": 4, "Deer": 1, "Monkey": 2, "Mongoose": 2, "Lion": 3 },
    "Deer": { "Horse": 3, "Elephant": 2, "Sheep": 2, "Serpent": 2, "Dog": 0, "Cat": 2, "Rat": 2, "Cow": 2, "Buffalo": 2, "Tiger": 1, "Deer": 4, "Monkey": 2, "Mongoose": 2, "Lion": 2 },
    "Monkey": { "Horse": 2, "Elephant": 2, "Sheep": 0, "Serpent": 2, "Dog": 2, "Cat": 2, "Rat": 3, "Cow": 2, "Buffalo": 2, "Tiger": 2, "Deer": 2, "Monkey": 4, "Mongoose": 2, "Lion": 2 },
    "Mongoose": { "Horse": 2, "Elephant": 2, "Sheep": 2, "Serpent": 0, "Dog": 2, "Cat": 2, "Rat": 2, "Cow": 2, "Buffalo": 2, "Tiger": 2, "Deer": 2, "Monkey": 2, "Mongoose": 4, "Lion": 2 },
    "Lion": { "Horse": 2, "Elephant": 0, "Sheep": 2, "Serpent": 2, "Dog": 2, "Cat": 2, "Rat": 2, "Cow": 2, "Buffalo": 2, "Tiger": 3, "Deer": 2, "Monkey": 2, "Mongoose": 2, "Lion": 4 },
};

/**
 * Nadi (Energy Channel) for each Nakshatra - important for health/genetic compatibility
 * Adi (Vata), Madhya (Pitta), Antya (Kapha) - same nadi = 0 points (health concern)
 */
export const NAKSHATRA_NADI = {
    "Ashwini": "Adi",
    "Bharani": "Madhya",
    "Krittika": "Antya",
    "Rohini": "Antya",
    "Mrigashira": "Madhya",
    "Ardra": "Adi",
    "Punarvasu": "Adi",
    "Pushya": "Madhya",
    "Ashlesha": "Antya",
    "Magha": "Antya",
    "Purva Phalguni": "Madhya",
    "Uttara Phalguni": "Adi",
    "Hasta": "Adi",
    "Chitra": "Madhya",
    "Swati": "Antya",
    "Vishakha": "Antya",
    "Anuradha": "Madhya",
    "Jyeshtha": "Adi",
    "Moola": "Adi",
    "Purva Ashadha": "Madhya",
    "Uttara Ashadha": "Antya",
    "Shravana": "Antya",
    "Dhanishta": "Madhya",
    "Shatabhisha": "Adi",
    "Purva Bhadrapada": "Adi",
    "Uttara Bhadrapada": "Madhya",
    "Revati": "Antya",
};

/**
 * Varna (Spiritual Development/Nature) for each zodiac sign
 * Brahmin = Spiritual/Intellectual, Kshatriya = Warrior/Leader, Vaishya = Merchant/Service, Shudra = Worker/Physical
 */
export const SIGN_VARNA = {
    "Cancer": "Brahmin",
    "Scorpio": "Brahmin",
    "Pisces": "Brahmin",
    "Aries": "Kshatriya",
    "Leo": "Kshatriya",
    "Sagittarius": "Kshatriya",
    "Taurus": "Vaishya",
    "Virgo": "Vaishya",
    "Capricorn": "Vaishya",
    "Gemini": "Shudra",
    "Libra": "Shudra",
    "Aquarius": "Shudra",
};

/**
 * Sign modality - Cardinal (initiating), Fixed (stable), Mutable (adaptable)
 */
export const SIGN_MODALITY = {
    "Aries": "Cardinal",
    "Taurus": "Fixed",
    "Gemini": "Mutable",
    "Cancer": "Cardinal",
    "Leo": "Fixed",
    "Virgo": "Mutable",
    "Libra": "Cardinal",
    "Scorpio": "Fixed",
    "Sagittarius": "Mutable",
    "Capricorn": "Cardinal",
    "Aquarius": "Fixed",
    "Pisces": "Mutable",
};

/**
 * Gana (Temperament) classification for each Nakshatra
 * Deva = Divine/Gentle, Manushya = Human/Balanced, Rakshasa = Demon/Intense
 */
export const NAKSHATRA_GANA = {
    "Ashwini": "Deva",
    "Bharani": "Manushya",
    "Krittika": "Rakshasa",
    "Rohini": "Manushya",
    "Mrigashira": "Deva",
    "Ardra": "Manushya",
    "Punarvasu": "Deva",
    "Pushya": "Deva",
    "Ashlesha": "Rakshasa",
    "Magha": "Rakshasa",
    "Purva Phalguni": "Manushya",
    "Uttara Phalguni": "Manushya",
    "Hasta": "Deva",
    "Chitra": "Rakshasa",
    "Swati": "Deva",
    "Vishakha": "Rakshasa",
    "Anuradha": "Deva",
    "Jyeshtha": "Rakshasa",
    "Moola": "Rakshasa",
    "Purva Ashadha": "Manushya",
    "Uttara Ashadha": "Manushya",
    "Shravana": "Deva",
    "Dhanishta": "Rakshasa",
    "Shatabhisha": "Rakshasa",
    "Purva Bhadrapada": "Manushya",
    "Uttara Bhadrapada": "Manushya",
    "Revati": "Deva",
};

// =============================================================================
// ZODIAC DATA
// =============================================================================

/**
 * 12 Zodiac signs in order (0-indexed)
 */
export const ZODIAC_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
];

/**
 * Ruling planet (lord) of each zodiac sign
 */
export const SIGN_LORDS = {
    "Aries": "Mars",
    "Taurus": "Venus",
    "Gemini": "Mercury",
    "Cancer": "Moon",
    "Leo": "Sun",
    "Virgo": "Mercury",
    "Libra": "Venus",
    "Scorpio": "Mars",
    "Sagittarius": "Jupiter",
    "Capricorn": "Saturn",
    "Aquarius": "Saturn",
    "Pisces": "Jupiter",
};

/**
 * Element of each zodiac sign
 */
export const SIGN_ELEMENTS = {
    "Aries": "Fire",
    "Taurus": "Earth",
    "Gemini": "Air",
    "Cancer": "Water",
    "Leo": "Fire",
    "Virgo": "Earth",
    "Libra": "Air",
    "Scorpio": "Water",
    "Sagittarius": "Fire",
    "Capricorn": "Earth",
    "Aquarius": "Air",
    "Pisces": "Water",
};

// =============================================================================
// PLANETARY FRIENDSHIP (GRAHA MAITRI)
// =============================================================================

/**
 * Natural planetary friendships (Naisargika Maitri)
 * Each planet's friends, neutrals, and enemies
 */
export const PLANETARY_RELATIONSHIPS = {
    "Sun": {
        friends: ["Moon", "Mars", "Jupiter"],
        neutrals: ["Mercury"],
        enemies: ["Venus", "Saturn"],
    },
    "Moon": {
        friends: ["Sun", "Mercury"],
        neutrals: ["Mars", "Jupiter", "Venus", "Saturn"],
        enemies: [],
    },
    "Mars": {
        friends: ["Sun", "Moon", "Jupiter"],
        neutrals: ["Venus", "Saturn"],
        enemies: ["Mercury"],
    },
    "Mercury": {
        friends: ["Sun", "Venus"],
        neutrals: ["Mars", "Jupiter", "Saturn"],
        enemies: ["Moon"],
    },
    "Jupiter": {
        friends: ["Sun", "Moon", "Mars"],
        neutrals: ["Saturn"],
        enemies: ["Mercury", "Venus"],
    },
    "Venus": {
        friends: ["Mercury", "Saturn"],
        neutrals: ["Mars", "Jupiter"],
        enemies: ["Sun", "Moon"],
    },
    "Saturn": {
        friends: ["Mercury", "Venus"],
        neutrals: ["Jupiter"],
        enemies: ["Sun", "Moon", "Mars"],
    },
};

// =============================================================================
// COSMIC MATCH CALCULATIONS
// =============================================================================

/**
 * Calculate Graha Maitri (Planetary Friendship) score
 * Based on the lords of both Moon signs
 * 
 * @param {string} moonSign1 - First person's Moon sign
 * @param {string} moonSign2 - Second person's Moon sign
 * @returns {object} Score and details
 */
export function calculateGrahaMaitri(moonSign1, moonSign2) {
    const lord1 = SIGN_LORDS[moonSign1];
    const lord2 = SIGN_LORDS[moonSign2];
    
    if (!lord1 || !lord2) {
        return { score: 0, maxScore: 5, percentage: 0, error: "Invalid moon signs" };
    }
    
    // Same lord = automatic 5 points
    if (lord1 === lord2) {
        return {
            score: 5,
            maxScore: 5,
            percentage: 100,
            yourLord: lord1,
            theirLord: lord2,
            relationship: "Same",
            insight: `Both ruled by ${lord1} - natural understanding and harmony.`,
        };
    }
    
    const rel1 = PLANETARY_RELATIONSHIPS[lord1];
    const rel2 = PLANETARY_RELATIONSHIPS[lord2];
    
    // Determine relationship from each side
    const isFriend1 = rel1.friends.includes(lord2);
    const isNeutral1 = rel1.neutrals.includes(lord2);
    const isEnemy1 = rel1.enemies.includes(lord2);
    
    const isFriend2 = rel2.friends.includes(lord1);
    const isNeutral2 = rel2.neutrals.includes(lord1);
    const isEnemy2 = rel2.enemies.includes(lord1);
    
    // Score based on mutual relationship
    let score = 0;
    let relationship = "";
    let insight = "";
    
    if (isFriend1 && isFriend2) {
        score = 5;
        relationship = "Mutual Friends";
        insight = `${lord1} and ${lord2} are natural friends - excellent mental connection.`;
    } else if ((isFriend1 && isNeutral2) || (isNeutral1 && isFriend2)) {
        score = 4;
        relationship = "One Friend, One Neutral";
        insight = `${lord1} and ${lord2} have good compatibility - solid understanding.`;
    } else if (isNeutral1 && isNeutral2) {
        score = 3;
        relationship = "Both Neutral";
        insight = `${lord1} and ${lord2} are neutral - requires effort for connection.`;
    } else if ((isFriend1 && isEnemy2) || (isEnemy1 && isFriend2)) {
        score = 2;
        relationship = "Mixed (Friend/Enemy)";
        insight = `${lord1} and ${lord2} have mixed dynamics - can be challenging.`;
    } else if ((isNeutral1 && isEnemy2) || (isEnemy1 && isNeutral2)) {
        score = 1;
        relationship = "Neutral/Enemy";
        insight = `${lord1} and ${lord2} require patience - potential for friction.`;
    } else if (isEnemy1 && isEnemy2) {
        score = 0;
        relationship = "Mutual Enemies";
        insight = `${lord1} and ${lord2} are natural adversaries - challenging connection.`;
    }
    
    return {
        score,
        maxScore: 5,
        percentage: Math.round((score / 5) * 100),
        yourLord: lord1,
        theirLord: lord2,
        relationship,
        insight,
    };
}

/**
 * Calculate Gana (Temperament) compatibility
 * 
 * @param {string} nakshatra1 - First person's Moon nakshatra
 * @param {string} nakshatra2 - Second person's Moon nakshatra
 * @returns {object} Score and details
 */
export function calculateGana(nakshatra1, nakshatra2) {
    const gana1 = NAKSHATRA_GANA[nakshatra1];
    const gana2 = NAKSHATRA_GANA[nakshatra2];
    
    if (!gana1 || !gana2) {
        return { score: 0, maxScore: 6, percentage: 0, error: "Invalid nakshatras" };
    }
    
    // Gana compatibility matrix
    // NOTE: Adjusted Deva-Rakshasa from 1 to 2.5 points (42%)
    // These combinations can work well - think of it as "calm meets passion"
    // rather than an incompatible match. Many successful relationships have this dynamic.
    const ganaScores = {
        "Deva-Deva": 6,
        "Deva-Manushya": 5,
        "Deva-Rakshasa": 2.5,
        "Manushya-Deva": 5,
        "Manushya-Manushya": 6,
        "Manushya-Rakshasa": 3.5,
        "Rakshasa-Deva": 2.5,
        "Rakshasa-Manushya": 3.5,
        "Rakshasa-Rakshasa": 6,
    };
    
    const key = `${gana1}-${gana2}`;
    const score = ganaScores[key] || 0;
    
    const ganaDescriptions = {
        "Deva": "Divine - gentle, spiritual, peace-loving",
        "Manushya": "Human - practical, balanced, worldly",
        "Rakshasa": "Intense - powerful, independent, dynamic",
    };
    
    let insight = "";
    if (gana1 === gana2) {
        insight = `Both share ${gana1} temperament - natural understanding.`;
    } else if (score >= 5) {
        insight = `${gana1} and ${gana2} complement each other beautifully.`;
    } else if (score >= 3.5) {
        insight = `${gana1} and ${gana2} balance each other well.`;
    } else if (score >= 2.5) {
        insight = `${gana1} meets ${gana2} - different energies that can spark growth.`;
    } else {
        insight = `${gana1} and ${gana2} - patience creates deeper connection.`;
    }
    
    return {
        score,
        maxScore: 6,
        percentage: Math.round((score / 6) * 100),
        yourGana: gana1,
        theirGana: gana2,
        yourGanaDesc: ganaDescriptions[gana1],
        theirGanaDesc: ganaDescriptions[gana2],
        insight,
    };
}

/**
 * Calculate Tara (Star) compatibility
 * Based on counting from one nakshatra to another
 * 
 * @param {string} nakshatra1 - First person's Moon nakshatra
 * @param {string} nakshatra2 - Second person's Moon nakshatra
 * @returns {object} Score and details
 */
export function calculateTara(nakshatra1, nakshatra2) {
    const index1 = NAKSHATRAS.indexOf(nakshatra1);
    const index2 = NAKSHATRAS.indexOf(nakshatra2);
    
    if (index1 === -1 || index2 === -1) {
        return { score: 0, maxScore: 3, percentage: 0, error: "Invalid nakshatras" };
    }
    
    // Count from nakshatra1 to nakshatra2
    let count = ((index2 - index1) % 27 + 27) % 27 + 1;
    const taraNumber = count % 9 || 9;
    
    // Tara names and scores
    // NOTE: Traditional Vedic astrology gives partial points for "difficult" taras
    // since even challenging positions have growth potential. Changed from 0 to 1 point
    // for difficult positions to avoid artificially low scores.
    const taraData = {
        1: { name: "Janma", score: 1.5, quality: "Average", insight: "Birth star - neutral connection" },
        2: { name: "Sampat", score: 3, quality: "Excellent", insight: "Wealth star - prosperity together" },
        3: { name: "Vipat", score: 1, quality: "Challenging", insight: "Danger star - growth through caution" },
        4: { name: "Kshema", score: 3, quality: "Good", insight: "Wellbeing star - comfort together" },
        5: { name: "Pratyari", score: 1, quality: "Challenging", insight: "Obstacle star - strength through challenges" },
        6: { name: "Saadhaka", score: 3, quality: "Good", insight: "Achievement star - success together" },
        7: { name: "Vadha", score: 1, quality: "Challenging", insight: "Transformation star - deep change together" },
        8: { name: "Mitra", score: 3, quality: "Excellent", insight: "Friend star - natural friendship" },
        9: { name: "Param Mitra", score: 3, quality: "Excellent", insight: "Best friend star - deep connection" },
    };
    
    const tara = taraData[taraNumber];
    
    return {
        score: tara.score,
        maxScore: 3,
        percentage: Math.round((tara.score / 3) * 100),
        taraNumber,
        taraName: tara.name,
        quality: tara.quality,
        insight: tara.insight,
    };
}

/**
 * Calculate Rashi (Moon Sign Position) compatibility
 * Based on the relative position of Moon signs
 * 
 * @param {string} moonSign1 - First person's Moon sign
 * @param {string} moonSign2 - Second person's Moon sign
 * @returns {object} Score and details
 */
export function calculateRashiPosition(moonSign1, moonSign2) {
    const index1 = ZODIAC_SIGNS.indexOf(moonSign1);
    const index2 = ZODIAC_SIGNS.indexOf(moonSign2);
    
    if (index1 === -1 || index2 === -1) {
        return { score: 0, maxScore: 7, percentage: 0, error: "Invalid moon signs" };
    }
    
    // Position from sign1 to sign2
    let position = ((index2 - index1) % 12 + 12) % 12 + 1;
    
    // Scoring based on position
    // NOTE: Raised floor for challenging positions from 0-1 to 2-2.5
    // Square and quincunx aspects are challenging but still carry potential.
    // This prevents artificially low scores while respecting traditional meanings.
    const positionScores = {
        1: { score: 4, quality: "Average", insight: "Same sign - deep understanding, similar outlook" },
        2: { score: 6, quality: "Good", insight: "2nd/12th - natural flow and support" },
        3: { score: 3.5, quality: "Moderate", insight: "3rd/11th - friendship and shared interests" },
        4: { score: 2.5, quality: "Growth", insight: "4th/10th - square aspect - dynamic growth together" },
        5: { score: 7, quality: "Excellent", insight: "5th/9th - trine aspect - natural harmony" },
        6: { score: 2, quality: "Transformative", insight: "6th/8th - deep transformation and healing" },
        7: { score: 5.5, quality: "Magnetic", insight: "Opposite - magnetic attraction, balance each other" },
        8: { score: 2, quality: "Transformative", insight: "6th/8th - intense growth and evolution" },
        9: { score: 7, quality: "Excellent", insight: "5th/9th - trine aspect - natural harmony" },
        10: { score: 2.5, quality: "Growth", insight: "4th/10th - square aspect - dynamic growth together" },
        11: { score: 3.5, quality: "Moderate", insight: "3rd/11th - friendship and shared interests" },
        12: { score: 6, quality: "Good", insight: "2nd/12th - natural flow and support" },
    };
    
    const data = positionScores[position];
    const element1 = SIGN_ELEMENTS[moonSign1];
    const element2 = SIGN_ELEMENTS[moonSign2];
    
    return {
        score: data.score,
        maxScore: 7,
        percentage: Math.round((data.score / 7) * 100),
        position,
        quality: data.quality,
        yourMoon: moonSign1,
        theirMoon: moonSign2,
        yourElement: element1,
        theirElement: element2,
        insight: data.insight,
    };
}

// =============================================================================
// NEW COMPREHENSIVE COMPATIBILITY CALCULATIONS
// =============================================================================

/**
 * Element compatibility matrix
 * Fire-Air and Earth-Water are harmonious, Fire-Water and Earth-Air are challenging
 */
const ELEMENT_COMPATIBILITY = {
    "Fire-Fire": { score: 80, insight: "Both dynamic and energetic - lots of passion and drive" },
    "Fire-Air": { score: 90, insight: "Fire and Air fuel each other - inspiring and exciting connection" },
    "Fire-Earth": { score: 55, insight: "Fire meets Earth - different paces but can balance each other" },
    "Fire-Water": { score: 45, insight: "Fire and Water - intense dynamics that require understanding" },
    "Air-Fire": { score: 90, insight: "Air and Fire create sparks - stimulating and energizing" },
    "Air-Air": { score: 85, insight: "Both intellectual and communicative - endless conversations" },
    "Air-Earth": { score: 50, insight: "Air meets Earth - different perspectives that can ground or frustrate" },
    "Air-Water": { score: 60, insight: "Air and Water - creative potential with emotional depth" },
    "Earth-Fire": { score: 55, insight: "Earth meets Fire - stability meets enthusiasm" },
    "Earth-Air": { score: 50, insight: "Earth meets Air - practical meets theoretical" },
    "Earth-Earth": { score: 85, insight: "Both grounded and reliable - strong, stable connection" },
    "Earth-Water": { score: 90, insight: "Earth and Water nourish each other - deeply supportive bond" },
    "Water-Fire": { score: 45, insight: "Water meets Fire - emotional depth meets dynamic energy" },
    "Water-Air": { score: 60, insight: "Water meets Air - feelings and thoughts intertwine" },
    "Water-Earth": { score: 90, insight: "Water and Earth - nurturing and grounding together" },
    "Water-Water": { score: 80, insight: "Both deeply emotional - profound understanding but may lack grounding" },
};

/**
 * Modality compatibility - how action styles mesh
 */
const MODALITY_COMPATIBILITY = {
    "Cardinal-Cardinal": { score: 70, insight: "Both leaders - can clash or conquer together" },
    "Cardinal-Fixed": { score: 80, insight: "Initiator meets stabilizer - complementary dynamic" },
    "Cardinal-Mutable": { score: 85, insight: "Leader meets adapter - flexible and productive" },
    "Fixed-Cardinal": { score: 80, insight: "Stabilizer meets initiator - grounded progress" },
    "Fixed-Fixed": { score: 65, insight: "Both steadfast - loyal but potentially stubborn" },
    "Fixed-Mutable": { score: 75, insight: "Stable meets flexible - good balance" },
    "Mutable-Cardinal": { score: 85, insight: "Adapter meets leader - supportive dynamic" },
    "Mutable-Fixed": { score: 75, insight: "Flexible meets steady - balanced approach" },
    "Mutable-Mutable": { score: 70, insight: "Both adaptable - versatile but may lack direction" },
};

/**
 * Calculate Sun Sign Harmony
 * Measures core identity alignment - fundamental self compatibility
 * 
 * @param {string} sunSign1 - First person's Sun sign
 * @param {string} sunSign2 - Second person's Sun sign
 * @returns {object} Score and details
 */
export function calculateSunSignHarmony(sunSign1, sunSign2) {
    if (!sunSign1 || !sunSign2) {
        return null; // Not available
    }
    
    const element1 = SIGN_ELEMENTS[sunSign1];
    const element2 = SIGN_ELEMENTS[sunSign2];
    const modality1 = SIGN_MODALITY[sunSign1];
    const modality2 = SIGN_MODALITY[sunSign2];
    
    if (!element1 || !element2) {
        return { score: 0, percentage: 0, error: "Invalid sun signs" };
    }
    
    // Get element compatibility
    const elementKey = `${element1}-${element2}`;
    const elementData = ELEMENT_COMPATIBILITY[elementKey] || { score: 50, insight: "Unique combination" };
    
    // Get modality compatibility
    const modalityKey = `${modality1}-${modality2}`;
    const modalityData = MODALITY_COMPATIBILITY[modalityKey] || { score: 50, insight: "Unique dynamic" };
    
    // Combined score: 60% element, 40% modality
    const combinedScore = (elementData.score * 0.6) + (modalityData.score * 0.4);
    
    // Same sign bonus
    const sameSun = sunSign1 === sunSign2;
    const finalScore = sameSun ? Math.min(100, combinedScore + 10) : combinedScore;
    
    let insight = "";
    if (sameSun) {
        insight = `Both ${sunSign1} - you share core identity traits and understand each other's essence.`;
    } else if (finalScore >= 80) {
        insight = `${sunSign1} and ${sunSign2}: ${elementData.insight}`;
    } else if (finalScore >= 60) {
        insight = `${sunSign1} meets ${sunSign2}: Different but complementary energies.`;
    } else {
        insight = `${sunSign1} and ${sunSign2}: Growth comes from embracing differences.`;
    }
    
    return {
        score: Math.round(finalScore),
        percentage: Math.round(finalScore),
        yourSun: sunSign1,
        theirSun: sunSign2,
        yourElement: element1,
        theirElement: element2,
        yourModality: modality1,
        theirModality: modality2,
        sameSun,
        elementInsight: elementData.insight,
        modalityInsight: modalityData.insight,
        insight,
    };
}

/**
 * Calculate Ascendant (Lagna) Harmony
 * Measures social compatibility - how they present to and perceive each other
 * 
 * @param {string} lagna1 - First person's Ascendant
 * @param {string} lagna2 - Second person's Ascendant
 * @returns {object} Score and details
 */
export function calculateAscendantHarmony(lagna1, lagna2) {
    if (!lagna1 || !lagna2) {
        return null; // Not available
    }
    
    const element1 = SIGN_ELEMENTS[lagna1];
    const element2 = SIGN_ELEMENTS[lagna2];
    
    if (!element1 || !element2) {
        return { score: 0, percentage: 0, error: "Invalid ascendants" };
    }
    
    // Use sign position relationship (similar to moon but for outer self)
    const index1 = ZODIAC_SIGNS.indexOf(lagna1);
    const index2 = ZODIAC_SIGNS.indexOf(lagna2);
    
    if (index1 === -1 || index2 === -1) {
        return { score: 0, percentage: 0, error: "Invalid ascendants" };
    }
    
    const position = ((index2 - index1) % 12 + 12) % 12 + 1;
    
    // Scoring based on house relationship
    const positionScores = {
        1: { score: 75, insight: "Same rising - you present similarly to the world" },
        2: { score: 65, insight: "2nd/12th - supportive social dynamic" },
        3: { score: 70, insight: "3rd/11th - friendly interaction style" },
        4: { score: 55, insight: "4th/10th - different but growth-oriented" },
        5: { score: 85, insight: "5th/9th - naturally harmonious presentation" },
        6: { score: 50, insight: "6th/8th - requires adjustment in social settings" },
        7: { score: 80, insight: "Opposite rising - attracted to each other's style" },
        8: { score: 50, insight: "6th/8th - deep transformation in how you see each other" },
        9: { score: 85, insight: "5th/9th - easy, flowing social connection" },
        10: { score: 55, insight: "4th/10th - different approaches but complementary" },
        11: { score: 70, insight: "3rd/11th - natural friendship vibe" },
        12: { score: 65, insight: "2nd/12th - subtle support and understanding" },
    };
    
    const data = positionScores[position];
    
    return {
        score: data.score,
        percentage: data.score,
        position,
        yourLagna: lagna1,
        theirLagna: lagna2,
        yourElement: element1,
        theirElement: element2,
        insight: data.insight,
    };
}

/**
 * Calculate Element Balance
 * Looks at overall elemental energy between two people
 * 
 * @param {object} person1 - { moonSign, sunSign, ascendant }
 * @param {object} person2 - { moonSign, sunSign, ascendant }
 * @returns {object} Score and details
 */
export function calculateElementBalance(person1, person2) {
    // Count elements for each person
    const countElements = (person) => {
        const counts = { Fire: 0, Earth: 0, Air: 0, Water: 0 };
        
        if (person.moonSign && SIGN_ELEMENTS[person.moonSign]) {
            counts[SIGN_ELEMENTS[person.moonSign]] += 2; // Moon weighted more
        }
        if (person.sunSign && SIGN_ELEMENTS[person.sunSign]) {
            counts[SIGN_ELEMENTS[person.sunSign]] += 1.5;
        }
        if (person.ascendant && SIGN_ELEMENTS[person.ascendant]) {
            counts[SIGN_ELEMENTS[person.ascendant]] += 1;
        }
        
        return counts;
    };
    
    const elements1 = countElements(person1);
    const elements2 = countElements(person2);
    
    // Find dominant elements
    const getDominant = (counts) => {
        return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
    };
    
    const dominant1 = getDominant(elements1);
    const dominant2 = getDominant(elements2);
    
    // Calculate compatibility based on element distribution
    // Similar distributions = good; complementary = great; opposing = challenging but growth
    let score = 50; // Base score
    let insight = "";
    
    // Check dominant element compatibility
    const elementKey = `${dominant1}-${dominant2}`;
    const baseCompat = ELEMENT_COMPATIBILITY[elementKey]?.score || 50;
    
    // Check if they balance each other
    const total1 = elements1.Fire + elements1.Earth + elements1.Air + elements1.Water;
    const total2 = elements2.Fire + elements2.Earth + elements2.Air + elements2.Water;
    
    // Combined element spread
    const combined = {
        Fire: (elements1.Fire / total1 + elements2.Fire / total2) / 2,
        Earth: (elements1.Earth / total1 + elements2.Earth / total2) / 2,
        Air: (elements1.Air / total1 + elements2.Air / total2) / 2,
        Water: (elements1.Water / total1 + elements2.Water / total2) / 2,
    };
    
    // Check for balance (more balanced = better as a pair)
    const values = Object.values(combined);
    const max = Math.max(...values);
    const min = Math.min(...values);
    const spread = max - min;
    
    // Lower spread = more balanced = bonus
    const balanceBonus = Math.max(0, (0.5 - spread) * 40); // Up to 20 point bonus for balance
    
    score = baseCompat * 0.7 + balanceBonus + 15; // Base compatibility + balance bonus
    score = Math.min(100, Math.max(30, score)); // Clamp between 30-100
    
    if (dominant1 === dominant2) {
        insight = `Both ${dominant1}-dominant - you resonate on the same elemental frequency.`;
    } else if (balanceBonus > 10) {
        insight = `Together you create elemental balance - ${dominant1} meets ${dominant2} harmoniously.`;
    } else {
        insight = `${dominant1} energy meets ${dominant2} energy - different but can complement.`;
    }
    
    return {
        score: Math.round(score),
        percentage: Math.round(score),
        yourDominant: dominant1,
        theirDominant: dominant2,
        yourElements: elements1,
        theirElements: elements2,
        combinedBalance: combined,
        insight,
    };
}

/**
 * Calculate Instinctual Affinity (based on Yoni but for universal compatibility)
 * Measures natural, instinctive understanding - how people "click" on a primal level
 * 
 * @param {string} nakshatra1 - First person's nakshatra
 * @param {string} nakshatra2 - Second person's nakshatra
 * @returns {object} Score and details
 */
export function calculateInstinctualAffinity(nakshatra1, nakshatra2) {
    const yoni1 = NAKSHATRA_YONI[nakshatra1];
    const yoni2 = NAKSHATRA_YONI[nakshatra2];
    
    if (!yoni1 || !yoni2) {
        return { score: 0, percentage: 0, error: "Invalid nakshatras" };
    }
    
    const animal1 = yoni1.animal;
    const animal2 = yoni2.animal;
    
    // Get compatibility score (0-4 scale)
    const compatScore = YONI_COMPATIBILITY[animal1]?.[animal2] ?? 2;
    
    // Convert to percentage (0=25%, 1=40%, 2=55%, 3=75%, 4=100%)
    const percentageMap = { 0: 25, 1: 40, 2: 55, 3: 75, 4: 100 };
    const percentage = percentageMap[compatScore] || 55;
    
    let insight = "";
    if (compatScore === 4) {
        insight = `Both ${animal1} energy - deep instinctual understanding and natural connection.`;
    } else if (compatScore === 3) {
        insight = `${animal1} and ${animal2} - naturally drawn to each other, easy rapport.`;
    } else if (compatScore === 2) {
        insight = `${animal1} meets ${animal2} - neutral ground, connection builds with time.`;
    } else if (compatScore === 1) {
        insight = `${animal1} and ${animal2} - different instincts, requires conscious effort.`;
    } else {
        insight = `${animal1} meets ${animal2} - contrasting energies that can learn from each other.`;
    }
    
    return {
        score: percentage,
        percentage,
        rawScore: compatScore,
        maxScore: 4,
        yourAnimal: animal1,
        theirAnimal: animal2,
        insight,
    };
}

/**
 * Calculate Nadi (Energy Channel) compatibility
 * Different nadis = good energy flow, same nadi = potential energy conflict
 * Reframed for universal compatibility as energy flow compatibility
 * 
 * @param {string} nakshatra1 - First person's nakshatra
 * @param {string} nakshatra2 - Second person's nakshatra
 * @returns {object} Score and details
 */
export function calculateNadiEnergy(nakshatra1, nakshatra2) {
    const nadi1 = NAKSHATRA_NADI[nakshatra1];
    const nadi2 = NAKSHATRA_NADI[nakshatra2];
    
    if (!nadi1 || !nadi2) {
        return { score: 0, percentage: 0, error: "Invalid nakshatras" };
    }
    
    const nadiDescriptions = {
        "Adi": "Vata - creative, quick, changeable energy",
        "Madhya": "Pitta - focused, transformative, driven energy",
        "Antya": "Kapha - stable, nurturing, enduring energy",
    };
    
    let score, insight;
    
    if (nadi1 !== nadi2) {
        // Different nadis - good energy flow
        score = 85;
        insight = `${nadi1} meets ${nadi2} - complementary energy channels create dynamic flow.`;
    } else {
        // Same nadi - can work but may have energy conflicts
        score = 50;
        insight = `Both ${nadi1} energy - similar wavelengths but may need variety.`;
    }
    
    return {
        score,
        percentage: score,
        yourNadi: nadi1,
        theirNadi: nadi2,
        yourNadiDesc: nadiDescriptions[nadi1],
        theirNadiDesc: nadiDescriptions[nadi2],
        sameNadi: nadi1 === nadi2,
        insight,
    };
}

/**
 * Calculate complete Cosmic Match score (Universal compatibility)
 * COMPREHENSIVE 8-PILLAR SYSTEM for any relationship type
 * 
 * @param {object} person1 - { moonSign, nakshatra, sunSign?, ascendant? }
 * @param {object} person2 - { moonSign, nakshatra, sunSign?, ascendant? }
 * @returns {object} Complete cosmic match result
 */
export function calculateCosmicMatch(person1, person2) {
    // =================================================================
    // TIER 1: Core Pillars (always available with moonSign + nakshatra)
    // =================================================================
    const maitri = calculateGrahaMaitri(person1.moonSign, person2.moonSign);
    const gana = calculateGana(person1.nakshatra, person2.nakshatra);
    const tara = calculateTara(person1.nakshatra, person2.nakshatra);
    const moonPosition = calculateRashiPosition(person1.moonSign, person2.moonSign);
    const instinctual = calculateInstinctualAffinity(person1.nakshatra, person2.nakshatra);
    const nadiEnergy = calculateNadiEnergy(person1.nakshatra, person2.nakshatra);
    
    // =================================================================
    // TIER 2: Enhanced Pillars (if sunSign available)
    // =================================================================
    const sunHarmony = calculateSunSignHarmony(person1.sunSign, person2.sunSign);
    
    // =================================================================
    // TIER 3: Advanced Pillars (if ascendant available)
    // =================================================================
    const lagnaHarmony = calculateAscendantHarmony(person1.ascendant, person2.ascendant);
    const elementBalance = calculateElementBalance(person1, person2);
    
    // =================================================================
    // ADAPTIVE WEIGHTING
    // Base weights (total = 100):
    // - Mental (Maitri): 14%
    // - Temperament (Gana): 12%
    // - Flow (Tara): 8%
    // - Emotional (Moon Position): 12%
    // - Instinctual (Yoni): 10%
    // - Energy Flow (Nadi): 8%
    // - Core Identity (Sun): 14%
    // - Social (Lagna): 10%
    // - Element Balance: 12%
    // =================================================================
    
    const baseWeights = {
        mental: 14,
        temperament: 12,
        flow: 8,
        emotional: 12,
        instinctual: 10,
        energyFlow: 8,
        coreIdentity: 14,
        social: 10,
        elementBalance: 12,
    };
    
    // Adjust weights based on available data
    const hasSun = sunHarmony !== null;
    const hasLagna = lagnaHarmony !== null;
    
    let weights = { ...baseWeights };
    let redistributeWeight = 0;
    
    if (!hasSun) {
        redistributeWeight += weights.coreIdentity;
        weights.coreIdentity = 0;
    }
    if (!hasLagna) {
        redistributeWeight += weights.social;
        weights.social = 0;
        // Element balance becomes less accurate without lagna
        redistributeWeight += weights.elementBalance * 0.3;
        weights.elementBalance *= 0.7;
    }
    
    // Redistribute missing weights to core pillars
    if (redistributeWeight > 0) {
        const corePillars = ['mental', 'temperament', 'emotional', 'instinctual'];
        const redistPerPillar = redistributeWeight / corePillars.length;
        corePillars.forEach(p => weights[p] += redistPerPillar);
    }
    
    // Normalize weights to sum to 100
    const totalWeight = Object.values(weights).reduce((a, b) => a + b, 0);
    Object.keys(weights).forEach(k => weights[k] = (weights[k] / totalWeight) * 100);
    
    // =================================================================
    // CALCULATE WEIGHTED SCORE
    // =================================================================
    let rawScore = 0;
    let pillarCount = 0;
    
    // Core pillars (always present)
    rawScore += (maitri.percentage * weights.mental / 100);
    rawScore += (gana.percentage * weights.temperament / 100);
    rawScore += (tara.percentage * weights.flow / 100);
    rawScore += (moonPosition.percentage * weights.emotional / 100);
    rawScore += (instinctual.percentage * weights.instinctual / 100);
    rawScore += (nadiEnergy.percentage * weights.energyFlow / 100);
    pillarCount = 6;
    
    // Enhanced pillars
    if (hasSun) {
        rawScore += (sunHarmony.percentage * weights.coreIdentity / 100);
        pillarCount++;
    }
    
    // Advanced pillars
    if (hasLagna) {
        rawScore += (lagnaHarmony.percentage * weights.social / 100);
        rawScore += (elementBalance.percentage * weights.elementBalance / 100);
        pillarCount += 2;
    } else if (person1.moonSign && person2.moonSign && person1.sunSign && person2.sunSign) {
        // Partial element balance without lagna
        rawScore += (elementBalance.percentage * weights.elementBalance / 100);
        pillarCount++;
    }
    
    // =================================================================
    // NORMALIZATION & FINAL SCORE
    // =================================================================
    // Apply gentle curve: floor of 25% to prevent artificially low scores
    const SCORE_FLOOR = 25;
    const normalizedScore = SCORE_FLOOR + (rawScore / 100) * (100 - SCORE_FLOOR);
    const cosmicScore = Math.round(normalizedScore);
    
    // Determine label
    let label = "Developing";
    if (cosmicScore >= 85) label = "Exceptional";
    else if (cosmicScore >= 75) label = "Excellent";
    else if (cosmicScore >= 65) label = "Strong";
    else if (cosmicScore >= 55) label = "Good";
    else if (cosmicScore >= 45) label = "Moderate";
    
    // Generate insight
    let insight = "";
    if (cosmicScore >= 85) {
        insight = "An exceptional cosmic connection - you understand each other on a soul level.";
    } else if (cosmicScore >= 75) {
        insight = "A beautiful cosmic bond - natural harmony and deep understanding.";
    } else if (cosmicScore >= 65) {
        insight = "A strong connection - you complement each other well.";
    } else if (cosmicScore >= 55) {
        insight = "Good compatibility - solid foundation for any relationship.";
    } else if (cosmicScore >= 45) {
        insight = "Moderate connection - understanding deepens with time and effort.";
    } else {
        insight = "A unique dynamic - different energies that can help each other grow.";
    }
    
    // Build comprehensive pillar breakdown
    const pillars = {
        mental: {
            name: "Mental Wavelength",
            description: "How your minds understand each other",
            ...maitri,
            score: maitri.percentage,
            weight: Math.round(weights.mental),
            source: "graha_maitri",
        },
        temperament: {
            name: "Temperament",
            description: "Personality style compatibility",
            ...gana,
            score: gana.percentage,
            weight: Math.round(weights.temperament),
            source: "gana",
        },
        flow: {
            name: "Natural Flow",
            description: "Ease of interaction",
            ...tara,
            score: tara.percentage,
            weight: Math.round(weights.flow),
            source: "tara",
        },
        emotional: {
            name: "Emotional Bond",
            description: "How emotions resonate",
            ...moonPosition,
            score: moonPosition.percentage,
            weight: Math.round(weights.emotional),
            source: "moon_position",
        },
        instinctual: {
            name: "Instinctual Affinity",
            description: "Natural, intuitive connection",
            ...instinctual,
            score: instinctual.percentage,
            weight: Math.round(weights.instinctual),
            source: "yoni_affinity",
        },
        energyFlow: {
            name: "Energy Flow",
            description: "How life energies complement",
            ...nadiEnergy,
            score: nadiEnergy.percentage,
            weight: Math.round(weights.energyFlow),
            source: "nadi",
        },
    };
    
    // Add enhanced pillars if available
    if (hasSun) {
        pillars.coreIdentity = {
            name: "Core Identity",
            description: "Fundamental self alignment",
            ...sunHarmony,
            score: sunHarmony.percentage,
            weight: Math.round(weights.coreIdentity),
            source: "sun_harmony",
        };
    }
    
    if (hasLagna) {
        pillars.social = {
            name: "Social Harmony",
            description: "How you present to each other",
            ...lagnaHarmony,
            score: lagnaHarmony.percentage,
            weight: Math.round(weights.social),
            source: "lagna_harmony",
        };
    }
    
    if (elementBalance && weights.elementBalance > 0) {
        pillars.elementBalance = {
            name: "Element Balance",
            description: "Overall energy compatibility",
            ...elementBalance,
            score: elementBalance.percentage,
            weight: Math.round(weights.elementBalance),
            source: "element_balance",
        };
    }
    
    return {
        score: cosmicScore,
        rawScore: Math.round(rawScore),
        label,
        insight,
        pillarCount,
        dataCompleteness: {
            hasMoonData: true,
            hasSunData: hasSun,
            hasLagnaData: hasLagna,
            completenessLevel: hasLagna ? "full" : hasSun ? "enhanced" : "basic",
        },
        pillars,
    };
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Get nakshatra from Moon degree
 * @param {number} moonDegree - Moon's longitude in degrees (0-360)
 * @returns {string} Nakshatra name
 */

/**
 * Get zodiac sign from degree
 * @param {number} degree - Longitude in degrees (0-360)
 * @returns {string} Sign name
 */
export function getSignFromDegree(degree) {
    const signIndex = Math.floor(degree / 30) % 12;
    return ZODIAC_SIGNS[signIndex];
}

/**
 * Normalize zodiac sign name
 */
export function normalizeSign(name) {
    if (!name) return null;
    
    const normalized = name.trim();
    
    // Direct match
    if (ZODIAC_SIGNS.includes(normalized)) return normalized;
    
    // Try case-insensitive match
    for (const sign of ZODIAC_SIGNS) {
        if (sign.toLowerCase() === normalized.toLowerCase()) {
            return sign;
        }
    }
    
    return normalized;
}

// =============================================================================
// LIFE PHASE SYNC (Dasha Comparison)
// =============================================================================

/**
 * Planetary energy categories based on Vedic astrology
 * Used for Life Phase Sync feature
 */
export const PLANET_ENERGY = {
    "Jupiter": {
        type: "benefic",
        theme: "Growth & Wisdom",
        description: "Expansion, learning, and spiritual growth",
        color: "#F59E0B", // Amber/Gold
    },
    "Venus": {
        type: "benefic", 
        theme: "Harmony & Love",
        description: "Relationships, creativity, and pleasures",
        color: "#EC4899", // Pink
    },
    "Mercury": {
        type: "adaptive",
        theme: "Learning & Change",
        description: "Communication, intellect, and flexibility",
        color: "#10B981", // Emerald
    },
    "Moon": {
        type: "emotional",
        theme: "Intuition & Care",
        description: "Emotions, nurturing, and inner life",
        color: "#8B5CF6", // Purple
    },
    "Sun": {
        type: "leadership",
        theme: "Identity & Power",
        description: "Self-expression, confidence, and vitality",
        color: "#F97316", // Orange
    },
    "Mars": {
        type: "dynamic",
        theme: "Action & Drive",
        description: "Energy, courage, and initiative",
        color: "#EF4444", // Red
    },
    "Saturn": {
        type: "transformative",
        theme: "Discipline & Growth",
        description: "Lessons, structure, and maturity",
        color: "#6366F1", // Indigo
    },
    "Rahu": {
        type: "transformative",
        theme: "Ambition & Desire",
        description: "Material desires, unconventional paths",
        color: "#7C3AED", // Violet
    },
    "Ketu": {
        type: "spiritual",
        theme: "Detachment & Spirit",
        description: "Spirituality, past karma, letting go",
        color: "#06B6D4", // Cyan
    },
};

/**
 * Sync interpretations based on energy type combinations
 */
const SYNC_INTERPRETATIONS = {
    // Same energy type
    "benefic-benefic": {
        label: "Flowing Together",
        quality: "excellent",
        insight: "Both in expansive, positive life phases. This is a harmonious time to connect and enjoy each other's growth.",
    },
    "transformative-transformative": {
        label: "Growing Together", 
        quality: "growth",
        insight: "Both facing life lessons and transformation. You can support each other through challenges and emerge stronger.",
    },
    "dynamic-dynamic": {
        label: "High Energy",
        quality: "good",
        insight: "Both in action-oriented phases. Lots of drive and initiative - channel it together for great results.",
    },
    "emotional-emotional": {
        label: "Deep Connection",
        quality: "excellent", 
        insight: "Both in emotionally rich phases. Deep understanding and nurturing energy flows between you.",
    },
    "spiritual-spiritual": {
        label: "Soul Connection",
        quality: "excellent",
        insight: "Both in introspective, spiritual phases. A rare opportunity for deep, meaningful connection.",
    },
    
    // Complementary combinations
    "benefic-transformative": {
        label: "Complementary",
        quality: "good",
        insight: "One can uplift and encourage while the other provides grounding. A supportive, balanced dynamic.",
    },
    "transformative-benefic": {
        label: "Complementary",
        quality: "good", 
        insight: "One can uplift and encourage while the other provides grounding. A supportive, balanced dynamic.",
    },
    "benefic-dynamic": {
        label: "Energizing",
        quality: "good",
        insight: "Growth meets action - you can inspire each other to pursue goals with wisdom and enthusiasm.",
    },
    "dynamic-benefic": {
        label: "Energizing",
        quality: "good",
        insight: "Growth meets action - you can inspire each other to pursue goals with wisdom and enthusiasm.",
    },
    "emotional-benefic": {
        label: "Nurturing",
        quality: "excellent",
        insight: "Care meets expansion - a warm, growth-oriented connection with emotional depth.",
    },
    "benefic-emotional": {
        label: "Nurturing", 
        quality: "excellent",
        insight: "Care meets expansion - a warm, growth-oriented connection with emotional depth.",
    },
    "adaptive-benefic": {
        label: "Learning Together",
        quality: "good",
        insight: "Flexibility meets wisdom - open communication and shared learning opportunities.",
    },
    "benefic-adaptive": {
        label: "Learning Together",
        quality: "good",
        insight: "Flexibility meets wisdom - open communication and shared learning opportunities.",
    },
    
    // Challenging but growth-oriented
    "transformative-dynamic": {
        label: "Intense Growth",
        quality: "challenging",
        insight: "Both in intense phases - can be powerful if channeled well, but requires patience and understanding.",
    },
    "dynamic-transformative": {
        label: "Intense Growth",
        quality: "challenging",
        insight: "Both in intense phases - can be powerful if channeled well, but requires patience and understanding.",
    },
    "spiritual-dynamic": {
        label: "Balance Needed",
        quality: "challenging",
        insight: "One seeks stillness while the other seeks action. Finding middle ground creates beautiful balance.",
    },
    "dynamic-spiritual": {
        label: "Balance Needed",
        quality: "challenging",
        insight: "One seeks stillness while the other seeks action. Finding middle ground creates beautiful balance.",
    },
    
    // Default for other combinations
    "default": {
        label: "Unique Dynamic",
        quality: "moderate",
        insight: "Your life phases bring different energies. Understanding each other's current needs creates connection.",
    },
};

/**
 * Calculate Life Phase Sync between two people
 * Based on their current Mahadasha periods
 * 
 * @param {object} dasha1 - First person's currentDasha data
 * @param {object} dasha2 - Second person's currentDasha data
 * @returns {object} Life Phase Sync result
 */
export function calculateLifePhaseSync(dasha1, dasha2) {
    // Extract Mahadasha lords
    const n1 = normalizeDasha(dasha1);
    const n2 = normalizeDasha(dasha2);
    const maha1 = n1.mahaDasha || n1.levels.maha?.lord || null;
    const maha2 = n2.mahaDasha || n2.levels.maha?.lord || null;

    // Extract Antardasha lords (optional, for more detail)
    const antar1 = n1.antarDasha || n1.levels.antar?.lord || null;
    const antar2 = n2.antarDasha || n2.levels.antar?.lord || null;
    
    // If we don't have dasha data for either person, return null
    if (!maha1 || !maha2) {
        return null;
    }
    
    // Get energy info for each person's Mahadasha
    const energy1 = PLANET_ENERGY[maha1] || { type: "unknown", theme: maha1, description: "Current life period" };
    const energy2 = PLANET_ENERGY[maha2] || { type: "unknown", theme: maha2, description: "Current life period" };
    
    // Get energy info for Antardasha (if available)
    const antarEnergy1 = antar1 ? PLANET_ENERGY[antar1] : null;
    const antarEnergy2 = antar2 ? PLANET_ENERGY[antar2] : null;
    
    // Determine sync interpretation
    const syncKey = `${energy1.type}-${energy2.type}`;
    const interpretation = SYNC_INTERPRETATIONS[syncKey] || 
                          SYNC_INTERPRETATIONS["default"];
    
    // Check if same Mahadasha lord (rare, special connection)
    const sameMahaDasha = maha1 === maha2;
    let enhancedInterpretation = interpretation;
    
    if (sameMahaDasha) {
        enhancedInterpretation = {
            label: "In Sync",
            quality: "excellent",
            insight: `Both of you are in ${maha1} Mahadasha - experiencing the same life themes. This creates deep understanding and natural alignment.`,
        };
    }
    
    // Extract timing info if available
    // Dates can be either at root level (mahaStartDate) or in levels.maha.startDate
    const maha1Dates = dasha1?.levels?.maha || {};
    const maha2Dates = dasha2?.levels?.maha || {};
    const antar1Dates = dasha1?.levels?.antar || {};
    const antar2Dates = dasha2?.levels?.antar || {};
    
    return {
        user1: {
            mahaDasha: maha1,
            antarDasha: antar1,
            energyType: energy1.type,
            theme: energy1.theme,
            description: energy1.description,
            color: energy1.color || "#6B7280",
            // Check root level first, then levels.maha
            mahaStartDate: dasha1?.mahaStartDate || maha1Dates.startDate || null,
            mahaEndDate: dasha1?.mahaEndDate || maha1Dates.endDate || null,
            antarStartDate: dasha1?.antarStartDate || antar1Dates.startDate || null,
            antarEndDate: dasha1?.antarEndDate || antar1Dates.endDate || null,
        },
        user2: {
            mahaDasha: maha2,
            antarDasha: antar2,
            energyType: energy2.type,
            theme: energy2.theme,
            description: energy2.description,
            color: energy2.color || "#6B7280",
            // Check root level first, then levels.maha
            mahaStartDate: dasha2?.mahaStartDate || maha2Dates.startDate || null,
            mahaEndDate: dasha2?.mahaEndDate || maha2Dates.endDate || null,
            antarStartDate: dasha2?.antarStartDate || antar2Dates.startDate || null,
            antarEndDate: dasha2?.antarEndDate || antar2Dates.endDate || null,
        },
        sync: {
            label: enhancedInterpretation.label,
            quality: enhancedInterpretation.quality,
            insight: enhancedInterpretation.insight,
            sameMahaDasha: sameMahaDasha,
        },
    };
}


