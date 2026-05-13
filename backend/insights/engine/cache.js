/**
 * Cache — read-through caching abstraction for insight flavors.
 *
 * Wraps Firestore with a tiny consistent interface. Each flavor declares its
 * own cache key + TTL; the engine handles the rest. Bumping CACHE_VERSION
 * invalidates all cached entries automatically.
 *
 * Storage location: `insightsCache` collection, doc id = `<version>:<key>`.
 * For per-user readings, prefer storing the actual result on the user doc
 * (via flavor.store()); cache here is for "did we already generate this?"
 * dedupe and short-lived intermediates.
 */

import { db, logger } from "../../lib/firebase.js";
import { DateTime } from "luxon";

const COLLECTION = "insightsCache";

// Bump when prompts or output schemas change in a way that invalidates
// cached results. Old entries are ignored (and lazily replaced) automatically.
export const CACHE_VERSION = "v1";

/**
 * Build a versioned, Firestore-safe doc id from a flavor cache key.
 */
function docId(key) {
    return `${CACHE_VERSION}:${key}`.replace(/[/]/g, ":").replace(/\s+/g, "_");
}

/**
 * Read a cached value if present and not expired.
 *
 * @param {string} key       - Flavor-supplied cache key
 * @param {number} ttlHours  - Time-to-live in hours; <=0 means never expires
 * @returns {Promise<Object|null>} Cached `value` or null on miss/expired/error
 */
export async function getCached(key, ttlHours) {
    if (!key) return null;
    try {
        const snap = await db.collection(COLLECTION).doc(docId(key)).get();
        if (!snap.exists) return null;

        const data = snap.data();
        const cachedAt = data.cachedAt?.toDate?.() || new Date(data.cachedAt);
        if (!cachedAt || isNaN(cachedAt.getTime())) return null;

        if (ttlHours > 0) {
            const hoursOld = DateTime.now().diff(
                DateTime.fromJSDate(cachedAt),
                "hours",
            ).hours;
            if (hoursOld >= ttlHours) {
                // Expired — fire-and-forget delete; don't block the caller.
                snap.ref.delete().catch(() => {});
                return null;
            }
        }

        return data.value ?? null;
    } catch (error) {
        logger.warn("Cache read failed", {
            structuredData: true,
            key,
            error: String(error?.message || error),
        });
        return null;
    }
}

/**
 * Write a value to the cache. Errors are swallowed (cache failures should
 * never break the calling flow).
 *
 * @param {string} key       - Flavor-supplied cache key
 * @param {Object} value     - Anything JSON-serializable
 * @param {number} ttlHours  - Used for cleanup heuristics; <=0 for permanent
 */
export async function setCached(key, value, ttlHours) {
    if (!key || value === undefined || value === null) return;
    try {
        await db.collection(COLLECTION).doc(docId(key)).set({
            value,
            cachedAt: new Date(),
            ttlHours: ttlHours || 24,
            version: CACHE_VERSION,
        });
    } catch (error) {
        logger.warn("Cache write failed", {
            structuredData: true,
            key,
            error: String(error?.message || error),
        });
    }
}

/**
 * Force-invalidate a single cache entry. Useful when a user changes birth
 * data or a flavor explicitly wants to regenerate.
 */
export async function invalidateCached(key) {
    if (!key) return;
    try {
        await db.collection(COLLECTION).doc(docId(key)).delete();
    } catch (error) {
        logger.warn("Cache invalidate failed", {
            structuredData: true,
            key,
            error: String(error?.message || error),
        });
    }
}
