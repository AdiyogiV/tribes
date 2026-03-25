/**
 * Standardized Error Handling Utilities
 * 
 * Establishes consistent error handling patterns across all backend functions:
 * 
 * 1. Critical Operations - logAndThrow()
 *    Use when failure should propagate to caller (callables, main function logic)
 * 
 * 2. Background Tasks - logAndReturn()
 *    Use when failure shouldn't block main operation (async side effects)
 * 
 * 3. Cleanup Operations - logWarning()
 *    Use for non-critical cleanup that shouldn't fail the main operation
 */

import { logger } from "firebase-functions";

/**
 * Log error and re-throw (for critical operations)
 * Use when the operation MUST succeed for the function to be considered successful.
 * 
 * @param {string} context - Where the error occurred (e.g., "generateInsight")
 * @param {Error} error - The error object
 * @param {Object} metadata - Additional context (userId, etc.)
 * @throws {Error} Always re-throws the error
 */
export function logAndThrow(context, error, metadata = {}) {
    logger.error(`[${context}] Critical error`, {
        structuredData: true,
        ...metadata,
        error: String(error),
        stack: error.stack?.substring(0, 500),
    });
    throw error;
}

/**
 * Log error and return null/default (for background tasks)
 * Use when failure shouldn't block the main operation.
 * 
 * @param {string} context - Where the error occurred
 * @param {Error} error - The error object
 * @param {Object} metadata - Additional context
 * @param {*} returnValue - Value to return (default: null)
 * @returns {*} The returnValue parameter
 */
export function logAndReturn(context, error, metadata = {}, returnValue = null) {
    logger.error(`[${context}] Background task failed`, {
        structuredData: true,
        ...metadata,
        error: String(error),
        stack: error.stack?.substring(0, 500),
    });
    return returnValue;
}

/**
 * Log warning only (for cleanup/non-critical operations)
 * Use when failure is expected or acceptable.
 * 
 * @param {string} context - Where the warning occurred
 * @param {string} message - Warning message
 * @param {Object} metadata - Additional context
 */
export function logWarning(context, message, metadata = {}) {
    logger.warn(`[${context}] ${message}`, {
        structuredData: true,
        ...metadata,
    });
}

/**
 * Log info for successful operations
 * 
 * @param {string} context - Operation context
 * @param {string} message - Success message
 * @param {Object} metadata - Additional data
 */
export function logSuccess(context, message, metadata = {}) {
    logger.info(`[${context}] ${message}`, {
        structuredData: true,
        ...metadata,
    });
}

/**
 * Wrap an async function with error handling
 * Logs errors and returns a default value on failure.
 * 
 * @param {string} context - Operation context
 * @param {Function} fn - Async function to wrap
 * @param {*} defaultValue - Value to return on error
 * @returns {*} Result of fn or defaultValue on error
 */
export async function withErrorHandling(context, fn, defaultValue = null) {
    try {
        return await fn();
    } catch (error) {
        return logAndReturn(context, error, {}, defaultValue);
    }
}

/**
 * Create a structured success response for callable functions
 * 
 * @param {*} data - Response data
 * @param {Object} metadata - Optional metadata (e.g., pagination info)
 * @returns {Object} Structured success response
 */
export function successResponse(data, metadata = null) {
    const response = {
        success: true,
        data,
    };
    
    if (metadata) {
        response.metadata = metadata;
    }
    
    return response;
}

/**
 * Create a structured error response for callable functions
 * 
 * @param {string} code - Error code (matches HttpsError codes)
 * @param {string} message - User-facing message
 * @param {Object} details - Additional error details
 * @returns {Object} Structured error response
 */
export function errorResponse(code, message, details = null) {
    const response = {
        success: false,
        error: {
            code,
            message,
        },
    };
    
    if (details) {
        response.error.details = details;
    }
    
    return response;
}

/**
 * @deprecated Use errorResponse instead
 * Create a structured error response for callable functions
 */
export function createErrorResponse(code, message, details = {}) {
    return errorResponse(code, message, details);
}

/**
 * Sanitize error for logging (remove sensitive data)
 * 
 * @param {Error} error - Error object
 * @returns {Object} Sanitized error info
 */
export function sanitizeError(error) {
    return {
        message: String(error?.message || error),
        name: error?.name,
        code: error?.code,
        // Truncate stack to prevent huge log entries
        stack: error?.stack?.substring(0, 500),
    };
}

/**
 * Wrap a callable function with standardized error handling
 * Returns success/error response format consistently
 * 
 * @param {string} context - Function name for logging
 * @param {Function} fn - Async function to execute
 * @returns {Promise<Object>} Standardized response { success, data } or { success, error }
 */
export async function withStandardResponse(context, fn) {
    try {
        const result = await fn();
        return successResponse(result);
    } catch (error) {
        // Log the error
        logger.error(`[${context}] Error`, {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        
        // Return standardized error response
        const code = error.code || "internal";
        const message = error.message || "An unexpected error occurred";
        
        return errorResponse(code, message);
    }
}
