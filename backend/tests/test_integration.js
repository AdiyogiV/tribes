/**
 * Comprehensive Integration Test
 * Tests actual Cloud Functions execution and Firestore operations
 * Run with: node test_integration.js
 */

import { db } from "./lib/firebase.js";
import { DateTime } from "luxon";
import {
    generateLatLngHash,
    generateChartSignature,
    generateTransitHash,
    getCachedTransitData,
    cacheTransitData,
    getCachedAIInsight,
    cacheAIInsight,
} from "./lib/cache_utils.js";
import {
    calculateHouseActivations,
    calculateTransitAspects,
    scoreHouseActivations,
    scoreAspects,
} from "./lib/vedic_analysis.js";

// Test user data (mock)
const TEST_USER_ID = "test_user_" + Date.now();
const TEST_USER_DATA = {
    userId: TEST_USER_ID,
    birthYear: 1990,
    birthMonth: 5,
    birthDay: 15,
    birthTime: "10:30",
    birthLatitude: 28.6139, // Delhi
    birthLongitude: 77.2090,
    timeZone: "Asia/Kolkata",
    timeZoneOffset: 5.5,
    sunSign: "Taurus",
    moonSign: "Leo",
    ascendant: "Scorpio",
    nakshatra: "Rohini",
    currentDasha: {
        mahaDasha: "Venus",
        antarDasha: "Sun",
    },
    birthChartData: {
        output: {
            Ascendant: { fullDegree: 240, longitude: 240, sign: "Scorpio", house: 1 },
            Sun: { fullDegree: 45, longitude: 45, sign: "Taurus", house: 2 },
            Moon: { fullDegree: 120, longitude: 120, sign: "Leo", house: 5 },
            Mars: { fullDegree: 180, longitude: 180, sign: "Virgo", house: 6 },
        },
    },
};

let testsPassed = 0;
let testsFailed = 0;

function logTest(name, passed, details = "") {
    if (passed) {
        console.log(`✅ ${name}`);
        testsPassed++;
        if (details) console.log(`   ${details}`);
    } else {
        console.log(`❌ ${name}`);
        testsFailed++;
        if (details) console.log(`   ${details}`);
    }
}

async function testCacheOperations() {
    console.log("\n🧪 Testing Cache Operations (Firestore)...");
    
    const today = DateTime.now().toFormat("yyyy-MM-dd");
    const lat = TEST_USER_DATA.birthLatitude;
    const lng = TEST_USER_DATA.birthLongitude;
    
    // Test 1: Cache transit data
    try {
        const testTransitData = {
            panchang: { tithi: "Shukla Paksha", nakshatra: "Rohini" },
            transits: {
                Sun: { sign: "Aries", house: 1, degree: 30 },
                Moon: { sign: "Leo", house: 5, degree: 120 },
            },
        };
        
        await cacheTransitData(today, lat, lng, testTransitData);
        logTest("Cache Transit Data", true, "Data written to Firestore");
        
        // Test 2: Retrieve cached data
        const cached = await getCachedTransitData(today, lat, lng);
        const cacheHit = cached !== null && cached.panchang !== undefined;
        logTest("Retrieve Cached Transit Data", cacheHit, cacheHit ? "Cache hit successful" : "Cache miss or error");
        
        if (cached) {
            logTest("Cached Data Structure", 
                cached.panchang && cached.transits,
                `Panchang: ${cached.panchang.tithi}, Transits: ${Object.keys(cached.transits).length} planets`
            );
        }
    } catch (error) {
        logTest("Cache Operations", false, `Error: ${error.message}`);
    }
}

async function testAIInsightCache() {
    console.log("\n🧪 Testing AI Insight Cache...");
    
    const today = DateTime.now().toFormat("yyyy-MM-dd");
    const chartSig = generateChartSignature(TEST_USER_DATA);
    const transitHash = "test_hash_123";
    const testInsight = "This is a test insight for verification.";
    
    try {
        // Cache AI insight
        await cacheAIInsight(chartSig, today, transitHash, testInsight);
        logTest("Cache AI Insight", true, "Insight cached");
        
        // Retrieve cached insight
        const cached = await getCachedAIInsight(chartSig, today, transitHash);
        const cacheHit = cached === testInsight;
        logTest("Retrieve Cached AI Insight", cacheHit, cacheHit ? "Cache hit - insight matches" : "Cache miss");
        
    } catch (error) {
        logTest("AI Insight Cache", false, `Error: ${error.message}`);
    }
}

