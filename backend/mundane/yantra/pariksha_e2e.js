/**
 * यन्त्र — परीक्षा E2E (End-to-End Test)
 *
 * Tests the FULL Varahamihira pipeline:
 *   1. Observe the world (news → domain heat)
 *   2. Build sky state (real or test positions)
 *   3. Apply rules WITH Nimitta boost
 *   4. Synthesize (fallback — no LLM key needed)
 *
 * This tests everything EXCEPT:
 *   - Firestore reads (uses raw positions for offline testing)
 *   - LLM synthesis (uses fallback)
 *   - Agent memory (requires Gemini API key)
 *
 * Run: node mundane/yantra/pariksha_e2e.js
 */

import { buildSkyStateFromRaw } from "../kriya/drik_ganita.js";
import { applyAllRules } from "../kriya/phala_ganana.js";
import { observeNimitta, computeDomainHeat, classifyHeadline } from "../kriya/nimitta_pariksha.js";
import { synthesizeFallback } from "../kriya/phala_sangraha.js";

// ── Approximate planetary positions for April 12, 2026 ────────────────
const APRIL_2026_POSITIONS = {
    Sun:     { sign: "Pisces",  longitude: 358.5, isRetrograde: false, sunDistance: 0 },
    Moon:    { sign: "Leo",     longitude: 135.2, isRetrograde: false, sunDistance: 136.7 },
    Mars:    { sign: "Cancer",  longitude: 105.8, isRetrograde: false, sunDistance: 107.3 },
    Mercury: { sign: "Pisces",  longitude: 349.2, isRetrograde: false, sunDistance: 9.3 },
    Jupiter: { sign: "Gemini",  longitude: 78.4,  isRetrograde: false, sunDistance: 80.1 },
    Venus:   { sign: "Aries",   longitude: 15.6,  isRetrograde: false, sunDistance: 17.1 },
    Saturn:  { sign: "Pisces",  longitude: 343.7, isRetrograde: false, sunDistance: 14.8 },
    Rahu:    { sign: "Pisces",  longitude: 355.1, isRetrograde: true,  sunDistance: 3.4 },
    Ketu:    { sign: "Virgo",   longitude: 175.1, isRetrograde: true,  sunDistance: 176.6 },
};

const ACTIVE_ECLIPSES = [
    { type: "solar", sign: "Aquarius", durationMinutes: 142, date: "2026-02-17", nakshatra: "Shatabhisha" },
    { type: "lunar", sign: "Virgo",    durationMinutes: 205, date: "2026-03-03", nakshatra: "Hasta" },
];

