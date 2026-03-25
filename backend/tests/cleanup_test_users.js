/**
 * Cleanup test users from Firebase Auth
 * Usage: 
 *   Dry run: node tests/cleanup_test_users.js --dry-run
 *   Delete:  node tests/cleanup_test_users.js --confirm
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { readFileSync, writeFileSync } from "fs";
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

function isTestUser(user) {
    const name = user.displayName || '';
    const uid = user.uid || '';
    const email = user.email || '';

    // Test patterns for UID (very specific to avoid false positives)
    const uidTestPatterns = [
        /test[-_]/i,
        /^test$/i,
        /debug/i,
        /timing[-_]test/i,
        /speed[-_]test/i,
        /performance/i,
        /e2e[-_]/i,
        /end[-_]to[-_]end/i,
        /verification/i,
        /comparison/i,
        /^simple[-_]/i,
        /^final[-_]/i,
        /^fast[-_]/i,
        /firestore[-_]test/i,
        /user[-_]test/i,
        /-\d{13,}$/,  // UIDs ending with timestamps like "test-1759596785414"
    ];

    // Name patterns - only if name is clearly test-related
    const nameTestPatterns = [
        /^test$/i,
        /^tester$/i,
        /^debug/i,
        /^test\s/i,
    ];

    // Check UID for test patterns
    if (uidTestPatterns.some(pattern => pattern.test(uid))) {
        return true;
    }

    // Check name for test patterns
    if (nameTestPatterns.some(pattern => pattern.test(name))) {
        return true;
    }

    // Check email for test patterns
    if (email && (email.includes('test') || email.includes('debug'))) {
        return true;
    }

    return false;
}

async function cleanupTestUsers(dryRun = true) {
    console.log("\n🧹 Test User Cleanup Script");
    console.log("=".repeat(70));
    console.log(`Mode: ${dryRun ? "🔍 DRY RUN (no changes will be made)" : "⚠️  LIVE MODE (users will be deleted)"}\n`);

    // Fetch all Auth users
    console.log("📥 Fetching all users from Firebase Auth...");
    const authResult = await auth.listUsers(1000);

    // Identify test users
    const testUsers = [];
    const realUsers = [];

    for (const user of authResult.users) {
        // Check if they have a Firestore profile
        const firestoreDoc = await db.collection("users").doc(user.uid).get();
        const hasFirestore = firestoreDoc.exists;

        if (isTestUser(user)) {
            testUsers.push({
                uid: user.uid,
                name: user.displayName || '(no name)',
                phone: user.phoneNumber || 'none',
                email: user.email || 'none',
                created: user.metadata.creationTime,
                hasFirestore,
            });
        } else {
            realUsers.push(user.uid);
        }
    }

    console.log(`✓ Found ${testUsers.length} test users`);
    console.log(`✓ Found ${realUsers.length} real users (will NOT be touched)\n`);

    // Separate test users by whether they have Firestore profiles
    const testUsersWithFirestore = testUsers.filter(u => u.hasFirestore);
    const testUsersAuthOnly = testUsers.filter(u => !u.hasFirestore);

    console.log("📊 Test Users Breakdown:");
    console.log(`   Auth-only (safe to delete): ${testUsersAuthOnly.length}`);
    console.log(`   With Firestore profiles: ${testUsersWithFirestore.length}`);

    if (testUsersWithFirestore.length > 0) {
        console.log("\n⚠️  WARNING: Some test users have Firestore profiles!");
        console.log("   These will be deleted from Auth but Firestore data will remain.");
        console.log("   Consider cleaning up Firestore manually if needed.\n");
    }

    // Show sample of users to be deleted
    console.log("\n📋 Sample of test users to be deleted:");
    testUsers.slice(0, 10).forEach((user, i) => {
        console.log(`   ${i + 1}. ${user.name} (${user.uid})`);
        console.log(`      Phone: ${user.phone} | Created: ${user.created}`);
        console.log(`      Has Firestore: ${user.hasFirestore ? 'Yes' : 'No'}`);
    });

    if (testUsers.length > 10) {
        console.log(`   ... and ${testUsers.length - 10} more`);
    }

    if (dryRun) {
        console.log("\n" + "=".repeat(70));
        console.log("🔍 DRY RUN COMPLETE");
        console.log("=".repeat(70));
        console.log(`\nWould delete ${testUsers.length} test users from Firebase Auth.`);
        console.log("\nTo actually delete, run:");
        console.log("   node tests/cleanup_test_users.js --confirm\n");

        // Save list to file for review
        const csvDir = join(__dirname, '../analysis');
        const fs = await import('fs');
        if (!fs.existsSync(csvDir)) {
            fs.mkdirSync(csvDir, { recursive: true });
        }

        const csv = [
            'UID,Name,Phone,Email,Created,Has Firestore'
        ];

        testUsers.forEach(user => {
            csv.push([
                user.uid,
                user.name,
                user.phone,
                user.email,
                user.created,
                user.hasFirestore ? 'Yes' : 'No'
            ].join(','));
        });

        const filePath = join(csvDir, 'test_users_to_delete.csv');
        writeFileSync(filePath, csv.join('\n'), 'utf8');
        console.log(`✓ List saved to: ${filePath}\n`);

        return;
    }

    // Actually delete users
    console.log("\n" + "=".repeat(70));
    console.log("⚠️  DELETING TEST USERS");
    console.log("=".repeat(70));
    console.log(`\nThis will delete ${testUsers.length} test users from Firebase Auth...\n`);

    let deleted = 0;
    let errors = 0;
    const errorLog = [];

    // Delete in batches (Firebase allows up to 1000 at a time)
    const batchSize = 100;
    for (let i = 0; i < testUsers.length; i += batchSize) {
        const batch = testUsers.slice(i, i + batchSize);
        const uidsToDelete = batch.map(u => u.uid);

        try {
            await auth.deleteUsers(uidsToDelete);
            deleted += batch.length;
            console.log(`✓ Deleted batch ${Math.floor(i / batchSize) + 1}: ${batch.length} users (${deleted}/${testUsers.length} total)`);
        } catch (error) {
            console.error(`❌ Error deleting batch ${Math.floor(i / batchSize) + 1}:`, error.message);
            errors += batch.length;
            errorLog.push({
                batch: Math.floor(i / batchSize) + 1,
                error: error.message,
                uids: uidsToDelete
            });
        }
    }

    console.log("\n" + "=".repeat(70));
    console.log("✅ CLEANUP COMPLETE");
    console.log("=".repeat(70));
    console.log(`\n✓ Successfully deleted: ${deleted} users`);
    if (errors > 0) {
        console.log(`❌ Errors: ${errors} users`);
        console.log("\nError log:");
        errorLog.forEach(log => {
            console.log(`   Batch ${log.batch}: ${log.error}`);
        });
    }

    console.log(`\n📊 Remaining users: ${authResult.users.length - deleted}`);
    console.log("\n✅ Done!\n");
}

// Parse command line arguments
const args = process.argv.slice(2);
const hasConfirm = args.includes('--confirm');
const hasDryRun = args.includes('--dry-run');
const isDryRun = !hasConfirm || hasDryRun;

if (!hasConfirm && !hasDryRun) {
    console.log("\n⚠️  WARNING: This will DELETE test users from Firebase Auth!");
    console.log("Run with --dry-run first to see what will be deleted.");
    console.log("Run with --confirm to actually delete.\n");
    process.exit(1);
}

cleanupTestUsers(isDryRun)
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error);
        process.exit(1);
    });
