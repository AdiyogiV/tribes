/**
 * HOUSE INTERPRETATIONS - Deep Vedic Analysis for Each House
 * 
 * Generates AI-powered personalized interpretations for all 12 houses
 * considering: sign, lord placement, occupants, aspects, yogas, and dasha.
 * 
 * Called on-demand when user taps a house (if not already generated).
 */

import { logger } from "./firebase.js";
import { geminiApiKey } from "./secrets.js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { HOUSE_SIGNIFICATIONS } from "./constants.js";
import { AI_MODELS } from "./config.js";
import { normalizeDasha } from "./astro_helpers.js";

const ZODIAC_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"
];

const SIGN_LORDS = {
    Aries: "Mars", Taurus: "Venus", Gemini: "Mercury", Cancer: "Moon",
    Leo: "Sun", Virgo: "Mercury", Libra: "Venus", Scorpio: "Mars",
    Sagittarius: "Jupiter", Capricorn: "Saturn", Aquarius: "Saturn", Pisces: "Jupiter"
};

const HOUSE_NAMES = {
    1: "Lagna (Self)", 2: "Dhana (Wealth)", 3: "Sahaja (Siblings)",
    4: "Sukha (Home)", 5: "Putra (Children)", 6: "Ari (Health)",
    7: "Yuvati (Marriage)", 8: "Ayu (Transformation)", 9: "Dharma (Fortune)",
    10: "Karma (Career)", 11: "Labha (Gains)", 12: "Vyaya (Liberation)"
};

const HOUSE_TYPES = {
    1: ["Kendra", "Trikona"], 4: ["Kendra"], 7: ["Kendra", "Maraka"], 10: ["Kendra", "Upachaya"],
    5: ["Trikona"], 9: ["Trikona"],
    2: ["Maraka"],
    3: ["Upachaya"], 6: ["Dusthana", "Upachaya"], 11: ["Upachaya"],
    8: ["Dusthana"], 12: ["Dusthana"]
};

// ============================================================================
// MAIN EXPORT - Generate All House Interpretations
// ============================================================================

/**
 * Generate personalized interpretations for all 12 houses
 * @param {Object} astroData - User's complete astrology data
 * @returns {Object} { 1: { interpretation, sign, lord, ... }, 2: {...}, ... }
 */
export async function generateHouseInterpretations(astroData) {
    const startTime = Date.now();
    logger.info("🏠 Starting house interpretations generation");

    try {
        // Extract birth chart data
        const birthChartData = astroData.birthChartData;
        if (!birthChartData?.output) {
            logger.warn("No birth chart data available for house interpretations");
            return null;
        }

        const planets = extractPlanets(birthChartData.output);
        const ascendantDegree = getAscendantDegree(planets);
        const lagnaSignIndex = Math.floor(ascendantDegree / 30) % 12;
        const lagnaSign = ZODIAC_SIGNS[lagnaSignIndex];

        // Build context for all 12 houses
        const houseContexts = [];
        for (let house = 1; house <= 12; house++) {
            const context = buildHouseContext(house, lagnaSignIndex, planets, astroData);
            houseContexts.push(context);
        }

        // Generate AI interpretations
        const interpretations = await generateAIInterpretations(houseContexts, lagnaSign, astroData);

        logger.info("✅ House interpretations generated", {
            latencyMs: Date.now() - startTime,
            housesGenerated: Object.keys(interpretations).length
        });

        return interpretations;
    } catch (error) {
        logger.error("❌ House interpretations failed", { error: error.message });
        return null;
    }
}

// ============================================================================
// CONTEXT BUILDING
// ============================================================================

/**
 * Build comprehensive context for a single house
 */
