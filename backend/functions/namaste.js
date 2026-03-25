import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { RATE_LIMITS } from "../lib/constants.js";
import { AURA_POINTS } from "../lib/constants.js";

// Namaste configuration - uses shared constants
const NAMASTE_CONFIG = {
    DAILY_LIMIT: RATE_LIMITS.NAMASTE_DAILY_LIMIT,
    AURA_POINTS_RECEIVED: RATE_LIMITS.NAMASTE_AURA_POINTS,
    AURA_POINTS_SENT: AURA_POINTS.NAMASTE_SENT,
};

/**
 * Get today's date string in YYYY-MM-DD format (UTC)
 */
function getTodayDateString() {
    return new Date().toISOString().split("T")[0];
}

/**
 * Check if user A has blocked user B or vice versa
 */
async function checkBlocked(db, userA, userB) {
    try {
        // Check if A blocked B
        const aBlockedB = await db
            .collection("blocks")
            .doc(userA)
            .collection("blocked")
            .doc(userB)
            .get();

        if (aBlockedB.exists) return true;

        // Check if B blocked A
        const bBlockedA = await db
            .collection("blocks")
            .doc(userB)
            .collection("blocked")
            .doc(userA)
            .get();

        return bBlockedA.exists;
    } catch (error) {
        logger.warn("Error checking blocked status:", error);
        return false;
    }
}

/**
 * Award aura points for namaste with deduplication
 * Only awards once per sender->recipient per day
 */
async function awardNamasteAura(db, recipientUid, senderUid, today) {
    const trackingId = `namaste_${senderUid}_${recipientUid}_${today}`;
    const trackingRef = db
        .collection("users")
        .doc(recipientUid)
        .collection("auraTracking")
        .doc(trackingId);

    const trackingDoc = await trackingRef.get();
    if (trackingDoc.exists) {
        // Already awarded today
        logger.info(`Aura already awarded for namaste: ${trackingId}`);
        return false;
    }

    // Award aura points
    const userRef = db.collection("users").doc(recipientUid);
    const historyRef = db
        .collection("users")
        .doc(recipientUid)
        .collection("auraHistory")
        .doc();

    await db.runTransaction(async (t) => {
        // Update user's total aura score
        t.set(
            userRef,
            {
                auraScore: FieldValue.increment(NAMASTE_CONFIG.AURA_POINTS_RECEIVED),
                lastAuraUpdate: FieldValue.serverTimestamp(),
            },
            { merge: true },
        );

        // Record tracking to prevent duplicates
        t.set(trackingRef, {
            points: NAMASTE_CONFIG.AURA_POINTS_RECEIVED,
            reason: "Received namaste",
            timestamp: FieldValue.serverTimestamp(),
            metadata: { senderUserId: senderUid, action: "namaste_received" },
        });

        // Record in history
        t.set(historyRef, {
            points: NAMASTE_CONFIG.AURA_POINTS_RECEIVED,
            reason: "Received namaste",
            action: "namaste_received",
            affectedUserId: senderUid,
            timestamp: FieldValue.serverTimestamp(),
            metadata: { senderUserId: senderUid, action: "namaste_received" },
        });
    });

    logger.info(
        `Awarded ${NAMASTE_CONFIG.AURA_POINTS_RECEIVED} aura to ${recipientUid} from namaste by ${senderUid}`,
    );
    return true;
}

/**
 * Send Namaste - Main callable function
 * 
 * Handles all namaste logic:
 * - Validates authentication and permissions
 * - Enforces daily quota (3 per day)
 * - Prevents duplicate sends to same person per day
 * - Creates notification
 * - Awards aura points
 * - Optionally sends chat message
 * - Records in sender's history
 * 
 * @param {Object} request.data
 * @param {string} request.data.recipientUid - User to send namaste to
 * @param {boolean} request.data.sendChatMessage - Whether to send a chat message
 * @param {string} request.data.dmId - DM conversation ID (required if sendChatMessage is true)
 * 
 * @returns {Object} { success: boolean, remaining: number, error?: string }
 */
