/**
 * Script to completely delete user accounts and all their data
 * This simulates what happens when a user deletes their account from the app
 * 
 * Usage: node tests/delete_users.js
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
    readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8")
);

initializeApp({
    credential: cert(serviceAccount),
    storageBucket: "ty-dev-516d7.appspot.com",
});

const db = getFirestore();
const auth = getAuth();
const storage = getStorage();

// Users to delete - specified by name (case insensitive search)
const USERS_TO_DELETE = ["anjuswami", "abhinav", "anju"];

/**
 * Find users by name (partial match, case insensitive)
 */
async function findUsersByName(names) {
    console.log("\n🔍 Searching for users...\n");
    
    const usersSnapshot = await db.collection("users").get();
    const foundUsers = [];
    
    for (const doc of usersSnapshot.docs) {
        const data = doc.data();
        const userName = (data.name || "").toLowerCase();
        
        for (const searchName of names) {
            if (userName.includes(searchName.toLowerCase())) {
                foundUsers.push({
                    uid: doc.id,
                    name: data.name,
                    phoneNumber: data.phoneNumber,
                    email: data.email,
                });
                console.log(`  ✅ Found: "${data.name}" (${doc.id})`);
                if (data.phoneNumber) console.log(`     Phone: ${data.phoneNumber}`);
                break;
            }
        }
    }
    
    return foundUsers;
}

/**
 * Delete all documents in a subcollection
 */
async function deleteSubcollection(parentRef, subcollectionName) {
    const subcollectionRef = parentRef.collection(subcollectionName);
    const docs = await subcollectionRef.get();
    
    if (docs.empty) return 0;
    
    const batch = db.batch();
    docs.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    
    return docs.size;
}

/**
 * Delete user's posts and remove from feeds
 */
async function deleteUserPosts(userId) {
    console.log("  📝 Deleting user posts...");
    let count = 0;
    
    // Delete from posts collection
    const postsSnapshot = await db.collection("posts")
        .where("author", "==", userId)
        .get();
    
    for (const doc of postsSnapshot.docs) {
        const postId = doc.id;
        
        // Delete from globalFeed
        await db.collection("globalFeed").doc(postId).delete().catch(() => {});
        
        // Delete from spacePosts (need to find which space)
        const postData = doc.data();
        if (postData.space) {
            await db.collection("spacePosts").doc(postData.space)
                .collection("posts").doc(postId).delete().catch(() => {});
        }
        
        // Delete the post itself
        await doc.ref.delete();
        count++;
    }
    
    console.log(`     Deleted ${count} posts`);
    return count;
}

/**
 * Remove user from all spaces they belong to
 */
async function removeUserFromSpaces(userId) {
    console.log("  🏠 Removing from spaces...");
    let count = 0;
    
    // Get user's spaces
    const userSpacesSnapshot = await db.collection("userSpaces").doc(userId)
        .collection("spaces").get();
    
    for (const spaceDoc of userSpacesSnapshot.docs) {
        const spaceId = spaceDoc.id;
        
        // Remove from spaceRoles
        await db.collection("spaceRoles").doc(spaceId)
            .collection("roles").doc(userId).delete().catch(() => {});
        
        // Update space member count if exists
        const spaceRef = db.collection("spaces").doc(spaceId);
        const space = await spaceRef.get();
        if (space.exists) {
            const spaceData = space.data();
            if (spaceData.members && Array.isArray(spaceData.members)) {
                await spaceRef.update({
                    members: FieldValue.arrayRemove(userId),
                    memberCount: FieldValue.increment(-1),
                }).catch(() => {});
            }
        }
        
        count++;
    }
    
    // Delete userSpaces document
    await deleteSubcollection(db.collection("userSpaces").doc(userId), "spaces");
    await db.collection("userSpaces").doc(userId).delete().catch(() => {});
    
    console.log(`     Removed from ${count} spaces`);
    return count;
}

/**
 * Delete user's Firestore data
 */
