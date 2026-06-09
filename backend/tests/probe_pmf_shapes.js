/**
 * READ-ONLY PROBE — maps collection shapes & rough counts for PMF analysis.
 * Throwaway recon: confirms what data actually exists before we build the
 * full extractor. Touches nothing, writes nothing.
 *
 * Usage: node tests/probe_pmf_shapes.js
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serviceAccount = JSON.parse(
  readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8")
);
initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();
const auth = getAuth();
const HOLYCOW_USER_ID = "holycow_system_user";

const line = (s = "") => console.log(s);
const hr = () => line("=".repeat(70));

// Count a top-level collection (with a soft cap so we don't read forever).
async function countCollection(name, cap = 20000) {
  try {
    const snap = await db.collection(name).limit(cap).get();
    return snap.size + (snap.size === cap ? "+" : "");
  } catch (e) {
    return `ERR(${e.code || e.message})`;
  }
}

async function main() {
  hr();
  line("📡 PMF DATA PROBE — read-only recon");
  hr();

  // 1) Auth vs Firestore population
  line("\n1⃣  POPULATION");
  let authCount = "n/a";
  try {
    const authList = await auth.listUsers(1000);
    authCount = `${authList.users.length}${authList.pageToken ? "+ (more pages)" : ""}`;
  } catch (e) {
    authCount = `SKIPPED (${e.errorInfo?.code || e.code || "no auth-admin perm"})`;
  }
  const usersSnap = await db.collection("users").get();
  line(`   Firebase Auth users : ${authCount}`);
  line(`   Firestore users docs: ${usersSnap.size}`);

  // Profile completeness + activity hints from user docs
  let withAstro = 0, withAyur = 0, withPhone = 0, withStreak = 0, deleted = 0;
  const userFieldFreq = {};
  usersSnap.docs.forEach((d) => {
    const u = d.data();
    if (u.astrologyProfile) withAstro++;
    if (u.ayurvedaProfile) withAyur++;
    if (u.phoneNumber) withPhone++;
    if (u.insightStreak) withStreak++;
    if (u.isDeleted) deleted++;
    Object.keys(u).forEach((k) => (userFieldFreq[k] = (userFieldFreq[k] || 0) + 1));
  });
  line(`   → with astrologyProfile: ${withAstro}`);
  line(`   → with ayurvedaProfile : ${withAyur}`);
  line(`   → with phoneNumber     : ${withPhone}`);
  line(`   → with insightStreak   : ${withStreak}`);
  line(`   → flagged isDeleted    : ${deleted}`);

  // 2) Top-level collection counts
  line("\n2️⃣  COLLECTION COUNTS (top-level)");
  const collections = [
    "dmConversations", "spaceChats", "spaces", "posts", "globalFeed",
    "postReplies", "postLikes", "reposts", "notifications", "anonymousMessages",
    "shareLinks", "ai_chat_sessions", "calls", "deletedUsers", "phoneIndex",
  ];
  for (const c of collections) {
    line(`   ${c.padEnd(20)}: ${await countCollection(c)}`);
  }

  // 3) AI conversations specifically
  line("\n3️⃣  HOLYCOW AI CHATS");
  const dmSnap = await db.collection("dmConversations").get();
  let aiConvos = 0, humanConvos = 0;
  const aiConvoIds = [];
  dmSnap.docs.forEach((d) => {
    const data = d.data();
    const isAi = data.isAiConversation === true ||
      (Array.isArray(data.participants) && data.participants.includes(HOLYCOW_USER_ID));
    if (isAi) { aiConvos++; aiConvoIds.push(d.id); }
    else humanConvos++;
  });
  line(`   Total dmConversations : ${dmSnap.size}`);
  line(`   → AI (HolyCow) convos : ${aiConvos}`);
  line(`   → Human DM convos     : ${humanConvos}`);

  // Sample message volume across up to 25 AI convos
  let sampledConvos = 0, totalAiMsgs = 0, userMsgs = 0, voiceMsgs = 0;
  const sampleQuestions = [];
  for (const id of aiConvoIds.slice(0, 25)) {
    const msgs = await db.collection("dmConversations").doc(id)
      .collection("messages").get();
    sampledConvos++;
    msgs.docs.forEach((m) => {
      const md = m.data();
      totalAiMsgs++;
      if (md.senderId !== HOLYCOW_USER_ID) {
        userMsgs++;
        if (sampleQuestions.length < 15 && md.content) {
          sampleQuestions.push(String(md.content).slice(0, 120));
        }
      }
      if (md.isVoiceMessage) voiceMsgs++;
    });
  }
  line(`   Sampled ${sampledConvos} AI convos → ${totalAiMsgs} msgs (${userMsgs} from users, ${voiceMsgs} voice)`);

  // 4) Field shape of a sample AI message + conversation
  line("\n4️⃣  SHAPE SAMPLES");
  if (aiConvoIds.length) {
    const cdoc = await db.collection("dmConversations").doc(aiConvoIds[0]).get();
    line(`   dmConversation fields: ${Object.keys(cdoc.data()).join(", ")}`);
    const m = await db.collection("dmConversations").doc(aiConvoIds[0])
      .collection("messages").limit(1).get();
    if (!m.empty) line(`   message fields       : ${Object.keys(m.docs[0].data()).join(", ")}`);
  }
  // User doc field frequency (top 25 by presence)
  line("\n   user doc field presence (field: count):");
  Object.entries(userFieldFreq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 30)
    .forEach(([k, v]) => line(`     ${k.padEnd(24)}: ${v}`));

  // 5) Subcollection presence sample (per-user astro/health engagement)
  line("\n5️⃣  PER-USER SUBCOLLECTION PRESENCE (sample of 10 users)");
  const subs = ["dailyInsights", "favoriteInsights", "insightFeedback",
    "savedInsights", "healthSnapshots", "nadiReadings", "stories"];
  const tally = Object.fromEntries(subs.map((s) => [s, 0]));
  const sampleUsers = usersSnap.docs.slice(0, 10);
  for (const ud of sampleUsers) {
    for (const s of subs) {
      const snap = await db.collection(`users/${ud.id}/${s}`).limit(1).get();
      if (snap.size > 0) tally[s]++;
    }
  }
  subs.forEach((s) => line(`   ${s.padEnd(18)}: ${tally[s]}/10 users have data`));

  // 6) What are people asking? (raw sample — internal eyes only)
  line("\n6️⃣  SAMPLE USER QUESTIONS TO HOLYCOW (raw, internal)");
  sampleQuestions.forEach((q, i) => line(`   ${String(i + 1).padStart(2)}. ${q}`));

  hr();
  line("✅ Probe complete. Nothing was written.");
  hr();
}

main().then(() => process.exit(0)).catch((e) => {
  console.error("❌ Probe error:", e);
  process.exit(1);
});
