/**
 * commsGateway — Single Cloud Run service for communication-related onCall methods.
 *
 * Consolidates 3 separate functions into 1, reducing deploy footprint.
 *
 * Flutter calls:  functions.httpsCallable('commsGateway').call({ method: '...', ...data })
 *
 * Methods:
 *   - getLinkPreview        [public]   Fetch URL metadata for link previews
 *   - getChatPromptConfig   [public]   Get AI chat system prompt config
 *   - generateAgoraToken    [auth]     Generate Agora RTC token for calls
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { agoraAppCertificate } from "../lib/secrets.js";

// Import handlers
import { handleGetLinkPreview } from "../functions/link_preview.js";
import { handleGetChatPromptConfig } from "../functions/ai.js";
import { handleGenerateAgoraToken } from "../functions/agora_token.js";

// Method registry — maps method name to handler + auth requirement
const methods = {
    // Public methods (no auth required)
    getLinkPreview: { handler: (req) => handleGetLinkPreview(req), auth: false },
    getChatPromptConfig: { handler: (req) => handleGetChatPromptConfig(req), auth: false },

    // Auth-required methods
    generateAgoraToken: { handler: (req) => handleGenerateAgoraToken(req), auth: true },
};

export const commsGateway = onCall({
    secrets: [agoraAppCertificate],
    timeoutSeconds: 30, // max of all methods
    memory: "256MiB", // max of all methods
    region: "asia-southeast2",
    invoker: "public",
    cpu: 1,
    concurrency: 40,
    maxInstances: 2,
}, async (request) => {
    const { method, ...data } = request.data || {};

    if (!method || typeof method !== "string") {
        throw new HttpsError(
            "invalid-argument",
            "Missing required 'method' field. Expected one of: " + Object.keys(methods).join(", "),
        );
    }

    const entry = methods[method];
    if (!entry) {
        throw new HttpsError(
            "invalid-argument",
            `Unknown method '${method}'. Available: ${Object.keys(methods).join(", ")}`,
        );
    }

    // Auth check for protected methods
    if (entry.auth && !request.auth?.uid) {
        throw new HttpsError(
            "unauthenticated",
            `Method '${method}' requires authentication.`,
        );
    }

    logger.info("commsGateway", { method, uid: request.auth?.uid || "anon" });

    // Reconstruct request.data for handlers that read from it directly
    const proxiedRequest = {
        ...request,
        data,
    };

    try {
        return await entry.handler(proxiedRequest);
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("commsGateway unhandled error", {
            method,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        throw new HttpsError("internal", `${method} failed: ${error.message}`);
    }
});
