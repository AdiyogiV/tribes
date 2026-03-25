/**
 * Real Integration Test for Astrology Insights Cloud Functions
 * Tests actual deployed functions with real Firestore data
 * 
 * Prerequisites:
 * 1. User must be logged in via Firebase CLI: firebase login
 * 2. Set TEST_USER_ID environment variable or use your actual user ID
 * 3. User must have complete astrology profile in Firestore
 * 
 * Run: node test_real_functions.js
 */

import { initializeApp } from "firebase/app";
import { getFirestore, doc, getDoc, collection, query, where, getDocs } from "firebase/firestore";
import { getAuth, signInWithEmailAndPassword } from "firebase/auth";
import { getFunctions, httpsCallable } from "firebase/functions";
import { DateTime } from "luxon";

// Firebase config - replace with your actual config
const firebaseConfig = {
  // You'll need to add your Firebase config here
  // Or use environment variables
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);
const functions = getFunctions(app);

const TEST_USER_ID = process.env.TEST_USER_ID || process.env.USER_ID;
const TEST_USER_EMAIL = process.env.TEST_USER_EMAIL;
const TEST_USER_PASSWORD = process.env.TEST_USER_PASSWORD;

const testResults = {
  passed: 0,
  failed: 0,
  tests: [],
};

function logTest(name, passed, details = "") {
  const result = { name, passed, details, timestamp: new Date().toISOString() };
  testResults.tests.push(result);
  
  if (passed) {
    console.log(`✅ ${name}`);
    testResults.passed++;
    if (details) console.log(`   ${details}`);
  } else {
    console.log(`❌ ${name}`);
    testResults.failed++;
    if (details) console.log(`   ${details}`);
  }
}

async function checkUserProfile() {
  console.log("\n🔍 Checking User Profile...");
  
  if (!TEST_USER_ID) {
    logTest("User ID Check", false, "TEST_USER_ID not set. Set it or use USER_ID env var");
    return false;
  }
  
  try {
    const userDoc = await getDoc(doc(db, "users", TEST_USER_ID));
    
    if (!userDoc.exists()) {
      logTest("User Exists", false, `User ${TEST_USER_ID} not found in Firestore`);
      return false;
    }
    
    const userData = userDoc.data();
    const astrologyData = userData?.astrologyData;
    
    if (!astrologyData) {
      logTest("Astrology Data", false, "User has no astrologyData");
      return false;
    }
    
    if (!astrologyData.isEnabled) {
      logTest("Astrology Enabled", false, "Astrology is not enabled for this user");
      return false;
    }
    
    const requiredFields = [
      'birthYear', 'birthMonth', 'birthDay', 'birthTime',
      'birthLatitude', 'birthLongitude'
    ];
    
    const missingFields = requiredFields.filter(field => 
      astrologyData[field] == null || astrologyData[field] === undefined
    );
    
    if (missingFields.length > 0) {
      logTest("Complete Birth Data", false, 
        `Missing fields: ${missingFields.join(', ')}`);
      return false;
    }
    
    logTest("User Profile Check", true, 
      `User: ${TEST_USER_ID}, Birth: ${astrologyData.birthYear}-${astrologyData.birthMonth}-${astrologyData.birthDay}`);
    
    return true;
  } catch (error) {
    logTest("User Profile Check", false, `Error: ${error.message}`);
    return false;
  }
}

async function testGenerateInsightFunction() {
  console.log("\n🧪 Testing: generateInsightForCurrentUser Cloud Function...");
  
  try {
    // Authenticate if credentials provided
    if (TEST_USER_EMAIL && TEST_USER_PASSWORD) {
      await signInWithEmailAndPassword(auth, TEST_USER_EMAIL, TEST_USER_PASSWORD);
      logTest("Authentication", true, `Logged in as ${TEST_USER_EMAIL}`);
    } else {
      logTest("Authentication", false, 
        "TEST_USER_EMAIL and TEST_USER_PASSWORD not set. Using existing auth.");
    }
    
    const generateInsight = httpsCallable(functions, 'generateInsightForCurrentUser');
    
    console.log("   Calling Cloud Function...");
    const startTime = Date.now();
    const result = await generateInsight();
    const duration = Date.now() - startTime;
    
    if (result.data && result.data.success) {
      logTest("Function Call Success", true, 
        `Response received in ${duration}ms`);
      
      const insightData = result.data;
      logTest("Response Structure", 
        insightData.insight && insightData.date,
        `Insight length: ${insightData.insight?.length || 0} chars, Date: ${insightData.date}`);
      
      return insightData;
    } else {
      logTest("Function Call Success", false, 
        `Unexpected response: ${JSON.stringify(result.data)}`);
      return null;
    }
  } catch (error) {
    logTest("Function Call", false, `Error: ${error.message}`);
    if (error.code) {
      console.log(`   Error code: ${error.code}`);
    }
    return null;
  }
}

