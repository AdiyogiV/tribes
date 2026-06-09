/**
 * DEEP ENGAGEMENT EXTRACT — who these people are + every derivable metric.
 *
 * Builds a master per-user behavioral matrix from COLLECTION-LEVEL reads only
 * (users, posts, globalFeed, calls, reposts, spaces, notifications, and
 * dmConversations *doc metadata* — NO message-subcollection walk, so it does
 * not contend with the long-running extract_pmf_snapshot job).
 *
 * Real Firestore field names (verified via probe_engagement_shapes.js):
 *   users:    followerCount, followingCount, auraScore, ftueCompleted,
 *             astrologyData, ayurvedaData, nickname, bio/description,
 *             anonymousLinkSlug, isPrivateProfile, fcmTokens, personalFarmId,
 *             lastStoryExpiresAt, name, phoneNumber, timestamp, isAi
 *   posts:    author, title, video, thumbnail, replyCount, replyTo, space
 *   globalFeed: author, spaceId, title, timestamp
 *   calls:    callerId, calleeId, status(ended|missed|rejected), type(video|voice),
 *             createdAt, answeredAt, endedAt
 *   reposts:  reposterId, originalAuthorId, timestamp
 *   spaces:   creatorId, name, spaceType, lastPostAt
 *   notifications: <docId=uid> count
 *   dmConversations: participants[], isAiConversation, lastActivity, createdAt
 *
 * Read-only. Writes backend/analysis/engagement/*.csv|json.
 * Usage: node tests/extract_engagement_deep.js
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

const OUT = join(__dirname, "../analysis/engagement");
if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });
const AI_UID = "holycow_system_user";
const DAY = 24 * 60 * 60 * 1000;
const now = Date.now();
const log = (s = "") => console.log(s);

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
  log(`   wrote ${file} (${rows.length} rows)`);
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
function isTestUser(name, uid, email) {
  const u = uid || "", n = name || "", e = email || "";
  const uidPat = [
    /test[-_]/i, /^test$/i, /debug/i, /timing[-_]test/i, /speed[-_]test/i,
    /performance/i, /e2e[-_]/i, /end[-_]to[-_]end/i, /verification/i,
    /comparison/i, /^simple[-_]/i, /^final[-_]/i, /^fast[-_]/i,
    /firestore[-_]test/i, /user[-_]test/i, /-\d{13,}$/,
  ];
  const namePat = [/^test$/i, /^tester$/i, /^debug/i, /^test\s/i];
  if (uidPat.some((p) => p.test(u))) return true;
  if (namePat.some((p) => p.test(n))) return true;
  if (e && (e.includes("test") || e.includes("debug"))) return true;
  return false;
}
const daysAgo = (ms) => (ms ? Math.floor((now - ms) / DAY) : "");

async function main() {
  log("=".repeat(72));
  log(" DEEP ENGAGEMENT EXTRACT");
  log("=".repeat(72));

  // ---------- parallel fetch ----------
  log("\nFetching all collections in parallel (no message walk)...");
  async function allAuthUsers() {
    const map = new Map();
    let page = await auth.listUsers(1000);
    while (true) {
      page.users.forEach((u) => map.set(u.uid, u));
      if (!page.pageToken) break;
      page = await auth.listUsers(1000, page.pageToken);
    }
    return map;
  }
  const [
    authMap, usersSnap, postsSnap, feedSnap, callsSnap,
    repostsSnap, spacesSnap, notifSnap, dmSnap,
  ] = await Promise.all([
    allAuthUsers(),
    db.collection("users").get(),
    db.collection("posts").get(),
    db.collection("globalFeed").get(),
    db.collection("calls").get(),
    db.collection("reposts").get(),
    db.collection("spaces").get(),
    db.collection("notifications").get(),
    db.collection("dmConversations").get(),
  ]);

  const fsUsers = new Map();
  usersSnap.docs.forEach((d) => fsUsers.set(d.id, d.data()));
  log(`   auth=${authMap.size} users=${fsUsers.size} posts=${postsSnap.size} ` +
      `feed=${feedSnap.size} calls=${callsSnap.size} reposts=${repostsSnap.size} ` +
      `spaces=${spacesSnap.size} notif=${notifSnap.size} dm=${dmSnap.size}`);

  // ---------- per-user accumulator ----------
  const M = new Map();
  const acc = (uid) => {
    if (!uid) return null;
    if (!M.has(uid)) M.set(uid, {
      postsTotal: 0, postsOriginal: 0, postsReplies: 0, postsVideo: 0,
      repliesReceived: 0, feedPosts: 0, spacesCreated: 0,
      repostsMade: 0, repostsReceived: 0,
      aiConvos: 0, aiLast: null, humanConvos: 0, humanLast: null,
      humanPartners: new Set(),
      callsMade: 0, callsReceived: 0, callsAnswered: 0, callsMissed: 0,
      callsRejected: 0, videoCalls: 0, voiceCalls: 0, talkSec: 0,
      callPartners: new Set(), notifCount: 0,
    });
    return M.get(uid);
  };

  // posts
  postsSnap.docs.forEach((d) => {
    const p = d.data();
    const a = acc(p.author);
    if (!a) return;
    a.postsTotal++;
    if (p.replyTo) a.postsReplies++; else a.postsOriginal++;
    if (p.video) a.postsVideo++;
    a.repliesReceived += Number(p.replyCount) || 0;
  });
  // global feed
  feedSnap.docs.forEach((d) => {
    const f = d.data();
    const a = acc(f.author);
    if (a) a.feedPosts++;
  });
  // spaces
  spacesSnap.docs.forEach((d) => {
    const s = d.data();
    const a = acc(s.creatorId);
    if (a) a.spacesCreated++;
  });
  // reposts
  repostsSnap.docs.forEach((d) => {
    const r = d.data();
    const rep = acc(r.reposterId);
    if (rep) rep.repostsMade++;
    const orig = acc(r.originalAuthorId);
    if (orig) orig.repostsReceived++;
  });
  // calls
  callsSnap.docs.forEach((d) => {
    const c = d.data();
    const caller = acc(c.callerId);
    const callee = acc(c.calleeId);
    const ans = toMillis(c.answeredAt);
    const end = toMillis(c.endedAt);
    const dur = ans && end && end > ans ? Math.round((end - ans) / 1000) : 0;
    if (caller) {
      caller.callsMade++;
      if (c.type === "video") caller.videoCalls++; else caller.voiceCalls++;
      if (c.status === "ended") { caller.callsAnswered++; caller.talkSec += dur; }
      if (c.calleeId) caller.callPartners.add(c.calleeId);
    }
    if (callee) {
      caller && (void 0);
      callee.callsReceived++;
      if (c.status === "ended") { callee.callsAnswered++; callee.talkSec += dur; }
      else if (c.status === "missed") callee.callsMissed++;
      else if (c.status === "rejected") callee.callsRejected++;
      if (c.callerId) callee.callPartners.add(c.callerId);
    }
  });
  // dm conversations (doc-level only)
  dmSnap.docs.forEach((d) => {
    const c = d.data();
    const parts = Array.isArray(c.participants) ? c.participants : [];
    const isAi = c.isAiConversation === true || parts.includes(AI_UID);
    const last = toMillis(c.lastActivity) || toMillis(c.createdAt);
    if (isAi) {
      const uid = parts.find((p) => p !== AI_UID);
      const a = acc(uid);
      if (a) { a.aiConvos++; a.aiLast = a.aiLast ? Math.max(a.aiLast, last) : last; }
    } else {
      parts.forEach((uid) => {
        const a = acc(uid);
        if (!a) return;
        a.humanConvos++;
        a.humanLast = a.humanLast ? Math.max(a.humanLast, last) : last;
        parts.filter((x) => x !== uid).forEach((x) => a.humanPartners.add(x));
      });
    }
  });
  // notifications (docId == uid)
  notifSnap.docs.forEach((d) => {
    const a = acc(d.id);
    if (a) a.notifCount = Number(d.data().count) || 0;
  });

  // ---------- build master rows ----------
  log("\nBuilding master matrix...");
  const allUids = new Set([
    ...authMap.keys(), ...fsUsers.keys(), ...M.keys(),
  ]);
  const HEADER = [
    "uid", "name", "phone", "class",
    "created", "last_sign_in", "tenure_days", "last_seen_days", "one_and_done",
    "in_auth", "in_firestore", "profile_complete", "ftue_completed",
    "has_astro", "has_ayurveda", "has_nickname", "has_bio", "has_anon_link",
    "is_private", "has_push", "has_story", "has_farm",
    "aura_score", "followers", "following", "follower_following_ratio",
    "posts_total", "posts_original", "posts_replies", "posts_with_video",
    "replies_received", "feed_posts", "spaces_created",
    "reposts_made", "reposts_received",
    "ai_convos", "ai_last_activity_days",
    "human_convos", "human_dm_partners", "human_last_activity_days",
    "calls_made", "calls_received", "calls_answered", "calls_missed",
    "calls_rejected", "call_partners", "talk_time_sec", "video_calls",
    "voice_calls", "notif_count",
    "engagement_received", "content_score", "comm_score", "total_engagement",
  ];

  const rows = [];
  let real = 0, test = 0, system = 0;
  for (const uid of allUids) {
    const au = authMap.get(uid);
    const u = fsUsers.get(uid) || {};
    const a = M.get(uid) || acc("__tmp__"); // never null
    const name = au?.displayName || u.name || u.nickname || "";
    const email = au?.email || u.email || "";
    const phone = au?.phoneNumber || u.phoneNumber || "";
    const isSystem = uid === AI_UID || u.isAi === true;
    const isTest = !isSystem && isTestUser(name, uid, email);
    const klass = isSystem ? "system" : isTest ? "test" : "real";
    if (isSystem) system++; else if (isTest) test++; else real++;

    const createdMs = au ? new Date(au.metadata.creationTime).getTime() : toMillis(u.timestamp);
    const lastMs = au?.metadata?.lastSignInTime ? new Date(au.metadata.lastSignInTime).getTime() : null;
    const tenure = createdMs ? Math.floor((now - createdMs) / DAY) : "";
    const lastSeen = lastMs ? Math.floor((now - lastMs) / DAY) : "";
    const oneAndDone = lastMs && createdMs ? (lastMs - createdMs < DAY ? 1 : 0) : "";

    const followers = u.followerCount || 0;
    const following = u.followingCount || 0;
    const ratio = following > 0 ? (followers / following).toFixed(2) : (followers > 0 ? followers : 0);

    const engReceived = followers + a.repliesReceived * 2 + a.repostsReceived * 3;
    const contentScore = a.postsOriginal * 3 + a.postsReplies + a.feedPosts * 2 + a.spacesCreated * 2;
    const commScore = a.aiConvos + a.humanConvos * 2 + a.callsAnswered * 2 + Math.round(a.talkSec / 60);
    const totalEng = engReceived + contentScore + commScore;

    rows.push([
      uid, name, phone, klass,
      au?.metadata?.creationTime || (createdMs ? new Date(createdMs).toISOString() : ""),
      au?.metadata?.lastSignInTime || "",
      tenure, lastSeen, oneAndDone,
      au ? 1 : 0, fsUsers.has(uid) ? 1 : 0,
      (name && phone) ? 1 : 0, u.ftueCompleted ? 1 : 0,
      u.astrologyData ? 1 : 0, u.ayurvedaData ? 1 : 0,
      u.nickname ? 1 : 0, (u.bio || u.description) ? 1 : 0, u.anonymousLinkSlug ? 1 : 0,
      u.isPrivateProfile ? 1 : 0,
      (u.fcmTokens || u.fcmToken) ? 1 : 0, u.lastStoryExpiresAt ? 1 : 0, u.personalFarmId ? 1 : 0,
      u.auraScore || 0, followers, following, ratio,
      a.postsTotal, a.postsOriginal, a.postsReplies, a.postsVideo,
      a.repliesReceived, a.feedPosts, a.spacesCreated,
      a.repostsMade, a.repostsReceived,
      a.aiConvos, daysAgo(a.aiLast),
      a.humanConvos, a.humanPartners.size, daysAgo(a.humanLast),
      a.callsMade, a.callsReceived, a.callsAnswered, a.callsMissed,
      a.callsRejected, a.callPartners.size, a.talkSec, a.videoCalls,
      a.voiceCalls, a.notifCount,
      engReceived, contentScore, commScore, totalEng,
    ]);
  }
  M.delete("__tmp__");

  // sort by total engagement desc
  const idx = (k) => HEADER.indexOf(k);
  rows.sort((x, y) => Number(y[idx("total_engagement")]) - Number(x[idx("total_engagement")]));

  writeCsv("user_engagement_full.csv", HEADER, rows);
  const realRows = rows.filter((r) => r[idx("class")] === "real");
  writeCsv("real_users_engagement.csv", HEADER, realRows);

  // ---------- leaderboards ----------
  const lb = (sortKey, cols) => [...realRows]
    .filter((r) => Number(r[idx(sortKey)]) > 0)
    .sort((a, b) => Number(b[idx(sortKey)]) - Number(a[idx(sortKey)]))
    .slice(0, 30)
    .map((r) => cols.map((c) => r[idx(c)]));

  writeCsv("leaderboard_followers.csv",
    ["uid", "name", "followers", "following", "follower_following_ratio", "total_engagement"],
    lb("followers", ["uid", "name", "followers", "following", "follower_following_ratio", "total_engagement"]));
  writeCsv("leaderboard_engagement.csv",
    ["uid", "name", "total_engagement", "engagement_received", "content_score", "comm_score", "followers"],
    lb("total_engagement", ["uid", "name", "total_engagement", "engagement_received", "content_score", "comm_score", "followers"]));
  writeCsv("leaderboard_creators.csv",
    ["uid", "name", "posts_total", "posts_original", "feed_posts", "replies_received", "spaces_created"],
    lb("content_score", ["uid", "name", "posts_total", "posts_original", "feed_posts", "replies_received", "spaces_created"]));
  writeCsv("leaderboard_callers.csv",
    ["uid", "name", "calls_made", "calls_received", "calls_answered", "talk_time_sec", "call_partners", "video_calls", "voice_calls"],
    lb("talk_time_sec", ["uid", "name", "calls_made", "calls_received", "calls_answered", "talk_time_sec", "call_partners", "video_calls", "voice_calls"]));
  writeCsv("leaderboard_ai_users.csv",
    ["uid", "name", "ai_convos", "ai_last_activity_days", "has_astro", "has_ayurveda", "aura_score"],
    lb("ai_convos", ["uid", "name", "ai_convos", "ai_last_activity_days", "has_astro", "has_ayurveda", "aura_score"]));

  // ---------- aggregate summary ----------
  const sum = (k, rs = realRows) => rs.reduce((s, r) => s + (Number(r[idx(k)]) || 0), 0);
  const cnt = (k, rs = realRows) => rs.filter((r) => Number(r[idx(k)]) > 0).length;
  const totalTalk = sum("talk_time_sec");
  const summary = {
    generatedAt: new Date().toISOString(),
    population: { real, test, system, totalAccounts: rows.length },
    socialGraph: {
      usersWithFollowers: cnt("followers"),
      totalFollowerEdges: sum("followers"),
      usersFollowingSomeone: cnt("following"),
      maxFollowers: Math.max(...realRows.map((r) => Number(r[idx("followers")]) || 0)),
    },
    content: {
      usersWhoPosted: cnt("posts_total"),
      totalPosts: sum("posts_total"),
      originalPosts: sum("posts_original"),
      replyPosts: sum("posts_replies"),
      videoPosts: sum("posts_with_video"),
      totalRepliesReceived: sum("replies_received"),
      feedPosts: sum("feed_posts"),
      spacesCreated: sum("spaces_created"),
      reposts: sum("reposts_made"),
    },
    calls: {
      usersWhoCalled: cnt("calls_made"),
      usersWhoReceivedCalls: cnt("calls_received"),
      totalCallsAnswered: sum("calls_answered"),
      totalCallsMissed: sum("calls_missed"),
      totalCallsRejected: sum("calls_rejected"),
      totalTalkTimeMin: Math.round(totalTalk / 60),
      videoCalls: sum("video_calls"),
      voiceCalls: sum("voice_calls"),
    },
    messaging: {
      usersWithAiConvos: cnt("ai_convos"),
      totalAiConvos: sum("ai_convos"),
      usersWithHumanDMs: cnt("human_convos"),
      totalHumanConvos: sum("human_convos"),
    },
    activation: {
      ftueCompleted: cnt("ftue_completed"),
      hasAstro: cnt("has_astro"),
      hasAyurveda: cnt("has_ayurveda"),
      hasPushEnabled: cnt("has_push"),
      hasAnonLink: cnt("has_anon_link"),
      postedStory: cnt("has_story"),
      hasFarm: cnt("has_farm"),
    },
    files: [
      "user_engagement_full.csv", "real_users_engagement.csv",
      "leaderboard_followers.csv", "leaderboard_engagement.csv",
      "leaderboard_creators.csv", "leaderboard_callers.csv",
      "leaderboard_ai_users.csv", "summary.json",
    ],
  };
  writeFileSync(join(OUT, "summary.json"), JSON.stringify(summary, null, 2));
  log("   wrote summary.json");

  log("\n" + "=".repeat(72));
  log(" DONE — backend/analysis/engagement/");
  log("=".repeat(72));
  log(JSON.stringify(summary, null, 2));
}

main().then(() => process.exit(0)).catch((e) => { console.error("Error:", e); process.exit(1); });
