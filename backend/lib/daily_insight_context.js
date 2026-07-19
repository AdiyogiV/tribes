/**
 * Forecast context — reusable Vedic context builders for narrated readings.
 *
 * The unified forecast currently consumes the dasha builder. Other exports are
 * retained for longer-form reading surfaces that need current transit context.
 *
 * Three main functions:
 *   buildDashaContext()   — dasha phase + recent themes for narrative continuity
 *   getTodayAstroData()   — today's panchang, transits, shadBala, muhurat from API
 *   getSearchContext()     — Google Search grounding context for AI enrichment
 */

import { logger } from "./firebase.js";
// Vertex AI — no API key needed (uses ADC)
import { DateTime } from "luxon";
import { runEphemerisFlow } from "../functions/ephemeris.js";
import { buildAstroSearchContext } from "./search.js";
import { calculateWholeSignHouse } from "./vedic_analysis.js";
import { extractAscendantDegree, normalizeDasha } from "./astro_helpers.js";

// ── Dasha context ───────────────────────────────────────────────────

/**
 * Build Dasha context for narrative continuity.
 * Calculates phase in current period and fetches recent themes.
 * @param {string} userId - User ID
 * @param {Object} currentDasha - Current dasha data from user profile
 * @returns {Object} Dasha context for AI prompt
 */
export async function buildDashaContext(userId, currentDasha) {
    const { mahaDasha, antarDasha, levels } = normalizeDasha(currentDasha);

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

    return {
        period: mahaDasha && antarDasha ? `${mahaDasha}-${antarDasha}` : mahaDasha || "Unknown",
        mahaDasha,
        antarDasha,
        pratyantarDasha: levels.pratyantar?.lord || null,
        phase,
        percentComplete,
        daysRemaining,
        recentThemes: [],
        // Phase-specific guidance for AI
        phaseGuidance: phase === "BEGINNING" ?
            "New energies are emerging. Focus on initiating and setting intentions." :
            phase === "CLOSING" ?
                "This period is completing. Focus on integration and preparation for transition." :
                "Period is in full effect. Work actively with these energies.",
    };
}

// ── Today's astronomical data ───────────────────────────────────────

/**
 * Get today's astrological data for a user's location.
 * Fetches panchang, transits, and samvat from the astro API.
 * Calculates transit houses relative to user's natal Lagna (Whole Sign).
 * Note: shadbala is natal (read from the user profile), not fetched here.
 * @param {Object} userAstroData - User's astrology profile from Firestore
 * @returns {{ panchang, transits, muhurat, todaySamvat }}
 */
