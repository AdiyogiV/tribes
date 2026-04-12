/**
 * Cosmic Agent Runner — Cloud Function Triggers (Phase 4 + Phase 7)
 *
 * Two triggers:
 * 1. Scheduled: runs daily at 2:30 AM UTC (after sky_positions updates at 2 AM)
 * 2. Callable: manual trigger for testing via HTTP
 *
 * Both load sky positions from Firestore and invoke the agent.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { geminiApiKey, tavilyApiKey } from "../lib/secrets.js";
import { db, logger } from "../lib/firebase.js";
import { runCosmicAgent } from "./cosmic_agent.js";
import { generateDailyTransitReadings } from "./transit_personalization.js";

// =============================================================================
// SCHEDULED TRIGGER — Daily at 2:30 AM UTC
// =============================================================================

export const cosmicAgentDaily = onSchedule(
    {
        schedule: "30 2 * * *",  // 2:30 AM UTC daily
        timeZone: "UTC",
        timeoutSeconds: 300,     // 5 minute timeout
        memory: "1GiB",
        region: "us-central1",
        secrets: [geminiApiKey, tavilyApiKey],
        retryCount: 1,           // Retry once on failure
    },
    async () => {
        logger.info("Cosmic agent daily run starting");

        const skyPositions = await loadSkyPositions();
        const today = new Date().toISOString().split("T")[0];

        const result = await runCosmicAgent({
            geminiApiKey: geminiApiKey.value(),
            tavilyApiKey: tavilyApiKey.value(),
            date: today,
            skyPositions,
        });

        if (!result.success) {
            logger.error("Cosmic agent daily run failed", {
                structuredData: true,
                error: result.error,
            });
            // Still try to generate transit readings even if agent fails
        }

        // Generate per-ascendant transit readings (12 calls, ~$0.004)
        try {
            await generateDailyTransitReadings(geminiApiKey.value(), today);
            logger.info("Transit readings generated successfully");
        } catch (transitErr) {
            logger.error("Transit readings generation failed", {
                structuredData: true,
                error: String(transitErr),
            });
        }

        if (!result.success) {
            throw new Error(`Agent run failed: ${result.error}`);
        }

        logger.info("Cosmic agent daily run completed", {
            structuredData: true,
            runId: result.runId,
            toolCalls: result.stats?.toolCalls,
            searchesUsed: result.stats?.searchesUsed,
            wallTimeMs: result.stats?.wallTimeMs,
        });
    }
);

// =============================================================================
// CALLABLE TRIGGER — Manual / Testing
// =============================================================================

export const cosmicAgentManual = onCall(
    {
        timeoutSeconds: 300,
        memory: "1GiB",
        region: "us-central1",
        secrets: [geminiApiKey, tavilyApiKey],
    },
    async (request) => {
        // Optional: require auth
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Authentication required");
        }

        const dateOverride = request.data?.date || null;
        const today = dateOverride || new Date().toISOString().split("T")[0];

        logger.info("Cosmic agent manual run starting", {
            structuredData: true,
            date: today,
            uid: request.auth.uid,
        });

        const skyPositions = await loadSkyPositions();

        const result = await runCosmicAgent({
            geminiApiKey: geminiApiKey.value(),
            tavilyApiKey: tavilyApiKey.value(),
            date: today,
            skyPositions,
        });

        return {
            success: result.success,
            runId: result.runId,
            stats: result.stats,
            summary: typeof result.summary === "string"
                ? result.summary.substring(0, 2000)
                : String(result.summary || "").substring(0, 2000),
            error: result.error || null,
        };
    }
);

// =============================================================================
// HELPER — Load sky positions from Firestore
// =============================================================================

async function loadSkyPositions() {
    try {
        const doc = await db.collection("global_astro").doc("sky_positions").get();
        if (!doc.exists) {
            logger.warn("No sky positions document found");
            return null;
        }
        return doc.data()?.positions || null;
    } catch (error) {
        logger.error("Failed to load sky positions", {
            structuredData: true,
            error: String(error),
        });
        return null;
    }
}
