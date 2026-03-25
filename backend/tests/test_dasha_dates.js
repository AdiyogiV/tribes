/**
 * Dasha Date Calculation Audit Test
 * 
 * This test verifies the correctness of the Dasha date parsing and storage.
 * 
 * FIXED BUG: The timezone offset was being applied TWICE to Antar Dasha dates:
 * 1. First in buildAntarDashas → formatDashaDateForStorage (correct)
 * 2. Second in the currentAntar.find() comparison (WAS WRONG, NOW FIXED!)
 * 
 * Run with: node tests/test_dasha_dates.js
 */

// ANSI colors
const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    green: "\x1b[32m",
    red: "\x1b[31m",
    yellow: "\x1b[33m",
    cyan: "\x1b[36m",
};

function log(message, color = "reset") {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function logTest(name, passed, details = "") {
    const status = passed ? "✓ PASS" : "✗ FAIL";
    const color = passed ? "green" : "red";
    log(`  ${status}: ${name}`, color);
    if (details) console.log(`    → ${details}`);
}

// ============================================================================
// OLD BUGGY VERSION (for comparison)
// ============================================================================

const parseDashaDatBuggy = (value, offsetHours = 0) => {
    if (!value || typeof value !== "string") return null;
    const normalized = value.replace(" ", "T");
    const withZone = /[zZ]$/.test(normalized) ? normalized : `${normalized}Z`;
    const parsed = new Date(withZone);
    if (Number.isNaN(parsed.getTime())) return null;
    if (typeof offsetHours === "number" && offsetHours !== 0) {
        return new Date(parsed.getTime() - (offsetHours * 60 * 60 * 1000));
    }
    return parsed;
};

const formatDashaDateForStorageBuggy = (value, offsetHours = 0) => {
    const parsed = parseDashaDatBuggy(value, offsetHours);
    return parsed ? parsed.toISOString() : (value || null);
};

// ============================================================================
// FIXED VERSION (now deployed in production)
// ============================================================================

const parseDashaDateFixed = (value, offsetHours = 0) => {
    if (!value || typeof value !== "string") return null;
    const normalized = value.replace(" ", "T");

    // Check if the date already has a timezone indicator (Z, +HH:MM, -HH:MM)
    const hasTimezone = /[zZ]$/.test(normalized) || /[+-]\d{2}:?\d{2}$/.test(normalized);

    const withZone = hasTimezone ? normalized : `${normalized}Z`;
    const parsed = new Date(withZone);
    if (Number.isNaN(parsed.getTime())) return null;

    // CRITICAL FIX: Only apply offset if the original string didn't have a timezone
    // If it already had a TZ (like stored ISO strings), the offset was already applied
    if (!hasTimezone && typeof offsetHours === "number" && offsetHours !== 0) {
        return new Date(parsed.getTime() - (offsetHours * 60 * 60 * 1000));
    }
    return parsed;
};

const formatDashaDateForStorageFixed = (value, offsetHours = 0) => {
    const parsed = parseDashaDateFixed(value, offsetHours);
    return parsed ? parsed.toISOString() : (value || null);
};

// ============================================================================
// TEST CASES
// ============================================================================

function runTests() {
    log("\n" + "=".repeat(80), "bright");
    log("  DASHA DATE CALCULATION AUDIT", "bright");
    log("=".repeat(80) + "\n", "bright");

    let passed = 0;
    let total = 0;

    // Test data: IST timezone (UTC+5.5)
    const offsetHours = 5.5;

    // Simulated API response date (local time, no TZ marker)
    const apiDate = "2024-01-15 10:30:00";

    // Expected UTC: 10:30 IST = 05:00 UTC
    const expectedUtcMs = Date.parse("2024-01-15T05:00:00.000Z");

    log("TEST 1: Initial conversion from API date", "cyan");
    log(`  API Date (local): "${apiDate}"`, "yellow");
    log(`  Offset: ${offsetHours}h (IST = UTC+5.5)`, "yellow");
    log(`  Expected UTC: 2024-01-15T05:00:00.000Z\n`, "yellow");

    // Test 1a: Buggy version - first conversion
    total++;
    const buggyFirst = parseDashaDatBuggy(apiDate, offsetHours);
    const buggyFirstCorrect = buggyFirst && buggyFirst.getTime() === expectedUtcMs;
    logTest("Buggy version - first conversion", buggyFirstCorrect,
        `Got: ${buggyFirst?.toISOString()}`);
    if (buggyFirstCorrect) passed++;

    // Test 1b: Fixed version - first conversion
    total++;
    const fixedFirst = parseDashaDateFixed(apiDate, offsetHours);
    const fixedFirstCorrect = fixedFirst && fixedFirst.getTime() === expectedUtcMs;
    logTest("Fixed version - first conversion", fixedFirstCorrect,
        `Got: ${fixedFirst?.toISOString()}`);
    if (fixedFirstCorrect) passed++;

    // Store as ISO (simulating what formatDashaDateForStorage does)
    const storedIso = "2024-01-15T05:00:00.000Z";
    log(`\nStored ISO string: "${storedIso}"`, "yellow");

    log("\nTEST 2: Second parse of ALREADY CONVERTED ISO string", "cyan");
    log("  (This simulates the currentAntar.find() comparison)\n", "yellow");

    // Test 2a: Demonstrate the old bug (for documentation)
    total++;
    const buggySecond = parseDashaDatBuggy(storedIso, offsetHours);
    const buggySecondWrongMs = Date.parse("2024-01-14T23:30:00.000Z"); // 5.5h before correct
    const buggySecondIsWrong = buggySecond && buggySecond.getTime() === buggySecondWrongMs;
    logTest("Old buggy behavior demonstrated (double offset)", buggySecondIsWrong,
        `Old: ${buggySecond?.toISOString()} (wrong: Jan 14 23:30)`);
    if (buggySecondIsWrong) passed++;

    // Test 2b: Fixed version - should NOT apply offset again
    total++;
    const fixedSecond = parseDashaDateFixed(storedIso, offsetHours);
    const fixedSecondCorrect = fixedSecond && fixedSecond.getTime() === expectedUtcMs;
    logTest("FIXED version preserves correct date", fixedSecondCorrect,
        `Fixed: ${fixedSecond?.toISOString()} (correct: Jan 15 05:00)`);
    if (fixedSecondCorrect) passed++;

    // Test 3: Real-world scenario - checking if a date is "current"
    log("\nTEST 3: Real-world current period check (FIXED FLOW)", "cyan");

    // Simulate Maha Dasha: Jan 1, 2020 to Jan 1, 2040
    // Simulate Antar Dasha within it: Jan 1, 2024 to Jan 1, 2026
    const antarStartApi = "2024-01-01 00:00:00";
    const antarEndApi = "2026-01-01 00:00:00";

    // After storage using FIXED version (correctly converted to UTC)
    const antarStartStored = formatDashaDateForStorageFixed(antarStartApi, offsetHours);
    const antarEndStored = formatDashaDateForStorageFixed(antarEndApi, offsetHours);

    log(`  Antar Start (API local time): "${antarStartApi}"`, "yellow");
    log(`  Antar Start (stored UTC): "${antarStartStored}"`, "yellow");
    log(`  Antar End (API local time): "${antarEndApi}"`, "yellow");
    log(`  Antar End (stored UTC): "${antarEndStored}"`, "yellow");

    // Current time: Jan 15, 2025 (should be WITHIN the Antar period)
    const testNow = new Date("2025-01-15T12:00:00.000Z");
    log(`  Current time (test): ${testNow.toISOString()}\n`, "yellow");

    // Test 3a: Parse with FIXED function - should correctly detect current period
    total++;
    const fixedAntarStart = parseDashaDateFixed(antarStartStored, offsetHours);
    const fixedAntarEnd = parseDashaDateFixed(antarEndStored, offsetHours);
    const fixedIsWithin = testNow >= fixedAntarStart && testNow <= fixedAntarEnd;

    // Verify the dates are correct (not double-shifted)
    const expectedStart = Date.parse("2023-12-31T18:30:00.000Z"); // Jan 1 00:00 IST = Dec 31 18:30 UTC
    const expectedEnd = Date.parse("2025-12-31T18:30:00.000Z");   // Jan 1 00:00 IST = Dec 31 18:30 UTC
    const datesCorrect = fixedAntarStart.getTime() === expectedStart && fixedAntarEnd.getTime() === expectedEnd;

    logTest("FIXED: Dates correctly preserved after re-parse", datesCorrect,
        `Start: ${fixedAntarStart?.toISOString()}, End: ${fixedAntarEnd?.toISOString()}`);
    if (datesCorrect) passed++;

    // Test 3b: Current period detection works
    total++;
    logTest("FIXED: Current period detection works", fixedIsWithin,
        `Now (${testNow.toISOString()}) is between start and end`);
    if (fixedIsWithin) passed++;

    // Test 4: Vimshottari Dasha period lengths verification
    log("\nTEST 4: Vimshottari Dasha period lengths", "cyan");

    const VIMSHOTTARI_YEARS = {
        Ketu: 7,
        Venus: 20,
        Sun: 6,
        Moon: 10,
        Mars: 7,
        Rahu: 18,
        Jupiter: 16,
        Saturn: 19,
        Mercury: 17,
    };

    const totalYears = Object.values(VIMSHOTTARI_YEARS).reduce((a, b) => a + b, 0);
    total++;
    const vimshottariCorrect = totalYears === 120;
    logTest("Vimshottari total = 120 years", vimshottariCorrect,
        `Sum: ${totalYears} years`);
    if (vimshottariCorrect) passed++;

    // Print the canonical order (starting from birth nakshatra's lord)
    log("\n  Vimshottari Dasha Order (canonical):", "yellow");
    const order = ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"];
    order.forEach(lord => {
        console.log(`    ${lord}: ${VIMSHOTTARI_YEARS[lord]} years`);
    });

    // Test 5: Full end-to-end flow simulation
    log("\nTEST 5: End-to-end flow simulation", "cyan");
    log("  (Simulating: API → Backend → Firestore → Frontend)\n", "yellow");

    // Scenario: Person born Jan 15, 1990 in Delhi (IST)
    // API returns Maha Dasha start in local time: 2019-01-01 00:00:00 IST
    // Expected display: Jan 1, 2019 (in user's local timezone)

    const apiMahaStart = "2019-01-01 00:00:00"; // IST local time from API

    // Step 1: Backend stores as UTC
    const storedMahaStart = formatDashaDateForStorageFixed(apiMahaStart, offsetHours);
    log(`  API returns (IST): "${apiMahaStart}"`, "yellow");
    log(`  Backend stores (UTC): "${storedMahaStart}"`, "yellow");

    // Step 2: Frontend parses and converts to local time
    const frontendDate = new Date(storedMahaStart);
    // Simulate toLocal() by adding the offset back (this is what happens in Dart)
    const localDisplay = new Date(frontendDate.getTime() + (offsetHours * 60 * 60 * 1000));

    total++;
    // The date should display as Jan 1, 2019 00:00:00 in IST
    const displayCorrect = localDisplay.getUTCFullYear() === 2019 &&
        localDisplay.getUTCMonth() === 0 &&
        localDisplay.getUTCDate() === 1 &&
        localDisplay.getUTCHours() === 0;
    logTest("End-to-end: Frontend displays original local date", displayCorrect,
        `Frontend shows: ${localDisplay.toISOString()} (should be Jan 1 2019 00:00 in local TZ)`);
    if (displayCorrect) passed++;

    // Summary
    log("\n" + "=".repeat(80), "bright");
    log(`  RESULTS: ${passed}/${total} tests passed`, passed === total ? "green" : "red");
    log("=".repeat(80) + "\n", "bright");

    if (passed === total) {
        log("✅ ALL TESTS PASSED! Dasha date calculations are correct.", "green");
        log("\nThe complete flow:", "cyan");
        log("  1. API returns dates in user's birth location local time", "cyan");
        log("  2. Backend converts to UTC and stores as ISO string with 'Z'", "cyan");
        log("  3. Backend comparison uses UTC (no double offset)", "cyan");
        log("  4. Frontend converts UTC back to local time for display", "cyan");
    } else {
        log("⚠️  SOME TESTS FAILED - Review above for details.", "red");
    }

    return passed === total;
}

// Run tests
const allPassed = runTests();
process.exit(allPassed ? 0 : 1);