export async function getTodayAstroData(userAstroData) {
    const { birthLatitude, birthLongitude, timeZone, timeZoneOffset } = userAstroData;

    // Prefer current location over birth location
    const latitude = userAstroData.currentLatitude ?? birthLatitude;
    const longitude = userAstroData.currentLongitude ?? birthLongitude;

    // Use current timezone if provided, otherwise use birth timezone
    const currentTimeZone = userAstroData.currentTimeZone ?? timeZone;
    const currentTimeZoneOffset = typeof userAstroData.currentTimeZoneOffset === "number" ?
        userAstroData.currentTimeZoneOffset :
        (typeof timeZoneOffset === "number" ? timeZoneOffset : 0);

    if (latitude == null || longitude == null) {
        logger.warn("Missing location data for user");
        return { panchang: {}, transits: {}, shadBala: {}, todaySamvat: null };
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
            usingCurrentLocation:
                userAstroData.currentLatitude != null && userAstroData.currentLongitude != null,
        });

        const result = await runEphemerisFlow({
            mode: "standard", // planets + panchang + samvat. No natal-only extras
            payload: todayPayload,
            timeZoneId: currentTimeZone || "UTC",
            timeZoneOffset: currentTimeZoneOffset,
        });

        // Extract panchang
        const panchang = result.panchang || {};

        logger.info("📊 Panchang data received", {
            structuredData: true,
            userId: userAstroData.userId || "unknown",
            tithi: panchang.tithi || "missing",
            nakshatra: panchang.nakshatra || "missing",
            yoga: panchang.yoga || "missing",
            karana: panchang.karana || "missing",
        });

        // Extract planetary positions — transit houses relative to USER'S natal Lagna
        const planets = result.birthChartData?.output || result.birthChartData?.planets || {};
        const transits = {};

        const userAscendantDegree = extractAscendantDegree(userAstroData);

        if (userAscendantDegree == null) {
            logger.warn("⚠️ Could not extract user's natal ascendant degree", {
                structuredData: true,
                userId: userAstroData.userId || "unknown",
            });
        }

        if (planets && typeof planets === "object") {
            Object.entries(planets).forEach(([key, data]) => {
                if (data && typeof data === "object") {
                    const name = data.name || key;
                    const transitDegree = data.fullDegree || data.full_degree;

                    // Whole Sign houses: planet in same sign as Lagna = 1st house
                    let transitHouse = null;
                    if (transitDegree != null && userAscendantDegree != null) {
                        transitHouse = calculateWholeSignHouse(transitDegree, userAscendantDegree);
                    } else {
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

        // Muhurat and Samvat (shadbala is natal, read from the user profile instead)
        const muhurat = {};
        const muhuratSource = result.muhurat?.days?.[now.toFormat("yyyy-MM-dd")] || {};
        if (muhuratSource.rahuKala) muhurat.rahuKaal = muhuratSource.rahuKala;
        if (muhuratSource.yamaganda) muhurat.yamaganda = muhuratSource.yamaganda;
        if (muhuratSource.gulikaKala) muhurat.gulikaKala = muhuratSource.gulikaKala;
        if (muhuratSource.abhijit) muhurat.abhijit = muhuratSource.abhijit;
        if (muhuratSource.amrit) muhurat.amritKaal = muhuratSource.amrit;
        if (muhuratSource.brahmaMuhurat) muhurat.brahmaMuhurat = muhuratSource.brahmaMuhurat;
        if (muhuratSource.durMuhurat) muhurat.durMuhurat = muhuratSource.durMuhurat;
        if (muhuratSource.varjyam) muhurat.varjyam = muhuratSource.varjyam;

        const todaySamvat = result.samvatInfo || null;

        logger.info(" Today's data fetched", {
            structuredData: true,
            panchangKeys: Object.keys(panchang).filter((k) => panchang[k]).length,
            transitCount: Object.keys(transits).length,
            hasMuhurat: Object.keys(muhurat).length > 0,
            hasTodaySamvat: !!todaySamvat,
        });

        return { panchang, transits, muhurat, todaySamvat };
    } catch (error) {
        logger.error("Failed to get today's astro data", { error: String(error) });
        return { panchang: {}, transits: {}, todaySamvat: null };
    }
}

// ── Google Search context ───────────────────────────────────────────

/**
 * Build Google Search context for enriching AI insights.
 * Uses tiered caching: global data cached for all users,
 * user-specific data cached per user combination.
 * @param {Object} userAstroData - User's astrology profile
 * @param {Object} todayAstroData - Today's astronomical data
 * @returns {Object|null} Search context or null if unavailable
 */
export async function getSearchContext(userAstroData, todayAstroData) {
    try {
        const today = DateTime.now().toFormat("yyyy-MM-dd");
        const startTime = Date.now();

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
        const dataPoints = [
            context?.global?.events?.retrogrades?.length > 0,
            !!context?.global?.events?.moonPhase,
            !!context?.global?.todayNews?.summary,
            !!context?.global?.weekly?.overview,
            !!context?.panchang?.tithi?.meaning,
            !!context?.userProfile?.lagna?.characteristics,
            !!context?.dasha?.general?.interpretation,
            !!context?.userSpecific?.lagnaForecast,
            !!context?.userSpecific?.moonSignForecast,
            !!context?.remedies?.advice,
        ].filter(Boolean).length;

        logger.info("✅ Search context built", {
            structuredData: true,
            durationMs: duration,
            totalDataPoints: dataPoints,
        });

        return context;
    } catch (error) {
        logger.error("❌ Search context build failed (continuing without search)", {
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        return null;
    }
}
