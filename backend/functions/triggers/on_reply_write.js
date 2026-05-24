/**
 * onReplyWrite — Consolidated trigger for `postReplies/{postId}/replies/{replyId}` writes.
 *
 * Merges two previously separate Cloud Functions on the same path:
 *
 *   ON CREATE:
 *     1. awardReplyAura  (aura.js) — increment replyCount on the parent post,
 *        award aura to BOTH the parent author (POST_REPLY_RECEIVED) and the
 *        reply author (CREATE_REPLY). Skips self-replies for aura but still
 *        increments the count.
 *
 *   ON DELETE:
 *     2. onReplyDeleted  (aura.js) — decrement replyCount on the parent post.
 *
 * Eventarc only allows one Cloud Function per unique document path.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../../lib/firebase.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { AURA_POINTS } from "../../lib/constants.js";
import { awardAura } from "../../lib/aura_service.js";

// =============================================================================
// CREATE-branch handler — was `awardReplyAura`
// =============================================================================

async function handleReplyCreated(reply, postId, replyId) {
    try {
        const postDoc = await db.collection("posts").doc(postId).get();

        if (!postDoc.exists) {
            logger.warn("Original post not found for reply", { postId, replyId });
            return;
        }

        const post = postDoc.data();
        const postAuthor = post.author;
        const replyAuthor = reply.author;

        // Always increment replyCount (even for self-replies)
        await db.collection("posts").doc(postId).update({
            replyCount: FieldValue.increment(1),
        });

        logger.info("Reply count incremented", { postId, replyId });

        if (!postAuthor || !replyAuthor) {
            logger.warn("Missing author information for aura", { postId, replyId });
            return;
        }

        if (postAuthor === replyAuthor) {
            // Self-reply - don't award aura but count is already incremented
            return;
        }

        await awardAura(
            postAuthor,
            AURA_POINTS.POST_REPLY_RECEIVED,
            "Received reply on post",
            { replyAuthor, postId, replyId, action: "post_reply_received" },
        );

        await awardAura(
            replyAuthor,
            AURA_POINTS.CREATE_REPLY,
            "Created reply",
            { postId, replyId, action: "reply_created" },
        );
    } catch (error) {
        logger.error("Error processing reply", { error: error.message, postId, replyId });
    }
}

// =============================================================================
// DELETE-branch handler — was `onReplyDeleted`
// =============================================================================

async function handleReplyDeleted(postId, replyId) {
    try {
        const postDoc = await db.collection("posts").doc(postId).get();

        if (!postDoc.exists) {
            logger.warn("Original post not found for reply deletion", { postId, replyId });
            return;
        }

        await db.collection("posts").doc(postId).update({
            replyCount: FieldValue.increment(-1),
        });

        logger.info("Reply count decremented", { postId, replyId });
    } catch (error) {
        logger.error("Error processing reply deletion", { error: error.message, postId, replyId });
    }
}

// =============================================================================
// Unified Cloud Function
// =============================================================================

const createPipeline = withIdempotency("onReplyWrite:create", async (event) => {
    const snap = event.data?.after;
    if (!snap) return;
    const reply = snap.data();
    if (!reply) {
        logger.warn("No reply data found", { postId: event.params.postId, replyId: event.params.replyId });
        return;
    }
    await handleReplyCreated(reply, event.params.postId, event.params.replyId);
});

const deletePipeline = withIdempotency("onReplyWrite:delete", async (event) => {
    await handleReplyDeleted(event.params.postId, event.params.replyId);
});

export const onReplyWrite = onDocumentWritten("postReplies/{postId}/replies/{replyId}", async (event) => {
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
