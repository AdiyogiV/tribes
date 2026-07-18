/**
 * Handler for `process_narrate` task type.
 *
 * Runs the one-Gemini-call monthly forecast narration for a single user.
 * Payload: { uid }
 */

import { narrateForecastForUser } from "../forecast/narrate.js";

export async function handleProcessNarrate(payload, ctx) {
    const { uid } = payload || {};
    const { logger } = ctx;

    if (!uid) {
        logger.error("[narrate-worker] missing uid", { structuredData: true });
        return; // don't retry
    }

    try {
        const res = await narrateForecastForUser(uid);
        logger.info("[narrate-worker] done", { structuredData: true, uid, ...res });
    } catch (error) {
        logger.error("[narrate-worker] failed", {
            structuredData: true,
            uid,
            error: String(error?.message || error),
            stack: error?.stack?.substring(0, 500),
        });
        throw error; // trigger Cloud Tasks retry
    }
}
