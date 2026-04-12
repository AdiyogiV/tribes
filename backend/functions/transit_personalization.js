/**
 * Transit Personalization — Cosmic Intelligence Agent (Phase 5)
 *
 * Translates GLOBAL sky signals into PERSONAL house-by-house readings.
 * The global agent produces signals once → this layer maps them to each user's chart.
 *
 * Architecture:
 * - Global signals are extracted once daily (Phase 1)
 * - Per-ascendant batching: 12 ascendant signs cover all users
 * - Each user's specific reading = their ascendant batch + their dasha context
 *
 * Cost: 12 Gemini Flash calls per day (one per ascendant) = ~$0.004/day
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import { calculateHouseFromDegree } from "./vedic_analysis.js";
import { ZODIAC_SIGNS } from "../lib/constants.js";
import { db, logger } from "../lib/firebase.js";
import { AI_MODELS } from "../lib/config.js";

// Sign lords mapping
const SIGN_LORDS = {
    Aries: "Mars", Taurus: "Venus", Gemini: "Mercury", Cancer: "Moon",
    Leo: "Sun", Virgo: "Mercury", Libra: "Venus", Scorpio: "Mars",
    Sagittarius: "Jupiter", Capricorn: "Saturn", Aquarius: "Saturn", Pisces: "Jupiter",
};

// House names for display
const HOUSE_NAMES = {
    1: "Self & Body", 2: "Wealth & Speech", 3: "Courage & Siblings",
    4: "Home & Comfort", 5: "Children & Creativity", 6: "Health & Enemies",
    7: "Marriage & Partnerships", 8: "Transformation & Longevity",
    9: "Fortune & Dharma", 10: "Career & Status", 11: "Gains & Aspirations",
    12: "Losses & Liberation",
};

// =============================================================================
// BATCH TRANSIT READINGS — 12 ascendants cover all users
// =============================================================================

/**
 * Generate transit readings for all 12 ascendant signs.
 * Call this once per day after the agent run completes.
 *
 * @param {Object[]} globalSignals - Signals from extractSignals() (today's top signals)
 * @param {Object} todayPositions - { planetName: { longitude, sign, signDegree, ... } }
 * @param {string} geminiApiKeyValue - API key
 * @param {string} dateStr - "yyyy-MM-dd"
 * @returns {Object} { byAscendant: { "Aries": {...}, ... }, date }
 */
export async function generateTransitReadings(globalSignals, todayPositions, geminiApiKeyValue, dateStr) {
    const genAI = new GoogleGenerativeAI(geminiApiKeyValue);
    const model = genAI.getGenerativeModel({
        model: AI_MODELS?.GEMINI_FLASH || "gemini-2.0-flash",
    });

    const results = {};
    const errors = [];

    // Process 12 ascendants — run in parallel batches of 4 to avoid rate limits
    for (let batch = 0; batch < 3; batch++) {
        const batchSigns = ZODIAC_SIGNS.slice(batch * 4, (batch + 1) * 4);

        const batchResults = await Promise.allSettled(
            batchSigns.map(async (ascSign) => {
                const ascSignIndex = ZODIAC_SIGNS.indexOf(ascSign);
                const ascDegree = ascSignIndex * 30; // Start of sign

                // Map transit planets to houses for this ascendant
                const transitHouses = mapTransitsToHouses(todayPositions, ascDegree);

                // Build prompt
                const prompt = buildTransitPrompt(ascSign, transitHouses, globalSignals, dateStr);

                try {
                    const response = await model.generateContent(prompt);
                    const text = response.response.text();
                    const parsed = parseTransitResponse(text, ascSign, transitHouses);

                    return { ascSign, reading: parsed, error: null };
                } catch (error) {
                    logger.warn(`Transit reading failed for ${ascSign}`, {
                        structuredData: true,
                        error: String(error),
                    });
                    return { ascSign, reading: null, error: String(error) };
                }
            })
        );

        for (const result of batchResults) {
            if (result.status === "fulfilled" && result.value.reading) {
                results[result.value.ascSign] = result.value.reading;
            } else {
                const val = result.status === "fulfilled" ? result.value : { ascSign: "unknown", error: String(result.reason) };
                errors.push(val);
            }
        }
    }

    // Store to Firestore for frontend consumption
    await storeTransitReadings(dateStr, results);

    logger.info("Transit readings generated", {
        structuredData: true,
        date: dateStr,
        generated: Object.keys(results).length,
        errors: errors.length,
    });

    return {
        byAscendant: results,
        date: dateStr,
        stats: {
            generated: Object.keys(results).length,
            errors: errors.length,
        },
    };
}

