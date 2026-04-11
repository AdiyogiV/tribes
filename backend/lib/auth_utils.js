/**
 * Authentication utilities for Firebase Cloud Functions
 * Eliminates duplicated auth check boilerplate across function files
 */

import { HttpsError } from "firebase-functions/v2/https";

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
