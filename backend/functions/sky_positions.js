/**
 * Global Sky Positions - SMART Incremental Architecture
 * 
 * KEY PRINCIPLES:
 * 1. Planetary positions are GLOBAL (same for everyone)
 * 2. Only fetch NEW days (incremental updates)
 * 3. Keep ALL historical data (no deletion)
 * 4. Calculate and store upcoming events (sign ingresses, retrogrades)
 * 5. Insight generation just READS pre-calculated data
 * 
 * Data stored in Firestore:
 * - global_astro/sky_positions: { positions: { "2026-01-16": {...}, ... }, lastFetchedDate, ... }
 * - global_astro/upcoming_events: { signIngresses: [...], retrogrades: [...], ... }
 */

import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { DateTime } from "luxon";
import { db, FieldValue } from "../lib/firebase.js";
import { freeAstrologyApiKey } from "../lib/secrets.js";

const API_BASE = "https://json.freeastrologyapi.com";
const PLANETS_ENDPOINT = "/planets";
const SAMVAT_ENDPOINT = "/samvatinfo";
const LUNAR_MONTH_ENDPOINT = "/lunarmonthinfo";
const TITHI_ENDPOINT = "/tithi-durations";
const MUHURAT_ENDPOINT = "/good-bad-times";

// Ujjain - the Hindu Prime Meridian (traditional reference point)
const DEFAULT_LAT = 23.1765;
const DEFAULT_LNG = 75.7885;
const DEFAULT_TZ = 5.5;
const DEFAULT_TZ_ID = "Asia/Kolkata";

// How far ahead to maintain positions (60 days)
const DAYS_AHEAD_TARGET = 60;
const MUHURAT_DAYS_AHEAD = 3;
const MUHURAT_CACHE_HOURS = 6;

// Important planets for tracking (9 Vedic grahas + 3 outer planets)
const TRACKED_PLANETS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu", "Uranus", "Neptune", "Pluto"];

// ============================================================================
// API HELPERS
// ============================================================================

const tryParseJson = (input) => {
    if (typeof input !== "string") return null;
    try {
        return JSON.parse(input);
    } catch {
        return null;
    }
};

const unwrapOutputPayload = (input, { maxDepth = 3 } = {}) => {
    let current = input;
    for (let depth = 0; depth < maxDepth; depth += 1) {
        if (current == null) break;
        if (typeof current === "string") {
            const parsed = tryParseJson(current);
            if (parsed == null) break;
            current = parsed;
            continue;
        }
        if (typeof current === "object") {
            return current;
        }
        break;
    }
    return (typeof current === "object" && current !== null) ? current : null;
};

const extractApiOutput = (response) => {
    if (!response) return null;
    if (typeof response === "object" && !Array.isArray(response)) {
        if (Object.prototype.hasOwnProperty.call(response, "output")) {
            const parsed = unwrapOutputPayload(response.output);
            if (parsed && typeof parsed === "object") {
                return parsed;
            }
        }
        return response;
    }
    if (typeof response === "string") {
        return unwrapOutputPayload(response);
    }
    return null;
};

const isEmptyPanchang = (value) => {
    if (!value || typeof value !== "object") return true;
    return Object.keys(value).length === 0;
};

