#!/usr/bin/env node
/**
 * Cosmic Daily — Time Simulation
 *
 * Simulates the system running over a range of dates to test:
 * - Memory accumulation (do observations build?)
 * - Prediction validation (does day N+14 check day N's predictions?)
 * - Learning loop (does the model reference past patterns?)
 * - Output quality over time (does it get better?)
 *
 * Usage:
 *   node scripts/simulate_cosmic.js --from 2026-01-01 --to 2026-01-14
 *   node scripts/simulate_cosmic.js --from 2026-01-01 --days 7
 *   node scripts/simulate_cosmic.js --from 2026-01-01 --to 2026-01-31 --every 3  # every 3rd day
 *   node scripts/simulate_cosmic.js --from 2026-03-01 --days 14 --dry-run        # show plan only
 *   node scripts/simulate_cosmic.js --from 2026-01-01 --days 7 --fresh           # clear memory first
 *
 * Notes:
 *   - News headlines will be TODAY's news for all simulated dates (Google RSS
 *     doesn't have historical data). This is fine — we're testing the astrology
 *     + memory loop, not news correlation.
 *   - Each run costs ~1 Gemini Flash call (~$0.001). A 30-day sim ≈ $0.03.
 *   - Sky positions must exist in Firestore for each simulated date.
 */

import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Set GOOGLE_APPLICATION_CREDENTIALS so firebase-admin auto-initializes
process.env.GOOGLE_APPLICATION_CREDENTIALS = join(__dirname, "../serviceAccountKey.json");

const { db } = await import("../lib/firebase.js");

// ─────────────────────────────────────────────────────────────────────────────
// CLI PARSING
// ─────────────────────────────────────────────────────────────────────────────

function parseArgs() {
    const args = process.argv.slice(2);
    const opts = { from: null, to: null, days: null, every: 1, dryRun: false, fresh: false };

    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case "--from": opts.from = args[++i]; break;
            case "--to": opts.to = args[++i]; break;
            case "--days": opts.days = parseInt(args[++i]); break;
            case "--every": opts.every = parseInt(args[++i]); break;
            case "--dry-run": opts.dryRun = true; break;
            case "--fresh": opts.fresh = true; break;
        }
    }

    if (!opts.from) {
        console.error("Usage: simulate_cosmic.js --from YYYY-MM-DD [--to YYYY-MM-DD | --days N] [--every N] [--dry-run] [--fresh]");
        process.exit(1);
    }

    // Resolve end date
    if (!opts.to && opts.days) {
        const start = new Date(opts.from);
        start.setDate(start.getDate() + opts.days - 1);
        opts.to = start.toISOString().split("T")[0];
    } else if (!opts.to) {
        opts.to = opts.from; // single day
    }

    return opts;
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE RANGE GENERATION
// ─────────────────────────────────────────────────────────────────────────────

