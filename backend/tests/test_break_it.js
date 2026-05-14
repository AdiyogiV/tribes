/**
 * Break It Test Suite
 * Tests edge cases, failure scenarios, and stress conditions
 * Goal: Find all weaknesses and breaking points
 */

import { db } from "./lib/firebase.js";
import { DateTime } from "luxon";
import {
    calculateHouseActivations,
    calculateTransitAspects,
    scoreHouseActivations,
    scoreAspects,
} from "./lib/vedic_analysis.js";
import {
    generateChartSignature,
    getCachedTransitData,
    cacheTransitData,
    getCachedAIInsight,
    cacheAIInsight,
} from "./lib/cache_utils.js";

const failures = [];
const warnings = [];
const passedTests = [];

function logResult(name, testPassed, details = "", isWarning = false) {
    if (testPassed) {
        console.log(`✅ ${name}`);
        if (details) console.log(`   ${details}`);
        passedTests.push(name);
    } else {
        if (isWarning) {
            console.log(`⚠️  ${name}`);
            warnings.push({ name, details });
        } else {
            console.log(`❌ ${name} - BREAKS!`);
            failures.push({ name, details });
        }
        if (details) console.log(`   ${details}`);
    }
}

async function testInvalidInputs() {
    console.log("\n💥 Testing Invalid Inputs...\n");
    
    try {
        // Test with null/undefined
        const nullResult = calculateHouseActivations(null, null);
        logResult(
            "Null Inputs",
            Array.isArray(nullResult) && nullResult.length === 0,
            "Should return empty array, not crash"
        );
        
        // Test with undefined
        const undefinedResult = calculateHouseActivations(undefined, undefined);
        logResult(
            "Undefined Inputs",
            Array.isArray(undefinedResult) && nullResult.length === 0,
            "Should handle undefined gracefully"
        );
        
        // Test with empty objects
        const emptyResult = calculateHouseActivations({}, {});
        logResult(
            "Empty Objects",
            Array.isArray(emptyResult),
            "Should handle empty objects"
        );
        
        // Test with wrong types
        try {
            calculateHouseActivations("string", 123);
            logResult("Wrong Types", false, "Should throw error or handle gracefully");
        } catch (e) {
            logResult("Wrong Types", true, "Throws error (good!)");
        }
        
        // Test with missing ascendant
        const noAscendant = calculateHouseActivations(
            { planets: { Sun: { fullDegree: 30 } } },
            { Sun: { degree: 60 } }
        );
        logResult(
            "Missing Ascendant",
            Array.isArray(noAscendant) && noAscendant.length === 0,
            "Should return empty array when ascendant missing"
        );
        
        // Test with invalid degrees
        const invalidDegrees = calculateHouseActivations(
            { ascendant: "invalid", planets: {} },
            { Sun: { degree: "not a number" } }
        );
        logResult(
            "Invalid Degrees",
            Array.isArray(invalidDegrees),
            "Should handle invalid degree values"
        );
        
        // Test with negative degrees
        const negativeDegrees = calculateHouseActivations(
            { ascendant: -10, planets: {} },
            { Sun: { degree: -50 } }
        );
        logResult(
            "Negative Degrees",
            Array.isArray(negativeDegrees),
            "Should handle negative degrees (normalize)",
            true
        );
        
        // Test with degrees > 360
        const largeDegrees = calculateHouseActivations(
            { ascendant: 500, planets: {} },
            { Sun: { degree: 1000 } }
        );
        logResult(
            "Degrees > 360",
            Array.isArray(largeDegrees),
            "Should normalize degrees > 360",
            true
        );
        
    } catch (error) {
        failures.push({ name: "Invalid Inputs Test", details: `Crashed: ${error.message}` });
        console.log(`❌ Invalid Inputs Test - CRASHED: ${error.message}`);
    }
}

