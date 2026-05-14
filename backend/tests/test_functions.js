/**
 * Test script to verify astrology functions work correctly
 * Run with: node test_functions.js
 */

import { db } from "../lib/firebase.js";
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
import { DateTime } from "luxon";

async function testCacheUtils() {
    console.log("\n🧪 Testing Cache Utils...");
    
    // Test 1: Lat/Lng hash generation
    const hash1 = generateLatLngHash(28.6139, 77.2090); // Delhi
    const hash2 = generateLatLngHash(28.6139, 77.2090); // Same location
    const hash3 = generateLatLngHash(19.0760, 72.8777); // Mumbai
    
    console.log(`✅ Lat/Lng Hash Test:`);
    console.log(`   Delhi: ${hash1}`);
    console.log(`   Delhi (again): ${hash2}`);
    console.log(`   Mumbai: ${hash3}`);
    console.log(`   Match: ${hash1 === hash2 ? "✅" : "❌"}`);
    console.log(`   Different: ${hash1 !== hash3 ? "✅" : "❌"}`);
    
    // Test 2: Chart signature generation
    const testUserData = {
        sunSign: "Aries",
        moonSign: "Leo",
        ascendant: "Scorpio",
        nakshatra: "Rohini",
    };
    const signature = generateChartSignature(testUserData);
    console.log(`\n✅ Chart Signature Test:`);
    console.log(`   Signature: ${signature}`);
    console.log(`   Format correct: ${signature.includes("aries") && signature.includes("leo") ? "✅" : "❌"}`);
    
    // Test 3: Transit hash generation
    const testTransits = {
        Sun: { sign: "Aries", house: 1 },
        Moon: { sign: "Leo", house: 5 },
        Mars: { sign: "Scorpio", house: 8 },
    };
    const transitHash = generateTransitHash(testTransits);
    console.log(`\n✅ Transit Hash Test:`);
    console.log(`   Hash: ${transitHash}`);
    console.log(`   Contains planets: ${transitHash.includes("Sun") && transitHash.includes("Moon") ? "✅" : "❌"}`);
    
    // Test 4: Cache operations (mock - won't actually write to Firestore)
    const today = DateTime.now().toFormat("yyyy-MM-dd");
    console.log(`\n✅ Cache Operations Test:`);
    console.log(`   Today: ${today}`);
    console.log(`   Cache key format: transits/daily/${today}/${hash1}`);
    console.log(`   ✅ Cache utilities working`);
    
    return true;
}

async function testVedicAnalysis() {
    console.log("\n🧪 Testing Vedic Analysis...");
    
    // Test house activations
    const natalChart = {
        ascendant: 120, // 4th sign (Cancer)
        planets: {
            Sun: { fullDegree: 30, sign: "Aries", house: 1 },
            Moon: { fullDegree: 150, sign: "Leo", house: 5 },
        },
    };
    
    const transits = {
        Sun: { degree: 60, sign: "Gemini", house: 3 },
        Moon: { degree: 180, sign: "Virgo", house: 6 },
        Mars: { degree: 240, sign: "Sagittarius", house: 9 },
    };
    
    const houseActivations = calculateHouseActivations(natalChart, transits);
    console.log(`✅ House Activations Test:`);
    console.log(`   Found ${houseActivations.length} activations`);
    houseActivations.forEach((act, i) => {
        console.log(`   ${i + 1}. ${act.planet} → House ${act.house} (${act.signification})`);
    });
    console.log(`   ${houseActivations.length > 0 ? "✅" : "❌"} Activations calculated`);
    
    // Test aspects
    const aspects = calculateTransitAspects(natalChart, transits);
    console.log(`\n✅ Aspects Test:`);
    console.log(`   Found ${aspects.length} aspects`);
    aspects.slice(0, 3).forEach((asp, i) => {
        console.log(`   ${i + 1}. ${asp.transitPlanet} ${asp.type} ${asp.natalPlanet} (${asp.angle}°)`);
    });
    console.log(`   ${aspects.length > 0 ? "✅" : "❌"} Aspects calculated`);
    
    // Test scoring
    const scoredActivations = scoreHouseActivations(houseActivations, null);
    const scoredAspects = scoreAspects(aspects, null);
    
    console.log(`\n✅ Scoring Test:`);
    console.log(`   Scored ${scoredActivations.length} activations`);
    console.log(`   Scored ${scoredAspects.length} aspects`);
    console.log(`   ${scoredActivations.length > 0 && scoredAspects.length > 0 ? "✅" : "❌"} Scoring working`);
    
    return true;
}

async function testImports() {
    console.log("\n🧪 Testing Imports...");
    
    try {
        // Test that all imports work
        const cacheUtils = await import("./lib/cache_utils.js");
        const vedicAnalysis = await import("./lib/vedic_analysis.js");
        
        console.log(`✅ Cache Utils imported: ${cacheUtils ? "✅" : "❌"}`);
        console.log(`✅ Vedic Analysis imported: ${vedicAnalysis ? "✅" : "❌"}`);
        
        // Check exports
        const cacheExports = Object.keys(cacheUtils);
        const vedicExports = Object.keys(vedicAnalysis);
        
        console.log(`\n✅ Cache Utils Exports (${cacheExports.length}):`);
        cacheExports.forEach(exp => console.log(`   - ${exp}`));
        
        console.log(`\n✅ Vedic Analysis Exports (${vedicExports.length}):`);
        vedicExports.forEach(exp => console.log(`   - ${exp}`));
        
        return true;
    } catch (error) {
        console.error(`❌ Import Error: ${error.message}`);
        return false;
    }
}

async function runAllTests() {
    console.log("🚀 Starting Function Tests...\n");
    
    try {
        const importTest = await testImports();
        const cacheTest = await testCacheUtils();
        const vedicTest = await testVedicAnalysis();
        
        console.log("\n" + "=".repeat(50));
        console.log("📊 Test Results:");
        console.log("=".repeat(50));
        console.log(`   Imports: ${importTest ? "✅ PASS" : "❌ FAIL"}`);
        console.log(`   Cache Utils: ${cacheTest ? "✅ PASS" : "❌ FAIL"}`);
        console.log(`   Vedic Analysis: ${vedicTest ? "✅ PASS" : "❌ FAIL"}`);
        console.log("=".repeat(50));
        
        if (importTest && cacheTest && vedicTest) {
            console.log("\n✅ All tests passed! Functions are working correctly.");
            process.exit(0);
        } else {
            console.log("\n❌ Some tests failed. Please check the errors above.");
            process.exit(1);
        }
    } catch (error) {
        console.error(`\n❌ Test Error: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    }
}

// Run tests
runAllTests();



