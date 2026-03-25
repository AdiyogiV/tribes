#!/usr/bin/env node

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

const serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
}

const db = admin.firestore();

async function listUsers() {
    console.log('\n🔍 Searching for users with astrology profiles...\n');

    const users = await db.collection('users')
        .where('astrologyData.birthDate', '!=', null)
        .limit(20)
        .get();

    if (users.empty) {
        console.log('❌ No users found with astrology data\n');
        process.exit(1);
    }

    console.log(`✅ Found ${users.size} users with astrology profiles:\n`);
    console.log('─'.repeat(100));
    console.log('UID'.padEnd(30) + 'Name'.padEnd(25) + 'Email/Phone'.padEnd(30) + 'Birth Date');
    console.log('─'.repeat(100));

    users.docs.forEach(doc => {
        const data = doc.data();
        const uid = doc.id;
        const name = data.name || 'N/A';
        const contact = data.email || data.phone || 'N/A';
        const birthDate = data.astrologyData?.birthDate || 'N/A';
        const mahadasha = data.astrologyData?.currentDasha?.mahadasha || 'N/A';
        const antardasha = data.astrologyData?.currentDasha?.antardasha || 'N/A';

        console.log(uid.substring(0, 28).padEnd(30) + name.substring(0, 23).padEnd(25) + contact.substring(0, 28).padEnd(30) + birthDate);
    });

    console.log('─'.repeat(100));
    console.log(`\n💡 To debug a specific user, run:`);
    console.log(`   node tests/debug_user_dasha.js <UID from above>\n`);

    process.exit(0);
}

listUsers();
