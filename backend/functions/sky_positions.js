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

import { logger } from "firebase-functions";
import { DateTime } from "luxon";
import { db, FieldValue } from "../lib/firebase.js";
import { freeAstrologyApiKey } from "../lib/secrets.js";
import { callFreeAstro, callFreeAstroSafe } from "./free_astro_client.js";
import { extractApiOutput } from "../lib/astro_helpers.js";
import { parseMuhuratDay } from "../lib/muhurat_helpers.js";

const PLANETS_ENDPOINT = "/planets";
const SAMVAT_ENDPOINT = "/samvatinfo";
const LUNAR_MONTH_ENDPOINT = "/lunarmonthinfo";
const TITHI_ENDPOINT = "/tithi-durations";
const MUHURAT_ENDPOINT = "/good-bad-times";

// Ujjain - the Hindu Prime Meridian (traditional reference point)
const DEFAULT_LAT = 23.1765;
const DEFAULT_LNG = 75.7885;
const DEFAULT_TZ = 5.5;

// How far ahead to maintain positions + panchang + muhurat (365 days).
// A fresh deploy backfills ~4 daily runs (MAX_FETCH_PER_RUN per run).
const DAYS_AHEAD_TARGET = 365;
// Maintain a rolling window of past days too, so scrolling the wheel BACKWARD
// has data. Matches the client wheel reach (_sliderRangeDays = 180). Days older
// than this are pruned on each run, which also caps the single-doc size (the
// doc has a hard 1 MiB Firestore ceiling) instead of growing forever.
const DAYS_BEHIND_TARGET = 180;

// Safety batch limit per run — avoids Cloud Function timeout (300s).
// Each day costs up to 5 API calls (1 position + 3 panchang + 1 muhurat)
// at 150ms throttle each.  100 days × 5 × 150ms ≈ 75s (well within 300s).
const MAX_FETCH_PER_RUN = 100;

// Important planets for tracking (9 Vedic grahas + 3 outer planets)
const TRACKED_PLANETS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu", "Uranus", "Neptune", "Pluto"];

const isEmptyPanchang = (value) => {
    if (!value || typeof value !== "object") return true;
    return Object.keys(value).length === 0;
};

/** Check if muhurat data for a date is missing or empty. */
const isEmptyMuhurat = (value) => {
    if (!value || typeof value !== "object") return true;
    return Object.keys(value).length === 0;
};

/**
 * Convert a muhurat time string to minutes from midnight.  Handles:
 *   - Full ISO datetimes: "2026-06-10 06:24:00" or "2026-06-10T06:24:00"
 *     (this is what parseMuhuratDay actually stores — see processUnifiedTimeline's
 *      timeToAbsoluteMinutes, which parses the same field via DateTime.fromISO)
 *   - Clock strings: "HH:MM" or "HH:MM AM/PM"
 * Returns null on bad input.
 */
function timeStrToMinutes(str) {
    if (!str || typeof str !== "string") return null;

    // ISO datetime (has a yyyy-mm-dd date part): grab the first HH:MM that
    // follows the date (after a 'T' or whitespace separator). Parsing this as
    // "HH:MM" directly would yield garbage (h = NaN → 0), collapsing every
    // event to ~midnight — the "crumbled to one spot" bug.
    if (/\d{4}-\d{2}-\d{2}/.test(str)) {
        const m = str.match(/(?:T|\s)(\d{1,2}):(\d{2})/);
        if (m) {
            const h = Number(m[1]);
            const min = Number(m[2]);
            if (!Number.isNaN(h) && !Number.isNaN(min)) return h * 60 + min;
        }
        return null;
    }

    // Clock string: "HH:MM" or "HH:MM AM/PM".
    const clean = str.replace(/\s*(AM|PM)\s*/i, "").trim();
    const parts = clean.split(":");
    let h = Number(parts[0]) || 0;
    const m = Number(parts[1]) || 0;
    if (/PM/i.test(str) && h < 12) h += 12;
    if (/AM/i.test(str) && h === 12) h = 0;
    return h * 60 + m;
}

