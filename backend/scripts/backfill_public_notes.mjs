#!/usr/bin/env node
/**
 * One-time backfill: force re-narration of specific users' forecasts so newly
 * added narration fields (e.g. the third-person `publicNote`) get written onto
 * forecast days that were narrated before those fields existed.
 *
 * WHY THIS EXISTS
 * ---------------
 * Deploying new narrate.js code does NOT retroactively re-narrate existing
 * forecasts. Normal (nightly) narration is gated by the story "runway"
 * (NARRATE_MIN_LEAD_DAYS = 7): a user is only re-narrated when their narrated
 * window is about to run out. So a user with a healthy multi-week forecast will
 * keep serving OLD documents (missing `publicNote`) for weeks. This script
 * forces an UNCONDITIONAL re-narration for the given uids.
 *
 * HOW IT WORKS
 * ------------
 * Enqueues a `process_narrate` task onto the deployed taskRouter queue. The
 * DEPLOYED worker runs narrateForecastForUser with its own Gemini env, so we
 * don't need any AI keys locally — just ADC to enqueue.
 *
 * Usage:
 *   node scripts/backfill_public_notes.mjs <uid> [<uid> ...]            # dry-run
 *   node scripts/backfill_public_notes.mjs --run <uid> [<uid> ...]      # enqueue
 *
 * Auth: uses Application Default Credentials (gcloud auth application-default login).
 */

import admin from "firebase-admin";
import { getFunctions } from "firebase-admin/functions";

const QUEUE_NAME = "locations/asia-southeast2/functions/taskRouter";

const args = process.argv.slice(2);
const RUN = args.includes("--run");
const uids = args.filter((a) => a !== "--run");

if (uids.length === 0) {
    console.error("Usage: node scripts/backfill_public_notes.mjs [--run] <uid> [<uid> ...]");
    process.exit(1);
}

if (!admin.apps.length) admin.initializeApp();

async function main() {
    console.log(`\n publicNote backfill (${RUN ? "LIVE — enqueuing" : "DRY RUN"})`);
    console.log(`   queue: ${QUEUE_NAME}`);
    console.log(`   targets (${uids.length}): ${uids.join(", ")}\n`);

    if (!RUN) {
        console.log("Dry run — pass --run to actually enqueue re-narration tasks.");
        return;
    }

    const queue = getFunctions().taskQueue(QUEUE_NAME);
    let enqueued = 0;
    for (const uid of uids) {
        try {
            await queue.enqueue({ taskType: "process_narrate", uid });
            enqueued++;
            console.log(`    enqueued narrate for ${uid}`);
        } catch (err) {
            console.error(`    failed for ${uid}: ${err.message}`);
        }
    }
    console.log(`\nDone. Enqueued ${enqueued}/${uids.length}. The deployed worker`);
    console.log("will narrate within ~seconds; re-check the forecast doc after.\n");
}

main().then(() => process.exit(0)).catch((e) => {
    console.error(e);
    process.exit(1);
});
