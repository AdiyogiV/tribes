/**
 * First Reading — Cloud Function wrapper.
 *
 * Thin shell around the insights engine first_reading flavor.
 * The real logic (prompt, validation, storage) lives in
 * insights/flavors/first_reading.js. This file only handles:
 *   - Firebase onCall wiring + auth
 *   - "Already exists" fast path (no AI call)
 *   - Response formatting for the Flutter client
 *   - Backward-compat exports for astro_sync.js
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, logger } from "../lib/firebase.js";
import { geminiApiKey } from "../lib/secrets.js";
import { requireAuth } from "../lib/auth_utils.js";
import { runFlavor } from "../insights/engine/insight_engine.js";
import {
    firstReadingFlavor,
    buildCosmicHighlights,
} from "../insights/flavors/first_reading.js";

// Re-export for astro_sync.js backward compatibility
export { buildCosmicHighlights };

// REMOVED: generateFirstReadingContent — astro_sync now uses runFlavor(firstReadingFlavor, ...) directly.

/**
 * Generate first reading — Cloud Function (onCall).
 * Called after astro sync completes for new users.
 * Returns cached reading on fast path; generates via insights engine otherwise.
 */
export const generateFirstReading = onCall(
    {
        secrets: [geminiApiKey],
        timeoutSeconds: 45,
        memory: "256MiB",
        region: "asia-southeast2",
        invoker: "public",
    },
    async (request) => {
        const uid = requireAuth(request, "generate first reading");
        const startTime = Date.now();
        logger.info("📖 generateFirstReading invoked", { uid });

        try {
            const userRef = db.collection("users").doc(uid);
            const userSnap = await userRef.get();

            if (!userSnap.exists) {
                throw new HttpsError("not-found", "User not found");
            }

            const userData = userSnap.data();
            const astroData = userData.astrologyData;

            if (!astroData) {
                throw new HttpsError("failed-precondition", "No astrology data found");
            }

            // Fast path — reading already exists (permanent, never expires)
            if (astroData.firstReading?.content) {
                logger.info("First reading cache hit", { uid, latency: Date.now() - startTime });
                return {
                    success: true,
                    alreadyExists: true,
                    data: {
                        content: astroData.firstReading.content,
                        highlights: astroData.firstReading.highlights || buildCosmicHighlights(astroData),
                        generatedAt: astroData.firstReading.generatedAt,
                    },
                };
            }

            if (!astroData.sunSign) {
                return { success: false, error: "Astro data not ready yet", data: null };
            }

            // Generate via insights engine (gatherContext → prompt → AI → validate → store)
            const { result } = await runFlavor(firstReadingFlavor, { uid });

            // Build highlights for the response (store() already saved them to Firestore)
            const highlights = buildCosmicHighlights(astroData);

            logger.info("✅ First reading complete", {
                uid, latency: Date.now() - startTime, contentLength: result?.length,
            });

            return {
                success: true,
                alreadyExists: false,
                data: {
                    content: result,
                    highlights,
                    generatedAt: new Date().toISOString(),
                },
            };
        } catch (error) {
            if (error instanceof HttpsError) throw error;
            logger.error("❌ First reading failed", {
                uid, error: error.message, stack: error.stack?.substring(0, 300),
                latency: Date.now() - startTime,
            });
            return { success: false, error: error.message, data: null };
        }
    },
);
