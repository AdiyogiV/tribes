/**
 * Deep diagnostic: traces the entire cosmic_daily pipeline step by step
 * and dumps each intermediate output for quality inspection.
 *
 * Usage: source .env && node scripts/diagnose_pipeline.js [date]
 */

import { readFileSync } from "fs";

// Firebase setup
process.env.GOOGLE_APPLICATION_CREDENTIALS = "serviceAccountKey.json";
const { db } = await import("../lib/firebase.js");
const { extractSignals, diffSky, getTopSignals } = await import("../functions/signal_engine.js");
const { getPanchanga, getNakshatra, getNakshatraMundane } = await import("../lib/vedic_utils.js");
const { scanUpcomingTransits } = await import("../lib/upcoming_transits.js");
const { initMemory, listMemories, recallMemory } = await import("../lib/agent_memory.js");
const { fetchNewsHeadlines, formatNewsForPrompt } = await import("../lib/news_feed.js");
const { ZODIAC_SIGNS } = await import("../lib/constants.js");

const apiKey = process.env.GEMINI_API_KEY;
const dateStr = process.argv[2] || "2026-04-05";

console.log("=".repeat(80));
console.log(`PIPELINE DIAGNOSTIC — ${dateStr}`);
console.log("=".repeat(80));

// ═══════════════════════════════════════════════════════════════════════════
// STEP 1: Load sky positions
// ═══════════════════════════════════════════════════════════════════════════
console.log("\n\n" + "█".repeat(80));
console.log("STEP 1: SKY POSITIONS");
console.log("█".repeat(80));

const skyDoc = await db.collection("global_astro").doc("sky_positions").get();
const allPositions = skyDoc.data()?.positions || {};
const sortedDates = Object.keys(allPositions).sort();
const todayIdx = sortedDates.indexOf(dateStr);
const todayPos = allPositions[dateStr];
const yesterdayPos = todayIdx > 0 ? allPositions[sortedDates[todayIdx - 1]] : null;

if (!todayPos) {
    console.error(`❌ No positions for ${dateStr}. Available: ${sortedDates[0]} to ${sortedDates[sortedDates.length - 1]}`);
    process.exit(1);
}

