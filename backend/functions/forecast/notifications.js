/**
 * One daily forecast notification, sourced from the same read-model as every
 * other insight surface. No AI call and no card-index choreography.
 */

import { db, FieldValue, logger } from "../../lib/firebase.js";
import { getRecentlyActiveUids } from "../../lib/auth_utils.js";
import { dayKey, istToday } from "./forecast_helpers.js";

const ACTIVE_DAYS = Number(process.env.FORECAST_NOTIFICATION_ACTIVE_DAYS || 7);
const MAX_USERS = Number(process.env.FORECAST_NOTIFICATION_MAX_USERS || 500);

function previewFor(day) {
    const copy = day?.narrative || day?.action || "Your personal forecast is ready.";
    return String(copy).replace(/[*_#`]/g, "").trim().slice(0, 150);
}

/**
 * Create deterministic notification documents for today's narrated forecast.
 * Firestore's notification trigger performs the actual FCM delivery.
 */
export async function runDispatchDailyForecastNotifications() {
    const today = dayKey(istToday());
    const month = today.slice(0, 7);
    const active = [...await getRecentlyActiveUids(ACTIVE_DAYS)].slice(0, MAX_USERS);
    let created = 0;
    let skipped = 0;

    for (const uid of active) {
        const userRef = db.collection("users").doc(uid);
        const [userSnap, forecastSnap] = await Promise.all([
            userRef.get(),
            userRef.collection("forecast").doc(month).get(),
        ]);
        const user = userSnap.data() || {};
        if (user.dailyInsightNotificationsEnabled === false) {
            skipped++;
            continue;
        }

        const day = forecastSnap.exists ?
            (forecastSnap.data().days || []).find((entry) => entry.date === today) :
            null;
        if (!day?.heading || !day?.narrative) {
            skipped++;
            continue;
        }

        const ref = db.collection("notifications").doc(uid)
            .collection("notifications").doc(`daily-forecast-${today}`);
        const result = await db.runTransaction(async (transaction) => {
            if ((await transaction.get(ref)).exists) return false;
            transaction.create(ref, {
                type: "dailyAstroInsight",
                title: day.heading,
                preview: previewFor(day),
                insightId: today,
                date: today,
                source: "forecast",
                timestamp: FieldValue.serverTimestamp(),
                read: false,
            });
            return true;
        });
        if (result) created++;
        else skipped++;
    }

    logger.info("forecast notifications: complete", {
        active: active.length, created, skipped, date: today,
    });
    return { active: active.length, created, skipped, date: today };
}
