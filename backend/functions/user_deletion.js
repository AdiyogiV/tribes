/**
 * User Account Deletion Handler
 * 
 * Triggered when a Firebase Auth user is deleted.
 * Performs complete cleanup of ALL user data across the system.
 * 
 * This is the SERVER-SIDE implementation that handles:
 * - User document + all subcollections
 * - Posts and media
 * - Follow relationships (both directions)
 * - Space memberships
 * - DM conversations
 * - Indices (phone, nickname)
 * - Storage files
 * - Audit logging
 */

import * as functionsV1 from "firebase-functions/v1";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { getStorage } from "firebase-admin/storage";
import { storageBucketName } from "../lib/secrets.js";

/**
 * Main deletion handler - triggered by Firebase Auth user deletion
 * 
 * When frontend calls FirebaseAuth.user.delete(), this function is
 * automatically triggered to clean up all associated data.
 * 
 * Note: Using v1 auth trigger as v2 doesn't support auth events yet.
 * Runtime options: 5 minutes timeout, 512MB memory for comprehensive cleanup.
 */
export const onUserDeleted = functionsV1
    .runWith({
        timeoutSeconds: 300,  // 5 minutes for comprehensive cleanup
        memory: "512MB",
    })
    .auth.user()
    .onDelete(async (user) => {
    const userId = user.uid;
    const startTime = Date.now();
    
    logger.info(`🗑️ [DELETE] Starting account deletion for user: ${userId}`);
    
    const results = {
        userId,
        phoneNumber: user.phoneNumber || null,
        email: user.email || null,
        startedAt: new Date().toISOString(),
        phases: {},
        errors: [],
        summary: {},
    };
    
    try {
        // PHASE 1: Delete user-owned data (docs + subcollections)
        logger.info(`[DELETE] Phase 1: Deleting user-owned data...`);
        results.phases.userOwnedData = await deleteUserOwnedData(userId);
        
        // PHASE 2: Delete user's posts and media
        logger.info(`[DELETE] Phase 2: Deleting user posts...`);
        results.phases.posts = await deleteUserPosts(userId);
        
        // PHASE 3: Clean cross-user references (follows, spaces, DMs)
        logger.info(`[DELETE] Phase 3: Cleaning cross-user references...`);
        results.phases.crossUserRefs = await cleanCrossUserReferences(userId);
        
        // PHASE 4: Clean indices and system data
        logger.info(`[DELETE] Phase 4: Cleaning indices...`);
        results.phases.indices = await cleanIndicesAndSystemData(userId, user.phoneNumber);
        
        // PHASE 5: Clean storage files
        logger.info(`[DELETE] Phase 5: Cleaning storage...`);
        results.phases.storage = await cleanStorage(userId);
        
        // Calculate summary
        results.completedAt = new Date().toISOString();
        results.durationMs = Date.now() - startTime;
        results.summary = calculateSummary(results.phases);
        
        // Update audit record with success
        await updateAuditRecord(userId, results, "completed");
        
        logger.info(`✅ [DELETE] Account deletion complete for ${userId}`, {
            durationMs: results.durationMs,
            summary: results.summary,
        });
        
    } catch (error) {
        logger.error(`❌ [DELETE] Account deletion failed for ${userId}:`, error);
        results.errors.push({
            phase: "global",
            message: error.message,
            stack: error.stack,
        });
        results.completedAt = new Date().toISOString();
        results.durationMs = Date.now() - startTime;
        
        // Update audit record with failure
        await updateAuditRecord(userId, results, "failed");
        
        // Don't rethrow - we've logged the error and updated audit
        // Rethrowing would cause infinite retries for permanent failures
    }
});

// =============================================================================
// PHASE 1: Delete user-owned documents and their subcollections
// =============================================================================

