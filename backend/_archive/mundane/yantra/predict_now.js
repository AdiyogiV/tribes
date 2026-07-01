/**
 * यन्त्र — PREDICT NOW
 *
 * Runs the FULL Varahamihira system for TODAY:
 *   1. Real sidereal positions (interpolated Lahiri)
 *   2. Fresh news from Guardian API (last 7 days)
 *   3. Nimitta extraction from headlines
 *   4. Varga pipeline (930 rules, 6 layers)
 *   5. LLM synthesis (Gemini Flash)
 *   6. Past prediction validation against current news
 *
 * Run: node mundane/yantra/predict_now.js
 */

import { enrichPositions } from "../kriya/drik_ganita.js";
import { computeDomainHeat, classifyHeadline } from "../kriya/nimitta_pariksha.js";
import { synthesizeForecast, synthesizeFallback } from "../kriya/phala_sangraha.js";
import { fetchHeadlinesForDate, formatHeadlinesForPrompt } from "../../lib/news_archive.js";
import { normalizeDomain } from "../adhyaya/vishaya.js";
import { runPipeline, summarizePipeline } from "../varga/pipeline.js";
import { extractNimittaFromNews } from "../kriya/nimitta_sangraha.js";
import { writeFileSync, readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "AIzaSyCwbDKQzY_V4dy5x5Oj_rZ6lRuiWFRLgwc";

// ─── Positions ──────────────────────────────────────────────────────────
const MONTHLY_POSITIONS = JSON.parse(
    readFileSync(join(__dirname, "..", "data", "graha_sthiti_2025_2026.json"), "utf-8")
);
const ZODIAC_SIGNS = ["Aries","Taurus","Gemini","Cancer","Leo","Virgo",
                      "Libra","Scorpio","Sagittarius","Capricorn","Aquarius","Pisces"];

function getPositionsForDate(dateStr) {
    const months = Object.keys(MONTHLY_POSITIONS).sort();
    const target = new Date(dateStr);
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

function getSeason(date) {
    const m = date.getMonth();
    if (m === 2 || m === 3) return 'vasanta';
    if (m === 4 || m === 5) return 'grishma';
    if (m === 6 || m === 7) return 'varsha';
    if (m === 8 || m === 9) return 'sharad';
    if (m === 10 || m === 11) return 'hemanta';
    return 'shishira';
}

function getNakshatra(longitude) {
    const NAKSHATRAS = [
        'Aswini','Bharani','Krittika','Rohini','Mrigasira','Ardra','Punarvasu','Pushya','Aslesha',
        'Magha','Purvaphalguni','Uttaraphalguni','Hasta','Chitra','Swati','Visakha','Anuradha','Jyeshta',
        'Moola','Purvashadha','Uttarashadha','Sravana','Dhanishta','Satabhishak','Purvabhadra','Uttarabhadra','Revati'
    ];
    return NAKSHATRAS[Math.floor(((longitude % 360) + 360) % 360 / (360/27))];
}

// ─── Load past predictions for context ──────────────────────────────────
let pastPredictions = [];
try {
    const past = JSON.parse(readFileSync(join(__dirname, "..", "data", "simulation_varga_llm_results.json"), "utf-8"));
    pastPredictions = past.predictionStore || [];
} catch { /* no past data */ }

// ─── Main ───────────────────────────────────────────────────────────────
async function predictNow() {
    const today = new Date();
    const dateStr = today.toISOString().split('T')[0];
    const season = getSeason(today);

    console.log(`\n${"═".repeat(80)}`);
    console.log(`  बृहत्संहिता — LIVE PREDICTION FOR ${dateStr}`);
    console.log(`  Season: ${season} | Samvatsara: Plavanga (BS Ch.8)`);
    console.log(`${"═".repeat(80)}\n`);

    // ── Step 1: Sky State ────────────────────────────────────────────────
    console.log("━━━ STEP 1: SKY STATE (दृक् गणित) ━━━");
    const positions = getPositionsForDate(dateStr);
    const skyState = { positions: enrichPositions(positions) };

    for (const [planet, pos] of Object.entries(positions)) {
        const nak = getNakshatra(pos.longitude);
        const retro = pos.isRetrograde ? ' ℞' : '';
        console.log(`  🪐 ${planet.padEnd(10)} ${pos.sign.padEnd(12)} ${pos.longitude.toFixed(1)}° (${nak})${retro}`);
    }
    console.log('');

    // ── Step 2: News → Nimitta ───────────────────────────────────────────
    console.log("━━━ STEP 2: NIMITTA (निमित्त संग्रह) ━━━");

    // Fetch last 3 days of news for broader coverage
    const allHeadlines = [];
    for (let daysBack = 0; daysBack <= 2; daysBack++) {
        const d = new Date(today);
        d.setDate(d.getDate() - daysBack);
        const ds = d.toISOString().split('T')[0];
        try {
            const hl = await fetchHeadlinesForDate(ds, { limit: 20 });
            allHeadlines.push(...hl);
            console.log(`  📰 ${ds}: ${hl.length} headlines`);
        } catch (e) {
            console.log(`  ⚠️ ${ds}: fetch failed (${e.message?.slice(0, 40)})`);
        }
        await new Promise(r => setTimeout(r, 300));
    }

    // Deduplicate headlines by title
    const seen = new Set();
    const headlines = allHeadlines.filter(h => {
        const key = (h.title || h.headline || '').slice(0, 50);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
    });

    console.log(`  Total unique headlines: ${headlines.length}`);

    // Extract nimitta
    const nimitta = extractNimittaFromNews(headlines);
    if (nimitta.length > 0) {
        console.log(`  🌍 Nimitta extracted: ${nimitta.length}`);
        for (const n of nimitta.slice(0, 5)) {
            console.log(`    → [${n.type}] ${(n.headline || '').slice(0, 70)}`);
        }
    }

    // Domain heat
    const domainHeat = computeDomainHeat(headlines);
    const hotDomains = Object.entries(domainHeat)
        .filter(([, v]) => v.normalizedHeat > 0.2)
        .sort((a, b) => b[1].normalizedHeat - a[1].normalizedHeat)
        .slice(0, 6);

    console.log(`\n  🔥 Hot domains in news:`);
    for (const [domain, v] of hotDomains) {
        const bar = '█'.repeat(Math.round(v.normalizedHeat * 20));
        console.log(`    ${(v.label || domain).padEnd(25)} heat: ${v.normalizedHeat.toFixed(2)} (${v.count} articles) ${bar}`);
    }
    console.log('');

    // ── Step 3: Varga Pipeline ───────────────────────────────────────────
    console.log("━━━ STEP 3: VARGA PIPELINE (930 rules, 6 layers) ━━━");

    const earthquakes = [];
    const portents = [];
    for (const n of nimitta) {
        if (n.type === 'earthquake_report') {
            earthquakes.push({ nakshatra: 'Aswini', timeOfDay: 'day', magnitude: 4.5, place: n.headline, source: 'news' });
        }
        if (n.type.includes('portent') || n.type.includes('anomaly') || n.type.includes('volcanic')) {
            portents.push({ type: n.type, desc: n.headline, tier: 2, source: 'news' });
        }
    }

    const observations = {
        sunVisual: { color: 'normal', discShape: 'normal', hasThamasaKeelaka: false, rayColors: [], hasMockSuns: false, hasHalo: false },
        season,
        earthquakes,
        portents,
        omens: [],
        marsContext: {},
        mercuryContext: {},
        jupiterContext: { transitSpeed: 'normal' },
        venusContext: { visibility: 'evening' },
        saturnContext: {},
    };

    const pipelineResult = runPipeline(skyState, observations, { date: dateStr });
    const { effects, stats, jupiterYear, convergenceMap } = pipelineResult;

    console.log(`  Raw effects:       ${stats.rawCount}`);
    console.log(`  After filtering:   ${stats.filteredOut} removed`);
    console.log(`  After cancellation: ${stats.cancelledCount} cancelled`);
    console.log(`  Final effects:     ${stats.finalCount}`);
    console.log(`  Convergent domains: ${stats.convergentDomains}`);
    console.log(`  Jupiter Year:      ${jupiterYear?.samvatsara?.name} (${jupiterYear?.samvatsara?.dir})`);
    console.log(`  Pipeline time:     ${stats.elapsedMs}ms`);
    console.log('');

    // Domain scores
    const domainScores = {};
    for (const e of effects) {
        if (!domainScores[e.domain]) domainScores[e.domain] = { posSum: 0, negSum: 0, count: 0 };
        if (e.dir === 'pos') domainScores[e.domain].posSum += e.weight;
        else if (e.dir === 'neg') domainScores[e.domain].negSum += e.weight;
        domainScores[e.domain].count++;
    }
    const domainScoreArr = Object.entries(domainScores)
        .map(([d, s]) => ({
            domain: d,
            label: d,
            outlook: s.posSum > s.negSum ? "favorable" : s.negSum > s.posSum ? "challenging" : "mixed",
            netScore: s.posSum - s.negSum,
            count: s.count,
        }))
        .sort((a, b) => Math.abs(b.netScore) - Math.abs(a.netScore));

    console.log("  📊 Domain outlook:");
    for (const d of domainScoreArr.slice(0, 8)) {
        const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
        console.log(`    ${emoji} ${d.domain.padEnd(20)} ${d.outlook.padEnd(12)} net: ${d.netScore > 0 ? '+' : ''}${d.netScore.toFixed(2)} (${d.count} effects)`);
    }
    console.log('');

    // Top effects
    console.log("  ⚡ Top effects:");
    for (const e of effects.slice(0, 10)) {
        const dir = e.dir === 'pos' ? '↑' : e.dir === 'neg' ? '↓' : '~';
        const regions = e.targetRegions?.length > 0 ? ` → ${e.targetRegions.slice(0, 3).join(', ')}` : '';
        const peak = e.manifestation?.peakDate ? ` [peak: ${e.manifestation.peakDate}]` : '';
        console.log(`    ${dir} [${e.weight.toFixed(2)}] ${e.planet || '?'}: ${e.desc.slice(0, 70)}${regions}${peak}`);
    }
    console.log('');

    // ── Step 4: Validate past predictions against today's news ──────────
    console.log("━━━ STEP 4: PAST PREDICTION VALIDATION ━━━");
    const todayDate = new Date(dateStr);
    let validated = 0, failed = 0, duePreds = [];

    for (const pred of pastPredictions) {
        if (pred.status !== 'pending') continue;
        const manifest = new Date(pred.manifestDate);
        // Check if within ±14 day window of today
        const daysDiff = Math.abs((todayDate - manifest) / 86400000);
        if (daysDiff > 14) continue;

        duePreds.push(pred);
        const heat = domainHeat[pred.domain];
        const wasHotAtCreation = pred.creationDomains?.includes(pred.domain);
        const threshold = wasHotAtCreation ? 0.6 : 0.3;

        if (heat && heat.normalizedHeat > threshold && heat.count >= (wasHotAtCreation ? 5 : 1)) {
            const sentiment = heat.avgSentiment ?? 0;
            const dirMatch = (pred.direction === 'neg' && sentiment <= 0) ||
                           (pred.direction === 'pos' && sentiment >= 0) ||
                           pred.direction === 'mix';
            if (dirMatch) {
                console.log(`  ✅ PLAUSIBLE: [${pred.domain}] "${pred.statement.slice(0, 80)}..."`);
                console.log(`     Evidence: ${pred.domain} heat ${heat.normalizedHeat.toFixed(2)}, ${heat.count} headlines`);
                validated++;
            } else {
                console.log(`  ❌ WRONG DIRECTION: [${pred.domain}] predicted ${pred.direction}, sentiment ${sentiment.toFixed(2)}`);
                failed++;
            }
        } else {
            console.log(`  ❌ UNCONFIRMED: [${pred.domain}] "${pred.statement.slice(0, 70)}..." — domain quiet`);
            failed++;
        }
    }
    if (duePreds.length === 0) console.log("  No past predictions due within ±14 days of today.");
    else console.log(`\n  Score: ${validated}/${duePreds.length} plausible (${(validated/duePreds.length*100).toFixed(0)}%)`);
    console.log('');

    // ── Step 5: LLM Synthesis ────────────────────────────────────────────
    console.log("━━━ STEP 5: GEMINI SYNTHESIS (फल संग्रह) ━━━");

    // Build past predictions context for LLM (dedup)
    const pendingByDomain = {};
    for (const p of pastPredictions.filter(p => p.status === 'pending')) {
        if (!pendingByDomain[p.domain]) pendingByDomain[p.domain] = [];
        pendingByDomain[p.domain].push(p);
    }
    const ledgerLines = [];
    for (const [dom, preds] of Object.entries(pendingByDomain).sort((a, b) => b[1].length - a[1].length)) {
        const latest = preds[preds.length - 1];
        ledgerLines.push(`- ${dom} (${preds.length} pending): "${latest.statement.slice(0, 60)}..."`);
    }
    const predictionLedger = ledgerLines.length > 0
        ? "### ⏳ Pending Predictions (DO NOT repeat):\n" + ledgerLines.join("\n")
        : null;

    const newsText = formatHeadlinesForPrompt(headlines);
    const summary = summarizePipeline(pipelineResult);

    // Build koorma text
    const regionEffects = effects.filter(e => e.targetRegions?.length > 0);
    const koormaLines = [];
    const regionSet = new Set();
    for (const e of regionEffects.slice(0, 10)) {
        for (const r of e.targetRegions.slice(0, 3)) {
            if (!regionSet.has(r)) {
                regionSet.add(r);
                const dir = e.dir === 'pos' ? '↑' : e.dir === 'neg' ? '↓' : '~';
                koormaLines.push(`${r}: ${dir} ${e.desc.slice(0, 60)} (${e.domain})`);
            }
        }
    }

    const analysisForLLM = {
        date: dateStr,
        effects,
        totalEffects: stats.finalCount,
        summary,
        domainScores: domainScoreArr,
        koormaText: koormaLines.length > 0 ? koormaLines.join("\n") : null,
        nakshatraText: null,
        foregroundEffects: effects, // All are foreground for single reading
        backgroundEffects: [],
        newsContext: newsText,
        memoryContext: null,
        predictionLedger,
        domainCoverage: null,
        nimittaHotDomains: hotDomains.map(([d, v]) => ({
            domain: d, label: v.label || d, heat: v.normalizedHeat, headlines: v.count
        })),
    };

    let forecast;
    try {
        forecast = await synthesizeForecast(GEMINI_API_KEY, analysisForLLM, { temperature: 0.5 });
        console.log(`  🤖 Model: ${forecast._meta?.model}`);
        console.log(`  ⏱ Duration: ${forecast._meta?.durationMs}ms`);
    } catch (err) {
        console.log(`  ⚠️ LLM failed: ${err.message}`);
        forecast = synthesizeFallback(analysisForLLM);
    }

    // ── Step 6: Output ───────────────────────────────────────────────────
    console.log('');
    console.log(`${"═".repeat(80)}`);
    console.log(`  बृहत्संहिता PREDICTION — ${dateStr}`);
    console.log(`${"═".repeat(80)}`);
    console.log('');

    if (forecast.headline) {
        console.log(`  📢 ${forecast.headline}`);
        console.log('');
    }

    if (forecast.executive_summary) {
        console.log(`  ${forecast.executive_summary}`);
        console.log('');
    }

    if (forecast.domain_forecasts?.length > 0) {
        console.log("  ━━━ DOMAIN FORECASTS ━━━");
        for (const df of forecast.domain_forecasts) {
            const emoji = df.outlook === "favorable" ? "🟢" : df.outlook === "challenging" ? "🔴" : "🟡";
            console.log(`  ${emoji} ${(df.domain || '').toUpperCase()} — ${df.outlook} (confidence: ${df.confidence})`);
            console.log(`    ${df.forecast}`);
            console.log(`    Timeframe: ${df.timeframe}`);
            console.log('');
        }
    }

    if (forecast.geographic_focus?.length > 0) {
        console.log("  ━━━ GEOGRAPHIC FOCUS ━━━");
        for (const gf of forecast.geographic_focus) {
            console.log(`  🌍 ${gf.region}: ${gf.theme} [${(gf.planets || []).join(', ')}]`);
        }
        console.log('');
    }

    if (forecast.predictions?.length > 0) {
        console.log("  ━━━ PREDICTIONS ━━━");
        for (let i = 0; i < forecast.predictions.length; i++) {
            const p = forecast.predictions[i];
            const dir = p.direction === 'pos' ? '↑' : p.direction === 'neg' ? '↓' : '↔';
            console.log(`  ${dir} PREDICTION ${i+1}: [${(p.domain || '').toUpperCase()}] confidence: ${p.confidence}`);
            console.log(`    ${p.statement}`);
            console.log(`    Timeframe: ${p.timeframe}`);
            console.log(`    Driving planet: ${p.driving_planet || '?'}`);
            console.log(`    Basis: ${p.basis || 'rules engine'}`);
            console.log('');
        }
    }

    if (forecast.key_transits?.length > 0) {
        console.log("  ━━━ KEY TRANSITS ━━━");
        for (const kt of forecast.key_transits) {
            console.log(`  🪐 ${kt.transit}: ${kt.significance} (${kt.duration})`);
        }
        console.log('');
    }

    if (forecast.watch_items?.length > 0) {
        console.log("  ━━━ WATCH ITEMS ━━━");
        for (const wi of forecast.watch_items) {
            console.log(`  👁 ${wi}`);
        }
        console.log('');
    }

    if (forecast.brihat_samhita_note) {
        console.log(`  📜 ${forecast.brihat_samhita_note}`);
        console.log('');
    }

    // Save
    const outputPath = join(__dirname, "..", "data", `prediction_${dateStr}.json`);
    writeFileSync(outputPath, JSON.stringify({
        date: dateStr,
        season,
        positions,
        headlineCount: headlines.length,
        nimittaCount: nimitta.length,
        hotDomains: hotDomains.map(([d, v]) => ({ domain: d, heat: v.normalizedHeat })),
        pipelineStats: stats,
        jupiterYear: jupiterYear?.samvatsara?.name,
        forecast,
        pastPredictionValidation: { due: duePreds.length, validated, failed },
        generatedAt: new Date().toISOString(),
    }, null, 2));
    console.log(`  📁 Saved: ${outputPath}`);
    console.log(`${"═".repeat(80)}`);
}

predictNow().catch(err => {
    console.error("Prediction failed:", err);
    process.exit(1);
});
