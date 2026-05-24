/**
 * =============================================================================
 * EDGE CASE TEST SUITE FOR REPOST SYSTEM
 * =============================================================================
 * 
 * Tests additional edge cases and failure scenarios not covered in main tests
 * 
 * Run: node tests/test_reposts_edge_cases.js
 * 
 * =============================================================================
 */

import { db, FieldValue } from "../lib/firebase.js";
import { handleCreateRepost, handleDeleteRepost, cascadeDeleteReposts } from "../functions/reposts.js";
import { HttpsError } from "firebase-functions/v2/https";

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

function createMockRequest(userId, data) {
    return {
        auth: { uid: userId },
        data: data,
    };
}

// =============================================================================
// EDGE CASE TESTS
// =============================================================================

async function testCascadeDelete_ExactBatchSize() {
    console.log("\n🧪 Testing: Cascade delete - Exactly 500 reposts (batch boundary)");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Popular Post",
            repostCount: 500,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const postId = postRef.id;
        
        // Create exactly 500 reposts to test batch boundary
        const batches = [];
        for (let i = 0; i < 5; i++) {
            const batch = db.batch();
            for (let j = 0; j < 100; j++) {
                const repostRef = db.collection("reposts").doc();
                batch.set(repostRef, {
                    reposterId: `${TEST_USER_ID}_${i}_${j}`,
                    originalPostId: postId,
                    originalAuthorId: TEST_USER_2_ID,
                    originalPostContextType: "profile",
                    originalSpaceId: null,
                    contextType: "profile",
                    contextId: null,
                    timestamp: FieldValue.serverTimestamp(),
                });
            }
            batches.push(batch);
        }
        
        // Commit all batches
        await Promise.all(batches.map(b => b.commit()));
        
        // Verify 500 reposts exist
        const beforeSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postId)
            .get();
        logTest("500 reposts created", beforeSnapshot.size === 500,
            `Expected: 500, Got: ${beforeSnapshot.size}`);
        
        const postDoc = await db.collection("posts").doc(postId).get();
        const postData = postDoc.data();
        
        // Test cascade delete
        await cascadeDeleteReposts(postId, postData);
        
        // Verify all deleted
        const afterSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postId)
            .get();
        
        logTest("All 500 reposts deleted", afterSnapshot.size === 0,
            `Expected: 0, Got: ${afterSnapshot.size}`);
        
        await db.collection("posts").doc(postId).delete();
        
        return true;
    } catch (error) {
        logTest("Cascade delete - exact batch size", false, error.message);
        console.error(error.stack);
        return false;
    }
}

async function testCascadeDelete_MoreThanBatchSize() {
    console.log("\n🧪 Testing: Cascade delete - More than 500 reposts (multiple batches)");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Very Popular Post",
            repostCount: 1200,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const postId = postRef.id;
        
        // Create 1200 reposts (more than one batch)
        const batches = [];
        for (let i = 0; i < 12; i++) {
            const batch = db.batch();
            for (let j = 0; j < 100; j++) {
                const repostRef = db.collection("reposts").doc();
                batch.set(repostRef, {
                    reposterId: `${TEST_USER_ID}_${i}_${j}`,
                    originalPostId: postId,
                    originalAuthorId: TEST_USER_2_ID,
                    originalPostContextType: "profile",
                    originalSpaceId: null,
                    contextType: "profile",
                    contextId: null,
                    timestamp: FieldValue.serverTimestamp(),
                });
            }
            batches.push(batch);
        }
        
        await Promise.all(batches.map(b => b.commit()));
        
        const beforeSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postId)
            .get();
        logTest("1200 reposts created", beforeSnapshot.size === 1200,
            `Expected: 1200, Got: ${beforeSnapshot.size}`);
        
        const postDoc = await db.collection("posts").doc(postId).get();
        const postData = postDoc.data();
        
        // Test cascade delete (should handle pagination)
        await cascadeDeleteReposts(postId, postData);
        
        const afterSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postId)
            .get();
        
        logTest("All 1200 reposts deleted", afterSnapshot.size === 0,
            `Expected: 0, Got: ${afterSnapshot.size}`);
        
        await db.collection("posts").doc(postId).delete();
        
        return true;
    } catch (error) {
        logTest("Cascade delete - more than batch size", false, error.message);
        console.error(error.stack);
        return false;
    }
}

async function testCascadeDelete_ConcurrentDeletions() {
    console.log("\n🧪 Testing: Cascade delete - Concurrent repost deletions during cascade");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Post with concurrent deletions",
            repostCount: 10,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const postId = postRef.id;
        
        // Create reposts
        const repostIds = [];
        for (let i = 0; i < 10; i++) {
            const repostRef = await db.collection("reposts").add({
                reposterId: `${TEST_USER_ID}_${i}`,
                originalPostId: postId,
                originalAuthorId: TEST_USER_2_ID,
                originalPostContextType: "profile",
                originalSpaceId: null,
                contextType: "profile",
                contextId: null,
                timestamp: FieldValue.serverTimestamp(),
            });
            repostIds.push(repostRef.id);
        }
        
        // Start cascade delete
        const postDoc = await db.collection("posts").doc(postId).get();
        const postData = postDoc.data();
        const cascadePromise = cascadeDeleteReposts(postId, postData);
        
        // Simulate concurrent manual deletions (user deleting their repost)
        // Delete first 3 reposts manually
        const manualDeletes = repostIds.slice(0, 3).map(id => 
            db.collection("reposts").doc(id).delete()
        );
        await Promise.all(manualDeletes);
        
        // Wait for cascade delete to complete
        await cascadePromise;
        
        // Verify all reposts are deleted (both cascade and manual)
        const afterSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postId)
            .get();
        
        logTest("All reposts deleted (cascade + concurrent)", afterSnapshot.size === 0,
            `Expected: 0, Got: ${afterSnapshot.size}`);
        
        await db.collection("posts").doc(postId).delete();
        
        return true;
    } catch (error) {
        logTest("Cascade delete - concurrent deletions", false, error.message);
        console.error(error.stack);
        return false;
    }
}

