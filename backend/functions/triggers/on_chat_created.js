/**
 * onChatCreated — Consolidated trigger for `spaceChats/{messageId}` document creation.
 *
 * Merges two previously separate Cloud Functions that listened to the same path:
 *   1. onNewChatMessage (chat_notifications.js)  — multi-recipient FCM with rate limiting
 *   2. filterChatMessage (chat_moderation.js)    — content moderation / auto-removal
 *
 * Eventarc only allows one Cloud Function per unique document path, so we collapse
 * them into a single onDocumentCreated handler. Moderation runs first; if the
 * message is blocked, we skip notification work entirely.
 *
 * Behavior preserved exactly:
 *   - Rate limit cache (per spaceId:recipientId) with deterministic cleanup
 *   - Skip notifications for:
 *       * call history messages (messageType === 'call')
 *       * deleted senders (deletedUsers/{senderId})
 *   - Mention-aware notifications (bypass rate limit + bespoke body)
 *   - Auto-delete + reports/ write for objectionable text content
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, getMessaging, logger } from "../../lib/firebase.js";
import { getUserFcmTokens, removeInvalidTokens, isInvalidTokenError } from "../../lib/fcm_utils.js";
import { containsBlockedText } from "../../lib/utils.js";
import { RATE_LIMITS } from "../../lib/constants.js";

// =============================================================================
// Module-scoped rate-limit cache (resets on cold start, which is acceptable).
// =============================================================================
const rateLimitCache = new Map();
let lastNotificationRateLimitCleanup = Date.now();
const ROLE_PAGE_SIZE = 500;

// =============================================================================
// Helpers — copied verbatim from chat_notifications.js to preserve behavior.
// =============================================================================

async function fetchSpaceMemberIds(spaceId, senderId) {
    const rolesRef = db.collection("spaceRoles").doc(spaceId).collection("roles");
    const memberIds = [];
    let lastDoc = null;

    // eslint-disable-next-line no-constant-condition
    while (true) {
        let query = rolesRef.orderBy("__name__").limit(ROLE_PAGE_SIZE);
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();
        if (snapshot.empty) break;

        for (const doc of snapshot.docs) {
            const userId = doc.id;
            if (userId !== senderId) {
                memberIds.push(userId);
            }
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < ROLE_PAGE_SIZE) break;
    }

    return memberIds;
}

function shouldRateLimit(spaceId, recipientId) {
    const key = `${spaceId}:${recipientId}`;
    const now = Date.now();
    const lastSent = rateLimitCache.get(key);

    if (lastSent && (now - lastSent) < RATE_LIMITS.CHAT_NOTIFICATION_WINDOW_MS) {
        return true;
    }

    rateLimitCache.set(key, now);

    if (now - lastNotificationRateLimitCleanup > RATE_LIMITS.RATE_LIMIT_CLEANUP_INTERVAL_MS ||
        rateLimitCache.size > RATE_LIMITS.RATE_LIMIT_MAX_ENTRIES) {
        lastNotificationRateLimitCleanup = now;
        const cutoff = now - RATE_LIMITS.CHAT_NOTIFICATION_WINDOW_MS * 10;
        let cleanedCount = 0;
        for (const [k, v] of rateLimitCache.entries()) {
            if (v < cutoff) {
                rateLimitCache.delete(k);
                cleanedCount++;
            }
        }
        if (cleanedCount > 100) {
            logger.info("Notification rate limit cleanup", {
                structuredData: true,
                cleaned: cleanedCount,
                remaining: rateLimitCache.size,
            });
        }
    }

    return false;
}

function formatNotificationBody(messageType, content, senderName, isDM) {
    const prefix = isDM ? "" : `${senderName}: `;

    switch (messageType) {
    case "text":
        const displayContent = content && content.length > 50 ?
            content.substring(0, 50) + "..." :
            content || "";
        return isDM ? displayContent : `${prefix}${displayContent}`;
    case "image":
        return isDM ? "📷 Sent a photo" : `${senderName} sent a photo`;
    case "video":
        return isDM ? "🎬 Sent a video" : `${senderName} sent a video`;
    case "audio":
        return isDM ? "🎵 Sent an audio message" : `${senderName} sent an audio message`;
    case "file":
        return isDM ? "📎 Sent a file" : `${senderName} sent a file`;
    case "shared_content":
        const sharedContent = content && content.length > 50 ?
            content.substring(0, 50) + "..." :
            content || "Shared something";
        return isDM ? `📤 ${sharedContent}` : `${senderName}: ${sharedContent}`;
    case "namaste":
        return isDM ? "🙏 Namaste" : `${senderName} sent a Namaste`;
    default:
        return isDM ? "New message" : `${senderName} sent a message`;
    }
}

function buildFCMMessage({
    conversationName, notificationBody, spaceId, messageId,
    senderId, senderName, senderAvatar, messageType, content,
}) {
    return {
        notification: {
            title: conversationName,
            body: notificationBody,
        },
        data: {
            type: "chat",
            spaceId: spaceId || "",
            messageId: messageId || "",
            senderId: senderId || "",
            senderName: senderName || "",
            senderAvatar: senderAvatar || "",
            messageType: messageType || "text",
            messageContent: content || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            timestamp: String(Date.now()),
        },
        apns: {
            payload: {
                aps: {
                    "mutable-content": 1,
                    "badge": 1,
                    "sound": "default",
                    "thread-id": spaceId,
                    "category": "chat",
                },
            },
            fcm_options: { image: senderAvatar || undefined },
        },
        android: {
            priority: "high",
            ttl: 86400000,
            notification: {
                channelId: "chat_messages",
                priority: "high",
                defaultSound: true,
                defaultVibrateTimings: true,
                tag: spaceId,
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
        },
    };
}

async function getRecipientIds(spaceId, senderId) {
    if (spaceId.startsWith("dm_")) {
        const dmConversationDoc = await db.collection("dmConversations").doc(spaceId).get();

        if (dmConversationDoc.exists) {
            const dmData = dmConversationDoc.data();
            const participants = dmData.participants || [];
            return participants.filter((id) => id !== senderId);
        } else {
            const parts = spaceId.substring(3).split("_");
            return parts.filter((id) => id !== senderId && id.length > 0);
        }
    } else {
        return fetchSpaceMemberIds(spaceId, senderId);
    }
}

async function getConversationInfo(spaceId, senderName) {
    if (spaceId.startsWith("dm_")) {
        return { name: senderName || "New Message", picture: null };
    }

    try {
        const spaceDoc = await db.collection("spaces").doc(spaceId).get();
        if (spaceDoc.exists) {
            const spaceData = spaceDoc.data();
            return {
                name: spaceData.name || "Chat",
                picture: spaceData.displayPicture || null,
            };
        }
    } catch (e) {
        logger.warn("Failed to get space info", { spaceId, error: String(e) });
    }

    return { name: "Chat", picture: null };
}

async function extractMentionedUserIds(content, recipientIds) {
    if (!content || recipientIds.length === 0) return [];

    const mentionPattern = /@(\w+)/g;
    const mentions = [];
    let match;
    while ((match = mentionPattern.exec(content)) !== null) {
        mentions.push(match[1].toLowerCase());
    }

    if (mentions.length === 0) return [];

    const mentionedIds = [];
    for (const userId of recipientIds) {
        try {
            const userDoc = await db.collection("users").doc(userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                const userName = (userData.name || userData.nickname || "").toLowerCase();
                if (mentions.some((m) => userName.includes(m) || m.includes(userName))) {
                    mentionedIds.push(userId);
                }
            }
        } catch (e) {
            continue;
        }
    }

    return mentionedIds;
}

// =============================================================================
// Moderation phase — runs first; if blocked, doc is deleted and we early-exit.
// Returns true when message was blocked & removed (skip notifications).
// =============================================================================
async function moderateMessage(event, messageData, messageId) {
    if (messageData.messageType !== "text") {
        return false;
    }

    const content = messageData.content || "";
    if (!containsBlockedText(content)) {
        return false;
    }

    logger.info("Blocked objectionable chat message", {
        structuredData: true,
        messageId,
        senderId: messageData.senderId,
        spaceId: messageData.spaceId,
    });

    try {
        await event.data?.ref.delete();

        await db.collection("reports").add({
            type: "chat_message",
            messageId: messageId,
            reportedBy: "system",
            reason: "Objectionable content detected",
            content: content.substring(0, 200),
            senderId: messageData.senderId,
            spaceId: messageData.spaceId,
            timestamp: new Date(),
            status: "auto_removed",
        });

        logger.info("Deleted objectionable message and created report", {
            structuredData: true,
            messageId,
        });
    } catch (error) {
        logger.error("Error filtering chat message", {
            structuredData: true,
            messageId,
            error: error.message,
        });
    }

    return true;
}

// =============================================================================
// Notification phase — push-only multi-recipient FCM (no Firestore alerts).
// =============================================================================
async function notifyRecipients(messageData, messageId) {
    const {
        spaceId,
        senderId,
        senderName,
        senderAvatar,
        content,
        messageType,
        mentionedUserIds,
    } = messageData;

    if (!spaceId || !senderId) {
        logger.warn("Missing spaceId or senderId in chat message", {
            structuredData: true,
            messageId,
        });
        return;
    }

    const deletedUserDoc = await db.collection("deletedUsers").doc(senderId).get();
    if (deletedUserDoc.exists) {
        logger.info("Skipping notification - sender account is deleted", {
            structuredData: true,
            messageId,
            senderId,
        });
        return;
    }

    if (messageType === "call") {
        logger.info("Skipping notification for call history message", {
            structuredData: true,
            messageId,
            spaceId,
        });
        return;
    }

    logger.info("Processing chat notification", {
        structuredData: true,
        messageId,
        spaceId,
        senderId,
        messageType,
        hasMentions: !!(mentionedUserIds && mentionedUserIds.length > 0),
    });

    const recipientIds = await getRecipientIds(spaceId, senderId);

    if (recipientIds.length === 0) {
        logger.info("No recipients found for chat message", {
            structuredData: true,
            messageId,
            spaceId,
        });
        return;
    }

    const mentioned = mentionedUserIds && mentionedUserIds.length > 0 ?
        mentionedUserIds.filter((id) => recipientIds.includes(id)) :
        await extractMentionedUserIds(content, recipientIds);

    const isDM = spaceId.startsWith("dm_");
    const { name: conversationName } = await getConversationInfo(spaceId, senderName);
    const notificationBody = formatNotificationBody(messageType, content, senderName, isDM);

    const fcmMessage = buildFCMMessage({
        conversationName,
        notificationBody,
        spaceId,
        messageId,
        senderId,
        senderName,
        senderAvatar,
        messageType,
        content,
    });

    const messaging = getMessaging();
    let successCount = 0;
    let failCount = 0;
    let rateLimitedCount = 0;
    let mentionCount = 0;

    const sendPromises = recipientIds.map(async (recipientId) => {
        try {
            const isMentioned = mentioned.includes(recipientId);
            if (!isMentioned && shouldRateLimit(spaceId, recipientId)) {
                rateLimitedCount++;
                return { recipientId, status: "rate_limited" };
            }

            const recipientDoc = await db.collection("users").doc(recipientId).get();
            if (!recipientDoc.exists) return { recipientId, status: "user_not_found" };

            const fcmTokens = getUserFcmTokens(recipientDoc.data());
            if (fcmTokens.length === 0) return { recipientId, status: "no_tokens" };

            let messageToSend = { ...fcmMessage };
            if (isMentioned) {
                mentionCount++;
                const mentionSnippet = (content || "").substring(0, 100);
                const mentionEllipsis = (content || "").length > 100 ? "..." : "";
                messageToSend = {
                    ...fcmMessage,
                    notification: {
                        ...fcmMessage.notification,
                        title: fcmMessage.notification.title,
                        body: `${senderName} mentioned you: ${mentionSnippet}${mentionEllipsis}`,
                    },
                    data: { ...fcmMessage.data, isMention: "true" },
                };
            }

            const invalidTokens = [];
            let recipientSuccess = 0;
            for (const token of fcmTokens) {
                try {
                    await messaging.send({ ...messageToSend, token });
                    recipientSuccess++;
                    successCount++;
                } catch (tokenError) {
                    const errorCode = tokenError.code || tokenError.errorInfo?.code;
                    if (isInvalidTokenError(errorCode)) invalidTokens.push(token);
                    failCount++;
                }
            }
            if (invalidTokens.length > 0) {
                removeInvalidTokens(recipientId, invalidTokens).catch(() => {});
            }
            return { recipientId, status: recipientSuccess > 0 ? "sent" : "failed", isMention: isMentioned };
        } catch (recipientError) {
            logger.error("Error sending to recipient", {
                structuredData: true,
                recipientId,
                error: String(recipientError),
            });
            failCount++;
            return { recipientId, status: "error", error: String(recipientError) };
        }
    });

    await Promise.all(sendPromises);

    logger.info("Chat notifications sent (push only; not in alerts list)", {
        structuredData: true,
        messageId,
        spaceId,
        recipientCount: recipientIds.length,
        successCount,
        failCount,
        rateLimitedCount,
        mentionCount,
    });
}

// =============================================================================
// Unified Cloud Function — single Eventarc subscription on spaceChats/{messageId}
// =============================================================================
export const onChatCreated = onDocumentCreated("spaceChats/{messageId}", async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const messageData = snap.data();
    const messageId = event.params.messageId;

    if (!messageData) {
        logger.warn("No message data found", { structuredData: true, messageId });
        return null;
    }

    try {
        // Phase 1: moderation. If message is removed, skip notifications entirely.
        const wasBlocked = await moderateMessage(event, messageData, messageId);
        if (wasBlocked) return null;

        // Phase 2: notifications.
        await notifyRecipients(messageData, messageId);
        return null;
    } catch (error) {
        logger.error("Error processing chat created", {
            structuredData: true,
            messageId,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        return null;
    }
});
