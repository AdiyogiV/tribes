/**
 * =============================================================================
 * COMPREHENSIVE REPOST SYSTEM TEST SUITE (Admin SDK)
 * =============================================================================
 * 
 * Tests EVERYTHING deeply using Firebase Admin SDK (same as Cloud Functions)
 * This allows us to test functions directly without needing client SDK
 * 
 * Prerequisites:
 * 1. Firebase emulator running: firebase emulators:start
 *    OR Firebase project configured with service account
 * 2. Set TEST_USER_ID and TEST_USER_2_ID environment variables
 * 
 * Run: node tests/test_reposts_admin.js
 * 
 * =============================================================================
 */

import { db, FieldValue } from "../lib/firebase.js";
import { createRepost, deleteRepost } from "../functions/reposts.js";

// Use existing Firebase Admin instance from lib/firebase.js
// db and FieldValue are already exported and initialized

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

// =============================================================================
// TEST SETUP & TEARDOWN
// =============================================================================

async function setupTestData() {
    console.log("\n🔧 Setting up test data...");
    
    try {
        // Create test users
        await db.collection("users").doc(TEST_USER_ID).set({
            name: "Test User 1",
            username: "testuser1",
            isPrivateProfile: false,
            displayPicture: "https://example.com/user1.jpg",
        });
        
        await db.collection("users").doc(TEST_USER_2_ID).set({
            name: "Test User 2",
            username: "testuser2",
            isPrivateProfile: false,
            displayPicture: "https://example.com/user2.jpg",
        });
        
        await db.collection("users").doc(TEST_USER_3_ID).set({
            name: "Test User 3",
            username: "testuser3",
            isPrivateProfile: true, // Private profile
            displayPicture: "https://example.com/user3.jpg",
        });
        
        logTest("Test data setup", true, `Created users: ${TEST_USER_ID}, ${TEST_USER_2_ID}, ${TEST_USER_3_ID}`);
        return true;
    } catch (error) {
        logTest("Test data setup", false, `Error: ${error.message}`);
        return false;
    }
}

