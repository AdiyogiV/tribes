/**
 * Unified API Client
 * 
 * Provides a consistent interface for making external API calls with:
 * - Automatic retry with exponential backoff
 * - Configurable timeouts
 * - Structured error handling and logging
 * - Request/response logging (without sensitive data)
 * 
 * Usage:
 *   import { apiCall, ApiError } from "../lib/api_client.js";
 *   
 *   const result = await apiCall({
 *     url: "https://api.example.com/endpoint",
 *     method: "POST",
 *     headers: { "x-api-key": apiKey },
 *     body: { data: "value" },
 *     context: "myFunction",
 *   });
 */

import { logger } from "firebase-functions";
import { logAndThrow, logAndReturn } from "./error_utils.js";
import { TIMEOUTS } from "./constants.js";

// =============================================================================
// CUSTOM ERROR CLASS
// =============================================================================

/**
 * Custom error class for API errors with additional context
 */
export class ApiError extends Error {
    constructor(message, { statusCode, url, method, responseBody, cause } = {}) {
        super(message);
        this.name = "ApiError";
        this.statusCode = statusCode;
        this.url = url;
        this.method = method;
        this.responseBody = responseBody;
        this.cause = cause;
    }
    
    /**
     * Check if error is retryable (server errors, network errors)
     */
    isRetryable() {
        // Retry on 5xx errors, network errors, or timeout
        if (!this.statusCode) return true; // Network/timeout errors
        return this.statusCode >= 500 && this.statusCode < 600;
    }
}

// =============================================================================
// CONFIGURATION
// =============================================================================

const DEFAULT_CONFIG = {
    timeoutMs: TIMEOUTS.API_REQUEST_MS || 30000,
    maxRetries: 3,
    retryDelayMs: 1000,
    maxRetryDelayMs: 10000,
};

// =============================================================================
// MAIN API CALL FUNCTION
// =============================================================================

/**
 * Make an API call with retry, timeout, and error handling
 * 
 * @param {Object} options - API call options
 * @param {string} options.url - The URL to call
 * @param {string} [options.method="GET"] - HTTP method
 * @param {Object} [options.headers={}] - Request headers
 * @param {Object|string} [options.body] - Request body (will be JSON stringified if object)
 * @param {number} [options.timeoutMs] - Request timeout in milliseconds
 * @param {number} [options.maxRetries] - Maximum number of retry attempts
 * @param {string} [options.context="apiCall"] - Context for logging
 * @param {boolean} [options.throwOnError=true] - Whether to throw on error or return null
 * @returns {Promise<Object|null>} Parsed JSON response or null on error (if throwOnError=false)
 */
export async function apiCall({
    url,
    method = "GET",
    headers = {},
    body = null,
    timeoutMs = DEFAULT_CONFIG.timeoutMs,
    maxRetries = DEFAULT_CONFIG.maxRetries,
    context = "apiCall",
    throwOnError = true,
}) {
    let lastError;
    const startTime = Date.now();
    
    for (let attempt = 0; attempt < maxRetries; attempt++) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
        
        try {
            // Prepare request options
            const fetchOptions = {
                method,
                headers: {
                    "Content-Type": "application/json",
                    ...headers,
                },
                signal: controller.signal,
            };
            
            // Add body if present
            if (body != null) {
                fetchOptions.body = typeof body === "string" ? body : JSON.stringify(body);
            }
            
            // Make the request
            const response = await fetch(url, fetchOptions);
            clearTimeout(timeoutId);
            
            // Check for HTTP errors
            if (!response.ok) {
                const errorBody = await response.text().catch(() => "");
                const error = new ApiError(
                    `HTTP ${response.status}: ${response.statusText}`,
                    {
                        statusCode: response.status,
                        url: sanitizeUrl(url),
                        method,
                        responseBody: errorBody.substring(0, 500),
                    }
                );
                
                // Log detailed error
                logger.warn(`[${context}] API error (attempt ${attempt + 1}/${maxRetries})`, {
                    structuredData: true,
                    statusCode: response.status,
                    url: sanitizeUrl(url),
                    method,
                    errorBody: errorBody.substring(0, 200),
                });
                
                // Check if retryable
                if (error.isRetryable() && attempt < maxRetries - 1) {
                    lastError = error;
                    await delay(calculateBackoff(attempt));
                    continue;
                }
                
                throw error;
            }
            
            // Parse JSON response
            const data = await response.json();
            
            // Log success (without sensitive data)
            const duration = Date.now() - startTime;
            if (duration > 5000) {
                logger.info(`[${context}] Slow API call completed`, {
                    structuredData: true,
                    url: sanitizeUrl(url),
                    method,
                    durationMs: duration,
                    attempts: attempt + 1,
                });
            }
            
            return data;
            
        } catch (error) {
            clearTimeout(timeoutId);
            
            // Handle abort/timeout
            if (error.name === "AbortError") {
                lastError = new ApiError("Request timeout", {
                    url: sanitizeUrl(url),
                    method,
                    cause: error,
                });
                
                logger.warn(`[${context}] API timeout (attempt ${attempt + 1}/${maxRetries})`, {
                    structuredData: true,
                    url: sanitizeUrl(url),
                    method,
                    timeoutMs,
                });
                
                if (attempt < maxRetries - 1) {
                    await delay(calculateBackoff(attempt));
                    continue;
                }
            }
            
            // Handle other errors
            if (!(error instanceof ApiError)) {
                lastError = new ApiError(error.message, {
                    url: sanitizeUrl(url),
                    method,
                    cause: error,
                });
            } else {
                lastError = error;
            }
            
            // Non-retryable error or last attempt
            if (!lastError.isRetryable() || attempt >= maxRetries - 1) {
                break;
            }
            
            await delay(calculateBackoff(attempt));
        }
    }
    
    // All retries exhausted
    if (throwOnError) {
        logAndThrow(context, lastError, {
            url: sanitizeUrl(url),
            method,
            attempts: maxRetries,
        });
    }
    
    return logAndReturn(context, lastError, {
        url: sanitizeUrl(url),
        method,
        attempts: maxRetries,
    }, null);
}

