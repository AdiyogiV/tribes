#!/usr/bin/env node

/**
 * Edge Case Testing for Dasha System
 * Tests various boundary conditions and edge cases
 */

// Colors for terminal output
const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    red: "\x1b[31m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    blue: "\x1b[34m",
    cyan: "\x1b[36m",
};

// Reproduce the exact backend parseDashaDate logic
function parseDashaDate(value, offsetHours = 0) {
    if (!value || typeof value !== "string") return null;
    const normalized = value.replace(" ", "T");

    const hasTimezone = /[zZ]$/.test(normalized) || /[+-]\d{2}:?\d{2}$/.test(normalized);

    const withZone = hasTimezone ? normalized : `${normalized}Z`;
    const parsed = new Date(withZone);
    if (Number.isNaN(parsed.getTime())) return null;

    if (!hasTimezone && typeof offsetHours === "number" && offsetHours !== 0) {
        return new Date(parsed.getTime() - (offsetHours * 60 * 60 * 1000));
    }
    return parsed;
}

function formatDashaDateForStorage(value, offsetHours = 0) {
    const parsed = parseDashaDate(value, offsetHours);
    return parsed ? parsed.toISOString() : (value || null);
}

// Frontend parse logic
function frontendParseDashaDate(raw) {
    if (!raw || typeof raw !== "string") return null;
    const normalized = raw.includes("T") ? raw : raw.replace(" ", "T");
    try {
        const parsed = new Date(normalized);
        if (isNaN(parsed.getTime())) return null;
        if (parsed.getFullYear() < 1900 || parsed.getFullYear() > 2100) return null;
        return parsed;
    } catch (e) {
        return null;
    }
}

const testCases = [
    {
        name: "Leap Year Feb 29",
        apiDate: "2024-02-29 12:00:00",
        timezone: 5.5,
        expectedUTC: "2024-02-29T06:30:00.000Z",
    },
    {
        name: "DST Transition (Spring Forward)",
        apiDate: "2024-03-10 02:30:00",
        timezone: -5,
        expectedUTC: "2024-03-10T07:30:00.000Z",
    },
    {
        name: "DST Transition (Fall Back)",
        apiDate: "2024-11-03 01:30:00",
        timezone: -5,
        expectedUTC: "2024-11-03T06:30:00.000Z",
    },
    {
        name: "Year Boundary (New Year)",
        apiDate: "2025-01-01 00:00:00",
        timezone: 5.5,
        expectedUTC: "2024-12-31T18:30:00.000Z",
    },
    {
        name: "Negative Timezone (West)",
        apiDate: "2024-06-15 14:00:00",
        timezone: -8,
        expectedUTC: "2024-06-15T22:00:00.000Z",
    },
    {
        name: "Positive Timezone (East)",
        apiDate: "2024-06-15 14:00:00",
        timezone: 9,
        expectedUTC: "2024-06-15T05:00:00.000Z",
    },
    {
        name: "Zero Offset (UTC)",
        apiDate: "2024-06-15 14:00:00",
        timezone: 0,
        expectedUTC: "2024-06-15T14:00:00.000Z",
    },
    {
        name: "Half-Hour Offset (India)",
        apiDate: "2024-06-15 14:00:00",
        timezone: 5.5,
        expectedUTC: "2024-06-15T08:30:00.000Z",
    },
    {
        name: "Quarter-Hour Offset (Nepal)",
        apiDate: "2024-06-15 14:00:00",
        timezone: 5.75,
        expectedUTC: "2024-06-15T08:15:00.000Z",
    },
    {
        name: "Large Positive Offset",
        apiDate: "2024-06-15 14:00:00",
        timezone: 12,
        expectedUTC: "2024-06-15T02:00:00.000Z",
    },
    {
        name: "Large Negative Offset",
        apiDate: "2024-06-15 14:00:00",
        timezone: -11,
        expectedUTC: "2024-06-16T01:00:00.000Z",
    },
    {
        name: "Midnight Boundary",
        apiDate: "2024-06-15 00:00:00",
        timezone: 5.5,
        expectedUTC: "2024-06-14T18:30:00.000Z",
    },
    {
        name: "End of Day",
        apiDate: "2024-06-15 23:59:59",
        timezone: 5.5,
        expectedUTC: "2024-06-15T18:29:59.000Z",
    },
    {
        name: "Century Boundary",
        apiDate: "2000-01-01 00:00:00",
        timezone: 5.5,
        expectedUTC: "1999-12-31T18:30:00.000Z",
    },
    {
        name: "Far Future Date",
        apiDate: "2099-12-31 23:59:59",
        timezone: 5.5,
        expectedUTC: "2099-12-31T18:29:59.000Z",
    },
];

console.log(`${colors.bright}${colors.cyan}
${"=".repeat(80)}
  EDGE CASE TESTING FOR DASHA SYSTEM
${"=".repeat(80)}
${colors.reset}\n`);

let passed = 0;
let failed = 0;

testCases.forEach((test, index) => {
    console.log(`${colors.bright}Test ${index + 1}/${testCases.length}: ${test.name}${colors.reset}`);
    console.log(`  Input: ${test.apiDate} (Offset: ${test.timezone > 0 ? '+' : ''}${test.timezone})`);

    // Step 1: Backend converts API date to UTC
    const converted = formatDashaDateForStorage(test.apiDate, test.timezone);
    console.log(`  Backend converted: ${converted}`);
    console.log(`  Expected:          ${test.expectedUTC}`);

    if (converted !== test.expectedUTC) {
        console.log(`  ${colors.red}✗ CONVERSION FAILED${colors.reset}\n`);
        failed++;
        return;
    }

    // Step 2: Backend reads from Firestore and determines current dasha
    // (should NOT apply offset again)
    const reRead = parseDashaDate(converted, test.timezone);
    const expected = new Date(test.expectedUTC);

    if (reRead.getTime() !== expected.getTime()) {
        console.log(`  ${colors.red}✗ RE-READ FAILED (double offset applied!)${colors.reset}`);
        console.log(`  Re-read: ${reRead.toISOString()}`);
        console.log(`  Expected: ${expected.toISOString()}\n`);
        failed++;
        return;
    }

    // Step 3: Frontend parses for display
    const frontendParsed = frontendParseDashaDate(converted);
    if (frontendParsed.getTime() !== expected.getTime()) {
        console.log(`  ${colors.red}✗ FRONTEND PARSE FAILED${colors.reset}`);
        console.log(`  Frontend: ${frontendParsed.toISOString()}`);
        console.log(`  Expected: ${expected.toISOString()}\n`);
        failed++;
        return;
    }

    console.log(`  ${colors.green}✓ PASSED${colors.reset}\n`);
    passed++;
});

console.log(`${colors.bright}${colors.cyan}
${"=".repeat(80)}
  EDGE CASE TEST SUMMARY
${"=".repeat(80)}
${colors.reset}`);

console.log(`\n  Total tests: ${testCases.length}`);
console.log(`  ${colors.green}Passed: ${passed}${colors.reset}`);
console.log(`  ${failed > 0 ? colors.red : colors.green}Failed: ${failed}${colors.reset}\n`);

if (failed === 0) {
    console.log(`${colors.bright}${colors.green}
${"=".repeat(80)}
  ✅ ALL EDGE CASES PASSED
${"=".repeat(80)}
${colors.reset}\n`);
    process.exit(0);
} else {
    console.log(`${colors.bright}${colors.red}
${"=".repeat(80)}
  ❌ SOME EDGE CASES FAILED
${"=".repeat(80)}
${colors.reset}\n`);
    process.exit(1);
}
