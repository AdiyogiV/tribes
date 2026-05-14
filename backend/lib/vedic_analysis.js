/**
 * Vedic Astrology Analysis Utilities
 * Comprehensive calculations based on classical Jyotish texts
 * 
 * References:
 * - Brihat Parashara Hora Shastra (BPHS) - Primary source
 * - Phaladeepika by Mantreswara
 * - Saravali by Kalyana Varma
 * - Jataka Parijata
 * - Standard Parashari system
 * 
 * Mathematical Basis:
 * - Sidereal zodiac (Lahiri Ayanamsa standard)
 * - Equal house system (Bhava = 30° from Lagna degree)
 * - Traditional orbs and aspects
 */

import { logger } from "firebase-functions";
import { 
    GANDMOOL_NAKSHATRAS, 
    HOUSE_SIGNIFICATIONS,
    NAKSHATRAS as SHARED_NAKSHATRAS,
} from "./constants.js";

// ============================================================================
// FOUNDATIONAL VEDIC CONSTANTS
// ============================================================================

// HOUSE_SIGNIFICATIONS imported from lib/constants.js

/**
 * Planet natural friendship chart (Naisargika Maitri)
 * Based on BPHS Chapter 3
 */
const PLANET_FRIENDSHIPS = {
    Sun: { friends: ["Moon", "Mars", "Jupiter"], neutral: ["Mercury"], enemies: ["Venus", "Saturn"] },
    Moon: { friends: ["Sun", "Mercury"], neutral: ["Mars", "Jupiter", "Venus", "Saturn"], enemies: [] },
    Mars: { friends: ["Sun", "Moon", "Jupiter"], neutral: ["Venus", "Saturn"], enemies: ["Mercury"] },
    Mercury: { friends: ["Sun", "Venus"], neutral: ["Mars", "Jupiter", "Saturn"], enemies: ["Moon"] },
    Jupiter: { friends: ["Sun", "Moon", "Mars"], neutral: ["Saturn"], enemies: ["Mercury", "Venus"] },
    Venus: { friends: ["Mercury", "Saturn"], neutral: ["Mars", "Jupiter"], enemies: ["Sun", "Moon"] },
    Saturn: { friends: ["Mercury", "Venus"], neutral: ["Jupiter"], enemies: ["Sun", "Moon", "Mars"] },
};

/**
 * Combustion orbs (Asta) - When planets are too close to Sun
 * Based on BPHS Chapter 25
 */
const COMBUSTION_ORBS = {
    Moon: 12,      // Moon combust within 12°
    Mars: 17,      // Mars combust within 17°
    Mercury: 14,   // Mercury combust within 14° (12° when retrograde)
    Jupiter: 11,   // Jupiter combust within 11°
    Venus: 10,     // Venus combust within 10° (8° when retrograde)
    Saturn: 15,    // Saturn combust within 15°
};

/**
 * Exaltation degrees (Uccha) - Exact degree of maximum strength
 * Based on BPHS
 */
const EXALTATION_DEGREES = {
    Sun: { sign: "Aries", degree: 10 },
    Moon: { sign: "Taurus", degree: 3 },
    Mars: { sign: "Capricorn", degree: 28 },
    Mercury: { sign: "Virgo", degree: 15 },
    Jupiter: { sign: "Cancer", degree: 5 },
    Venus: { sign: "Pisces", degree: 27 },
    Saturn: { sign: "Libra", degree: 20 },
    Rahu: { sign: "Taurus", degree: 20 },   // Traditional - some texts differ
    Ketu: { sign: "Scorpio", degree: 20 },  // Traditional - some texts differ
};

/**
 * Debilitation degrees (Neecha) - Exact degree of minimum strength
 * Always 180° from exaltation
 */
const DEBILITATION_DEGREES = {
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

/**
 * Mool Trikona signs and degree ranges
 * Based on BPHS - planets are strong in their Mool Trikona
 */
const MOOL_TRIKONA = {
    Sun: { sign: "Leo", from: 0, to: 20 },
    Moon: { sign: "Taurus", from: 3, to: 30 },
    Mars: { sign: "Aries", from: 0, to: 12 },
    Mercury: { sign: "Virgo", from: 15, to: 20 },
    Jupiter: { sign: "Sagittarius", from: 0, to: 10 },
    Venus: { sign: "Libra", from: 0, to: 15 },
    Saturn: { sign: "Aquarius", from: 0, to: 20 },
};

/**
 * Yogakaraka planets for each ascendant
 * A Yogakaraka rules both a Kendra (1,4,7,10) and Trikona (5,9) house
 */
const YOGAKARAKA = {
    Aries: null,           // No Yogakaraka
    Taurus: "Saturn",      // Rules 9th & 10th
    Gemini: null,          // No Yogakaraka
    Cancer: "Mars",        // Rules 5th & 10th
    Leo: "Mars",           // Rules 4th & 9th
    Virgo: null,           // No Yogakaraka (Mercury rules 1 & 10 but 1 is both Kendra & Trikona)
    Libra: "Saturn",       // Rules 4th & 5th
    Scorpio: null,         // No Yogakaraka (though Jupiter rules 5 and Moon rules 9)
    Sagittarius: null,     // No Yogakaraka
    Capricorn: "Venus",    // Rules 5th & 10th
    Aquarius: "Venus",     // Rules 4th & 9th
    Pisces: null,          // No Yogakaraka (Mars rules 9, Moon rules 5)
};

// GANDMOOL_NAKSHATRAS imported from lib/constants.js


// ============================================================================
// SCORING CONSTANTS
// Extracted from inline magic numbers for maintainability and documentation
// ============================================================================

/**
 * Dignity scores used in calculatePlanetDignity()
 * Scale: 0 (weakest) to 100 (strongest)
 * Based on traditional Shadbala proportional strengths
 */
const DIGNITY_SCORES = {
    EXALTED_BASE: 100,        // Maximum possible score at exact exaltation degree
    EXALTED_PENALTY_PER_DEG: 1.5, // Score reduction per degree from exact exaltation
    EXALTED_MIN: 85,          // Floor for exalted planets (even far from exact degree)
    DEBILITATED_BASE: 15,     // Base score at exact debilitation degree
    DEBILITATED_GAIN_PER_DEG: 1.5, // Score gain per degree from exact debilitation
    DEBILITATED_MAX: 30,      // Ceiling for debilitated planets
    MOOL_TRIKONA: 80,         // Mool Trikona dignity score
    OWN_SIGN: 75,             // Planet in own sign (Swakshetra)
    FRIENDLY: 60,             // Planet in sign of friend
    NEUTRAL: 50,              // Planet in neutral sign (also default/unknown)
    ENEMY: 35,                // Planet in sign of enemy
};

/**
 * Aspect strength values for calculateAspect()
 * Higher = stronger influence between the two planets
 */
const ASPECT_STRENGTHS = {
    CONJUNCTION: 10,
    OPPOSITION: 8,
    TRINE: 6,
    SQUARE: 5,
    SEXTILE: 4,
    ORB_DEGREES: 10,          // Standard orb for all aspects
    MIN_STRENGTH_THRESHOLD: 4, // Minimum strength to include in results
};

/**
 * Transit significance scores for calculateTransitSignificance()
 */
const TRANSIT_SCORES = {
    MAJOR_HOUSE: 10,          // Kendra houses (1, 4, 7, 10)
    SECONDARY_HOUSE: 7,       // Trikona + 2nd/11th houses (2, 5, 9, 11)
    TERTIARY_HOUSE: 3,        // Dusthana + minor houses (3, 6, 8, 12)
    SLOW_PLANET_BONUS: 5,     // Extra weight for Saturn, Jupiter, Rahu, Ketu
    LAGNA_ASPECT: 10,         // Aspect to Ascendant
};

/**
 * Nakshatra list for reference (27 nakshatras)
 */
const NAKSHATRAS = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra",
    "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni",
    "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha", "Jyeshtha",
    "Moola", "Purva Ashadha", "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha",
    "Purva Bhadrapada", "Uttara Bhadrapada", "Revati",
];

/**
 * Get house signification
 */
export function getHouseSignification(houseNumber) {
    return HOUSE_SIGNIFICATIONS[houseNumber] || "Unknown house";
}

/**
 * Calculate house number from degree (1-12)
 * Houses are 30° each, starting from Ascendant
 * 
 * Mathematical basis:
 * - Ascendant degree marks the beginning of 1st house
 * - Each house spans exactly 30°
 * - Planet's house = floor((planet_degree - ascendant_degree + 360) % 360 / 30) + 1
 */
export function calculateHouseFromDegree(degree, ascendantDegree) {
    if (degree == null || ascendantDegree == null) return null;

    // Normalize to 0-359.999... range
    const normalizedDegree = ((degree - ascendantDegree + 360) % 360);
    // Calculate house (1-12)
    const houseNumber = Math.floor(normalizedDegree / 30) + 1;
    // Ensure result is 1-12 (defensive check)
    return Math.min(Math.max(houseNumber, 1), 12);
}

/**
 * Get nakshatra from absolute degree (0-360)
 * Each nakshatra spans 13°20' (13.333...°)
 */
export function getNakshatraFromDegree(degree) {
    if (degree == null) return null;
    const normalizedDegree = ((degree % 360) + 360) % 360;
    const nakshatraIndex = Math.floor(normalizedDegree / (360 / 27));
    return NAKSHATRAS[nakshatraIndex] || null;
}

/**
 * Get sign from absolute degree (0-360)
 */
export function getSignFromDegree(degree) {
    if (degree == null) return null;
    const normalizedDegree = ((degree % 360) + 360) % 360;
    const signIndex = Math.floor(normalizedDegree / 30);
    return VEDIC_SIGNS[signIndex] || null;
}

