import { db, FieldValue, logger } from "./firebase.js";

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


