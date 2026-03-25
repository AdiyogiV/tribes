import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";
import { awardAura } from "./aura.js";
import { AURA_POINTS } from "../lib/constants.js";

/**
 * Follow System - Backend Handlers
 * 
 * Architecture:
 * - Frontend writes to: userFollowing/{userId}/following/{targetId} with status='pending'
 * - Backend handles:
 *   - If target is public: immediately set status='following', create follower record, update counts
 *   - If target is private: keep status='pending', send follow request notification
 *   - On approval: set status='following', create follower record, update counts
 * 
 * This keeps the frontend light and ensures data integrity.
 */

/**
 * Check if a user has a private profile
 */
async function isPrivateProfile(userId) {
    try {
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        return userData?.isPrivateProfile === true;
    } catch (error) {
        logger.warn("Error checking private profile", { userId, error: error.message });
        return false; // Default to public on error
    }
}

/**
 * Check if either user has blocked the other
 * @returns {boolean} true if either user has blocked the other
 */
async function isBlockedEitherWay(userId1, userId2) {
    try {
        const [user1BlockedUser2, user2BlockedUser1] = await Promise.all([
            db.collection("blocks")
                .doc(userId1)
                .collection("blocked")
                .doc(userId2)
                .get(),
            db.collection("blocks")
                .doc(userId2)
                .collection("blocked")
                .doc(userId1)
                .get(),
        ]);
        return user1BlockedUser2.exists || user2BlockedUser1.exists;
    } catch (error) {
        logger.warn("Error checking block status", {
            userId1,
            userId2,
            error: error.message,
        });
        return false; // Default to not blocked on error
    }
}

/**
 * Handle new follow - triggered when user adds to their following list
 * If target is public: creates follower record and updates counts
 * If target is private: sends follow request notification
 */
