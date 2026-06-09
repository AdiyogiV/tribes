/**
 * ACTUAL-USER RESEARCH — corrected, deep, FAST.
 *
 * Reconciles the four populations (Auth ⨯ Firestore users ⨯ deletedUsers ⨯
 * phoneIndex), strips test + AI/system accounts, and profiles the *real* humans:
 * activity recency, profile completeness, astro/ayurveda activation, social graph.
 *
 * Uses the REAL Firestore field names (the old analyze_users_deep.js read
 * astrologyProfile/followers/createdAt which don't exist — they're
 * astrologyData/followerCount/timestamp). Pure collection-level reads + parallel
 * fetches — no slow per-user subcollection walk. Finishes in seconds.
 *
 * Read-only. Writes to backend/analysis/user_research/*.csv|json.
 *
 * Usage: node tests/research_actual_users.js
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
const OUT = join(__dirname, "../analysis/user_research");
if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

const AI_UID = "holycow_system_user";
const DAY = 24 * 60 * 60 * 1000;
const now = Date.now();
const log = (s = "") => console.log(s);

// ---------- csv helpers ----------
function csvCell(v) {
  if (v === null || v === undefined) return "";
  const s = String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}
function writeCsv(file, header, rows) {
  const out = [header.join(",")];
  for (const r of rows) out.push(r.map(csvCell).join(","));
  writeFileSync(join(OUT, file), out.join("\n"), "utf8");
  log(`    ${file} (${rows.length} rows)`);
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

// ---------- test/system classification ----------
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

async function main() {
  log("=".repeat(72));
  log(" ACTUAL-USER RESEARCH (corrected schema, fast)");
  log("=".repeat(72));

  // ---------- parallel fetch of every population ----------
  log("\n Fetching Auth + Firestore populations in parallel...");
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
  const [authMap, usersSnap, deletedSnap, phoneSnap] = await Promise.all([
    allAuthUsers(),
    db.collection("users").get(),
    db.collection("deletedUsers").get(),
    db.collection("phoneIndex").get(),
  ]);

  const fsUsers = new Map();
  usersSnap.docs.forEach((d) => fsUsers.set(d.id, d.data()));

  log(`   Auth users        : ${authMap.size}`);
  log(`   Firestore users   : ${fsUsers.size}`);
  log(`   deletedUsers      : ${deletedSnap.size}`);
  log(`   phoneIndex entries: ${phoneSnap.size}`);

  // ---------- reconcile ----------
  const allUids = new Set([...authMap.keys(), ...fsUsers.keys()]);
  let complete = 0, authOnly = 0, fsOnly = 0;
  let real = 0, test = 0, system = 0;

  const rows = [];
  const realRows = [];
  for (const uid of allUids) {
    const au = authMap.get(uid);
    const u = fsUsers.get(uid) || {};
    const name = au?.displayName || u.name || u.nickname || "";
    const email = au?.email || u.email || "";
    const phone = au?.phoneNumber || u.phoneNumber || "";

    const inAuth = !!au;
    const inFs = fsUsers.has(uid);
    if (inAuth && inFs) complete++;
    else if (inAuth) authOnly++;
    else fsOnly++;

    const isSystem = uid === AI_UID || u.isAi === true;
    const isTest = !isSystem && isTestUser(name, uid, email);
    if (isSystem) system++;
    else if (isTest) test++;
    else real++;

    // timestamps — Auth is the source of truth for created/last-seen
    const createdMs = au
      ? new Date(au.metadata.creationTime).getTime()
      : toMillis(u.timestamp);
    const lastMs = au?.metadata?.lastSignInTime
      ? new Date(au.metadata.lastSignInTime).getTime()
      : null;
    const ageDays = createdMs ? Math.floor((now - createdMs) / DAY) : "";
    const lastSeenDays = lastMs ? Math.floor((now - lastMs) / DAY) : "";
    const neverReturned =
      lastMs && createdMs ? (lastMs - createdMs < DAY ? 1 : 0) : "";

    // CORRECT field names
    const hasAstro = u.astrologyData ? 1 : 0;
    const hasAyur = u.ayurvedaData ? 1 : 0;
    const ftue = u.ftueCompleted ? 1 : 0;
    const profileComplete = name && phone ? 1 : 0;
    const aura = u.auraScore || 0;
    const followers = u.followerCount || 0;
    const following = u.followingCount || 0;
    const hasBio = (u.bio || u.description) ? 1 : 0;
    const hasNickname = u.nickname ? 1 : 0;
    const hasAnonLink = u.anonymousLinkSlug ? 1 : 0;
    const isPrivate = u.isPrivateProfile ? 1 : 0;

    const klass = isSystem ? "system" : isTest ? "test" : "real";
    const row = [
      uid, name, phone, email, klass,
      inAuth ? 1 : 0, inFs ? 1 : 0,
      au?.metadata?.creationTime || (createdMs ? new Date(createdMs).toISOString() : ""),
      au?.metadata?.lastSignInTime || "",
      ageDays, lastSeenDays, neverReturned,
      profileComplete, ftue, hasAstro, hasAyur,
      hasNickname, hasBio, hasAnonLink, isPrivate,
      aura, followers, following,
    ];
    rows.push(row);
    if (klass === "real") realRows.push(row);
  }

  // ---------- write full roster + clean real roster ----------
  log("\n Writing rosters...");
  const HEADER = [
    "uid", "name", "phone", "email", "class",
    "in_auth", "in_firestore", "created", "last_sign_in",
    "age_days", "last_seen_days", "never_returned",
    "profile_complete", "ftue_completed", "has_astro", "has_ayurveda",
    "has_nickname", "has_bio", "has_anon_link", "is_private",
    "aura_score", "followers", "following",
  ];
  writeCsv("all_accounts.csv", HEADER, rows);
  writeCsv("real_users.csv", HEADER, realRows);

  // ---------- segment the real users ----------
  const num = (r, k) => Number(r[HEADER.indexOf(k)]) || 0;
  const active7 = realRows.filter((r) => num(r, "last_seen_days") <= 7 && r[HEADER.indexOf("last_sign_in")]);
  const active30 = realRows.filter((r) => num(r, "last_seen_days") <= 30 && r[HEADER.indexOf("last_sign_in")]);
  const dormant = realRows.filter((r) => num(r, "last_seen_days") > 30);
  const oneAndDone = realRows.filter((r) => r[HEADER.indexOf("never_returned")] === 1);

  const withAstro = realRows.filter((r) => num(r, "has_astro")).length;
  const withAyur = realRows.filter((r) => num(r, "has_ayurveda")).length;
  const ftueDone = realRows.filter((r) => num(r, "ftue_completed")).length;
  const profileDone = realRows.filter((r) => num(r, "profile_complete")).length;
  const withFollowers = realRows.filter((r) => num(r, "followers") > 0).length;

  // top users by aura
  const topAura = [...realRows]
    .sort((a, b) => num(b, "aura_score") - num(a, "aura_score"))
    .slice(0, 15)
    .map((r) => [r[0], r[1], num(r, "aura_score"), num(r, "followers"), num(r, "following")]);
  writeCsv("top_users_by_aura.csv",
    ["uid", "name", "aura_score", "followers", "following"], topAura);

  // signup-by-month cohort (real users)
  const byMonth = new Map();
  for (const r of realRows) {
    const c = r[HEADER.indexOf("created")];
    if (!c) continue;
    const mo = c.slice(0, 7);
    if (!byMonth.has(mo)) byMonth.set(mo, { n: 0, ret: 0 });
    const b = byMonth.get(mo);
    b.n++;
    if (num(r, "last_seen_days") <= 30) b.ret++; // still active in last 30d
  }
  const cohortRows = [...byMonth.entries()].sort().map(([mo, b]) => [
    mo, b.n, b.ret, ((100 * b.ret) / b.n).toFixed(1),
  ]);
  writeCsv("signup_cohorts_by_month.csv",
    ["signup_month", "real_users", "still_active_30d", "retained_pct"], cohortRows);

  // ---------- summary ----------
  const everRegistered = phoneSnap.size; // best proxy for cumulative humans
  const summary = {
    generatedAt: new Date().toISOString(),
    reconciliation: {
      authUsers: authMap.size,
      firestoreUserDocs: fsUsers.size,
      deletedUsers: deletedSnap.size,
      phoneIndexEntries: phoneSnap.size,
      complete_authAndFirestore: complete,
      authOnly_incompleteSignup: authOnly,
      firestoreOnly_orphanedDocs: fsOnly,
    },
    classification: {
      realUsers: real,
      testUsers: test,
      systemOrAiAccounts: system,
    },
    realUserActivity: {
      total: real,
      active_last_7d: active7.length,
      active_last_30d: active30.length,
      dormant_over_30d: dormant.length,
      one_and_done_neverReturned: oneAndDone.length,
      pct_active_30d: ((100 * active30.length) / Math.max(real, 1)).toFixed(1),
      pct_one_and_done: ((100 * oneAndDone.length) / Math.max(real, 1)).toFixed(1),
    },
    realUserActivation: {
      profileComplete: profileDone,
      profileCompletePct: ((100 * profileDone) / Math.max(real, 1)).toFixed(1),
      ftueCompleted: ftueDone,
      ftueCompletedPct: ((100 * ftueDone) / Math.max(real, 1)).toFixed(1),
      hasAstrologyData: withAstro,
      astroPct: ((100 * withAstro) / Math.max(real, 1)).toFixed(1),
      hasAyurvedaData: withAyur,
      ayurvedaPct: ((100 * withAyur) / Math.max(real, 1)).toFixed(1),
      hasFollowers: withFollowers,
    },
    populationStory: {
      everRegistered_phoneIndex: everRegistered,
      currentlyLoginable_auth: authMap.size,
      churnedOut: everRegistered - authMap.size,
      realActiveHumans_30d: active30.length,
    },
    files: [
      "all_accounts.csv", "real_users.csv", "top_users_by_aura.csv",
      "signup_cohorts_by_month.csv", "summary.json",
    ],
  };
  writeFileSync(join(OUT, "summary.json"), JSON.stringify(summary, null, 2));
  log("    summary.json");

  log("\n" + "=".repeat(72));
  log(" DONE — backend/analysis/user_research/");
  log("=".repeat(72));
  log(JSON.stringify(summary, null, 2));
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(" Error:", e);
  process.exit(1);
});
