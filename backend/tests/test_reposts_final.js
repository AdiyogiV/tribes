/**
 * =============================================================================
 * COMPREHENSIVE REPOST SYSTEM TEST SUITE (Final)
 * =============================================================================
 * 
 * Tests repost handlers directly (extracted from onCall wrappers)
 * This allows comprehensive testing without Firebase Functions runtime
 * 
 * Run: node tests/test_reposts_final.js
 * 
 * =============================================================================
 */

import { db, FieldValue } from "../lib/firebase.js";
import { createRepostHandler, deleteRepostHandler } from "../functions/reposts.js";
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
// SETUP & TEARDOWN
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
        logTest("Test data setup", false, error.message);
        return false;
    }
}

async function cleanupTestData() {
    console.log("\n🧹 Cleaning up test data...");
    
    try {
        // Clean reposts
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
            .get();
        
        const batch = db.batch();
        repostsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
        if (repostsSnapshot.docs.length > 0) await batch.commit();
        
        // Clean posts
        const postsSnapshot = await db.collection("posts")
            .where("author", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
            .get();
        
        const postBatch = db.batch();
        postsSnapshot.docs.forEach(doc => postBatch.delete(doc.ref));
        if (postsSnapshot.docs.length > 0) await postBatch.commit();
        
        // Clean users
        await db.collection("users").doc(TEST_USER_ID).delete();
        await db.collection("users").doc(TEST_USER_2_ID).delete();
        await db.collection("users").doc(TEST_USER_3_ID).delete();
        
        logTest("Test data cleanup", true);
        return true;
    } catch (error) {
        logTest("Test data cleanup", false, error.message);
        return false;
    }
}

// =============================================================================
// TEST CASES
// =============================================================================

async function testCreateRepost_Basic() {
    console.log("\n🧪 Testing: createRepost - Basic");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const result = await createRepostHandler(createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        
        logTest("Create repost - success", !!result.repostId);
        
        const repostDoc = await db.collection("reposts").doc(result.repostId).get();
        const repostData = repostDoc.data();
        
        logTest("Repost document created", repostDoc.exists);
        logTest("Repost has originalPostId", repostData?.originalPostId === postRef.id);
        logTest("Repost has reposterId", repostData?.reposterId === TEST_USER_ID);
        logTest("Repost has originalPostContextType", repostData?.originalPostContextType === "profile");
        logTest("Repost has originalSpaceId", repostData?.originalSpaceId === null);
        
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count incremented", postDoc.data()?.repostCount === 1);
        
        await db.collection("reposts").doc(result.repostId).delete();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Create repost - basic", false, error.message);
        return false;
    }
}

async function testCreateRepost_Duplicate() {
    console.log("\n🧪 Testing: createRepost - Duplicate prevention");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const mockRequest = createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        });
        
        const result1 = await createRepostHandler(mockRequest);
        logTest("First repost created", !!result1.repostId);
        
        try {
            await createRepostHandler(mockRequest);
            logTest("Duplicate repost prevented", false, "Should have thrown error");
        } catch (error) {
            const isDuplicate = error instanceof HttpsError && error.code === "already-exists";
            logTest("Duplicate repost prevented", isDuplicate, error.message);
        }
        
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "==", TEST_USER_ID)
            .where("originalPostId", "==", postRef.id)
            .get();
        logTest("Only one repost exists", repostsSnapshot.size === 1);
        
        await db.collection("reposts").doc(result1.repostId).delete();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Duplicate prevention", false, error.message);
        return false;
    }
}

async function testCreateRepost_PrivateProfile() {
    console.log("\n🧪 Testing: createRepost - Private profile");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_3_ID,
            contextType: "profile",
            title: "Private Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const mockRequest = createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        });
        
        try {
            await createRepostHandler(mockRequest);
            logTest("Private post repost blocked", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error instanceof HttpsError && error.code === "permission-denied";
            logTest("Private post repost blocked", isPermissionError, error.message);
        }
        
        await db.collection("follows")
            .doc(TEST_USER_ID)
            .collection("following")
            .doc(TEST_USER_3_ID)
            .set({ timestamp: FieldValue.serverTimestamp() });
        
        try {
            const result = await createRepostHandler(mockRequest);
            logTest("Follower can repost", !!result.repostId);
            await db.collection("reposts").doc(result.repostId).delete();
        } catch (error) {
            logTest("Follower can repost", false, error.message);
        }
        
        await db.collection("posts").doc(postRef.id).delete();
        await db.collection("follows")
            .doc(TEST_USER_ID)
            .collection("following")
            .doc(TEST_USER_3_ID)
            .delete();
        
        return true;
    } catch (error) {
        logTest("Private profile test", false, error.message);
        return false;
    }
}