async function testVedicCalculations() {
    console.log("\n🧪 Testing Vedic Calculations with Real Data...");
    
    try {
        const natalChart = {
            ascendant: 240, // Scorpio
            planets: TEST_USER_DATA.birthChartData.output,
        };
        
        const transits = {
            Sun: { degree: 30, sign: "Aries", house: 1 },
            Moon: { degree: 120, sign: "Leo", house: 5 },
            Mars: { degree: 180, sign: "Virgo", house: 6 },
            Jupiter: { degree: 270, sign: "Sagittarius", house: 9 },
        };
        
        // Test house activations
        const activations = calculateHouseActivations(natalChart, transits);
        logTest("House Activations Calculation", 
            activations.length > 0,
            `Found ${activations.length} activations: ${activations.map(a => `${a.planet}→H${a.house}`).join(", ")}`
        );
        
        // Test aspects
        const aspects = calculateTransitAspects(natalChart, transits);
        logTest("Aspects Calculation",
            aspects.length > 0,
            `Found ${aspects.length} aspects: ${aspects.slice(0, 3).map(a => `${a.transitPlanet} ${a.type} ${a.natalPlanet}`).join(", ")}`
        );
        
        // Test scoring
        const scoredActivations = scoreHouseActivations(activations, TEST_USER_DATA.currentDasha);
        const scoredAspects = scoreAspects(aspects, TEST_USER_DATA.currentDasha);
        
        logTest("Scoring House Activations",
            scoredActivations.length > 0 && scoredActivations[0].significance !== undefined,
            `Top activation: ${scoredActivations[0]?.planet} (significance: ${scoredActivations[0]?.significance})`
        );
        
        logTest("Scoring Aspects",
            scoredAspects.length > 0 && scoredAspects[0].significance !== undefined,
            `Top aspect: ${scoredAspects[0]?.transitPlanet} ${scoredAspects[0]?.type} ${scoredAspects[0]?.natalPlanet} (significance: ${scoredAspects[0]?.significance})`
        );
        
    } catch (error) {
        logTest("Vedic Calculations", false, `Error: ${error.message}`);
        console.error(error.stack);
    }
}

async function testFirestoreOperations() {
    console.log("\n🧪 Testing Firestore Operations...");
    
    try {
        const today = DateTime.now().toFormat("yyyy-MM-dd");
        
        // Test 1: Write daily insight
        const insightRef = db.collection("users").doc(TEST_USER_ID).collection("dailyInsights").doc(today);
        const testInsightData = {
            insight: "Test insight for integration testing",
            date: today,
            generatedAt: new Date(),
            astrologicalData: {
                transits: { Sun: { sign: "Aries", house: 1 } },
                panchang: { tithi: "Shukla Paksha" },
                houseActivations: [{ planet: "Sun", house: 1, signification: "Self" }],
                significantAspects: [{ transitPlanet: "Sun", natalPlanet: "Moon", type: "square" }],
            },
            notificationSent: false,
        };
        
        await insightRef.set(testInsightData);
        logTest("Write Daily Insight to Firestore", true, "Insight document created");
        
        // Test 2: Read daily insight
        const insightDoc = await insightRef.get();
        const readSuccess = insightDoc.exists && insightDoc.data().insight === testInsightData.insight;
        logTest("Read Daily Insight from Firestore", readSuccess, readSuccess ? "Insight retrieved correctly" : "Read failed");
        
        // Test 3: Write favorite insight
        const favoriteRef = db.collection("users").doc(TEST_USER_ID).collection("favoriteInsights").doc(today);
        await favoriteRef.set({
            insightId: today,
            date: today,
            createdAt: new Date(),
        });
        logTest("Write Favorite Insight", true, "Favorite document created");
        
        // Test 4: Read favorite insight
        const favoriteDoc = await favoriteRef.get();
        const favoriteReadSuccess = favoriteDoc.exists;
        logTest("Read Favorite Insight", favoriteReadSuccess, favoriteReadSuccess ? "Favorite retrieved" : "Read failed");
        
        // Test 5: Write feedback
        const feedbackRef = db.collection("users").doc(TEST_USER_ID).collection("insightFeedback").doc();
        await feedbackRef.set({
            insightId: today,
            date: today,
            feedback: "thumbs_up",
            rating: 1,
            createdAt: new Date(),
        });
        logTest("Write Insight Feedback", true, "Feedback document created");
        
        // Cleanup test data
        await insightRef.delete();
        await favoriteRef.delete();
        await feedbackRef.delete();
        logTest("Cleanup Test Data", true, "Test documents deleted");
        
    } catch (error) {
        logTest("Firestore Operations", false, `Error: ${error.message}`);
        console.error(error.stack);
    }
}

