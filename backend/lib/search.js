import { logger } from "./firebase.js";
import { getVertexAI, extractText } from "./vertex_client.js";
import {
    getCachedAstroKnowledge,
    cacheAstroKnowledge,
    getCachedAstroCurrent,
    cacheAstroCurrent,
} from "./cache_utils.js";
import { getOrdinal } from "./utils.js";
import { AI_MODELS } from "./config.js";
import { normalizeDasha } from "./astro_helpers.js";

// =============================================================================
// WEB SEARCH (VIA GEMINI GOOGLE SEARCH GROUNDING)
// We intentionally do NOT use Google Custom Search API anymore.
// Gemini (with googleSearch tool) handles retrieval.
// =============================================================================

const MAX_RESULTS_PER_QUERY = 5;

function stripCodeFences(text) {
    if (!text) return "";
    return text
        .replace(/```json\s*/gi, "```")
        .replace(/```[\s\r\n]*/g, "")
        .trim();
}

function safeParseJsonArray(text) {
    const cleaned = stripCodeFences(text);
    const start = cleaned.indexOf("[");
    const end = cleaned.lastIndexOf("]");
    if (start === -1 || end === -1 || end <= start) return null;
    const json = cleaned.slice(start, end + 1);
    try {
        const parsed = JSON.parse(json);
        return Array.isArray(parsed) ? parsed : null;
    } catch {
        return null;
    }
}

// =============================================================================
// ASTROLOGY SEARCH FUNCTIONS
// Comprehensive Google Search integration for Vedic astrology knowledge
// =============================================================================

/**
 * Extract best snippet from search results
 */
function extractBestSnippet(results, maxLength = 500) {
    if (!results || !Array.isArray(results) || results.length === 0) {
        return null;
    }

    // Combine top snippets, prioritize longer ones
    const snippets = results
        .map(r => r.snippet || "")
        .filter(s => s.length > 50)
        .slice(0, 3);

    if (snippets.length === 0) return results[0]?.snippet || null;

    const combined = snippets.join(" ");
    return combined.length > maxLength ? combined.substring(0, maxLength) + "..." : combined;
}

/**
 * Parse retrograde planets from search results
 */
function parseRetrogrades(results) {
    if (!results || !Array.isArray(results)) return [];

    const retrogrades = [];
    const planets = ["Mercury", "Venus", "Mars", "Jupiter", "Saturn"];
    const text = results.map(r => (r.snippet || "") + " " + (r.title || "")).join(" ").toLowerCase();

    for (const planet of planets) {
        const planetLower = planet.toLowerCase();
        // Check if planet is mentioned with retrograde
        if (text.includes(planetLower) && text.includes("retrograde")) {
            // Make sure it's not "ends retrograde" or "not retrograde"
            const retroPattern = new RegExp(`${planetLower}.*retrograde|retrograde.*${planetLower}`, "i");
            const notRetroPattern = new RegExp(`${planetLower}.*(ends|not|over|direct).*retrograde|retrograde.*(ends|over).*${planetLower}`, "i");

            if (retroPattern.test(text) && !notRetroPattern.test(text)) {
                retrogrades.push(planet);
            }
        }
    }

    return retrogrades;
}

/**
 * Parse Moon phase from search results
 */
function parseMoonPhase(results) {
    if (!results || !Array.isArray(results)) return null;

    const text = results.map(r => (r.snippet || "") + " " + (r.title || "")).join(" ");

    // Look for Full Moon
    const fullMoonMatch = text.match(/full\s*moon[:\s]*(\w+\s+\d+|\d+\s+\w+)/i);
    if (fullMoonMatch) {
        // Try to find the sign
        const signMatch = text.match(/full\s*moon.*?in\s+(\w+)/i);
        return {
            type: "Full Moon",
            date: fullMoonMatch[1],
            sign: signMatch ? signMatch[1] : null,
        };
    }

    // Look for New Moon
    const newMoonMatch = text.match(/new\s*moon[:\s]*(\w+\s+\d+|\d+\s+\w+)/i);
    if (newMoonMatch) {
        const signMatch = text.match(/new\s*moon.*?in\s+(\w+)/i);
        return {
            type: "New Moon",
            date: newMoonMatch[1],
            sign: signMatch ? signMatch[1] : null,
        };
    }

    return null;
}

/**
 * Parse eclipse info from search results
 */
function parseEclipse(results) {
    if (!results || !Array.isArray(results)) return null;

    const text = results.map(r => (r.snippet || "") + " " + (r.title || "")).join(" ");

    // Look for lunar eclipse
    const lunarMatch = text.match(/lunar\s*eclipse[:\s]*(\w+\s+\d+|\d+\s+\w+)/i);
    if (lunarMatch) {
        return {
            type: "Lunar Eclipse",
            date: lunarMatch[1],
        };
    }

    // Look for solar eclipse
    const solarMatch = text.match(/solar\s*eclipse[:\s]*(\w+\s+\d+|\d+\s+\w+)/i);
    if (solarMatch) {
        return {
            type: "Solar Eclipse",
            date: solarMatch[1],
        };
    }

    return null;
}

// =============================================================================
// STATIC KNOWLEDGE SEARCHES (Cache Forever)
// =============================================================================

/**
 * Get Lagna (Ascendant) meaning - Cache Forever
 * @param {string} lagna - Ascendant sign (e.g., "Aries", "Taurus")
 */
export async function getLagnaMeaning(lagna) {
    if (!lagna) return null;

    const cacheKey = lagna.toLowerCase();
    const cached = await getCachedAstroKnowledge("lagna", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${lagna} ascendant lagna personality characteristics career vedic astrology`
    );

    const meaning = {
        sign: lagna,
        characteristics: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("lagna", cacheKey, meaning);
    return meaning;
}

/**
 * Get Moon Sign meaning - Cache Forever
 * @param {string} moonSign - Moon sign (e.g., "Cancer", "Leo")
 */
export async function getMoonSignMeaning(moonSign) {
    if (!moonSign) return null;

    const cacheKey = moonSign.toLowerCase();
    const cached = await getCachedAstroKnowledge("moonSign", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${moonSign} Moon sign emotional patterns mind vedic astrology rashi`
    );

    const meaning = {
        sign: moonSign,
        characteristics: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("moonSign", cacheKey, meaning);
    return meaning;
}

/**
 * Get Nakshatra meaning - Cache Forever
 * @param {string} nakshatra - Nakshatra name (e.g., "Rohini", "Ashwini")
 */
export async function getNakshatraMeaning(nakshatra) {
    if (!nakshatra) return null;

    const cacheKey = nakshatra.toLowerCase().replace(/\s+/g, "_");
    const cached = await getCachedAstroKnowledge("nakshatra", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${nakshatra} nakshatra characteristics personality deity career vedic astrology`
    );

    const meaning = {
        nakshatra,
        characteristics: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("nakshatra", cacheKey, meaning);
    return meaning;
}

/**
 * Get Tithi meaning - Cache Forever
 * @param {string} tithi - Tithi name (e.g., "Shukla Chaturthi", "Krishna Ashtami")
 */
export async function getTithiMeaning(tithi) {
    if (!tithi) return null;

    const cacheKey = tithi.toLowerCase().replace(/\s+/g, "_");
    const cached = await getCachedAstroKnowledge("tithi", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${tithi} tithi meaning favorable activities fasting rituals vedic astrology`
    );

    const meaning = {
        tithi,
        meaning: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("tithi", cacheKey, meaning);
    return meaning;
}

/**
 * Get Yoga (Panchang) meaning - Cache Forever
 * @param {string} yoga - Yoga name (e.g., "Siddhi", "Vishkumbh")
 */
export async function getYogaMeaning(yoga) {
    if (!yoga) return null;

    const cacheKey = yoga.toLowerCase().replace(/\s+/g, "_");
    const cached = await getCachedAstroKnowledge("yoga", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${yoga} yoga panchang meaning auspicious inauspicious vedic astrology`
    );

    const meaning = {
        yoga,
        meaning: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("yoga", cacheKey, meaning);
    return meaning;
}

/**
 * Get Dasha interpretation - Cache Forever
 * @param {string} mahaDasha - Mahadasha lord (e.g., "Venus", "Saturn")
 * @param {string} antarDasha - Antardasha lord (e.g., "Saturn", "Jupiter")
 * @param {string} area - Life area: "general", "career", "relationships", "health"
 */
export async function getDashaMeaning(mahaDasha, antarDasha, area = "general") {
    if (!mahaDasha || !antarDasha) return null;

    const cacheKey = `${mahaDasha}_${antarDasha}_${area}`.toLowerCase();
    const cached = await getCachedAstroKnowledge("dasha", cacheKey);
    if (cached) return cached;

    let query;
    switch (area) {
        case "career":
            query = `${mahaDasha} Mahadasha ${antarDasha} Antardasha career job business effects vedic`;
            break;
        case "relationships":
            query = `${mahaDasha} Mahadasha ${antarDasha} Antardasha love marriage relationship effects vedic`;
            break;
        case "health":
            query = `${mahaDasha} Mahadasha ${antarDasha} Antardasha health wellness effects vedic`;
            break;
        default:
            query = `${mahaDasha} Mahadasha ${antarDasha} Antardasha effects predictions meaning vedic astrology`;
    }

    const results = await performWebSearch(query);

    const meaning = {
        mahaDasha,
        antarDasha,
        area,
        interpretation: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("dasha", cacheKey, meaning);
    return meaning;
}

/**
 * Get Transit interpretation - Cache Forever
 * @param {string} planet - Planet name (e.g., "Jupiter", "Saturn")
 * @param {number} house - House number (1-12)
 */
export async function getTransitMeaning(planet, house) {
    if (!planet || !house) return null;

    const cacheKey = `${planet}_${house}`.toLowerCase();
    const cached = await getCachedAstroKnowledge("transit", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${planet} transit ${getOrdinal(house)} house effects career relationships vedic astrology`
    );

    const meaning = {
        planet,
        house,
        effects: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("transit", cacheKey, meaning);
    return meaning;
}

/**
 * Get Planet remedies - Cache Forever
 * @param {string} planet - Planet name (e.g., "Saturn", "Mars")
 * @param {boolean} isWeak - Whether the planet is weak
 */
export async function getPlanetRemedies(planet, isWeak = true) {
    if (!planet) return null;

    const cacheKey = `${planet}_${isWeak ? "weak" : "strong"}`.toLowerCase();
    const cached = await getCachedAstroKnowledge("remedy", cacheKey);
    if (cached) return cached;

    const query = isWeak
        ? `weak ${planet} remedies mantra gemstone fasting donation vedic astrology`
        : `strong ${planet} benefits how to leverage vedic astrology`;

    const results = await performWebSearch(query);

    const remedies = {
        planet,
        isWeak,
        advice: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("remedy", cacheKey, remedies);
    return remedies;
}

/**
 * Get House signification - Cache Forever
 * @param {number} house - House number (1-12)
 */
export async function getHouseMeaning(house) {
    if (!house || house < 1 || house > 12) return null;

    const cacheKey = `house_${house}`;
    const cached = await getCachedAstroKnowledge("house", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${getOrdinal(house)} house meaning significations vedic astrology bhava`
    );

    const meaning = {
        house,
        significations: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("house", cacheKey, meaning);
    return meaning;
}

/**
 * Get Retrograde survival guide - Cache Forever
 * @param {string} planet - Planet name (e.g., "Mercury", "Venus")
 */
export async function getRetrogradeGuide(planet) {
    if (!planet) return null;

    const cacheKey = `${planet}_retrograde`.toLowerCase();
    const cached = await getCachedAstroKnowledge("retrograde", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${planet} retrograde effects do's don'ts survival guide vedic astrology`
    );

    const guide = {
        planet,
        guide: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroKnowledge("retrograde", cacheKey, guide);
    return guide;
}

// =============================================================================
// CURRENT DATA SEARCHES (Cache 1-30 days)
// =============================================================================

/**
 * Get global astronomical events - Cache 7 days
 * @param {Date} date - Date to search for
 */
export async function getGlobalAstroEvents(date) {
    const month = date.toLocaleString("en", { month: "long" });
    const year = date.getFullYear();
    const cacheKey = `${year}_${date.getMonth()}`;

    const cached = await getCachedAstroCurrent("global", cacheKey);
    if (cached) return cached;

    // Execute searches in parallel
    const [retrogradeResults, eclipseResults, moonResults] = await Promise.all([
        performWebSearch(`planets retrograde ${month} ${year} Mercury Venus Mars Jupiter Saturn status`),
        performWebSearch(`eclipse ${month} ${year} lunar solar astrology effects`),
        performWebSearch(`Full Moon New Moon ${month} ${year} dates zodiac sign`),
    ]);

    const events = {
        retrogrades: parseRetrogrades(retrogradeResults),
        eclipse: parseEclipse(eclipseResults),
        moonPhase: parseMoonPhase(moonResults),
        month,
        year,
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroCurrent("global", cacheKey, events, 7); // Cache 7 days
    return events;
}

/**
 * Get current retrograde status - Cache 7 days
 * @param {Date} date - Date to search for
 */
export async function getCurrentRetrogrades(date) {
    const month = date.toLocaleString("en", { month: "long" });
    const year = date.getFullYear();
    const cacheKey = `retrogrades_${year}_${date.getMonth()}`;

    const cached = await getCachedAstroCurrent("retrogrades", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `Mercury Venus Mars Jupiter Saturn retrograde ${month} ${year} dates status direct`
    );

    const retrogrades = {
        planets: parseRetrogrades(results),
        details: extractBestSnippet(results, 300),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroCurrent("retrogrades", cacheKey, retrogrades, 7);
    return retrogrades;
}

/**
 * Get major transit news for today/this week - Cache 1 day
 * Includes planets going direct, sign changes, major aspects
 * @param {Date} date - Date to search for
 */
export async function getDailyTransitNews(date) {
    const day = date.getDate();
    const month = date.toLocaleString("en", { month: "long" });
    const year = date.getFullYear();
    const cacheKey = `transitnews_${year}_${date.getMonth()}_${day}`;

    const cached = await getCachedAstroCurrent("transitnews", cacheKey);
    if (cached) return cached;

    // Search for major planetary events happening now
    const results = await performWebSearch(
        `astrology ${month} ${day} ${year} planet direct retrograde station sign change major transit event`
    );

    const news = {
        summary: extractBestSnippet(results, 500),
        date: `${month} ${day}, ${year}`,
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroCurrent("transitnews", cacheKey, news, 1); // Cache 1 day only
    return news;
}

/**
 * Get monthly predictions - Cache 30 days
 * @param {Date} date - Date to search for
 */
export async function getMonthlyPredictions(date) {
    const month = date.toLocaleString("en", { month: "long" });
    const year = date.getFullYear();
    const cacheKey = `monthly_${year}_${date.getMonth()}`;

    const cached = await getCachedAstroCurrent("monthly", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `${month} ${year} astrology predictions vedic major transits events`
    );

    const predictions = {
        month,
        year,
        overview: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroCurrent("monthly", cacheKey, predictions, 30);
    return predictions;
}

/**
 * Get weekly predictions - Cache 7 days
 * @param {Date} date - Date to search for
 */
export async function getWeeklyPredictions(date) {
    const weekStart = new Date(date);
    weekStart.setDate(date.getDate() - date.getDay()); // Start of week (Sunday)
    const weekKey = `${weekStart.getFullYear()}_${weekStart.getMonth()}_${weekStart.getDate()}`;

    const cached = await getCachedAstroCurrent("weekly", weekKey);
    if (cached) return cached;

    const month = date.toLocaleString("en", { month: "long" });
    const year = date.getFullYear();

    const results = await performWebSearch(
        `astrology predictions this week ${month} ${year} vedic planetary transits`
    );

    const predictions = {
        weekOf: weekStart.toISOString().split("T")[0],
        overview: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroCurrent("weekly", weekKey, predictions, 7);
    return predictions;
}

/**
 * Get Hindu festivals for the month - Cache 30 days
 * @param {Date} date - Date to search for
 */
export async function getMonthlyFestivals(date) {
    const month = date.toLocaleString("en", { month: "long" });
    const year = date.getFullYear();
    const cacheKey = `festivals_${year}_${date.getMonth()}`;

    const cached = await getCachedAstroCurrent("festivals", cacheKey);
    if (cached) return cached;

    const results = await performWebSearch(
        `Hindu festivals ${month} ${year} dates panchang ekadashi purnima amavasya`
    );

    const festivals = {
        month,
        year,
        list: extractBestSnippet(results),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroCurrent("festivals", cacheKey, festivals, 30);
    return festivals;
}

/**
 * Get today's astrological weather - Cache 1 day
 * @param {Date} date - Date to search for
 */
export async function getDailyAstroWeather(date) {
    const dateStr = date.toISOString().split("T")[0];
    const cacheKey = `daily_${dateStr}`;

    const cached = await getCachedAstroCurrent("daily", cacheKey);
    if (cached) return cached;

    const month = date.toLocaleString("en", { month: "long" });
    const day = date.getDate();
    const year = date.getFullYear();

    const results = await performWebSearch(
        `astrological energy today ${month} ${day} ${year} planetary aspects vedic`
    );

    const weather = {
        date: dateStr,
        overview: extractBestSnippet(results, 300),
        searchedAt: new Date().toISOString(),
    };

    await cacheAstroCurrent("daily", cacheKey, weather, 1);
    return weather;
}

// =============================================================================
// COMPREHENSIVE CONTEXT BUILDER
// =============================================================================

/**
 * Build comprehensive astrological context for AI prompt
 * This is THE wisdom context - everything happening NOW at all timescales
 * Search liberally - for global events AND user-specific combinations
 */
export async function buildAstroSearchContext(userAstroData, todayAstroData) {
    const now = new Date();
    const month = now.toLocaleString("en", { month: "long" });
    const year = now.getFullYear();
    const context = {};

    // User's specific details for personalized searches
    const userLagna = userAstroData.ascendant || userAstroData.lagna || "";
    const userMoonSign = userAstroData.moonSign || "";
    const userNakshatra = userAstroData.nakshatra || userAstroData.moonNakshatra || "";
    const { mahaDasha, antarDasha } = normalizeDasha(userAstroData.currentDasha);

    // BATCH 1: Global knowledge (what's happening in the sky NOW)
    const [
        globalEvents,
        dailyTransitNews,
        weeklyPredictions,
        monthlyPredictions,
        monthlyFestivals,
    ] = await Promise.all([
        getGlobalAstroEvents(now),
        getDailyTransitNews(now),
        getWeeklyPredictions(now),
        getMonthlyPredictions(now),
        getMonthlyFestivals(now),
    ]);

    // BATCH 2: User-specific searches (how current events affect THIS user)
    const userSpecificSearches = await Promise.all([
        // How current transits affect user's ascendant
        userLagna ? performWebSearch(`${userLagna} ascendant ${month} ${year} predictions transits effects`) : null,
        // How current transits affect user's moon sign  
        userMoonSign ? performWebSearch(`${userMoonSign} moon sign ${month} ${year} horoscope predictions`) : null,
        // User's dasha + current time
        mahaDasha ? performWebSearch(`${mahaDasha} mahadasha ${month} ${year} predictions effects`) : null,
        // Major transit effects on user's sign (e.g., "Saturn direct Scorpio ascendant")
        userLagna && globalEvents?.retrogrades ?
            performWebSearch(`Saturn direct ${userLagna} ascendant effects 2025`) : null,
    ]);

    // BATCH 3: Panchang and static knowledge
    const [
        tithiMeaning,
        todayNakshatraMeaning,
        yogaMeaning,
        birthNakshatraMeaning,
        lagnaMeaning,
        dashaGeneral,
    ] = await Promise.all([
        getTithiMeaning(todayAstroData.panchang?.tithi),
        getNakshatraMeaning(todayAstroData.panchang?.nakshatra),
        getYogaMeaning(todayAstroData.panchang?.yoga),
        getNakshatraMeaning(userNakshatra),
        getLagnaMeaning(userLagna),
        getDashaMeaning(mahaDasha, antarDasha, "general"),
    ]);

    // Assemble context with ALL the data
    context.global = {
        events: globalEvents,
        todayNews: dailyTransitNews,
        weekly: weeklyPredictions,
        monthly: monthlyPredictions,
        festivals: monthlyFestivals,
    };

    // User-specific insights from searches
    context.userSpecific = {
        lagnaForecast: userSpecificSearches[0] ? extractBestSnippet(userSpecificSearches[0], 400) : null,
        moonSignForecast: userSpecificSearches[1] ? extractBestSnippet(userSpecificSearches[1], 400) : null,
        dashaForecast: userSpecificSearches[2] ? extractBestSnippet(userSpecificSearches[2], 400) : null,
        majorTransitEffect: userSpecificSearches[3] ? extractBestSnippet(userSpecificSearches[3], 400) : null,
    };

    context.userProfile = {
        lagna: lagnaMeaning,
        nakshatra: birthNakshatraMeaning,
    };

    context.dasha = {
        general: dashaGeneral,
    };

    context.panchang = {
        tithi: tithiMeaning,
        nakshatra: todayNakshatraMeaning,
        yoga: yogaMeaning,
    };

    // Fetch transit meanings for top house activations
    if (todayAstroData.houseActivations && Array.isArray(todayAstroData.houseActivations)) {
        const topActivations = todayAstroData.houseActivations.slice(0, 3);
        const transitMeanings = await Promise.all(
            topActivations.map(activation =>
                getTransitMeaning(activation.planet, activation.house)
            )
        );
        context.transits = transitMeanings.filter(Boolean);
    }

    // Fetch remedies for weak planets
    if (todayAstroData.shadBala) {
        const weakPlanets = Object.entries(todayAstroData.shadBala)
            .filter(([_, data]) => data.percentage_strength < 100)
            .map(([planet]) => planet);

        if (weakPlanets.length > 0) {
            const weakestPlanet = weakPlanets[0];
            context.remedies = await getPlanetRemedies(weakestPlanet, true);
        }
    }

    // Fetch retrograde guides if any planets are retrograde
    if (globalEvents?.retrogrades?.length > 0) {
        context.retrogradeGuides = await Promise.all(
            globalEvents.retrogrades.slice(0, 2).map(planet => getRetrogradeGuide(planet))
        );
    }

    return context;
}

/**
 * Perform web search using Gemini Google Search grounding
 * @param {string} query - Search query string
 * @param {number} numResults - Number of results to return (max 10)
 * @returns {Promise<Array>} Array of search results
 */
export async function performWebSearch(query, numResults = MAX_RESULTS_PER_QUERY) {
    try {
        const limited = Math.max(1, Math.min(numResults, 10));

        logger.info("Executing Gemini grounded search", {
            structuredData: true,
            query,
            numResults: limited,
        });

        const vertexAI = getVertexAI();
        const model = vertexAI.getGenerativeModel({
            model: AI_MODELS.GEMINI_FLASH,
            tools: [{ googleSearch: {} }],
        });

        const prompt = [
            "Use Google Search (grounding tool) to answer this query with real sources.",
            "",
            `Query: ${query}`,
            "",
            `Return ONLY a JSON array with up to ${limited} items. Each item must be:`,
            '{ "title": string, "snippet": string, "link": string, "displayLink": string }',
            "",
            "Rules:",
            "- No markdown, no commentary, JSON only",
            "- snippet should be 1-2 sentences",
            "- link must be a real URL from search results",
        ].join("\n");

        const result = await model.generateContent({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
        });
        const text = extractText(result) || "";

        const parsed = safeParseJsonArray(text);
        const results = (parsed || []).slice(0, limited).map((item) => ({
            title: typeof item?.title === "string" ? item.title : "",
            snippet: typeof item?.snippet === "string" ? item.snippet : "",
            link: typeof item?.link === "string" ? item.link : "",
            displayLink: typeof item?.displayLink === "string" ? item.displayLink : "",
        })).filter((r) => r.title || r.snippet || r.link);

        logger.info("Gemini grounded search completed", {
            structuredData: true,
            query,
            resultCount: results.length,
        });

        return results;
    } catch (error) {
        logger.error("Gemini grounded search failed", {
            structuredData: true,
            query,
            error: String(error),
        });
        return [];
    }
}