/**
 * Calculate house using WHOLE SIGN house system
 * This is the preferred method for TRANSIT analysis in Vedic astrology
 * 
 * In whole sign houses:
 * - The entire sign containing the Lagna is the 1st house
 * - The next sign is the 2nd house, etc.
 * - A planet's house depends only on its SIGN, not exact degree
 * 
 * Example: If Lagna is Capricorn (at any degree), and Sun is in Capricorn:
 * - Sun is in 1st house (regardless of whether Sun's degree is before/after Lagna degree)
 * 
 * This is different from Bhava/Equal house calculation which uses exact degrees.
 * 
 * @param {number} planetDegree - Planet's absolute longitude (0-360)
 * @param {number} ascendantDegree - Ascendant's absolute longitude (0-360)
 * @returns {number} House number (1-12)
 */
export function calculateWholeSignHouse(planetDegree, ascendantDegree) {
    if (planetDegree == null || ascendantDegree == null) return null;
    
    // Get sign index (0-11) for both planet and ascendant
    const planetSignIndex = Math.floor(((planetDegree % 360) + 360) % 360 / 30);
    const ascendantSignIndex = Math.floor(((ascendantDegree % 360) + 360) % 360 / 30);
    
    // Calculate house (1-12) using whole sign method
    // Planet in same sign as Lagna = 1st house
    const houseIndex = ((planetSignIndex - ascendantSignIndex + 12) % 12);
    return houseIndex + 1; // Convert 0-11 to 1-12
}

/**
 * Calculate VEDIC aspects (Drishti)
 * 
 * In Vedic astrology, aspects are based on HOUSES, not degrees like Western astrology.
 * - All planets aspect the 7th house from themselves (180°)
 * - Mars additionally aspects 4th and 8th houses (90° and 210°)
 * - Jupiter additionally aspects 5th and 9th houses (120° and 240°)
 * - Saturn additionally aspects 3rd and 10th houses (60° and 270°)
 * - Rahu/Ketu aspect like Jupiter (5th and 9th)
 * 
 * Reference: BPHS Chapter 26
 */
export function calculateVedicAspect(aspectingPlanet, aspectingDegree, aspectedDegree) {
    if (aspectingDegree == null || aspectedDegree == null) return null;

    // Calculate house distance (1-12)
    let houseDiff = Math.floor(((aspectedDegree - aspectingDegree + 360) % 360) / 30) + 1;
    if (houseDiff > 12) houseDiff -= 12;
    
    const aspects = [];
    
    // All planets have full 7th aspect (opposition)
    if (houseDiff === 7) {
        aspects.push({ type: "full_aspect", house: 7, strength: 100 });
    }
    
    // Special aspects based on planet
    const planetName = aspectingPlanet?.toString() || "";
    
    if (planetName.includes("Mars")) {
        // Mars aspects 4th and 8th with full strength
        if (houseDiff === 4) aspects.push({ type: "special_aspect", house: 4, strength: 100 });
        if (houseDiff === 8) aspects.push({ type: "special_aspect", house: 8, strength: 100 });
    }
    
    if (planetName.includes("Jupiter")) {
        // Jupiter aspects 5th and 9th with full strength
        if (houseDiff === 5) aspects.push({ type: "special_aspect", house: 5, strength: 100 });
        if (houseDiff === 9) aspects.push({ type: "special_aspect", house: 9, strength: 100 });
    }
    
    if (planetName.includes("Saturn")) {
        // Saturn aspects 3rd and 10th with full strength
        if (houseDiff === 3) aspects.push({ type: "special_aspect", house: 3, strength: 100 });
        if (houseDiff === 10) aspects.push({ type: "special_aspect", house: 10, strength: 100 });
    }
    
    if (planetName.includes("Rahu") || planetName.includes("Ketu")) {
        // Rahu/Ketu aspect like Jupiter (5th and 9th)
        if (houseDiff === 5) aspects.push({ type: "special_aspect", house: 5, strength: 100 });
        if (houseDiff === 9) aspects.push({ type: "special_aspect", house: 9, strength: 100 });
    }
    
    // Conjunction (same house)
    if (houseDiff === 1) {
        // Check actual degree proximity for conjunction
        const diff = Math.abs(aspectingDegree - aspectedDegree);
        const angle = Math.min(diff, 360 - diff);
        if (angle < 12) { // Traditional conjunction orb
            aspects.push({ type: "conjunction", house: 1, strength: 100, orb: angle });
        }
    }
    
    return aspects.length > 0 ? aspects : null;
}

/**
 * Check if a planet aspects another planet (Vedic method)
 * Returns true if aspectingPlanet aspects aspectedPlanet
 */
export function doesPlanetAspect(aspectingPlanet, aspectingDegree, aspectedDegree) {
    const aspects = calculateVedicAspect(aspectingPlanet, aspectingDegree, aspectedDegree);
    return aspects && aspects.length > 0;
}

/**
 * Calculate planet dignity/strength (Bala)
 * Returns strength category and score
 * 
 * Based on traditional dignity:
 * - Exalted (Uccha): Highest strength
 * - Mool Trikona: Very strong
 * - Own sign (Swakshetra): Strong
 * - Friendly sign: Moderate
 * - Neutral sign: Neutral
 * - Enemy sign: Weak
 * - Debilitated (Neecha): Weakest
 */
export function calculatePlanetDignity(planetName, signName, degreeInSign = 15) {
    if (!planetName || !signName) return { dignity: "unknown", score: DIGNITY_SCORES.NEUTRAL };

    const pName = planetName.toString();
    const sName = signName.toString().toLowerCase();

    // Check exaltation
    const exalt = EXALTATION_DEGREES[pName];
    if (exalt && exalt.sign.toLowerCase() === sName) {
        const distFromExact = Math.abs(degreeInSign - exalt.degree);
        const score = DIGNITY_SCORES.EXALTED_BASE - (distFromExact * DIGNITY_SCORES.EXALTED_PENALTY_PER_DEG);
        return { dignity: "exalted", score: Math.max(DIGNITY_SCORES.EXALTED_MIN, score), isExalted: true };
    }

    // Check debilitation
    const debil = DEBILITATION_DEGREES[pName];
    if (debil && debil.sign.toLowerCase() === sName) {
        const distFromExact = Math.abs(degreeInSign - debil.degree);
        const score = DIGNITY_SCORES.DEBILITATED_BASE + (distFromExact * DIGNITY_SCORES.DEBILITATED_GAIN_PER_DEG);
        return { dignity: "debilitated", score: Math.min(DIGNITY_SCORES.DEBILITATED_MAX, score), isDebilitated: true };
    }

    // Check Mool Trikona
    const mool = MOOL_TRIKONA[pName];
    if (mool && mool.sign.toLowerCase() === sName) {
        if (degreeInSign >= mool.from && degreeInSign <= mool.to) {
            return { dignity: "mool_trikona", score: DIGNITY_SCORES.MOOL_TRIKONA, isMoolTrikona: true };
        }
    }

    // Check own sign
    const rulership = PLANET_RULERSHIP[pName];
    if (rulership && rulership.some(s => s.toLowerCase() === sName)) {
        return { dignity: "own_sign", score: DIGNITY_SCORES.OWN_SIGN, isOwnSign: true };
    }

    // Check friendship based on sign lord
    const signLord = getSignLord(signName);
    if (signLord && PLANET_FRIENDSHIPS[pName]) {
        const friendships = PLANET_FRIENDSHIPS[pName];
        if (friendships.friends.includes(signLord)) {
            return { dignity: "friendly", score: DIGNITY_SCORES.FRIENDLY };
        }
        if (friendships.enemies.includes(signLord)) {
            return { dignity: "enemy", score: DIGNITY_SCORES.ENEMY };
        }
        if (friendships.neutral.includes(signLord)) {
            return { dignity: "neutral", score: DIGNITY_SCORES.NEUTRAL };
        }
    }

    return { dignity: "neutral", score: DIGNITY_SCORES.NEUTRAL };
}

/**
 * Get the lord (ruler) of a sign
 */
function getSignLord(signName) {
    if (!signName) return null;
    const sName = signName.toString().toLowerCase();
    for (const [planet, signs] of Object.entries(PLANET_RULERSHIP)) {
        if (signs.some(s => s.toLowerCase() === sName)) {
            return planet;
        }
    }
    return null;
}

/**
 * Check if planet is combust (Asta)
 * A planet too close to the Sun loses strength
 * 
 * Reference: BPHS Chapter 25
 */
export function checkCombustion(planetName, planetDegree, sunDegree, isRetrograde = false) {
    if (!planetName || planetDegree == null || sunDegree == null) return null;
    if (planetName === "Sun" || planetName === "Rahu" || planetName === "Ketu") return null;
    
    const diff = Math.abs(planetDegree - sunDegree);
    const angle = Math.min(diff, 360 - diff);
    
    let orbLimit = COMBUSTION_ORBS[planetName] || 12;
    
    // Mercury and Venus have tighter orbs when retrograde
    if (isRetrograde) {
        if (planetName === "Mercury") orbLimit = 12;
        if (planetName === "Venus") orbLimit = 8;
    }
    
    if (angle <= orbLimit) {
        const severity = angle < (orbLimit / 2) ? "severe" : "moderate";
        return {
            isCombust: true,
            orb: angle,
            severity,
            effect: `${planetName} is combust (within ${angle.toFixed(1)}° of Sun) - significations weakened`,
        };
    }
    
    return { isCombust: false };
}

/**
 * Check Gandmool Dosha
 * Birth in certain nakshatras is considered inauspicious
 */
export function checkGandmoolDosha(moonNakshatra) {
    if (!moonNakshatra) return null;
    
    const nakshatra = moonNakshatra.toString();
    const isGandmool = GANDMOOL_NAKSHATRAS.some(
        gn => nakshatra.toLowerCase().includes(gn.toLowerCase())
    );
    
    if (isGandmool) {
        return {
            hasGandmool: true,
            nakshatra: moonNakshatra,
            description: `Born in ${moonNakshatra} nakshatra - Gandmool Dosha present. Traditional remedies may be beneficial.`,
        };
    }
    
    return { hasGandmool: false };
}