async function deleteUserOwnedData(userId) {
    const results = { deleted: [], errors: [] };
    
    // 1. User document subcollections (must delete before parent)
    const userSubcollections = [
        "dailyInsights",
        "favoriteInsights", 
        "insightFeedback",
        "astrology",
        "auraTracking",
        "auraHistory",
        "predictions",
    ];
    
    for (const subcol of userSubcollections) {
        try {
            const count = await deleteCollection(`users/${userId}/${subcol}`);
            if (count > 0) {
                results.deleted.push({ collection: `users/${userId}/${subcol}`, count });
            }
        } catch (e) {
            results.errors.push({ collection: `users/${userId}/${subcol}`, error: e.message });
        }
    }
    
    // 2. Delete user document itself
    try {
        await db.collection("users").doc(userId).delete();
        results.deleted.push({ collection: "users", count: 1 });
    } catch (e) {
        results.errors.push({ collection: "users", error: e.message });
    }
    
    // 3. Blocks collection (subcollection + parent)
    try {
        const blockedCount = await deleteCollection(`blocks/${userId}/blocked`);
        await db.collection("blocks").doc(userId).delete();
        results.deleted.push({ collection: "blocks", count: blockedCount + 1 });
    } catch (e) {
        results.errors.push({ collection: "blocks", error: e.message });
    }
    
    // 4. Notifications collection (subcollection + parent)
    try {
        const notifCount = await deleteCollection(`notifications/${userId}/notifications`);
        await db.collection("notifications").doc(userId).delete();
        results.deleted.push({ collection: "notifications", count: notifCount + 1 });
    } catch (e) {
        results.errors.push({ collection: "notifications", error: e.message });
    }
    
    // 5. UserItems
    try {
        await db.collection("userItems").doc(userId).delete();
        results.deleted.push({ collection: "userItems", count: 1 });
    } catch (e) {
        results.errors.push({ collection: "userItems", error: e.message });
    }
    
    // 6. UserSpaces (subcollection + parent)
    try {
        const spacesCount = await deleteCollection(`userSpaces/${userId}/spaces`);
        await db.collection("userSpaces").doc(userId).delete();
        results.deleted.push({ collection: "userSpaces", count: spacesCount + 1 });
    } catch (e) {
        results.errors.push({ collection: "userSpaces", error: e.message });
    }
    
    // 7. UserFeed (subcollection + parent)
    try {
        const feedCount = await deleteCollection(`userFeed/${userId}/posts`);
        await db.collection("userFeed").doc(userId).delete();
        results.deleted.push({ collection: "userFeed", count: feedCount + 1 });
    } catch (e) {
        results.errors.push({ collection: "userFeed", error: e.message });
    }
    
    // 8. UserContacts (if exists)
    try {
        await db.collection("userContacts").doc(userId).delete();
        results.deleted.push({ collection: "userContacts", count: 1 });
    } catch (e) {
        // Ignore - might not exist
    }
    
    // 9. UserReplies (subcollection + parent)
    try {
        const repliesCount = await deleteCollection(`userReplies/${userId}/replies`);
        if (repliesCount > 0) {
            await db.collection("userReplies").doc(userId).delete();
            results.deleted.push({ collection: "userReplies", count: repliesCount + 1 });
        }
    } catch (e) {
        // Ignore - might not exist
    }
    
    return results;
}

// =============================================================================
// PHASE 2: Delete user's posts and associated media
// =============================================================================

