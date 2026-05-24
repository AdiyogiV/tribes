/**
 * Handler for `process_insight` task type.
 *
 * Originally `processInsightTask` in insight_worker.js.
 * Generates one user's daily astrology insight via AI.
 *
 * Payload: { userId, astrologyData, date }
 */

import { generateInsightForUserForce } from "../daily_astro_insights.js";

export async function handleProcessInsight(payload, ctx) {
    const { userId, astrologyData, date } = payload;
    const { db, logger } = ctx;

    if (!userId || !astrologyData) {
        logger.error("[INSIGHT-WORKER] Invalid task data", {
            structuredData: true,
            hasUserId: !!userId,
            hasAstrologyData: !!astrologyData,
        });
        return;
    }

    logger.info("[INSIGHT-WORKER] Processing user insight", {
        structuredData: true,
        userId,
        date,
        hasAscendant: !!astrologyData.ascendant,
        hasMoonSign: !!astrologyData.moonSign,
    });

    try {
        const result = await generateInsightForUserForce(userId, astrologyData, true);

        logger.info("[INSIGHT-WORKER] User insight generated", {
            structuredData: true,
            userId,
            date: result.date,
            theme: result.theme,
            sectionCount: result.sections?.length || 0,
        });

        await updateGenerationProgress(db, logger, date, userId, "success");
    } catch (error) {
        logger.error("[INSIGHT-WORKER] Failed to generate insight", {
            structuredData: true,
            userId,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });

        await updateGenerationProgress(db, logger, date, userId, "failed", String(error));

        throw error; // trigger Cloud Tasks retry
    }
}

async function updateGenerationProgress(db, logger, date, userId, status, error = null) {
    try {
        const progressRef = db
            .collection("insightGenerationLogs")
            .doc(date)
            .collection("users")
            .doc(userId);

        await progressRef.set({
            status,
            error,
            processedAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
        }, { merge: true });
    } catch (e) {
        logger.warn("[INSIGHT-WORKER] Failed to update progress", {
            structuredData: true,
            userId,
            error: String(e),
        });
    }
}
