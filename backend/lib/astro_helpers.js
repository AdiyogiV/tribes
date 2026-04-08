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
