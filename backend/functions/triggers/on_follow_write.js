/**
 * onFollowWrite — Consolidated trigger for `userFollowing/{followerId}/following/{targetUserId}` writes.
 *
 * Merges three previously separate Cloud Functions on the same path:
 *
 *   ON CREATE:
 *     1. onFollow          (follows.js) — new follow. If target is public, approve
 *        immediately (creates follower record, increments counts, sends "follow"
 *        notification + aura). If private, mark pending + send "followRequest".
 *
 *   ON UPDATE:
 *     2. onFollowApproved  (follows.js) — fires when status flips from 'pending'
 *        to 'following' (private profile accepts a pending request). Creates
 *        follower record, increments counts, sends "followAccepted" + aura, and
 *        emits "mutualFollow" notification if reciprocal follow exists.
 *
 *   ON DELETE:
 *     3. onUnfollow        (follows.js) — deletes follower record, decrements counts.
 *
 * Eventarc only allows one Cloud Function per unique document path.
 *
 * IMPORTANT: this file re-implements all helper logic locally rather than
 * importing from `follows.js`, because importing the old file would also
 * pull in the old onDocumentCreated/Updated/Deleted exports (Firebase Gen2
 * registers them on import). The callable handlers (handleAcceptFollowRequest /
 * handleRejectFollowRequest) remain in `follows.js` and are still routed
 * via `socialGateway` — they are NOT re-exported there.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../../lib/firebase.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { isBlockedEitherWay as _isBlockedEitherWay } from "../../lib/utils.js";
import { awardAura } from "../../lib/aura_service.js";
import { AURA_POINTS } from "../../lib/constants.js";

// =============================================================================
// Helpers (verbatim from follows.js)
// =============================================================================

async function isPrivateProfile(userId) {
    try {
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        return userData?.isPrivateProfile === true;
    } catch (error) {
        logger.warn("Error checking private profile", { userId, error: error.message });
        return false;
    }
}

async function isBlockedEitherWay(userId1, userId2) {
    return _isBlockedEitherWay(db, userId1, userId2);
}

async function checkMutualFollowCreated(followerId, targetUserId) {
    try {
        const reverseFollowDoc = await db
            .collection("userFollowing")
            .doc(targetUserId)
            .collection("following")
            .doc(followerId)
            .get();

        if (!reverseFollowDoc.exists) {
            return false;
        }

        const status = reverseFollowDoc.data()?.status || "following";
        return status === "following";
    } catch (error) {
        logger.warn("Error checking mutual follow", { error: error.message });
        return false;
    }
}

async function approveFollow(followerId, targetUserId, followDocRef) {
    logger.info("approveFollow: Starting", {
        structuredData: true,
        followerId,
        targetUserId,
    });

    await db.runTransaction(async (transaction) => {
        const followerRef = db
            .collection("userFollowers")
            .doc(targetUserId)
            .collection("followers")
            .doc(followerId);

        transaction.set(followerRef, {
            followerId: followerId,
            status: "following",
            timestamp: FieldValue.serverTimestamp(),
        });

        transaction.update(followDocRef, {
            status: "following",
        });

        const followerUserRef = db.collection("users").doc(followerId);
        transaction.update(followerUserRef, {
            followingCount: FieldValue.increment(1),
        });

        const targetUserRef = db.collection("users").doc(targetUserId);
        transaction.update(targetUserRef, {
            followerCount: FieldValue.increment(1),
        });
    });

    logger.info("approveFollow: transaction committed", {
        structuredData: true,
        followerId,
        targetUserId,
    });

    const auraOk = await awardAura(targetUserId, AURA_POINTS.NEW_FOLLOWER, "New follower", { followerId, action: "new_follower" });
    logger.info("approveFollow: awardAura result", {
        structuredData: true,
        targetUserId,
        auraOk,
        points: AURA_POINTS.NEW_FOLLOWER,
    });

    const isMutual = await checkMutualFollowCreated(followerId, targetUserId);
    if (isMutual) {
        const isBlocked = await isBlockedEitherWay(followerId, targetUserId);
        if (isBlocked) {
            logger.info("Mutual follow detected but users have a block - skipping notification", {
                structuredData: true,
                followerId,
                targetUserId,
            });
            return;
        }

        logger.info("Mutual follow detected! Sending friend notifications", {
            structuredData: true,
            followerId,
            targetUserId,
        });

        await sendMutualFollowNotification(followerId, targetUserId);
    }
}

async function sendFollowNotification(followerId, targetUserId) {
    try {
        const followerDoc = await db.collection("users").doc(followerId).get();
        const followerData = followerDoc.data();

        if (!followerData) return;

        const followerName = followerData.name || followerData.username || "Someone";

        await db
            .collection("notifications")
            .doc(targetUserId)
            .collection("notifications")
            .add({
                type: "follow",
                fromUserId: followerId,
                fromUserName: followerName,
                fromUserAvatar: followerData.displayPicture || followerData.avatarUrl || null,
                message: `${followerName} started following you`,
                read: false,
                timestamp: FieldValue.serverTimestamp(),
            });

        logger.info("Follow notification sent", { structuredData: true, followerId, targetUserId });
    } catch (error) {
        logger.error("Error sending follow notification", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId,
        });
    }
}

async function sendFollowRequestNotification(followerId, targetUserId) {
    try {
        const followerDoc = await db.collection("users").doc(followerId).get();
        const followerData = followerDoc.data();

        if (!followerData) return;

        const followerName = followerData.name || followerData.username || "Someone";

        await db
            .collection("notifications")
            .doc(targetUserId)
            .collection("notifications")
            .add({
                type: "followRequest",
                fromUserId: followerId,
                fromUserName: followerName,
                fromUserAvatar: followerData.displayPicture || followerData.avatarUrl || null,
                message: `${followerName} wants to follow you`,
                read: false,
                timestamp: FieldValue.serverTimestamp(),
            });

        logger.info("Follow request notification sent", { structuredData: true, followerId, targetUserId });
    } catch (error) {
        logger.error("Error sending follow request notification", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId,
        });
    }
}

async function sendFollowAcceptedNotification(followerId, targetUserId) {
    try {
        const targetDoc = await db.collection("users").doc(targetUserId).get();
        const targetData = targetDoc.data();

        if (!targetData) return;

        const targetName = targetData.name || targetData.username || "Someone";

        await db
            .collection("notifications")
            .doc(followerId)
            .collection("notifications")
            .add({
                type: "followAccepted",
                fromUserId: targetUserId,
                fromUserName: targetName,
                fromUserAvatar: targetData.displayPicture || targetData.avatarUrl || null,
                message: `${targetName} accepted your follow request`,
                read: false,
                timestamp: FieldValue.serverTimestamp(),
            });

        logger.info("Follow accepted notification sent", { structuredData: true, followerId, targetUserId });
    } catch (error) {
        logger.error("Error sending follow accepted notification", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId,
        });
    }
}

async function sendMutualFollowNotification(user1Id, user2Id) {
    try {
        const [user1Doc, user2Doc] = await Promise.all([
            db.collection("users").doc(user1Id).get(),
            db.collection("users").doc(user2Id).get(),
        ]);

        const user1Data = user1Doc.data();
        const user2Data = user2Doc.data();

        if (!user1Data || !user2Data) return;

        const user1Name = user1Data.name || user1Data.username || "Someone";
        const user2Name = user2Data.name || user2Data.username || "Someone";

        await Promise.all([
            db.collection("notifications")
                .doc(user1Id)
                .collection("notifications")
                .add({
                    type: "mutualFollow",
                    fromUserId: user2Id,
                    fromUserName: user2Name,
                    fromUserAvatar: user2Data.displayPicture || user2Data.avatarUrl || null,
                    message: `🎉 You and ${user2Name} are now friends! Tap to see your compatibility`,
                    read: false,
                    timestamp: FieldValue.serverTimestamp(),
                }),
            db.collection("notifications")
                .doc(user2Id)
                .collection("notifications")
                .add({
                    type: "mutualFollow",
                    fromUserId: user1Id,
                    fromUserName: user1Name,
                    fromUserAvatar: user1Data.displayPicture || user1Data.avatarUrl || null,
                    message: `🎉 You and ${user1Name} are now friends! Tap to see your compatibility`,
                    read: false,
                    timestamp: FieldValue.serverTimestamp(),
                }),
        ]);

        logger.info("Mutual follow notifications sent to both users", {
            structuredData: true,
            user1Id,
            user2Id,
        });
    } catch (error) {
        logger.error("Error sending mutual follow notification", {
            structuredData: true,
            error: error.message,
            user1Id,
            user2Id,
        });
    }
}

// =============================================================================
// Branch handlers
// =============================================================================

/**
 * CREATE branch — was `onFollow`.
 */
