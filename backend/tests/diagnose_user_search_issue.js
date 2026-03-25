#!/usr/bin/env node

/**
 * Deep Diagnosis: Why is a user unsearchable?
 * Checks all possible reasons for search failure
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

const serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    red: "\x1b[31m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    cyan: "\x1b[36m",
};

async function diagnoseUser(searchTerm) {
    console.log(`${colors.bright}${colors.cyan}
${"=".repeat(80)}
  DEEP DIAGNOSIS: USER SEARCH ISSUE
${"=".repeat(80)}
${colors.reset}\n`);

    console.log(`${colors.cyan}Searching for: ${searchTerm}${colors.reset}\n`);

    // 1. Check if user document exists at all
    console.log(`${colors.cyan}STEP 1: Check if user document exists${colors.reset}`);
    const allUsers = await db.collection('users').get();
    console.log(`  Total users in database: ${allUsers.size}\n`);

    // Search by name, nickname, phone
    let foundUsers = [];
    for (const doc of allUsers.docs) {
        const data = doc.data();
        const name = (data.name || '').toLowerCase();
        const nickname = (data.nickname || '').toLowerCase();
        const phone = data.phoneNumber || data.phone || '';

        if (name.includes(searchTerm.toLowerCase()) ||
            nickname.includes(searchTerm.toLowerCase()) ||
            phone.includes(searchTerm)) {
            foundUsers.push({ id: doc.id, data });
        }
    }

    if (foundUsers.length === 0) {
        console.log(`${colors.red}  ❌ NO USER FOUND matching "${searchTerm}"${colors.reset}\n`);
        console.log(`${colors.yellow}  Possible reasons:${colors.reset}`);
        console.log(`    1. User document doesn't exist`);
        console.log(`    2. Name/nickname doesn't match search term`);
        console.log(`    3. Registration never completed\n`);
        return;
    }

    console.log(`${colors.green}  ✓ Found ${foundUsers.length} user(s):${colors.reset}\n`);

    for (const user of foundUsers) {
        console.log(`${colors.bright}  User ID: ${user.id}${colors.reset}`);
        console.log(`  Name: ${user.data.name || 'N/A'}`);
        console.log(`  Nickname: ${user.data.nickname || 'N/A'}`);
        console.log(`  Phone: ${user.data.phoneNumber || user.data.phone || 'N/A'}`);
        console.log(`  Email: ${user.data.email || 'N/A'}\n`);

        // 2. Check deletedUsers collection
        console.log(`${colors.cyan}STEP 2: Check if user is marked as deleted${colors.reset}`);
        const deletedDoc = await db.collection('deletedUsers').doc(user.id).get();
        if (deletedDoc.exists) {
            const deletedData = deletedDoc.data();
            console.log(`${colors.red}  ❌ User IS in deletedUsers collection!${colors.reset}`);
            console.log(`     Status: ${deletedData.status}`);
            console.log(`     Deleted at: ${deletedData.deletionRequestedAt?.toDate()}`);
            console.log(`     Phone: ${deletedData.phoneNumber || 'N/A'}\n`);
            console.log(`${colors.yellow}  ISSUE: Search filters out users in deletedUsers collection${colors.reset}\n`);
        } else {
            console.log(`${colors.green}  ✓ User is NOT in deletedUsers collection${colors.reset}\n`);
        }

        // 3. Check if there are OLD deletion records for same phone
        console.log(`${colors.cyan}STEP 3: Check for old deletion records (same phone)${colors.reset}`);
        const phone = user.data.phoneNumber || user.data.phone;
        if (phone) {
            const oldDeletions = await db.collection('deletedUsers')
                .where('phoneNumber', '==', phone)
                .get();

            if (oldDeletions.size > 0) {
                console.log(`${colors.yellow}  ⚠ Found ${oldDeletions.size} old deletion record(s) for this phone:${colors.reset}`);
                for (const oldDoc of oldDeletions.docs) {
                    const oldData = oldDoc.data();
                    console.log(`     Old UID: ${oldDoc.id}`);
                    console.log(`     Status: ${oldData.status}`);
                    console.log(`     Deleted: ${oldData.deletionRequestedAt?.toDate()}\n`);
                }
                console.log(`${colors.yellow}  ISSUE: Old deletion records exist but current UID is different${colors.reset}\n`);
            } else {
                console.log(`${colors.green}  ✓ No old deletion records found${colors.reset}\n`);
            }
        }

        // 4. Check phoneIndex
        console.log(`${colors.cyan}STEP 4: Check phoneIndex${colors.reset}`);
        if (phone) {
            // We need to hash the phone - simulate the hash function
            const crypto = await import('crypto');
            const normalized = phone.replace(/\D/g, ''); // Remove non-digits
            const hash = crypto.createHash('sha256').update(normalized).digest('hex');

            const phoneIndexDoc = await db.collection('phoneIndex').doc(hash).get();
            if (phoneIndexDoc.exists) {
                const indexData = phoneIndexDoc.data();
                if (indexData.userId === user.id) {
                    console.log(`${colors.green}  ✓ phoneIndex correct (points to current UID)${colors.reset}\n`);
                } else {
                    console.log(`${colors.red}  ❌ phoneIndex points to WRONG UID!${colors.reset}`);
                    console.log(`     Points to: ${indexData.userId}`);
                    console.log(`     Should be: ${user.id}\n`);
                    console.log(`${colors.yellow}  ISSUE: phoneIndex not updated after account recreation${colors.reset}\n`);
                }
            } else {
                console.log(`${colors.red}  ❌ phoneIndex entry MISSING!${colors.reset}\n`);
                console.log(`${colors.yellow}  ISSUE: User not discoverable via phone contacts${colors.reset}\n`);
            }
        }

        // 5. Check name and nickname fields
        console.log(`${colors.cyan}STEP 5: Check name/nickname fields for search${colors.reset}`);
        const name = user.data.name;
        const nickname = user.data.nickname;

        if (!name || name.trim() === '') {
            console.log(`${colors.red}  ❌ Name field is EMPTY or missing${colors.reset}\n`);
            console.log(`${colors.yellow}  ISSUE: Search queries 'name' field - won't find empty names${colors.reset}\n`);
        } else {
            console.log(`${colors.green}  ✓ Name field exists: "${name}"${colors.reset}\n`);
        }

        if (!nickname || nickname.trim() === '') {
            console.log(`${colors.red}  ❌ Nickname field is EMPTY or missing${colors.reset}\n`);
            console.log(`${colors.yellow}  ISSUE: Search queries 'nickname' field - won't find empty nicknames${colors.reset}\n`);
        } else {
            console.log(`${colors.green}  ✓ Nickname field exists: "${nickname}"${colors.reset}\n`);
        }

        // 6. Check timestamps
        console.log(`${colors.cyan}STEP 6: Check account creation timestamp${colors.reset}`);
        const timestamp = user.data.timestamp;
        if (timestamp) {
            const createdAt = timestamp.toDate();
            const now = new Date();
            const ageMinutes = Math.floor((now - createdAt) / (1000 * 60));
            console.log(`  Account created: ${createdAt.toISOString()}`);
            console.log(`  Age: ${ageMinutes} minutes ago\n`);

            if (ageMinutes < 5) {
                console.log(`${colors.yellow}  ⚠ Account is VERY NEW (< 5 minutes)${colors.reset}`);
                console.log(`     Possible indexing delay\n`);
            }
        } else {
            console.log(`${colors.red}  ❌ No timestamp field found${colors.reset}\n`);
        }

        // 7. Simulate search query
        console.log(`${colors.cyan}STEP 7: Simulate Firestore search query${colors.reset}`);
        const searchLower = searchTerm.toLowerCase();

        // Query 1: name prefix
        const nameQuery = await db.collection('users')
            .where('name', '>=', searchLower)
            .where('name', '<', searchLower + '\uf8ff')
            .get();
        console.log(`  Name prefix query: ${nameQuery.size} result(s)`);

        // Query 2: nickname prefix
        const nicknameQuery = await db.collection('users')
            .where('nickname', '>=', searchLower)
            .where('nickname', '<', searchLower + '\uf8ff')
            .get();
        console.log(`  Nickname prefix query: ${nicknameQuery.size} result(s)\n`);

        const foundInName = nameQuery.docs.some(d => d.id === user.id);
        const foundInNickname = nicknameQuery.docs.some(d => d.id === user.id);

        if (!foundInName && !foundInNickname) {
            console.log(`${colors.red}  ❌ User NOT found in Firestore prefix queries${colors.reset}\n`);
            console.log(`${colors.yellow}  ISSUE: Firestore queries use prefix matching${colors.reset}`);
            console.log(`     Search term: "${searchLower}"`);
            console.log(`     User name: "${(name || '').toLowerCase()}"`);
            console.log(`     User nickname: "${(nickname || '').toLowerCase()}"`);
            console.log(`     Name starts with search? ${(name || '').toLowerCase().startsWith(searchLower)}`);
            console.log(`     Nickname starts with search? ${(nickname || '').toLowerCase().startsWith(searchLower)}\n`);
        } else {
            console.log(`${colors.green}  ✓ User IS found in Firestore queries${colors.reset}\n`);
        }

        console.log(`${colors.cyan}${"=".repeat(80)}${colors.reset}\n`);
        console.log(`${colors.bright}SUMMARY FOR ${user.data.name}:${colors.reset}\n`);

        const issues = [];

        if (deletedDoc.exists) {
            issues.push("❌ User is in deletedUsers collection");
        }

        const oldDeletions = await db.collection('deletedUsers')
            .where('phoneNumber', '==', phone)
            .get();
        if (oldDeletions.size > 0 && !deletedDoc.exists) {
            issues.push("⚠️  Old deletion records exist (different UID)");
        }

        if (phone) {
            const crypto = await import('crypto');
            const normalized = phone.replace(/\D/g, '');
            const hash = crypto.createHash('sha256').update(normalized).digest('hex');
            const phoneIndexDoc = await db.collection('phoneIndex').doc(hash).get();

            if (!phoneIndexDoc.exists) {
                issues.push("❌ phoneIndex entry missing");
            } else if (phoneIndexDoc.data().userId !== user.id) {
                issues.push("❌ phoneIndex points to wrong UID");
            }
        }

        if (!name || name.trim() === '') {
            issues.push("❌ Name field empty");
        }

        if (!nickname || nickname.trim() === '') {
            issues.push("❌ Nickname field empty");
        }

        if (!foundInName && !foundInNickname) {
            issues.push("❌ Not found in Firestore prefix queries");
        }

        if (issues.length === 0) {
            console.log(`${colors.green}  ✅ NO ISSUES FOUND - User should be searchable!${colors.reset}\n`);
        } else {
            console.log(`${colors.red}  Found ${issues.length} issue(s):${colors.reset}\n`);
            issues.forEach(issue => console.log(`    ${issue}`));
            console.log();
        }
    }

    process.exit(0);
}

const searchTerm = process.argv[2];
if (!searchTerm) {
    console.log(`${colors.yellow}Usage: node diagnose_user_search_issue.js <name|phone|nickname>${colors.reset}\n`);
    process.exit(1);
}

diagnoseUser(searchTerm);
