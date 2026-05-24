/**
 * onSpacePostWrite — Consolidated trigger for `spacePosts/{spaceId}/posts/{postId}` writes.
 *
 * Merges three previously separate Cloud Functions on the same path:
 *
 *   ON CREATE:
 *     1. addPostToFeeds            (feeds.js)         — notifications + globalFeed write
 *     2. awardCreateSpacePostAura  (aura.js)          — aura for non-reply top-level posts
 *
 *   ON DELETE:
 *     3. deleteSpacePostFromGlobalFeed (feeds.js)     — purge globalFeed entry
 *
 * Eventarc allows only one Cloud Function per unique document path; this trigger
 * collapses the three into one onDocumentWritten subscription.
 *
 * NOTE: this path (`spacePosts/...`) is different from `spaces/{spaceId}/posts/{postId}`
 * — the latter is handled by `onSpacePostDeleted` in reposts.js (kept separate).
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, FieldValue, logger } from "../../lib/firebase.js";
import { withIdempotency } from "../../lib/idempotency.js";
import { BATCH_SIZES, AURA_POINTS } from "../../lib/constants.js";
import { isPublicSpace } from "../../lib/utils.js";
import { awardAura } from "../../lib/aura_service.js";

const ROLE_PAGE_SIZE = 500;

async function fetchSpaceMemberIds(spaceId) {
    const rolesRef = db.collection("spaceRoles").doc(spaceId).collection("roles");
    const memberIds = [];
    let lastDoc = null;

    // eslint-disable-next-line no-constant-condition
    while (true) {
        let query = rolesRef.orderBy("__name__").limit(ROLE_PAGE_SIZE);
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();
        if (snapshot.empty) break;

        for (const doc of snapshot.docs) {
            const data = doc.data();
            if (data.role !== "invited" && data.role !== "requested") {
                memberIds.push(doc.id);
            }
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < ROLE_PAGE_SIZE) break;
    }

    return memberIds;
}

// =============================================================================
// CREATE-branch handlers
// =============================================================================

/**
 * Was `addPostToFeeds` (feeds.js): notifies members + writes to globalFeed if
 * the space is public; also bumps space.lastPostAt.
 */
async function handleSpacePostFanoutOnCreate(postData, spaceId, postId) {
    const { author, title, thumbnail, replyTo, video } = postData;

    const spaceDoc = await db.collection("spaces").doc(spaceId).get();
    const spaceData = spaceDoc.data();
    if (!spaceData) {
        return;
    }

    await db.collection("spaces").doc(spaceId).update({
        lastPostAt: FieldValue.serverTimestamp(),
    });

    const authorDoc = await db.collection("users").doc(author).get();
    const authorData = authorDoc.exists ? authorDoc.data() : {};
    const authorName = authorData.name || authorData.username || "Someone";
    const authorPic = authorData.displayPicture || "";

    const memberIds = await fetchSpaceMemberIds(spaceId);
    const recipientIds = memberIds.filter((userId) => userId !== author && userId !== replyTo);

    const NOTIFICATION_BATCH_SIZE = BATCH_SIZES.FIRESTORE_WRITES || 500;
    let notificationCount = 0;

    for (let i = 0; i < recipientIds.length; i += NOTIFICATION_BATCH_SIZE) {
        const batch = db.batch();
        const chunk = recipientIds.slice(i, i + NOTIFICATION_BATCH_SIZE);

        for (const userId of chunk) {
            const notificationRef = db
                .collection("notifications")
                .doc(userId)
                .collection("notifications")
                .doc();

            batch.set(notificationRef, {
                type: "newSpacePost",
                read: false,
                postId: postId,
                author: author,
                authorName: authorName,
                authorPic: authorPic,
                title: title || "",
                thumbnail: thumbnail,
                replyTo: replyTo,
                video: video,
                space: spaceId,
                spaceName: spaceData.name || "",
                timestamp: FieldValue.serverTimestamp(),
            });
            notificationCount++;
        }

        await batch.commit();
    }

    if (isPublicSpace(spaceData)) {
        await db.collection("globalFeed").doc(postId).set({
            postId,
            author,
            contextType: "space",
            contextId: spaceId,
            title: title || "",
            thumbnail,
            timestamp: FieldValue.serverTimestamp(),
        });
    }

    logger.info("Space post processed (notifications + global feed)", {
        structuredData: true,
        postId,
        spaceId,
        notificationCount,
        addedToGlobalFeed: isPublicSpace(spaceData),
    });
}

/**
 * Was `awardCreateSpacePostAura` (aura.js).
 */
async function handleSpacePostAuraOnCreate(postData, spaceId, postId) {
    if (!postData?.author) {
        logger.warn("Space post missing author, skipping create-post aura", { postId, spaceId });
        return;
    }

    if (postData.replyTo) {
        return;
    }

    await awardAura(
        postData.author,
        AURA_POINTS.CREATE_POST,
        "Created post",
        { postId, spaceId, action: "space_post_created" },
    );

    logger.info("Created-space-post aura awarded", { postId, spaceId, author: postData.author });
}

// =============================================================================
// DELETE-branch handler
// =============================================================================

/**
 * Was `deleteSpacePostFromGlobalFeed` (feeds.js).
 */
async function handleSpacePostGlobalFeedDelete(postId) {
    try {
        await db.collection("globalFeed").doc(postId).delete();
        logger.info("Space post removed from global feed", {
            structuredData: true,
            postId,
        });
    } catch (error) {
        // Ignore - post may not be in global feed
    }
}

// =============================================================================
// Unified Cloud Function
// =============================================================================

const createPipeline = withIdempotency("onSpacePostWrite:create", async (event) => {
    const snap = event.data?.after;
    if (!snap) return;
    const postData = snap.data();
    if (!postData) return;
    const { spaceId, postId } = event.params;

    // Run fanout + aura concurrently. Both are independent.
    await Promise.all([
        handleSpacePostFanoutOnCreate(postData, spaceId, postId).catch((e) =>
            logger.error("space-post-create fanout failed", { spaceId, postId, error: String(e) })),
        handleSpacePostAuraOnCreate(postData, spaceId, postId).catch((e) =>
            logger.error("space-post-create aura failed", { spaceId, postId, error: String(e) })),
    ]);
});

const deletePipeline = withIdempotency("onSpacePostWrite:delete", async (event) => {
    const { postId } = event.params;
    await handleSpacePostGlobalFeedDelete(postId);
});

export const onSpacePostWrite = onDocumentWritten("spacePosts/{spaceId}/posts/{postId}", async (event) => {
    const beforeExists = event.data?.before?.exists ?? false;
    const afterExists = event.data?.after?.exists ?? false;

    if (!beforeExists && afterExists) {
        await createPipeline(event);
        return null;
    }

    if (beforeExists && !afterExists) {
        await deletePipeline(event);
        return null;
    }

    // UPDATE — no merged trigger needs this branch.
    return null;
});
