/**
 * One-time cleanup script for inactive / empty spaces (Grams).
 *
 * Run from backend/:
 *   node scripts/cleanup_inactive_spaces.js              # List only (dry-run)
 *   node scripts/cleanup_inactive_spaces.js --dry-run    # Same: list only
 *   node scripts/cleanup_inactive_spaces.js --yes        # Delete empty spaces (no prompt)
 *   node scripts/cleanup_inactive_spaces.js --inactive-days=180 --yes   # Also delete spaces inactive 180+ days
 *
 * Requires: GOOGLE_APPLICATION_CREDENTIALS or default Firebase project credentials.
 *
 * Criteria:
 *   Default: Delete only spaces with zero posts AND zero chat messages.
 *   With --inactive-days=N: Also delete spaces with no posts/chat in the last N days.
 *
 * Excluded (never deleted):
 *   - DM conversations (spaceId starting with dm_).
 *   - Profile Grams (isProfileGram === true or spaceType === 3 personal).
 */

import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';

if (!admin.apps.length) {
    admin.initializeApp();
}

const db = getFirestore();
const BATCH_SIZE = 500;

const args = process.argv.slice(2);
const yesFlag = args.includes('--yes');
const dryRunFlag = args.includes('--dry-run');
const inactiveDaysArg = args.find(a => a.startsWith('--inactive-days='));
const inactiveDays = inactiveDaysArg ? parseInt(inactiveDaysArg.split('=')[1], 10) : 0;
const minAgeDaysArg = args.find(a => a.startsWith('--min-age-days='));
const minAgeDays = minAgeDaysArg ? parseInt(minAgeDaysArg.split('=')[1], 10) : 0;
const emptyOnly = inactiveDays <= 0;
// Dry run by default when no args. With --inactive-days=N we run for real (and prompt unless --yes).
const dryRun = dryRunFlag || args.length === 0;

/**
 * Delete all documents in a collection (or query) in batches of BATCH_SIZE.
 */
async function deleteQueryBatch(queryRef) {
    const snapshot = await queryRef.limit(BATCH_SIZE).get();
    if (snapshot.empty) return 0;
    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    return snapshot.size;
}

/**
 * Delete entire subcollection by path (e.g. spacePosts/{id}/posts).
 */
async function deleteSubcollection(parentRef, subcollectionId) {
    const colRef = parentRef.collection(subcollectionId);
    let total = 0;
    let n;
    do {
        n = await deleteQueryBatch(colRef);
        total += n;
    } while (n === BATCH_SIZE);
    return total;
}

function qualifiesForDeletion(stats, emptyOnlyMode, inactiveDaysThreshold) {
    if (emptyOnlyMode) {
        return stats.postCount === 0 && !stats.hasChat;
    }
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - inactiveDaysThreshold);
    const lastActivity = stats.lastPostAt && stats.lastChatAt
        ? (stats.lastPostAt > stats.lastChatAt ? stats.lastPostAt : stats.lastChatAt)
        : (stats.lastPostAt || stats.lastChatAt);
    if (!lastActivity) return stats.postCount === 0 && !stats.hasChat;
    return lastActivity < cutoff;
}

/**
 * Paged count for subcollection (Firestore has no count() on collection ref in older SDK).
 */
async function countSubcollection(parentRef, subcollectionId) {
    const colRef = parentRef.collection(subcollectionId);
    let count = 0;
    let snapshot = await colRef.limit(BATCH_SIZE).get();
    while (!snapshot.empty) {
        count += snapshot.size;
        if (snapshot.size < BATCH_SIZE) break;
        const last = snapshot.docs[snapshot.docs.length - 1];
        snapshot = await colRef.startAfter(last).limit(BATCH_SIZE).get();
    }
    return count;
}

async function getSpaceStatsFast(spaceId, spaceData) {
    const lastPostAt = spaceData?.lastPostAt?.toDate?.() || null;

    const postsSnap = await db.collection('spacePosts').doc(spaceId).collection('posts').limit(1).get();
    const postCount = postsSnap.empty ? 0 : await countSubcollection(db.collection('spacePosts').doc(spaceId), 'posts');

    const chatSnap = await db.collection('spaceChats').where('spaceId', '==', spaceId).limit(1).get();
    const hasChat = !chatSnap.empty;

    let lastChatAt = null;
    if (hasChat) {
        const lastChatSnap = await db.collection('spaceChats')
            .where('spaceId', '==', spaceId)
            .orderBy('timestamp', 'desc')
            .limit(1)
            .get();
        if (!lastChatSnap.empty) {
            const ts = lastChatSnap.docs[0].data()?.timestamp;
            lastChatAt = ts?.toDate?.() || null;
        }
    }

    return { postCount, hasChat, lastPostAt, lastChatAt };
}

