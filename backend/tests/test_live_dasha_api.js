/**
 * Live API Verification Test
 * 
 * This test calls the actual FreeAstrologyAPI to get Dasha data
 * for a specific birth date, which you can then compare against
 * external calculators.
 * 
 * REQUIRES: Set FREE_ASTROLOGY_API_KEY environment variable
 * 
 * Run with: 
 *   FREE_ASTROLOGY_API_KEY=your_key node tests/test_live_dasha_api.js
 * 
 * Or use the existing secret by running through firebase emulators
 */

import fetch from 'node-fetch';

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

// Test case: January 15, 1990, 10:30 AM, New Delhi
const TEST_BIRTH_DATA = {
    year: 1990,
    month: 1,
    date: 15,
    hours: 10,
    minutes: 30,
    seconds: 0,
    latitude: 28.6139,
    longitude: 77.2090,
    timezone: 5.5,  // IST = UTC+5:30
};

const API_BASE = "https://json.freeastrologyapi.com";
const DASHA_ENDPOINT = "/vimsottari/maha-dasas-and-antar-dasas";
const PLANETS_ENDPOINT = "/planets/extended";

async function callApi(endpoint, payload, apiKey) {
    const url = `${API_BASE}${endpoint}`;

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': apiKey,
            },
            body: JSON.stringify(payload),
        });

        if (!response.ok) {
            throw new Error(`API returned ${response.status}: ${response.statusText}`);
        }

        return await response.json();
    } catch (error) {
        throw new Error(`API call failed: ${error.message}`);
    }
}

