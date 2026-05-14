import { db, logger } from "../lib/firebase.js";
import { DateTime } from "luxon";

/**
 * Cache utilities for astrology predictions
 * Implements multi-layer caching strategy:
 * 
 * 1. STATIC KNOWLEDGE (Cache Forever - astroKnowledge collection)
 *    - Lagna meanings, Moon sign meanings
 *    - Nakshatra meanings, Tithi meanings, Yoga meanings
 *    - Dasha interpretations (81 combos × 4 areas)
 *    - Transit meanings (108 combos)
 *    - Planet remedies, House meanings
 * 
 * 2. CURRENT DATA (Cache 1-30 days - astroCurrent collection)
 *    - Daily: Today's astrological weather (1 day)
 *    - Weekly: Weekly predictions, retrogrades (7 days)
 *    - Monthly: Monthly predictions, festivals, eclipses (30 days)
 * 
 * 3. LOCATION DATA (Cache 24h - astroCache collection)
 *    - Transits, panchang for specific location
 * 
 * 4. AI INSIGHTS (Cache 24h - astroCache collection)
 *    - Generated insights per chart signature
 * 
 * CACHE VERSION: Bump this when making significant prompt/format changes
 * This invalidates all AI insight caches automatically
 */

// ⚠️ BUMP THIS when you change AI prompts, card formats, or insight structure
// v4: Fixed AI copying example text ("Strategic negotiation", "Dominant influence")
// v5: Simplified to 4 cards (removed timing), more future-focused prompt
// v6: Fixed strength card data format (planet/strength -> name/value to match frontend)
// v7: Simplified to 3 essential cards (hero, prediction, guidance) - removed strength/timing
const CACHE_VERSION = "v7";

const CACHE_COLLECTION = "astroCache";
const KNOWLEDGE_COLLECTION = "astroKnowledge";
const CURRENT_COLLECTION = "astroCurrent";

const SEARCH_CACHE_TTL_HOURS = 12;

// TTL constants for different cache tiers
const TTL_FOREVER = -1; // Never expires
const TTL_WEEKLY = 168; // 7 days in hours


/**
 * Get cached Google Search context for a date
 * Returns null if cache miss or expired
 */
export async function getCachedSearchContext(date) {
    try {
        // Use colon instead of slash to avoid Firestore path issues
        const cacheKey = `astro-context:${date}`;
        const cacheDoc = await db.collection(CACHE_COLLECTION).doc(cacheKey).get();

        if (!cacheDoc.exists) {
            return null;
        }

        const cacheData = cacheDoc.data();
        const cachedAt = cacheData.cachedAt?.toDate();
        if (!cachedAt) return null;

        const hoursSinceCache = DateTime.now().diff(DateTime.fromJSDate(cachedAt), "hours").hours;
        if (hoursSinceCache >= SEARCH_CACHE_TTL_HOURS) {
            // Cache expired, delete it
            await cacheDoc.ref.delete();
            return null;
        }

        logger.info("Cache hit for search context", {
            structuredData: true,
            cacheKey,
            hoursSinceCache: Math.round(hoursSinceCache * 10) / 10,
        });

        return cacheData.data;
    } catch (error) {
        logger.warn("Error checking search cache", {
            structuredData: true,
            error: String(error),
        });
        return null;
    }
}

/**
 * Cache Google Search context for a date
 */
export async function cacheSearchContext(date, context) {
    try {
        // Use colon instead of slash to avoid Firestore path issues
        const cacheKey = `astro-context:${date}`;
        await db.collection(CACHE_COLLECTION).doc(cacheKey).set({
            data: context,
            cachedAt: new Date(),
            ttlHours: SEARCH_CACHE_TTL_HOURS,
        });

        logger.info("Cached search context", {
            structuredData: true,
            cacheKey,
        });
    } catch (error) {
        logger.warn("Error caching search context", {
            structuredData: true,
            error: String(error),
        });
    }
}

// =============================================================================
// STATIC KNOWLEDGE CACHE (Forever - astroKnowledge collection)
// =============================================================================

/**
 * Get cached static astrological knowledge (never expires)
 * @param {string} category - Category: lagna, moonSign, nakshatra, tithi, yoga, dasha, transit, remedy, house, retrograde
 * @param {string} key - Specific key within category
 */
export async function getCachedAstroKnowledge(category, key) {
    try {
        if (!category || !key) return null;

        const docPath = `${category}:${key}`.replace(/\s+/g, "_").toLowerCase();
        const cacheDoc = await db.collection(KNOWLEDGE_COLLECTION).doc(docPath).get();

        if (!cacheDoc.exists) {
            return null;
        }

        logger.info("Cache hit for astro knowledge", {
            structuredData: true,
            category,
            key,
        });

        return cacheDoc.data();
    } catch (error) {
        logger.warn("Error checking astro knowledge cache", {
            structuredData: true,
            category,
            key,
            error: String(error),
        });
        return null;
    }
}

