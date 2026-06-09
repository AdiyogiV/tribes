/**
 * dedupe_messages.js — one-time cleanup of duplicated AI chat messages.
 *
 * Root cause (now fixed in the Flutter client): each save wrote every message
 * with a fresh random doc id, so messages piled up ~6x. This script collapses
 * each logical message (same senderId + timestamp + content) down to a single
 * doc, keeping the lexicographically-first doc id and deleting the rest.
 *
 * SAFE BY DEFAULT: dry-run unless you pass --apply.
 *
 *   node tests/dedupe_messages.js            # report only, deletes nothing
 *   node tests/dedupe_messages.js --apply    # actually delete duplicates
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serviceAccount = JSON.parse(
    readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8"),
);
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const APPLY = process.argv.includes("--apply");
const HOLYCOW = "holycow_system_user";

const millis = (ts) =>
    !ts ? 0 : ts.toMillis ? ts.toMillis() : ts._seconds ? ts._seconds * 1000 : Number(ts) || 0;

async function main() {
    console.log(`\n Message dedupe — mode: ${APPLY ? "APPLY (will delete)" : "DRY-RUN (no writes)"}\n`);

    const dm = await db.collection("dmConversations").get();
    const aiConvos = dm.docs.filter((d) => {
        const c = d.data();
        return c.isAiConversation === true ||
            (Array.isArray(c.participants) && c.participants.includes(HOLYCOW));
    });
    console.log(`Scanning ${aiConvos.length} AI conversations...\n`);

    let totalDocs = 0, totalUnique = 0, totalDeleted = 0, convosTouched = 0;

    for (const cdoc of aiConvos) {
        const msgsRef = db.collection("dmConversations").doc(cdoc.id).collection("messages");
        const snap = await msgsRef.get();
        if (snap.empty) continue;

        // Group by logical identity.
        const groups = new Map();
        snap.docs.forEach((d) => {
            const x = d.data();
            const key = `${x.senderId}|${millis(x.timestamp)}|${(x.content || "").slice(0, 80)}`;
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key).push(d.id);
        });

        const dupIds = [];
        for (const ids of groups.values()) {
            if (ids.length > 1) {
                ids.sort();              // deterministic keeper
                dupIds.push(...ids.slice(1)); // delete all but the first
            }
        }

        totalDocs += snap.size;
        totalUnique += groups.size;
        if (dupIds.length === 0) continue;
        convosTouched++;

        console.log(`  ${cdoc.id}: ${snap.size} docs → ${groups.size} unique  (deleting ${dupIds.length})`);

        if (APPLY) {
            // Batch deletes (Firestore cap 500/batch).
            for (let i = 0; i < dupIds.length; i += 450) {
                const batch = db.batch();
                dupIds.slice(i, i + 450).forEach((id) => batch.delete(msgsRef.doc(id)));
                await batch.commit();
            }
        }
        totalDeleted += dupIds.length;
    }

    console.log("\n" + "=".repeat(60));
    console.log(`Conversations with dupes : ${convosTouched}`);
    console.log(`Total message docs       : ${totalDocs}`);
    console.log(`Unique logical messages  : ${totalUnique}`);
    console.log(`Duplicates ${APPLY ? "DELETED " : "to delete"}      : ${totalDeleted}`);
    console.log(`Bloat factor             : ${(totalDocs / Math.max(totalUnique, 1)).toFixed(2)}x`);
    console.log("=".repeat(60));
    if (!APPLY && totalDeleted > 0) {
        console.log("\nDry-run only. Re-run with --apply to delete.\n");
    }
}

main().then(() => process.exit(0)).catch((e) => {
    console.error(" dedupe error:", e);
    process.exit(1);
});
