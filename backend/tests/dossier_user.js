/**
 * SINGLE-USER FORENSIC DOSSIER (read-only).
 * Pulls everything about one uid: Auth record, full Firestore doc, phoneIndex,
 * their AI conversations + actual messages, human DMs, posts, calls.
 * Usage: node tests/dossier_user.js <uid>
 */
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serviceAccount = JSON.parse(
  readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8")
);
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();
const auth = getAuth();
const AI_UID = "holycow_system_user";
const log = (s = "") => console.log(s);

const UID = process.argv[2];
if (!UID) { console.error("provide uid"); process.exit(1); }

function tms(ts) {
  if (!ts) return null;
  if (ts.toMillis) return ts.toMillis();
  if (ts.seconds) return ts.seconds * 1000;
  if (ts._seconds) return ts._seconds * 1000;
  return null;
}
const iso = (ts) => { const m = tms(ts); return m ? new Date(m).toISOString() : ""; };

async function main() {
  log("=".repeat(72));
  log(" DOSSIER: " + UID);
  log("=".repeat(72));

  // Auth
  log("\n--- FIREBASE AUTH ---");
  let au = null;
  try { au = await auth.getUser(UID); } catch (e) { log("  (no auth record: " + e.code + ")"); }
  if (au) {
    log("  displayName : " + au.displayName);
    log("  phone       : " + au.phoneNumber);
    log("  email       : " + au.email);
    log("  created     : " + au.metadata.creationTime);
    log("  lastSignIn  : " + au.metadata.lastSignInTime);
    log("  lastRefresh : " + au.metadata.lastRefreshTime);
    log("  disabled    : " + au.disabled);
    log("  providers   : " + au.providerData.map((p) => p.providerId).join(","));
  }

  // Firestore user doc
  log("\n--- FIRESTORE users DOC ---");
  const udoc = await db.collection("users").doc(UID).get();
  if (udoc.exists) {
    const u = udoc.data();
    Object.keys(u).sort().forEach((k) => {
      let v = u[k];
      if (v && (v.toMillis || v.seconds)) v = iso(v);
      else if (typeof v === "object") v = JSON.stringify(v).slice(0, 200);
      log("  " + k + ": " + v);
    });
  } else log("  (no firestore doc)");

  // phoneIndex
  log("\n--- phoneIndex matches ---");
  const piSnap = await db.collection("phoneIndex").get();
  piSnap.docs.forEach((d) => {
    const data = d.data();
    if (d.id.includes(UID) || JSON.stringify(data).includes(UID)) {
      log("  " + d.id + " => " + JSON.stringify(data));
    }
  });

  // dmConversations involving this user
  log("\n--- CONVERSATIONS ---");
  const dmSnap = await db.collection("dmConversations").get();
  const mine = dmSnap.docs.filter((d) => {
    const p = d.data().participants || [];
    return p.includes(UID);
  });
  let aiCount = 0, humanCount = 0;
  const allQuestions = [];
  for (const cdoc of mine) {
    const c = cdoc.data();
    const isAi = c.isAiConversation === true || (c.participants || []).includes(AI_UID);
    const msgs = await db.collection("dmConversations").doc(cdoc.id)
      .collection("messages").get();
    const sorted = msgs.docs.map((m) => m.data()).sort((a, b) => (tms(a.timestamp) || 0) - (tms(b.timestamp) || 0));
    if (isAi) {
      aiCount++;
      sorted.forEach((m) => {
        if (m.senderId === UID && m.content) {
          allQuestions.push({ t: iso(m.timestamp), voice: !!m.isVoiceMessage, q: m.content });
        }
      });
    } else {
      humanCount++;
    }
  }
  log("  AI conversations   : " + aiCount);
  log("  Human conversations: " + humanCount);
  log("  Total questions to HolyCow: " + allQuestions.length);

  allQuestions.sort((a, b) => (a.t < b.t ? -1 : 1));
  if (allQuestions.length) {
    log("  First question: " + allQuestions[0].t);
    log("  Last question : " + allQuestions[allQuestions.length - 1].t);
    log("\n  ALL QUESTIONS (chronological):");
    allQuestions.forEach((q, i) => {
      log(`   ${i + 1}. [${q.t}]${q.voice ? "[voice]" : ""} ${q.q.slice(0, 200)}`);
    });
  }

  // posts
  log("\n--- POSTS ---");
  const posts = await db.collection("posts").where("author", "==", UID).get();
  log("  count: " + posts.size);
  posts.docs.slice(0, 10).forEach((p) => log("   - " + (p.data().title || "(video, no title)")));

  // calls
  log("\n--- CALLS ---");
  const callsSnap = await db.collection("calls").get();
  const made = callsSnap.docs.filter((d) => d.data().callerId === UID);
  const recv = callsSnap.docs.filter((d) => d.data().calleeId === UID);
  log("  made: " + made.length + " received: " + recv.length);

  // save JSON dossier
  const OUT = join(__dirname, "../analysis/dossiers");
  if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });
  writeFileSync(join(OUT, UID + ".json"), JSON.stringify({
    uid: UID,
    auth: au ? {
      displayName: au.displayName, phone: au.phoneNumber, email: au.email,
      created: au.metadata.creationTime, lastSignIn: au.metadata.lastSignInTime,
      providers: au.providerData.map((p) => p.providerId),
    } : null,
    firestore: udoc.exists ? udoc.data() : null,
    aiConversations: aiCount, humanConversations: humanCount,
    questions: allQuestions, posts: posts.size,
    callsMade: made.length, callsReceived: recv.length,
  }, null, 2));
  log("\n  saved dossier to analysis/dossiers/" + UID + ".json");
  log("\ndone");
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