/**
 * Cache static astrological knowledge (never expires)
 * @param {string} category - Category: lagna, moonSign, nakshatra, tithi, yoga, dasha, transit, remedy, house, retrograde
 * @param {string} key - Specific key within category
 * @param {object} data - Data to cache
 */
export async function cacheAstroKnowledge(category, key, data) {
    try {
        if (!category || !key || !data) return;

        const docPath = `${category}:${key}`.replace(/\s+/g, "_").toLowerCase();
        await db.collection(KNOWLEDGE_COLLECTION).doc(docPath).set({
            ...data,
            category,
            key,
            cachedAt: new Date(),
            ttl: TTL_FOREVER, // Never expires
        });

        logger.info("Cached astro knowledge", {
            structuredData: true,
            category,
            key,
        });
    } catch (error) {
        logger.warn("Error caching astro knowledge", {
            structuredData: true,
            category,
            key,
            error: String(error),
        });
    }
}

// =============================================================================
// CURRENT DATA CACHE (1-30 days - astroCurrent collection)
// =============================================================================

/**
 * Get cached current astrological data (with TTL)
 * @param {string} category - Category: global, daily, weekly, monthly, retrogrades, festivals
 * @param {string} key - Specific key (usually date-based)
 */
export async function getCachedAstroCurrent(category, key) {
    try {
        if (!category || !key) return null;

        const docPath = `${category}:${key}`.replace(/\s+/g, "_").toLowerCase();
        const cacheDoc = await db.collection(CURRENT_COLLECTION).doc(docPath).get();

        if (!cacheDoc.exists) {
            return null;
        }

        const cacheData = cacheDoc.data();
        const cachedAt = cacheData.cachedAt?.toDate?.() || new Date(cacheData.cachedAt);
        if (!cachedAt || isNaN(cachedAt.getTime())) return null;

        // Check TTL
        const ttlHours = cacheData.ttlHours || TTL_WEEKLY;
        const hoursSinceCache = DateTime.now().diff(DateTime.fromJSDate(cachedAt), "hours").hours;
        
        if (hoursSinceCache >= ttlHours) {
            // Cache expired, delete it
            await cacheDoc.ref.delete();
            return null;
        }

        logger.info("Cache hit for astro current", {
            structuredData: true,
            category,
            key,
            hoursSinceCache: Math.round(hoursSinceCache * 10) / 10,
        });

        return cacheData;
    } catch (error) {
        logger.warn("Error checking astro current cache", {
            structuredData: true,
            category,
            key,
            error: String(error),
        });
        return null;
    }
}

/**
 * Cache current astrological data (with TTL)
 * @param {string} category - Category: global, daily, weekly, monthly, retrogrades, festivals
 * @param {string} key - Specific key (usually date-based)
 * @param {object} data - Data to cache
 * @param {number} ttlDays - Time to live in days (1, 7, or 30)
 */
export async function cacheAstroCurrent(category, key, data, ttlDays = 7) {
    try {
        if (!category || !key || !data) return;

        const docPath = `${category}:${key}`.replace(/\s+/g, "_").toLowerCase();
        const ttlHours = ttlDays * 24;
        
        await db.collection(CURRENT_COLLECTION).doc(docPath).set({
            ...data,
            category,
            key,
            cachedAt: new Date(),
            ttlHours,
            ttlDays,
        });

        logger.info("Cached astro current", {
            structuredData: true,
            category,
            key,
            ttlDays,
        });
    } catch (error) {
        logger.warn("Error caching astro current", {
            structuredData: true,
            category,
            key,
            error: String(error),
        });
    }
}

// =============================================================================
// CACHE STATISTICS & CLEANUP
// =============================================================================

/**
 * Get cache statistics
 */
export async function getCacheStats() {
    try {
        const [knowledgeSnap, currentSnap, cacheSnap] = await Promise.all([
            db.collection(KNOWLEDGE_COLLECTION).count().get(),
            db.collection(CURRENT_COLLECTION).count().get(),
            db.collection(CACHE_COLLECTION).count().get(),
        ]);

        return {
            knowledgeEntries: knowledgeSnap.data().count,
            currentEntries: currentSnap.data().count,
            cacheEntries: cacheSnap.data().count,
            timestamp: new Date().toISOString(),
        };
    } catch (error) {
        logger.warn("Error getting cache stats", {
            structuredData: true,
            error: String(error),
        });
        return null;
    }
}

/**
 * Clean up expired cache entries
 */
