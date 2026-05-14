import { logger } from "firebase-functions";
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { withIdempotency } from "../lib/idempotency.js";
import { AURA_POINTS } from "../lib/constants.js";

/**
 * Helper: award aura points to a user (positive only). Exported for use by follows.js etc.
 */
export async function awardAura(userId, points, reason, metadata = {}) {
    if (!userId || points <= 0) {
        logger.warn("awardAura: skipped (invalid params)", {
            structuredData: true,
            userId: userId || null,
            points,
            reason,
        });
        return false;
    }

    const db = getFirestore();
    const batch = db.batch();

    try {
        const userRef = db.collection("users").doc(userId);
        batch.set(
            userRef,
            {
                auraScore: FieldValue.increment(points),
                lastAuraUpdate: FieldValue.serverTimestamp(),
            },
            { merge: true },
        );

        const historyRef = db
            .collection("users")
            .doc(userId)
            .collection("auraHistory")
            .doc();

        batch.set(historyRef, {
            points,
            reason,
            timestamp: FieldValue.serverTimestamp(),
            metadata,
        });

        await batch.commit();

        logger.info(`Awarded ${points} aura to user ${userId} for: ${reason}`);
        return true;
    } catch (error) {
        logger.error("Error awarding aura:", error);
        return false;
    }
}

/**
 * Cloud Function: Award aura when a top-level post is created in posts/ (writes to auraHistory).
 * Skips replies (posts with replyTo) – reply author is awarded by awardReplyAura.
 */
export const awardCreatePostAura = onDocumentCreated(
    "posts/{postId}",
    withIdempotency("awardCreatePostAura", async (event) => {
        const postData = event.data?.data();
        const { postId } = event.params;

        if (!postData?.author) {
            logger.warn("Post missing author, skipping create-post aura", { postId });
            return null;
        }

        // Only award for top-level posts (no replyTo)
        if (postData.replyTo) {
            return null;
        }

        await awardAura(
            postData.author,
            AURA_POINTS.CREATE_POST,
            "Created post",
            { postId, action: "post_created" },
        );

        logger.info("Created-post aura awarded", { postId, author: postData.author });
        return null;
    }),
);

/**
 * Cloud Function: Award aura when a top-level space post is created (e.g. video in spacePosts).
 * Writes to auraHistory. Skips replies.
 */
export const awardCreateSpacePostAura = onDocumentCreated(
    "spacePosts/{spaceId}/posts/{postId}",
    withIdempotency("awardCreateSpacePostAura", async (event) => {
        const postData = event.data?.data();
        const { postId, spaceId } = event.params;

        if (!postData?.author) {
            logger.warn("Space post missing author, skipping create-post aura", { postId, spaceId });
            return null;
        }

        if (postData.replyTo) {
            return null;
        }

        await awardAura(
            postData.author,
            AURA_POINTS.CREATE_POST,
            "Created post",
            { postId, spaceId, action: "space_post_created" },
        );

        logger.info("Created-space-post aura awarded", { postId, spaceId, author: postData.author });
        return null;
    }),
);

// REMOVED: awardNamasteAura Cloud Function trigger.
// It was a no-op that fired on EVERY notification doc create and just returned null,
// wasting invocations. Namaste aura is awarded inline in namaste.js via the local
// helper `awardNamasteAuraToRecipient()` (see sendNamaste flow).

/**
 * Cloud Function: Handle new reply - increment replyCount and award aura
 */
