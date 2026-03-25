import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";
import { BATCH_SIZES, isPublicSpaceType } from "../lib/constants.js";

/**
 * Feed System - Pull-Based Architecture
 * 
 * NEW ARCHITECTURE (2024):
 * - Single source of truth: posts/ collection
 * - Client queries posts/ directly using contextType + contextId
 * - No userFeed fanout needed - reduces complexity and write costs
 * - globalFeed maintained for discovery/guest users
 * 
 * DEPRECATED:
 * - userFeed fanout (client now queries posts/ directly)
 * - spacePosts collection (posts/ is the source of truth)
 * 
 * KEPT:
 * - globalFeed for discovery
 * - Notifications for new posts
 */

const ROLE_PAGE_SIZE = 500;

async function fetchSpaceMemberIds(spaceId) {
    const rolesRef = db.collection("spaceRoles").doc(spaceId).collection("roles");
    const memberIds = [];
    let lastDoc = null;

    while (true) {
        let query = rolesRef.orderBy("__name__").limit(ROLE_PAGE_SIZE);
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();
        if (snapshot.empty) break;

        for (const doc of snapshot.docs) {
            const data = doc.data();
            if (data.role !== "invited" && data.role !== "requested") {
                memberIds.push(doc.id);
            }
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < ROLE_PAGE_SIZE) break;
    }

    return memberIds;
}

/**
 * Space is public (eligible for global feed) iff:
 * - type is OPEN or PUBLIC (see constants.js SPACE_TYPES) and not limitedVisibility, or
 * - legacy profile gram. Must match firestore.rules isPublicSpace().
 */
function isPublicSpace(spaceData) {
    if (!spaceData) return false;
    if (spaceData.limitedVisibility === true) return false;
    if (spaceData.isProfileGram === true) return true;
    return isPublicSpaceType(spaceData.spaceType);
}

/**
 * Handle space post creation
 * - Add to globalFeed if public
 * - Send notifications to members
 * - Write to spacePosts for backward compatibility (DEPRECATED - will be removed)
 */
export const addPostToFeeds = onDocumentCreated("spacePosts/{spaceId}/posts/{postId}", withIdempotency("addPostToFeeds", async (event) => {
    const snapshot = event.data;
    const postData = snapshot.data();
    const { spaceId, postId } = event.params;
    const { author, title, thumbnail, replyTo, video } = postData;

    const spaceDoc = await db.collection("spaces").doc(spaceId).get();
    const spaceData = spaceDoc.data();
    if (!spaceData) {
        return;
    }

    // Track last activity timestamp on the space for discovery ordering
    await db.collection("spaces").doc(spaceId).update({
        lastPostAt: FieldValue.serverTimestamp(),
    });

    // Get author info for notifications
    const authorDoc = await db.collection("users").doc(author).get();
    const authorData = authorDoc.exists ? authorDoc.data() : {};
    const authorName = authorData.name || authorData.username || "Someone";
    const authorPic = authorData.displayPicture || "";

    // Get members for notifications (paged to avoid large snapshots)
    const memberIds = await fetchSpaceMemberIds(spaceId);

    // Send notifications to members (except author) using batched writes
    const recipientIds = memberIds.filter(userId => userId !== author && userId !== replyTo);

    // Use batched writes to prevent hitting Firestore limits
    const NOTIFICATION_BATCH_SIZE = BATCH_SIZES.FIRESTORE_WRITES || 500;
    let notificationCount = 0;

    for (let i = 0; i < recipientIds.length; i += NOTIFICATION_BATCH_SIZE) {
        const batch = db.batch();
        const chunk = recipientIds.slice(i, i + NOTIFICATION_BATCH_SIZE);

        for (const userId of chunk) {
            const notificationRef = db
                .collection("notifications")
                .doc(userId)
                .collection("notifications")
                .doc();

            batch.set(notificationRef, {
                type: "newSpacePost",
                read: false,
                postId: postId,
                author: author,
                authorName: authorName,
                authorPic: authorPic,
                title: title || "",
                thumbnail: thumbnail,
                replyTo: replyTo,
                video: video,
                space: spaceId,
                spaceName: spaceData.name || "",
                timestamp: FieldValue.serverTimestamp(),
            });
            notificationCount++;
        }

        await batch.commit();
    }

    // Add to global feed if public space
    if (isPublicSpace(spaceData)) {
        await db.collection("globalFeed").doc(postId).set({
            postId,
            author,
            contextType: "space",
            contextId: spaceId,
            title: title || "",
            thumbnail,
            timestamp: FieldValue.serverTimestamp(),
        });
    }

    logger.info("Space post processed (notifications + global feed)", {
        structuredData: true,
        postId,
        spaceId,
        notificationCount,
        addedToGlobalFeed: isPublicSpace(spaceData),
    });
}));

/**
 * Handle profile post creation
 * - Add to globalFeed for discovery (if public profile)
 */