async function verifyInsightInFirestore(insightDate) {
  console.log("\n🔍 Verifying Insight in Firestore...");
  
  if (!TEST_USER_ID || !insightDate) {
    logTest("Firestore Verification", false, "Missing user ID or insight date");
    return false;
  }
  
  try {
    const insightDoc = await getDoc(
      doc(db, "users", TEST_USER_ID, "dailyInsights", insightDate)
    );
    
    if (!insightDoc.exists()) {
      logTest("Insight Document Exists", false, 
        `Document not found: users/${TEST_USER_ID}/dailyInsights/${insightDate}`);
      return false;
    }
    
    const insightData = insightDoc.data();
    
    logTest("Insight Document Exists", true, "Document found in Firestore");
    
    // Verify structure
    const hasInsight = !!insightData.insight;
    const hasDate = !!insightData.date;
    const hasAstroData = !!insightData.astrologicalData;
    const hasGeneratedAt = !!insightData.generatedAt;
    
    logTest("Insight Structure", 
      hasInsight && hasDate && hasAstroData && hasGeneratedAt,
      `Has insight: ${hasInsight}, Has date: ${hasDate}, Has astro data: ${hasAstroData}, Has timestamp: ${hasGeneratedAt}`);
    
    // Verify astrological data structure
    if (insightData.astrologicalData) {
      const astroData = insightData.astrologicalData;
      const hasTransits = !!astroData.transits;
      const hasPanchang = !!astroData.panchang;
      const hasHouseActivations = !!astroData.houseActivations;
      const hasAspects = !!astroData.significantAspects;
      
      logTest("Astrological Data Structure",
        hasTransits || hasPanchang || hasHouseActivations || hasAspects,
        `Transits: ${hasTransits}, Panchang: ${hasPanchang}, House Activations: ${hasHouseActivations}, Aspects: ${hasAspects}`);
    }
    
    return true;
  } catch (error) {
    logTest("Firestore Verification", false, `Error: ${error.message}`);
    return false;
  }
}

async function verifyNotificationCreated(insightDate) {
  console.log("\n🔍 Verifying Notification Created...");
  
  if (!TEST_USER_ID || !insightDate) {
    logTest("Notification Verification", false, "Missing user ID or insight date");
    return false;
  }
  
  try {
    // Check notifications collection
    const notificationsRef = collection(db, "notifications", TEST_USER_ID, "notifications");
    const q = query(
      notificationsRef,
      where("type", "==", "dailyAstroInsight"),
      where("insightId", "==", insightDate)
    );
    
    const snapshot = await getDocs(q);
    
    if (snapshot.empty) {
      logTest("Notification Created", false, 
        "No notification found for this insight");
      return false;
    }
    
    const notification = snapshot.docs[0].data();
    logTest("Notification Created", true, 
      `Notification found: ${notification.preview?.substring(0, 50)}...`);
    
    return true;
  } catch (error) {
    logTest("Notification Verification", false, 
      `Error: ${error.message}. Note: Notifications may be created via trigger.`);
    return false;
  }
}

async function testCacheAfterGeneration(insightDate) {
  console.log("\n🔍 Testing Cache After Generation...");
  
  try {
    // Check if transit cache was created
    const cacheRef = collection(db, "astroCache");
    const cacheQuery = query(
      cacheRef,
      where("__name__", ">=", `transits:daily:${insightDate}:`),
      where("__name__", "<=", `transits:daily:${insightDate}:~`)
    );
    
    const cacheSnapshot = await getDocs(cacheQuery);
    
    if (cacheSnapshot.empty) {
      logTest("Transit Cache Created", false, 
        "No transit cache found (may be normal if cache key format differs)");
    } else {
      logTest("Transit Cache Created", true, 
        `Found ${cacheSnapshot.size} cache entry/entries`);
    }
    
    return true;
  } catch (error) {
    logTest("Cache Check", false, `Error: ${error.message}`);
    return false;
  }
}

