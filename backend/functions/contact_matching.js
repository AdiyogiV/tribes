/**
 * Contact Matching Cloud Functions
 * 
 * Handles contact matching on the backend with:
 * - Better normalization with multiple strategies
 * - Analytics and insights collection
 * - Centralized logging for debugging
 * - Rate limiting and security
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { normalizePhoneMultiple, hashPhone, maskPhone } from "../lib/phone_utils.js";
import { requireAuth } from "../lib/auth_utils.js";

const db = getFirestore();

/**
 * Match contacts against phoneIndex
 * 
 * @param {Object} data - { contacts: [{name, phone}, ...] }
 * @returns {Object} - { matches: [{name, phone, hash, userId}, ...], stats: {...} }
 */
export const matchContacts = onCall({
    region: "asia-southeast2",
    memory: "256MiB",
    timeoutSeconds: 60,
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
    // AppCheck: DISABLED until Flutter client enables FirebaseAppCheck
    // TODO: Set to true after enabling AppCheck in lib/main.dart
    // enforceAppCheck: true,
}, async (request) => {
    const userId = requireAuth(request, "match contacts");
    const { contacts } = request.data;
    
    if (!contacts || !Array.isArray(contacts)) {
        throw new HttpsError('invalid-argument', 'contacts must be an array');
    }
    
    if (contacts.length > 1000) {
        throw new HttpsError('invalid-argument', 'Maximum 1000 contacts per request');
    }
    
    logger.info(`[matchContacts] User ${userId} matching ${contacts.length} contacts`);
    
    const startTime = Date.now();
    const stats = {
        totalContacts: contacts.length,
        validPhones: 0,
        uniqueHashes: 0,
        matchesFound: 0,
        normalizationVariants: 0,
    };
    
    // Build hash map: hash -> {name, phone, normalizedAs}
    const hashMap = new Map();
    const phoneAnalytics = []; // For debugging
    
    for (const contact of contacts) {
        const { name, phone } = contact;
        if (!phone) continue;
        
        const normalizedForms = normalizePhoneMultiple(phone);
        stats.normalizationVariants += normalizedForms.length;
        
        if (normalizedForms.length === 0) {
            phoneAnalytics.push({ name, phone, status: 'invalid', reason: 'too_short_or_invalid' });
            continue;
        }
        
        stats.validPhones++;
        
        // Hash all normalized forms
        for (const normalized of normalizedForms) {
            const hash = hashPhone(normalized);
            if (!hashMap.has(hash)) {
                hashMap.set(hash, { name, phone, normalizedAs: normalized });
            }
        }
        
        phoneAnalytics.push({ 
            name, 
            phone, 
            status: 'valid', 
            normalizedForms,
            hashes: normalizedForms.map(n => hashPhone(n)),
        });
    }
    
    stats.uniqueHashes = hashMap.size;
    
    logger.info(`[matchContacts] Generated ${hashMap.size} unique hashes from ${stats.validPhones} valid phones`);
    
    // Query phoneIndex in batches
    const hashes = Array.from(hashMap.keys());
    const matchesByUserId = new Map(); // Deduplicate by userId
    
    for (let i = 0; i < hashes.length; i += 10) {
        const batch = hashes.slice(i, i + 10);
        
        const snapshot = await db
            .collection('phoneIndex')
            .where('__name__', 'in', batch)
            .get();
        
        for (const doc of snapshot.docs) {
            const matchedUserId = doc.data().userId;
            // Exclude self and deduplicate by userId
            if (matchedUserId && matchedUserId !== userId && !matchesByUserId.has(matchedUserId)) {
                const contactData = hashMap.get(doc.id);
                matchesByUserId.set(matchedUserId, {
                    name: contactData.name,
                    phone: contactData.phone,
                    normalizedAs: contactData.normalizedAs,
                    hash: doc.id,
                    userId: matchedUserId,
                });
            }
        }
    }
    
    const matches = Array.from(matchesByUserId.values());
    stats.matchesFound = matches.length;
    stats.processingTimeMs = Date.now() - startTime;
    stats.matchRate = stats.validPhones > 0 
        ? (stats.matchesFound / stats.validPhones * 100).toFixed(2) + '%'
        : '0%';
    
    logger.info(`[matchContacts] Found ${matches.length} matches in ${stats.processingTimeMs}ms`);
    logger.info(`[matchContacts] Stats:`, JSON.stringify(stats));
    
    // Save contact relationships (who this user has in contacts)
    // This enables backend phone visibility checks
    saveContactRelationships(userId, matches.map(m => m.userId)).catch(e =>
        logger.error('[matchContacts] Failed to save contact relationships:', e)
    );
    
    // Save analytics (async, don't wait)
    saveMatchAnalytics(userId, stats, phoneAnalytics.slice(0, 10)).catch(e => 
        logger.error('[matchContacts] Failed to save analytics:', e)
    );
    
    return {
        matches,
        stats,
        // Include sample analytics for debugging (first 5 non-matching)
        debugSamples: phoneAnalytics
            .filter(p => p.status === 'valid')
            .slice(0, 5)
            .map(p => ({ 
                name: p.name, 
                phone: p.phone, 
                hashes: p.hashes,
            })),
    };
});

