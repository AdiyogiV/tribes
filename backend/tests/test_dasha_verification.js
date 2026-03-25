/**
 * Vimshottari Dasha External Verification Test
 * 
 * This script outputs data that can be verified against:
 * 1. https://mahadasha.com
 * 2. https://dashaclub.com/calculator
 * 3. https://www.astrosage.com/free/dasha.asp
 * 4. https://www.prokerala.com/astrology/dasha/
 * 
 * VERIFICATION STEPS:
 * 1. Run this script to see the Dasha constants and test case
 * 2. Go to any of the above websites
 * 3. Enter the SAME birth details shown below
 * 4. Compare the Maha Dasha periods and dates
 * 
 * Run with: node tests/test_dasha_verification.js
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
// VIMSHOTTARI DASHA CONSTANTS (From Brihat Parashara Hora Shastra)
// =============================================================================

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

// The canonical order of Dashas (Ketu starts the cycle)
const DASHA_ORDER = ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"];

// 27 Nakshatras and their ruling planets (Dasha lords)
// This is the key mapping that determines starting Dasha
const NAKSHATRA_LORDS = {
    // Ketu Nakshatras (1, 10, 19)
    "Ashwini": "Ketu",        // 1st nakshatra
    "Magha": "Ketu",          // 10th nakshatra
    "Moola": "Ketu",          // 19th nakshatra

    // Venus Nakshatras (2, 11, 20)
    "Bharani": "Venus",       // 2nd nakshatra
    "Purva Phalguni": "Venus",// 11th nakshatra
    "Purva Ashadha": "Venus", // 20th nakshatra

    // Sun Nakshatras (3, 12, 21)
    "Krittika": "Sun",        // 3rd nakshatra
    "Uttara Phalguni": "Sun", // 12th nakshatra
    "Uttara Ashadha": "Sun",  // 21st nakshatra

    // Moon Nakshatras (4, 13, 22)
    "Rohini": "Moon",         // 4th nakshatra
    "Hasta": "Moon",          // 13th nakshatra
    "Shravana": "Moon",       // 22nd nakshatra

    // Mars Nakshatras (5, 14, 23)
    "Mrigashira": "Mars",     // 5th nakshatra
    "Chitra": "Mars",         // 14th nakshatra
    "Dhanishta": "Mars",      // 23rd nakshatra

    // Rahu Nakshatras (6, 15, 24)
    "Ardra": "Rahu",          // 6th nakshatra
    "Swati": "Rahu",          // 15th nakshatra
    "Shatabhisha": "Rahu",    // 24th nakshatra

    // Jupiter Nakshatras (7, 16, 25)
    "Punarvasu": "Jupiter",   // 7th nakshatra
    "Vishakha": "Jupiter",    // 16th nakshatra
    "Purva Bhadrapada": "Jupiter", // 25th nakshatra

    // Saturn Nakshatras (8, 17, 26)
    "Pushya": "Saturn",       // 8th nakshatra
    "Anuradha": "Saturn",     // 17th nakshatra
    "Uttara Bhadrapada": "Saturn", // 26th nakshatra

    // Mercury Nakshatras (9, 18, 27)
    "Ashlesha": "Mercury",    // 9th nakshatra
    "Jyeshtha": "Mercury",    // 18th nakshatra
    "Revati": "Mercury",      // 27th nakshatra
};

// =============================================================================
// VERIFICATION OUTPUT
// =============================================================================

function runVerification() {
    log("\n" + "=".repeat(80), "bright");
    log("  VIMSHOTTARI DASHA EXTERNAL VERIFICATION", "bright");
    log("=".repeat(80) + "\n", "bright");

    // 1. Show Dasha Period Years
    log("1. VIMSHOTTARI DASHA PERIOD YEARS", "cyan");
    log("   (Verify these match BPHS and external calculators)\n", "yellow");

    let total = 0;
    DASHA_ORDER.forEach((lord, idx) => {
        const years = VIMSHOTTARI_YEARS[lord];
        total += years;
        console.log(`   ${idx + 1}. ${lord.padEnd(10)} = ${years} years`);
    });
    console.log(`   ${"─".repeat(25)}`);
    console.log(`   Total              = ${total} years`);

    if (total === 120) {
        log("\n   ✓ CORRECT: Total equals 120 years (full cycle)", "green");
    } else {
        log(`\n   ✗ ERROR: Total should be 120, got ${total}`, "red");
    }

    // 2. Show Nakshatra-Lord Mapping
    log("\n\n2. NAKSHATRA TO DASHA LORD MAPPING", "cyan");
    log("   (The Moon's nakshatra at birth determines the starting Dasha)\n", "yellow");

    const nakshatrasByLord = {};
    Object.entries(NAKSHATRA_LORDS).forEach(([nakshatra, lord]) => {
        if (!nakshatrasByLord[lord]) nakshatrasByLord[lord] = [];
        nakshatrasByLord[lord].push(nakshatra);
    });

    DASHA_ORDER.forEach(lord => {
        const nakshatras = nakshatrasByLord[lord] || [];
        console.log(`   ${lord.padEnd(10)}: ${nakshatras.join(", ")}`);
    });

    // 3. Test Case for Manual Verification
    log("\n\n3. TEST CASE FOR MANUAL VERIFICATION", "cyan");
    log("   Use these EXACT details in external calculators:\n", "yellow");

    const testCase = {
        date: "January 15, 1990",
        time: "10:30 AM",
        location: "New Delhi, India",
        latitude: "28.6139° N",
        longitude: "77.2090° E",
        timezone: "IST (UTC+5:30)",
    };

    console.log("   ┌─────────────────────────────────────────────────┐");
    console.log("   │  BIRTH DETAILS FOR VERIFICATION                 │");
    console.log("   ├─────────────────────────────────────────────────┤");
    console.log(`   │  Date:      ${testCase.date.padEnd(33)} │`);
    console.log(`   │  Time:      ${testCase.time.padEnd(33)} │`);
    console.log(`   │  Location:  ${testCase.location.padEnd(33)} │`);
    console.log(`   │  Latitude:  ${testCase.latitude.padEnd(33)} │`);
    console.log(`   │  Longitude: ${testCase.longitude.padEnd(33)} │`);
    console.log(`   │  Timezone:  ${testCase.timezone.padEnd(33)} │`);
    console.log("   └─────────────────────────────────────────────────┘");

    // 4. External Calculators to Verify Against
    log("\n\n4. EXTERNAL CALCULATORS FOR VERIFICATION", "cyan");
    log("   Enter the above birth details in these websites:\n", "yellow");

    const calculators = [
        { name: "AstroSage", url: "https://www.astrosage.com/free/dasha.asp" },
        { name: "Prokerala", url: "https://www.prokerala.com/astrology/dasha/" },
        { name: "DashaClub", url: "https://dashaclub.com/calculator" },
        { name: "ClickAstro", url: "https://www.clickastro.com/free-vimshottari-dasha-calculator/" },
        { name: "AstroVed", url: "https://www.astroved.com/astropedia/en/free-tools/dasha-calculator" },
    ];

    calculators.forEach((calc, idx) => {
        console.log(`   ${idx + 1}. ${calc.name}: ${calc.url}`);
    });

    // 5. What to Compare
    log("\n\n5. WHAT TO COMPARE", "cyan");
    log("   When comparing, check:\n", "yellow");

    const checkList = [
        "Moon Nakshatra (determines starting Dasha lord)",
        "Current Maha Dasha lord",
        "Maha Dasha start and end dates",
        "Current Antar Dasha lord",
        "Antar Dasha start and end dates",
        "The order of all Maha Dashas for life",
    ];

    checkList.forEach((item, idx) => {
        console.log(`   ${idx + 1}. ${item}`);
    });

    // 6. Known Reference Points
    log("\n\n6. REFERENCE: APPROXIMATE RESULTS FOR JAN 15, 1990 DELHI", "cyan");
    log("   (These should approximately match external calculators)\n", "yellow");

    console.log("   Note: Exact dates may vary slightly based on:");
    console.log("   - Ayanamsa used (Lahiri is most common)");
    console.log("   - Swiss Ephemeris vs. other calculation methods");
    console.log("   - Rounding of Moon position in nakshatra\n");

    console.log("   Expected Moon Nakshatra: Around Mrigashira or Ardra");
    console.log("   (Moon was at ~55-60° = late Taurus/early Gemini)");
    console.log("   If Mrigashira: Starting Dasha = Mars");
    console.log("   If Ardra: Starting Dasha = Rahu\n");

    log("\n" + "=".repeat(80), "bright");
    log("  VERIFICATION INSTRUCTIONS", "bright");
    log("=".repeat(80), "bright");

    console.log(`
   1. Open one of the calculator websites listed above
   2. Enter the EXACT birth details from section 3
   3. Compare the Moon Nakshatra and Dasha periods
   4. The dates should match within a few hours
   
   If there's a significant discrepancy (more than 1 day), it could be:
   - Different Ayanamsa setting (use Lahiri)
   - Time zone handling issue
   - Different ephemeris data
   
   Our system uses FreeAstrologyAPI which uses Swiss Ephemeris + Lahiri Ayanamsa
`);

    log("=".repeat(80) + "\n", "bright");
}

// Run verification
runVerification();




