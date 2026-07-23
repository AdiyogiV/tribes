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
 *   node scripts/backfill_public_notes.mjs --all                         # dry-run all
 *   node scripts/backfill_public_notes.mjs --run --all                   # enqueue all
 *
 * Auth: uses Application Default Credentials (gcloud auth application-default login).
 */

import admin from "firebase-admin";
import { getFunctions } from "firebase-admin/functions";

const QUEUE_NAME = "locations/asia-southeast2/functions/taskRouter";
const ENQUEUE_BATCH_SIZE = 500;

const args = process.argv.slice(2);
const RUN = args.includes("--run");
const ALL = args.includes("--all");
const uids = args.filter((a) => a !== "--run" && a !== "--all");

if (!ALL && uids.length === 0) {
    console.error("Usage: node scripts/backfill_public_notes.mjs [--run] [--all] <uid> [<uid> ...]");
    process.exit(1);
}

if (!admin.apps.length) admin.initializeApp();

async function getAllAstrologyUids() {
    const usersSnap = await admin.firestore()
        .collection("users")
        .where("astrologyData", "!=", null)
        .get();
    return usersSnap.docs.map((doc) => doc.id);
}

async function main() {
    const targetUids = ALL ? await getAllAstrologyUids() : uids;
    console.log(`\n publicNote backfill (${RUN ? "LIVE — enqueuing" : "DRY RUN"})`);
    console.log(`   queue: ${QUEUE_NAME}`);
    console.log(`   mode: ${ALL ? "ALL users with astrologyData" : "explicit uids"}`);
    if (!ALL) console.log(`   targets (${targetUids.length}): ${targetUids.join(", ")}`);
    else console.log(`   targets discovered: ${targetUids.length}`);
    console.log("");

    if (!RUN) {
        console.log("Dry run — pass --run to actually enqueue re-narration tasks.");
        return;
    }

    const queue = getFunctions().taskQueue(QUEUE_NAME);
    let enqueued = 0;
    for (let i = 0; i < targetUids.length; i++) {
        const uid = targetUids[i];
        try {
            await queue.enqueue({ taskType: "process_narrate", uid });
            enqueued++;
            console.log(`    enqueued narrate for ${uid} (${i + 1}/${targetUids.length})`);
        } catch (err) {
            console.error(`    failed for ${uid}: ${err.message}`);
        }
        if ((i + 1) % ENQUEUE_BATCH_SIZE === 0) {
            console.log(`    progress: ${i + 1}/${targetUids.length}`);
        }
    }
    console.log(`\nDone. Enqueued ${enqueued}/${targetUids.length}. The deployed worker`);
    console.log("will narrate within ~seconds; re-check the forecast doc after.\n");
}

main().then(() => process.exit(0)).catch((e) => {
    console.error(e);
    process.exit(1);
});
