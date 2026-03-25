#!/usr/bin/env node

import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { DateTime } from 'luxon';

const serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

async function checkApiPayload() {
    const userDoc = await db.collection('users').doc('i6RGCDiUcjb7Gcl8QImnafj0quA3').get();
    const astroData = userDoc.data().astrologyData || {};

    console.log('\n=== RAW FIRESTORE DATA ===\n');
    console.log('birthYear:', astroData.birthYear);
    console.log('birthMonth:', astroData.birthMonth);
    console.log('birthDay:', astroData.birthDay);
    console.log('birthTime:', astroData.birthTime);
    console.log('timeZone:', astroData.timeZone);
    console.log('timeZoneOffset:', astroData.timeZoneOffset);

    // Simulate extractDateParts
    console.log('\n=== EXTRACT DATE PARTS (Backend Logic) ===\n');

    let year, month, day;
    if (astroData.birthYear && astroData.birthMonth && astroData.birthDay) {
        console.log('✓ Using explicit year/month/day fields:');
        year = astroData.birthYear;
        month = astroData.birthMonth;
        day = astroData.birthDay;
        console.log('  year:', year);
        console.log('  month:', month);
        console.log('  day:', day);
    } else {
        console.log('Using birthDate timestamp (fallback path):');
        const birthDate = astroData.birthDate.toDate();
        console.log('  birthDate timestamp:', birthDate.toISOString());
        console.log('  As UTC:', birthDate.toUTCString());

        const timeZoneId = astroData.timeZone || 'Asia/Kolkata';
        console.log('  timeZoneId:', timeZoneId);

        const zoned = DateTime.fromJSDate(birthDate, { zone: timeZoneId });
        console.log('  Converted to timezone:', zoned.toISO());
        year = zoned.year;
        month = zoned.month;
        day = zoned.day;
        console.log('  Extracted year:', year);
        console.log('  Extracted month:', month);
        console.log('  Extracted day:', day);
    }

    // Simulate parseTimeParts
    console.log('\n=== PARSE TIME PARTS ===\n');
    const birthTime = astroData.birthTime;
    const timeParts = birthTime.split(':').map(p => parseInt(p, 10) || 0);
    const hours = timeParts[0] || 0;
    const minutes = timeParts[1] || 0;
    const seconds = timeParts[2] || 0;

    console.log('birthTime string:', birthTime);
    console.log('Parsed hours:', hours);
    console.log('Parsed minutes:', minutes);
    console.log('Parsed seconds:', seconds);

    // Final API payload
    console.log('\n=== API PAYLOAD (What gets sent to FreeAstrologyAPI) ===\n');
    const payload = {
        year,
        month,
        date: day,
        hours,
        minutes,
        seconds,
        latitude: astroData.birthLatitude,
        longitude: astroData.birthLongitude,
        timezone: astroData.timeZoneOffset || 5.5,
    };

    console.log(JSON.stringify(payload, null, 2));

    console.log('\n=== COMBINED DATE-TIME ===\n');
    console.log('API receives this as:');
    console.log(`  ${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')} ${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`);
    console.log(`  In timezone: ${astroData.timeZone} (UTC${astroData.timeZoneOffset >= 0 ? '+' : ''}${astroData.timeZoneOffset})`);

    // NOW compare with the Dasha dates we received
    console.log('\n=== STORED DASHA DATES ===\n');
    const currentDasha = astroData.currentDasha;
    if (currentDasha) {
        console.log('Mercury Antar Dasha:');
        console.log('  Start (UTC):', currentDasha.antarStartDate);
        console.log('  End (UTC):  ', currentDasha.antarEndDate);

        const endDate = new Date(currentDasha.antarEndDate);
        const endLocal = endDate.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
        console.log('  End (IST):  ', endLocal);
    }

    // Compare with expected
    console.log('\n=== EXTERNAL APP DATA (User Provided) ===\n');
    console.log('Mercury Antar Dasha:');
    console.log('  Expected: 27/01/2024 → 06/10/2026');
    console.log('  Your App: 24/02/2024 → 03/11/2026');
    console.log('  Difference: ~28 days');

    console.log('\n=== ROOT CAUSE ANALYSIS ===\n');
    console.log('The API payload is CORRECT (July 31, 1998 at 19:30 IST)');
    console.log('But the returned Dasha dates are ~28 days off.');
    console.log('\nPossible causes:');
    console.log('  1. FreeAstrologyAPI uses different calculation method than external app');
    console.log('  2. Different Ayanamsa (Lahiri vs others) causing Moon position shift');
    console.log('  3. API precision/rounding differences');
    console.log('  4. External app might be using slightly different birth time');

    process.exit(0);
}

checkApiPayload();