/**
 * Check Kemadruma Yoga (very important negative yoga)
 * Moon without planets in 2nd or 12th from it causes mental troubles and poverty
 * 
 * Reference: BPHS, Phaladeepika
 * 
 * Cancellation occurs if:
 * - Moon in Kendra from Lagna
 * - Moon conjunct/aspected by benefics
 * - Moon in Kendra from a planet
 */
export function checkKemadrumaYoga(moonHouse, moonDegree, planets, ascDegree) {
    if (moonHouse == null || moonDegree == null || !planets) return null;
    
    // Houses 2nd and 12th from Moon
    const house2ndFromMoon = moonHouse === 12 ? 1 : moonHouse + 1;
    const house12thFromMoon = moonHouse === 1 ? 12 : moonHouse - 1;
    
    let hasPlanetIn2nd = false;
    let hasPlanetIn12th = false;
    const relevantPlanets = ["Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
    
    for (const planetName of relevantPlanets) {
        const planet = planets[planetName];
        if (!planet) continue;
        
        const pDegree = planet.fullDegree || planet.full_degree || planet.longitude;
        if (pDegree == null) continue;
        
        const pHouse = calculateHouseFromDegree(pDegree, ascDegree);
        
        if (pHouse === house2ndFromMoon) hasPlanetIn2nd = true;
        if (pHouse === house12thFromMoon) hasPlanetIn12th = true;
    }
    
    // Kemadruma exists if no planets in 2nd or 12th from Moon
    if (!hasPlanetIn2nd && !hasPlanetIn12th) {
        // Check for cancellation
        const isMoonInKendra = [1, 4, 7, 10].includes(moonHouse);
        
        if (isMoonInKendra) {
            return {
                hasKemadruma: false,
                cancelled: true,
                reason: "Moon in Kendra from Lagna cancels Kemadruma",
            };
        }
        
        return {
            hasKemadruma: true,
            description: "Kemadruma Yoga - Moon without support in adjacent houses. May indicate periods of loneliness or financial challenges. Benefic aspects can mitigate.",
            severity: "Moderate",
        };
    }
    
    return { hasKemadruma: false };
}

/**
 * Calculate aspects between two planets (Western-style, for compatibility)
 * Kept for backward compatibility
 */
export function calculateAspect(degree1, degree2) {
    if (degree1 == null || degree2 == null) return null;

    const diff = Math.abs(degree1 - degree2);
    const angle = Math.min(diff, 360 - diff);

    // Using traditional Vedic conjunction orb
    const orb = ASPECT_STRENGTHS.ORB_DEGREES;
    if (angle < orb) return { type: "conjunction", angle, strength: ASPECT_STRENGTHS.CONJUNCTION };
    if (Math.abs(angle - 180) < orb) return { type: "opposition", angle, strength: ASPECT_STRENGTHS.OPPOSITION };
    if (Math.abs(angle - 120) < orb) return { type: "trine", angle, strength: ASPECT_STRENGTHS.TRINE };
    if (Math.abs(angle - 90) < orb) return { type: "square", angle, strength: ASPECT_STRENGTHS.SQUARE };
    if (Math.abs(angle - 60) < orb) return { type: "sextile", angle, strength: ASPECT_STRENGTHS.SEXTILE };

    return null;
}

/**
 * Calculate house activations from transits
 * Returns array of activated houses with significations
 */
export function calculateHouseActivations(natalChart, transits) {
    if (!natalChart || !transits) return [];

    const activations = [];
    // Handle ascendant as number or object
    const ascendantDegree = typeof natalChart.ascendant === "number"
        ? natalChart.ascendant
        : (natalChart.ascendant?.fullDegree || natalChart.ascendant?.longitude);

    if (ascendantDegree == null) return [];

    // Process each transiting planet
    Object.entries(transits).forEach(([planet, transitData]) => {
        if (!transitData || typeof transitData !== "object") return;

        const transitDegree = transitData.degree || transitData.fullDegree || transitData.longitude;
        if (transitDegree == null) return;

        const houseNumber = calculateHouseFromDegree(transitDegree, ascendantDegree);
        if (!houseNumber) return;

        const signification = getHouseSignification(houseNumber);

        activations.push({
            planet,
            house: houseNumber,
            signification,
            transitSign: transitData.sign,
            transitDegree,
        });
    });

    return activations;
}

/**
 * Calculate aspects between transit and natal planets
 * Returns array of significant aspects
 */
export function calculateTransitAspects(natalChart, transits) {
    if (!natalChart || !transits) return [];

    const aspects = [];
    const natalPlanets = natalChart.planets || natalChart.birthChartData?.planets || {};

    // Process each transiting planet
    Object.entries(transits).forEach(([transitPlanet, transitData]) => {
        if (!transitData || typeof transitData !== "object") return;

        const transitDegree = transitData.degree || transitData.fullDegree || transitData.longitude;
        if (transitDegree == null) return;

        // Check aspects to all natal planets
        Object.entries(natalPlanets).forEach(([natalPlanet, natalData]) => {
            if (!natalData || typeof natalData !== "object") return;
            if (transitPlanet === natalPlanet) return; // Skip same planet

            const natalDegree = natalData.fullDegree || natalData.longitude;
            if (natalDegree == null) return;

            const aspect = calculateAspect(transitDegree, natalDegree);
            if (aspect && aspect.strength >= ASPECT_STRENGTHS.MIN_STRENGTH_THRESHOLD) { // Only significant aspects
                aspects.push({
                    transitPlanet,
                    natalPlanet,
                    type: aspect.type,
                    angle: aspect.angle,
                    strength: aspect.strength,
                });
            }
        });
    });

    return aspects;
}

/**
 * Calculate significance score for a transit
 * Higher score = more significant
 */
export function calculateTransitSignificance(transitData, natalPlanet, planetName) {
    if (!transitData || !natalPlanet) return 0;

    let score = 0;

    // House importance
    const houseNumber = transitData.house;
    if (houseNumber) {
        // Major houses (1, 4, 7, 10) are more significant
        if ([1, 4, 7, 10].includes(houseNumber)) {
            score += TRANSIT_SCORES.MAJOR_HOUSE;
        } else if ([2, 5, 9, 11].includes(houseNumber)) {
            score += TRANSIT_SCORES.SECONDARY_HOUSE;
        } else {
            score += TRANSIT_SCORES.TERTIARY_HOUSE;
        }
    }

    // Planet importance (slow planets are more significant)
    const slowPlanets = ["Saturn", "Jupiter", "Rahu", "Ketu"];
    if (slowPlanets.includes(planetName)) {
        score += TRANSIT_SCORES.SLOW_PLANET_BONUS;
    }

    // Aspect to Lagna (most significant)
    if (transitData.aspectsToLagna) {
        score += TRANSIT_SCORES.LAGNA_ASPECT;
    }

    return score;
}

/**
 * Score house activations by significance
 */
export function scoreHouseActivations(houseActivations, dashaData) {
    if (!houseActivations || houseActivations.length === 0) return [];

    return houseActivations.map(activation => {
        let significance = 0;

        // House importance
        if ([1, 4, 7, 10].includes(activation.house)) {
            significance += 10;
        } else if ([2, 5, 9, 11].includes(activation.house)) {
            significance += 7;
        } else {
            significance += 3;
        }

        // Planet importance
        const slowPlanets = ["Saturn", "Jupiter", "Rahu", "Ketu"];
        if (slowPlanets.includes(activation.planet)) {
            significance += 5;
        }

        // Dasha interaction (if transit planet is Dasha lord)
        if (dashaData) {
            const mahaDasha = dashaData.mahaDasha || dashaData.mahadasha;
            const antarDasha = dashaData.antarDasha || dashaData.antardasha;

            if (activation.planet === mahaDasha || activation.planet === antarDasha) {
                significance += 8;
            }
        }

        return {
            ...activation,
            score: significance, // Use 'score' for consistency with frontend expectations
            significance, // Keep both for backward compatibility
        };
    }).sort((a, b) => (b.score || b.significance) - (a.score || a.significance)); // Sort by score descending
}

/**
 * Score aspects by significance
 */
export function scoreAspects(aspects, dashaData) {
    if (!aspects || aspects.length === 0) return [];

    return aspects.map(aspect => {
        let significance = aspect.strength || 0;

        // Aspect type importance
        if (aspect.type === "conjunction" || aspect.type === "opposition") {
            significance += 2;
        }

        // Dasha interaction
        if (dashaData) {
            const mahaDasha = dashaData.mahaDasha || dashaData.mahadasha;
            const antarDasha = dashaData.antarDasha || dashaData.antardasha;

            if (aspect.transitPlanet === mahaDasha || aspect.transitPlanet === antarDasha) {
                significance += 8;
            }
        }

        return {
            ...aspect,
            score: significance, // Use 'score' for consistency with frontend expectations
            significance, // Keep both for backward compatibility
        };
    }).sort((a, b) => (b.score || b.significance) - (a.score || a.significance)); // Sort by score descending
}

// ========================================
// RAJ YOGA CALCULATIONS
// ========================================

const VEDIC_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
];

// Planet rulership (which sign each planet rules)
const PLANET_RULERSHIP = {
    Sun: ["Leo"],
    Moon: ["Cancer"],
    Mars: ["Aries", "Scorpio"],
    Mercury: ["Gemini", "Virgo"],
    Jupiter: ["Sagittarius", "Pisces"],
    Venus: ["Taurus", "Libra"],
    Saturn: ["Capricorn", "Aquarius"],
};

// Exaltation signs
const EXALTATION = {
    Sun: "Aries",
    Moon: "Taurus",
    Mars: "Capricorn",
    Mercury: "Virgo",
    Jupiter: "Cancer",
    Venus: "Pisces",
    Saturn: "Libra",
};

// Kendra houses (angular): 1, 4, 7, 10
const KENDRA_HOUSES = [1, 4, 7, 10];
// Trikona houses (trines): 1, 5, 9
const TRIKONA_HOUSES = [1, 5, 9];

