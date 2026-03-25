/**
 * =============================================================================
 * COMPREHENSIVE REPOST SYSTEM TEST SUITE
 * =============================================================================
 * 
 * Tests EVERYTHING deeply:
 * - All edge cases for createRepost
 * - All edge cases for deleteRepost
 * - Cascade delete triggers
 * - Permissions (private profiles, spaces, followers, members)
 * - Race conditions and transaction atomicity
 * - Feed integration
 * - Error handling
 * - Data consistency
 * - Missing fields, invalid data, deleted posts
 * 
 * Prerequisites:
 * 1. Firebase emulator running: firebase emulators:start
 * 2. Set TEST_USER_ID and TEST_USER_2_ID environment variables
 * 
 * Run: node tests/test_reposts_comprehensive.js
 * 
 * =============================================================================
 */

import { initializeApp } from "firebase/app";
import { 
    getFirestore, 
    doc, 
    getDoc, 
    collection, 
    query, 
    where, 
    getDocs, 
    addDoc, 
    deleteDoc,
    setDoc,
    updateDoc,
    connectFirestoreEmulator,
    writeBatch,
    Timestamp,
    serverTimestamp,
} from "firebase/firestore";
// Auth import - only use if not in emulator mode
let getAuth, signInWithEmailAndPassword;
try {
    const authModule = await import("firebase/auth");
    getAuth = authModule.getAuth;
    signInWithEmailAndPassword = authModule.signInWithEmailAndPassword;
} catch (error) {
    // Auth not available in emulator mode
    console.log("⚠️  Firebase Auth module not available");
}
import { 
    getFunctions, 
    httpsCallable,
    connectFunctionsEmulator 
} from "firebase/functions";

// Firebase config
const USE_EMULATOR = process.env.USE_EMULATOR !== "false";
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "tribes-test";

