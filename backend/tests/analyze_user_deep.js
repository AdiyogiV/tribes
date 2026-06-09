/**
 * DEEP single-user analysis: every activity signal + full two-sided transcripts.
 * Read-only. Usage: node tests/analyze_user_deep.js <uid>
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
const UID = process.argv[2];
const log = (s = "") => console.log(s);
const now = Date.now();
const DAY = 86400000;

function tms(ts) {
  if (!ts) return null;
  if (typeof ts === "number") return ts;
  if (ts.toMillis) return ts.toMillis();
  if (ts.seconds) return ts.seconds * 1000;
  if (ts._seconds) return ts._seconds * 1000;
  if (typeof ts === "string") { const d = new Date(ts); return isNaN(d) ? null : d.getTime(); }
  return null;
}
const iso = (ts) => { const m = tms(ts); return m ? new Date(m).toISOString() : ""; };
const ago = (ms) => (ms ? Math.floor((now - ms) / DAY) + "d ago" : "n/a");

async function main() {
  log("=".repeat(72));
  log(" DEEP ACTIVITY ANALYSIS: " + UID);
  log("=".repeat(72));

  // ---- recency signals ----
  const au = await auth.getUser(UID).catch(() => null);
  const udoc = await db.collection("users").doc(UID).get();
  const u = udoc.exists ? udoc.data() : {};

  const signals = [];
  if (au) {
    signals.push(["Auth account created", tms(au.metadata.creationTime), false]);
    signals.push(["Auth last sign-in", tms(au.metadata.lastSignInTime), true]);
    signals.push(["Auth last token REFRESH (app opened)", tms(au.metadata.lastRefreshTime), true]);
  }
  signals.push(["User doc lastUpdated", tms(u.lastUpdated), true]);
  signals.push(["FCM lastTokenUpdate", tms(u.lastTokenUpdate), true]);
  signals.push(["lastAuraUpdate", tms(u.lastAuraUpdate), false]); // server cron
  signals.push(["lastStoryExpiresAt", tms(u.lastStoryExpiresAt), true]);

  // subcollections that imply usage
  const subs = ["dailyInsights", "favoriteInsights", "savedInsights",
    "insightFeedback", "healthSnapshots", "nadiReadings", "stories", "notifications"];
  const subInfo = {};
  for (const s of subs) {
    const snap = await db.collection(`users/${UID}/${s}`).get();
    let latest = null;
    snap.docs.forEach((d) => {
      const dt = d.data();
      const t = tms(dt.timestamp || dt.createdAt || dt.date || dt.viewedAt || dt.generatedAt);
      if (t) latest = latest ? Math.max(latest, t) : t;
    });
    subInfo[s] = { count: snap.size, latest };
    // dailyInsights = server-generated daily cron, NOT user activity
    const userDriven = s !== "dailyInsights";
    if (latest) signals.push([`subcol ${s} latest`, latest, userDriven]);
  }

  // ---- conversations + full transcripts ----
  const dmSnap = await db.collection("dmConversations").get();
  const mine = dmSnap.docs.filter((d) => (d.data().participants || []).includes(UID));
  const transcript = [];
  let convoLastActivity = null;
  for (const cdoc of mine) {
    const c = cdoc.data();
    const la = tms(c.lastActivity);
    if (la) convoLastActivity = convoLastActivity ? Math.max(convoLastActivity, la) : la;
    const msgs = await db.collection("dmConversations").doc(cdoc.id).collection("messages").get();
    msgs.docs.forEach((m) => {
      const md = m.data();
      transcript.push({
        convo: cdoc.id, t: tms(md.timestamp),
        who: md.senderId === UID ? "USER" : (md.senderId === AI_UID ? "HOLYCOW" : md.senderId),
        voice: !!md.isVoiceMessage, content: (md.content || "").toString(),
      });
    });
  }
  if (convoLastActivity) signals.push(["Convo lastActivity (talked to HolyCow)", convoLastActivity, true]);
  transcript.sort((a, b) => (a.t || 0) - (b.t || 0));

  // dedupe consecutive identical
  const clean = [];
  for (const m of transcript) {
    const prev = clean[clean.length - 1];
    if (prev && prev.who === m.who && prev.content === m.content && prev.t === m.t) continue;
    clean.push(m);
  }

  // ---- print recency report ----
  log("\n--- ACTIVITY SIGNALS (most recent first) ---");
  const valid = signals.filter((s) => s[1]).sort((a, b) => b[1] - a[1]);
  valid.forEach(([label, t, userDriven]) =>
    log(`  ${iso(t).slice(0, 19)}  (${ago(t).padStart(8)})  ${userDriven ? "[USER]  " : "[system]"} ${label}`));
  const userValid = valid.filter((s) => s[2]);
  const mostRecent = userValid.length ? userValid[0][1] : null;
  log("\n  >>> MOST RECENT *USER-DRIVEN* ACTIVITY: " + (mostRecent ? `${iso(mostRecent)} (${ago(mostRecent)})` : "unknown"));
  log("  >>> VERDICT (system signals excluded): " + (mostRecent && (now - mostRecent) < 7 * DAY ? "ACTIVE (within 7d)"
    : mostRecent && (now - mostRecent) < 30 * DAY ? "RECENTLY ACTIVE (within 30d)"
    : "DORMANT (no real activity in 30d+)"));

  log("\n--- SUBCOLLECTION USAGE ---");
  Object.entries(subInfo).forEach(([s, v]) => log(`  ${s}: ${v.count} docs` + (v.latest ? `, latest ${iso(v.latest).slice(0, 10)}` : "")));

  // ---- engagement timeline (messages per day) ----
  const userMsgs = clean.filter((m) => m.who === "USER" && m.content && !/voice message/i.test(m.content));
  const byDay = {};
  userMsgs.forEach((m) => { const d = iso(m.t).slice(0, 10); byDay[d] = (byDay[d] || 0) + 1; });
  log("\n--- HER MESSAGE TIMELINE (typed msgs/day) ---");
  Object.entries(byDay).sort().forEach(([d, n]) => log(`  ${d}: ${"#".repeat(Math.min(n, 40))} ${n}`));

  // ---- save full transcript ----
  const OUT = join(__dirname, "../analysis/dossiers");
  if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });
  const lines = clean.map((m) =>
    `[${iso(m.t).slice(0, 19)}] ${m.who}${m.voice ? " (voice)" : ""}: ${m.content}`);
  writeFileSync(join(OUT, UID + "_transcript.txt"), lines.join("\n"), "utf8");
  log(`\n  full two-sided transcript (${clean.length} msgs) -> dossiers/${UID}_transcript.txt`);
  log("\ndone");
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
