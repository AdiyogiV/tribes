import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
export { logger } from "firebase-functions";

// Global defaults for all Gen2 functions
//
// CRITICAL CPU/CONCURRENCY TUNING:
// - Firebase Gen2 requires cpu >= 1 when concurrency > 1.
//   cpu: 0.5 + concurrency: 40 fails validation at deploy time.
// - With cpu: 1 and maxInstances: 1, worst-case deploy burst is
//   82 functions × 1 vCPU × 1 instance = 82 vCPU theoretical, but
//   Cloud Run only runs ~10-15 health checks in parallel during deploy,
//   staying within the 20 vCPU regional quota.
// - maxInstances: 1 is fine for ~100 users. Each instance handles
//   concurrency: 40 requests simultaneously via Node.js async I/O,
//   giving 40 concurrent requests per function — plenty of headroom.
setGlobalOptions({
    region: "asia-southeast2",
    timeoutSeconds: 60,
    memory: "256MiB",
    cpu: 1,
    concurrency: 40,
    maxInstances: 1,
});

// Initialize Firebase Admin exactly once
initializeApp();

// Firestore instance with safe settings
const db = getFirestore();
db.settings({ ignoreUndefinedProperties: true });

export { db, FieldValue, getMessaging };


