/**
 * Authentication utilities for Firebase Cloud Functions
 * Eliminates duplicated auth check boilerplate across function files
 */

import { HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { logger } from "./firebase.js";

/**
 * Extract and validate authenticated user ID from a Cloud Function request.
 * Throws HttpsError("unauthenticated") if the request lacks valid auth.
 *
 * @param {object} request - Firebase onCall request object
 * @param {string} [context] - Optional context string for error message (e.g. "fetch profile")
 * @returns {string} The authenticated user's UID
 * @throws {HttpsError} If request.auth is missing
 */
export function requireAuth(request, context) {
    if (!request.auth) {
        const msg = context
            ? `Must be authenticated to ${context}`
            : "Must be authenticated";
        throw new HttpsError("unauthenticated", msg);
    }
    return request.auth.uid;
}

/**
 * Build a Set of uids that have used the app within the last `days` days.
 *
 * Uses Firebase Auth's lastRefreshTime (bumped whenever the ID token is
 * refreshed = app opened) with lastSignInTime as a fallback. Pages through
 * listUsers (1000 at a time) so it costs only cheap Auth reads, never LLM
 * calls. Used to gate nightly AI generation so we stop paying Vertex for
 * dormant accounts that never open the app.
 *
 * @param {number} days - Activity window in days.
 * @returns {Promise<Set<string>>} Set of recently-active uids.
 */
export async function getRecentlyActiveUids(days) {
    const cutoffMs = Date.now() - days * 24 * 60 * 60 * 1000;
    const active = new Set();
    let pageToken;
    let scanned = 0;
    do {
        const page = await getAuth().listUsers(1000, pageToken);
        for (const u of page.users) {
            scanned++;
            const last = u.metadata?.lastRefreshTime || u.metadata?.lastSignInTime;
            if (last && new Date(last).getTime() >= cutoffMs) {
                active.add(u.uid);
            }
        }
        pageToken = page.pageToken;
    } while (pageToken);
    logger.info("getRecentlyActiveUids: scanned auth users", {
        structuredData: true,
        days,
        scanned,
        active: active.size,
    });
    return active;
}
