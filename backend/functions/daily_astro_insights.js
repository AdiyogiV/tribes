import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";
import { geminiApiKey, freeAstrologyApiKey } from "../lib/secrets.js";
import { DateTime } from "luxon";
import { runAstroFlow } from "./free_astro.js";
import { buildAstroSearchContext } from "./search.js";
import {
    getCachedSearchContext,
    getCacheStats,
    clearAllCaches,
    clearAIInsightCaches,
    clearOldVersionedCaches,
    getCacheVersion,
    cleanupExpiredCache,
} from "./cache_utils.js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { AI_MODELS } from "../lib/config.js";
import { getFunctions } from "firebase-admin/functions";
import { calculateWholeSignHouse } from "./vedic_analysis.js";
import { getUpcomingSignIngresses, getUpcomingRetrogrades } from "./sky_positions.js";
import { extractAscendantDegree, stripMarkdown } from "../lib/astro_helpers.js";
import { INSIGHT_SYSTEM_PROMPT, buildInsightUserPrompt } from "./prompts/daily_insights.js";

// BATCH_SIZE removed - now using queue-based processing
// stripMarkdown and extractAscendantDegree imported from lib/astro_helpers.js

/**
 * Build Dasha context for narrative continuity
 * Calculates phase in current period and fetches recent themes
 * @param {string} userId - User ID
 * @param {Object} currentDasha - Current dasha data from user profile
 * @returns {Object} Dasha context for AI prompt
 */
async function buildDashaContext(userId, currentDasha) {
    const mahaDasha = currentDasha?.mahadasha || currentDasha?.maha_dasha || "";
    const antarDasha = currentDasha?.antardasha || currentDasha?.antar_dasha || "";
    const levels = currentDasha?.levels || {};

    // Calculate phase in Antar Dasha (if dates available)
    let phase = "ACTIVE"; // Default
    let percentComplete = 50;
    let daysRemaining = null;

    if (levels.antar?.start && levels.antar?.end) {
        try {
            const start = DateTime.fromISO(levels.antar.start);
            const end = DateTime.fromISO(levels.antar.end);
            const now = DateTime.now();

            const totalDays = end.diff(start, "days").days;
            const elapsedDays = now.diff(start, "days").days;
            daysRemaining = Math.max(0, Math.floor(end.diff(now, "days").days));

            percentComplete = Math.min(100, Math.max(0, Math.round((elapsedDays / totalDays) * 100)));

            if (percentComplete < 20) {
                phase = "BEGINNING";
            } else if (percentComplete > 80) {
                phase = "CLOSING";
            } else {
                phase = "ACTIVE";
            }
        } catch (e) {
            logger.warn("Could not calculate dasha phase", { error: String(e) });
        }
    }

    // Fetch recent insights for theme extraction
    let recentThemes = [];
    try {
        const sevenDaysAgo = DateTime.now().minus({ days: 7 });
        const recentInsights = await db
            .collection("users")
            .doc(userId)
            .collection("dailyInsights")
            .where("date", ">=", sevenDaysAgo.toFormat("yyyy-MM-dd"))
            .orderBy("date", "desc")
            .limit(7)
            .get();

        recentThemes = recentInsights.docs
            .map((doc) => doc.data().theme)
            .filter(Boolean);
    } catch (e) {
        logger.warn("Could not fetch recent themes", { error: String(e) });
    }

    return {
        period: mahaDasha && antarDasha ? `${mahaDasha}-${antarDasha}` : mahaDasha || "Unknown",
        mahaDasha,
        antarDasha,
        pratyantarDasha: levels.pratyantar?.lord || null,
        phase,
        percentComplete,
        daysRemaining,
        recentThemes: recentThemes.slice(0, 5),
        // Phase-specific guidance for AI
        phaseGuidance: phase === "BEGINNING" ?
            "New energies are emerging. Focus on initiating and setting intentions." :
            phase === "CLOSING" ?
                "This period is completing. Focus on integration and preparation for transition." :
                "Period is in full effect. Work actively with these energies.",
    };
}

/**
 * Generate personalized daily astrology insight using AI
 * Uses ALL available data: API + Google Search
 */