// Parse FreeAstrologyAPI time string format: "{starts_at: 2023-03-20 07:52:14, ends_at: 2023-03-20 09:22:52}"
const parseTimeString = (timeStr) => {
    if (!timeStr || typeof timeStr !== "string") return null;

    try {
        // Try JSON parse first
        const jsonParsed = tryParseJson(timeStr);
        if (jsonParsed) return jsonParsed;

        const cleaned = timeStr.trim().replace(/^\{|\}$/g, "");
        const parts = cleaned.split(/,/);
        const result = {};

        for (const part of parts) {
            const colonIndex = part.indexOf(":");
            if (colonIndex === -1) continue;

            const key = part.substring(0, colonIndex).trim();
            const value = part.substring(colonIndex + 1).trim();
            const cleanValue = value.replace(/^["']|["']$/g, "");
            result[key] = cleanValue;
        }

        return Object.keys(result).length > 0 ? result : null;
    } catch (error) {
        logger.warn("⚠️ Failed to parse time string:", error.message);
        return null;
    }
};

/**
 * Fetch planetary positions from FreeAstrologyAPI for a specific date
 */
async function fetchPlanetaryPositionsForDate(date) {
    const apiKey = freeAstrologyApiKey.value();
    if (!apiKey) {
        throw new Error("FreeAstrologyAPI key not configured");
    }

    const payload = {
        year: date.year,
        month: date.month,
        date: date.day,
        hours: 12, // noon
        minutes: 0,
        seconds: 0,
        latitude: DEFAULT_LAT,
        longitude: DEFAULT_LNG,
        timezone: DEFAULT_TZ,
        config: {
            observation_point: "geocentric",
            ayanamsha: "lahiri",
        },
    };

    const response = await fetch(`${API_BASE}${PLANETS_ENDPOINT}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
        },
        body: JSON.stringify(payload),
    });

    if (!response.ok) {
        const error = await response.text();
        throw new Error(`API error (${response.status}): ${error}`);
    }

    return response.json();
}

/**
 * Extract relevant planet data from API response
 */
function extractPlanetData(apiResponse) {
    const output = apiResponse.output;
    if (!output) return null;

    const planets = {};
    const planetsObj = Array.isArray(output) ? output[0] : output;

    Object.entries(planetsObj).forEach(([key, data]) => {
        if (!data || typeof data !== "object") return;

        const name = data.name || key;
        const planetName = TRACKED_PLANETS.find((p) => name.includes(p) || key.includes(p));
        if (!planetName) return;

        planets[planetName] = {
            longitude: data.fullDegree || data.longitude || data.full_degree,
            sign: data.sign || data.Sign,
            signDegree: data.normDegree || data.degree || (data.fullDegree ? data.fullDegree % 30 : null),
            isRetro: data.isRetro === true || data.is_retro === true,
            nakshatra: data.nakshatra || data.Nakshatra,
        };
    });

    return planets;
}

/**
 * Fetch panchang data for a date
 */
async function fetchPanchangForDate(date) {
    const apiKey = freeAstrologyApiKey.value();
    if (!apiKey) return null;

    const payload = {
        year: date.year,
        month: date.month,
        date: date.day,
        hours: 12,
        minutes: 0,
        seconds: 0,
        latitude: DEFAULT_LAT,
        longitude: DEFAULT_LNG,
        timezone: DEFAULT_TZ,
        config: {
            observation_point: "geocentric",
            ayanamsha: "lahiri",
        },
    };

    const headers = {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
    };

    try {
        const [samvatRes, lunarRes, tithiRes] = await Promise.all([
            fetch(`${API_BASE}${SAMVAT_ENDPOINT}`, { method: "POST", headers, body: JSON.stringify(payload) })
                .then(r => r.ok ? r.json() : null).catch(() => null),
            fetch(`${API_BASE}${LUNAR_MONTH_ENDPOINT}`, { method: "POST", headers, body: JSON.stringify(payload) })
                .then(r => r.ok ? r.json() : null).catch(() => null),
            fetch(`${API_BASE}${TITHI_ENDPOINT}`, { method: "POST", headers, body: JSON.stringify(payload) })
                .then(r => r.ok ? r.json() : null).catch(() => null),
        ]);

        // Debug: Log raw API responses
        logger.info("📅 Panchang API responses", {
            date: `${date.year}-${date.month}-${date.day}`,
            samvatResKeys: samvatRes ? Object.keys(samvatRes) : null,
            lunarResKeys: lunarRes ? Object.keys(lunarRes) : null,
            tithiResKeys: tithiRes ? Object.keys(tithiRes) : null,
            samvatHasOutput: samvatRes?.output !== undefined,
            lunarHasOutput: lunarRes?.output !== undefined,
            tithiHasOutput: tithiRes?.output !== undefined,
        });

        const samvat = extractApiOutput(samvatRes) || {};
        const lunar = extractApiOutput(lunarRes) || {};
        const tithiRaw = extractApiOutput(tithiRes) || {};

        // Debug: Log extracted data
        logger.info("📅 Panchang extracted data", {
            samvatKeys: Object.keys(samvat),
            lunarKeys: Object.keys(lunar),
            tithiRawKeys: Object.keys(tithiRaw),
            samvatVikram: samvat.vikram_chaitradi_number,
            lunarMonth: lunar.lunar_month_full_name || lunar.lunarMonthFullName,
            tithiName: tithiRaw.name || tithiRaw.tithi_name || (tithiRaw.tithi?.name),
        });

        // Handle nested tithi object
        const tithi = (tithiRaw.tithi && typeof tithiRaw.tithi === "object") ? tithiRaw.tithi : tithiRaw;

        const tithiNum = tithi.number || tithi.tithi_number;
        const panchang = {
            // Vikram Samvat - try multiple key variations
            vikram_chaitradi_number: samvat.vikram_chaitradi_number || samvat.vikramChaitradiNumber,
            vikram_chaitradi_year_name: samvat.vikram_chaitradi_year_name || samvat.vikramChaitradiYearName,
            saka_salivahana_number: samvat.saka_salivahana_number || samvat.sakaSalivahanaNumber,
            // Lunar month - try multiple key variations
            lunar_month_name: lunar.lunar_month_name || lunar.lunarMonthName,
            lunar_month_full_name: lunar.lunar_month_full_name || lunar.lunarMonthFullName,
            // Tithi
            name: tithi.name || tithi.tithi_name || tithi.tithiName,
            number: tithiNum,
            tithi_number: tithiNum, // For frontend compatibility
            paksha: tithi.paksha || tithi.tithi_paksha || tithi.tithiPaksha,
            // Other panchang elements
            karana: samvat.karana || samvat.Karana,
            yoga: samvat.yoga || samvat.Yoga,
            nakshatra: samvat.nakshatra || samvat.Nakshatra,
        };

        // Remove undefined/null/empty values
        Object.keys(panchang).forEach(key => {
            if (panchang[key] === undefined || panchang[key] === null || panchang[key] === "") {
                delete panchang[key];
            }
        });

        logger.info("📅 Panchang final result", {
            date: `${date.year}-${date.month}-${date.day}`,
            keys: Object.keys(panchang),
            isEmpty: Object.keys(panchang).length === 0,
            vikramYear: panchang.vikram_chaitradi_number,
            tithiName: panchang.name,
        });

        return Object.keys(panchang).length > 0 ? panchang : null;
    } catch (error) {
        logger.warn("Failed to fetch panchang", { error: String(error) });
        return null;
    }
}

async function fetchMuhuratForDate(date) {
    const apiKey = freeAstrologyApiKey.value();
    if (!apiKey) {
        throw new Error("FreeAstrologyAPI key not configured");
    }

    const payload = {
        year: date.year,
        month: date.month,
        date: date.day,
        hours: 12,
        minutes: 0,
        seconds: 0,
        latitude: DEFAULT_LAT,
        longitude: DEFAULT_LNG,
        timezone: DEFAULT_TZ,
        config: {
            observation_point: "geocentric",
            ayanamsha: "lahiri",
        },
    };

    const response = await fetch(`${API_BASE}${MUHURAT_ENDPOINT}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
        },
        body: JSON.stringify(payload),
    });

    if (!response.ok) {
        const error = await response.text();
        throw new Error(`API error (${response.status}): ${error}`);
    }

    return response.json();
}

