import { onCall } from "firebase-functions/v2/https";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";
import { validateRequest } from "../lib/schemas.js";
import { z } from "zod";
import { SPACE_TYPES } from "../lib/constants.js";
import { isPublicSpace } from "../lib/utils.js";

// =============================================================================
// SCHEMAS
// =============================================================================

const CreateRepostSchema = z.object({
    originalPostId: z.string().min(1),
    contextType: z.enum(["profile", "space"]),
    contextId: z.string().nullish(), // Can be null or undefined for profile reposts (nullish = nullable + optional)
});

const DeleteRepostSchema = z.object({
    repostId: z.string().min(1),
});

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Get original post (handles both profile and space posts)
 * @param {string} postId - Original post ID
 * @param {string} contextType - "profile" or "space"
 * @param {string} [spaceId] - Space ID if contextType is "space"
 * @returns {Promise<{id: string, ...data} | null>}
 */
async function getOriginalPost(postId, contextType, spaceId = null) {
    try {
        if (contextType === "profile") {
            const doc = await db.collection("posts").doc(postId).get();
            if (!doc.exists) return null;
            return { id: doc.id, ...doc.data() };
        } else if (contextType === "space" && spaceId) {
            const doc = await db
                .collection("spaces")
                .doc(spaceId)
                .collection("posts")
                .doc(postId)
                .get();
            if (!doc.exists) {
                // Fallback: try top-level posts collection
                const fallbackDoc = await db.collection("posts").doc(postId).get();
                if (!fallbackDoc.exists) return null;
                return { id: fallbackDoc.id, ...fallbackDoc.data() };
            }
            return { id: doc.id, ...doc.data() };
        } else {
            // Try top-level posts collection as fallback
            const doc = await db.collection("posts").doc(postId).get();
            if (!doc.exists) return null;
            return { id: doc.id, ...doc.data() };
        }
    } catch (error) {
        logger.error("Error getting original post", {
            structuredData: true,
            error: error.message,
            postId,
            contextType,
        });
        return null;
    }
}

/**
 * Validate repost permissions
 * @param {string} reposterId - User ID of reposter
 * @param {object} originalPost - Original post data
 * @param {string} targetContextType - Where repost is going ("profile" or "space")
 * @param {string} [targetContextId] - Target space ID if reposting to space
 */