function buildHouseContext(houseNumber, lagnaSignIndex, planets, astroData) {
    // Calculate sign in this house
    const signIndex = (lagnaSignIndex + houseNumber - 1) % 12;
    const sign = ZODIAC_SIGNS[signIndex];
    const signLord = SIGN_LORDS[sign];

    // Find planets in this house
    const planetsInHouse = [];
    const planetDegrees = {};

    Object.entries(planets).forEach(([name, data]) => {
        if (!data || name.toLowerCase() === 'ascendant') return;
        const houseNum = data.house_number || data.houseNumber;
        if (houseNum === houseNumber) {
            planetsInHouse.push({
                name,
                degree: data.fullDegree || data.full_degree,
                sign: data.sign,
                nakshatra: data.nakshatra,
                isRetrograde: data.isRetrograde || data.retrograde,
                isCombust: data.combust || data.isCombust,
            });
        }
        // Store all planet degrees for aspect calculation
        planetDegrees[name] = data.fullDegree || data.full_degree;
    });

    // Find house lord's placement
    let lordPlacement = null;
    Object.entries(planets).forEach(([name, data]) => {
        if (name.toLowerCase().includes(signLord.toLowerCase())) {
            lordPlacement = {
                house: data.house_number || data.houseNumber,
                sign: data.sign,
                nakshatra: data.nakshatra,
                isRetrograde: data.isRetrograde || data.retrograde,
                isCombust: data.combust || data.isCombust,
                dignity: getPlanetDignity(name, data.sign),
            };
        }
    });

    // Calculate aspects TO this house (which planets aspect this house)
    const aspectsToHouse = calculateAspectsToHouse(houseNumber, planets, lagnaSignIndex);

    // Check if house lord is current dasha planet
    const { mahaDasha, antarDasha } = normalizeDasha(astroData.currentDasha);
    const isActiveDasha = signLord === mahaDasha || signLord === antarDasha;

    // Check yogas involving this house
    const relevantYogas = findYogasForHouse(houseNumber, signLord, astroData.rajYogas, astroData.yogasDetailed);

    return {
        houseNumber,
        houseName: HOUSE_NAMES[houseNumber],
        houseType: HOUSE_TYPES[houseNumber] || [],
        signification: HOUSE_SIGNIFICATIONS[houseNumber],
        sign,
        signLord,
        lordPlacement,
        planetsInHouse,
        aspectsToHouse,
        isActiveDasha,
        activeDashaPlanet: isActiveDasha ? (signLord === mahaDasha ? "Mahadasha" : "Antardasha") : null,
        relevantYogas,
    };
}

/**
 * Calculate which planets aspect a given house
 */
function calculateAspectsToHouse(targetHouse, planets, lagnaSignIndex) {
    const aspects = [];

    // Calculate the degree range of the target house
    const houseStartDegree = ((lagnaSignIndex + targetHouse - 1) % 12) * 30;
    const houseMidDegree = houseStartDegree + 15; // Middle of house for aspect calculation

    Object.entries(planets).forEach(([name, data]) => {
        if (!data || name.toLowerCase() === 'ascendant') return;

        const planetDegree = data.fullDegree || data.full_degree;
        if (planetDegree == null) return;

        const planetHouse = data.house_number || data.houseNumber;
        if (planetHouse === targetHouse) return; // Skip planets IN the house

        // Calculate house distance
        let houseDiff = targetHouse - planetHouse;
        if (houseDiff <= 0) houseDiff += 12;

        // Check for aspects
        const planetName = name.toString();
        let aspectType = null;

        // All planets aspect 7th house
        if (houseDiff === 7) {
            aspectType = "7th aspect";
        }
        // Mars special aspects
        else if (planetName.includes("Mars") && (houseDiff === 4 || houseDiff === 8)) {
            aspectType = `${houseDiff}th aspect (Mars)`;
        }
        // Jupiter special aspects
        else if (planetName.includes("Jupiter") && (houseDiff === 5 || houseDiff === 9)) {
            aspectType = `${houseDiff}th aspect (Jupiter)`;
        }
        // Saturn special aspects
        else if (planetName.includes("Saturn") && (houseDiff === 3 || houseDiff === 10)) {
            aspectType = `${houseDiff}th aspect (Saturn)`;
        }
        // Rahu/Ketu aspect like Jupiter
        else if ((planetName.includes("Rahu") || planetName.includes("Ketu")) && (houseDiff === 5 || houseDiff === 9)) {
            aspectType = `${houseDiff}th aspect`;
        }

        if (aspectType) {
            aspects.push({
                planet: name,
                type: aspectType,
                fromHouse: planetHouse,
                isBenefic: isBeneficPlanet(name),
            });
        }
    });

    return aspects;
}

/**
 * Check if a planet is naturally benefic
 */
