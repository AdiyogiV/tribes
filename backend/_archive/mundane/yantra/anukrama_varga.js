/**
 * यन्त्र — अनुक्रम VARGA (Full Year — Complete System)
 *
 * The DEFINITIVE full-year simulation combining ALL subsystems:
 *
 *   1. REAL sidereal positions (interpolated Lahiri from graha_sthiti_2025_2026.json)
 *   2. REAL historical news (Guardian API) → Nimitta extraction
 *   3. Varga pipeline (930 rules, 6 layers, deduplication, cancellation)
 *   4. LLM synthesis (Gemini Flash) — narrative + structured predictions
 *   5. Confidence learning (accumulates across readings)
 *   6. Memory (past readings inform future synthesis)
 *   7. Prediction lifecycle (PAKA-aware store, due-date validation, anti-echo)
 *
 * This is Varahamihira's process with modern infrastructure:
 *   Sky (Drik Ganita) + Earth (Nimitta) + Rules (Varga 930) + Scholar (Gemini)
 *
 * Run: node mundane/yantra/anukrama_varga.js
 */

import { getAllTriggerDates } from "../kriya/kaal_nirnaya.js";
import { enrichPositions } from "../kriya/drik_ganita.js";
import { computeDomainHeat, validatePredictions } from "../kriya/nimitta_pariksha.js";
import { synthesizeForecast, synthesizeFallback } from "../kriya/phala_sangraha.js";
import { fetchHeadlinesForDate, formatHeadlinesForPrompt } from "../../lib/news_archive.js";
import { normalizeDomain } from "../adhyaya/vishaya.js";
import { runPipeline, summarizePipeline } from "../varga/pipeline.js";
import { extractNimittaFromNews } from "../kriya/nimitta_sangraha.js";
import { writeFileSync, readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── API Key ────────────────────────────────────────────────────────────
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "AIzaSyCwbDKQzY_V4dy5x5Oj_rZ6lRuiWFRLgwc";

// ─── Eclipse data for the period ────────────────────────────────────────
const ECLIPSES = [
    { type: "solar", sign: "Pisces",   date: "2025-03-29", durationMinutes: 155 },
    { type: "lunar", sign: "Virgo",    date: "2025-09-07", durationMinutes: 180 },
    { type: "solar", sign: "Aquarius", date: "2026-02-17", durationMinutes: 142 },
    { type: "lunar", sign: "Virgo",    date: "2026-03-03", durationMinutes: 205 },
];

// ─── Real Positions (Lahiri sidereal, interpolated) ─────────────────────
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

// ─── Season from date ───────────────────────────────────────────────────
function getSeason(date) {
    const m = date.getMonth();
    if (m === 2 || m === 3) return 'vasanta';
    if (m === 4 || m === 5) return 'grishma';
    if (m === 6 || m === 7) return 'varsha';
    if (m === 8 || m === 9) return 'sharad';
    if (m === 10 || m === 11) return 'hemanta';
    return 'shishira';
}

// ─── Eclipse check ──────────────────────────────────────────────────────
function getActiveEclipses(dateStr) {
    const d = new Date(dateStr);
    return ECLIPSES.filter(e => {
        const days = (d - new Date(e.date)) / 86400000;
        return days >= 0 && days <= 90;
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIDENCE STORE — Learns which rules manifest across the year
// ═══════════════════════════════════════════════════════════════════════════

const confidenceStore = {};
const LEARNING_RATE = 0.15;

function applyConfidence(effects) {
    return effects.map(e => {
        const conf = confidenceStore[e.ruleId] ?? 0.5;
        return {
            ...e,
            rawWeight: e.weight,
            weight: Math.round(e.weight * (0.5 + conf) * 100) / 100,
            confidence: conf,
        };
    });
}

function updateConfidence(validations) {
    let updates = 0;
    for (const v of validations) {
        if (!v.ruleId) continue;
        const old = confidenceStore[v.ruleId] ?? 0.5;
        confidenceStore[v.ruleId] = Math.max(0.05, Math.min(0.99,
            old + LEARNING_RATE * (v.evidence - old)
        ));
        updates++;
    }
    return updates;
}

// ═══════════════════════════════════════════════════════════════════════════
// MEMORY STORE — Past readings for LLM continuity
// ═══════════════════════════════════════════════════════════════════════════

const memoryStore = [];

function storeReading(date, headline, topDomains, predictionSummaries = []) {
    memoryStore.push({
        date,
        headline,
        topDomains,
        predictions: predictionSummaries,
        storedAt: new Date().toISOString(),
    });
    if (memoryStore.length > 50) memoryStore.shift();
}

function recallPastReadings(limit = 5) {
    return memoryStore.slice(-limit);
}

// ═══════════════════════════════════════════════════════════════════════════
// PREDICTION LIFECYCLE — PAKA-aware store, validation, anti-echo
// ═══════════════════════════════════════════════════════════════════════════

const predictionStore = [];

const PAKA_DELAYS = {
    Saturn: 365, Jupiter: 365, Rahu: 180, Ketu: 180,
    Venus: 180, Mars: 60, Moon: 30, Mercury: 21, Sun: 15,
};

function buildPredictionLedger(currentDate) {
    if (predictionStore.length === 0) return null;
    const lines = [];

    const plausible = predictionStore.filter(p => p.status === "plausible");
    if (plausible.length > 0) {
        lines.push("### ✅ Validated Predictions (your past predictions that came true):");
        for (const p of plausible.slice(-5)) {
            lines.push(`- [${p.domain}] "${p.statement.slice(0, 100)}" (created ${p.createdDate}, confirmed ${p.manifestDate})`);
            if (p.evidence) lines.push(`  Evidence: ${p.evidence}`);
        }
    }

    const failed = predictionStore.filter(p => p.status === "unconfirmed" || p.status === "echo");
    if (failed.length > 0) {
        lines.push("### ❌ Failed/Unconfirmed Predictions (learn from these):");
        for (const p of failed.slice(-5)) {
            lines.push(`- [${p.domain}] "${p.statement.slice(0, 80)}" — ${p.evidence || "no evidence found"}`);
        }
    }

    const pending = predictionStore.filter(p => p.status === "pending");
    if (pending.length > 0) {
        lines.push("### ⏳ Your Pending Predictions (DO NOT repeat these):");
        const byDomain = {};
        for (const p of pending) {
            if (!byDomain[p.domain]) byDomain[p.domain] = [];
            byDomain[p.domain].push(p);
        }
        for (const [domain, preds] of Object.entries(byDomain).sort((a, b) => b[1].length - a[1].length)) {
            const latest = preds[preds.length - 1];
            lines.push(`- ${domain} (${preds.length} pending): latest = "${latest.statement.slice(0, 80)}..." [manifests ${latest.manifestDate}]`);
        }
        lines.push(`TOTAL PENDING: ${pending.length} predictions across ${Object.keys(byDomain).length} domains.`);
        const blocked = Object.entries(byDomain).filter(([, preds]) => preds.length >= 5);
        if (blocked.length > 0) {
            lines.push(`🚫 HARD CAP REACHED — these domains are BLOCKED (5+ pending): ${blocked.map(([d]) => d).join(", ")}`);
        }
    }

    return lines.length > 0 ? lines.join("\n") : null;
}

function buildDomainCoverageContext() {
    if (predictionStore.length < 6) return null;
    const domainCounts = {};
    for (const p of predictionStore) {
        domainCounts[p.domain] = (domainCounts[p.domain] || 0) + 1;
    }

    const allDomains = [
        "government", "military", "economy", "banking", "trade", "agriculture",
        "health", "media", "religion", "judiciary", "education", "foreign_affairs",
        "diplomacy", "public_mood", "real_estate", "technology", "social_movements",
        "humanitarian", "refugees", "maritime", "crisis", "mortality", "taxation",
        "insurance", "labor", "infrastructure", "transport", "entertainment",
        "culture", "sports", "research", "terrorism", "resources",
    ];

    const overRepresented = Object.entries(domainCounts)
        .filter(([, c]) => c >= 3)
        .sort((a, b) => b[1] - a[1])
        .map(([d, c]) => `${d}(${c})`);
    const neglected = allDomains.filter(d => !domainCounts[d]);
    const underServed = allDomains.filter(d => domainCounts[d] === 1);

    if (overRepresented.length === 0 && neglected.length === 0) return null;

    const lines = [];
    if (overRepresented.length > 0) lines.push(`🚫 SATURATED: ${overRepresented.join(", ")}`);
    if (neglected.length > 0) lines.push(`⚠️ ZERO-PREDICTION: ${neglected.join(", ")}`);
    if (underServed.length > 0) lines.push(`📊 Under-served: ${underServed.join(", ")}`);

    const dirCounts = { pos: 0, neg: 0, mix: 0 };
    for (const p of predictionStore) dirCounts[p.direction] = (dirCounts[p.direction] || 0) + 1;
    const total = predictionStore.length || 1;
    const negPct = ((dirCounts.neg / total) * 100).toFixed(0);
    const posPct = ((dirCounts.pos / total) * 100).toFixed(0);
    lines.push(`📊 Direction: ${posPct}% positive, ${negPct}% negative. ${dirCounts.neg > dirCounts.pos * 1.5 ? "⚠️ TOO NEGATIVE" : "Balance OK."}`);

    return lines.join("\n");
}

function storePredictions(predictions, readingDate, effects, activeHeadlines = []) {
    for (const pred of predictions) {
        pred.domain = normalizeDomain(pred.domain);

        // Find SLOWEST planet driving this domain for PAKA timing
        const domainEffects = effects.filter(e => normalizeDomain(e.domain) === pred.domain);
        let pakaDelayDays = 30;
        let drivingPlanet = null;

        if (domainEffects.length > 0) {
            let maxDelay = 0;
            for (const eff of domainEffects) {
                if (eff.manifestation?.delayDays > maxDelay) {
                    maxDelay = eff.manifestation.delayDays;
                    drivingPlanet = eff.planet;
                }
                const planets = (eff.planet || "").split("+");
                for (const p of planets) {
                    const delay = PAKA_DELAYS[p.trim()];
                    if (delay && delay > maxDelay) {
                        maxDelay = delay;
                        drivingPlanet = p.trim();
                    }
                }
            }
            pakaDelayDays = maxDelay || 30;
        }

        const d = new Date(readingDate);
        d.setDate(d.getDate() + pakaDelayDays);
        const manifestDate = d.toISOString().split("T")[0];

        // Anti-circular-validation: tag creation-time headline domains
        const creationDomains = new Set();
        for (const hl of activeHeadlines) {
            if (hl.domain) creationDomains.add(normalizeDomain(hl.domain));
        }

        predictionStore.push({
            id: pred.id || `pred_${readingDate}_${predictionStore.length}`,
            statement: pred.statement,
            domain: pred.domain,
            direction: pred.direction,
            confidence: pred.confidence,
            createdDate: readingDate,
            manifestDate,
            pakaDelayDays,
            drivingPlanet,
            status: "pending",
            evidence: null,
            creationDomains: [...creationDomains],
        });
    }
}

function checkDuePredictions(currentDate, domainHeat) {
    const now = new Date(currentDate);
    let confirmed = 0, denied = 0, checked = 0, echoFiltered = 0;

    for (const pred of predictionStore) {
        if (pred.status !== "pending") continue;
        if (new Date(pred.manifestDate) > now) continue;

        checked++;
        const normalizedDomain = normalizeDomain(pred.domain);
        if (normalizedDomain !== pred.domain) pred.domain = normalizedDomain;
        const heat = domainHeat[pred.domain];

        const wasHotAtCreation = pred.creationDomains?.includes(pred.domain);
        const heatThreshold = wasHotAtCreation ? 0.6 : 0.3;
        const minHeadlines = wasHotAtCreation ? 5 : 1;
        const echoTag = wasHotAtCreation ? " [anti-echo: raised bar]" : "";

        if (heat && heat.normalizedHeat > heatThreshold && heat.count >= minHeadlines) {
            const sentiment = heat.avgSentiment ?? 0;
            const directionMatch =
                (pred.direction === "neg" && sentiment <= 0) ||
                (pred.direction === "pos" && sentiment >= 0) ||
                pred.direction === "mix";

            if (directionMatch) {
                pred.status = "plausible";
                pred.evidence = `Domain "${pred.domain}" active (heat ${heat.normalizedHeat.toFixed(2)}, ${heat.count} headlines)${echoTag}`;
                confirmed++;
            } else {
                pred.status = "unconfirmed";
                pred.evidence = `Sentiment (${sentiment.toFixed(2)}) contradicts ${pred.direction}${echoTag}`;
                denied++;
            }
        } else if (wasHotAtCreation && heat && heat.normalizedHeat > 0.3) {
            pred.status = "echo";
            pred.evidence = `Likely echo — hot at creation and still modestly active`;
            echoFiltered++;
            denied++;
        } else {
            pred.status = "unconfirmed";
            pred.evidence = `Domain "${pred.domain}" quiet at manifestation window`;
            denied++;
        }
    }

    return { checked, confirmed, denied, echoFiltered };
}

// ═══════════════════════════════════════════════════════════════════════════
// VARGA → ANALYSIS ADAPTER
// Converts varga/ pipeline output into the format synthesizeForecast() expects
// ═══════════════════════════════════════════════════════════════════════════

function buildAnalysisForLLM(pipelineResult, dateStr, {
    headlines, domainHeat, hotDomains, memoryContext,
    predictionLedger, domainCoverage, prevEffectKeys,
}) {
    const { effects, stats, jupiterYear, convergenceMap } = pipelineResult;

    // Build domain scores from varga effects (mimics old phala_ganana format)
    const domainScores = {};
    for (const e of effects) {
        if (!domainScores[e.domain]) {
            domainScores[e.domain] = { domain: e.domain, label: e.domain, posSum: 0, negSum: 0, count: 0 };
        }
        const ds = domainScores[e.domain];
        if (e.dir === 'pos') ds.posSum += e.weight;
        else if (e.dir === 'neg') ds.negSum += e.weight;
        ds.count++;
    }
    const domainScoreArr = Object.values(domainScores)
        .map(d => ({
            domain: d.domain,
            label: d.label,
            outlook: d.posSum > d.negSum ? "favorable" : d.negSum > d.posSum ? "challenging" : "mixed",
            netScore: d.posSum - d.negSum,
        }))
        .sort((a, b) => Math.abs(b.netScore) - Math.abs(a.netScore));

    // Build summary text
    const summary = summarizePipeline(pipelineResult);

    // Koorma Chakra text from effects with targetRegions
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
    const koormaText = koormaLines.length > 0 ? koormaLines.join("\n") : null;

    // Foreground/background separation
    const SLOW = new Set(["Saturn", "Jupiter", "Rahu", "Ketu"]);
    const foregroundEffects = effects.filter(e => {
        const key = `${e.planet}|${e.sign || '?'}|${e.domain}`;
        const isNew = !prevEffectKeys || !prevEffectKeys.has(key);
        const isFast = !SLOW.has(e.planet) && !e.planet?.includes("+");
        return isNew || isFast || e.category === "conjunction" || e.category === "eclipse";
    });
    const backgroundEffects = effects.filter(e => {
        const key = `${e.planet}|${e.sign || '?'}|${e.domain}`;
        const isSlow = SLOW.has(e.planet) && !e.planet?.includes("+");
        const isOld = prevEffectKeys && prevEffectKeys.has(key);
        return isSlow && isOld && e.category !== "conjunction" && e.category !== "eclipse";
    });

    // News text for LLM
    const newsContext = formatHeadlinesForPrompt(headlines);

    return {
        date: dateStr,
        effects,
        totalEffects: stats.finalCount,
        summary,
        domainScores: domainScoreArr,
        koormaText,
        nakshatraText: null,
        foregroundEffects,
        backgroundEffects,
        newsContext,
        memoryContext,
        predictionLedger,
        domainCoverage,
        nimittaHotDomains: hotDomains.map(([d, v]) => ({
            domain: d, label: v.label || d, heat: v.normalizedHeat, headlines: v.count
        })),
        jupiterYear: jupiterYear?.samvatsara?.name,
        convergentDomains: stats.convergentDomains,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SIMULATION
// ═══════════════════════════════════════════════════════════════════════════

async function runFullYear() {
    const startDate = "2025-04-01";
    const endDate = "2026-04-14";
    const triggers = getAllTriggerDates(startDate, endDate);

    console.log(`\n${"═".repeat(78)}`);
    console.log(`  बृहत्संहिता — FULL YEAR VARGA + LLM PIPELINE`);
    console.log(`  Real Positions + News + 930 Rules + Gemini + Memory + Prediction Lifecycle`);
    console.log(`  ${startDate} → ${endDate} | ${triggers.length} Panchanga triggers`);
    console.log(`${"═".repeat(78)}\n`);

    const results = [];
    let totalNewsHeadlines = 0;
    let totalNimitta = 0;
    let totalEffects = 0;
    let totalCancelled = 0;
    let totalLLMCalls = 0;
    let prevEffectKeys = null;

    for (let i = 0; i < triggers.length; i++) {
        const trigger = triggers[i];
        const dateStr = trigger.date;
        const date = new Date(dateStr);
        const icon = { purnima: "🌕", amavasya: "🌑", ingress: "⚡" }[trigger.type] || "📌";

        console.log(`${icon} ${dateStr} [${trigger.type}] — Trigger ${i + 1}/${triggers.length}`);

        // ── Step 1: Real sidereal positions ─────────────────────────────
        let positions;
        try {
            positions = getPositionsForDate(dateStr);
        } catch (err) {
            console.log(`  ❌ Position load failed: ${err.message}\n`);
            continue;
        }
        const skyState = { positions: enrichPositions(positions) };
        const planetCount = Object.keys(skyState.positions).length;

        // ── Step 2: Historical news → Nimitta extraction ────────────────
        let headlines = [];
        let newsNimitta = [];
        try {
            headlines = await fetchHeadlinesForDate(dateStr, { limit: 25 });
        } catch { /* non-fatal */ }
        totalNewsHeadlines += headlines.length;

        if (headlines.length > 0) {
            newsNimitta = extractNimittaFromNews(headlines);
        }

        // ── Step 3: Domain heat from news ───────────────────────────────
        const domainHeat = computeDomainHeat(headlines);
        const hotDomains = Object.entries(domainHeat)
            .filter(([, v]) => v.normalizedHeat > 0.2)
            .sort((a, b) => b[1].normalizedHeat - a[1].normalizedHeat)
            .slice(0, 4);

        console.log(`  📰 News: ${headlines.length} headlines → ${newsNimitta.length} nimitta | ${hotDomains.length} hot domains`);

        // ── Step 4: Build observations for varga pipeline ───────────────
        const season = getSeason(date);
        const eclipses = getActiveEclipses(dateStr);

        const earthquakes = [];
        const portents = [];
        for (const n of newsNimitta) {
            if (n.type === 'earthquake_report') {
                earthquakes.push({
                    nakshatra: 'Aswini', timeOfDay: 'day', magnitude: 4.5,
                    place: n.headline, source: 'news'
                });
            }
            if (n.type.includes('portent') || n.type.includes('anomaly') || n.type.includes('volcanic')) {
                portents.push({ type: n.type, desc: n.headline, tier: 2, source: 'news' });
            }
        }
        totalNimitta += newsNimitta.length + earthquakes.length;

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

        // ── Step 5: Run varga/ pipeline (930 rules, 6 layers) ──────────
        const pipelineResult = runPipeline(skyState, observations, { date: dateStr });

        // Apply confidence learning to effects
        pipelineResult.effects = applyConfidence(pipelineResult.effects);

        totalEffects += pipelineResult.stats.rawCount;
        totalCancelled += pipelineResult.stats.cancelledCount;

        const boosted = pipelineResult.effects.filter(e => e.nimittaBoost > 0).length;

        console.log(`  🪐 ${planetCount} planets | 📊 ${pipelineResult.stats.rawCount} → ${pipelineResult.stats.finalCount} effects | 🔗 ${pipelineResult.stats.convergentDomains} convergent`);

        // ── Step 6: Build LLM context + synthesize ──────────────────────
        const pastReadings = recallPastReadings(5);
        const memoryContext = pastReadings.length > 0
            ? pastReadings.map(m => {
                let line = `${m.date}: ${m.headline} [${m.topDomains}]`;
                if (m.predictions?.length > 0) {
                    line += `\n  Predictions: ${m.predictions.join("; ")}`;
                }
                return line;
            }).join("\n")
            : null;

        const predictionLedger = buildPredictionLedger(dateStr);
        const domainCoverage = buildDomainCoverageContext();

        const analysisForLLM = buildAnalysisForLLM(pipelineResult, dateStr, {
            headlines,
            domainHeat,
            hotDomains,
            memoryContext,
            predictionLedger,
            domainCoverage,
            prevEffectKeys,
        });

        let forecast;
        try {
            forecast = await synthesizeForecast(GEMINI_API_KEY, analysisForLLM, { temperature: 0.55 });
            totalLLMCalls++;
            console.log(`  🤖 LLM: "${(forecast.headline || '').slice(0, 70)}..."`);
        } catch (err) {
            console.log(`  ⚠️  LLM failed (${(err.message || '').slice(0, 50)}), using fallback`);
            forecast = synthesizeFallback(analysisForLLM);
        }

        // ── Step 7: PAKA-Aware Validate + Learn ─────────────────────────
        let validationCount = 0;
        let pakaSkipped = 0;
        let confidenceUpdates = 0;
        if (headlines.length > 0) {
            try {
                const validations = validatePredictions(pipelineResult.effects, domainHeat, dateStr);
                pakaSkipped = pipelineResult.effects.filter(e => e.weight >= 0.3).length - validations.length;
                confidenceUpdates = updateConfidence(validations);
                validationCount = validations.length;
            } catch { /* non-fatal */ }
        }

        // ── Step 8: Store in memory + track predictions ─────────────────
        const topDomainStr = (analysisForLLM.domainScores || []).slice(0, 3)
            .map(d => `${d.domain}(${d.outlook})`).join(", ");
        const predSummaries = (forecast.predictions || [])
            .map(p => `[${p.domain}] ${(p.statement || "").slice(0, 60)}`);
        storeReading(dateStr, forecast.headline || "No headline", topDomainStr, predSummaries);

        if (forecast.predictions?.length > 0) {
            storePredictions(forecast.predictions, dateStr, pipelineResult.effects, headlines);
        }

        // Check if any PAST predictions are now due
        const predCheck = checkDuePredictions(dateStr, domainHeat);
        if (predCheck.checked > 0) {
            const echoNote = predCheck.echoFiltered > 0 ? ` | ${predCheck.echoFiltered} echo` : "";
            console.log(`  🔮 Predictions: ${predCheck.checked} due | ${predCheck.confirmed}✅ | ${predCheck.denied}❌${echoNote}`);
        }

        // ── Print domain outlook ────────────────────────────────────────
        for (const d of (analysisForLLM.domainScores || []).slice(0, 4)) {
            const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
            console.log(`  ${emoji} ${d.domain.padEnd(20)} ${d.outlook.padEnd(12)} net: ${d.netScore > 0 ? "+" : ""}${d.netScore.toFixed(2)}`);
        }

        if (forecast.predictions?.length > 0) {
            console.log(`  🔮 New predictions: ${forecast.predictions.length}`);
            for (const p of forecast.predictions.slice(0, 2)) {
                console.log(`     → ${(p.statement || '').slice(0, 80)}...`);
            }
        }

        console.log(`  📝 Memory: ${memoryStore.length} | Confidence: ${Object.keys(confidenceStore).length} rules | Validated: ${validationCount} | PAKA-skipped: ${pakaSkipped}`);

        // Track effect keys for foreground/background split
        prevEffectKeys = new Set();
        for (const e of pipelineResult.effects) {
            prevEffectKeys.add(`${e.planet}|${e.sign || '?'}|${e.domain}`);
        }

        results.push({
            date: dateStr,
            trigger: trigger.type,
            season,
            jupiterYear: pipelineResult.jupiterYear?.samvatsara?.name,
            planetCount,
            headlines: headlines.length,
            nimitta: newsNimitta.length,
            earthquakes: earthquakes.length,
            rawEffects: pipelineResult.stats.rawCount,
            filtered: pipelineResult.stats.filteredOut,
            cancelled: pipelineResult.stats.cancelledCount,
            finalEffects: pipelineResult.stats.finalCount,
            convergentDomains: pipelineResult.stats.convergentDomains,
            elapsedMs: pipelineResult.stats.elapsedMs,
            headline: forecast.headline,
            usedLLM: !!forecast._meta?.model && forecast._meta.model !== "fallback_rules_only",
            predictions: forecast.predictions?.length || 0,
            validations: validationCount,
            confidenceRulesTracked: Object.keys(confidenceStore).length,
            memoryDepth: memoryStore.length,
            topEffects: pipelineResult.effects.slice(0, 5).map(e => ({
                domain: e.domain, dir: e.dir, weight: +e.weight.toFixed(3),
                desc: e.desc.slice(0, 100),
                regions: e.targetRegions?.slice(0, 3),
                peak: e.manifestation?.peakDate
            })),
            topDomains: (analysisForLLM.domainScores || []).slice(0, 4).map(d => ({
                domain: d.domain, outlook: d.outlook, net: d.netScore
            })),
            hotDomains: hotDomains.map(([d, v]) => `${d}(${v.normalizedHeat.toFixed(2)})`),
            eclipses: eclipses.length,
        });

        console.log('');

        // Rate limit for Guardian API + Gemini
        await new Promise(r => setTimeout(r, 800));
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FINAL SUMMARY
    // ═══════════════════════════════════════════════════════════════════════

    console.log(`${"═".repeat(78)}`);
    console.log(`  FULL YEAR VARGA + LLM SIMULATION COMPLETE`);
    console.log(`${"═".repeat(78)}`);
    console.log(`  📅 Triggers processed:     ${results.length}/${triggers.length}`);
    console.log(`  🪐 Real API positions:     ${results.length} dates (interpolated sidereal)`);
    console.log(`  📰 Total news headlines:   ${totalNewsHeadlines}`);
    console.log(`  🌍 Total nimitta:          ${totalNimitta}`);
    console.log(`  📊 Total effects detected: ${totalEffects}`);
    console.log(`  ❌ Total cancelled:        ${totalCancelled}`);
    console.log(`  🤖 LLM synthesis calls:    ${totalLLMCalls}`);
    console.log(`  📝 Memories accumulated:   ${memoryStore.length}`);
    console.log(`  📈 Confidence rules:       ${Object.keys(confidenceStore).length}`);

    // Prediction lifecycle summary
    const predPending = predictionStore.filter(p => p.status === "pending").length;
    const predPlausible = predictionStore.filter(p => p.status === "plausible").length;
    const predUnconfirmed = predictionStore.filter(p => p.status === "unconfirmed").length;
    const predEcho = predictionStore.filter(p => p.status === "echo").length;
    console.log(`  🔮 Predictions total:      ${predictionStore.length}`);
    console.log(`     ✅ Plausible:           ${predPlausible}`);
    console.log(`     ❌ Unconfirmed:         ${predUnconfirmed}`);
    console.log(`     🔄 Echo-filtered:       ${predEcho}`);
    console.log(`     ⏳ Still pending (PAKA): ${predPending}`);

    // PAKA distribution
    const pakaBuckets = { "≤30d": 0, "31-90d": 0, "91-200d": 0, "201-365d": 0, ">365d": 0 };
    for (const pred of predictionStore) {
        const delay = pred.pakaDelayDays || 30;
        if (delay <= 30) pakaBuckets["≤30d"]++;
        else if (delay <= 90) pakaBuckets["31-90d"]++;
        else if (delay <= 200) pakaBuckets["91-200d"]++;
        else if (delay <= 365) pakaBuckets["201-365d"]++;
        else pakaBuckets[">365d"]++;
    }
    console.log(`\n  ## PAKA Compliance (BS Ch.97 Timing Distribution)`);
    for (const [bucket, count] of Object.entries(pakaBuckets)) {
        const pct = predictionStore.length > 0 ? ((count / predictionStore.length) * 100).toFixed(0) : 0;
        const bar = "█".repeat(Math.round(count / Math.max(1, predictionStore.length) * 40));
        console.log(`     ${bucket.padEnd(10)} ${String(count).padStart(3)} (${String(pct).padStart(2)}%) ${bar}`);
    }

    // Driving planet distribution
    const planetDist = {};
    for (const pred of predictionStore) {
        const p = pred.drivingPlanet || "unknown";
        planetDist[p] = (planetDist[p] || 0) + 1;
    }
    console.log(`\n  ## Driving Planet Distribution`);
    for (const [planet, count] of Object.entries(planetDist).sort((a, b) => b[1] - a[1])) {
        console.log(`     ${planet.padEnd(12)} ${count} predictions`);
    }

    // Domain frequency across the year
    const domainFreq = {};
    for (const r of results) {
        for (const d of r.topDomains || []) {
            if (!domainFreq[d.domain]) domainFreq[d.domain] = { fav: 0, chal: 0, mix: 0, total: 0, netSum: 0 };
            domainFreq[d.domain][d.outlook === "favorable" ? "fav" : d.outlook === "challenging" ? "chal" : "mix"]++;
            domainFreq[d.domain].total++;
            domainFreq[d.domain].netSum += d.net;
        }
    }

    console.log(`\n  ## Year-Long Domain Outlook`);
    for (const [domain, stats] of Object.entries(domainFreq).sort((a, b) => b[1].total - a[1].total)) {
        const avg = (stats.netSum / stats.total).toFixed(2);
        const icon = stats.chal > stats.fav ? "🔴" : stats.fav > stats.chal ? "🟢" : "🟡";
        console.log(`  ${icon} ${domain.padEnd(25)} ${stats.total}x | avg: ${avg} | fav: ${stats.fav} chal: ${stats.chal}`);
    }

    // Jupiter year transitions
    const yearChanges = [];
    let prevYear = null;
    for (const r of results) {
        if (r.jupiterYear !== prevYear) {
            yearChanges.push({ date: r.date, year: r.jupiterYear });
            prevYear = r.jupiterYear;
        }
    }
    console.log(`\n  ## Samvatsara Transitions`);
    for (const yc of yearChanges) {
        console.log(`  🪐 ${yc.date}: ${yc.year}`);
    }

    // Confidence evolution
    const confEntries = Object.entries(confidenceStore).sort((a, b) => b[1] - a[1]);
    if (confEntries.length > 0) {
        console.log(`\n  ## Top Confidence Rules (learned from year of data)`);
        for (const [rule, score] of confEntries.slice(0, 8)) {
            const bar = "█".repeat(Math.round(score * 20));
            console.log(`  ${score >= 0.6 ? "✅" : score <= 0.4 ? "❌" : "➖"} ${rule.padEnd(45)} ${score.toFixed(3)} ${bar}`);
        }
        console.log(`\n  ## Lowest Confidence (rules that didn't manifest)`);
        for (const [rule, score] of confEntries.slice(-5).reverse()) {
            console.log(`  ❌ ${rule.padEnd(45)} ${score.toFixed(3)}`);
        }
    }

    // Season distribution
    const seasonCount = {};
    for (const r of results) {
        seasonCount[r.season] = (seasonCount[r.season] || 0) + 1;
    }
    console.log(`\n  ## Seasonal Coverage`);
    for (const [s, c] of Object.entries(seasonCount)) {
        console.log(`  ${s.padEnd(12)} ${c} triggers`);
    }

    // Save everything
    const outputPath = join(__dirname, "..", "data", "simulation_varga_llm_results.json");
    writeFileSync(outputPath, JSON.stringify({
        meta: {
            startDate: "2025-04-01", endDate: "2026-04-14",
            triggersProcessed: results.length,
            totalNewsHeadlines, totalNimitta, totalEffects, totalCancelled,
            totalLLMCalls,
            confidenceRules: Object.keys(confidenceStore).length,
            memoryDepth: memoryStore.length,
            engine: "varga/ pipeline (930 rules, 6 layers) + Gemini Flash + Memory + Prediction Lifecycle",
            runAt: new Date().toISOString(),
        },
        results,
        confidenceStore,
        memoryStore,
        predictionStore,
        predictionSummary: {
            total: predictionStore.length,
            plausible: predPlausible,
            unconfirmed: predUnconfirmed,
            echoFiltered: predEcho,
            pending: predPending,
            pakaDistribution: pakaBuckets,
            drivingPlanetDistribution: planetDist,
        },
    }, null, 2));
    console.log(`\n  📁 Results saved: ${outputPath}`);
    console.log(`${"═".repeat(78)}`);
}

runFullYear().catch(err => {
    console.error("Simulation failed:", err);
    process.exit(1);
});