const parseMuhuratDay = (parsedMuhurat) => {
    const dayData = {};

    if (parsedMuhurat.rahu_kaalam_data) {
        dayData.rahuKala = parseTimeString(parsedMuhurat.rahu_kaalam_data);
        dayData.rahu_kala = dayData.rahuKala;
    }
    if (parsedMuhurat.gulika_kalam_data) {
        dayData.gulikaKala = parseTimeString(parsedMuhurat.gulika_kalam_data);
        dayData.gulika_kala = dayData.gulikaKala;
    }
    if (parsedMuhurat.yama_gandam_data) {
        dayData.yamaganda = parseTimeString(parsedMuhurat.yama_gandam_data);
        dayData.yamagandaKala = dayData.yamaganda;
    }
    if (parsedMuhurat.varjyam_data) {
        dayData.varjyam = parseTimeString(parsedMuhurat.varjyam_data);
    }

    if (parsedMuhurat.abhijit_data) {
        dayData.abhijit = parseTimeString(parsedMuhurat.abhijit_data);
    }
    if (parsedMuhurat.amrit_kaal_data) {
        dayData.amrit = parseTimeString(parsedMuhurat.amrit_kaal_data);
        dayData.amritKaal = dayData.amrit;
    }
    if (parsedMuhurat.brahma_muhurat_data) {
        dayData.brahmaMuhurat = parseTimeString(parsedMuhurat.brahma_muhurat_data);
    }
    if (parsedMuhurat.dur_muhurat_data) {
        const durParsed = parseTimeString(parsedMuhurat.dur_muhurat_data);
        dayData.durMuhurat = durParsed || parsedMuhurat.dur_muhurat_data;
    }

    return dayData;
};

