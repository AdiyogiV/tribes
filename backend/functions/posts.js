import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";
import { PostSchema } from "../lib/schemas.js";

export const newPost = onDocumentCreated("posts/{postId}", withIdempotency("newPost", async (event) => {
    const snap = event.data;
    const postData = snap.data();
    try {
        PostSchema.parse(postData);
    } catch (e) {
        return;
    }
    const { replyTo, author, thumbnail, space } = postData;
    if (replyTo) {
        try {
            const postDoc = await db.collection("posts").doc(replyTo).get();
            if (!postDoc.exists) {
                return;
            }
            const postAuthor = postDoc.data().author;
            
            // Skip notification if replying to own post
            if (author === postAuthor) {
                return;
            }
            
            // Get reply author's info for the notification
            const authorDoc = await db.collection("users").doc(author).get();
            const authorData = authorDoc.exists ? authorDoc.data() : {};
            const authorName = authorData.name || authorData.username || "Someone";
            const authorPic = authorData.displayPicture || "";
            
            const notification = {
                type: "reply",
                read: false,
                postId: snap.id,
                replyToPost: replyTo,
                author: author,
                authorName: authorName,
                authorPic: authorPic,
                thumbnail: thumbnail,
                space: space,
                timestamp: FieldValue.serverTimestamp(),
            };
            await db.collection("notifications").doc(postAuthor).collection("notifications").add(notification);
            await db.collection("userFeed").doc(postAuthor).collection("posts").doc(event.params.postId).set({
                ...postData,
                seen: false,
                timestamp: FieldValue.serverTimestamp(),
            });
        } catch (error) {
            logger.error("Error handling reply notification", { structuredData: true, error });
        }
    }
}));

export const deletePost = onDocumentDeleted("posts/{postId}", withIdempotency("deletePost", async (event) => {
    const snap = event.data;
    const postData = snap.data();
    const deletedPostId = event.params.postId;
    
    try {
        PostSchema.parse(postData);
    } catch (e) {
        return;
    }
    
    const { replyTo } = postData;
    
    // PART 1: If this post was a reply, clean up from original author's feed
    if (replyTo) {
        try {
            const originalPostDoc = await db.collection("posts").doc(replyTo).get();
            if (originalPostDoc.exists) {
                const originalPostAuthor = originalPostDoc.data()?.author;
                if (originalPostAuthor) {
                    await db.collection("userFeed").doc(originalPostAuthor).collection("posts").doc(deletedPostId).delete();
                }
            }
        } catch (error) {
            logger.error("Error deleting reply from feed", { structuredData: true, error });
        }
    }
    
    // PART 2: Clean up orphaned replies that reference this deleted post
    // This prevents "missing post" errors when replies point to deleted posts
    try {
        await cleanupOrphanedReplies(deletedPostId);
    } catch (error) {
        logger.error("Error cleaning up orphaned replies", {
            structuredData: true,
            deletedPostId,
            error: String(error),
        });
        // Don't throw - this is cleanup, not critical
    }
}));

/**
 * Clean up orphaned reply references when a post is deleted
 * Clears the replyTo field on posts that referenced the deleted post
 * This prevents "post not found" errors in the UI
 * 
 * @param {string} deletedPostId - ID of the deleted post
 */
async function cleanupOrphanedReplies(deletedPostId) {
    // Find all posts that have replyTo pointing to the deleted post
    const orphanedReplies = await db.collection("posts")
        .where("replyTo", "==", deletedPostId)
        .limit(100) // Safety limit
        .get();
    
    if (orphanedReplies.empty) {
        return;
    }
    
    logger.info("Cleaning up orphaned replies", {
        structuredData: true,
        deletedPostId,
        orphanCount: orphanedReplies.size,
    });
    
    // Use batched writes for efficiency
    const batch = db.batch();
    
    orphanedReplies.docs.forEach((doc) => {
        // Clear the replyTo reference but keep the post
        // This makes the reply appear as a standalone post
        batch.update(doc.ref, {
            replyTo: FieldValue.delete(),
            _originalReplyTo: deletedPostId, // Keep for audit trail
            _replyToDeleted: true,
        });
    });
    
    await batch.commit();
    
    logger.info("Orphaned replies cleaned up", {
        structuredData: true,
        deletedPostId,
        cleanedCount: orphanedReplies.size,
    });
}

// REMOVED: newSpacePost - Logic merged into feeds.js addPostToFeeds for optimization
// This eliminates a redundant function invocation and duplicate spaceRoles read
