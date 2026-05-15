import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { DateTime } from "luxon";
import { db, FieldValue } from "../lib/firebase.js";
import {
    calculateRajYogas,
    checkCombustion,
    calculatePlanetDignity,
    checkKemadrumaYoga,
    calculateHouseFromDegree,
} from "../lib/vedic_analysis.js";
import { freeAstrologyApiKey } from "../lib/secrets.js";
import { requireAuth } from "../lib/auth_utils.js";
import { GANDMOOL_NAKSHATRAS, FREE_ASTROLOGY_API, ZODIAC_SIGNS, NAKSHATRAS } from "../lib/constants.js";
import {
    calculateCosmicMatch,
    calculateLifePhaseSync,
    normalizeNakshatra,
    normalizeSign,
} from "../lib/vedic_compatibility.js";
import { safeParseJson, checkBlockedDetailed } from "../lib/utils.js";
import { extractApiOutput, parseApiTimeString } from "../lib/astro_helpers.js";
import { parseMuhuratDay as _parseMuhuratDay, processUnifiedTimeline as _processUnifiedTimeline } from "../lib/muhurat_helpers.js";

// ============================================================================
// FreeAstrologyAPI Configuration
// Using centralized constants from lib/constants.js
// ============================================================================
const API_BASE = FREE_ASTROLOGY_API.BASE_URL;

// Destructure endpoints for cleaner usage throughout the file
const {
    PLANETS_EXTENDED: PLANETS_ENDPOINT,
    PLANETS: PLANETS_ENDPOINT_FALLBACK,
    DASHA: DASHA_ENDPOINT,
    DASHA_ALT1: DASHA_ENDPOINT_ALT1,
    DASHA_ALT2: DASHA_ENDPOINT_ALT2,
    DASHA_ALT3: DASHA_ENDPOINT_ALT3,
    DASA_INFO: DASA_INFORMATION_ENDPOINT,
    SAMVAT: SAMVAT_ENDPOINT,
    LUNAR_MONTH: LUNAR_MONTH_ENDPOINT,
    TITHI: TITHI_ENDPOINT,
    NAKSHATRA_DURATIONS: NAKSHATRA_DURATIONS_ENDPOINT,
    YOGA_DURATIONS: YOGA_DURATIONS_ENDPOINT,
    VEDIC_WEEKDAY: VEDIC_WEEKDAY_ENDPOINT,
    HORA_TIMINGS: HORA_TIMINGS_ENDPOINT,
    CHOGHADIYA: CHOGHADIYA_TIMINGS_ENDPOINT,
    GOOD_BAD_TIMES: GOOD_BAD_TIMES_ENDPOINT,
    NAVAMSA: NAVAMSA_INFO_ENDPOINT,
    D10_CHART: D10_CHART_ENDPOINT,
    SHADBALA: SHADBALA_SUMMARY_ENDPOINT,
    ASHTAKOOT: ASHTAKOOT_SCORE_ENDPOINT,
} = FREE_ASTROLOGY_API.ENDPOINTS;

// Note: Keep-alive agent removed - modern fetch() handles connection pooling internally

const getApiKey = () => {
    // Try Firebase v2 secret first
    try {
        const secretValue = freeAstrologyApiKey.value();
        if (secretValue) return secretValue;
    } catch (e) {
        // Secret not available in this context, try env
    }
    // Fallback to environment variable
    return process.env.FREE_ASTROLOGY_API_KEY || "";
};

