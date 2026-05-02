import crypto from "node:crypto";
import { db, FieldValue, logger } from "./firebase.js";

/**
 * EVENT-LEVEL idempotency.
 * Prevents the same Firestore event ID from being processed twice
 * (Cloud Functions delivers at-least-once and may redeliver on retry).
 *
 * Use this for handlers that perform external side effects
 * (FCM, email, Aura points, etc.) where double-execution is harmful.
 *
 * NOTE: this does NOT prevent infinite write-back loops, because each
 * loop iteration is a NEW event with a NEW event ID. For loop safety
 * use `loopGuard` or `withLoopGuard` below.
 */
export function withIdempotency(functionName, handler) {
    return async (event) => {
        try {
            const eventId = event.id || `${functionName}-${Date.now()}`;
            const key = `${functionName}-${eventId}`;
            const ref = db.collection("functionEvents").doc(key);
            // Use create to ensure atomic uniqueness
            await ref.create({ createdAt: FieldValue.serverTimestamp() });
        } catch (e) {
            // Already processed
            logger.info("Duplicate event skipped", { structuredData: true, functionName, error: String(e) });
            return null;
        }
        return handler(event);
    };
}

/**
 * Compute a deterministic SHA-1 hash of an arbitrary value, ignoring
 * Firestore Timestamp objects and undefined fields. Used to detect
 * whether a document's *meaningful* content has actually changed.
 */
export function contentHash(value) {
    const seen = new WeakSet();
    const normalize = (v) => {
        if (v === undefined || v === null) return null;
        if (typeof v !== "object") return v;
        // Skip Firestore Timestamp / Date (their values change every write)
        if (typeof v.toMillis === "function") return "__ts__";
        if (v instanceof Date) return "__date__";
        if (seen.has(v)) return "__cycle__";
        seen.add(v);
        if (Array.isArray(v)) return v.map(normalize);
        const out = {};
        for (const k of Object.keys(v).sort()) {
            const nv = normalize(v[k]);
            if (nv !== undefined) out[k] = nv;
        }
        return out;
    };
    const json = JSON.stringify(normalize(value));
    return crypto.createHash("sha1").update(json).digest("hex");
}

/**
 * LOOP guard for `onDocumentWritten` / `onDocumentUpdated` triggers
 * that need to write back to the trigger document (e.g. denormalizing
 * computed fields onto the source doc).
 *
 * Strategy:
 *   1. Hash the input fields the handler depends on (`inputSelector`).
 *   2. Look at the document's stored `_meta.<functionName>.inputHash`.
 *   3. If it matches, skip — we have already processed this version
 *      (this ALWAYS includes the case where the function's own
 *      write-back triggered us, because input fields haven't changed).
 *   4. Run the handler, which is responsible for writing the new
 *      result PLUS the new `_meta.<functionName>` block in the SAME
 *      .update() / .set() call (so we don't loop on the metadata write).
 *
 * Returns: { shouldSkip: boolean, inputHash: string, metaPatch: object }
 *
 * Usage:
 *   export const onFoo = onDocumentWritten("things/{id}", async (event) => {
 *       const after = event.data?.after?.data();
 *       if (!after) return;
 *       const guard = loopGuard("onFoo", after, (d) => ({
 *           sleep: d.sleepHours,
 *           hrv: d.hrv,
 *       }));
 *       if (guard.shouldSkip) return;
 *
 *       // ... compute result ...
 *
 *       await event.data.after.ref.update({
 *           "result.value": computed,
 *           ...guard.metaPatch,   // <-- IMPORTANT: write meta in same update
 *       });
 *   });
 */
export function loopGuard(functionName, afterData, inputSelector) {
    const input = inputSelector(afterData) ?? {};
    const inputHash = contentHash(input);
    const storedHash = afterData?._meta?.[functionName]?.inputHash;
    const shouldSkip = storedHash === inputHash;

    return {
        shouldSkip,
        inputHash,
        metaPatch: {
            [`_meta.${functionName}.inputHash`]: inputHash,
            [`_meta.${functionName}.processedAt`]: FieldValue.serverTimestamp(),
        },
    };
}

/**
 * Higher-order wrapper combining event-level dedup AND loop guard.
 * Use when the handler writes back to its own trigger document.
 *
 * The `inputSelector` MUST return only the fields the handler actually
 * reads from the document. Don't include fields the handler writes,
 * or fields with server timestamps.
 *
 * The wrapped handler receives `(event, ctx)` where
 *   ctx = { metaPatch, inputHash, after }
 * and is responsible for spreading `ctx.metaPatch` into its update
 * call so subsequent invocations can detect the no-op.
 */
export function withLoopGuard(functionName, inputSelector, handler) {
    return withIdempotency(functionName, async (event) => {
        const after = event.data?.after?.data();
        if (!after) return; // doc deleted — nothing to guard

        const guard = loopGuard(functionName, after, inputSelector);
        if (guard.shouldSkip) {
            logger.debug("loopGuard: skipping no-op invocation", {
                structuredData: true,
                functionName,
                docPath: event.data?.after?.ref?.path,
                inputHash: guard.inputHash,
            });
            return null;
        }
        return handler(event, {
            metaPatch: guard.metaPatch,
            inputHash: guard.inputHash,
            after,
        });
    });
}
