/**
 * Feed System - Cleanup helpers only.
 *
 * The trigger-based feed functions that used to live here
 * (`addPostToFeeds`, `addProfilePostToGlobalFeed`, `deletePostFromGlobalFeed`,
 * `deleteSpacePostFromGlobalFeed`) have all been merged into path-based
 * triggers under `functions/triggers/`:
 *
 *   - `posts/{postId}`                        → on_post_write.js
 *   - `spacePosts/{spaceId}/posts/{postId}`   → on_space_post_write.js
 *
 * The scheduled cleanup runner `runCleanupOrphanedFeedEntries` remains here
 * and is invoked by `unifiedOrchestrator` Phase 1 (Sunday-only branch).
 *
 * NEW ARCHITECTURE (2024):
 * - Single source of truth: posts/ collection
 * - Client queries posts/ directly using contextType + contextId
 * - No userFeed fanout needed - reduces complexity and write costs
 * - globalFeed maintained for discovery/guest users
 */

import { db, logger } from "../lib/firebase.js";
import { isPublicSpace } from "../lib/utils.js";

// ============================================================================
// CLEANUP FUNCTIONS - Maintain data integrity
// ============================================================================

/**
 * Clean up orphaned globalFeed entries where the referenced post no longer exists.
 * Invoked by unifiedOrchestrator on Sundays.
 */
export async function runCleanupOrphanedFeedEntries() {
    logger.info("🗑️ Starting orphaned feed entries cleanup", {
        structuredData: true,
        timestamp: new Date().toISOString(),
    });

    const BATCH_SIZE = 500;
    let deletedCount = 0;
    let checkedCount = 0;
    const refsToDelete = [];

    try {
        // Get all globalFeed entries
        const feedSnapshot = await db.collection("globalFeed").get();

        if (feedSnapshot.empty) {
            logger.info("No globalFeed entries to check");
            return { deletedCount: 0, checkedCount: 0 };
        }

        for (const feedDoc of feedSnapshot.docs) {
            checkedCount++;
            const feedData = feedDoc.data();
            const postId = feedData.postId || feedDoc.id;

            // Remove entries that belong to private spaces (privacy fix: they should never be in globalFeed)
            if (feedData.contextType === "space" && feedData.contextId) {
                const spaceDoc = await db.collection("spaces").doc(feedData.contextId).get();
                const spaceData = spaceDoc.data();
                if (spaceData && !isPublicSpace(spaceData)) {
                    refsToDelete.push(feedDoc.ref);
                    continue;
                }
            }

            // Check if the referenced post exists (orphaned)
            const postDoc = await db.collection("posts").doc(postId).get();

            if (!postDoc.exists) {
                if (feedData.contextType === "space" && feedData.contextId) {
                    const spacePostDoc = await db
                        .collection("spacePosts")
                        .doc(feedData.contextId)
                        .collection("posts")
                        .doc(postId)
                        .get();
                    if (!spacePostDoc.exists) refsToDelete.push(feedDoc.ref);
                } else {
                    refsToDelete.push(feedDoc.ref);
                }
            }
        }

        // Delete in batches
        for (let i = 0; i < refsToDelete.length; i += BATCH_SIZE) {
            const batch = db.batch();
            const chunk = refsToDelete.slice(i, i + BATCH_SIZE);
            chunk.forEach((ref) => batch.delete(ref));
            await batch.commit();
            deletedCount += chunk.length;
        }

        logger.info("✅ Orphaned and private-space feed entries cleanup completed", {
            structuredData: true,
            checkedCount,
            deletedCount,
            refsToDeleteCount: refsToDelete.length,
        });

        return { deletedCount, checkedCount };
    } catch (error) {
        logger.error("❌ Orphaned feed cleanup failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
            checkedCount,
            deletedCount,
        });
        throw error;
    }
}
