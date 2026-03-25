/**
 * Persistent Rate Limiter using Firestore
 * 
 * Provides rate limiting that persists across Cloud Function cold starts.
 * Uses Firestore with TTL for automatic cleanup.
 * 
 * Usage:
 *   import { checkRateLimit, RateLimitConfig } from "../lib/rate_limiter.js";
 *   
 *   const config = { windowMs: 60000, maxRequests: 20, identifier: userId };
 *   const { allowed, remaining, resetAt } = await checkRateLimit("ai_chat", config);
 *   if (!allowed) throw new HttpsError("resource-exhausted", "Rate limit exceeded");
 */

import { db, FieldValue } from "./firebase.js";
import { logger } from "firebase-functions";

// Collection for storing rate limit data
const RATE_LIMIT_COLLECTION = "_rateLimits";

// In-memory cache to reduce Firestore reads (short TTL)
const memoryCache = new Map();
const MEMORY_CACHE_TTL_MS = 5000; // 5 seconds

/**
 * Rate limit configuration
 * @typedef {Object} RateLimitConfig
 * @property {number} windowMs - Time window in milliseconds
 * @property {number} maxRequests - Maximum requests allowed in window
 * @property {string} identifier - Unique identifier (userId, IP, etc.)
 */

/**
 * Rate limit result
 * @typedef {Object} RateLimitResult
 * @property {boolean} allowed - Whether the request is allowed
 * @property {number} remaining - Remaining requests in current window
 * @property {number} resetAt - Timestamp when the window resets
 * @property {number} retryAfterMs - Milliseconds until rate limit resets (if blocked)
 */

/**
 * Check and update rate limit for a given context and identifier
 * 
 * @param {string} context - Rate limit context (e.g., "ai_chat", "api_call")
 * @param {RateLimitConfig} config - Rate limit configuration
 * @returns {Promise<RateLimitResult>} Rate limit check result
 */
export async function checkRateLimit(context, { windowMs, maxRequests, identifier }) {
    const now = Date.now();
    const docId = `${context}_${identifier}`;
    
    // Check memory cache first (reduces Firestore reads)
    const cached = memoryCache.get(docId);
    if (cached && now - cached.timestamp < MEMORY_CACHE_TTL_MS) {
        if (cached.count >= maxRequests && now < cached.windowEnd) {
            return {
                allowed: false,
                remaining: 0,
                resetAt: cached.windowEnd,
                retryAfterMs: cached.windowEnd - now,
            };
        }
    }
    
    try {
        const docRef = db.collection(RATE_LIMIT_COLLECTION).doc(docId);
        
        // Use transaction for atomic read-modify-write
        const result = await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(docRef);
            const data = doc.exists ? doc.data() : null;
            
            // Calculate window boundaries
            const windowStart = data?.windowStart?.toMillis?.() || data?.windowStart || 0;
            const windowEnd = windowStart + windowMs;
            const isWindowExpired = now >= windowEnd;
            
            if (!data || isWindowExpired) {
                // Start a new window
                const newWindowStart = now;
                const newWindowEnd = now + windowMs;
                const expiresAt = new Date(newWindowEnd + 60000); // Cleanup 1 min after window ends
                
                transaction.set(docRef, {
                    context,
                    identifier,
                    windowStart: newWindowStart,
                    count: 1,
                    expiresAt, // For TTL cleanup
                    updatedAt: FieldValue.serverTimestamp(),
                });
                
                // Update memory cache
                memoryCache.set(docId, { 
                    count: 1, 
                    windowEnd: newWindowEnd, 
                    timestamp: now 
                });
                
                return {
                    allowed: true,
                    remaining: maxRequests - 1,
                    resetAt: newWindowEnd,
                    retryAfterMs: 0,
                };
            }
            
            // Window is still active
            const currentCount = data.count || 0;
            
            if (currentCount >= maxRequests) {
                // Rate limit exceeded
                memoryCache.set(docId, { 
                    count: currentCount, 
                    windowEnd, 
                    timestamp: now 
                });
                
                return {
                    allowed: false,
                    remaining: 0,
                    resetAt: windowEnd,
                    retryAfterMs: windowEnd - now,
                };
            }
            
            // Increment count
            const newCount = currentCount + 1;
            transaction.update(docRef, {
                count: newCount,
                updatedAt: FieldValue.serverTimestamp(),
            });
            
            // Update memory cache
            memoryCache.set(docId, { 
                count: newCount, 
                windowEnd, 
                timestamp: now 
            });
            
            return {
                allowed: true,
                remaining: maxRequests - newCount,
                resetAt: windowEnd,
                retryAfterMs: 0,
            };
        });
        
        return result;
        
    } catch (error) {
        // On error, fail open (allow request) but log warning
        logger.warn("[RateLimiter] Firestore error, failing open", {
            structuredData: true,
            context,
            identifier,
            error: error.message,
        });
        
        return {
            allowed: true,
            remaining: maxRequests,
            resetAt: now + windowMs,
            retryAfterMs: 0,
        };
    }
}

