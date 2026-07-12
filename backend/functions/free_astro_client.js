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
 *
 * Resilience (the whole app stands on this one free third-party API):
 *   - per-attempt timeout via AbortController (REQUEST_TIMEOUT_MS)
 *   - bounded retries on transient failures (network error, 429, 5xx) with backoff
 *   - non-transient errors (4xx except 429) fail fast — retrying won't help
 * Success path is unchanged: returns the parsed JSON.
 */
export const REQUEST_TIMEOUT_MS = 15000;
export const MAX_RETRIES = 2;      // up to 3 attempts total
export const RETRY_BASE_DELAY_MS = 600;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const isTransientStatus = (status) => status === 429 || (status >= 500 && status <= 599);

export const callFreeAstro = async (endpoint, payload) => {
    const apiKey = getApiKey();
    if (!apiKey) {
        throw new HttpsError(
            "failed-precondition",
            "FreeAstrologyAPI key is not configured",
        );
    }

    let lastError;
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
        try {
            const response = await fetch(`${API_BASE}${endpoint}`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "x-api-key": apiKey,
                },
                body: JSON.stringify(payload),
                signal: controller.signal,
            });

            if (!response.ok) {
                const errorBody = await response.text();
                logger.error(`API Error ${endpoint}`, {
                    structuredData: true,
                    endpoint,
                    status: response.status,
                    attempt,
                    errorBody: errorBody.substring(0, 500),
                    payloadKeys: Object.keys(payload || {}),
                });
                const error = new HttpsError(
                    "internal",
                    `FreeAstrologyAPI error (${response.status}): ${errorBody}`,
                );
                error.statusCode = response.status;
                // Transient? retry (if attempts remain). Otherwise fail fast.
                if (isTransientStatus(response.status) && attempt < MAX_RETRIES) {
                    lastError = error;
                    await sleep(RETRY_BASE_DELAY_MS * (attempt + 1));
                    continue;
                }
                throw error;
            }

            return await response.json();
        } catch (err) {
            // Non-transient HttpsError (e.g. a 4xx we just threw): re-throw now.
            if (err instanceof HttpsError && !isTransientStatus(err.statusCode)) {
                throw err;
            }
            // Network error / timeout (AbortError) / transient HttpsError: maybe retry.
            lastError = err;
            const isAbort = err?.name === "AbortError";
            logger.warn(`FreeAstrologyAPI transient failure ${endpoint}`, {
                structuredData: true,
                endpoint,
                attempt,
                reason: isAbort ? "timeout" : String(err?.message || err),
            });
            if (attempt < MAX_RETRIES) {
                await sleep(RETRY_BASE_DELAY_MS * (attempt + 1));
                continue;
            }
        } finally {
            clearTimeout(timer);
        }
    }

    // Exhausted retries.
    if (lastError instanceof HttpsError) throw lastError;
    throw new HttpsError(
        "unavailable",
        `FreeAstrologyAPI unreachable after ${MAX_RETRIES + 1} attempts: ${String(lastError?.message || lastError)}`,
    );
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