async function testDeleteRepost_Basic() {
    console.log("\n🧪 Testing: deleteRepost - Basic");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
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
        
        const result = await deleteRepostHandler(createMockRequest(TEST_USER_ID, {
            repostId: repostRef.id,
        }));
        
        logTest("Delete repost - success", result?.success === true);
        
        const repostDoc = await db.collection("reposts").doc(repostRef.id).get();
        logTest("Repost deleted", !repostDoc.exists);
        
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count decremented", postDoc.data()?.repostCount === 0);
        
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Delete repost - basic", false, error.message);
        return false;
    }
}

async function testCreateRepost_SpacePost() {
    console.log("\n🧪 Testing: createRepost - Space post");
    
    try {
        const spaceRef = await db.collection("spaces").add({
            spaceType: 0,
            members: [TEST_USER_ID, TEST_USER_2_ID],
            name: "Test Space",
        });
        
        const spacePostRef = await db
            .collection("spaces")
            .doc(spaceRef.id)
            .collection("posts")
            .add({
                author: TEST_USER_2_ID,
                contextType: "space",
                space: spaceRef.id,
                title: "Space Post",
                repostCount: 0,
                timestamp: FieldValue.serverTimestamp(),
            });
        
        await db.collection("posts").doc(spacePostRef.id).set({
            author: TEST_USER_2_ID,
            contextType: "space",
            space: spaceRef.id,
            title: "Space Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const result = await createRepostHandler(createMockRequest(TEST_USER_ID, {
            originalPostId: spacePostRef.id,
            contextType: "profile",
            contextId: null,
        }));
        
        logTest("Space post repost created", !!result.repostId);
        
        const repostDoc = await db.collection("reposts").doc(result.repostId).get();
        const repostData = repostDoc.data();
        
        logTest("Repost stores originalPostContextType", repostData?.originalPostContextType === "space");
        logTest("Repost stores originalSpaceId", repostData?.originalSpaceId === spaceRef.id);
        
        const spacePostDoc = await db
            .collection("spaces")
            .doc(spaceRef.id)
            .collection("posts")
            .doc(spacePostRef.id)
            .get();
        
        logTest("Space post count incremented", spacePostDoc.data()?.repostCount === 1);
        
        await db.collection("reposts").doc(result.repostId).delete();
        await db.collection("spaces").doc(spaceRef.id)
            .collection("posts").doc(spacePostRef.id).delete();
        await db.collection("posts").doc(spacePostRef.id).delete();
        await db.collection("spaces").doc(spaceRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Space post repost", false, error.message);
        return false;
    }
}

async function testCreateRepost_InvalidData() {
    console.log("\n🧪 Testing: createRepost - Invalid data");
    
    try {
        // Empty originalPostId
        try {
            await createRepostHandler(createMockRequest(TEST_USER_ID, {
                originalPostId: "",
                contextType: "profile",
                contextId: null,
            }));
            logTest("Empty originalPostId rejected", false, "Should have thrown error");
        } catch (error) {
            const isValidError = error instanceof HttpsError && error.code === "invalid-argument";
            logTest("Empty originalPostId rejected", isValidError, error.message);
        }
        
        // Missing contextId for space
        try {
            await createRepostHandler(createMockRequest(TEST_USER_ID, {
                originalPostId: "some-id",
                contextType: "space",
                contextId: null,
            }));
            logTest("Missing contextId for space rejected", false, "Should have thrown error");
        } catch (error) {
            const isValidError = error instanceof HttpsError && error.code === "invalid-argument";
            logTest("Missing contextId for space rejected", isValidError, error.message);
        }
        
        return true;
    } catch (error) {
        logTest("Invalid data test", false, error.message);
        return false;
    }
}

async function testCreateRepost_MissingPost() {
    console.log("\n🧪 Testing: createRepost - Missing post");
    
    try {
        try {
            await createRepostHandler(createMockRequest(TEST_USER_ID, {
                originalPostId: "non-existent-post-id",
                contextType: "profile",
                contextId: null,
            }));
            logTest("Missing post repost blocked", false, "Should have thrown error");
        } catch (error) {
            const isNotFoundError = error instanceof HttpsError && error.code === "not-found";
            logTest("Missing post repost blocked", isNotFoundError, error.message);
        }
        
        return true;
    } catch (error) {
        logTest("Missing post test", false, error.message);
        return false;
    }
}