export const awardReplyAura = onDocumentCreated(
    "postReplies/{postId}/replies/{replyId}",
    withIdempotency("awardReplyAura", async (event) => {
        const reply = event.data?.data();
        const postId = event.params.postId;
        const replyId = event.params.replyId;

        if (!reply) {
            logger.warn("No reply data found", { postId, replyId });
            return null;
        }

        const db = getFirestore();

        try {
            // Get the original post to find the author
            const postDoc = await db.collection("posts").doc(postId).get();

            if (!postDoc.exists) {
                logger.warn("Original post not found for reply", { postId, replyId });
                return null;
            }

            const post = postDoc.data();
            const postAuthor = post.author;
            const replyAuthor = reply.author;

            // Always increment replyCount (even for self-replies)
            await db.collection("posts").doc(postId).update({
                replyCount: FieldValue.increment(1),
            });

            logger.info("Reply count incremented", { postId, replyId });

            // Skip aura if missing authors or self-reply
            if (!postAuthor || !replyAuthor) {
                logger.warn("Missing author information for aura", { postId, replyId });
                return null;
            }

            if (postAuthor === replyAuthor) {
                // Self-reply - don't award aura but count is already incremented
                return null;
            }

            // Award aura to post author for receiving a reply
            await awardAura(
                postAuthor,
                AURA_POINTS.POST_REPLY_RECEIVED,
                "Received reply on post",
                { replyAuthor, postId, replyId, action: "post_reply_received" },
            );

            // Award aura to reply author for creating a reply
            await awardAura(
                replyAuthor,
                AURA_POINTS.CREATE_REPLY,
                "Created reply",
                { postId, replyId, action: "reply_created" },
            );

            return null;
        } catch (error) {
            logger.error("Error processing reply", { error: error.message, postId, replyId });
            return null;
        }
    }),
);

/**
 * Cloud Function: Handle reply deletion - decrement replyCount
 */
export const onReplyDeleted = onDocumentDeleted(
    "postReplies/{postId}/replies/{replyId}",
    withIdempotency("onReplyDeleted", async (event) => {
        const postId = event.params.postId;
        const replyId = event.params.replyId;

        const db = getFirestore();

        try {
            const postDoc = await db.collection("posts").doc(postId).get();

            if (!postDoc.exists) {
                logger.warn("Original post not found for reply deletion", { postId, replyId });
                return null;
            }

            // Decrement replyCount
            await db.collection("posts").doc(postId).update({
                replyCount: FieldValue.increment(-1),
            });

            logger.info("Reply count decremented", { postId, replyId });

            return null;
        } catch (error) {
            logger.error("Error processing reply deletion", { error: error.message, postId, replyId });
            return null;
        }
    }),
);

/**
 * Cloud Function: Award aura when a post like is created
 * Note: likeCount is handled separately in likes_and_invites.js
 */
export const awardLikeAura = onDocumentCreated(
    "postLikes/{postId}/likes/{userId}",
    withIdempotency("awardLikeAura", async (event) => {
        const postId = event.params.postId;
        const likerUserId = event.params.userId;

        const db = getFirestore();

        try {
            // Get the post to find the author
            const postDoc = await db.collection("posts").doc(postId).get();

            if (!postDoc.exists) {
                logger.warn("Post not found for aura award", { postId, likerUserId });
                return null;
            }

            const post = postDoc.data();
            const postAuthor = post.author;

            if (!postAuthor || !likerUserId) {
                logger.warn("Missing author for aura award", { postId, likerUserId });
                return null;
            }

            // Don't award if liking own post
            if (postAuthor === likerUserId) {
                return null;
            }

            // Award aura to post author for receiving a like
            await awardAura(
                postAuthor,
                AURA_POINTS.POST_LIKE_RECEIVED,
                "Received like on post",
                { likerUserId, postId, action: "post_like_received" },
            );

            logger.info("Like aura awarded", { postId, likerUserId, postAuthor });

            return null;
        } catch (error) {
            logger.error("Error awarding like aura", { error: error.message, postId, likerUserId });
            return null;
        }
    }),
);

/**
 * Single callable for client-initiated aura awards. Pass { action: "profile_complete" | "astrology_setup" | "daily_insight_view" }.
 * Keeps one function to deploy and one place to add new actions.
 */