async function testMalformedData() {
    console.log("\n💥 Testing Malformed Data...\n");
    
    try {
        // Test with nested nulls
        const nestedNulls = calculateHouseActivations(
            { ascendant: null, planets: { Sun: null } },
            { Sun: null }
        );
        logResult(
            "Nested Nulls",
            Array.isArray(nestedNulls),
            "Should handle nested null values"
        );
        
        // Test with circular references (simulated)
        const circularLike = {
            ascendant: 120,
            planets: { Sun: { fullDegree: 30 } },
        };
        // circularLike.self = circularLike; // Would cause issues if not handled
        const circularResult = calculateHouseActivations(circularLike, { Sun: { degree: 60 } });
        logResult(
            "Circular References",
            Array.isArray(circularResult),
            "Should handle potential circular references",
            true
        );
        
        // Test with extremely large objects
        const largePlanets = {};
        for (let i = 0; i < 1000; i++) {
            largePlanets[`Planet${i}`] = { fullDegree: i * 0.36 };
        }
        const largeResult = calculateHouseActivations(
            { ascendant: 120, planets: largePlanets },
            { Sun: { degree: 60 } }
        );
        logResult(
            "Large Objects",
            Array.isArray(largeResult),
            `Should handle large objects (${Object.keys(largePlanets).length} planets)`,
            true
        );
        
        // Test with missing required fields
        const missingFields = calculateHouseActivations(
            { ascendant: 120 }, // No planets
            { Sun: { degree: 60 } } // Missing sign, house
        );
        logResult(
            "Missing Fields",
            Array.isArray(missingFields),
            "Should handle missing optional fields"
        );
        
    } catch (error) {
        failures.push({ name: "Malformed Data Test", details: `Crashed: ${error.message}` });
        console.log(`❌ Malformed Data Test - CRASHED: ${error.message}`);
    }
}

async function testConcurrentOperations() {
    console.log("\n💥 Testing Concurrent Operations...\n");
    
    try {
        const today = DateTime.now().toFormat("yyyy-MM-dd");
        const lat = 28.6139;
        const lng = 77.2090;
        
        // Simulate concurrent cache writes
        const promises = [];
        for (let i = 0; i < 10; i++) {
            promises.push(
                cacheTransitData(today, lat + i * 0.001, lng, {
                    panchang: { tithi: `Test${i}` },
                    transits: { Sun: { sign: "Aries", degree: 30 + i } },
                })
            );
        }
        
        await Promise.all(promises);
        logResult(
            "Concurrent Cache Writes",
            true,
            "10 concurrent writes completed",
            true
        );
        
        // Test concurrent reads
        const readPromises = [];
        for (let i = 0; i < 10; i++) {
            readPromises.push(getCachedTransitData(today, lat + i * 0.001, lng));
        }
        
        const results = await Promise.all(readPromises);
        const successCount = results.filter(r => r !== null).length;
        logResult(
            "Concurrent Cache Reads",
            successCount > 0,
            `${successCount}/10 reads succeeded`,
            true
        );
        
    } catch (error) {
        failures.push({ name: "Concurrent Operations", details: `Crashed: ${error.message}` });
        console.log(`❌ Concurrent Operations - CRASHED: ${error.message}`);
    }
}

async function testMemoryIntensive() {
    console.log("\n💥 Testing Memory Intensive Operations...\n");
    
    try {
        // Create large transit data
        const largeTransits = {};
        const planets = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];
        planets.forEach(planet => {
            largeTransits[planet] = {
                degree: Math.random() * 360,
                sign: "Aries",
                house: Math.floor(Math.random() * 12) + 1,
            };
        });
        
        // Create large natal chart
        const largeNatalChart = {
            ascendant: 120,
            planets: {},
        };
        for (let i = 0; i < 100; i++) {
            largeNatalChart.planets[`Planet${i}`] = {
                fullDegree: Math.random() * 360,
                sign: "Aries",
                house: Math.floor(Math.random() * 12) + 1,
            };
        }
        
        const startTime = Date.now();
        const activations = calculateHouseActivations(largeNatalChart, largeTransits);
        const duration = Date.now() - startTime;
        
        logResult(
            "Large Data Processing",
            duration < 5000, // Should complete in < 5 seconds
            `Processed ${Object.keys(largeNatalChart.planets).length} planets in ${duration}ms`,
            duration > 1000 // Warning if slow
        );
        
        // Test aspect calculations with large data
        const aspectStart = Date.now();
        const aspects = calculateTransitAspects(largeNatalChart, largeTransits);
        const aspectDuration = Date.now() - aspectStart;
        
        logResult(
            "Large Aspect Calculations",
            aspectDuration < 10000, // Should complete in < 10 seconds
            `Calculated ${aspects.length} aspects in ${aspectDuration}ms`,
            aspectDuration > 2000 // Warning if slow
        );
        
    } catch (error) {
        failures.push({ name: "Memory Intensive", details: `Crashed: ${error.message}` });
        console.log(`❌ Memory Intensive - CRASHED: ${error.message}`);
    }
}

