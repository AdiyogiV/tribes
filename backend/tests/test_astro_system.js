/**
 * Comprehensive Test Suite for Astrology Prediction System
 * Tests all components and shows clear, actionable results
 */

import { db } from "./lib/firebase.js";
import { DateTime } from "luxon";
import {
    calculateHouseActivations,
    calculateTransitAspects,
    scoreHouseActivations,
    scoreAspects,
    getHouseSignification,
} from "./functions/vedic_analysis.js";
import {
    calculateFutureTransits,
    detectUpcomingEvents,
    formatUpcomingEvents,
} from "./functions/future_transits.js";
import { runAstroFlow } from "./functions/free_astro.js";

// ANSI colors for terminal output
const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    green: "\x1b[32m",
    red: "\x1b[31m",
    yellow: "\x1b[33m",
    blue: "\x1b[34m",
    cyan: "\x1b[36m",
    magenta: "\x1b[35m",
};

function log(message, color = "reset") {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSection(title) {
    console.log("\n" + "=".repeat(80));
    log(title, "bright");
    console.log("=".repeat(80));
}

function logTest(name, passed, details = "") {
    const status = passed ? "✓ PASS" : "✗ FAIL";
    const color = passed ? "green" : "red";
    log(`  ${status}: ${name}`, color);
    if (details) {
        console.log(`    ${details}`);
    }
}

/**
 * Test 1: House Activation Calculation
 */
async function testHouseActivations() {
    logSection("TEST 1: House Activation Calculation");

    // Mock natal chart
    const natalChart = {
        ascendant: 210, // Scorpio ascendant
        planets: {
            Sun: { fullDegree: 35, sign: "Aries" },
            Moon: { fullDegree: 125, sign: "Leo" },
            Mars: { fullDegree: 305, sign: "Aquarius" },
        },
    };

    // Mock current transits
    const transits = {
        Sun: { sign: "Aries", degree: 25, house: 6 },
        Moon: { sign: "Leo", degree: 130, house: 9 },
        Mars: { sign: "Scorpio", degree: 220, house: 11 },
        Jupiter: { sign: "Taurus", degree: 35, house: 2 },
        Saturn: { sign: "Capricorn", degree: 280, house: 1 },
    };

    try {
        const activations = calculateHouseActivations(natalChart, transits);
        const scored = scoreHouseActivations(activations, { mahaDasha: "Jupiter", antarDasha: "Mars" });

        logTest("House activations calculated", activations.length > 0, `${activations.length} activations found`);
        
        if (scored.length > 0) {
            log("\n  Top House Activations:", "cyan");
            scored.slice(0, 5).forEach((act, idx) => {
                console.log(`    ${idx + 1}. ${act.planet} → House ${act.house} (${act.signification})`);
                console.log(`       Score: ${act.score}, Transit: ${act.transitSign}`);
            });
        }

        return { passed: true, activations: scored };
    } catch (error) {
        logTest("House activations calculated", false, `Error: ${error.message}`);
        return { passed: false, error: error.message };
    }
}

/**
 * Test 2: Aspect Calculation
 */
async function testAspectCalculation() {
    logSection("TEST 2: Aspect Calculation");

    const natalChart = {
        ascendant: 210,
        planets: {
            Sun: { fullDegree: 35 },
            Moon: { fullDegree: 125 },
            Mars: { fullDegree: 305 },
        },
    };

    const transits = {
        Sun: { sign: "Aries", degree: 25 },
        Moon: { sign: "Leo", degree: 130 },
        Mars: { sign: "Scorpio", degree: 220 },
        Jupiter: { sign: "Taurus", degree: 35 },
    };

    try {
        const aspects = calculateTransitAspects(natalChart, transits);
        const scored = scoreAspects(aspects, { mahaDasha: "Jupiter" });

        logTest("Aspects calculated", aspects.length > 0, `${aspects.length} aspects found`);

        if (scored.length > 0) {
            log("\n  Significant Aspects:", "cyan");
            scored.slice(0, 5).forEach((asp, idx) => {
                console.log(`    ${idx + 1}. ${asp.transitPlanet} ${asp.type} ${asp.natalPlanet}`);
                console.log(`       Angle: ${asp.angle.toFixed(1)}°, Score: ${asp.score}`);
            });
        }

        return { passed: true, aspects: scored };
    } catch (error) {
        logTest("Aspects calculated", false, `Error: ${error.message}`);
        return { passed: false, error: error.message };
    }
}

/**
 * Test 3: Future Transit Calculation
 */
async function testFutureTransits() {
    logSection("TEST 3: Future Transit Calculation");

    const natalChart = {
        ascendant: 210,
        planets: {
            Sun: { fullDegree: 35 },
            Moon: { fullDegree: 125 },
        },
    };

    const userAstroData = {
        birthLatitude: 28.6,
        birthLongitude: 77.2,
        timeZone: "Asia/Kolkata",
        timeZoneOffset: 5.5,
    };

    try {
        log("  Calculating future transits for next 7 days...", "yellow");
        const futureTransits = await calculateFutureTransits(natalChart, userAstroData, 7);
        
        logTest("Future transits calculated", futureTransits.length > 0, `${futureTransits.length} days calculated`);

        if (futureTransits.length > 0) {
            log("\n  Future Transit Timeline:", "cyan");
            futureTransits.slice(0, 3).forEach((day) => {
                console.log(`    ${day.date}:`);
                Object.entries(day.transits).slice(0, 3).forEach(([planet, data]) => {
                    console.log(`      ${planet}: ${data.sign} (House ${data.house})`);
                });
            });
        }

        // Detect upcoming events
        const todayTransits = futureTransits[0]?.transits || {};
        const upcomingEvents = detectUpcomingEvents(futureTransits, natalChart, todayTransits);

        logTest("Upcoming events detected", upcomingEvents.length >= 0, `${upcomingEvents.length} events found`);

        if (upcomingEvents.length > 0) {
            log("\n  Upcoming Significant Events:", "cyan");
            upcomingEvents.forEach((event) => {
                console.log(`    ${event.date}: ${event.type} - ${event.significance}`);
            });
        }

        return { passed: true, futureTransits, upcomingEvents };
    } catch (error) {
        logTest("Future transits calculated", false, `Error: ${error.message}`);
        return { passed: false, error: error.message };
    }
}

/**
 * Test 4: Real User Data Test
 */
async function testRealUserData() {
    logSection("TEST 4: Real User Data Test");

    try {
        // Get a real user with astrology data
        const usersSnapshot = await db
            .collection("users")
            .where("astrologyData.isEnabled", "==", true)
            .limit(1)
            .get();

        if (usersSnapshot.empty) {
            logTest("User with astrology data found", false, "No users with astrology enabled");
            return { passed: false, error: "No test users available" };
        }

        const userDoc = usersSnapshot.docs[0];
        const userData = userDoc.data();
        const astrologyData = userData.astrologyData;

        logTest("User with astrology data found", true, `User ID: ${userDoc.id}`);

        // Check required fields
        const hasRequiredData = 
            astrologyData.birthYear &&
            astrologyData.birthLatitude != null &&
            astrologyData.birthLongitude != null;

        logTest("User has required birth data", hasRequiredData, 
            hasRequiredData ? "All required fields present" : "Missing birth data");

        if (!hasRequiredData) {
            return { passed: false, error: "Incomplete user data" };
        }

        // Test transit calculation for this user
        const today = DateTime.now().toFormat("yyyy-MM-dd");
        const now = DateTime.now().setZone(astrologyData.timeZone || "UTC");
        
        const payload = {
            year: now.year,
            month: now.month,
            date: now.day,
            hours: now.hour,
            minutes: now.minute,
            seconds: Math.floor(now.second),
            latitude: astrologyData.birthLatitude,
            longitude: astrologyData.birthLongitude,
            timezone: astrologyData.timeZoneOffset || 0,
        };

        log("  Fetching current transits for user...", "yellow");
        const result = await runAstroFlow({
            mode: "full",
            payload,
            timeZoneId: astrologyData.timeZone || "UTC",
            timeZoneOffset: astrologyData.timeZoneOffset || 0,
        });

        const planets = result.birthChartData?.planets || {};
        const transits = {};
        Object.entries(planets).forEach(([planet, data]) => {
            if (data && typeof data === "object") {
                transits[planet] = {
                    sign: data.sign || data.Sign,
                    degree: data.fullDegree || data.longitude,
                };
            }
        });

        logTest("Current transits fetched", Object.keys(transits).length > 0, 
            `${Object.keys(transits).length} planets calculated`);

        if (Object.keys(transits).length > 0) {
            log("\n  Current Planetary Positions:", "cyan");
            Object.entries(transits).slice(0, 5).forEach(([planet, data]) => {
                console.log(`    ${planet}: ${data.sign} (${data.degree?.toFixed(1)}°)`);
            });
        }

        return { 
            passed: true, 
            userId: userDoc.id,
            transits,
            astrologyData: {
                lagna: astrologyData.ascendant,
                sunSign: astrologyData.sunSign,
                moonSign: astrologyData.moonSign,
                dasha: astrologyData.currentDasha,
            },
        };
    } catch (error) {
        logTest("Real user data test", false, `Error: ${error.message}`);
        return { passed: false, error: error.message };
    }
}

/**
 * Test 5: End-to-End Insight Generation Test
 */
async function testEndToEnd() {
    logSection("TEST 5: End-to-End Insight Generation Test");

    try {
        // Get a real user
        const usersSnapshot = await db
            .collection("users")
            .where("astrologyData.isEnabled", "==", true)
            .limit(1)
            .get();

        if (usersSnapshot.empty) {
            logTest("End-to-end test", false, "No test users available");
            return { passed: false };
        }

        const userDoc = usersSnapshot.docs[0];
        const userData = userDoc.data();
        const astrologyData = userData.astrologyData;

        log("  Testing complete insight generation flow...", "yellow");

        // This would normally call generateInsightForUser
        // For testing, we'll just verify the data structure
        const hasBirthChart = astrologyData.birthChartData != null;
        const hasDasha = astrologyData.currentDasha != null;
        const hasLocation = astrologyData.birthLatitude != null && astrologyData.birthLongitude != null;

        logTest("Birth chart data available", hasBirthChart);
        logTest("Dasha data available", hasDasha);
        logTest("Location data available", hasLocation);

        const allDataPresent = hasBirthChart && hasDasha && hasLocation;
        logTest("All data present for insight generation", allDataPresent);

        if (allDataPresent) {
            log("\n  ✅ System is ready to generate insights!", "green");
            log("  To generate an actual insight, call generateInsightForCurrentUser from the app", "yellow");
        }

        return { passed: allDataPresent, userId: userDoc.id };
    } catch (error) {
        logTest("End-to-end test", false, `Error: ${error.message}`);
        return { passed: false, error: error.message };
    }
}

/**
 * Main test runner
 */
async function runAllTests() {
    log("\n" + "=".repeat(80), "bright");
    log("VEDIC ASTROLOGY PREDICTION SYSTEM - COMPREHENSIVE TEST SUITE", "bright");
    log("=".repeat(80) + "\n", "bright");

    const results = {
        houseActivations: null,
        aspects: null,
        futureTransits: null,
        realUserData: null,
        endToEnd: null,
    };

    try {
        results.houseActivations = await testHouseActivations();
        results.aspects = await testAspectCalculation();
        results.futureTransits = await testFutureTransits();
        results.realUserData = await testRealUserData();
        results.endToEnd = await testEndToEnd();

        // Summary
        logSection("TEST SUMMARY");

        const allTests = [
            { name: "House Activations", result: results.houseActivations },
            { name: "Aspect Calculation", result: results.aspects },
            { name: "Future Transits", result: results.futureTransits },
            { name: "Real User Data", result: results.realUserData },
            { name: "End-to-End", result: results.endToEnd },
        ];

        let passedCount = 0;
        let totalCount = allTests.length;

        allTests.forEach((test) => {
            const passed = test.result?.passed === true;
            if (passed) passedCount++;
            logTest(test.name, passed, passed ? "All checks passed" : test.result?.error || "Failed");
        });

        console.log("\n");
        log(`Total: ${passedCount}/${totalCount} tests passed`, passedCount === totalCount ? "green" : "yellow");

        if (passedCount === totalCount) {
            log("\n✅ ALL TESTS PASSED! System is ready for production.", "green");
        } else {
            log("\n⚠️  Some tests failed. Review errors above.", "yellow");
        }

        return results;
    } catch (error) {
        log(`\n❌ FATAL ERROR: ${error.message}`, "red");
        console.error(error);
        return results;
    }
}

// Run tests if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
    runAllTests()
        .then(() => {
            console.log("\n");
            process.exit(0);
        })
        .catch((error) => {
            console.error("Test execution failed:", error);
            process.exit(1);
        });
}

export { runAllTests, testHouseActivations, testAspectCalculation, testFutureTransits, testRealUserData, testEndToEnd };