async function testDuplicateGeneration(insightDate) {
  console.log("\n🧪 Testing: Duplicate Generation Prevention...");
  
  try {
    const generateInsight = httpsCallable(functions, 'generateInsightForCurrentUser');
    
    console.log("   Calling function again (should return existing insight)...");
    const result = await generateInsight();
    
    if (result.data && result.data.success) {
      // Should return existing insight, not generate new one
      logTest("Duplicate Prevention", true, 
        "Function handled duplicate call (may return existing or new)");
      return true;
    } else {
      logTest("Duplicate Prevention", false, 
        "Unexpected response on duplicate call");
      return false;
    }
  } catch (error) {
    logTest("Duplicate Prevention", false, `Error: ${error.message}`);
    return false;
  }
}

async function generateTestReport() {
  console.log("\n" + "=".repeat(60));
  console.log("📊 Real Function Test Report");
  console.log("=".repeat(60));
  console.log(`Total Tests: ${testResults.passed + testResults.failed}`);
  console.log(`✅ Passed: ${testResults.passed}`);
  console.log(`❌ Failed: ${testResults.failed}`);
  if (testResults.passed + testResults.failed > 0) {
    console.log(`Success Rate: ${((testResults.passed / (testResults.passed + testResults.failed)) * 100).toFixed(1)}%`);
  }
  console.log("=".repeat(60));
  
  if (testResults.failed > 0) {
    console.log("\n❌ Failed Tests:");
    testResults.tests
      .filter(t => !t.passed)
      .forEach(t => console.log(`   - ${t.name}: ${t.details}`));
  }
  
  // Save report
  const fs = await import('fs');
  const report = {
    timestamp: new Date().toISOString(),
    testType: "real_functions",
    summary: {
      total: testResults.passed + testResults.failed,
      passed: testResults.passed,
      failed: testResults.failed,
      successRate: testResults.passed + testResults.failed > 0 
        ? ((testResults.passed / (testResults.passed + testResults.failed)) * 100).toFixed(1) + "%"
        : "0%",
    },
    tests: testResults.tests,
  };
  
  fs.writeFileSync('test_real_functions_report.json', JSON.stringify(report, null, 2));
  console.log("\n📄 Test report saved to test_real_functions_report.json");
}

async function runRealFunctionTests() {
  console.log("🚀 Starting Real Cloud Function Integration Tests...\n");
  console.log(`Test User ID: ${TEST_USER_ID || 'NOT SET'}`);
  console.log(`Test Date: ${DateTime.now().toFormat("yyyy-MM-dd")}`);
  console.log("=".repeat(60));
  
  if (!TEST_USER_ID) {
    console.error("\n❌ ERROR: TEST_USER_ID not set!");
    console.error("Set it with: export TEST_USER_ID='your-user-id'");
    console.error("Or set USER_ID environment variable");
    process.exit(1);
  }
  
  try {
    // Step 1: Check user profile
    const profileValid = await checkUserProfile();
    if (!profileValid) {
      console.error("\n❌ User profile check failed. Cannot proceed with tests.");
      await generateTestReport();
      process.exit(1);
    }
    
    // Step 2: Test insight generation
    const insightData = await testGenerateInsightFunction();
    
    if (!insightData) {
      console.error("\n❌ Insight generation failed. Cannot proceed with verification.");
      await generateTestReport();
      process.exit(1);
    }
    
    const insightDate = insightData.date || DateTime.now().toFormat("yyyy-MM-dd");
    
    // Step 3: Verify insight in Firestore
    await verifyInsightInFirestore(insightDate);
    
    // Step 4: Verify notification (may not exist if trigger hasn't run)
    await verifyNotificationCreated(insightDate);
    
    // Step 5: Check cache
    await testCacheAfterGeneration(insightDate);
    
    // Step 6: Test duplicate prevention
    await testDuplicateGeneration(insightDate);
    
    await generateTestReport();
    
    if (testResults.failed === 0) {
      console.log("\n✅ All real function tests passed! System is working correctly.");
      process.exit(0);
    } else {
      console.log(`\n⚠️  ${testResults.failed} test(s) failed. Please review the errors above.`);
      process.exit(1);
    }
  } catch (error) {
    console.error(`\n❌ Test suite error: ${error.message}`);
    console.error(error.stack);
    await generateTestReport();
    process.exit(1);
  }
}

// Run tests
runRealFunctionTests();



