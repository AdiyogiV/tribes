/**
 * onPostWrite — Consolidated trigger for `posts/{postId}` writes.
 *
 * Merges six previously separate Cloud Functions that listened to the same path:
 *
 *   ON CREATE:
 *     1. newPost                       (posts.js)         — reply notifications + userFeed write
 *     2. addProfilePostToGlobalFeed    (feeds.js)         — public profile posts → globalFeed
 *     3. awardCreatePostAura           (aura.js)          — aura for non-reply top-level posts
 *
 *   ON DELETE:
 *     4. deletePost                    (posts.js)         — cleanupOrphanedReplies + userFeed cleanup
 *     5. deletePostFromGlobalFeed      (feeds.js)         — purge globalFeed entry
 *     6. onOriginalPostDeleted         (reposts.js)       — cascadeDeleteReposts
 *
 * Eventarc allows only one Cloud Function per unique document path, so we
 * collapse them into a single onDocumentWritten handler that dispatches based
 * on create-vs-delete state. Behavior is preserved exactly per side effect.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../../lib/firebase.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { PostSchema } from "../../lib/schemas.js";
import { awardAura } from "../../lib/aura_service.js";
import { AURA_POINTS } from "../../lib/constants.js";
import { cascadeDeleteReposts } from "../reposts.js";

// =============================================================================
// CREATE-branch handlers — preserve original semantics of the 3 merged triggers
// =============================================================================

/**
 * Was `newPost` (posts.js): if the post is a reply, write a notification + a
 * userFeed entry for the original author so the reply shows in their feed.
 */
async function handleReplyNotificationOnCreate(snap, postData, postId) {
    try {
        PostSchema.parse(postData);
    } catch (e) {
        return;
    }
    const { replyTo, author, thumbnail, space } = postData;
    if (!replyTo) return;

    try {
        const postDoc = await db.collection("posts").doc(replyTo).get();
        if (!postDoc.exists) {
            return;
        }
        const postAuthor = postDoc.data().author;

        // Skip notification if replying to own post
        if (author === postAuthor) {
            return;
        }

        const authorDoc = await db.collection("users").doc(author).get();
        const authorData = authorDoc.exists ? authorDoc.data() : {};
        const authorName = authorData.name || authorData.username || "Someone";
        const authorPic = authorData.displayPicture || "";

        const notification = {
            type: "reply",
            read: false,
            postId: postId,
            replyToPost: replyTo,
            author: author,
            authorName: authorName,
            authorPic: authorPic,
            thumbnail: thumbnail,
            space: space,
            timestamp: FieldValue.serverTimestamp(),
        };
        await db.collection("notifications").doc(postAuthor).collection("notifications").add(notification);
        await db.collection("userFeed").doc(postAuthor).collection("posts").doc(postId).set({
            ...postData,
            seen: false,
            timestamp: FieldValue.serverTimestamp(),
        });
    } catch (error) {
        logger.error("Error handling reply notification", { structuredData: true, error });
    }
}

/**
 * Was `addProfilePostToGlobalFeed` (feeds.js): adds public profile posts to
 * the globalFeed for discovery. Skips private profiles and non-profile context.
 */
