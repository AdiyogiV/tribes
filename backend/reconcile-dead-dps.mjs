#!/usr/bin/env node
/**
 * One-time reconciliation: find users whose `displayPicture` URL is dead
 * (file 404 in Storage, or a stale download token) and repair the Firestore
 * record so the app cleanly falls back to the user's yoni-tribe avatar.
 *
 * Background: Aurogram was rebranded from an older app. Legacy 2021-2024 user
 * documents were carried over, but their Storage profile photos were not — so
 * their stored displayPicture URLs point at files that no longer exist. Those
 * render blank everywhere (feed, chat, profiles, dashboard).
 *
 * This script checks the ACTUAL stored URL (what the app fetches). If it does
 * not return an image, the DP is considered dead. For each dead DP it:
 *   - clears `displayPicture` (sets it to "")   -> app shows yoni animal
 *   - sets `legacyOrphan: true`                  -> lets you find/soft-archive
 *
 * Uses the Firestore REST API + gcloud access token (same pattern as
 * backfill-astro-365.mjs). No firebase-admin, no service account, no deploy.
 *
 * Usage:
 *   node reconcile-dead-dps.mjs                     # DRY RUN — reports only
 *   node reconcile-dead-dps.mjs --run              # apply repairs
 *   node reconcile-dead-dps.mjs --concurrency=8    # tune parallelism (default 6)
 *   node reconcile-dead-dps.mjs --limit=50         # only check first N (testing)
 */

import { execSync } from "child_process";

// ─── Config ──────────────────────────────────────────────────────────────────
const PROJECT_ID = "ty-dev-516d7";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const APPLY = process.argv.includes("--run");
const CONCURRENCY =
  Number((process.argv.find((a) => a.startsWith("--concurrency=")) || "").split("=")[1]) || 6;
const LIMIT =
  Number((process.argv.find((a) => a.startsWith("--limit=")) || "").split("=")[1]) || Infinity;

// ─── Auth ────────────────────────────────────────────────────────────────────
function accessToken() {
  return execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
}
let TOKEN = accessToken();

async function firestore(path, init = {}) {
  const res = await fetch(`${FIRESTORE_BASE}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      "Content-Type": "application/json",
      ...(init.headers || {}),
    },
  });
  if (res.status === 401) {
    // token expired mid-run — refresh once and retry
    TOKEN = accessToken();
    return firestore(path, init);
  }
  return res;
}

// ─── Step 1: page through all users, collecting those with a displayPicture ────
async function listUsersWithDp() {
  const out = [];
  let pageToken = "";
  do {
    const qs = new URLSearchParams({
      pageSize: "300",
      "mask.fieldPaths": "displayPicture",
    });
    // second mask field must be added separately (URLSearchParams overwrites dup keys)
    let url = `/users?${qs.toString()}&mask.fieldPaths=name`;
    if (pageToken) url += `&pageToken=${encodeURIComponent(pageToken)}`;
    const res = await firestore(url);
    if (!res.ok) throw new Error(`List users failed: ${res.status} ${await res.text()}`);
    const data = await res.json();
    for (const doc of data.documents || []) {
      const uid = doc.name.split("/").pop();
      const pic = doc.fields?.displayPicture?.stringValue || "";
      const name = doc.fields?.name?.stringValue || "(no name)";
      if (pic.startsWith("http")) out.push({ uid, pic, name });
      if (out.length >= LIMIT) return out;
    }
    pageToken = data.nextPageToken || "";
  } while (pageToken);
  return out;
}

// ─── Step 2: is the stored URL actually a live image? ─────────────────────────
async function isDeadDp(url) {
  try {
    const res = await fetch(url, { method: "GET" });
    if (!res.ok) return { dead: true, reason: `HTTP ${res.status}` };
    const ct = (res.headers.get("content-type") || "").toLowerCase();
    // Cancel the body — we only needed the headers.
    try { await res.body?.cancel(); } catch {}
    if (!ct.startsWith("image/")) return { dead: true, reason: `content-type ${ct || "?"}` };
    return { dead: false, reason: ct };
  } catch (e) {
    return { dead: true, reason: `fetch error: ${e.message}` };
  }
}

// ─── Step 3: repair a dead record ─────────────────────────────────────────────
async function repair(uid) {
  const body = {
    fields: {
      displayPicture: { stringValue: "" },
      legacyOrphan: { booleanValue: true },
    },
  };
  const url =
    `/users/${uid}?updateMask.fieldPaths=displayPicture&updateMask.fieldPaths=legacyOrphan`;
  const res = await firestore(url, { method: "PATCH", body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`PATCH ${uid} failed: ${res.status} ${await res.text()}`);
}

// ─── Simple concurrency pool ──────────────────────────────────────────────────
async function mapPool(items, worker, size) {
  const results = new Array(items.length);
  let i = 0;
  async function run() {
    while (i < items.length) {
      const idx = i++;
      results[idx] = await worker(items[idx], idx);
    }
  }
  await Promise.all(Array.from({ length: Math.min(size, items.length) }, run));
  return results;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
(async () => {
  console.log(`\nReconcile dead DPs — ${APPLY ? "APPLY (will write)" : "DRY RUN (no writes)"}\n`);

  const users = await listUsersWithDp();
  console.log(`Users with a displayPicture URL: ${users.length}\n`);

  let checked = 0;
  const dead = [];
  await mapPool(
    users,
    async (u) => {
      const { dead: isDead, reason } = await isDeadDp(u.pic);
      checked++;
      if (isDead) dead.push({ ...u, reason });
      if (checked % 25 === 0) process.stdout.write(`  checked ${checked}/${users.length}\r`);
    },
    CONCURRENCY,
  );

  console.log(`\n\nDead DPs found: ${dead.length} of ${users.length}\n`);
  for (const d of dead) {
    console.log(`  ${d.uid}  "${d.name}"  (${d.reason})`);
  }

  if (!dead.length) {
    console.log("\nNothing to repair. Clean!\n");
    return;
  }

  if (!APPLY) {
    console.log(`\nDRY RUN — no changes made. Re-run with --run to repair these ${dead.length} records.\n`);
    return;
  }

  console.log(`\nRepairing ${dead.length} records...`);
  let ok = 0;
  await mapPool(
    dead,
    async (d) => {
      try {
        await repair(d.uid);
        ok++;
      } catch (e) {
        console.log(`  FAILED ${d.uid}: ${e.message}`);
      }
    },
    CONCURRENCY,
  );
  console.log(`\nRepaired ${ok}/${dead.length}. Done.\n`);
})().catch((e) => {
  console.error("\nFATAL:", e.message);
  process.exit(1);
});
