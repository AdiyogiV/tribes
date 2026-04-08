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

/**
 * Truncate string to specified length with ellipsis
 * @param {string} str - String to truncate
 * @param {number} maxLength - Maximum length
 * @returns {string} Truncated string
 */
export function truncate(str, maxLength = 100) {
    if (!str || typeof str !== "string") return "";
    return str.length > maxLength ? str.substring(0, maxLength) + "..." : str;
}

/**
 * Capitalize first letter of a string
 * @param {string} str - String to capitalize
 * @returns {string} Capitalized string
 */
export function capitalize(str) {
    if (!str || typeof str !== "string") return "";
    return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
}

/**
 * Slugify a string (convert to lowercase, replace spaces with underscores)
 * @param {string} str - String to slugify
 * @returns {string} Slugified string
 */
export function slugify(str) {
    if (!str || typeof str !== "string") return "";
    return str.toLowerCase().replace(/\s+/g, "_").replace(/[^a-z0-9_]/g, "");
}

// =============================================================================
// JSON UTILITIES
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
// DATE/TIME UTILITIES
// =============================================================================

/**
 * Format date as YYYY-MM-DD
 * @param {Date} date - Date to format
 * @returns {string} Formatted date string
 */
export function formatDateYMD(date = new Date()) {
    return date.toISOString().split("T")[0];
}

/**
 * Get current month name and year
 * @param {Date} date - Date to use
 * @returns {{ month: string, year: number }} Month name and year
 */
export function getMonthYear(date = new Date()) {
    return {
        month: date.toLocaleString("en", { month: "long" }),
        year: date.getFullYear(),
    };
}

/**
 * Check if a timestamp is within the last N hours
 * @param {Date} timestamp - Timestamp to check
 * @param {number} hours - Number of hours
 * @returns {boolean} True if within the last N hours
 */
export function isWithinHours(timestamp, hours) {
    if (!timestamp) return false;
    const now = Date.now();
    const diff = now - timestamp.getTime();
    return diff < hours * 60 * 60 * 1000;
}

// =============================================================================
// ARRAY UTILITIES
// =============================================================================

/**
 * Remove duplicates from array
 * @param {Array} arr - Array to deduplicate
 * @returns {Array} Deduplicated array
 */
export function unique(arr) {
    return [...new Set(arr)];
}

/**
 * Chunk array into smaller arrays
 * @param {Array} arr - Array to chunk
 * @param {number} size - Chunk size
 * @returns {Array<Array>} Array of chunks
 */
export function chunk(arr, size) {
    const chunks = [];
    for (let i = 0; i < arr.length; i += size) {
        chunks.push(arr.slice(i, i + size));
    }
    return chunks;
}

/**
 * Safely get first element of array
 * @param {Array} arr - Array
 * @returns {*} First element or undefined
 */
export function first(arr) {
    return Array.isArray(arr) && arr.length > 0 ? arr[0] : undefined;
}

// =============================================================================
// OBJECT UTILITIES
// =============================================================================

/**
 * Deep merge objects (target object is mutated)
 * @param {object} target - Target object
 * @param {...object} sources - Source objects
 * @returns {object} Merged object
 */
export function deepMerge(target, ...sources) {
    if (!sources.length) return target;
    const source = sources.shift();

    if (isObject(target) && isObject(source)) {
        for (const key in source) {
            if (isObject(source[key])) {
                if (!target[key]) Object.assign(target, { [key]: {} });
                deepMerge(target[key], source[key]);
            } else {
                Object.assign(target, { [key]: source[key] });
            }
        }
    }

    return deepMerge(target, ...sources);
}

/**
 * Check if value is a plain object
 * @param {*} item - Value to check
 * @returns {boolean} True if plain object
 */
export function isObject(item) {
    return item && typeof item === "object" && !Array.isArray(item);
}

/**
 * Pick specified keys from object
 * @param {object} obj - Source object
 * @param {string[]} keys - Keys to pick
 * @returns {object} New object with picked keys
 */