async function handleFollowCreated(event) {
    const { followerId, targetUserId } = event.params;
    const followData = event.data?.after?.data();

    logger.info("onFollow: triggered", {
        structuredData: true,
        followerId,
        targetUserId,
        status: followData?.status,
        hasData: !!followData,
    });

    if (!followData) {
        logger.warn("onFollow: No data in follow document", { followerId, targetUserId });
        return;
    }

    if (followerId === targetUserId) {
        logger.warn("onFollow: Self-follow attempted", { followerId });
        await event.data.after.ref.delete();
        return;
    }

    try {
        const isPrivate = await isPrivateProfile(targetUserId);

        if (isPrivate) {
            const currentStatus = followData.status;
            if (currentStatus !== "pending") {
                logger.info("Correcting follow status for private profile", {
                    structuredData: true,
                    followerId,
                    targetUserId,
                    originalStatus: currentStatus,
                    newStatus: "pending",
                });
                await event.data.after.ref.update({ status: "pending" });
            }

            logger.info("Follow request pending (private profile)", {
                structuredData: true,
                followerId,
                targetUserId,
            });

            await sendFollowRequestNotification(followerId, targetUserId);
            return;
        }

        logger.info("onFollow: public profile, approving follow", {
            structuredData: true,
            followerId,
            targetUserId,
        });
        await approveFollow(followerId, targetUserId, event.data.after.ref);
        logger.info("onFollow: approveFollow completed (public)", {
            structuredData: true,
            followerId,
            targetUserId,
        });

        sendFollowNotification(followerId, targetUserId).catch((err) => {
            logger.warn("Failed to send follow notification", {
                error: err.message,
                followerId,
                targetUserId,
            });
        });
    } catch (error) {
        logger.error("Error processing follow", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId,
        });
        throw error;
    }
}

