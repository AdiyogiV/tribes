/**
 * Shared Phone Utility Functions
 * 
 * Centralized phone number normalization and hashing for consistent matching
 * across all backend functions (contact_matching.js, phone_index.js, etc.)
 */

import crypto from "crypto";

/**
 * Normalize phone number for consistent hashing.
 * Returns the primary normalized form.
 * 
 * @param {string} phone - Raw phone number
 * @returns {string|null} - Normalized phone or null if invalid
 */
export function normalizePhone(phone) {
    if (!phone) return null;
    
    // Remove all non-digit except leading +
    let digits = phone.replace(/[^\d+]/g, '');
    
    // Must have at least 10 digits
    const digitCount = digits.replace('+', '').length;
    if (digitCount < 10) return null;
    
    // Ensure country code
    if (!digits.startsWith('+')) {
        // Remove leading 0 if present (common in Indian local numbers)
        if (digits.startsWith('0')) {
            digits = digits.substring(1);
        }
        
        if (digits.length === 10) {
            // Assume India (+91) for 10-digit numbers
            digits = '+91' + digits;
        } else if (digits.startsWith('91') && digits.length === 12) {
            digits = '+' + digits;
        } else if (digits.length > 10) {
            // Assume it has country code, just add +
            digits = '+' + digits;
        }
    }
    
    return digits;
}

/**
 * Get all possible normalized forms of a phone number for better matching.
 * Tries different normalizations to maximize match potential.
 * 
 * @param {string} phone - Raw phone number
 * @returns {string[]} - Array of possible normalized forms
 */
export function normalizePhoneMultiple(phone) {
    if (!phone) return [];
    
    // Remove all non-digit except leading +
    let digits = phone.replace(/[^\d+]/g, '');
    
    // Must have at least 10 digits
    const digitCount = digits.replace('+', '').length;
    if (digitCount < 10) return [];
    
    const results = new Set();
    
    // Strategy 1: Already has +, use as-is
    if (digits.startsWith('+')) {
        results.add(digits);
        // Also try without + for matching
        const withoutPlus = digits.substring(1);
        if (withoutPlus.length >= 10) {
            results.add('+' + withoutPlus);
        }
    }
    
    // Strategy 2: Strip leading 0 (common in India/many countries)
    let stripped = digits;
    if (stripped.startsWith('0') && !stripped.startsWith('+')) {
        stripped = stripped.substring(1);
    }
    
    // Strategy 3: 10-digit number - assume India
    if (stripped.length === 10 && !stripped.startsWith('+')) {
        results.add('+91' + stripped);
    }
    
    // Strategy 4: 12-digit starting with 91 - add +
    if (stripped.startsWith('91') && stripped.length === 12) {
        results.add('+' + stripped);
    }
    
    // Strategy 5: 11-digit starting with 0 followed by 91 - strip 0, add +
    if (digits.startsWith('091') && digits.length === 13) {
        results.add('+' + digits.substring(1));
    }
    
    // Strategy 6: Any other long number - try adding + prefix
    if (stripped.length > 10 && !stripped.startsWith('+')) {
        results.add('+' + stripped);
    }
    
    // Strategy 7: Handle numbers saved as "91 XXXXX XXXXX" (with space/dash after country code)
    const match = phone.match(/^(\+?91)[\s\-]?(\d{10})$/);
    if (match) {
        results.add('+91' + match[2]);
    }
    
    return Array.from(results);
}

/**
 * Hash phone number for privacy using SHA-256.
 * Returns full 64-character hex hash for collision resistance.
 * 
 * Security note: Using full hash instead of truncated version to minimize
 * collision risk. The additional storage cost (64 vs 16 chars) is negligible.
 * 
 * @param {string} phone - Normalized phone number
 * @returns {string} - Full SHA-256 hash (64 hex characters)
 */
export function hashPhone(phone) {
    return crypto.createHash('sha256').update(phone).digest('hex');
}

/**
 * Get hash variants for a phone number.
 * Returns all possible hashes for multi-strategy matching.
 * 
 * @param {string} phone - Raw phone number
 * @returns {{normalized: string, hash: string}[]} - Array of {normalized, hash} objects
 */
export function getPhoneHashVariants(phone) {
    const normalizedForms = normalizePhoneMultiple(phone);
    return normalizedForms.map(normalized => ({
        normalized,
        hash: hashPhone(normalized),
    }));
}

/**
 * Validate phone number format.
 * 
 * @param {string} phone - Phone number to validate
 * @returns {boolean} - True if valid
 */
export function isValidPhone(phone) {
    if (!phone) return false;
    const digits = phone.replace(/[^\d]/g, '');
    return digits.length >= 10 && digits.length <= 15;
}

/**
 * Format phone for display (mask middle digits for privacy).
 * 
 * @param {string} phone - Phone number
 * @returns {string} - Masked phone like "+91 98****10"
 */
export function maskPhone(phone) {
    if (!phone || phone.length < 6) return phone;
    const visible = 4;
    const start = phone.slice(0, visible);
    const end = phone.slice(-2);
    return `${start}****${end}`;
}