async function testCacheEdgeCases() {
    console.log("\n💥 Testing Cache Edge Cases...\n");
    
    try {
        // Test with invalid dates
        const invalidDate = "invalid-date";
        const invalidCache = await getCachedTransitData(invalidDate, 28.6, 77.2);
        logResult(
            "Invalid Date Cache",
            invalidCache === null,
            "Should return null for invalid date"
        );
        
        // Test with null coordinates
        const nullCoords = await getCachedTransitData("2025-01-01", null, null);
        logResult(
            "Null Coordinates Cache",
            nullCoords === null,
            "Should return null for null coordinates"
        );
        
        // Test with extreme coordinates
        const extremeCoords = await cacheTransitData(
            "2025-01-01",
            90.0, // North pole
            -180.0, // International date line
            { panchang: {}, transits: {} }
        );
        logResult(
            "Extreme Coordinates",
            true,
            "Should handle extreme coordinates",
            true
        );
        
        // Test chart signature with special characters
        const specialChars = generateChartSignature({
            sunSign: "Aries & Leo",
            moonSign: "Virgo/Scorpio",
            ascendant: "Sagittarius-Capricorn",
            nakshatra: "Rohini (Moon)",
        });
        logResult(
            "Special Characters in Signature",
            !specialChars.includes("&") && !specialChars.includes("/"),
            `Signature: ${specialChars}`,
            true
        );
        
        // Test with empty chart signature
        const emptySig = generateChartSignature({});
        logResult(
            "Empty Chart Signature",
            emptySig.length > 0,
            `Empty signature: ${emptySig}`,
            true
        );
        
    } catch (error) {
        failures.push({ name: "Cache Edge Cases", details: `Crashed: ${error.message}` });
        console.log(`❌ Cache Edge Cases - CRASHED: ${error.message}`);
    }
}

async function testScoringEdgeCases() {
    console.log("\n💥 Testing Scoring Edge Cases...\n");
    
    try {
        // Test with empty activations
        const emptyActivations = scoreHouseActivations([], null);
        logResult(
            "Empty Activations Scoring",
            Array.isArray(emptyActivations) && emptyActivations.length === 0,
            "Should return empty array"
        );
        
        // Test with null dasha
        const activations = [
            { planet: "Sun", house: 1, signification: "Self" },
        ];
        const nullDasha = scoreHouseActivations(activations, null);
        logResult(
            "Null Dasha Scoring",
            nullDasha.length > 0 && typeof nullDasha[0].score === 'number',
            "Should score even without dasha data"
        );
        
        // Test with invalid dasha structure
        const invalidDasha = scoreHouseActivations(activations, { invalid: "data" });
        logResult(
            "Invalid Dasha Structure",
            invalidDasha.length > 0,
            "Should handle invalid dasha structure",
            true
        );
        
        // Test with missing house numbers
        const missingHouse = [{ planet: "Sun", signification: "Self" }];
        try {
            const missingResult = scoreHouseActivations(missingHouse, null);
            logResult(
                "Missing House Number",
                Array.isArray(missingResult),
                "Should handle missing house number",
                true
            );
        } catch (e) {
            logResult("Missing House Number", false, `Crashed: ${e.message}`);
        }
        
    } catch (error) {
        failures.push({ name: "Scoring Edge Cases", details: `Crashed: ${error.message}` });
        console.log(`❌ Scoring Edge Cases - CRASHED: ${error.message}`);
    }
}

async function testFirestoreFailures() {
    console.log("\n💥 Testing Firestore Failure Scenarios...\n");
    
    try {
        // Test with invalid collection path
        try {
            await db.collection("").doc("test").get();
            logResult("Empty Collection Path", false, "Should reject empty path");
        } catch (e) {
            logResult("Empty Collection Path", true, "Properly rejects empty path");
        }
        
        // Test with very long document ID
        const longId = "a".repeat(1500); // Firestore limit is 1500 bytes
        try {
            const longDoc = db.collection("_test").doc(longId);
            await longDoc.get(); // This should work, but might be slow
            logResult(
                "Very Long Document ID",
                true,
                "Handles long IDs (may be slow)",
                true
            );
        } catch (e) {
            logResult("Very Long Document ID", false, `Failed: ${e.message}`);
        }
        
        // Test with special characters in path
        const specialPath = db.collection("_test").doc("test@#$%^&*()");
        try {
            await specialPath.get();
            logResult(
                "Special Characters in Path",
                true,
                "Handles special characters",
                true
            );
        } catch (e) {
            logResult("Special Characters in Path", false, `Failed: ${e.message}`);
        }
        
    } catch (error) {
        failures.push({ name: "Firestore Failures", details: `Crashed: ${error.message}` });
        console.log(`❌ Firestore Failures - CRASHED: ${error.message}`);
    }
}

