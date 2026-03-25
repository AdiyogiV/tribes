import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, FieldValue, getMessaging, logger } from "../lib/firebase.js";
import { getUserFcmTokens } from "../lib/fcm_utils.js";

/**
 * Send push notification when someone starts/joins a group call
 * Triggered when the active call document is created or updated
 */
export const onGroupCallActivity = onDocumentWritten(
    "spaces/{spaceId}/calls/active",
    async (event) => {
        const spaceId = event.params.spaceId;
        const beforeData = event.data?.before?.data();
        const afterData = event.data?.after?.data();

        // Document was deleted (call ended) - no notification needed
        if (!afterData) {
            logger.info("📞 [GROUP_CALL] Call ended in space", { spaceId });
            return;
        }

        const beforeParticipants = beforeData?.participants || [];
        const afterParticipants = afterData?.participants || [];

        // Find newly joined participants
        const beforeIds = new Set(beforeParticipants.map(p => p.oderId));
        const newParticipants = afterParticipants.filter(p => !beforeIds.has(p.oderId));

        if (newParticipants.length === 0) {
            logger.info("📞 [GROUP_CALL] No new participants", { spaceId });
            return;
        }

        try {
            // Get space info
            const spaceDoc = await db.collection("spaces").doc(spaceId).get();
            const spaceData = spaceDoc.data();
            const spaceName = spaceData?.name || 'a gram';

            // Get all space members from spaceRoles collection
            // Members are stored in: spaceRoles/{spaceId}/roles/{userId}
            const membersSnapshot = await db
                .collection("spaceRoles")
                .doc(spaceId)
                .collection("roles")
                .get();

            if (membersSnapshot.empty) {
                logger.info("📞 [GROUP_CALL] No members in space", { spaceId });
                return;
            }

            // Get the caller info (first new participant)
            const caller = newParticipants[0];
            const callerName = caller.displayName || 'Someone';

            // Get current participant IDs to exclude from notifications
            const participantIds = new Set(afterParticipants.map(p => p.oderId));

            // Collect FCM tokens for all members NOT in the call
            const allTokens = [];
            const memberIds = [];

            // Valid roles that should receive notifications
            const validRoles = ['member', 'admin', 'creator'];

            for (const memberDoc of membersSnapshot.docs) {
                const memberId = memberDoc.id;
                const memberData = memberDoc.data();
                const memberRole = memberData?.role;
                
                // Skip if not a valid member role (skip 'invited', 'requested', etc.)
                if (!validRoles.includes(memberRole)) {
                    continue;
                }
                
                // Skip if member is already in the call
                if (participantIds.has(memberId)) {
                    continue;
                }

                memberIds.push(memberId);
            }

            // Fetch user data in parallel
            const userDocs = await Promise.all(
                memberIds.map(id => db.collection("users").doc(id).get())
            );

            for (const userDoc of userDocs) {
                if (userDoc.exists) {
                    const tokens = getUserFcmTokens(userDoc.data());
                    allTokens.push(...tokens);
                }
            }

            if (allTokens.length === 0) {
                logger.info("📞 [GROUP_CALL] No FCM tokens for space members", { 
                    spaceId,
                    memberCount: memberIds.length,
                    membersChecked: memberIds,
                });
                return;
            }

            logger.info("📞 [GROUP_CALL] Found tokens to notify", {
                spaceId,
                memberCount: memberIds.length,
                tokenCount: allTokens.length,
            });

            // Create notification message
            const participantCount = afterParticipants.length;
            const isNewCall = beforeParticipants.length === 0;
            
            const title = spaceName;
            const body = isNewCall 
                ? `📞 ${callerName} started a group call`
                : `📞 ${callerName} joined the call (${participantCount} in call)`;

            // IMPORTANT: Use data-only message (no 'notification' field)
            // This ensures our Flutter app can show custom notification with Join/Dismiss actions
            // If we include 'notification', FCM auto-displays it without our action buttons
            const message = {
                tokens: allTokens,
                // NOTE: No 'notification' field - this is intentional!
                // Data-only messages are delivered to our background handler
                // where we show a local notification with action buttons
                data: {
                    type: 'group_call',
                    spaceId: spaceId,
                    spaceName: spaceName,
                    callerName: callerName,
                    participantCount: String(participantCount),
                    // Include title/body in data for Flutter to display
                    title: title,
                    body: body,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                android: {
                    priority: 'high',
                    // No notification field for data-only handling
                },
                apns: {
                    headers: {
                        'apns-priority': '10',
                    },
                    payload: {
                        aps: {
                            // content-available enables background processing
                            'content-available': 1,
                            // Include alert for iOS to show notification
                            alert: {
                                title: title,
                                body: body,
                            },
                            sound: 'default',
                            badge: 1,
                            // mutable-content allows notification modification
                            'mutable-content': 1,
                        },
                    },
                },
            };

            const response = await getMessaging().sendEachForMulticast(message);

            logger.info("📞 [GROUP_CALL] Notifications sent", {
                spaceId,
                spaceName,
                callerName,
                participantCount,
                tokenCount: allTokens.length,
                successCount: response.successCount,
                failureCount: response.failureCount,
            });

            // Persist group_call docs for alerts list (one per non-participant member)
            const BATCH_SIZE = 500;
            const payload = {
                type: "group_call",
                read: false,
                spaceId,
                spaceName,
                callerName,
                participantCount,
                timestamp: FieldValue.serverTimestamp(),
            };
            for (let i = 0; i < memberIds.length; i += BATCH_SIZE) {
                const batch = db.batch();
                const chunk = memberIds.slice(i, i + BATCH_SIZE);
                for (const memberId of chunk) {
                    const ref = db.collection("notifications").doc(memberId).collection("notifications").doc();
                    batch.set(ref, payload);
                }
                await batch.commit();
            }
            logger.info("📞 [GROUP_CALL] Alert docs persisted", {
                spaceId,
                memberCount: memberIds.length,
            });

        } catch (error) {
            logger.error("📞 [GROUP_CALL] Error sending notifications", {
                spaceId,
                error: String(error),
            });
        }
    }
);