function generateDateRange(from, to, every) {
    const dates = [];
    const start = new Date(from);
    const end = new Date(to);
    let current = new Date(start);
    let step = 0;

    while (current <= end) {
        if (step % every === 0) {
            dates.push(current.toISOString().split("T")[0]);
        }
        current.setDate(current.getDate() + 1);
        step++;
    }
    return dates;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SIMULATION
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
    const opts = parseArgs();
    const dates = generateDateRange(opts.from, opts.to, opts.every);

    // Check which dates have sky positions
    const skyDoc = await db.collection("global_astro").doc("sky_positions").get();
    const positions = skyDoc.data()?.positions || {};
    const availableDates = dates.filter(d => positions[d]);
    const missingDates = dates.filter(d => !positions[d]);

    console.log(`\n${"═".repeat(70)}`);
    console.log(`🌌 COSMIC DAILY SIMULATION`);
    console.log(`${"═".repeat(70)}`);
    console.log(`  From:     ${opts.from}`);
    console.log(`  To:       ${opts.to}`);
    console.log(`  Every:    ${opts.every} day(s)`);
    console.log(`  Dates:    ${dates.length} total, ${availableDates.length} with sky data`);
    if (missingDates.length > 0) {
        console.log(`  Missing:  ${missingDates.slice(0, 5).join(", ")}${missingDates.length > 5 ? "..." : ""}`);
    }
    console.log(`  Fresh:    ${opts.fresh}`);
    console.log(`  Est cost: ~$${(availableDates.length * 0.001).toFixed(3)} (Gemini Flash)`);
    console.log(`  Est time: ~${(availableDates.length * 15)} seconds`);
    console.log(`${"═".repeat(70)}\n`);

    if (availableDates.length === 0) {
        console.error("❌ No sky positions found for any date in range.");
        console.log(`   Available range: ${Object.keys(positions).sort()[0]} → ${Object.keys(positions).sort().pop()}`);
        process.exit(1);
    }

    if (opts.dryRun) {
        console.log("🏁 DRY RUN — dates that would be simulated:");
        for (const d of availableDates) console.log(`  📅 ${d}`);
        process.exit(0);
    }

    // Get Gemini key
    const apiKey = process.env.GEMINI_API_KEY || await getGeminiKey();
    if (!apiKey) {
        console.error("❌ No GEMINI_API_KEY. Export it or set in Firebase secrets.");
        process.exit(1);
    }

    // Fresh start?
    if (opts.fresh) {
        console.log("🗑️  Clearing memories and outputs for fresh simulation...");
        await clearCollection("cosmic_memory");
        await clearCollection("cosmic_daily_output");
        console.log();
    }

    // Import the daily function
    const { generateDailyOutput } = await import("../functions/cosmic_daily.js");

    // Track stats across the simulation
    const stats = {
        totalPredictions: 0,
        totalUpdates: 0,
        confirmed: 0,
        missed: 0,
        errors: 0,
        wallTimes: [],
    };

    // Run each date sequentially (order matters — memory builds up!)
    for (let i = 0; i < availableDates.length; i++) {
        const dateStr = availableDates[i];
        const dayNum = i + 1;

        console.log(`\n${"─".repeat(70)}`);
        console.log(`📅 Day ${dayNum}/${availableDates.length}: ${dateStr}`);
        console.log(`${"─".repeat(70)}`);

        try {
            const startTime = Date.now();
            const output = await generateDailyOutput(apiKey, dateStr);
            const elapsed = Date.now() - startTime;
            stats.wallTimes.push(elapsed);

            const predCount = output.predictions?.length || 0;
            const updateCount = output.predictionUpdates?.length || 0;
            stats.totalPredictions += predCount;
            stats.totalUpdates += updateCount;

            // Count confirmed/missed
            for (const u of output.predictionUpdates || []) {
                if (u.status === "confirmed") stats.confirmed++;
                if (u.status === "missed") stats.missed++;
            }

            // Print summary for this day
            console.log(`  ✅ ${(elapsed / 1000).toFixed(1)}s | ${predCount} predictions | ${updateCount} updates`);

            // World energy preview
            const energyPreview = (output.worldEnergy || "").substring(0, 120);
            console.log(`  🌍 ${energyPreview}...`);

            // Show predictions
            for (const p of (output.predictions || []).slice(0, 3)) {
                console.log(`  🔮 [${(p.confidence * 100).toFixed(0)}%] ${p.claim.substring(0, 80)}`);
            }
            if (predCount > 3) console.log(`     ... +${predCount - 3} more`);

            // Show prediction updates (the learning loop!)
            for (const u of output.predictionUpdates || []) {
                const icon = u.status === "confirmed" ? "✅" : u.status === "missed" ? "❌" : "⏳";
                console.log(`  ${icon} UPDATE: [${u.status}] ${(u.originalClaim || "").substring(0, 70)}`);
            }

            // Memory count
            const memSnap = await db.collection("cosmic_memory").count().get();
            console.log(`  🧠 Total memories: ${memSnap.data().count}`);

        } catch (err) {
            stats.errors++;
            console.error(`  ❌ ERROR: ${err.message}`);
        }

        // Brief pause between runs to avoid rate limiting
        if (i < availableDates.length - 1) {
            await sleep(2000);
        }
    }

    // ─── Final Report ────────────────────────────────────────────────────
    console.log(`\n${"═".repeat(70)}`);
    console.log(`📊 SIMULATION COMPLETE`);
    console.log(`${"═".repeat(70)}`);
    console.log(`  Days simulated:     ${availableDates.length}`);
    console.log(`  Total predictions:  ${stats.totalPredictions}`);
    console.log(`  Prediction updates: ${stats.totalUpdates}`);
    console.log(`  Confirmed:          ${stats.confirmed}`);
    console.log(`  Missed:             ${stats.missed}`);
    console.log(`  Errors:             ${stats.errors}`);

    const avgTime = stats.wallTimes.length > 0
        ? (stats.wallTimes.reduce((a, b) => a + b, 0) / stats.wallTimes.length / 1000).toFixed(1)
        : "N/A";
    console.log(`  Avg wall time:      ${avgTime}s`);
    console.log(`  Total wall time:    ${(stats.wallTimes.reduce((a, b) => a + b, 0) / 1000).toFixed(0)}s`);

    // Final memory state
    const namespaces = ["observations", "predictions", "patterns", "reflections", "research"];
    console.log(`\n  🧠 Final Memory State:`);
    for (const ns of namespaces) {
        const snap = await db.collection("cosmic_memory").where("namespace", "==", ns).count().get();
        console.log(`     ${ns.padEnd(15)} ${snap.data().count}`);
    }
    console.log(`\n${"═".repeat(70)}\n`);

    process.exit(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

async function clearCollection(name) {
    const BATCH = 500;
    const snap = await db.collection(name).get();
    if (snap.empty) return;
    for (let i = 0; i < snap.docs.length; i += BATCH) {
        const batch = db.batch();
        snap.docs.slice(i, i + BATCH).forEach(doc => batch.delete(doc.ref));
        await batch.commit();
    }
    console.log(`  Cleared ${snap.size} docs from ${name}`);
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function getGeminiKey() {
    try {
        const { execSync } = await import("child_process");
        return execSync(
            "firebase functions:secrets:access GEMINI_API_KEY 2>/dev/null",
            { cwd: join(__dirname, ".."), encoding: "utf-8", timeout: 10000 }
        ).trim();
    } catch { return null; }
}

main().catch(err => {
    console.error("Fatal:", err);
    process.exit(1);
});
