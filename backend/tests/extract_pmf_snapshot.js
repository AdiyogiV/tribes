/**
 * PMF SNAPSHOT EXTRACTOR — comprehensive behavioral export for internal analysis.
 *
 * Pulls a full per-user behavioral matrix, retention cohorts, and the complete
 * HolyCow question corpus from Firestore. CSV-first (analysis-ready) + a
 * summary.json. Internal eyes only — raw question text included on purpose.
 *
 * Read-only. Writes only to backend/analysis/*.csv|json locally.
 *
 * Usage: node tests/extract_pmf_snapshot.js
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
const HOLYCOW_USER_ID = "holycow_system_user";
const OUT = join(__dirname, "../analysis");
if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

const log = (s = "") => console.log(s);
const DAY = 24 * 60 * 60 * 1000;
const now = Date.now();

// ---------- helpers ----------
function csvCell(v) {
  if (v === null || v === undefined) return "";
  const s = String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}
function writeCsv(file, header, rows) {
  const out = [header.join(",")];
  for (const r of rows) out.push(r.map(csvCell).join(","));
  writeFileSync(join(OUT, file), out.join("\n"), "utf8");
  log(`   ✓ ${file} (${rows.length} rows)`);
}
function toMillis(ts) {
  if (!ts) return null;
  if (typeof ts === "number") return ts;
  if (ts.toMillis) return ts.toMillis();
  if (ts.seconds) return ts.seconds * 1000;
  if (ts._seconds) return ts._seconds * 1000;
  const d = new Date(ts);
  return isNaN(d) ? null : d.getTime();
}
function iso(ts) {
  const m = toMillis(ts);
  return m ? new Date(m).toISOString() : "";
}
function dayKey(ts) {
  const m = toMillis(ts);
  return m ? new Date(m).toISOString().slice(0, 10) : "";
}
// crude test-user filter (mirrors analyze_users_deep heuristics)
function isTestUser(name, uid, email) {
  const u = uid || "", n = name || "", e = email || "";
  return /test[-_]|^test$|debug|e2e[-_]|verification|-\d{13,}$/i.test(u) ||
    /^test$|^tester$|^debug/i.test(n) ||
    (e && /test|debug/i.test(e));
}

async function main() {
  log("=".repeat(70));
  log("📦 PMF SNAPSHOT EXTRACTOR");
  log("=".repeat(70));

  // ---------- 1. Auth metadata ----------
  log("\n1️⃣  Fetching Auth users...");
  const authMap = new Map();
  let page = await auth.listUsers(1000);
  while (true) {
    page.users.forEach((u) => authMap.set(u.uid, u));
    if (!page.pageToken) break;
    page = await auth.listUsers(1000, page.pageToken);
  }
  log(`   ${authMap.size} auth users`);

  // ---------- 2. User docs ----------
  log("\n2️⃣  Fetching Firestore user docs...");
  const usersSnap = await db.collection("users").get();
  log(`   ${usersSnap.size} user docs`);
  const users = new Map();
  usersSnap.docs.forEach((d) => users.set(d.id, d.data()));

  // ---------- 3. Walk all DM conversations (AI + human) ----------
  log("\n3️⃣  Walking conversations + messages (this is the slow part)...");
  const dmSnap = await db.collection("dmConversations").get();
  // per-user aggregates
  const agg = new Map(); // uid -> counters
  const ensure = (uid) => {
    if (!agg.has(uid)) agg.set(uid, {
      aiConvos: 0, aiUserMsgs: 0, aiVoiceMsgs: 0, aiCharsTyped: 0,
      humanConvos: 0, humanMsgs: 0,
      firstAiAt: null, lastAiAt: null,
    });
    return agg.get(uid);
  };

  const questionRows = [];   // every user->HolyCow message
  const convoRows = [];      // per AI conversation summary
  let processed = 0;

  for (const cdoc of dmSnap.docs) {
    const c = cdoc.data();
    const parts = Array.isArray(c.participants) ? c.participants : [];
    const isAi = c.isAiConversation === true || parts.includes(HOLYCOW_USER_ID);
    const humanUid = parts.find((p) => p !== HOLYCOW_USER_ID);

    const msgsSnap = await db.collection("dmConversations").doc(cdoc.id)
      .collection("messages").get();

    if (isAi) {
      const uid = humanUid || "unknown";
      const a = ensure(uid);
      a.aiConvos++;
      let userMsgCount = 0, firstQ = "", convoChars = 0;
      let cFirst = null, cLast = null;
      msgsSnap.docs.forEach((m) => {
        const md = m.data();
        const tms = toMillis(md.timestamp);
        if (md.senderId !== HOLYCOW_USER_ID) {
          userMsgCount++;
          const content = (md.content || "").toString();
          convoChars += content.length;
          a.aiUserMsgs++;
          a.aiCharsTyped += content.length;
          if (md.isVoiceMessage) a.aiVoiceMsgs++;
          if (!firstQ && content) firstQ = content;
          if (tms) { a.firstAiAt = a.firstAiAt ? Math.min(a.firstAiAt, tms) : tms;
                     a.lastAiAt = a.lastAiAt ? Math.max(a.lastAiAt, tms) : tms; }
          if (tms) { cFirst = cFirst ? Math.min(cFirst, tms) : tms;
                     cLast = cLast ? Math.max(cLast, tms) : tms; }
          questionRows.push([
            cdoc.id, uid, iso(md.timestamp), dayKey(md.timestamp),
            md.isVoiceMessage ? 1 : 0, content.length, content,
          ]);
        }
      });
      convoRows.push([
        cdoc.id, uid, iso(c.createdAt), msgsSnap.size, userMsgCount,
        convoChars, cFirst && cLast ? Math.round((cLast - cFirst) / 1000) : 0,
        firstQ,
      ]);
    } else {
      const uid = humanUid || parts[0] || "unknown";
      const a = ensure(uid);
      a.humanConvos++;
      a.humanMsgs += msgsSnap.docs.filter((m) => m.data().senderId === uid).length;
    }
    if (++processed % 100 === 0) log(`   ...${processed}/${dmSnap.size} convos`);
  }
  log(`   processed ${processed} conversations`);

  // ---------- 4. Posts per author ----------
  log("\n4️⃣  Counting posts per author...");
  const postsSnap = await db.collection("posts").get();
  const postCount = new Map();
  postsSnap.docs.forEach((p) => {
    const a = p.data().author;
    if (a) postCount.set(a, (postCount.get(a) || 0) + 1);
  });

  // ---------- 5. Per-user subcollection presence (dailyInsights) ----------
  log("\n5️⃣  Sampling per-user astro engagement (dailyInsights counts)...");
  const insightCount = new Map();
  let ui = 0;
  for (const uid of users.keys()) {
    try {
      const s = await db.collection(`users/${uid}/dailyInsights`).get();
      if (s.size) insightCount.set(uid, s.size);
    } catch (_) {}
    if (++ui % 50 === 0) log(`   ...${ui}/${users.size} users scanned`);
  }

  // ---------- 6. Build per-user matrix ----------
  log("\n6️⃣  Building per-user matrix...");
  const userRows = [];
  const allUids = new Set([...authMap.keys(), ...users.keys()]);
  let real = 0, test = 0;
  for (const uid of allUids) {
    const au = authMap.get(uid);
    const u = users.get(uid) || {};
    const name = au?.displayName || u.name || "";
    const email = au?.email || u.email || "";
    const test_ = isTestUser(name, uid, email);
    if (test_) test++; else real++;
    const a = agg.get(uid) || {};
    const created = au?.metadata?.creationTime || iso(u.timestamp);
    const lastSignIn = au?.metadata?.lastSignInTime || "";
    const createdMs = au ? new Date(au.metadata.creationTime).getTime() : toMillis(u.timestamp);
    const lastMs = au?.metadata?.lastSignInTime ? new Date(au.metadata.lastSignInTime).getTime() : null;
    userRows.push([
      uid, name, email, au?.phoneNumber || u.phoneNumber || "",
      test_ ? 1 : 0,
      created, lastSignIn,
      createdMs ? Math.floor((now - createdMs) / DAY) : "",          // age days
      lastMs && createdMs ? Math.floor((lastMs - createdMs) / DAY) : "", // lifespan days
      !!au ? 1 : 0, users.has(uid) ? 1 : 0,
      u.astrologyData ? 1 : 0, u.ayurvedaData ? 1 : 0,
      u.ftueCompleted ? 1 : 0,
      u.auraScore || 0, u.followerCount || 0, u.followingCount || 0,
      postCount.get(uid) || 0,
      a.aiConvos || 0, a.aiUserMsgs || 0, a.aiVoiceMsgs || 0, a.aiCharsTyped || 0,
      a.humanConvos || 0, a.humanMsgs || 0,
      insightCount.get(uid) || 0,
      a.firstAiAt ? new Date(a.firstAiAt).toISOString() : "",
      a.lastAiAt ? new Date(a.lastAiAt).toISOString() : "",
    ]);
  }

  writeCsv("users.csv", [
    "uid", "name", "email", "phone", "is_test",
    "auth_created", "last_sign_in", "age_days", "lifespan_days",
    "in_auth", "in_firestore",
    "has_astro", "has_ayurveda", "ftue_completed",
    "aura_score", "followers", "following", "posts",
    "ai_convos", "ai_user_msgs", "ai_voice_msgs", "ai_chars_typed",
    "human_convos", "human_msgs", "daily_insights",
    "first_ai_at", "last_ai_at",
  ], userRows);

  writeCsv("holycow_messages.csv",
    ["convo_id", "uid", "timestamp", "day", "is_voice", "char_len", "content"],
    questionRows);

  writeCsv("holycow_conversations.csv",
    ["convo_id", "uid", "created", "total_msgs", "user_msgs", "user_chars",
     "span_seconds", "first_question"],
    convoRows);

  // ---------- 7. Retention cohorts (from auth dates) ----------
  log("\n7️⃣  Computing retention cohorts...");
  const cohortRows = [];
  const realUsers = userRows.filter((r) => r[4] === 0 && r[5]); // not test, has created
  // bucket by signup week
  const buckets = new Map();
  for (const r of realUsers) {
    const createdMs = new Date(r[5]).getTime();
    const lastMs = r[6] ? new Date(r[6]).getTime() : null;
    if (!createdMs) continue;
    const wk = new Date(createdMs).toISOString().slice(0, 10);
    if (!buckets.has(wk)) buckets.set(wk, { n: 0, d1: 0, d7: 0, d30: 0 });
    const b = buckets.get(wk);
    b.n++;
    if (lastMs) {
      const life = lastMs - createdMs;
      if (life >= 1 * DAY) b.d1++;
      if (life >= 7 * DAY) b.d7++;
      if (life >= 30 * DAY) b.d30++;
    }
  }
  [...buckets.entries()].sort().forEach(([wk, b]) => {
    cohortRows.push([wk, b.n,
      b.d1, (100 * b.d1 / b.n).toFixed(1),
      b.d7, (100 * b.d7 / b.n).toFixed(1),
      b.d30, (100 * b.d30 / b.n).toFixed(1)]);
  });
  writeCsv("retention_cohorts.csv",
    ["signup_day", "users", "ret_d1", "ret_d1_pct", "ret_d7", "ret_d7_pct",
     "ret_d30", "ret_d30_pct"], cohortRows);

  // ---------- 8. Daily HolyCow activity ----------
  log("\n8️⃣  Daily HolyCow activity...");
  const byDay = new Map();
  for (const q of questionRows) {
    const d = q[3];
    if (!d) continue;
    if (!byDay.has(d)) byDay.set(d, { msgs: 0, users: new Set() });
    const e = byDay.get(d);
    e.msgs++; e.users.add(q[1]);
  }
  const dailyRows = [...byDay.entries()].sort()
    .map(([d, e]) => [d, e.msgs, e.users.size]);
  writeCsv("holycow_daily.csv", ["day", "user_msgs", "active_users"], dailyRows);

  // ---------- 9. Summary JSON ----------
  log("\n9️⃣  Summary...");
  const realRows = userRows.filter((r) => r[4] === 0);
  const sum = (idx, rows) => rows.reduce((s, r) => s + (Number(r[idx]) || 0), 0);
  const withAi = realRows.filter((r) => Number(r[18]) > 0).length;
  const summary = {
    generatedAt: new Date().toISOString(),
    population: {
      authUsers: authMap.size,
      firestoreUsers: users.size,
      realUsers: real,
      testUsers: test,
      withAstroData: sum(11, realRows),
      withAyurvedaData: sum(12, realRows),
      ftueCompleted: sum(13, realRows),
      ftueCompletionPct: (100 * sum(13, realRows) / real).toFixed(1),
    },
    holycow: {
      aiConversations: sum(18, realRows),
      aiUserMessages: sum(19, realRows),
      voiceMessages: sum(20, realRows),
      usersWhoUsedAi: withAi,
      aiAdoptionPct: (100 * withAi / real).toFixed(1),
      avgMsgsPerActiveUser: (sum(19, realRows) / Math.max(withAi, 1)).toFixed(1),
      avgMsgsPerConvo: (sum(19, realRows) / Math.max(sum(18, realRows), 1)).toFixed(2),
    },
    social: {
      humanConvos: sum(21, realRows),
      humanMsgs: sum(22, realRows),
      totalPosts: sum(17, realRows),
      usersWhoPosted: realRows.filter((r) => Number(r[17]) > 0).length,
    },
    files: ["users.csv", "holycow_messages.csv", "holycow_conversations.csv",
      "retention_cohorts.csv", "holycow_daily.csv", "summary.json"],
  };
  writeFileSync(join(OUT, "summary.json"), JSON.stringify(summary, null, 2));
  log(`   ✓ summary.json`);

  log("\n" + "=".repeat(70));
  log("✅ EXTRACTION COMPLETE — backend/analysis/");
  log("=".repeat(70));
  log(JSON.stringify(summary, null, 2));
}

main().then(() => process.exit(0)).catch((e) => {
  console.error("❌ Extraction error:", e);
  process.exit(1);
});
