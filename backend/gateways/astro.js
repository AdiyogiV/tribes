/**
 * astroGateway — Single Cloud Run service for all astrology-related onCall methods.
 *
 * Consolidates 9 separate functions into 1, reducing deploy footprint
 * from 9 vCPU to 1 vCPU and eliminating quota issues.
 *
 * Flutter calls:  functions.httpsCallable('astroGateway').call({ method: '...', ...data })
 *
 * Methods:
 *   - getSkyPositions         [public]   Read cached planetary positions
 *   - getUpcomingEvents       [public]   Read pre-calculated events
 *   - getAstroCalendar        [public]   Compact calendar (positions + panchang + muhurat)
 *   - prefetchSkyPositions    [public]   Trigger manual sky prefetch
 *   - freeAstroCalculate      [auth]     Full birth chart calculation
 *   - calculateCompatibility  [auth]     Kundli matching between two users
 *   - searchGeoLocation       [public]   Location autocomplete
 *   - syncAstroProfile        [auth]     Sync/upgrade astro data
 *   - invalidateCompCache     [internal] Clear compatibility cache for a user
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { freeAstrologyApiKey, geminiApiKey } from "../lib/secrets.js";

// Import handlers from their existing files
import {
    handleGetSkyPositions,
    handleGetUpcomingEvents,
    handlePrefetchSkyPositions,
    handleGetAstroCalendar,
} from "../functions/sky_positions.js";

import {
    handleFreeAstroCalculate,
    handleCalculateCompatibility,
    handleSearchGeoLocation,
    invalidateCompatibilityCache,
} from "../functions/astro_api.js";

import {
    handleSyncAstroProfile,
} from "../functions/astro_sync.js";

// Method registry — maps method name to handler + auth requirement
const methods = {
    // Public methods (no auth required)
    getSkyPositions:      { handler: (req, data) => handleGetSkyPositions(), auth: false },
    getUpcomingEvents:    { handler: (req, data) => handleGetUpcomingEvents(), auth: false },
    getAstroCalendar:     { handler: (req, data) => handleGetAstroCalendar(req, data), auth: false },
    prefetchSkyPositions: { handler: (req) => handlePrefetchSkyPositions(req), auth: false },
    searchGeoLocation:    { handler: (req, data) => handleSearchGeoLocation(req, data), auth: false },

    // Auth-required methods
    freeAstroCalculate:     { handler: (req) => handleFreeAstroCalculate(req), auth: true },
    calculateCompatibility: { handler: (req) => handleCalculateCompatibility(req), auth: true },
    syncAstroProfile:       { handler: (req) => handleSyncAstroProfile(req), auth: true },
    invalidateCompCache:    { handler: (req, data) => invalidateCompatibilityCache(data.userId), auth: true },
};

export const astroGateway = onCall({
    secrets: [freeAstrologyApiKey, geminiApiKey],
    timeoutSeconds: 300,   // max of all methods (prefetchSkyPositions needs 300)
    memory: "512MiB",      // max of all methods
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

    logger.info("astroGateway", { method, uid: request.auth?.uid || "anon" });

    // Reconstruct request.data for handlers that read from it directly
    // (e.g., freeAstroCalculate reads request.data.birthDate)
    const proxiedRequest = {
        ...request,
        data,
    };

    try {
        return await entry.handler(proxiedRequest, data);
    } catch (error) {
        // Re-throw HttpsErrors as-is (they have proper codes for the client)
        if (error instanceof HttpsError) {
            throw error;
        }
        logger.error("astroGateway unhandled error", {
            method,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        throw new HttpsError("internal", `${method} failed: ${error.message}`);
    }
});