async function runLiveVerification() {
    log("\n" + "=".repeat(80), "bright");
    log("  LIVE API DASHA VERIFICATION", "bright");
    log("=".repeat(80) + "\n", "bright");

    // Get API key from environment
    const apiKey = process.env.FREE_ASTROLOGY_API_KEY;

    if (!apiKey) {
        log("⚠️  No API key found!", "red");
        console.log(`
To run this test, set the FREE_ASTROLOGY_API_KEY environment variable:

   FREE_ASTROLOGY_API_KEY=your_key node tests/test_live_dasha_api.js

Or check your serviceAccountKey.json or secrets for the key.
`);
        log("\nAlternatively, manually verify using these birth details:\n", "yellow");
        console.log(JSON.stringify(TEST_BIRTH_DATA, null, 2));
        console.log(`
   Date: January 15, 1990
   Time: 10:30 AM
   Location: New Delhi, India (28.6139°N, 77.2090°E)
   Timezone: IST (UTC+5:30)
`);
        log("Use these details on:", "cyan");
        console.log("   - https://www.astrosage.com/free/dasha.asp");
        console.log("   - https://www.prokerala.com/astrology/dasha/");
        console.log("   - https://dashaclub.com/calculator\n");
        return;
    }

    log("Birth Details:", "cyan");
    console.log(`   Date: January ${TEST_BIRTH_DATA.date}, ${TEST_BIRTH_DATA.year}`);
    console.log(`   Time: ${TEST_BIRTH_DATA.hours}:${TEST_BIRTH_DATA.minutes} IST`);
    console.log(`   Location: New Delhi (${TEST_BIRTH_DATA.latitude}°N, ${TEST_BIRTH_DATA.longitude}°E)\n`);

    try {
        // 1. Get Planets data to see Moon Nakshatra
        log("1. Fetching planet positions...", "yellow");
        const planetsData = await callApi(PLANETS_ENDPOINT, TEST_BIRTH_DATA, apiKey);

        if (planetsData.output) {
            const planets = Array.isArray(planetsData.output) ? planetsData.output[0] : planetsData.output;

            // Find Moon
            const moonData = planets["2"] || planets["Moon"] ||
                Object.values(planets).find(p => p.name?.toLowerCase() === "moon");

            if (moonData) {
                log("\n   MOON POSITION:", "green");
                console.log(`   Sign: ${moonData.zodiac_sign_name || moonData.sign || 'N/A'}`);
                console.log(`   Nakshatra: ${moonData.nakshatra_name || 'N/A'}`);
                console.log(`   Degrees: ${moonData.fullDegree?.toFixed(2) || moonData.full_degree?.toFixed(2) || 'N/A'}°`);
                console.log(`   (Compare this Nakshatra with external calculators)\n`);
            }
        }

        // 2. Get Dasha data
        log("2. Fetching Dasha periods...", "yellow");
        const dashaData = await callApi(DASHA_ENDPOINT, TEST_BIRTH_DATA, apiKey);

        if (dashaData.output) {
            const dashaPeriods = typeof dashaData.output === 'string'
                ? JSON.parse(dashaData.output)
                : dashaData.output;

            log("\n   MAHA DASHA PERIODS:", "green");
            console.log("   (Compare these dates with external calculators)\n");

            const now = new Date();
            let currentMaha = null;

            Object.entries(dashaPeriods).forEach(([lord, period], idx) => {
                if (!period || typeof period !== 'object') return;

                // Extract start and end times
                let startTime = period.start_time || period.startTime;
                let endTime = period.end_time || period.endTime;

                // If period is a nested object of antar dashas, find first/last
                if (!startTime && typeof period === 'object') {
                    const entries = Object.values(period).filter(v => v && typeof v === 'object');
                    if (entries.length > 0) {
                        const sorted = entries.sort((a, b) =>
                            new Date(a.start_time || a.startTime) - new Date(b.start_time || b.startTime)
                        );
                        startTime = sorted[0]?.start_time || sorted[0]?.startTime;
                        endTime = sorted[sorted.length - 1]?.end_time || sorted[sorted.length - 1]?.endTime;
                    }
                }

                if (startTime && endTime) {
                    const start = new Date(startTime.replace(' ', 'T') + 'Z');
                    const end = new Date(endTime.replace(' ', 'T') + 'Z');

                    // Adjust for IST display (subtract 5.5 hours to show in birth local time)
                    const startLocal = new Date(start.getTime() - (5.5 * 60 * 60 * 1000));
                    const endLocal = new Date(end.getTime() - (5.5 * 60 * 60 * 1000));

                    const isCurrent = now >= start && now <= end;
                    if (isCurrent) currentMaha = lord;

                    const marker = isCurrent ? " ← CURRENT" : "";
                    const color = isCurrent ? "magenta" : "reset";

                    const formatDate = (d) => {
                        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
                    };

                    log(`   ${String(idx + 1).padStart(2)}. ${(period.Lord || lord).padEnd(10)} : ${formatDate(startLocal)} → ${formatDate(endLocal)}${marker}`, color);
                }
            });

            if (currentMaha) {
                log(`\n   ✓ Current Maha Dasha: ${currentMaha}`, "green");
            }
        }

        // 3. Summary
        log("\n" + "=".repeat(80), "bright");
        log("  VERIFICATION CHECKLIST", "bright");
        log("=".repeat(80) + "\n", "bright");

        console.log("   Compare the above results with external calculators:");
        console.log("   1. https://www.astrosage.com/free/dasha.asp");
        console.log("   2. https://www.prokerala.com/astrology/dasha/");
        console.log("   3. https://dashaclub.com/calculator\n");

        console.log("   Use these exact details:");
        console.log("   - Date: January 15, 1990");
        console.log("   - Time: 10:30 AM");
        console.log("   - Location: New Delhi, India");
        console.log("   - Ayanamsa: Lahiri (most common)\n");

        console.log("   What to verify:");
        console.log("   ✓ Moon Nakshatra should match");
        console.log("   ✓ Maha Dasha periods should match within a day");
        console.log("   ✓ Current Maha Dasha lord should match");
        console.log("   ✓ Order of Dashas should match\n");

    } catch (error) {
        log(`\n❌ Error: ${error.message}`, "red");
        console.log("\nTry verifying manually using the birth details above.");
    }
}

// Run verification
runLiveVerification().catch(console.error);




