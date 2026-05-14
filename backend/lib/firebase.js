import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
export { logger } from "firebase-functions";

// Global defaults for all Gen2 functions
// NOTE: concurrency=80 is critical — Node.js handles async I/O concurrently.
// concurrency=1 caused 429 "no available instance" errors because each instance
// could only serve 1 request at a time, and with minInstances=0, instances scaled
// down immediately, forcing cold starts.
// Also: concurrency=80 enables fractional vCPU per function (~0.083 vCPU each),
// keeping total CPU usage well under quota. concurrency=1 forces 1 full vCPU per
// function — at 80+ functions this blows past the 20 vCPU quota.
setGlobalOptions({
    region: "asia-southeast2",
    timeoutSeconds: 60,
    memory: "256MiB",
    concurrency: 80,
    // maxInstances: 3 × concurrency 80 = 240 concurrent requests — plenty for ~100 users.
    // Acts as a safety net against runaway scale-out (e.g., a retry loop).
    maxInstances: 3,
});

// Initialize Firebase Admin exactly once
initializeApp();

// Firestore instance with safe settings
const db = getFirestore();
db.settings({ ignoreUndefinedProperties: true });

export { db, FieldValue, getMessaging };


