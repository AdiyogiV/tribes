/**
 * taskRouter — Unified Cloud Tasks worker for the two async jobs:
 *   1. processInsightTask   (was in insight_worker.js)
 *   2. processPerHouseTask  (was in per_house_scheduler.js)
 *
 * Why merge?
 *   - Each onTaskDispatched export is its own Cloud Run service consuming 1 vCPU
 *     baseline. Merging into one service saves vCPU of the regional quota.
 *   - The router uses a `taskType` discriminator in the payload to route to the
 *     correct handler.
 *
 * TASK PAYLOADS:
 *   taskType: "process_insight"    — { userId, astrologyData, date }
 *   taskType: "process_per_house"  — { uid }
 *
 * BACKWARD-COMPAT: if `taskType` is missing (in-flight task enqueued before this
 * code deployed), the router infers from shape — `astrologyData` => process_insight,
 * otherwise => process_per_house.
 */

import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { geminiApiKey, freeAstrologyApiKey } from "../lib/secrets.js";

// Lazy-loaded handler modules — only imported on first use of each task type.
// This keeps cold start fast for the most common task (card notifications,
// which doesn't need any of the AI/astrology heavy imports).
let _processInsightHandler = null;
let _processPerHouseHandler = null;

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