/**
 * Get sign number (1-12) from sign name
 */
function getSignNumber(signName) {
    if (!signName) return null;
    const idx = VEDIC_SIGNS.findIndex(s => s.toLowerCase() === signName.toLowerCase());
    return idx >= 0 ? idx + 1 : null;
}

/**
 * Get house number from planet degree and ascendant degree
 */
function getHouseNumber(planetDegree, ascendantDegree) {
    if (planetDegree == null || ascendantDegree == null) return null;
    const diff = ((planetDegree - ascendantDegree + 360) % 360);
    return Math.floor(diff / 30) + 1;
}

/**
 * Check if planet is in its own sign
 */
function isInOwnSign(planetName, signName) {
    const rulership = PLANET_RULERSHIP[planetName];
    if (!rulership || !signName) return false;
    return rulership.some(s => s.toLowerCase() === signName.toLowerCase());
}

/**
 * Check if planet is exalted
 */
function isExalted(planetName, signName) {
    const exaltSign = EXALTATION[planetName];
    if (!exaltSign || !signName) return false;
    return exaltSign.toLowerCase() === signName.toLowerCase();
}

/**
 * Calculate Raj Yogas from planetary positions
 * @param {Object} planets - Planetary positions from API
 * @param {string|Object} ascendant - Ascendant sign or object with sign info
 * @returns {Array} Array of detected Raj Yogas
 */