export const awardAuraAction = onCall(
    { region: "asia-southeast2", invoker: "public" },
    async (request) => {
        const userId = request.auth?.uid;
        if (!userId) {
            throw new HttpsError("unauthenticated", "Must be signed in");
        }

        const action = request.data?.action;
        if (!action) {
            throw new HttpsError("invalid-argument", "Missing action");
        }

        logger.info("awardAuraAction called", { userId, action });

        const db = getFirestore();
        const userRef = db.collection("users").doc(userId);
        const userSnap = await userRef.get();
        if (!userSnap.exists) {
            throw new HttpsError("not-found", "User not found");
        }
        const data = userSnap.data();

        if (action === "profile_complete") {
            logger.info("awardAuraAction profile_complete", {
                userId,
                auraProfileCompleteAwarded: data.auraProfileCompleteAwarded,
                hasName: !!(data.name != null && String(data.name).trim() !== ""),
                hasNickname: !!(data.nickname != null && String(data.nickname).trim() !== ""),
                hasPicture: !!(data.displayPicture != null && String(data.displayPicture).trim() !== ""),
            });
            if (data.auraProfileCompleteAwarded === true) {
                logger.info("Profile complete already awarded, skipping", { userId });
                return { success: true, alreadyAwarded: true };
            }
            const hasName = data.name != null && String(data.name).trim() !== "";
            const hasNickname = data.nickname != null && String(data.nickname).trim() !== "";
            const hasPicture = data.displayPicture != null && String(data.displayPicture).trim() !== "";
            if (!hasName || !hasNickname || !hasPicture) {
                logger.info("Profile incomplete, not awarding", { userId, hasName, hasNickname, hasPicture });
                return { success: false, reason: "profile_incomplete" };
            }
            await awardAura(userId, AURA_POINTS.PROFILE_COMPLETE, "Profile complete", { action: "profile_complete" });
            await userRef.set({ auraProfileCompleteAwarded: true }, { merge: true });
            logger.info("Profile complete aura awarded", { userId, points: AURA_POINTS.PROFILE_COMPLETE });
            return { success: true, alreadyAwarded: false };
        }

        if (action === "astrology_setup") {
            if (data.auraAstrologySetupAwarded === true) {
                return { success: true, alreadyAwarded: true };
            }
            await awardAura(userId, AURA_POINTS.ASTROLOGY_SETUP, "Astrology setup", { action: "astrology_setup" });
            await userRef.set({ auraAstrologySetupAwarded: true }, { merge: true });
            logger.info("Astrology setup aura awarded", { userId });
            return { success: true, alreadyAwarded: false };
        }

        if (action === "daily_insight_view") {
            const today = new Date().toISOString().split("T")[0];
            const trackingRef = db.collection("users").doc(userId).collection("auraTracking").doc(`daily_insight_view_${today}`);
            if ((await trackingRef.get()).exists) {
                return { success: true, alreadyAwarded: true };
            }
            await awardAura(userId, AURA_POINTS.DAILY_INSIGHT_VIEW, "Viewed daily insight", { action: "daily_insight_view", date: today });
            await trackingRef.set({
                points: AURA_POINTS.DAILY_INSIGHT_VIEW,
                reason: "Viewed daily insight",
                timestamp: FieldValue.serverTimestamp(),
                metadata: { date: today },
            });
            logger.info("Daily insight view aura awarded", { userId, date: today });
            return { success: true, alreadyAwarded: false };
        }

        throw new HttpsError("invalid-argument", "Unknown action");
    },
);

// REMOVED: getUserAuraRank, getAuraLeaderboard, awardManualAura.
// - getUserAuraRank / getAuraLeaderboard: Flutter app computes rank/leaderboard
//   client-side from Firestore reads (see lib aura_service.dart). The backend
//   callables were never wired into the active UI code path.
// - awardManualAura: SECURITY HOLE — `invoker: public` + no admin role check
//   meant any authenticated user could award arbitrary aura to anyone.
//   No admin UI existed to use it safely; removed.