export const addProfilePostToGlobalFeed = onDocumentCreated("posts/{postId}", withIdempotency("addProfilePostToGlobalFeed", async (event) => {
    const snapshot = event.data;
    const postData = snapshot.data();
    const { postId } = event.params;

    // Only process profile posts
    if (postData.contextType !== 'profile') {
        return;
    }

    // Check if author has private profile
    const authorId = postData.author;
    if (authorId) {
        try {
            const authorDoc = await db.collection("users").doc(authorId).get();
            const authorData = authorDoc.data();
            if (authorData?.isPrivateProfile === true) {
                logger.info("Skipping global feed for private profile post", {
                    structuredData: true,
                    postId,
                    authorId,
                });
                return;
            }
        } catch (error) {
            logger.warn("Error checking author privacy", {
                structuredData: true,
                postId,
                authorId,
                error: error.message,
            });
            // Continue - default to public if check fails
        }
    }

    // Handle thumbnail: image posts store image URL in 'video' field, not 'thumbnail'
    // Use video field for image posts, thumbnail for others, or fallback to video
    const postType = postData.postType || 'video';
    const thumbnail = postData.thumbnail || (postType === 'image' ? postData.video : null) || postData.video || null;

    try {
        await db.collection("globalFeed").doc(postId).set({
            postId,
            author: authorId,
            contextType: 'profile',
            title: postData.title || "",
            thumbnail: thumbnail,
            timestamp: FieldValue.serverTimestamp(),
        });

        logger.info("Profile post added to global feed", {
            structuredData: true,
            postId,
            authorId,
            postType: postType,
            hasThumbnail: !!thumbnail,
        });
    } catch (error) {
        logger.error("Failed to add profile post to global feed", {
            structuredData: true,
            postId,
            authorId,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        // Re-throw to ensure Firebase Functions logs the error
        throw error;
    }
}));

/**
 * Remove post from global feed when deleted
 */
export const deletePostFromGlobalFeed = onDocumentDeleted("posts/{postId}", withIdempotency("deletePostFromGlobalFeed", async (event) => {
    const { postId } = event.params;

    try {
        await db.collection("globalFeed").doc(postId).delete();
        logger.info("Post removed from global feed", {
            structuredData: true,
            postId,
        });
    } catch (error) {
        logger.warn("Error removing post from global feed", {
            structuredData: true,
            postId,
            error: error.message,
        });
    }
}));

/**
 * Clean up space post from global feed when deleted from spacePosts
 */
export const deleteSpacePostFromGlobalFeed = onDocumentDeleted("spacePosts/{spaceId}/posts/{postId}", withIdempotency("deleteSpacePostFromGlobalFeed", async (event) => {
    const { postId } = event.params;

    try {
        await db.collection("globalFeed").doc(postId).delete();
        logger.info("Space post removed from global feed", {
            structuredData: true,
            postId,
        });
    } catch (error) {
        // Ignore - post may not be in global feed
    }
}));

// ============================================================================
// DEPRECATED FUNCTIONS - Kept for backward compatibility during migration
// These will be removed in a future release
// ============================================================================

/**
 * @deprecated - No longer needed with pull-based architecture
 * Client now queries posts/ directly instead of userFeed
 */
export const addProfilePostToFollowerFeeds = onDocumentCreated("posts/{postId}", withIdempotency("addProfilePostToFollowerFeeds", async (event) => {
    const postData = event.data?.data();

    // DEPRECATED: Skip fanout - client queries posts/ directly now
    if (postData?.contextType === 'profile') {
        logger.info("DEPRECATED: Skipping userFeed fanout for profile post", {
            structuredData: true,
            postId: event.params.postId,
            message: "Client now queries posts/ directly",
        });
    }
    return;
}));

/**
 * @deprecated - No longer needed with pull-based architecture
 */
export const deletePostFromFeeds = onDocumentDeleted("spacePosts/{spaceId}/posts/{postId}", withIdempotency("deletePostFromFeeds", async (event) => {
    // DEPRECATED: No userFeed cleanup needed
    logger.info("DEPRECATED: deletePostFromFeeds - no action needed", {
        structuredData: true,
        postId: event.params.postId,
    });
    return;
}));

/**
 * @deprecated - No longer needed with pull-based architecture
 */
export const addRecentPostsToNewMemberFeed = () => null;

/**
 * @deprecated - No longer needed with pull-based architecture
 */
export const backfillFeedOnFollow = () => null;

// ============================================================================
// CLEANUP FUNCTIONS - Maintain data integrity
// ============================================================================

import { onSchedule } from "firebase-functions/v2/scheduler";

/**
 * Clean up orphaned globalFeed entries where the referenced post no longer exists
 * Runs weekly to prevent "post not found" errors in the feed
 */
export const cleanupOrphanedFeedEntries = onSchedule({
    schedule: "0 3 * * 0", // Every Sunday at 3 AM IST
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 540,
    memory: "512MiB",
}, async (event) => {
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
});