/**
 * Get space creation date from creator's userSpaces doc or earliest spaceRoles timestamp.
 */
async function getSpaceCreatedAt(spaceId, spaceData) {
    const creatorId = spaceData?.creatorId;
    if (creatorId) {
        const creatorSpaceDoc = await db.collection('userSpaces').doc(creatorId).collection('spaces').doc(spaceId).get();
        const ts = creatorSpaceDoc.exists && creatorSpaceDoc.data()?.timestamp;
        if (ts && ts.toDate) return ts.toDate();
    }
    const rolesSnap = await db.collection('spaceRoles').doc(spaceId).collection('roles').limit(1).get();
    if (rolesSnap.empty) return null;
    const rolesAll = await db.collection('spaceRoles').doc(spaceId).collection('roles').get();
    let earliest = null;
    for (const d of rolesAll.docs) {
        const t = d.data()?.timestamp?.toDate?.();
        if (t && (!earliest || t < earliest)) earliest = t;
    }
    return earliest;
}

/**
 * Permanently delete a space and all related data.
 */
async function deleteSpace(spaceId) {
    const spaceRef = db.collection('spaces').doc(spaceId);
    const rolesRef = db.collection('spaceRoles').doc(spaceId).collection('roles');

    const rolesSnap = await rolesRef.get();
    const memberIds = rolesSnap.docs.map(d => d.id);

    const batch = db.batch();

    for (const userId of memberIds) {
        batch.delete(db.collection('spaceRoles').doc(spaceId).collection('roles').doc(userId));
        batch.delete(db.collection('userSpaces').doc(userId).collection('spaces').doc(spaceId));
    }
    await batch.commit();

    let totalChats = 0;
    let query = db.collection('spaceChats').where('spaceId', '==', spaceId);
    let n;
    do {
        n = await deleteQueryBatch(query);
        totalChats += n;
    } while (n === BATCH_SIZE);

    const spacePostsRef = db.collection('spacePosts').doc(spaceId);
    const postsInSpaceCount = await deleteSubcollection(spacePostsRef, 'posts');
    await spacePostsRef.delete();

    const postsSnapshot = await db.collection('posts')
        .where('space', '==', spaceId)
        .get();

    for (const postDoc of postsSnapshot.docs) {
        const postId = postDoc.id;
        const repliesRef = db.collection('postReplies').doc(postId).collection('replies');
        let r;
        do {
            r = await deleteQueryBatch(repliesRef.limit(BATCH_SIZE));
        } while (r === BATCH_SIZE);
        await db.collection('globalFeed').doc(postId).delete();
        await postDoc.ref.delete();
    }

    const callsRef = db.collection('spaces').doc(spaceId).collection('calls').doc('active');
    const callDoc = await callsRef.get();
    if (callDoc.exists) await callsRef.delete();

    await spaceRef.delete();

    return {
        membersRemoved: memberIds.length,
        chatsDeleted: totalChats,
        spacePostsDeleted: postsInSpaceCount,
        mainPostsDeleted: postsSnapshot.size,
    };
}