/**
 * Make an API call that returns null on error instead of throwing
 * Convenience wrapper around apiCall with throwOnError=false
 */
export async function apiCallSafe(options) {
    return apiCall({ ...options, throwOnError: false });
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Calculate exponential backoff delay
 * @param {number} attempt - Current attempt number (0-indexed)
 * @returns {number} Delay in milliseconds
 */
function calculateBackoff(attempt) {
    const baseDelay = DEFAULT_CONFIG.retryDelayMs;
    const maxDelay = DEFAULT_CONFIG.maxRetryDelayMs;
    const exponentialDelay = baseDelay * Math.pow(2, attempt);
    // Add jitter (±25%)
    const jitter = exponentialDelay * 0.25 * (Math.random() * 2 - 1);
    return Math.min(exponentialDelay + jitter, maxDelay);
}

/**
 * Delay execution
 * @param {number} ms - Milliseconds to delay
 */
function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Sanitize URL for logging (remove sensitive query params)
 * @param {string} url - URL to sanitize
 * @returns {string} Sanitized URL
 */
function sanitizeUrl(url) {
    try {
        const parsed = new URL(url);
        // Remove sensitive query parameters
        const sensitiveParams = ["key", "apikey", "api_key", "token", "secret", "password"];
        sensitiveParams.forEach(param => {
            if (parsed.searchParams.has(param)) {
                parsed.searchParams.set(param, "[REDACTED]");
            }
        });
        return parsed.toString();
    } catch {
        // If URL parsing fails, return truncated version
        return url.substring(0, 100) + (url.length > 100 ? "..." : "");
    }
}

// =============================================================================
// SPECIALIZED API CLIENTS
// =============================================================================

/**
 * Create a pre-configured API client for a specific service
 * 
 * @param {Object} config - Client configuration
 * @param {string} config.baseUrl - Base URL for the service
 * @param {Object} [config.defaultHeaders={}] - Default headers for all requests
 * @param {number} [config.timeoutMs] - Default timeout
 * @param {number} [config.maxRetries] - Default max retries
 * @returns {Object} Configured client with get, post, put, delete methods
 */
export function createApiClient({ baseUrl, defaultHeaders = {}, timeoutMs, maxRetries }) {
    const makeRequest = (method) => async (endpoint, options = {}) => {
        const url = `${baseUrl}${endpoint}`;
        return apiCall({
            url,
            method,
            headers: { ...defaultHeaders, ...options.headers },
            body: options.body,
            timeoutMs: options.timeoutMs ?? timeoutMs,
            maxRetries: options.maxRetries ?? maxRetries,
            context: options.context ?? `${method} ${endpoint}`,
            throwOnError: options.throwOnError,
        });
    };
    
    return {
        get: makeRequest("GET"),
        post: makeRequest("POST"),
        put: makeRequest("PUT"),
        delete: makeRequest("DELETE"),
        patch: makeRequest("PATCH"),
    };
}
