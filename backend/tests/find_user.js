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

const searchTerm = process.argv[2];

if (!searchTerm) {
    console.log('\n❌ Please provide a search term');
    console.log('   Usage: node find_user.js <name or phone>\n');
    process.exit(1);
}

async function findUser() {
    console.log(`\n🔍 Searching for users matching "${searchTerm}"...\n`);

    // Try case variations
    const variations = [
        searchTerm,
        searchTerm.charAt(0).toUpperCase() + searchTerm.slice(1).toLowerCase(),
        searchTerm.toUpperCase(),
        searchTerm.toLowerCase()
    ];

    const allMatches = [];

    for (const variant of variations) {
        const users = await db.collection('users')
            .where('name', '>=', variant)
            .where('name', '<=', variant + '\uf8ff')
            .limit(10)
            .get();

        users.docs.forEach(doc => {
            if (!allMatches.find(m => m.id === doc.id)) {
                allMatches.push(doc);
            }
        });
    }

    // Also try phone search if it's all digits
    if (/^\d+$/.test(searchTerm)) {
        const phoneVariants = [searchTerm, `+91${searchTerm}`, `+91 ${searchTerm}`];
        for (const phoneVar of phoneVariants) {
            const users = await db.collection('users')
                .where('phone', '==', phoneVar)
                .limit(5)
                .get();

            users.docs.forEach(doc => {
                if (!allMatches.find(m => m.id === doc.id)) {
                    allMatches.push(doc);
                }
            });
        }
    }

    if (allMatches.length === 0) {
        console.log(`❌ No users found matching "${searchTerm}"\n`);
        process.exit(1);
    }

    console.log(`✅ Found ${allMatches.length} user(s):\n`);
    console.log('─'.repeat(110));
    console.log('UID'.padEnd(30) + 'Name'.padEnd(25) + 'Email/Phone'.padEnd(30) + 'Has Astrology?');
    console.log('─'.repeat(110));

    allMatches.forEach(doc => {
        const data = doc.data();
        const uid = doc.id;
        const name = data.name || 'N/A';
        const contact = data.email || data.phone || 'N/A';
        const hasAstro = data.astrologyData?.birthDate ? '✅ Yes' : '❌ No';

        console.log(uid.substring(0, 28).padEnd(30) + name.substring(0, 23).padEnd(25) + contact.substring(0, 28).padEnd(30) + hasAstro);
    });

    console.log('─'.repeat(110));
    console.log(`\n💡 To debug astrology data, run:`);
    console.log(`   node tests/debug_user_dasha.js <UID from above>\n`);

    process.exit(0);
}

findUser();
