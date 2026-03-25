#!/usr/bin/env node

/**
 * Test to verify the Dasha date parsing fix
 */

console.log('\n=== TESTING DASHA DATE PARSING FIX ===\n');

// Simulate the OLD code (with timezone offset)
const parseDashaDateOLD = (value, offsetHours = 0) => {
    if (!value || typeof value !== "string") return null;
    const normalized = value.replace(" ", "T");
    const hasTimezone = /[zZ]$/.test(normalized) || /[+-]\d{2}:?\d{2}$/.test(normalized);
    const withZone = hasTimezone ? normalized : `${normalized}Z`;
    const parsed = new Date(withZone);
    if (Number.isNaN(parsed.getTime())) return null;

    // OLD: Apply offset if no timezone
    if (!hasTimezone && typeof offsetHours === "number" && offsetHours !== 0) {
        return new Date(parsed.getTime() - (offsetHours * 60 * 60 * 1000));
    }
    return parsed;
};

// Simulate the NEW code (without timezone offset)
const parseDashaDateNEW = (value, offsetHours = 0) => {
    if (!value || typeof value !== "string") return null;
    const normalized = value.replace(" ", "T");
    const hasTimezone = /[zZ]$/.test(normalized) || /[+-]\d{2}:?\d{2}$/.test(normalized);
    const withZone = hasTimezone ? normalized : `${normalized}Z`;
    const parsed = new Date(withZone);
    if (Number.isNaN(parsed.getTime())) return null;

    // NEW: Do NOT apply offset
    return parsed;
};

// Test with Mercury Antar Dasha end date from external app
const externalAppDate = "2026-10-06"; // What external apps show
const apiDateString = "2026-10-08 03:00:00"; // Example API response
const offsetHours = 5.5;

console.log('External App Expected:', externalAppDate);
console.log('API Date String:', apiDateString);
console.log('Timezone Offset:', offsetHours, 'hours (IST)\n');

console.log('--- OLD CODE (with offset) ---');
const oldResult = parseDashaDateOLD(apiDateString, offsetHours);
console.log('Parsed:', oldResult?.toISOString());
console.log('Display:', oldResult?.toLocaleDateString('en-GB'));
console.log('Difference from external:', Math.abs(new Date(externalAppDate) - oldResult) / (1000 * 60 * 60 * 24), 'days\n');

console.log('--- NEW CODE (without offset) ---');
const newResult = parseDashaDateNEW(apiDateString, offsetHours);
console.log('Parsed:', newResult?.toISOString());
console.log('Display:', newResult?.toLocaleDateString('en-GB'));
console.log('Difference from external:', Math.abs(new Date(externalAppDate) - newResult) / (1000 * 60 * 60 * 24), 'days\n');

// Test with the actual stored date
console.log('--- ACTUAL STORED DATA ---');
const storedDate = "2026-11-03T02:08:22.293Z";
const stored = new Date(storedDate);
console.log('Stored in Firestore:', storedDate);
console.log('Display:', stored.toLocaleDateString('en-GB'));
console.log('Difference from external:', Math.abs(new Date(externalAppDate) - stored) / (1000 * 60 * 60 * 24), 'days');
console.log('\n✅ This confirms the stored date is wrong by ~28 days\n');

// Calculate what the API should return to match external
console.log('--- EXPECTED API DATE ---');
const expectedUTC = new Date(externalAppDate + "T00:00:00Z");
console.log('If external shows Oct 6, 2026, API should return:', expectedUTC.toISOString().replace('T', ' ').replace('.000Z', ''));
console.log('Or close to that date\n');
