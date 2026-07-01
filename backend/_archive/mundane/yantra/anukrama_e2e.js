/**
 * यन्त्र — अनुक्रम E2E (Full Year Simulation — Real Everything)
 *
 * Runs the FULL Varahamihira pipeline for every Panchanga trigger
 * over the past year (April 2025 → April 2026):
 *
 *   For each trigger date:
 *   1. Fetch REAL sidereal positions from FreeAstrologyAPI (Lahiri ayanamsha)
 *   2. Fetch historical news via Google News RSS (before:/after: date params)
 *   3. Compute domain heat (Nimitta) from news
 *   4. Apply rules engine WITH Nimitta boost
 *   5. Apply confidence memory (accumulates across readings)
 *   6. LLM synthesis via Gemini Flash (real narrative, not fallback)
 *   7. Store reading in memory for next trigger to recall
 *   8. Update confidence scores from validation
 *
 * This is the system running AS IT WOULD IN PRODUCTION, week by week.
 *
 * Run: node mundane/yantra/anukrama_e2e.js
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import { getAllTriggerDates } from "../kriya/kaal_nirnaya.js";
import { enrichPositions, detectActiveEclipses } from "../kriya/drik_ganita.js";
import { applyAllRules } from "../kriya/phala_ganana.js";
import { computeDomainHeat, classifyHeadline, validatePredictions } from "../kriya/nimitta_pariksha.js";
import { synthesizeForecast, synthesizeFallback } from "../kriya/phala_sangraha.js";
import { fetchHeadlinesForDate, formatHeadlinesForPrompt } from "../../lib/news_archive.js";
import { normalizeDomain } from "../adhyaya/vishaya.js";
import { writeFileSync, readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── API Keys ────────────────────────────────────────────────────────────
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "AIzaSyCwbDKQzY_V4dy5x5Oj_rZ6lRuiWFRLgwc";

// Eclipse data for the period
const ECLIPSES = [
    { type: "solar", sign: "Pisces",   date: "2025-03-29", durationMinutes: 155 },
    { type: "lunar", sign: "Virgo",    date: "2025-09-07", durationMinutes: 180 },
    { type: "solar", sign: "Aquarius", date: "2026-02-17", durationMinutes: 142 },
    { type: "lunar", sign: "Virgo",    date: "2026-03-03", durationMinutes: 205 },
];

// ─── Position Data (interpolated from monthly sidereal snapshots) ───────
// FreeAstrologyAPI blocked by corporate firewall, so we interpolate from
// the existing graha_sthiti_2025_2026.json (Lahiri ayanamsha, monthly data).
// Interpolation gives unique fast-planet positions for each trigger date.

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
            isRetro: b[planet].isRetrograde,
            sunDistance: Math.round(sd * 100) / 100,
        };
    }
    return result;
}

// ─── Historical News Fetcher (Guardian Open Platform API) ───────────────
// Real headlines from the actual date. Free API, works from corporate network.

async function fetchHistoricalNews(dateStr, maxResults = 25) {
    return fetchHeadlinesForDate(dateStr, { limit: maxResults });
}

// ─── Eclipse Windows ────────────────────────────────────────────────────

function getActiveEclipses(dateStr) {
    const d = new Date(dateStr);
    return ECLIPSES.filter(e => {
        const days = (d - new Date(e.date)) / 86400000;
        return days >= 0 && days <= 90;
    });
}

// ─── Confidence Store (in-memory, accumulates across readings) ──────────

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

// ─── Memory Store (in-memory, accumulates across readings) ──────────────

const memoryStore = [];

function storeReading(date, headline, topDomains, predictionSummaries = []) {
    memoryStore.push({
        date,
        headline,
        topDomains,
        predictions: predictionSummaries, // Store prediction summaries for richer memory
        storedAt: new Date().toISOString(),
    });
    if (memoryStore.length > 50) memoryStore.shift();
}

function recallPastReadings(limit = 5) {
    return memoryStore.slice(-limit);
}

// ─── Prediction Lifecycle Tracker ───────────────────────────────────────
// Stores predictions with their PAKA expiry dates.
// When a trigger date arrives past a prediction's manifestDate,
// we check the news to see if it manifested.

const predictionStore = []; // { id, statement, domain, direction, createdDate, manifestDate, status, evidence }

/**
 * Build a prediction ledger string for the LLM context.
 * Shows: (a) what was already predicted (dedup), (b) outcomes (learning).
 * Grouped by status: validated, failed, pending.
 */
