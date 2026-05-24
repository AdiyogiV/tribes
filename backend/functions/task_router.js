/**
 * taskRouter — Unified Cloud Tasks worker that replaces three separate workers:
 *   1. dispatchCardNotification (was in daily_astro_insights.js)
 *   2. processInsightTask        (was in insight_worker.js)
 *   3. processPerHouseTask       (was in per_house_scheduler.js)
 *
 * Why merge?
 *   - Each onTaskDispatched export is its own Cloud Run service consuming 1 vCPU
 *     baseline. Merging into one service saves 2 vCPU of the regional quota.
 *   - The router uses a `taskType` discriminator in the payload to route to the
 *     correct handler. All enqueue callsites are updated to add this field and
 *     to enqueue against the unified queue name.
 *
 * Settings are the max of all three original workers (per Cloud Tasks semantics
 * the rate-limit and concurrency settings apply to the function as a whole):
 *   - memory: 512MiB     (max of 256/512/512)
 *   - timeoutSeconds: 120 (max of 30/120/90)
 *   - maxConcurrentDispatches: 100 (max of 100/10/8)
 *   - maxDispatchesPerSecond: 10   (max of 10/2/2)
 *   - secrets: union [geminiApiKey, freeAstrologyApiKey] (card dispatch needs none,
 *     but loading them costs nothing and isn't observable from the worker)
 *
 * The autoscaler still keeps idle instances rare because the global
 * `concurrency: 40` setting from lib/firebase.js means a single instance can
 * accept up to 40 concurrent invocations before scale-out.
 *
 * TASK PAYLOADS:
 *   taskType: "dispatch_card_notification" — { userId, date, cardIndex, cardType, title, content, scheduledFor }
 *   taskType: "process_insight"            — { userId, astrologyData, date }
 *   taskType: "process_per_house"          — { uid }
 *
 * BACKWARD-COMPAT: if `taskType` is missing on a payload (e.g. an in-flight
 * task enqueued before this code was deployed), the router infers the type by
 * inspecting the shape — `cardIndex` field => card_notification, `astrologyData`
 * field => process_insight, otherwise => process_per_house. This lets us deploy
 * the router and the enqueue-site changes in two phases without dropping tasks.
 */

import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { geminiApiKey, freeAstrologyApiKey } from "../lib/secrets.js";

// Lazy-loaded handler modules — only imported on first use of each task type.
// This keeps cold start fast for the most common task (card notifications,
// which doesn't need any of the AI/astrology heavy imports).
let _dispatchCardHandler = null;
let _processInsightHandler = null;
let _processPerHouseHandler = null;

async function getDispatchCardHandler() {
    if (!_dispatchCardHandler) {
        const mod = await import("./task_handlers/dispatch_card_handler.js");
        _dispatchCardHandler = mod.handleDispatchCardNotification;
    }
    return _dispatchCardHandler;
}

async function getProcessInsightHandler() {
    if (!_processInsightHandler) {
        const mod = await import("./task_handlers/process_insight_handler.js");
        _processInsightHandler = mod.handleProcessInsight;
    }
    return _processInsightHandler;
}

async function getProcessPerHouseHandler() {
    if (!_processPerHouseHandler) {
        const mod = await import("./task_handlers/process_per_house_handler.js");
        _processPerHouseHandler = mod.handleProcessPerHouse;
    }
    return _processPerHouseHandler;
}

/**
 * Resolve the task type:
 *   - Prefer explicit `taskType` field set by the enqueuer.
 *   - Fall back to shape sniffing for backward-compat with in-flight tasks.
 */
function resolveTaskType(payload) {
    if (payload?.taskType && typeof payload.taskType === "string") {
        return payload.taskType;
    }
    // Inference rules (kept in priority order — most specific first):
    if (payload?.cardIndex !== undefined) return "dispatch_card_notification";
    if (payload?.astrologyData !== undefined) return "process_insight";
    if (payload?.uid !== undefined && payload?.userId === undefined) return "process_per_house";
    return null;
}

export const taskRouter = onTaskDispatched({
    retryConfig: {
        maxAttempts: 3,
        minBackoffSeconds: 30,
        maxBackoffSeconds: 300,
    },
    rateLimits: {
        maxConcurrentDispatches: 100,
        maxDispatchesPerSecond: 10,
    },
    region: "asia-southeast2",
    memory: "512MiB",
    timeoutSeconds: 120,
    secrets: [geminiApiKey, freeAstrologyApiKey],
}, async (req) => {
    const payload = req.data || {};
    const taskType = resolveTaskType(payload);

    if (!taskType) {
        logger.error("[TASK-ROUTER] Could not resolve taskType — payload shape unknown", {
            structuredData: true,
            payloadKeys: Object.keys(payload),
        });
        return; // do not retry — invalid payload
    }

    logger.info("[TASK-ROUTER] dispatching", {
        structuredData: true,
        taskType,
    });

    switch (taskType) {
    case "dispatch_card_notification": {
        const handler = await getDispatchCardHandler();
        return handler(payload, { db, FieldValue, logger });
    }
    case "process_insight": {
        const handler = await getProcessInsightHandler();
        return handler(payload, { db, FieldValue, logger });
    }
    case "process_per_house": {
        const handler = await getProcessPerHouseHandler();
        return handler(payload, { db, FieldValue, logger });
    }
    default:
        logger.error("[TASK-ROUTER] Unknown taskType", {
            structuredData: true,
            taskType,
        });
        return; // do not retry — unknown type
    }
});