// =============================================================================
// MAP TRANSITS TO HOUSES
// =============================================================================

/**
 * Map all transit planets to houses for a specific ascendant degree.
 *
 * @param {Object} positions - { planetName: { longitude, sign, signDegree, isRetro, nakshatra } }
 * @param {number} ascDegree - Ascendant degree (0-360)
 * @returns {Object} { byHouse: { 1: [planets], ... }, byPlanet: { Sun: { house, sign, ... } } }
 */
function mapTransitsToHouses(positions, ascDegree) {
    const byHouse = {};
    const byPlanet = {};

    for (let h = 1; h <= 12; h++) {
        byHouse[h] = [];
    }

    for (const [name, pos] of Object.entries(positions)) {
        if (!pos?.longitude) continue;

        const house = calculateHouseFromDegree(pos.longitude, ascDegree);
        if (!house) continue;

        const entry = {
            planet: name,
            house,
            sign: pos.sign,
            signDegree: pos.signDegree,
            isRetro: pos.isRetro || false,
            nakshatra: pos.nakshatra,
        };

        byHouse[house].push(entry);
        byPlanet[name] = entry;
    }

    return { byHouse, byPlanet };
}

// =============================================================================
// PROMPT BUILDING
// =============================================================================

/**
 * Build the transit reading prompt for one ascendant.
 */
function buildTransitPrompt(ascSign, transitHouses, globalSignals, dateStr) {
    const ascIndex = ZODIAC_SIGNS.indexOf(ascSign);

    // Build house overview
    let houseOverview = "";
    for (let h = 1; h <= 12; h++) {
        const signIndex = (ascIndex + h - 1) % 12;
        const sign = ZODIAC_SIGNS[signIndex];
        const lord = SIGN_LORDS[sign];
        const planets = transitHouses.byHouse[h];
        const planetList = planets.length > 0
            ? planets.map(p => `${p.planet}${p.isRetro ? "(R)" : ""} in ${p.sign}`).join(", ")
            : "empty";

        houseOverview += `House ${h} (${HOUSE_NAMES[h]}): ${sign}, lord ${lord} | Transits: ${planetList}\n`;
    }

    // Format top signals
    const signalSummary = globalSignals
        .slice(0, 8)
        .map(s => {
            const orb = s.orb != null ? ` (${s.orb}° orb)` : "";
            return `- ${s.type}: ${s.planets.join("+")} ${s.aspect || s.dignity || s.stationType || ""}${orb} [intensity ${s.intensity}/10]`;
        })
        .join("\n");

    return `You are a Vedic astrologer giving transit readings for ${dateStr}.

ASCENDANT: ${ascSign} Rising

CURRENT TRANSITS BY HOUSE:
${houseOverview}

TODAY'S GLOBAL SIGNALS:
${signalSummary}

TASK: Write a transit reading for each of the 12 houses. For each house:
1. What transiting planets are there and what they signify for that house
2. How the global signals (aspects, dignities) affect this house specifically
3. Practical guidance (1 sentence)

RULES:
- Be specific to ${ascSign} rising. House 1 = ${ascSign}, House 7 = ${ZODIAC_SIGNS[(ascIndex + 6) % 12]}, etc.
- Mention retrograde planets explicitly
- If a house is empty of transits, discuss the transit of its lord
- Keep each house reading to 2-3 sentences max
- Focus on the MOST relevant houses (ones with major transits or affected by today's signals)
- For less affected houses, keep it brief (1 sentence)

FORMAT: Use exactly this format for each house:
---HOUSE 1---
[reading]
---HOUSE 2---
[reading]
... through ---HOUSE 12---`;
}

// =============================================================================
// RESPONSE PARSING
// =============================================================================

/**
 * Parse the AI response into structured house readings.
 */