export const sendNamaste = onCall({
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    const db = getFirestore();
    const senderId = request.auth?.uid;
    const { recipientUid, sendChatMessage, dmId } = request.data || {};

    const pointsForSender = NAMASTE_CONFIG.AURA_POINTS_SENT;
    logger.info("sendNamaste called", {
        senderId,
        recipientUid,
        sendChatMessage: !!sendChatMessage,
        pointsForSender,
        pointsForRecipient: NAMASTE_CONFIG.AURA_POINTS_RECEIVED,
    });
    if (pointsForSender === 0) {
        logger.warn("sendNamaste: AURA_POINTS_SENT is 0 - sender will not get aura");
    }

    // 1. Authentication check
    if (!senderId) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    // 2. Validate input
    if (!recipientUid || typeof recipientUid !== "string") {
        throw new HttpsError("invalid-argument", "recipientUid is required");
    }

    // 3. Self-namaste check
    if (senderId === recipientUid) {
        return { success: false, error: "SELF_NAMASTE", remaining: null };
    }

    // 4. Block check
    const isBlocked = await checkBlocked(db, senderId, recipientUid);
    if (isBlocked) {
        return { success: false, error: "BLOCKED", remaining: null };
    }

    // 5. Check recipient exists
    const recipientDoc = await db.collection("users").doc(recipientUid).get();
    if (!recipientDoc.exists) {
        return { success: false, error: "USER_NOT_FOUND", remaining: null };
    }

    // 6. Get today's quota
    const today = getTodayDateString();
    const quotaRef = db.collection("users").doc(senderId).collection("namasteQuota").doc(today);
    const quotaDoc = await quotaRef.get();
    const quota = quotaDoc.exists
        ? quotaDoc.data()
        : { sent: 0, recipients: [] };

    const currentSent = quota.sent || 0;
    const currentRecipients = quota.recipients || [];

    // 7. Check daily limit
    if (currentSent >= NAMASTE_CONFIG.DAILY_LIMIT) {
        logger.info(`User ${senderId} exceeded daily namaste quota`);
        return { success: false, error: "QUOTA_EXCEEDED", remaining: 0 };
    }

    // 8. Check if already sent to this person today
    if (currentRecipients.includes(recipientUid)) {
        logger.info(`User ${senderId} already sent namaste to ${recipientUid} today`);
        return {
            success: false,
            error: "ALREADY_SENT_TODAY",
            remaining: NAMASTE_CONFIG.DAILY_LIMIT - currentSent,
        };
    }

    // 9. Get sender info for notification (before transaction)
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderData = senderDoc.data() || {};
    const senderName = senderData.name || senderData.nickname || senderData.username || "Someone";
    const senderAvatar = senderData.displayPicture || "";

    // 10. Execute namaste in transaction
    try {
        await db.runTransaction(async (t) => {
            // Create notification for recipient with full sender info
            const notificationRef = db
                .collection("notifications")
                .doc(recipientUid)
                .collection("notifications")
                .doc();

            t.set(notificationRef, {
                author: senderId,
                authorName: senderName,
                authorPic: senderAvatar,
                type: "namaste",
                read: false,
                timestamp: FieldValue.serverTimestamp(),
            });

            // Update sender's quota
            t.set(
                quotaRef,
                {
                    sent: FieldValue.increment(1),
                    recipients: FieldValue.arrayUnion(recipientUid), // Pass value directly, not array
                    lastUpdated: FieldValue.serverTimestamp(),
                },
                { merge: true },
            );

            // Award sender +1 aura and record in history (cap is already 3/day via quota)
            const senderUserRef = db.collection("users").doc(senderId);
            const senderHistoryRef = db
                .collection("users")
                .doc(senderId)
                .collection("auraHistory")
                .doc();

            t.set(
                senderUserRef,
                {
                    auraScore: FieldValue.increment(NAMASTE_CONFIG.AURA_POINTS_SENT),
                    lastAuraUpdate: FieldValue.serverTimestamp(),
                },
                { merge: true },
            );
            t.set(senderHistoryRef, {
                points: NAMASTE_CONFIG.AURA_POINTS_SENT,
                reason: "Sent namaste",
                action: "namaste_sent",
                affectedUserId: recipientUid,
                timestamp: FieldValue.serverTimestamp(),
                metadata: { recipientUserId: recipientUid },
            });

            // Send chat message if requested
            if (sendChatMessage && dmId) {
                // Use already-fetched sender info for the message
                const messageRef = db
                    .collection("dmConversations")
                    .doc(dmId)
                    .collection("messages")
                    .doc();

                t.set(messageRef, {
                    spaceId: dmId,
                    senderId: senderId,
                    senderName: senderName,
                    senderAvatar: senderAvatar,
                    content: "🙏",
                    messageType: "namaste",
                    reactions: {},
                    readBy: [senderId],
                    timestamp: FieldValue.serverTimestamp(),
                });
            }
        });

        // Award aura points to recipient (outside transaction for dedup logic)
        const recipientAwarded = await awardNamasteAura(db, recipientUid, senderId, today);

        const newRemaining = NAMASTE_CONFIG.DAILY_LIMIT - currentSent - 1;
        const senderPointsAwarded = NAMASTE_CONFIG.AURA_POINTS_SENT;
        logger.info("Namaste sent successfully", {
            senderId,
            recipientUid,
            remaining: newRemaining,
            senderPointsAwarded,
            recipientPointsAwarded: recipientAwarded ? NAMASTE_CONFIG.AURA_POINTS_RECEIVED : 0,
        });
        logger.info(`Awarded ${senderPointsAwarded} aura to sender ${senderId} for sending namaste`);

        return {
            success: true,
            remaining: newRemaining,
            senderPointsAwarded,
            recipientPointsAwarded: recipientAwarded ? NAMASTE_CONFIG.AURA_POINTS_RECEIVED : 0,
        };
    } catch (error) {
        logger.error("Error sending namaste:", error);
        throw new HttpsError("internal", "Failed to send namaste");
    }
});

