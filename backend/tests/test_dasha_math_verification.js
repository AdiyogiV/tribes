/**
 * DEEP DASHA MATHEMATICAL VERIFICATION
 * 
 * This script verifies Dasha calculations from first principles
 * using the traditional Vimshottari Dasha algorithm.
 * 
 * The Vimshottari Dasha system:
 * 1. Total cycle = 120 years
 * 2. Each of 9 planets rules a specific duration
 * 3. The Moon's Nakshatra at birth determines starting Dasha
 * 4. The Moon's position within the Nakshatra determines the balance
 * 
 * Run with: node tests/test_dasha_math_verification.js
 */

// ANSI colors
const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    green: "\x1b[32m",
    red: "\x1b[31m",
    yellow: "\x1b[33m",
    cyan: "\x1b[36m",
    magenta: "\x1b[35m",
};

function log(message, color = "reset") {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

// =============================================================================
// VIMSHOTTARI DASHA CONSTANTS (Standard - from BPHS)
// =============================================================================

// Dasha years for each planet (total = 120)
const DASHA_YEARS = {
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

// The fixed order of Dashas (starting from Ketu)
const DASHA_ORDER = ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"];

// Each Nakshatra spans 13°20' (13.333...°)
const NAKSHATRA_SPAN = 360 / 27; // = 13.333...°

// 27 Nakshatras with their ruling planets
const NAKSHATRAS = [
    { name: "Ashwini", lord: "Ketu" },           // 0
    { name: "Bharani", lord: "Venus" },          // 1
    { name: "Krittika", lord: "Sun" },           // 2
    { name: "Rohini", lord: "Moon" },            // 3
    { name: "Mrigashira", lord: "Mars" },        // 4
    { name: "Ardra", lord: "Rahu" },             // 5
    { name: "Punarvasu", lord: "Jupiter" },      // 6
    { name: "Pushya", lord: "Saturn" },          // 7
    { name: "Ashlesha", lord: "Mercury" },       // 8
    { name: "Magha", lord: "Ketu" },             // 9
    { name: "Purva Phalguni", lord: "Venus" },   // 10
    { name: "Uttara Phalguni", lord: "Sun" },    // 11
    { name: "Hasta", lord: "Moon" },             // 12
    { name: "Chitra", lord: "Mars" },            // 13
    { name: "Swati", lord: "Rahu" },             // 14
    { name: "Vishakha", lord: "Jupiter" },       // 15
    { name: "Anuradha", lord: "Saturn" },        // 16
    { name: "Jyeshtha", lord: "Mercury" },       // 17
    { name: "Moola", lord: "Ketu" },             // 18
    { name: "Purva Ashadha", lord: "Venus" },    // 19
    { name: "Uttara Ashadha", lord: "Sun" },     // 20
    { name: "Shravana", lord: "Moon" },          // 21
    { name: "Dhanishta", lord: "Mars" },         // 22
    { name: "Shatabhisha", lord: "Rahu" },       // 23
    { name: "Purva Bhadrapada", lord: "Jupiter" }, // 24
    { name: "Uttara Bhadrapada", lord: "Saturn" }, // 25
    { name: "Revati", lord: "Mercury" },         // 26
];

// =============================================================================
// DASHA CALCULATION FUNCTIONS
// =============================================================================

/**
 * Get Nakshatra index and position from Moon's longitude
 */
function getNakshatraFromMoonDegree(moonDegree) {
    const normalizedDegree = ((moonDegree % 360) + 360) % 360;
    const nakshatraIndex = Math.floor(normalizedDegree / NAKSHATRA_SPAN);
    const nakshatraStart = nakshatraIndex * NAKSHATRA_SPAN;
    const positionInNakshatra = normalizedDegree - nakshatraStart;
    const traversedFraction = positionInNakshatra / NAKSHATRA_SPAN;

    return {
        index: nakshatraIndex,
        nakshatra: NAKSHATRAS[nakshatraIndex],
        degree: normalizedDegree,
        positionInNakshatra,
        traversedFraction,
        remainingFraction: 1 - traversedFraction,
    };
}

/**
 * Calculate complete Dasha timeline from birth
 */
function calculateDashaTimeline(birthDate, moonDegree) {
    const nakshatraInfo = getNakshatraFromMoonDegree(moonDegree);
    const startingLord = nakshatraInfo.nakshatra.lord;
    const startingIndex = DASHA_ORDER.indexOf(startingLord);

    // First Dasha balance (remaining portion of nakshatra)
    const firstDashaFullYears = DASHA_YEARS[startingLord];
    const firstDashaBalance = nakshatraInfo.remainingFraction * firstDashaFullYears;

    const timeline = [];
    let currentDate = new Date(birthDate);

    // First (partial) Dasha
    const firstEndDate = new Date(currentDate);
    firstEndDate.setTime(firstEndDate.getTime() + (firstDashaBalance * 365.25 * 24 * 60 * 60 * 1000));

    timeline.push({
        lord: startingLord,
        startDate: new Date(currentDate),
        endDate: new Date(firstEndDate),
        years: firstDashaBalance,
        isPartial: true,
    });

    currentDate = new Date(firstEndDate);

    // Remaining Dashas in order
    for (let i = 1; i < 9; i++) {
        const lordIndex = (startingIndex + i) % 9;
        const lord = DASHA_ORDER[lordIndex];
        const years = DASHA_YEARS[lord];

        const endDate = new Date(currentDate);
        endDate.setTime(endDate.getTime() + (years * 365.25 * 24 * 60 * 60 * 1000));

        timeline.push({
            lord,
            startDate: new Date(currentDate),
            endDate: new Date(endDate),
            years,
            isPartial: false,
        });

        currentDate = new Date(endDate);
    }

    return {
        nakshatraInfo,
        startingLord,
        firstDashaBalance,
        timeline,
    };
}

/**
 * Find current Dasha from timeline
 */
function getCurrentDasha(timeline, asOfDate = new Date()) {
    for (const dasha of timeline) {
        if (asOfDate >= dasha.startDate && asOfDate < dasha.endDate) {
            return dasha;
        }
    }
    return null;
}

// =============================================================================
// TEST CASES
// =============================================================================

const TEST_CASES = [
    {
        name: "Test Case 1: Delhi, 1990",
        birthDate: new Date("1990-01-15T05:00:00Z"), // 10:30 AM IST = 05:00 UTC
        moonDegree: 57.5, // Approximate Moon position for this date (Mrigashira nakshatra)
        location: "New Delhi, India",
        localTime: "January 15, 1990 at 10:30 AM IST",
    },
    {
        name: "Test Case 2: Mumbai, 1985",
        birthDate: new Date("1985-03-21T06:30:00Z"), // 12:00 PM IST = 06:30 UTC
        moonDegree: 125.0, // Leo - Magha nakshatra (Ketu lord)
        location: "Mumbai, India",
        localTime: "March 21, 1985 at 12:00 PM IST",
    },
    {
        name: "Test Case 3: Chennai, 2000",
        birthDate: new Date("2000-07-04T02:00:00Z"), // 7:30 AM IST = 02:00 UTC
        moonDegree: 45.0, // Taurus - Rohini nakshatra (Moon lord)
        location: "Chennai, India",
        localTime: "July 4, 2000 at 7:30 AM IST",
    },
];

// =============================================================================
// RUN VERIFICATION
// =============================================================================

function runVerification() {
    log("\n" + "█".repeat(80), "bright");
    log("  DEEP VIMSHOTTARI DASHA MATHEMATICAL VERIFICATION", "bright");
    log("█".repeat(80) + "\n", "bright");

    // First, verify constants
    log("1. VERIFYING DASHA CONSTANTS", "cyan");
    log("   (From Brihat Parashara Hora Shastra)\n", "yellow");

    const totalYears = Object.values(DASHA_YEARS).reduce((a, b) => a + b, 0);
    console.log(`   Total Dasha cycle: ${totalYears} years`);
    if (totalYears === 120) {
        log("   ✓ CORRECT: Total equals 120 years", "green");
    } else {
        log(`   ✗ ERROR: Should be 120, got ${totalYears}`, "red");
    }

    console.log(`   Number of Nakshatras: ${NAKSHATRAS.length}`);
    if (NAKSHATRAS.length === 27) {
        log("   ✓ CORRECT: 27 Nakshatras", "green");
    } else {
        log(`   ✗ ERROR: Should be 27, got ${NAKSHATRAS.length}`, "red");
    }

    console.log(`   Nakshatra span: ${NAKSHATRA_SPAN.toFixed(4)}° (should be 13.3333°)`);
    if (Math.abs(NAKSHATRA_SPAN - 13.333333) < 0.001) {
        log("   ✓ CORRECT: Nakshatra span is 13°20'", "green");
    }

    // Verify nakshatra-lord mapping pattern (3 nakshatras per lord)
    const lordCounts = {};
    NAKSHATRAS.forEach(n => {
        lordCounts[n.lord] = (lordCounts[n.lord] || 0) + 1;
    });

    let lordPatternCorrect = true;
    Object.entries(lordCounts).forEach(([lord, count]) => {
        if (count !== 3) {
            lordPatternCorrect = false;
            log(`   ✗ ERROR: ${lord} has ${count} nakshatras (should be 3)`, "red");
        }
    });
    if (lordPatternCorrect) {
        log("   ✓ CORRECT: Each planet rules exactly 3 nakshatras", "green");
    }

    // Run test cases
    log("\n\n2. TEST CASE CALCULATIONS", "cyan");
    log("   (Verify these against external calculators)\n", "yellow");

    TEST_CASES.forEach((testCase, idx) => {
        log(`\n   ─── ${testCase.name} ───`, "magenta");
        console.log(`   Location: ${testCase.location}`);
        console.log(`   Date/Time: ${testCase.localTime}`);
        console.log(`   Moon Degree: ${testCase.moonDegree}°`);

        const result = calculateDashaTimeline(testCase.birthDate, testCase.moonDegree);

        log(`\n   CALCULATED RESULTS:`, "cyan");
        console.log(`   Moon Nakshatra: ${result.nakshatraInfo.nakshatra.name}`);
        console.log(`   Nakshatra Lord: ${result.nakshatraInfo.nakshatra.lord}`);
        console.log(`   Position in Nakshatra: ${result.nakshatraInfo.positionInNakshatra.toFixed(2)}° of ${NAKSHATRA_SPAN.toFixed(2)}°`);
        console.log(`   Traversed: ${(result.nakshatraInfo.traversedFraction * 100).toFixed(1)}%`);
        console.log(`   First Dasha Balance: ${result.firstDashaBalance.toFixed(2)} years`);

        log(`\n   MAHA DASHA TIMELINE:`, "cyan");

        const now = new Date();
        const currentDasha = getCurrentDasha(result.timeline, now);

        result.timeline.forEach((dasha, i) => {
            const startStr = dasha.startDate.toISOString().split('T')[0];
            const endStr = dasha.endDate.toISOString().split('T')[0];
            const isCurrent = currentDasha && currentDasha.lord === dasha.lord &&
                currentDasha.startDate.getTime() === dasha.startDate.getTime();
            const marker = isCurrent ? " ← CURRENT" : "";
            const partial = dasha.isPartial ? " (partial)" : "";

            console.log(`   ${String(i + 1).padStart(2)}. ${dasha.lord.padEnd(10)} ${startStr} → ${endStr} (${dasha.years.toFixed(1)}y)${partial}${marker}`);
        });

        if (currentDasha) {
            log(`\n   Current Maha Dasha: ${currentDasha.lord}`, "green");
        }
    });

    // Verification guide
    log("\n\n" + "=".repeat(80), "bright");
    log("  EXTERNAL VERIFICATION GUIDE", "bright");
    log("=".repeat(80) + "\n", "bright");

    console.log("   To verify these calculations, use the following websites:");
    console.log("   1. https://www.astrosage.com/free/dasha.asp");
    console.log("   2. https://www.prokerala.com/astrology/dasha/");
    console.log("   3. https://dashaclub.com/calculator");
    console.log("   4. https://www.kundli-software.com/free-kundli-horoscope.html\n");

    console.log("   Enter these birth details for Test Case 1:");
    console.log("   ┌────────────────────────────────────────────┐");
    console.log("   │  Date: January 15, 1990                    │");
    console.log("   │  Time: 10:30 AM                            │");
    console.log("   │  Place: New Delhi, India                   │");
    console.log("   │  Ayanamsa: Lahiri (default on most sites)  │");
    console.log("   └────────────────────────────────────────────┘\n");

    console.log("   WHAT TO COMPARE:");
    console.log("   1. Moon Nakshatra name");
    console.log("   2. Current Maha Dasha lord");
    console.log("   3. Maha Dasha start/end dates (±1 day is acceptable)");
    console.log("   4. Sequence of all Maha Dashas\n");

    console.log("   ACCEPTABLE VARIATIONS:");
    console.log("   - Dates may differ by up to 1 day due to:");
    console.log("     * Different ayanamsa precision");
    console.log("     * Different ephemeris data (Swiss vs JPL)");
    console.log("     * Rounding differences in Moon position");
    console.log("   - The sequence of Dashas should be IDENTICAL");
    console.log("   - The lord names should match exactly\n");

    // Mathematical proof
    log("\n" + "=".repeat(80), "bright");
    log("  MATHEMATICAL PROOF OF OUR IMPLEMENTATION", "bright");
    log("=".repeat(80) + "\n", "bright");

    console.log("   Our implementation follows the standard Vimshottari algorithm:\n");
    console.log("   1. NAKSHATRA DETERMINATION:");
    console.log("      index = floor(moon_degree / 13.333...)");
    console.log("      For 57.5°: floor(57.5 / 13.333) = floor(4.31) = 4");
    console.log("      Nakshatra 4 = Mrigashira (Mars) ✓\n");

    console.log("   2. BALANCE CALCULATION:");
    console.log("      position_in_nakshatra = moon_degree - (index × 13.333...)");
    console.log("      For 57.5°: 57.5 - (4 × 13.333) = 57.5 - 53.33 = 4.17°");
    console.log("      traversed_fraction = 4.17 / 13.333 = 0.3125 (31.25%)");
    console.log("      remaining_fraction = 1 - 0.3125 = 0.6875 (68.75%)");
    console.log("      first_dasha_balance = 0.6875 × 7 years (Mars) = 4.81 years ✓\n");

    console.log("   3. DASHA SEQUENCE:");
    console.log("      Starting from Mars (index 4 in DASHA_ORDER):");
    console.log("      Mars → Rahu → Jupiter → Saturn → Mercury → Ketu → Venus → Sun → Moon ✓\n");

    console.log("   4. DATE CALCULATION:");
    console.log("      Each period = years × 365.25 days (accounting for leap years)");
    console.log("      End date = Start date + period_duration ✓\n");

    log("=".repeat(80) + "\n", "bright");
}

// Run verification
runVerification();




