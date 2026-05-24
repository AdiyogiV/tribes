/**
 * healthGateway — Single Cloud Run service for all health/ayurveda onCall methods.
 *
 * Consolidates 5 separate functions into 1, reducing deploy footprint.
 *
 * Flutter calls:  functions.httpsCallable('healthGateway').call({ method: '...', ...data })
 *
 * Methods:
 *   - calculateAyurvedaProfile      [auth]   Calculate/recalculate Prakriti from birth chart
 *   - calculateCurrentVikriti       [auth]   Calculate current dosha balance (Vikriti)
 *   - resetAyurvedaProfile          [auth]   Reset and recalculate Ayurveda profile
 *   - getAyurvedaRecommendations    [auth]   AI-powered personalized wellness advice
 *   - analyzeHealthTrends           [auth]   Analyze watch health data for trend analysis
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { geminiApiKey } from "../lib/secrets.js";

// Import handlers
import {
    handleCalculateAyurvedaProfile,
    handleCalculateCurrentVikriti,
    handleResetAyurvedaProfile,
    handleGetAyurvedaRecommendations,
    handleAnalyzeHealthTrends,
} from "../functions/ayurveda.js";

// Method registry — maps method name to handler + auth requirement
const methods = {
    calculateAyurvedaProfile: { handler: (req) => handleCalculateAyurvedaProfile(req), auth: true },
    calculateCurrentVikriti: { handler: (req) => handleCalculateCurrentVikriti(req), auth: true },
    resetAyurvedaProfile: { handler: (req) => handleResetAyurvedaProfile(req), auth: true },
    getAyurvedaRecommendations: { handler: (req) => handleGetAyurvedaRecommendations(req), auth: true },
    analyzeHealthTrends: { handler: (req) => handleAnalyzeHealthTrends(req), auth: true },
};

export const healthGateway = onCall({
    secrets: [geminiApiKey],
    timeoutSeconds: 60, // max of all methods (calculateAyurvedaProfile, resetAyurvedaProfile, getAyurvedaRecommendations)
    memory: "512MiB", // max of all methods (getAyurvedaRecommendations)
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

    logger.info("healthGateway", { method, uid: request.auth?.uid || "anon" });

    // Reconstruct request.data for handlers that read from it directly
    const proxiedRequest = {
        ...request,
        data,
    };

    try {
        return await entry.handler(proxiedRequest);
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("healthGateway unhandled error", {
            method,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        throw new HttpsError("internal", `${method} failed: ${error.message}`);
    }
});
