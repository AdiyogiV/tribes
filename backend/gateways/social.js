/**
 * socialGateway — Single Cloud Run service for all social/interaction onCall methods.
 *
 * Consolidates 10 separate functions into 1, reducing deploy footprint.
 *
 * Flutter calls:  functions.httpsCallable('socialGateway').call({ method: '...', ...data })
 *
 * Methods:
 *   - sendNamaste              [auth]     Send a namaste to another user
 *   - getNamasteQuota          [auth]     Get remaining daily namaste quota
 *   - acceptFollowRequest      [auth]     Accept a pending follow request
 *   - rejectFollowRequest      [auth]     Reject a pending follow request
 *   - submitAnonymousMessage   [public]   Submit an anonymous message
 *   - matchContacts            [auth]     Match phone contacts against user index
 *   - indexUserPhone           [auth]     Index a user's phone for contact matching
 *   - checkPhoneExists         [auth]     Check if a phone already has an account (login branching)
 *   - createRepost             [auth]     Create a repost of a post
 *   - deleteRepost             [auth]     Delete a repost
 *   - awardAuraAction          [auth]     Award aura for a profile/engagement action
 *   - clearAiMemory            [auth]     Wipe the user's durable Aurobhatt memory
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

// Import handlers from their existing files
import {
    handleSendNamaste,
    handleGetNamasteQuota,
} from "../functions/namaste.js";

import {
    handleAcceptFollowRequest,
    handleRejectFollowRequest,
} from "../functions/follows.js";

import {
    handleSubmitAnonymousMessage,
} from "../functions/anonymous_messages.js";

import {
    handleMatchContacts,
} from "../functions/contact_matching.js";

import {
    handleIndexUserPhone,
    handleCheckPhoneExists,
} from "../functions/phone_index.js";

import {
    handleCreateRepost,
    handleDeleteRepost,
} from "../functions/reposts.js";

import {
    handleAwardAuraAction,
} from "../functions/aura.js";

import {
    handleClearUserMemory,
} from "../functions/user_memory.js";

// Method registry — maps method name to handler + auth requirement
const methods = {
    // Auth-required methods
    sendNamaste: { handler: (req) => handleSendNamaste(req), auth: true },
    getNamasteQuota: { handler: (req) => handleGetNamasteQuota(req), auth: true },
    acceptFollowRequest: { handler: (req) => handleAcceptFollowRequest(req), auth: true },
    rejectFollowRequest: { handler: (req) => handleRejectFollowRequest(req), auth: true },
    matchContacts: { handler: (req) => handleMatchContacts(req), auth: true },
    indexUserPhone: { handler: (req) => handleIndexUserPhone(req), auth: true },
    checkPhoneExists: { handler: (req) => handleCheckPhoneExists(req), auth: true },
    createRepost: { handler: (req) => handleCreateRepost(req), auth: true },
    deleteRepost: { handler: (req) => handleDeleteRepost(req), auth: true },
    awardAuraAction: { handler: (req) => handleAwardAuraAction(req), auth: true },
    clearAiMemory: { handler: (req) => handleClearUserMemory(req), auth: true },

    // Public methods (no auth required)
    submitAnonymousMessage: { handler: (req) => handleSubmitAnonymousMessage(req), auth: false },
};

export const socialGateway = onCall({
    timeoutSeconds: 60, // max of all methods (matchContacts needs 60)
    memory: "256MiB", // max of all methods (matchContacts needs 256MiB)
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

    logger.info("socialGateway", { method, uid: request.auth?.uid || "anon" });

    // Reconstruct request.data for handlers that read from it directly
    const proxiedRequest = {
        ...request,
        data,
    };

    try {
        return await entry.handler(proxiedRequest);
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("socialGateway unhandled error", {
            method,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        throw new HttpsError("internal", `${method} failed: ${error.message}`);
    }
});
