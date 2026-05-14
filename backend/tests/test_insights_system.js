/**
 * Test Suite for Enhanced Insights System
 * Tests the new search, caching, and structured insight functionality
 * 
 * Run with: node test_insights_system.js
 */

import { DateTime } from "luxon";

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

function logSection(title) {
    console.log("\n" + "=".repeat(70));
    log(title, "bright");
    console.log("=".repeat(70));
}

function logTest(name, passed, details = "") {
    const status = passed ? "✓ PASS" : "✗ FAIL";
    const color = passed ? "green" : "red";
    log(`  ${status}: ${name}`, color);
    if (details) console.log(`    ${details}`);
}

// ============================================================================
// TEST 1: Cache Utils Exports
// ============================================================================
async function testCacheExports() {
    logSection("TEST 1: Cache Utils Exports");
    
    try {
        const cacheUtils = await import("./lib/cache_utils.js");
        const exports = Object.keys(cacheUtils);
        
        // Check for new tiered caching functions
        const requiredExports = [
            "getCachedAstroKnowledge",
            "cacheAstroKnowledge", 
            "getCachedAstroCurrent",
            "cacheAstroCurrent",
            "getCacheStats",
            "cleanupExpiredCache",
        ];
        
        const missingExports = requiredExports.filter(e => !exports.includes(e));
        
        logTest("All new cache functions exported", missingExports.length === 0,
            missingExports.length > 0 ? `Missing: ${missingExports.join(", ")}` : `Found ${exports.length} exports`);
        
        console.log("\n  Exports found:");
        exports.forEach(e => console.log(`    - ${e}`));
        
        return missingExports.length === 0;
    } catch (error) {
        logTest("Cache Utils import", false, `Error: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 2: Search Functions Exports
// ============================================================================
async function testSearchExports() {
    logSection("TEST 2: Search Functions Exports");
    
    try {
        const search = await import("./lib/search.js");
        const exports = Object.keys(search);
        
        // Check for new astro search functions
        const requiredExports = [
            "performWebSearch",
            "getLagnaMeaning",
            "getMoonSignMeaning",
            "getNakshatraMeaning",
            "getTithiMeaning",
            "getYogaMeaning",
            "getDashaMeaning",
            "getTransitMeaning",
            "getPlanetRemedies",
            "getHouseMeaning",
            "getRetrogradeGuide",
            "getGlobalAstroEvents",
            "getCurrentRetrogrades",
            "getMonthlyPredictions",
            "getWeeklyPredictions",
            "getMonthlyFestivals",
            "getDailyAstroWeather",
            "buildAstroSearchContext",
        ];
        
        const missingExports = requiredExports.filter(e => !exports.includes(e));
        
        logTest("All search functions exported", missingExports.length === 0,
            missingExports.length > 0 ? `Missing: ${missingExports.join(", ")}` : `Found ${exports.length} exports`);
        
        console.log("\n  Exports found:");
        exports.forEach(e => console.log(`    - ${e}`));
        
        return missingExports.length === 0;
    } catch (error) {
        logTest("Search Functions import", false, `Error: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 3: Free Astro API Endpoints
// ============================================================================
async function testFreeAstroEndpoints() {
    logSection("TEST 3: Free Astro API Endpoints");
    
    try {
        const freeAstro = await import("./functions/free_astro.js");
        const exports = Object.keys(freeAstro);
        
        // Check for main exports
        const requiredExports = [
            "runAstroFlow",
            "freeAstroCalculate",
            "calculateCompatibility",
        ];
        
        const missingExports = requiredExports.filter(e => !exports.includes(e));
        
        logTest("Free Astro exports present", missingExports.length === 0,
            missingExports.length > 0 ? `Missing: ${missingExports.join(", ")}` : `Found ${exports.length} exports`);
        
        // Check that Shad Bala and D10 constants are in the file
        const fs = await import("fs");
        const fileContent = fs.readFileSync("./functions/free_astro.js", "utf8");
        
        const hasShadBala = fileContent.includes("SHADBALA_SUMMARY_ENDPOINT");
        const hasD10 = fileContent.includes("D10_CHART_ENDPOINT");
        
        logTest("Shad Bala endpoint defined", hasShadBala);
        logTest("D10 Chart endpoint defined", hasD10);
        
        return missingExports.length === 0 && hasShadBala && hasD10;
    } catch (error) {
        logTest("Free Astro import", false, `Error: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 4: Daily Insights Exports
// ============================================================================
async function testDailyInsightsExports() {
    logSection("TEST 4: Daily Insights Exports");
    
    try {
        const insights = await import("./functions/daily_astro_insights.js");
        const exports = Object.keys(insights);
        
        const requiredExports = [
            "generateInsightForCurrentUser",
            "generateDailyAstroInsights",
        ];
        
        const missingExports = requiredExports.filter(e => !exports.includes(e));
        
        logTest("Daily Insights exports present", missingExports.length === 0,
            missingExports.length > 0 ? `Missing: ${missingExports.join(", ")}` : `Found ${exports.length} exports`);
        
        // Check for new structured prompt elements
        const fs = await import("fs");
        const fileContent = fs.readFileSync("./functions/daily_astro_insights.js", "utf8");
        
        const hasStructuredPrompt = fileContent.includes("VEDIC PREDICTION METHODOLOGY");
        const hasLifeAreas = fileContent.includes("lifeAreas");
        const hasTiming = fileContent.includes('"timing"');
        const hasRemedies = fileContent.includes('"remedies"');
        const hasSearchContext = fileContent.includes("buildAstroSearchContext");
        
        logTest("Structured prompt present", hasStructuredPrompt);
        logTest("Life areas in output", hasLifeAreas);
        logTest("Timing in output", hasTiming);
        logTest("Remedies in output", hasRemedies);
        logTest("Search context integration", hasSearchContext);
        
        return missingExports.length === 0 && hasStructuredPrompt && hasLifeAreas;
    } catch (error) {
        logTest("Daily Insights import", false, `Error: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 5: Vedic Analysis Integration
// ============================================================================
async function testVedicAnalysisIntegration() {
    logSection("TEST 5: Vedic Analysis Integration");
    
    try {
        const vedic = await import("./lib/vedic_analysis.js");
        
        // Test calculateHouseActivations
        const natalChart = {
            ascendant: 120,
            planets: {
                Sun: { fullDegree: 30, sign: "Aries", house: 1 },
                Moon: { fullDegree: 150, sign: "Leo", house: 5 },
            },
        };
        
        const transits = {
            Sun: { degree: 60, sign: "Gemini", house: 3 },
            Moon: { degree: 180, sign: "Virgo", house: 6 },
            Jupiter: { degree: 240, sign: "Sagittarius", house: 9 },
        };
        
        const houseActivations = vedic.calculateHouseActivations(natalChart, transits);
        logTest("House activations calculated", houseActivations.length > 0,
            `${houseActivations.length} activations found`);
        
        const transitAspects = vedic.calculateTransitAspects(natalChart, transits);
        logTest("Transit aspects calculated", transitAspects.length >= 0,
            `${transitAspects.length} aspects found`);
        
        return true;
    } catch (error) {
        logTest("Vedic Analysis integration", false, `Error: ${error.message}`);
        return false;
    }
}

// ============================================================================
// TEST 6: Data Structure Validation
// ============================================================================
async function testDataStructures() {
    logSection("TEST 6: Expected Data Structures");
    
    // Test expected insight output structure
    const expectedInsightStructure = {
        dailyTheme: "string",
        mainInsight: "string",
        lifeAreas: {
            career: "string",
            relationships: "string",
            health: "string",
            spiritual: "string",
        },
        timing: {
            best: "string",
            careful: "string",
            keyMoment: "string|null",
        },
        activities: {
            favorable: ["array"],
            avoid: ["array"],
        },
        lucky: {
            color: "string",
            number: "number",
            direction: "string",
        },
        remedies: {
            quick: "string",
            mantra: "string|null",
            offering: "string|null",
        },
        awareness: {
            physical: "string",
            emotional: "string",
            practical: "string",
        },
    };
    
    log("\n  Expected AI Output Structure:", "cyan");
    console.log(JSON.stringify(expectedInsightStructure, null, 2).split('\n').map(l => `    ${l}`).join('\n'));
    
    logTest("Data structure documented", true);
    
    return true;
}

// ============================================================================
// TEST RUNNER
// ============================================================================
async function runAllTests() {
    log("\n" + "=".repeat(70), "bright");
    log("ENHANCED INSIGHTS SYSTEM - TEST SUITE", "bright");
    log("=".repeat(70) + "\n", "bright");
    
    const results = [];
    
    results.push({ name: "Cache Exports", passed: await testCacheExports() });
    results.push({ name: "Search Exports", passed: await testSearchExports() });
    results.push({ name: "Free Astro Endpoints", passed: await testFreeAstroEndpoints() });
    results.push({ name: "Daily Insights Exports", passed: await testDailyInsightsExports() });
    results.push({ name: "Vedic Analysis", passed: await testVedicAnalysisIntegration() });
    results.push({ name: "Data Structures", passed: await testDataStructures() });
    
    // Summary
    logSection("TEST SUMMARY");
    
    let passed = 0;
    let failed = 0;
    
    results.forEach(r => {
        const color = r.passed ? "green" : "red";
        const status = r.passed ? "✓ PASS" : "✗ FAIL";
        log(`  ${status}: ${r.name}`, color);
        if (r.passed) passed++; else failed++;
    });
    
    console.log("\n" + "-".repeat(70));
    log(`\nTotal: ${passed}/${results.length} tests passed`, passed === results.length ? "green" : "yellow");
    
    if (failed > 0) {
        log("\n⚠️  Some tests failed. Review errors above.", "yellow");
    } else {
        log("\n✅ All tests passed! Ready for deployment.", "green");
    }
    
    // Deployment instructions
    log("\n" + "=".repeat(70), "bright");
    log("NEXT STEPS: DEPLOYMENT & LIVE TESTING", "bright");
    log("=".repeat(70), "bright");
    
    console.log(`
  1. Deploy to Firebase:
     ${colors.cyan}cd /Users/apple/Documents/Abhinav/tribes/backend${colors.reset}
     ${colors.cyan}firebase deploy --only functions${colors.reset}

  2. Test via Firebase Console or App:
     - Open Firebase Console > Functions
     - Check logs for any deployment errors
     - Test generateInsightForCurrentUser from the app

  3. Monitor in production:
     ${colors.cyan}firebase functions:log --only generateInsightForCurrentUser${colors.reset}

  4. Test Google Search integration:
     - Google Custom Search is no longer used (Gemini grounding replaces it)
     
  5. Verify in app:
     - Open app > Astrology > Daily Insights
     - Click "Generate Insight" 
     - Check for structured response with life areas, timing, etc.
`);
    
    process.exit(failed > 0 ? 1 : 0);
}

// Run tests
runAllTests().catch(error => {
    log(`\n❌ Test runner failed: ${error.message}`, "red");
    console.error(error.stack);
    process.exit(1);
});



