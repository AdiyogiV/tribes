/**
 * unifiedOrchestrator — Single scheduled function replacing both
 * dailyOrchestrator and healthOrchestrator.
 *
 * Runs daily at 11:00 PM UTC (4:30 AM IST). Executes ALL nightly batch work
 * in dependency order across a single Cloud Run instance.
 *
 * Why merge?
 *   - Each onSchedule export creates a separate Cloud Run service that
 *     consumes 1 vCPU from the regional quota. The original two schedules
 *     ran 30 minutes apart but had no inter-dependency, so collapsing them
 *     into one execution saves a vCPU and avoids a second cold start.
 *   - Health work runs at the end (after user-insight enqueue) so the
 *     orchestrator's wall time is roughly daily-time + health-time. Both
 *     phases are independently bounded by their original task budgets.
 *
 * Phase 1: Cleanup (parallel — all independent)
 *   - cleanupTypingIndicators
 *   - cleanupTypingIndicators
 *   - cleanupOldDispatchEntries
 *   - cleanupExpiredCacheEntries
 *   - processPendingDeletions    (sweeps `deletedUsers` tombstones — replaces
 *                                 the former onUserDeleted v1 auth trigger)
 *   - Sunday only: cleanupOrphanedFeedEntries
 *
 * Phase 2: Data Refresh (sequential — Phase 3 needs this)
 *   - refreshSkyPositionsDaily (positions + panchang + muhurat, single source)
 *
 * Phase 3: (removed) Mundane/world content generation was archived —
 *   see backend/_archive/. Personal insights no longer depend on it.
 *
 * Phase 4: User Insights (sequential — depends on Phase 2)
 *   - generateDailyAstroInsights (enqueues per-user Cloud Tasks)
 *   - enqueuePerHouseReadings    (enqueues per-house Cloud Tasks)
 *
 * Phase 5: Health (independent — runs last)
 *   - nightlyHealthAnalysis      (always)
 *   - weeklyHealthAggregation    (Monday only)
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

// Phase 1: Cleanup runners
import { runCleanupTypingIndicators } from "../cleanup_typing.js";
import { runCleanupOldDispatchEntries, runCleanupExpiredCacheEntries } from "../maintenance.js";
import { runCleanupOrphanedFeedEntries } from "../feeds.js";
import { runProcessPendingDeletions } from "../user_deletion.js";
import { runRefreshUserMemories } from "../user_memory.js";

// Phase 2: Data refresh runners
import { runRefreshSkyPositionsDaily } from "../sky_positions.js";

// Phase 3 (mundane/world content) archived — see backend/_archive/.

// Phase 4: User insight runners
import { runGenerateDailyAstroInsights } from "../daily_astro_insights.js";
import { runEnqueuePerHouseReadings } from "../../insights/orchestration/per_house_scheduler.js";

// Phase 5: Health runners
import { runNightlyHealthAnalysis, runWeeklyHealthAggregation } from "../ayurveda.js";

/**
 * Run a named task with timing + error isolation.
 * Returns { name, ok, ms, error? }.
 */
async function runTask(name, fn) {
    const start = Date.now();
    try {
        await fn();
        const ms = Date.now() - start;
        logger.info(`✅ ${name}`, { ms });
        return { name, ok: true, ms };
    } catch (error) {
        const ms = Date.now() - start;
        logger.error(`❌ ${name} failed`, {
            ms,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        return { name, ok: false, ms, error: error.message };
    }
}

export const unifiedOrchestrator = onSchedule({
    schedule: "0 23 * * *", // 11:00 PM UTC = 4:30 AM IST
    timeZone: "UTC",
    timeoutSeconds: 1800, // 30 min ceiling (daily + health combined)
    memory: "1GiB", // max of the two original orchestrators
    region: "asia-southeast2",
    retryCount: 1,
}, async () => {
    const orchestratorStart = Date.now();
    const now = new Date();
    const dayOfWeek = now.getUTCDay(); // 0 = Sunday, 1 = Monday
    const dayOfMonth = now.getUTCDate();
    const results = [];

    logger.info("unifiedOrchestrator started", {
        dayOfWeek,
        dayOfMonth,
        isSunday: dayOfWeek === 0,
        isMonday: dayOfWeek === 1,
        isBimonthly: dayOfMonth === 1 || dayOfMonth === 15,
    });

    // ── Phase 1: Cleanup (parallel — all independent) ──────────────────
    logger.info("Phase 1: Cleanup");
    const cleanupTasks = [
        runTask("cleanupTypingIndicators", runCleanupTypingIndicators),
        runTask("cleanupOldDispatchEntries", runCleanupOldDispatchEntries),
        runTask("cleanupExpiredCacheEntries", runCleanupExpiredCacheEntries),
        runTask("processPendingDeletions", runProcessPendingDeletions),
    ];

    // Conditional cleanup tasks
    if (dayOfWeek === 0) {
        cleanupTasks.push(
            runTask("cleanupOrphanedFeedEntries (Sunday)", runCleanupOrphanedFeedEntries),
        );
    }

    results.push(...await Promise.all(cleanupTasks));

    // ── Phase 1b: User memory refresh (independent — reads dmConversations) ─
    // Refreshes durable per-user memory for anyone who chatted since the last
    // run, so tomorrow's sessions open with continuity instead of amnesia.
    logger.info("Phase 1b: User memory refresh");
    results.push(await runTask("refreshUserMemories", runRefreshUserMemories));

    // ── Phase 2: Data Refresh (sequential — Phase 3 needs this) ────────
    logger.info("Phase 2: Data Refresh");
    results.push(await runTask("refreshSkyPositionsDaily", runRefreshSkyPositionsDaily));

    // (muhurat is now part of the sky_positions smartPrefetch — single source)

    // ── Phase 3: (archived) mundane/world content generation ───────────
    // Removed — personal insights don't depend on it. See backend/_archive/.

    // ── Phase 4: User Insights (sequential — depends on Phase 2) ───────
    logger.info("Phase 4: User Insights");
    results.push(await runTask("generateDailyAstroInsights", runGenerateDailyAstroInsights));
    results.push(await runTask("enqueuePerHouseReadings", runEnqueuePerHouseReadings));

    // ── Phase 5: Health (independent — runs last) ─────────────────────
    logger.info("Phase 5: Health");
    results.push(await runTask("nightlyHealthAnalysis", runNightlyHealthAnalysis));
    if (dayOfWeek === 1) {
        results.push(await runTask("weeklyHealthAggregation (Monday)", runWeeklyHealthAggregation));
    }

    // ── Summary ────────────────────────────────────────────────────────
    const totalMs = Date.now() - orchestratorStart;
    const failed = results.filter((r) => !r.ok);
    const summary = {
        totalMs,
        tasksRun: results.length,
        succeeded: results.length - failed.length,
        failed: failed.length,
        failedTasks: failed.map((r) => r.name),
    };

    if (failed.length > 0) {
        logger.error("unifiedOrchestrator completed with failures", summary);
    } else {
        logger.info("unifiedOrchestrator completed successfully", summary);
    }
});
