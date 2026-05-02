#!/usr/bin/env node
/**
 * Dev Seed Script — aurogram-dev
 *
 * Writes synthetic test data into the DEV Firestore to exercise backend
 * Cloud Functions without touching real users.
 *
 * ⚠️  NEVER run against prod. This script uses FIREBASE_PROJECT env var
 *     and will refuse to run if it detects the prod project ID.
 *
 * Prerequisites:
 *   1. Deploy functions to dev: ./deploy.sh dev
 *   2. Generate a dev service account key from the GCP console
 *      (aurogram-dev → IAM → Service Accounts → firebase-adminsdk → Keys)
 *      and save it as backend/serviceAccountKey.dev.json (gitignored)
 *   3. Run: GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.dev.json node scripts/seed-dev.js
 *
 *      OR point at the emulator:
 *      FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed-dev.js --emulator
 *
 * Usage:
 *   node scripts/seed-dev.js                     # seed all collections
 *   node scripts/seed-dev.js --user              # seed one synthetic user
 *   node scripts/seed-dev.js --health            # write a healthSnapshot (triggers onHealthSnapshotWrite)
 *   node scripts/seed-dev.js --post              # write a post (triggers addPostToFeeds etc.)
 *   node scripts/seed-dev.js --cleanup           # delete all synthetic data
 */

import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { readFileSync, existsSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── Safety guard ──────────────────────────────────────────────────────────────

const PROD_PROJECT_ID = "ty-dev-516d7";
const DEV_PROJECT_ID  = "aurogram-dev";
const EMULATOR        = process.argv.includes("--emulator");

function initAdmin() {
    if (getApps().length > 0) return getApps()[0];

    if (EMULATOR) {
        process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
        return initializeApp({ projectId: DEV_PROJECT_ID });
    }

    // Look for dev service account key
    const keyPath = join(__dirname, "..", "serviceAccountKey.dev.json");
    if (!existsSync(keyPath)) {
        console.error(`
❌  Dev service account key not found at: backend/serviceAccountKey.dev.json

    How to get it:
    1. Open https://console.firebase.google.com/project/aurogram-dev
    2. Project Settings → Service Accounts → Generate new private key
    3. Save as: backend/serviceAccountKey.dev.json
       (It is gitignored — never commit it)

    Or use the emulator (no key needed):
       FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed-dev.js --emulator
`);
        process.exit(1);
    }

    const key = JSON.parse(readFileSync(keyPath, "utf8"));

    // Prod safety check
    if (key.project_id === PROD_PROJECT_ID) {
        console.error(`\n❌  REFUSING: serviceAccountKey.dev.json belongs to the PROD project!\n    Use the aurogram-dev service account key.\n`);
        process.exit(1);
    }

    console.log(`✓ Using project: ${key.project_id}`);
    return initializeApp({ credential: cert(key) });
}

initAdmin();
const db = getFirestore();

// ── Synthetic data helpers ────────────────────────────────────────────────────

const DEV_USER_ID   = "dev-test-user-001";
const DEV_DAY_KEY   = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

async function seedUser() {
    const ref = db.collection("users").doc(DEV_USER_ID);
    await ref.set({
        uid: DEV_USER_ID,
        displayName: "Dev Test User",
        username: "devtest",
        email: "devtest@aurogram.dev",
        createdAt: FieldValue.serverTimestamp(),
        ayurvedaData: {
            prakriti: { vata: 40, pitta: 35, kapha: 25 },
        },
        _synthetic: true, // marker so cleanup can find this doc
    }, { merge: true });
    console.log(`✓ Seeded user: users/${DEV_USER_ID}`);
}

async function seedHealthSnapshot() {
    // This write triggers onHealthSnapshotWrite on the dev project.
    // Watch the function logs to verify it handles it correctly.
    const ref = db
        .collection("users").doc(DEV_USER_ID)
        .collection("healthSnapshots").doc(DEV_DAY_KEY);

    await ref.set({
        dayKey: DEV_DAY_KEY,
        hrv: 55,
        restingHR: 68,
        sleepHours: 7.5,
        ojasScore: 72,
        recordedAt: FieldValue.serverTimestamp(),
        _synthetic: true,
    });
    console.log(`✓ Wrote healthSnapshot: users/${DEV_USER_ID}/healthSnapshots/${DEV_DAY_KEY}`);
    console.log(`  → Watch for onHealthSnapshotWrite trigger in dev function logs`);
    console.log(`  → firebase functions:log --project dev`);
}

async function seedPost() {
    const ref = db.collection("posts").doc();
    await ref.set({
        authorId: DEV_USER_ID,
        content: "Dev seed test post",
        createdAt: FieldValue.serverTimestamp(),
        visibility: "public",
        _synthetic: true,
    });
    console.log(`✓ Wrote post: posts/${ref.id}`);
    console.log(`  → Watch for newPost / addPostToFeeds triggers`);
}

async function cleanup() {
    console.log("Cleaning up synthetic data...");

    // healthSnapshots
    const snaps = await db
        .collection("users").doc(DEV_USER_ID)
        .collection("healthSnapshots")
        .where("_synthetic", "==", true)
        .get();
    for (const d of snaps.docs) { await d.ref.delete(); }
    console.log(`  Deleted ${snaps.size} healthSnapshot(s)`);

    // posts
    const posts = await db.collection("posts").where("_synthetic", "==", true).get();
    for (const d of posts.docs) { await d.ref.delete(); }
    console.log(`  Deleted ${posts.size} post(s)`);

    // user
    const userRef = db.collection("users").doc(DEV_USER_ID);
    const user = await userRef.get();
    if (user.exists && user.data()?._synthetic) {
        await userRef.delete();
        console.log(`  Deleted user ${DEV_USER_ID}`);
    }

    console.log("✓ Cleanup complete");
}

// ── Entry point ───────────────────────────────────────────────────────────────

const args = process.argv.slice(2).filter(a => !a.startsWith("--emulator"));

async function main() {
    if (args.includes("--cleanup")) {
        await cleanup();
        return;
    }

    if (args.length === 0 || args.includes("--user") || !args.some(a => a !== "--user")) {
        await seedUser();
    }
    if (args.length === 0 || args.includes("--health")) {
        if (!args.includes("--user")) await seedUser(); // ensure user exists
        await seedHealthSnapshot();
    }
    if (args.includes("--post")) {
        if (!args.includes("--user")) await seedUser();
        await seedPost();
    }

    console.log("\nDone. Monitor function activity:");
    console.log("  firebase functions:log --project dev --only onHealthSnapshotWrite");
}

main().catch(err => { console.error(err); process.exit(1); });