async function deleteUserPosts(userId) {
    const results = { postsDeleted: 0, repliesDeleted: 0, feedEntriesDeleted: 0, repostsDeleted: 0, errors: [] };
    
    try {
        // Get all posts by this user
        const postsSnapshot = await db.collection("posts")
            .where("author", "==", userId)
            .get();
        
        for (const postDoc of postsSnapshot.docs) {
            const postId = postDoc.id;
            const postData = postDoc.data();
            
            try {
                const batch = db.batch();
                
                // Delete from spacePosts
                if (postData.space) {
                    batch.delete(
                        db.collection("spacePosts")
                            .doc(postData.space)
                            .collection("posts")
                            .doc(postId)
                    );
                }
                
                // Delete from globalFeed
                batch.delete(db.collection("globalFeed").doc(postId));
                
                // Delete post replies subcollection
                const repliesSnapshot = await db.collection("postReplies")
                    .doc(postId)
                    .collection("replies")
                    .get();
                
                for (const replyDoc of repliesSnapshot.docs) {
                    batch.delete(replyDoc.ref);
                    results.repliesDeleted++;
                }
                
                // Delete postReplies parent doc
                batch.delete(db.collection("postReplies").doc(postId));
                
                // Delete the post document itself
                batch.delete(postDoc.ref);
                
                await batch.commit();
                results.postsDeleted++;
                
                // Delete storage files for this post (outside batch)
                await deletePostStorage(postId);
                
            } catch (e) {
                results.errors.push({ postId, error: e.message });
            }
        }
        
        // Delete all reposts created by this user
        try {
            const BATCH_SIZE = 500;
            let lastDoc = null;
            let totalRepostsDeleted = 0;
            
            while (true) {
                let query = db.collection("reposts")
                    .where("reposterId", "==", userId)
                    .limit(BATCH_SIZE);
                
                if (lastDoc) {
                    query = query.startAfter(lastDoc);
                }
                
                const repostsSnapshot = await query.get();
                
                if (repostsSnapshot.empty) {
                    break;
                }
                
                // First, collect repost data and delete reposts
                const repostsToProcess = [];
                const deleteBatch = db.batch();
                
                for (const repostDoc of repostsSnapshot.docs) {
                    const repostData = repostDoc.data();
                    repostsToProcess.push({
                        originalPostId: repostData.originalPostId,
                        originalPostContextType: repostData.originalPostContextType || "profile",
                        originalSpaceId: repostData.originalSpaceId || null,
                    });
                    
                    // Delete the repost
                    deleteBatch.delete(repostDoc.ref);
                    totalRepostsDeleted++;
                }
                
                await deleteBatch.commit();
                
                // Now update original posts and globalFeed (separate from delete batch)
                // First, fetch all globalFeed docs we need to update
                const globalFeedRefs = repostsToProcess.map(r => 
                    db.collection("globalFeed").doc(r.originalPostId)
                );
                const globalFeedDocs = await Promise.all(
                    globalFeedRefs.map(ref => ref.get())
                );
                
                const updateBatch = db.batch();
                let updateCount = 0;
                
                for (let i = 0; i < repostsToProcess.length; i++) {
                    const repostInfo = repostsToProcess[i];
                    const { originalPostId, originalPostContextType, originalSpaceId } = repostInfo;
                    const globalFeedDoc = globalFeedDocs[i];
                    
                    // Remove from globalFeed repostedBy array
                    if (globalFeedDoc.exists) {
                        const feedData = globalFeedDoc.data();
                        const repostedBy = (feedData.repostedBy || []).filter(id => id !== userId);
                        
                        if (repostedBy.length === 0 && feedData.repostedBy && feedData.repostedBy.length > 0) {
                            // If this was the only reposter, remove repostedBy field entirely
                            updateBatch.update(globalFeedDoc.ref, {
                                repostedBy: FieldValue.delete(),
                                repostCount: FieldValue.increment(-1),
                            });
                            updateCount++;
                        } else if (repostedBy.length < (feedData.repostedBy || []).length) {
                            // Update repostedBy array
                            updateBatch.update(globalFeedDoc.ref, {
                                repostedBy: repostedBy,
                                repostCount: FieldValue.increment(-1),
                            });
                            updateCount++;
                        }
                    }
                    
                    // Decrement repost count on original post (if it still exists)
                    let originalPostRef;
                    if (originalPostContextType === "profile") {
                        originalPostRef = db.collection("posts").doc(originalPostId);
                    } else if (originalSpaceId) {
                        originalPostRef = db.collection("spaces")
                            .doc(originalSpaceId)
                            .collection("posts")
                            .doc(originalPostId);
                    } else {
                        // Fallback to top-level posts
                        originalPostRef = db.collection("posts").doc(originalPostId);
                    }
                    
                    // Decrement repost count (will fail silently if post doesn't exist)
                    updateBatch.update(originalPostRef, {
                        repostCount: FieldValue.increment(-1),
                    });
                    updateCount++;
                    
                    // Commit batch if we're approaching Firestore limit (500 operations)
                    if (updateCount >= 450) {
                        await updateBatch.commit().catch((e) => {
                            // Some updates might fail if original posts are deleted - that's okay
                            logger.warn(`Some repost updates failed: ${e.message}`);
                        });
                        updateCount = 0;
                    }
                }
                
                // Commit remaining updates
                if (updateCount > 0) {
                    await updateBatch.commit().catch((e) => {
                        logger.warn(`Some repost updates failed: ${e.message}`);
                    });
                }
                
                results.repostsDeleted += totalRepostsDeleted;
                
                if (repostsSnapshot.size < BATCH_SIZE) {
                    break;
                }
                
                lastDoc = repostsSnapshot.docs[repostsSnapshot.docs.length - 1];
            }
            
            if (totalRepostsDeleted > 0) {
                logger.info(`[DELETE] Deleted ${totalRepostsDeleted} reposts by user ${userId}`);
            }
        } catch (e) {
            results.errors.push({ collection: "reposts", error: e.message });
        }
        
        // Also delete any entries in globalFeed that might have been missed
        try {
            const globalFeedSnapshot = await db.collection("globalFeed")
                .where("author", "==", userId)
                .get();
            
            const batch = db.batch();
            for (const doc of globalFeedSnapshot.docs) {
                batch.delete(doc.ref);
                results.feedEntriesDeleted++;
            }
            if (!globalFeedSnapshot.empty) {
                await batch.commit();
            }
        } catch (e) {
            results.errors.push({ collection: "globalFeed", error: e.message });
        }
        
    } catch (e) {
        results.errors.push({ phase: "posts", error: e.message });
    }
    
    return results;
}