async function validateRepostPermissions(reposterId, originalPost, targetContextType, targetContextId = null) {
    // Check if original post exists
    if (!originalPost) {
        throw new HttpsError("not-found", "Original post not found");
    }

    // IMPORTANT: Reply posts are always treated as profile posts for repost permissions
    // Even if they have contextType="space" or a space field, replies are user-generated
    // content that should be repostable based on author privacy, not space privacy
    // Check for replyTo field (can be null, empty string, or missing - all mean "not a reply")
    const replyToValue = originalPost.replyTo;
    const isReply = replyToValue != null && replyToValue !== "" && String(replyToValue).trim() !== "";
    const effectiveContextType = isReply ? "profile" : (originalPost.contextType || "profile");

    // Log for debugging
    logger.info("Repost permission check", {
        structuredData: true,
        originalPostId: originalPost.id || originalPost.originalPostId,
        originalContextType: originalPost.contextType,
        replyTo: replyToValue,
        isReply,
        effectiveContextType,
        reposterId,
    });

    // Validate original post privacy
    if (effectiveContextType === "profile") {
        const authorDoc = await db.collection("users").doc(originalPost.author).get();
        const authorData = authorDoc.data();

        if (authorData?.isPrivateProfile === true) {
            // Check if reposter follows author
            const followsDoc = await db
                .collection("follows")
                .doc(reposterId)
                .collection("following")
                .doc(originalPost.author)
                .get();

            if (!followsDoc.exists) {
                throw new HttpsError("permission-denied", "Cannot repost private profile content");
            }
        }
    } else if (effectiveContextType === "space") {
        const spaceDoc = await db.collection("spaces").doc(originalPost.space || originalPost.contextId).get();
        const spaceData = spaceDoc.data();

        if (!isPublicSpace(spaceData)) {
            // Check if reposter is member
            const members = spaceData?.members || [];
            if (!members.includes(reposterId)) {
                throw new HttpsError("permission-denied", "Cannot repost private space content");
            }
        }
    }

    // Validate target context permissions
    if (targetContextType === "space" && targetContextId) {
        const targetSpaceDoc = await db.collection("spaces").doc(targetContextId).get();
        const targetSpaceData = targetSpaceDoc.data();

        if (!targetSpaceData) {
            throw new HttpsError("not-found", "Target space not found");
        }

        const members = targetSpaceData.members || [];
        if (!members.includes(reposterId)) {
            throw new HttpsError("permission-denied", "Not a member of target space");
        }
    }

    // Check for duplicate repost
    // Use originalPost.id (from getOriginalPost) or fallback to originalPost.originalPostId
    const postIdToCheck = originalPost.id || originalPost.originalPostId;
    if (!postIdToCheck) {
        throw new HttpsError("invalid-argument", "Original post ID is missing");
    }

    // Query for potential duplicates (get multiple to filter by contextId)
    let duplicateQuery = db.collection("reposts")
        .where("reposterId", "==", reposterId)
        .where("originalPostId", "==", postIdToCheck)
        .where("contextType", "==", targetContextType)
        .limit(10); // Get multiple to filter by contextId

    const existingReposts = await duplicateQuery.get();

    // Filter by contextId in memory (more reliable than Firestore null handling)
    const isDuplicate = existingReposts.docs.some((doc) => {
        const data = doc.data();
        const docContextId = data.contextId || null;
        const targetContextIdValue = targetContextId || null;
        return docContextId === targetContextIdValue;
    });

    if (isDuplicate) {
        throw new HttpsError("already-exists", "User already reposted this post");
    }
}

/**
 * Atomically increment repost count on original post
 */
async function incrementRepostCount(originalPostId, originalPost, contextType) {
    const updateData = {
        repostCount: FieldValue.increment(1),
        lastRepostedAt: FieldValue.serverTimestamp(),
    };

    try {
        if (contextType === "profile" || originalPost.contextType === "profile") {
            await db.collection("posts").doc(originalPostId).update(updateData);
        } else {
            const spaceId = originalPost.space || originalPost.contextId;
            if (spaceId) {
                await db
                    .collection("spaces")
                    .doc(spaceId)
                    .collection("posts")
                    .doc(originalPostId)
                    .update(updateData);
            } else {
                // Fallback to top-level posts
                await db.collection("posts").doc(originalPostId).update(updateData);
            }
        }
    } catch (error) {
        logger.error("Error incrementing repost count", {
            structuredData: true,
            error: error.message,
            originalPostId,
            contextType,
        });
        throw error;
    }
}

/**
 * Atomically decrement repost count on original post
 * Uses originalPost.contextType to determine where the post lives
 */
async function decrementRepostCount(originalPostId, originalPost, contextType) {
    const updateData = {
        repostCount: FieldValue.increment(-1),
    };

    try {
        // Use originalPost.contextType (where original post lives), not repost contextType
        const postContextType = originalPost.contextType || contextType || "profile";

        if (postContextType === "profile") {
            await db.collection("posts").doc(originalPostId).update(updateData);
        } else {
            const spaceId = originalPost.space || originalPost.contextId;
            if (spaceId) {
                await db
                    .collection("spaces")
                    .doc(spaceId)
                    .collection("posts")
                    .doc(originalPostId)
                    .update(updateData);
            } else {
                // Fallback to top-level posts (shouldn't happen, but safety)
                await db.collection("posts").doc(originalPostId).update(updateData);
            }
        }
    } catch (error) {
        logger.error("Error decrementing repost count", {
            structuredData: true,
            error: error.message,
            originalPostId,
            contextType,
            originalPostContextType: originalPost?.contextType,
        });
        // Don't throw - this is cleanup, not critical
    }
}