function isBeneficPlanet(planetName) {
    const name = planetName.toLowerCase();
    if (name.includes("jupiter") || name.includes("venus")) return true;
    if (name.includes("moon") || name.includes("mercury")) return true; // Conditionally benefic
    return false;
}

/**
 * Get planet dignity in a sign
 */
function getPlanetDignity(planet, sign) {
    if (!planet || !sign) return "neutral";

    const dignities = {
        Sun: { exalted: "Aries", debilitated: "Libra", own: ["Leo"] },
        Moon: { exalted: "Taurus", debilitated: "Scorpio", own: ["Cancer"] },
        Mars: { exalted: "Capricorn", debilitated: "Cancer", own: ["Aries", "Scorpio"] },
        Mercury: { exalted: "Virgo", debilitated: "Pisces", own: ["Gemini", "Virgo"] },
        Jupiter: { exalted: "Cancer", debilitated: "Capricorn", own: ["Sagittarius", "Pisces"] },
        Venus: { exalted: "Pisces", debilitated: "Virgo", own: ["Taurus", "Libra"] },
        Saturn: { exalted: "Libra", debilitated: "Aries", own: ["Capricorn", "Aquarius"] },
    };

    const planetKey = Object.keys(dignities).find(k => planet.toLowerCase().includes(k.toLowerCase()));
    if (!planetKey) return "neutral";

    const d = dignities[planetKey];
    if (d.exalted === sign) return "exalted";
    if (d.debilitated === sign) return "debilitated";
    if (d.own?.includes(sign)) return "own sign";
    return "neutral";
}

/**
 * Find yogas relevant to a house
 */
function findYogasForHouse(houseNumber, signLord, rajYogas, yogasDetailed) {
    const relevant = [];

    // Check Raj Yogas
    if (rajYogas && Array.isArray(rajYogas)) {
        rajYogas.forEach(yoga => {
            const yogaStr = JSON.stringify(yoga).toLowerCase();
            if (yogaStr.includes(`house ${houseNumber}`) ||
                yogaStr.includes(signLord.toLowerCase()) ||
                yogaStr.includes(`${houseNumber}th`)) {
                relevant.push(yoga.name || yoga.yoga || "Raj Yoga");
            }
        });
    }

    return relevant.slice(0, 2); // Max 2 yogas per house
}

// ============================================================================
// AI INTERPRETATION GENERATION
// ============================================================================

/**
 * Generate AI interpretations for all houses in a single call
 */
async function generateAIInterpretations(houseContexts, lagnaSign, astroData) {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
        throw new Error("Gemini API key missing");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: AI_MODELS.GEMINI_FLASH,
        generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 4000,
        },
    });

    // Build the comprehensive prompt
    const prompt = buildInterpretationPrompt(houseContexts, lagnaSign, astroData);

    const systemPrompt = `You are a masterful Vedic astrologer who synthesizes chart factors into profound, specific insights.
You connect the dots others miss: house lord placements, planetary dignities, aspects, and timing.
Your readings make people feel truly SEEN—because you're reading THEIR specific chart, not generic descriptions.
Speak directly, warmly, and with conviction. Every insight should feel like a gift of self-understanding.`;

    const result = await model.generateContent([
        { text: systemPrompt },
        { text: prompt },
    ]);

    const response = result.response.text();
    return parseAIResponse(response, houseContexts);
}

/**
 * Build comprehensive prompt for AI
 */