const callFreeAstro = async (endpoint, payload) => {
    const apiKey = getApiKey();
    if (!apiKey) {
        throw new HttpsError(
            "failed-precondition",
            "FreeAstrologyAPI key is not configured",
        );
    }

    const response = await fetch(`${API_BASE}${endpoint}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
        },
        body: JSON.stringify(payload),
    });

    if (!response.ok) {
        const errorBody = await response.text();
        // Detailed error logging for debugging
        logger.error(`API Error ${endpoint}`, {
            structuredData: true,
            endpoint,
            status: response.status,
            errorBody: errorBody.substring(0, 500),
            payloadKeys: Object.keys(payload || {}),
        });
        const error = new HttpsError(
            "internal",
            `FreeAstrologyAPI error (${response.status}): ${errorBody}`,
        );
        error.statusCode = response.status;
        throw error;
    }

    return await response.json();
};

// Helper to call API safely, returning null instead of throwing
// Note: Errors are already logged in detail by callFreeAstro
const callFreeAstroSafe = async (endpoint, payload) => {
    try {
        return await callFreeAstro(endpoint, payload);
    } catch (error) {
        return null;
    }
};

const parseTimeString = parseApiTimeString;

/**
 * Parse a dasha date string to a JavaScript Date object.
 * 
 * The FreeAstrologyAPI returns dates in LOCAL time (user's birth timezone) 
 * without a timezone indicator. We need to convert these to UTC for storage
 * and comparison.
 * 
 * IMPORTANT: Only apply the offset to dates WITHOUT a timezone indicator.
 * If the date already has 'Z' or a timezone offset (like stored ISO strings),
 * it's already in UTC and should NOT have the offset applied again.
 * 
 * @param {string} value - Date string from API (e.g., "2024-01-15 10:30:00") or stored ISO
 * @param {number} offsetHours - Birth location timezone offset from UTC (e.g., 5.5 for IST)
 * @returns {Date|null} - JavaScript Date object in UTC, or null if parsing fails
 */
const parseDashaDate = (value, offsetHours = 0) => {
    if (!value || typeof value !== "string") return null;
    const normalized = value.replace(" ", "T");

    // Check if the date already has a timezone indicator (Z, +HH:MM, -HH:MM)
    // This indicates the date is already in UTC or has a proper timezone
    const hasTimezone = /[zZ]$/.test(normalized) || /[+-]\d{2}:?\d{2}$/.test(normalized);

    const withZone = hasTimezone ? normalized : `${normalized}Z`;
    const parsed = new Date(withZone);
    if (Number.isNaN(parsed.getTime())) return null;

    // CRITICAL: Only apply offset to dates WITHOUT a timezone indicator
    // These are dates from the API in local time that need conversion to UTC
    // Dates that already have 'Z' (like stored ISO strings) are already in UTC
    if (!hasTimezone && typeof offsetHours === "number" && offsetHours !== 0) {
        return new Date(parsed.getTime() - (offsetHours * 60 * 60 * 1000));
    }
    return parsed;
};

const formatDashaDateForStorage = (value, offsetHours = 0) => {
    const parsed = parseDashaDate(value, offsetHours);
    return parsed ? parsed.toISOString() : (value || null);
};

const buildAntarDashas = (source, { fallbackToKey = false, offsetHours = 0 } = {}) => {
    if (!source || typeof source !== "object") return [];

    const entries = Object.entries(source)
        .map(([key, value]) => {
            if (!value || typeof value !== "object") return null;
            const start = value.start_time || value.startTime;
            const end = value.end_time || value.endTime;
            if (!start || !end) return null;
            return {
                lord: value.Lord || value.lord || (fallbackToKey ? key : null),
                startDate: formatDashaDateForStorage(start, offsetHours),
                endDate: formatDashaDateForStorage(end, offsetHours),
            };
        })
        .filter(Boolean)
        .sort((a, b) => {
            const left = parseDashaDate(a.startDate, offsetHours);
            const right = parseDashaDate(b.startDate, offsetHours);
            if (!left || !right) return 0;
            return left - right;
        });

    return entries;
};

// Reuse the house calculation from vedic_analysis.js (has defensive bounds checking)
const getHouseFromDegrees = calculateHouseFromDegree;

// Helper to check if a planet is between Rahu and Ketu (going clockwise from Rahu to Ketu)
const isPlanetBetweenRahuKetu = (planetDegree, rahuDegree, ketuDegree) => {
    // Normalize degrees to 0-360
    const normPlanet = ((planetDegree % 360) + 360) % 360;
    const normRahu = ((rahuDegree % 360) + 360) % 360;
    const normKetu = ((ketuDegree % 360) + 360) % 360;

    // Rahu and Ketu are always 180° apart, but we check both arcs
    // The arc from Rahu going forward (clockwise in the zodiac) to Ketu
    if (normRahu < normKetu) {
        // Rahu to Ketu spans forward without crossing 360°
        return normPlanet > normRahu && normPlanet < normKetu;
    } else {
        // Rahu to Ketu crosses 360° (e.g., Rahu at 350°, Ketu at 170°)
        return normPlanet > normRahu || normPlanet < normKetu;
    }
};

// Calculate doshas from planetary positions
const calculateDoshasFromPlanets = (planets, ascendant = null) => {
    if (!planets || typeof planets !== "object") return null;

    const doshas = {};

    // Get ascendant degree for house calculations
    const ascDegree = ascendant?.fullDegree || ascendant?.full_degree ||
        ascendant?.longitude || null;

    // Numeric key mapping for FreeAstrologyAPI
    const numericKeyMap = {
        "Ascendant": "0", "Sun": "1", "Moon": "2", "Venus": "3",
        "Mars": "4", "Mercury": "5", "Jupiter": "6", "Saturn": "7",
        "Rahu": "8", "Ketu": "9",
    };

    // Helper to get planet by various name formats
    const getPlanetByName = (name) => {
        // Try direct key matches
        let planet = planets[name] || planets[name.toLowerCase()] ||
            planets[name.charAt(0).toUpperCase() + name.slice(1).toLowerCase()];

        if (planet) return planet;

        // Try numeric key
        const numericKey = numericKeyMap[name];
        if (numericKey && planets[numericKey]) {
            return planets[numericKey];
        }

        // Search by internal name property
        for (const [key, value] of Object.entries(planets)) {
            if (value && typeof value === "object") {
                const planetName = (value.name || "").toString().toLowerCase();
                if (planetName === name.toLowerCase()) {
                    return value;
                }
            }
        }

        return null;
    };

    // Mangal Dosha (Mars in 1st, 2nd, 4th, 7th, 8th, or 12th house FROM ASCENDANT)
    // Severity varies by house placement per traditional Vedic texts (BPHS, Phaladeepika)
    const mars = getPlanetByName("Mars");
    if (mars && ascDegree != null) {
        const marsDegree = mars.fullDegree || mars.full_degree || mars.longitude;
        const marsSign = mars.zodiac_sign_name || mars.sign;
        const marsHouse = getHouseFromDegrees(marsDegree, ascDegree);
        const mangalDoshaHouses = [1, 2, 4, 7, 8, 12];
        if (marsHouse && mangalDoshaHouses.includes(marsHouse)) {
            doshas.mangal_dosha = true;
            doshas.mangal_dosha_house = marsHouse;

            // Determine severity based on house (traditional interpretation)
            // 7th & 8th houses: Strong (directly impacts marriage/longevity)
            // 1st & 4th houses: Moderate (affects self/emotions)
            // 2nd & 12th houses: Mild (considered less problematic)
            let severity = "Moderate";
            if (marsHouse === 7 || marsHouse === 8) {
                severity = "Strong";
            } else if (marsHouse === 2 || marsHouse === 12) {
                severity = "Mild";
            }

            // Cancellation/reduction factors per BPHS:
            // 1. Mars in own sign (Aries, Scorpio) or exalted (Capricorn)
            // 2. Mars aspected by Jupiter (benefic aspect)
            // 3. Both partners have Mangal Dosha (cancels out)
            const marsInOwnSign = marsSign &&
                (marsSign.toLowerCase() === "aries" ||
                    marsSign.toLowerCase() === "scorpio");
            const marsExalted = marsSign && marsSign.toLowerCase() === "capricorn";

            if (marsInOwnSign || marsExalted) {
                // Reduce severity when Mars is dignified
                if (severity === "Strong") severity = "Moderate";
                else if (severity === "Moderate") severity = "Mild";
                doshas.mangal_dosha_mitigated = true;
                doshas.mangal_dosha_mitigation = marsExalted ?
                    "Mars exalted in Capricorn" :
                    `Mars in own sign ${marsSign}`;
            }

            doshas.mangal_dosha_severity = severity;
        }
    }

    // Kaal Sarp Dosha - ALL 7 planets must be hemmed between Rahu and Ketu
    // The 7 planets are: Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn
    const rahu = getPlanetByName("Rahu");
    const ketu = getPlanetByName("Ketu");
    if (rahu && ketu) {
        const rahuDegree = rahu.fullDegree || rahu.full_degree || rahu.longitude || 0;
        const ketuDegree = ketu.fullDegree || ketu.full_degree || ketu.longitude || 0;

        // Check only the 7 classical planets (excluding Rahu, Ketu)
        const sevenPlanets = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
        let planetsChecked = 0;
        let inArc1 = 0; // Rahu→Ketu arc
        let inArc2 = 0; // Ketu→Rahu arc

        for (const planetName of sevenPlanets) {
            const planet = getPlanetByName(planetName);
            if (!planet) continue;

            const planetDegree = planet.fullDegree || planet.full_degree || planet.longitude;
            if (planetDegree == null) continue;

            planetsChecked++;

            // Check which arc the planet is in
            const normPlanet = ((planetDegree % 360) + 360) % 360;
            const normRahu = ((rahuDegree % 360) + 360) % 360;
            const normKetu = ((ketuDegree % 360) + 360) % 360;

            let isInArc1;
            if (normRahu < normKetu) {
                isInArc1 = normPlanet > normRahu && normPlanet < normKetu;
            } else {
                isInArc1 = normPlanet > normRahu || normPlanet < normKetu;
            }

            if (isInArc1) inArc1++;
            else inArc2++;
        }

        // Kaal Sarp requires ALL 7 planets on one side of the Rahu-Ketu axis
        const isKaalSarp = planetsChecked >= 7 && (inArc1 === 7 || inArc2 === 7);

        if (isKaalSarp) {
            doshas.kaal_sarp_dosha = true;
            doshas.kaal_sarp_severity = "Present";
        }
    }

    // Shani Dosha (Saturn in challenging houses from Ascendant or Moon)
    const saturn = getPlanetByName("Saturn");
    const moon = getPlanetByName("Moon");
    if (saturn && ascDegree != null) {
        const saturnDegree = saturn.fullDegree || saturn.full_degree || saturn.longitude;
        const saturnHouse = getHouseFromDegrees(saturnDegree, ascDegree);
        const shaniDoshaHouses = [1, 4, 7, 8, 10];

        if (saturnHouse && shaniDoshaHouses.includes(saturnHouse)) {
            doshas.shani_dosha = true;
            doshas.shani_dosha_severity = "Moderate";
            doshas.shani_dosha_house = saturnHouse;
        }

        // Also check Kantaka Shani (Saturn in Kendra from Moon)
        if (moon) {
            const moonDegree = moon.fullDegree || moon.full_degree || moon.longitude;
            if (moonDegree != null) {
                const saturnFromMoon = getHouseFromDegrees(saturnDegree, moonDegree);
                if (saturnFromMoon && [1, 4, 7, 10].includes(saturnFromMoon)) {
                    doshas.shani_dosha = true;
                    doshas.shani_dosha_severity = doshas.shani_dosha_severity === "Moderate" ? "Strong" : "Moderate";
                    doshas.shani_from_moon = saturnFromMoon;
                }
            }
        }
    }

    // Pitra Dosha (Ancestral karma) - Sun afflicted by Rahu/Ketu, or 9th house afflicted
    const sun = getPlanetByName("Sun");
    if (sun && rahu && ketu) {
        const sunDegree = sun.fullDegree || sun.full_degree || sun.longitude;
        const rahuDegree = rahu.fullDegree || rahu.full_degree || rahu.longitude;
        const ketuDegree = ketu.fullDegree || ketu.full_degree || ketu.longitude;

        if (sunDegree != null && rahuDegree != null && ketuDegree != null) {
            const sunRahuDiff = Math.abs(sunDegree - rahuDegree);
            const sunRahuAngle = Math.min(sunRahuDiff, 360 - sunRahuDiff);
            const sunKetuDiff = Math.abs(sunDegree - ketuDegree);
            const sunKetuAngle = Math.min(sunKetuDiff, 360 - sunKetuDiff);

            // Pitra Dosha if Sun conjunct Rahu or Ketu within 10°
            if (sunRahuAngle < 10 || sunKetuAngle < 10) {
                doshas.pitra_dosha = true;
                doshas.pitra_dosha_severity = sunRahuAngle < 5 || sunKetuAngle < 5 ? "Strong" : "Moderate";
                doshas.pitra_dosha_type = sunRahuAngle < 10 ? "Sun-Rahu conjunction" : "Sun-Ketu conjunction";
            }

            // Also check if Rahu/Ketu in 9th house
            if (ascDegree != null) {
                const rahuHouse = getHouseFromDegrees(rahuDegree, ascDegree);
                const ketuHouse = getHouseFromDegrees(ketuDegree, ascDegree);
                if (rahuHouse === 9 || ketuHouse === 9) {
                    doshas.pitra_dosha = true;
                    doshas.pitra_dosha_severity = doshas.pitra_dosha_severity || "Moderate";
                    doshas.pitra_dosha_9th_afflicted = true;
                }
            }
        }
    }

    // Grahan Dosha (Eclipse affliction) - Moon or Sun conjunct Rahu/Ketu
    if (moon && rahu && ketu) {
        const moonDegree = moon.fullDegree || moon.full_degree || moon.longitude;
        const rahuDegree = rahu.fullDegree || rahu.full_degree || rahu.longitude;
        const ketuDegree = ketu.fullDegree || ketu.full_degree || ketu.longitude;

        if (moonDegree != null && rahuDegree != null && ketuDegree != null) {
            const moonRahuDiff = Math.abs(moonDegree - rahuDegree);
            const moonRahuAngle = Math.min(moonRahuDiff, 360 - moonRahuDiff);
            const moonKetuDiff = Math.abs(moonDegree - ketuDegree);
            const moonKetuAngle = Math.min(moonKetuDiff, 360 - moonKetuDiff);

            // Grahan Dosha on Moon (Chandra Grahan)
            if (moonRahuAngle < 12 || moonKetuAngle < 12) {
                doshas.grahan_dosha = true;
                doshas.grahan_type = moonRahuAngle < 12 ? "Chandra-Rahu (Lunar)" : "Chandra-Ketu (Lunar)";
                doshas.grahan_severity = (moonRahuAngle < 5 || moonKetuAngle < 5) ? "Strong" : "Moderate";
            }

            // Grahan Dosha on Sun (Surya Grahan) - already covered in Pitra Dosha
            // but we note it separately if present
            if (sun) {
                const sunDegree = sun.fullDegree || sun.full_degree || sun.longitude;
                if (sunDegree != null) {
                    const sunRahuDiff = Math.abs(sunDegree - rahuDegree);
                    const sunRahuAngle = Math.min(sunRahuDiff, 360 - sunRahuDiff);

                    if (sunRahuAngle < 12 && !doshas.grahan_dosha) {
                        doshas.grahan_dosha = true;
                        doshas.grahan_type = "Surya-Rahu (Solar)";
                        doshas.grahan_severity = sunRahuAngle < 5 ? "Strong" : "Moderate";
                    }
                }
            }
        }
    }

    return Object.keys(doshas).length > 0 ? doshas : null;
};

// Calculate Gandmool Dosha from Moon nakshatra
const calculateGandmoolDosha = (moonNakshatra) => {
    if (!moonNakshatra) return null;

    const nakshatra = moonNakshatra.toString();
    const isGandmool = GANDMOOL_NAKSHATRAS.some(
        gn => nakshatra.toLowerCase().includes(gn.toLowerCase())
    );

    if (isGandmool) {
        return {
            gandmool_dosha: true,
            gandmool_nakshatra: moonNakshatra,
            gandmool_severity: "Present",
            gandmool_description: `Birth in ${moonNakshatra} nakshatra. Traditional Gandmool Shanti puja may be beneficial.`,
        };
    }

    return null;
};

// Calculate planet combustion states
const calculateCombustionStates = (planets) => {
    if (!planets) return null;

    const combustionData = {};
    const sun = planets.Sun || planets.sun || Object.values(planets).find(p =>
        p && (p.name?.toLowerCase() === "sun")
    );

    if (!sun) return null;

    const sunDegree = sun.fullDegree || sun.full_degree || sun.longitude;
    if (sunDegree == null) return null;

    const planetsToCheck = ["Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

    for (const planetName of planetsToCheck) {
        const planet = planets[planetName] || planets[planetName.toLowerCase()];
        if (!planet) continue;

        const planetDegree = planet.fullDegree || planet.full_degree || planet.longitude;
        if (planetDegree == null) continue;

        const isRetrograde = planet.isRetro === true || planet.retrograde === true;
        const combustion = checkCombustion(planetName, planetDegree, sunDegree, isRetrograde);

        if (combustion && combustion.isCombust) {
            combustionData[planetName] = {
                isCombust: true,
                orb: combustion.orb,
                severity: combustion.severity,
            };
        }
    }

    return Object.keys(combustionData).length > 0 ? combustionData : null;
};

/**
 * Tiered astrology data fetching for optimized performance
 * 
 * Modes:
 * - "basic"    (~3-4s)  - Planets + signs + dasha + yogas/doshas (calculated)
 *                         Used for onboarding, gets user seeing their chart fast
 * - "standard" (~6-8s)  - Basic + samvat + detailed dasha + yogas + panchang + navamsa
 *                         Default for returning users, provides complete astro data
 * - "full"     (~7-9s)  - Standard + shadbala + d10 (career chart)
 *                         On-demand when viewing detailed planet strengths
 * - "muhurat"  (~8-9s)  - Only muhurat data (3 days), DISABLED for now
 *                         Note: Muhurat is heavy and rarely used, disabled to save time
 * - "dasha"             - Only dasha data (legacy)
 * - "chart-only"        - Only planets (legacy)
 * 
 * NOTE: Muhurat disabled by default - takes 8-9s for a feature used in one place
 */
export const runAstroFlow = async ({
    mode = "full",
    payload,
    timeZoneId,
    timeZoneOffset,
}) => {
    const shouldFetchPlanets = mode !== "dasha" && mode !== "muhurat";
    const shouldFetchDasha = mode !== "chart-only" && mode !== "muhurat";
    const shouldFetchSamvat = mode === "standard" || mode === "full";
    const shouldFetchPanchang = mode === "standard" || mode === "full";
    // MUHURAT DISABLED - Takes 8-9 seconds for a feature that's rarely used
    // Enable with mode === "muhurat" if needed in future
    const shouldFetchMuhurat = mode === "muhurat"; // Explicitly disabled from "full"
    const shouldFetchExtras = mode === "full"; // navamsa moved to standard, keep shadbala/d10

    let planetData = null;
    let dashaData = null;
    let samvatInfo = null;
    const offsetHours = typeof timeZoneOffset === "number" ? timeZoneOffset : 0;

    logger.info(`🚀 runAstroFlow starting`, {
        mode,
        shouldFetchPlanets,
        shouldFetchDasha,
        shouldFetchSamvat,
        shouldFetchPanchang,
        shouldFetchMuhurat,
        shouldFetchExtras
    });

    // PHASE 1: Parallel fetch of core data (planets + samvat + dasha primary)
    // These can all be fetched simultaneously to save time
    const corePromises = [];

    // Planets promise
    if (shouldFetchPlanets) {
        corePromises.push(
            callFreeAstro(PLANETS_ENDPOINT, payload)
                .catch(async (planetsError) => {
                    const errorMsg = planetsError.message || "";
                    const statusCode = planetsError.statusCode ||
                        (errorMsg.match(/\((\d+)\)/) ? parseInt(errorMsg.match(/\((\d+)\)/)[1], 10) : null);

                    // Attempt fallback to legacy endpoint
                    if (statusCode === 404 || statusCode === 400 || statusCode === 422) {
                        try {
                            return await callFreeAstro(PLANETS_ENDPOINT_FALLBACK, payload);
                        } catch (fallbackError) {
                            return null;
                        }
                    }
                    return null;
                })
                .then(data => ({ type: 'planets', data }))
        );
    }

    // Samvat/calendar promises (only for standard/full)
    // Use the provided payload date (birth or current) without overrides.
    if (shouldFetchSamvat) {
        const samvatPayload = payload ? { ...payload, day: payload.date ?? payload.day } : payload;
        corePromises.push(
            Promise.all([
                callFreeAstroSafe(SAMVAT_ENDPOINT, samvatPayload),
                callFreeAstroSafe(LUNAR_MONTH_ENDPOINT, samvatPayload),
                callFreeAstroSafe(TITHI_ENDPOINT, samvatPayload),
            ]).then(([samvat, lunar, tithi]) => ({
                type: 'samvat',
                data: { samvat, lunar, tithi }
            }))
        );

        // Log which payload is being used - this is critical for debugging
        logger.info("📅 Fetching samvat info", {
            structuredData: true,
            payloadDate: samvatPayload ? `${samvatPayload.year}-${samvatPayload.month}-${samvatPayload.date}` : "none",
            payloadLocation: samvatPayload ? `${samvatPayload.latitude}, ${samvatPayload.longitude}` : "none",
            payloadTime: samvatPayload ? `${samvatPayload.hours}:${samvatPayload.minutes}` : "none",
        });
    }

    // Execute all core promises in parallel
    const coreResults = await Promise.all(corePromises);

    // Process results
    for (const result of coreResults) {
        if (result.type === 'planets' && result.data) {
            planetData = result.data;
        } else if (result.type === 'samvat' && result.data) {
            const { samvat, lunar, tithi } = result.data;

            const parsedSamvat = extractApiOutput(samvat);
            if (parsedSamvat && typeof parsedSamvat === "object") {
                samvatInfo = parsedSamvat;
            } else if (samvat && typeof samvat === "object") {
                samvatInfo = samvat;
            }

            const parsedLunarMonth = extractApiOutput(lunar);
            if (parsedLunarMonth && typeof parsedLunarMonth === "object") {
                samvatInfo = { ...samvatInfo, ...parsedLunarMonth };
            }

            const parsedTithi = extractApiOutput(tithi);
            if (parsedTithi && typeof parsedTithi === "object") {
                samvatInfo = { ...samvatInfo, ...parsedTithi };
            }
        }
    }

    // Fetch dasha only if requested
    if (shouldFetchDasha) {
        try {
            // Try the primary endpoint first
            let rawDashaResponse = null;

            try {
                rawDashaResponse = await callFreeAstro(DASHA_ENDPOINT, payload);
            } catch (firstError) {
                // Extract status code from error
                const statusCode = firstError.statusCode ||
                    (
                        firstError.message &&
                            firstError.message.match(/\((\d+)\)/) ?
                            parseInt(firstError.message.match(/\((\d+)\)/)[1], 10) :
                            null
                    );

                // If primary endpoint fails with 403/404, try alternatives
                if (statusCode === 403 || statusCode === 404) {
                    const alternatives = [DASHA_ENDPOINT_ALT1, DASHA_ENDPOINT_ALT2, DASHA_ENDPOINT_ALT3];

                    for (const altEndpoint of alternatives) {
                        try {
                            rawDashaResponse = await callFreeAstro(altEndpoint, payload);
                            break;
                        } catch (altError) {
                            continue;
                        }
                    }
                } else {
                    throw firstError; // Re-throw if it's not a 403/404
                }
            }

            if (!rawDashaResponse) {
                throw new Error("All dasha endpoints failed");
            }

            // Process dasha response - extract current maha dasha
            if (rawDashaResponse) {
                const now = new Date();

                // Parse the API response (might be stringified JSON in output field)
                let dashaPeriodsObj = null;

                if (rawDashaResponse.output && typeof rawDashaResponse.output === "string") {
                    try {
                        dashaPeriodsObj = JSON.parse(rawDashaResponse.output);
                    } catch (parseError) {
                        logger.error("Failed to parse dasha output", {
                            structuredData: true,
                            error: parseError.message,
                            outputPreview: rawDashaResponse.output?.substring(0, 200),
                        });
                    }
                } else if (typeof rawDashaResponse === "object" && !Array.isArray(rawDashaResponse)) {
                    dashaPeriodsObj = rawDashaResponse;
                }

                if (dashaPeriodsObj && typeof dashaPeriodsObj === "object" && !Array.isArray(dashaPeriodsObj)) {
                    const dashaEntries = Object.entries(dashaPeriodsObj);

                    // Build comprehensive dasha structure
                    const allMahaDashas = [];
                    let currentMahaDasha = null;
                    let currentAntarDasha = null;

                    for (const [mahaKey, mahaPeriod] of dashaEntries) {
                        if (!mahaPeriod || typeof mahaPeriod !== "object") continue;

                        let antarDashas = [];
                        let mahaStartRaw = mahaPeriod.start_time || mahaPeriod.startTime || null;
                        let mahaEndRaw = mahaPeriod.end_time || mahaPeriod.endTime || null;

                        // Primary format: explicit sub_lords object
                        if (mahaPeriod.sub_lords && typeof mahaPeriod.sub_lords === "object") {
                            antarDashas = buildAntarDashas(mahaPeriod.sub_lords, { offsetHours });
                        }

                        // New format: mahaPeriod itself is a map of antar dashas keyed by lord names
                        if (!antarDashas.length) {
                            const nestedAntar = buildAntarDashas(mahaPeriod, { fallbackToKey: true, offsetHours });
                            if (nestedAntar.length) {
                                antarDashas = nestedAntar;

                                if (!mahaStartRaw) {
                                    mahaStartRaw = nestedAntar[0].startDate;
                                }
                                if (!mahaEndRaw) {
                                    mahaEndRaw = nestedAntar[nestedAntar.length - 1].endDate;
                                }
                            }
                        }

                        if (!mahaStartRaw || !mahaEndRaw) continue;

                        const mahaStart = parseDashaDate(mahaStartRaw, offsetHours);
                        const mahaEnd = parseDashaDate(mahaEndRaw, offsetHours);
                        const mahaStartIso = formatDashaDateForStorage(mahaStartRaw, offsetHours);
                        const mahaEndIso = formatDashaDateForStorage(mahaEndRaw, offsetHours);
                        if (!mahaStart || !mahaEnd) {
                            continue;
                        }
                        const mahaLord = mahaPeriod.Lord || mahaPeriod.lord || mahaKey;
                        const isCurrentMaha = now >= mahaStart && now <= mahaEnd;

                        if (isCurrentMaha && antarDashas.length) {
                            const currentAntar = antarDashas.find((antar) => {
                                const antarStart = parseDashaDate(antar.startDate, offsetHours);
                                const antarEnd = parseDashaDate(antar.endDate, offsetHours);
                                return antarStart && antarEnd && now >= antarStart && now <= antarEnd;
                            });
                            if (currentAntar) {
                                currentAntarDasha = currentAntar;
                            }
                        }

                        allMahaDashas.push({
                            lord: mahaLord,
                            startDate: mahaStartIso,
                            endDate: mahaEndIso,
                            antarDashas,
                        });

                        if (isCurrentMaha) {
                            currentMahaDasha = {
                                lord: mahaLord,
                                startDate: mahaStartIso,
                                endDate: mahaEndIso,
                            };
                        }
                    }

                    const dashaTree = allMahaDashas.map((maha) => ({
                        level: "maha",
                        lord: maha.lord,
                        startDate: maha.startDate,
                        endDate: maha.endDate,
                        children: (maha.antarDashas || []).map((antar) => ({
                            level: "antar",
                            lord: antar.lord,
                            startDate: antar.startDate,
                            endDate: antar.endDate,
                        })),
                    }));

                    const baseLevels = {};
                    if (currentMahaDasha) {
                        baseLevels.maha = {
                            lord: currentMahaDasha.lord,
                            startDate: currentMahaDasha.startDate,
                            endDate: currentMahaDasha.endDate,
                        };
                    }
                    if (currentAntarDasha) {
                        baseLevels.antar = {
                            lord: currentAntarDasha.lord,
                            startDate: currentAntarDasha.startDate,
                            endDate: currentAntarDasha.endDate,
                        };
                    }

                    // Calculate progress and format dates for frontend
                    const calculateProgress = (startDate, endDate) => {
                        if (!startDate || !endDate) return null;
                        try {
                            const start = new Date(startDate);
                            const end = new Date(endDate);
                            const now = new Date();

                            // Validate dates
                            if (isNaN(start.getTime()) || isNaN(end.getTime())) return null;
                            if (end <= start) return null;

                            const total = (end - start) / 1000; // seconds
                            const elapsed = (now - start) / 1000; // seconds

                            if (total <= 0) return null;

                            const progress = Math.max(0, Math.min(1, elapsed / total));
                            return isNaN(progress) || !isFinite(progress) ? null : progress;
                        } catch (e) {
                            logger.warn("⚠️ Error calculating dasha progress:", e.message);
                            return null;
                        }
                    };

                    const formatDateRange = (startDate, endDate) => {
                        if (!startDate || !endDate) return "Dates unavailable";
                        try {
                            const start = new Date(startDate);
                            const end = new Date(endDate);

                            // Validate dates
                            if (isNaN(start.getTime()) || isNaN(end.getTime())) {
                                return "Dates unavailable";
                            }

                            const formatDate = (date) => {
                                const day = String(date.getDate()).padStart(2, "0");
                                const month = String(date.getMonth() + 1).padStart(2, "0");
                                return `${day}/${month}/${date.getFullYear()}`;
                            };
                            return `${formatDate(start)} → ${formatDate(end)}`;
                        } catch (e) {
                            logger.warn("⚠️ Error formatting date range:", e.message);
                            return "Dates unavailable";
                        }
                    };

                    // Return clean comprehensive dasha data with pre-processed display data
                    if (currentMahaDasha) {
                        const processedLevels = {};
                        Object.entries(baseLevels).forEach(([levelKey, levelData]) => {
                            if (levelData) {
                                processedLevels[levelKey] = {
                                    ...levelData,
                                    progress: calculateProgress(levelData.startDate, levelData.endDate),
                                    dateRange: formatDateRange(levelData.startDate, levelData.endDate),
                                };
                            }
                        });

                        dashaData = {
                            mahadasha: currentMahaDasha.lord,
                            antardasha: currentAntarDasha?.lord || null,
                            mahaStartDate: currentMahaDasha.startDate,
                            mahaEndDate: currentMahaDasha.endDate,
                            antarStartDate: currentAntarDasha?.startDate || null,
                            antarEndDate: currentAntarDasha?.endDate || null,
                            allMahaDashas,
                            tree: dashaTree,
                            levels: baseLevels,
                            processedLevels, // Pre-processed for frontend display
                        };
                    } else {
                        logger.warn("Could not find current dasha period", { structuredData: true });
                        dashaData = null;
                    }
                } else {
                    logger.warn("Could not parse dasha structure", { structuredData: true });
                    dashaData = null;
                }
            } else {
                logger.warn("Raw dasha response is null", { structuredData: true });
                dashaData = null;
            }
        } catch (dashaError) {
            logger.error("Dasha fetch error", {
                structuredData: true,
                error: dashaError.message,
            });
            dashaData = null;
        }
    }

    // Enrich with deeper dasa levels (pratyantar → deha) for the current moment
    // Only fetch for standard/full modes - basic mode skips this for speed
    const mergedDashaLevels = dashaData?.levels ? { ...dashaData.levels } : {};
    let detailedDashaInfo = null;
    const shouldFetchDetailedDasha = shouldFetchDasha && (mode === "standard" || mode === "full");

    if (shouldFetchDetailedDasha) {
        try {
            const offsetHours = typeof timeZoneOffset === "number" ? timeZoneOffset : 0;
            let localTime = DateTime.now().setZone(timeZoneId || "UTC");
            if (!localTime.isValid) {
                localTime = DateTime.now().setZone("UTC");
            }
            const eventData = {
                year: localTime.year,
                month: localTime.month,
                date: localTime.day,
                hours: localTime.hour,
                minutes: localTime.minute,
                seconds: Math.floor(localTime.second),
            };

            const dasaInfoPayload = {
                ...payload,
                event_data: eventData,
            };

            detailedDashaInfo = await callFreeAstro(DASA_INFORMATION_ENDPOINT, dasaInfoPayload);

            const parsedDetailedInfo = extractApiOutput(detailedDashaInfo);
            const detailedSource = parsedDetailedInfo && typeof parsedDetailedInfo === "object" ?
                parsedDetailedInfo :
                null;

            const normalizeLevel = (source, levelKey) => {
                if (!source || typeof source !== "object") return null;
                const lord = source.Lord || source.lord || source.planet || null;
                if (!lord) return null;
                const start = source.start_time || source.startTime || source.start || null;
                const end = source.end_time || source.endTime || source.end || null;
                return {
                    lord,
                    startDate: formatDashaDateForStorage(start, offsetHours),
                    endDate: formatDashaDateForStorage(end, offsetHours),
                    level: levelKey,
                };
            };

            const detailedLevels = {
                maha: normalizeLevel(detailedSource?.maha_dasa, "maha"),
                antar: normalizeLevel(detailedSource?.antar_dasa, "antar"),
                pratyantar: normalizeLevel(detailedSource?.pratyantar_dasa, "pratyantar"),
                sookshma: normalizeLevel(detailedSource?.sookshma_antar_dasa, "sookshma"),
                praana: normalizeLevel(detailedSource?.praana_antar_dasa, "praana"),
                deha: normalizeLevel(detailedSource?.deha_antar_dasa, "deha"),
            };

            Object.entries(detailedLevels).forEach(([key, value]) => {
                if (!value) return;
                if (!mergedDashaLevels[key]) {
                    mergedDashaLevels[key] = value;
                }
                if (dashaData) {
                    if (key === "maha") {
                        dashaData.mahadasha = value.lord;
                        dashaData.mahaStartDate = value.startDate;
                        dashaData.mahaEndDate = value.endDate;
                    }
                    if (key === "antar") {
                        dashaData.antardasha = value.lord;
                        dashaData.antarStartDate = value.startDate;
                        dashaData.antarEndDate = value.endDate;
                    }
                }
            });

            if (parsedDetailedInfo) {
                detailedDashaInfo = parsedDetailedInfo;
            }
        } catch (detailedError) {
            logger.warn("Detailed dasa info fetch failed", {
                structuredData: true,
                error: detailedError.message,
            });
        }
    }

    // Simple: return valid dasha data or null
    const hasLevelData = Object.keys(mergedDashaLevels).length > 0;
    const finalDashaData = (shouldFetchDasha && (dashaData || hasLevelData)) ? {
        ...(dashaData || {}),
        levels: mergedDashaLevels,
        detailed: shouldFetchDetailedDasha ? detailedDashaInfo : null,
    } : null;

    const result = {
        currentDasha: finalDashaData,
        timeZoneId,
        timeZoneOffset,
        samvatInfo,
    };

    // Final result is ready - no need to log success

    if (shouldFetchPlanets && planetData) {
        // Use centralized constants from lib/constants.js
        const vedicSigns = ZODIAC_SIGNS;
        const nakshatras = NAKSHATRAS;

        const planetsOutput = Array.isArray(planetData.output) ?
            planetData.output[0] :
            planetData.output;

        const normalizedPlanets = [];
        if (planetsOutput && typeof planetsOutput === "object") {
            Object.entries(planetsOutput).forEach(([key, value]) => {
                if (value && typeof value === "object") {
                    normalizedPlanets.push({
                        apiName: key,
                        name: value.name || key,
                        ...value,
                    });
                }
            });
        }


        const getPlanet = (targets) => normalizedPlanets.find((planet) => {
            const label = (planet.apiName || planet.name || "").toString().toLowerCase();
            if (!label) return false;
            if (Array.isArray(targets)) {
                return targets.some((target) => target === label);
            }
            return label === targets;
        });

        const degToSign = (degree) => {
            if (typeof degree !== "number") return null;
            return vedicSigns[Math.floor(degree / 30) % 12];
        };

        const degToNakshatra = (degree) => {
            if (typeof degree !== "number") return null;
            return nakshatras[Math.floor(degree / (360 / 27)) % 27];
        };

        const ascendantPlanet = getPlanet(["ascendant", "lagna", "0"]);
        const sunPlanet = getPlanet(["sun", "1"]);
        const moonPlanet = getPlanet(["moon", "2"]);

        const sunSign = sunPlanet?.zodiac_sign_name ||
            degToSign(sunPlanet?.fullDegree || sunPlanet?.full_degree);
        const moonSign = moonPlanet?.zodiac_sign_name ||
            degToSign(moonPlanet?.fullDegree || moonPlanet?.full_degree);
        const ascendant = ascendantPlanet?.zodiac_sign_name ||
            degToSign(ascendantPlanet?.fullDegree || ascendantPlanet?.full_degree);

        const moonNakshatra = moonPlanet?.nakshatra_name ||
            degToNakshatra(moonPlanet?.fullDegree || moonPlanet?.full_degree);
        const lagnaNakshatra = ascendantPlanet?.nakshatra_name ||
            degToNakshatra(ascendantPlanet?.fullDegree || ascendantPlanet?.full_degree);

        result.sunSign = sunSign;
        result.moonSign = moonSign;
        result.ascendant = ascendant;
        result.nakshatra = moonNakshatra;
        result.moonNakshatra = moonNakshatra;
        result.lagnaNakshatra = lagnaNakshatra;
        result.birthChartData = planetData;

        // Process planets for frontend display (pre-processed data)
        const processedPlanets = [];
        const planetOrder = [
            { name: "Ascendant", label: "Lagna", legacy: "0" },
            { name: "Sun", label: "Sun", legacy: "1" },
            { name: "Moon", label: "Moon", legacy: "2" },
            { name: "Mars", label: "Mars", legacy: "4" },
            { name: "Mercury", label: "Mercury", legacy: "5" },
            { name: "Jupiter", label: "Jupiter", legacy: "6" },
            { name: "Venus", label: "Venus", legacy: "3" },
            { name: "Saturn", label: "Saturn", legacy: "7" },
            { name: "Rahu", label: "Rahu", legacy: "8" },
            { name: "Ketu", label: "Ketu", legacy: "9" },
        ];

        const resolvePlanet = (name, legacyKey) => {
            const found = normalizedPlanets.find((p) => {
                const label = (p.apiName || p.name || "").toString().toLowerCase();
                return label === name.toLowerCase() ||
                    (legacyKey && label === legacyKey) ||
                    (p.apiName && p.apiName.toString().toLowerCase() === name.toLowerCase());
            });
            return found || null;
        };

        planetOrder.forEach((planetInfo) => {
            const planetData = resolvePlanet(planetInfo.name, planetInfo.legacy);
            if (!planetData) return;

            const fullDegree = planetData.fullDegree || planetData.full_degree;
            const degreesInSign = fullDegree != null ? fullDegree % 30 : null;
            const degrees = planetData.degrees ?? (degreesInSign != null ? Math.floor(degreesInSign) : null);
            const minutes = planetData.minutes ??
                (degreesInSign != null ? Math.floor((degreesInSign - Math.floor(degreesInSign)) * 60) : null);
            const seconds = planetData.seconds ??
                (degreesInSign != null ? Math.floor((((degreesInSign - Math.floor(degreesInSign)) * 60) % 1) * 60) : null);

            const sign = planetData.zodiac_sign_name || degToSign(fullDegree);
            const nakshatraName = planetData.nakshatra_name || degToNakshatra(fullDegree);
            const houseNumber = planetData.house_number || planetData.houseNumber;
            // Properly handle retrograde - API might return string "true"/"false" or boolean
            const retroValue = planetData.isRetro ?? planetData.retrograde ?? false;
            const isRetrograde = retroValue === true || retroValue === "true" || retroValue === "True" || retroValue === 1;

            // Only add planet if we have essential data
            if (sign || nakshatraName || houseNumber != null) {
                const planetEntry = {
                    name: planetInfo.label,
                    sign: sign || null,
                    nakshatra: nakshatraName || null,
                    houseNumber: houseNumber || null,
                    degrees: degrees || null,
                    minutes: minutes || null,
                    seconds: seconds || null,
                    fullDegree: fullDegree || null,
                    isRetrograde: Boolean(isRetrograde),
                };

                // Calculate and add dignity for planets (not Ascendant)
                if (planetInfo.label !== "Lagna" && sign) {
                    const dignity = calculatePlanetDignity(planetInfo.label, sign, degreesInSign ?? 15);
                    if (dignity) {
                        planetEntry.dignity = dignity.dignity;
                        planetEntry.dignityScore = dignity.score;
                        if (dignity.isExalted) planetEntry.isExalted = true;
                        if (dignity.isDebilitated) planetEntry.isDebilitated = true;
                        if (dignity.isMoolTrikona) planetEntry.isMoolTrikona = true;
                        if (dignity.isOwnSign) planetEntry.isOwnSign = true;
                    }
                }

                processedPlanets.push(planetEntry);
            }
        });

        result.processedPlanets = processedPlanets;

        // Calculate Raj Yogas from planetary positions
        try {
            const rajYogas = calculateRajYogas(planetsOutput, ascendantPlanet);
            result.rajYogas = rajYogas && rajYogas.length > 0 ? rajYogas : [];
        } catch (rajYogaError) {
            logger.warn("Raj Yoga calculation error", {
                structuredData: true,
                error: rajYogaError.message,
            });
            result.rajYogas = [];
        }
    }

    // Fetch additional comprehensive astrology data based on mode
    let doshasData = null;
    let yogasData = null;
    let panchangData = null;
    let muhuratData = null;
    let navamsaData = null;

    // Doshas are always calculated from planets (fast, local calculation)
    // This runs in all modes since it's CPU-only, no API calls
    if (shouldFetchPlanets && planetData) {
        const planetsOutput = Array.isArray(planetData.output) ?
            planetData.output[0] :
            planetData.output;

        if (planetsOutput && typeof planetsOutput === "object") {
            const planetsMap = {};
            Object.entries(planetsOutput).forEach(([key, value]) => {
                if (value && typeof value === "object") {
                    planetsMap[key] = value;
                }
            });

            const ascendant = planetsMap["0"] || planetsMap.Ascendant || planetsMap.ascendant ||
                Object.values(planetsMap).find((p) =>
                    p && (p.name?.toLowerCase() === "ascendant" || p.name?.toLowerCase() === "lagna"),
                );

            if (Object.keys(planetsMap).length > 0) {
                doshasData = calculateDoshasFromPlanets(planetsMap, ascendant);

                // Add Gandmool Dosha if Moon nakshatra is available
                if (result.moonNakshatra) {
                    const gandmoolData = calculateGandmoolDosha(result.moonNakshatra);
                    if (gandmoolData && gandmoolData.gandmool_dosha) {
                        doshasData = { ...doshasData, ...gandmoolData };
                    }
                }

                // Add combustion data for affected planets
                const combustionData = calculateCombustionStates(planetsMap);
                if (combustionData) {
                    doshasData = doshasData || {};
                    doshasData.combustion = combustionData;

                    // Count combust planets for severity
                    const combustCount = Object.keys(combustionData).length;
                    if (combustCount > 0) {
                        doshasData.has_combustion = true;
                        doshasData.combust_planets = Object.keys(combustionData);
                    }
                }
            }
        }
    }

    // Fetch Yogas using yoga-durations endpoint - only for standard/full modes
    if (shouldFetchPanchang) {
        try {
            const yogasResponse = await callFreeAstro(YOGA_DURATIONS_ENDPOINT, payload);
            const parsedYogas = extractApiOutput(yogasResponse);
            if (parsedYogas && typeof parsedYogas === "object") {
                yogasData = parsedYogas;
            }
        } catch (yogasError) {
            logger.warn("Yoga-durations fetch failed", {
                structuredData: true,
                error: yogasError.message?.substring(0, 200),
            });
        }
    }

    // Fetch Panchang (daily astrological calendar) - only for standard/full modes
    if (shouldFetchPanchang) {
        const panchangPayload = payload ? { ...payload, day: payload.date ?? payload.day } : payload;
        try {
            panchangData = {};

            // Get tithi using tithi-durations endpoint
            try {
                const tithiResponse = await callFreeAstro(TITHI_ENDPOINT, panchangPayload);
                const parsedTithi = extractApiOutput(tithiResponse);

                if (parsedTithi && typeof parsedTithi === "object") {
                    const tithiName = parsedTithi.name;
                    const paksha = parsedTithi.paksha;

                    if (tithiName) {
                        const pakshaCapitalized = paksha ? paksha.charAt(0).toUpperCase() + paksha.slice(1) : "";
                        panchangData.tithi = pakshaCapitalized ? `${pakshaCapitalized} ${tithiName}` : tithiName;
                        panchangData.tithiNumber = parsedTithi.number;
                        panchangData.tithiPaksha = paksha;
                        panchangData.tithiCompletesAt = parsedTithi.completes_at;
                    }
                }
            } catch (tithiError) {
                logger.warn("Tithi fetch failed", {
                    structuredData: true,
                    error: tithiError.message?.substring(0, 100),
                });
            }

            // Fallback to samvatInfo if tithi not found
            if (!panchangData.tithi && samvatInfo?.tithi) {
                panchangData.tithi = samvatInfo.tithi;
            }

            // Get nakshatra information
            try {
                const nakshatraResponse = await callFreeAstro(NAKSHATRA_DURATIONS_ENDPOINT, panchangPayload);
                const parsedNakshatra = extractApiOutput(nakshatraResponse);
                if (parsedNakshatra && typeof parsedNakshatra === "object") {
                    panchangData.nakshatra = parsedNakshatra.name || parsedNakshatra.nakshatra;
                    panchangData.nakshatraNumber = parsedNakshatra.number;
                }
            } catch (nakshatraError) {
                logger.warn("Nakshatra-durations fetch failed", {
                    structuredData: true,
                    error: nakshatraError.message,
                });
            }

            // Get yoga information (already fetched above)
            if (yogasData) {
                const yogaEntries = Object.values(yogasData);
                if (yogaEntries.length > 0 && yogaEntries[0].name) {
                    panchangData.yoga = yogaEntries[0].name;
                    panchangData.yogaNumber = yogaEntries[0].number;
                }
            }

            // Use karana from samvatInfo
            if (samvatInfo?.karana) {
                panchangData.karana = samvatInfo.karana;
            }

            // Get vedic weekday
            try {
                const weekdayResponse = await callFreeAstro(VEDIC_WEEKDAY_ENDPOINT, panchangPayload);
                const parsedWeekday = extractApiOutput(weekdayResponse);
                if (parsedWeekday && typeof parsedWeekday === "object") {
                    panchangData.vedicWeekday = parsedWeekday.vedic_weekday_name || parsedWeekday.vedicWeekdayName;
                    panchangData.weekday = parsedWeekday.weekday_name || parsedWeekday.weekdayName;
                }
            } catch (weekdayError) {
                logger.warn("Vedic weekday fetch failed", {
                    structuredData: true,
                    error: weekdayError.message,
                });
            }

            // Merge samvatInfo fields into panchangData so panchang always has
            // lunar month and Vikram Samvat year (these come from separate API calls
            // stored in samvatInfo but are needed together with tithi/nakshatra)
            if (samvatInfo && panchangData) {
                if (!panchangData.lunar_month_full_name && samvatInfo.lunar_month_full_name) {
                    panchangData.lunar_month_full_name = samvatInfo.lunar_month_full_name;
                }
                if (!panchangData.lunar_month_name && samvatInfo.lunar_month_name) {
                    panchangData.lunar_month_name = samvatInfo.lunar_month_name;
                }
                if (!panchangData.vikram_chaitradi_number && samvatInfo.vikram_chaitradi_number) {
                    panchangData.vikram_chaitradi_number = samvatInfo.vikram_chaitradi_number;
                }
                if (!panchangData.vikram_chaitradi_year_name && samvatInfo.vikram_chaitradi_year_name) {
                    panchangData.vikram_chaitradi_year_name = samvatInfo.vikram_chaitradi_year_name;
                }
                if (!panchangData.saka_salivahana_number && samvatInfo.saka_salivahana_number) {
                    panchangData.saka_salivahana_number = samvatInfo.saka_salivahana_number;
                }
            }

            if (Object.keys(panchangData).filter((k) => panchangData[k] != null).length === 0) {
                panchangData = null;
            }
        } catch (panchangError) {
            logger.warn("Panchang build failed", {
                structuredData: true,
                error: panchangError.message?.substring(0, 200),
            });
        }
    } // End shouldFetchPanchang

    // Fetch Muhurat (auspicious/inauspicious times) for 72 hours (3 days)
    // Only for full mode or muhurat mode - this is the slowest part (~8-9s)
    if (shouldFetchMuhurat) {
        const muhuratPayload = payload;
        try {

            // parseMuhuratDay imported from lib/muhurat_helpers.js
            const parseMuhuratDay = _parseMuhuratDay;

            // processUnifiedTimeline imported from lib/muhurat_helpers.js

            // Fetch muhurat for 3 days (today, tomorrow, day after tomorrow)
            muhuratData = {
                days: {},
                fetchedAt: DateTime.now().toISO(),
            };

            const localTime = DateTime.now().setZone(timeZoneId || "UTC");
            if (localTime.isValid && muhuratPayload && muhuratPayload.latitude != null) {
                // Prepare payloads for all 3 days
                const dayPayloads = [];
                for (let dayOffset = 0; dayOffset < 3; dayOffset++) {
                    const targetDate = localTime.plus({ days: dayOffset });
                    const dateKey = `${targetDate.year}-${targetDate.month.toString().padStart(2, "0")}-${targetDate.day.toString().padStart(2, "0")}`;
                    dayPayloads.push({
                        dateKey,
                        payload: {
                            year: targetDate.year,
                            month: targetDate.month,
                            date: targetDate.day,
                            hours: 0,
                            minutes: 0,
                            seconds: 0,
                            latitude: muhuratPayload.latitude,
                            longitude: muhuratPayload.longitude,
                            timezone: offsetHours,
                        },
                    });
                }

                // Fetch muhurat for all 3 days in parallel
                const muhuratPromises = dayPayloads.map(({ dateKey, payload }) =>
                    callFreeAstroSafe(GOOD_BAD_TIMES_ENDPOINT, payload)
                        .then((response) => ({ dateKey, response }))
                        .catch(() => ({ dateKey, response: null })),
                );
                const muhuratResults = await Promise.all(muhuratPromises);

                for (const { dateKey, response } of muhuratResults) {
                    const parsedMuhurat = extractApiOutput(response);
                    if (parsedMuhurat && typeof parsedMuhurat === "object") {
                        muhuratData.days[dateKey] = parseMuhuratDay(parsedMuhurat);
                    }
                }

                // Fetch panchang timing events for 3 days (nakshatra, yoga, hora, choghadiya)
                muhuratData.timelineEvents = {
                    days: {},
                    fetchedAt: DateTime.now().toISO(),
                };

                for (let dayOffset = 0; dayOffset < 3; dayOffset++) {
                    try {
                        const targetDate = localTime.plus({ days: dayOffset });
                        const dayPayload = {
                            year: targetDate.year,
                            month: targetDate.month,
                            date: targetDate.day,
                            hours: 0,
                            minutes: 0,
                            seconds: 0,
                            latitude: muhuratPayload.latitude,
                            longitude: muhuratPayload.longitude,
                            timezone: offsetHours,
                            config: {
                                observation_point: "geocentric",
                                ayanamsha: "lahiri",
                            },
                        };

                        const dateKey = `${targetDate.year}-${targetDate.month.toString().padStart(2, "0")}-${targetDate.day.toString().padStart(2, "0")}`;
                        const dayEvents = {};

                        // Fetch all timeline data in parallel for performance
                        const [nakshatraResponse, yogaResponse, horaResponse, choghadiyaResponse] = await Promise.all([
                            callFreeAstroSafe(NAKSHATRA_DURATIONS_ENDPOINT, dayPayload),
                            callFreeAstroSafe(YOGA_DURATIONS_ENDPOINT, dayPayload),
                            callFreeAstroSafe(HORA_TIMINGS_ENDPOINT, dayPayload),
                            callFreeAstroSafe(CHOGHADIYA_TIMINGS_ENDPOINT, dayPayload),
                        ]);

                        // Process nakshatra response
                        const parsedNakshatra = extractApiOutput(nakshatraResponse);
                        if (parsedNakshatra && typeof parsedNakshatra === "object") {
                            if (Array.isArray(parsedNakshatra)) {
                                dayEvents.nakshatraChanges = parsedNakshatra;
                            } else if (parsedNakshatra.nakshatra_timings || parsedNakshatra.timings) {
                                dayEvents.nakshatraChanges = parsedNakshatra.nakshatra_timings || parsedNakshatra.timings;
                            } else {
                                dayEvents.nakshatra = parsedNakshatra;
                            }
                        }

                        // Process yoga response
                        const parsedYoga = extractApiOutput(yogaResponse);
                        if (parsedYoga && typeof parsedYoga === "object") {
                            if (Array.isArray(parsedYoga)) {
                                dayEvents.yogaChanges = parsedYoga;
                            } else if (parsedYoga.yoga_timings || parsedYoga.timings) {
                                dayEvents.yogaChanges = parsedYoga.yoga_timings || parsedYoga.timings;
                            } else {
                                dayEvents.yoga = parsedYoga;
                            }
                        }

                        // Process hora response
                        const parsedHora = extractApiOutput(horaResponse);
                        if (parsedHora && typeof parsedHora === "object") {
                            if (Array.isArray(parsedHora)) {
                                dayEvents.horaChanges = parsedHora;
                            } else if (parsedHora.hora_timings || parsedHora.timings) {
                                dayEvents.horaChanges = parsedHora.hora_timings || parsedHora.timings;
                            } else {
                                dayEvents.hora = parsedHora;
                            }
                        }

                        // Process choghadiya response
                        const parsedChoghadiya = extractApiOutput(choghadiyaResponse);
                        if (parsedChoghadiya && typeof parsedChoghadiya === "object") {
                            if (Array.isArray(parsedChoghadiya)) {
                                dayEvents.choghadiyaChanges = parsedChoghadiya;
                            } else if (parsedChoghadiya.choghadiya_timings || parsedChoghadiya.timings) {
                                dayEvents.choghadiyaChanges = parsedChoghadiya.choghadiya_timings || parsedChoghadiya.timings;
                            } else {
                                dayEvents.choghadiya = parsedChoghadiya;
                            }
                        }

                        if (Object.keys(dayEvents).length > 0) {
                            muhuratData.timelineEvents.days[dateKey] = dayEvents;
                        }

                        // Reduced delay since we're using parallel calls now
                        if (dayOffset < 2) {
                            await new Promise((resolve) => setTimeout(resolve, 100));
                        }
                    } catch (dayError) {
                        logger.warn("Timeline events fetch failed", {
                            structuredData: true,
                            dayOffset,
                            error: dayError.message?.substring(0, 200),
                        });
                    }
                }

                // For backward compatibility, also set today's data at root level
                const todayKey = `${localTime.year}-${localTime.month.toString().padStart(2, "0")}-${localTime.day.toString().padStart(2, "0")}`;
                if (muhuratData.days[todayKey]) {
                    Object.assign(muhuratData, muhuratData.days[todayKey]);
                }

                // Process all days into a unified timeline with absolute positions
                muhuratData.unifiedTimeline = _processUnifiedTimeline(muhuratData.days, timeZoneId, { clampBounds: true, includeDayCount: true });
            } else {
                // Fallback to single day if we can't determine dates
                const muhuratResponse = await callFreeAstro(GOOD_BAD_TIMES_ENDPOINT, muhuratPayload);
                const parsedMuhurat = extractApiOutput(muhuratResponse);
                if (parsedMuhurat && typeof parsedMuhurat === "object") {
                    muhuratData = parseMuhuratDay(parsedMuhurat);
                    muhuratData.fetchedAt = DateTime.now().toISO();
                }
            }
        } catch (muhuratError) {
            logger.warn("Muhurat fetch failed", {
                structuredData: true,
                error: muhuratError.message?.substring(0, 200),
            });
        }
    } // End shouldFetchMuhurat

    // Fetch Navamsa (D9) for standard+ modes - commonly needed for relationship insights
    if (shouldFetchPanchang) { // standard or full
        const navamsaResponse = await callFreeAstroSafe(NAVAMSA_INFO_ENDPOINT, payload);
        const parsedNavamsa = extractApiOutput(navamsaResponse);
        if (parsedNavamsa && typeof parsedNavamsa === "object") {
            navamsaData = parsedNavamsa;
        }
    }

    // Fetch Shad Bala and D10 Chart - only for full mode (detailed strength analysis)
    let shadBalaData = null;
    let d10ChartData = null;
    if (shouldFetchExtras) {
        const [shadBalaResponse, d10Response] = await Promise.all([
            callFreeAstroSafe(SHADBALA_SUMMARY_ENDPOINT, payload),
            callFreeAstroSafe(D10_CHART_ENDPOINT, payload),
        ]);

        // Process Shad Bala response
        const parsedShadBala = extractApiOutput(shadBalaResponse);
        if (parsedShadBala && typeof parsedShadBala === "object") {
            shadBalaData = parsedShadBala;

            // Calculate strong and weak planets
            const strongPlanets = [];
            const weakPlanets = [];

            Object.entries(parsedShadBala).forEach(([planet, data]) => {
                if (data && typeof data === "object" && data.percentage_strength != null) {
                    const strength = data.percentage_strength;
                    if (strength >= 100) {
                        strongPlanets.push({ planet, strength: Math.round(strength) });
                    } else {
                        weakPlanets.push({ planet, strength: Math.round(strength) });
                    }
                }
            });

            // Sort by strength
            strongPlanets.sort((a, b) => b.strength - a.strength);
            weakPlanets.sort((a, b) => a.strength - b.strength);

            shadBalaData._analysis = {
                strongPlanets,
                weakPlanets,
                strongestPlanet: strongPlanets[0] || null,
                weakestPlanet: weakPlanets[0] || null,
            };
        }

        // Process D10 response
        const parsedD10 = extractApiOutput(d10Response);
        if (parsedD10 && typeof parsedD10 === "object") {
            d10ChartData = parsedD10;
        }
    }

    // Add new data to result
    if (doshasData) result.doshas = doshasData;
    if (yogasData) result.yogasDetailed = yogasData;
    if (panchangData) result.panchang = panchangData;
    if (muhuratData) result.muhurat = muhuratData;
    if (navamsaData) result.navamsa = navamsaData;
    if (shadBalaData) result.shadBala = shadBalaData;
    if (d10ChartData) result.d10Chart = d10ChartData;

    // Add sync status to track which level of data was fetched
    // This helps frontend know what data is available and what needs lazy loading
    result.syncMode = mode;

    // CRITICAL: Only mark as complete if we actually got the core data
    // If planetData is null or signs weren't extracted, mark as partial/failed
    const hasBasicData = result.sunSign && result.moonSign && result.ascendant;

    if (!hasBasicData) {
        // Planet data fetch failed - mark as partial and log the issue
        result.syncStatus = "partial";
        logger.error(`❌ runAstroFlow FAILED - no planet data retrieved`, {
            structuredData: true,
            mode,
            hasPlanets: !!planetData,
            sunSign: result.sunSign,
            moonSign: result.moonSign,
            ascendant: result.ascendant,
            message: "FreeAstrologyAPI may be down, rate limited, or API key invalid",
        });
    } else {
        result.syncStatus = mode === "basic" ? "basic_complete" :
            mode === "standard" ? "standard_complete" :
                mode === "full" ? "full_complete" :
                    mode === "muhurat" ? "muhurat_complete" : "partial";
    }

    logger.info(`✅ runAstroFlow completed`, {
        mode,
        syncStatus: result.syncStatus,
        hasPlanets: !!planetData,
        hasBasicData,
        sunSign: result.sunSign,
        moonSign: result.moonSign,
        hasDasha: !!finalDashaData,
        hasDoshas: !!doshasData,
        hasYogas: !!yogasData,
        hasPanchang: !!panchangData,
        hasMuhurat: !!muhuratData,
        hasNavamsa: !!navamsaData,
    });

    return result;
};

export const freeAstroCalculate = onCall({
    secrets: [freeAstrologyApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
    // AppCheck: DISABLED until Flutter client enables FirebaseAppCheck
    // TODO: Set enforceAppCheck: true after enabling AppCheck in lib/main.dart
}, async (request) => {
    try {
        requireAuth(request, "request astrology data");

        const {
            mode = "full",
            birthDate,
            birthTime,
            latitude,
            longitude,
            timeZoneId,
            timeZoneOffset,
        } = request.data || {};

        // Validate required fields
        if (!birthDate || typeof birthDate !== "string" || !birthTime || typeof birthTime !== "string") {
            throw new HttpsError(
                "invalid-argument",
                "birthDate and birthTime are required and must be strings",
            );
        }

        if (typeof latitude !== "number" || typeof longitude !== "number") {
            throw new HttpsError(
                "invalid-argument",
                "latitude and longitude must be numbers",
            );
        }

        // Validate coordinate ranges
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            throw new HttpsError(
                "invalid-argument",
                "Invalid latitude or longitude values",
            );
        }

        if (typeof timeZoneOffset !== "number" || isNaN(timeZoneOffset)) {
            throw new HttpsError(
                "invalid-argument",
                `timeZoneOffset must be a number (hours), got ${typeof timeZoneOffset}: ${timeZoneOffset}`,
            );
        }

        // Validate and parse birth date
        const dateParts = birthDate.split("-");
        if (dateParts.length !== 3) {
            throw new HttpsError(
                "invalid-argument",
                "birthDate must be in YYYY-MM-DD format",
            );
        }
        const year = parseInt(dateParts[0], 10);
        const month = parseInt(dateParts[1], 10);
        const day = parseInt(dateParts[2], 10);

        if (isNaN(year) || isNaN(month) || isNaN(day) ||
            year < 1900 || year > new Date().getFullYear() ||
            month < 1 || month > 12 || day < 1 || day > 31) {
            throw new HttpsError(
                "invalid-argument",
                "Invalid birth date values",
            );
        }

        // Validate and parse birth time
        const timeParts = birthTime.split(":");
        if (timeParts.length < 2) {
            throw new HttpsError(
                "invalid-argument",
                "birthTime must be in HH:MM or HH:MM:SS format",
            );
        }
        const hours = parseInt(timeParts[0], 10);
        const minutes = parseInt(timeParts[1], 10) || 0;
        const seconds = parseInt(timeParts[2], 10) || 0;

        if (isNaN(hours) || isNaN(minutes) || isNaN(seconds) ||
            hours < 0 || hours > 23 || minutes < 0 || minutes > 59 || seconds < 0 || seconds > 59) {
            throw new HttpsError(
                "invalid-argument",
                "Invalid birth time values",
            );
        }

        const payload = {
            year,
            month,
            date: day,
            hours,
            minutes,
            seconds,
            latitude,
            longitude,
            timezone: timeZoneOffset,
        };

        const result = await runAstroFlow({
            mode,
            payload,
            timeZoneId,
            timeZoneOffset,
        });

        return result;
    } catch (error) {
        logger.error("freeAstroCalculate error", {
            structuredData: true,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

// Constants for compatibility calculation
const COMPATIBILITY_CACHE_TTL_DAYS = 30;
// Cache version - bump this when changing scoring algorithm to invalidate old cached scores
// v1 = initial
// v2 = 2026-01-06 scoring algorithm update (fixed low scores issue)
// v3 = 2026-01-06 comprehensive 8-pillar system (added sun sign, ascendant, element balance, etc.)
const COMPATIBILITY_CACHE_VERSION = "v3";
const MAX_ASHTAKOOT_SCORE = 36;

// Helper function to extract birth data for compatibility calculation
const extractBirthDataForCompatibility = (astroData) => {
    if (!astroData) return null;

    // Extract date parts
    let year; let month; let day;
    if (astroData.birthYear && astroData.birthMonth && astroData.birthDay) {
        year = astroData.birthYear;
        month = astroData.birthMonth;
        day = astroData.birthDay;
    } else if (astroData.birthDate) {
        const birthDate = astroData.birthDate?.toDate?.() || new Date(astroData.birthDate);
        if (isNaN(birthDate.getTime())) return null;
        year = birthDate.getFullYear();
        month = birthDate.getMonth() + 1;
        day = birthDate.getDate();
    } else {
        return null;
    }

    // Extract time parts
    const birthTime = astroData.birthTime;
    if (!birthTime || typeof birthTime !== "string") return null;
    const timeParts = birthTime.split(":").map((p) => parseInt(p, 10) || 0);
    const hours = timeParts[0] || 0;
    const minutes = timeParts[1] || 0;
    const seconds = timeParts[2] || 0;

    // Extract location
    const latitude = astroData.birthLatitude;
    const longitude = astroData.birthLongitude;

    // Handle timezone - use timeZoneOffset (number in hours) if available
    // Then try parsing timeZone as number, then try as IANA timezone name using Luxon
    let timeZone = null;
    if (astroData.timeZoneOffset != null) {
        // timeZoneOffset is already a number (hours offset)
        timeZone = typeof astroData.timeZoneOffset === "number" ? astroData.timeZoneOffset : parseFloat(astroData.timeZoneOffset);
        if (isNaN(timeZone)) {
            timeZone = null;
        }
    }

    if (timeZone == null && astroData.timeZone != null && astroData.timeZone !== "") {
        // First try parsing as a number (e.g., "5.5" for IST)
        const parsedTz = parseFloat(astroData.timeZone);
        if (!isNaN(parsedTz)) {
            timeZone = parsedTz;
        } else {
            // Try to parse as IANA timezone name (e.g., "Asia/Kolkata") using Luxon
            try {
                // Create a DateTime at a known date/time in the specified timezone
                // Use the user's birth date to get the correct offset (handles DST)
                const birthDateTime = DateTime.fromObject(
                    { year, month, day, hour: hours, minute: minutes },
                    { zone: astroData.timeZone }
                );
                if (birthDateTime.isValid && birthDateTime.offset != null) {
                    // Luxon offset is in minutes, convert to hours
                    timeZone = birthDateTime.offset / 60;
                }
            } catch (e) {
                // Invalid timezone name, timeZone stays null
                logger.warn("Failed to parse IANA timezone", {
                    timezone: astroData.timeZone,
                    error: e.message,
                });
            }
        }
    }

    if (latitude == null || longitude == null || timeZone == null) {
        return null;
    }

    return {
        year: parseInt(year, 10),
        month: parseInt(month, 10),
        date: parseInt(day, 10),
        hours: parseInt(hours, 10),
        minutes: parseInt(minutes, 10),
        seconds: parseInt(seconds, 10),
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        timezone: timeZone, // Already a number, no need to parseFloat again
    };
};

// Validate astrology data for compatibility calculation
// Note: Both users must have astrology enabled. The 'visibility' field controls
// whether others can calculate compatibility (public = allowed, private = not allowed)
const validateAstrologyDataForCompatibility = (astroData, userId, isCurrentUser = false) => {
    if (!astroData) {
        logger.warn("Compatibility validation failed: no astrology profile", {
            userId,
            isCurrentUser,
        });
        throw new HttpsError(
            "failed-precondition",
            "User must have astrology profile set up",
        );
    }

    if (!astroData.isEnabled) {
        logger.warn("Compatibility validation failed: astrology not enabled", {
            userId,
            isCurrentUser,
            isEnabled: astroData.isEnabled,
        });
        throw new HttpsError(
            "failed-precondition",
            "User must have astrology enabled",
        );
    }

    // Check visibility for the other user (not the current user making the request)
    // 'private' visibility means the user doesn't want others to calculate compatibility
    if (!isCurrentUser && astroData.visibility === "private") {
        logger.info("Compatibility validation: user profile is private", {
            userId,
            visibility: astroData.visibility,
        });
        throw new HttpsError(
            "failed-precondition",
            "User has set their astrology profile to private",
        );
    }

    const birthData = extractBirthDataForCompatibility(astroData);
    if (!birthData) {
        // Log detailed info about what's missing
        logger.warn("Compatibility validation failed: incomplete birth data", {
            userId,
            isCurrentUser,
            hasBirthYear: !!astroData.birthYear,
            hasBirthMonth: !!astroData.birthMonth,
            hasBirthDay: !!astroData.birthDay,
            hasBirthDate: !!astroData.birthDate,
            hasBirthTime: !!astroData.birthTime,
            birthTime: astroData.birthTime,
            hasBirthLatitude: astroData.birthLatitude != null,
            hasBirthLongitude: astroData.birthLongitude != null,
            hasTimeZone: astroData.timeZone != null,
            hasTimeZoneOffset: astroData.timeZoneOffset != null,
            timeZone: astroData.timeZone,
            timeZoneOffset: astroData.timeZoneOffset,
        });
        throw new HttpsError(
            "failed-precondition",
            "User must have complete birth data (date, time, location)",
        );
    }

    return birthData;
};

// Invalidate compatibility cache for a user
export const invalidateCompatibilityCache = async (userId) => {
    try {
        // Find all compatibility scores involving this user
        const cacheRef = db.collection("compatibilityScores");
        const [scoresWithUser1, scoresWithUser2] = await Promise.all([
            cacheRef.where("user1Id", "==", userId).get(),
            cacheRef.where("user2Id", "==", userId).get(),
        ]);

        const batch = db.batch();
        let deleteCount = 0;

        scoresWithUser1.forEach((doc) => {
            batch.delete(doc.ref);
            deleteCount++;
        });

        scoresWithUser2.forEach((doc) => {
            batch.delete(doc.ref);
            deleteCount++;
        });

        if (deleteCount > 0) {
            await batch.commit();
        }
    } catch (error) {
        logger.error("Error invalidating compatibility cache", {
            structuredData: true,
            userId,
            error: error.message,
        });
        // Don't throw - cache invalidation failure shouldn't break the main flow
    }
};

/** @see ../lib/utils.js — consolidated blocking utility */
const checkBlockedStatus = async (userId1, userId2) => {
    const result = await checkBlockedDetailed(db, userId1, userId2);
    // Map to legacy field names used by callers in this file
    return {
        isBlocked: result.isBlocked,
        blockerIsCurrentUser: result.blockerIsUser1,
        blockerIsOtherUser: result.blockerIsUser2,
    };
};

// Helper function to check mutual follow status
const checkMutualFollow = async (userId1, userId2) => {
    try {
        // Check both directions in parallel
        const [user1FollowsUser2, user2FollowsUser1] = await Promise.all([
            // Does user1 follow user2 with confirmed status?
            db.collection("userFollowing")
                .doc(userId1)
                .collection("following")
                .doc(userId2)
                .get(),
            // Does user2 follow user1?
            db.collection("userFollowers")
                .doc(userId1)
                .collection("followers")
                .doc(userId2)
                .get(),
        ]);

        // Both must exist for mutual follow
        if (!user1FollowsUser2.exists || !user2FollowsUser1.exists) {
            return false;
        }

        // User1's follow must be confirmed (status = 'following')
        const status = user1FollowsUser2.data()?.status || "following";
        return status === "following";
    } catch (error) {
        logger.warn("Error checking mutual follow", {
            userId1,
            userId2,
            error: error.message,
        });
        return false;
    }
};

export const calculateCompatibility = onCall({
    secrets: [freeAstrologyApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
    // AppCheck: DISABLED until Flutter client enables FirebaseAppCheck
    // TODO: Set enforceAppCheck: true after enabling AppCheck in lib/main.dart
}, async (request) => {
    try {
        const currentUserId = requireAuth(request, "calculate compatibility");

        const { otherUserId } = request.data || {};

        if (!otherUserId || typeof otherUserId !== "string") {
            throw new HttpsError(
                "invalid-argument",
                "otherUserId is required and must be a string",
            );
        }

        if (currentUserId === otherUserId) {
            throw new HttpsError(
                "invalid-argument",
                "Cannot calculate compatibility with yourself",
            );
        }

        // Check mutual follow requirement (friends only can see compatibility)
        const isMutualFollow = await checkMutualFollow(currentUserId, otherUserId);
        if (!isMutualFollow) {
            throw new HttpsError(
                "permission-denied",
                "Compatibility requires mutual follow. Follow each other to unlock!",
            );
        }

        // Check if either user has blocked the other
        const blockStatus = await checkBlockedStatus(currentUserId, otherUserId);
        if (blockStatus.isBlocked) {
            if (blockStatus.blockerIsOtherUser) {
                // Other user blocked current user - don't reveal this explicitly
                throw new HttpsError(
                    "permission-denied",
                    "Compatibility is not available for this user.",
                );
            } else {
                // Current user blocked the other user
                throw new HttpsError(
                    "failed-precondition",
                    "You have blocked this user. Unblock to see compatibility.",
                );
            }
        }

        // Sort user IDs for consistent cache key
        const [user1Id, user2Id] = [currentUserId, otherUserId].sort();
        const cacheKey = `${user1Id}_${user2Id}`;

        // Check cache first
        const cacheRef = db.collection("compatibilityScores").doc(cacheKey);
        const cachedDoc = await cacheRef.get();

        if (cachedDoc.exists) {
            const cachedData = cachedDoc.data();
            const calculatedAt = cachedData.calculatedAt?.toDate?.() || new Date(cachedData.calculatedAt);
            const daysSinceCalculation = (Date.now() - calculatedAt.getTime()) / (1000 * 60 * 60 * 24);
            const cacheVersion = cachedData.cacheVersion;

            // Check both TTL and cache version - invalidate if version mismatch
            if (daysSinceCalculation < COMPATIBILITY_CACHE_TTL_DAYS && cacheVersion === COMPATIBILITY_CACHE_VERSION) {
                return {
                    success: true,
                    // Primary: Cosmic Match
                    cosmicMatch: cachedData.cosmicMatch,
                    // Life Phase Sync (Dasha comparison)
                    lifePhaseSync: cachedData.lifePhaseSync || null,
                    // Secondary: Traditional Ashtakoot
                    traditionalMatch: {
                        totalScore: cachedData.totalScore,
                        outOf: cachedData.outOf,
                        percentage: cachedData.percentage,
                        details: cachedData.details,
                        matchType: cachedData.matchType || "mutual",
                    },
                    // Legacy fields for backward compatibility
                    totalScore: cachedData.totalScore,
                    outOf: cachedData.outOf,
                    percentage: cachedData.percentage,
                    details: cachedData.details,
                    cached: true,
                };
            }
            // Cache miss due to version mismatch or TTL expiry - will recalculate below
        }

        // Fetch both users' astrology data
        const [currentUserDoc, otherUserDoc] = await Promise.all([
            db.collection("users").doc(currentUserId).get(),
            db.collection("users").doc(otherUserId).get(),
        ]);

        if (!currentUserDoc.exists || !otherUserDoc.exists) {
            throw new HttpsError(
                "not-found",
                "One or both users not found",
            );
        }

        const currentUserData = currentUserDoc.data() || {};
        const otherUserData = otherUserDoc.data() || {};
        const currentAstroData = currentUserData.astrologyData;
        const otherAstroData = otherUserData.astrologyData;

        // Validate astrology data (throws HttpsError if invalid)
        // Current user is always allowed (isCurrentUser = true), other user respects visibility setting
        const user1BirthData = validateAstrologyDataForCompatibility(currentAstroData, currentUserId, true);
        const user2BirthData = validateAstrologyDataForCompatibility(otherAstroData, otherUserId, false);

        // Extract gender and astro info for cosmic match calculation
        const user1Gender = currentAstroData.gender;
        const user2Gender = otherAstroData.gender;

        // Get moon signs and nakshatras for cosmic match
        const user1MoonSign = normalizeSign(currentAstroData.moonSign);
        const user2MoonSign = normalizeSign(otherAstroData.moonSign);
        const user1Nakshatra = normalizeNakshatra(currentAstroData.nakshatra || currentAstroData.moonNakshatra);
        const user2Nakshatra = normalizeNakshatra(otherAstroData.nakshatra || otherAstroData.moonNakshatra);

        // Get sun signs and ascendants for comprehensive cosmic match
        const user1SunSign = normalizeSign(currentAstroData.sunSign);
        const user2SunSign = normalizeSign(otherAstroData.sunSign);
        const user1Ascendant = normalizeSign(currentAstroData.ascendant || currentAstroData.lagna);
        const user2Ascendant = normalizeSign(otherAstroData.ascendant || otherAstroData.lagna);

        // Get current Dasha data for life phase sync
        const user1Dasha = currentAstroData.currentDasha;
        const user2Dasha = otherAstroData.currentDasha;

        // =====================================================================
        // COSMIC MATCH (Universal, Gender-Neutral, Comprehensive 8-Pillar System)
        // =====================================================================
        let cosmicMatch = null;
        if (user1MoonSign && user2MoonSign && user1Nakshatra && user2Nakshatra) {
            cosmicMatch = calculateCosmicMatch(
                {
                    moonSign: user1MoonSign,
                    nakshatra: user1Nakshatra,
                    sunSign: user1SunSign,
                    ascendant: user1Ascendant,
                },
                {
                    moonSign: user2MoonSign,
                    nakshatra: user2Nakshatra,
                    sunSign: user2SunSign,
                    ascendant: user2Ascendant,
                }
            );
        }

        // =====================================================================
        // LIFE PHASE SYNC (Dasha Comparison)
        // =====================================================================
        const lifePhaseSync = calculateLifePhaseSync(user1Dasha, user2Dasha);

        // =====================================================================
        // TRADITIONAL ASHTAKOOT MATCH
        // =====================================================================

        // Determine if we should use gender-specific or averaged calculation
        // Traditional: Male-Female pairing (single direction)
        // Mutual: Same-sex, Non-binary, or unknown (average both directions)
        // 
        // This follows Vedic tradition which recognizes tritiya-prakriti (third nature)
        // For non-binary individuals, we use mutual averaging like same-sex pairings
        let matchType = "mutual"; // Default: average both directions
        let ashtakootPayloads = [];

        // Helper to check if gender is binary (Male or Female)
        const isBinaryGender = (gender) => gender === "Male" || gender === "Female";

        // Traditional calculation only for Male-Female pairs where both are binary
        const isTraditionalPairing = user1Gender && user2Gender
            && isBinaryGender(user1Gender) && isBinaryGender(user2Gender)
            && user1Gender !== user2Gender;

        if (isTraditionalPairing) {
            // Traditional M-F pairing - use correct roles
            matchType = "traditional";
            const maleData = user1Gender === "Male" ? user1BirthData : user2BirthData;
            const femaleData = user1Gender === "Female" ? user1BirthData : user2BirthData;

            ashtakootPayloads = [{
                male: maleData,
                female: femaleData,
                config: {
                    observation_point: "geocentric",
                    language: "en",
                    ayanamsha: "lahiri",
                },
            }];
        } else {
            // Non-traditional pairing: calculate both ways and average
            // This includes: same-sex, non-binary involved, or unknown genders
            if (user1Gender === "Non-binary" || user2Gender === "Non-binary") {
                matchType = "non_binary";
            } else if (user1Gender && user2Gender && user1Gender === user2Gender) {
                matchType = "same_gender";
            } else {
                matchType = "mutual";
            }

            ashtakootPayloads = [
                {
                    male: user1BirthData,
                    female: user2BirthData,
                    config: {
                        observation_point: "geocentric",
                        language: "en",
                        ayanamsha: "lahiri",
                    },
                },
                {
                    male: user2BirthData,
                    female: user1BirthData,
                    config: {
                        observation_point: "geocentric",
                        language: "en",
                        ayanamsha: "lahiri",
                    },
                },
            ];
        }

        // Call API with retry logic for transient failures
        const callWithRetry = async (payload, retries = 2) => {
            for (let i = 0; i <= retries; i++) {
                try {
                    const response = await callFreeAstro(ASHTAKOOT_SCORE_ENDPOINT, payload);
                    if (response?.output) {
                        return response;
                    }
                    throw new Error("Invalid API response: missing output");
                } catch (error) {
                    // Don't retry on rate limits (429) - fail fast
                    const statusCode = error.statusCode || (error.code === "internal" ? 500 : null);
                    if (statusCode === 429) {
                        throw error; // Don't retry rate limits
                    }
                    // Don't retry on other client errors (4xx), only server errors (5xx) and network issues
                    if (statusCode && statusCode >= 400 && statusCode < 500) {
                        throw error; // Don't retry client errors
                    }

                    if (i === retries) {
                        throw error;
                    }
                    // Wait before retry (exponential backoff)
                    const delayMs = 1000 * Math.pow(2, i);
                    await new Promise((resolve) => setTimeout(resolve, delayMs));
                }
            }
        };

        // =====================================================================
        // ASHTAKOOT API CALL - Graceful degradation on failure
        // =====================================================================
        let traditionalMatch = null;
        let averagedScore = null;
        let primaryOutput = null;
        let ashtakootError = null;

        try {
            // Execute API calls
            const responses = await Promise.all(
                ashtakootPayloads.map(payload => callWithRetry(payload))
            );

            // Validate API responses
            if (responses.some(r => !r?.output)) {
                throw new Error("Invalid response from astrology API");
            }

            // Calculate final Ashtakoot score
            const outOf = responses[0].output.out_of || MAX_ASHTAKOOT_SCORE;

            if (responses.length === 1) {
                // Traditional (single direction)
                averagedScore = responses[0].output.total_score || 0;
                primaryOutput = responses[0].output;
            } else {
                // Averaged (both directions)
                const score1 = responses[0].output.total_score || 0;
                const score2 = responses[1].output.total_score || 0;
                averagedScore = (score1 + score2) / 2;
                primaryOutput = responses[0].output;
            }

            const percentage = (averagedScore / outOf) * 100;

            // Build traditional match result
            traditionalMatch = {
                totalScore: averagedScore,
                outOf: outOf,
                percentage: percentage,
                details: primaryOutput,
                matchType: matchType,
            };
        } catch (error) {
            // Log the Ashtakoot API failure
            const statusCode = error.statusCode || (error.message?.includes("429") ? 429 : null);
            const isRateLimited = statusCode === 429 || error.message?.includes("Too Many Requests") || error.message?.includes("Limit Exceeded");

            ashtakootError = isRateLimited ? "rate_limited" : "api_error";

            logger.warn("Ashtakoot API failed, returning Cosmic Match only", {
                structuredData: true,
                error: error.message,
                statusCode: statusCode,
                isRateLimited: isRateLimited,
                hasCosmic: !!cosmicMatch,
            });

            // Continue without Ashtakoot - we'll return partial results
        }

        // =====================================================================
        // RETURN RESULTS - Full or Partial depending on API success
        // =====================================================================

        // If we have full results (both Cosmic and Ashtakoot), cache them
        if (traditionalMatch && cosmicMatch) {
            const cacheData = {
                cacheVersion: COMPATIBILITY_CACHE_VERSION,
                cosmicMatch: cosmicMatch,
                lifePhaseSync: lifePhaseSync,
                totalScore: averagedScore,
                outOf: traditionalMatch.outOf,
                percentage: traditionalMatch.percentage,
                details: primaryOutput,
                matchType: matchType,
                calculatedAt: FieldValue.serverTimestamp(),
                user1Id: user1Id,
                user2Id: user2Id,
            };

            await cacheRef.set(cacheData);

            return {
                success: true,
                // Primary: Cosmic Match (universal)
                cosmicMatch: cosmicMatch,
                // Life Phase Sync (Dasha comparison)
                lifePhaseSync: lifePhaseSync,
                // Secondary: Traditional Ashtakoot
                traditionalMatch: traditionalMatch,
                // Legacy fields for backward compatibility
                totalScore: averagedScore,
                outOf: traditionalMatch.outOf,
                percentage: traditionalMatch.percentage,
                details: primaryOutput,
                cached: false,
            };
        }

        // Partial results - Cosmic Match available but Ashtakoot failed
        // Don't cache partial results so we can retry Ashtakoot next time
        if (cosmicMatch) {
            logger.info("Returning partial compatibility (Cosmic Match only)", {
                structuredData: true,
                cosmicScore: cosmicMatch.score,
                ashtakootError: ashtakootError,
            });

            return {
                success: true,
                partial: true, // Flag indicating partial results
                partialReason: ashtakootError === "rate_limited"
                    ? "Traditional matching temporarily unavailable due to high demand. Try again later."
                    : "Traditional matching temporarily unavailable.",
                // Primary: Cosmic Match (universal) - still available!
                cosmicMatch: cosmicMatch,
                // Life Phase Sync (Dasha comparison) - still available!
                lifePhaseSync: lifePhaseSync,
                // Secondary: Traditional Ashtakoot - unavailable
                traditionalMatch: null,
                // Legacy fields - null to indicate unavailable
                totalScore: null,
                outOf: null,
                percentage: null,
                details: null,
                cached: false,
            };
        }

        // If we have neither Cosmic nor Ashtakoot, throw error
        throw new HttpsError(
            "internal",
            "Unable to calculate compatibility. Please try again later.",
        );
    } catch (error) {
        logger.error("calculateCompatibility error", {
            structuredData: true,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });

        // Don't expose internal errors to client
        if (error instanceof HttpsError) {
            throw error;
        }

        throw new HttpsError(
            "internal",
            "Failed to calculate compatibility. Please try again later.",
        );
    }
});

// ============================================================================
// GEO SEARCH - Search locations using Free Astrology API
// Returns proper city data with coordinates and timezone
// ============================================================================
const GEO_DETAILS_ENDPOINT = "/geo-details";

export const searchGeoLocation = onCall({
    secrets: [freeAstrologyApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (no auth required for location search)
}, async (request) => {
    try {
        const { query } = request.data || {};

        if (!query || typeof query !== "string" || query.trim().length < 2) {
            return { success: true, results: [] };
        }

        const searchQuery = query.trim();

        // Call the Free Astrology API geo-details endpoint
        const response = await callFreeAstro(GEO_DETAILS_ENDPOINT, {
            location: searchQuery,
        });

        // The API returns an array of results
        if (!response || !Array.isArray(response)) {
            logger.warn("Unexpected geo response format", {
                structuredData: true,
                query: searchQuery,
                responseType: typeof response,
            });
            return { success: true, results: [] };
        }

        // Transform results to a cleaner format
        const results = response.map((item) => ({
            name: item.location_name || searchQuery,
            fullName: item.complete_name || item.location_name || searchQuery,
            country: item.country || "",
            region: item.administrative_zone_1 || "",
            subRegion: item.administrative_zone_2 || "",
            latitude: item.latitude,
            longitude: item.longitude,
            timezone: item.timezone || null,
            timezoneOffset: item.timezone_offset || null,
        })).filter((item) =>
            // Filter out invalid results
            item.latitude != null &&
            item.longitude != null &&
            !isNaN(item.latitude) &&
            !isNaN(item.longitude)
        );

        logger.info("Geo search completed", {
            structuredData: true,
            query: searchQuery,
            resultsCount: results.length,
        });

        return {
            success: true,
            results: results,
        };
    } catch (error) {
        logger.error("searchGeoLocation error", {
            structuredData: true,
            error: error.message,
            query: request.data?.query,
        });

        // Return empty results instead of throwing for better UX
        return {
            success: false,
            results: [],
            error: "Location search failed. Please try again.",
        };
    }
});