async function generateInsightWithAI(userAstroData, todayAstroData, searchContext) {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
        throw new Error("Gemini API key missing");
    }

    // Extract user's core chart data
    const lagna = userAstroData.ascendant || userAstroData.lagna || "Unknown";
    const moonSign = userAstroData.moonSign || "Unknown";
    const sunSign = userAstroData.sunSign || "Unknown";
    const nakshatra = userAstroData.nakshatra || userAstroData.moonNakshatra || "Unknown";

    // Extract dasha (all levels)
    const currentDasha = userAstroData.currentDasha || {};
    const mahaDasha = currentDasha.mahadasha || currentDasha.maha_dasha || "";
    const antarDasha = currentDasha.antardasha || currentDasha.antar_dasha || "";
    const levels = currentDasha.levels || {};

    let dashaText = "";
    if (mahaDasha) dashaText += `Mahadasha: ${mahaDasha}`;
    if (antarDasha) dashaText += `, Antardasha: ${antarDasha}`;
    if (levels.pratyantar?.lord) dashaText += `, Pratyantar: ${levels.pratyantar.lord}`;
    if (levels.sookshma?.lord) dashaText += `, Sookshma: ${levels.sookshma.lord}`;

    // Extract Raj Yogas (with full details)
    const rajYogas = userAstroData.rajYogas || [];
    const yogaNames = rajYogas.map((y) => y.name || y).filter(Boolean).join(", ") || "None detected";

    // Build detailed yoga info for AI context
    const yogaDetails = rajYogas.map((y) => {
        if (typeof y === "object" && y.name) {
            let detail = y.name;
            if (y.type) detail += ` [${y.type}]`;
            if (y.strength) detail += ` (${y.strength})`;
            if (y.planets) detail += ` - ${Array.isArray(y.planets) ? y.planets.join(", ") : y.planets}`;
            return detail;
        }
        return y;
    }).join("; ");

    // Extract Doshas (comprehensive - all calculated doshas)
    const doshas = userAstroData.doshas || {};
    const doshaList = [];
    const doshaDetails = [];

    if (doshas.mangal_dosha) {
        doshaList.push("Mangal Dosha");
        doshaDetails.push(`Mangal Dosha${doshas.mangal_dosha_house ? ` in House ${doshas.mangal_dosha_house}` : ""} - Mars influence`);
    }
    if (doshas.kaal_sarp_dosha) {
        doshaList.push("Kaal Sarp Dosha");
        doshaDetails.push("Kaal Sarp Dosha - focused karmic energy");
    }
    if (doshas.shani_dosha) {
        doshaList.push("Shani Dosha");
        doshaDetails.push(`Shani Dosha${doshas.shani_dosha_house ? ` in House ${doshas.shani_dosha_house}` : ""} - Saturn's discipline`);
    }
    if (doshas.pitra_dosha) {
        doshaList.push("Pitra Dosha");
        doshaDetails.push(`Pitra Dosha${doshas.pitra_dosha_type ? ` (${doshas.pitra_dosha_type})` : ""} - ancestral pattern`);
    }
    if (doshas.grahan_dosha) {
        doshaList.push("Grahan Dosha");
        doshaDetails.push(`Grahan Dosha${doshas.grahan_type ? ` (${doshas.grahan_type})` : ""} - eclipse influence`);
    }
    if (doshas.gandmool_dosha) {
        doshaList.push("Gandmool Dosha");
        doshaDetails.push(`Gandmool Dosha${doshas.gandmool_nakshatra ? ` (${doshas.gandmool_nakshatra})` : ""} - transformative nakshatra`);
    }
    if (doshas.has_combustion && doshas.combust_planets?.length > 0) {
        doshaList.push("Combustion");
        doshaDetails.push(`Combustion: ${doshas.combust_planets.join(", ")} planets near Sun`);
    }

    // Extract Shad Bala (planetary strength)
    const shadBala = todayAstroData.shadBala || {};
    const analysis = shadBala._analysis || {};
    const strongPlanets = (analysis.strongPlanets || []).map((p) => `${p.planet}(${p.strength}%)`).join(", ") || "Unknown";
    const weakPlanets = (analysis.weakPlanets || []).map((p) => `${p.planet}(${p.strength}%)`).join(", ") || "None";

    // Extract Panchang
    const panchang = todayAstroData.panchang || {};
    const tithi = panchang.tithi || "Unknown";
    const todayNakshatra = panchang.nakshatra || "Unknown";
    const yoga = panchang.yoga || "Unknown";
    const karana = panchang.karana || "Unknown";

    // Extract Transits (current planetary positions)
    // NOTE: Transit house numbers are calculated relative to user's natal Lagna (ascendant)
    // This is the correct Vedic astrology method for transit interpretation
    const transits = todayAstroData.transits || {};
    const transitList = Object.entries(transits)
        .filter(([name]) => name !== "Ascendant")
        .map(([name, data]) => {
            const sign = data.sign || "?";
            const house = data.house || "";
            // Transit house is relative to user's natal Lagna
            return house ? `${name} in ${sign} (transiting user's ${house}th house)` : `${name} in ${sign}`;
        })
        .join(", ") || "Unknown";

    // Today's day and ruler
    const today = DateTime.now();
    const dayLords = { 1: "Moon", 2: "Mars", 3: "Mercury", 4: "Jupiter", 5: "Venus", 6: "Saturn", 7: "Sun" };
    const todayLord = dayLords[today.weekday] || "Sun";
    const todayName = today.toFormat("EEEE");

    // Fetch ACCURATE upcoming events from pre-calculated global data
    // These are AUTHORITATIVE - calculated from actual astronomical positions
    let upcomingEventsText = "";
    try {
        // Fetch both ingresses and retrogrades (just Firestore reads - instant!)
        const [ingresses, retrogrades] = await Promise.all([
            getUpcomingSignIngresses(),
            getUpcomingRetrogrades(),
        ]);

        const majorPlanets = ["Sun", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
        const eventParts = [];

        // Format sign ingresses
        if (ingresses.length > 0) {
            const relevantIngresses = ingresses
                .filter(ing => majorPlanets.includes(ing.planet))
                .slice(0, 6);

            if (relevantIngresses.length > 0) {
                const ingressText = relevantIngresses
                    .map(ing => `${ing.planet} enters ${ing.toSign} on ${ing.date}`)
                    .join("; ");
                eventParts.push(`Sign Changes: ${ingressText}`);
            }
        }

        // Format retrogrades  
        if (retrogrades.length > 0) {
            const relevantRetros = retrogrades
                .filter(r => majorPlanets.includes(r.planet))
                .slice(0, 4);

            if (relevantRetros.length > 0) {
                const retroText = relevantRetros
                    .map(r => `${r.planet} ${r.type === "retrograde_start" ? "goes retrograde" : "goes direct"} on ${r.date}`)
                    .join("; ");
                eventParts.push(`Retrogrades: ${retroText}`);
            }
        }

        if (eventParts.length > 0) {
            upcomingEventsText = eventParts.join("\n");
            logger.info("📅 Upcoming events for AI", {
                structuredData: true,
                ingressCount: ingresses.length,
                retroCount: retrogrades.length,
                eventText: upcomingEventsText.substring(0, 200),
            });
        }
    } catch (eventsError) {
        logger.warn("Failed to fetch upcoming events", { error: String(eventsError) });
    }

    // Extract Muhurat (good/bad times)
    const muhurat = todayAstroData.muhurat || {};
    const muhuratList = [];
    if (muhurat.abhijit) muhuratList.push(`★ Abhijit Muhurat: ${muhurat.abhijit.start}-${muhurat.abhijit.end}`);
    if (muhurat.amritKaal) muhuratList.push(`★ Amrit Kaal: ${muhurat.amritKaal.start}-${muhurat.amritKaal.end}`);
    if (muhurat.brahmaMuhurat) muhuratList.push(`★ Brahma Muhurat: ${muhurat.brahmaMuhurat.start}-${muhurat.brahmaMuhurat.end}`);
    if (muhurat.rahuKaal) muhuratList.push(`⚠ Rahu Kaal: ${muhurat.rahuKaal.start}-${muhurat.rahuKaal.end}`);
    if (muhurat.yamaganda) muhuratList.push(`⚠ Yama Gandam: ${muhurat.yamaganda.start}-${muhurat.yamaganda.end}`);
    if (muhurat.gulikaKala) muhuratList.push(`⚠ Gulika Kala: ${muhurat.gulikaKala.start}-${muhurat.gulikaKala.end}`);
    if (muhurat.varjyam) muhuratList.push(`⚠ Varjyam: ${muhurat.varjyam.start}-${muhurat.varjyam.end}`);

    // Extract Google Search context (if available) - SEND MAXIMUM DATA
    let searchInsights = "";
    if (searchContext) {
        const global = searchContext.global || {};
        const userSpec = searchContext.userSpecific || {};
        const panchangMeanings = searchContext.panchang || {};
        const userProfile = searchContext.userProfile || {};
        const dashaContext = searchContext.dasha || {};

        // ============ GLOBAL COSMIC WEATHER (affects everyone) ============
        searchInsights += "\n\n=== CURRENT COSMIC WEATHER ===";

        // Retrogrades - VERY important for predictions
        if (global.events?.retrogrades?.length > 0) {
            searchInsights += `\n🔄 RETROGRADES NOW: ${global.events.retrogrades.join(", ")}`;
        } else {
            searchInsights += `\n✓ NO MAJOR RETROGRADES currently`;
        }

        // Moon phase
        if (global.events?.moonPhase) {
            const mp = global.events.moonPhase;
            searchInsights += `\n🌙 MOON PHASE: ${mp.type}${mp.sign ? ` in ${mp.sign}` : ""}${mp.date ? ` (${mp.date})` : ""}`;
        }

        // Eclipse warnings
        if (global.events?.eclipse) {
            searchInsights += `\n⚠️ ECLIPSE: ${global.events.eclipse.type} on ${global.events.eclipse.date}`;
        }

        // Today's cosmic news - full context
        if (global.todayNews?.summary) {
            searchInsights += `\n📰 TODAY'S NEWS: ${global.todayNews.summary.substring(0, 500)}`;
        }

        // Weekly outlook
        if (global.weekly?.overview) {
            searchInsights += `\n📅 THIS WEEK: ${global.weekly.overview.substring(0, 400)}`;
        }

        // Monthly context
        if (global.monthly?.overview) {
            searchInsights += `\n📆 THIS MONTH: ${global.monthly.overview.substring(0, 300)}`;
        }

        // Festivals (spiritual energy peaks)
        if (global.festivals?.list) {
            searchInsights += `\n🕉️ FESTIVALS: ${global.festivals.list.substring(0, 200)}`;
        }

        // ============ TODAY'S PANCHANG MEANINGS ============
        searchInsights += "\n\n=== TODAY'S PANCHANG SIGNIFICANCE ===";

        if (panchangMeanings.tithi?.meaning) {
            searchInsights += `\n• TITHI (${tithi}): ${panchangMeanings.tithi.meaning.substring(0, 300)}`;
        }
        if (panchangMeanings.nakshatra?.characteristics) {
            searchInsights += `\n• NAKSHATRA (${todayNakshatra}): ${panchangMeanings.nakshatra.characteristics.substring(0, 300)}`;
        }
        if (panchangMeanings.yoga?.meaning) {
            searchInsights += `\n• YOGA (${yoga}): ${panchangMeanings.yoga.meaning.substring(0, 200)}`;
        }

        // ============ USER'S PROFILE KNOWLEDGE ============
        searchInsights += "\n\n=== YOUR ASTROLOGICAL PROFILE ===";

        // Lagna (ascendant) meaning - who you are
        if (userProfile.lagna?.characteristics) {
            searchInsights += `\n• YOUR ${lagna} LAGNA: ${userProfile.lagna.characteristics.substring(0, 400)}`;
        }

        // Birth nakshatra - your soul nature
        if (userProfile.nakshatra?.characteristics) {
            searchInsights += `\n• YOUR ${nakshatra} NAKSHATRA: ${userProfile.nakshatra.characteristics.substring(0, 300)}`;
        }

        // Dasha period interpretation - current life chapter
        if (dashaContext.general?.interpretation) {
            searchInsights += `\n• YOUR ${mahaDasha}-${antarDasha} DASHA: ${dashaContext.general.interpretation.substring(0, 400)}`;
        }

        // ============ USER-SPECIFIC FORECASTS ============
        searchInsights += "\n\n=== YOUR CURRENT FORECASTS ===";

        if (userSpec.lagnaForecast) {
            searchInsights += `\n• ${lagna} ASCENDANT NOW: ${userSpec.lagnaForecast.substring(0, 400)}`;
        }
        if (userSpec.moonSignForecast) {
            searchInsights += `\n• ${moonSign} MOON NOW: ${userSpec.moonSignForecast.substring(0, 400)}`;
        }
        if (userSpec.dashaForecast) {
            searchInsights += `\n• ${mahaDasha} PERIOD NOW: ${userSpec.dashaForecast.substring(0, 400)}`;
        }
        if (userSpec.majorTransitEffect) {
            searchInsights += `\n• MAJOR TRANSIT EFFECT: ${userSpec.majorTransitEffect.substring(0, 300)}`;
        }

        // ============ REMEDIES FOR WEAK PLANETS ============
        if (searchContext.remedies?.advice) {
            searchInsights += `\n\n=== REMEDIES ===`;
            searchInsights += `\n${searchContext.remedies.planet} REMEDY: ${searchContext.remedies.advice.substring(0, 300)}`;
        }

        // ============ RETROGRADE GUIDES ============
        if (searchContext.retrogradeGuides?.length > 0) {
            searchInsights += `\n\n=== RETROGRADE GUIDANCE ===`;
            for (const guide of searchContext.retrogradeGuides) {
                if (guide?.guide) {
                    searchInsights += `\n${guide.planet} RETROGRADE: ${guide.guide.substring(0, 250)}`;
                }
            }
        }
    }

    // Log what we're sending to AI
    logger.info("📊 Insight Generation Data", {
        structuredData: true,
        userId: userAstroData.userId || "unknown",
        lagna,
        moonSign,
        sunSign,
        nakshatra,
        dashaText,
        rajYogas: yogaNames,
        doshas: doshaList.join(", ") || "None",
        strongPlanets,
        weakPlanets,
        todayTithi: tithi,
        todayNakshatra,
        todayYoga: yoga,
        todayLord,
        transitCount: Object.keys(transits).length,
        hasSearchContext: !!searchContext,
        searchInsightsLength: searchInsights.length,
    });

    const prompt = buildInsightUserPrompt({
        lagna,
        moonSign,
        sunSign,
        nakshatra,
        dashaText,
        yogaNames,
        doshaList,
        todayName,
        todayLord,
        tithi,
        todayNakshatra,
        strongPlanets,
        weakPlanets,
        transitList,
        upcomingEventsText,
        searchInsights,
    });

    logger.info("🤖 Sending to Gemini", {
        structuredData: true,
        promptLength: prompt.length,
        model: AI_MODELS.GEMINI_FLASH,
    });

    try {
        // Initialize Gemini
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({
            model: AI_MODELS.GEMINI_FLASH,
            // Enable Google Search grounding so Gemini can fetch current info directly.
            // (We no longer rely on Google Custom Search API keys.)
            tools: [{ googleSearch: {} }],
            generationConfig: {
                temperature: 0.92, // Higher for more creative, engaging outputs
                maxOutputTokens: 1500, // Room for richer content
            },
        });

        const result = await model.generateContent([
            { text: INSIGHT_SYSTEM_PROMPT },
            { text: prompt },
        ]);

        const response = result.response;
        const rawContent = response.text()?.trim();

        logger.info("🤖 Gemini Response received", {
            structuredData: true,
            responseLength: rawContent?.length || 0,
        });

        if (!rawContent) {
            throw new Error("AI returned empty response");
        }

        // Parse JSON
        let parsed;
        try {
            let cleaned = rawContent;
            if (cleaned.startsWith("```json")) cleaned = cleaned.slice(7);
            if (cleaned.startsWith("```")) cleaned = cleaned.slice(3);
            if (cleaned.endsWith("```")) cleaned = cleaned.slice(0, -3);
            parsed = JSON.parse(cleaned.trim());
        } catch (parseError) {
            logger.error("JSON parse failed", { rawContent: rawContent.substring(0, 500) });
            parsed = {
                theme: "Today's Guidance",
                message: rawContent.substring(0, 300),
                sections: [],
            };
        }

        // Ensure required fields
        if (!parsed.theme) parsed.theme = "Today's Guidance";
        if (!parsed.message) parsed.message = "Your cosmic blueprint holds unique potential today. Trust the energies aligning in your favor and take inspired action where you feel called.";
        if (!parsed.sections) parsed.sections = [];

        // Ensure each section has displayOrder and scheduledFor (4 insights for full day)
        const defaultSchedules = ["06:00", "12:00", "17:00", "21:00"];
        parsed.sections = parsed.sections.slice(0, 4).map((section, index) => ({
            title: section.title || `Section ${index + 1}`,
            content: section.content || "",
            cardType: section.cardType || "insight", // Unified type for backward compatibility
            displayOrder: section.displayOrder || (index + 1),
            scheduledFor: section.scheduledFor || defaultSchedules[index] || "06:00",
        }));

        logger.info("✅ Insight generated", {
            structuredData: true,
            theme: parsed.theme,
            messageLength: parsed.message?.length,
            sectionCount: parsed.sections?.length,
        });

        return parsed;
    } catch (error) {
        logger.error("AI insight generation failed", { error: String(error) });
        throw error;
    }
}

