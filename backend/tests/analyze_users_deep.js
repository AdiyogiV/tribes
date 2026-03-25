/**
 * Deep analysis of all users - Auth vs Firestore, test vs real users
 * Exports to CSV for detailed analysis
 * Usage: node tests/analyze_users_deep.js
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
    const name = user.displayName || user.name || '';
    const uid = user.uid || user.id || '';
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

function formatDate(timestamp) {
    if (!timestamp) return 'N/A';

    try {
        let date;
        if (timestamp.toDate) {
            date = timestamp.toDate();
        } else if (timestamp.seconds) {
            date = new Date(timestamp.seconds * 1000);
        } else if (typeof timestamp === 'string') {
            date = new Date(timestamp);
        } else {
            date = timestamp;
        }
        return date.toISOString();
    } catch (e) {
        return 'Invalid Date';
    }
}

function escapeCsv(value) {
    if (value === null || value === undefined) return '';
    const str = String(value);
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
}

async function analyzeUsers() {
    console.log("🔍 Starting deep user analysis...\n");

    // Fetch all users from both sources
    console.log("📥 Fetching all users from Firestore and Auth...");
    const firestoreSnapshot = await db.collection("users").get();
    const authResult = await auth.listUsers(1000);

    // Build maps for easy lookup
    const firestoreUsers = new Map();
    firestoreSnapshot.docs.forEach(doc => {
        firestoreUsers.set(doc.id, {
            id: doc.id,
            ...doc.data()
        });
    });

    const authUsers = new Map();
    authResult.users.forEach(user => {
        authUsers.set(user.uid, user);
    });

    console.log(`✓ Found ${firestoreUsers.size} users in Firestore`);
    console.log(`✓ Found ${authUsers.size} users in Firebase Auth\n`);

    // Categorize all users
    const analysis = {
        completeUsers: [],      // In both Auth and Firestore
        authOnly: [],           // In Auth but not Firestore (incomplete signup)
        firestoreOnly: [],      // In Firestore but not Auth (shouldn't happen)
        testUsers: [],          // Test/debug users
        realUsers: [],          // Real production users
    };

    // Analyze Auth users
    for (const [uid, authUser] of authUsers) {
        const firestoreData = firestoreUsers.get(uid);
        const isTest = isTestUser(authUser);

        const userData = {
            uid,
            name: authUser.displayName || firestoreData?.name || '(no name)',
            phone: authUser.phoneNumber || firestoreData?.phoneNumber || '',
            email: authUser.email || firestoreData?.email || '',
            authCreated: authUser.metadata.creationTime,
            authLastSignIn: authUser.metadata.lastSignInTime,
            inFirestore: !!firestoreData,
            firestoreCreated: firestoreData?.createdAt ? formatDate(firestoreData.createdAt) : 'N/A',
            isTest,
            // Additional Firestore fields
            hasAstrology: !!firestoreData?.astrologyProfile,
            hasAyurveda: !!firestoreData?.ayurvedaProfile,
            hasProfileComplete: !!(firestoreData?.name && firestoreData?.phoneNumber),
            followersCount: firestoreData?.followers || 0,
            followingCount: firestoreData?.following || 0,
            postsCount: firestoreData?.posts || 0,
        };

        if (isTest) {
            analysis.testUsers.push(userData);
        } else {
            analysis.realUsers.push(userData);
        }

        if (firestoreData) {
            analysis.completeUsers.push(userData);
        } else {
            analysis.authOnly.push(userData);
        }
    }

    // Check for Firestore-only users (shouldn't exist)
    for (const [uid, firestoreData] of firestoreUsers) {
        if (!authUsers.has(uid)) {
            analysis.firestoreOnly.push({
                uid,
                name: firestoreData.name || '(no name)',
                phone: firestoreData.phoneNumber || '',
                email: firestoreData.email || '',
                firestoreCreated: formatDate(firestoreData.createdAt),
                isTest: isTestUser(firestoreData),
            });
        }
    }

    // Sort by creation date (newest first)
    const sortByDate = (a, b) => {
        const dateA = new Date(a.authCreated || a.firestoreCreated || 0);
        const dateB = new Date(b.authCreated || b.firestoreCreated || 0);
        return dateB - dateA;
    };

    analysis.completeUsers.sort(sortByDate);
    analysis.authOnly.sort(sortByDate);
    analysis.testUsers.sort(sortByDate);
    analysis.realUsers.sort(sortByDate);

    // Print summary
    console.log("=".repeat(80));
    console.log("📊 USER ANALYSIS SUMMARY");
    console.log("=".repeat(80));
    console.log(`\n✅ Complete Users (Auth + Firestore): ${analysis.completeUsers.length}`);
    console.log(`⚠️  Auth-Only Users (Incomplete signup): ${analysis.authOnly.length}`);
    console.log(`❓ Firestore-Only Users (Orphaned): ${analysis.firestoreOnly.length}`);
    console.log(`\n🧪 Test Users: ${analysis.testUsers.length}`);
    console.log(`👤 Real Users: ${analysis.realUsers.length}`);
    console.log(`\n📈 Total Unique Users: ${authUsers.size}`);

    // Analyze incomplete users
    console.log("\n\n" + "=".repeat(80));
    console.log("⚠️  INCOMPLETE USERS ANALYSIS (Auth but no Firestore)");
    console.log("=".repeat(80));

    const incompleteReal = analysis.authOnly.filter(u => !u.isTest);
    const incompleteTest = analysis.authOnly.filter(u => u.isTest);

    console.log(`\nReal users who didn't complete signup: ${incompleteReal.length}`);
    console.log(`Test users incomplete: ${incompleteTest.length}`);

    if (incompleteReal.length > 0) {
        console.log("\n🔍 Real incomplete users breakdown:");

        // Group by signup recency
        const now = Date.now();
        const day = 24 * 60 * 60 * 1000;
        const recent = incompleteReal.filter(u => (now - new Date(u.authCreated).getTime()) < 7 * day);
        const month = incompleteReal.filter(u => {
            const age = now - new Date(u.authCreated).getTime();
            return age >= 7 * day && age < 30 * day;
        });
        const old = incompleteReal.filter(u => (now - new Date(u.authCreated).getTime()) >= 30 * day);

        console.log(`  - Last 7 days: ${recent.length}`);
        console.log(`  - Last 30 days: ${month.length}`);
        console.log(`  - Older than 30 days: ${old.length}`);

        console.log("\n📋 Sample of real incomplete users:");
        incompleteReal.slice(0, 10).forEach((u, i) => {
            console.log(`  ${i + 1}. ${u.name || '(no name)'}`);
            console.log(`     Phone: ${u.phone || 'none'}`);
            console.log(`     Email: ${u.email || 'none'}`);
            console.log(`     Created: ${u.authCreated}`);
            console.log(`     Last Sign In: ${u.authLastSignIn}`);
            console.log();
        });
    }

    // Test users breakdown
    console.log("\n" + "=".repeat(80));
    console.log("🧪 TEST USERS BREAKDOWN");
    console.log("=".repeat(80));
    console.log(`\nTotal test users: ${analysis.testUsers.length}`);
    console.log(`Test users in Auth only: ${incompleteTest.length}`);
    console.log(`Test users complete (Auth + Firestore): ${analysis.testUsers.filter(u => u.inFirestore).length}`);

    // Export to CSV
    console.log("\n\n" + "=".repeat(80));
    console.log("📄 EXPORTING TO CSV FILES");
    console.log("=".repeat(80));

    const csvDir = join(__dirname, '../analysis');
    const fs = await import('fs');
    if (!fs.existsSync(csvDir)) {
        fs.mkdirSync(csvDir, { recursive: true });
    }

    // Export all users
    const allUsersCsv = [
        'UID,Name,Phone,Email,Auth Created,Last Sign In,In Firestore,Firestore Created,Is Test,Has Astrology,Has Ayurveda,Profile Complete,Followers,Following,Posts'
    ];

    for (const user of [...analysis.completeUsers, ...analysis.authOnly]) {
        allUsersCsv.push([
            escapeCsv(user.uid),
            escapeCsv(user.name),
            escapeCsv(user.phone),
            escapeCsv(user.email),
            escapeCsv(user.authCreated),
            escapeCsv(user.authLastSignIn),
            user.inFirestore ? 'Yes' : 'No',
            escapeCsv(user.firestoreCreated),
            user.isTest ? 'Yes' : 'No',
            user.hasAstrology ? 'Yes' : 'No',
            user.hasAyurveda ? 'Yes' : 'No',
            user.hasProfileComplete ? 'Yes' : 'No',
            user.followersCount || 0,
            user.followingCount || 0,
            user.postsCount || 0,
        ].join(','));
    }

    const allUsersFile = join(csvDir, 'all_users.csv');
    writeFileSync(allUsersFile, allUsersCsv.join('\n'), 'utf8');
    console.log(`✓ All users exported to: ${allUsersFile}`);

    // Export incomplete users
    const incompleteCsv = [
        'UID,Name,Phone,Email,Auth Created,Last Sign In,Is Test,Days Since Signup'
    ];

    const now = Date.now();
    for (const user of analysis.authOnly) {
        const daysSince = Math.floor((now - new Date(user.authCreated).getTime()) / (24 * 60 * 60 * 1000));
        incompleteCsv.push([
            escapeCsv(user.uid),
            escapeCsv(user.name),
            escapeCsv(user.phone),
            escapeCsv(user.email),
            escapeCsv(user.authCreated),
            escapeCsv(user.authLastSignIn),
            user.isTest ? 'Yes' : 'No',
            daysSince,
        ].join(','));
    }

    const incompleteFile = join(csvDir, 'incomplete_users.csv');
    writeFileSync(incompleteFile, incompleteCsv.join('\n'), 'utf8');
    console.log(`✓ Incomplete users exported to: ${incompleteFile}`);

    // Export real users only
    const realUsersCsv = [
        'UID,Name,Phone,Email,Auth Created,Last Sign In,In Firestore,Firestore Created,Has Astrology,Has Ayurveda,Profile Complete,Followers,Following,Posts'
    ];

    for (const user of analysis.realUsers) {
        realUsersCsv.push([
            escapeCsv(user.uid),
            escapeCsv(user.name),
            escapeCsv(user.phone),
            escapeCsv(user.email),
            escapeCsv(user.authCreated),
            escapeCsv(user.authLastSignIn),
            user.inFirestore ? 'Yes' : 'No',
            escapeCsv(user.firestoreCreated),
            user.hasAstrology ? 'Yes' : 'No',
            user.hasAyurveda ? 'Yes' : 'No',
            user.hasProfileComplete ? 'Yes' : 'No',
            user.followersCount || 0,
            user.followingCount || 0,
            user.postsCount || 0,
        ].join(','));
    }

    const realUsersFile = join(csvDir, 'real_users.csv');
    writeFileSync(realUsersFile, realUsersCsv.join('\n'), 'utf8');
    console.log(`✓ Real users exported to: ${realUsersFile}`);

    // Export test users
    const testUsersCsv = [
        'UID,Name,Phone,Email,Auth Created,In Firestore'
    ];

    for (const user of analysis.testUsers) {
        testUsersCsv.push([
            escapeCsv(user.uid),
            escapeCsv(user.name),
            escapeCsv(user.phone),
            escapeCsv(user.email),
            escapeCsv(user.authCreated),
            user.inFirestore ? 'Yes' : 'No',
        ].join(','));
    }

    const testUsersFile = join(csvDir, 'test_users.csv');
    writeFileSync(testUsersFile, testUsersCsv.join('\n'), 'utf8');
    console.log(`✓ Test users exported to: ${testUsersFile}`);

    console.log("\n✅ Analysis complete! Check the backend/analysis/ directory for CSV files.");

    return analysis;
}

analyzeUsers()
    .then(() => {
        console.log("\n✅ Done!");
        process.exit(0);
    })
    .catch((error) => {
        console.error("❌ Error:", error);
        process.exit(1);
    });
