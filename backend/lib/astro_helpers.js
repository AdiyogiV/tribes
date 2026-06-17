/**
 * Shared astrology helper functions
 *
 * Utility functions used across multiple astrology modules
 * (free_astro, daily_astro_insights, ayurveda, sky_positions, etc.)
 */

import { unwrapJsonOutput, safeParseJson } from "./utils.js";

// =============================================================================
// API RESPONSE UTILITIES
// =============================================================================

/**
 * Extract the meaningful payload from a FreeAstrologyAPI response.
 *
 * The API commonly wraps results in an `output` field that may itself be
 * a JSON string. This function unwraps that and returns a plain object,
 * or null if nothing usable can be extracted.
 *
 * @param {*} response - Raw API response
 * @returns {object|null} Extracted output object
 */
export function extractApiOutput(response) {
    if (!response) return null;
    if (typeof response === "object" && !Array.isArray(response)) {
        if (Object.prototype.hasOwnProperty.call(response, "output")) {
            const parsed = unwrapJsonOutput(response.output);
            if (parsed && typeof parsed === "object") {
                return parsed;
            }
        }
        return response;
    }
    if (typeof response === "string") {
        return unwrapJsonOutput(response);
    }
    return null;
}

// =============================================================================
// CHART DATA EXTRACTION
// =============================================================================

/**
 * Extract user's natal ascendant (Lagna) degree from astrology data.
 *
 * This is CRITICAL for calculating transit houses correctly in Vedic astrology.
 * Transit houses must be calculated relative to the user's natal ascendant,
 * NOT the current sky's ascendant (which changes every ~2 hours).
 *
 * @param {Object} astroData - User's astrology data from Firestore
 * @returns {number|null} Ascendant degree (0-360) or null if not found
 */
export function extractAscendantDegree(astroData) {
    // Method 1: Check processedPlanets array (normalized format)
    const pp = astroData?.processedPlanets;
    if (Array.isArray(pp)) {
        const lagna = pp.find(
            (p) =>
                (p?.name === "Lagna" || p?.name === "Ascendant") &&
                (p?.fullDegree != null || p?.full_degree != null),
        );
        if (lagna?.fullDegree != null) return lagna.fullDegree;
        if (lagna?.full_degree != null) return lagna.full_degree;
    }

    // Method 2: Check raw birthChartData.output
    const out = astroData?.birthChartData?.output;
    const outObj = Array.isArray(out) ? out[0] : out;
    if (outObj && typeof outObj === "object") {
        // Try common keys for Ascendant
        const asc =
            outObj["0"] ||
            outObj.Ascendant ||
            outObj.ascendant ||
            Object.values(outObj).find(
                (p) =>
                    p &&
                    typeof p === "object" &&
                    (p.name?.toLowerCase?.() === "ascendant" || p.name?.toLowerCase?.() === "lagna"),
            );
        const deg = asc?.fullDegree || asc?.full_degree || asc?.longitude;
        if (deg != null) return deg;
    }

    return null;
}

// =============================================================================
// TEXT UTILITIES
// =============================================================================

/**
 * Strip markdown formatting from text for clean notification display.
 * Removes **bold**, *italic*, __underline__, and other common markdown.
 *
 * @param {string} text - Text that may contain markdown
 * @returns {string} Clean text without markdown formatting
 */
