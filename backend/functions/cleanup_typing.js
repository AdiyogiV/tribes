import { db, logger } from "../lib/firebase.js";

/**
 * Scheduled function to clean up stale typing indicators.
 *
 * WHY ONCE PER DAY IS ENOUGH:
 * The Flutter client already filters out typing docs older than 10 seconds
 * (see chat_presence.dart line 88-96). Orphaned docs are invisible to users.
 * This function only exists to prevent the `typing` collection from growing
 * endlessly with dead documents — a housekeeping task, not a real-time one.
 *
 * COST IMPACT:
 * Old: every 1 minute = 43,200 invocations/month (~₹10-15/month wasted)
 * New: once per day   = 30 invocations/month (~₹0)
 *
 * FUTURE: Replace entirely with a Firestore TTL policy on the `typing`
 * collection (auto-delete docs where expiresAt < now) — zero functions needed.
 */
/** Extracted runner for orchestrator consolidation. */
export async function runCleanupTypingIndicators() {
    try {
        // Delete typing documents older than 1 minute (generous cutoff for daily cleanup)
        const cutoff = new Date(Date.now() - 60000); // 1 minute ago

        let totalDeleted = 0;
        let hasMore = true;

        // Paginated cleanup — may have accumulated docs over 24 hours
        while (hasMore) {
            const expiredDocs = await db
                .collection("typing")
                .where("updatedAt", "<", cutoff)
                .limit(500) // Firestore batch limit
                .get();

            if (expiredDocs.empty) {
                hasMore = false;
                break;
            }

            const batch = db.batch();
            expiredDocs.docs.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();

            totalDeleted += expiredDocs.size;
            hasMore = expiredDocs.size === 500; // More pages if we hit the limit
        }

        if (totalDeleted > 0) {
            logger.info("Cleaned up stale typing indicators", {
                structuredData: true,
                count: totalDeleted,
            });
        }
    } catch (error) {
        logger.error("Error cleaning up typing indicators", {
            structuredData: true,
            error: error.message,
        });
    }
}

// NOTE: `cleanupTypingIndicators` was a standalone `onSchedule` export.
// It is now invoked by `unifiedOrchestrator` Phase 1 (cleanup) via the
// `runCleanupTypingIndicators` runner above.
