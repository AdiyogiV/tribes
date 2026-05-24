/**
 * Handler for `process_per_house` task type.
 *
 * Originally `processPerHouseTask` in insights/orchestration/per_house_scheduler.js.
 * Runs the per-house flavor of the insight engine for one user.
 *
 * Payload: { uid }
 */

import { runFlavor } from "../../insights/engine/insight_engine.js";
import {
    perHouseFlavor,
    computeCycleWindow,
} from "../../insights/flavors/per_house.js";

export async function handleProcessPerHouse(payload, ctx) {
    const { uid } = payload || {};
    const { logger } = ctx;

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
}