export function calculateRajYogas(planets, ascendant) {
    const rajYogas = [];

    if (!planets || typeof planets !== "object") return rajYogas;

    // Extract planet data helper
    const getPlanet = (name) => {
        // Try exact match first
        let p = planets[name] || planets[name.toLowerCase()];
        if (p) return { ...p, name };

        // Try numeric keys (FreeAstrologyAPI format)
        const numericMap = {
            Ascendant: "0", Sun: "1", Moon: "2", Venus: "3",
            Mars: "4", Mercury: "5", Jupiter: "6", Saturn: "7",
            Rahu: "8", Ketu: "9",
        };
        const key = numericMap[name];
        if (key && planets[key]) {
            return { ...planets[key], name };
        }

        // Search by name field
        for (const [k, v] of Object.entries(planets)) {
            if (v && typeof v === "object") {
                const pName = (v.name || k).toString().toLowerCase();
                if (pName === name.toLowerCase()) {
                    return { ...v, name };
                }
            }
        }
        return null;
    };

    // Get ascendant degree
    const ascData = typeof ascendant === "object" ? ascendant : getPlanet("Ascendant");
    const ascDegree = ascData?.fullDegree || ascData?.full_degree || ascData?.longitude;
    const ascSign = ascData?.zodiac_sign_name || ascData?.sign;

    if (ascDegree == null) {
        logger.warn("⚠️ Cannot calculate Raj Yogas: missing ascendant degree");
        return rajYogas;
    }

    // Helper to get planet's house and sign
    const getPlanetInfo = (name) => {
        const p = getPlanet(name);
        if (!p) return null;
        const degree = p.fullDegree || p.full_degree || p.longitude;
        const sign = p.zodiac_sign_name || p.sign;
        const house = degree != null ? getHouseNumber(degree, ascDegree) : null;
        return { name, degree, sign, house, data: p };
    };

    // Get all major planets
    const sun = getPlanetInfo("Sun");
    const moon = getPlanetInfo("Moon");
    const mars = getPlanetInfo("Mars");
    const mercury = getPlanetInfo("Mercury");
    const jupiter = getPlanetInfo("Jupiter");
    const venus = getPlanetInfo("Venus");
    const saturn = getPlanetInfo("Saturn");
    const rahu = getPlanetInfo("Rahu");
    const ketu = getPlanetInfo("Ketu");

    // ========================================
    // 1. PANCH MAHAPURUSHA YOGAS
    // When Mars, Mercury, Jupiter, Venus, Saturn in kendra & own/exalted sign
    // ========================================

    const mahapurushaCheck = [
        { planet: mars, name: "Ruchaka Yoga", lord: "Mars" },
        { planet: mercury, name: "Bhadra Yoga", lord: "Mercury" },
        { planet: jupiter, name: "Hamsa Yoga", lord: "Jupiter" },
        { planet: venus, name: "Malavya Yoga", lord: "Venus" },
        { planet: saturn, name: "Shasha Yoga", lord: "Saturn" },
    ];

    for (const check of mahapurushaCheck) {
        const p = check.planet;
        if (!p || !p.house || !p.sign) continue;

        if (KENDRA_HOUSES.includes(p.house)) {
            if (isInOwnSign(check.lord, p.sign) || isExalted(check.lord, p.sign)) {
                rajYogas.push({
                    name: check.name,
                    type: "Panch Mahapurusha",
                    description: `${check.lord} in ${p.sign} (house ${p.house}) - ${isExalted(check.lord, p.sign) ? "exalted" : "own sign"} in kendra`,
                    strength: isExalted(check.lord, p.sign) ? "Strong" : "Moderate",
                    planets: [check.lord],
                });
            }
        }
    }

    // ========================================
    // 2. GAJA KESARI YOGA
    // Jupiter in kendra from Moon
    // ========================================
    if (jupiter && moon && jupiter.degree != null && moon.degree != null) {
        const jupFromMoon = getHouseNumber(jupiter.degree, moon.degree);
        if (jupFromMoon && KENDRA_HOUSES.includes(jupFromMoon)) {
            rajYogas.push({
                name: "Gaja Kesari Yoga",
                type: "Raj Yoga",
                description: `Jupiter in kendra (house ${jupFromMoon}) from Moon - wisdom, respect, and fortune`,
                strength: "Strong",
                planets: ["Jupiter", "Moon"],
            });
        }
    }

    // ========================================
    // 3. BUDHADITYA YOGA
    // Sun and Mercury conjunction
    // ========================================
    if (sun && mercury && sun.degree != null && mercury.degree != null) {
        const diff = Math.abs(sun.degree - mercury.degree);
        const angle = Math.min(diff, 360 - diff);
        if (angle < 10) { // Within 10 degrees
            rajYogas.push({
                name: "Budhaditya Yoga",
                type: "Raj Yoga",
                description: "Sun-Mercury conjunction in same sign - intelligence, fame, and success",
                strength: angle < 5 ? "Strong" : "Moderate",
                planets: ["Sun", "Mercury"],
            });
        }
    }

    // ========================================
    // 4. LAKSHMI YOGA
    // Venus in own/exalted sign in kendra/trikona, 9th lord strong
    // ========================================
    if (venus && venus.house && venus.sign) {
        const venusInKendraTrikona = KENDRA_HOUSES.includes(venus.house) || TRIKONA_HOUSES.includes(venus.house);
        const venusStrong = isInOwnSign("Venus", venus.sign) || isExalted("Venus", venus.sign);
        if (venusInKendraTrikona && venusStrong) {
            rajYogas.push({
                name: "Lakshmi Yoga",
                type: "Dhana Yoga",
                description: `Venus ${isExalted("Venus", venus.sign) ? "exalted" : "in own sign"} in house ${venus.house} - wealth and prosperity`,
                strength: "Strong",
                planets: ["Venus"],
            });
        }
    }

    // ========================================
    // 5. CHANDRA-MANGAL YOGA
    // Moon-Mars conjunction
    // ========================================
    if (moon && mars && moon.degree != null && mars.degree != null) {
        const diff = Math.abs(moon.degree - mars.degree);
        const angle = Math.min(diff, 360 - diff);
        if (angle < 10) {
            rajYogas.push({
                name: "Chandra-Mangal Yoga",
                type: "Dhana Yoga",
                description: "Moon-Mars conjunction - wealth through courage and enterprise",
                strength: angle < 5 ? "Strong" : "Moderate",
                planets: ["Moon", "Mars"],
            });
        }
    }

    // ========================================
    // 6. GURU-MANGAL YOGA
    // Jupiter-Mars conjunction or aspect
    // ========================================
    if (jupiter && mars && jupiter.degree != null && mars.degree != null) {
        const diff = Math.abs(jupiter.degree - mars.degree);
        const angle = Math.min(diff, 360 - diff);
        if (angle < 10) {
            rajYogas.push({
                name: "Guru-Mangal Yoga",
                type: "Raj Yoga",
                description: "Jupiter-Mars conjunction - courage combined with wisdom, leadership",
                strength: angle < 5 ? "Strong" : "Moderate",
                planets: ["Jupiter", "Mars"],
            });
        }
    }

    // ========================================
    // HELPER: Get house lord based on ascendant sign
    // Must be defined before use in yoga calculations
    // ========================================
    const getHouseLord = (houseNumber, ascSignName) => {
        if (!ascSignName) return null;
        const ascSignIdx = VEDIC_SIGNS.findIndex(
            (s) => s.toLowerCase() === ascSignName.toLowerCase()
        );
        if (ascSignIdx < 0) return null;

        // Calculate which sign rules the house
        const houseSignIdx = (ascSignIdx + houseNumber - 1) % 12;
        const houseSign = VEDIC_SIGNS[houseSignIdx];

        // Find which planet rules that sign
        for (const [planet, signs] of Object.entries(PLANET_RULERSHIP)) {
            if (signs.some((s) => s.toLowerCase() === houseSign.toLowerCase())) {
                return planet;
            }
        }
        return null;
    };

    // ========================================
    // 7. DHARMAKARMADHIPATI YOGA
    // 9th lord (Dharma) and 10th lord (Karma) in conjunction or mutual aspect
    // This is the most powerful Raj Yoga - combining fortune with action
    // ========================================
    const ninth_lord_dkd = getHouseLord(9, ascSign);
    const tenth_lord_dkd = getHouseLord(10, ascSign);
    
    if (ninth_lord_dkd && tenth_lord_dkd && ninth_lord_dkd !== tenth_lord_dkd) {
        const ninthLordInfo = getPlanetInfo(ninth_lord_dkd);
        const tenthLordInfo = getPlanetInfo(tenth_lord_dkd);
        
        if (ninthLordInfo && tenthLordInfo && 
            ninthLordInfo.degree != null && tenthLordInfo.degree != null) {
            // Check conjunction
            const diff = Math.abs(ninthLordInfo.degree - tenthLordInfo.degree);
            const angle = Math.min(diff, 360 - diff);
            
            if (angle < 15) {
                rajYogas.push({
                    name: "Dharmakarmadhipati Yoga",
                    type: "Raj Yoga",
                    description: `${ninth_lord_dkd} (9th lord) conjunct ${tenth_lord_dkd} (10th lord) - destiny aligned with action, success through righteous deeds`,
                    strength: angle < 8 ? "Strong" : "Moderate",
                    planets: [ninth_lord_dkd, tenth_lord_dkd],
                });
            }
            
            // Also check mutual exchange (Parivartana)
            if (ninthLordInfo.house === 10 && tenthLordInfo.house === 9) {
                rajYogas.push({
                    name: "Dharmakarmadhipati Yoga",
                    type: "Raj Yoga",
                    description: `${ninth_lord_dkd} (9th lord) exchanging houses with ${tenth_lord_dkd} (10th lord) - powerful career and fortune combination`,
                    strength: "Strong",
                    planets: [ninth_lord_dkd, tenth_lord_dkd],
                });
            }
        }
    }

    // ========================================
    // 8. VIPARITA RAJA YOGA (Harsh Vipreet Raj Yoga)
    // Lord of 6th, 8th, or 12th house placed in another dusthana (6th, 8th, 12th)
    // This creates "success through adversity" - turning challenges into triumphs
    // ========================================
    const dusthanaHouses = [6, 8, 12];

    // Check Viparita Raja Yoga
    const sixth_lord = getHouseLord(6, ascSign);
    const eighth_lord = getHouseLord(8, ascSign);
    const twelfth_lord = getHouseLord(12, ascSign);

    const dusthanaLords = [
        { lord: sixth_lord, house: 6 },
        { lord: eighth_lord, house: 8 },
        { lord: twelfth_lord, house: 12 },
    ].filter((d) => d.lord);

    for (const { lord, house } of dusthanaLords) {
        const lordInfo = getPlanetInfo(lord);
        if (lordInfo && lordInfo.house && dusthanaHouses.includes(lordInfo.house)) {
            // Lord of a dusthana is in a dusthana (can be same or different)
            rajYogas.push({
                name: "Viparita Raja Yoga",
                type: "Raj Yoga (Viparita)",
                description: `${lord} (lord of house ${house}) in dusthana house ${lordInfo.house} - success through overcoming obstacles`,
                strength: "Moderate",
                planets: [lord],
            });
            break; // Only count once
        }
    }

    // ========================================
    // 9. SHAKATA YOGA
    // Moon in 6th, 8th, or 12th house from Jupiter
    // This can cause fluctuating fortunes
    // ========================================
    if (moon && jupiter && moon.degree != null && jupiter.degree != null) {
        const moonFromJup = getHouseNumber(moon.degree, jupiter.degree);
        if (moonFromJup && [6, 8, 12].includes(moonFromJup)) {
            rajYogas.push({
                name: "Shakata Yoga",
                type: "Yoga",
                description: `Moon in house ${moonFromJup} from Jupiter - fluctuating fortunes, resilience needed`,
                strength: "Present",
                planets: ["Moon", "Jupiter"],
            });
        }
    }

    // ========================================
    // 10. DHAN YOGA (Wealth Yoga)
    // Multiple combinations involving 2nd (wealth) and 11th (gains) houses
    // ========================================
    const second_lord = getHouseLord(2, ascSign);
    const eleventh_lord = getHouseLord(11, ascSign);

    // Check if 2nd and 11th lords are connected (conjunction or in each other's houses)
    if (second_lord && eleventh_lord) {
        const secondLordInfo = getPlanetInfo(second_lord);
        const eleventhLordInfo = getPlanetInfo(eleventh_lord);

        if (secondLordInfo && eleventhLordInfo) {
            // Check conjunction
            if (secondLordInfo.degree != null && eleventhLordInfo.degree != null) {
                const diff = Math.abs(secondLordInfo.degree - eleventhLordInfo.degree);
                const angle = Math.min(diff, 360 - diff);
                if (angle < 15) {
                    rajYogas.push({
                        name: "Dhan Yoga",
                        type: "Dhana Yoga",
                        description: `${second_lord} (2nd lord) conjunct ${eleventh_lord} (11th lord) - wealth accumulation`,
                        strength: angle < 8 ? "Strong" : "Moderate",
                        planets: [second_lord, eleventh_lord],
                    });
                }
            }

            // Check mutual exchange (each in other's house)
            if (
                secondLordInfo.house === 11 &&
                eleventhLordInfo.house === 2
            ) {
                rajYogas.push({
                    name: "Dhan Yoga",
                    type: "Dhana Yoga",
                    description: `Parivartana between 2nd lord (${second_lord}) and 11th lord (${eleventh_lord}) - financial prosperity`,
                    strength: "Strong",
                    planets: [second_lord, eleventh_lord],
                });
            }
        }
    }

    // Jupiter or Venus in 2nd or 11th house also forms Dhan Yoga
    if (jupiter && jupiter.house && [2, 11].includes(jupiter.house)) {
        rajYogas.push({
            name: "Dhan Yoga",
            type: "Dhana Yoga",
            description: `Jupiter in house ${jupiter.house} - natural benefic in wealth/gains house`,
            strength: "Moderate",
            planets: ["Jupiter"],
        });
    }
    if (venus && venus.house && [2, 11].includes(venus.house)) {
        rajYogas.push({
            name: "Dhan Yoga",
            type: "Dhana Yoga",
            description: `Venus in house ${venus.house} - natural benefic in wealth/gains house`,
            strength: "Moderate",
            planets: ["Venus"],
        });
    }

    // ========================================
    // 11. UBHAYACHARI YOGA
    // Planets (other than Moon, Rahu, Ketu) on both sides of Sun
    // Creates influence, fame and success
    // ========================================
    if (sun && sun.degree != null) {
        const planetsForUbhayachari = [mars, mercury, jupiter, venus, saturn].filter(
            (p) => p && p.degree != null
        );

        // Check for planets in houses immediately before and after Sun
        const sunHouse = sun.house;
        if (sunHouse) {
            const houseBefore = sunHouse === 1 ? 12 : sunHouse - 1;
            const houseAfter = sunHouse === 12 ? 1 : sunHouse + 1;

            const planetBefore = planetsForUbhayachari.find((p) => p.house === houseBefore);
            const planetAfter = planetsForUbhayachari.find((p) => p.house === houseAfter);

            if (planetBefore && planetAfter) {
                rajYogas.push({
                    name: "Ubhayachari Yoga",
                    type: "Raj Yoga",
                    description: `${planetBefore.name} and ${planetAfter.name} flanking Sun - fame, influence, and success`,
                    strength: "Strong",
                    planets: [planetBefore.name, "Sun", planetAfter.name],
                });
            }
        }
    }

    // ========================================
    // 12. PARASHARI RAJ YOGA
    // Lords of Kendra (1,4,7,10) and Trikona (1,5,9) in mutual association
    // Most powerful Raj Yoga formation
    // ========================================
    const kendraLords = [1, 4, 7, 10]
        .map((h) => ({ house: h, lord: getHouseLord(h, ascSign) }))
        .filter((d) => d.lord);
    const trikonaLords = [5, 9]
        .map((h) => ({ house: h, lord: getHouseLord(h, ascSign) }))
        .filter((d) => d.lord);

    for (const kendra of kendraLords) {
        for (const trikona of trikonaLords) {
            if (kendra.lord === trikona.lord) continue; // Same planet can't form yoga with itself

            const kendraInfo = getPlanetInfo(kendra.lord);
            const trikonaInfo = getPlanetInfo(trikona.lord);

            if (!kendraInfo || !trikonaInfo) continue;
            if (kendraInfo.degree == null || trikonaInfo.degree == null) continue;

            // Check conjunction
            const diff = Math.abs(kendraInfo.degree - trikonaInfo.degree);
            const angle = Math.min(diff, 360 - diff);

            if (angle < 15) {
                rajYogas.push({
                    name: "Parashari Raj Yoga",
                    type: "Raj Yoga",
                    description: `${kendra.lord} (${kendra.house}th lord) conjunct ${trikona.lord} (${trikona.house}th lord) - power, authority, success`,
                    strength: angle < 8 ? "Strong" : "Moderate",
                    planets: [kendra.lord, trikona.lord],
                });
                break; // Found one, that's enough
            }
        }
    }

    // ========================================
    // 13. NEECHA BHANGA RAJA YOGA
    // Debilitated planet's weakness gets cancelled (multiple conditions)
    // Reference: BPHS Chapter 28 - Neecha Bhanga Rules
    // ========================================
    const debilitationSigns = {
        Sun: "Libra",
        Moon: "Scorpio",
        Mars: "Cancer",
        Mercury: "Pisces",
        Jupiter: "Capricorn",
        Venus: "Virgo",
        Saturn: "Aries",
    };
    
    // Lords of debilitation signs (who rules the sign where planet is debilitated)
    const debSignLords = {
        Sun: "Venus",      // Libra lord
        Moon: "Mars",      // Scorpio lord
        Mars: "Moon",      // Cancer lord
        Mercury: "Jupiter", // Pisces lord
        Jupiter: "Saturn",  // Capricorn lord
        Venus: "Mercury",   // Virgo lord
        Saturn: "Mars",     // Aries lord
    };
    
    // Lords of exaltation signs (who rules the sign where planet gets exalted)
    const exaltSignLords = {
        Sun: "Mars",       // Aries lord
        Moon: "Venus",     // Taurus lord
        Mars: "Saturn",    // Capricorn lord
        Mercury: "Mercury", // Virgo lord (own sign)
        Jupiter: "Moon",   // Cancer lord
        Venus: "Jupiter",  // Pisces lord
        Saturn: "Venus",   // Libra lord
    };

    for (const [planetName, debSign] of Object.entries(debilitationSigns)) {
        const p = getPlanetInfo(planetName);
        if (!p || !p.sign) continue;
        if (p.sign.toLowerCase() !== debSign.toLowerCase()) continue;
        
        // Planet is debilitated - now check for cancellation
        let cancellationFound = false;
        let cancellationType = "";
        
        // Rule 1: Debilitated planet in Kendra
        if (p.house && KENDRA_HOUSES.includes(p.house)) {
            cancellationFound = true;
            cancellationType = `in kendra (house ${p.house})`;
        }
        
        // Rule 2: Lord of debilitation sign in Kendra from Lagna
        const debLord = debSignLords[planetName];
        if (debLord) {
            const debLordInfo = getPlanetInfo(debLord);
            if (debLordInfo && debLordInfo.house && KENDRA_HOUSES.includes(debLordInfo.house)) {
                cancellationFound = true;
                cancellationType = `${debLord} (lord of ${debSign}) in kendra`;
            }
        }
        
        // Rule 3: Lord of exaltation sign in Kendra from Lagna
        const exaltLord = exaltSignLords[planetName];
        if (exaltLord && exaltLord !== planetName) {
            const exaltLordInfo = getPlanetInfo(exaltLord);
            if (exaltLordInfo && exaltLordInfo.house && KENDRA_HOUSES.includes(exaltLordInfo.house)) {
                cancellationFound = true;
                cancellationType = `${exaltLord} (exaltation lord) in kendra`;
            }
        }
        
        // Rule 4: Debilitated planet conjunct or aspected by exaltation lord
        if (exaltLord && exaltLord !== planetName) {
            const exaltLordInfo = getPlanetInfo(exaltLord);
            if (exaltLordInfo && p.degree != null && exaltLordInfo.degree != null) {
                const diff = Math.abs(p.degree - exaltLordInfo.degree);
                const angle = Math.min(diff, 360 - diff);
                if (angle < 12) { // Conjunction
                    cancellationFound = true;
                    cancellationType = `conjunct ${exaltLord}`;
                }
            }
        }
        
        if (cancellationFound) {
            rajYogas.push({
                name: "Neecha Bhanga Raja Yoga",
                type: "Raj Yoga (Cancellation)",
                description: `${planetName} debilitated in ${p.sign} but ${cancellationType} - rise after initial struggles, eventual success`,
                strength: "Moderate",
                planets: [planetName],
            });
        }
    }

    // ========================================
    // 14. ADHI YOGA
    // Benefics (Jupiter, Venus, Mercury) in 6th, 7th, 8th from Moon
    // Creates leadership and authority
    // ========================================
    if (moon && moon.degree != null) {
        const benefics = [jupiter, venus, mercury].filter((p) => p && p.degree != null);
        const adhiHouses = [6, 7, 8];
        const beneficsInAdhi = benefics.filter((p) => {
            const houseFromMoon = getHouseNumber(p.degree, moon.degree);
            return houseFromMoon && adhiHouses.includes(houseFromMoon);
        });

        if (beneficsInAdhi.length >= 2) {
            rajYogas.push({
                name: "Adhi Yoga",
                type: "Raj Yoga",
                description: `${beneficsInAdhi.map((p) => p.name).join(", ")} in 6th/7th/8th from Moon - leadership and authority`,
                strength: beneficsInAdhi.length >= 3 ? "Strong" : "Moderate",
                planets: beneficsInAdhi.map((p) => p.name),
            });
        }
    }

    // ========================================
    // 15. AMALA YOGA
    // Benefic in 10th from Moon or Ascendant
    // Creates purity of character and fame
    // ========================================
    const beneficPlanets = [jupiter, venus, mercury].filter((p) => p && p.house);
    for (const benefic of beneficPlanets) {
        // Check 10th from Ascendant
        if (benefic.house === 10) {
            rajYogas.push({
                name: "Amala Yoga",
                type: "Raj Yoga",
                description: `${benefic.name} in 10th house - fame through righteous deeds`,
                strength: "Moderate",
                planets: [benefic.name],
            });
            break;
        }
        // Check 10th from Moon
        if (moon && moon.degree != null && benefic.degree != null) {
            const houseFromMoon = getHouseNumber(benefic.degree, moon.degree);
            if (houseFromMoon === 10) {
                rajYogas.push({
                    name: "Amala Yoga",
                    type: "Raj Yoga",
                    description: `${benefic.name} in 10th from Moon - pure character and reputation`,
                    strength: "Moderate",
                    planets: [benefic.name, "Moon"],
                });
                break;
            }
        }
    }

    // ========================================
    // 16. SARASWATI YOGA
    // Jupiter, Venus, Mercury in kendra/trikona/2nd house together
    // Grants wisdom, learning, and eloquence
    // ========================================
    const saraswatiHouses = [...KENDRA_HOUSES, ...TRIKONA_HOUSES, 2];
    const jupInSaraswati = jupiter && jupiter.house && saraswatiHouses.includes(jupiter.house);
    const venInSaraswati = venus && venus.house && saraswatiHouses.includes(venus.house);
    const merInSaraswati = mercury && mercury.house && saraswatiHouses.includes(mercury.house);

    if (jupInSaraswati && venInSaraswati && merInSaraswati) {
        rajYogas.push({
            name: "Saraswati Yoga",
            type: "Raj Yoga",
            description: "Jupiter, Venus, Mercury in auspicious houses - wisdom, learning, and artistic talents",
            strength: "Strong",
            planets: ["Jupiter", "Venus", "Mercury"],
        });
    }

    // ========================================
    // 17. VESHI YOGA
    // Planet (other than Moon) in 2nd house from Sun
    // Grants wealth and influence
    // ========================================
    if (sun && sun.house) {
        const houseAfterSun = sun.house === 12 ? 1 : sun.house + 1;
        const planetsExceptMoon = [mars, mercury, jupiter, venus, saturn].filter(
            (p) => p && p.house === houseAfterSun
        );
        if (planetsExceptMoon.length > 0) {
            rajYogas.push({
                name: "Veshi Yoga",
                type: "Raj Yoga",
                description: `${planetsExceptMoon.map((p) => p.name).join(", ")} in 2nd from Sun - wealth and authority`,
                strength: "Moderate",
                planets: [...planetsExceptMoon.map((p) => p.name), "Sun"],
            });
        }
    }

    // ========================================
    // 18. VOSHI YOGA
    // Planet (other than Moon) in 12th house from Sun
    // Grants charitable nature and spiritual growth
    // ========================================
    if (sun && sun.house) {
        const houseBeforeSun = sun.house === 1 ? 12 : sun.house - 1;
        const planetsExceptMoon = [mars, mercury, jupiter, venus, saturn].filter(
            (p) => p && p.house === houseBeforeSun
        );
        if (planetsExceptMoon.length > 0) {
            rajYogas.push({
                name: "Voshi Yoga",
                type: "Raj Yoga",
                description: `${planetsExceptMoon.map((p) => p.name).join(", ")} in 12th from Sun - charitable nature`,
                strength: "Moderate",
                planets: [...planetsExceptMoon.map((p) => p.name), "Sun"],
            });
        }
    }

    // ========================================
    // 19. SUNAPHA YOGA
    // Planet (other than Sun, Rahu, Ketu) in 2nd from Moon
    // Grants self-made wealth and intelligence
    // ========================================
    if (moon && moon.house) {
        const houseAfterMoon = moon.house === 12 ? 1 : moon.house + 1;
        const validPlanets = [mars, mercury, jupiter, venus, saturn].filter(
            (p) => p && p.house === houseAfterMoon
        );
        if (validPlanets.length > 0) {
            rajYogas.push({
                name: "Sunapha Yoga",
                type: "Raj Yoga",
                description: `${validPlanets.map((p) => p.name).join(", ")} in 2nd from Moon - self-made success`,
                strength: "Moderate",
                planets: [...validPlanets.map((p) => p.name), "Moon"],
            });
        }
    }

    // ========================================
    // 20. ANAPHA YOGA
    // Planet (other than Sun, Rahu, Ketu) in 12th from Moon
    // Grants good health and reputation
    // ========================================
    if (moon && moon.house) {
        const houseBeforeMoon = moon.house === 1 ? 12 : moon.house - 1;
        const validPlanets = [mars, mercury, jupiter, venus, saturn].filter(
            (p) => p && p.house === houseBeforeMoon
        );
        if (validPlanets.length > 0) {
            rajYogas.push({
                name: "Anapha Yoga",
                type: "Raj Yoga",
                description: `${validPlanets.map((p) => p.name).join(", ")} in 12th from Moon - good health and fame`,
                strength: "Moderate",
                planets: [...validPlanets.map((p) => p.name), "Moon"],
            });
        }
    }

    // ========================================
    // 21. DURUDHARA YOGA
    // Planets on both sides of Moon (2nd and 12th from Moon)
    // Grants wealth, vehicles, and comforts
    // ========================================
    if (moon && moon.house) {
        const houseAfterMoon = moon.house === 12 ? 1 : moon.house + 1;
        const houseBeforeMoon = moon.house === 1 ? 12 : moon.house - 1;
        const validPlanets = [mars, mercury, jupiter, venus, saturn].filter((p) => p && p.house);

        const planetAfter = validPlanets.find((p) => p.house === houseAfterMoon);
        const planetBefore = validPlanets.find((p) => p.house === houseBeforeMoon);

        if (planetAfter && planetBefore) {
            rajYogas.push({
                name: "Durudhara Yoga",
                type: "Raj Yoga",
                description: `${planetBefore.name} and ${planetAfter.name} flanking Moon - wealth and comforts`,
                strength: "Strong",
                planets: [planetBefore.name, "Moon", planetAfter.name],
            });
        }
    }

    // ========================================
    // 22. KAHALA YOGA
    // 4th and 9th lords in mutual kendra or strong positions
    // Grants courage and leadership
    // ========================================
    const fourth_lord = getHouseLord(4, ascSign);
    const ninth_lord = getHouseLord(9, ascSign);
    if (fourth_lord && ninth_lord && fourth_lord !== ninth_lord) {
        const fourthLordInfo = getPlanetInfo(fourth_lord);
        const ninthLordInfo = getPlanetInfo(ninth_lord);

        if (fourthLordInfo && ninthLordInfo && fourthLordInfo.house && ninthLordInfo.house) {
            const bothInKendra =
                KENDRA_HOUSES.includes(fourthLordInfo.house) &&
                KENDRA_HOUSES.includes(ninthLordInfo.house);
            if (bothInKendra) {
                rajYogas.push({
                    name: "Kahala Yoga",
                    type: "Raj Yoga",
                    description: `${fourth_lord} (4th lord) and ${ninth_lord} (9th lord) both in kendras - courage and leadership`,
                    strength: "Moderate",
                    planets: [fourth_lord, ninth_lord],
                });
            }
        }
    }

    // ========================================
    // 23. KESARI YOGA (variant of Gaja Kesari)
    // Jupiter and Moon in mutual kendras
    // ========================================
    if (jupiter && moon && jupiter.house && moon.house) {
        const jupFromMoonHouse = getHouseNumber(jupiter.degree, moon.degree);
        const moonFromJupHouse = getHouseNumber(moon.degree, jupiter.degree);
        if (
            jupFromMoonHouse &&
            moonFromJupHouse &&
            KENDRA_HOUSES.includes(jupFromMoonHouse) &&
            KENDRA_HOUSES.includes(moonFromJupHouse)
        ) {
            // Already covered by Gaja Kesari, but adding strength indication
        }
    }

    // ========================================
    // 24. CHAMARA YOGA
    // Ascendant lord in Kendra, aspected by Jupiter
    // Grants learning, longevity, and fame
    // Using proper Vedic house-based aspects
    // ========================================
    const first_lord = getHouseLord(1, ascSign);
    if (first_lord && jupiter) {
        const firstLordInfo = getPlanetInfo(first_lord);
        if (firstLordInfo && firstLordInfo.house && KENDRA_HOUSES.includes(firstLordInfo.house)) {
            // Check if Jupiter aspects using Vedic method (house-based)
            // Jupiter's full aspect: 7th house, special aspects: 5th and 9th
            if (jupiter.house && firstLordInfo.house) {
                let jupiterHouseFromLord = ((firstLordInfo.house - jupiter.house + 12) % 12);
                if (jupiterHouseFromLord === 0) jupiterHouseFromLord = 12;
                
                // Jupiter aspects 5th, 7th, 9th houses from itself
                const isAspectedByJupiter = [5, 7, 9].includes(jupiterHouseFromLord) || 
                    jupiter.house === firstLordInfo.house; // Conjunction
                
                if (isAspectedByJupiter) {
                    rajYogas.push({
                        name: "Chamara Yoga",
                        type: "Raj Yoga",
                        description: `${first_lord} (lagna lord) in kendra aspected by Jupiter - learning and fame`,
                        strength: "Moderate",
                        planets: [first_lord, "Jupiter"],
                    });
                }
            }
        }
    }

    // ========================================
    // 25. YOGAKARAKA YOGA
    // When the Yogakaraka planet for a specific ascendant is strong
    // Yogakaraka rules both Kendra and Trikona - extremely beneficial
    // ========================================
    const yogakarakaPlanet = YOGAKARAKA[ascSign];
    if (yogakarakaPlanet) {
        const yogakarakaInfo = getPlanetInfo(yogakarakaPlanet);
        if (yogakarakaInfo && yogakarakaInfo.house && yogakarakaInfo.sign) {
            const isInKendraTrikona = KENDRA_HOUSES.includes(yogakarakaInfo.house) || 
                                      TRIKONA_HOUSES.includes(yogakarakaInfo.house);
            const isStrong = isInOwnSign(yogakarakaPlanet, yogakarakaInfo.sign) || 
                            isExalted(yogakarakaPlanet, yogakarakaInfo.sign);
            
            if (isInKendraTrikona || isStrong) {
                rajYogas.push({
                    name: "Yogakaraka Yoga",
                    type: "Raj Yoga",
                    description: `${yogakarakaPlanet} is Yogakaraka for ${ascSign} lagna, placed in house ${yogakarakaInfo.house}${isStrong ? " in strength" : ""} - exceptional fortune and success`,
                    strength: isStrong ? "Strong" : "Moderate",
                    planets: [yogakarakaPlanet],
                    isYogakaraka: true,
                });
            }
        }
    }

    // ========================================
    // 26. KEMADRUMA YOGA CHECK (Important negative yoga)
    // Moon without planets in 2nd/12th causes difficulties
    // We add this as a warning, not as a positive yoga
    // ========================================
    if (moon && moon.house && ascDegree != null) {
        const house2ndFromMoon = moon.house === 12 ? 1 : moon.house + 1;
        const house12thFromMoon = moon.house === 1 ? 12 : moon.house - 1;
        
        const relevantPlanets = [mars, mercury, jupiter, venus, saturn].filter(p => p && p.house);
        const planetIn2nd = relevantPlanets.find(p => p.house === house2ndFromMoon);
        const planetIn12th = relevantPlanets.find(p => p.house === house12thFromMoon);
        
        if (!planetIn2nd && !planetIn12th) {
            // Check for cancellation - Moon in Kendra from Lagna
            const isMoonInKendra = KENDRA_HOUSES.includes(moon.house);
            
            if (!isMoonInKendra) {
                rajYogas.push({
                    name: "Kemadruma Yoga",
                    type: "Challenging Yoga",
                    description: "Moon without planets in adjacent houses - may indicate periods of struggle. Jupiter's aspect or Moon's strength can mitigate.",
                    strength: "Present",
                    planets: ["Moon"],
                    isChallenging: true,
                });
            }
        }
    }

    // ========================================
    // 27. RAJA YOGA (Kendra-Trikona Connection)
    // When lord of Kendra is in Trikona OR lord of Trikona is in Kendra
    // This is the classical definition from BPHS
    // ========================================
    for (const kendraHouse of [1, 4, 7, 10]) {
        const kendraLord = getHouseLord(kendraHouse, ascSign);
        if (!kendraLord) continue;
        
        const kendraLordInfo = getPlanetInfo(kendraLord);
        if (!kendraLordInfo || !kendraLordInfo.house) continue;
        
        // Kendra lord in Trikona (5 or 9)
        if ([5, 9].includes(kendraLordInfo.house)) {
            rajYogas.push({
                name: "Raja Yoga",
                type: "Raj Yoga",
                description: `${kendraLord} (${kendraHouse}th lord) in ${kendraLordInfo.house}th house (Trikona) - authority and success`,
                strength: "Moderate",
                planets: [kendraLord],
            });
            break; // One is enough
        }
    }
    
    for (const trikonaHouse of [5, 9]) {
        const trikonaLord = getHouseLord(trikonaHouse, ascSign);
        if (!trikonaLord) continue;
        
        const trikonaLordInfo = getPlanetInfo(trikonaLord);
        if (!trikonaLordInfo || !trikonaLordInfo.house) continue;
        
        // Trikona lord in Kendra
        if (KENDRA_HOUSES.includes(trikonaLordInfo.house)) {
            // Avoid duplicate if already added
            const alreadyAdded = rajYogas.some(y => 
                y.name === "Raja Yoga" && y.planets.includes(trikonaLord)
            );
            if (!alreadyAdded) {
                rajYogas.push({
                    name: "Raja Yoga",
                    type: "Raj Yoga",
                    description: `${trikonaLord} (${trikonaHouse}th lord) in ${trikonaLordInfo.house}th house (Kendra) - fortune through action`,
                    strength: "Moderate",
                    planets: [trikonaLord],
                });
                break;
            }
        }
    }

    // Remove duplicates by name (keep first occurrence)
    const uniqueYogas = [];
    const seen = new Set();
    for (const yoga of rajYogas) {
        if (!seen.has(yoga.name)) {
            seen.add(yoga.name);
            uniqueYogas.push(yoga);
        }
    }

    logger.info(`✨ Calculated ${uniqueYogas.length} Raj Yogas`);
    return uniqueYogas;
}

