/**
 * Handler for `process_per_house` task type.
 *
 * Generates one user's per-house readings for the current cycle.
 * Payload: { uid }
 */

import { generatePerHouse, computeCycleWindow } from "../per_house.js";

export async function handleProcessPerHouse(payload, ctx) {
    const { uid } = payload || {};
    const { logger } = ctx;

    if (!uid) {
        logger.error("[per_house-worker] missing uid", { structuredData: true });
        return; // don't retry
    }

    const { cycleStart, cycleEnd } = computeCycleWindow();
    logger.info("[per_house-worker] processing", {
        structuredData: true, uid, cycleStart, cycleEnd,
    });

    try {
        const { houses, latencyMs } = await generatePerHouse(uid, cycleStart, cycleEnd);
        logger.info("[per_house-worker] done", {
            structuredData: true,
            uid,
            latencyMs,
            houseCount: Object.keys(houses || {}).length,
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
