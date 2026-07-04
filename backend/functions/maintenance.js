// maintenance.js — cache + housekeeping operations for the astrology pipeline.
//
// These are cross-cutting maintenance concerns (cache clearing, expired-entry
// sweeps, old dispatch-record pruning). They used to live inside
// daily_astro_insights.js, which conflated "generate the horoscope" with
// "keep the database tidy". Extracted here so each file has one job.
//
// Wiring:
//   - handleClearAstroCaches       → insightGateway (admin onCall method)
//   - runCleanupOldDispatchEntries → unifiedOrchestrator Phase 1
//   - runCleanupExpiredCacheEntries→ unifiedOrchestrator Phase 1

import { HttpsError } from "firebase-functions/v2/https";
import { db, logger } from "../lib/firebase.js";
import { DateTime } from "luxon";
import {
    getCacheStats,
    clearAllCaches,
    clearAIInsightCaches,
    clearOldVersionedCaches,
    getCacheVersion,
    cleanupExpiredCache,
} from "../lib/cache_utils.js";

/**
 * Admin function to clear caches.
 * Call with: { mode: "all" | "ai" | "old" }
 * - all: Clear ALL caches (nuclear option)
 * - ai:  Clear only AI insight caches
 * - old: Clear only old versioned caches (keeps current version)
 */
export async function handleClearAstroCaches(request) {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new HttpsError("unauthenticated", "Must be logged in");
    }

    const mode = request.data?.mode || "old";

    logger.info(" Cache clear requested", {
        structuredData: true,
        userId,
        mode,
        cacheVersion: getCacheVersion(),
    });

    let result;
    switch (mode) {
    case "all":
        result = await clearAllCaches();
        break;
    case "ai":
        result = await clearAIInsightCaches();
        break;
    case "old":
    default:
        result = await clearOldVersionedCaches();
        break;
    }

    const stats = await getCacheStats();

    return {
        ...result,
        cacheVersion: getCacheVersion(),
        stats,
    };
}

/**
 * CLEANUP: Remove old insightDispatch entries.
 * Keeps last 7 days of dispatch data for debugging.
 * Invoked by unifiedOrchestrator Phase 1.
 */
export async function runCleanupOldDispatchEntries() {
    const now = DateTime.now().setZone("Asia/Kolkata");
    const cutoffDate = now.minus({ days: 7 }).toFormat("yyyy-MM-dd");

    logger.info(" Starting insightDispatch cleanup", {
        structuredData: true,
        cutoffDate,
        currentDate: now.toFormat("yyyy-MM-dd"),
    });

    try {
        // Get all date documents older than cutoff
        const dispatchDocs = await db.collection("insightDispatch").get();

        let deletedDates = 0;
        let deletedEntries = 0;

        for (const dateDoc of dispatchDocs.docs) {
            const dateKey = dateDoc.id;

            // Skip dates newer than cutoff
            if (dateKey >= cutoffDate) {
                continue;
            }

            // Delete all time slot subcollections for this date
            const timeSlots = ["0600", "1200", "1700", "2100"];
            for (const slot of timeSlots) {
                const entriesSnapshot = await db
                    .collection("insightDispatch")
                    .doc(dateKey)
                    .collection(slot)
                    .get();

                if (!entriesSnapshot.empty) {
                    const batch = db.batch();
                    entriesSnapshot.docs.forEach((doc) => {
                        batch.delete(doc.ref);
                        deletedEntries++;
                    });
                    await batch.commit();
                }
            }

            // Delete the date document itself
            await dateDoc.ref.delete();
            deletedDates++;
        }

        logger.info(" insightDispatch cleanup completed", {
            structuredData: true,
            deletedDates,
            deletedEntries,
            cutoffDate,
        });

        return { success: true, deletedDates, deletedEntries };
    } catch (error) {
        logger.error(" insightDispatch cleanup failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
}

/**
 * CLEANUP: Remove expired cache entries from astroCache and astroCurrent
 * collections. Invoked by unifiedOrchestrator Phase 1.
 */
export async function runCleanupExpiredCacheEntries() {
    logger.info(" Starting expired cache cleanup", {
        structuredData: true,
        timestamp: DateTime.now().setZone("Asia/Kolkata").toISO(),
    });

    try {
        const result = await cleanupExpiredCache();

        logger.info(" Cache cleanup completed", {
            structuredData: true,
            deletedCount: result.deletedCount,
        });

        return result;
    } catch (error) {
        logger.error(" Cache cleanup failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
}
