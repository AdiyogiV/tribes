import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, getMessaging, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";
import { getOrdinal } from "../lib/utils.js";
import { getUserFcmTokens, removeInvalidTokens, isInvalidTokenError } from "../lib/fcm_utils.js";

export const sendPushNotification = onDocumentCreated({
    document: "notifications/{userId}/notifications/{notificationId}",
    region: "asia-southeast2",
    memory: "256MiB",
}, withIdempotency("sendPushNotification", async (event) => {
    const snap = event.data;
    const notificationData = snap.data();
    const userId = event.params.userId;
    try {
        logger.info("📲 [FCM-TRIGGER] sendPushNotification triggered", {
            structuredData: true,
            userId,
            notificationId: event.params.notificationId,
            notificationType: notificationData.type,
            notificationDataKeys: Object.keys(notificationData),
            cardType: notificationData.cardType || "n/a",
            date: notificationData.date || "n/a",
        });

        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        const fcmTokens = getUserFcmTokens(userData);

        logger.info("📲 [FCM-TOKENS] User document retrieved", {
            structuredData: true,
            userId,
            userExists: userDoc.exists,
            hasFcmTokens: !!userData?.fcmTokens,
            hasLegacyToken: !!userData?.fcmToken,
            tokenCount: fcmTokens.length,
        });

        if (fcmTokens.length === 0) {
            logger.warn("📲 [FCM-SKIP] No FCM tokens found for user - notification will not be sent", {
                structuredData: true,
                userId,
                notificationId: event.params.notificationId,
                notificationType: notificationData.type,
            });
            return null;
        }

        logger.info("📲 [FCM-PREPARE] FCM tokens found, preparing notification", {
            structuredData: true,
            userId,
            notificationId: event.params.notificationId,
            tokenCount: fcmTokens.length,
            tokenPrefixes: fcmTokens.map(t => t.substring(0, 20) + "..."),
        });
        // Base message without token (tokens added when sending)
        const baseMessage = {
            notification: { title: "New Notification", body: "You have a new notification" },
            data: {
                type: notificationData.type,
                notificationId: event.params.notificationId,
                authorName: "",
                authorPic: "",
                authorId: "",
                reply: "",
                space: "",
                post: "",
                spaceName: "",
            },
            // iOS specific options - REQUIRED for iOS push notifications
            apns: {
                payload: {
                    aps: {
                        'mutable-content': 1,
                        badge: 1,
                        sound: 'default',
                        'content-available': 1,
                    },
                },
                headers: {
                    'apns-priority': '10',
                },
            },
            // Android specific options
            android: {
                priority: 'high',
                ttl: 86400000, // 24 hours
                notification: {
                    channelId: 'general_notifications',
                    priority: 'high',
                    defaultSound: true,
                    defaultVibrateTimings: true,
                },
            },
        };
        // group_call: push is sent by group_call_notifications.js; do not send again
        if (notificationData.type === "group_call") {
            logger.info("📲 [FCM-SKIP] group_call push sent by group_call_notifications; skipping trigger FCM", {
                structuredData: true,
                userId,
                notificationId: event.params.notificationId,
            });
            return null;
        }

        // Keep reference for modifications below
        const message = baseMessage;
        switch (notificationData.type) {
            case "missed_call": {
                const callerName = notificationData.callerName || "Someone";
                const callType = notificationData.callType === "video" ? "video" : "voice";
                message.notification.title = "Missed call";
                message.notification.body = `Missed ${callType} call from ${callerName}`;
                message.data.type = "missed_call";
                message.data.callId = notificationData.callId || "";
                message.data.callerId = notificationData.callerId || "";
                message.data.callerName = callerName;
                message.data.callType = callType;
                break;
            }
            case "reply": {
                const replierDoc = await db.collection("users").doc(notificationData.author).get();
                const replierData = replierDoc.data();
                const spaceDoc = await db.collection("spaces").doc(notificationData.space).get();
                const spaceData = spaceDoc.data();
                message.notification.title = `${replierData.name} replied to your post in ${spaceData.name}`;
                message.notification.body = `Tap to view ${replierData.name}'s reply to your post in group ${spaceData.name}.`;
                message.data.reply = notificationData.postId;
                message.data.space = notificationData.space;
                break;
            }
            case "invite": {
                const inviterDoc = await db.collection("users").doc(notificationData.inviter).get();
                const inviterData = inviterDoc.data();
                const invitedSpaceDoc = await db.collection("spaces").doc(notificationData.space).get();
                const invitedSpaceData = invitedSpaceDoc.data();
                message.notification.title = `${inviterData.name} invited you to ${invitedSpaceData.name}`;
                message.notification.body = `Tap to view the invite from ${inviterData.name}.`;
                break;
            }
            case "addedtogroup": {
                const adderDoc = await db.collection("users").doc(notificationData.inviter).get();
                const adderData = adderDoc.data();
                const addedSpaceDoc = await db.collection("spaces").doc(notificationData.space).get();
                const addedSpaceData = addedSpaceDoc.data();
                message.notification.title = `Added to group ${addedSpaceData.name}`;
                message.notification.body = `${adderData.name} added you to the group ${addedSpaceData.name}. Tap to View.`;
                break;
            }
            case "request": {
                const requestorDoc = await db.collection("users").doc(notificationData.requestor).get();
                const requestorData = requestorDoc.data();
                const requestedSpaceDoc = await db.collection("spaces").doc(notificationData.space).get();
                const requestedSpaceData = requestedSpaceDoc.data();
                message.notification.title = `${requestorData.name} requested to join ${requestedSpaceData.name}`;
                message.notification.body = `Tap to view the request from ${requestorData.name}.`;
                message.data.space = notificationData.space;
                break;
            }
            case "namaste": {
                const authorDoc = await db.collection("users").doc(notificationData.author).get();
                const authorData = authorDoc.data();
                message.notification.title = `${authorData.name} says Namaste`;
                message.notification.body = `Tap to greet ${authorData.name} back.`;
                message.data.authorName = authorData.name;
                message.data.authorId = notificationData.author;
                message.data.authorPic = authorData.displayPicture || "";
                break;
            }
            case "newSpacePost": {
                const postauthorDoc = await db.collection("users").doc(notificationData.author).get();
                const postauthorData = postauthorDoc.data();
                const postSpaceDoc = await db.collection("spaces").doc(notificationData.space).get();
                const postSpaceData = postSpaceDoc.data();
                message.notification.title = `${postauthorData.name} posted in ${postSpaceData.name}`;
                message.notification.body = `Tap to view ${postauthorData.name}'s new post in ${postSpaceData.name}.`;
                message.data.authorName = postauthorData.name;
                message.data.authorId = notificationData.author;
                message.data.authorPic = postauthorData.displayPicture || "";
                message.data.post = notificationData.postId;
                message.data.space = notificationData.space;
                message.data.spaceName = postSpaceData.name;
                break;
            }
            case "like": {
                const likedSpaceDoc = await db.collection("spaces").doc(notificationData.space).get();
                const likedSpaceData = likedSpaceDoc.data();
                message.notification.title = `${notificationData.likerName} liked your post.`;
                message.notification.body = `Tap to view the post that ${notificationData.likerName} liked in ${likedSpaceData.name}.`;
                message.data.post = notificationData.postId;
                message.data.space = notificationData.space;
                message.data.authorId = notificationData.liker;
                message.data.authorName = notificationData.likerName;
                message.data.spaceName = likedSpaceData.name;
                break;
            }
            case "dailyAstroInsight": {
                const title = notificationData.title || "Your Daily Insight";
                const preview = notificationData.preview ||
                    "Tap to read your personalized forecast";
                message.notification.title = title;
                message.notification.body = preview.length > 120 ?
                    `${preview.substring(0, 120)}...` : preview;
                message.data.type = "dailyAstroInsight";
                message.data.insightId = notificationData.insightId || "";
                message.data.date = notificationData.date || "";
                message.data.source = notificationData.source || "forecast";

                logger.info("[FCM] Prepared unified forecast notification", {
                    structuredData: true,
                    userId,
                    notificationId: event.params.notificationId,
                    title,
                });
                break;
            }
            case "chat":
            case "message": {
                // Chat/message notifications (typically handled by onNewChatMessage, but also support manual creation)
                const senderName = notificationData.senderName || "Someone";
                const messageContent = notificationData.messageContent || notificationData.content || "";
                const messageType = notificationData.messageType || "text";
                const conversationName = notificationData.conversationName || notificationData.spaceName || senderName;
                
                message.notification.title = conversationName;
                
                switch (messageType) {
                    case 'text':
                        const displayContent = messageContent.length > 50 
                            ? messageContent.substring(0, 50) + '...' 
                            : messageContent;
                        message.notification.body = `${senderName}: ${displayContent}`;
                        break;
                    case 'image':
                        message.notification.body = `${senderName} sent a photo`;
                        break;
                    case 'video':
                        message.notification.body = `${senderName} sent a video`;
                        break;
                    case 'audio':
                        message.notification.body = `${senderName} sent an audio message`;
                        break;
                    default:
                        message.notification.body = `${senderName} sent a message`;
                }
                
                message.data.type = "chat";
                message.data.spaceId = notificationData.spaceId || "";
                message.data.senderId = notificationData.senderId || "";
                message.data.senderName = senderName;
                message.data.messageType = messageType;
                break;
            }
            case "follow": {
                // Someone started following you
                const followerName = notificationData.fromUserName || "Someone";
                message.notification.title = "New Follower";
                message.notification.body = `${followerName} started following you`;
                message.data.type = "follow";
                message.data.authorId = notificationData.fromUserId || "";
                message.data.authorName = followerName;
                message.data.authorPic = notificationData.fromUserAvatar || "";
                break;
            }
            case "followRequest": {
                // Someone wants to follow you (private profile)
                const requesterName = notificationData.fromUserName || "Someone";
                message.notification.title = "Follow Request";
                message.notification.body = `${requesterName} wants to follow you`;
                message.data.type = "followRequest";
                message.data.authorId = notificationData.fromUserId || "";
                message.data.authorName = requesterName;
                message.data.authorPic = notificationData.fromUserAvatar || "";
                break;
            }
            case "followAccepted": {
                // Your follow request was accepted
                const accepterName = notificationData.fromUserName || "Someone";
                message.notification.title = "Follow Request Accepted";
                message.notification.body = `${accepterName} accepted your follow request`;
                message.data.type = "followAccepted";
                message.data.authorId = notificationData.fromUserId || "";
                message.data.authorName = accepterName;
                message.data.authorPic = notificationData.fromUserAvatar || "";
                break;
            }
            case "mutualFollow": {
                // You and someone are now friends (mutual follow)!
                const friendName = notificationData.fromUserName || "Someone";
                message.notification.title = "You're Now Friends! 🎉";
                message.notification.body = `You and ${friendName} are now friends. Tap to see your compatibility!`;
                message.data.type = "mutualFollow";
                message.data.authorId = notificationData.fromUserId || "";
                message.data.authorName = friendName;
                message.data.authorPic = notificationData.fromUserAvatar || "";
                break;
            }
            case "anonymousMessage": {
                const preview = notificationData.preview || "";
                message.notification.title = "New anonymous message";
                message.notification.body =
                    preview.length > 0 ? preview : "Tap to see what they said.";
                message.data.type = "anonymousMessage";
                message.data.messageId = notificationData.messageId || "";
                break;
            }
        }

        // Set appropriate Android channel and iOS category based on notification type
        const channelMap = {
            "missed_call": "calls",
            "group_call": "calls",
            "chat": "chat_messages",
            "message": "chat_messages",
            "reply": "social_notifications",
            'like': 'social_notifications',
            'namaste': 'social_notifications',
            'newSpacePost': 'social_notifications',
            'follow': 'social_notifications',
            'followRequest': 'social_notifications',
            'followAccepted': 'social_notifications',
            'mutualFollow': 'social_notifications',
            'invite': 'gram_notifications',
            'request': 'gram_notifications',
            'addedtogroup': 'gram_notifications',
            'dailyAstroInsight': 'astro_insights',
            'anonymousMessage': 'general_notifications',
        };
        const channelId = channelMap[notificationData.type] || 'general_notifications';
        
        // Update Android channel
        message.android.notification.channelId = channelId;
        
        // Update iOS category for action handling
        message.apns.payload.aps.category = notificationData.type;

        const messaging = getMessaging();
        logger.info("📲 [FCM-SEND] Sending FCM notification to all devices", {
            structuredData: true,
            userId,
            notificationId: event.params.notificationId,
            type: notificationData.type,
            deviceCount: fcmTokens.length,
            title: message.notification.title,
            body: message.notification.body?.substring(0, 50) + "...",
            dataKeys: Object.keys(message.data),
        });

        // Send to all user's devices
        const invalidTokens = [];
        const sendPromises = fcmTokens.map(async (token, index) => {
            logger.info(`📲 [FCM-DEVICE] Sending to device ${index + 1}/${fcmTokens.length}`, {
                structuredData: true,
                userId,
                tokenPrefix: token.substring(0, 20) + "...",
            });
            try {
                const messageWithToken = { ...message, token };
                const response = await messaging.send(messageWithToken);
                logger.info(`📲 [FCM-SUCCESS] Device ${index + 1} received notification`, {
                    structuredData: true,
                    userId,
                    messageId: response,
                });
                return { success: true, token, messageId: response };
            } catch (error) {
                // Check if token is invalid and should be removed
                const errorCode = error.code || error.errorInfo?.code;
                logger.error(`📲 [FCM-ERROR] Failed to send to device ${index + 1}`, {
                    structuredData: true,
                    userId,
                    errorCode,
                    errorMessage: String(error),
                });
                if (isInvalidTokenError(errorCode)) {
                    invalidTokens.push(token);
                    logger.warn("📲 [FCM-INVALID] Invalid FCM token detected, will remove", {
                        structuredData: true,
                        userId,
                        errorCode,
                    });
                }
                return { success: false, token, error: String(error) };
            }
        });

        const results = await Promise.all(sendPromises);
        const successCount = results.filter(r => r.success).length;
        const failCount = results.filter(r => !r.success).length;

        // Clean up invalid tokens
        if (invalidTokens.length > 0) {
            await removeInvalidTokens(userId, invalidTokens);
        }

        logger.info("📲 [FCM-COMPLETE] FCM notifications sent", {
            structuredData: true,
            userId,
            notificationId: event.params.notificationId,
            notificationType: notificationData.type,
            cardType: notificationData.cardType || "n/a",
            successCount,
            failCount,
            totalDevices: fcmTokens.length,
            invalidTokensRemoved: invalidTokens.length,
            messageIds: results.filter(r => r.success).map(r => r.messageId),
        });

        return null;
    } catch (error) {
        logger.error("Error sending push", { structuredData: true, error: String(error) });
        return null;
    }
}));


