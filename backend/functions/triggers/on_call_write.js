/**
 * onCallWrite — Consolidated trigger for `calls/{callId}` writes.
 *
 * Merges two previously separate Cloud Functions that listened on the same path:
 *   1. sendCallNotification (onDocumentCreated) — high-priority data-only FCM
 *      when a new call is in 'ringing' state.
 *   2. onCallStatusChanged   (onDocumentUpdated) — persists `missed_call`
 *      notification and cleans ICE candidate subcollections when the call ends.
 *
 * Uses `onDocumentWritten` so a single Eventarc subscription covers both
 * create and update events. Behavior is preserved exactly: branches are
 * selected via `event.data.before.exists` / `event.data.after.exists`.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, FieldValue, getMessaging, logger } from "../../lib/firebase.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { getUserFcmTokens } from "../../lib/fcm_utils.js";

/**
 * Handle the CREATE branch — emits the incoming call push.
 */
async function handleCallCreated(event) {
    const snap = event.data?.after;
    if (!snap) return;
    const callData = snap.data();
    if (!callData) return;
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
        if (callData.status !== "ringing") {
            logger.info("📞 [CALL] Skipping notification - call not ringing", {
                structuredData: true,
                status: callData.status,
            });
            return;
        }

        const calleeDoc = await db.collection("users").doc(callData.calleeId).get();
        const calleeData = calleeDoc.data();
        const fcmTokens = getUserFcmTokens(calleeData);

        const isVideo = callData.type === "video";
        const callerName = callData.callerName || "Someone";
        const callBody = isVideo ? "📹 Incoming video call..." : "📞 Incoming voice call...";

        if (fcmTokens.length > 0) {
            const message = {
                tokens: fcmTokens,
                data: {
                    type: "incoming_call",
                    callId: callId,
                    callerId: callData.callerId,
                    callerName: callerName,
                    callerAvatar: callData.callerAvatar || "",
                    callType: callData.type || "voice",
                    title: callerName,
                    body: callBody,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                    priority: "high",
                    ttl: 60000,
                },
                apns: {
                    headers: {
                        "apns-priority": "10",
                        "apns-push-type": "background",
                        "apns-topic": "com.canay.dhaara",
                    },
                    payload: {
                        aps: {
                            "content-available": 1,
                        },
                        type: "incoming_call",
                        callId: callId,
                        callerId: callData.callerId,
                        callerName: callerName,
                        callType: callData.type || "voice",
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
}

/**
 * Handle the UPDATE branch — persists missed_call alerts + cleans ICE.
 */
async function handleCallUpdated(event) {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    if (!beforeSnap || !afterSnap) return;
    const before = beforeSnap.data();
    const after = afterSnap.data();
    if (!before || !after) return;
    const callId = event.params.callId;

    if (before.status === after.status) return;

    logger.info("📞 [CALL] Status changed", {
        structuredData: true,
        callId,
        from: before.status,
        to: after.status,
    });

    if (["ended", "rejected", "missed", "cancelled"].includes(after.status)) {
        try {
            const callRef = db.collection("calls").doc(callId);

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

/**
 * Unified Cloud Function — single Eventarc subscription on calls/{callId}.
 *
 * Branches on create vs update by inspecting `before.exists` / `after.exists`.
 * We do NOT handle the delete branch here — calls are never directly deleted by
 * triggers, and any orphan cleanup is non-critical.
 *
 * NOTE: sendCallNotification was wrapped in `withIdempotency`. We keep that
 * wrapper for the create branch only (idempotency keyed on the event id).
 */
const wrappedCreated = withIdempotency("sendCallNotification", handleCallCreated);

export const onCallWrite = onDocumentWritten("calls/{callId}", async (event) => {
    const beforeExists = event.data?.before?.exists ?? false;
    const afterExists = event.data?.after?.exists ?? false;

    // Deleted — nothing to do.
    if (beforeExists && !afterExists) return null;

    // Created — invoke notification handler (wrapped with idempotency).
    if (!beforeExists && afterExists) {
        await wrappedCreated(event);
        return null;
    }

    // Updated — invoke status-change handler.
    if (beforeExists && afterExists) {
        await handleCallUpdated(event);
        return null;
    }

    return null;
});