async function deletePostStorage(postId) {
    const storage = getStorage();
    const bucket = storage.bucket(storageBucketName.value());
    
    const filesToDelete = [
        `posts/${postId}/thumbnail.jpg`,
        `posts/${postId}/video.mp4`,
        `posts/${postId}/audio.m4a`,
        `posts/${postId}/audio.wav`,
    ];
    
    for (const filePath of filesToDelete) {
        try {
            await bucket.file(filePath).delete();
        } catch (e) {
            // File might not exist - ignore
        }
    }
}

// =============================================================================
// PHASE 3: Clean cross-user references (follows, spaces, DMs)
// =============================================================================

async function cleanCrossUserReferences(userId) {
    const results = { 
        followingCleaned: 0, 
        followersCleaned: 0, 
        spaceRolesCleaned: 0,
        dmConversationsCleaned: 0,
        spaceChatMessagesCleaned: 0,
        errors: [] 
    };
    
    // 1. Clean following relationships
    // Get everyone this user follows, remove user from their followers list
    try {
        const followingSnapshot = await db.collection("userFollowing")
            .doc(userId)
            .collection("following")
            .get();
        
        for (const doc of followingSnapshot.docs) {
            const targetUserId = doc.id;
            try {
                // Remove from target's followers list
                await db.collection("userFollowers")
                    .doc(targetUserId)
                    .collection("followers")
                    .doc(userId)
                    .delete();
                
                // Decrement their follower count
                await db.collection("users").doc(targetUserId).update({
                    followerCount: FieldValue.increment(-1),
                }).catch(() => {}); // User might be deleted too
                
                results.followingCleaned++;
            } catch (e) {
                results.errors.push({ type: "following", target: targetUserId, error: e.message });
            }
        }
        
        // Delete user's following collection
        await deleteCollection(`userFollowing/${userId}/following`);
        await db.collection("userFollowing").doc(userId).delete();
        
    } catch (e) {
        results.errors.push({ type: "following", error: e.message });
    }
    
    // 2. Clean follower relationships
    // Get everyone who follows this user, remove this user from their following list
    try {
        const followersSnapshot = await db.collection("userFollowers")
            .doc(userId)
            .collection("followers")
            .get();
        
        for (const doc of followersSnapshot.docs) {
            const followerId = doc.id;
            try {
                // Remove from follower's following list
                await db.collection("userFollowing")
                    .doc(followerId)
                    .collection("following")
                    .doc(userId)
                    .delete();
                
                // Decrement their following count
                await db.collection("users").doc(followerId).update({
                    followingCount: FieldValue.increment(-1),
                }).catch(() => {}); // User might be deleted too
                
                results.followersCleaned++;
            } catch (e) {
                results.errors.push({ type: "followers", follower: followerId, error: e.message });
            }
        }
        
        // Delete user's followers collection
        await deleteCollection(`userFollowers/${userId}/followers`);
        await db.collection("userFollowers").doc(userId).delete();
        
    } catch (e) {
        results.errors.push({ type: "followers", error: e.message });
    }
    
    // 3. Clean space roles (remove user from all spaces)
    // Use userSpaces collection (already queried above) to find all spaces the user is in
    try {
        const userSpacesSnapshot = await db.collection("userSpaces")
            .doc(userId)
            .collection("spaces")
            .get();
        
        for (const spaceDoc of userSpacesSnapshot.docs) {
            const spaceId = spaceDoc.id;
            try {
                // Delete the role document from spaceRoles/{spaceId}/roles/{userId}
                await db.collection("spaceRoles")
                    .doc(spaceId)
                    .collection("roles")
                    .doc(userId)
                    .delete();
                
                // Update space member count if the space still exists
                await db.collection("spaces").doc(spaceId).update({
                    memberCount: FieldValue.increment(-1),
                }).catch(() => {}); // Space might be deleted
                
                results.spaceRolesCleaned++;
            } catch (e) {
                results.errors.push({ type: "spaceRole", spaceId, error: e.message });
            }
        }
    } catch (e) {
        results.errors.push({ type: "spaceRoles", error: e.message });
    }
    
    // 4. Clean DM conversations
    try {
        const dmSnapshot = await db.collection("dmConversations")
            .where("participants", "array-contains", userId)
            .get();
        
        for (const dmDoc of dmSnapshot.docs) {
            try {
                const dmData = dmDoc.data();
                const participants = dmData.participants || [];
                
                if (participants.length <= 2) {
                    // Only 2 participants - delete entire conversation
                    await deleteCollection(`dmConversations/${dmDoc.id}/messages`);
                    await dmDoc.ref.delete();
                } else {
                    // More than 2 participants - just remove this user
                    await dmDoc.ref.update({
                        participants: FieldValue.arrayRemove(userId),
                    });
                }
                results.dmConversationsCleaned++;
            } catch (e) {
                results.errors.push({ type: "dmConversation", id: dmDoc.id, error: e.message });
            }
        }
    } catch (e) {
        results.errors.push({ type: "dmConversations", error: e.message });
    }
    
    // 5. Clean space chat messages
    // OPTIMIZED: Query spaceChats collection directly instead of iterating all spaces
    // spaceChats stores all messages with senderId field - much faster than O(spaces) iteration
    try {
        // Delete in batches to handle large message counts
        const BATCH_SIZE = 500;
        let totalDeleted = 0;
        let hasMore = true;
        
        while (hasMore) {
            const messagesSnapshot = await db.collection("spaceChats")
                .where("senderId", "==", userId)
                .limit(BATCH_SIZE)
                .get();
            
            if (messagesSnapshot.empty) {
                hasMore = false;
                break;
            }
            
            const batch = db.batch();
            messagesSnapshot.docs.forEach((doc) => {
                batch.delete(doc.ref);
            });
            await batch.commit();
            
            totalDeleted += messagesSnapshot.size;
            results.spaceChatMessagesCleaned += messagesSnapshot.size;
            
            // If we got less than batch size, we're done
            if (messagesSnapshot.size < BATCH_SIZE) {
                hasMore = false;
            }
        }
        
        if (totalDeleted > 0) {
            logger.info("[DELETE] Cleaned user's space chat messages", {
                structuredData: true,
                userId,
                messagesDeleted: totalDeleted,
            });
        }
    } catch (e) {
        results.errors.push({ type: "spaceChatMessages", error: e.message });
    }
    
    return results;
}