/**
 * Get today's astrological data for a user's location
 * Fetches ALL available data from API
 * Uses current location if provided, otherwise falls back to birth location
 */
async function getTodayAstroData(userAstroData) {
    const { birthLatitude, birthLongitude, timeZone, timeZoneOffset } = userAstroData;

    // For "today's" data, prefer current location over birth location
    // Current location can be passed in userAstroData.currentLatitude/currentLongitude
    // or we can use device location if available
    const latitude = userAstroData.currentLatitude ?? birthLatitude;
    const longitude = userAstroData.currentLongitude ?? birthLongitude;

    // Use current timezone if provided, otherwise use birth timezone
    const currentTimeZone = userAstroData.currentTimeZone ?? timeZone;
    const currentTimeZoneOffset = typeof userAstroData.currentTimeZoneOffset === "number"
        ? userAstroData.currentTimeZoneOffset
        : (typeof timeZoneOffset === "number" ? timeZoneOffset : 0);

    if (!latitude || !longitude) {
        logger.warn("Missing location data for user");
        return { panchang: {}, transits: {}, shadBala: {} };
    }

    try {
        const now = DateTime.now().setZone(currentTimeZone || "UTC");
        const todayPayload = {
            year: now.year,
            month: now.month,
            date: now.day,
            hours: now.hour,
            minutes: now.minute,
            seconds: Math.floor(now.second),
            latitude: latitude,
            longitude: longitude,
            timezone: currentTimeZoneOffset,
        };

        logger.info("📅 Fetching today's astro data", {
            structuredData: true,
            userId: userAstroData.userId || "unknown",
            date: now.toFormat("yyyy-MM-dd HH:mm"),
            timezone: currentTimeZone || "UTC",
            timezoneOffset: currentTimeZoneOffset,
            location: `${latitude}, ${longitude}`,
            usingCurrentLocation: !!(userAstroData.currentLatitude && userAstroData.currentLongitude),
            birthLocation: `${birthLatitude}, ${birthLongitude}`,
            birthTimezone: timeZone || "UTC",
            payload: JSON.stringify(todayPayload),
        });

        const result = await runAstroFlow({
            mode: "full",
            payload: todayPayload,
            // IMPORTANT: use *current* timezone inputs (not birth timezone)
            timeZoneId: currentTimeZone || "UTC",
            timeZoneOffset: currentTimeZoneOffset,
        });

        // Extract panchang (no samvat fallback merge)
        const panchang = result.panchang || {};

        // Log panchang data for debugging - this will show what's different between users
        logger.info("📊 Panchang data received", {
            structuredData: true,
            userId: userAstroData.userId || "unknown",
            tithi: panchang.tithi || "missing",
            nakshatra: panchang.nakshatra || "missing",
            yoga: panchang.yoga || "missing",
            karana: panchang.karana || "missing",
            tithiPaksha: panchang.tithiPaksha || "missing",
            tithiName: panchang.name || "missing",
            paksha: panchang.paksha || "missing",
            lunarMonthFull: panchang.lunar_month_full_name || "missing",
            lunarMonth: panchang.lunar_month_name || "missing",
            vikramYear: panchang.vikram_chaitradi_number || "missing",
            vikramYearName: panchang.vikram_chaitradi_year_name || "missing",
            fullPanchang: JSON.stringify(panchang),
        });

        // Log samvat info if available
        if (result.samvatInfo) {
            logger.info("📅 Samvat info received", {
                structuredData: true,
                userId: userAstroData.userId || "unknown",
                timestamp: result.samvatInfo.timestamp || "missing",
                tithiName: result.samvatInfo.name || "missing",
                paksha: result.samvatInfo.paksha || "missing",
                lunarMonthFull: result.samvatInfo.lunar_month_full_name || "missing",
                lunarMonth: result.samvatInfo.lunar_month_name || "missing",
                vikramYear: result.samvatInfo.vikram_chaitradi_number || "missing",
                vikramYearName: result.samvatInfo.vikram_chaitradi_year_name || "missing",
                fullSamvatInfo: JSON.stringify(result.samvatInfo),
            });
        } else {
            logger.warn("⚠️ Samvat info is MISSING for today", {
                structuredData: true,
                userId: userAstroData.userId || "unknown",
            });
        }

        // Extract planetary positions (transits)
        // CRITICAL FIX: Calculate transit houses relative to USER'S natal ascendant
        // The API returns house numbers based on the CURRENT sky's ascendant (changes every ~2 hours)
        // But in Vedic astrology, transit houses must be calculated from the user's BIRTH ascendant
        const planets = result.birthChartData?.output || result.birthChartData?.planets || {};
        const transits = {};

        // Get user's natal ascendant degree for correct transit house calculation
        const userAscendantDegree = extractAscendantDegree(userAstroData);

        if (userAscendantDegree == null) {
            logger.warn("⚠️ Could not extract user's natal ascendant degree - transit houses may be inaccurate", {
                structuredData: true,
                userId: userAstroData.userId || "unknown",
                hasProcessedPlanets: !!userAstroData.processedPlanets,
                hasBirthChartData: !!userAstroData.birthChartData,
            });
        } else {
            // Calculate the sign name for logging
            const SIGN_NAMES = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
                "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"];
            const ascSignIndex = Math.floor(userAscendantDegree / 30);
            logger.info("📊 Using WHOLE SIGN houses for transit calculation", {
                structuredData: true,
                userId: userAstroData.userId || "unknown",
                userAscendantDegree: userAscendantDegree.toFixed(2),
                ascendantSign: SIGN_NAMES[ascSignIndex] || "Unknown",
                ascendantSignIndex: ascSignIndex,
                note: "Whole sign = planet in same sign as Lagna is in 1st house",
            });
        }

        if (planets && typeof planets === "object") {
            Object.entries(planets).forEach(([key, data]) => {
                if (data && typeof data === "object") {
                    const name = data.name || key;
                    const transitDegree = data.fullDegree || data.full_degree;

                    // Calculate transit house using WHOLE SIGN houses (standard for transit analysis)
                    // In whole sign system: planet in same sign as Lagna = 1st house
                    // This is different from Bhava calculation which uses exact degrees
                    let transitHouse = null;
                    if (transitDegree != null && userAscendantDegree != null) {
                        transitHouse = calculateWholeSignHouse(transitDegree, userAscendantDegree);
                    } else {
                        // Fallback to API's house number if we can't calculate correctly
                        transitHouse = data.house_number || data.house;
                    }

                    transits[name] = {
                        sign: data.zodiac_sign_name || data.sign,
                        house: transitHouse,
                        degree: transitDegree,
                        isRetro: data.isRetro === true || data.isRetro === "true",
                    };
                }
            });
        }

        // Extract Shad Bala (planetary strength)
        const shadBala = result.shadBala || {};

        // Extract Muhurat data (good/bad times)
        const muhurat = {};
        const muhuratSource = result.muhurat?.days?.[DateTime.now().toFormat("yyyy-MM-dd")] || {};
        if (muhuratSource.rahuKala) muhurat.rahuKaal = muhuratSource.rahuKala;
        if (muhuratSource.yamaganda) muhurat.yamaganda = muhuratSource.yamaganda;
        if (muhuratSource.gulikaKala) muhurat.gulikaKala = muhuratSource.gulikaKala;
        if (muhuratSource.abhijit) muhurat.abhijit = muhuratSource.abhijit;
        if (muhuratSource.amrit) muhurat.amritKaal = muhuratSource.amrit;
        if (muhuratSource.brahmaMuhurat) muhurat.brahmaMuhurat = muhuratSource.brahmaMuhurat;
        if (muhuratSource.durMuhurat) muhurat.durMuhurat = muhuratSource.durMuhurat;
        if (muhuratSource.varjyam) muhurat.varjyam = muhuratSource.varjyam;

        // TODAY's samvat info (lunar month + vikram year + calendar data)
        // This is calculated for TODAY's date (not birth date).
        // Stored separately so frontend can distinguish from birth samvat.
        const todaySamvat = result.samvatInfo || null;

        logger.info("✅ Today's data fetched", {
            structuredData: true,
            panchangKeys: Object.keys(panchang).filter((k) => panchang[k]).length,
            transitCount: Object.keys(transits).length,
            hasShadBala: Object.keys(shadBala).length > 0,
            hasMuhurat: Object.keys(muhurat).length > 0,
            muhuratKeys: Object.keys(muhurat).join(", "),
            hasTodaySamvat: !!todaySamvat,
            todaySamvatLunarMonth: todaySamvat?.lunar_month_full_name || "missing",
            todaySamvatVikram: todaySamvat?.vikram_chaitradi_number || "missing",
        });

        return { panchang, transits, shadBala, muhurat, todaySamvat };
    } catch (error) {
        logger.error("Failed to get today's astro data", { error: String(error) });
        return { panchang: {}, transits: {}, shadBala: {}, todaySamvat: null };
    }
}

