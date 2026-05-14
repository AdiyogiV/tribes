import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { db, logger } from "../lib/firebase.js";
import { geminiApiKey, freeAstrologyApiKey } from "../lib/secrets.js";
import { generateInsightForUserForce } from "./daily_astro_insights.js";

/**
 * INSIGHT WORKER
 * Processes one user insight at a time via Cloud Tasks queue.
 * This prevents quota spikes by controlling concurrency at the worker level.
 *
 * maxInstances: 5 means max 5 users processed in parallel (vs. 50 with old batch)
 * rateLimits: 10/s dispatch rate ensures smooth throughput
 */
export const processInsightTask = onTaskDispatched({
    retryConfig: {
        maxAttempts: 3,
        minBackoffSeconds: 30,
        maxBackoffSeconds: 300,
    },
    rateLimits: {
        maxConcurrentDispatches: 10,
        maxDispatchesPerSecond: 2, // 2 tasks/sec = ~120/min = steady load
    },
    region: "asia-southeast2",
    memory: "512MiB", // Reduced from 1GiB — per-user insight generation is well under this budget
    timeoutSeconds: 120, // Each user gets 2 minutes max
    secrets: [geminiApiKey, freeAstrologyApiKey],
}, async (req) => {
    const { userId, astrologyData, date } = req.data;

    if (!userId || !astrologyData) {
        logger.error("[INSIGHT-WORKER] Invalid task data", {
            structuredData: true,
            hasUserId: !!userId,
            hasAstrologyData: !!astrologyData,
        });
        return; // Don't retry invalid tasks
    }

    logger.info("[INSIGHT-WORKER] Processing user insight", {
        structuredData: true,
        userId,
        date,
        hasAscendant: !!astrologyData.ascendant,
        hasMoonSign: !!astrologyData.moonSign,
    });

    try {
        // Generate insight for this single user
        // forceRegenerate=true since this is the daily batch run
        const result = await generateInsightForUserForce(userId, astrologyData, true);

        logger.info("[INSIGHT-WORKER] User insight generated", {
            structuredData: true,
            userId,
            date: result.date,
            theme: result.theme,
            sectionCount: result.sections?.length || 0,
        });

        // Update progress tracking (optional but useful for monitoring)
        await updateGenerationProgress(date, userId, "success");
    } catch (error) {
        logger.error("[INSIGHT-WORKER] Failed to generate insight", {
            structuredData: true,
            userId,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });

        await updateGenerationProgress(date, userId, "failed", String(error));

        // Re-throw to trigger Cloud Tasks retry
        throw error;
    }
});

/**
 * Update generation progress for monitoring
 * Stores in insightGenerationLogs/{date}/users/{userId}
 */
async function updateGenerationProgress(date, userId, status, error = null) {
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
        // Don't fail the task for logging errors
        logger.warn("[INSIGHT-WORKER] Failed to update progress", {
            structuredData: true,
            userId,
            error: String(e),
        });
    }
}