/**
 * Check if original post should be added to globalFeed
 */
async function shouldAddToGlobalFeed(originalPost) {
    if (originalPost.contextType === "profile") {
        const authorDoc = await db.collection("users").doc(originalPost.author).get();
        const authorData = authorDoc.data();
        return authorData?.isPrivateProfile !== true;
    } else if (originalPost.contextType === "space") {
        const spaceId = originalPost.space || originalPost.contextId;
        if (!spaceId) return false;
        const spaceDoc = await db.collection("spaces").doc(spaceId).get();
        const spaceData = spaceDoc.data();
        return isPublicSpace(spaceData);
    }
    return false;
}

/**
 * Update globalFeed entry for repost (boost original post visibility)
 */
async function updateGlobalFeedForRepost(originalPostId, originalPost, reposterId) {
    if (!(await shouldAddToGlobalFeed(originalPost))) {
        return;
    }

    try {
        const feedRef = db.collection("globalFeed").doc(originalPostId);
        const feedDoc = await feedRef.get();

        if (feedDoc.exists) {
            // Update existing entry
            const feedData = feedDoc.data();
            const repostedBy = feedData.repostedBy || [];

            // Add reposter to array (keep last 10, remove duplicates)
            const updatedRepostedBy = [reposterId, ...repostedBy]
                .filter((id, index, arr) => arr.indexOf(id) === index) // Remove duplicates
                .slice(0, 10); // Keep last 10

            await feedRef.update({
                repostCount: FieldValue.increment(1),
                lastRepostedAt: FieldValue.serverTimestamp(),
                repostedBy: updatedRepostedBy,
            });
        } else {
            // Create new entry pointing to original post
            await feedRef.set({
                postId: originalPostId,
                author: originalPost.author,
                contextType: originalPost.contextType,
                contextId: originalPost.contextId || originalPost.space,
                title: originalPost.title || "",
                thumbnail: originalPost.thumbnail || null,
                repostCount: 1,
                repostedBy: [reposterId],
                lastRepostedAt: FieldValue.serverTimestamp(),
                timestamp: originalPost.timestamp || FieldValue.serverTimestamp(),
            });
        }
    } catch (error) {
        logger.error("Error updating globalFeed for repost", {
            structuredData: true,
            error: error.message,
            originalPostId,
            reposterId,
        });
        // Don't throw - feed update is not critical
    }
}

/**
 * Remove repost from globalFeed
 */
async function removeRepostFromGlobalFeed(originalPostId, reposterId) {
    try {
        const feedRef = db.collection("globalFeed").doc(originalPostId);
        const feedDoc = await feedRef.get();

        if (!feedDoc.exists) {
            return;
        }

        const feedData = feedDoc.data();
        const repostedBy = (feedData.repostedBy || []).filter(id => id !== reposterId);

        await feedRef.update({
            repostCount: FieldValue.increment(-1),
            repostedBy,
        });
    } catch (error) {
        logger.error("Error removing repost from globalFeed", {
            structuredData: true,
            error: error.message,
            originalPostId,
            reposterId,
        });
        // Don't throw - feed update is not critical
    }
}

/**
 * Send notification to original author when reposted
 */