async function runE2E() {
    console.log("═══════════════════════════════════════════════════════════════");
    console.log("  BRIHAT SAMHITA — FULL E2E PIPELINE");
    console.log("  Varahamihira's Flow: Nimitta → Sky → Rules → Synthesis");
    console.log("═══════════════════════════════════════════════════════════════\n");

    // ── Step 1: Observe the World (Nimitta) ──────────────────────────────
    console.log("क्रिया २: निमित्त अवलोकन (Observing the World)...");
    let nimitta;
    try {
        nimitta = await observeNimitta(30);
        console.log(`  ✅ Fetched ${nimitta.headlineCount} headlines`);
        if (nimitta.error) console.log(`  ⚠️  Error: ${nimitta.error}`);

        const hotDomains = Object.entries(nimitta.domainHeat)
            .filter(([, v]) => v.normalizedHeat > 0.2)
            .sort((a, b) => b[1].normalizedHeat - a[1].normalizedHeat);

        if (hotDomains.length > 0) {
            console.log("\n  🔥 Hot Domains in Today's News:");
            for (const [domain, v] of hotDomains.slice(0, 8)) {
                console.log(`     ${v.label.padEnd(30)} heat: ${v.normalizedHeat.toFixed(2)}  (${v.count} headlines)`);
                for (const h of v.headlines.slice(0, 2)) {
                    console.log(`       → "${h.slice(0, 80)}${h.length > 80 ? '...' : ''}"`);
                }
            }
        } else {
            console.log("  📭 No hot domains detected in news");
        }
    } catch (err) {
        console.log(`  ❌ News fetch failed: ${err.message}`);
        console.log("  → Proceeding without Nimitta (offline mode)");
        nimitta = { domainHeat: {}, headlines: [], newsText: "", headlineCount: 0 };
    }

    // ── Step 2: Build Sky State ──────────────────────────────────────────
    console.log("\n\nक्रिया ३: दृक् गणित (Sky Observation)...");
    const skyState = buildSkyStateFromRaw(APRIL_2026_POSITIONS, "2026-04-12", ACTIVE_ECLIPSES);
    skyState.domainHeat = nimitta.domainHeat; // INJECT Nimitta into sky state
    console.log(`  ✅ ${Object.keys(skyState.positions).length} planets, ${skyState.activeEclipses.length} eclipse windows`);

    // ── Step 3: Apply Rules (with Nimitta boost) ─────────────────────────
    console.log("\nक्रिया ४: फल गणन (Effect Calculation + Nimitta Boost)...");
    const analysis = applyAllRules(skyState);
    console.log(`  ✅ ${analysis.totalEffects} effects computed`);
    console.log(`  ✅ Nimitta boost applied: ${analysis.domainHeatApplied ? 'YES' : 'NO'}`);

    // Show which effects got boosted
    const boostedEffects = analysis.effects.filter(e => e.nimittaBoost > 0);
    if (boostedEffects.length > 0) {
        console.log(`\n  📈 ${boostedEffects.length} effects boosted by Nimitta:`);
        for (const e of boostedEffects.slice(0, 8)) {
            const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
            console.log(`     ${arrow} ${e.planet} in ${e.sign} → ${e.domain}: +${e.nimittaBoost}% boost (${e.preNimittaWeight?.toFixed(2)} → ${e.weight.toFixed(2)})`);
            if (e.nimittaHeadlines?.length > 0) {
                console.log(`       Headlines: "${e.nimittaHeadlines[0].slice(0, 70)}..."`);
            }
        }
    }

    // ── Step 4: Synthesis (fallback — no LLM) ────────────────────────────
    console.log("\n\nक्रिया ६: फल संग्रह (Synthesis)...");
    const forecast = synthesizeFallback(analysis);
    console.log(`  ✅ Headline: ${forecast.headline}`);
    console.log(`  ✅ ${forecast.domain_forecasts.length} domain forecasts`);
    console.log(`  ✅ ${forecast.key_transits.length} key transits`);
    console.log(`  ✅ ${forecast.geographic_focus.length} geographic focus areas`);

    // ── Final Summary ────────────────────────────────────────────────────
    console.log("\n═══════════════════════════════════════════════════════════════");
    console.log("  PIPELINE SUMMARY");
    console.log("═══════════════════════════════════════════════════════════════");
    console.log(`  📰 Headlines observed:    ${nimitta.headlineCount}`);
    console.log(`  🔥 Hot domains in news:   ${Object.keys(nimitta.domainHeat).filter(k => nimitta.domainHeat[k].normalizedHeat > 0.3).length}`);
    console.log(`  🪐 Planets tracked:       ${Object.keys(skyState.positions).length}`);
    console.log(`  🌑 Eclipse windows:       ${skyState.activeEclipses.length}`);
    console.log(`  📊 Total effects:         ${analysis.totalEffects}`);
    console.log(`  📈 Nimitta-boosted:       ${boostedEffects.length}`);
    console.log(`  🏛️  Domains affected:      ${analysis.domainScores.length}`);
    console.log(`  🔮 Conjunctions:          ${analysis.conjunctions.length}`);

    console.log("\n  Domain Outlook:");
    for (const d of analysis.domainScores.slice(0, 10)) {
        const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
        const boost = boostedEffects.some(e => e.domain === d.domain) ? " 🔥" : "";
        console.log(`    ${emoji} ${d.label.padEnd(30)} ${d.outlook.padEnd(12)} net: ${d.netScore > 0 ? "+" : ""}${d.netScore.toFixed(2)}${boost}`);
    }

    console.log("\n═══════════════════════════════════════════════════════════════");
    console.log("  Full Varahamihira pipeline complete. 🙏");
    console.log("  News informs predictions. Memory is wired. Stars lead.");
    console.log("═══════════════════════════════════════════════════════════════");
}

runE2E().catch(err => {
    console.error("E2E test failed:", err);
    process.exit(1);
});
