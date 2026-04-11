/**
 * Script to run the phone index migration
 * 
 * This script reads phone numbers from Firebase Auth (not Firestore user docs)
 * and creates phoneIndex entries for contact discovery.
 * 
 * Usage: node tests/run_phone_migration.js
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import crypto from "crypto";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { normalizePhone } from "../lib/phone_utils.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
    readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8")
);

initializeApp({
    credential: cert(serviceAccount),
});

const db = getFirestore();
const auth = getAuth();

/**
 * Hash phone number for privacy
 */
function hashPhone(phone) {
    const hash = crypto.createHash('sha256');
    hash.update(phone);
    return hash.digest('hex').substring(0, 16);
}

/**
 * List all users from Firebase Auth (with pagination)
 */
async function listAllAuthUsers() {
    const users = [];
    let nextPageToken;
    
    do {
        const result = await auth.listUsers(1000, nextPageToken);
        users.push(...result.users);
        nextPageToken = result.pageToken;
    } while (nextPageToken);
    
    return users;
}

async function migratePhoneIndex() {
    console.log("🚀 Starting phoneIndex migration...\n");
    console.log("📱 Fetching users from Firebase Auth...\n");
    
    // Get all users from Firebase Auth (this has their phone numbers)
    const authUsers = await listAllAuthUsers();
    console.log(`Found ${authUsers.length} users in Firebase Auth\n`);
    
    let processed = 0;
    let indexed = 0;
    let skipped = 0;
    let alreadyIndexed = 0;
    let errors = 0;
    let updatedUserDoc = 0;
    
    for (const authUser of authUsers) {
        processed++;
        const userId = authUser.uid;
        const phoneNumber = authUser.phoneNumber;
        const displayName = authUser.displayName || authUser.email || userId.substring(0, 8);
        
        if (!phoneNumber) {
            console.log(`⏭️  [${processed}/${authUsers.length}] ${displayName}: No phone number`);
            skipped++;
            continue;
        }
        
        try {
            const normalized = normalizePhone(phoneNumber);
            if (!normalized) {
                console.log(`⚠️  [${processed}/${authUsers.length}] ${displayName}: Invalid phone ${phoneNumber}`);
                skipped++;
                continue;
            }
            
            const hash = hashPhone(normalized);
            
            // 1. Check if phone is in user document, add if missing
            const userDoc = await db.collection("users").doc(userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                if (!userData.phoneNumber) {
                    await db.collection("users").doc(userId).update({
                        phoneNumber: phoneNumber,
                    });
                    console.log(`📝 [${processed}/${authUsers.length}] ${displayName}: Added phone to user doc`);
                    updatedUserDoc++;
                }
            }
            
            // 2. Check if phoneIndex already exists
            const existingDoc = await db.collection("phoneIndex").doc(hash).get();
            if (existingDoc.exists) {
                console.log(`✓  [${processed}/${authUsers.length}] ${displayName}: Already indexed`);
                alreadyIndexed++;
                continue;
            }
            
            // 3. Index the user
            await db.collection("phoneIndex").doc(hash).set({
                userId: userId,
                createdAt: FieldValue.serverTimestamp(),
                migratedAt: FieldValue.serverTimestamp(),
            });
            
            console.log(`✅ [${processed}/${authUsers.length}] ${displayName}: Indexed (${normalized} → ${hash})`);
            indexed++;
            
        } catch (error) {
            console.error(`❌ [${processed}/${authUsers.length}] ${displayName}: Error -`, error.message);
            errors++;
        }
    }
    
    console.log("\n" + "=".repeat(50));
    console.log("📊 Migration Summary");
    console.log("=".repeat(50));
    console.log(`Total Auth users:    ${processed}`);
    console.log(`Newly indexed:       ${indexed}`);
    console.log(`Already indexed:     ${alreadyIndexed}`);
    console.log(`Updated user docs:   ${updatedUserDoc}`);
    console.log(`Skipped (no phone):  ${skipped}`);
    console.log(`Errors:              ${errors}`);
    console.log("=".repeat(50));
    
    return { processed, indexed, alreadyIndexed, updatedUserDoc, skipped, errors };
}

// Run the migration
migratePhoneIndex()
    .then((result) => {
        console.log("\n✅ Migration complete!");
        process.exit(0);
    })
    .catch((error) => {
        console.error("\n❌ Migration failed:", error);
        process.exit(1);
    });

