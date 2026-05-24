import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
export { logger } from "firebase-functions";

// Global defaults for all Gen2 functions
//
// Every Cloud Function = 1 Cloud Run service = 1 vCPU (fractional CPU doesn't
// work in this project). Regional quota is 20 vCPU, so we must keep total
// function count ≤ 20.
//
// Current architecture (post-consolidation):
//   5 gateways + 1 orchestrator + ~11 merged triggers + 1 task worker
//   + aiChat ≈ 20 functions = 20 vCPU
//
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


