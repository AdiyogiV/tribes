/**
 * User Account Deletion Handler — Tombstone-Sweep Model
 *
 * No longer triggered by Firebase Auth events. Instead, the Flutter client
 * writes a tombstone to `deletedUsers/{uid}` with `status: 'pending'` before
 * calling `user.delete()`, and the `unifiedOrchestrator` Phase 1 (cleanup)
 * sweep picks up pending tombstones and runs the cleanup phases.
 *
 * Why the change?
 *   - The previous `onUserDeleted` v1 auth trigger was its own Cloud Run
 *     service (v2 doesn't support auth events yet), consuming 1 vCPU from
 *     the 20 vCPU regional quota for an event that fires extremely rarely.
 *   - Moving the work into the daily orchestrator collapses that vCPU back
 *     into the scheduler's instance.
 *   - Latency tradeoff: deleted accounts retain Firestore data for up to
 *     ~24 hours (until the next orchestrator run) instead of being cleaned
 *     within minutes. Acceptable since the Auth user is already gone and
 *     the data is orphaned (no client can read it as the owner).
 *
 * Performs complete cleanup of ALL user data across the system:
 * - User document + all subcollections
 * - Posts and media
 * - Follow relationships (both directions)
 * - Space memberships
 * - DM conversations
 * - Indices (phone, nickname)
 * - Storage files
 * - Audit logging
 */