// =============================================================================
// PHASE 4: Clean indices and system data
// =============================================================================

async function cleanIndicesAndSystemData(userId, phoneNumber) {
    const results = { cleaned: [], errors: [] };
    
    // 1. Delete phoneIndex entry
    if (phoneNumber) {
        try {
            const phoneIndexSnapshot = await db.collection("phoneIndex")
                .where("userId", "==", userId)
                .get();
            
            for (const doc of phoneIndexSnapshot.docs) {
                await doc.ref.delete();
                results.cleaned.push({ collection: "phoneIndex", docId: doc.id });
            }
        } catch (e) {
            results.errors.push({ collection: "phoneIndex", error: e.message });
        }
    }
    
    // 2. Remove nickname from nicknames/pairs
    try {
        const nicknameDoc = await db.collection("nicknames").doc("pairs").get();
        if (nicknameDoc.exists) {
            const nicknamePairs = nicknameDoc.data() || {};
            let userNickname = null;
            
            // Find the nickname belonging to this user
            for (const [nickname, data] of Object.entries(nicknamePairs)) {
                if (data && typeof data === "object" && data.uid === userId) {
                    userNickname = nickname;
                    break;
                }
            }
            
            if (userNickname) {
                await db.collection("nicknames").doc("pairs").update({
                    [userNickname]: FieldValue.delete(),
                });
                results.cleaned.push({ collection: "nicknames", nickname: userNickname });
            }
        }
    } catch (e) {
        results.errors.push({ collection: "nicknames", error: e.message });
    }
    
    // 3. Delete compatibility scores involving this user
    try {
        // Query where user is user1
        const compat1 = await db.collection("compatibilityScores")
            .where("user1Id", "==", userId)
            .get();
        
        // Query where user is user2
        const compat2 = await db.collection("compatibilityScores")
            .where("user2Id", "==", userId)
            .get();
        
        const allCompatDocs = [...compat1.docs, ...compat2.docs];
        if (allCompatDocs.length > 0) {
            const batch = db.batch();
            for (const doc of allCompatDocs) {
                batch.delete(doc.ref);
            }
            await batch.commit();
            results.cleaned.push({ collection: "compatibilityScores", count: allCompatDocs.length });
        }
    } catch (e) {
        results.errors.push({ collection: "compatibilityScores", error: e.message });
    }
    
    // 4. Clean up any reports made by this user (optional - for data minimization)
    try {
        const reportsSnapshot = await db.collection("reports")
            .where("reportedBy", "==", userId)
            .get();
        
        if (!reportsSnapshot.empty) {
            const batch = db.batch();
            for (const doc of reportsSnapshot.docs) {
                // Anonymize rather than delete (keep for moderation history)
                batch.update(doc.ref, {
                    reportedBy: "deleted_user",
                });
            }
            await batch.commit();
            results.cleaned.push({ collection: "reports", count: reportsSnapshot.size, action: "anonymized" });
        }
    } catch (e) {
        // Ignore - reports collection might not exist
    }
    
    return results;
}