async function sendRepostNotification(originalAuthorId, reposterId, originalPostId) {
    try {
        // Skip if self-repost
        if (originalAuthorId === reposterId) {
            return;
        }

        // Get reposter info
        const reposterDoc = await db.collection("users").doc(reposterId).get();
        const reposterData = reposterDoc.data() || {};
        const reposterName = reposterData.name || reposterData.username || "Someone";
        const reposterPic = reposterData.displayPicture || "";

        // Get original post for thumbnail
        // Try top-level posts first, then check if it's a space post
        let originalPostDoc = await db.collection("posts").doc(originalPostId).get();
        let originalPostData = originalPostDoc.data() || {};
        let thumbnail = originalPostData.thumbnail || null;

        // If not found in top-level posts, it might be a space post
        // Try to get from repost document's previewThumbnail if available
        if (!originalPostDoc.exists || !thumbnail) {
            const repostDoc = await db.collection("reposts")
                .where("originalPostId", "==", originalPostId)
                .limit(1)
                .get();
            if (!repostDoc.empty) {
                const repostData = repostDoc.docs[0].data();
                thumbnail = repostData.previewThumbnail || thumbnail;
            }
        }

        const notification = {
            type: "repost",
            read: false,
            postId: originalPostId,
            reposter: reposterId,
            reposterName: reposterName,
            reposterDisplayPicture: reposterPic,
            thumbnail: thumbnail,
            timestamp: FieldValue.serverTimestamp(),
        };

        await db
            .collection("notifications")
            .doc(originalAuthorId)
            .collection("notifications")
            .add(notification);

        logger.info("Repost notification sent", {
            structuredData: true,
            originalAuthorId,
            reposterId,
            originalPostId,
        });
    } catch (error) {
        logger.warn("Failed to send repost notification", {
            structuredData: true,
            error: error.message,
            originalAuthorId,
            reposterId,
        });
        // Don't throw - notification is not critical
    }
}

// =============================================================================
// CLOUD FUNCTIONS
// =============================================================================

/**
 * Create a repost handler (core logic)
 * Extracted for testability - can be tested directly without onCall wrapper
 */