function parseTransitResponse(response, ascSign, transitHouses) {
    const houses = {};
    const ascIndex = ZODIAC_SIGNS.indexOf(ascSign);

    for (let h = 1; h <= 12; h++) {
        const regex = new RegExp(`---HOUSE ${h}---([\\s\\S]*?)(?=---HOUSE \\d+---|$)`, "i");
        const match = response.match(regex);
        const reading = match ? match[1].trim() : null;

        const signIndex = (ascIndex + h - 1) % 12;
        const sign = ZODIAC_SIGNS[signIndex];
        const planets = transitHouses.byHouse[h] || [];

        houses[h] = {
            houseNumber: h,
            houseName: HOUSE_NAMES[h],
            sign,
            signLord: SIGN_LORDS[sign],
            transitPlanets: planets.map(p => ({
                planet: p.planet,
                sign: p.sign,
                isRetro: p.isRetro,
            })),
            reading: (reading && reading.length >= 15) ? reading : null,
            hasTransits: planets.length > 0,
        };
    }

    return {
        ascendant: ascSign,
        houses,
        generatedAt: new Date().toISOString(),
    };
}

// =============================================================================
// FIRESTORE STORAGE
// =============================================================================

/**
 * Store transit readings to Firestore for frontend consumption.
 * Path: global_astro/transit_readings/{date}
 */
async function storeTransitReadings(dateStr, byAscendant) {
    try {
        const docRef = db.collection("global_astro_transit_readings").doc(dateStr);
        await docRef.set({
            date: dateStr,
            byAscendant,
            generatedAt: new Date(),
            ascendantCount: Object.keys(byAscendant).length,
        });
    } catch (error) {
        logger.error("Failed to store transit readings", {
            structuredData: true,
            error: String(error),
        });
    }
}

// =============================================================================
// USER-SPECIFIC READING — Fetch pre-computed reading for a user
// =============================================================================

/**
 * Get the transit reading for a specific user.
 * Looks up their ascendant sign and returns the pre-computed batch reading.
 *
 * @param {string} uid - User ID
 * @param {string} [dateStr] - Date (default: today)
 * @returns {Object|null} User's transit reading with all 12 houses
 */
export async function getUserTransitReading(uid, dateStr = null) {
    const date = dateStr || new Date().toISOString().split("T")[0];

    try {
        // Get user's ascendant
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) return null;

        const astroData = userDoc.data()?.astrologyData;
        if (!astroData) return null;

        // Determine ascendant sign
        let ascSign = null;
        if (astroData.ascendant?.sign) {
            ascSign = astroData.ascendant.sign;
        } else if (astroData.lagna?.sign) {
            ascSign = astroData.lagna.sign;
        } else if (typeof astroData.ascendant === "string") {
            ascSign = astroData.ascendant;
        }

        if (!ascSign || !ZODIAC_SIGNS.includes(ascSign)) {
            logger.warn("Invalid ascendant sign for user", { uid, ascSign });
            return null;
        }

        // Fetch pre-computed reading
        const readingDoc = await db.collection("global_astro_transit_readings").doc(date).get();
        if (!readingDoc.exists) return null;

        const reading = readingDoc.data()?.byAscendant?.[ascSign];
        if (!reading) return null;

        return {
            ...reading,
            userId: uid,
            date,
            userAscendant: ascSign,
        };
    } catch (error) {
        logger.error("Failed to get user transit reading", {
            structuredData: true,
            error: String(error),
            uid,
        });
        return null;
    }
}

// =============================================================================
// EXPORT: Cloud Function trigger for batch generation
// =============================================================================

/**
 * Generate all transit readings after the daily agent run.
 * Called from cosmic_agent_runner.js after the agent completes.
 */
export async function generateDailyTransitReadings(geminiApiKeyValue, dateStr) {
    try {
        // Load today's sky positions
        const skyDoc = await db.collection("global_astro").doc("sky_positions").get();
        if (!skyDoc.exists) throw new Error("No sky positions available");

        const positions = skyDoc.data()?.positions || {};
        const todayPositions = positions[dateStr];
        if (!todayPositions) throw new Error(`No positions for ${dateStr}`);

        // Load today's signals from Firestore (written by the agent)
        const signalSnap = await db.collection("global_astro_signals")
            .where("date", "==", dateStr)
            .orderBy("intensity", "desc")
            .limit(15)
            .get();

        const signals = signalSnap.docs.map(d => ({ id: d.id, ...d.data() }));

        // Generate readings
        return await generateTransitReadings(signals, todayPositions, geminiApiKeyValue, dateStr);
    } catch (error) {
        logger.error("Failed to generate daily transit readings", {
            structuredData: true,
            error: String(error),
        });
        return { error: String(error) };
    }
}