// =============================================================================
// PHASE 5: Clean storage files
// =============================================================================

async function cleanStorage(userId) {
    const results = { filesDeleted: 0, errors: [] };
    const storage = getStorage();
    const bucket = storage.bucket(storageBucketName.value());
    
    // Directories to clean
    const prefixes = [
        `users/${userId}/`,
        `avatars/${userId}/`,
    ];
    
    for (const prefix of prefixes) {
        try {
            const [files] = await bucket.getFiles({ prefix });
            for (const file of files) {
                try {
                    await file.delete();
                    results.filesDeleted++;
                } catch (e) {
                    results.errors.push({ file: file.name, error: e.message });
                }
            }
        } catch (e) {
            results.errors.push({ prefix, error: e.message });
        }
    }
    
    // Also delete voice messages sent by this user (chat_audio/)
    try {
        const [audioFiles] = await bucket.getFiles({ prefix: "chat_audio/" });
        const userAudioFiles = audioFiles.filter(f => f.name.includes(userId));
        for (const file of userAudioFiles) {
            try {
                await file.delete();
                results.filesDeleted++;
            } catch (e) {
                // Ignore individual file errors
            }
        }
    } catch (e) {
        // Ignore - might not have any audio files
    }
    
    return results;
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Delete all documents in a collection/subcollection
 * Returns the count of deleted documents
 */
async function deleteCollection(collectionPath) {
    const collectionRef = db.collection(collectionPath);
    const snapshot = await collectionRef.get();
    
    if (snapshot.empty) {
        return 0;
    }
    
    // Delete in batches of 500 (Firestore limit)
    const batchSize = 500;
    let deleted = 0;
    
    while (true) {
        const batch = db.batch();
        const docs = await collectionRef.limit(batchSize).get();
        
        if (docs.empty) {
            break;
        }
        
        docs.forEach(doc => {
            batch.delete(doc.ref);
            deleted++;
        });
        
        await batch.commit();
        
        if (docs.size < batchSize) {
            break;
        }
    }
    
    return deleted;
}

/**
 * Update the audit record in deletedUsers collection
 */
async function updateAuditRecord(userId, results, status) {
    try {
        await db.collection("deletedUsers").doc(userId).set({
            ...results,
            status,
            updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
    } catch (e) {
        logger.error(`Failed to update audit record for ${userId}:`, e);
    }
}

/**
 * Calculate summary statistics from phase results
 */
function calculateSummary(phases) {
    const summary = {
        totalDocumentsDeleted: 0,
        totalFilesDeleted: 0,
        totalErrors: 0,
    };
    
    for (const [phaseName, phaseResult] of Object.entries(phases)) {
        if (phaseResult.deleted) {
            summary.totalDocumentsDeleted += phaseResult.deleted.reduce((sum, d) => sum + (d.count || 1), 0);
        }
        if (phaseResult.postsDeleted) {
            summary.totalDocumentsDeleted += phaseResult.postsDeleted;
        }
        if (phaseResult.repliesDeleted) {
            summary.totalDocumentsDeleted += phaseResult.repliesDeleted;
        }
        if (phaseResult.followingCleaned) {
            summary.totalDocumentsDeleted += phaseResult.followingCleaned;
        }
        if (phaseResult.followersCleaned) {
            summary.totalDocumentsDeleted += phaseResult.followersCleaned;
        }
        if (phaseResult.filesDeleted) {
            summary.totalFilesDeleted += phaseResult.filesDeleted;
        }
        if (phaseResult.errors) {
            summary.totalErrors += phaseResult.errors.length;
        }
    }
    
    return summary;
}

// =============================================================================
// SCHEDULED CLEANUP: Recover from failed deletions
// =============================================================================

/**
 * Biweekly cleanup job to handle failed or stale deletions.
 * 
 * Runs on the 1st and 15th of each month at 3 AM UTC (8:30 AM IST).
 * Finds deletions that are:
 * - status: "pending" for more than 1 hour (Cloud Function never ran/completed)
 * - status: "failed" (Cloud Function ran but errored)
 * 
 * For each stale deletion, attempts to re-run the cleanup phases.
 * This handles edge cases like:
 * - Cloud Function timeout
 * - Transient Firestore errors
 * - Old deletions from before the Cloud Function was deployed
 */
export const cleanupStaleDeletions = onSchedule({
    schedule: "0 3 1,15 * *",  // 3 AM UTC on 1st and 15th of each month
    timeZone: "UTC",
    timeoutSeconds: 540,    // 9 minutes max
    memory: "512MiB",
}, async (event) => {
    logger.info("🔄 [CLEANUP] Starting daily stale deletion cleanup");
    
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const results = { processed: 0, succeeded: 0, failed: 0, errors: [] };
    
    try {
        // Find stale "pending" deletions (older than 1 hour)
        const pendingSnapshot = await db.collection("deletedUsers")
            .where("status", "==", "pending")
            .where("deletionRequestedAt", "<", oneHourAgo)
            .limit(10)  // Process max 10 per run to avoid timeout
            .get();
        
        // Find "failed" deletions that need retry
        const failedSnapshot = await db.collection("deletedUsers")
            .where("status", "==", "failed")
            .limit(10)
            .get();
        
        const staleDeletions = [...pendingSnapshot.docs, ...failedSnapshot.docs];
        
        if (staleDeletions.length === 0) {
            logger.info("✅ [CLEANUP] No stale deletions found");
            return;
        }
        
        logger.info(`[CLEANUP] Found ${staleDeletions.length} stale deletions to process`);
        
        for (const doc of staleDeletions) {
            const userId = doc.id;
            const data = doc.data();
            results.processed++;
            
            logger.info(`[CLEANUP] Processing stale deletion for user: ${userId}`);
            
            try {
                // Mark as "retrying" to prevent duplicate processing
                await doc.ref.update({
                    status: "retrying",
                    retryStartedAt: FieldValue.serverTimestamp(),
                });
                
                // Re-run cleanup phases (user doc may or may not exist)
                await deleteUserOwnedData(userId);
                await deleteUserPosts(userId);
                await cleanCrossUserReferences(userId);
                await cleanIndicesAndSystemData(userId, data.phoneNumber);
                await cleanStorage(userId);
                
                // Mark as completed
                await doc.ref.update({
                    status: "completed",
                    completedAt: FieldValue.serverTimestamp(),
                    retriedAt: FieldValue.serverTimestamp(),
                    retryNote: "Cleaned up by scheduled job",
                });
                
                results.succeeded++;
                logger.info(`✅ [CLEANUP] Successfully cleaned up user: ${userId}`);
                
            } catch (error) {
                results.failed++;
                results.errors.push({ userId, error: error.message });
                
                // Mark as failed again with error details
                await doc.ref.update({
                    status: "failed",
                    lastRetryError: error.message,
                    lastRetryAt: FieldValue.serverTimestamp(),
                }).catch(() => {});
                
                logger.error(`❌ [CLEANUP] Failed to clean up user ${userId}:`, error);
            }
        }
        
        logger.info(`🔄 [CLEANUP] Completed - Processed: ${results.processed}, Succeeded: ${results.succeeded}, Failed: ${results.failed}`);
        
    } catch (error) {
        logger.error("❌ [CLEANUP] Scheduled cleanup job failed:", error);
    }
});

