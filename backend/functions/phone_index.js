/**
 * Phone Index Functions
 * 
 * Functions for managing the phoneIndex collection used for contact discovery.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { normalizePhone, normalizePhoneMultiple, hashPhone } from "../lib/phone_utils.js";
import { requireAuth } from "../lib/auth_utils.js";

const db = getFirestore();

/**
 * Migration function to backfill phoneIndex for all existing users
 * 
 * This should be called ONCE to populate phoneIndex for users who registered
 * before the phone indexing feature was added.
 * 
 * Call via: firebase functions:call migratePhoneIndex
 */
export const migratePhoneIndex = onCall(
    {
        timeoutSeconds: 540, // 9 minutes max
        memory: "512MiB",
    },
    async (request) => {
        requireAuth(request, "migrate phone index");

        logger.info("Starting phoneIndex migration...");
        
        const usersSnapshot = await db.collection("users").get();
        
        let processed = 0;
        let indexed = 0;
        let skipped = 0;
        let errors = 0;
        const results = [];
        
        // Process in batches
        const batch = db.batch();
        let batchCount = 0;
        const MAX_BATCH = 500;
        
        for (const userDoc of usersSnapshot.docs) {
            processed++;
            const userData = userDoc.data();
            const userId = userDoc.id;
            const phoneNumber = userData.phoneNumber || userData.phone;
            
            if (!phoneNumber) {
                skipped++;
                continue;
            }
            
            try {
                const normalized = normalizePhone(phoneNumber);
                if (!normalized) {
                    logger.info(`Skipping user ${userId}: invalid phone ${phoneNumber}`);
                    skipped++;
                    continue;
                }
                
                const hash = hashPhone(normalized);
                
                // Check if already exists
                const existingDoc = await db.collection("phoneIndex").doc(hash).get();
                if (existingDoc.exists) {
                    // Already indexed
                    skipped++;
                    continue;
                }
                
                // Add to batch
                batch.set(db.collection("phoneIndex").doc(hash), {
                    userId: userId,
                    createdAt: FieldValue.serverTimestamp(),
                    migratedAt: FieldValue.serverTimestamp(),
                });
                
                indexed++;
                batchCount++;
                
                // Commit batch if it reaches max size
                if (batchCount >= MAX_BATCH) {
                    await batch.commit();
                    logger.info(`Committed batch of ${batchCount} phone indexes`);
                    batchCount = 0;
                }
                
            } catch (error) {
                logger.error(`Error indexing user ${userId}:`, error);
                errors++;
            }
        }
        
        // Commit remaining
        if (batchCount > 0) {
            await batch.commit();
            logger.info(`Committed final batch of ${batchCount} phone indexes`);
        }
        
        const summary = {
            totalUsers: processed,
            indexed: indexed,
            skipped: skipped,
            errors: errors,
        };
        
        logger.info("Migration complete:", summary);
        
        return summary;
    }
);

/**
 * Index a single user's phone (can be called manually if needed)
 */
export const indexUserPhone = onCall({
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke
}, async (request) => {
    const callerUid = requireAuth(request, "index user phone");

    const userId = request.data.userId || callerUid;
    
    // Get user document
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
        throw new HttpsError("not-found", "User not found");
    }
    
    const userData = userDoc.data();
    const phoneNumber = userData.phoneNumber || userData.phone;
    
    if (!phoneNumber) {
        throw new HttpsError("failed-precondition", "User has no phone number");
    }
    
    const normalized = normalizePhone(phoneNumber);
    if (!normalized) {
        throw new HttpsError("invalid-argument", "Invalid phone number format");
    }
    
    const hash = hashPhone(normalized);
    
    await db.collection("phoneIndex").doc(hash).set({
        userId: userId,
        createdAt: FieldValue.serverTimestamp(),
    });
    
    return { success: true, hash: hash };
});

