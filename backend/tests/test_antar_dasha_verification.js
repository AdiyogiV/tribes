#!/usr/bin/env node

/**
 * Antar Dasha (Sub-Period) Verification Test
 * Compares our Antar Dasha calculations with external astrology sources
 */

const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    red: "\x1b[31m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    blue: "\x1b[34m",
    cyan: "\x1b[36m",
};

// Birth details - same as previous test
const BIRTH_DATA = {
    date: "July 31, 1998",
    time: "19:30 IST",
    location: "Delhi, India",
    timezone: 5.5,
};

// Expected Saturn Antar Dashas from external app (user provided)
const EXPECTED_SATURN_ANTAR_DASHAS = [
    { lord: "Saturn", start: "2021-01-21", end: "2024-01-27", duration: "3 Y, 0 M, 3 D" },
    { lord: "Mercury", start: "2024-01-27", end: "2026-10-06", duration: "2 Y, 8 M, 9 D" },
    { lord: "Ketu", start: "2026-10-06", end: "2027-11-16", duration: "1 Y, 1 M, 10 D" },
    { lord: "Venus", start: "2027-11-16", end: "2031-01-16", duration: "3 Y, 2 M, 0 D" },
    { lord: "Sun", start: "2031-01-16", end: "2031-12-28", duration: "0 Y, 11 M, 12 D" },
    { lord: "Moon", start: "2031-12-28", end: "2033-07-28", duration: "1 Y, 7 M, 0 D" },
    { lord: "Mars", start: "2033-07-28", end: "2034-09-07", duration: "1 Y, 1 M, 10 D" },
    { lord: "Rahu", start: "2034-09-07", end: "2037-07-13", duration: "2 Y, 10 M, 6 D" },
    { lord: "Jupiter", start: "2037-07-13", end: "2040-01-25", duration: "2 Y, 6 M, 12 D" },
];

// Vimshottari Dasha periods (in years)
const MAHA_DASHA_YEARS = {
    Sun: 6,
    Moon: 10,
    Mars: 7,
    Rahu: 18,
    Jupiter: 16,
    Saturn: 19,
    Mercury: 17,
    Ketu: 7,
    Venus: 20,
};

// Calculate Antar Dasha durations within a Maha Dasha
function calculateAntarDashaDuration(mahaDashaLord, antarDashaLord) {
    const mahaDashaYears = MAHA_DASHA_YEARS[mahaDashaLord];
    const antarDashaYears = MAHA_DASHA_YEARS[antarDashaLord];

    // Antar Dasha duration formula: (Maha years * Antar years) / Total Vimshottari cycle (120 years)
    return (mahaDashaYears * antarDashaYears) / 120;
}

// Calculate all Antar Dashas for Saturn Maha Dasha
function calculateSaturnAntarDashas(saturnMahaStart) {
    // Saturn Antar Dasha order (starts with itself)
    const antarOrder = ["Saturn", "Mercury", "Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter"];

    const antarDashas = [];
    let currentStart = new Date(saturnMahaStart);

    for (const antarLord of antarOrder) {
        const durationYears = calculateAntarDashaDuration("Saturn", antarLord);
        const durationDays = durationYears * 365.25; // Account for leap years

        const endDate = new Date(currentStart);
        endDate.setDate(endDate.getDate() + Math.round(durationDays));

        antarDashas.push({
            lord: antarLord,
            startDate: currentStart.toISOString().split('T')[0],
            endDate: endDate.toISOString().split('T')[0],
            durationYears: durationYears.toFixed(4),
        });

        currentStart = new Date(endDate);
    }

    return antarDashas;
}

// Compare two dates (allow up to 5 days difference)
function compareDates(date1, date2) {
    const d1 = new Date(date1);
    const d2 = new Date(date2);
    const diffDays = Math.abs((d1 - d2) / (1000 * 60 * 60 * 24));
    return {
        match: diffDays <= 5,
        diffDays: Math.round(diffDays),
    };
}

// Format duration in years, months, days
function formatDuration(durationYears) {
    const years = Math.floor(durationYears);
    const remainingDays = (durationYears - years) * 365.25;
    const months = Math.floor(remainingDays / 30.44);
    const days = Math.round(remainingDays % 30.44);
    return `${years} Y, ${months} M, ${days} D`;
}

console.log(`${colors.bright}${colors.cyan}
${"=".repeat(80)}
  ANTAR DASHA (SUB-PERIOD) VERIFICATION
${"=".repeat(80)}
${colors.reset}\n`);

console.log(`${colors.cyan}BIRTH DETAILS:${colors.reset}`);
console.log(`  Date: ${BIRTH_DATA.date}`);
console.log(`  Time: ${BIRTH_DATA.time}`);
console.log(`  Location: ${BIRTH_DATA.location}`);
console.log(`  Timezone: UTC+${BIRTH_DATA.timezone}\n`);