// ============================================================================
// ASHTAKAVARGA CALCULATIONS
// Based on Brihat Parashara Hora Shastra (BPHS) - Classical Vedic Astrology
//
// TODO: FreeAstrologyAPI has Ashtakavarga "Coming Soon" - when available,
// replace this local calculation with API call for better accuracy and
// consistency with other astrological data.
// API endpoint will likely be: /ashtakavarga or /ashtaka-varga
// ============================================================================

/**
 * Ashtakavarga Bindu Tables (BPHS standard)
 * Each planet gives bindus from specific houses counted from itself and other reference points.
 * Format: { planet: [houses from which it gives bindu] }
 * Houses are 1-indexed positions from the reference point.
 */
const ASHTAKAVARGA_TABLES = {
    // Sun gives bindus from these houses (from each reference planet)
    Sun: {
        fromSun: [1, 2, 4, 7, 8, 9, 10, 11],
        fromMoon: [3, 6, 10, 11],
        fromMars: [1, 2, 4, 7, 8, 9, 10, 11],
        fromMercury: [3, 5, 6, 9, 10, 11, 12],
        fromJupiter: [5, 6, 9, 11],
        fromVenus: [6, 7, 12],
        fromSaturn: [1, 2, 4, 7, 8, 9, 10, 11],
        fromLagna: [3, 4, 6, 10, 11, 12],
    },
    // Moon gives bindus from these houses
    Moon: {
        fromSun: [3, 6, 7, 8, 10, 11],
        fromMoon: [1, 3, 6, 7, 10, 11],
        fromMars: [2, 3, 5, 6, 9, 10, 11],
        fromMercury: [1, 3, 4, 5, 7, 8, 10, 11],
        fromJupiter: [1, 4, 7, 8, 10, 11, 12],
        fromVenus: [3, 4, 5, 7, 9, 10, 11],
        fromSaturn: [3, 5, 6, 11],
        fromLagna: [3, 6, 10, 11],
    },
    // Mars gives bindus from these houses
    Mars: {
        fromSun: [3, 5, 6, 10, 11],
        fromMoon: [3, 6, 11],
        fromMars: [1, 2, 4, 7, 8, 10, 11],
        fromMercury: [3, 5, 6, 11],
        fromJupiter: [6, 10, 11, 12],
        fromVenus: [6, 8, 11, 12],
        fromSaturn: [1, 4, 7, 8, 9, 10, 11],
        fromLagna: [1, 3, 6, 10, 11],
    },
    // Mercury gives bindus from these houses
    Mercury: {
        fromSun: [5, 6, 9, 11, 12],
        fromMoon: [2, 4, 6, 8, 10, 11],
        fromMars: [1, 2, 4, 7, 8, 9, 10, 11],
        fromMercury: [1, 3, 5, 6, 9, 10, 11, 12],
        fromJupiter: [6, 8, 11, 12],
        fromVenus: [1, 2, 3, 4, 5, 8, 9, 11],
        fromSaturn: [1, 2, 4, 7, 8, 9, 10, 11],
        fromLagna: [1, 2, 4, 6, 8, 10, 11],
    },
    // Jupiter gives bindus from these houses
    Jupiter: {
        fromSun: [1, 2, 3, 4, 7, 8, 9, 10, 11],
        fromMoon: [2, 5, 7, 9, 11],
        fromMars: [1, 2, 4, 7, 8, 10, 11],
        fromMercury: [1, 2, 4, 5, 6, 9, 10, 11],
        fromJupiter: [1, 2, 3, 4, 7, 8, 10, 11],
        fromVenus: [2, 5, 6, 9, 10, 11],
        fromSaturn: [3, 5, 6, 12],
        fromLagna: [1, 2, 4, 5, 6, 7, 9, 10, 11],
    },
    // Venus gives bindus from these houses
    Venus: {
        fromSun: [8, 11, 12],
        fromMoon: [1, 2, 3, 4, 5, 8, 9, 11, 12],
        fromMars: [3, 5, 6, 9, 11, 12],
        fromMercury: [3, 5, 6, 9, 11],
        fromJupiter: [5, 8, 9, 10, 11],
        fromVenus: [1, 2, 3, 4, 5, 8, 9, 10, 11],
        fromSaturn: [3, 4, 5, 8, 9, 10, 11],
        fromLagna: [1, 2, 3, 4, 5, 8, 9, 11],
    },
    // Saturn gives bindus from these houses
    Saturn: {
        fromSun: [1, 2, 4, 7, 8, 10, 11],
        fromMoon: [3, 6, 11],
        fromMars: [3, 5, 6, 10, 11, 12],
        fromMercury: [6, 8, 9, 10, 11, 12],
        fromJupiter: [5, 6, 11, 12],
        fromVenus: [6, 11, 12],
        fromSaturn: [3, 5, 6, 11],
        fromLagna: [1, 3, 4, 6, 10, 11],
    },
};

