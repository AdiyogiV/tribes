/**
 * Handler for `dispatch_card_notification` task type.
 *
 * Originally `dispatchCardNotification` in daily_astro_insights.js.
 * Sends a single insight-card push notification (4 per day, scheduled at
 * 6 AM / 12 PM / 5 PM / 9 PM IST). Idempotent: each card has a per-insight
 * `cardNotifications[cardIndex].sent` flag.
 *
 * Payload: { userId, date, cardIndex, cardType, title, content, scheduledFor }
 */

import { stripMarkdown } from "../../lib/astro_helpers.js";

export async function handleDispatchCardNotification(payload, ctx) {
    // cardType is documented in payload but unused in this handler
    const { userId, date, cardIndex, title, content, scheduledFor } = payload;
    const { db, FieldValue, logger } = ctx;

    if (!userId || !date || cardIndex === undefined) {
        logger.error("[DISPATCH-WORKER] Invalid task data", {
            structuredData: true,
            hasUserId: !!userId,
            hasDate: !!date,
            cardIndex,
        });
        return; // Don't retry invalid tasks
    }

    logger.info("[DISPATCH-WORKER] Dispatching card notification", {
        structuredData: true,
        userId,
        date,
        cardIndex,
        scheduledFor,
    });

    try {
        // Skip if already delivered
        const insightSnap = await db.collection("users").doc(userId).collection("dailyInsights").doc(date).get();
        if (insightSnap.exists) {
            const data = insightSnap.data();
            const cardNotifications = data?.cardNotifications || {};
            const cardState = cardNotifications[String(cardIndex)] || cardNotifications[cardIndex];
            if (cardState?.sent === true) {
                logger.info("[DISPATCH-WORKER] Card already sent, skipping", {
                    structuredData: true,
                    userId,
                    date,
                    cardIndex,
                });
                return;
            }
        }

        // Create notification document
        const notificationRef = db
            .collection("notifications")
            .doc(userId)
            .collection("notifications")
            .doc();

        await notificationRef.set({
            type: "dailyAstroInsight",
            cardType: "insight",
            cardIndex: cardIndex || 0,
            totalCards: 4,
            title: title || "",
            preview: stripMarkdown(content || "").substring(0, 150),
            insightId: date,
            date: date,
            timestamp: FieldValue.serverTimestamp(),
            read: false,
        });

        // Mark card as sent on the insight doc
        try {
            const insightRef = db
                .collection("users")
                .doc(userId)
                .collection("dailyInsights")
                .doc(date);

            await insightRef.update({
                [`cardNotifications.${cardIndex}.sent`]: true,
                [`cardNotifications.${cardIndex}.sentAt`]: FieldValue.serverTimestamp(),
            });
        } catch (updateError) {
            logger.warn("[DISPATCH-WORKER] Failed to update insight cardNotifications", {
                structuredData: true,
                userId,
                cardIndex,
                error: String(updateError),
            });
        }

        logger.info("[DISPATCH-WORKER] Card notification dispatched", {
            structuredData: true,
            userId,
            date,
            cardIndex,
        });
    } catch (error) {
        logger.error("[DISPATCH-WORKER] Failed to dispatch card notification", {
            structuredData: true,
            userId,
            date,
            cardIndex,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error; // Re-throw to trigger Cloud Tasks retry
    }
}