async function deleteUserFirestoreData(userId) {
    console.log("  🗄️ Deleting Firestore data...");
    
    // User document subcollections
    const userRef = db.collection("users").doc(userId);
    const subcollections = [
        "dailyInsights",
        "favoriteInsights", 
        "insightFeedback",
        "predictions",
        "auraHistory",
        "auraTracking",
        "blocked",
    ];
    
    for (const subcol of subcollections) {
        const count = await deleteSubcollection(userRef, subcol);
        if (count > 0) console.log(`     Deleted ${count} docs from ${subcol}`);
    }
    
    // Delete main user document
    await userRef.delete().catch(() => {});
    console.log("     Deleted user document");
    
    // Delete notifications
    const notifSubCount = await deleteSubcollection(
        db.collection("notifications").doc(userId), 
        "notifications"
    );
    await db.collection("notifications").doc(userId).delete().catch(() => {});
    if (notifSubCount > 0) console.log(`     Deleted ${notifSubCount} notifications`);
    
    // Delete userItems
    await db.collection("userItems").doc(userId).delete().catch(() => {});
    
    // Delete userFeed
    const feedCount = await deleteSubcollection(
        db.collection("userFeed").doc(userId),
        "posts"
    );
    await db.collection("userFeed").doc(userId).delete().catch(() => {});
    if (feedCount > 0) console.log(`     Deleted ${feedCount} feed items`);
    
    // Delete userContacts
    await db.collection("userContacts").doc(userId).delete().catch(() => {});
    
    // Delete phoneIndex entries for this user
    const phoneIndexDocs = await db.collection("phoneIndex")
        .where("userId", "==", userId)
        .get();
    for (const doc of phoneIndexDocs.docs) {
        await doc.ref.delete();
    }
    if (!phoneIndexDocs.empty) console.log(`     Deleted ${phoneIndexDocs.size} phoneIndex entries`);
    
    // Delete compatibility scores involving this user
    const compatDocs1 = await db.collection("compatibilityScores")
        .where("user1Id", "==", userId)
        .get();
    const compatDocs2 = await db.collection("compatibilityScores")
        .where("user2Id", "==", userId)
        .get();
    for (const doc of [...compatDocs1.docs, ...compatDocs2.docs]) {
        await doc.ref.delete();
    }
    if (compatDocs1.size + compatDocs2.size > 0) {
        console.log(`     Deleted ${compatDocs1.size + compatDocs2.size} compatibility scores`);
    }
    
    // Remove from globalFeed (posts authored by this user)
    const globalFeedDocs = await db.collection("globalFeed")
        .where("author", "==", userId)
        .get();
    for (const doc of globalFeedDocs.docs) {
        await doc.ref.delete();
    }
    if (!globalFeedDocs.empty) console.log(`     Deleted ${globalFeedDocs.size} globalFeed entries`);
}

/**
 * Clean up DM conversations involving this user
 */
async function cleanupDMConversations(userId) {
    console.log("  💬 Cleaning DM conversations...");
    let count = 0;
    
    // Find all DM conversations where user is a participant
    const dmSnapshot = await db.collection("dmConversations").get();
    
    for (const doc of dmSnapshot.docs) {
        const data = doc.data();
        const participants = data.participants || [];
        
        if (participants.includes(userId)) {
            // If only 2 participants, delete the conversation
            if (participants.length <= 2) {
                // Delete messages subcollection
                await deleteSubcollection(doc.ref, "messages");
                await doc.ref.delete();
            } else {
                // Remove user from participants
                await doc.ref.update({
                    participants: FieldValue.arrayRemove(userId),
                });
            }
            count++;
        }
    }
    
    if (count > 0) console.log(`     Cleaned ${count} DM conversations`);
}

/**
 * Clean up chat messages in spaces
 */
async function cleanupSpaceChatMessages(userId) {
    console.log("  💭 Cleaning space chat messages...");
    // Note: Messages are typically kept but anonymized, or can be deleted
    // For complete deletion, we'll mark them as deleted
    let count = 0;
    
    const spacesSnapshot = await db.collection("spaces").get();
    
    for (const spaceDoc of spacesSnapshot.docs) {
        const messagesRef = spaceDoc.ref.collection("messages");
        const userMessages = await messagesRef
            .where("sender", "==", userId)
            .get();
        
        for (const msgDoc of userMessages.docs) {
            // Option 1: Delete message entirely
            await msgDoc.ref.delete();
            // Option 2: Anonymize (uncomment if preferred)
            // await msgDoc.ref.update({
            //     sender: "deleted_user",
            //     text: "[Message deleted]",
            // });
            count++;
        }
    }
    
    if (count > 0) console.log(`     Deleted ${count} chat messages`);
}

/**
 * Remove user's nickname from nickname collection
 */
async function cleanupNickname(userId) {
    console.log("  🏷️ Cleaning nickname...");
    
    try {
        const nicknameDoc = await db.collection("nickname").doc("pairs").get();
        if (nicknameDoc.exists) {
            const nicknamePairs = nicknameDoc.data();
            let userNickname = null;
            
            for (const [key, value] of Object.entries(nicknamePairs)) {
                if (value && typeof value === 'object' && value.uid === userId) {
                    userNickname = key;
                    break;
                }
            }
            
            if (userNickname) {
                await db.collection("nickname").doc("pairs").update({
                    [userNickname]: FieldValue.delete(),
                });
                console.log(`     Removed nickname: ${userNickname}`);
            }
        }
    } catch (e) {
        // Nickname collection might not exist
    }
}

/**
 * Delete user's storage data
 */