console.log(`\nDate range in Firestore: ${sortedDates[0]} → ${sortedDates[sortedDates.length - 1]} (${sortedDates.length} days)`);
console.log(`Today index: ${todayIdx}, Yesterday: ${sortedDates[todayIdx - 1] || "none"}`);
console.log(`\nRaw positions for ${dateStr}:`);
for (const [planet, data] of Object.entries(todayPos)) {
    const sign = ZODIAC_SIGNS[Math.floor(data.longitude / 30)];
    const deg = (data.longitude % 30).toFixed(2);
    const retro = data.isRetro ? " (R)" : "";
    console.log(`  ${planet.padEnd(10)} ${data.longitude.toFixed(4).padStart(10)}°  = ${deg}° ${sign}${retro}`);
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 2: Panchanga
// ═══════════════════════════════════════════════════════════════════════════
console.log("\n\n" + "█".repeat(80));
console.log("STEP 2: PANCHANGA");
console.log("█".repeat(80));

const panchanga = getPanchanga(todayPos, dateStr);
if (panchanga) {
    console.log(`\n  Vara:      ${panchanga.vara.name} (${panchanga.vara.lord})`);
    console.log(`  Tithi:     ${panchanga.tithi.name} #${panchanga.tithi.index} (${panchanga.tithi.paksha}) — ${panchanga.tithi.percent}% elapsed`);
    console.log(`  Nakshatra: ${panchanga.nakshatra.name} P${panchanga.nakshatra.pada} (${panchanga.nakshatra.lord})`);
    console.log(`  Yoga:      ${panchanga.yoga.name} #${panchanga.yoga.index}`);
    console.log(`  Phase:     ${panchanga.lunarPhase}`);
    console.log(`\n  Moon mundane theme: "${getNakshatraMundane(panchanga.nakshatra.name)}"`);
    console.log(`\n  All planet nakshatras:`);
    for (const [planet, nak] of Object.entries(panchanga.planetNakshatras)) {
        console.log(`    ${planet.padEnd(10)} ${nak.name.padEnd(22)} P${nak.pada} (${nak.lord})`);
    }
} else {
    console.log("  ❌ Panchanga returned null!");
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 3: Signal extraction
// ═══════════════════════════════════════════════════════════════════════════
console.log("\n\n" + "█".repeat(80));
console.log("STEP 3: SIGNAL EXTRACTION");
console.log("█".repeat(80));

const signals = extractSignals(todayPos, yesterdayPos, dateStr);
const topSignals = getTopSignals(signals, 15);
const diff = yesterdayPos ? diffSky(todayPos, yesterdayPos, dateStr) : null;

console.log(`\n  Total signals extracted: ${signals.length}`);
console.log(`  Top 15 signals:`);
for (const s of topSignals) {
    const applying = s.applying === true ? " APPLYING" : s.applying === false ? " separating" : "";
    const orb = s.orb != null ? ` orb:${s.orb}°` : "";
    console.log(`  [★${String(s.intensity).padStart(2)}/10] ${s.type.padEnd(12)} ${s.planets.join(" + ").padEnd(25)} ${(s.aspect || s.dignity || s.stationType || "").padEnd(15)}${orb}${applying}`);
    console.log(`           Domains: ${(s.domains || []).slice(0, 5).join(", ")}`);
}

// Signal type breakdown
const typeCounts = {};
for (const s of signals) {
    typeCounts[s.type] = (typeCounts[s.type] || 0) + 1;
}
console.log(`\n  Signal breakdown: ${JSON.stringify(typeCounts)}`);

if (diff) {
    console.log(`\n  Sky diff summary: ${diff.summary}`);
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 4: Upcoming transits
// ═══════════════════════════════════════════════════════════════════════════
console.log("\n\n" + "█".repeat(80));
console.log("STEP 4: UPCOMING TRANSITS (14 days)");
console.log("█".repeat(80));

const upcoming = scanUpcomingTransits(allPositions, sortedDates, todayIdx, 14);
console.log(`\n  Total upcoming events: ${upcoming.length}`);
for (const evt of upcoming) {
    if (evt.type === "aspect_perfection") {
        console.log(`  [+${String(evt.daysAway).padStart(2)}d ${evt.date}] ASPECT: ${evt.planet1}-${evt.planet2} ${evt.aspect} perfects (orb: ${evt.orb}°)`);
    } else if (evt.type === "ingress") {
        console.log(`  [+${String(evt.daysAway).padStart(2)}d ${evt.date}] INGRESS: ${evt.planet} ${evt.fromSign} → ${evt.toSign}`);
    } else if (evt.type === "station") {
        console.log(`  [+${String(evt.daysAway).padStart(2)}d ${evt.date}] STATION: ${evt.planet} goes ${evt.stationType} in ${evt.sign}`);
    }
}

// Type breakdown
const upcomingTypes = {};
for (const e of upcoming) {
    const key = e.type + (e.type === "ingress" ? `:${e.planet}` : "");
    upcomingTypes[key] = (upcomingTypes[key] || 0) + 1;
}
console.log(`\n  Breakdown: ${JSON.stringify(upcomingTypes)}`);

// ═══════════════════════════════════════════════════════════════════════════
// STEP 5: Memory recall
// ═══════════════════════════════════════════════════════════════════════════
console.log("\n\n" + "█".repeat(80));
console.log("STEP 5: MEMORY RECALL");
console.log("█".repeat(80));

if (apiKey) {
    initMemory(apiKey);

    const [observations, predictions, patterns] = await Promise.all([
        listMemories("observations", 7),
        listMemories("predictions", 15),
        recallMemory("current major world events planetary patterns", {
            namespace: "patterns",
            topK: 5,
            minSimilarity: 0.2,
        }),
    ]);

    console.log(`\n  Observations: ${observations.length}`);
    for (const obs of observations.slice(0, 3)) {
        const date = obs.createdAt ? new Date(obs.createdAt).toISOString().split("T")[0] : "?";
        console.log(`    [${date}] ${obs.content.substring(0, 150)}...`);
    }

    console.log(`\n  Predictions: ${predictions.length}`);
    for (const pred of predictions.slice(0, 5)) {
        console.log(`    - ${pred.content.substring(0, 150)}...`);
    }

    console.log(`\n  Patterns: ${patterns.length}`);
    for (const pat of patterns) {
        console.log(`    [sim:${pat.similarity}] ${pat.content.substring(0, 150)}...`);
    }
} else {
    console.log("  ⚠️ No API key — skipping memory recall");
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 6: News fetch
// ═══════════════════════════════════════════════════════════════════════════
console.log("\n\n" + "█".repeat(80));
console.log("STEP 6: NEWS HEADLINES");
console.log("█".repeat(80));

const headlines = await fetchNewsHeadlines({ limit: 20 });
const newsText = formatNewsForPrompt(headlines);
console.log(`\n  Headlines fetched: ${headlines.length}`);
for (const h of headlines.slice(0, 10)) {
    console.log(`    • ${h.title?.substring(0, 100)}`);
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP 7: Check existing Firestore output for this date
// ═══════════════════════════════════════════════════════════════════════════
console.log("\n\n" + "█".repeat(80));
console.log("STEP 7: EXISTING OUTPUT IN FIRESTORE");
console.log("█".repeat(80));

const existingDoc = await db.collection("cosmic_daily_output").doc(dateStr).get();
if (existingDoc.exists) {
    const data = existingDoc.data();
    console.log(`\n  ✅ Output exists for ${dateStr}`);
    console.log(`  Generated at: ${data.generatedAt?.toDate?.() || data.generatedAt}`);
    console.log(`  Wall time: ${data.wallTimeMs}ms`);
    console.log(`\n  worldEnergy (first 500 chars):`);
    console.log(`    ${data.worldEnergy?.substring(0, 500)}`);
    console.log(`\n  Predictions: ${data.predictions?.length || 0}`);
    for (const p of (data.predictions || [])) {
        console.log(`    • [conf:${p.confidence}] ${p.claim}`);
        console.log(`      timeframe: ${p.timeframe}`);
        console.log(`      basedOn: ${p.basedOn?.substring(0, 120)}`);
    }
    console.log(`\n  Prediction Updates: ${data.predictionUpdates?.length || 0}`);
    for (const u of (data.predictionUpdates || [])) {
        console.log(`    • [${u.status}] ${u.originalClaim?.substring(0, 100)}`);
        console.log(`      evidence: ${u.evidence?.substring(0, 120)}`);
    }
    console.log(`\n  Houses:`);
    for (const [h, info] of Object.entries(data.houses || {})) {
        const planets = (info.planets || []).map(p => `${p.planet}${p.isRetro ? "(R)" : ""}`).join(", ");
        console.log(`    H${h} ${info.sign} [${info.name}] ${planets ? "← " + planets : ""}`);
        console.log(`       ${info.reading?.substring(0, 150)}`);
    }
    console.log(`\n  Observations: ${data.observations?.substring(0, 300)}`);
    console.log(`\n  Signals summary: ${data.signalsSummary?.length || 0} signals`);
    console.log(`  Panchanga: ${data.panchanga ? JSON.stringify(data.panchanga.tithi) + " " + data.panchanga.lunarPhase : "MISSING"}`);
    console.log(`  Upcoming transits: ${data.upcomingTransits?.length || 0}`);
} else {
    console.log(`\n  ⚠️ No output stored for ${dateStr}`);
}

console.log("\n\n" + "=".repeat(80));
console.log("DIAGNOSTIC COMPLETE");
console.log("=".repeat(80));

process.exit(0);
