#!/usr/bin/env node

/**
 * Debug actual user's Dasha data from Firestore
 * This will show what's actually stored vs what should be stored
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

const serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));

// Initialize Firebase Admin
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
}

const db = admin.firestore();

const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    red: "\x1b[31m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    cyan: "\x1b[36m",
};

async function debugUserDasha(userIdOrEmail) {
    console.log(`${colors.bright}${colors.cyan}
${"=".repeat(80)}
  DEBUGGING USER'S ACTUAL DASHA DATA
${"=".repeat(80)}
${colors.reset}\n`);

    try {
        // Find user by email, phone, or UID
        let userDoc;
        if (userIdOrEmail.includes('@')) {
            console.log(`${colors.cyan}Searching for user by email: ${userIdOrEmail}${colors.reset}\n`);
            const usersSnapshot = await db.collection('users')
                .where('email', '==', userIdOrEmail)
                .limit(1)
                .get();

            if (usersSnapshot.empty) {
                console.log(`${colors.red}No user found with email: ${userIdOrEmail}${colors.reset}\n`);
                return;
            }
            userDoc = usersSnapshot.docs[0];
        } else if (/^\d+$/.test(userIdOrEmail)) {
            // Phone number - try multiple formats
            console.log(`${colors.cyan}Searching for user by phone: ${userIdOrEmail}${colors.reset}\n`);

            // Try exact match
            let usersSnapshot = await db.collection('users')
                .where('phone', '==', userIdOrEmail)
                .limit(1)
                .get();

            // Try with +91 prefix
            if (usersSnapshot.empty) {
                console.log(`  Trying with +91 prefix...`);
                usersSnapshot = await db.collection('users')
                    .where('phone', '==', `+91${userIdOrEmail}`)
                    .limit(1)
                    .get();
            }

            // Try with +91 and space
            if (usersSnapshot.empty) {
                console.log(`  Trying with +91 and space...`);
                usersSnapshot = await db.collection('users')
                    .where('phone', '==', `+91 ${userIdOrEmail}`)
                    .limit(1)
                    .get();
            }

            if (usersSnapshot.empty) {
                console.log(`${colors.red}No user found with phone: ${userIdOrEmail} (tried multiple formats)${colors.reset}\n`);
                return;
            }
            userDoc = usersSnapshot.docs[0];
        } else {
            // Try as UID first
            console.log(`${colors.cyan}Trying as UID: ${userIdOrEmail}${colors.reset}\n`);
            userDoc = await db.collection('users').doc(userIdOrEmail).get();

            if (!userDoc.exists) {
                // Try searching by name (case-insensitive by trying different cases)
                console.log(`  Not found as UID, searching by name...`);
                let usersSnapshot = await db.collection('users')
                    .where('name', '>=', userIdOrEmail)
                    .where('name', '<=', userIdOrEmail + '\uf8ff')
                    .limit(5)
                    .get();

                // Try with capitalized first letter
                if (usersSnapshot.empty) {
                    const capitalized = userIdOrEmail.charAt(0).toUpperCase() + userIdOrEmail.slice(1).toLowerCase();
                    console.log(`  Trying with capitalized name: ${capitalized}...`);
                    usersSnapshot = await db.collection('users')
                        .where('name', '>=', capitalized)
                        .where('name', '<=', capitalized + '\uf8ff')
                        .limit(5)
                        .get();
                }

                if (usersSnapshot.empty) {
                    console.log(`${colors.red}No user found with UID or name: ${userIdOrEmail}${colors.reset}\n`);
                    return;
                }

                // If multiple users found, list them
                if (usersSnapshot.size > 1) {
                    console.log(`\n${colors.yellow}Found ${usersSnapshot.size} users matching "${userIdOrEmail}":${colors.reset}`);
                    usersSnapshot.docs.forEach((doc, idx) => {
                        const data = doc.data();
                        console.log(`  ${idx + 1}. ${data.name} (${doc.id}) - ${data.email || data.phone || 'N/A'}`);
                    });
                    console.log(`\n${colors.cyan}Using first match: ${usersSnapshot.docs[0].data().name}${colors.reset}\n`);
                }

                userDoc = usersSnapshot.docs[0];
            }
        }

        const userData = userDoc.data();
        const userId = userDoc.id;

        console.log(`${colors.green}✓ User found: ${userId}${colors.reset}`);
        console.log(`  Name: ${userData.name || 'N/A'}`);
        console.log(`  Email: ${userData.email || 'N/A'}\n`);

        // Get astrology data
        const astroData = userData.astrologyData || {};

        console.log(`${colors.cyan}BIRTH DETAILS:${colors.reset}`);
        if (astroData.birthDate) {
            console.log(`  Date: ${astroData.birthDate}`);
        }
        if (astroData.birthTime) {
            console.log(`  Time: ${astroData.birthTime}`);
        }
        if (astroData.birthPlace) {
            console.log(`  Place: ${astroData.birthPlace}`);
        }
        if (astroData.timezone) {
            console.log(`  Timezone: ${astroData.timezone}`);
        }
        console.log();

        // Get current Dasha
        const currentDasha = astroData.currentDasha || {};

        console.log(`${colors.cyan}CURRENT DASHA DATA IN FIRESTORE:${colors.reset}\n`);

        console.log(`  ${colors.bright}Maha Dasha:${colors.reset} ${currentDasha.mahadasha || 'N/A'}`);
        console.log(`    Start: ${currentDasha.mahaStartDate || 'N/A'}`);
        console.log(`    End:   ${currentDasha.mahaEndDate || 'N/A'}\n`);

        console.log(`  ${colors.bright}Antar Dasha:${colors.reset} ${currentDasha.antardasha || 'N/A'}`);
        console.log(`    Start: ${currentDasha.antarStartDate || 'N/A'}`);
        console.log(`    End:   ${currentDasha.antarEndDate || 'N/A'}\n`);

        // Check if dates are in correct format
        const checkDateFormat = (dateStr, label) => {
            if (!dateStr) return;
            const hasZ = dateStr.endsWith('Z');
            const isISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(dateStr);
            const color = (hasZ && isISO) ? colors.green : colors.red;
            const symbol = (hasZ && isISO) ? '✓' : '✗';
            console.log(`    ${color}${symbol} ${label}: ${dateStr}${colors.reset}`);
            if (!hasZ) console.log(`      ${colors.yellow}⚠ Missing 'Z' suffix - may cause timezone issues!${colors.reset}`);
            if (!isISO) console.log(`      ${colors.yellow}⚠ Not in ISO 8601 format!${colors.reset}`);
        };

        console.log(`${colors.cyan}DATE FORMAT VERIFICATION:${colors.reset}`);
        checkDateFormat(currentDasha.mahaStartDate, 'Maha Start');
        checkDateFormat(currentDasha.mahaEndDate, 'Maha End');
        checkDateFormat(currentDasha.antarStartDate, 'Antar Start');
        checkDateFormat(currentDasha.antarEndDate, 'Antar End');
        console.log();

        // Show how frontend would display the antar end date
        if (currentDasha.antarEndDate) {
            console.log(`${colors.cyan}FRONTEND DISPLAY:${colors.reset}`);
            try {
                const endDate = new Date(currentDasha.antarEndDate);
                const localDate = endDate.toLocaleString('en-IN', {
                    timeZone: 'Asia/Kolkata',
                    day: '2-digit',
                    month: '2-digit',
                    year: 'numeric'
                });
                console.log(`  User sees Antar end as: ${localDate} (DD/MM/YYYY format)`);
                console.log(`  Stored in Firestore as: ${currentDasha.antarEndDate}`);
                console.log(`  Parsed as Date object:  ${endDate.toISOString()}\n`);
            } catch (e) {
                console.log(`  ${colors.red}Error parsing date: ${e.message}${colors.reset}\n`);
            }
        }

        // Check all Antar Dashas for current Maha
        console.log(`${colors.cyan}ALL ANTAR DASHAS (if available):${colors.reset}\n`);
        const allMahas = currentDasha.allMahaDashas || [];
        const currentMaha = allMahas.find(m => m.lord === currentDasha.mahadasha);

        if (currentMaha && currentMaha.antarDashas) {
            console.log(`  Found ${currentMaha.antarDashas.length} Antar Dashas for ${currentMaha.lord}:\n`);
            console.log(`  ${"Planet".padEnd(12)} ${"Start Date".padEnd(30)} ${"End Date".padEnd(30)}`);
            console.log(`  ${"-".repeat(74)}`);

            for (const antar of currentMaha.antarDashas) {
                const isCurrentAntar = antar.lord === currentDasha.antardasha;
                const color = isCurrentAntar ? colors.green + colors.bright : colors.reset;
                const marker = isCurrentAntar ? '→ ' : '  ';

                // Convert to DD/MM/YYYY for display
                let startDisplay = antar.startDate || 'N/A';
                let endDisplay = antar.endDate || 'N/A';

                try {
                    if (antar.startDate) {
                        const d = new Date(antar.startDate);
                        startDisplay = `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`;
                    }
                    if (antar.endDate) {
                        const d = new Date(antar.endDate);
                        endDisplay = `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`;
                    }
                } catch (e) { }

                console.log(`${color}${marker}${antar.lord.padEnd(12)} ${startDisplay.padEnd(30)} ${endDisplay.padEnd(30)}${colors.reset}`);
            }
            console.log();
        } else {
            console.log(`  ${colors.yellow}No Antar Dasha data found${colors.reset}\n`);
        }

        // Check last updated
        if (astroData.lastCalculated) {
            console.log(`${colors.cyan}LAST UPDATED:${colors.reset}`);
            console.log(`  ${astroData.lastCalculated}`);
            const lastCalc = new Date(astroData.lastCalculated);
            const daysSince = Math.floor((Date.now() - lastCalc.getTime()) / (1000 * 60 * 60 * 24));
            console.log(`  (${daysSince} days ago)\n`);
        }

        console.log(`${colors.bright}${colors.cyan}${"=".repeat(80)}${colors.reset}\n`);

    } catch (error) {
        console.error(`${colors.red}Error:${colors.reset}`, error.message);
        console.error(error.stack);
    } finally {
        process.exit(0);
    }
}

// Get user ID or email from command line
const userIdOrEmail = process.argv[2];

if (!userIdOrEmail) {
    console.log(`${colors.yellow}Usage: node debug_user_dasha.js <userId or email>${colors.reset}`);
    console.log(`${colors.yellow}Example: node debug_user_dasha.js abhinavvashisht@gmail.com${colors.reset}\n`);
    process.exit(1);
}

debugUserDasha(userIdOrEmail);