/**
 * Get sign index (0-11) from planet position
 * @param {Object} planet - Planet object with sign or fullDegree
 * @returns {number|null} Sign index (0-11) or null
 */
function getSignIndex(planet) {
    if (!planet) return null;
    
    // If we have fullDegree, calculate sign from that
    if (planet.fullDegree != null || planet.full_degree != null) {
        const deg = planet.fullDegree ?? planet.full_degree;
        return Math.floor(((deg % 360) + 360) % 360 / 30);
    }
    
    // Otherwise try to get from sign name
    const signName = planet.sign || planet.signName;
    if (!signName) return null;
    
    const idx = VEDIC_SIGNS.findIndex(s => s.toLowerCase() === signName.toLowerCase());
    return idx >= 0 ? idx : null;
}

/**
 * Calculate Bhinnashtakavarga (BAV) for a single planet
 * BAV shows how many bindus each planet contributes to each of the 12 signs
 * 
 * @param {string} planet - Planet name (Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn)
 * @param {Object} planetPositions - Object containing all planet positions { Sun: {sign/fullDegree}, Moon: {...}, etc. }
 * @param {number} lagnaSignIndex - Sign index (0-11) of the Lagna/Ascendant
 * @returns {Object} BAV scores for each sign { Aries: 3, Taurus: 5, ... }
 */
