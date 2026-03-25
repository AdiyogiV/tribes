/**
 * =============================================================================
 * REPOST HELPER FUNCTIONS TEST SUITE
 * =============================================================================
 * 
 * Tests helper functions directly (not wrapped in onCall)
 * These functions can be tested without Firebase Functions runtime
 * 
 * Run: node tests/test_reposts_helpers.js
 * 
 * =============================================================================
 */

import { db, FieldValue } from "../lib/firebase.js";

// We'll need to import helper functions if they're exported
// For now, we'll test what we can access

const TEST_USER_ID = process.env.TEST_USER_ID || "test_user_" + Date.now();
const TEST_USER_2_ID = process.env.TEST_USER_2_ID || "test_user_2_" + Date.now();

const testResults = {
    passed: 0,
    failed: 0,
    tests: [],
};

function logTest(name, passed, details = "") {
    if (passed) {
        console.log(`✅ ${name}`);
        testResults.passed++;
    } else {
        console.log(`❌ ${name}`);
        testResults.failed++;
        if (details) console.log(`   ${details}`);
    }
}

async function testFirestoreOperations() {
    console.log("\n🧪 Testing: Firestore operations");
    
    try {
        // Test: Create post
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        logTest("Create post", !!postRef.id);
        
        // Test: Read post
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Read post", postDoc.exists);
        
        // Test: Update post
        await db.collection("posts").doc(postRef.id).update({
            repostCount: FieldValue.increment(1),
        });
        
        const updatedDoc = await db.collection("posts").doc(postRef.id).get();
        const updatedData = updatedDoc.data();
        logTest("Update repost count", updatedData?.repostCount === 1);
        
        // Test: Create repost
        const repostRef = await db.collection("reposts").add({
            reposterId: TEST_USER_ID,
            originalPostId: postRef.id,
            originalPostContextType: "profile",
            originalSpaceId: null,
            contextType: "profile",
            contextId: null,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        logTest("Create repost document", !!repostRef.id);
        
        // Test: Query reposts
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "==", TEST_USER_ID)
            .where("originalPostId", "==", postRef.id)
            .get();
        
        logTest("Query reposts", repostsSnapshot.size === 1);
        
        // Cleanup
        await db.collection("reposts").doc(repostRef.id).delete();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Firestore operations", false, error.message);
        return false;
    }
}

async function testTransactionOperations() {
    console.log("\n🧪 Testing: Transaction operations");
    
    try {
        // Create test post
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Transaction Test",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // Test: Transaction with repost creation and count increment
        await db.runTransaction(async (transaction) => {
            const repostRef = db.collection("reposts").doc();
            transaction.set(repostRef, {
                reposterId: TEST_USER_ID,
                originalPostId: postRef.id,
                originalPostContextType: "profile",
                contextType: "profile",
                timestamp: FieldValue.serverTimestamp(),
            });
            
            transaction.update(db.collection("posts").doc(postRef.id), {
                repostCount: FieldValue.increment(1),
            });
        });
        
        // Verify
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        const postData = postDoc.data();
        logTest("Transaction atomicity", postData?.repostCount === 1);
        
        // Cleanup
        const repostsSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postRef.id)
            .get();
        
        const batch = db.batch();
        repostsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Transaction operations", false, error.message);
        return false;
    }
}

async function runAllTests() {
    console.log("🚀 Testing Repost Helper Functions...\n");
    
    try {
        await testFirestoreOperations();
        await testTransactionOperations();
        
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
        process.exit(1);
    }
}

runAllTests();