/**
 * Check rate limit without incrementing (peek only)
 * Useful for showing remaining quota to users
 * 
 * @param {string} context - Rate limit context
 * @param {RateLimitConfig} config - Rate limit configuration
 * @returns {Promise<RateLimitResult>} Current rate limit status
 */
export async function getRateLimitStatus(context, { windowMs, maxRequests, identifier }) {
    const now = Date.now();
    const docId = `${context}_${identifier}`;
    
    try {
        const doc = await db.collection(RATE_LIMIT_COLLECTION).doc(docId).get();
        
        if (!doc.exists) {
            return {
                allowed: true,
                remaining: maxRequests,
                resetAt: now + windowMs,
                retryAfterMs: 0,
            };
        }
        
        const data = doc.data();
        const windowStart = data.windowStart?.toMillis?.() || data.windowStart || 0;
        const windowEnd = windowStart + windowMs;
        const isWindowExpired = now >= windowEnd;
        
        if (isWindowExpired) {
            return {
                allowed: true,
                remaining: maxRequests,
                resetAt: now + windowMs,
                retryAfterMs: 0,
            };
        }
        
        const currentCount = data.count || 0;
        const remaining = Math.max(0, maxRequests - currentCount);
        
        return {
            allowed: remaining > 0,
            remaining,
            resetAt: windowEnd,
            retryAfterMs: remaining > 0 ? 0 : windowEnd - now,
        };
        
    } catch (error) {
        logger.warn("[RateLimiter] Error checking status", {
            structuredData: true,
            context,
            identifier,
            error: error.message,
        });
        
        return {
            allowed: true,
            remaining: maxRequests,
            resetAt: now + windowMs,
            retryAfterMs: 0,
        };
    }
}

/**
 * Reset rate limit for a specific context and identifier
 * Useful for admin override or testing
 * 
 * @param {string} context - Rate limit context
 * @param {string} identifier - Unique identifier
 */
export async function resetRateLimit(context, identifier) {
    const docId = `${context}_${identifier}`;
    
    try {
        await db.collection(RATE_LIMIT_COLLECTION).doc(docId).delete();
        memoryCache.delete(docId);
    } catch (error) {
        logger.warn("[RateLimiter] Error resetting rate limit", {
            structuredData: true,
            context,
            identifier,
            error: error.message,
        });
    }
}

/**
 * Cleanup expired rate limit entries
 * Called periodically by scheduled function or manually
 * 
 * @param {number} batchSize - Number of documents to delete per batch
 * @returns {Promise<number>} Number of documents deleted
 */
export async function cleanupExpiredRateLimits(batchSize = 500) {
    const now = new Date();
    let totalDeleted = 0;
    
    try {
        let hasMore = true;
        
        while (hasMore) {
            const snapshot = await db.collection(RATE_LIMIT_COLLECTION)
                .where("expiresAt", "<", now)
                .limit(batchSize)
                .get();
            
            if (snapshot.empty) {
                hasMore = false;
                break;
            }
            
            const batch = db.batch();
            snapshot.docs.forEach((doc) => {
                batch.delete(doc.ref);
            });
            await batch.commit();
            
            totalDeleted += snapshot.size;
            
            if (snapshot.size < batchSize) {
                hasMore = false;
            }
        }
        
        if (totalDeleted > 0) {
            logger.info("[RateLimiter] Cleaned up expired entries", {
                structuredData: true,
                deleted: totalDeleted,
            });
        }
        
        return totalDeleted;
        
    } catch (error) {
        logger.error("[RateLimiter] Cleanup error", {
            structuredData: true,
            error: error.message,
        });
        return totalDeleted;
    }
}

/**
 * Clear in-memory cache
 * Useful for testing or when cache becomes stale
 */
export function clearMemoryCache() {
    memoryCache.clear();
}

// Pre-defined rate limit configurations for common use cases
export const RATE_LIMIT_PRESETS = {
    // AI chat: 20 requests per minute
    AI_CHAT: {
        windowMs: 60000,
        maxRequests: 20,
    },
    // API calls: 100 requests per minute
    API_STANDARD: {
        windowMs: 60000,
        maxRequests: 100,
    },
    // Strict: 5 requests per minute (for expensive operations)
    API_STRICT: {
        windowMs: 60000,
        maxRequests: 5,
    },
    // Insights: 1 request per 2 minutes
    INSIGHTS: {
        windowMs: 120000,
        maxRequests: 1,
    },
};
