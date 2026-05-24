/**
 * onPostLikeWrite — Consolidated trigger for `postLikes/{postId}/likes/{userId}` writes.
 *
 * Merges three previously separate Cloud Functions on the same path:
 *
 *   ON CREATE:
 *     1. newLike         (likes_and_invites.js) — increment likeCount + notify author
 *     2. awardLikeAura   (aura.js)              — award POST_LIKE_RECEIVED to author
 *
 *   ON DELETE:
 *     3. removeLike      (likes_and_invites.js) — decrement likeCount
 *
 * Eventarc only allows one Cloud Function per unique document path.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../../lib/firebase.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { AURA_POINTS } from "../../lib/constants.js";
import { awardAura } from "../../lib/aura_service.js";

// =============================================================================
// CREATE-branch handler
// =============================================================================

/**
 * Combined from `newLike` + `awardLikeAura`. Both used to read the post once
 * each; we now share that read across both side effects.
 */
async function handleLikeCreated(postId, likerId) {
    try {
        const postDoc = await db.collection("posts").doc(postId).get();
        if (!postDoc.exists) {
            logger.warn("Post not found for like", { postId, likerId });
            return;
        }

        const postData = postDoc.data();
        const postAuthor = postData.author;

        // Increment likeCount on the post (always, even for self-likes)
        await db.collection("posts").doc(postId).update({
            likeCount: FieldValue.increment(1),
        });

        logger.info("Like count incremented", { postId, likerId });

        // Skip notification + aura if liking own post
        if (!postAuthor || likerId === postAuthor) {
            return;
        }

        // Notify author + award aura in parallel — both depend on post + liker.
        await Promise.all([
            (async () => {
                const likerDoc = await db.collection("users").doc(likerId).get();
                const likerData = likerDoc.data() || {};

                const notification = {
                    type: "like",
                    read: false,
                    postId: postId,
                    liker: likerId,
                    likerName: likerData.name || "Someone",
                    likerDisplayPicture: likerData.displayPicture || "",
                    thumbnail: postData.thumbnail,
                    space: postData.space,
                    timestamp: FieldValue.serverTimestamp(),
                };

                await db.collection("notifications").doc(postAuthor).collection("notifications").add(notification);
            })().catch((e) => logger.error("Error sending like notification", {
                structuredData: true,
                error: e.message,
                postId,
                likerId,
            })),

            awardAura(
                postAuthor,
                AURA_POINTS.POST_LIKE_RECEIVED,
                "Received like on post",
                { likerUserId: likerId, postId, action: "post_like_received" },
            ).then(() => {
                logger.info("Like aura awarded", { postId, likerId, postAuthor });
            }).catch((e) => logger.error("Error awarding like aura", {
                structuredData: true,
                error: e.message,
                postId,
                likerId,
            })),
        ]);
    } catch (error) {
        logger.error("Error processing like", { structuredData: true, error: error.message, postId, likerId });
    }
}

// =============================================================================
// DELETE-branch handler
// =============================================================================

async function handleLikeDeleted(postId, likerId) {
    try {
        const postDoc = await db.collection("posts").doc(postId).get();
        if (!postDoc.exists) {
            logger.warn("Post not found for unlike", { postId, likerId });
            return;
        }

        await db.collection("posts").doc(postId).update({
            likeCount: FieldValue.increment(-1),
        });

        logger.info("Like count decremented", { postId, likerId });
    } catch (error) {
        logger.error("Error processing unlike", { structuredData: true, error: error.message, postId, likerId });
    }
}

// =============================================================================
// Unified Cloud Function
// =============================================================================

const createPipeline = withIdempotency("onPostLikeWrite:create", async (event) => {
    const { postId, userId: likerId } = event.params;
    await handleLikeCreated(postId, likerId);
});

const deletePipeline = withIdempotency("onPostLikeWrite:delete", async (event) => {
    const { postId, userId: likerId } = event.params;
    await handleLikeDeleted(postId, likerId);
});

export const onPostLikeWrite = onDocumentWritten("postLikes/{postId}/likes/{userId}", async (event) => {
    const beforeExists = event.data?.before?.exists ?? false;
    const afterExists = event.data?.after?.exists ?? false;

    if (!beforeExists && afterExists) {
        await createPipeline(event);
        return null;
    }

    if (beforeExists && !afterExists) {
        await deletePipeline(event);
        return null;
    }

    return null;
});