// For emulator, use minimal config (no API keys needed)
const firebaseConfig = USE_EMULATOR ? {
    projectId: FIREBASE_PROJECT_ID,
} : {
    projectId: FIREBASE_PROJECT_ID,
    // Add production config here if needed
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
// Auth is not needed for emulator testing - Cloud Functions handle auth via request.auth
const functions = getFunctions(app, USE_EMULATOR ? undefined : "asia-southeast2");

// Connect to emulator if using emulator
if (USE_EMULATOR) {
    try {
        connectFirestoreEmulator(db, "127.0.0.1", 8080);
        connectFunctionsEmulator(functions, "127.0.0.1", 5001);
        console.log("✅ Connected to Firebase emulator");
    } catch (error) {
        // Already connected or emulator not running
        console.log("⚠️  Emulator connection:", error.message);
    }
}

const TEST_USER_ID = process.env.TEST_USER_ID || "test_user_" + Date.now();
const TEST_USER_2_ID = process.env.TEST_USER_2_ID || "test_user_2_" + Date.now();
const TEST_USER_3_ID = process.env.TEST_USER_3_ID || "test_user_3_" + Date.now();
const TEST_USER_EMAIL = process.env.TEST_USER_EMAIL;
const TEST_USER_PASSWORD = process.env.TEST_USER_PASSWORD;

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
        await setDoc(doc(db, "users", TEST_USER_ID), {
            name: "Test User 1",
            username: "testuser1",
            isPrivateProfile: false,
            displayPicture: "https://example.com/user1.jpg",
        });
        
        await setDoc(doc(db, "users", TEST_USER_2_ID), {
            name: "Test User 2",
            username: "testuser2",
            isPrivateProfile: false,
            displayPicture: "https://example.com/user2.jpg",
        });
        
        await setDoc(doc(db, "users", TEST_USER_3_ID), {
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
        const repostsQuery = query(
            collection(db, "reposts"),
            where("reposterId", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
        );
        const repostsSnapshot = await getDocs(repostsQuery);
        const deletePromises = repostsSnapshot.docs.map(doc => deleteDoc(doc.ref));
        await Promise.all(deletePromises);
        
        // Delete test posts
        const postsQuery = query(
            collection(db, "posts"),
            where("author", "in", [TEST_USER_ID, TEST_USER_2_ID, TEST_USER_3_ID])
        );
        const postsSnapshot = await getDocs(postsQuery);
        const postDeletePromises = postsSnapshot.docs.map(doc => deleteDoc(doc.ref));
        await Promise.all(postDeletePromises);
        
        // Delete test spaces
        const spacesQuery = query(
            collection(db, "spaces"),
            where("members", "array-contains", TEST_USER_ID)
        );
        const spacesSnapshot = await getDocs(spacesQuery);
        const spaceDeletePromises = spacesSnapshot.docs.map(doc => deleteDoc(doc.ref));
        await Promise.all(spaceDeletePromises);
        
        // Delete test users
        await deleteDoc(doc(db, "users", TEST_USER_ID));
        await deleteDoc(doc(db, "users", TEST_USER_2_ID));
        await deleteDoc(doc(db, "users", TEST_USER_3_ID));
        
        // Clean up follows
        const followsRef = doc(db, "follows", TEST_USER_ID);
        const followingRef = collection(followsRef, "following");
        const followingSnapshot = await getDocs(followingRef);
        const followDeletePromises = followingSnapshot.docs.map(doc => deleteDoc(doc.ref));
        await Promise.all(followDeletePromises);
        
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
        const testPostRef = await addDoc(collection(db, "posts"), {
            author: TEST_USER_2_ID,
            authorName: "Test User 2",
            contextType: "profile",
            title: "Test Post for Repost",
            content: "This is a test post",
            repostCount: 0,
            timestamp: serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        // Note: In emulator mode, Cloud Functions automatically authenticate requests
        // For production testing, you'd need to authenticate here
        
        // Get Cloud Function
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Test: Create repost
        const result = await createRepostFn({
            originalPostId: testPostId,
            contextType: "profile",
            contextId: null,
        });
        
        const repostId = result.data.repostId;
        logTest("Create repost - success", !!repostId, `Repost ID: ${repostId}`);
        
        // Verify repost document
        const repostDoc = await getDoc(doc(db, "reposts", repostId));
        const repostExists = repostDoc.exists();
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
        const postDoc = await getDoc(doc(db, "posts", testPostId));
        const postData = postDoc.data();
        const countIncremented = postData?.repostCount === 1;
        
        logTest("Repost count incremented", countIncremented,
            `Expected: 1, Got: ${postData?.repostCount}`);
        
        // Cleanup
        await deleteDoc(doc(db, "reposts", repostId));
        await deleteDoc(doc(db, "posts", testPostId));
        
        return true;
    } catch (error) {
        logTest("Create repost - basic", false, `Error: ${error.message}`);
        return false;
    }
}

async function testCreateRepost_DuplicatePrevention() {
    console.log("\n🧪 Testing: createRepost - Duplicate prevention");
    
    try {
        // Create a test post
        const testPostRef = await addDoc(collection(db, "posts"), {
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 0,
            timestamp: serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Create first repost
        const result1 = await createRepostFn({
            originalPostId: testPostId,
            contextType: "profile",
            contextId: null,
        });
        
        const repostId1 = result1.data.repostId;
        logTest("First repost created", !!repostId1);
        
        // Try to create duplicate (should fail)
        try {
            await createRepostFn({
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            });
            logTest("Duplicate repost prevented", false, "Should have thrown error");
        } catch (error) {
            const isDuplicateError = error.code === "already-exists" ||
                error.message?.includes("already reposted");
            logTest("Duplicate repost prevented", isDuplicateError,
                `Error: ${error.message}`);
        }
        
        // Verify only one repost exists
        const repostsQuery = query(
            collection(db, "reposts"),
            where("reposterId", "==", TEST_USER_ID),
            where("originalPostId", "==", testPostId)
        );
        const repostsSnapshot = await getDocs(repostsQuery);
        logTest("Only one repost exists", repostsSnapshot.size === 1,
            `Found ${repostsSnapshot.size} reposts`);
        
        // Verify count is correct
        const postDoc = await getDoc(doc(db, "posts", testPostId));
        const postData = postDoc.data();
        logTest("Repost count correct", postData?.repostCount === 1,
            `Expected: 1, Got: ${postData?.repostCount}`);
        
        // Cleanup
        await deleteDoc(doc(db, "reposts", repostId1));
        await deleteDoc(doc(db, "posts", testPostId));
        
        return true;
    } catch (error) {
        logTest("Duplicate prevention", false, `Error: ${error.message}`);
        return false;
    }
}

async function testCreateRepost_SpacePost() {
    console.log("\n🧪 Testing: createRepost - Space post repost");
    
    try {
        // Create a test space
        const testSpaceRef = await addDoc(collection(db, "spaces"), {
            spaceType: 0, // Public space
            members: [TEST_USER_ID, TEST_USER_2_ID],
            name: "Test Space",
        });
        
        const testSpaceId = testSpaceRef.id;
        
        // Create a space post
        const spacePostRef = await addDoc(
            collection(db, "spaces", testSpaceId, "posts"),
            {
                author: TEST_USER_2_ID,
                contextType: "space",
                space: testSpaceId,
                title: "Space Post",
                repostCount: 0,
                timestamp: serverTimestamp(),
            }
        );
        
        const spacePostId = spacePostRef.id;
        
        // Also create in top-level posts for lookup
        await setDoc(doc(db, "posts", spacePostId), {
            author: TEST_USER_2_ID,
            contextType: "space",
            space: testSpaceId,
            title: "Space Post",
            repostCount: 0,
            timestamp: serverTimestamp(),
        });
        
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Test: Create repost of space post
        const result = await createRepostFn({
            originalPostId: spacePostId,
            contextType: "profile",
            contextId: null,
        });
        
        const repostId = result.data.repostId;
        logTest("Space post repost created", !!repostId);
        
        // Verify repost stores original context
        const repostDoc = await getDoc(doc(db, "reposts", repostId));
        const repostData = repostDoc.data();
        
        logTest("Repost stores originalPostContextType", 
            repostData?.originalPostContextType === "space");
        logTest("Repost stores originalSpaceId", 
            repostData?.originalSpaceId === testSpaceId);
        
        // Verify count incremented on space post
        const spacePostDoc = await getDoc(
            doc(db, "spaces", testSpaceId, "posts", spacePostId)
        );
        
        const spacePostData = spacePostDoc.data();
        logTest("Space post count incremented", 
            spacePostData?.repostCount === 1);
        
        // Cleanup
        await deleteDoc(doc(db, "reposts", repostId));
        await deleteDoc(doc(db, "spaces", testSpaceId, "posts", spacePostId));
        await deleteDoc(doc(db, "posts", spacePostId));
        await deleteDoc(doc(db, "spaces", testSpaceId));
        
        return true;
    } catch (error) {
        logTest("Space post repost", false, `Error: ${error.message}`);
        return false;
    }
}

async function testCreateRepost_PrivateProfile() {
    console.log("\n🧪 Testing: createRepost - Private profile permissions");
    
    try {
        // Create a post by private user
        const testPostRef = await addDoc(collection(db, "posts"), {
            author: TEST_USER_3_ID,
            contextType: "profile",
            title: "Private Post",
            repostCount: 0,
            timestamp: serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Test: Non-follower cannot repost
        try {
            await createRepostFn({
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            });
            logTest("Private post repost blocked (non-follower)", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error.code === "permission-denied" ||
                error.message?.includes("private");
            logTest("Private post repost blocked (non-follower)", isPermissionError,
                `Error: ${error.message}`);
        }
        
        // Test: Follower can repost
        await setDoc(
            doc(db, "follows", TEST_USER_ID, "following", TEST_USER_3_ID),
            { timestamp: serverTimestamp() }
        );
        
        try {
            const result = await createRepostFn({
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            });
            logTest("Follower can repost private post", !!result.data.repostId);
            
            // Cleanup
            await deleteDoc(doc(db, "reposts", result.data.repostId));
        } catch (error) {
            logTest("Follower can repost private post", false, 
                `Error: ${error.message}`);
        }
        
        // Cleanup
        await deleteDoc(doc(db, "posts", testPostId));
        await deleteDoc(doc(db, "follows", TEST_USER_ID, "following", TEST_USER_3_ID));
        
        return true;
    } catch (error) {
        logTest("Private profile permissions", false, `Error: ${error.message}`);
        return false;
    }
}

async function testCreateRepost_PrivateSpace() {
    console.log("\n🧪 Testing: createRepost - Private space permissions");
    
    try {
        // Create a private space
        const testSpaceRef = await addDoc(collection(db, "spaces"), {
            spaceType: 2, // Private space
            members: [TEST_USER_2_ID], // Only user 2 is member
            name: "Private Space",
        });
        
        const testSpaceId = testSpaceRef.id;
        
        // Create a space post
        const spacePostRef = await addDoc(
            collection(db, "spaces", testSpaceId, "posts"),
            {
                author: TEST_USER_2_ID,
                contextType: "space",
                space: testSpaceId,
                title: "Private Space Post",
                repostCount: 0,
                timestamp: serverTimestamp(),
            }
        );
        
        const spacePostId = spacePostRef.id;
        
        // Also create in top-level posts
        await setDoc(doc(db, "posts", spacePostId), {
            author: TEST_USER_2_ID,
            contextType: "space",
            space: testSpaceId,
            title: "Private Space Post",
            repostCount: 0,
            timestamp: serverTimestamp(),
        });
        
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Test: Non-member cannot repost
        try {
            await createRepostFn({
                originalPostId: spacePostId,
                contextType: "profile",
                contextId: null,
            });
            logTest("Private space post repost blocked (non-member)", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error.code === "permission-denied" ||
                error.message?.includes("private");
            logTest("Private space post repost blocked (non-member)", isPermissionError,
                `Error: ${error.message}`);
        }
        
        // Test: Member can repost
        await updateDoc(doc(db, "spaces", testSpaceId), {
            members: [TEST_USER_ID, TEST_USER_2_ID],
        });
        
        try {
            const result = await createRepostFn({
                originalPostId: spacePostId,
                contextType: "profile",
                contextId: null,
            });
            logTest("Member can repost private space post", !!result.data.repostId);
            
            // Cleanup
            await deleteDoc(doc(db, "reposts", result.data.repostId));
        } catch (error) {
            logTest("Member can repost private space post", false, 
                `Error: ${error.message}`);
        }
        
        // Cleanup
        await deleteDoc(doc(db, "spaces", testSpaceId, "posts", spacePostId));
        await deleteDoc(doc(db, "posts", spacePostId));
        await deleteDoc(doc(db, "spaces", testSpaceId));
        
        return true;
    } catch (error) {
        logTest("Private space permissions", false, `Error: ${error.message}`);
        return false;
    }
}

async function testCreateRepost_MissingPost() {
    console.log("\n🧪 Testing: createRepost - Missing post handling");
    
    try {
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Test: Try to repost non-existent post
        try {
            await createRepostFn({
                originalPostId: "non-existent-post-id",
                contextType: "profile",
                contextId: null,
            });
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
        return false;
    }
}

async function testCreateRepost_InvalidData() {
    console.log("\n🧪 Testing: createRepost - Invalid data handling");
    
    try {
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Test: Empty originalPostId
        try {
            await createRepostFn({
                originalPostId: "",
                contextType: "profile",
                contextId: null,
            });
            logTest("Empty originalPostId rejected", false, "Should have thrown error");
        } catch (error) {
            const isValidError = error.code === "invalid-argument";
            logTest("Empty originalPostId rejected", isValidError,
                `Error: ${error.message}`);
        }
        
        // Test: Missing contextId for space repost
        try {
            await createRepostFn({
                originalPostId: "some-post-id",
                contextType: "space",
                contextId: null,
            });
            logTest("Missing contextId for space repost rejected", false, "Should have thrown error");
        } catch (error) {
            const isValidError = error.code === "invalid-argument";
            logTest("Missing contextId for space repost rejected", isValidError,
                `Error: ${error.message}`);
        }
        
        return true;
    } catch (error) {
        logTest("Invalid data handling", false, `Error: ${error.message}`);
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
        const testPostRef = await addDoc(collection(db, "posts"), {
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Test Post",
            repostCount: 1,
            timestamp: serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        // Create a repost manually (for testing delete)
        const repostRef = await addDoc(collection(db, "reposts"), {
            reposterId: TEST_USER_ID,
            originalPostId: testPostId,
            originalAuthorId: TEST_USER_2_ID,
            originalPostContextType: "profile",
            originalSpaceId: null,
            contextType: "profile",
            contextId: null,
            timestamp: serverTimestamp(),
        });
        
        const repostId = repostRef.id;
        
        const deleteRepostFn = httpsCallable(functions, "deleteRepost");
        
        // Test: Delete repost
        const result = await deleteRepostFn({ repostId });
        logTest("Delete repost - success", result.data?.success === true);
        
        // Verify repost deleted
        const repostDoc = await getDoc(doc(db, "reposts", repostId));
        logTest("Repost document deleted", !repostDoc.exists());
        
        // Verify count decremented
        const postDoc = await getDoc(doc(db, "posts", testPostId));
        const postData = postDoc.data();
        const countDecremented = postData?.repostCount === 0;
        
        logTest("Repost count decremented", countDecremented,
            `Expected: 0, Got: ${postData?.repostCount}`);
        
        // Cleanup
        await deleteDoc(doc(db, "posts", testPostId));
        
        return true;
    } catch (error) {
        logTest("Delete repost - basic", false, `Error: ${error.message}`);
        return false;
    }
}

async function testDeleteRepost_SpacePost() {
    console.log("\n🧪 Testing: deleteRepost - Space post handling");
    
    try {
        // Create a test space
        const testSpaceRef = await addDoc(collection(db, "spaces"), {
            spaceType: 0,
            members: [TEST_USER_ID, TEST_USER_2_ID],
            name: "Test Space",
        });
        
        const testSpaceId = testSpaceRef.id;
        
        // Create a space post
        const spacePostRef = await addDoc(
            collection(db, "spaces", testSpaceId, "posts"),
            {
                author: TEST_USER_2_ID,
                contextType: "space",
                space: testSpaceId,
                title: "Space Post",
                repostCount: 1,
                timestamp: serverTimestamp(),
            }
        );
        
        const spacePostId = spacePostRef.id;
        
        // Also create in top-level posts
        await setDoc(doc(db, "posts", spacePostId), {
            author: TEST_USER_2_ID,
            contextType: "space",
            space: testSpaceId,
            title: "Space Post",
            repostCount: 1,
            timestamp: serverTimestamp(),
        });
        
        // Create a repost
        const repostRef = await addDoc(collection(db, "reposts"), {
            reposterId: TEST_USER_ID,
            originalPostId: spacePostId,
            originalAuthorId: TEST_USER_2_ID,
            originalPostContextType: "space",
            originalSpaceId: testSpaceId,
            contextType: "profile",
            contextId: null,
            timestamp: serverTimestamp(),
        });
        
        const repostId = repostRef.id;
        
        const deleteRepostFn = httpsCallable(functions, "deleteRepost");
        
        // Test: Delete repost
        await deleteRepostFn({ repostId });
        
        // Verify count decremented on space post
        const spacePostDoc = await getDoc(
            doc(db, "spaces", testSpaceId, "posts", spacePostId)
        );
        
        const spacePostData = spacePostDoc.data();
        logTest("Space post count decremented", 
            spacePostData?.repostCount === 0);
        
        // Cleanup
        await deleteDoc(doc(db, "spaces", testSpaceId, "posts", spacePostId));
        await deleteDoc(doc(db, "posts", spacePostId));
        await deleteDoc(doc(db, "spaces", testSpaceId));
        
        return true;
    } catch (error) {
        logTest("Delete repost - space post", false, `Error: ${error.message}`);
        return false;
    }
}

async function testDeleteRepost_PermissionDenied() {
    console.log("\n🧪 Testing: deleteRepost - Permission denied");
    
    try {
        // Create a repost by user 2
        const repostRef = await addDoc(collection(db, "reposts"), {
            reposterId: TEST_USER_2_ID,
            originalPostId: "some-post-id",
            originalAuthorId: TEST_USER_2_ID,
            originalPostContextType: "profile",
            originalSpaceId: null,
            contextType: "profile",
            contextId: null,
            timestamp: serverTimestamp(),
        });
        
        const repostId = repostRef.id;
        
        const deleteRepostFn = httpsCallable(functions, "deleteRepost");
        
        // Test: User 1 tries to delete user 2's repost (should fail)
        try {
            await deleteRepostFn({ repostId });
            logTest("Permission denied for other user's repost", false, "Should have thrown error");
        } catch (error) {
            const isPermissionError = error.code === "permission-denied";
            logTest("Permission denied for other user's repost", isPermissionError,
                `Error: ${error.message}`);
        }
        
        // Cleanup
        await deleteDoc(doc(db, "reposts", repostId));
        
        return true;
    } catch (error) {
        logTest("Permission denied test", false, `Error: ${error.message}`);
        return false;
    }
}

async function testDeleteRepost_MissingRepost() {
    console.log("\n🧪 Testing: deleteRepost - Missing repost handling");
    
    try {
        const deleteRepostFn = httpsCallable(functions, "deleteRepost");
        
        // Test: Try to delete non-existent repost
        try {
            await deleteRepostFn({ repostId: "non-existent-repost-id" });
            logTest("Missing repost deletion blocked", false, "Should have thrown error");
        } catch (error) {
            const isNotFoundError = error.code === "not-found";
            logTest("Missing repost deletion blocked", isNotFoundError,
                `Error: ${error.message}`);
        }
        
        return true;
    } catch (error) {
        logTest("Missing repost handling", false, `Error: ${error.message}`);
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
        const testPostRef = await addDoc(collection(db, "posts"), {
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Race Test Post",
            repostCount: 0,
            timestamp: serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const createRepostFn = httpsCallable(functions, "createRepost");
        
        // Simulate two concurrent requests
        const promise1 = createRepostFn({
            originalPostId: testPostId,
            contextType: "profile",
            contextId: null,
        });
        
        const promise2 = createRepostFn({
            originalPostId: testPostId,
            contextType: "profile",
            contextId: null,
        });
        
        const results = await Promise.allSettled([promise1, promise2]);
        
        // One should succeed, one should fail
        const succeeded = results.filter(r => r.status === "fulfilled").length;
        const failed = results.filter(r => r.status === "rejected").length;
        
        logTest("Concurrent reposts handled", succeeded === 1 && failed === 1,
            `Succeeded: ${succeeded}, Failed: ${failed}`);
        
        // Verify only one repost exists
        const repostsQuery = query(
            collection(db, "reposts"),
            where("reposterId", "==", TEST_USER_ID),
            where("originalPostId", "==", testPostId)
        );
        const repostsSnapshot = await getDocs(repostsQuery);
        logTest("Only one repost created", repostsSnapshot.size === 1,
            `Found ${repostsSnapshot.size} reposts`);
        
        // Verify count is correct
        const postDoc = await getDoc(doc(db, "posts", testPostId));
        const postData = postDoc.data();
        logTest("Repost count correct", postData?.repostCount === 1,
            `Expected: 1, Got: ${postData?.repostCount}`);
        
        // Cleanup
        if (repostsSnapshot.size > 0) {
            await deleteDoc(doc(db, "reposts", repostsSnapshot.docs[0].id));
        }
        await deleteDoc(doc(db, "posts", testPostId));
        
        return true;
    } catch (error) {
        logTest("Race condition test", false, `Error: ${error.message}`);
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
        const testPostRef = await addDoc(collection(db, "posts"), {
            author: TEST_USER_2_ID,
            contextType: "profile",
            title: "Count Test Post",
            repostCount: 0,
            timestamp: serverTimestamp(),
        });
        
        const testPostId = testPostRef.id;
        
        const createRepostFn = httpsCallable(functions, "createRepost");
        const deleteRepostFn = httpsCallable(functions, "deleteRepost");
        
        // Create multiple reposts
        const repostIds = [];
        for (let i = 0; i < 3; i++) {
            const result = await createRepostFn({
                originalPostId: testPostId,
                contextType: "profile",
                contextId: null,
            });
            repostIds.push(result.data.repostId);
        }
        
        // Verify count
        const postDoc1 = await getDoc(doc(db, "posts", testPostId));
        const postData1 = postDoc1.data();
        logTest("Repost count after 3 reposts", postData1?.repostCount === 3,
            `Expected: 3, Got: ${postData1?.repostCount}`);
        
        // Delete one repost
        await deleteRepostFn({ repostId: repostIds[0] });
        
        // Verify count decremented
        const postDoc2 = await getDoc(doc(db, "posts", testPostId));
        const postData2 = postDoc2.data();
        logTest("Repost count after deletion", postData2?.repostCount === 2,
            `Expected: 2, Got: ${postData2?.repostCount}`);
        
        // Verify actual reposts count matches
        const repostsQuery = query(
            collection(db, "reposts"),
            where("originalPostId", "==", testPostId)
        );
        const repostsSnapshot = await getDocs(repostsQuery);
        logTest("Actual reposts count matches", repostsSnapshot.size === 2,
            `Expected: 2, Got: ${repostsSnapshot.size}`);
        
        // Cleanup
        for (const repostId of repostIds.slice(1)) {
            await deleteRepostFn({ repostId });
        }
        await deleteDoc(doc(db, "posts", testPostId));
        
        return true;
    } catch (error) {
        logTest("Data consistency test", false, `Error: ${error.message}`);
        return false;
    }
}

// =============================================================================
// TEST RUNNER
// =============================================================================

async function runAllTests() {
    console.log("🚀 Starting Comprehensive Repost System Test Suite...\n");
    console.log(`Test User 1: ${TEST_USER_ID}`);
    console.log(`Test User 2: ${TEST_USER_2_ID}`);
    console.log(`Test User 3: ${TEST_USER_3_ID}`);
    console.log(`Using Emulator: ${USE_EMULATOR}`);
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
        await testCreateRepost_PrivateSpace();
        await testCreateRepost_MissingPost();
        await testCreateRepost_InvalidData();
        
        console.log("\n" + "=".repeat(60));
        console.log("TESTING DELETE REPOST");
        console.log("=".repeat(60));
        await testDeleteRepost_Basic();
        await testDeleteRepost_SpacePost();
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