export async function createRepostHandler(request) {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { originalPostId, contextType, contextId } = validateRequest(
        CreateRepostSchema,
        request.data,
        "createRepost"
    );

    // Validate context
    if (contextType === "space" && !contextId) {
        throw new HttpsError("invalid-argument", "contextId required for space reposts");
    }

    // Validate originalPostId
    if (!originalPostId || originalPostId.trim() === "") {
        throw new HttpsError("invalid-argument", "originalPostId is required");
    }

    try {
        // 1. Get original post
        // First try to determine contextType from original post
        const originalPostDoc = await db.collection("posts").doc(originalPostId).get();
        let originalPost = null;
        let originalContextType = null;
        let originalSpaceId = null;

        if (originalPostDoc.exists) {
            originalPost = { id: originalPostDoc.id, ...originalPostDoc.data() };
            originalContextType = originalPost.contextType || "profile";
            originalSpaceId = originalPost.space || originalPost.contextId;
        } else {
            // Try space posts collections
            // This is inefficient but necessary for backward compatibility
            // In production, we'd need spaceId passed from client
            throw new HttpsError("not-found", "Original post not found");
        }

        if (!originalPost) {
            throw new HttpsError("not-found", "Original post not found");
        }

        // Try to get from space collection if it's a space post
        // Also check if post wasn't found in top-level posts (might be space-only)
        if ((originalContextType === "space" && originalSpaceId) || !originalPostDoc.exists) {
            // If we don't have spaceId yet, try to find it by searching spaces
            // This is a fallback for when client doesn't provide contextType correctly
            if (!originalSpaceId && !originalPostDoc.exists) {
                // Try to find post in any space (inefficient but necessary fallback)
                // In practice, client should provide correct contextType
                logger.warn("Post not found in top-level posts, searching spaces", {
                    structuredData: true,
                    originalPostId,
                });
            }

            // If we have spaceId, fetch from space subcollection
            if (originalSpaceId) {
                const spacePostDoc = await db
                    .collection("spaces")
                    .doc(originalSpaceId)
                    .collection("posts")
                    .doc(originalPostId)
                    .get();
                if (spacePostDoc.exists) {
                    originalPost = { id: spacePostDoc.id, ...spacePostDoc.data() };
                    // Update contextType from fetched data
                    originalContextType = originalPost.contextType || "space";
                }
            }
        }

        // If still not found, check if it's a reply in postReplies collection
        // Replies are stored in postReplies/{originalPostId}/replies/{replyId}
        // If this post exists as a reply, it should be treated as a profile post
        if (!originalPost) {
            // Search for this postId in any postReplies subcollection
            // This is a fallback - in practice, replies should be found in posts/ or spaces/ collections
            logger.warn("Post not found in posts or spaces, checking if it's a reply", {
                structuredData: true,
                originalPostId,
            });
        }

        // Log post data for debugging reply detection
        if (originalPost) {
            logger.info("Fetched original post for repost", {
                structuredData: true,
                originalPostId,
                contextType: originalPost.contextType,
                replyTo: originalPost.replyTo,
                space: originalPost.space,
                contextId: originalPost.contextId,
            });
        }

        // 2. Validate original post has required fields
        if (!originalPost.author) {
            throw new HttpsError("invalid-argument", "Original post missing author field");
        }

        // 3. Validate permissions (includes duplicate check)
        await validateRepostPermissions(userId, originalPost, contextType, contextId);

        // 4. Create repost document atomically with duplicate check and count increment using transaction
        // This prevents race conditions where two requests create duplicates simultaneously
        const repostRef = await db.runTransaction(async (transaction) => {
            // Re-check for duplicate inside transaction (prevents race condition)
            // Firestore transactions support query reads - this is safe
            const postIdToCheck = originalPost.id || originalPost.originalPostId;

            // Build query for duplicate check
            // Note: We query without contextId filter (handled in memory) to avoid index issues
            let duplicateQuery = db.collection("reposts")
                .where("reposterId", "==", userId)
                .where("originalPostId", "==", postIdToCheck)
                .where("contextType", "==", contextType)
                .limit(10);

            // Execute query inside transaction (Firestore admin SDK supports this)
            const existingRepostsSnapshot = await transaction.get(duplicateQuery);

            // Filter by contextId in memory (more reliable than Firestore null handling)
            const isDuplicate = existingRepostsSnapshot.docs.some((doc) => {
                const data = doc.data();
                const docContextId = data.contextId || null;
                const targetContextIdValue = contextId || null;
                return docContextId === targetContextIdValue;
            });

            if (isDuplicate) {
                throw new HttpsError("already-exists", "User already reposted this post");
            }

            // Verify original post still exists (could have been deleted between checks)
            const originalContextType = originalPost.contextType || "profile";
            const originalSpaceId = originalPost.space || originalPost.contextId;

            let originalPostRef;
            if (originalContextType === "profile") {
                originalPostRef = db.collection("posts").doc(originalPostId);
            } else if (originalSpaceId) {
                originalPostRef = db.collection("spaces")
                    .doc(originalSpaceId)
                    .collection("posts")
                    .doc(originalPostId);
            } else {
                // Fallback to top-level posts
                originalPostRef = db.collection("posts").doc(originalPostId);
            }

            const originalPostSnapshot = await transaction.get(originalPostRef);
            if (!originalPostSnapshot.exists) {
                throw new HttpsError("not-found", "Original post was deleted");
            }

            // Create repost document
            // Store original post context info for efficient lookup during deletion
            const newRepostRef = db.collection("reposts").doc();
            transaction.set(newRepostRef, {
                reposterId: userId,
                originalPostId: originalPostId,
                originalAuthorId: originalPost.author,
                originalPostContextType: originalPost.contextType || "profile", // Store where original post lives
                originalSpaceId: originalPost.space || originalPost.contextId || null, // Store space ID if space post
                contextType: contextType, // Where repost is going (target context)
                contextId: contextId || null, // Target space ID if reposting to space
                timestamp: FieldValue.serverTimestamp(),
                previewThumbnail: originalPost.thumbnail || null,
                previewTitle: originalPost.title || null,
                createdAt: FieldValue.serverTimestamp(),
            });

            // Increment repost count atomically in same transaction
            const updateData = {
                repostCount: FieldValue.increment(1),
                lastRepostedAt: FieldValue.serverTimestamp(),
            };
            transaction.update(originalPostRef, updateData);

            return newRepostRef;
        });

        // Note: Repost count increment is now handled atomically in the transaction above

        // 5. Update globalFeed if original was public (non-critical, best-effort)
        if (await shouldAddToGlobalFeed(originalPost)) {
            await updateGlobalFeedForRepost(originalPostId, originalPost, userId);
        }

        // 6. Send notification (async, non-critical, best-effort)
        sendRepostNotification(originalPost.author, userId, originalPostId).catch(err =>
            logger.warn("Failed to send repost notification", { error: err })
        );

        logger.info("Repost created successfully", {
            structuredData: true,
            repostId: repostRef.id,
            originalPostId,
            reposterId: userId,
            contextType,
        });

        return { repostId: repostRef.id };
    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        logger.error("Error creating repost", {
            structuredData: true,
            error: error.message,
            originalPostId,
            reposterId: userId,
        });
        throw new HttpsError("internal", "Failed to create repost");
    }
}

