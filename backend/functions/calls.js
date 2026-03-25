import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db, FieldValue, getMessaging, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";
import { getUserFcmTokens } from "../lib/fcm_utils.js";

/**
 * Send push notification for incoming call
 * Triggered when a new call document is created
 * 
 * Uses FCM data message for iOS and Android
 */
export const sendCallNotification = onDocumentCreated(
    {
        document: "calls/{callId}",
    },
    withIdempotency("sendCallNotification", async (event) => {
        const snap = event.data;
        const callData = snap.data();
        const callId = event.params.callId;

        try {
            logger.info("📞 [CALL] New call notification triggered", {
                structuredData: true,
                callId,
                callerId: callData.callerId,
                calleeId: callData.calleeId,
                callType: callData.type,
            });

            // Only send notification if call is in 'ringing' state
            if (callData.status !== 'ringing') {
                logger.info("📞 [CALL] Skipping notification - call not ringing", {
                    structuredData: true,
                    status: callData.status,
                });
                return;
            }

            // Get callee's tokens (FCM)
            const calleeDoc = await db.collection("users").doc(callData.calleeId).get();
            const calleeData = calleeDoc.data();
            const fcmTokens = getUserFcmTokens(calleeData);

            const isVideo = callData.type === 'video';
            const callerName = callData.callerName || 'Someone';
            const callBody = isVideo ? '📹 Incoming video call...' : '📞 Incoming voice call...';

            // Send FCM data message (iOS + Android)
            if (fcmTokens.length > 0) {
                // Create high-priority DATA-ONLY message for incoming call
                const message = {
                    tokens: fcmTokens,
                    data: {
                        type: 'incoming_call',
                        callId: callId,
                        callerId: callData.callerId,
                        callerName: callerName,
                        callerAvatar: callData.callerAvatar || '',
                        callType: callData.type || 'voice',
                        title: callerName,
                        body: callBody,
                        click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    },
                    android: {
                        priority: 'high',
                        ttl: 60000, // 60 seconds TTL
                    },
                    apns: {
                        headers: {
                            'apns-priority': '10',
                            'apns-push-type': 'background',
                            'apns-topic': 'com.canay.dhaara',
                        },
                        payload: {
                            aps: {
                                'content-available': 1,
                            },
                            type: 'incoming_call',
                            callId: callId,
                            callerId: callData.callerId,
                            callerName: callerName,
                            callType: callData.type || 'voice',
                        },
                    },
                };

                const response = await getMessaging().sendEachForMulticast(message);
                
                logger.info("📞 [CALL] FCM notification sent", {
                    structuredData: true,
                    callId,
                    successCount: response.successCount,
                    failureCount: response.failureCount,
                });
            }

            // Log overall delivery status
            if (fcmTokens.length === 0) {
                logger.warn("📞 [CALL] No tokens available for callee", {
                    structuredData: true,
                    callId,
                    calleeId: callData.calleeId,
                });
            } else {
                logger.info("📞 [CALL] Notification delivery complete", {
                    structuredData: true,
                    callId,
                    fcmTokenCount: fcmTokens.length,
                });
            }

        } catch (error) {
            logger.error("📞 [CALL] Error sending call notification", {
                structuredData: true,
                callId,
                error: String(error),
            });
            throw error;
        }
    })
);

/**
 * Handle call status changes
 * Clean up ICE candidates immediately when call ends
 */
export const onCallStatusChanged = onDocumentUpdated(
    "calls/{callId}",
    async (event) => {
        const before = event.data.before.data();
        const after = event.data.after.data();
        const callId = event.params.callId;

        // Only process if status changed
        if (before.status === after.status) return;

        logger.info("📞 [CALL] Status changed", {
            structuredData: true,
            callId,
            from: before.status,
            to: after.status,
        });

        // If call ended, clean up ICE candidates and persist missed_call for alerts list
        if (["ended", "rejected", "missed", "cancelled"].includes(after.status)) {
            try {
                const callRef = db.collection("calls").doc(callId);

                // Persist missed call to callee's notifications (for alerts list)
                if (after.status === "missed" && after.calleeId) {
                    const callerName = after.callerName || (await db.collection("users").doc(after.callerId).get()).data()?.name || "Someone";
                    await db
                        .collection("notifications")
                        .doc(after.calleeId)
                        .collection("notifications")
                        .add({
                            type: "missed_call",
                            read: false,
                            callId,
                            callerId: after.callerId,
                            callerName,
                            callerAvatar: after.callerAvatar || "",
                            callType: after.type || "voice",
                            timestamp: FieldValue.serverTimestamp(),
                        });
                    logger.info("📞 [CALL] Missed call notification persisted", {
                        structuredData: true,
                        callId,
                        calleeId: after.calleeId,
                    });
                }

                // Delete ICE candidates subcollections
                const callerCandidates = await callRef.collection("callerCandidates").get();
                const calleeCandidates = await callRef.collection("calleeCandidates").get();

                if (callerCandidates.empty && calleeCandidates.empty) {
                    logger.info("📞 [CALL] No ICE candidates to clean up", {
                        structuredData: true,
                        callId,
                    });
                    return;
                }

                const batch = db.batch();
                callerCandidates.docs.forEach((doc) => batch.delete(doc.ref));
                calleeCandidates.docs.forEach((doc) => batch.delete(doc.ref));
                await batch.commit();

                logger.info("📞 [CALL] Cleaned up ICE candidates", {
                    structuredData: true,
                    callId,
                    callerCandidatesCount: callerCandidates.size,
                    calleeCandidatesCount: calleeCandidates.size,
                });
            } catch (error) {
                logger.error("📞 [CALL] Error cleaning up call", {
                    structuredData: true,
                    callId,
                    error: String(error),
                });
            }
        }
    }
);
