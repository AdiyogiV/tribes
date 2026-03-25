/**
 * Shared FCM (Firebase Cloud Messaging) Utilities
 * 
 * Centralizes FCM token handling to avoid duplication across:
 * - notifications.js
 * - chat_notifications.js
 * - calls.js
 * - group_call_notifications.js
 */

import { db, FieldValue, logger } from "./firebase.js";

/**
 * Get all valid FCM tokens for a user.
 * Supports both legacy single fcmToken and new fcmTokens array.
 * 
 * @param {Object} userData - User document data
 * @returns {string[]} Array of FCM tokens (deduplicated)
 */
export function getUserFcmTokens(userData) {
    if (!userData) return [];
    
    const tokens = new Set();
    
    // Add tokens from new array format
    if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach(token => {
            if (token && typeof token === "string" && token.length > 0) {
                tokens.add(token);
            }
        });
    }
    
    // Add legacy single token (for backward compatibility)
    if (userData.fcmToken && typeof userData.fcmToken === "string" && userData.fcmToken.length > 0) {
        tokens.add(userData.fcmToken);
    }
    
    return Array.from(tokens);
}

/**
 * Remove invalid tokens from user's document.
 * Called when FCM returns errors for specific tokens.
 * 
 * @param {string} userId - User ID
 * @param {string[]} invalidTokens - Array of invalid tokens to remove
 */
export async function removeInvalidTokens(userId, invalidTokens) {
    if (!invalidTokens || invalidTokens.length === 0) return;
    
    try {
        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();
        const userData = userDoc.data();
        
        // Remove from fcmTokens array
        if (userData?.fcmTokens && Array.isArray(userData.fcmTokens)) {
            await userRef.update({
                fcmTokens: FieldValue.arrayRemove(...invalidTokens),
            });
        }
        
        // Clear legacy fcmToken if it's invalid
        if (userData?.fcmToken && invalidTokens.includes(userData.fcmToken)) {
            await userRef.update({
                fcmToken: FieldValue.delete(),
            });
        }
        
        logger.info("Removed invalid FCM tokens", {
            structuredData: true,
            userId,
            removedCount: invalidTokens.length,
        });
    } catch (error) {
        logger.error("Failed to remove invalid tokens", {
            structuredData: true,
            userId,
            error: String(error),
        });
    }
}

/**
 * Check if an FCM error code indicates an invalid token
 * 
 * @param {string} errorCode - FCM error code
 * @returns {boolean} True if token should be removed
 */
export function isInvalidTokenError(errorCode) {
    return [
        "messaging/registration-token-not-registered",
        "messaging/invalid-registration-token",
        "messaging/invalid-argument",
    ].includes(errorCode);
}

/**
 * Truncate FCM token for logging (privacy-safe)
 * 
 * @param {string} token - Full FCM token
 * @param {number} prefixLength - Number of characters to show (default 20)
 * @returns {string} Truncated token with "..."
 */
export function truncateToken(token, prefixLength = 20) {
    if (!token || typeof token !== "string") return "[invalid]";
    if (token.length <= prefixLength) return token;
    return `${token.substring(0, prefixLength)}...`;
}
