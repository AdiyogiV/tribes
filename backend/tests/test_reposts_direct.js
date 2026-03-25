/**
 * =============================================================================
 * COMPREHENSIVE REPOST SYSTEM TEST SUITE (Direct Function Testing)
 * =============================================================================
 * 
 * Tests the core logic by extracting handlers from onCall wrappers
 * This allows us to test functions directly without HTTP layer
 * 
 * Prerequisites:
 * 1. Firebase emulator running: firebase emulators:start
 *    OR Firebase project configured
 * 2. Set TEST_USER_ID and TEST_USER_2_ID environment variables
 * 
 * Run: node tests/test_reposts_direct.js
 * 
 * =============================================================================
 */

import { db, FieldValue } from "../lib/firebase.js";

// Import the actual handler functions by extracting from onCall wrappers
// We'll need to import the file and extract the handlers
import * as repostsModule from "../functions/reposts.js";

const TEST_USER_ID = process.env.TEST_USER_ID || "test_user_" + Date.now();
const TEST_USER_2_ID = process.env.TEST_USER_2_ID || "test_user_2_" + Date.now();
const TEST_USER_3_ID = process.env.TEST_USER_3_ID || "test_user_3_" + Date.now();

const testResults = {
    passed: 0,
    failed: 0,
    tests: [],
    errors: [],
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
        testResults.errors.push({ name, details });
        if (details) console.log(`   ${details}`);
    }
}

// Extract handler from onCall wrapper
// onCall returns a function that wraps the handler
// We need to call it to get the actual handler
async function getHandler(functionWrapper) {
    // onCall functions are callable, but we need to extract the handler
    // For testing, we'll create a mock request and call the wrapper
    // The wrapper will call our handler with the request
    return async (request) => {
        // Create a mock callable context
        const mockContext = {
            eventId: "test-event-id",
            timestamp: new Date().toISOString(),
            eventType: "google.cloud.functions.framework.v1.CloudEvent",
            resource: "test-resource",
        };
        
        // Call the wrapper with mock context
        return await functionWrapper.run(request, mockContext);
    };
}

// Mock request creator
function createMockRequest(userId, data) {
    return {
        auth: { uid: userId },
        data: data,
        rawRequest: {
            headers: {},
            method: "POST",
        },
    };
}

// =============================================================================
// TEST SETUP & TEARDOWN
// =============================================================================

async function setupTestData() {
    console.log("\n🔧 Setting up test data...");
    
    try {
        await db.collection("users").doc(TEST_USER_ID).set({
            name: "Test User 1",
            username: "testuser1",
            isPrivateProfile: false,
        });
        
        await db.collection("users").doc(TEST_USER_2_ID).set({
            name: "Test User 2",
            username: "testuser2",
            isPrivateProfile: false,
        });
        
        await db.collection("users").doc(TEST_USER_3_ID).set({
            name: "Test User 3",
            username: "testuser3",
            isPrivateProfile: true,
        });
        
        logTest("Test data setup", true);
        return true;
    } catch (error) {
        logTest("Test data setup", false, `Error: ${error.message}`);
        return false;
    }
}

async function cleanupTestData() {
    console.log("\n🧹 Cleaning up test data...");
    
    try {
        // Clean up reposts
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
            .get();
        
        const batch = db.batch();
        repostsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
        if (repostsSnapshot.docs.length > 0) {
            await batch.commit();
        }
        
        // Clean up posts
        const postsSnapshot = await db.collection("posts")
            .where("author", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
            .get();
        
        const postBatch = db.batch();
        postsSnapshot.docs.forEach(doc => postBatch.delete(doc.ref));
        if (postsSnapshot.docs.length > 0) {
            await postBatch.commit();
        }
        
        // Clean up users
        await db.collection("users").doc(TEST_USER_ID).delete();
        await db.collection("users").doc(TEST_USER_2_ID).delete();
        await db.collection("users").doc(TEST_USER_3_ID).delete();
        
        logTest("Test data cleanup", true);
        return true;
    } catch (error) {
        logTest("Test data cleanup", false, `Error: ${error.message}`);
        return false;
    }
}

// =============================================================================
// TEST CASES
// =============================================================================

async function testCreateRepost_Basic() {
    console.log("\n🧪 Testing: createRepost - Basic functionality");
    
    try {
        // Create test post
        const testPostRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        // Call function via wrapper
        const mockRequest = createMockRequest(TEST_USER_ID, {
            originalPostId: testPostId,
            contextType: "profile",
            contextId: null,
        });
        
        const result = await repostsModule.createRepost(mockRequest);
        const repostId = result.repostId;
        
        logTest("Create repost - success", !!repostId);
        
        // Verify repost document
        const repostDoc = await db.collection("reposts").doc(repostId).get();
        logTest("Repost document created", repostDoc.exists);
        
        // Verify count
        const postDoc = await db.collection("posts").doc(testPostId).get();
        const postData = postDoc.data();
        logTest("Repost count incremented", postData?.repostCount === 1);
        
        // Cleanup
        await db.collection("reposts").doc(repostId).delete();
        await db.collection("posts").doc(testPostId).delete();
        
        return true;
    } catch (error) {
        logTest("Create repost - basic", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

// =============================================================================
// TEST RUNNER
// =============================================================================

async function runAllTests() {
    console.log("🚀 Starting Repost System Test Suite (Direct)...\n");
    console.log(`Test User 1: ${TEST_USER_ID}`);
    console.log(`Test User 2: ${TEST_USER_2_ID}`);
    console.log("=".repeat(60));
    
    try {
        await setupTestData();
        await testCreateRepost_Basic();
        await cleanupTestData();
        
        console.log("\n" + "=".repeat(60));
        console.log("📊 TEST SUMMARY");
        console.log("=".repeat(60));
        console.log(`   ✅ Passed: ${testResults.passed}`);
        console.log(`   ❌ Failed: ${testResults.failed}`);
        console.log("=".repeat(60));
        
        if (testResults.failed === 0) {
            console.log("\n✅ ALL TESTS PASSED!");
            process.exit(0);
        } else {
            console.log(`\n⚠️  ${testResults.failed} test(s) failed.`);
            process.exit(1);
        }
    } catch (error) {
        console.error(`\n❌ Test suite error: ${error.message}`);
        console.error(error.stack);
        await cleanupTestData();
        process.exit(1);
    }
}

runAllTests();