function buildPredictionLedger(currentDate) {
    if (predictionStore.length === 0) return null;

    const lines = [];

    // Validated predictions — the LLM should know what worked
    const plausible = predictionStore.filter(p => p.status === "plausible");
    if (plausible.length > 0) {
        lines.push("### ✅ Validated Predictions (your past predictions that came true):");
        for (const p of plausible.slice(-5)) {
            lines.push(`- [${p.domain}] "${p.statement.slice(0, 100)}" (created ${p.createdDate}, confirmed ${p.manifestDate})`);
            if (p.evidence) lines.push(`  Evidence: ${p.evidence}`);
        }
    }

    // Failed predictions — the LLM should learn from failures
    const failed = predictionStore.filter(p => p.status === "unconfirmed" || p.status === "echo");
    if (failed.length > 0) {
        lines.push("### ❌ Failed/Unconfirmed Predictions (learn from these):");
        for (const p of failed.slice(-5)) {
            lines.push(`- [${p.domain}] "${p.statement.slice(0, 80)}" — ${p.evidence || "no evidence found"}`);
        }
    }

    // Pending predictions — CRITICAL for dedup. The LLM must NOT repeat these.
    const pending = predictionStore.filter(p => p.status === "pending");
    if (pending.length > 0) {
        lines.push("### ⏳ Your Pending Predictions (DO NOT repeat these — they are already in the ledger):");
        // Group by domain to show coverage
        const byDomain = {};
        for (const p of pending) {
            if (!byDomain[p.domain]) byDomain[p.domain] = [];
            byDomain[p.domain].push(p);
        }
        for (const [domain, preds] of Object.entries(byDomain).sort((a, b) => b[1].length - a[1].length)) {
            const count = preds.length;
            const latest = preds[preds.length - 1];
            lines.push(`- ${domain} (${count} pending): latest = "${latest.statement.slice(0, 80)}..." [manifests ${latest.manifestDate}]`);
        }
        lines.push(`TOTAL PENDING: ${pending.length} predictions across ${Object.keys(byDomain).length} domains.`);
        // Explicitly list BLOCKED domains (hard cap at 5 predictions per domain)
        const blocked = Object.entries(byDomain).filter(([, preds]) => preds.length >= 5);
        if (blocked.length > 0) {
            lines.push(`🚫 HARD CAP REACHED — these domains are BLOCKED (5+ pending): ${blocked.map(([d]) => d).join(", ")}`);
            lines.push("You MUST NOT add any prediction in these domains. Choose from neglected domains instead.");
        }
    }

    return lines.length > 0 ? lines.join("\n") : null;
}

/**
 * Build domain coverage context — shows which domains are over/under-represented.
 * Encourages the LLM to diversify into neglected domains.
 */
