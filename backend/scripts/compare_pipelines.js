#!/usr/bin/env node
/**
 * Compare OLD (cosmic_daily) vs NEW (mundane samhita) pipeline outputs
 * by fetching the most recent docs from Firestore.
 *
 * High-level quality dimensions:
 *  - Volume        — how many predictions per run
 *  - Specificity   — has regions/timing/weights vs vague prose
 *  - Groundedness  — rule citations / nimitta-boost / confidence
 *  - LLM cost      — wall time + token-ish proxies
 */
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { writeFileSync } from "fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
process.env.GOOGLE_APPLICATION_CREDENTIALS = join(__dirname, "../serviceAccountKey.json");

const { db } = await import("../lib/firebase.js");

async function fetchRecent(collection, n = 5) {
  const snap = await db.collection(collection).orderBy("generatedAt", "desc").limit(n).get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

function safeLen(x) {
  if (!x) return 0;
  if (Array.isArray(x)) return x.length;
  if (typeof x === "string") return x.length;
  if (typeof x === "object") return Object.keys(x).length;
  return 0;
}

function characterize(doc, side) {
  const c = { _side: side, _date: doc.id };
  c.wallTimeMs = doc.wallTimeMs ?? null;
  c.predictions = safeLen(doc.predictions);
  c.headline = (doc.headline || doc.executive_summary || "").slice(0, 120);
  // OLD-shape fields
  if (side === "OLD") {
    c.signals = safeLen(doc.signals || doc.topSignals);
    c.observations = (doc.observations || "").length;
    c.themes = safeLen(doc.themes);
    c.totalPromptChars = JSON.stringify(doc).length;
  }
  // NEW-shape fields
  if (side === "NEW") {
    c.totalEffects = doc.steps?.phalaGanana?.totalEffects ?? doc.rawAnalysis?.totalEffects ?? null;
    c.domains = safeLen(doc.steps?.phalaGanana?.topEffects) ||
                safeLen(doc.rawAnalysis?.domainScores);
    c.nimittaHeadlines = doc.steps?.nimittaAvalokan?.headlineCount ?? null;
    c.nimittaBoosted = doc.steps?.phalaGanana?.nimittaBoosted ?? null;
    c.memoriesRecalled = doc.steps?.smritiRecall?.memoriesFound ?? null;
    c.confidenceUpdates = doc.steps?.smritiLearn?.updatesApplied ?? null;
    c.panchanga = doc._panchanga?.triggerType ?? null;
    c.totalDocChars = JSON.stringify(doc).length;
  }
  return c;
}

function scoreSpecificity(doc) {
  // crude "specificity score": count predictions w/ region + timeframe + confidence
  let s = 0, total = 0;
  for (const p of (doc.predictions || [])) {
    total++;
    if (p.region || p.regions || p.targetRegions) s++;
    if (p.timeframe || p.peakDate || p.manifestation) s++;
    if (typeof p.confidence === "number") s++;
  }
  return total ? +(s / (total * 3)).toFixed(2) : 0;
}

console.log("\n══════════════════════════════════════════════════════════════════");
console.log("  PIPELINE QUALITY COMPARISON — OLD (cosmic_daily) vs NEW (samhita)");
console.log("══════════════════════════════════════════════════════════════════\n");

const [oldDocs, newDocs] = await Promise.all([
  fetchRecent("cosmic_daily_output", 5).catch(e => { console.error("OLD err:", e.message); return []; }),
  fetchRecent("mundane_forecasts", 5).catch(e => { console.error("NEW err:", e.message); return []; }),
]);

console.log(`OLD docs found: ${oldDocs.length}`);
console.log(`NEW docs found: ${newDocs.length}\n`);

const oldChar = oldDocs.map(d => characterize(d, "OLD"));
const newChar = newDocs.map(d => characterize(d, "NEW"));

console.log("── OLD (cosmic_daily) recent runs ────────────────────────────────");
for (const c of oldChar) {
  const spec = scoreSpecificity(oldDocs.find(d => d.id === c._date));
  console.log(`  ${c._date} | ${c.predictions}p | ${c.wallTimeMs}ms | spec=${spec} | "${c.headline}"`);
}

console.log("\n── NEW (samhita) recent runs ─────────────────────────────────────");
for (const c of newChar) {
  const spec = scoreSpecificity(newDocs.find(d => d.id === c._date));
  console.log(`  ${c._date} | ${c.predictions}p | ${c.totalEffects} effects | ${c.wallTimeMs}ms | nimitta=${c.nimittaHeadlines} | spec=${spec} | "${c.headline}"`);
}

// Detail dump: pick latest of each
console.log("\n══════════════════════════════════════════════════════════════════");
console.log("  SAMPLE PREDICTIONS — latest from each");
console.log("══════════════════════════════════════════════════════════════════");

if (oldDocs[0]) {
  console.log(`\n┌─ OLD ${oldDocs[0].id} ───────────────────────────`);
  console.log(`  headline: ${oldDocs[0].headline || oldDocs[0].executive_summary || "(none)"}`);
  for (const p of (oldDocs[0].predictions || []).slice(0, 3)) {
    console.log("  •", JSON.stringify(p).slice(0, 280));
  }
}

if (newDocs[0]) {
  console.log(`\n┌─ NEW ${newDocs[0].id} ───────────────────────────`);
  console.log(`  headline: ${newDocs[0].headline || newDocs[0].executive_summary || "(none)"}`);
  for (const p of (newDocs[0].predictions || []).slice(0, 3)) {
    console.log("  •", JSON.stringify(p).slice(0, 280));
  }
}

// Save full dump for HTML report later
const out = {
  generatedAt: new Date().toISOString(),
  oldRecent: oldDocs,
  newRecent: newDocs,
  summary: { oldChar, newChar },
};
const outPath = join(__dirname, "../mundane/data/pipeline_comparison.json");
writeFileSync(outPath, JSON.stringify(out, null, 2));
console.log(`\n✓ Wrote ${outPath}\n`);

process.exit(0);
