import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
export { logger } from "firebase-functions";

// Global defaults for all Gen2 functions
//
// CRITICAL CPU/CONCURRENCY TUNING:
// - Without an explicit `cpu` value, Gen2 instances default to 1 full vCPU.
//   With 80+ functions in this project and Cloud Run starting 1 instance per
//   function during deploy health checks, the deploy burst alone exceeded the
//   20 vCPU regional quota — causing partial deploys, trigger-type mismatches,
//   and infinite delete/recreate loops.
// - Cloud Run links CPU and concurrency: cpu < 1 caps concurrency. cpu: 0.5
//   allows concurrency up to ~60. That's plenty for these low-traffic functions
//   (~100 users) while halving the per-instance CPU footprint.
// - 25 functions creating in parallel during deploy × 0.5 vCPU = 12.5 vCPU,
//   safely under the 20 vCPU quota.
// - Node.js handles async I/O concurrently, so concurrency=40 is more than
//   enough to avoid 429 "no available instance" errors that concurrency=1
//   previously caused.
setGlobalOptions({
    region: "asia-southeast2",
    timeoutSeconds: 60,
    memory: "256MiB",
    cpu: 0.5,
    concurrency: 40,
    // maxInstances: 3 × concurrency 40 = 120 concurrent requests — plenty for ~100 users.
    // Acts as a safety net against runaway scale-out (e.g., a retry loop).
    maxInstances: 3,
});

// Initialize Firebase Admin exactly once
initializeApp();

// Firestore instance with safe settings
const db = getFirestore();
db.settings({ ignoreUndefinedProperties: true });

export { db, FieldValue, getMessaging };