function buildInterpretationPrompt(houseContexts, lagnaSign, astroData) {
    const { mahaDasha } = normalizeDasha(astroData.currentDasha);
    const mahaDashaLabel = mahaDasha || "Unknown";

    let prompt = `You are a Vedic astrologer giving personalized readings.

CHART: ${lagnaSign} Rising | ${mahaDashaLabel} Mahadasha${astroData.moonSign ? ` | ${astroData.moonSign} Moon` : ""}

TASK: Write ONE flowing paragraph (2-3 sentences) per house that weaves ALL factors together.

CRITICAL: Do NOT explain factors separately. Do NOT write "Libra here means X. Saturn adds Y. The lord placement shows Z." 
Instead, SYNTHESIZE everything into a single coherent story about this area of their life.

EXAMPLE OF WHAT NOT TO DO:
"Libra in your 10th brings harmony to career. Saturn here adds discipline. Your 10th lord Venus in the 7th connects work to partnerships."
^ This is fragmented—three separate observations listed in sequence.

EXAMPLE OF WHAT TO DO:
"Your career path blends artistic sensibility with serious discipline—you're drawn to work that creates beauty but demands mastery. Partnerships play a key role in your professional rise, whether through collaboration, a supportive spouse, or clients who become allies."
^ This weaves sign (Libra/beauty), planet (Saturn/discipline), and lord placement (Venus in 7th/partnerships) into ONE flowing insight.

RULES:
- ONE coherent paragraph per house, not bullet points or separate analyses
- Speak to THEIR life, not astrological theory ("You" not "This placement")  
- If dasha lord is active for this house, mention timing naturally within the insight
- Be specific, warm, empowering—help them understand themselves

OUTPUT:
---HOUSE 1---
[one synthesized paragraph]
---HOUSE 2---
[one synthesized paragraph]
...through all 12 houses

CHART DATA FOR EACH HOUSE:
`;

    houseContexts.forEach(ctx => {
        prompt += `
---
HOUSE ${ctx.houseNumber} (${ctx.houseName}):
- Sign: ${ctx.sign} (Lord: ${ctx.signLord})
- Natural significations: ${ctx.signification}
- House type: ${ctx.houseType.join(", ") || "Standard"}
`;

        if (ctx.lordPlacement) {
            prompt += `- House Lord ${ctx.signLord} placed in: House ${ctx.lordPlacement.house} (${ctx.lordPlacement.sign})`;
            if (ctx.lordPlacement.dignity !== "neutral") {
                prompt += ` - ${ctx.lordPlacement.dignity}`;
            }
            if (ctx.lordPlacement.isRetrograde) prompt += ` [Retrograde]`;
            if (ctx.lordPlacement.isCombust) prompt += ` [Combust]`;
            prompt += "\n";
        }

        if (ctx.planetsInHouse.length > 0) {
            prompt += `- Planets IN house: ${ctx.planetsInHouse.map(p => {
                let desc = p.name;
                if (p.isRetrograde) desc += " (R)";
                if (p.isCombust) desc += " (combust)";
                return desc;
            }).join(", ")}\n`;
        }

        if (ctx.aspectsToHouse.length > 0) {
            prompt += `- Aspects to house: ${ctx.aspectsToHouse.map(a =>
                `${a.planet} (${a.type}${a.isBenefic ? ", benefic" : ""})`
            ).join(", ")}\n`;
        }

        if (ctx.isActiveDasha) {
            prompt += `- ⭐ ACTIVE: House lord ${ctx.signLord} is current ${ctx.activeDashaPlanet} planet!\n`;
        }

        if (ctx.relevantYogas.length > 0) {
            prompt += `- Special Yogas: ${ctx.relevantYogas.join(", ")}\n`;
        }
    });

    return prompt;
}

/**
 * Parse AI response into structured house interpretations
 * Returns null for houses where AI parsing fails (no fallback)
 */
function parseAIResponse(response, houseContexts) {
    const interpretations = {};

    for (let house = 1; house <= 12; house++) {
        const ctx = houseContexts[house - 1];

        // Extract interpretation for this house
        const regex = new RegExp(`---HOUSE ${house}---([\\s\\S]*?)(?=---HOUSE \\d+---|$)`, "i");
        const match = response.match(regex);

        const interpretation = match ? match[1].trim() : null;

        interpretations[house] = {
            interpretation: (interpretation && interpretation.length >= 20) ? interpretation : null,
            sign: ctx.sign,
            signLord: ctx.signLord,
            lordPlacement: ctx.lordPlacement?.house || null,
            planetsInHouse: ctx.planetsInHouse.map(p => p.name),
            aspectsFrom: ctx.aspectsToHouse.map(a => a.planet),
            isActiveDasha: ctx.isActiveDasha,
        };
    }

    return interpretations;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function extractPlanets(output) {
    if (typeof output === "object" && !Array.isArray(output)) {
        return output;
    }
    if (Array.isArray(output) && output.length > 0) {
        return output[0];
    }
    return {};
}

function getAscendantDegree(planets) {
    const asc = planets.Ascendant || planets.ascendant || planets["0"];
    return asc?.fullDegree || asc?.full_degree || 0;
}

