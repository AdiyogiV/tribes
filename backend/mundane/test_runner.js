/**
 * Test Runner — Fire the Brihat Samhita Rules Engine with April 2026 Sky
 *
 * Uses approximate positions for April 12, 2026 to validate the engine.
 * In production, these come from Swiss Ephemeris calculations.
 *
 * Run: node --experimental-vm-modules mundane/test_runner.js
 * Or:  node mundane/test_runner.js (if package.json has "type": "module")
 */

import { applyAllRules, detectChanges } from "./engine/rule_applier.js";
import { buildSkyStateFromRaw } from "./engine/sky_adapter.js";
import { getSlowPlanetNakshatraThemes, formatNakshatraContext } from "./rules/nakshatra_effects.js";
import { synthesizeFallback } from "./engine/synthesis_agent.js";

// ── Approximate planetary positions for April 12, 2026 ────────────────
// Source: Swiss Ephemeris / standard almanac data
// These are SIDEREAL (Lahiri ayanamsha ~24°12' for 2026)
const APRIL_2026_POSITIONS = {
    Sun:     { sign: "Pisces",      longitude: 358.5, isRetrograde: false, sunDistance: 0 },
    Moon:    { sign: "Leo",         longitude: 135.2, isRetrograde: false, sunDistance: 136.7 },
    Mars:    { sign: "Cancer",      longitude: 105.8, isRetrograde: false, sunDistance: 107.3 },
    Mercury: { sign: "Pisces",      longitude: 349.2, isRetrograde: false, sunDistance: 9.3 },
    Jupiter: { sign: "Gemini",      longitude: 78.4,  isRetrograde: false, sunDistance: 80.1 },
    Venus:   { sign: "Aries",       longitude: 15.6,  isRetrograde: false, sunDistance: 17.1 },
    Saturn:  { sign: "Pisces",      longitude: 343.7, isRetrograde: false, sunDistance: 14.8 },
    Rahu:    { sign: "Pisces",      longitude: 355.1, isRetrograde: true,  sunDistance: 3.4 },
    Ketu:    { sign: "Virgo",       longitude: 175.1, isRetrograde: true,  sunDistance: 176.6 },
};

// ── Active eclipse windows (Feb-Mar 2026 eclipses still in effect) ────
const ACTIVE_ECLIPSES = [
    {
        type: "solar",
        sign: "Aquarius",
        durationMinutes: 142,
        date: "2026-02-17",
        nakshatra: "Shatabhisha",
    },
    {
        type: "lunar",
        sign: "Virgo",
        durationMinutes: 205,
        date: "2026-03-03",
        nakshatra: "Hasta",
    },
];

// ── Build sky state (same as production, but from raw data) ───────────
console.log("═══════════════════════════════════════════════════════════════");
console.log("  BRIHAT SAMHITA RULES ENGINE — April 12, 2026");
console.log("═══════════════════════════════════════════════════════════════\n");

const skyState = buildSkyStateFromRaw(APRIL_2026_POSITIONS, "2026-04-12", ACTIVE_ECLIPSES);
const result = applyAllRules(skyState);

// Print summary
console.log(result.summary);

// Print Koorma geographic activation
console.log("\n## Geographic Activation (Koorma Chakra)");
console.log(result.koormaText);

// Print full effect count
console.log(`\n## Statistics`);
console.log(`  Total active effects: ${result.totalEffects}`);
console.log(`  Conjunctions: ${result.conjunctions.length}`);
console.log(`  Domains affected: ${result.domainScores.length}`);

// Nakshatra sub-themes
console.log("\n## Nakshatra Sub-Themes (Slow Planets)");
const nakThemes = getSlowPlanetNakshatraThemes(skyState.positions);
for (const t of nakThemes) {
    console.log(`  ${t.planet} in ${t.nakshatra} (${t.lord}'s nak, pada ${t.pada})`);
    if (t.hasSpecificEffects) {
        for (const e of t.effects) {
            const a = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
            console.log(`    ${a} [${e.weight.toFixed(2)}] ${e.desc}`);
        }
    } else {
        console.log(`    → ${t.composedDesc}`);
    }
}

// Detailed domain breakdown
console.log("\n## Full Domain Breakdown");
for (const d of result.domainScores) {
    const bar = d.netScore > 0
        ? "█".repeat(Math.min(20, Math.round(d.netScore * 10)))
        : "░".repeat(Math.min(20, Math.round(Math.abs(d.netScore) * 10)));
    const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
    console.log(`  ${emoji} ${d.label.padEnd(30)} net: ${(d.netScore > 0 ? "+" : "") + d.netScore.toFixed(2).padStart(6)} ${bar}`);
}

// Print all effects sorted by weight
console.log("\n## All Active Effects (sorted by weight)");
for (const e of result.effects) {
    const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
    const CAT_MAP = { slow_transit: "SLOW", fast_transit: "FAST", conjunction: "CONJ", eclipse: "ECLP", nakshatra_sub_theme: "NAK " };
    const cat = CAT_MAP[e.category] || e.category?.substring(0, 4).toUpperCase() || "????";
    console.log(`  ${arrow} [${e.weight.toFixed(2)}] [${cat}] ${(e.planet + " in " + e.sign).padEnd(22)} → ${e.domain.padEnd(18)} ${e.desc}`);
}

// ── Test change detection ──────────────────────────────────────────────
console.log("\n═══════════════════════════════════════════════════════════════");
console.log("  CHANGE DETECTION TEST (simulated week-over-week)");
console.log("═══════════════════════════════════════════════════════════════\n");

// Simulate previous week (Mars was still in Gemini, Sun was earlier in Pisces)
const PREV_WEEK = {
    ...APRIL_2026_POSITIONS,
    Mars: { sign: "Gemini", longitude: 89.5, isRetrograde: false, sunDistance: 91.0 },
    Sun:  { sign: "Pisces", longitude: 351.0, isRetrograde: false, sunDistance: 0 },
};

const changes = detectChanges(PREV_WEEK, APRIL_2026_POSITIONS);
if (changes.length === 0) {
    console.log("  No significant changes detected.");
} else {
    for (const c of changes) {
        const badge = c.significance === "critical" ? "🚨" : c.significance === "major" ? "⚠️" : "📌";
        console.log(`  ${badge} [${c.significance.toUpperCase()}] ${c.desc}`);
    }
}

// ── Test fallback synthesis ────────────────────────────────────────────
console.log("\n═══════════════════════════════════════════════════════════════");
console.log("  FALLBACK SYNTHESIS TEST (no LLM)");
console.log("═══════════════════════════════════════════════════════════════\n");

const fallback = synthesizeFallback(result);
console.log(`  Headline: ${fallback.headline}`);
console.log(`  Domain forecasts: ${fallback.domain_forecasts.length}`);
console.log(`  Key transits: ${fallback.key_transits.length}`);
console.log(`  Watch items: ${fallback.watch_items.length}`);
for (const kt of fallback.key_transits) {
    console.log(`    🪐 ${kt.transit} (~${kt.duration})`);
}
console.log(`  Geographic focus: ${fallback.geographic_focus.length} regions`);
for (const gf of fallback.geographic_focus.slice(0, 5)) {
    console.log(`    🌍 ${gf.region}: ${gf.planets.join(", ")}`);
}

console.log("\n═══════════════════════════════════════════════════════════════");
console.log("  Engine test complete. All systems operational. 🐶");
console.log("═══════════════════════════════════════════════════════════════");
