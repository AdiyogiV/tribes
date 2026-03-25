/**
 * Runtime Configuration
 * 
 * Centralized configuration for values that may vary by environment
 * or need to be easily adjustable without code changes.
 * 
 * ORGANIZATION:
 * - config.js (this file): Runtime/environment-specific configuration
 *   - AI models, function timeouts, memory settings
 *   - Default locations, notification channels
 *   - Values that might change between environments
 * 
 * - constants.js: Static domain constants
 *   - Astrology data (nakshatras, zodiac signs, etc.)
 *   - Firestore collection names
 *   - API endpoints, notification types
 *   - Rate limits, batch sizes, cache TTLs
 * 
 * - secrets.js: Sensitive credentials and environment params
 *   - API keys (via defineSecret)
 *   - Environment-specific identifiers (via defineString)
 */

// =============================================================================
// AI MODEL CONFIGURATION
// =============================================================================

export const AI_MODELS = {
    // Gemini model for insights and interpretations
    GEMINI_FLASH: "gemini-2.0-flash",
    GEMINI_PRO: "gemini-1.5-pro",

    // OpenRouter models (via AI_CONFIG in constants.js)
    // Use constants.js AI_CONFIG for OpenRouter settings
};

// =============================================================================
// DEFAULT LOCATIONS
// =============================================================================

/**
 * Default location for astronomical calculations
 * Ujjain, India - Traditional reference point for Vedic astrology
 */
export const DEFAULT_LOCATION = {
    latitude: 23.1765,
    longitude: 75.7885,
    timezone: 5.5, // IST offset in hours
    name: "Ujjain, India",
};

// =============================================================================
// SKY POSITIONS CONFIGURATION
// =============================================================================

export const SKY_POSITIONS_CONFIG = {
    // Days to prefetch ahead
    DAYS_AHEAD_TARGET: 60,
    // Muhurat calculation range
    MUHURAT_DAYS_AHEAD: 3,
    // Cache duration in hours
    MUHURAT_CACHE_HOURS: 6,
};

// =============================================================================
// FUNCTION TIMEOUTS AND MEMORY
// =============================================================================

export const FUNCTION_CONFIG = {
    // AI Chat function
    AI_CHAT: {
        timeoutSeconds: 300,
        memory: "512MiB",
    },
    // Insight generation
    INSIGHT_WORKER: {
        timeoutSeconds: 120,
        memory: "256MiB",
        retryConfig: {
            maxAttempts: 3,
            minBackoffSeconds: 30,
            maxBackoffSeconds: 300,
        },
        rateLimits: {
            maxConcurrentDispatches: 10,
            maxDispatchesPerSecond: 2,
        },
    },
    // User deletion cleanup
    USER_DELETION: {
        timeoutSeconds: 300,
        memory: "512MB",
    },
};

// =============================================================================
// NOTIFICATION CONFIGURATION
// =============================================================================

export const NOTIFICATION_CONFIG = {
    // Android channel configuration
    CHANNELS: {
        CHAT: "chat_messages",
        CALLS: "call_notifications",
        SOCIAL: "social_notifications",
        INSIGHTS: "daily_insights",
    },

    // APNs configuration
    APNS: {
        BUNDLE_ID: "com.canay.dhaara",
    },

    // Android priority
    ANDROID: {
        PRIORITY: "high",
        TTL_MS: 60000, // 1 minute for calls
    },
};

// =============================================================================
// CHAT CONFIGURATION
// =============================================================================

export const CHAT_CONFIG = {
    // Maximum history messages to include in AI context
    MAX_HISTORY_MESSAGES: 20,
    // Typing indicator timeout
    TYPING_TIMEOUT_MS: 10000,
};

// =============================================================================
// CLEANUP CONFIGURATION
// =============================================================================

export const CLEANUP_CONFIG = {
    // AI session cleanup threshold (24 hours)
    AI_SESSION_STALE_MS: 24 * 60 * 60 * 1000,
    // Typing indicator cleanup threshold
    TYPING_STALE_MS: 10000,
    // Insight card delay between generations
    CARD_DELAY_MS: 10000,
};

// =============================================================================
// AGORA CONFIGURATION
// =============================================================================

export const AGORA_CONFIG = {
    // Token expiry in seconds (1 hour)
    TOKEN_EXPIRY_SECONDS: 3600,
};

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Get environment-aware configuration
 * @param {string} env - Environment name (development, staging, production)
 * @returns {Object} Environment-specific overrides
 */
export function getEnvironmentConfig(env) {
    const configs = {
        development: {
            // More permissive rate limits for development
            rateLimitMultiplier: 2,
            logLevel: "debug",
        },
        staging: {
            rateLimitMultiplier: 1.5,
            logLevel: "info",
        },
        production: {
            rateLimitMultiplier: 1,
            logLevel: "warn",
        },
    };

    return configs[env] || configs.production;
}
