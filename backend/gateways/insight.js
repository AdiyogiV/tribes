/**
 * insightGateway — Single Cloud Run service for all insight/reading onCall methods.
 *
 * Consolidates 10 separate functions into 1, reducing deploy footprint.
 *
 * Flutter calls:  functions.httpsCallable('insightGateway').call({ method: '...', ...data })
 *
 * Methods:
 *   - generateFirstReading           [auth]     Generate birth chart first reading
 *   - generateCurrentTimesReading    [auth]     Generate current times reading
 *   - generateInsightForCurrentUser  [auth]     Generate daily personalized insight
 *   - clearAstroCaches               [auth]     Clear astro caches (admin)
 *   - generatePerHouseNow            [auth]     Force regenerate per-house readings
 *   - submitInsightFeedback          [auth]     Submit thumbs up/down for insight
 *   - toggleFavoriteInsight          [auth]     Toggle favorite status for insight
 *   - cosmicDailyManual              [auth]     Manual trigger for cosmic daily
 *   - generateMundaneForecast        [public]   Generate mundane astrology forecast
 *   - getMundaneForecast             [public]   Read cached mundane forecast
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { geminiApiKey, freeAstrologyApiKey } from "../lib/secrets.js";

// Import handlers
import { handleGenerateFirstReading } from "../functions/first_reading.js";
import { handleGenerateCurrentTimesReading } from "../functions/current_times_reading.js";
import {
    handleGenerateInsightForCurrentUser,
    handleClearAstroCaches,
} from "../functions/daily_astro_insights.js";
import { handleGeneratePerHouseNow } from "../insights/orchestration/per_house_scheduler.js";
import {
    handleSubmitInsightFeedback,
    handleToggleFavoriteInsight,
} from "../functions/astro_engagement.js";
import { handleCosmicDailyManual } from "../functions/cosmic_daily.js";
import {
    handleGenerateMundaneForecast,
    handleGetMundaneForecast,
} from "../mundane/index.js";

// Method registry — maps method name to handler + auth requirement
const methods = {
    // Auth-required methods
    generateFirstReading: { handler: (req) => handleGenerateFirstReading(req), auth: true },
    generateCurrentTimesReading: { handler: (req) => handleGenerateCurrentTimesReading(req), auth: true },
    generateInsightForCurrentUser: { handler: (req) => handleGenerateInsightForCurrentUser(req), auth: true },
    clearAstroCaches: { handler: (req) => handleClearAstroCaches(req), auth: true },
    generatePerHouseNow: { handler: (req) => handleGeneratePerHouseNow(req), auth: true },
    submitInsightFeedback: { handler: (req) => handleSubmitInsightFeedback(req), auth: true },
    toggleFavoriteInsight: { handler: (req) => handleToggleFavoriteInsight(req), auth: true },
    cosmicDailyManual: { handler: (req) => handleCosmicDailyManual(req), auth: true },

    // Public methods (no auth required)
    generateMundaneForecast: { handler: (req) => handleGenerateMundaneForecast(req), auth: false },
    getMundaneForecast: { handler: (req) => handleGetMundaneForecast(req), auth: false },
};

export const insightGateway = onCall({
    secrets: [geminiApiKey, freeAstrologyApiKey],
    timeoutSeconds: 300, // max of all methods (cosmicDailyManual needs 300)
    memory: "512MiB", // max of all methods
    region: "asia-southeast2",
    invoker: "public",
    cpu: 1,
    concurrency: 40,
    maxInstances: 2,
}, async (request) => {
    const { method, ...data } = request.data || {};

    if (!method || typeof method !== "string") {
        throw new HttpsError(
            "invalid-argument",
            "Missing required 'method' field. Expected one of: " + Object.keys(methods).join(", "),
        );
    }

    const entry = methods[method];
    if (!entry) {
        throw new HttpsError(
            "invalid-argument",
            `Unknown method '${method}'. Available: ${Object.keys(methods).join(", ")}`,
        );
    }

    // Auth check for protected methods
    if (entry.auth && !request.auth?.uid) {
        throw new HttpsError(
            "unauthenticated",
            `Method '${method}' requires authentication.`,
        );
    }

    logger.info("insightGateway", { method, uid: request.auth?.uid || "anon" });

    // Reconstruct request.data for handlers that read from it directly
    const proxiedRequest = {
        ...request,
        data,
    };

    try {
        return await entry.handler(proxiedRequest);
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("insightGateway unhandled error", {
            method,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        throw new HttpsError("internal", `${method} failed: ${error.message}`);
    }
});