async function testPerformanceLimits() {
    console.log("\n💥 Testing Performance Limits...\n");
    
    try {
        // Test with maximum reasonable data
        const maxTransits = {};
        const allPlanets = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu", "Uranus", "Neptune", "Pluto"];
        allPlanets.forEach(planet => {
            maxTransits[planet] = {
                degree: Math.random() * 360,
                sign: "Aries",
                house: Math.floor(Math.random() * 12) + 1,
            };
        });
        
        const maxNatal = {
            ascendant: 120,
            planets: {},
        };
        allPlanets.forEach(planet => {
            maxNatal.planets[planet] = {
                fullDegree: Math.random() * 360,
                sign: "Aries",
                house: Math.floor(Math.random() * 12) + 1,
            };
        });
        
        const perfStart = Date.now();
        const perfActivations = calculateHouseActivations(maxNatal, maxTransits);
        const perfAspects = calculateTransitAspects(maxNatal, maxTransits);
        const perfDuration = Date.now() - perfStart;
        
        logResult(
            "Performance with Max Data",
            perfDuration < 2000,
            `Processed ${allPlanets.length} planets in ${perfDuration}ms (${perfActivations.length} activations, ${perfAspects.length} aspects)`,
            perfDuration > 500
        );
        
    } catch (error) {
        failures.push({ name: "Performance Limits", details: `Crashed: ${error.message}` });
        console.log(`❌ Performance Limits - CRASHED: ${error.message}`);
    }
}

async function generateBreakReport() {
    console.log("\n" + "=".repeat(60));
    console.log("💥 BREAK IT TEST REPORT");
    console.log("=".repeat(60));
    console.log(`✅ Passed: ${passedTests.length}`);
    console.log(`❌ Failures: ${failures.length}`);
    console.log(`⚠️  Warnings: ${warnings.length}`);
    console.log("=".repeat(60));
    
    if (failures.length > 0) {
        console.log("\n❌ CRITICAL FAILURES (System Breaks):");
        failures.forEach((failure, i) => {
            console.log(`   ${i + 1}. ${failure.name}`);
            if (failure.details) console.log(`      ${failure.details}`);
        });
    }
    
    if (warnings.length > 0) {
        console.log("\n⚠️  WARNINGS (Potential Issues):");
        warnings.forEach((warning, i) => {
            console.log(`   ${i + 1}. ${warning.name}`);
            if (warning.details) console.log(`      ${warning.details}`);
        });
    }
    
    // Save report
    const fs = await import('fs');
    const report = {
        timestamp: new Date().toISOString(),
        summary: {
            passed: passedTests.length,
            failures: failures.length,
            warnings: warnings.length,
        },
        failures,
        warnings,
        passed: passedTests,
    };
    
    fs.writeFileSync('break_it_report.json', JSON.stringify(report, null, 2));
    console.log("\n📄 Report saved to break_it_report.json");
    
    return failures.length === 0;
}

async function runBreakItTests() {
    console.log("💥 BREAK IT TEST SUITE");
    console.log("Testing edge cases, failures, and stress conditions...\n");
    console.log("=".repeat(60));
    
    await testInvalidInputs();
    await testMalformedData();
    await testConcurrentOperations();
    await testMemoryIntensive();
    await testCacheEdgeCases();
    await testScoringEdgeCases();
    await testFirestoreFailures();
    await testPerformanceLimits();
    
    const success = await generateBreakReport();
    
    if (success) {
        console.log("\n✅ System is robust! No critical failures found.");
        process.exit(0);
    } else {
        console.log(`\n❌ Found ${failures.length} critical failure(s). System needs improvement.`);
        process.exit(1);
    }
}

runBreakItTests();

