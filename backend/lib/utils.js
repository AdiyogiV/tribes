/**
 * Shared utility functions for the Tribes backend
 * Common helpers used across multiple modules
 */

import { logger } from "./firebase.js";

// =============================================================================
// STRING UTILITIES
// =============================================================================

/**
 * Get ordinal suffix for a number (1st, 2nd, 3rd, 4th, etc.)
 * @param {number} n - The number
 * @returns {string} Number with ordinal suffix
 */
export function getOrdinal(n) {
    const num = parseInt(n, 10);
    if (isNaN(num)) return String(n);

    const s = ["th", "st", "nd", "rd"];
    const v = num % 100;
    return num + (s[(v - 20) % 10] || s[v] || s[0]);
}

// =============================================================================
// JSON UTILITIES
// Used by: lib/astro_helpers.js, functions/astro_api.js
// =============================================================================

/**
 * Safely parse JSON, returning null on error
 * @param {string} value - JSON string to parse
 * @returns {object|null} Parsed object or null
 */
export function safeParseJson(value) {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    try {
        return JSON.parse(trimmed);
    } catch {
        return null;
    }
}

/**
 * Unwrap nested JSON output (common in API responses)
 * @param {*} input - Input to unwrap
 * @param {object} options - Options { maxDepth: number }
 * @returns {object|null} Unwrapped object or null
 */
export function unwrapJsonOutput(input, { maxDepth = 3 } = {}) {
    let current = input;
    for (let depth = 0; depth < maxDepth; depth += 1) {
        if (current == null) break;

        if (typeof current === "string") {
            const parsed = safeParseJson(current);
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
}

// =============================================================================
// BLOCKING / PRIVACY UTILITIES
// =============================================================================

/**
 * Check if either user has blocked the other.
 * Returns a simple boolean — use checkBlockedDetailed() when you need to
 * know *who* blocked *whom*.
 *
 * @param {Firestore} db - Firestore instance
 * @param {string} userId1
 * @param {string} userId2
 * @returns {Promise<boolean>}
 */
export async function isBlockedEitherWay(db, userId1, userId2) {
    try {
        const [u1BlockedU2, u2BlockedU1] = await Promise.all([
            db.collection("blocks").doc(userId1).collection("blocked").doc(userId2).get(),
            db.collection("blocks").doc(userId2).collection("blocked").doc(userId1).get(),
        ]);
        return u1BlockedU2.exists || u2BlockedU1.exists;
    } catch (error) {
        logger.warn("Error checking block status", {
            userId1,
            userId2,
            error: error.message,
        });
        return false;
    }
}

/**
 * Detailed block check — returns who blocked whom.
 *
 * @param {Firestore} db - Firestore instance
 * @param {string} userId1
 * @param {string} userId2
 * @returns {Promise<{isBlocked: boolean, blockerIsUser1: boolean, blockerIsUser2: boolean}>}
 */
export async function checkBlockedDetailed(db, userId1, userId2) {
    try {
        const [u1BlockedU2, u2BlockedU1] = await Promise.all([
            db.collection("blocks").doc(userId1).collection("blocked").doc(userId2).get(),
            db.collection("blocks").doc(userId2).collection("blocked").doc(userId1).get(),
        ]);
        return {
            isBlocked: u1BlockedU2.exists || u2BlockedU1.exists,
            blockerIsUser1: u1BlockedU2.exists,
            blockerIsUser2: u2BlockedU1.exists,
        };
    } catch (error) {
        logger.warn("Error checking block status", {
            userId1,
            userId2,
            error: error.message,
        });
        return { isBlocked: false, blockerIsUser1: false, blockerIsUser2: false };
    }
}

// =============================================================================
// TEXT MODERATION UTILITIES
// =============================================================================

/** Terms that should be blocked in user-generated content. */
const BLOCKLIST = ["kill yourself", "kys", "suicide"];

/**
 * Normalize text for comparison (trim + lowercase).
 * @param {string} text
 * @returns {string}
 */
export function normalizeText(text) {
    return (text || "").trim().toLowerCase();
}

/**
 * Check whether text contains any blocked/harmful terms.
 * @param {string} text
 * @returns {boolean}
 */
export function containsBlockedText(text) {
    if (!text) return false;
    const normalized = normalizeText(text);
    return BLOCKLIST.some((term) => normalized.includes(term));
}

// =============================================================================
// SPACE VISIBILITY UTILITIES
// =============================================================================

/**
 * Determine if a space is publicly visible in feeds.
 * @param {object} spaceData - Firestore space document data
 * @returns {boolean}
 */
export function isPublicSpace(spaceData) {
    if (!spaceData) return false;
    if (spaceData.limitedVisibility === true) return false;
    if (spaceData.isProfileGram === true) return true;

    // Delegate to constants for type-based check
    // Importing inline to avoid circular dependency at module level
    return [0, 1].includes(spaceData.spaceType);
}