/**
 * Create a repost (callable function)
 * Client calls this instead of writing directly to Firestore
 */
export const createRepost = onCall(createRepostHandler);

/**
 * Delete a repost handler (core logic)
 * Extracted for testability - can be tested directly without onCall wrapper
 */
export async function deleteRepostHandler(request) {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { repostId } = validateRequest(DeleteRepostSchema, request.data, "deleteRepost");

    try {
        // Get repost
        const repostDoc = await db.collection("reposts").doc(repostId).get();
        if (!repostDoc.exists) {
            throw new HttpsError("not-found", "Repost not found");
        }

        const repostData = repostDoc.data();
        if (repostData.reposterId !== userId) {
            throw new HttpsError("permission-denied", "Can only delete own reposts");
        }

        const originalPostId = repostData.originalPostId;

        // Use stored original post context info from repost document (efficient lookup)
        const originalPostContextType = repostData.originalPostContextType || "profile";
        const originalSpaceId = repostData.originalSpaceId || null;

        // Get original post for context (using stored context info)
        let originalPost = null;

        if (originalPostContextType === "profile") {
            const topLevelPostDoc = await db.collection("posts").doc(originalPostId).get();
            if (topLevelPostDoc.exists) {
                originalPost = { id: topLevelPostDoc.id, ...topLevelPostDoc.data() };
            }
        } else if (originalSpaceId) {
            // Use stored space ID to find space post efficiently
            const spacePostDoc = await db
                .collection("spaces")
                .doc(originalSpaceId)
                .collection("posts")
                .doc(originalPostId)
                .get();
            if (spacePostDoc.exists) {
                originalPost = { id: spacePostDoc.id, ...spacePostDoc.data() };
            } else {
                // Fallback: try top-level posts (for backward compatibility)
                const fallbackDoc = await db.collection("posts").doc(originalPostId).get();
                if (fallbackDoc.exists) {
                    originalPost = { id: fallbackDoc.id, ...fallbackDoc.data() };
                }
            }
        } else {
            // Fallback: try top-level posts
            const fallbackDoc = await db.collection("posts").doc(originalPostId).get();
            if (fallbackDoc.exists) {
                originalPost = { id: fallbackDoc.id, ...fallbackDoc.data() };
            }
        }

        // Delete repost
        await repostDoc.ref.delete();

        // Decrement count (non-critical - if this fails, count is wrong but repost is deleted)
        if (originalPost) {
            try {
                await decrementRepostCount(originalPostId, originalPost, originalPostContextType);
            } catch (countError) {
                logger.warn("Failed to decrement repost count after deleting repost", {
                    structuredData: true,
                    error: countError.message,
                    repostId,
                    originalPostId,
                });
                // Don't throw - repost was deleted successfully, count can be corrected
            }
        } else {
            // Fallback: try to decrement from top-level posts
            try {
                await db.collection("posts").doc(originalPostId).update({
                    repostCount: FieldValue.increment(-1),
                });
            } catch (error) {
                logger.warn("Failed to decrement repost count (post may not exist)", {
                    structuredData: true,
                    error: error.message,
                    originalPostId,
                });
            }
        }

        // Update globalFeed
        await removeRepostFromGlobalFeed(originalPostId, userId);

        logger.info("Repost deleted successfully", {
            structuredData: true,
            repostId,
            originalPostId,
            reposterId: userId,
        });

        return { success: true };
    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        logger.error("Error deleting repost", {
            structuredData: true,
            error: error.message,
            repostId,
        });
        throw new HttpsError("internal", "Failed to delete repost");
    }
}