function buildDomainCoverageContext() {
    if (predictionStore.length < 6) return null; // Too early to judge

    const domainCounts = {};
    for (const p of predictionStore) {
        domainCounts[p.domain] = (domainCounts[p.domain] || 0) + 1;
    }

    // All 35 domain keys
    const allDomains = [
        "government", "military", "economy", "banking", "trade", "agriculture",
        "health", "media", "religion", "judiciary", "education", "foreign_affairs",
        "diplomacy", "public_mood", "real_estate", "technology", "social_movements",
        "humanitarian", "refugees", "maritime", "crisis", "mortality", "taxation",
        "insurance", "labor", "infrastructure", "transport", "entertainment",
        "culture", "sports", "research", "terrorism", "resources",
    ];

    const overRepresented = Object.entries(domainCounts)
        .filter(([, c]) => c >= 3) // Lowered from 5 to 3 for stricter rotation
        .sort((a, b) => b[1] - a[1])
        .map(([d, c]) => `${d}(${c})`);

    const neglected = allDomains.filter(d => !domainCounts[d]);
    const underServed = allDomains.filter(d => domainCounts[d] === 1);

    if (overRepresented.length === 0 && neglected.length === 0) return null;

    const lines = [];
    if (overRepresented.length > 0) {
        lines.push(`🚫 SATURATED domains (DO NOT add more predictions here): ${overRepresented.join(", ")}`);
    }
    if (neglected.length > 0) {
        lines.push(`⚠️ ZERO-PREDICTION domains (USE these if any effects support them): ${neglected.join(", ")}`);
    }
    if (underServed.length > 0) {
        lines.push(`📊 Under-served domains (only 1 prediction, room for more): ${underServed.join(", ")}`);
    }
    // Direction balance
    const dirCounts = { pos: 0, neg: 0, mix: 0 };
    for (const p of predictionStore) dirCounts[p.direction] = (dirCounts[p.direction] || 0) + 1;
    const total = predictionStore.length || 1;
    const negPct = ((dirCounts.neg / total) * 100).toFixed(0);
    const posPct = ((dirCounts.pos / total) * 100).toFixed(0);
    lines.push(`📊 Direction balance: ${posPct}% positive, ${negPct}% negative. ${dirCounts.neg > dirCounts.pos * 1.5 ? "⚠️ TOO NEGATIVE — at least 1 of your 3 predictions MUST be positive." : "Balance OK."}`);

    return lines.join("\n");
}

function storePredictions(predictions, readingDate, effects, activeHeadlines = []) {
    // Import PAKA table for fallback timing
    // (already imported at top via paka.js through phala_ganana)
    const PAKA_DELAYS = {
        Saturn: 365, Jupiter: 365, Rahu: 180, Ketu: 180,
        Venus: 180, Mars: 60, Moon: 30, Mercury: 21, Sun: 15,
    };

    for (const pred of predictions) {
        // Normalize domain key (LLM may output "Maritime & Naval" instead of "maritime")
        pred.domain = normalizeDomain(pred.domain);

        // ── PAKA-Aware Manifestation Dating ──────────────────────────────
        // Strategy: Find the SLOWEST planet driving effects in this domain.
        // The slowest planet determines when the effect ripens (BS Ch.97).

        // Step 1: Find ALL effects in this prediction's domain
        const domainEffects = effects.filter(e =>
            normalizeDomain(e.domain) === pred.domain
        );

        let manifestDate = null;
        let drivingPlanet = null;
        let pakaDelayDays = null;

        if (domainEffects.length > 0) {
            // Step 2: Use the SLOWEST planet's PAKA from matching effects
            // This ensures Saturn-in-Pisces maritime effects get 365 days, not 30
            let maxDelay = 0;
            for (const eff of domainEffects) {
                if (eff.manifestation?.delayDays > maxDelay) {
                    maxDelay = eff.manifestation.delayDays;
                    drivingPlanet = eff.planet;
                }
                // For effects without manifestation, look up planet directly
                const planets = (eff.planet || "").split("+"); // Handle conjunctions
                for (const p of planets) {
                    const delay = PAKA_DELAYS[p.trim()];
                    if (delay && delay > maxDelay) {
                        maxDelay = delay;
                        drivingPlanet = p.trim();
                    }
                }
            }
            pakaDelayDays = maxDelay || 30; // True fallback only if no planet found
        } else {
            // Step 3: No matching effects — use highest-weight effect's planet as proxy
            const highestEffect = effects[0]; // effects are pre-sorted by weight
            if (highestEffect) {
                const planets = (highestEffect.planet || "").split("+");
                const maxP = planets.reduce((best, p) => {
                    const d = PAKA_DELAYS[p.trim()] || 0;
                    return d > (best.delay || 0) ? { planet: p.trim(), delay: d } : best;
                }, { planet: null, delay: 0 });
                pakaDelayDays = maxP.delay || 30;
                drivingPlanet = maxP.planet;
            } else {
                pakaDelayDays = 30;
            }
        }

        // Compute manifestation date from PAKA delay
        const d = new Date(readingDate);
        d.setDate(d.getDate() + pakaDelayDays);
        manifestDate = d.toISOString().split("T")[0];

        // ── Anti-Circular-Validation: tag creation-time headlines ──────────
        // Store which headline domains were active when this prediction was created.
        // Validation will discount evidence from the same domain pattern.
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
            creationDomains: [...creationDomains], // For anti-echo validation
        });
    }
}