/**
 * UPDATE branch — was `onFollowApproved`. Only fires when status flips from
 * 'pending' → 'following'.
 */
async function handleFollowUpdated(event) {
    const { followerId, targetUserId } = event.params;
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (beforeData?.status !== "pending" || afterData?.status !== "following") {
        return;
    }

    try {
        const followerRef = db
            .collection("userFollowers")
            .doc(targetUserId)
            .collection("followers")
            .doc(followerId);

        const followerDoc = await followerRef.get();
        if (followerDoc.exists) {
            logger.info("Follower record already exists, skipping", { followerId, targetUserId });
            return;
        }

        await db.runTransaction(async (transaction) => {
            transaction.set(followerRef, {
                followerId: followerId,
                status: "following",
                timestamp: FieldValue.serverTimestamp(),
            });

            const followerUserRef = db.collection("users").doc(followerId);
            transaction.update(followerUserRef, {
                followingCount: FieldValue.increment(1),
            });

            const targetUserRef = db.collection("users").doc(targetUserId);
            transaction.update(targetUserRef, {
                followerCount: FieldValue.increment(1),
            });
        });

        logger.info("Follow request approved (private profile)", {
            structuredData: true,
            followerId,
            targetUserId,
        });

        await awardAura(targetUserId, AURA_POINTS.NEW_FOLLOWER, "New follower", { followerId, action: "new_follower" });

        sendFollowAcceptedNotification(followerId, targetUserId).catch((err) => {
            logger.warn("Failed to send follow accepted notification", {
                error: err.message,
                followerId,
                targetUserId,
            });
        });

        const isMutual = await checkMutualFollowCreated(followerId, targetUserId);
        if (isMutual) {
            const isBlocked = await isBlockedEitherWay(followerId, targetUserId);
            if (!isBlocked) {
                logger.info("Mutual follow detected after private approval! Sending friend notifications", {
                    structuredData: true,
                    followerId,
                    targetUserId,
                });
                await sendMutualFollowNotification(followerId, targetUserId);
            } else {
                logger.info("Mutual follow after private approval but users have a block - skipping notification", {
                    structuredData: true,
                    followerId,
                    targetUserId,
                });
            }
        }
    } catch (error) {
        logger.error("Error processing follow approval", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId,
        });
        throw error;
    }
}

/**
 * DELETE branch — was `onUnfollow`.
 */
async function handleFollowDeleted(event) {
    const { followerId, targetUserId } = event.params;

    try {
        await db.runTransaction(async (transaction) => {
            const followerRef = db
                .collection("userFollowers")
                .doc(targetUserId)
                .collection("followers")
                .doc(followerId);

            const followerDoc = await transaction.get(followerRef);

            if (followerDoc.exists) {
                transaction.delete(followerRef);

                const followerUserRef = db.collection("users").doc(followerId);
                transaction.update(followerUserRef, {
                    followingCount: FieldValue.increment(-1),
                });

                const targetUserRef = db.collection("users").doc(targetUserId);
                transaction.update(targetUserRef, {
                    followerCount: FieldValue.increment(-1),
                });
            } else {
                logger.warn("Follower record not found during unfollow", {
                    structuredData: true,
                    followerId,
                    targetUserId,
                });
            }
        });

        logger.info("Unfollow processed successfully", {
            structuredData: true,
            followerId,
            targetUserId,
        });
    } catch (error) {
        logger.error("Error processing unfollow", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId,
        });
        throw error;
    }
}

// =============================================================================
// Unified Cloud Function
// =============================================================================

const createPipeline = withIdempotency("onFollowWrite:create", handleFollowCreated);
const updatePipeline = withIdempotency("onFollowWrite:update", handleFollowUpdated);
const deletePipeline = withIdempotency("onFollowWrite:delete", handleFollowDeleted);

export const onFollowWrite = onDocumentWritten("userFollowing/{followerId}/following/{targetUserId}", async (event) => {
    const beforeExists = event.data?.before?.exists ?? false;
    const afterExists = event.data?.after?.exists ?? false;

    if (!beforeExists && afterExists) {
        await createPipeline(event);
        return null;
    }

    if (beforeExists && afterExists) {
        await updatePipeline(event);
        return null;
    }

    if (beforeExists && !afterExists) {
        await deletePipeline(event);
        return null;
    }

    return null;
});