async function testDataStructures() {
    console.log("\n🧪 Testing Data Structure Compatibility...");
    
    try {
        // Test chart signature generation
        const sig = generateChartSignature(TEST_USER_DATA);
        logTest("Chart Signature Generation",
            sig.includes("taurus") && sig.includes("leo") && sig.includes("scorpio"),
            `Signature: ${sig}`
        );
        
        // Test transit hash generation
        const transits = {
            Sun: { sign: "Aries", house: 1 },
            Moon: { sign: "Leo", house: 5 },
        };
        const hash = generateTransitHash(transits);
        logTest("Transit Hash Generation",
            hash.includes("Sun") && hash.includes("Moon"),
            `Hash: ${hash.substring(0, 50)}...`
        );
        
        // Test lat/lng hash
        const latLngHash = generateLatLngHash(TEST_USER_DATA.birthLatitude, TEST_USER_DATA.birthLongitude);
        logTest("Lat/Lng Hash Generation",
            latLngHash === "28.6_77.2",
            `Hash: ${latLngHash}`
        );
        
    } catch (error) {
        logTest("Data Structure Compatibility", false, `Error: ${error.message}`);
    }
}

async function testErrorHandling() {
    console.log("\n🧪 Testing Error Handling...");
    
    try {
        // Test null handling in cache functions
        const nullCache = await getCachedTransitData("2025-01-01", null, null);
        logTest("Null Lat/Lng Handling", nullCache === null, "Returns null for invalid input");
        
        // Test empty transits hash
        const emptyHash = generateTransitHash({});
        logTest("Empty Transits Hash", emptyHash === "default", `Returns default: ${emptyHash}`);
        
        // Test missing chart data
        const missingSig = generateChartSignature({});
        logTest("Missing Chart Data Handling", typeof missingSig === "string", `Handles missing data: ${missingSig}`);
        
    } catch (error) {
        logTest("Error Handling", false, `Error: ${error.message}`);
    }
}

async function runAllTests() {
    console.log("🚀 Starting Comprehensive Integration Tests...\n");
    console.log("=".repeat(60));
    
    try {
        await testDataStructures();
        await testVedicCalculations();
        await testCacheOperations();
        await testAIInsightCache();
        await testFirestoreOperations();
        await testErrorHandling();
        
        console.log("\n" + "=".repeat(60));
        console.log("📊 Test Summary:");
        console.log("=".repeat(60));
        console.log(`   ✅ Passed: ${testsPassed}`);
        console.log(`   ❌ Failed: ${testsFailed}`);
        console.log(`   📈 Success Rate: ${((testsPassed / (testsPassed + testsFailed)) * 100).toFixed(1)}%`);
        console.log("=".repeat(60));
        
        if (testsFailed === 0) {
            console.log("\n✅ All integration tests passed! System is working correctly.");
            process.exit(0);
        } else {
            console.log(`\n⚠️  ${testsFailed} test(s) failed. Please review the errors above.`);
            process.exit(1);
        }
    } catch (error) {
        console.error(`\n❌ Test suite error: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    }
}

// Run all tests
runAllTests();



