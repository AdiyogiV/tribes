#!/usr/bin/env node
/**
 * Cosmic Daily — Backend Test Harness
 *
 * This is a BACKEND system. We test it from backend. No frontend needed.
 *
 * Usage:
 *   node scripts/test_cosmic.js                    # Run for today
 *   node scripts/test_cosmic.js 2026-04-12         # Run for specific date
 *   node scripts/test_cosmic.js --inspect 2026-04-12  # Just read existing output
 *   node scripts/test_cosmic.js --memory           # Show memory stats
 *   node scripts/test_cosmic.js --clear-memory     # Wipe all memories (fresh start)
 *   node scripts/test_cosmic.js --clear-output     # Wipe all daily outputs
 */

import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Set GOOGLE_APPLICATION_CREDENTIALS so firebase-admin auto-initializes
// with the service account when firebase.js calls initializeApp().
process.env.GOOGLE_APPLICATION_CREDENTIALS = join(__dirname, "../serviceAccountKey.json");

// Now import firebase.js — it calls initializeApp() using the env var above.
const { db } = await import("../lib/firebase.js");

// ─────────────────────────────────────────────────────────────────────────────
// CLI PARSING
// ─────────────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const flags = args.filter(a => a.startsWith("--"));
const positional = args.filter(a => !a.startsWith("--"));

const TODAY = new Date().toISOString().split("T")[0];

