/**
 * Current Times Reading — Cloud Function wrapper.
 *
 * Thin shell around the insights engine current_times flavor.
 * The real logic (prompt, validation, storage) lives in
 * insights/flavors/current_times.js. This file only handles:
 *   - Firebase onCall wiring + auth
 *   - 24h cache check (fast path from user doc)
 *   - Response formatting for the Flutter client
 *   - triggerCurrentTimesReading() export for astro_sync.js
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, logger } from "../lib/firebase.js";
import { geminiApiKey } from "../lib/secrets.js";
import { requireAuth } from "../lib/auth_utils.js";
import { runFlavor } from "../insights/engine/insight_engine.js";
import { currentTimesFlavor } from "../insights/flavors/current_times.js";

/**
 * Generate current times reading — Cloud Function (onCall).
 * Uses user's chart + current dasha. Stored under astrologyData.currentTimesReading.
 * Returns cached reading if generated within 24h; regenerates otherwise.
 */
export const generateCurrentTimesReading = onCall(
    {
        secrets: [geminiApiKey],
        timeoutSeconds: 45,
        memory: "256MiB",
        region: "asia-southeast2",
        invoker: "public",
    },
    async (request) => {
        const uid = requireAuth(request, "generate current times reading");
        const startTime = Date.now();
        logger.info("📖 generateCurrentTimesReading invoked", { uid });

        try {
            const userRef = db.collection("users").doc(uid);
            const userSnap = await userRef.get();

            if (!userSnap.exists) {
                throw new HttpsError("not-found", "User not found");
            }

            const userData = userSnap.data();
            const astroData = userData.astrologyData;

            if (!astroData) {
                throw new HttpsError(
                    "failed-precondition",
                    "No astrology data found. Save birth details first.",
                );
            }

            if (!astroData.sunSign) {
                return { success: false, error: "Astro data not ready yet", data: null };
            }

            // Fast path — return cached if generated within 24h
            const existing = astroData.currentTimesReading;
            if (existing?.content && existing.generatedAt) {
                const ts = existing.generatedAt?.toMillis?.() ?? 0;
                if (Date.now() - ts < 24 * 60 * 60 * 1000) {
                    logger.info("Current times reading cache hit", {
                        uid, latency: Date.now() - startTime,
                    });
                    const generatedAtIso = typeof existing.generatedAt?.toDate === "function" ?
                        existing.generatedAt.toDate().toISOString() :
                        new Date(ts).toISOString();
                    return {
                        success: true,
                        alreadyExists: true,
                        data: { content: existing.content, generatedAt: generatedAtIso },
                    };
                }
            }

            // Generate via insights engine (gatherContext → prompt → AI → validate → store)
            const { result } = await runFlavor(currentTimesFlavor, { uid });

            logger.info("✅ Current times reading complete", {
                uid, latency: Date.now() - startTime, contentLength: result?.length,
            });

            return {
                success: true,
                alreadyExists: false,
                data: { content: result, generatedAt: new Date().toISOString() },
            };
        } catch (error) {
            if (error instanceof HttpsError) throw error;
            logger.error("❌ Current times reading failed", {
                uid, error: error.message, stack: error.stack?.substring(0, 300),
                latency: Date.now() - startTime,
            });
            return { success: false, error: error.message, data: null };
        }
    },
);

/**
 * Generate and save current times reading (internal use by astro_sync).
 * Called during sync so the reading is ready when user reaches the Current Times step.
 * @param {string} uid - User ID
 * @param {string} userName - Display name
 * @param {Object} astroData - User's astrology data (from Firestore)
 * @returns {Promise<boolean>} True if saved or already existed, false on failure
 */
export async function triggerCurrentTimesReading(uid, userName, astroData) {
    if (astroData?.currentTimesReading?.content) {
        logger.info("Current times reading already exists, skipping", { uid });
        return true;
    }
    if (!astroData?.sunSign) {
        logger.warn("Cannot generate current times reading: no sunSign", { uid });
        return false;
    }
    try {
        logger.info("📖 Generating current times reading internally", { uid });

        // Use runFlavor with pre-loaded context (avoids redundant Firestore read)
        await runFlavor(currentTimesFlavor, { uid, userName, astroData });

        logger.info("✅ Current times reading generated and saved", { uid });
        return true;
    } catch (error) {
        logger.error("❌ Current times reading generation failed", {
            uid, error: error.message, stack: error.stack?.substring(0, 300),
        });
        return false;
    }
}