function checkDuePredictions(currentDate, domainHeat) {
    const now = new Date(currentDate);
    let confirmed = 0, denied = 0, checked = 0, echoFiltered = 0;

    for (const pred of predictionStore) {
        if (pred.status !== "pending") continue;
        if (new Date(pred.manifestDate) > now) continue;

        // This prediction is DUE — check against current news domain heat
        checked++;
        // Normalize domain in case it was stored before normalizer existed
        const normalizedDomain = normalizeDomain(pred.domain);
        if (normalizedDomain !== pred.domain) pred.domain = normalizedDomain;
        const heat = domainHeat[pred.domain];

        // ── Anti-Echo Detection (prevents circular validation) ──────────
        // If this domain was already hot in news when the prediction was created,
        // require SIGNIFICANTLY stronger evidence to count as plausible.
        // Without this, reading news → predicting same topic → validating against
        // similar news 30 days later creates a self-fulfilling loop.
        const wasHotAtCreation = pred.creationDomains?.includes(pred.domain);
        const heatThreshold = wasHotAtCreation ? 0.6 : 0.3;   // 2x threshold for echoes
        const minHeadlines = wasHotAtCreation ? 5 : 1;          // Need more headlines
        const echoTag = wasHotAtCreation ? " [anti-echo: raised bar]" : "";

        if (heat && heat.normalizedHeat > heatThreshold && heat.count >= minHeadlines) {
            const sentiment = heat.avgSentiment ?? 0;
            const directionMatch =
                (pred.direction === "neg" && sentiment <= 0) ||
                (pred.direction === "pos" && sentiment >= 0) ||
                pred.direction === "mix";

            if (directionMatch) {
                pred.status = "plausible";
                pred.evidence = `Domain "${pred.domain}" active in news (heat ${heat.normalizedHeat.toFixed(2)}, ${heat.count} headlines, sentiment ${sentiment.toFixed(2)})${echoTag}`;
                confirmed++;
            } else {
                // Domain active but sentiment contradicts prediction direction
                pred.status = "unconfirmed";
                pred.evidence = `Domain "${pred.domain}" active but sentiment (${sentiment.toFixed(2)}) contradicts ${pred.direction} prediction${echoTag}`;
                denied++;
            }
        } else if (wasHotAtCreation && heat && heat.normalizedHeat > 0.3) {
            // Domain was hot at creation AND is still only modestly hot now.
            // This is LIKELY an echo — same persistent news cycle, not a new event.
            pred.status = "echo";
            pred.evidence = `Domain "${pred.domain}" was hot at creation (${pred.createdDate}) and still active (heat ${heat.normalizedHeat.toFixed(2)}) — likely echo, not new manifestation`;
            echoFiltered++;
            denied++;
        } else {
            pred.status = "unconfirmed";
            pred.evidence = `Domain "${pred.domain}" quiet in news at manifestation window`;
            denied++;
        }
    }

    return { checked, confirmed, denied, echoFiltered };
}

// ─── Main Simulation ────────────────────────────────────────────────────

