/**
 * Runtime Issues Test
 * Tests actual function execution and identifies runtime problems
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
} from "./lib/cache_utils.js";

const issues = [];
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
            console.log(`❌ ${name}`);
            issues.push({ name, details });
        }
        if (details) console.log(`   ${details}`);
    }
}

async function testVedicCalculationsWithRealData() {
    console.log("\n🧪 Testing Vedic Calculations with Real Data...\n");
    
    // Test data that mimics real user data
    const natalChart = {
        ascendant: 120.5, // Leo ascendant
        planets: {
            Sun: { fullDegree: 45.2, sign: "Aries", house: 1 },
            Moon: { fullDegree: 180.3, sign: "Virgo", house: 6 },
            Mars: { fullDegree: 300.1, sign: "Aquarius", house: 11 },
            Jupiter: { fullDegree: 60.5, sign: "Gemini", house: 3 },
            Venus: { fullDegree: 15.8, sign: "Aries", house: 1 },
            Saturn: { fullDegree: 240.2, sign: "Sagittarius", house: 9 },
            Ascendant: { fullDegree: 120.5, sign: "Leo", house: 1 },
        },
    };
    
    const transits = {
        Sun: { degree: 60.0, sign: "Gemini", house: 3 },
        Moon: { degree: 200.0, sign: "Libra", house: 7 },
        Mars: { degree: 320.0, sign: "Pisces", house: 12 },
        Jupiter: { degree: 80.0, sign: "Gemini", house: 3 },
        Venus: { degree: 30.0, sign: "Aries", house: 1 },
        Saturn: { degree: 250.0, sign: "Sagittarius", house: 9 },
    };
    
    try {
        // Test house activations
        const houseActivations = calculateHouseActivations(natalChart, transits);
        logResult(
            "House Activations Calculation",
            houseActivations.length > 0,
            `Found ${houseActivations.length} activations`
        );
        
        if (houseActivations.length > 0) {
            const firstActivation = houseActivations[0];
            logResult(
                "House Activation Structure",
                !!firstActivation.planet && !!firstActivation.house && !!firstActivation.signification,
                `Example: ${firstActivation.planet} → House ${firstActivation.house} (${firstActivation.signification})`
            );
        }
        
        // Test aspects
        const aspects = calculateTransitAspects(natalChart, transits);
        logResult(
            "Aspect Calculations",
            aspects.length > 0,
            `Found ${aspects.length} aspects`
        );
        
        if (aspects.length > 0) {
            const firstAspect = aspects[0];
            logResult(
                "Aspect Structure",
                !!firstAspect.transitPlanet && !!firstAspect.natalPlanet && !!firstAspect.type,
                `Example: ${firstAspect.transitPlanet} ${firstAspect.type} ${firstAspect.natalPlanet}`
            );
        }
        
        // Test scoring
        const dashaData = { mahaDasha: "Jupiter", antarDasha: "Mars" };
        const scoredActivations = scoreHouseActivations(houseActivations, dashaData);
        const scoredAspects = scoreAspects(aspects, dashaData);
        
        logResult(
            "Scoring System",
            scoredActivations.length > 0 && scoredAspects.length > 0,
            `Scored ${scoredActivations.length} activations, ${scoredAspects.length} aspects`
        );
        
        if (scoredActivations.length > 0) {
            const topActivation = scoredActivations[0];
            logResult(
                "Scoring Adds Score Field",
                typeof topActivation.score === 'number' && topActivation.score > 0,
                `Top activation score: ${topActivation.score}`
            );
        }
        
    } catch (error) {
        logResult("Vedic Calculations", false, `Error: ${error.message}`);
        console.error("   Stack:", error.stack);
    }
}

async function testCacheOperations() {
    console.log("\n🧪 Testing Cache Operations...\n");
    
    const today = DateTime.now().toFormat("yyyy-MM-dd");
    const lat = 28.6139;
    const lng = 77.2090;
    
    const testData = {
        panchang: { tithi: "Shukla Paksha", nakshatra: "Rohini" },
        transits: { Sun: { sign: "Aries", degree: 30 } },
    };
    
    try {
        // Test cache write
        await cacheTransitData(today, lat, lng, testData);
        logResult("Cache Write", true, "Data written to cache");
        
        // Test cache read
        const cached = await getCachedTransitData(today, lat, lng);
        logResult(
            "Cache Read",
            cached !== null,
            cached ? "Cache hit successful" : "Cache miss"
        );
        
        if (cached) {
            logResult(
                "Cache Data Structure",
                !!cached.panchang && !!cached.transits,
                "Cache contains panchang and transits"
            );
        }
        
    } catch (error) {
        logResult("Cache Operations", false, `Error: ${error.message}`);
        console.error("   Stack:", error.stack);
    }
}

async function testChartSignature() {
    console.log("\n🧪 Testing Chart Signature Generation...\n");
    
    const testData = {
        sunSign: "Aries",
        moonSign: "Leo",
        ascendant: "Scorpio",
        nakshatra: "Rohini",
    };
    
    try {
        const signature = generateChartSignature(testData);
        logResult(
            "Chart Signature Generation",
            signature.length > 0 && signature.includes("aries"),
            `Signature: ${signature}`
        );
        
        // Test with missing data
        const partialData = { sunSign: "Aries" };
        const partialSig = generateChartSignature(partialData);
        logResult(
            "Partial Data Handling",
            partialSig.length > 0,
            `Handles missing data: ${partialSig}`,
            true // Warning
        );
        
    } catch (error) {
        logResult("Chart Signature", false, `Error: ${error.message}`);
    }
}

async function testEdgeCases() {
    console.log("\n🧪 Testing Edge Cases...\n");
    
    try {
        // Test with null ascendant
        const nullAscendantChart = {
            ascendant: null,
            planets: { Sun: { fullDegree: 30 } },
        };
        const nullTransits = { Sun: { degree: 60 } };
        
        const nullResult = calculateHouseActivations(nullAscendantChart, nullTransits);
        logResult(
            "Null Ascendant Handling",
            Array.isArray(nullResult) && nullResult.length === 0,
            "Returns empty array for null ascendant",
            true // Warning
        );
        
        // Test with empty transits
        const emptyTransits = {};
        const emptyResult = calculateHouseActivations(
            { ascendant: 120, planets: {} },
            emptyTransits
        );
        logResult(
            "Empty Transits Handling",
            Array.isArray(emptyResult),
            "Handles empty transits gracefully",
            true
        );
        
        // Test with missing planets
        const missingPlanetsChart = {
            ascendant: 120,
            planets: {},
        };
        const missingResult = calculateHouseActivations(missingPlanetsChart, {
            Sun: { degree: 60 },
        });
        logResult(
            "Missing Planets Handling",
            Array.isArray(missingResult),
            "Handles missing natal planets",
            true
        );
        
    } catch (error) {
        logResult("Edge Cases", false, `Error: ${error.message}`);
    }
}

async function testFirestoreConnection() {
    console.log("\n🧪 Testing Firestore Connection...\n");
    
    try {
        // Try to read a collection (should work even if empty)
        const testRef = db.collection("_test_connection");
        await testRef.limit(1).get();
        
        logResult("Firestore Connection", true, "Successfully connected to Firestore");
        
    } catch (error) {
        logResult(
            "Firestore Connection",
            false,
            `Error: ${error.message}. Check Firebase initialization.`
        );
    }
}

async function generateReport() {
    console.log("\n" + "=".repeat(60));
    console.log("📊 Runtime Issues Report");
    console.log("=".repeat(60));
    console.log(`✅ Passed: ${passedTests.length}`);
    console.log(`❌ Issues: ${issues.length}`);
    console.log(`⚠️  Warnings: ${warnings.length}`);
    console.log("=".repeat(60));
    
    if (issues.length > 0) {
        console.log("\n❌ CRITICAL ISSUES:");
        issues.forEach((issue, i) => {
            console.log(`   ${i + 1}. ${issue.name}`);
            if (issue.details) console.log(`      ${issue.details}`);
        });
    }
    
    if (warnings.length > 0) {
        console.log("\n⚠️  WARNINGS:");
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
            issues: issues.length,
            warnings: warnings.length,
        },
        passed: passedTests,
        issues,
        warnings,
    };
    
    fs.writeFileSync('runtime_issues_report.json', JSON.stringify(report, null, 2));
    console.log("\n📄 Report saved to runtime_issues_report.json");
    
    return issues.length === 0;
}

async function runRuntimeTests() {
    console.log("🚀 Running Runtime Issues Tests...\n");
    console.log("=".repeat(60));
    
    await testFirestoreConnection();
    await testVedicCalculationsWithRealData();
    await testCacheOperations();
    await testChartSignature();
    await testEdgeCases();
    
    const success = await generateReport();
    
    if (success) {
        console.log("\n✅ Runtime tests complete. No critical issues found!");
        process.exit(0);
    } else {
        console.log(`\n❌ Runtime tests complete. Found ${issues.length} critical issue(s).`);
        process.exit(1);
    }
}

runRuntimeTests();

