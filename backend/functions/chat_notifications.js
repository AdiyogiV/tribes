import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, getMessaging, logger } from "../lib/firebase.js";
import { getUserFcmTokens, removeInvalidTokens, isInvalidTokenError } from "../lib/fcm_utils.js";
import { RATE_LIMITS } from "../lib/constants.js";

// In-memory rate limiting cache (resets on cold start, which is acceptable)
const rateLimitCache = new Map();
let lastNotificationRateLimitCleanup = Date.now();
const ROLE_PAGE_SIZE = 500;

async function fetchSpaceMemberIds(spaceId, senderId) {
    const rolesRef = db.collection("spaceRoles").doc(spaceId).collection("roles");
    const memberIds = [];
    let lastDoc = null;

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

/**
 * Check if notification should be rate limited
 * @param {string} spaceId - The conversation/space ID
 * @param {string} recipientId - The recipient user ID
 * @returns {boolean} - True if should be rate limited (don't send)
 */
function shouldRateLimit(spaceId, recipientId) {
    const key = `${spaceId}:${recipientId}`;
    const now = Date.now();
    const lastSent = rateLimitCache.get(key);
    
    if (lastSent && (now - lastSent) < RATE_LIMITS.CHAT_NOTIFICATION_WINDOW_MS) {
        return true;
    }
    
    rateLimitCache.set(key, now);
    
    // Deterministic cleanup: every 30 seconds OR when map gets too large
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

/**
 * Format notification body based on message type
 * @param {string} messageType - Type of message
 * @param {string} content - Message content
 * @param {string} senderName - Sender's name
 * @param {boolean} isDM - Is this a DM conversation
 * @returns {string} Formatted notification body
 */
function formatNotificationBody(messageType, content, senderName, isDM) {
    const prefix = isDM ? '' : `${senderName}: `;
    
    switch (messageType) {
        case 'text':
            const displayContent = content && content.length > 50 
                ? content.substring(0, 50) + '...' 
                : content || '';
            return isDM ? displayContent : `${prefix}${displayContent}`;
        case 'image':
            return isDM ? '📷 Sent a photo' : `${senderName} sent a photo`;
        case 'video':
            return isDM ? '🎬 Sent a video' : `${senderName} sent a video`;
        case 'audio':
            return isDM ? '🎵 Sent an audio message' : `${senderName} sent an audio message`;
        case 'file':
            return isDM ? '📎 Sent a file' : `${senderName} sent a file`;
        case 'shared_content':
            // Content will be like "Shared a post" or custom message
            const sharedContent = content && content.length > 50 
                ? content.substring(0, 50) + '...' 
                : content || 'Shared something';
            return isDM ? `📤 ${sharedContent}` : `${senderName}: ${sharedContent}`;
        case 'namaste':
            return isDM ? '🙏 Namaste' : `${senderName} sent a Namaste`;
        default:
            return isDM ? 'New message' : `${senderName} sent a message`;
    }
}

/**
 * Build FCM message payload (chat push only; no Firestore - alerts list does not show chat)
 */
function buildFCMMessage({ conversationName, notificationBody, spaceId, messageId, senderId, senderName, senderAvatar, messageType, content }) {
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
                    badge: 1,
                    sound: "default",
                    "thread-id": spaceId,
                    category: "chat",
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

/**
 * Get recipient IDs for a conversation
 * @param {string} spaceId - Space/conversation ID
 * @param {string} senderId - Sender ID to exclude
 * @returns {Promise<string[]>} Array of recipient IDs
 */
async function getRecipientIds(spaceId, senderId) {
    if (spaceId.startsWith('dm_')) {
        // Direct message - get from dmConversations or parse from ID
        const dmConversationDoc = await db.collection('dmConversations').doc(spaceId).get();
        
        if (dmConversationDoc.exists) {
            const dmData = dmConversationDoc.data();
            const participants = dmData.participants || [];
            return participants.filter(id => id !== senderId);
        } else {
            // Fallback: parse participant IDs from conversation ID (dm_uid1_uid2)
            const parts = spaceId.substring(3).split('_');
            return parts.filter(id => id !== senderId && id.length > 0);
        }
    } else {
        // Space/group chat - get all members from spaceRoles
        return fetchSpaceMemberIds(spaceId, senderId);
    }
}

/**
 * Get conversation display name
 * @param {string} spaceId - Space/conversation ID
 * @param {string} senderName - Sender name (used for DMs)
 * @returns {Promise<{name: string, picture: string|null}>}
 */
async function getConversationInfo(spaceId, senderName) {
    if (spaceId.startsWith('dm_')) {
        return { name: senderName || 'New Message', picture: null };
    }
    
    try {
        const spaceDoc = await db.collection('spaces').doc(spaceId).get();
        if (spaceDoc.exists) {
            const spaceData = spaceDoc.data();
            return {
                name: spaceData.name || 'Chat',
                picture: spaceData.displayPicture || null,
            };
        }
    } catch (e) {
        logger.warn("Failed to get space info", { spaceId, error: String(e) });
    }
    
    return { name: 'Chat', picture: null };
}

/**
 * Extract mentioned user IDs from message content
 * Looks for @username patterns and tries to match them to user names
 * @param {string} content - Message content
 * @param {string[]} recipientIds - Potential recipient IDs to check
 * @returns {Promise<string[]>} - Array of mentioned user IDs
 */
async function extractMentionedUserIds(content, recipientIds) {
    if (!content || recipientIds.length === 0) return [];
    
    // Find all @mentions in content
    const mentionPattern = /@(\w+)/g;
    const mentions = [];
    let match;
    while ((match = mentionPattern.exec(content)) !== null) {
        mentions.push(match[1].toLowerCase());
    }
    
    if (mentions.length === 0) return [];
    
    // Check each recipient's name against mentions
    const mentionedIds = [];
    for (const userId of recipientIds) {
        try {
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                const userName = (userData.name || userData.nickname || '').toLowerCase();
                if (mentions.some(m => userName.includes(m) || m.includes(userName))) {
                    mentionedIds.push(userId);
                }
            }
        } catch (e) {
            // Skip users we can't look up
            continue;
        }
    }
    
    return mentionedIds;
}

/**
 * Triggered when a new chat message is created in spaceChats collection
 * Sends push notifications to all participants except the sender
 */
export const onNewChatMessage = onDocumentCreated("spaceChats/{messageId}", async (event) => {
    const snap = event.data;
    const messageData = snap.data();
    const messageId = event.params.messageId;

    try {
        const {
            spaceId,
            senderId,
            senderName,
            senderAvatar,
            content,
            messageType,
            mentionedUserIds, // Array of user IDs mentioned (from client)
        } = messageData;

        // Validate required fields
        if (!spaceId || !senderId) {
            logger.warn("Missing spaceId or senderId in chat message", {
                structuredData: true,
                messageId,
            });
            return null;
        }

        // Check if sender is deleted - don't send notifications for deleted users
        const deletedUserDoc = await db.collection("deletedUsers").doc(senderId).get();
        if (deletedUserDoc.exists) {
            logger.info("Skipping notification - sender account is deleted", {
                structuredData: true,
                messageId,
                senderId,
            });
            return null;
        }

        // Skip notifications for call history messages
        // These are logged after a call ends - no need to notify "you have a message"
        if (messageType === 'call') {
            logger.info("Skipping notification for call history message", {
                structuredData: true,
                messageId,
                spaceId,
            });
            return null;
        }

        logger.info("Processing chat notification", {
            structuredData: true,
            messageId,
            spaceId,
            senderId,
            messageType,
            hasMentions: !!(mentionedUserIds && mentionedUserIds.length > 0),
        });

        // Get recipients
        const recipientIds = await getRecipientIds(spaceId, senderId);

        if (recipientIds.length === 0) {
            logger.info("No recipients found for chat message", {
                structuredData: true,
                messageId,
                spaceId,
            });
            return null;
        }

        // Get mentioned user IDs (use client-provided list or extract from content)
        const mentioned = mentionedUserIds && mentionedUserIds.length > 0
            ? mentionedUserIds.filter(id => recipientIds.includes(id))
            : await extractMentionedUserIds(content, recipientIds);

        // Get conversation info and format body (chat = push only; not shown in alerts list)
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
                    messageToSend = {
                        ...fcmMessage,
                        notification: {
                            ...fcmMessage.notification,
                            title: fcmMessage.notification.title,
                            body: `${senderName} mentioned you: ${(content || "").substring(0, 100)}${(content || "").length > 100 ? "..." : ""}`,
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

        return null;
    } catch (error) {
        logger.error("Error processing chat notification", {
            structuredData: true,
            messageId,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        return null;
    }
});
