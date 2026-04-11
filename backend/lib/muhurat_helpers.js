/**
 * Shared Muhurat Parsing Helpers
 *
 * Extracted from free_astro.js and sky_positions.js to eliminate duplication.
 * Both files had near-identical parseMuhuratDay and processUnifiedTimeline functions.
 */

import { DateTime } from "luxon";
import { parseApiTimeString } from "./astro_helpers.js";

/**
 * Parse muhurat data for a single day from the Free Astrology API response.
 *
 * Extracts inauspicious (Rahu Kala, Gulika Kala, Yamaganda, Varjyam)
 * and auspicious (Abhijit, Amrit Kaal, Brahma Muhurat, Dur Muhurat) times.
 *
 * @param {object} parsedMuhurat - Raw parsed muhurat data from the API
 * @returns {object} Structured day data with parsed time ranges
 */
export const parseMuhuratDay = (parsedMuhurat) => {
    const dayData = {};

    // Extract sunrise/sunset if available (Free Astrology API includes these)
    if (parsedMuhurat.sunrise) {
        dayData.sunrise = parsedMuhurat.sunrise;
    }
    if (parsedMuhurat.sunset) {
        dayData.sunset = parsedMuhurat.sunset;
    }

    // Parse inauspicious times
    if (parsedMuhurat.rahu_kaalam_data) {
        dayData.rahuKala = parseApiTimeString(parsedMuhurat.rahu_kaalam_data);
        dayData.rahu_kala = dayData.rahuKala;
    }
    if (parsedMuhurat.gulika_kalam_data) {
        dayData.gulikaKala = parseApiTimeString(parsedMuhurat.gulika_kalam_data);
        dayData.gulika_kala = dayData.gulikaKala;
    }
    if (parsedMuhurat.yama_gandam_data) {
        dayData.yamaganda = parseApiTimeString(parsedMuhurat.yama_gandam_data);
        dayData.yamagandaKala = dayData.yamaganda;
    }
    if (parsedMuhurat.varjyam_data) {
        dayData.varjyam = parseApiTimeString(parsedMuhurat.varjyam_data);
    }

    // Parse auspicious times
    if (parsedMuhurat.abhijit_data) {
        dayData.abhijit = parseApiTimeString(parsedMuhurat.abhijit_data);
    }
    if (parsedMuhurat.amrit_kaal_data) {
        dayData.amrit = parseApiTimeString(parsedMuhurat.amrit_kaal_data);
        dayData.amritKaal = dayData.amrit;
    }
    if (parsedMuhurat.brahma_muhurat_data) {
        dayData.brahmaMuhurat = parseApiTimeString(parsedMuhurat.brahma_muhurat_data);
    }
    if (parsedMuhurat.dur_muhurat_data) {
        const durParsed = parseApiTimeString(parsedMuhurat.dur_muhurat_data);
        dayData.durMuhurat = durParsed || parsedMuhurat.dur_muhurat_data;
    }

    return dayData;
};

/**
 * Process all days' muhurat data into a unified timeline with absolute minute positions.
 *
 * @param {object} daysData - Map of dateKey -> dayData (from parseMuhuratDay)
 * @param {string} timeZoneId - IANA timezone identifier
 * @param {object} [options] - Optional configuration
 * @param {boolean} [options.clampBounds=false] - If true, clamp timeline to 5AM-10PM per day
 * @param {boolean} [options.includeDayCount=false] - If true, include dayCount in response
 * @returns {object} Timeline with events array, startTime, endTime, dateKeys
 */
export const processUnifiedTimeline = (daysData, timeZoneId, options = {}) => {
    const { clampBounds = false, includeDayCount = false } = options;
    const events = [];
    const sortedDateKeys = Object.keys(daysData).sort();

    if (sortedDateKeys.length === 0) return { events: [], startTime: 0, endTime: 0 };

    // Parse reference date (first day)
    const firstDateKey = sortedDateKeys[0];
    const [refYear, refMonth, refDay] = firstDateKey.split("-").map(Number);
    const refDate = DateTime.fromObject(
        { year: refYear, month: refMonth, day: refDay },
        { zone: timeZoneId },
    );

    // Helper to convert time string to absolute minutes from reference
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

    // Process each day's events
    for (const dateKey of sortedDateKeys) {
        const dayData = daysData[dateKey];
        if (!dayData) continue;

        // Process inauspicious times
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

        // Process auspicious times
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

    // Sort events by start time
    events.sort((a, b) => a.start - b.start);

    // Calculate overall time range
    const minStart = events.length ? Math.min(...events.map((e) => e.start)) : 0;
    const maxEnd = events.length ? Math.max(...events.map((e) => e.end)) : 0;

    let startTime = Math.floor(minStart / 60) * 60;
    let endTime = Math.ceil(maxEnd / 60) * 60;

    if (clampBounds) {
        // Ensure reasonable bounds (5 AM to 10 PM per day)
        startTime = Math.max(startTime, 5 * 60);
        endTime = Math.min(endTime, (sortedDateKeys.length * 24 * 60) + (22 * 60));
    } else {
        startTime = Math.max(0, startTime);
    }

    const result = {
        events,
        startTime,
        endTime,
        dateKeys: sortedDateKeys,
    };

    if (includeDayCount) {
        result.dayCount = sortedDateKeys.length;
    }

    return result;
};
