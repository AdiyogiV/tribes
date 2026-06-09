/**
 * Probe: do HolyCow voice messages actually have retrievable audio?
 * Read-only. Checks audioUrl presence/shape across AI voice messages.
 */
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const sa = JSON.parse(readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8"));
initializeApp({ credential: cert(sa), storageBucket: `${sa.project_id}.appspot.com` });
const db = getFirestore();
const HOLYCOW = "holycow_system_user";

const cats = { real_url: 0, local_marker: 0, null_url: 0, empty: 0, other: 0 };
const samples = [];
let voiceTotal = 0, scanned = 0;

const dms = await db.collection("dmConversations").get();
const aiIds = dms.docs.filter((d) => {
  const x = d.data();
  return x.isAiConversation === true ||
    (Array.isArray(x.participants) && x.participants.includes(HOLYCOW));
}).map((d) => d.id);

console.log(`Scanning voice messages across ${aiIds.length} AI convos...`);
for (const id of aiIds) {
  const msgs = await db.collection("dmConversations").doc(id)
    .collection("messages").where("isVoiceMessage", "==", true).get();
  for (const m of msgs.docs) {
    voiceTotal++;
    const d = m.data();
    const u = d.audioUrl;
    if (u === undefined) cats.null_url++;
    else if (u === null) cats.null_url++;
    else if (u === "") cats.empty++;
    else if (u === "local") cats.local_marker++;
    else if (typeof u === "string" && u.startsWith("http")) {
      cats.real_url++;
      if (samples.length < 10) samples.push(u);
    } else { cats.other++; }
    // also check duration + any transcript-ish field
    if (scanned < 3) { console.log("  sample fields:", Object.keys(d).join(",")); scanned++; }
  }
}

console.log("\n=== VOICE AUDIO AVAILABILITY ===");
console.log(`total voice messages: ${voiceTotal}`);
for (const [k, v] of Object.entries(cats)) console.log(`  ${k.padEnd(14)}: ${v}`);
console.log("\nsample real URLs:");
samples.forEach((s) => console.log("  " + s.slice(0, 120)));

// If we have real URLs, confirm at least one object actually exists in Storage
if (samples.length) {
  try {
    const bucket = getStorage().bucket();
    const [files] = await bucket.getFiles({ prefix: "chats/", maxResults: 5 });
    console.log(`\nStorage chats/ sample objects: ${files.length}`);
    files.forEach((f) => console.log("  " + f.name));
  } catch (e) { console.log("storage check err:", e.message); }
}
process.exit(0);
