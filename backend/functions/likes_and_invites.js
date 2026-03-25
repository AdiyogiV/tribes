import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";

/**
 * Handle new like - increment likeCount and send notification
 */
export const newLike = onDocumentCreated("postLikes/{postId}/likes/{userId}", withIdempotency("newLike", async (event) => {
    const postId = event.params.postId;
    const likerId = event.params.userId;
    
    try {
        const postDoc = await db.collection("posts").doc(postId).get();
        if (!postDoc.exists) {
            logger.warn("Post not found for like", { postId, likerId });
            return;
        }
        
        const postData = postDoc.data();
        const postAuthor = postData.author;
        
        // Increment likeCount on the post (always, even for self-likes)
        await db.collection("posts").doc(postId).update({
            likeCount: FieldValue.increment(1),
        });
        
        logger.info("Like count incremented", { postId, likerId });
        
        // Skip notification if liking own post
        if (likerId === postAuthor) {
            return;
        }
        
        // Send notification to post author
        const likerDoc = await db.collection("users").doc(likerId).get();
        const likerData = likerDoc.data() || {};
        
        const notification = {
            type: "like",
            read: false,
            postId: postId,
            liker: likerId,
            likerName: likerData.name || "Someone",
            likerDisplayPicture: likerData.displayPicture || "",
            thumbnail: postData.thumbnail,
            space: postData.space,
            timestamp: FieldValue.serverTimestamp(),
        };
        
        await db.collection("notifications").doc(postAuthor).collection("notifications").add(notification);
        
    } catch (error) {
        logger.error("Error processing like", { structuredData: true, error: error.message, postId, likerId });
    }
}));

/**
 * Handle unlike - decrement likeCount
 */
export const removeLike = onDocumentDeleted("postLikes/{postId}/likes/{userId}", withIdempotency("removeLike", async (event) => {
    const postId = event.params.postId;
    const likerId = event.params.userId;
    
    try {
        const postDoc = await db.collection("posts").doc(postId).get();
        if (!postDoc.exists) {
            logger.warn("Post not found for unlike", { postId, likerId });
            return;
        }
        
        // Decrement likeCount on the post
        await db.collection("posts").doc(postId).update({
            likeCount: FieldValue.increment(-1),
        });
        
        logger.info("Like count decremented", { postId, likerId });
        
    } catch (error) {
        logger.error("Error processing unlike", { structuredData: true, error: error.message, postId, likerId });
    }
}));

export const newInvite = onDocumentCreated("userSpaces/{userId}/spaces/{space}", withIdempotency("newInvite", async (event) => {
    const snap = event.data;
    const postData = snap.data();
    const { role, inviter } = postData;
    const userId = event.params.userId;
    const spaceId = event.params.space;
    
    // Helper function to get user name and avatar
    const getUserInfo = async (uid) => {
        if (!uid) return { name: "Someone", avatar: "" };
        try {
            const userDoc = await db.collection("users").doc(uid).get();
            if (!userDoc.exists) return { name: "Someone", avatar: "" };
            const data = userDoc.data();
            return {
                name: data.name || data.username || "Someone",
                avatar: data.displayPicture || "",
            };
        } catch (e) {
            return { name: "Someone", avatar: "" };
        }
    };
    
    // Helper function to get space name
    const getSpaceName = async (sid) => {
        if (!sid) return "";
        try {
            const spaceDoc = await db.collection("spaces").doc(sid).get();
            if (!spaceDoc.exists) return "";
            return spaceDoc.data().name || "";
        } catch (e) {
            return "";
        }
    };
    
    if (role == "invited") {
        try {
            const [inviterInfo, spaceName] = await Promise.all([
                getUserInfo(postData.inviter),
                getSpaceName(spaceId),
            ]);
            
            const notification = {
                type: "invite",
                read: false,
                role: role,
                inviter: postData.inviter,
                inviterName: inviterInfo.name,
                inviterAvatar: inviterInfo.avatar,
                space: spaceId,
                spaceName: spaceName,
                timestamp: FieldValue.serverTimestamp(),
            };
            await db.collection("notifications").doc(userId).collection("notifications").add(notification);
        } catch (error) {
            logger.error("Error sending invite notification", { structuredData: true, error });
        }
    }
    if (role == "requested") {
        try {
            const spaceDoc = await db.collection("spaces").doc(spaceId).get();
            if (!spaceDoc.exists) {
                return;
            }
            const spaceData = spaceDoc.data();
            const creator = spaceData.creatorId;
            
            const requestorInfo = await getUserInfo(userId);
            
            const notification = {
                type: "request",
                read: false,
                role: role,
                requestor: userId,
                requestorName: requestorInfo.name,
                requestorAvatar: requestorInfo.avatar,
                space: spaceId,
                spaceName: spaceData.name || "",
                timestamp: FieldValue.serverTimestamp(),
            };
            await db.collection("notifications").doc(creator).collection("notifications").add(notification);
        } catch (error) {
            logger.error("Error sending request notification", { structuredData: true, error });
        }
    }
    if (role == "member" && inviter != null) {
        try {
            const [inviterInfo, spaceName] = await Promise.all([
                getUserInfo(inviter),
                getSpaceName(spaceId),
            ]);
            
            const notification = {
                type: "addedtogroup",
                read: false,
                role: role,
                inviter: inviter,
                inviterName: inviterInfo.name,
                inviterAvatar: inviterInfo.avatar,
                space: spaceId,
                spaceName: spaceName,
                timestamp: FieldValue.serverTimestamp(),
            };
            await db.collection("notifications").doc(userId).collection("notifications").add(notification);
        } catch (error) {
            logger.error("Error sending added-to-group notification", { structuredData: true, error });
        }
    }
}));