const processUnifiedTimeline = (daysData, timeZoneId) => {
    const events = [];
    const sortedDateKeys = Object.keys(daysData).sort();

    if (sortedDateKeys.length === 0) return { events: [], startTime: 0, endTime: 0 };

    const firstDateKey = sortedDateKeys[0];
    const [refYear, refMonth, refDay] = firstDateKey.split("-").map(Number);
    const refDate = DateTime.fromObject(
        { year: refYear, month: refMonth, day: refDay },
        { zone: timeZoneId },
    );

    const timeToAbsoluteMinutes = (timeData) => {
        if (!timeData || typeof timeData !== "object") return null;

        const startsAt = timeData.starts_at || timeData.startsAt;
        const endsAt = timeData.ends_at || timeData.endsAt;
        if (!startsAt || !endsAt) return null;

        try {
            const startDt = DateTime.fromISO(startsAt.replace(" ", "T"), { zone: timeZoneId });
            const endDt = DateTime.fromISO(endsAt.replace(" ", "T"), { zone: timeZoneId });
            if (!startDt.isValid || !endDt.isValid) return null;

            const startMinutes = Math.floor(startDt.diff(refDate.startOf("day"), "minutes").minutes);
            const endMinutes = Math.floor(endDt.diff(refDate.startOf("day"), "minutes").minutes);
            return { start: startMinutes, end: endMinutes };
        } catch {
            return null;
        }
    };

    for (const dateKey of sortedDateKeys) {
        const dayData = daysData[dateKey];
        if (!dayData) continue;

        const inauspiciousTypes = [
            { key: "rahuKala", name: "Rahu Kala", fallback: "rahu_kala" },
            { key: "gulikaKala", name: "Gulika Kala", fallback: "gulika_kala" },
            { key: "yamaganda", name: "Yamaganda", fallback: "yamagandaKala" },
            { key: "varjyam", name: "Varjyam", fallback: null },
        ];

        for (const type of inauspiciousTypes) {
            const timeData = dayData[type.key] || (type.fallback ? dayData[type.fallback] : null);
            const range = timeToAbsoluteMinutes(timeData);
            if (range) {
                events.push({
                    name: type.name,
                    start: range.start,
                    end: range.end,
                    type: "inauspicious",
                    dateKey,
                });
            }
        }

        const auspiciousTypes = [
            { key: "abhijit", name: "Abhijit Muhurat" },
            { key: "amrit", name: "Amrit Kaal", fallback: "amritKaal" },
            { key: "brahmaMuhurat", name: "Brahma Muhurat" },
        ];

        for (const type of auspiciousTypes) {
            const timeData = dayData[type.key] || (type.fallback ? dayData[type.fallback] : null);
            const range = timeToAbsoluteMinutes(timeData);
            if (range) {
                events.push({
                    name: type.name,
                    start: range.start,
                    end: range.end,
                    type: "auspicious",
                    dateKey,
                });
            }
        }
    }

    const minStart = events.length ? Math.min(...events.map((e) => e.start)) : 0;
    const maxEnd = events.length ? Math.max(...events.map((e) => e.end)) : 0;

    return {
        events,
        startTime: Math.max(0, Math.floor(minStart / 60) * 60),
        endTime: Math.ceil(maxEnd / 60) * 60,
        dateKeys: sortedDateKeys,
    };
};

// ============================================================================
// UPCOMING EVENTS CALCULATION (Sign Ingresses, Retrogrades)
// ============================================================================

/**
 * Calculate sign ingresses from position data
 * Detects when planets change signs
 */
