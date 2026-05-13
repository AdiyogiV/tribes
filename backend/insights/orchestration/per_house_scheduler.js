/**
 * per_house orchestration — scheduler + worker + manual callable.
 *
 * Three exports:
 *   1. enqueuePerHouseReadings  — daily scheduler; finds users whose cycle
 *      has expired and enqueues regeneration tasks.
 *   2. processPerHouseTask      — Cloud Tasks worker; runs the flavor for
 *      one user.
 *   3. generatePerHouseNow      — onCall callable; force regenerate for
 *      the calling user (used on first sync + manual refresh).
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFunctions } from "firebase-admin/functions";
import { DateTime } from "luxon";
import { db, logger } from "../../lib/firebase.js";
import { geminiApiKey, freeAstrologyApiKey } from "../../lib/secrets.js";
import { requireAuth } from "../../lib/auth_utils.js";
import { runFlavor } from "../engine/insight_engine.js";
import {
    perHouseFlavor,
    computeCycleWindow,
    needsRegeneration,
    PER_HOUSE_CYCLE_DAYS,
} from "../flavors/per_house.js";

const QUEUE_NAME =
    "locations/asia-southeast2/functions/processPerHouseTask";
const ENQUEUE_WINDOW_SECONDS = 3600; // spread across 1h
const REGION = "asia-southeast2";

// Test-mode safety cap. Set PER_HOUSE_MAX_USERS=N as a function env var to limit
// how many users get enqueued in a single scheduler run. 0 (or unset) = no cap.
// Use this when validating a fresh deploy to avoid blasting all users with AI calls.
const MAX_USERS_PER_RUN = parseInt(process.env.PER_HOUSE_MAX_USERS || "0", 10);

// Optional UID allowlist — comma-separated UIDs. If set, ONLY these users get enqueued.
// Use for surgical test runs against a known account.
const TEST_UID_ALLOWLIST = (process.env.PER_HOUSE_TEST_UIDS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

// ---------------------------------------------------------------------------
// 1. Scheduler — runs daily, enqueues users whose cycle expired
// ---------------------------------------------------------------------------

export const enqueuePerHouseReadings = onSchedule({
    schedule: "30 5 * * *", // 5:30 AM IST, after the daily insight enqueue
    region: REGION,
    timeZone: "Asia/Kolkata",
    memory: "512MiB",
    timeoutSeconds: 540,
}, async () => {
    const today = DateTime.now().setZone("Asia/Kolkata");
    logger.info("🏠 Per-house enqueue starting", {
        structuredData: true,
        date: today.toFormat("yyyy-MM-dd"),
    });

    let scanned = 0;
    let enqueued = 0;
    let skippedFresh = 0;
    let skippedNoData = 0;
    let enqueueFailed = 0;

    try {
        const usersSnap = await db.collection("users")
            .where("astrologyData", "!=", null)
            .get();

        const queue = getFunctions().taskQueue(QUEUE_NAME);
        const candidates = [];

        usersSnap.forEach((doc) => {
            scanned++;
            if (TEST_UID_ALLOWLIST.length && !TEST_UID_ALLOWLIST.includes(doc.id)) {
                return; // not in test allowlist, silently skip
            }
            const astro = doc.data().astrologyData;
            if (!astro?.ascendant && !astro?.lagna) {
                skippedNoData++;
                return;
            }
            if (!needsRegeneration(astro.skyHouseReadings, today)) {
                skippedFresh++;
                return;
            }
            candidates.push(doc.id);
        });

        // Apply safety cap if configured.
        if (MAX_USERS_PER_RUN > 0 && candidates.length > MAX_USERS_PER_RUN) {
            logger.info("[per_house] safety cap applied", {
                structuredData: true,
                originalCount: candidates.length,
                cappedTo: MAX_USERS_PER_RUN,
            });
            candidates.length = MAX_USERS_PER_RUN;
        }

        const total = candidates.length;
        for (let i = 0; i < total; i++) {
            const uid = candidates[i];
            const delaySeconds = total > 0
                ? Math.floor((i / total) * ENQUEUE_WINDOW_SECONDS)
                : 0;
            try {
                await queue.enqueue(
                    { uid, scheduledFor: today.toISO() },
                    { scheduleDelaySeconds: delaySeconds },
                );
                enqueued++;
            } catch (e) {
                enqueueFailed++;
                logger.warn("[per_house] enqueue failed", {
                    structuredData: true,
                    uid,
                    error: String(e?.message || e),
                });
            }
        }

        logger.info("✅ Per-house enqueue complete", {
            structuredData: true,
            scanned,
            enqueued,
            skippedFresh,
            skippedNoData,
            enqueueFailed,
            cycleDays: PER_HOUSE_CYCLE_DAYS,
        });

        return { scanned, enqueued, skippedFresh, skippedNoData, enqueueFailed };
    } catch (error) {
        logger.error("❌ Per-house enqueue failed", {
            structuredData: true,
            error: String(error?.message || error),
            stack: error?.stack?.substring(0, 500),
        });
        throw error;
    }
});

// ---------------------------------------------------------------------------
// 2. Worker — runs the flavor for a single user
// ---------------------------------------------------------------------------

export const processPerHouseTask = onTaskDispatched({
    retryConfig: {
        maxAttempts: 3,
        minBackoffSeconds: 30,
        maxBackoffSeconds: 300,
    },
    rateLimits: {
        maxConcurrentDispatches: 8,
        maxDispatchesPerSecond: 2,
    },
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 90,
    secrets: [geminiApiKey, freeAstrologyApiKey],
}, async (req) => {
    const { uid } = req.data || {};
    if (!uid) {
        logger.error("[per_house-worker] missing uid", { structuredData: true });
        return; // don't retry
    }

    const window = computeCycleWindow();
    logger.info("[per_house-worker] processing", {
        structuredData: true,
        uid,
        cycleStart: window.cycleStart,
        cycleEnd: window.cycleEnd,
    });

    try {
        const { result, latencyMs } = await runFlavor(perHouseFlavor, {
            uid,
            ...window,
        });
        logger.info("[per_house-worker] done", {
            structuredData: true,
            uid,
            latencyMs,
            houseCount: Object.keys(result?.houses || {}).length,
        });
    } catch (error) {
        logger.error("[per_house-worker] failed", {
            structuredData: true,
            uid,
            error: String(error?.message || error),
            stack: error?.stack?.substring(0, 500),
        });
        throw error; // trigger Cloud Tasks retry
    }
});

// ---------------------------------------------------------------------------
// 3. Manual callable — used on first sync or for force-refresh from app
// ---------------------------------------------------------------------------

export const generatePerHouseNow = onCall({
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 90,
    secrets: [geminiApiKey, freeAstrologyApiKey],
    invoker: "public",
}, async (request) => {
    // Wrap EVERYTHING so no exception ever escapes as bare INTERNAL.
    // Each stage logs its name on entry; on failure we re-throw an HttpsError
    // whose message tells us exactly which stage and why.
    let stage = "init";
    let uid = null;
    try {
        stage = "requireAuth";
        uid = requireAuth(request, "generate per-house readings");
        const force = !!request.data?.force;
        logger.info("[per_house-callable] entered", {
            structuredData: true,
            uid,
            force,
        });

        stage = "loadUser";
        const userSnap = await db.collection("users").doc(uid).get();
        if (!userSnap.exists) {
            throw new HttpsError("not-found", "User not found");
        }
        const astro = userSnap.data().astrologyData;
        if (!astro?.ascendant && !astro?.lagna) {
            throw new HttpsError(
                "failed-precondition",
                "Astrology data not ready yet",
            );
        }

        stage = "checkFreshness";
        if (!force && !needsRegeneration(astro.skyHouseReadings)) {
            return {
                success: true,
                alreadyFresh: true,
                cycleEndDate: astro.skyHouseReadings.cycleEndDate,
                houses: astro.skyHouseReadings.houses,
            };
        }

        stage = "runFlavor";
        const window = computeCycleWindow();
        const { result, latencyMs } = await runFlavor(
            perHouseFlavor,
            { uid, ...window },
            { bypassCache: true },
        );

        stage = "return";
        return {
            success: true,
            alreadyFresh: false,
            cycleStartDate: window.cycleStart,
            cycleEndDate: window.cycleEnd,
            houses: result.houses,
            latencyMs,
        };
    } catch (error) {
        // If it's already an HttpsError, just rebrand the message with stage.
        if (error instanceof HttpsError) {
            logger.error("[per_house-callable] HttpsError thrown", {
                structuredData: true,
                uid,
                stage,
                code: error.code,
                message: error.message,
            });
            throw new HttpsError(
                error.code,
                `[stage=${stage}] ${error.message}`,
                error.details,
            );
        }
        // Anything else: log full detail, re-throw as informative HttpsError.
        const message = String(error?.message || error || "unknown error");
        const stack = error?.stack?.substring(0, 800) || "no stack";
        logger.error("[per_house-callable] uncaught exception", {
            structuredData: true,
            uid,
            stage,
            message,
            stack,
            errorName: error?.name,
            errorConstructor: error?.constructor?.name,
        });
        throw new HttpsError(
            "internal",
            `[stage=${stage}] ${message}`,
            { stage, errorName: error?.name },
        );
    }
});