async function main() {
    const threshold = inactiveDays || 180;
    const emptyOnlyMode = emptyOnly;

    console.log('\n🏠 Spaces cleanup');
    console.log('   Mode:', dryRun ? 'DRY-RUN (no changes)' : 'EXECUTE (will delete)');
    console.log('   Criteria:', emptyOnlyMode ? 'Empty only (0 posts, 0 chat)' : `Inactive for ${threshold} days`);
    console.log('');

    const spacesSnap = await db.collection('spaces').get();
    const candidates = [];

    // SpaceType 3 = legacy "personal" (profile timeline). Never delete profile Grams.
    const SPACE_TYPE_PERSONAL = 3;
    for (const doc of spacesSnap.docs) {
        const spaceId = doc.id;
        const data = doc.data() || {};
        if (spaceId.startsWith('dm_')) continue;
        if (data.isProfileGram === true) continue; // Profile Gram (user timeline)
        if (data.spaceType === SPACE_TYPE_PERSONAL) continue; // Legacy personal/profile space

        const stats = await getSpaceStatsFast(spaceId, data);
        if (qualifiesForDeletion(stats, emptyOnlyMode, threshold || 180)) {
            candidates.push({
                id: spaceId,
                name: data.name || spaceId,
                creatorId: data.creatorId,
                ...stats,
            });
        }
    }

    // Attach createdAt from creator's userSpaces or spaceRoles
    for (const s of candidates) {
        const spaceDoc = await db.collection('spaces').doc(s.id).get();
        s.createdAt = await getSpaceCreatedAt(s.id, spaceDoc.data() || {});
    }

    const cutoff100 = minAgeDays > 0 ? new Date(Date.now() - minAgeDays * 24 * 60 * 60 * 1000) : null;
    const filtered = cutoff100
        ? candidates.filter(s => s.createdAt && s.createdAt < cutoff100)
        : candidates;

    const withUnknown = candidates.filter(s => !s.createdAt).length;
    if (minAgeDays > 0) {
        console.log(`Filter: empty spaces created before ${minAgeDays} days ago (before ${cutoff100.toISOString().slice(0, 10)}).`);
        if (withUnknown > 0) console.log(`Spaces with unknown creation date are excluded (${withUnknown}).`);
        console.log('');
    }

    if (filtered.length === 0) {
        console.log(candidates.length === 0 ? '✅ No spaces qualify for cleanup.' : `✅ No spaces qualify after filtering by min-age (${candidates.length} empty, 0 created before ${minAgeDays} days).`);
        if (candidates.length > 0 && minAgeDays > 0) {
            console.log('\nAll qualifying empty spaces (with creation date):');
            candidates.forEach((s, i) => {
                const created = s.createdAt ? s.createdAt.toISOString().slice(0, 10) : 'unknown';
                const old = s.createdAt && s.createdAt < cutoff100 ? 'yes' : 'no';
                console.log(`  ${i + 1}. ${s.name} | ${s.id} | created: ${created} | older_than_${minAgeDays}d: ${old}`);
            });
        }
        return;
    }

    const list = minAgeDays > 0 ? filtered : candidates;
    const cutoff100ForDisplay = new Date(Date.now() - 100 * 24 * 60 * 60 * 1000);
    const allHaveDate = candidates.every(s => s.createdAt);
    const allOlderThan100 = allHaveDate && candidates.every(s => s.createdAt < cutoff100ForDisplay);
    const unknownCount = candidates.filter(s => !s.createdAt).length;
    const newerCount = candidates.filter(s => s.createdAt && s.createdAt >= cutoff100ForDisplay).length;
    const olderCount = candidates.filter(s => s.createdAt && s.createdAt < cutoff100ForDisplay).length;

    console.log(`Empty spaces total: ${candidates.length}`);
    console.log(`  Created before 100 days: ${olderCount} | In last 100 days: ${newerCount} | Unknown creation date: ${unknownCount}`);
    console.log(`Were they ALL created before 100 days? ${allOlderThan100 ? 'Yes.' : `No — ${newerCount} newer, ${unknownCount} unknown.`}\n`);

    console.log(`Final list for cleanup${minAgeDays > 0 ? ` (created before ${minAgeDays} days only)` : ' (all empty)'}: ${list.length} space(s)\n`);
    list.forEach((s, i) => {
        const created = s.createdAt ? s.createdAt.toISOString().slice(0, 10) : 'unknown';
        const older100 = s.createdAt ? (s.createdAt < cutoff100ForDisplay ? 'yes' : 'no') : '—';
        console.log(`  ${i + 1}. ${s.name} (${s.id})`);
        console.log(`     created: ${created}, older_than_100d: ${older100}, posts: ${s.postCount}, chat: ${s.hasChat ? 'yes' : 'no'}`);
    });
    console.log('');

    if (dryRun) {
        console.log('Run without --dry-run to perform deletion. Use --yes to skip confirmation.');
        return;
    }

    const toDelete = minAgeDays > 0 ? filtered : candidates;
    if (toDelete.length === 0) {
        return;
    }

    if (!yesFlag) {
        console.log('Confirm deletion of the above spaces? (y/N)');
        const readline = await import('readline');
        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
        const answer = await new Promise(resolve => rl.question('> ', resolve));
        rl.close();
        if (answer?.toLowerCase() !== 'y' && answer?.toLowerCase() !== 'yes') {
            console.log('Aborted.');
            return;
        }
    }

    let ok = 0;
    let err = 0;
    for (const s of toDelete) {
        try {
            const result = await deleteSpace(s.id);
            console.log(`  Deleted: ${s.name} (${s.id})`, result);
            ok++;
        } catch (e) {
            console.error(`  Failed: ${s.name} (${s.id})`, e.message);
            err++;
        }
    }

    console.log('\n✅ Done.');
    console.log(`   Deleted: ${ok}, Errors: ${err}`);
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Cleanup failed:', err);
        process.exit(1);
    });