export function stripMarkdown(text) {
    if (!text) return "";
    return text
        .replace(/\*\*([^*]+)\*\*/g, "$1") // **bold** -> bold
        .replace(/\*([^*]+)\*/g, "$1") // *italic* -> italic
        .replace(/__([^_]+)__/g, "$1") // __underline__ -> underline
        .replace(/_([^_]+)_/g, "$1") // _italic_ -> italic
        .replace(/~~([^~]+)~~/g, "$1") // ~~strikethrough~~ -> text
        .replace(/`([^`]+)`/g, "$1") // `code` -> code
        .replace(/#{1,6}\s*/g, "") // # headers -> remove #
        .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1") // [link](url) -> link
        .replace(/\n{2,}/g, " ") // Multiple newlines -> space
        .replace(/\n/g, " ") // Single newline -> space
        .trim();
}

// =============================================================================
// API TIME STRING PARSING
// =============================================================================

/**
 * Parse FreeAstrologyAPI time string format.
 * Handles: "{starts_at: 2023-03-20 07:52:14, ends_at: 2023-03-20 09:22:52}"
 *
 * @param {string} timeStr - Time string from API
 * @returns {object|null} Parsed time object or null
 */
export function parseApiTimeString(timeStr) {
    if (!timeStr || typeof timeStr !== "string") return null;

    try {
        // Try JSON parse first
        const jsonParsed = safeParseJson(timeStr);
        if (jsonParsed) return jsonParsed;

        // Parse the string format: "{starts_at: ..., ends_at: ...}"
        const cleaned = timeStr.trim().replace(/^\{|\}$/g, "");
        const parts = cleaned.split(/,/);
        const result = {};

        for (const part of parts) {
            const colonIndex = part.indexOf(":");
            if (colonIndex === -1) continue;

            const key = part.substring(0, colonIndex).trim();
            const value = part.substring(colonIndex + 1).trim();

            // Remove quotes if present
            const cleanValue = value.replace(/^["']|["']$/g, "");
            result[key] = cleanValue;
        }

        return Object.keys(result).length > 0 ? result : null;
    } catch {
        return null;
    }
}

// =============================================================================
// FIELD NAME NORMALIZATION
// =============================================================================

/**
 * Normalize dasha data to consistent camelCase field names.
 *
 * The astro API returns snake_case (`maha_dasha`, `antar_dasha`) but the
 * codebase and Firestore prefer camelCase (`mahadasha`, `antardasha`).
 * This helper eliminates the `x || y` fallback pattern scattered across
 * 10+ files. Call once when reading dasha data; downstream code uses
 * the normalized names.
 *
 * @param {Object} currentDasha - Raw dasha object from user profile
 * @returns {{ mahaDasha: string, antarDasha: string, pratyantarDasha: string|null, levels: Object }}
 */
export function normalizeDasha(currentDasha) {
    if (!currentDasha) {
        return { mahaDasha: "", antarDasha: "", pratyantarDasha: null, levels: {} };
    }
    return {
        mahaDasha: currentDasha.mahaDasha || currentDasha.mahadasha || currentDasha.maha_dasha || "",
        antarDasha: currentDasha.antarDasha || currentDasha.antardasha || currentDasha.antar_dasha || "",
        pratyantarDasha: currentDasha.levels?.pratyantar?.lord || null,
        levels: currentDasha.levels || {},
    };
}

/**
 * Resolve which dasha period is active RIGHT NOW from the stored timeline.
 *
 * Vimshottari dasha is fixed math from birth — the full timeline (`tree`) is
 * computed once and never changes. But the "current period" pointer
 * (mahadasha/antardasha + their dates) is only a SNAPSHOT taken at signup, and
 * nothing ever advances it. So a few months later the stored pointer names an
 * antardasha that has already ended → past-dated predictions.
 *
 * This walks the (static) timeline and returns the same dasha object with the
 * pointer fields refreshed to whatever period contains `now`. It's a handful of
 * date comparisons — no API call, no recompute. If there's no timeline to walk,
 * the original object is returned untouched (safe fallback).
 *
 * @param {Object} currentDasha - Stored dasha object (must contain `tree`)
 * @param {Date} [now] - Reference instant (defaults to current time)
 * @returns {Object} currentDasha with active maha/antar pointer fields
 */
export function resolveActiveDasha(currentDasha, now = new Date()) {
    const tree = currentDasha?.tree;
    if (!Array.isArray(tree) || tree.length === 0) return currentDasha;

    const within = (node) => {
        const start = new Date(node.startDate);
        const end = new Date(node.endDate);
        return !isNaN(start) && !isNaN(end) && start <= now && now < end;
    };

    const activeMaha = tree.find(within);
    if (!activeMaha) return currentDasha; // outside the computed range — leave as-is
    const activeAntar = (activeMaha.children || []).find(within) || null;

    return {
        ...currentDasha,
        mahadasha: activeMaha.lord,
        mahaStartDate: activeMaha.startDate,
        mahaEndDate: activeMaha.endDate,
        endDate: activeMaha.endDate,
        antardasha: activeAntar?.lord || null,
        antarStartDate: activeAntar?.startDate || null,
        antarEndDate: activeAntar?.endDate || null,
        levels: {
            ...(currentDasha.levels || {}),
            maha: { lord: activeMaha.lord, start: activeMaha.startDate, end: activeMaha.endDate },
            antar: activeAntar ?
                { lord: activeAntar.lord, start: activeAntar.startDate, end: activeAntar.endDate } :
                null,
            // Pratyantar isn't in the stored timeline, so the snapshot value is
            // unreliable once maha/antar have advanced — drop it rather than lie.
            pratyantar: null,
        },
    };
}

/**
 * Normalize core chart field names to consistent accessors.
 *
 * Handles the `ascendant/lagna`, `nakshatra/moonNakshatra`, and planet
 * degree field duality.
 *
 * @param {Object} astroData - User's astrologyData from Firestore
 * @returns {{ ascendant, moonSign, sunSign, nakshatra, currentDasha: normalized }}
 */
export function normalizeChart(astroData) {
    if (!astroData) {
        return {
            ascendant: "Unknown",
            moonSign: "Unknown",
            sunSign: "Unknown",
            nakshatra: "Unknown",
            currentDasha: normalizeDasha(null),
        };
    }
    return {
        ascendant: astroData.ascendant || astroData.lagna || "Unknown",
        moonSign: astroData.moonSign || "Unknown",
        sunSign: astroData.sunSign || "Unknown",
        nakshatra: astroData.nakshatra || astroData.moonNakshatra || "Unknown",
        currentDasha: normalizeDasha(astroData.currentDasha),
    };
}

/**
 * Normalize a planet position entry from the astro API.
 * Handles fullDegree/full_degree, zodiac_sign_name/sign, house_number/house duality.
 *
 * @param {Object} planetData - Raw planet entry from API
 * @returns {{ degree: number|null, sign: string, house: number|null, isRetro: boolean }}
 */
export function normalizePlanet(planetData) {
    if (!planetData || typeof planetData !== "object") {
        return { degree: null, sign: "Unknown", house: null, isRetro: false };
    }
    return {
        degree: planetData.fullDegree ?? planetData.full_degree ?? null,
        sign: planetData.zodiac_sign_name || planetData.sign || "Unknown",
        house: planetData.house_number ?? planetData.house ?? null,
        isRetro: planetData.isRetro === true || planetData.isRetro === "true",
    };
}