/**
 * Get Namaste Quota - Returns user's remaining namastes for today
 * 
 * @returns {Object} { remaining: number, sent: number, recipients: string[] }
 */
export const getNamasteQuota = onCall({
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    const db = getFirestore();
    const userId = request.auth?.uid;

    if (!userId) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const today = getTodayDateString();
    const quotaDoc = await db
        .collection("users")
        .doc(userId)
        .collection("namasteQuota")
        .doc(today)
        .get();

    if (!quotaDoc.exists) {
        return {
            remaining: NAMASTE_CONFIG.DAILY_LIMIT,
            sent: 0,
            recipients: [],
        };
    }

    const data = quotaDoc.data();
    const sent = data.sent || 0;

    return {
        remaining: NAMASTE_CONFIG.DAILY_LIMIT - sent,
        sent: sent,
        recipients: data.recipients || [],
    };
});

/**
 * Check if can send namaste to a specific user
 * Lightweight check without sending
 * 
 * @param {string} request.data.recipientUid - User to check
 * @returns {Object} { canSend: boolean, reason?: string }
 */
export const canSendNamaste = onCall({
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    const db = getFirestore();
    const senderId = request.auth?.uid;
    const { recipientUid } = request.data || {};

    if (!senderId) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    if (!recipientUid) {
        throw new HttpsError("invalid-argument", "recipientUid is required");
    }

    // Self check
    if (senderId === recipientUid) {
        return { canSend: false, reason: "SELF_NAMASTE" };
    }

    // Block check
    const isBlocked = await checkBlocked(db, senderId, recipientUid);
    if (isBlocked) {
        return { canSend: false, reason: "BLOCKED" };
    }

    // Quota check
    const today = getTodayDateString();
    const quotaDoc = await db
        .collection("users")
        .doc(senderId)
        .collection("namasteQuota")
        .doc(today)
        .get();

    if (!quotaDoc.exists) {
        return { canSend: true };
    }

    const data = quotaDoc.data();
    const sent = data.sent || 0;
    const recipients = data.recipients || [];

    if (sent >= NAMASTE_CONFIG.DAILY_LIMIT) {
        return { canSend: false, reason: "QUOTA_EXCEEDED" };
    }

    if (recipients.includes(recipientUid)) {
        return { canSend: false, reason: "ALREADY_SENT_TODAY" };
    }

    return { canSend: true };
});