/**
 * Convert a parsed muhurat day (from parseMuhuratDay) to compact [start, end]
 * minute pairs keyed by short codes.
 *
 * Compact keys:
 *   r = Rahu Kala, g = Gulika Kala, y = Yamaganda, v = Varjyam,
 *   a = Abhijit, am = Amrit Kaal, b = Brahma Muhurat, d = Dur Muhurat
 */
function muhuratToCompact(muhuratDay) {
    if (!muhuratDay) return null;
    const compact = {};

    const toMin = (timeData) => {
        if (!timeData) return null;
        const s = timeData.starts_at || timeData.startsAt;
        const e = timeData.ends_at || timeData.endsAt;
        if (!s || !e) return null;
        const sm = timeStrToMinutes(s);
        const em = timeStrToMinutes(e);
        if (sm == null || em == null) return null;
        return [sm, em];
    };

    const r = toMin(muhuratDay.rahuKala);    if (r) compact.r = r;
    const g = toMin(muhuratDay.gulikaKala);  if (g) compact.g = g;
    const y = toMin(muhuratDay.yamaganda);   if (y) compact.y = y;
    const v = toMin(muhuratDay.varjyam);     if (v) compact.v = v;
    const a = toMin(muhuratDay.abhijit);     if (a) compact.a = a;
    const am = toMin(muhuratDay.amrit || muhuratDay.amritKaal);
    if (am) compact.am = am;
    const b = toMin(muhuratDay.brahmaMuhurat); if (b) compact.b = b;
    const d = toMin(muhuratDay.durMuhurat);  if (d) compact.d = d;

    return Object.keys(compact).length > 0 ? compact : null;
}

// Use canonical parseApiTimeString from lib/astro_helpers.js (previously duplicated here with a bug)

/**
 * Fetch planetary positions from FreeAstrologyAPI for a specific date
 */