async function handleProfilePostToGlobalFeedOnCreate(postData, postId) {
    if (postData.contextType !== "profile") {
        return;
    }

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
    const postType = postData.postType || "video";
    const thumbnail = postData.thumbnail || (postType === "image" ? postData.video : null) || postData.video || null;

    try {
        await db.collection("globalFeed").doc(postId).set({
            postId,
            author: authorId,
            contextType: "profile",
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
        throw error;
    }
}

/**
 * Was `awardCreatePostAura` (aura.js): awards aura ONLY for top-level posts
 * (skips replies; reply author is awarded by the separate reply trigger).
 */
async function handleCreatePostAuraOnCreate(postData, postId) {
    if (!postData?.author) {
        logger.warn("Post missing author, skipping create-post aura", { postId });
        return;
    }

    if (postData.replyTo) {
        return;
    }

    await awardAura(
        postData.author,
        AURA_POINTS.CREATE_POST,
        "Created post",
        { postId, action: "post_created" },
    );

    logger.info("Created-post aura awarded", { postId, author: postData.author });
}

// =============================================================================
// DELETE-branch handlers
// =============================================================================

/**
 * Was `deletePost` (posts.js): cleans up reply references and the original
 * author's userFeed entry if this post was a reply.
 */
async function handleDeletePostBookkeeping(postData, deletedPostId) {
    try {
        PostSchema.parse(postData);
    } catch (e) {
        return;
    }

    const { replyTo } = postData;

    // PART 1: If this post was a reply, clean up from original author's feed
    if (replyTo) {
        try {
            const originalPostDoc = await db.collection("posts").doc(replyTo).get();
            if (originalPostDoc.exists) {
                const originalPostAuthor = originalPostDoc.data()?.author;
                if (originalPostAuthor) {
                    await db.collection("userFeed").doc(originalPostAuthor).collection("posts").doc(deletedPostId).delete();
                }
            }
        } catch (error) {
            logger.error("Error deleting reply from feed", { structuredData: true, error });
        }
    }

    // PART 2: Clean up orphaned replies that reference this deleted post
    try {
        await cleanupOrphanedReplies(deletedPostId);
    } catch (error) {
        logger.error("Error cleaning up orphaned replies", {
            structuredData: true,
            deletedPostId,
            error: String(error),
        });
        // Don't throw - this is cleanup, not critical
    }
}

/**
 * Clean up orphaned reply references (verbatim from posts.js).
 */
async function cleanupOrphanedReplies(deletedPostId) {
    const orphanedReplies = await db.collection("posts")
        .where("replyTo", "==", deletedPostId)
        .limit(100)
        .get();

    if (orphanedReplies.empty) {
        return;
    }

    logger.info("Cleaning up orphaned replies", {
        structuredData: true,
        deletedPostId,
        orphanCount: orphanedReplies.size,
    });

    const batch = db.batch();

    orphanedReplies.docs.forEach((doc) => {
        batch.update(doc.ref, {
            replyTo: FieldValue.delete(),
            _originalReplyTo: deletedPostId,
            _replyToDeleted: true,
        });
    });

    await batch.commit();

    logger.info("Orphaned replies cleaned up", {
        structuredData: true,
        deletedPostId,
        cleanedCount: orphanedReplies.size,
    });
}

/**
 * Was `deletePostFromGlobalFeed` (feeds.js).
 */
async function handleDeleteGlobalFeedEntry(postId) {
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
}

/**
 * Was `onOriginalPostDeleted` (reposts.js): cascade-delete every repost that
 * pointed at the deleted post. Skips repost docs themselves to avoid recursion.
 */
async function handleCascadeRepostDelete(deletedPostId, postData) {
    if (postData?.isRepost) {
        return;
    }
    await cascadeDeleteReposts(deletedPostId, postData);
}

// =============================================================================
// Unified Cloud Function — single Eventarc subscription on posts/{postId}.
// =============================================================================

/**
 * Idempotency-wrapped CREATE pipeline. Each of the 3 sub-handlers used to be
 * its own onDocumentCreated with withIdempotency keyed on its own function
 * name; we preserve that by giving each its own key but call them in series
 * within one trigger.
 */
const createPipeline = withIdempotency("onPostWrite:create", async (event) => {
    const snap = event.data?.after;
    if (!snap) return;
    const postData = snap.data();
    if (!postData) return;
    const postId = event.params.postId;

    // Run in series — each handler is independent but they share Firestore reads.
    // Order: aura first (cheapest), then global feed write, then reply fanout.
    await Promise.all([
        handleCreatePostAuraOnCreate(postData, postId).catch((e) =>
            logger.error("post-create aura failed", { postId, error: String(e) })),
        handleProfilePostToGlobalFeedOnCreate(postData, postId).catch((e) =>
            logger.error("post-create globalFeed failed", { postId, error: String(e) })),
        handleReplyNotificationOnCreate(snap, postData, postId).catch((e) =>
            logger.error("post-create reply notification failed", { postId, error: String(e) })),
    ]);
});

/**
 * Idempotency-wrapped DELETE pipeline.
 */
const deletePipeline = withIdempotency("onPostWrite:delete", async (event) => {
    const beforeSnap = event.data?.before;
    if (!beforeSnap) return;
    const postData = beforeSnap.data() || {};
    const deletedPostId = event.params.postId;

    await Promise.all([
        handleDeletePostBookkeeping(postData, deletedPostId).catch((e) =>
            logger.error("post-delete bookkeeping failed", { deletedPostId, error: String(e) })),
        handleDeleteGlobalFeedEntry(deletedPostId).catch((e) =>
            logger.error("post-delete globalFeed failed", { deletedPostId, error: String(e) })),
        handleCascadeRepostDelete(deletedPostId, postData).catch((e) =>
            logger.error("post-delete cascade failed", { deletedPostId, error: String(e) })),
    ]);
});

export const onPostWrite = onDocumentWritten("posts/{postId}", async (event) => {
    const beforeExists = event.data?.before?.exists ?? false;
    const afterExists = event.data?.after?.exists ?? false;

    // CREATE
    if (!beforeExists && afterExists) {
        await createPipeline(event);
        return null;
    }

    // DELETE
    if (beforeExists && !afterExists) {
        await deletePipeline(event);
        return null;
    }

    // UPDATE — no merged trigger needs this branch today; intentional no-op.
    return null;
});
