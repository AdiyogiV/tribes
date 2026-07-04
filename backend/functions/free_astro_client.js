// free_astro_client.js — the single low-level HTTP client for FreeAstrologyAPI.
//
// Extracted from ephemeris.js so that every caller (the ephemeris flow,
// compatibility, geo search) shares ONE fetch wrapper, ONE api-key resolver,
// and ONE error-handling path instead of each file re-implementing it.
//
// Requires the calling Cloud Function to declare `freeAstrologyApiKey` in its
// `secrets` array (the gateways already do).

import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { freeAstrologyApiKey } from "../lib/secrets.js";
import { FREE_ASTROLOGY_API } from "../lib/constants.js";

export const API_BASE = FREE_ASTROLOGY_API.BASE_URL;

/**
 * Resolve the API key from the Firebase v2 secret, falling back to env.
 */
export const getApiKey = () => {
    // Try Firebase v2 secret first
    try {
        const secretValue = freeAstrologyApiKey.value();
        if (secretValue) return secretValue;
    } catch (e) {
        // Secret not available in this context, try env
    }
    // Fallback to environment variable
    return process.env.FREE_ASTROLOGY_API_KEY || "";
};

/**
 * POST to a FreeAstrologyAPI endpoint. Throws HttpsError on failure.
 */
export const callFreeAstro = async (endpoint, payload) => {
    const apiKey = getApiKey();
    if (!apiKey) {
        throw new HttpsError(
            "failed-precondition",
            "FreeAstrologyAPI key is not configured",
        );
    }

    const response = await fetch(`${API_BASE}${endpoint}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
        },
        body: JSON.stringify(payload),
    });

    if (!response.ok) {
        const errorBody = await response.text();
        // Detailed error logging for debugging
        logger.error(`API Error ${endpoint}`, {
            structuredData: true,
            endpoint,
            status: response.status,
            errorBody: errorBody.substring(0, 500),
            payloadKeys: Object.keys(payload || {}),
        });
        const error = new HttpsError(
            "internal",
            `FreeAstrologyAPI error (${response.status}): ${errorBody}`,
        );
        error.statusCode = response.status;
        throw error;
    }

    return await response.json();
};

/**
 * Call the API safely, returning null instead of throwing.
 * Note: Errors are already logged in detail by callFreeAstro.
 */
export const callFreeAstroSafe = async (endpoint, payload) => {
    try {
        return await callFreeAstro(endpoint, payload);
    } catch (error) {
        return null;
    }
};