export const onFollow = onDocumentCreated(
    "userFollowing/{followerId}/following/{targetUserId}",
    withIdempotency("onFollow", async (event) => {
        const { followerId, targetUserId } = event.params;
        const followData = event.data?.data();

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

        // Prevent self-follow (shouldn't happen but safety check)
        if (followerId === targetUserId) {
            logger.warn("onFollow: Self-follow attempted", { followerId });
            await event.data.ref.delete();
            return;
        }

        try {
            // Check if target has private profile
            const isPrivate = await isPrivateProfile(targetUserId);

            if (isPrivate) {
                // CRITICAL: Enforce status='pending' for private profiles
                // Frontend might have stale data and send 'following' - we must correct it
                const currentStatus = followData.status;
                if (currentStatus !== "pending") {
                    logger.info("Correcting follow status for private profile", {
                        structuredData: true,
                        followerId,
                        targetUserId,
                        originalStatus: currentStatus,
                        newStatus: "pending",
                    });
                    await event.data.ref.update({ status: "pending" });
                }

                logger.info("Follow request pending (private profile)", {
                    structuredData: true,
                    followerId,
                    targetUserId,
                });

                // Send follow request notification
                await sendFollowRequestNotification(followerId, targetUserId);
                return;
            }

            // Public profile: immediately approve the follow
            logger.info("onFollow: public profile, approving follow", {
                structuredData: true,
                followerId,
                targetUserId,
            });
            await approveFollow(followerId, targetUserId, event.data.ref);
            logger.info("onFollow: approveFollow completed (public)", {
                structuredData: true,
                followerId,
                targetUserId,
            });

            // Send follow notification (fire and forget)
            sendFollowNotification(followerId, targetUserId).catch((err) => {
                logger.warn("Failed to send follow notification", {
                    error: err.message,
                    followerId,
                    targetUserId
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
    })
);

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
 * Approve a follow - creates follower record, updates counts, sets status to 'following'
 */
async function approveFollow(followerId, targetUserId, followDocRef) {
    logger.info("approveFollow: Starting", {
        structuredData: true,
        followerId,
        targetUserId,
    });

    await db.runTransaction(async (transaction) => {
        // 1. Create follower record in target's followers collection
        const followerRef = db
            .collection("userFollowers")
            .doc(targetUserId)
            .collection("followers")
            .doc(followerId);

        transaction.set(followerRef, {
            followerId: followerId,
            status: "following", // Include status for consistency with userFollowing
            timestamp: FieldValue.serverTimestamp(),
        });

        // 2. Update follow doc status to 'following'
        transaction.update(followDocRef, {
            status: "following",
        });

        // 3. Increment followingCount on follower's user doc
        const followerUserRef = db.collection("users").doc(followerId);
        transaction.update(followerUserRef, {
            followingCount: FieldValue.increment(1),
        });

        // 4. Increment followerCount on target's user doc
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

    // Aura: new follower (+5 to user who gained follower)
    const auraOk = await awardAura(targetUserId, AURA_POINTS.NEW_FOLLOWER, "New follower", { followerId, action: "new_follower" });
    logger.info("approveFollow: awardAura result", {
        structuredData: true,
        targetUserId,
        auraOk,
        points: AURA_POINTS.NEW_FOLLOWER,
    });

    // Check if this creates a mutual follow (friends!)
    const isMutual = await checkMutualFollowCreated(followerId, targetUserId);
    if (isMutual) {
        // Before sending "friends" notification, check if either user has blocked the other
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

        // Send "now friends" notification to both users
        await sendMutualFollowNotification(followerId, targetUserId);
    }
}

/**
 * Handle follow request approval - triggered when status changes from 'pending' to 'following'
 * This happens when a private profile user accepts a follow request
 */
export const onFollowApproved = onDocumentUpdated(
    "userFollowing/{followerId}/following/{targetUserId}",
    withIdempotency("onFollowApproved", async (event) => {
        const { followerId, targetUserId } = event.params;
        const beforeData = event.data?.before?.data();
        const afterData = event.data?.after?.data();

        // Only process if status changed from 'pending' to 'following'
        if (beforeData?.status !== "pending" || afterData?.status !== "following") {
            return;
        }

        try {
            // Check if follower record already exists (idempotency)
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

            // Create follower record and update counts (but don't update status - it's already 'following')
            await db.runTransaction(async (transaction) => {
                transaction.set(followerRef, {
                    followerId: followerId,
                    status: "following", // Include status for consistency
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

            // Aura: new follower (+5)
            await awardAura(targetUserId, AURA_POINTS.NEW_FOLLOWER, "New follower", { followerId, action: "new_follower" });

            // Send acceptance notification to the follower
            sendFollowAcceptedNotification(followerId, targetUserId).catch((err) => {
                logger.warn("Failed to send follow accepted notification", {
                    error: err.message,
                    followerId,
                    targetUserId
                });
            });

            // Check if this creates a mutual follow (friends!)
            const isMutual = await checkMutualFollowCreated(followerId, targetUserId);
            if (isMutual) {
                // Before sending "friends" notification, check if either user has blocked the other
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
    })
);

/**
 * Handle unfollow - triggered when user removes from their following list
 * Deletes the follower record and decrements counts
 */
export const onUnfollow = onDocumentDeleted(
    "userFollowing/{followerId}/following/{targetUserId}",
    withIdempotency("onUnfollow", async (event) => {
        const { followerId, targetUserId } = event.params;

        try {
            // Use a transaction for atomic updates
            await db.runTransaction(async (transaction) => {
                // 1. Delete follower record from target's followers collection
                const followerRef = db
                    .collection("userFollowers")
                    .doc(targetUserId)
                    .collection("followers")
                    .doc(followerId);

                // Check if it exists before decrementing
                const followerDoc = await transaction.get(followerRef);

                if (followerDoc.exists) {
                    transaction.delete(followerRef);

                    // 2. Decrement followingCount on follower's user doc
                    const followerUserRef = db.collection("users").doc(followerId);
                    transaction.update(followerUserRef, {
                        followingCount: FieldValue.increment(-1),
                    });

                    // 3. Decrement followerCount on target's user doc
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
            throw error; // Re-throw to trigger retry
        }
    })
);

/**
 * Send follow notification to the target user (for public profiles)
 */
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

/**
 * Send follow request notification to the target user (for private profiles)
 */
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
export const acceptFollowRequest = onCall({
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke
}, async (request) => {
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
                targetUserId: currentUserId
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
                targetUserId: currentUserId
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
});

/**
 * CALLABLE: Reject/decline a follow request (for private profiles)
 * 
 * Called by the target user (private profile owner) to reject a pending follow request.
 * Deletes the follow document, which triggers onUnfollow.
 */
export const rejectFollowRequest = onCall({
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke
}, async (request) => {
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

        // Delete the follow document - this triggers onUnfollow
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
});

