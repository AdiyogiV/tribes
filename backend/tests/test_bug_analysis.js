#!/usr/bin/env node

/**
 * Analyze the ACTUAL bug in the Jan 5 "fix"
 */

console.log('\n=== BUG ANALYSIS ===\n');

const apiDate = "2026-10-08 08:30:00"; // What API returns (IST time)
const offsetHours = 5.5;

console.log('API returns:', apiDate, '(in IST/local time)');
console.log('Timezone offset:', offsetHours, 'hours\n');

// OLD CODE (before Jan 5)
console.log('--- OLD CODE (before Jan 5) ---');
const normalized1 = apiDate.replace(" ", "T");
console.log('1. Normalize:', normalized1);
const withZone1 = /[zZ]$/.test(normalized1) ? normalized1 : `${normalized1}Z`;
console.log('2. Add Z:', withZone1);
const parsed1 = new Date(withZone1);
console.log('3. Parse as UTC:', parsed1.toISOString());
// OLD: Always subtract if offset is provided
const result1 = new Date(parsed1.getTime() - (offsetHours * 60 * 60 * 1000));
console.log('4. Subtract', offsetHours, 'hours:', result1.toISOString());
console.log('5. Display:', result1.toLocaleDateString('en-GB'), '\n');

// NEW CODE (after Jan 5 "fix")
console.log('--- NEW CODE (after Jan 5 "fix") ---');
const normalized2 = apiDate.replace(" ", "T");
console.log('1. Normalize:', normalized2);
const hasTimezone = /[zZ]$/.test(normalized2) || /[+-]\d{2}:?\d{2}$/.test(normalized2);
console.log('2. Has timezone?', hasTimezone);
const withZone2 = hasTimezone ? normalized2 : `${normalized2}Z`;
console.log('3. Add Z:', withZone2);
const parsed2 = new Date(withZone2);
console.log('4. Parse as UTC:', parsed2.toISOString());
// Check AGAIN after adding Z
const hasTimezoneAfterZ = /[zZ]$/.test(withZone2) || /[+-]\d{2}:?\d{2}$/.test(withZone2);
console.log('5. Has timezone after adding Z?', hasTimezoneAfterZ);
// NEW: Only subtract if !hasTimezone
if (!hasTimezoneAfterZ && offsetHours !== 0) {
    const result2 = new Date(parsed2.getTime() - (offsetHours * 60 * 60 * 1000));
    console.log('6. Subtract', offsetHours, 'hours:', result2.toISOString());
} else {
    console.log('6. ❌ SKIPPING offset subtraction because hasTimezone =', hasTimezoneAfterZ);
    console.log('   Final result:', parsed2.toISOString());
    console.log('   Display:', parsed2.toLocaleDateString('en-GB'));
}

console.log('\n--- THE BUG ---');
console.log('The "fix" checks hasTimezone AFTER adding Z to the string!');
console.log('So API dates like "2026-10-08 08:30:00" become "2026-10-08T08:30:00Z"');
console.log('Then hasTimezone = TRUE, so offset is NOT subtracted.');
console.log('This means IST times are treated as UTC, causing ~6 hour shifts.');
console.log('\nOct 8, 2026 08:30 IST = Oct 8, 2026 03:00 UTC');
console.log('But the new code treats it as Oct 8, 2026 08:30 UTC (WRONG!)');

console.log('\n--- EXPECTED vs ACTUAL ---');
console.log('External apps:', '06/10/2026');
console.log('Old code result:', result1.toLocaleDateString('en-GB'), '(2 days off - acceptable)');
console.log('New code result:', parsed2.toLocaleDateString('en-GB'), '(should match old code)');

// But wait, that's only a 5.5 hour difference, not 28 days!
console.log('\n--- WAIT, THERE\'S MORE ---');
console.log('5.5 hour difference can\'t cause 28 days!');
console.log('Let me check if the API itself returns different dates...\n');
