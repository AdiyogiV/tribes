import { HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { isBlockedEitherWay as _isBlockedEitherWay } from "../lib/utils.js";
import { awardAura } from "../lib/aura_service.js";
import { AURA_POINTS } from "../lib/constants.js";

/**
 * Follow System - Callable Handlers (gateway-invoked).
 *
 * NOTE: The Firestore triggers previously defined here
 *   - onFollow         (onDocumentCreated)
 *   - onFollowApproved (onDocumentUpdated)
 *   - onUnfollow       (onDocumentDeleted)
 * have been merged into the path-based trigger
 * `functions/triggers/on_follow_write.js`
 * (onDocumentWritten on userFollowing/{followerId}/following/{targetUserId}).
 *
 * This file now only contains the callable handlers
 * (`handleAcceptFollowRequest`, `handleRejectFollowRequest`) wired into the
 * social gateway, plus a few local helpers they need.
 */

/** @see ../lib/utils.js — consolidated blocking utility */
async function isBlockedEitherWay(userId1, userId2) {
    return _isBlockedEitherWay(db, userId1, userId2);
}

/**
 * Check if a mutual follow now exists (both users follow each other)
 */
async function checkMutualFollowCreated(followerId, targetUserId) {
    try {
        // Check if target is also following the follower
        const reverseFollowDoc = await db
            .collection("userFollowing")
            .doc(targetUserId)
            .collection("following")
            .doc(followerId)
            .get();

        if (!reverseFollowDoc.exists) {
            return false;
        }

        // Check that reverse follow is also confirmed
        const status = reverseFollowDoc.data()?.status || "following";
        return status === "following";
    } catch (error) {
        logger.warn("Error checking mutual follow", { error: error.message });
        return false;
    }
}

/**
 * Send follow accepted notification to the follower (when private profile approves)
 */
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

/**
 * Send "now friends" notification when mutual follow is created
 * This is the VIRAL moment - both users discover their compatibility!
 */
async function sendMutualFollowNotification(user1Id, user2Id) {
    try {
        // Fetch both users' data
        const [user1Doc, user2Doc] = await Promise.all([
            db.collection("users").doc(user1Id).get(),
            db.collection("users").doc(user2Id).get(),
        ]);

        const user1Data = user1Doc.data();
        const user2Data = user2Doc.data();

        if (!user1Data || !user2Data) return;

        const user1Name = user1Data.name || user1Data.username || "Someone";
        const user2Name = user2Data.name || user2Data.username || "Someone";

        // Create notifications for BOTH users (this is the reveal moment!)
        await Promise.all([
            // Notification for user1
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
            // Notification for user2
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

/**
 * CALLABLE: Accept a follow request (for private profiles)
 *
 * Called by the target user (private profile owner) to accept a pending follow request.
 * This is a Cloud Function because:
 * - The target user needs to update the follower's document
 * - Firestore rules only allow document owner to write to their userFollowing
 * - Backend has Admin SDK which bypasses rules
 */
export async function handleAcceptFollowRequest(request) {
    const { followerId } = request.data || {};
    const currentUserId = request.auth?.uid;

    if (!currentUserId) {
        throw new HttpsError("unauthenticated", "Must be logged in to accept follow requests");
    }

    if (!followerId || typeof followerId !== "string") {
        throw new HttpsError("invalid-argument", "followerId is required");
    }

    if (followerId === currentUserId) {
        throw new HttpsError("invalid-argument", "Cannot accept follow request from yourself");
    }

    try {
        // Verify the follow request exists and is pending
        const followRef = db
            .collection("userFollowing")
            .doc(followerId)
            .collection("following")
            .doc(currentUserId);

        const followDoc = await followRef.get();

        if (!followDoc.exists) {
            throw new HttpsError("not-found", "Follow request not found");
        }

        const followData = followDoc.data();
        if (followData?.status !== "pending") {
            // Already approved or in unexpected state
            if (followData?.status === "following") {
                return { success: true, message: "Already following" };
            }
            throw new HttpsError("failed-precondition", "Invalid follow request status");
        }

        // Check if follower record already exists (idempotency)
        const followerRef = db
            .collection("userFollowers")
            .doc(currentUserId)
            .collection("followers")
            .doc(followerId);

        const followerDoc = await followerRef.get();
        const followerExists = followerDoc.exists;

        // Do everything in one transaction for atomicity
        await db.runTransaction(async (transaction) => {
            // Update status to 'following'
            transaction.update(followRef, { status: "following" });

            // Only create follower record and update counts if not already done
            if (!followerExists) {
                transaction.set(followerRef, {
                    followerId: followerId,
                    status: "following",
                    timestamp: FieldValue.serverTimestamp(),
                });

                const followerUserRef = db.collection("users").doc(followerId);
                transaction.update(followerUserRef, {
                    followingCount: FieldValue.increment(1),
                });

                const targetUserRef = db.collection("users").doc(currentUserId);
                transaction.update(targetUserRef, {
                    followerCount: FieldValue.increment(1),
                });
            }
        });

        logger.info("Follow request accepted via callable (full flow)", {
            structuredData: true,
            followerId,
            targetUserId: currentUserId,
            followerRecordCreated: !followerExists,
        });

        // Aura: new follower (+5) when we created the follower record (onFollowApproved won't run awardAura because record already exists)
        if (!followerExists) {
            await awardAura(currentUserId, AURA_POINTS.NEW_FOLLOWER, "New follower", { followerId, action: "new_follower" });
        }

        // Send acceptance notification to the follower (async, don't wait)
        sendFollowAcceptedNotification(followerId, currentUserId).catch((err) => {
            logger.warn("Failed to send follow accepted notification", {
                error: err.message,
                followerId,
                targetUserId: currentUserId,
            });
        });

        // Check if this creates a mutual follow (friends!)
        checkMutualFollowCreated(followerId, currentUserId).then(async (isMutual) => {
            if (isMutual) {
                const isBlocked = await isBlockedEitherWay(followerId, currentUserId);
                if (!isBlocked) {
                    logger.info("Mutual follow detected! Sending friend notifications", {
                        structuredData: true,
                        followerId,
                        targetUserId: currentUserId,
                    });
                    await sendMutualFollowNotification(followerId, currentUserId);
                }
            }
        }).catch((err) => {
            logger.warn("Failed to check/send mutual follow notification", {
                error: err.message,
                followerId,
                targetUserId: currentUserId,
            });
        });

        return { success: true };
    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        logger.error("Error accepting follow request", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId: currentUserId,
        });
        throw new HttpsError("internal", "Failed to accept follow request");
    }
}

/**
 * CALLABLE: Reject/decline a follow request (for private profiles)
 *
 * Called by the target user (private profile owner) to reject a pending follow request.
 * Deletes the follow document, which triggers the unfollow branch of onFollowWrite.
 */
export async function handleRejectFollowRequest(request) {
    const { followerId } = request.data || {};
    const currentUserId = request.auth?.uid;

    if (!currentUserId) {
        throw new HttpsError("unauthenticated", "Must be logged in to reject follow requests");
    }

    if (!followerId || typeof followerId !== "string") {
        throw new HttpsError("invalid-argument", "followerId is required");
    }

    if (followerId === currentUserId) {
        throw new HttpsError("invalid-argument", "Cannot reject follow request from yourself");
    }

    try {
        // Verify the follow request exists
        const followRef = db
            .collection("userFollowing")
            .doc(followerId)
            .collection("following")
            .doc(currentUserId);

        const followDoc = await followRef.get();

        if (!followDoc.exists) {
            // Already deleted/rejected - idempotent success
            return { success: true, message: "Follow request not found or already rejected" };
        }

        // Delete the follow document - this triggers the unfollow branch of onFollowWrite.
        await followRef.delete();

        logger.info("Follow request rejected via callable", {
            structuredData: true,
            followerId,
            targetUserId: currentUserId,
        });

        return { success: true };
    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        logger.error("Error rejecting follow request", {
            structuredData: true,
            error: error.message,
            followerId,
            targetUserId: currentUserId,
        });
        throw new HttpsError("internal", "Failed to reject follow request");
    }
}