/**
 * Enhanced migration that creates multiple hash entries per user
 * to handle different phone number formats device contacts might have.
 * 
 * Call via: firebase functions:call migratePhoneIndexEnhanced
 */
export const migratePhoneIndexEnhanced = onCall(
    {
        region: "asia-southeast2",
        timeoutSeconds: 540,
        memory: "512MiB",
    },
    async (request) => {
        requireAuth(request, "migrate phone index enhanced");

        logger.info("Starting ENHANCED phoneIndex migration...");
        
        const usersSnapshot = await db.collection("users").get();
        
        let processed = 0;
        let usersIndexed = 0;
        let hashesCreated = 0;
        let skipped = 0;
        let errors = 0;
        
        for (const userDoc of usersSnapshot.docs) {
            processed++;
            const userData = userDoc.data();
            const userId = userDoc.id;
            const phoneNumber = userData.phoneNumber || userData.phone;
            
            if (!phoneNumber) {
                skipped++;
                continue;
            }
            
            try {
                // Get multiple normalized forms
                const normalizedForms = normalizePhoneMultiple(phoneNumber);
                
                if (normalizedForms.length === 0) {
                    logger.info(`Skipping user ${userId}: invalid phone ${phoneNumber}`);
                    skipped++;
                    continue;
                }
                
                let userHashesCreated = 0;
                
                // Create an index entry for each normalized form
                for (const normalized of normalizedForms) {
                    const hash = hashPhone(normalized);
                    
                    // Create/update the index entry
                    await db.collection("phoneIndex").doc(hash).set({
                        userId: userId,
                        normalizedPhone: normalized,
                        originalPhone: phoneNumber,
                        createdAt: FieldValue.serverTimestamp(),
                        migratedAt: FieldValue.serverTimestamp(),
                    }, { merge: true });
                    
                    hashesCreated++;
                    userHashesCreated++;
                }
                
                logger.info(`✅ User ${userId}: indexed ${userHashesCreated} variants of ${phoneNumber}`);
                usersIndexed++;
                
            } catch (error) {
                logger.error(`❌ Error indexing user ${userId}:`, error);
                errors++;
            }
        }
        
        const summary = {
            totalUsers: processed,
            usersIndexed: usersIndexed,
            hashesCreated: hashesCreated,
            skipped: skipped,
            errors: errors,
            avgHashesPerUser: usersIndexed > 0 ? (hashesCreated / usersIndexed).toFixed(2) : 0,
        };
        
        logger.info("Enhanced migration complete:", summary);
        
        return summary;
    }
);

/**
 * Diagnostic function to check phone matching for a specific user
 */
export const debugUserPhoneIndex = onCall(
    {
        region: "asia-southeast2",
    },
    async (request) => {
        requireAuth(request, "debug user phone index");

        const { userId, phone } = request.data;
        
        const results = {
            userId,
            phoneProvided: phone,
            userDoc: null,
            phoneInUserDoc: null,
            normalizedForms: [],
            hashes: [],
            phoneIndexEntries: [],
        };
        
        // Get user doc
        if (userId) {
            const userDoc = await db.collection("users").doc(userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                results.userDoc = { exists: true };
                results.phoneInUserDoc = userData.phoneNumber || userData.phone || null;
            }
        }
        
        // Normalize the phone (either from param or from user doc)
        const phoneToCheck = phone || results.phoneInUserDoc;
        
        if (phoneToCheck) {
            results.normalizedForms = normalizePhoneMultiple(phoneToCheck);
            results.hashes = results.normalizedForms.map(n => ({
                normalized: n,
                hash: hashPhone(n),
            }));
            
            // Check each hash in phoneIndex
            for (const { hash } of results.hashes) {
                const doc = await db.collection("phoneIndex").doc(hash).get();
                results.phoneIndexEntries.push({
                    hash,
                    exists: doc.exists,
                    data: doc.exists ? doc.data() : null,
                });
            }
        }
        
        return results;
    }
);