console.log(`${colors.cyan}SATURN MAHA DASHA:${colors.reset}`);
console.log(`  Period: 2021-01-25 → 2040-01-25 (19 years)\n`);

// Calculate our Antar Dashas
const saturnMahaStart = "2021-01-25"; // From our previous verification
const calculatedAntarDashas = calculateSaturnAntarDashas(saturnMahaStart);

console.log(`${colors.cyan}ANTAR DASHA COMPARISON:${colors.reset}\n`);
console.log(`${colors.bright}${"─".repeat(120)}${colors.reset}`);
console.log(`${colors.bright}Planet      Our Calculation                 External App                    Diff (days)  Match${colors.reset}`);
console.log(`${colors.bright}${"─".repeat(120)}${colors.reset}`);

let allMatch = true;
let totalDiff = 0;

for (let i = 0; i < EXPECTED_SATURN_ANTAR_DASHAS.length; i++) {
    const expected = EXPECTED_SATURN_ANTAR_DASHAS[i];
    const calculated = calculatedAntarDashas[i];

    const startComp = compareDates(calculated.startDate, expected.start);
    const endComp = compareDates(calculated.endDate, expected.end);

    const maxDiff = Math.max(startComp.diffDays, endComp.diffDays);
    totalDiff += maxDiff;

    const match = startComp.match && endComp.match;
    if (!match) allMatch = false;

    const color = match ? colors.green : colors.red;
    const symbol = match ? "✓" : "✗";

    const lordPadded = expected.lord.padEnd(11);
    const ourPeriod = `${calculated.startDate} → ${calculated.endDate}`;
    const extPeriod = `${expected.start} → ${expected.end}`;
    const diffStr = String(maxDiff).padStart(5);

    console.log(`${color}${lordPadded} ${ourPeriod.padEnd(31)} ${extPeriod.padEnd(31)} ${diffStr}        ${symbol}${colors.reset}`);
}

console.log(`${colors.bright}${"─".repeat(120)}${colors.reset}\n`);

// Calculate average difference
const avgDiff = totalDiff / EXPECTED_SATURN_ANTAR_DASHAS.length;

console.log(`${colors.cyan}ANALYSIS:${colors.reset}`);
console.log(`  Total Antar Dashas: ${EXPECTED_SATURN_ANTAR_DASHAS.length}`);
console.log(`  Average difference: ${avgDiff.toFixed(1)} days`);
console.log(`  Maximum acceptable: 5 days\n`);

// Show calculation method
console.log(`${colors.cyan}CALCULATION METHOD:${colors.reset}`);
console.log(`  Antar Dasha Duration = (Maha Dasha Years × Antar Dasha Years) ÷ 120`);
console.log(`  Example: Saturn-Mercury = (19 × 17) ÷ 120 = 2.692 years ≈ 2 Y, 8 M, 9 D\n`);

console.log(`${colors.cyan}EXPECTED VS CALCULATED DURATIONS:${colors.reset}\n`);
for (let i = 0; i < EXPECTED_SATURN_ANTAR_DASHAS.length; i++) {
    const expected = EXPECTED_SATURN_ANTAR_DASHAS[i];
    const calculated = calculatedAntarDashas[i];
    const calcDuration = formatDuration(parseFloat(calculated.durationYears));

    console.log(`  ${expected.lord.padEnd(10)}: Expected ${expected.duration.padEnd(15)} | Calculated ${calcDuration.padEnd(15)}`);
}

console.log(`\n${colors.bright}${colors.cyan}${"=".repeat(80)}${colors.reset}`);
if (allMatch) {
    console.log(`${colors.bright}${colors.green}  ✅ ALL ANTAR DASHAS MATCH (within acceptable tolerance)${colors.reset}`);
} else {
    console.log(`${colors.bright}${colors.red}  ❌ SOME ANTAR DASHAS DO NOT MATCH${colors.reset}`);
}
console.log(`${colors.bright}${colors.cyan}${"=".repeat(80)}${colors.reset}\n`);

console.log(`${colors.yellow}NOTE:${colors.reset}`);
console.log(`  Minor differences (1-5 days) are acceptable and expected due to:`);
console.log(`  • Different rounding methods for fractional days`);
console.log(`  • Leap year handling variations`);
console.log(`  • Starting date precision differences`);
console.log(`  • Moon position calculation precision\n`);

if (allMatch) {
    console.log(`${colors.green}${colors.bright}RESULT: Antar Dasha calculations are CORRECT ✓${colors.reset}\n`);
    process.exit(0);
} else {
    console.log(`${colors.red}${colors.bright}RESULT: Antar Dasha calculations need review${colors.reset}\n`);
    process.exit(1);
}