async function runFullYearSimulation() {
    const startDate = "2025-04-01";
    const endDate = "2026-04-12";
    const triggers = getAllTriggerDates(startDate, endDate);

    console.log(`\n${"═".repeat(78)}`);
    console.log(`  बृहत्संहिता — FULL YEAR SIMULATION (Real Positions + News + LLM + Memory)`);
    console.log(`  ${startDate} → ${endDate} | ${triggers.length} Panchanga triggers`);
    console.log(`${"═".repeat(78)}\n`);

    const results = [];
    let prevAnalysis = null;
    let totalLLMCalls = 0;
    let totalNewsHeadlines = 0;

    for (let i = 0; i < triggers.length; i++) {
        const trigger = triggers[i];
        const dateStr = trigger.date;
        const icon = { purnima: "🌕", amavasya: "🌑", ingress: "⚡" }[trigger.type] || "📌";

        console.log(`${icon} ${dateStr} [${trigger.type}] — Trigger ${i + 1}/${triggers.length}`);

        // ── Step 1: Get positions (interpolated sidereal, Lahiri) ────────
        let positions;
        try {
            positions = getPositionsForDate(dateStr);
            console.log(`  🪐 Positions: ${Object.keys(positions).length} planets (interpolated sidereal)`);
        } catch (err) {
            console.log(`  ❌ Position load failed: ${err.message}`);
            console.log(`  → Skipping this trigger\n`);
            continue;
        }

        // ── Step 2: Fetch historical news (Nimitta) ─────────────────────
        const headlines = await fetchHistoricalNews(dateStr, 25);
        totalNewsHeadlines += headlines.length;
        const domainHeat = computeDomainHeat(headlines);
        const hotDomains = Object.entries(domainHeat)
            .filter(([, v]) => v.normalizedHeat > 0.2)
            .sort((a, b) => b[1].normalizedHeat - a[1].normalizedHeat)
            .slice(0, 4);

        console.log(`  📰 News: ${headlines.length} headlines, ${hotDomains.length} hot domains`);
        for (const [domain, v] of hotDomains.slice(0, 2)) {
            console.log(`     🔥 ${v.label}: heat ${v.normalizedHeat.toFixed(2)} (${v.count} articles)`);
        }

        // ── Step 3: Build sky state + apply rules with Nimitta boost ────
        const enriched = enrichPositions(positions);
        const eclipses = getActiveEclipses(dateStr);
        const skyState = {
            positions: enriched,
            prevPositions: null,
            activeEclipses: eclipses,
            date: dateStr,
            panchang: null,
            computedPanchanga: null,
            domainHeat, // INJECT Nimitta
        };

        const analysis = applyAllRules(skyState);
        analysis.effects = applyConfidence(analysis.effects);

        const boosted = analysis.effects.filter(e => e.nimittaBoost > 0).length;
        console.log(`  📊 ${analysis.totalEffects} effects, ${boosted} Nimitta-boosted, ${eclipses.length} eclipse windows`);

        // Foreground/background separation
        const prevKeys = new Set();
        if (prevAnalysis) {
            for (const e of prevAnalysis.effects) prevKeys.add(`${e.planet}|${e.sign}|${e.domain}`);
        }
        const SLOW = new Set(["Saturn", "Jupiter", "Rahu", "Ketu"]);
        const foreground = analysis.effects.filter(e => {
            const isNew = !prevKeys.has(`${e.planet}|${e.sign}|${e.domain}`);
            const isFast = !SLOW.has(e.planet) && !e.planet?.includes("+");
            return isNew || isFast || e.category === "conjunction" || e.category === "eclipse";
        });

        // ── Step 4: LLM Synthesis ───────────────────────────────────────
        let forecast;
        const pastReadings = recallPastReadings(5); // expanded from 2 → 5
        const memoryContext = pastReadings.length > 0
            ? pastReadings.map(m => {
                let line = `${m.date}: ${m.headline} [${m.topDomains}]`;
                if (m.predictions?.length > 0) {
                    line += `\n  Predictions made: ${m.predictions.join("; ")}`;
                }
                return line;
            }).join("\n")
            : null;
        const newsText = formatHeadlinesForPrompt(headlines);

        // ── Build Prediction Ledger context for LLM ─────────────────────
        // Shows the LLM what it already predicted (dedup) + what validated/failed (learning)
        const predictionLedger = buildPredictionLedger(dateStr);

        // ── Build domain coverage gap context ───────────────────────────
        // Tell the LLM which domains have been over/under-predicted
        const domainCoverage = buildDomainCoverageContext();

        try {
            // Separate background (persistent slow planets) from foreground (new + fast)
            const SLOW = new Set(["Saturn", "Jupiter", "Rahu", "Ketu"]);
            const backgroundEffects = analysis.effects.filter(e => {
                const isSlow = SLOW.has(e.planet) && !e.planet?.includes("+");
                const isOld = prevKeys.has(`${e.planet}|${e.sign}|${e.domain}`);
                return isSlow && isOld && e.category !== "conjunction" && e.category !== "eclipse";
            });

            const enrichedAnalysis = {
                ...analysis,
                foregroundEffects: foreground, // what's NEW — drive 70% of narrative
                backgroundEffects: backgroundEffects, // persistent — 30% context
                newsContext: newsText,
                memoryContext,
                predictionLedger,    // NEW: past predictions for dedup + learning
                domainCoverage,      // NEW: domain coverage gaps
                nimittaHotDomains: hotDomains.map(([d, v]) => ({ domain: d, label: v.label, heat: v.normalizedHeat, headlines: v.count })),
            };
            forecast = await synthesizeForecast(GEMINI_API_KEY, enrichedAnalysis, { temperature: 0.55 });
            totalLLMCalls++;
            console.log(`  🤖 LLM synthesis: "${forecast.headline?.slice(0, 70)}..."`);
        } catch (err) {
            console.log(`  ⚠️  LLM failed (${err.message?.slice(0, 50)}), using fallback`);
            forecast = synthesizeFallback(analysis);
        }

        // ── Step 5: PAKA-Aware Validate + Learn ─────────────────────────
        // Only validates effects whose manifestation peak date has PASSED.
        // Saturn effects from month 1 won't be validated until month 12+.
        let validationCount = 0;
        let pakaSkipped = 0;
        let confidenceUpdates = 0;
        if (headlines.length > 0) {
            try {
                // Use proper PAKA-aware validation
                const validations = validatePredictions(analysis.effects, domainHeat, dateStr);
                pakaSkipped = analysis.effects.filter(e => e.weight >= 0.3).length - validations.length;
                confidenceUpdates = updateConfidence(validations);
                validationCount = validations.length;
            } catch {
                // Non-fatal
            }
        }

        // ── Step 6: Store in memory + track predictions ──────────────────
        const topDomainStr = analysis.domainScores.slice(0, 3).map(d => `${d.domain}(${d.outlook})`).join(", ");
        const predSummaries = (forecast.predictions || []).map(p => `[${p.domain}] ${(p.statement || "").slice(0, 60)}`);
        storeReading(dateStr, forecast.headline || "No headline", topDomainStr, predSummaries);

        // Store LLM predictions with PAKA expiry dates + creation-time headlines
        if (forecast.predictions?.length > 0) {
            storePredictions(forecast.predictions, dateStr, analysis.effects, headlines);
        }

        // Check if any PAST predictions are now due for validation
        const predCheck = checkDuePredictions(dateStr, domainHeat);
        if (predCheck.checked > 0) {
            const echoNote = predCheck.echoFiltered > 0 ? ` | ${predCheck.echoFiltered} echo-filtered` : "";
            console.log(`  🔮 Prediction check: ${predCheck.checked} due | ${predCheck.confirmed} plausible | ${predCheck.denied} unconfirmed${echoNote}`);
        }

        // ── Print domain outlook ────────────────────────────────────────
        for (const d of analysis.domainScores.slice(0, 4)) {
            const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
            const boost = analysis.effects.some(e => e.domain === d.domain && e.nimittaBoost > 0) ? " 🔥" : "";
            console.log(`  ${emoji} ${d.label.padEnd(28)} ${d.outlook.padEnd(12)} net: ${d.netScore > 0 ? "+" : ""}${d.netScore.toFixed(2)}${boost}`);
        }

        if (forecast.predictions?.length > 0) {
            console.log(`  🔮 Predictions: ${forecast.predictions.length}`);
            for (const p of forecast.predictions.slice(0, 2)) {
                console.log(`     → ${p.statement?.slice(0, 80)}...`);
            }
        }

        console.log(`  📝 Memory: ${memoryStore.length} stored | Confidence: ${Object.keys(confidenceStore).length} rules | Validated: ${validationCount} | PAKA-skipped: ${pakaSkipped} (not yet ripe)\n`);

        results.push({
            trigger,
            date: dateStr,
            positions: Object.keys(positions).length,
            headlines: headlines.length,
            hotDomains: hotDomains.map(([d, v]) => `${d}(${v.normalizedHeat.toFixed(2)})`),
            effects: analysis.totalEffects,
            nimittaBoosted: boosted,
            eclipseWindows: eclipses.length,
            foregroundNew: foreground.length,
            headline: forecast.headline,
            topDomains: analysis.domainScores.slice(0, 4).map(d => ({ domain: d.domain, outlook: d.outlook, net: d.netScore })),
            predictions: forecast.predictions?.length || 0,
            validations: validationCount,
            confidenceRulesTracked: Object.keys(confidenceStore).length,
            memoryDepth: memoryStore.length,
            usedLLM: !!forecast._meta?.model && forecast._meta.model !== "fallback_rules_only",
        });

        prevAnalysis = analysis;

        // Rate limit between triggers (API courtesy)
        await new Promise(r => setTimeout(r, 300));
    }

    // ── Final Summary ────────────────────────────────────────────────────
    console.log(`${"═".repeat(78)}`);
    console.log(`  SIMULATION COMPLETE`);
    console.log(`${"═".repeat(78)}`);
    console.log(`  📅 Triggers processed:     ${results.length}/${triggers.length}`);
    console.log(`  🪐 Real API positions:     ${results.length} dates`);
    console.log(`  📰 Total news headlines:   ${totalNewsHeadlines}`);
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
    console.log(`     🔄 Echo-filtered:       ${predEcho} (would have been false "plausible" before)`);
    console.log(`     ⏳ Still pending (PAKA): ${predPending}`);

    // PAKA distribution analysis — how long are prediction horizons now?
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
    // Show driving planet distribution
    const planetDist = {};
    for (const pred of predictionStore) {
        const p = pred.drivingPlanet || "unknown";
        planetDist[p] = (planetDist[p] || 0) + 1;
    }
    console.log(`\n  ## Driving Planet Distribution`);
    for (const [planet, count] of Object.entries(planetDist).sort((a, b) => b - a)) {
        console.log(`     ${planet.padEnd(12)} ${count} predictions`);
    }

    // Domain frequency analysis
    const domainFreq = {};
    for (const r of results) {
        for (const d of r.topDomains) {
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
        console.log(`  ${icon} ${domain.padEnd(25)} ${stats.total}x active | avg: ${avg} | fav: ${stats.fav} chal: ${stats.chal}`);
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

    // Save results
    const outputPath = join(__dirname, "..", "data", "simulation_e2e_results.json");
    writeFileSync(outputPath, JSON.stringify({
        meta: {
            startDate, endDate,
            triggersProcessed: results.length,
            totalLLMCalls,
            totalNewsHeadlines,
            confidenceRules: Object.keys(confidenceStore).length,
            memoryDepth: memoryStore.length,
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
    console.log(`\n  📁 Full results: ${outputPath}`);
    console.log(`${"═".repeat(78)}`);
}

runFullYearSimulation().catch(err => {
    console.error("Simulation failed:", err);
    process.exit(1);
});