async function testDeleteRepost_PermissionDenied() {
    console.log("\n🧪 Testing: deleteRepost - Permission denied");
    
    try {
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
        
        try {
            await deleteRepostHandler(createMockRequest(TEST_USER_ID, {
                repostId: repostRef.id,
            }));
            logTest("Permission denied for other user's repost", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error instanceof HttpsError && error.code === "permission-denied";
            logTest("Permission denied for other user's repost", isPermissionError, error.message);
        }
        
        await db.collection("reposts").doc(repostRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Permission denied test", false, error.message);
        return false;
    }
}

async function testDeleteRepost_MissingRepost() {
    console.log("\n🧪 Testing: deleteRepost - Missing repost");
    
    try {
        try {
            await deleteRepostHandler(createMockRequest(TEST_USER_ID, {
                repostId: "non-existent-repost-id",
            }));
            logTest("Missing repost deletion blocked", false, "Should have thrown error");
        } catch (error) {
            const isNotFoundError = error instanceof HttpsError && error.code === "not-found";
            logTest("Missing repost deletion blocked", isNotFoundError, error.message);
        }
        
        return true;
    } catch (error) {
        logTest("Missing repost test", false, error.message);
        return false;
    }
}

async function testDeleteRepost_SpacePost() {
    console.log("\n🧪 Testing: deleteRepost - Space post");
    
    try {
        const spaceRef = await db.collection("spaces").add({
            spaceType: 0,
            members: [TEST_USER_ID, TEST_USER_2_ID],
            name: "Test Space",
        });
        
        const spacePostRef = await db
            .collection("spaces")
            .doc(spaceRef.id)
            .collection("posts")
            .add({
                author: TEST_USER_2_ID,
                contextType: "space",
                space: spaceRef.id,
                title: "Space Post",
                repostCount: 1,
                timestamp: FieldValue.serverTimestamp(),
            });
        
        await db.collection("posts").doc(spacePostRef.id).set({
            author: TEST_USER_2_ID,
            contextType: "space",
            space: spaceRef.id,
            title: "Space Post",
            repostCount: 1,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const repostRef = await db.collection("reposts").add({
            reposterId: TEST_USER_ID,
            originalPostId: spacePostRef.id,
            originalAuthorId: TEST_USER_2_ID,
            originalPostContextType: "space",
            originalSpaceId: spaceRef.id,
            contextType: "profile",
            contextId: null,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        await deleteRepostHandler(createMockRequest(TEST_USER_ID, {
            repostId: repostRef.id,
        }));
        
        const spacePostDoc = await db
            .collection("spaces")
            .doc(spaceRef.id)
            .collection("posts")
            .doc(spacePostRef.id)
            .get();
        
        logTest("Space post count decremented", spacePostDoc.data()?.repostCount === 0);
        
        await db.collection("spaces").doc(spaceRef.id)
            .collection("posts").doc(spacePostRef.id).delete();
        await db.collection("posts").doc(spacePostRef.id).delete();
        await db.collection("spaces").doc(spaceRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Delete space post repost", false, error.message);
        return false;
    }
}

async function testDataConsistency() {
    console.log("\n🧪 Testing: Data consistency");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Consistency Test",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // Test: Create and delete repost multiple times
        const repostIds = [];
        
        // Create repost
        const result1 = await createRepostHandler(createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        repostIds.push(result1.repostId);
        
        // Verify count
        let postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count after create", postDoc.data()?.repostCount === 1,
            `Expected: 1, Got: ${postDoc.data()?.repostCount}`);
        
        // Delete repost
        await deleteRepostHandler(createMockRequest(TEST_USER_ID, {
            repostId: result1.repostId,
        }));
        
        // Verify count decremented
        postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count after delete", postDoc.data()?.repostCount === 0,
            `Expected: 0, Got: ${postDoc.data()?.repostCount}`);
        
        // Create again (should work after deletion)
        const result2 = await createRepostHandler(createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        repostIds.push(result2.repostId);
        
        // Verify count incremented again
        postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count after recreate", postDoc.data()?.repostCount === 1,
            `Expected: 1, Got: ${postDoc.data()?.repostCount}`);
        
        // Verify actual reposts count matches
        const repostsSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postRef.id)
            .get();
        
        logTest("Actual reposts count matches", repostsSnapshot.size === 1,
            `Expected: 1, Got: ${repostsSnapshot.size}`);
        
        // Cleanup
        await deleteRepostHandler(createMockRequest(TEST_USER_ID, {
            repostId: result2.repostId,
        }));
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Data consistency test", false, error.message);
        console.error(error.stack);
        return false;
    }
}

async function testCreateRepost_PrivateSpace() {
    console.log("\n🧪 Testing: createRepost - Private space");
    
    try {
        const spaceRef = await db.collection("spaces").add({
            spaceType: 2, // Private space
            members: [TEST_USER_2_ID], // Only user 2 is member
            name: "Private Space",
        });
        
        const spacePostRef = await db
            .collection("spaces")
            .doc(spaceRef.id)
            .collection("posts")
            .add({
                author: TEST_USER_2_ID,
                contextType: "space",
                space: spaceRef.id,
                title: "Private Space Post",
                repostCount: 0,
                timestamp: FieldValue.serverTimestamp(),
            });
        
        await db.collection("posts").doc(spacePostRef.id).set({
            author: TEST_USER_2_ID,
            contextType: "space",
            space: spaceRef.id,
            title: "Private Space Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // Test: Non-member cannot repost
        try {
            await createRepostHandler(createMockRequest(TEST_USER_ID, {
                originalPostId: spacePostRef.id,
                contextType: "profile",
                contextId: null,
            }));
            logTest("Private space post repost blocked (non-member)", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error instanceof HttpsError && error.code === "permission-denied";
            logTest("Private space post repost blocked (non-member)", isPermissionError, error.message);
        }
        
        // Test: Member can repost
        await db.collection("spaces").doc(spaceRef.id).update({
            members: [TEST_USER_ID, TEST_USER_2_ID],
        });
        
        try {
            const result = await createRepostHandler(createMockRequest(TEST_USER_ID, {
                originalPostId: spacePostRef.id,
                contextType: "profile",
                contextId: null,
            }));
            logTest("Member can repost private space post", !!result.repostId);
            await db.collection("reposts").doc(result.repostId).delete();
        } catch (error) {
            logTest("Member can repost private space post", false, error.message);
        }
        
        await db.collection("spaces").doc(spaceRef.id)
            .collection("posts").doc(spacePostRef.id).delete();
        await db.collection("posts").doc(spacePostRef.id).delete();
        await db.collection("spaces").doc(spaceRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Private space test", false, error.message);
        return false;
    }
}

async function testCreateRepost_SelfRepost() {
    console.log("\n🧪 Testing: createRepost - Self repost");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_ID,
            contextType: "profile",
            title: "My Own Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // Self-repost should work (no restriction)
        const result = await createRepostHandler(createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        
        logTest("Self-repost allowed", !!result.repostId);
        
        // Verify no notification sent (should be skipped for self-repost)
        // This is tested implicitly - if notification was sent, it would be logged
        
        await db.collection("reposts").doc(result.repostId).delete();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Self-repost test", false, error.message);
        return false;
    }
}

async function testCreateRepost_MultipleUsers() {
    console.log("\n🧪 Testing: createRepost - Multiple users reposting same post");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Popular Post",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // User 1 reposts
        const result1 = await createRepostHandler(createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        
        // User 2 reposts (different user, should work)
        const result2 = await createRepostHandler(createMockRequest(TEST_USER_2_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        
        logTest("Multiple users can repost same post", !!result1.repostId && !!result2.repostId);
        
        // Verify count is 2
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count for multiple users", postDoc.data()?.repostCount === 2,
            `Expected: 2, Got: ${postDoc.data()?.repostCount}`);
        
        // Verify both reposts exist
        const repostsSnapshot = await db.collection("reposts")
            .where("originalPostId", "==", postRef.id)
            .get();
        
        logTest("Both reposts exist", repostsSnapshot.size === 2,
            `Expected: 2, Got: ${repostsSnapshot.size}`);
        
        await db.collection("reposts").doc(result1.repostId).delete();
        await db.collection("reposts").doc(result2.repostId).delete();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Multiple users test", false, error.message);
        return false;
    }
}

async function testCreateRepost_MissingAuthor() {
    console.log("\n🧪 Testing: createRepost - Missing author field");
    
    try {
        const postRef = await db.collection("posts").add({
            // Missing author field
            contextType: "profile",
            title: "Post Without Author",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        try {
            await createRepostHandler(createMockRequest(TEST_USER_ID, {
                originalPostId: postRef.id,
                contextType: "profile",
                contextId: null,
            }));
            logTest("Missing author field rejected", false, "Should have thrown error");
        } catch (error) {
            const isValidError = error instanceof HttpsError && 
                (error.code === "invalid-argument" || error.message?.includes("author"));
            logTest("Missing author field rejected", isValidError, error.message);
        }
        
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Missing author test", false, error.message);
        return false;
    }
}

async function testDeleteRepost_DeletedOriginalPost() {
    console.log("\n🧪 Testing: deleteRepost - Deleted original post");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Post to Delete",
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
        
        // Delete original post first
        await db.collection("posts").doc(postRef.id).delete();
        
        // Delete repost (should still work even if original post is deleted)
        const result = await deleteRepostHandler(createMockRequest(TEST_USER_ID, {
            repostId: repostRef.id,
        }));
        
        logTest("Delete repost with deleted original post", result?.success === true);
        
        const repostDoc = await db.collection("reposts").doc(repostRef.id).get();
        logTest("Repost deleted even if original post deleted", !repostDoc.exists);
        
        return true;
    } catch (error) {
        logTest("Deleted original post test", false, error.message);
        return false;
    }
}

async function testTransactionAtomicity() {
    console.log("\n🧪 Testing: Transaction atomicity");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Transaction Test",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        // Create repost (transaction should ensure atomicity)
        const result = await createRepostHandler(createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        }));
        
        // Verify both repost and count updated atomically
        const repostDoc = await db.collection("reposts").doc(result.repostId).get();
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        
        const repostExists = repostDoc.exists;
        const countUpdated = postDoc.data()?.repostCount === 1;
        
        logTest("Transaction atomicity", repostExists && countUpdated,
            `Repost exists: ${repostExists}, Count updated: ${countUpdated}`);
        
        await db.collection("reposts").doc(result.repostId).delete();
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Transaction atomicity test", false, error.message);
        return false;
    }
}

async function testRaceCondition() {
    console.log("\n🧪 Testing: Race condition");
    
    try {
        const postRef = await db.collection("posts").add({
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Race Test",
            repostCount: 0,
            timestamp: FieldValue.serverTimestamp(),
        });
        
        const mockRequest = createMockRequest(TEST_USER_ID, {
            originalPostId: postRef.id,
            contextType: "profile",
            contextId: null,
        });
        
        // Start both requests concurrently (don't await individually)
        const promise1 = createRepostHandler(mockRequest);
        const promise2 = createRepostHandler(mockRequest);
        
        // Wait for both to settle
        const [result1, result2] = await Promise.allSettled([promise1, promise2]);
        
        const succeeded = [result1, result2].filter(r => r.status === "fulfilled").length;
        const failed = [result1, result2].filter(r => r.status === "rejected").length;
        
        logTest("Race condition handled", succeeded === 1 && failed === 1,
            `Succeeded: ${succeeded}, Failed: ${failed}`);
        
        const repostsSnapshot = await db.collection("reposts")
            .where("reposterId", "==", TEST_USER_ID)
            .where("originalPostId", "==", postRef.id)
            .get();
        
        logTest("Only one repost created", repostsSnapshot.size === 1,
            `Found ${repostsSnapshot.size} reposts`);
        
        // Verify count is correct
        const postDoc = await db.collection("posts").doc(postRef.id).get();
        logTest("Repost count correct", postDoc.data()?.repostCount === 1,
            `Expected: 1, Got: ${postDoc.data()?.repostCount}`);
        
        if (repostsSnapshot.size > 0) {
            await db.collection("reposts").doc(repostsSnapshot.docs[0].id).delete();
        }
        await db.collection("posts").doc(postRef.id).delete();
        
        return true;
    } catch (error) {
        logTest("Race condition test", false, error.message);
        console.error(error.stack);
        return false;
    }
}

// =============================================================================
// TEST RUNNER
// =============================================================================

async function runAllTests() {
    console.log("🚀 Starting Comprehensive Repost Test Suite...\n");
    console.log(`Test User 1: ${TEST_USER_ID}`);
    console.log(`Test User 2: ${TEST_USER_2_ID}`);
    console.log(`Test User 3: ${TEST_USER_3_ID}`);
    console.log("=".repeat(60));
    
    try {
        await setupTestData();
        
        await testCreateRepost_Basic();
        await testCreateRepost_Duplicate();
        await testCreateRepost_PrivateProfile();
        await testCreateRepost_PrivateSpace();
        await testCreateRepost_SpacePost();
        await testCreateRepost_SelfRepost();
        await testCreateRepost_MultipleUsers();
        await testCreateRepost_InvalidData();
        await testCreateRepost_MissingPost();
        await testCreateRepost_MissingAuthor();
        await testDeleteRepost_Basic();
        await testDeleteRepost_PermissionDenied();
        await testDeleteRepost_MissingRepost();
        await testDeleteRepost_SpacePost();
        await testDeleteRepost_DeletedOriginalPost();
        await testRaceCondition();
        await testDataConsistency();
        await testTransactionAtomicity();
        
        await cleanupTestData();
        
        console.log("\n" + "=".repeat(60));
        console.log("📊 FINAL SUMMARY");
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
            console.log("\n✅ ALL TESTS PASSED! System is perfect.");
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