function calculateSignIngresses(positions) {
    const sortedDates = Object.keys(positions).sort();
    const ingresses = [];

    for (let i = 1; i < sortedDates.length; i++) {
        const prevDate = sortedDates[i - 1];
        const currDate = sortedDates[i];
        const prevDay = positions[prevDate];
        const currDay = positions[currDate];

        if (!prevDay || !currDay) continue;

        for (const planet of TRACKED_PLANETS) {
            const prevPlanet = prevDay[planet];
            const currPlanet = currDay[planet];

            if (!prevPlanet?.sign || !currPlanet?.sign) continue;

            if (prevPlanet.sign !== currPlanet.sign) {
                ingresses.push({
                    planet,
                    fromSign: prevPlanet.sign,
                    toSign: currPlanet.sign,
                    date: currDate,
                    type: "sign_ingress",
                });
            }
        }
    }

    return ingresses.sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Calculate retrograde events from position data
 * Detects when planets start or end retrograde motion
 */
function calculateRetrogrades(positions) {
    const sortedDates = Object.keys(positions).sort();
    const events = [];

    // Only track planets that can be retrograde (not Sun, Moon, Rahu, Ketu)
    const retroPlanets = ["Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

    for (const planet of retroPlanets) {
        let wasRetro = null;

        for (let i = 0; i < sortedDates.length; i++) {
            const dateKey = sortedDates[i];
            const dayData = positions[dateKey];

            if (!dayData?.[planet]) continue;

            const isRetro = dayData[planet].isRetro === true;

            if (wasRetro !== null && isRetro !== wasRetro) {
                events.push({
                    planet,
                    type: isRetro ? "retrograde_start" : "retrograde_end",
                    date: dateKey,
                    description: isRetro
                        ? `${planet} goes retrograde`
                        : `${planet} goes direct`,
                });
            }

            wasRetro = isRetro;
        }
    }

    return events.sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Calculate and store all upcoming events
 * Called after positions are updated
 */
async function calculateAndStoreUpcomingEvents(positions) {
    const today = DateTime.now().setZone("UTC").toFormat("yyyy-MM-dd");

    // Calculate from all positions (including historical for context)
    const signIngresses = calculateSignIngresses(positions);
    const retrogrades = calculateRetrogrades(positions);

    // Filter to only future events for the main list
    const futureIngresses = signIngresses.filter(e => e.date >= today);
    const futureRetrogrades = retrogrades.filter(e => e.date >= today);

    // Store in Firestore
    const eventsRef = db.collection("global_astro").doc("upcoming_events");
    await eventsRef.set({
        signIngresses: futureIngresses,
        retrogrades: futureRetrogrades,
        // Also store all events for historical reference
        allSignIngresses: signIngresses,
        allRetrogrades: retrogrades,
        lastCalculated: FieldValue.serverTimestamp(),
        calculatedFrom: Object.keys(positions).sort()[0],
        calculatedTo: Object.keys(positions).sort().pop(),
        stats: {
            futureIngressCount: futureIngresses.length,
            futureRetroCount: futureRetrogrades.length,
            totalIngressCount: signIngresses.length,
            totalRetroCount: retrogrades.length,
        },
    });

    logger.info("📅 Calculated and stored upcoming events", {
        futureIngresses: futureIngresses.length,
        futureRetrogrades: futureRetrogrades.length,
        sampleIngresses: futureIngresses.slice(0, 5).map(e => `${e.planet}→${e.toSign} on ${e.date}`),
        sampleRetrogrades: futureRetrogrades.slice(0, 3).map(e => `${e.planet} ${e.type} on ${e.date}`),
    });

    return { signIngresses: futureIngresses, retrogrades: futureRetrogrades };
}

// ============================================================================
// SMART INCREMENTAL PREFETCH
// ============================================================================

/**
 * Smart incremental prefetch - only fetches missing days
 * 
 * Logic:
 * 1. Read existing positions from Firestore
 * 2. Determine target date (today + 60 days)
 * 3. Find missing dates
 * 4. Fetch ONLY missing dates (usually 1 per day)
 * 5. Merge with existing data
 * 6. Recalculate upcoming events
 */
async function smartPrefetch() {
    const docRef = db.collection("global_astro").doc("sky_positions");
    const doc = await docRef.get();

    const existingData = doc.exists ? doc.data() : {};
    const existingPositions = existingData.positions || {};
    const existingPanchang = existingData.panchang || {};
    const existingDates = new Set(Object.keys(existingPositions));

    const today = DateTime.now().setZone("UTC");
    const targetDate = today.plus({ days: DAYS_AHEAD_TARGET });

    // Find all dates we should have (today to target)
    const requiredDates = [];
    let checkDate = today;
    while (checkDate <= targetDate) {
        requiredDates.push(checkDate.toFormat("yyyy-MM-dd"));
        checkDate = checkDate.plus({ days: 1 });
    }

    // Find missing dates
    const missingDates = requiredDates.filter(d => !existingDates.has(d));

    logger.info("🔍 Smart prefetch analysis", {
        existingDays: existingDates.size,
        requiredDays: requiredDates.length,
        missingDays: missingDates.length,
        targetDate: targetDate.toFormat("yyyy-MM-dd"),
    });

    if (missingDates.length === 0) {
        const todayKey = today.toFormat("yyyy-MM-dd");
        if (!isEmptyPanchang(existingPanchang[todayKey])) {
            logger.info("✅ All position data is up to date - no fetch needed");
            return {
                fetched: 0,
                existing: existingDates.size,
                message: "Already up to date",
            };
        }

        logger.info("⚠️ Positions up to date, but today's panchang missing", { todayKey });
        try {
            const todayPanchang = await fetchPanchangForDate(today);
            if (todayPanchang) {
                const newPanchang = { ...existingPanchang, [todayKey]: todayPanchang };
                const sortedDates = Object.keys(existingPositions).sort();

                await docRef.set({
                    positions: existingPositions,
                    panchang: newPanchang,
                    lastUpdated: FieldValue.serverTimestamp(),
                    lastFetchedDate: sortedDates[sortedDates.length - 1] || null,
                    dateRange: {
                        from: sortedDates[0] || null,
                        to: sortedDates[sortedDates.length - 1] || null,
                    },
                    stats: {
                        totalDays: sortedDates.length,
                        panchangDays: Object.keys(newPanchang).length,
                        lastFetchCount: 0,
                        lastFetchErrors: 0,
                    },
                });

                logger.info("✅ Today's panchang refreshed without position fetch", { todayKey });
            }
        } catch (e) {
            logger.warn("Failed to refresh today's panchang", { error: String(e) });
        }

        return {
            fetched: 0,
            existing: existingDates.size,
            message: "Positions up to date; panchang refreshed",
        };
    }

    // Fetch missing dates
    const newPositions = { ...existingPositions };
    const newPanchang = { ...existingPanchang };
    let fetchedCount = 0;
    let errorCount = 0;

    for (const dateKey of missingDates) {
        const date = DateTime.fromISO(dateKey);

        try {
            // Fetch planetary positions
            const apiResponse = await fetchPlanetaryPositionsForDate(date);
            const planets = extractPlanetData(apiResponse);

            if (planets && Object.keys(planets).length > 0) {
                newPositions[dateKey] = planets;
                fetchedCount++;
            }

            // Fetch panchang for next 14 days (ensures we always have buffer)
            const daysFromToday = date.diff(today, "days").days;
            if (daysFromToday >= 0 && daysFromToday <= 14) {
                const panchang = await fetchPanchangForDate(date);
                if (panchang) {
                    newPanchang[dateKey] = panchang;
                }
            }

            // Rate limiting - 150ms between calls
            await new Promise(resolve => setTimeout(resolve, 150));
        } catch (error) {
            logger.warn(`Failed to fetch ${dateKey}:`, { error: String(error) });
            errorCount++;
        }
    }

    // CRITICAL: Ensure today's panchang always exists
    const todayKey = today.toFormat("yyyy-MM-dd");
    if (isEmptyPanchang(newPanchang[todayKey])) {
        logger.info("⚠️ Today's panchang missing, fetching explicitly");
        try {
            const todayPanchang = await fetchPanchangForDate(today);
            if (todayPanchang) {
                newPanchang[todayKey] = todayPanchang;
                logger.info("✅ Today's panchang fetched", { todayKey });
            }
        } catch (e) {
            logger.warn("Failed to fetch today's panchang", { error: String(e) });
        }
    }

    // Save updated positions
    const sortedDates = Object.keys(newPositions).sort();
    const panchangDays = Object.keys(newPanchang).length;

    await docRef.set({
        positions: newPositions,
        panchang: newPanchang,
        lastUpdated: FieldValue.serverTimestamp(),
        lastFetchedDate: sortedDates[sortedDates.length - 1],
        dateRange: {
            from: sortedDates[0],
            to: sortedDates[sortedDates.length - 1],
        },
        stats: {
            totalDays: sortedDates.length,
            panchangDays: panchangDays,
            lastFetchCount: fetchedCount,
            lastFetchErrors: errorCount,
        },
    });

    logger.info("📅 Panchang status", {
        panchangDays,
        hasTodayPanchang: !isEmptyPanchang(newPanchang[todayKey]),
        todayKey,
    });

    // Recalculate upcoming events with new data
    await calculateAndStoreUpcomingEvents(newPositions);

    logger.info("✅ Smart prefetch complete", {
        fetched: fetchedCount,
        errors: errorCount,
        totalDays: sortedDates.length,
        dateRange: `${sortedDates[0]} to ${sortedDates[sortedDates.length - 1]}`,
    });

    return {
        fetched: fetchedCount,
        errors: errorCount,
        totalDays: sortedDates.length,
    };
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================

/**
 * Manual trigger for smart prefetch
 * Note: enforceAppCheck: false allows calls without App Check verification
 */
export const prefetchSkyPositions = onCall({
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: [freeAstrologyApiKey],
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke
    enforceAppCheck: false,
}, async (request) => {
    // Optional: Add basic auth check if desired
    // For now, allow any authenticated user to trigger
    logger.info("📡 Manual prefetch triggered", {
        uid: request.auth?.uid || "anonymous",
    });
    return await smartPrefetch();
});

/**
 * Get cached sky positions AND global panchang
 */
export const getSkyPositions = onCall({
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke
}, async (request) => {
    try {
        const docRef = db.collection("global_astro").doc("sky_positions");
        const doc = await docRef.get();

        if (!doc.exists) {
            return {
                success: false,
                error: "No cached positions available",
                positions: {},
                panchang: {},
            };
        }

        const docData = doc.data();
        return {
            success: true,
            positions: docData.positions || {},
            panchang: docData.panchang || {},
            dateRange: docData.dateRange || null,
            lastUpdated: docData.lastUpdated?.toDate?.()?.toISOString() || null,
        };
    } catch (error) {
        logger.error("Error fetching sky positions:", error);
        return {
            success: false,
            error: error.message,
            positions: {},
            panchang: {},
        };
    }
});

/**
 * Get pre-calculated upcoming events (sign ingresses, retrogrades)
 * This is the FAST path - just reads from Firestore, no calculation
 */
export const getUpcomingEvents = onCall({
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke
}, async (request) => {
    try {
        const docRef = db.collection("global_astro").doc("upcoming_events");
        const doc = await docRef.get();

        if (!doc.exists) {
            return {
                success: false,
                error: "No upcoming events calculated yet",
                signIngresses: [],
                retrogrades: [],
            };
        }

        const data = doc.data();
        return {
            success: true,
            signIngresses: data.signIngresses || [],
            retrogrades: data.retrogrades || [],
            lastCalculated: data.lastCalculated?.toDate?.()?.toISOString() || null,
        };
    } catch (error) {
        logger.error("Error fetching upcoming events:", error);
        return {
            success: false,
            error: error.message,
            signIngresses: [],
            retrogrades: [],
        };
    }
});

/**
 * Get cached global muhurat timeline (Ujjain reference)
 * 
 * SIMPLE LOGIC:
 * - Always shows 3 days: today, tomorrow, day after
 * - Cache is valid if dateKeys[0] === today (date-based, not time-based)
 * - Fetches fresh data when date changes
 */
export const getGlobalMuhurat = onCall({
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast2",
    secrets: [freeAstrologyApiKey],
    invoker: "public",
}, async (request) => {
    try {
        const today = DateTime.now().setZone(DEFAULT_TZ_ID).startOf("day");
        const todayKey = today.toFormat("yyyy-MM-dd");
        const docRef = db.collection("global_astro").doc("muhurat");
        const doc = await docRef.get();

        // Check if cache is valid: dateKeys[0] must be today
        if (doc.exists) {
            const data = doc.data();
            const cachedDateKeys = data.dateKeys || [];
            const cacheIsForToday = cachedDateKeys[0] === todayKey;

            if (cacheIsForToday && data.muhurat) {
                logger.info("Returning cached muhurat for today", { todayKey });
                return {
                    success: true,
                    muhurat: data.muhurat,
                    cached: true,
                };
            }
        }

        // Fetch fresh data for 3 days: today, tomorrow, day after
        logger.info("Fetching fresh muhurat data", { todayKey });
        const dateKeys = [];
        const dayPromises = [];

        for (let i = 0; i < MUHURAT_DAYS_AHEAD; i += 1) {
            const day = today.plus({ days: i });
            const dateKey = day.toFormat("yyyy-MM-dd");
            dateKeys.push(dateKey);
            dayPromises.push(fetchMuhuratForDate(day));
        }

        const results = await Promise.allSettled(dayPromises);
        const daysData = {};

        results.forEach((result, index) => {
            if (result.status !== "fulfilled") return;
            const parsed = extractApiOutput(result.value);
            if (!parsed) return;
            daysData[dateKeys[index]] = parseMuhuratDay(parsed);
        });

        if (Object.keys(daysData).length === 0) {
            logger.warn("No muhurat data from API");
            return { success: false, error: "No muhurat data available", muhurat: {} };
        }

        // Build unified timeline for smooth scrolling
        const unifiedTimeline = processUnifiedTimeline(daysData, DEFAULT_TZ_ID);

        const muhuratData = {
            days: daysData,
            unifiedTimeline,
            dateKeys,
            fetchedAt: DateTime.now().toISO(),
            timeZoneId: DEFAULT_TZ_ID,
        };

        // Save to cache
        await docRef.set({
            muhurat: muhuratData,
            dateKeys,
            lastUpdated: FieldValue.serverTimestamp(),
        }, { merge: true });

        logger.info("Muhurat data cached", { dateKeys });
        return { success: true, muhurat: muhuratData, cached: false };
    } catch (error) {
        logger.error("Error fetching global muhurat:", error);
        return { success: false, error: error.message, muhurat: {} };
    }
});

/**
 * Helper function to get upcoming sign ingresses (for internal use)
 * Reads from pre-calculated data - NO calculation, instant response
 */
export async function getUpcomingSignIngresses() {
    try {
        const docRef = db.collection("global_astro").doc("upcoming_events");
        const doc = await docRef.get();

        if (!doc.exists) {
            logger.warn("No upcoming_events document found");
            return [];
        }

        const data = doc.data();
        return data.signIngresses || [];
    } catch (error) {
        logger.error("Error reading sign ingresses:", { error: String(error) });
        return [];
    }
}

/**
 * Helper function to get upcoming retrogrades (for internal use)
 */
export async function getUpcomingRetrogrades() {
    try {
        const docRef = db.collection("global_astro").doc("upcoming_events");
        const doc = await docRef.get();

        if (!doc.exists) return [];

        const data = doc.data();
        return data.retrogrades || [];
    } catch (error) {
        logger.error("Error reading retrogrades:", { error: String(error) });
        return [];
    }
}

/**
 * Scheduled: Smart incremental update
 * Runs daily at 2 AM UTC
 * 
 * This is now EFFICIENT:
 * - Day 1 (or if behind): Fetches all missing days
 * - Day 2+: Usually fetches only 1 new day
 */
export const refreshSkyPositionsDaily = onSchedule({
    schedule: "every day 02:00",
    timeZone: "UTC",
    timeoutSeconds: 540,
    memory: "512MiB",
    secrets: [freeAstrologyApiKey],
    region: "asia-southeast2",
}, async () => {
    logger.info("⏰ Scheduled smart prefetch starting");
    const result = await smartPrefetch();
    logger.info("⏰ Scheduled smart prefetch complete", result);
});

export const refreshMuhuratDaily = onSchedule({
    schedule: "every day 03:00",
    timeZone: "UTC",
    timeoutSeconds: 300,
    memory: "256MiB",
    secrets: [freeAstrologyApiKey],
    region: "asia-southeast2",
}, async () => {
    logger.info("⏰ Scheduled muhurat refresh starting");

    try {
        // Try to get fresh data from API
        const fakeRequest = { auth: null };
        const result = await getGlobalMuhurat(fakeRequest);

        if (result.success && result.muhurat) {
            logger.info("⏰ Scheduled muhurat refresh complete with fresh data");
        } else {
            logger.warn("⏰ API failed, falling back to basic data");
            // If API fails, ensure we have at least basic data
            await ensureBasicMuhuratData();
        }
    } catch (error) {
        logger.error("⏰ Scheduled muhurat refresh failed, using fallback", error);
        await ensureBasicMuhuratData();
    }
});

// Fallback: create minimal muhurat data if API fails
async function ensureBasicMuhuratData() {
    try {
        const today = DateTime.now().setZone(DEFAULT_TZ_ID).startOf("day");
        const todayKey = today.toFormat("yyyy-MM-dd");
        const docRef = db.collection("global_astro").doc("muhurat");

        logger.info("⏰ Creating fallback muhurat data", { todayKey });

        // Simple fallback with typical times
        const fallbackDay = {
            rahuKala: { starts_at: "12:00", ends_at: "13:30" },
            gulikaKala: { starts_at: "15:00", ends_at: "16:30" },
            yamaganda: { starts_at: "09:00", ends_at: "10:30" },
            abhijit: { starts_at: "11:45", ends_at: "12:30" },
        };

        const muhuratData = {
            days: { [todayKey]: fallbackDay },
            unifiedTimeline: { events: [], startTime: 0, endTime: 1440, dateKeys: [todayKey] },
            dateKeys: [todayKey],
            fetchedAt: DateTime.now().toISO(),
            timeZoneId: DEFAULT_TZ_ID,
            isFallback: true,
        };

        await docRef.set({
            muhurat: muhuratData,
            dateKeys: [todayKey],
            lastUpdated: FieldValue.serverTimestamp(),
        }, { merge: true });

        logger.info("⏰ Fallback muhurat data saved");
    } catch (error) {
        logger.error("⏰ Failed to set fallback muhurat data", error);
    }
}