async function main() {
    if (flags.includes("--memory")) {
        await showMemoryStats();
        process.exit(0);
    }
    if (flags.includes("--clear-memory")) {
        await clearCollection("cosmic_memory");
        process.exit(0);
    }
    if (flags.includes("--clear-output")) {
        await clearCollection("cosmic_daily_output");
        process.exit(0);
    }
    if (flags.includes("--inspect")) {
        const date = positional[0] || TODAY;
        await inspectOutput(date);
        process.exit(0);
    }

    // Default: run for a date
    const date = positional[0] || TODAY;
    await runSingleDay(date);
    process.exit(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// RUN SINGLE DAY
// ─────────────────────────────────────────────────────────────────────────────

async function runSingleDay(dateStr) {
    console.log(`\n🌙 Running cosmic daily for ${dateStr}...\n`);

    // Get Gemini API key from environment or Firebase secrets
    const apiKey = process.env.GEMINI_API_KEY || await getGeminiKey();
    if (!apiKey) {
        console.error("❌ No GEMINI_API_KEY. Set it as env var or in Firebase secrets.");
        process.exit(1);
    }

    const { generateDailyOutput } = await import("../functions/cosmic_daily.js");

    const startTime = Date.now();
    try {
        const output = await generateDailyOutput(apiKey, dateStr);
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

        console.log(`\n${"═".repeat(70)}`);
        console.log(`✅ COMPLETED in ${elapsed}s`);
        console.log(`${"═".repeat(70)}\n`);

        printOutput(output);
        await showMemoryStats();
    } catch (err) {
        console.error(`\n❌ FAILED after ${((Date.now() - startTime) / 1000).toFixed(1)}s`);
        console.error(err.message);
        console.error(err.stack);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSPECT EXISTING OUTPUT
// ─────────────────────────────────────────────────────────────────────────────

async function inspectOutput(dateStr) {
    const doc = await db.collection("cosmic_daily_output").doc(dateStr).get();
    if (!doc.exists) {
        console.log(`\n❌ No output for ${dateStr}. Run it first.`);
        return;
    }
    console.log(`\n📄 Output for ${dateStr}:\n`);
    printOutput(doc.data());
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINT OUTPUT — Human-readable display
// ─────────────────────────────────────────────────────────────────────────────

function printOutput(output) {
    // World Energy
    console.log("🌍 WORLD ENERGY");
    console.log("─".repeat(50));
    console.log(output.worldEnergy || "(empty)");

    // Predictions
    console.log(`\n🔮 PREDICTIONS (${(output.predictions || []).length})`);
    console.log("─".repeat(50));
    for (const p of output.predictions || []) {
        const conf = (p.confidence * 100).toFixed(0);
        console.log(`  [${conf}%] ${p.claim}`);
        console.log(`         ⏱ ${p.timeframe} | 📊 ${(p.domains || []).join(", ")}`);
        console.log(`         📝 ${p.basedOn}`);
    }

    // Prediction Updates
    if (output.predictionUpdates?.length > 0) {
        console.log(`\n📋 PREDICTION UPDATES (${output.predictionUpdates.length})`);
        console.log("─".repeat(50));
        for (const u of output.predictionUpdates) {
            const icon = u.status === "confirmed" ? "✅" : u.status === "missed" ? "❌" : "⏳";
            console.log(`  ${icon} [${u.status}] ${u.originalClaim}`);
            if (u.evidence) console.log(`     Evidence: ${u.evidence}`);
        }
    }

    // Houses
    console.log(`\n🏛️  MUNDANE HOUSES`);
    console.log("─".repeat(50));
    const houses = output.houses || {};
    for (let h = 1; h <= 12; h++) {
        const house = houses[String(h)] || houses[h];
        if (!house) continue;
        const planets = (house.planets || []).map(p =>
            `${p.planet}${p.isRetro ? "(R)" : ""}`
        ).join(", ");
        const planetStr = planets ? ` 🪐 ${planets}` : "";
        console.log(`  H${String(h).padStart(2)} ${house.sign?.padEnd(12) || ""} ${(house.name || "").padEnd(18)}${planetStr}`);
        if (house.reading) {
            // Wrap reading text at ~80 chars
            const lines = wordWrap(house.reading, 65);
            for (const line of lines) {
                console.log(`     ${line}`);
            }
        }
    }

    // Signals
    if (output.signalsSummary?.length > 0) {
        console.log(`\n⚡ TOP SIGNALS (${output.signalsSummary.length})`);
        console.log("─".repeat(50));
        for (const s of output.signalsSummary) {
            const dir = s.applying ? "→" : s.applying === false ? "←" : " ";
            const orb = s.orb != null ? ` (${s.orb}°)` : "";
            console.log(`  [${s.intensity}/10] ${s.planets.join("+")} ${s.aspect || s.dignity || s.type || ""}${orb} ${dir} ${(s.domains || []).slice(0, 3).join(", ")}`);
        }
    }

    // Observations
    if (output.observations) {
        console.log(`\n📝 OBSERVATIONS (stored as memory)`);
        console.log("─".repeat(50));
        const lines = wordWrap(output.observations, 70);
        for (const line of lines) console.log(`  ${line}`);
    }

    // Meta
    console.log(`\n⏱️  Wall time: ${output.wallTimeMs}ms`);
    console.log();
}

// ─────────────────────────────────────────────────────────────────────────────
// MEMORY STATS
// ─────────────────────────────────────────────────────────────────────────────

async function showMemoryStats() {
    console.log("\n🧠 MEMORY STATE");
    console.log("─".repeat(50));

    const namespaces = ["observations", "predictions", "patterns", "reflections", "research"];
    let total = 0;

    for (const ns of namespaces) {
        const snap = await db.collection("cosmic_memory")
            .where("namespace", "==", ns)
            .count().get();
        const count = snap.data().count;
        total += count;
        const icon = { observations: "👁", predictions: "🔮", patterns: "🔄", reflections: "💭", research: "🔍" }[ns];
        console.log(`  ${icon} ${ns.padEnd(15)} ${count}`);
    }
    console.log(`  ${"─".repeat(25)}`);
    console.log(`  📊 total${" ".repeat(10)} ${total}`);

    // Show last 3 observations
    const recentObs = await db.collection("cosmic_memory")
        .where("namespace", "==", "observations")
        .orderBy("createdAt", "desc")
        .limit(3)
        .get();

    if (!recentObs.empty) {
        console.log("\n  📋 Recent observations:");
        for (const doc of recentObs.docs) {
            const d = doc.data();
            const date = d.createdAt?.toDate?.()?.toISOString?.()?.split("T")[0] || "?";
            const preview = (d.content || "").substring(0, 100);
            console.log(`     [${date}] ${preview}...`);
        }
    }
    console.log();
}

// ─────────────────────────────────────────────────────────────────────────────
// CLEAR COLLECTION
// ─────────────────────────────────────────────────────────────────────────────

async function clearCollection(collectionName) {
    const snap = await db.collection(collectionName).get();
    if (snap.empty) {
        console.log(`\n✅ ${collectionName} already empty.`);
        return;
    }

    console.log(`\n🗑️  Deleting ${snap.size} docs from ${collectionName}...`);
    const batch = db.batch();
    for (const doc of snap.docs) {
        batch.delete(doc.ref);
    }
    await batch.commit();
    console.log(`✅ Cleared ${snap.size} docs from ${collectionName}.`);
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function wordWrap(text, maxWidth) {
    if (!text) return [];
    const words = text.split(/\s+/);
    const lines = [];
    let current = "";
    for (const word of words) {
        if (current.length + word.length + 1 > maxWidth) {
            lines.push(current);
            current = word;
        } else {
            current = current ? current + " " + word : word;
        }
    }
    if (current) lines.push(current);
    return lines;
}

async function getGeminiKey() {
    // Try reading from Firebase Functions secrets config
    try {
        const { execSync } = await import("child_process");
        const result = execSync(
            "firebase functions:secrets:access GEMINI_API_KEY 2>/dev/null",
            { cwd: join(__dirname, ".."), encoding: "utf-8", timeout: 10000 }
        ).trim();
        if (result && !result.includes("Error")) return result;
    } catch { /* fall through */ }
    return null;
}

main().catch(err => {
    console.error("Fatal:", err);
    process.exit(1);
});