export async function cleanupExpiredCache() {
    try {
        const now = DateTime.now();
        let deletedCount = 0;

        // Clean up astroCurrent collection
        const currentDocs = await db.collection(CURRENT_COLLECTION).get();
        const batch = db.batch();
        
        for (const doc of currentDocs.docs) {
            const data = doc.data();
            const cachedAt = data.cachedAt?.toDate?.() || new Date(data.cachedAt);
            const ttlHours = data.ttlHours || TTL_WEEKLY;
            
            if (cachedAt && !isNaN(cachedAt.getTime())) {
                const hoursSinceCache = now.diff(DateTime.fromJSDate(cachedAt), "hours").hours;
                if (hoursSinceCache >= ttlHours) {
                    batch.delete(doc.ref);
                    deletedCount++;
                }
            }
        }

        // Clean up astroCache collection
        const cacheDocs = await db.collection(CACHE_COLLECTION).get();
        
        for (const doc of cacheDocs.docs) {
            const data = doc.data();
            const cachedAt = data.cachedAt?.toDate?.() || new Date(data.cachedAt);
            const ttlHours = data.ttlHours || 24;
            
            if (cachedAt && !isNaN(cachedAt.getTime())) {
                const hoursSinceCache = now.diff(DateTime.fromJSDate(cachedAt), "hours").hours;
                if (hoursSinceCache >= ttlHours) {
                    batch.delete(doc.ref);
                    deletedCount++;
                }
            }
        }

        if (deletedCount > 0) {
            await batch.commit();
        }

        logger.info("Cache cleanup completed", {
            structuredData: true,
            deletedCount,
        });

        return { deletedCount };
    } catch (error) {
        logger.error("Error during cache cleanup", {
            structuredData: true,
            error: String(error),
        });
        return { deletedCount: 0, error: String(error) };
    }
}

// =============================================================================
// CACHE CLEARING UTILITIES
// =============================================================================

/**
 * Clear ALL cache entries (nuclear option)
 * Use when making major system changes
 * OPTIMIZED: Uses batched writes (max 500 per batch)
 */
export async function clearAllCaches() {
    const BATCH_SIZE = 500;
    try {
        let deletedCount = 0;
        
        // Clear astroCache collection in batches
        const cacheDocs = await db.collection(CACHE_COLLECTION).get();
        for (let i = 0; i < cacheDocs.docs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            const chunk = cacheDocs.docs.slice(i, i + BATCH_SIZE);
            chunk.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
            deletedCount += chunk.length;
        }
        
        // Clear astroCurrent collection in batches
        const currentDocs = await db.collection(CURRENT_COLLECTION).get();
        for (let i = 0; i < currentDocs.docs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            const chunk = currentDocs.docs.slice(i, i + BATCH_SIZE);
            chunk.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
            deletedCount += chunk.length;
        }
        
        logger.info("🗑️ All caches cleared", {
            structuredData: true,
            deletedCount,
            collections: [CACHE_COLLECTION, CURRENT_COLLECTION],
        });
        
        return { deletedCount, success: true };
    } catch (error) {
        logger.error("Error clearing all caches", {
            structuredData: true,
            error: String(error),
        });
        return { deletedCount: 0, success: false, error: String(error) };
    }
}


/**
 * Clear AI insight caches only (preserves transit/location caches)
 * Use when changing AI prompts or insight formats
 * OPTIMIZED: Uses batched writes (max 500 per batch)
 */
export async function clearAIInsightCaches() {
    const BATCH_SIZE = 500;
    try {
        let deletedCount = 0;

        const cacheDocs = await db.collection(CACHE_COLLECTION).get();
        const aiInsightDocs = cacheDocs.docs.filter((doc) => doc.id.startsWith("ai-insights:"));

        for (let i = 0; i < aiInsightDocs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            const chunk = aiInsightDocs.slice(i, i + BATCH_SIZE);
            chunk.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
            deletedCount += chunk.length;
        }

        logger.info("AI insight caches cleared", {
            structuredData: true,
            deletedCount,
        });

        return { deletedCount, success: true };
    } catch (error) {
        logger.error("Error clearing AI insight caches", {
            structuredData: true,
            error: String(error),
        });
        return { deletedCount: 0, success: false, error: String(error) };
    }
}

/**
 * Clear old versioned caches (keeps only current version)
 * Run after bumping CACHE_VERSION to clean up old entries
 * OPTIMIZED: Uses batched writes (max 500 per batch)
 */
export async function clearOldVersionedCaches() {
    const BATCH_SIZE = 500;
    try {
        let deletedCount = 0;

        const cacheDocs = await db.collection(CACHE_COLLECTION).get();
        const oldVersionDocs = cacheDocs.docs.filter((doc) =>
            doc.id.startsWith("ai-insights:") && !doc.id.includes(`:${CACHE_VERSION}:`)
        );

        for (let i = 0; i < oldVersionDocs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            const chunk = oldVersionDocs.slice(i, i + BATCH_SIZE);
            chunk.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
            deletedCount += chunk.length;
        }

        logger.info("Old versioned caches cleared", {
            structuredData: true,
            deletedCount,
            currentVersion: CACHE_VERSION,
        });

        return { deletedCount, success: true, currentVersion: CACHE_VERSION };
    } catch (error) {
        logger.error("Error clearing old versioned caches", {
            structuredData: true,
            error: String(error),
        });
        return { deletedCount: 0, success: false, error: String(error) };
    }
}

/**
 * Get current cache version
 */
export function getCacheVersion() {
    return CACHE_VERSION;
}