async function deleteUserStorage(userId) {
    console.log("  📦 Deleting storage data...");
    
    const bucket = storage.bucket();
    const prefixes = [
        `users/${userId}/`,
        `avatars/${userId}/`,
    ];
    
    for (const prefix of prefixes) {
        try {
            const [files] = await bucket.getFiles({ prefix });
            for (const file of files) {
                await file.delete().catch(() => {});
            }
            if (files.length > 0) console.log(`     Deleted ${files.length} files from ${prefix}`);
        } catch (e) {
            // Storage might not have files for this user
        }
    }
    
    // Also delete post media authored by this user
    try {
        const [postFiles] = await bucket.getFiles({ prefix: `posts/` });
        const userPostFiles = postFiles.filter(f => f.name.includes(userId));
        for (const file of userPostFiles) {
            await file.delete().catch(() => {});
        }
        if (userPostFiles.length > 0) console.log(`     Deleted ${userPostFiles.length} post files`);
    } catch (e) {
        // Ignore storage errors
    }
}

/**
 * Delete Firebase Auth user
 */
async function deleteAuthUser(userId) {
    console.log("  🔐 Deleting Firebase Auth user...");
    
    try {
        await auth.deleteUser(userId);
        console.log("     Auth user deleted");
        return true;
    } catch (e) {
        if (e.code === "auth/user-not-found") {
            console.log("     Auth user not found (already deleted)");
            return true;
        }
        console.log(`     ⚠️ Error deleting auth user: ${e.message}`);
        return false;
    }
}

/**
 * Store deleted user reference (for compliance/auditing)
 */
async function storeDeletedUserReference(userId, userData) {
    await db.collection("deletedUsers").doc(userId).set({
        name: userData.name || null,
        phoneNumber: userData.phoneNumber || null,
        deletedAt: FieldValue.serverTimestamp(),
        deletedBy: "admin_script",
    });
    console.log("     Added to deletedUsers collection");
}

/**
 * Main deletion function for a single user
 */
async function deleteUser(user) {
    console.log(`\n${"=".repeat(60)}`);
    console.log(`🗑️ DELETING USER: ${user.name} (${user.uid})`);
    console.log("=".repeat(60));
    
    try {
        // Delete all user data
        await deleteUserPosts(user.uid);
        await removeUserFromSpaces(user.uid);
        await cleanupDMConversations(user.uid);
        await cleanupSpaceChatMessages(user.uid);
        await deleteUserFirestoreData(user.uid);
        await cleanupNickname(user.uid);
        await deleteUserStorage(user.uid);
        
        // Store reference before deleting auth
        await storeDeletedUserReference(user.uid, user);
        
        // Delete Firebase Auth user (this will force logout)
        await deleteAuthUser(user.uid);
        
        console.log(`\n✅ Successfully deleted user: ${user.name}`);
        return true;
    } catch (error) {
        console.error(`\n❌ Error deleting user ${user.name}:`, error);
        return false;
    }
}

/**
 * Main execution
 */
async function main() {
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║          USER ACCOUNT DELETION SCRIPT                       ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log(`\nTarget users: ${USERS_TO_DELETE.join(", ")}`);
    
    // Find users
    const foundUsers = await findUsersByName(USERS_TO_DELETE);
    
    if (foundUsers.length === 0) {
        console.log("\n❌ No users found matching the specified names.");
        console.log("   Please check the user names and try again.");
        process.exit(1);
    }
    
    console.log(`\n📋 Found ${foundUsers.length} user(s) to delete:`);
    foundUsers.forEach((u, i) => {
        console.log(`   ${i + 1}. ${u.name} (${u.uid})`);
    });
    
    // Confirmation prompt
    console.log("\n⚠️  WARNING: This action is IRREVERSIBLE!");
    console.log("   All user data will be permanently deleted.");
    console.log("\n   Proceeding with deletion in 5 seconds...");
    console.log("   Press Ctrl+C to cancel.\n");
    
    // Wait 5 seconds before proceeding
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Delete each user
    let successCount = 0;
    for (const user of foundUsers) {
        const success = await deleteUser(user);
        if (success) successCount++;
    }
    
    // Summary
    console.log("\n" + "═".repeat(60));
    console.log("📊 DELETION SUMMARY");
    console.log("═".repeat(60));
    console.log(`   Total users processed: ${foundUsers.length}`);
    console.log(`   Successfully deleted:  ${successCount}`);
    console.log(`   Failed:                ${foundUsers.length - successCount}`);
    
    if (successCount === foundUsers.length) {
        console.log("\n✅ All users deleted successfully!");
    } else {
        console.log("\n⚠️ Some users could not be deleted. Check logs above.");
    }
}

main()
    .then(() => {
        console.log("\n🏁 Script completed.");
        process.exit(0);
    })
    .catch((error) => {
        console.error("\n💥 Script failed:", error);
        process.exit(1);
    });