export function calculateBhinnashtakavarga(planet, planetPositions, lagnaSignIndex) {
    const table = ASHTAKAVARGA_TABLES[planet];
    if (!table) return null;
    
    // Initialize scores for each sign (0-11)
    const scores = Array(12).fill(0);
    
    // Map reference names to actual planet data
    const refMap = {
        fromSun: planetPositions.Sun,
        fromMoon: planetPositions.Moon,
        fromMars: planetPositions.Mars,
        fromMercury: planetPositions.Mercury,
        fromJupiter: planetPositions.Jupiter,
        fromVenus: planetPositions.Venus,
        fromSaturn: planetPositions.Saturn,
        fromLagna: { signIndex: lagnaSignIndex }, // Lagna as pseudo-planet
    };
    
    // For each reference point, calculate contributions
    for (const [refKey, refPlanet] of Object.entries(refMap)) {
        const bindusFromRef = table[refKey];
        if (!bindusFromRef) continue;
        
        // Get the sign index of the reference point
        let refSignIndex;
        if (refKey === "fromLagna") {
            refSignIndex = lagnaSignIndex;
        } else {
            refSignIndex = getSignIndex(refPlanet);
        }
        
        if (refSignIndex == null) continue;
        
        // For each house that gives a bindu from this reference
        for (const houseNum of bindusFromRef) {
            // Calculate the target sign (house 1 = same sign as reference)
            const targetSignIndex = (refSignIndex + houseNum - 1) % 12;
            scores[targetSignIndex]++;
        }
    }
    
    // Convert to named object
    const result = {};
    for (let i = 0; i < 12; i++) {
        result[VEDIC_SIGNS[i]] = scores[i];
    }
    
    return result;
}

/**
 * Calculate Sarvashtakavarga (SAV) - Total bindus for each sign from all planets
 * SAV is the sum of all individual BAVs
 * 
 * @param {Object} planetPositions - All planet positions
 * @param {number} lagnaSignIndex - Lagna sign index
 * @returns {Object} SAV scores for each sign { Aries: 28, Taurus: 32, ... }
 */
export function calculateSarvashtakavarga(planetPositions, lagnaSignIndex) {
    const sav = {};
    VEDIC_SIGNS.forEach(sign => sav[sign] = 0);
    
    const planets = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
    
    for (const planet of planets) {
        const bav = calculateBhinnashtakavarga(planet, planetPositions, lagnaSignIndex);
        if (!bav) continue;
        
        for (const [sign, bindus] of Object.entries(bav)) {
            sav[sign] += bindus;
        }
    }
    
    return sav;
}

/**
 * Calculate complete Ashtakavarga for a birth chart
 * Returns both individual BAVs and total SAV
 * 
 * @param {Array|Object} processedPlanets - Planet data (array or object)
 * @param {string|number} ascendant - Ascendant sign name or degree
 * @returns {Object} { bav: { Sun: {...}, Moon: {...}, ... }, sav: {...} }
 */
export function calculateAshtakavarga(processedPlanets, ascendant) {
    // Convert processedPlanets array to object if needed
    let planetPositions = {};
    
    if (Array.isArray(processedPlanets)) {
        for (const p of processedPlanets) {
            const name = p.name || p.planet;
            if (name && !["Lagna", "Ascendant", "Rahu", "Ketu"].includes(name)) {
                planetPositions[name] = p;
            }
        }
    } else if (processedPlanets && typeof processedPlanets === "object") {
        planetPositions = processedPlanets;
    }
    
    // Get Lagna sign index
    let lagnaSignIndex;
    if (typeof ascendant === "number") {
        lagnaSignIndex = Math.floor(((ascendant % 360) + 360) % 360 / 30);
    } else if (typeof ascendant === "string") {
        lagnaSignIndex = VEDIC_SIGNS.findIndex(s => s.toLowerCase() === ascendant.toLowerCase());
    }
    
    if (lagnaSignIndex == null || lagnaSignIndex < 0) {
        logger.warn("Could not determine Lagna sign for Ashtakavarga");
        return null;
    }
    
    // Calculate BAV for each planet
    const bav = {};
    const planets = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
    
    for (const planet of planets) {
        bav[planet] = calculateBhinnashtakavarga(planet, planetPositions, lagnaSignIndex);
    }
    
    // Calculate SAV
    const sav = calculateSarvashtakavarga(planetPositions, lagnaSignIndex);
    
    logger.info("📊 Ashtakavarga calculated", { 
        hasBav: Object.keys(bav).length,
        savTotal: Object.values(sav).reduce((a, b) => a + b, 0),
    });
    
    return { bav, sav };
}

/**
 * Get transit bindu score for a planet transiting a sign
 * Higher score (5-8) = favorable transit, Lower (0-2) = challenging
 * 
 * @param {string} planet - Planet name
 * @param {string} transitSign - Sign being transited
 * @param {Object} ashtakavarga - Pre-calculated ashtakavarga { bav: {...}, sav: {...} }
 * @returns {Object} { bindus: number, quality: string }
 */
export function getTransitBinduScore(planet, transitSign, ashtakavarga) {
    if (!ashtakavarga?.bav?.[planet]) return null;
    
    const bindus = ashtakavarga.bav[planet][transitSign];
    if (bindus == null) return null;
    
    let quality;
    if (bindus >= 5) quality = "favorable";
    else if (bindus >= 3) quality = "neutral";
    else quality = "challenging";
    
    return { bindus, quality };
}