async function cleanupTestData() {
    console.log("\n🧹 Cleaning up test data...");
    
    try {
        // Delete test reposts
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
            .get();
        
        const batch = db.batch();
        repostsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
        if (repostsSnapshot.docs.length > 0) {
            await batch.commit();
        }
        
        // Delete test posts
        const postsSnapshot = await db.collection("posts")
            .where("author", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
            .get();
        
        const postBatch = db.batch();
        postsSnapshot.docs.forEach(doc => postBatch.delete(doc.ref));
        if (postsSnapshot.docs.length > 0) {
            await postBatch.commit();
        }
        
        // Delete test spaces
        const spacesSnapshot = await db.collection("spaces")
            .where("members", "array-contains", TEST_USER_ID)
            .get();
        
        const spaceBatch = db.batch();
        spacesSnapshot.docs.forEach(doc => {
            // Delete space posts
            const spaceId = doc.id;
            db.collection("spaces").doc(spaceId).collection("posts").get().then(snapshot => {
                snapshot.docs.forEach(postDoc => postDoc.ref.delete());
            });
            spaceBatch.delete(doc.ref);
        });
        if (spacesSnapshot.docs.length > 0) {
            await spaceBatch.commit();
        }
        
        // Delete test users
        await db.collection("users").doc(TEST_USER_ID).delete();
        await db.collection("users").doc(TEST_USER_2_ID).delete();
        await db.collection("users").doc(TEST_USER_3_ID).delete();
        
        // Clean up follows
        const followsRef = db.collection("follows").doc(TEST_USER_ID);
        const followingRef = followsRef.collection("following");
        const followingSnapshot = await followingRef.get();
        const followBatch = db.batch();
        followingSnapshot.docs.forEach(doc => followBatch.delete(doc.ref));
        if (followingSnapshot.docs.length > 0) {
            await followBatch.commit();
        }
        
        logTest("Test data cleanup", true);
        return true;
    } catch (error) {
        logTest("Test data cleanup", false, `Error: ${error.message}`);
        return false;
    }
}

// =============================================================================
// TEST CASES - CREATE REPOST
// =============================================================================

async function testCreateRepost_Basic() {
    console.log("\n🧪 Testing: createRepost - Basic functionality");
    
    try {
        // Create a test post
        const testPostRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            authorName: "Test User 2",
            contextType: "profile",
            title: "Test Post for Repost",
            content: "This is a test post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        // Mock request object (onCall format)
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: {
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            },
        };
        
        // Test: Create repost
        const result = await createRepost(mockRequest);
        const repostId = result.repostId;
        logTest("Create repost - success", !!repostId, `Repost ID: ${repostId}`);
        
        // Verify repost document
        const repostDoc = await db.collection("reposts").doc(repostId).get();
        const repostExists = repostDoc.exists;
        const repostData = repostDoc.data();
        
        logTest("Repost document created", repostExists);
        logTest("Repost has originalPostId", repostData?.originalPostId === testPostId);
        logTest("Repost has reposterId", repostData?.reposterId === TEST_USER_ID);
        logTest("Repost has originalPostContextType", repostData?.originalPostContextType === "profile");
        logTest("Repost has originalSpaceId field", repostData?.originalSpaceId === null);
        logTest("Repost has contextType", repostData?.contextType === "profile");
        logTest("Repost has contextId", repostData?.contextId === null);
        logTest("Repost has previewThumbnail", repostData?.previewThumbnail !== undefined);
        logTest("Repost has previewTitle", repostData?.previewTitle !== undefined);
        logTest("Repost has timestamp", !!repostData?.timestamp);
        
        // Verify repost count incremented
        const postDoc = await db.collection("posts").doc(testPostId).get();
        const postData = postDoc.data();
        const countIncremented = postData?.repostCount === 1;
        
        logTest("Repost count incremented", countIncremented,
            `Expected: 1, Got: ${postData?.repostCount}`);
        
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

async function testCreateRepost_DuplicatePrevention() {
    console.log("\n🧪 Testing: createRepost - Duplicate prevention");
    
    try {
        // Create a test post
        const testPostRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: {
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            },
        };
        
        // Create first repost
        const result1 = await createRepost(mockRequest);
        const repostId1 = result1.repostId;
        logTest("First repost created", !!repostId1);
        
        // Try to create duplicate (should fail)
        try {
            await createRepost(mockRequest);
            logTest("Duplicate repost prevented", false, "Should have thrown error");
        } catch (error) {
            const isDuplicateError = error.code === "already-exists" ||
                error.message?.includes("already reposted");
            logTest("Duplicate repost prevented", isDuplicateError,
                `Error: ${error.message}`);
        }
        
        // Verify only one repost exists
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "==", TEST_USER_ID)
            .where("originalPostId", "==", testPostId)
            .get();
        logTest("Only one repost exists", repostsSnapshot.size === 1,
            `Found ${repostsSnapshot.size} reposts`);
        
        // Verify count is correct
        const postDoc = await db.collection("posts").doc(testPostId).get();
        const postData = postDoc.data();
        logTest("Repost count correct", postData?.repostCount === 1,
            `Expected: 1, Got: ${postData?.repostCount}`);
        
        // Cleanup
        await db.collection("reposts").doc(repostId1).delete();
        await db.collection("posts").doc(testPostId).delete();
        
        return true;
    } catch (error) {
        logTest("Duplicate prevention", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

async function testCreateRepost_SpacePost() {
    console.log("\n🧪 Testing: createRepost - Space post repost");
    
    try {
        // Create a test space
        const testSpaceRef = await db.collection("spaces").add({
            spaceType: 0, // Public space
            members: [TEST_USER_ID, TEST_USER_2_ID],
            name: "Test Space",
        });
        
        const testSpaceId = testSpaceRef.id;
        
        // Create a space post
        const spacePostRef = await db
            .collection("spaces")
            .doc(testSpaceId)
            .collection("posts")
            .add({
                author: TEST_USER_2_ID,
                contextType: "space",
                space: testSpaceId,
                title: "Space Post",
                repostCount: 0,
                timestamp: FieldValue.serverTimestamp(),
            });
        
        const spacePostId = spacePostRef.id;
        
        // Also create in top-level posts for lookup
        await db.collection("posts").doc(spacePostId).set({
            author: TEST_USER_2_ID,
            contextType: "space",
            space: testSpaceId,
            title: "Space Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: {
                originalPostId: spacePostId,
                contextType: "profile",
                contextId: null,
            },
        };
        
        // Test: Create repost of space post
        const result = await createRepost(mockRequest);
        const repostId = result.repostId;
        logTest("Space post repost created", !!repostId);
        
        // Verify repost stores original context
        const repostDoc = await db.collection("reposts").doc(repostId).get();
        const repostData = repostDoc.data();
        
        logTest("Repost stores originalPostContextType", 
            repostData?.originalPostContextType === "space");
        logTest("Repost stores originalSpaceId", 
            repostData?.originalSpaceId === testSpaceId);
        
        // Verify count incremented on space post
        const spacePostDoc = await db
            .collection("spaces")
            .doc(testSpaceId)
            .collection("posts")
            .doc(spacePostId)
            .get();
        
        const spacePostData = spacePostDoc.data();
        logTest("Space post count incremented", 
            spacePostData?.repostCount === 1);
        
        // Cleanup
        await db.collection("reposts").doc(repostId).delete();
        await db.collection("spaces").doc(testSpaceId)
            .collection("posts").doc(spacePostId).delete();
        await db.collection("posts").doc(spacePostId).delete();
        await db.collection("spaces").doc(testSpaceId).delete();
        
        return true;
    } catch (error) {
        logTest("Space post repost", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

async function testCreateRepost_PrivateProfile() {
    console.log("\n🧪 Testing: createRepost - Private profile permissions");
    
    try {
        // Create a post by private user
        const testPostRef = await db.collection("posts").add({
            author: TEST_USER_3_ID,
            contextType: "profile",
            title: "Private Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: {
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            },
        };
        
        // Test: Non-follower cannot repost
        try {
            await createRepost(mockRequest);
            logTest("Private post repost blocked (non-follower)", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error.code === "permission-denied" ||
                error.message?.includes("private");
            logTest("Private post repost blocked (non-follower)", isPermissionError,
                `Error: ${error.message}`);
        }
        
        // Test: Follower can repost
        await db.collection("follows")
            .doc(TEST_USER_ID)
            .collection("following")
            .doc(TEST_USER_3_ID)
            .set({ timestamp: FieldValue.serverTimestamp() });
        
        try {
            const result = await createRepost(mockRequest);
            logTest("Follower can repost private post", !!result.repostId);
            
            // Cleanup
            await db.collection("reposts").doc(result.repostId).delete();
        } catch (error) {
            logTest("Follower can repost private post", false, 
                `Error: ${error.message}`);
        }
        
        // Cleanup
        await db.collection("posts").doc(testPostId).delete();
        await db.collection("follows")
            .doc(TEST_USER_ID)
            .collection("following")
            .doc(TEST_USER_3_ID)
            .delete();
        
        return true;
    } catch (error) {
        logTest("Private profile permissions", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

async function testCreateRepost_MissingPost() {
    console.log("\n🧪 Testing: createRepost - Missing post handling");
    
    try {
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: {
                originalPostId: "non-existent-post-id",
                contextType: "profile",
                contextId: null,
            },
        };
        
        // Test: Try to repost non-existent post
        try {
            await createRepost(mockRequest);
            logTest("Missing post repost blocked", false, "Should have thrown error");
        } catch (error) {
            const isNotFoundError = error.code === "not-found" ||
                error.message?.includes("not found");
            logTest("Missing post repost blocked", isNotFoundError,
                `Error: ${error.message}`);
        }
        
        return true;
    } catch (error) {
        logTest("Missing post handling", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

async function testCreateRepost_InvalidData() {
    console.log("\n🧪 Testing: createRepost - Invalid data handling");
    
    try {
        // Test: Empty originalPostId
        try {
            const mockRequest = {
                auth: { uid: TEST_USER_ID },
                data: {
                    originalPostId: "",
                    contextType: "profile",
                    contextId: null,
                },
            };
            await createRepost(mockRequest);
            logTest("Empty originalPostId rejected", false, "Should have thrown error");
        } catch (error) {
            const isValidError = error.code === "invalid-argument";
            logTest("Empty originalPostId rejected", isValidError,
                `Error: ${error.message}`);
        }
        
        // Test: Missing contextId for space repost
        try {
            const mockRequest = {
                auth: { uid: TEST_USER_ID },
                data: {
                    originalPostId: "some-post-id",
                    contextType: "space",
                    contextId: null,
                },
            };
            await createRepost(mockRequest);
            logTest("Missing contextId for space repost rejected", false, "Should have thrown error");
        } catch (error) {
            const isValidError = error.code === "invalid-argument";
            logTest("Missing contextId for space repost rejected", isValidError,
                `Error: ${error.message}`);
        }
        
        return true;
    } catch (error) {
        logTest("Invalid data handling", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

// =============================================================================
// TEST CASES - DELETE REPOST
// =============================================================================

async function testDeleteRepost_Basic() {
    console.log("\n🧪 Testing: deleteRepost - Basic functionality");
    
    try {
        // Create a test post
        const testPostRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 1,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        // Create a repost manually (for testing delete)
        const repostRef = await db.collection("reposts").add({
            reposterId: TEST_USER_ID,
            originalPostId: testPostId,
            originalAuthorId: TEST_USER_2_ID,
            originalPostContextType: "profile",
            originalSpaceId: null,
            contextType: "profile",
            contextId: null,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const repostId = repostRef.id;
        
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: { repostId },
        };
        
        // Test: Delete repost
        const result = await deleteRepost(mockRequest);
        logTest("Delete repost - success", result?.success === true);
        
        // Verify repost deleted
        const repostDoc = await db.collection("reposts").doc(repostId).get();
        logTest("Repost document deleted", !repostDoc.exists);
        
        // Verify count decremented
        const postDoc = await db.collection("posts").doc(testPostId).get();
        const postData = postDoc.data();
        const countDecremented = postData?.repostCount === 0;
        
        logTest("Repost count decremented", countDecremented,
            `Expected: 0, Got: ${postData?.repostCount}`);
        
        // Cleanup
        await db.collection("posts").doc(testPostId).delete();
        
        return true;
    } catch (error) {
        logTest("Delete repost - basic", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

async function testDeleteRepost_PermissionDenied() {
    console.log("\n🧪 Testing: deleteRepost - Permission denied");
    
    try {
        // Create a repost by user 2
        const repostRef = await db.collection("reposts").add({
            reposterId: TEST_USER_2_ID,
            originalPostId: "some-post-id",
            originalAuthorId: TEST_USER_2_ID,
            originalPostContextType: "profile",
            originalSpaceId: null,
            contextType: "profile",
            contextId: null,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const repostId = repostRef.id;
        
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: { repostId },
        };
        
        // Test: User 1 tries to delete user 2's repost (should fail)
        try {
            await deleteRepost(mockRequest);
            logTest("Permission denied for other user's repost", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error.code === "permission-denied";
            logTest("Permission denied for other user's repost", isPermissionError,
                `Error: ${error.message}`);
        }
        
        // Cleanup
        await db.collection("reposts").doc(repostId).delete();
        
        return true;
    } catch (error) {
        logTest("Permission denied test", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

async function testDeleteRepost_MissingRepost() {
    console.log("\n🧪 Testing: deleteRepost - Missing repost handling");
    
    try {
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: { repostId: "non-existent-repost-id" },
        };
        
        // Test: Try to delete non-existent repost
        try {
            await deleteRepost(mockRequest);
            logTest("Missing repost deletion blocked", false, "Should have thrown error");
        } catch (error) {
            const isNotFoundError = error.code === "not-found";
            logTest("Missing repost deletion blocked", isNotFoundError,
                `Error: ${error.message}`);
        }
        
        return true;
    } catch (error) {
        logTest("Missing repost handling", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

// =============================================================================
// TEST CASES - RACE CONDITIONS
// =============================================================================

async function testRaceCondition_ConcurrentReposts() {
    console.log("\n🧪 Testing: Race condition - Concurrent reposts");
    
    try {
        // Create a test post
        const testPostRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Race Test Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const mockRequest = {
            auth: { uid: TEST_USER_ID },
            data: {
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            },
        };
        
        // Simulate two concurrent requests
        const promise1 = createRepost(mockRequest);
        const promise2 = createRepost(mockRequest);
        
        const results = await Promise.allSettled([promise1, promise2]);
        
        // One should succeed, one should fail
        const succeeded = results.filter(r => r.status === "fulfilled").length;
        const failed = results.filter(r => r.status === "rejected").length;
        
        logTest("Concurrent reposts handled", succeeded === 1 && failed === 1,
            `Succeeded: ${succeeded}, Failed: ${failed}`);
        
        // Verify only one repost exists
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "==", TEST_USER_ID)
            .where("originalPostId", "==", testPostId)
            .get();
        logTest("Only one repost created", repostsSnapshot.size === 1,
            `Found ${repostsSnapshot.size} reposts`);
        
        // Verify count is correct
        const postDoc = await db.collection("posts").doc(testPostId).get();
        const postData = postDoc.data();
        logTest("Repost count correct", postData?.repostCount === 1,
            `Expected: 1, Got: ${postData?.repostCount}`);
        
        // Cleanup
        if (repostsSnapshot.size > 0) {
            await db.collection("reposts").doc(repostsSnapshot.docs[0].id).delete();
        }
        await db.collection("posts").doc(testPostId).delete();
        
        return true;
    } catch (error) {
        logTest("Race condition test", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

// =============================================================================
// TEST CASES - DATA CONSISTENCY
// =============================================================================

async function testDataConsistency_RepostCount() {
    console.log("\n🧪 Testing: Data consistency - Repost count accuracy");
    
    try {
        // Create a test post
        const testPostRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Count Test Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const mockCreateRequest = {
            auth: { uid: TEST_USER_ID },
            data: {
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            },
        };
        
        const mockDeleteRequest = (repostId) => ({
            auth: { uid: TEST_USER_ID },
            data: { repostId },
        });
        
        // Create multiple reposts
        const repostIds = [];
        for (let i = 0; i < 3; i++) {
            const result = await createRepost(mockCreateRequest);
            repostIds.push(result.repostId);
        }
        
        // Verify count
        const postDoc1 = await db.collection("posts").doc(testPostId).get();
        const postData1 = postDoc1.data();
        logTest("Repost count after 3 reposts", postData1?.repostCount === 3,
            `Expected: 3, Got: ${postData1?.repostCount}`);
        
        // Delete one repost
        await deleteRepost(mockDeleteRequest(repostIds[0]));
        
        // Verify count decremented
        const postDoc2 = await db.collection("posts").doc(testPostId).get();
        const postData2 = postDoc2.data();
        logTest("Repost count after deletion", postData2?.repostCount === 2,
            `Expected: 2, Got: ${postData2?.repostCount}`);
        
        // Verify actual reposts count matches
        const repostsSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", testPostId)
            .get();
        logTest("Actual reposts count matches", repostsSnapshot.size === 2,
            `Expected: 2, Got: ${repostsSnapshot.size}`);
        
        // Cleanup
        for (const repostId of repostIds.slice(1)) {
            await deleteRepost(mockDeleteRequest(repostId));
        }
        await db.collection("posts").doc(testPostId).delete();
        
        return true;
    } catch (error) {
        logTest("Data consistency test", false, `Error: ${error.message}`);
        console.error(error.stack);
        return false;
    }
}

// =============================================================================
// TEST RUNNER
// =============================================================================

async function runAllTests() {
    console.log("🚀 Starting Comprehensive Repost System Test Suite (Admin SDK)...\n");
    console.log(`Test User 1: ${TEST_USER_ID}`);
    console.log(`Test User 2: ${TEST_USER_2_ID}`);
    console.log(`Test User 3: ${TEST_USER_3_ID}`);
    console.log("=".repeat(60));
    
    try {
        // Setup
        const setupOk = await setupTestData();
        if (!setupOk) {
            console.error("\n❌ Test setup failed. Cannot proceed.");
            process.exit(1);
        }
        
        // Run all tests
        console.log("\n" + "=".repeat(60));
        console.log("TESTING CREATE REPOST");
        console.log("=".repeat(60));
        await testCreateRepost_Basic();
        await testCreateRepost_DuplicatePrevention();
        await testCreateRepost_SpacePost();
        await testCreateRepost_PrivateProfile();
        await testCreateRepost_MissingPost();
        await testCreateRepost_InvalidData();
        
        console.log("\n" + "=".repeat(60));
        console.log("TESTING DELETE REPOST");
        console.log("=".repeat(60));
        await testDeleteRepost_Basic();
        await testDeleteRepost_PermissionDenied();
        await testDeleteRepost_MissingRepost();
        
        console.log("\n" + "=".repeat(60));
        console.log("TESTING RACE CONDITIONS");
        console.log("=".repeat(60));
        await testRaceCondition_ConcurrentReposts();
        
        console.log("\n" + "=".repeat(60));
        console.log("TESTING DATA CONSISTENCY");
        console.log("=".repeat(60));
        await testDataConsistency_RepostCount();
        
        // Cleanup
        await cleanupTestData();
        
        // Summary
        console.log("\n" + "=".repeat(60));
        console.log("📊 FINAL TEST SUMMARY");
        console.log("=".repeat(60));
        console.log(`   ✅ Passed: ${testResults.passed}`);
        console.log(`   ❌ Failed: ${testResults.failed}`);
        const total = testResults.passed + testResults.failed;
        const successRate = total > 0 ? ((testResults.passed / total) * 100).toFixed(1) : 0;
        console.log(`   📈 Success Rate: ${successRate}%`);
        console.log("=".repeat(60));
        
        if (testResults.errors.length > 0) {
            console.log("\n❌ ERRORS FOUND:");
            testResults.errors.forEach((error, index) => {
                console.log(`   ${index + 1}. ${error.name}: ${error.details}`);
            });
        }
        
        if (testResults.failed === 0) {
            console.log("\n✅ ALL TESTS PASSED! System is working correctly.");
            process.exit(0);
        } else {
            console.log(`\n⚠️  ${testResults.failed} test(s) failed. Please review the errors above.`);
            process.exit(1);
        }
    } catch (error) {
        console.error(`\n❌ Test suite error: ${error.message}`);
        console.error(error.stack);
        await cleanupTestData();
        process.exit(1);
    }
}

// Run tests
runAllTests();
