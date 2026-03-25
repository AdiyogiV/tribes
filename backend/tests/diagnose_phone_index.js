/**
 * Diagnostic script to debug phone index matching
 * 
 * Usage: node tests/diagnose_phone_index.js
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import crypto from "crypto";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

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
 * Normalize phone number for consistent hashing
 */
function normalizePhone(phone) {
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
 * Hash phone number for privacy
 */
function hashPhone(phone) {
    const hash = crypto.createHash('sha256');
    hash.update(phone);
    return hash.digest('hex').substring(0, 16);
}

async function diagnose() {
    console.log("🔍 Diagnosing Phone Index...\n");
    
    // 1. Get all phoneIndex documents
    console.log("📋 All phoneIndex documents:");
    console.log("=".repeat(70));
    const phoneIndexDocs = await db.collection("phoneIndex").get();
    console.log(`Total: ${phoneIndexDocs.docs.length} documents\n`);
    
    const indexedHashes = new Map(); // hash -> userId
    for (const doc of phoneIndexDocs.docs) {
        const data = doc.data();
        indexedHashes.set(doc.id, data.userId);
        console.log(`  ${doc.id} → ${data.userId}`);
    }
    
    // 2. Get all Auth users and their phones
    console.log("\n\n📱 All Firebase Auth users with phones:");
    console.log("=".repeat(70));
    const authUsers = await auth.listUsers(1000);
    
    let usersWithPhone = 0;
    for (const user of authUsers.users) {
        if (user.phoneNumber) {
            usersWithPhone++;
            const normalized = normalizePhone(user.phoneNumber);
            const hash = normalized ? hashPhone(normalized) : 'N/A';
            const isIndexed = indexedHashes.has(hash);
            const status = isIndexed ? '✅' : '❌';
            
            console.log(`  ${status} ${user.displayName || user.uid.substring(0, 8)}`);
            console.log(`     Raw:        ${user.phoneNumber}`);
            console.log(`     Normalized: ${normalized || 'N/A'}`);
            console.log(`     Hash:       ${hash}`);
            console.log(`     Indexed:    ${isIndexed}\n`);
        }
    }
    
    console.log(`\nTotal users with phone: ${usersWithPhone}`);
    console.log(`Total indexed phones:   ${phoneIndexDocs.docs.length}`);
    
    // 3. Check user documents for phone numbers
    console.log("\n\n📄 User documents with phoneNumber field:");
    console.log("=".repeat(70));
    const usersWithPhoneInDoc = await db.collection("users")
        .where("phoneNumber", "!=", null)
        .get();
    
    console.log(`Total: ${usersWithPhoneInDoc.docs.length} documents\n`);
    for (const doc of usersWithPhoneInDoc.docs) {
        const data = doc.data();
        const phone = data.phoneNumber;
        const normalized = normalizePhone(phone);
        const hash = normalized ? hashPhone(normalized) : 'N/A';
        const isIndexed = indexedHashes.has(hash);
        
        console.log(`  User: ${data.name || doc.id.substring(0, 8)}`);
        console.log(`     Phone:      ${phone}`);
        console.log(`     Normalized: ${normalized || 'N/A'}`);
        console.log(`     Hash:       ${hash}`);
        console.log(`     In Index:   ${isIndexed}\n`);
    }
    
    // 4. Test some sample phone formats
    console.log("\n\n🧪 Testing phone number normalization:");
    console.log("=".repeat(70));
    const testNumbers = [
        "9876543210",
        "09876543210",
        "+919876543210",
        "919876543210",
        "+91 98765 43210",
        "(91) 9876543210",
        "+1 (650) 555-1234",
    ];
    
    for (const num of testNumbers) {
        const normalized = normalizePhone(num);
        const hash = normalized ? hashPhone(normalized) : 'N/A';
        console.log(`  "${num}"`);
        console.log(`     → ${normalized || 'INVALID'}`);
        console.log(`     → ${hash}\n`);
    }
}

diagnose()
    .then(() => {
        console.log("\n✅ Diagnosis complete!");
        process.exit(0);
    })
    .catch((error) => {
        console.error("\n❌ Diagnosis failed:", error);
        process.exit(1);
    });

