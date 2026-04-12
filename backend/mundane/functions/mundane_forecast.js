/**
 * Mundane Astrology Cloud Functions
 *
 * Two endpoints:
 * 1. generateMundaneForecast (onCall) — manual trigger, returns full forecast
 * 2. refreshMundaneDaily (onSchedule) — daily cron, stores in Firestore
 *
 * Architecture:
 *   Firestore positions → Sky Adapter → Rules Engine → Synthesis Agent → Output
 *
 * The rules engine is PURE COMPUTATION (no LLM, no cost).
 * The synthesis agent uses Gemini Flash (~$0.001/call) for narrative.
 */

import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { db, FieldValue } from "../../lib/firebase.js";
import { geminiApiKey } from "../../lib/secrets.js";
import { buildSkyState } from "../engine/sky_adapter.js";
import { applyAllRules } from "../engine/rule_applier.js";
import { synthesizeForecast, synthesizeFallback } from "../engine/synthesis_agent.js";

/**
 * Generate a mundane forecast for a specific date.
 * Can be called manually from the app or admin panel.
 *
 * @param {Object} request.data
 * @param {string} [request.data.date] - "YYYY-MM-DD", defaults to today
 * @param {boolean} [request.data.skipLLM] - If true, returns rules-only output
 * @param {boolean} [request.data.includeRaw] - If true, includes raw effects
 */
export const generateMundaneForecast = onCall({
    timeoutSeconds: 120,
    memory: "512MiB",
    secrets: [geminiApiKey],
    region: "asia-southeast2",
    invoker: "public",
    enforceAppCheck: false,
}, async (request) => {
    const startMs = Date.now();
    const dateKey = request.data?.date || null;
    const skipLLM = request.data?.skipLLM || false;
    const includeRaw = request.data?.includeRaw || false;

    try {
        // Step 1: Build sky state from Firestore
        logger.info("🌍 Building sky state", { dateKey });
        const skyState = await buildSkyState(dateKey);

        // Step 2: Apply rules engine
        logger.info("🌍 Applying rules engine", { date: skyState.date });
        const analysis = applyAllRules(skyState);

        // Step 3: Synthesize (LLM or fallback)
        let forecast;
        if (skipLLM) {
            forecast = synthesizeFallback(analysis);
        } else {
            const apiKey = geminiApiKey.value();
            forecast = await synthesizeForecast(apiKey, analysis);
        }

        // Step 4: Store in Firestore
        const docRef = db.collection("mundane_forecasts").doc(skyState.date);
        const storeData = {
            ...forecast,
            generatedAt: FieldValue.serverTimestamp(),
            wallTimeMs: Date.now() - startMs,
        };

        if (includeRaw) {
            storeData.rawAnalysis = {
                totalEffects: analysis.totalEffects,
                domainScores: analysis.domainScores,
                conjunctions: analysis.conjunctions,
                nakshatraThemes: analysis.nakshatraThemes,
            };
        }

        await docRef.set(storeData);

        logger.info("🌍 Mundane forecast generated", {
            date: skyState.date,
            totalEffects: analysis.totalEffects,
            domains: analysis.domainScores.length,
            wallTimeMs: Date.now() - startMs,
            usedLLM: !skipLLM,
        });

        return {
            success: true,
            forecast,
            stats: {
                totalEffects: analysis.totalEffects,
                domains: analysis.domainScores.length,
                conjunctions: analysis.conjunctions.length,
                wallTimeMs: Date.now() - startMs,
            },
        };

    } catch (error) {
        logger.error("🌍 Mundane forecast failed", { error: String(error), dateKey });
        return {
            success: false,
            error: error.message,
        };
    }
});

/**
 * Get the latest mundane forecast from cache.
 * Fast read — no computation, just Firestore lookup.
 */
export const getMundaneForecast = onCall({
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast2",
    invoker: "public",
}, async (request) => {
    const dateKey = request.data?.date || new Date().toISOString().split("T")[0];

    try {
        const doc = await db.collection("mundane_forecasts").doc(dateKey).get();

        if (!doc.exists) {
            return { success: false, error: `No forecast for ${dateKey}`, forecast: null };
        }

        const data = doc.data();
        return {
            success: true,
            forecast: data,
            cached: true,
        };
    } catch (error) {
        logger.error("Error fetching mundane forecast", { error: String(error) });
        return { success: false, error: error.message, forecast: null };
    }
});

/**
 * Daily scheduled mundane forecast generation.
 * Runs at 3:30 AM UTC (after sky positions refresh at 2 AM).
 */
export const refreshMundaneDaily = onSchedule({
    schedule: "every day 03:30",
    timeZone: "UTC",
    timeoutSeconds: 180,
    memory: "512MiB",
    secrets: [geminiApiKey],
    region: "asia-southeast2",
}, async () => {
    logger.info("⏰ Scheduled mundane forecast starting");
    const startMs = Date.now();

    try {
        const skyState = await buildSkyState();
        const analysis = applyAllRules(skyState);

        let forecast;
        try {
            const apiKey = geminiApiKey.value();
            forecast = await synthesizeForecast(apiKey, analysis);
        } catch (llmError) {
            logger.warn("LLM synthesis failed, using fallback", { error: String(llmError) });
            forecast = synthesizeFallback(analysis);
        }

        await db.collection("mundane_forecasts").doc(skyState.date).set({
            ...forecast,
            generatedAt: FieldValue.serverTimestamp(),
            wallTimeMs: Date.now() - startMs,
            scheduled: true,
        });

        logger.info("⏰ Scheduled mundane forecast complete", {
            date: skyState.date,
            totalEffects: analysis.totalEffects,
            wallTimeMs: Date.now() - startMs,
        });

    } catch (error) {
        logger.error("⏰ Scheduled mundane forecast failed", { error: String(error) });
    }
});