export function pick(obj, keys) {
    if (!obj || typeof obj !== "object") return {};
    return keys.reduce((result, key) => {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
            result[key] = obj[key];
        }
        return result;
    }, {});
}

/**
 * Omit specified keys from object
 * @param {object} obj - Source object
 * @param {string[]} keys - Keys to omit
 * @returns {object} New object without omitted keys
 */
export function omit(obj, keys) {
    if (!obj || typeof obj !== "object") return {};
    const keysSet = new Set(keys);
    return Object.keys(obj).reduce((result, key) => {
        if (!keysSet.has(key)) {
            result[key] = obj[key];
        }
        return result;
    }, {});
}

// =============================================================================
// ERROR HANDLING UTILITIES
// Note: For error handling, prefer using lib/error_utils.js which provides:
//   - logAndThrow() - for critical operations
//   - logAndReturn() - for background tasks
//   - withErrorHandling() - wrapper with logging
// =============================================================================

/**
 * Retry function with exponential backoff
 * @param {Function} fn - Async function to retry
 * @param {object} options - Options { maxRetries, baseDelayMs, maxDelayMs }
 * @returns {*} Function result
 */
export async function retry(fn, { maxRetries = 3, baseDelayMs = 1000, maxDelayMs = 10000 } = {}) {
    let lastError;
    
    for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
            return await fn();
        } catch (error) {
            lastError = error;
            
            if (attempt < maxRetries - 1) {
                const delay = Math.min(baseDelayMs * Math.pow(2, attempt), maxDelayMs);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }
    
    throw lastError;
}

// =============================================================================
// FIRESTORE UTILITIES
// =============================================================================

/**
 * Convert Firestore timestamp to Date
 * @param {*} timestamp - Firestore timestamp or Date
 * @returns {Date|null} Date object or null
 */
export function firestoreToDate(timestamp) {
    if (!timestamp) return null;
    if (timestamp instanceof Date) return timestamp;
    if (typeof timestamp.toDate === "function") return timestamp.toDate();
    if (timestamp._seconds) return new Date(timestamp._seconds * 1000);
    return null;
}

/**
 * Batch Firestore writes
 * @param {Firestore} db - Firestore instance
 * @param {Array} operations - Array of { ref, data, type: 'set'|'update'|'delete' }
 * @param {number} batchSize - Max operations per batch (default 500)
 */
export async function batchWrite(db, operations, batchSize = 500) {
    const batches = chunk(operations, batchSize);
    
    for (const batchOps of batches) {
        const batch = db.batch();
        
        for (const op of batchOps) {
            switch (op.type) {
                case "set":
                    batch.set(op.ref, op.data, op.options || {});
                    break;
                case "update":
                    batch.update(op.ref, op.data);
                    break;
                case "delete":
                    batch.delete(op.ref);
                    break;
            }
        }
        
        await batch.commit();
    }
}

// =============================================================================
// VALIDATION UTILITIES
// =============================================================================

/**
 * Check if value is a non-empty string
 * @param {*} value - Value to check
 * @returns {boolean} True if non-empty string
 */
export function isNonEmptyString(value) {
    return typeof value === "string" && value.trim().length > 0;
}

/**
 * Check if value is a positive number
 * @param {*} value - Value to check
 * @returns {boolean} True if positive number
 */
export function isPositiveNumber(value) {
    return typeof value === "number" && !isNaN(value) && value > 0;
}

/**
 * Validate required fields in object
 * @param {object} obj - Object to validate
 * @param {string[]} requiredFields - Required field names
 * @returns {{ valid: boolean, missing: string[] }} Validation result
 */
export function validateRequired(obj, requiredFields) {
    const missing = requiredFields.filter(field => {
        const value = obj?.[field];
        return value === undefined || value === null || value === "";
    });
    
    return {
        valid: missing.length === 0,
        missing,
    };
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