async function fetchPlanetaryPositionsForDate(date) {
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

    return callFreeAstro(PLANETS_ENDPOINT, payload);
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
    // Query at 6:00 AM IST (approximate sunrise at Ujjain).
    // In Vedic astrology the tithi at sunrise defines the day's tithi.
    // Noon queries risk picking up the NEXT tithi when the Moon moves
    // fast, making tithis appear "skipped" in the calendar (e.g.
    // Tritiya → Panchami with no Chaturthi).
    const payload = {
        year: date.year,
        month: date.month,
        date: date.day,
        hours: 6,
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

    try {
        // Fetch panchang from 3 separate API endpoints
        // IMPORTANT: Log failures explicitly — silent nulls caused weeks of missing data
        const fetchWithLogging = async (endpoint, name) => {
            const res = await callFreeAstroSafe(endpoint, payload);
            if (!res) {
                logger.warn(`\u26a0\ufe0f Panchang API ${name} unavailable`, {
                    endpoint, date: `${date.year}-${date.month}-${date.day}`,
                });
            }
            return res;
        };
        const [samvatRes, lunarRes, tithiRes] = await Promise.all([
            fetchWithLogging(SAMVAT_ENDPOINT, "samvat"),
            fetchWithLogging(LUNAR_MONTH_ENDPOINT, "lunar_month"),
            fetchWithLogging(TITHI_ENDPOINT, "tithi"),
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
        Object.keys(panchang).forEach((key) => {
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

    return callFreeAstro(MUHURAT_ENDPOINT, payload);
}

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
                    description: isRetro ?
                        `${planet} goes retrograde` :
                        `${planet} goes direct`,
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
    const futureIngresses = signIngresses.filter((e) => e.date >= today);
    const futureRetrogrades = retrogrades.filter((e) => e.date >= today);

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
        sampleIngresses: futureIngresses.slice(0, 5).map((e) => `${e.planet}→${e.toSign} on ${e.date}`),
        sampleRetrogrades: futureRetrogrades.slice(0, 3).map((e) => `${e.planet} ${e.type} on ${e.date}`),
    });

    return { signIngresses: futureIngresses, retrogrades: futureRetrogrades };
}

// ============================================================================
// SMART INCREMENTAL PREFETCH
// ============================================================================

/**
 * Smart incremental prefetch — fetches positions, panchang AND muhurat
 * for the full 365-day forward window.
 *
 * Logic:
 * 1. Read existing positions / panchang / muhurat from Firestore
 * 2. Determine target date (today + DAYS_AHEAD_TARGET)
 * 3. Find missing dates for ALL three data sets
 * 4. Fetch ONLY missing dates (usually 1 per day after initial population)
 * 5. Respect MAX_FETCH_PER_RUN to stay within function timeout
 * 6. Merge with existing data & recalculate upcoming events
 */
async function smartPrefetch() {
    const docRef = db.collection("global_astro").doc("sky_positions");
    const doc = await docRef.get();

    const existingData = doc.exists ? doc.data() : {};
    const existingPositions = existingData.positions || {};
    const existingPanchang = existingData.panchang || {};
    const existingMuhurat = existingData.muhurat || {};
    const existingDates = new Set(Object.keys(existingPositions));

    const today = DateTime.now().setZone("UTC");
    const targetDate = today.plus({ days: DAYS_AHEAD_TARGET });
    const todayKey = today.toFormat("yyyy-MM-dd");
    const tomorrowKey = today.plus({ days: 1 }).toFormat("yyyy-MM-dd");

    // ─── Future window: dates we should have (today-180 → today+365) ─────────
    const requiredDates = [];
    let checkDate = today.minus({ days: DAYS_BEHIND_TARGET });
    while (checkDate <= targetDate) {
        requiredDates.push(checkDate.toFormat("yyyy-MM-dd"));
        checkDate = checkDate.plus({ days: 1 });
    }
    const missingPositionDates = requiredDates.filter((d) => !existingDates.has(d));

    // ─── Panchang gaps: ALL required dates (not just 14-day window) ──────────
    const missingPanchangSet = new Set();
    for (const k of requiredDates) {
        if (isEmptyPanchang(existingPanchang[k])) missingPanchangSet.add(k);
    }
    // Also heal historical gaps inside existing panchang range
    const panchangKeys = Object.keys(existingPanchang).sort();
    if (panchangKeys.length > 0) {
        const first = DateTime.fromISO(panchangKeys[0]);
        const last = DateTime.fromISO(panchangKeys[panchangKeys.length - 1]);
        let cur = first;
        while (cur <= last) {
            const k = cur.toFormat("yyyy-MM-dd");
            if (isEmptyPanchang(existingPanchang[k])) missingPanchangSet.add(k);
            cur = cur.plus({ days: 1 });
        }
    }

    // ─── Muhurat gaps: ALL required dates ────────────────────────────────────
    const missingMuhuratSet = new Set();
    for (const k of requiredDates) {
        if (isEmptyMuhurat(existingMuhurat[k])) missingMuhuratSet.add(k);
    }

    const missingPanchangDates = Array.from(missingPanchangSet).sort();
    const missingMuhuratDates = Array.from(missingMuhuratSet).sort();

    logger.info("🔍 Smart prefetch analysis", {
        existingDays: existingDates.size,
        existingPanchangDays: panchangKeys.length,
        existingMuhuratDays: Object.keys(existingMuhurat).length,
        requiredDays: requiredDates.length,
        missingPositionDays: missingPositionDates.length,
        missingPanchangDays: missingPanchangDates.length,
        missingMuhuratDays: missingMuhuratDates.length,
        targetDate: targetDate.toFormat("yyyy-MM-dd"),
    });

    // ─── Nothing to do? Exit early. ──────────────────────────────────────────
    if (missingPositionDates.length === 0 &&
        missingPanchangDates.length === 0 &&
        missingMuhuratDates.length === 0) {
        logger.info("✅ All position, panchang AND muhurat data is up to date");
        return {
            fetched: 0,
            existing: existingDates.size,
            panchangFetched: 0,
            panchangErrors: 0,
            muhuratFetched: 0,
            muhuratErrors: 0,
            message: "Already up to date",
        };
    }

    // ─── Build a unified fetch list (de-duplicated by date). ─────────────────
    // For each date we know WHAT is missing, so we only call the APIs we need.
    // Sorted chronologically, capped at MAX_FETCH_PER_RUN.
    const allMissing = new Set([
        ...missingPositionDates,
        ...missingPanchangDates,
        ...missingMuhuratDates,
    ]);
    const fetchQueue = Array.from(allMissing).sort().slice(0, MAX_FETCH_PER_RUN);

    const newPositions = { ...existingPositions };
    const newPanchang = { ...existingPanchang };
    const newMuhurat = { ...existingMuhurat };
    let fetchedCount = 0;
    let errorCount = 0;
    let panchangFetched = 0;
    let panchangErrors = 0;
    let muhuratFetched = 0;
    let muhuratErrors = 0;

    for (const dateKey of fetchQueue) {
        const date = DateTime.fromISO(dateKey);
        const needsPosition = !existingDates.has(dateKey);
        const needsPanchang = missingPanchangSet.has(dateKey);
        const needsMuhurat = missingMuhuratSet.has(dateKey);

        // ── Positions (1 API call) ──────────────────────────────────────────
        if (needsPosition) {
            try {
                const apiResponse = await fetchPlanetaryPositionsForDate(date);
                const planets = extractPlanetData(apiResponse);
                if (planets && Object.keys(planets).length > 0) {
                    newPositions[dateKey] = planets;
                    fetchedCount++;
                }
                await new Promise((r) => setTimeout(r, 150));
            } catch (error) {
                logger.warn(`Failed positions ${dateKey}:`, { error: String(error) });
                errorCount++;
            }
        }

        // ── Panchang (3 API calls) ──────────────────────────────────────────
        if (needsPanchang) {
            try {
                const p = await fetchPanchangForDate(date);
                if (p) {
                    newPanchang[dateKey] = p;
                    panchangFetched++;
                } else {
                    panchangErrors++;
                }
                await new Promise((r) => setTimeout(r, 150));
            } catch (e) {
                logger.warn(`Failed panchang ${dateKey}:`, { error: String(e) });
                panchangErrors++;
            }
        }

        // ── Muhurat (1 API call) ────────────────────────────────────────────
        if (needsMuhurat) {
            try {
                const raw = await fetchMuhuratForDate(date);
                const parsed = extractApiOutput(raw);
                if (parsed) {
                    newMuhurat[dateKey] = parseMuhuratDay(parsed);
                    muhuratFetched++;
                } else {
                    muhuratErrors++;
                }
                await new Promise((r) => setTimeout(r, 150));
            } catch (e) {
                logger.warn(`Failed muhurat ${dateKey}:`, { error: String(e) });
                muhuratErrors++;
            }
        }
    }

    // ─── Loud surfacing of today/tomorrow panchang status (UTC). ─────────────
    const hasTodayPanchang = !isEmptyPanchang(newPanchang[todayKey]);
    const hasTomorrowPanchang = !isEmptyPanchang(newPanchang[tomorrowKey]);
    if (!hasTodayPanchang) {
        logger.error("❌ Today's panchang STILL missing after prefetch", { todayKey });
    }
    if (!hasTomorrowPanchang) {
        logger.warn("⚠️ Tomorrow's panchang missing (IST users may see stale data)", { tomorrowKey });
    }

    // ─── Prune days older than the rolling window (caps doc size). ──────────
    const pruneBefore = today.minus({ days: DAYS_BEHIND_TARGET }).toFormat("yyyy-MM-dd");
    let prunedCount = 0;
    for (const bag of [newPositions, newPanchang, newMuhurat]) {
        for (const k of Object.keys(bag)) {
            if (k < pruneBefore) {
                delete bag[k];
                prunedCount++;
            }
        }
    }
    if (prunedCount > 0) {
        logger.info(" Pruned stale astro days outside rolling window", { pruneBefore, prunedCount });
    }

    // ─── Persist. ────────────────────────────────────────────────────────────
    const sortedDates = Object.keys(newPositions).sort();
    const panchangDays = Object.keys(newPanchang).length;
    const muhuratDays = Object.keys(newMuhurat).length;

    await docRef.set({
        positions: newPositions,
        panchang: newPanchang,
        muhurat: newMuhurat,
        lastUpdated: FieldValue.serverTimestamp(),
        lastFetchedDate: sortedDates[sortedDates.length - 1] || null,
        dateRange: {
            from: sortedDates[0] || null,
            to: sortedDates[sortedDates.length - 1] || null,
        },
        stats: {
            totalDays: sortedDates.length,
            panchangDays,
            muhuratDays,
            lastFetchCount: fetchedCount,
            lastFetchErrors: errorCount,
            lastPanchangFetchCount: panchangFetched,
            lastPanchangFetchErrors: panchangErrors,
            lastMuhuratFetchCount: muhuratFetched,
            lastMuhuratFetchErrors: muhuratErrors,
            hasTodayPanchang,
            hasTomorrowPanchang,
        },
    });

    logger.info("📅 Prefetch status", {
        panchangDays,
        muhuratDays,
        hasTodayPanchang,
        hasTomorrowPanchang,
        todayKey,
        tomorrowKey,
        panchangFetched,
        panchangErrors,
        muhuratFetched,
        muhuratErrors,
        batchSize: fetchQueue.length,
        remainingMissing: allMissing.size - fetchQueue.length,
    });

    // Recalculate upcoming events with new data
    if (fetchedCount > 0 || missingPositionDates.length > 0) {
        await calculateAndStoreUpcomingEvents(newPositions);
    }

    logger.info("✅ Smart prefetch complete", {
        fetched: fetchedCount,
        errors: errorCount,
        panchangFetched,
        panchangErrors,
        muhuratFetched,
        muhuratErrors,
        totalDays: sortedDates.length,
        dateRange: sortedDates.length > 0
            ? `${sortedDates[0]} to ${sortedDates[sortedDates.length - 1]}`
            : "empty",
    });

    return {
        fetched: fetchedCount,
        errors: errorCount,
        panchangFetched,
        panchangErrors,
        muhuratFetched,
        muhuratErrors,
        totalDays: sortedDates.length,
        panchangDays,
        muhuratDays,
        hasTodayPanchang,
        hasTomorrowPanchang,
    };
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================

// ---------------------------------------------------------------------------
// Gateway-callable handlers (plain async functions)
// Called by the astroGateway router.
// ---------------------------------------------------------------------------

export async function handlePrefetchSkyPositions(request) {
    const fillAll = request?.data?.fillAll === true;
    logger.info("📡 Manual prefetch triggered", {
        uid: request.auth?.uid || "anonymous",
        fillAll,
    });

    if (!fillAll) {
        return await smartPrefetch();
    }

    // fillAll mode: loop batches until everything is populated or we
    // approach the 300s Cloud Function timeout.  Each batch handles
    // MAX_FETCH_PER_RUN dates, so ~4 passes fills the full 365-day window.
    const startTime = Date.now();
    const TIMEOUT_MS = 270_000; // stop 30s before the hard 300s limit
    let lastResult = null;
    let passes = 0;

    while (Date.now() - startTime < TIMEOUT_MS) {
        passes++;
        lastResult = await smartPrefetch();

        const totalFetched = (lastResult.fetched || 0)
            + (lastResult.panchangFetched || 0)
            + (lastResult.muhuratFetched || 0);
        if (totalFetched === 0) {
            logger.info(`✅ Full population complete after ${passes} pass(es)`);
            break;
        }
        logger.info(`🔄 Pass ${passes} done — fetched ${totalFetched} items, looping...`);
    }

    return { ...lastResult, passes };
}

export async function handleGetSkyPositions() {
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
}

export async function handleGetUpcomingEvents() {
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
}

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

/** Extracted runner for orchestrator consolidation. */
export async function runRefreshSkyPositionsDaily() {
    logger.info("⏰ Scheduled smart prefetch starting");
    const result = await smartPrefetch();
    logger.info("⏰ Scheduled smart prefetch complete", result);
}

// NOTE: `refreshSkyPositionsDaily` was a standalone `onSchedule` export.
// It is now invoked by `unifiedOrchestrator` Phase 2 (data refresh) via the
// `runRefreshSkyPositionsDaily` runner above.

// ============================================================================
// ASTRO CALENDAR (rolling window snapshot for infinite wheel scrolling)
// ============================================================================

/**
 * getAstroCalendar — Returns daily snapshots (positions + panchang + muhurat)
 * across the rolling window (today-180 → today+365). This is the SINGLE source
 * of truth for the wheel: positions, panchang AND muhurat all live here.
 *
 * Reads from the global_astro/sky_positions Firestore doc (populated by the
 * daily smartPrefetch job). Dates outside the prefetch window are excluded —
 * the client falls back to sidereal-period math for those.
 */

const NAKSHATRA_NAMES = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra",
    "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni",
    "Uttara Phalguni", "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha",
    "Jyeshtha", "Mula", "Purva Ashadha", "Uttara Ashadha", "Shravana",
    "Dhanishta", "Shatabhisha", "Purva Bhadrapada", "Uttara Bhadrapada", "Revati",
];

const YOGA_NAMES = [
    "Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda",
    "Sukarma", "Dhriti", "Shula", "Ganda", "Vriddhi", "Dhruva", "Vyaghata",
    "Harshana", "Vajra", "Siddhi", "Vyatipata", "Variyan", "Parigha", "Shiva",
    "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra", "Vaidhriti",
];

const KARANA_NAMES = [
    "Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti",
    "Shakuni", "Chatushpada", "Naga", "Kimstughna",
];

const PLANET_ORDER = ["Moon", "Sun", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];

// Lunar month name → number (1 = Chaitra … 12 = Phalguna).
// These are the EXACT spellings returned by FreeAstrologyAPI's /lunarmonthinfo endpoint.
// The API uses Telugu-style names ending in "-am".
// Prefixes: "Adhika " = intercalary month, "Nija " = regular month (when Adhika exists).
const LUNAR_MONTH_NUMBERS = {
    chaitram: 1,
    vaisakham: 2,
    jyeshtam: 3,
    ashadam: 4,
    sravanam: 5,
    bhadrapadam: 6,
    ashweeyujam: 7,
    karthikam: 8,
    maargasiram: 9,
    pushyam: 10,
    maagham: 11,
    phalgunam: 12,
};

/**
 * Resolve a lunar-month name to its 1-12 number.
 * Strips "Adhika " or "Nija " prefix (API uses these for intercalary months).
 */
function lunarMonthNameToNumber(name) {
    if (!name) return null;
    let key = name.toLowerCase().trim();
    // Strip Adhika/Nija prefix
    key = key.replace(/^(?:adhika?|nija)\s+/i, "").trim();
    const num = LUNAR_MONTH_NUMBERS[key];
    if (num) return num;
    // Log unrecognized name — should never happen with correct API data
    logger.warn("⚠️ Unrecognized lunar month name", { rawName: name, normalizedKey: key });
    return null;
}

function nakshatraNameToIndex(name) {
    if (!name) return -1;
    const lower = name.toLowerCase().trim();
    return NAKSHATRA_NAMES.findIndex((n) => n.toLowerCase() === lower);
}

function yogaNameToIndex(name) {
    if (!name) return -1;
    const lower = name.toLowerCase().trim();
    return YOGA_NAMES.findIndex((n) => n.toLowerCase() === lower);
}

function karanaNameToIndex(name) {
    if (!name) return -1;
    const lower = name.toLowerCase().trim();
    return KARANA_NAMES.findIndex((n) => n.toLowerCase() === lower);
}

/**
 * Build a compact calendar entry from full position + panchang + muhurat data.
 *
 * Compact format per day:
 *   n  = nakshatra index (0-26)
 *   t  = tithi number (1-30)
 *   p  = paksha (0=shukla, 1=krishna)
 *   y  = yoga index (0-26)
 *   k  = karana index (0-10)
 *   m  = planet longitudes [Mo,Su,Ma,Me,Ju,Ve,Sa,Ra,Ke]
 *   r  = retrograde flags (only if any planet retrograde)
 *   mu = muhurat {r:[s,e], g:[s,e], y:[s,e], a:[s,e], ...} in minutes
 */
function buildCalendarEntry(positionsForDay, panchangForDay, muhuratForDay) {
    const entry = {};

    // Panchang fields (indices are compact)
    if (panchangForDay) {
        const nIdx = nakshatraNameToIndex(panchangForDay.nakshatra);
        if (nIdx >= 0) entry.n = nIdx;

        const tNum = panchangForDay.tithi_number || panchangForDay.number;
        if (tNum != null) entry.t = Number(tNum);

        const paksha = panchangForDay.paksha;
        if (paksha) entry.p = paksha.toLowerCase().startsWith("k") ? 1 : 0;

        const yIdx = yogaNameToIndex(panchangForDay.yoga);
        if (yIdx >= 0) entry.y = yIdx;

        const kIdx = karanaNameToIndex(panchangForDay.karana);
        if (kIdx >= 0) entry.k = kIdx;

        // Lunar month — send raw string + number.
        // ln = raw API name (e.g. "Adhika Jyeshtam") — for adhika detection
        // lm = month number 1-12 — for numeric date display
        const monthName = panchangForDay.lunar_month_full_name
            || panchangForDay.lunar_month_name;
        if (monthName) {
            entry.ln = monthName;
            const monthNum = lunarMonthNameToNumber(monthName);
            if (monthNum) entry.lm = monthNum;
        }
    }

    // Planet longitudes (compact array)
    if (positionsForDay) {
        const lngs = [];
        const retros = [];
        let hasAny = false;

        for (const planet of PLANET_ORDER) {
            const pd = positionsForDay[planet];
            if (pd && pd.longitude != null) {
                lngs.push(Math.round(pd.longitude * 100) / 100); // 2 decimal places
                retros.push(pd.isRetro === true);
                hasAny = true;
            } else {
                lngs.push(null);
                retros.push(false);
            }
        }

        if (hasAny) {
            entry.m = lngs;
            // Only include retro array if any planet is retrograde
            if (retros.some(Boolean)) entry.r = retros;
        }
    }

    // Muhurat (compact minute pairs)
    const mu = muhuratToCompact(muhuratForDay);
    if (mu) entry.mu = mu;

    return Object.keys(entry).length > 0 ? entry : null;
}

export async function handleGetAstroCalendar(request, data) {
    try {
        const docRef = db.collection("global_astro").doc("sky_positions");
        const doc = await docRef.get();

        if (!doc.exists) {
            return { success: false, error: "No sky data available", calendar: {} };
        }

        const docData = doc.data();
        const positions = docData.positions || {};
        const panchang = docData.panchang || {};
        const muhurat = docData.muhurat || {};

        // Build compact calendar from all available dates
        const calendar = {};
        const allDates = new Set([
            ...Object.keys(positions),
            ...Object.keys(panchang),
            ...Object.keys(muhurat),
        ]);
        const sortedDates = Array.from(allDates).sort();

        for (const dateKey of sortedDates) {
            const entry = buildCalendarEntry(
                positions[dateKey], panchang[dateKey], muhurat[dateKey],
            );
            if (entry) calendar[dateKey] = entry;
        }

        logger.info("📅 Astro calendar served", {
            totalDays: Object.keys(calendar).length,
            dateRange: sortedDates.length > 0
                ? `${sortedDates[0]} to ${sortedDates[sortedDates.length - 1]}`
                : "empty",
        });

        return {
            success: true,
            calendar,
            dateRange: sortedDates.length > 0
                ? { from: sortedDates[0], to: sortedDates[sortedDates.length - 1] }
                : null,
        };
    } catch (error) {
        logger.error("Error building astro calendar:", error);
        return { success: false, error: error.message, calendar: {} };
    }
}
