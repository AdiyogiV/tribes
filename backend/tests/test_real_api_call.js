#!/usr/bin/env node

/**
 * Test with REAL API call to verify the fix
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

const serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const API_KEY = process.env.FREE_ASTROLOGY_API_KEY;

// Your actual birth data
const payload = {
    year: 1998,
    month: 7,
    date: 31,
    hours: 19,
    minutes: 30,
    seconds: 0,
    latitude: 28.65195,
    longitude: 77.23149,
    timezone: 5.5
};

console.log('\n=== TESTING WITH REAL API CALL ===\n');
console.log('Birth Data:', JSON.stringify(payload, null, 2));

(async () => {
    if (!API_KEY) {
        console.log('❌ No API key found. Set FREE_ASTROLOGY_API_KEY environment variable.');
        console.log('\nSkipping live API test...');
        console.log('\nBased on documentation and previous tests:');
        console.log('- External apps show: Mercury ends Oct 6, 2026');
        console.log('- Our app currently shows: Mercury ends Nov 3, 2026');
        console.log('- Difference: ~28 days');
        console.log('\nThe fix removes the 5.5 hour offset that was causing this shift.');
        process.exit(0);
    }

    try {
        console.log('\n1. Calling FreeAstrologyAPI...\n');

        const response = await fetch('https://json.freeastrologyapi.com/vimsottari/maha-dasas-and-antar-dasas', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': API_KEY
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const text = await response.text();
            console.log('❌ API Error:', response.status);
            console.log(text.substring(0, 500));
            process.exit(1);
        }

        const data = await response.json();

        console.log('Raw API Response:', JSON.stringify(data, null, 2).substring(0, 2000));

        // Parse output if it's stringified JSON
        let parsedData = data;
        if (data.output && typeof data.output === 'string') {
            parsedData = JSON.parse(data.output);
        } else if (data.output) {
            parsedData = data.output;
        }

        // Find Saturn > Mercury
        const saturn = parsedData.Saturn || parsedData.output?.Saturn;
        if (!saturn || !saturn.sub_lords) {
            console.log('❌ Saturn or sub_lords not found in response');
            console.log('Response structure:', Object.keys(parsedData));
            console.log('\nFull parsed data:', JSON.stringify(parsedData, null, 2).substring(0, 3000));
            process.exit(1);
        }

        const mercury = saturn.sub_lords.Mercury;
        if (!mercury) {
            console.log('❌ Mercury not found in Saturn sub_lords');
            process.exit(1);
        }

        console.log('✅ API Response for Mercury Antar Dasha:\n');
        console.log('Start:', mercury.start_time);
        console.log('End:', mercury.end_time);

        // Test OLD parsing (with offset)
        console.log('\n--- OLD CODE (with 5.5h offset) ---');
        const oldParsed = new Date(mercury.end_time.replace(' ', 'T') + 'Z');
        const oldResult = new Date(oldParsed.getTime() - (5.5 * 60 * 60 * 1000));
        console.log('Parsed as UTC, then subtract 5.5h:', oldResult.toISOString());
        console.log('Display date (DD/MM/YYYY):', oldResult.toLocaleDateString('en-GB'));

        // Test NEW parsing (without offset)
        console.log('\n--- NEW CODE (no offset) ---');
        const newParsed = new Date(mercury.end_time.replace(' ', 'T') + 'Z');
        console.log('Parsed as UTC:', newParsed.toISOString());
        console.log('Display date (DD/MM/YYYY):', newParsed.toLocaleDateString('en-GB'));

        // Compare with external
        const externalDate = new Date('2026-10-06');
        console.log('\n--- COMPARISON ---');
        console.log('External app shows:', '06/10/2026');
        console.log('Old code difference:', Math.abs(oldResult - externalDate) / (1000 * 60 * 60 * 24), 'days');
        console.log('New code difference:', Math.abs(newParsed - externalDate) / (1000 * 60 * 60 * 24), 'days');

        if (Math.abs(newParsed - externalDate) / (1000 * 60 * 60 * 24) < 5) {
            console.log('\n✅ NEW CODE is correct (< 5 days difference)');
        } else {
            console.log('\n⚠️ NEW CODE still has issues');
        }

        // Show what's currently stored
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc('i6RGCDiUcjb7Gcl8QImnafj0quA3').get();
        const currentDasha = userDoc.data()?.currentDasha;

        if (currentDasha?.antarEndDate) {
            console.log('\n--- CURRENTLY STORED IN FIRESTORE ---');
            const stored = new Date(currentDasha.antarEndDate);
            console.log('Stored:', stored.toISOString());
            console.log('Display:', stored.toLocaleDateString('en-GB'));
            console.log('Difference from external:', Math.abs(stored - externalDate) / (1000 * 60 * 60 * 24), 'days');
            console.log('\n⚠️ This needs to be resynced after deploying the fix');
        }

        process.exit(0);

    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
})();
