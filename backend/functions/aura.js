import { logger } from "firebase-functions";
import { HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { AURA_POINTS } from "../lib/constants.js";
// Shared aura helper — lives in lib/ so any domain can import without
// pulling in this Cloud Function file. Re-exported here for backward compat.
import { awardAura } from "../lib/aura_service.js";
export { awardAura };

/**
 * NOTE: The previously-defined Firestore triggers
 *   - awardCreatePostAura       (posts/{postId})
 *   - awardCreateSpacePostAura  (spacePosts/{spaceId}/posts/{postId})
 *   - awardReplyAura            (postReplies/{postId}/replies/{replyId})
 *   - onReplyDeleted            (postReplies/{postId}/replies/{replyId})
 *   - awardLikeAura             (postLikes/{postId}/likes/{userId})
 * have been merged into path-based triggers under `functions/triggers/`:
 *   - on_post_write.js      (posts/{postId})
 *   - on_space_post_write.js(spacePosts/{spaceId}/posts/{postId})
 *   - on_reply_write.js     (postReplies/{postId}/replies/{replyId})
 *   - on_post_like_write.js (postLikes/{postId}/likes/{userId})
 *
 * The standalone `awardAuraAction` onCall export has also been removed.
 * Its handler now lives below as `handleAwardAuraAction` and is wired into
 * `socialGateway` (method: 'awardAuraAction').
 */

// REMOVED: awardNamasteAura Cloud Function trigger.
// It was a no-op that fired on EVERY notification doc create and just returned null,
// wasting invocations. Namaste aura is awarded inline in namaste.js via the local
// helper `awardNamasteAuraToRecipient()` (see sendNamaste flow).

/**
 * Handler: Client-initiated aura awards. Extracted for socialGateway reuse.
 *
 * Pass { action: "profile_complete" | "astrology_setup" | "daily_insight_view" }.
 * Keeps one source of truth so new actions can be added in one place.
 */
export async function handleAwardAuraAction(request) {
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
}

// REMOVED: getUserAuraRank, getAuraLeaderboard, awardManualAura.
// - getUserAuraRank / getAuraLeaderboard: Flutter app computes rank/leaderboard
//   client-side from Firestore reads (see lib aura_service.dart). The backend
//   callables were never wired into the active UI code path.
// - awardManualAura: SECURITY HOLE — `invoker: public` + no admin role check
//   meant any authenticated user could award arbitrary aura to anyone.
//   No admin UI existed to use it safely; removed.
