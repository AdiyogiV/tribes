/**
 * यन्त्र — अग्नि कार्य (Agni Karya: Cloud Functions)
 *
 * Firebase Cloud Functions for the Brihat Samhita mundane astrology system.
 *
 * Two endpoints:
 * 1. generateMundaneForecast (onCall) — manual trigger, returns full forecast
 * 2. getMundaneForecast (onCall) — fast cache read
 * 3. refreshMundanePanchanga (onSchedule) — Panchanga-aware cron
 *
 * WIRED TO EXISTING BACKEND:
 * Uses performReading() from samhita.js which handles:
 * - Real positions from Firestore (global_astro/sky_positions)
 * - News (Nimitta) observed BEFORE predictions via lib/news_feed.js
 * - Memory recall/store via lib/agent_memory.js
 * - Confidence tracking via Firestore mundane_confidence collection
 * - Prediction storage via lib/signal_store.js
 */

import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { db, FieldValue } from "../../lib/firebase.js";
import { geminiApiKey } from "../../lib/secrets.js";
import { performReading } from "../samhita.js";
import { getPurnimaAmavasyaDates } from "../kriya/kaal_nirnaya.js";

/**
 * Generate a mundane forecast for a specific date.
 * Now uses the full Varahamihira pipeline:
 *   News (Nimitta) → Sky → Rules (with Nimitta boost) → Memory → Synthesis → Store
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
    const validate = request.data?.validate || false;

    try {
        const apiKey = skipLLM ? null : geminiApiKey.value();

        // Full Varahamihira reading pipeline
        const reading = await performReading({
            date: dateKey,
            geminiApiKey: apiKey,
            validate,
            learn: validate, // If validating, also learn
            skipNews: false, // Always observe the world
        });

        // Store in Firestore
        const storeData = {
            ...reading.forecast,
            steps: reading.steps,
            generatedAt: FieldValue.serverTimestamp(),
            wallTimeMs: Date.now() - startMs,
        };

        if (includeRaw && reading.analysis) {
            storeData.rawAnalysis = {
                totalEffects: reading.analysis.totalEffects,
                domainScores: reading.analysis.domainScores,
                conjunctions: reading.analysis.conjunctions,
                nakshatraThemes: reading.analysis.nakshatraThemes,
                domainHeatApplied: reading.analysis.domainHeatApplied,
            };
        }

        await db.collection("mundane_forecasts").doc(reading.date).set(storeData);

        logger.info("🌍 Mundane forecast generated", {
            date: reading.date,
            totalEffects: reading.analysis?.totalEffects,
            nimittaHeadlines: reading.steps.nimittaAvalokan?.headlineCount || 0,
            nimittaBoosted: reading.steps.phalaGanana?.nimittaBoosted,
            wallTimeMs: Date.now() - startMs,
            usedLLM: !skipLLM,
        });

        return {
            success: true,
            forecast: reading.forecast,
            steps: reading.steps,
            stats: {
                totalEffects: reading.analysis?.totalEffects,
                domains: reading.analysis?.domainScores?.length,
                conjunctions: reading.analysis?.conjunctions?.length,
                nimittaHeadlines: reading.steps.nimittaAvalokan?.headlineCount || 0,
                wallTimeMs: Date.now() - startMs,
            },
        };

    } catch (error) {
        logger.error("🌍 Mundane forecast failed", { error: String(error), dateKey });
        return { success: false, error: error.message };
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

        return { success: true, forecast: doc.data(), cached: true };
    } catch (error) {
        logger.error("Error fetching mundane forecast", { error: String(error) });
        return { success: false, error: error.message, forecast: null };
    }
});

/**
 * Panchanga-aware scheduled mundane forecast generation.
 *
 * Runs daily at 3:30 AM UTC but ONLY generates a forecast on
 * Panchanga trigger dates (Purnima, Amavasya, or ±1 day).
 * ~26 forecasts/year, following Varahamihira's principle.
 *
 * Now uses the FULL pipeline: News → Sky → Rules (Nimitta boost) →
 * Memory → Synthesis → Store → Learn
 */
export const refreshMundanePanchanga = onSchedule({
    schedule: "every day 03:30",
    timeZone: "UTC",
    timeoutSeconds: 180,
    memory: "512MiB",
    secrets: [geminiApiKey],
    region: "asia-southeast2",
}, async () => {
    const today = new Date().toISOString().split("T")[0];

    // Check if today is a Panchanga trigger (±1 day tolerance)
    const windowStart = new Date();
    windowStart.setDate(windowStart.getDate() - 1);
    const windowEnd = new Date();
    windowEnd.setDate(windowEnd.getDate() + 1);
    const triggers = getPurnimaAmavasyaDates(
        windowStart.toISOString().split("T")[0],
        windowEnd.toISOString().split("T")[0],
    );

    if (triggers.length === 0) {
        logger.info("🌙 No Panchanga trigger today — skipping", { today });
        return;
    }

    const trigger = triggers[0];
    logger.info("🌙 Panchanga trigger active — generating full reading", {
        today, trigger: trigger.type, triggerDate: trigger.date,
    });

    const startMs = Date.now();

    try {
        const apiKey = geminiApiKey.value();

        // Full Varahamihira pipeline with validation and learning
        const reading = await performReading({
            geminiApiKey: apiKey,
            validate: true,  // Validate against news
            learn: true,     // Update confidence from validation
            skipNews: false,  // Always observe the world
        });

        // Tag with Panchanga metadata
        reading.forecast._panchanga = {
            triggerType: trigger.type,
            triggerDate: trigger.date,
            triggerLabel: trigger.label,
        };

        await db.collection("mundane_forecasts").doc(reading.date).set({
            ...reading.forecast,
            steps: reading.steps,
            generatedAt: FieldValue.serverTimestamp(),
            wallTimeMs: Date.now() - startMs,
            scheduled: true,
            panchangaTrigger: trigger.type,
        });

        logger.info("🌙 Panchanga mundane forecast complete", {
            date: reading.date,
            trigger: trigger.type,
            totalEffects: reading.analysis?.totalEffects,
            nimittaHeadlines: reading.steps.nimittaAvalokan?.headlineCount || 0,
            memoriesRecalled: reading.steps.smritiRecall?.memoriesFound || 0,
            confidenceUpdates: reading.steps.smritiLearn?.updatesApplied || 0,
            wallTimeMs: Date.now() - startMs,
        });

    } catch (error) {
        logger.error("🌙 Panchanga mundane forecast failed", { error: String(error) });
    }
});
