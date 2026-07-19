/**
 * taskRouter — Unified Cloud Tasks worker for forecast narration and
 * per-house readings.
 *
 * Why merge?
 *   - Each onTaskDispatched export is its own Cloud Run service consuming 1 vCPU
 *     baseline. Merging into one service saves vCPU of the regional quota.
 *   - The router uses a `taskType` discriminator in the payload to route to the
 *     correct handler.
 *
 * TASK PAYLOADS:
 *   taskType: "process_per_house"  — { uid }
 *   taskType: "process_narrate"    — { uid }  (monthly forecast narration)
 */

import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { geminiApiKey, freeAstrologyApiKey } from "../lib/secrets.js";

// Lazy-loaded handler modules — only imported on first use of each task type.
// This keeps cold start fast for the most common task (card notifications,
// which doesn't need any of the AI/astrology heavy imports).
let _processPerHouseHandler = null;
let _processNarrateHandler = null;

async function getProcessPerHouseHandler() {
    if (!_processPerHouseHandler) {
        const mod = await import("./task_handlers/process_per_house_handler.js");
        _processPerHouseHandler = mod.handleProcessPerHouse;
    }
    return _processPerHouseHandler;
}

async function getProcessNarrateHandler() {
    if (!_processNarrateHandler) {
        const mod = await import("./task_handlers/process_narrate_handler.js");
        _processNarrateHandler = mod.handleProcessNarrate;
    }
    return _processNarrateHandler;
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
    // Backward compatibility for old per-house tasks without a discriminator.
    if (payload?.uid !== undefined) return "process_per_house";
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
    case "process_per_house": {
        const handler = await getProcessPerHouseHandler();
        return handler(payload, { db, FieldValue, logger });
    }
    case "process_narrate": {
        const handler = await getProcessNarrateHandler();
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
