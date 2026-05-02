/**
 * यन्त्र — अनुक्रम (Anukrama: Simulation & Backtest)
 *
 * Backtest Simulation Runner — Year-Long Mundane Engine Test
 *
 * Runs Brihat Samhita rules at Panchanga triggers (Purnima/Amavasya/Ingress)
 * for a full year. Separates foreground (new) vs background (persistent) effects.
 *
 * Position data: graha_sthiti_2025_2026.json (sidereal, Lahiri)
 * In production: Swiss Ephemeris via Firestore.
 *
 * Run: node mundane/yantra/anukrama.js
 */

import { applyAllRules } from "../kriya/phala_ganana.js";
import { buildSkyStateFromRaw } from "../kriya/drik_ganita.js";
import { synthesizeFallback } from "../kriya/phala_sangraha.js";
import { getAllTriggerDates, formatTriggerCalendar } from "../kriya/kaal_nirnaya.js";
import { writeFileSync, readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── Position Data & Interpolation ──────────────────────────────────────

const MONTHLY_POSITIONS = JSON.parse(
    readFileSync(join(__dirname, "..", "data", "graha_sthiti_2025_2026.json"), "utf-8")
);

const ZODIAC_SIGNS = ["Aries","Taurus","Gemini","Cancer","Leo","Virgo",
                      "Libra","Scorpio","Sagittarius","Capricorn","Aquarius","Pisces"];

/**
 * Interpolate positions for an exact date between two monthly snapshots.
 * Gives each trigger unique fast-planet positions.
 */
function getPositionsForDate(dateStr) {
    const months = Object.keys(MONTHLY_POSITIONS).sort();
    const target = new Date(dateStr);

    // Find bracketing months
    let before = months[0], after = months[months.length - 1];
    for (let i = 0; i < months.length - 1; i++) {
        if (target >= new Date(months[i] + "-01") && target < new Date(months[i + 1] + "-01")) {
            before = months[i]; after = months[i + 1]; break;
        }
    }

    const b = MONTHLY_POSITIONS[before], a = MONTHLY_POSITIONS[after];
    if (!a || before === after) return b;

    const frac = Math.max(0, Math.min(1,
        (target - new Date(before + "-01")) / (new Date(after + "-01") - new Date(before + "-01"))
    ));

    const result = {};
    for (const planet of Object.keys(b)) {
        if (!a[planet]) { result[planet] = { ...b[planet] }; continue; }

        let lonDiff = a[planet].longitude - b[planet].longitude;
        if (lonDiff > 180) lonDiff -= 360;
        if (lonDiff < -180) lonDiff += 360;
        let lon = (b[planet].longitude + lonDiff * frac + 360) % 360;

        let sdDiff = a[planet].sunDistance - b[planet].sunDistance;
        if (sdDiff > 180) sdDiff -= 360;
        if (sdDiff < -180) sdDiff += 360;
        let sd = b[planet].sunDistance + sdDiff * frac;
        if (sd < 0) sd += 360;
        if (sd > 180) sd = 360 - sd;

        result[planet] = {
            sign: ZODIAC_SIGNS[Math.floor(lon / 30) % 12],
            longitude: Math.round(lon * 100) / 100,
            isRetrograde: b[planet].isRetrograde,
            sunDistance: Math.round(sd * 100) / 100,
        };
    }
    return result;
}

// ─── Eclipse Data ────────────────────────────────────────────────────────

const ECLIPSES = [
    { type: "solar", sign: "Pisces",   date: "2025-03-29", durationMinutes: 155 },
    { type: "lunar", sign: "Virgo",    date: "2025-09-07", durationMinutes: 180 },
    { type: "solar", sign: "Aquarius", date: "2026-02-17", durationMinutes: 142 },
    { type: "lunar", sign: "Virgo",    date: "2026-03-03", durationMinutes: 205 },
];

function getActiveEclipses(dateStr) {
    const d = new Date(dateStr);
    return ECLIPSES.filter(e => {
        const days = (d - new Date(e.date)) / 86400000;
        return days >= 0 && days <= 90; // 3-month window
    });
}

// ─── Foreground / Background Classification ──────────────────────────────

const SLOW_PLANETS = new Set(["Saturn", "Jupiter", "Rahu", "Ketu"]);

function classifyEffects(analysis, prevAnalysis) {
    const prevKeys = new Set();
    if (prevAnalysis) {
        for (const e of prevAnalysis.effects) prevKeys.add(`${e.planet}|${e.sign}|${e.domain}`);
    }

    const foreground = [], background = [];
    for (const e of analysis.effects) {
        const isNew = !prevKeys.has(`${e.planet}|${e.sign}|${e.domain}`);
        const isFast = !SLOW_PLANETS.has(e.planet) && !e.planet?.includes("+");
        const isSpecial = e.category === "conjunction" || e.category === "eclipse"
            || e.desc?.includes("EXALTED") || e.desc?.includes("DEBILITATED");

        (isNew || isFast || isSpecial ? foreground : background).push(e);
    }
    foreground.sort((a, b) => b.weight - a.weight);
    return { foreground, background };
}

function pickHeadline(foreground, background, trigger) {
    const pool = foreground.length > 0 ? foreground : background;
    if (pool.length === 0) return "No significant signals.";
    const e = pool[0];
    const prefix = trigger.type === "ingress" ? "⚡ " :
        e.desc?.includes("EXALTED") ? "✨ " :
        e.desc?.includes("DEBILITATED") ? "⚠️ " : "";
    return `${prefix}${e.planet} in ${e.sign}: ${e.desc}`;
}

// ─── Simulation ──────────────────────────────────────────────────────────

export function runSimulation(startDate, endDate) {
    const triggers = getAllTriggerDates(startDate, endDate);
    const results = [];
    let prev = null;

    console.log(`\n${"═".repeat(70)}`);
    console.log(`  MUNDANE SIMULATION: ${startDate} → ${endDate} (${triggers.length} triggers)`);
    console.log(`${"═".repeat(70)}\n`);

    for (const trigger of triggers) {
        const positions = getPositionsForDate(trigger.date);
        const eclipses = getActiveEclipses(trigger.date);
        const skyState = buildSkyStateFromRaw(positions, trigger.date, eclipses);
        const analysis = applyAllRules(skyState);
        const { foreground, background } = classifyEffects(analysis, prev);
        const headline = pickHeadline(foreground, background, trigger);

        results.push({
            trigger, date: trigger.date,
            totalEffects: analysis.totalEffects,
            fg: foreground.length, bg: background.length,
            headline,
            topFg: foreground.slice(0, 3).map(e => `${e.planet}→${e.domain}(${e.dir})`),
            domainScores: analysis.domainScores.slice(0, 4),
            eclipseWindows: eclipses.length,
        });

        // Print
        const icon = { purnima: "🌕", amavasya: "🌑", ingress: "⚡" }[trigger.type] || "📌";
        console.log(`${icon} ${trigger.date} [${trigger.type}] — ${foreground.length} new, ${background.length} ongoing, ${eclipses.length} ecl`);
        console.log(`  📰 ${headline}`);

        // Foreground domains
        const fgDomains = {};
        for (const e of foreground) {
            if (!fgDomains[e.domain]) fgDomains[e.domain] = { p: 0, n: 0 };
            if (e.dir === "pos") fgDomains[e.domain].p += e.weight;
            else if (e.dir === "neg") fgDomains[e.domain].n += e.weight;
        }
        const fgSorted = Object.entries(fgDomains)
            .map(([d, v]) => ({ d, net: Math.round((v.p - v.n) * 100) / 100 }))
            .sort((a, b) => Math.abs(b.net) - Math.abs(a.net));
        for (const { d, net } of fgSorted.slice(0, 3)) {
            console.log(`  ${net > 0 ? "🟢" : "🔴"} [NEW] ${d}: ${net > 0 ? "+" : ""}${net}`);
        }
        if (background.length > 0) {
            const bgDomains = [...new Set(background.map(e => e.domain))].slice(0, 3);
            console.log(`  🔹 [ongoing] ${bgDomains.join(", ")}`);
        }
        console.log("");
        prev = analysis;
    }

    return { triggers, results };
}

// ─── Analysis ────────────────────────────────────────────────────────────

export function analyzeSimulation({ results }) {
    const lines = [`\n${"═".repeat(70)}`, "  SIMULATION ANALYSIS", `${"═".repeat(70)}`];

    // Domain frequency
    const freq = {};
    for (const r of results) {
        for (const d of r.domainScores) {
            if (!freq[d.domain]) freq[d.domain] = { n: 0, label: d.label, net: 0, fav: 0, chal: 0 };
            freq[d.domain].n++; freq[d.domain].net += d.netScore;
            if (d.outlook === "favorable") freq[d.domain].fav++;
            if (d.outlook === "challenging") freq[d.domain].chal++;
        }
    }

    lines.push("\n## Domain Activity");
    for (const [, d] of Object.entries(freq).sort((a, b) => b[1].n - a[1].n).slice(0, 12)) {
        const avg = (d.net / d.n).toFixed(2);
        const icon = d.chal > d.fav ? "🔴" : d.fav > d.chal ? "🟢" : "🟡";
        lines.push(`  ${icon} ${d.label.padEnd(30)} ${d.n}x, avg: ${avg}, fav: ${d.fav}, chal: ${d.chal}`);
    }

    // Eclipse coverage
    const eclZero = results.filter(r => r.eclipseWindows === 0).length;
    lines.push(`\n## Eclipse: ${results.length - eclZero}/${results.length} triggers with active windows`);

    // Headline diversity
    const unique = new Set(results.map(r => r.headline)).size;
    lines.push(`## Headlines: ${unique} unique / ${results.length} total (${(unique/results.length*100).toFixed(0)}%)`);

    const report = lines.join("\n");
    console.log(report);
    return report;
}

// ─── CLI Entry Point ─────────────────────────────────────────────────────

if (process.argv[1]?.includes("anukrama")) {
    console.log(formatTriggerCalendar("2025-04-01", "2026-04-12"));
    const sim = runSimulation("2025-04-01", "2026-04-12");
    analyzeSimulation(sim);
    writeFileSync(join(__dirname, "..", "data", "simulation_results.json"), JSON.stringify(sim, null, 2));
    console.log(`\n📁 Results: ${join(__dirname, "..", "data", "simulation_results.json")}`);
}