/**
 * Save which users this person has in their contacts
 * Uses a single document with array for efficiency (1 read vs N reads)
 * Replaces old contacts completely to handle removals
 */
async function saveContactRelationships(userId, contactUserIds) {
    try {
        // Store as array in single document - efficient for reads and writes
        // Max ~1MB per doc, ~10 bytes per userId = ~100K contacts supported
        await db.collection('userContacts').doc(userId).set({
            contactUserIds: contactUserIds || [],
            lastSync: FieldValue.serverTimestamp(),
            contactCount: contactUserIds?.length || 0,
        });
        
        logger.info(`[saveContactRelationships] Saved ${contactUserIds?.length || 0} contacts for user ${userId}`);
    } catch (e) {
        logger.error('[saveContactRelationships] Error:', e);
    }
}

/**
 * Save analytics for later analysis
 */
async function saveMatchAnalytics(userId, stats, samplePhones) {
    try {
        await db.collection('contactMatchAnalytics').add({
            userId,
            timestamp: FieldValue.serverTimestamp(),
            stats,
            samplePhones: samplePhones.map(p => ({
                // Mask phone for privacy using shared util
                phoneMasked: p.phone ? maskPhone(p.phone) : null,
                status: p.status,
                normalizedForms: p.normalizedForms?.length || 0,
            })),
        });
    } catch (e) {
        logger.error('[saveMatchAnalytics] Error:', e);
    }
}

// REMOVED: getMatchingInsights — admin-only analytics endpoint with no callers.
// `contactMatchAnalytics` is still populated by saveMatchAnalytics() for future use.

/**
 * Debug endpoint to check if a specific phone would match
 */
export const debugPhoneMatch = onCall({
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke
}, async (request) => {
    requireAuth(request, "debug phone match");

    const { phone } = request.data;
    if (!phone) {
        throw new HttpsError('invalid-argument', 'phone is required');
    }
    
    const normalizedForms = normalizePhoneMultiple(phone);
    const hashes = normalizedForms.map(n => ({ normalized: n, hash: hashPhone(n) }));
    
    // Check each hash in phoneIndex
    const results = [];
    for (const { normalized, hash } of hashes) {
        const doc = await db.collection('phoneIndex').doc(hash).get();
        results.push({
            normalized,
            hash,
            found: doc.exists,
            userId: doc.exists ? doc.data()?.userId : null,
        });
    }
    
    return {
        input: phone,
        normalizedForms,
        hashChecks: results,
        wouldMatch: results.some(r => r.found),
    };
});

// Note: getUserProfile function removed - phone numbers are no longer displayed
// in UI to anyone. Contact relationships are still stored for potential future use.