/**
 * Build Google Search context for a user
 * Uses tiered caching:
 * - Global data (retrogrades, weekly, monthly): cached for all users
 * - User-specific data (lagna forecast, dasha forecast): cached per user combination
 */
async function getSearchContext(userAstroData, todayAstroData) {
    try {
        // Search context is powered by Gemini Google Search grounding (no Custom Search API).
        // If Gemini isn't configured, skip gracefully.
        const apiKey = geminiApiKey.value();
        if (!apiKey) {
            logger.warn("⚠️ Gemini not configured, skipping search context");
            return null;
        }

        const today = DateTime.now().toFormat("yyyy-MM-dd");
        const startTime = Date.now();

        // Build context - the buildAstroSearchContext already uses caching internally
        // Each search function (getLagnaMeaning, getDashaMeaning, etc.) has its own cache
        logger.info("🔍 Building search context...", {
            structuredData: true,
            date: today,
            userLagna: userAstroData.ascendant || userAstroData.lagna || "unknown",
            userMoon: userAstroData.moonSign || "unknown",
            userDasha: userAstroData.currentDasha?.mahadasha || "unknown",
        });

        const context = await buildAstroSearchContext(userAstroData, todayAstroData);

        const duration = Date.now() - startTime;

        // Count what we got
        const stats = {
            durationMs: duration,
            // Global
            hasRetrogrades: context?.global?.events?.retrogrades?.length || 0,
            hasMoonPhase: !!context?.global?.events?.moonPhase,
            hasEclipse: !!context?.global?.events?.eclipse,
            hasTodayNews: !!context?.global?.todayNews?.summary,
            hasWeekly: !!context?.global?.weekly?.overview,
            hasMonthly: !!context?.global?.monthly?.overview,
            hasFestivals: !!context?.global?.festivals?.list,
            // Panchang
            hasTithiMeaning: !!context?.panchang?.tithi?.meaning,
            hasNakshatraMeaning: !!context?.panchang?.nakshatra?.characteristics,
            hasYogaMeaning: !!context?.panchang?.yoga?.meaning,
            // User profile
            hasLagnaMeaning: !!context?.userProfile?.lagna?.characteristics,
            hasNakshatraProfile: !!context?.userProfile?.nakshatra?.characteristics,
            hasDashaMeaning: !!context?.dasha?.general?.interpretation,
            // User forecasts
            hasLagnaForecast: !!context?.userSpecific?.lagnaForecast,
            hasMoonForecast: !!context?.userSpecific?.moonSignForecast,
            hasDashaForecast: !!context?.userSpecific?.dashaForecast,
            hasMajorTransit: !!context?.userSpecific?.majorTransitEffect,
            // Remedies
            hasRemedies: !!context?.remedies?.advice,
            retrogradeGuides: context?.retrogradeGuides?.length || 0,
        };

        // Count total data points
        const dataPoints = Object.values(stats).filter((v) => v === true || (typeof v === "number" && v > 0)).length;

        logger.info("✅ Search context built", {
            structuredData: true,
            totalDataPoints: dataPoints,
            ...stats,
        });

        return context;
    } catch (error) {
        logger.error("❌ Search context build failed (continuing without search)", {
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        // Don't fail the whole insight - just return null and continue
        return null;
    }
}

/**
 * Generate insight for a specific user
 * @param {boolean} forceRegenerate - If true, always generate new content (for 4x daily runs)
 */
async function generateInsightForUser(userId, userAstroData, forceRegenerate = true) {
    const today = DateTime.now().toFormat("yyyy-MM-dd");
    const insightRef = db
        .collection("users")
        .doc(userId)
        .collection("dailyInsights")
        .doc(today);

    // With 4x daily generations, we ALWAYS regenerate to give fresh content
    // Each generation sends all card notifications
    if (forceRegenerate) {
        logger.info("🔄 Generating fresh insight (4x daily mode)", { userId, date: today });
    } else {
        // Check if already exists (legacy behavior)
        const existing = await insightRef.get();
        if (existing.exists) {
            logger.info("Insight already exists", { userId, date: today });
            return { ...existing.data(), date: today, alreadyExists: true };
        }
    }

    // Generate new insight; first-time gets immediate delivery, else staggered
    const existing = await insightRef.get();
    return generateNewInsight(userId, userAstroData, insightRef, today, false, !existing.exists);
}

/**
 * Generate insight for user with force option
 * Key: generates NEW insight first, THEN saves (old stays visible until new is ready)
 * @exported for use by astro_sync.js to generate insights for new users
 */
export async function generateInsightForUserForce(userId, userAstroData, forceRegenerate = false) {
    const today = DateTime.now().toFormat("yyyy-MM-dd");
    const insightRef = db
        .collection("users")
        .doc(userId)
        .collection("dailyInsights")
        .doc(today);

    // If not forcing, check if exists
    if (!forceRegenerate) {
        const existing = await insightRef.get();
        if (existing.exists) {
            logger.info("Insight already exists", { userId, date: today });
            return { ...existing.data(), date: today, alreadyExists: true };
        }
    } else {
        // COOLDOWN CHECK: Prevent notification spam from rapid successive regeneration calls
        // If insight was generated within the last 5 minutes, skip notifications
        const existing = await insightRef.get();
        let skipNotification = false;

        if (existing.exists) {
            const data = existing.data();
            const generatedAt = data?.generatedAt?.toDate?.() || data?.generatedAt;
            if (generatedAt) {
                const generatedTime = new Date(generatedAt).getTime();
                const now = Date.now();
                const fiveMinutes = 5 * 60 * 1000;

                if (now - generatedTime < fiveMinutes) {
                    skipNotification = true;
                    logger.info("🔄 Force regenerating but SKIPPING notifications (cooldown active)", {
                        userId,
                        date: today,
                        lastGeneratedMs: now - generatedTime,
                        cooldownMs: fiveMinutes,
                    });
                } else {
                    logger.info("🔄 Force regenerating (old stays until new ready)", { userId, date: today });
                }
            }
        } else {
            logger.info("🔄 Force regenerating (no existing insight)", { userId, date: today });
        }

        // First-time (no existing): deliver immediately so user gets notifications now
        const immediateDelivery = !existing.exists;
        return generateNewInsight(userId, userAstroData, insightRef, today, skipNotification, immediateDelivery);
    }

    // First-time insight (no existing): deliver immediately
    return generateNewInsight(userId, userAstroData, insightRef, today, false, true);
}

/**
 * Extract predictions from insight sections and save for tracking
 * @param {string} userId - User ID
 * @param {string} insightDate - Date of the insight (yyyy-MM-dd)
 * @param {Array} sections - Processed insight sections
 */
async function extractAndSavePredictions(userId, insightDate, sections) {
    const predictionSections = sections.filter((s) =>
        s.data?.date, // Any section with a date is a prediction
    );

    if (predictionSections.length === 0) {
        logger.info("[PREDICTIONS] No predictions to extract", {
            structuredData: true,
            userId,
            insightDate,
        });
        return;
    }

    const predictionsRef = db.collection("users").doc(userId).collection("predictions");

    for (const section of predictionSections) {
        const data = section.data || {};

        // Parse the target date (try various formats including date ranges)
        let targetDate = null;
        if (data.date) {
            const dateStr = data.date.trim();
            const currentYear = DateTime.now().year;

            // Handle date RANGES like "December 10-16, 2025" or "Dec 10 - Dec 16"
            // Extract the START date from a range
            const rangePatterns = [
                // "December 10-16, 2025" or "December 10-16"
                /^([A-Za-z]+)\s+(\d{1,2})\s*[-–]\s*\d{1,2}(?:,?\s*(\d{4}))?$/,
                // "Dec 10 - Dec 16, 2025"
                /^([A-Za-z]+)\s+(\d{1,2})\s*[-–]\s*[A-Za-z]+\s+\d{1,2}(?:,?\s*(\d{4}))?$/,
                // "10-16 December 2025"
                /^(\d{1,2})\s*[-–]\s*\d{1,2}\s+([A-Za-z]+)(?:\s+(\d{4}))?$/,
            ];

            let rangeMatch = null;
            for (const pattern of rangePatterns) {
                rangeMatch = dateStr.match(pattern);
                if (rangeMatch) break;
            }

            if (rangeMatch) {
                // Extract month/day from range - use the START date
                let month; let day; let year;
                if (/^\d/.test(rangeMatch[1])) {
                    // "10-16 December 2025" format
                    day = rangeMatch[1];
                    month = rangeMatch[2];
                    year = rangeMatch[3] || currentYear;
                } else {
                    // "December 10-16, 2025" format
                    month = rangeMatch[1];
                    day = rangeMatch[2];
                    year = rangeMatch[3] || currentYear;
                }

                // Parse the extracted date
                const dateToTry = `${month} ${day}, ${year}`;
                let parsed = DateTime.fromFormat(dateToTry, "MMMM d, yyyy");
                if (!parsed.isValid) {
                    parsed = DateTime.fromFormat(dateToTry, "MMM d, yyyy");
                }
                if (parsed.isValid) {
                    if (parsed < DateTime.now()) {
                        parsed = parsed.plus({ years: 1 });
                    }
                    targetDate = parsed.toFormat("yyyy-MM-dd");
                }
            }

            // If not a range, try single date formats
            if (!targetDate) {
                const formats = [
                    "MMMM d, yyyy", // December 12, 2025
                    "MMM d, yyyy", // Dec 12, 2025
                    "MMM d", // Dec 12
                    "MMMM d", // December 12
                    "d MMM", // 12 Dec
                    "d MMMM", // 12 December
                    "yyyy-MM-dd", // 2024-12-12
                ];

                for (const format of formats) {
                    try {
                        let parsed = DateTime.fromFormat(dateStr, format);
                        if (parsed.isValid) {
                            // If year not in format, assume current or next year
                            if (!format.includes("yyyy")) {
                                parsed = parsed.set({ year: currentYear });
                                // If the date is in the past, assume next year
                                if (parsed < DateTime.now()) {
                                    parsed = parsed.plus({ years: 1 });
                                }
                            }
                            targetDate = parsed.toFormat("yyyy-MM-dd");
                            break;
                        }
                    } catch (e) {
                        // Try next format
                    }
                }
            }
        }

        if (!targetDate) {
            logger.warn("[PREDICTIONS] Could not parse target date", {
                structuredData: true,
                userId,
                rawDate: data.date,
            });
            continue;
        }

        // Create prediction document
        const predictionDoc = {
            createdAt: FieldValue.serverTimestamp(),
            targetDate,
            planet: data.planet || null,
            event: data.event || null,
            house: data.house || null,
            prediction: section.content?.substring(0, 500) || "",
            title: section.title || "",
            status: "pending", // pending | validated | expired
            insightDate,
            cardIndex: section.sectionIndex || 0,
        };

        const docRef = await predictionsRef.add(predictionDoc);

        logger.info("[PREDICTIONS] Saved prediction", {
            structuredData: true,
            userId,
            predictionId: docRef.id,
            targetDate,
            planet: data.planet,
            event: data.event,
        });
    }
}

// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
// CLOUD TASKS DISPATCH: Enqueue scheduled notification tasks
// Each card gets its own Cloud Task scheduled for specific time
// ═══════════════════════════════════════════════════════════════

/**
 * Enqueue dispatch tasks for each card notification
 * Each task is scheduled for its specific time (6 AM, 12 PM, 5 PM, 9 PM IST)
 * @param {string} userId - User ID
 * @param {string} date - Date string (yyyy-MM-dd)
 * @param {Array} sections - Processed sections with scheduledFor times
 */
async function enqueueDispatchTasks(userId, date, sections) {
    if (!sections || sections.length === 0) {
        return;
    }

    const functions = getFunctions();
    const dispatchQueue = functions.taskQueue("locations/asia-southeast2/functions/dispatchCardNotification");

    const now = DateTime.now().setZone("Asia/Kolkata");
    const todayDateStr = now.toFormat("yyyy-MM-dd");

    // Parse the date from insight (should be today's date)
    const insightDate = DateTime.fromFormat(date, "yyyy-MM-dd", { zone: "Asia/Kolkata" });

    let enqueued = 0;
    let failed = 0;

    for (let i = 0; i < sections.length; i++) {
        const section = sections[i];
        const scheduledFor = section.scheduledFor || "06:00";

        // Parse scheduled time (e.g., "06:00" -> 6 AM IST on insight date)
        const [hours, minutes] = scheduledFor.split(":").map(Number);
        let scheduledTime = insightDate.set({ hour: hours, minute: minutes, second: 0, millisecond: 0 });

        // If scheduled time is in the past, schedule for today (if generating late)
        // This handles edge case where generation happens after scheduled time
        if (scheduledTime < now) {
            scheduledTime = now.set({ hour: hours, minute: minutes, second: 0, millisecond: 0 });
            // If still in past, schedule for next occurrence (tomorrow)
            if (scheduledTime < now) {
                scheduledTime = scheduledTime.plus({ days: 1 });
            }
        }

        // Calculate seconds until scheduled time
        const delaySeconds = Math.max(0, Math.floor((scheduledTime.toMillis() - now.toMillis()) / 1000));

        try {
            await dispatchQueue.enqueue({
                userId,
                date,
                cardIndex: i,
                cardType: "insight", // Unified type
                title: section.title || "",
                content: section.content || "",
                scheduledFor,
            }, {
                scheduleDelaySeconds: delaySeconds,
            });

            enqueued++;
        } catch (error) {
            failed++;
            logger.error("[DISPATCH-ENQUEUE] Failed to enqueue dispatch task", {
                structuredData: true,
                userId,
                cardIndex: i,
                scheduledFor,
                error: String(error),
            });
        }
    }

    logger.info("[DISPATCH-ENQUEUE] Enqueued dispatch tasks", {
        structuredData: true,
        userId,
        date,
        enqueued,
        failed,
        totalCards: sections.length,
    });
}

// ═══════════════════════════════════════════════════════════════
// IMMEDIATE NOTIFICATION DELIVERY
// Sends ALL card notifications together with delays between each
// ═══════════════════════════════════════════════════════════════

/**
 * Helper to wait for specified milliseconds
 */
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Send ALL card notifications for an insight immediately
 * Cards are sent with 10 second delays between each
 * @param {string} userId - User ID
 * @param {string} today - Date string (yyyy-MM-dd)
 * @param {Array} sections - Processed sections from insight
 * @param {DocumentReference} insightRef - Reference to insight document
 */
async function sendAllCardNotifications(userId, today, sections, insightRef) {
    logger.info("[NOTIFICATIONS] Starting immediate delivery of all cards", {
        structuredData: true,
        userId,
        date: today,
        cardCount: sections.length,
    });

    const DELAY_BETWEEN_CARDS_MS = 10000; // 10 seconds between each notification
    let sentCount = 0;
    let errorCount = 0;

    for (let index = 0; index < sections.length; index++) {
        const section = sections[index];

        // Add delay between notifications (skip for first one)
        if (index > 0) {
            logger.info(`[NOTIFICATIONS] Waiting ${DELAY_BETWEEN_CARDS_MS / 1000}s before next card`, {
                structuredData: true,
                userId,
                nextCard: index,
            });
            await delay(DELAY_BETWEEN_CARDS_MS);
        }

        try {
            // Create notification document
            const notificationRef = db
                .collection("notifications")
                .doc(userId)
                .collection("notifications")
                .doc();

            const notificationData = {
                type: "dailyAstroInsight",
                cardType: "insight", // Unified type
                cardIndex: index,
                totalCards: sections.length,
                title: section.title || "",
                preview: stripMarkdown(section.content || "").substring(0, 150),
                sectionData: section.data || {},
                insightId: today,
                date: today,
                timestamp: FieldValue.serverTimestamp(),
                read: false,
            };

            await notificationRef.set(notificationData);

            // Mark this card as notified in the insight document
            await insightRef.update({
                [`cardNotifications.${index}.sent`]: true,
                [`cardNotifications.${index}.sentAt`]: FieldValue.serverTimestamp(),
            });

            sentCount++;
            logger.info(`[NOTIFICATIONS] Sent card ${index + 1}/${sections.length}`, {
                structuredData: true,
                userId,
                cardIndex: index,
                title: section.title,
            });
        } catch (cardError) {
            errorCount++;
            logger.error(`[NOTIFICATIONS] Failed to send card ${index}`, {
                structuredData: true,
                userId,
                cardIndex: index,
                error: String(cardError),
            });
        }
    }

    logger.info("[NOTIFICATIONS] Completed delivery", {
        structuredData: true,
        userId,
        date: today,
        sentCount,
        errorCount,
        totalCards: sections.length,
    });

    return { sentCount, errorCount };
}

/**
 * Core insight generation logic
 * When immediateDelivery is true (first-time insight): send all card notifications now.
 * When false: enqueue staggered tasks (6 AM, 12 PM, 5 PM, 9 PM IST).
 * @param {boolean} skipNotification - When true, skip both immediate and staggered delivery (e.g. cooldown)
 * @param {boolean} immediateDelivery - When true, deliver all cards now via sendAllCardNotifications; skip enqueue.
 */
async function generateNewInsight(userId, userAstroData, insightRef, today, skipNotification = false, immediateDelivery = false) {
    try {
        const startTime = Date.now();

        // Log what user data we have
        logger.info("🌟 Starting insight generation", {
            structuredData: true,
            userId,
            date: today,
            userDataAvailable: {
                lagna: !!(userAstroData.ascendant || userAstroData.lagna),
                moonSign: !!userAstroData.moonSign,
                sunSign: !!userAstroData.sunSign,
                nakshatra: !!(userAstroData.nakshatra || userAstroData.moonNakshatra),
                dasha: !!userAstroData.currentDasha,
                dashaLord: userAstroData.currentDasha?.mahadasha || userAstroData.currentDasha?.maha_dasha || "none",
                rajYogas: userAstroData.rajYogas?.length || 0,
                doshas: Object.keys(userAstroData.doshas || {}).length,
                location: !!(userAstroData.birthLatitude && userAstroData.birthLongitude),
            },
        });

        // Step 1: Get today's astronomical data
        const step1Start = Date.now();
        const todayAstroData = await getTodayAstroData(userAstroData);
        const step1Duration = Date.now() - step1Start;

        // Step 1.5: Build Dasha context for narrative continuity
        const dashaContext = await buildDashaContext(userId, userAstroData.currentDasha);
        logger.info("[DASHA] Built dasha context", {
            structuredData: true,
            userId,
            period: dashaContext.period,
            phase: dashaContext.phase,
            percentComplete: dashaContext.percentComplete,
            daysRemaining: dashaContext.daysRemaining,
            recentThemesCount: dashaContext.recentThemes?.length || 0,
        });

        // Step 2: Get Google Search context (optional but valuable)
        const step2Start = Date.now();
        const searchContext = await getSearchContext(userAstroData, todayAstroData);
        const step2Duration = Date.now() - step2Start;

        // Step 3: Generate insight with AI using ALL data
        const step3Start = Date.now();
        const structured = await generateInsightWithAI(userAstroData, todayAstroData, searchContext);
        const step3Duration = Date.now() - step3Start;

        // Use scheduledFor from AI response (Gemini now generates this)
        // Fallback to first slot if missing
        const getScheduleFor = (section) => {
            return section.scheduledFor || "06:00"; // Default to first slot
        };

        // Process sections with scheduling info
        const processedSections = (structured.sections || []).map((section, index) => ({
            ...section,
            cardType: section.cardType || "insight", // Unified type
            scheduledFor: getScheduleFor(section),
            sectionIndex: index,
            dispatched: false, // Track if notification sent
        }));

        // Build cardNotifications tracking map
        const cardNotifications = {};
        processedSections.forEach((section, index) => {
            cardNotifications[index] = {
                sent: false,
                window: section.scheduledFor,
                cardType: "insight", // Unified type
            };
        });

        const insightData = {
            theme: structured.theme || "Today's Guidance",
            message: structured.message || "",
            sections: processedSections,
            generatedAt: FieldValue.serverTimestamp(),
            date: today,
            version: "v7", // Bumped version for staggered delivery
            // Legacy field for backward compatibility
            astrologicalData: {
                transits: todayAstroData.transits,
                panchang: todayAstroData.panchang,
                shadBala: todayAstroData.shadBala?._analysis || null,
                // TODAY's samvat info (lunar month, vikram year, calendar data)
                // This is for TODAY's date — distinct from profile.samvatInfo (birth date)
                todaySamvat: todayAstroData.todaySamvat || null,
            },
            // NEW: Complete context for AI chat reuse
            // This allows chat to have the SAME context used to generate the insight
            astroContext: {
                // User's birth chart (static)
                userChart: {
                    sunSign: userAstroData.sunSign,
                    moonSign: userAstroData.moonSign,
                    ascendant: userAstroData.ascendant || userAstroData.lagna,
                    nakshatra: userAstroData.nakshatra || userAstroData.moonNakshatra,
                    currentDasha: userAstroData.currentDasha,
                    rajYogas: userAstroData.rajYogas?.map((y) => y.name || y) || [],
                    doshas: userAstroData.doshas,
                },
                // Dasha narrative context for continuity
                dashaContext: {
                    period: dashaContext.period,
                    phase: dashaContext.phase,
                    percentComplete: dashaContext.percentComplete,
                    daysRemaining: dashaContext.daysRemaining,
                    phaseGuidance: dashaContext.phaseGuidance,
                    recentThemes: dashaContext.recentThemes,
                },
                // Today's cosmic weather
                todayData: {
                    transits: todayAstroData.transits,
                    panchang: todayAstroData.panchang,
                    shadBala: todayAstroData.shadBala?._analysis || null,
                    muhurat: todayAstroData.muhurat,
                },
                // Search context summary (if available)
                cosmicWeather: searchContext ? {
                    retrogrades: searchContext.global?.events?.retrogrades || [],
                    moonPhase: searchContext.global?.events?.moonPhase,
                    eclipse: searchContext.global?.events?.eclipse,
                    todayNews: searchContext.global?.todayNews?.summary?.substring(0, 300),
                    weekly: searchContext.global?.weekly?.overview?.substring(0, 200),
                } : null,
                forecasts: searchContext?.userSpecific ? {
                    lagna: searchContext.userSpecific.lagnaForecast?.substring(0, 200),
                    moonSign: searchContext.userSpecific.moonSignForecast?.substring(0, 200),
                    dasha: searchContext.userSpecific.dashaForecast?.substring(0, 200),
                } : null,
            },
            notificationSent: false,
            // Staggered delivery tracking - per-card notification status
            cardNotifications: cardNotifications,
        };

        // Save (overwrites any existing - atomic operation)
        await insightRef.set(insightData);

        const totalDuration = Date.now() - startTime;

        logger.info("✅ Insight saved", {
            structuredData: true,
            userId,
            date: today,
            theme: insightData.theme,
            sectionCount: insightData.sections?.length || 0,
            performance: {
                totalMs: totalDuration,
                step1_todayDataMs: step1Duration,
                step2_searchContextMs: step2Duration,
                step3_aiGenerationMs: step3Duration,
            },
        });

        // Extract predictions from prediction cards for tracking/validation
        try {
            await extractAndSavePredictions(userId, today, processedSections);
        } catch (predError) {
            logger.error("[PREDICTIONS] Failed to extract predictions", {
                structuredData: true,
                userId,
                error: String(predError),
            });
            // Don't throw - insight saved successfully
        }

        // ═══════════════════════════════════════════════════════════════
        // DELIVERY: First-time = immediate (all cards now); otherwise staggered (6/12/5/9 IST)
        // ═══════════════════════════════════════════════════════════════
        if (!skipNotification) {
            if (immediateDelivery) {
                try {
                    await sendAllCardNotifications(userId, today, processedSections, insightRef);
                    logger.info("[INSIGHT-SAVED] Insight saved, immediate delivery sent", {
                        structuredData: true,
                        userId,
                        date: today,
                        cardCount: processedSections.length,
                    });
                } catch (deliverError) {
                    logger.error("[INSIGHT-DELIVERY] Immediate delivery failed", {
                        structuredData: true,
                        userId,
                        error: String(deliverError),
                    });
                    // Don't throw - insight doc is saved, user can open app and see it
                }
            } else {
                try {
                    await enqueueDispatchTasks(userId, today, processedSections);
                    logger.info("[INSIGHT-SAVED] Insight saved, dispatch tasks enqueued", {
                        structuredData: true,
                        userId,
                        date: today,
                        cardCount: processedSections.length,
                        scheduledTimes: [...new Set(processedSections.map(s => s.scheduledFor))],
                    });
                } catch (dispatchError) {
                    logger.error("[DISPATCH-ENQUEUE] Failed to enqueue dispatch tasks", {
                        structuredData: true,
                        userId,
                        error: String(dispatchError),
                    });
                }
            }
        } else {
            logger.info("[INSIGHT-SAVED] Insight saved, delivery skipped (cooldown)", {
                structuredData: true,
                userId,
                date: today,
            });
        }

        return { ...insightData, date: today };
    } catch (error) {
        logger.error("❌ Failed to generate insight", {
            structuredData: true,
            userId,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
}

/**
 * Callable function to generate insight for current user
 */
export const generateInsightForCurrentUser = onCall({
    region: "asia-southeast2",
    secrets: [geminiApiKey, freeAstrologyApiKey],
    timeoutSeconds: 120,
    memory: "1GiB",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
    // AppCheck: DISABLED until Flutter client enables FirebaseAppCheck
    // TODO: Set to true after enabling AppCheck in lib/main.dart
    // enforceAppCheck: true,
}, async (request) => {
    const userId = requireAuth(request, "get daily astro insights");
    const forceRegenerate = request.data?.forceRegenerate === true;

    // Accept current location from client (for accurate today's Vedic date)
    const currentLatitude = request.data?.currentLatitude;
    const currentLongitude = request.data?.currentLongitude;
    const currentTimeZone = request.data?.currentTimeZone;
    const currentTimeZoneOffset = request.data?.currentTimeZoneOffset;

    logger.info("🔮 generateInsightForCurrentUser called", {
        structuredData: true,
        userId,
        forceRegenerate,
        hasCurrentLocation: !!(currentLatitude && currentLongitude),
    });

    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const astrologyData = userData?.astrologyData;
        if (!astrologyData) {
            logger.warn("generateInsightForCurrentUser: user has no astrologyData (complete setup first)", {
                structuredData: true,
                userId,
            });
            throw new HttpsError("failed-precondition", "Complete astrology setup first");
        }

        // RATE LIMIT CHECK: Prevent rapid successive calls from triggering notification spam
        // If force regenerate was called within the last 2 minutes, return existing insight
        if (forceRegenerate) {
            const today = DateTime.now().toFormat("yyyy-MM-dd");
            const existingInsight = await db
                .collection("users")
                .doc(userId)
                .collection("dailyInsights")
                .doc(today)
                .get();

            if (existingInsight.exists) {
                const data = existingInsight.data();
                const generatedAt = data?.generatedAt?.toDate?.() || data?.generatedAt;
                if (generatedAt) {
                    const generatedTime = new Date(generatedAt).getTime();
                    const now = Date.now();
                    const twoMinutes = 2 * 60 * 1000;

                    if (now - generatedTime < twoMinutes) {
                        logger.info("⏱️ Rate limited: returning existing insight (generated recently)", {
                            structuredData: true,
                            userId,
                            lastGeneratedMs: now - generatedTime,
                            cooldownMs: twoMinutes,
                        });
                        return {
                            success: true,
                            date: data.date || today,
                            theme: data.theme,
                            message: data.message,
                            sections: data.sections,
                            rateLimited: true,
                        };
                    }
                }
            }
        }

        // Merge current location into astrology data if provided
        const astroDataWithLocation = {
            ...astrologyData,
            userId,
            ...(currentLatitude != null && { currentLatitude }),
            ...(currentLongitude != null && { currentLongitude }),
            ...(currentTimeZone != null && { currentTimeZone }),
            ...(currentTimeZoneOffset != null && { currentTimeZoneOffset }),
        };

        // For force regenerate: generate new insight first, THEN overwrite (so old stays visible)
        const insightData = await generateInsightForUserForce(userId, astroDataWithLocation, forceRegenerate);

        logger.info("generateInsightForCurrentUser success", {
            structuredData: true,
            userId,
            date: insightData.date,
            alreadyExists: insightData.alreadyExists === true,
        });

        return {
            success: true,
            date: insightData.date,
            theme: insightData.theme,
            message: insightData.message,
            sections: insightData.sections,
        };
    } catch (error) {
        logger.error("generateInsightForCurrentUser failed", { userId, error: String(error) });
        throw new HttpsError("internal", error.message || "Failed to generate insight");
    }
});

/**
 * GENERATION: Runs ONCE daily at 5 AM IST
 * Enqueues insight generation tasks to Cloud Tasks queue for steady throughput.
 * Each task processes ONE user - this prevents quota spikes.
 * 
 * OLD: Promise.all with BATCH_SIZE=50 -> quota spikes, failures
 * NEW: Cloud Tasks with rate limiting -> smooth, reliable generation
 */
export const generateDailyAstroInsights = onSchedule({
    schedule: "0 5 * * *", // 5 AM IST - ONCE daily
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    memory: "512MiB", // Reduced - we're just enqueuing, not processing
    timeoutSeconds: 300,
    secrets: [], // No secrets needed for enqueuing
}, async (event) => {
    const today = DateTime.now().setZone("Asia/Kolkata").toFormat("yyyy-MM-dd");

    logger.info("🌅 Starting daily insights ENQUEUE (queue-based generation)", {
        structuredData: true,
        date: today,
    });

    try {
        const usersSnapshot = await db.collection("users")
            .where("astrologyData", "!=", null)
            .get();

        if (usersSnapshot.empty) {
            logger.info("No users with astrology data found");
            return { success: true, enqueued: 0 };
        }

        const users = usersSnapshot.docs.map((doc) => ({
            userId: doc.id,
            astrologyData: doc.data().astrologyData,
        }));

        logger.info(`Enqueuing ${users.length} insight generation tasks`, {
            structuredData: true,
            userCount: users.length,
            date: today,
        });

        // Initialize generation log for today
        await db.collection("insightGenerationLogs").doc(today).set({
            date: today,
            totalUsers: users.length,
            startedAt: new Date().toISOString(),
            status: "enqueuing",
        });

        // Get the task queue for the insight worker
        // Use location-specific format to specify asia-southeast2 region
        const functions = getFunctions();
        const queue = functions.taskQueue("locations/asia-southeast2/functions/processInsightTask");

        // Enqueue tasks for all users
        // Spread generation over 1 hour to avoid API rate limits and load spikes
        // Cloud Tasks handles rate limiting via the worker's rateLimits config
        let enqueued = 0;
        let enqueueFailed = 0;

        // Spread enqueue over 1 hour (3600 seconds) to distribute load
        const GENERATION_WINDOW_SECONDS = 3600; // 1 hour
        const totalUsers = users.length;

        for (let i = 0; i < users.length; i++) {
            const user = users[i];

            try {
                // Calculate delay: spread evenly over 1 hour
                // First user: 0 seconds, last user: ~3600 seconds
                const delaySeconds = Math.floor((i / totalUsers) * GENERATION_WINDOW_SECONDS);

                await queue.enqueue({
                    userId: user.userId,
                    astrologyData: user.astrologyData,
                    date: today,
                }, {
                    scheduleDelaySeconds: delaySeconds,
                });
                enqueued++;
            } catch (e) {
                enqueueFailed++;
                logger.warn("[ENQUEUE] Failed to enqueue task", {
                    structuredData: true,
                    userId: user.userId,
                    error: String(e),
                });
            }
        }

        // Update generation log
        await db.collection("insightGenerationLogs").doc(today).update({
            status: "enqueued",
            enqueuedAt: new Date().toISOString(),
            enqueuedCount: enqueued,
            enqueueFailedCount: enqueueFailed,
        });

        logger.info("✅ Daily insights enqueue completed", {
            structuredData: true,
            date: today,
            enqueued,
            enqueueFailed,
            total: users.length,
        });

        return { success: true, enqueued, enqueueFailed, total: users.length };
    } catch (error) {
        logger.error("Daily insights enqueue failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });

        // Update log with failure
        try {
            await db.collection("insightGenerationLogs").doc(today).update({
                status: "failed",
                error: String(error),
                failedAt: new Date().toISOString(),
            });
        } catch (e) {
            // Ignore logging errors
        }

        throw error;
    }
});

/**
 * DISPATCH WORKER: Sends a single card notification
 * Called by Cloud Tasks at scheduled time (6 AM, 12 PM, 5 PM, 9 PM IST)
 */
export const dispatchCardNotification = onTaskDispatched({
    retryConfig: {
        maxAttempts: 3,
        minBackoffSeconds: 30,
        maxBackoffSeconds: 300,
    },
    rateLimits: {
        maxConcurrentDispatches: 100,
        maxDispatchesPerSecond: 10,
    },
    region: "asia-southeast2",
    memory: "256MiB",
    timeoutSeconds: 30,
}, async (req) => {
    const { userId, date, cardIndex, cardType, title, content, scheduledFor } = req.data;

    if (!userId || !date || cardIndex === undefined) {
        logger.error("[DISPATCH-WORKER] Invalid task data", {
            structuredData: true,
            hasUserId: !!userId,
            hasDate: !!date,
            cardIndex,
        });
        return; // Don't retry invalid tasks
    }

    logger.info("[DISPATCH-WORKER] Dispatching card notification", {
        structuredData: true,
        userId,
        date,
        cardIndex,
        scheduledFor,
    });

    try {
        // Skip if already delivered (e.g. immediate delivery for first-time insight)
        const insightSnap = await db.collection("users").doc(userId).collection("dailyInsights").doc(date).get();
        if (insightSnap.exists) {
            const data = insightSnap.data();
            const cardNotifications = data?.cardNotifications || {};
            const cardState = cardNotifications[String(cardIndex)] || cardNotifications[cardIndex];
            if (cardState?.sent === true) {
                logger.info("[DISPATCH-WORKER] Card already sent, skipping", {
                    structuredData: true,
                    userId,
                    date,
                    cardIndex,
                });
                return;
            }
        }

        // Create notification document (triggers push notification via Firestore trigger)
        const notificationRef = db
            .collection("notifications")
            .doc(userId)
            .collection("notifications")
            .doc();

        await notificationRef.set({
            type: "dailyAstroInsight",
            cardType: "insight", // Unified type
            cardIndex: cardIndex || 0,
            totalCards: 4, // Standard 4 cards per day
            title: title || "",
            preview: stripMarkdown(content || "").substring(0, 150),
            insightId: date,
            date: date,
            timestamp: FieldValue.serverTimestamp(),
            read: false,
        });

        // Update insight document to mark card as sent
        try {
            const insightRef = db
                .collection("users")
                .doc(userId)
                .collection("dailyInsights")
                .doc(date);

            await insightRef.update({
                [`cardNotifications.${cardIndex}.sent`]: true,
                [`cardNotifications.${cardIndex}.sentAt`]: FieldValue.serverTimestamp(),
            });
        } catch (updateError) {
            // Don't fail if insight update fails - notification is already sent
            logger.warn("[DISPATCH-WORKER] Failed to update insight cardNotifications", {
                structuredData: true,
                userId,
                cardIndex,
                error: String(updateError),
            });
        }

        logger.info("[DISPATCH-WORKER] Card notification dispatched", {
            structuredData: true,
            userId,
            date,
            cardIndex,
        });
    } catch (error) {
        logger.error("[DISPATCH-WORKER] Failed to dispatch card notification", {
            structuredData: true,
            userId,
            date,
            cardIndex,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        // Re-throw to trigger Cloud Tasks retry
        throw error;
    }
});

/**
 * DISPATCH: Runs 4 times daily (6 AM, 12 PM, 5 PM, 9 PM IST)
 * DEPRECATED: Replaced by Cloud Tasks scheduling (dispatchCardNotification)
 * Kept for backward compatibility during migration
 * @deprecated Use Cloud Tasks scheduling instead
 */
export const dispatchScheduledInsights = onSchedule({
    schedule: "0 6,12,17,21 * * *", // 6 AM, 12 PM, 5 PM, 9 PM IST
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    memory: "512MiB",
    timeoutSeconds: 300,
}, async (event) => {
    const now = DateTime.now().setZone("Asia/Kolkata");
    const currentHour = now.hour;
    const today = now.toFormat("yyyy-MM-dd");

    // Determine which scheduledFor time we're dispatching
    let targetTime;
    if (currentHour >= 5 && currentHour < 11) targetTime = "06:00";
    else if (currentHour >= 11 && currentHour < 16) targetTime = "12:00";
    else if (currentHour >= 16 && currentHour < 20) targetTime = "17:00";
    else targetTime = "21:00";

    // Convert to collection name format (06:00 -> 0600)
    const timeSlot = targetTime.replace(":", "");

    logger.info("📬 Starting INDEX-DRIVEN insight dispatch", {
        structuredData: true,
        targetTime,
        timeSlot,
        currentHour,
        date: today,
    });

    try {
        // INDEX-DRIVEN: Query only the specific time slot subcollection
        // Path: insightDispatch/{date}/{timeSlot}/*
        const dispatchSnapshot = await db
            .collection("insightDispatch")
            .doc(today)
            .collection(timeSlot)
            .where("dispatched", "==", false)
            .get();

        if (dispatchSnapshot.empty) {
            logger.info("No cards to dispatch for this time slot", {
                structuredData: true,
                date: today,
                timeSlot,
            });
            return { success: true, dispatched: 0, errors: 0 };
        }

        logger.info(`Found ${dispatchSnapshot.size} cards to dispatch`, {
            structuredData: true,
            date: today,
            timeSlot,
            cardCount: dispatchSnapshot.size,
        });

        let dispatched = 0;
        let errors = 0;

        for (const dispatchDoc of dispatchSnapshot.docs) {
            const dispatchData = dispatchDoc.data();
            const { userId, cardIndex, cardType, title, content } = dispatchData;

            if (!userId) {
                errors++;
                continue;
            }

            try {
                // Send notification for this card
                const notificationRef = db
                    .collection("notifications")
                    .doc(userId)
                    .collection("notifications")
                    .doc();

                await notificationRef.set({
                    type: "dailyAstroInsight",
                    cardType: cardType || "insight",
                    cardIndex: cardIndex || 0,
                    totalCards: 4, // Standard 4 cards per day
                    title: title || "",
                    preview: stripMarkdown(content || "").substring(0, 150),
                    insightId: today,
                    date: today,
                    timestamp: FieldValue.serverTimestamp(),
                    read: false,
                });

                // Mark dispatch entry as dispatched (instead of deleting, for audit trail)
                await dispatchDoc.ref.update({
                    dispatched: true,
                    dispatchedAt: new Date().toISOString(),
                });

                // Also update the insight document's cardNotifications
                try {
                    const insightRef = db
                        .collection("users")
                        .doc(userId)
                        .collection("dailyInsights")
                        .doc(today);

                    await insightRef.update({
                        [`cardNotifications.${cardIndex}.sent`]: true,
                        [`cardNotifications.${cardIndex}.sentAt`]: FieldValue.serverTimestamp(),
                    });
                } catch (updateError) {
                    // Don't fail dispatch if insight update fails
                    logger.warn("Failed to update insight cardNotifications", {
                        structuredData: true,
                        userId,
                        cardIndex,
                        error: String(updateError),
                    });
                }

                dispatched++;
                logger.info("Dispatched card", {
                    structuredData: true,
                    userId,
                    cardIndex,
                    timeSlot,
                });
            } catch (e) {
                errors++;
                logger.error("Failed to dispatch card", {
                    structuredData: true,
                    userId,
                    cardIndex,
                    error: String(e),
                });
            }
        }

        logger.info("📬 INDEX-DRIVEN dispatch completed", {
            structuredData: true,
            targetTime,
            timeSlot,
            date: today,
            dispatched,
            errors,
            totalCards: dispatchSnapshot.size,
        });

        return { success: true, dispatched, errors };
    } catch (error) {
        logger.error("Dispatch failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

/**
 * Monitoring endpoint - check system health, cache stats, and debug info
 */
export const getAstroInsightSystemHealth = onCall({
    region: "asia-southeast2",
    timeoutSeconds: 30,
    memory: "256MiB",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    const userId = requireAuth(request, "get astro insight system health");

    try {
        const health = {
            timestamp: new Date().toISOString(),
            status: "healthy",
            checks: {},
        };

        // 1. Check cache stats
        try {
            const cacheStats = await getCacheStats();
            health.checks.cache = {
                status: "ok",
                ...cacheStats,
            };
        } catch (e) {
            health.checks.cache = { status: "error", error: String(e) };
        }

        // 2. Check if Gemini is configured (used for Google Search grounding)
        const apiKey = geminiApiKey.value();
        health.checks.gemini = {
            status: apiKey ? "configured" : "not_configured",
            hasApiKey: !!apiKey,
        };

        // 3. Check today's global cache
        const today = DateTime.now().toFormat("yyyy-MM-dd");
        const cachedContext = await getCachedSearchContext(today);
        health.checks.todayCache = {
            status: cachedContext ? "cached" : "not_cached",
            date: today,
            hasGlobal: !!cachedContext?.global,
            hasRetrogrades: cachedContext?.global?.events?.retrogrades?.length || 0,
            hasTodayNews: !!cachedContext?.global?.todayNews,
            hasWeekly: !!cachedContext?.global?.weekly,
        };

        // 4. Check user's astrology data availability
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        const astroData = userData?.astrologyData;

        health.checks.userData = {
            status: astroData ? "available" : "not_setup",
            hasLagna: !!(astroData?.ascendant || astroData?.lagna),
            hasMoonSign: !!astroData?.moonSign,
            hasSunSign: !!astroData?.sunSign,
            hasNakshatra: !!(astroData?.nakshatra || astroData?.moonNakshatra),
            hasDasha: !!astroData?.currentDasha,
            hasRajYogas: (astroData?.rajYogas?.length || 0) > 0,
            hasDoshas: !!astroData?.doshas,
            hasLocation: !!(astroData?.birthLatitude && astroData?.birthLongitude),
        };

        // 5. Check today's insight for user
        const insightDoc = await db.collection("users").doc(userId).collection("dailyInsights").doc(today).get();
        health.checks.todayInsight = {
            status: insightDoc.exists ? "generated" : "not_generated",
            date: today,
            theme: insightDoc.data()?.theme || null,
            sectionCount: insightDoc.data()?.sections?.length || 0,
            version: insightDoc.data()?.version || null,
        };

        // Set overall status
        if (!astroData) {
            health.status = "needs_setup";
        } else if (!apiKey) {
            health.status = "limited"; // Works but no Gemini/search
        }

        logger.info("🏥 Health check completed", {
            structuredData: true,
            userId,
            status: health.status,
            cacheEntries: health.checks.cache?.cacheEntries || 0,
            todayCached: health.checks.todayCache?.status,
        });

        return health;
    } catch (error) {
        logger.error("Health check failed", { error: String(error) });
        return {
            timestamp: new Date().toISOString(),
            status: "error",
            error: String(error),
        };
    }
});

// ═══════════════════════════════════════════════════════════════
// PREDICTION VALIDATION
// Checks for predictions due today and sends validation notifications
// ═══════════════════════════════════════════════════════════════

/**
 * Check for predictions due today and send validation notifications
 * Runs at 9 AM IST daily
 */
export const checkPendingPredictions = onSchedule({
    schedule: "0 9 * * *",
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    memory: "256MiB",
    timeoutSeconds: 300,
}, async (event) => {
    const today = DateTime.now().setZone("Asia/Kolkata").toFormat("yyyy-MM-dd");

    logger.info("[PREDICTIONS-CHECK] Starting prediction validation check", {
        structuredData: true,
        targetDate: today,
    });

    try {
        // Query all users
        const usersSnapshot = await db.collection("users").get();
        let validationsSent = 0;
        let errorsCount = 0;

        for (const userDoc of usersSnapshot.docs) {
            const userId = userDoc.id;

            try {
                // Find predictions due today that are still pending
                const predictionsSnapshot = await db
                    .collection("users")
                    .doc(userId)
                    .collection("predictions")
                    .where("targetDate", "==", today)
                    .where("status", "==", "pending")
                    .get();

                if (predictionsSnapshot.empty) {
                    continue;
                }

                for (const predDoc of predictionsSnapshot.docs) {
                    const prediction = predDoc.data();

                    // Create validation notification
                    const notificationRef = db
                        .collection("notifications")
                        .doc(userId)
                        .collection("notifications")
                        .doc();

                    const planetText = prediction.planet ? `${prediction.planet} ` : "";
                    const eventText = prediction.event || "prediction";

                    await notificationRef.set({
                        type: "predictionValidation",
                        predictionId: predDoc.id,
                        title: `${planetText}${eventText} - Did it happen?`,
                        preview: stripMarkdown(prediction.prediction || "").substring(0, 100) || "Check if this prediction came true",
                        planet: prediction.planet,
                        event: prediction.event,
                        insightDate: prediction.insightDate,
                        timestamp: FieldValue.serverTimestamp(),
                        read: false,
                    });

                    validationsSent++;

                    logger.info("[PREDICTIONS-CHECK] Sent validation notification", {
                        structuredData: true,
                        userId,
                        predictionId: predDoc.id,
                        planet: prediction.planet,
                    });
                }
            } catch (userError) {
                logger.error(`[PREDICTIONS-CHECK] Failed for user ${userId}`, {
                    structuredData: true,
                    error: String(userError),
                });
                errorsCount++;
            }
        }

        logger.info("[PREDICTIONS-CHECK] Completed", {
            structuredData: true,
            targetDate: today,
            validationsSent,
            errorsCount,
            totalUsers: usersSnapshot.size,
        });
    } catch (error) {
        logger.error("[PREDICTIONS-CHECK] Failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

/**
 * Admin function to clear caches
 * Call with: { mode: "all" | "ai" | "old" }
 * - all: Clear ALL caches (nuclear option)
 * - ai: Clear only AI insight caches
 * - old: Clear only old versioned caches (keeps current version)
 */
export const clearAstroCaches = onCall({
    region: "asia-southeast2",
    memory: "256MiB",
    timeoutSeconds: 60,
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new HttpsError("unauthenticated", "Must be logged in");
    }

    // Optional: Add admin check here if you want to restrict this
    const mode = request.data?.mode || "old";

    logger.info("🗑️ Cache clear requested", {
        structuredData: true,
        userId,
        mode,
        cacheVersion: getCacheVersion(),
    });

    let result;
    switch (mode) {
        case "all":
            result = await clearAllCaches();
            break;
        case "ai":
            result = await clearAIInsightCaches();
            break;
        case "old":
        default:
            result = await clearOldVersionedCaches();
            break;
    }

    // Also get current cache stats
    const stats = await getCacheStats();

    return {
        ...result,
        cacheVersion: getCacheVersion(),
        stats,
    };
});

/**
 * CLEANUP: Remove old insightDispatch entries
 * Runs daily to prevent document accumulation
 * Keeps last 7 days of dispatch data for debugging
 */
export const cleanupOldDispatchEntries = onSchedule({
    schedule: "0 4 * * *", // Daily at 4 AM IST
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 300,
    memory: "256MiB",
}, async (event) => {
    const now = DateTime.now().setZone("Asia/Kolkata");
    const cutoffDate = now.minus({ days: 7 }).toFormat("yyyy-MM-dd");

    logger.info("🗑️ Starting insightDispatch cleanup", {
        structuredData: true,
        cutoffDate,
        currentDate: now.toFormat("yyyy-MM-dd"),
    });

    try {
        // Get all date documents older than cutoff
        const dispatchDocs = await db.collection("insightDispatch").get();

        let deletedDates = 0;
        let deletedEntries = 0;

        for (const dateDoc of dispatchDocs.docs) {
            const dateKey = dateDoc.id;

            // Skip dates newer than cutoff
            if (dateKey >= cutoffDate) {
                continue;
            }

            // Delete all time slot subcollections for this date
            const timeSlots = ["0600", "1200", "1700", "2100"];
            for (const slot of timeSlots) {
                const entriesSnapshot = await db
                    .collection("insightDispatch")
                    .doc(dateKey)
                    .collection(slot)
                    .get();

                if (!entriesSnapshot.empty) {
                    const batch = db.batch();
                    entriesSnapshot.docs.forEach((doc) => {
                        batch.delete(doc.ref);
                        deletedEntries++;
                    });
                    await batch.commit();
                }
            }

            // Delete the date document itself
            await dateDoc.ref.delete();
            deletedDates++;
        }

        logger.info("✅ insightDispatch cleanup completed", {
            structuredData: true,
            deletedDates,
            deletedEntries,
            cutoffDate,
        });

        return { success: true, deletedDates, deletedEntries };
    } catch (error) {
        logger.error("❌ insightDispatch cleanup failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

/**
 * CLEANUP: Remove expired cache entries from astroCache and astroCurrent collections
 * Runs daily to prevent stale data accumulation
 */
export const cleanupExpiredCacheEntries = onSchedule({
    schedule: "0 5 * * *", // Daily at 5 AM IST (after dispatch cleanup)
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 300,
    memory: "256MiB",
}, async (event) => {
    logger.info("🗑️ Starting expired cache cleanup", {
        structuredData: true,
        timestamp: DateTime.now().setZone("Asia/Kolkata").toISO(),
    });

    try {
        const result = await cleanupExpiredCache();

        logger.info("✅ Cache cleanup completed", {
            structuredData: true,
            deletedCount: result.deletedCount,
        });

        return result;
    } catch (error) {
        logger.error("❌ Cache cleanup failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