async function testCreateRepost_TransactionFailure() {
    console.log("\n🧪 Testing: Create repost - Transaction failure handling");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Transaction Test",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // Create repost normally
        const result1 = await handleCreateRepost(createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        
        logTest("First repost created", !!result1.repostId);
        
        // Try to create duplicate (should fail with already-exists)
        try {
            await handleCreateRepost(createMockRequest(TEST_USER_ID, {
                originalPostId: postRef.id,
                contextType: "profile",
                contextId: null,
            }));
            logTest("Duplicate repost prevented", false, "Should have thrown error");
        } catch (error) {
            const isDuplicate = error instanceof HttpsError && error.code === "already-exists";
            logTest("Duplicate repost prevented", isDuplicate, error.message);
        }
        
        // Verify only one repost exists
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "==", TEST_USER_ID)
            .where("originalPostId", "==", postRef.id)
            .get();
        
        logTest("Only one repost exists after duplicate attempt", repostsSnapshot.size === 1,
            `Expected: 1, Got: ${repostsSnapshot.size}`);
        
        // Verify count is correct
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count correct after duplicate attempt", postDoc.data()?.repostCount === 1,
            `Expected: 1, Got: ${postDoc.data()?.repostCount}`);
        
        await db.collection("reposts").doc(result1.repostId).delete();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Transaction failure handling", false, error.message);
        console.error(error.stack);
        return false;
    }
}

async function testDeleteRepost_AlreadyDeleted() {
    console.log("\n🧪 Testing: Delete repost - Repost already deleted");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Post",
            repostCount: 1,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const repostRef = await db.collection("reposts").add({
            reposterId: TEST_USER_ID,
            originalPostId: postRef.id,
            originalAuthorId: TEST_USER_2_ID,
            originalPostContextType: "profile",
            originalSpaceId: null,
            contextType: "profile",
            contextId: null,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // Delete repost
        await handleDeleteRepost(createMockRequest(TEST_USER_ID, {
            repostId: repostRef.id,
        }));
        
        logTest("Repost deleted successfully", true);
        
        // Try to delete again (should fail)
        try {
            await handleDeleteRepost(createMockRequest(TEST_USER_ID, {
                repostId: repostRef.id,
            }));
            logTest("Delete already-deleted repost prevented", false, "Should have thrown error");
        } catch (error) {
            const isNotFound = error instanceof HttpsError && error.code === "not-found";
            logTest("Delete already-deleted repost prevented", isNotFound, error.message);
        }
        
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Delete already-deleted repost", false, error.message);
        console.error(error.stack);
        return false;
    }
}

async function testCascadeDelete_NoReposts() {
    console.log("\n🧪 Testing: Cascade delete - Post with no reposts");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Post with no reposts",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const postId = postRef.id;
        const postDoc = await db.collection("posts").doc(postId).get();
        const postData = postDoc.data();
        
        // Cascade delete should handle gracefully
        await cascadeDeleteReposts(postId, postData);
        
        // Verify no errors occurred
        const repostsSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postId)
            .get();
        
        logTest("Cascade delete with no reposts handled", repostsSnapshot.size === 0,
            `Expected: 0, Got: ${repostsSnapshot.size}`);
        
        await db.collection("posts").doc(postId).delete();
        
        return true;
    } catch (error) {
        logTest("Cascade delete - no reposts", false, error.message);
        console.error(error.stack);
        return false;
    }
}

// =============================================================================
// TEST RUNNER
// =============================================================================

async function runAllTests() {
    console.log("🚀 Starting Edge Case Test Suite...\n");
    console.log(`Test User 1: ${TEST_USER_ID}`);
    console.log(`Test User 2: ${TEST_USER_2_ID}`);
    console.log(`Test User 3: ${TEST_USER_3_ID}`);
    console.log("=".repeat(60));
    
    try {
        await testCascadeDelete_ExactBatchSize();
        await testCascadeDelete_MoreThanBatchSize();
        await testCascadeDelete_ConcurrentDeletions();
        await testCreateRepost_TransactionFailure();
        await testDeleteRepost_AlreadyDeleted();
        await testCascadeDelete_NoReposts();
        
        console.log("\n" + "=".repeat(60));
        console.log("📊 EDGE CASE TEST SUMMARY");
        console.log("=".repeat(60));
        console.log(`   ✅ Passed: ${testResults.passed}`);
        console.log(`   ❌ Failed: ${testResults.failed}`);
        const total = testResults.passed + testResults.failed;
        const rate = total > 0 ? ((testResults.passed / total) * 100).toFixed(1) : 0;
        console.log(`   📈 Success Rate: ${rate}%`);
        console.log("=".repeat(60));
        
        if (testResults.errors.length > 0) {
            console.log("\n❌ ERRORS:");
            testResults.errors.forEach((e, i) => {
                console.log(`   ${i + 1}. ${e.name}: ${e.details}`);
            });
        }
        
        if (testResults.failed === 0) {
            console.log("\n✅ ALL EDGE CASE TESTS PASSED!");
            process.exit(0);
        } else {
            console.log(`\n⚠️  ${testResults.failed} test(s) failed.`);
            process.exit(1);
        }
    } catch (error) {
        console.error(`\n❌ Test suite error: ${error.message}`);
        console.error(error.stack);
        process.exit(1);
    }
}

runAllTests();