/**
 * Delete a repost (callable function)
 */
export const deleteRepost = onCall(deleteRepostHandler);

/**
 * Helper function to cascade delete all reposts of a deleted post
 * Also decrements repostCount on the original post (if it still exists)
 * Exported for testing
 */
export async function cascadeDeleteReposts(deletedPostId, deletedPostData) {
    try {
        // Find all reposts of this post (handle pagination for >500 reposts)
        let lastDoc = null;
        let totalDeleted = 0;
        const BATCH_SIZE = 500;

        while (true) {
            let query = db
                .collection("reposts")
                .where("originalPostId", "==", deletedPostId)
                .limit(BATCH_SIZE);

            if (lastDoc) {
                query = query.startAfter(lastDoc);
            }

            const repostsSnapshot = await query.get();

            if (repostsSnapshot.empty) {
                break;
            }

            logger.info("Cascading delete reposts batch", {
                structuredData: true,
                deletedPostId,
                batchSize: repostsSnapshot.size,
                totalDeletedSoFar: totalDeleted,
            });

            // Delete in batches (Firestore batch limit is 500)
            let batch = db.batch();
            let count = 0;

            for (const repostDoc of repostsSnapshot.docs) {
                batch.delete(repostDoc.ref);
                count++;
                totalDeleted++;

                if (count >= BATCH_SIZE) {
                    await batch.commit();
                    // Create new batch for next operations
                    batch = db.batch();
                    count = 0;
                }
            }

            if (count > 0) {
                await batch.commit();
            }

            // If we got less than BATCH_SIZE, we're done
            if (repostsSnapshot.size < BATCH_SIZE) {
                break;
            }

            lastDoc = repostsSnapshot.docs[repostsSnapshot.docs.length - 1];
        }

        // Note: We don't decrement repostCount here because the post is already deleted
        // The repostCount field on the deleted post is no longer accessible
        // This is fine - repostCount is denormalized data that becomes irrelevant when post is deleted
        // If we need accurate counts, we can always query the reposts collection directly

        // Remove from globalFeed
        await db.collection("globalFeed").doc(deletedPostId).delete().catch(() => {
            // Feed entry might not exist, ignore
        });

        logger.info("Reposts cascade deleted", {
            structuredData: true,
            deletedPostId,
            deletedCount: totalDeleted,
        });
    } catch (error) {
        logger.error("Error cascading delete reposts", {
            structuredData: true,
            error: error.message,
            deletedPostId,
        });
    }
}

/**
 * Handle original post deletion - cascade delete all reposts
 * Handles profile posts (posts/{postId})
 */
export const onOriginalPostDeleted = onDocumentDeleted(
    "posts/{postId}",
    withIdempotency("onOriginalPostDeleted", async (event) => {
        const deletedPostId = event.params.postId;
        const postData = event.data.data();

        // Skip if this was a repost (shouldn't happen with new model, but safety check)
        if (postData?.isRepost) {
            return;
        }

        await cascadeDeleteReposts(deletedPostId, postData);
    })
);

/**
 * Handle space post deletion - cascade delete all reposts
 * Handles space posts (spaces/{spaceId}/posts/{postId})
 */
export const onSpacePostDeleted = onDocumentDeleted(
    "spaces/{spaceId}/posts/{postId}",
    withIdempotency("onSpacePostDeleted", async (event) => {
        const deletedPostId = event.params.postId;
        const postData = event.data.data();

        // Skip if this was a repost (shouldn't happen with new model, but safety check)
        if (postData?.isRepost) {
            return;
        }

        await cascadeDeleteReposts(deletedPostId, postData);
    })
);
