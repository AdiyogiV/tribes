import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { withIdempotency } from "../lib/idempotency.js";

/**
 * NOTE: `newLike` and `removeLike` have been merged into
 * `functions/triggers/on_post_like_write.js` (path-based onDocumentWritten
 * on `postLikes/{postId}/likes/{userId}`). This file now only contains
 * `newInvite`, which listens on a different path
 * (`userSpaces/{userId}/spaces/{space}`).
 */

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