import { db, FieldValue, logger } from "../lib/firebase.js";
import { getStorage } from "firebase-admin/storage";
import { storageBucketName } from "../lib/secrets.js";

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
                            .doc(postId),
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
                const globalFeedRefs = repostsToProcess.map((r) =>
                    db.collection("globalFeed").doc(r.originalPostId),
                );
                const globalFeedDocs = await Promise.all(
                    globalFeedRefs.map((ref) => ref.get()),
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
                        const repostedBy = (feedData.repostedBy || []).filter((id) => id !== userId);

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
        errors: [],
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
        const userAudioFiles = audioFiles.filter((f) => f.name.includes(userId));
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

        docs.forEach((doc) => {
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
// DAILY TOMBSTONE SWEEP: Process deletedUsers tombstones
// =============================================================================

/**
 * Daily sweep that processes `deletedUsers` tombstones.
 *
 * Replaces the former `onUserDeleted` v1 auth trigger. Invoked by
 * `unifiedOrchestrator` Phase 1 (cleanup) on every daily run.
 *
 * Picks up two states:
 *   - `status: "pending"`  — newly tombstoned by the Flutter client
 *   - `status: "failed"`   — previous attempt errored, retry
 *
 * Each tombstone is atomically transitioned to `status: "processing"` via a
 * Firestore transaction before cleanup begins. This prevents double-processing
 * if multiple orchestrator runs overlap (e.g. retries) or if a future
 * deployment runs the sweep in parallel with itself.
 *
 * Cleanup phases (identical to the former auth trigger):
 *   1. deleteUserOwnedData       — user doc + subcollections
 *   2. deleteUserPosts           — posts + media + reposts
 *   3. cleanCrossUserReferences  — follows, spaces, DMs, chat messages
 *   4. cleanIndicesAndSystemData — phoneIndex, nicknames, compatibility
 *   5. cleanStorage              — Cloud Storage files
 *
 * Batch limits:
 *   - 50 pending tombstones per sweep (typical case: 0-5)
 *   - 10 failed tombstones per sweep (retry budget, deliberately smaller)
 *
 * Latency:
 *   - Up to 24 hours between client tombstone write and Firestore cleanup
 *     (orchestrator runs once daily at 11:00 PM UTC).
 *   - Auth user record is already deleted client-side; Firestore data is
 *     orphaned but unreachable since the only legitimate reader (the owner)
 *     no longer exists.
 */
export async function runProcessPendingDeletions() {
    logger.info("🗑️ [DELETE-SWEEP] Starting tombstone sweep");

    const results = { processed: 0, succeeded: 0, failed: 0, skipped: 0, errors: [] };

    try {
        // Pull both pending (new) and failed (retry) tombstones
        const pendingSnapshot = await db.collection("deletedUsers")
            .where("status", "==", "pending")
            .limit(50)
            .get();

        const failedSnapshot = await db.collection("deletedUsers")
            .where("status", "==", "failed")
            .limit(10)
            .get();

        const tombstones = [...pendingSnapshot.docs, ...failedSnapshot.docs];

        if (tombstones.length === 0) {
            logger.info("✅ [DELETE-SWEEP] No tombstones to process");
            return;
        }

        logger.info(`[DELETE-SWEEP] Found ${tombstones.length} tombstones to process`);

        for (const doc of tombstones) {
            const userId = doc.id;
            results.processed++;

            // Atomically claim the tombstone: pending|failed → processing.
            // If someone else already claimed it (e.g. an overlapping run),
            // the transaction returns null and we skip.
            let claimedData;
            try {
                claimedData = await db.runTransaction(async (tx) => {
                    const fresh = await tx.get(doc.ref);
                    if (!fresh.exists) return null;
                    const status = fresh.data().status;
                    if (status !== "pending" && status !== "failed") {
                        return null; // Already claimed
                    }
                    tx.update(doc.ref, {
                        status: "processing",
                        processingStartedAt: FieldValue.serverTimestamp(),
                    });
                    return fresh.data();
                });
            } catch (e) {
                logger.warn(`[DELETE-SWEEP] Could not claim tombstone ${userId}: ${e.message}`);
                results.skipped++;
                continue;
            }

            if (!claimedData) {
                logger.info(`[DELETE-SWEEP] Tombstone ${userId} already claimed by another run, skipping`);
                results.skipped++;
                continue;
            }

            const phoneNumber = claimedData.phoneNumber || null;
            const startTime = Date.now();

            const phaseResults = {
                userId,
                phoneNumber,
                email: claimedData.email || null,
                startedAt: new Date().toISOString(),
                phases: {},
                errors: [],
                summary: {},
            };

            try {
                logger.info(`[DELETE-SWEEP] Processing user: ${userId}`);

                phaseResults.phases.userOwnedData = await deleteUserOwnedData(userId);
                phaseResults.phases.posts = await deleteUserPosts(userId);
                phaseResults.phases.crossUserRefs = await cleanCrossUserReferences(userId);
                phaseResults.phases.indices = await cleanIndicesAndSystemData(userId, phoneNumber);
                phaseResults.phases.storage = await cleanStorage(userId);

                phaseResults.completedAt = new Date().toISOString();
                phaseResults.durationMs = Date.now() - startTime;
                phaseResults.summary = calculateSummary(phaseResults.phases);

                await updateAuditRecord(userId, phaseResults, "completed");
                results.succeeded++;

                logger.info(`✅ [DELETE-SWEEP] Cleaned up user ${userId}`, {
                    durationMs: phaseResults.durationMs,
                    summary: phaseResults.summary,
                });
            } catch (error) {
                phaseResults.errors.push({
                    phase: "global",
                    message: error.message,
                    stack: error.stack,
                });
                phaseResults.completedAt = new Date().toISOString();
                phaseResults.durationMs = Date.now() - startTime;

                await updateAuditRecord(userId, phaseResults, "failed");
                results.failed++;
                results.errors.push({ userId, error: error.message });

                logger.error(`❌ [DELETE-SWEEP] Failed for user ${userId}:`, error);
            }
        }

        logger.info(
            `🗑️ [DELETE-SWEEP] Completed — processed: ${results.processed}, ` +
            `succeeded: ${results.succeeded}, failed: ${results.failed}, skipped: ${results.skipped}`,
        );
    } catch (error) {
        logger.error("❌ [DELETE-SWEEP] Sweep failed:", error);
    }
}

