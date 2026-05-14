/**
 * Prompt Experiments — Testing 3 fundamentally different approaches
 *
 * All three use the SAME sky data, SAME news, SAME memories.
 * The ONLY difference is how the prompt structures the information.
 *
 * Experiment A: Current system (baseline) — signal dump
 * Experiment B: "Main Event" focus — identify dominant config, add house lordships
 * Experiment C: "Layered" — macro → monthly → weekly → daily hierarchy
 *
 * Usage: source .env && node scripts/prompt_experiments.js [date]
 */

import { GoogleGenerativeAI } from "@google/generative-ai";

process.env.GOOGLE_APPLICATION_CREDENTIALS = "serviceAccountKey.json";
const { db } = await import("../lib/firebase.js");
const { extractSignals, diffSky, getTopSignals } = await import("../lib/signal_engine.js");
const { getPanchanga, getNakshatra, getNakshatraMundane } = await import("../lib/vedic_utils.js");
const { scanUpcomingTransits } = await import("../lib/upcoming_transits.js");
const { initMemory, listMemories, recallMemory } = await import("../lib/agent_memory.js");
const { fetchNewsHeadlines, formatNewsForPrompt } = await import("../lib/news_feed.js");
const { ZODIAC_SIGNS, PLANETS } = await import("../lib/constants.js");
const { PLANET_RULERSHIP } = await import("../lib/signal_types.js");
const { buildHouseLordContext } = await import("../lib/house_lords.js");

const apiKey = process.env.GEMINI_API_KEY;
const dateStr = process.argv[2] || "2026-04-05";

if (!apiKey) { console.error("Need GEMINI_API_KEY"); process.exit(1); }
initMemory(apiKey);

// ═══════════════════════════════════════════════════════════════════════════
// SHARED DATA LOADING
// ═══════════════════════════════════════════════════════════════════════════

console.log(`Loading data for ${dateStr}...\n`);

const skyDoc = await db.collection("global_astro").doc("sky_positions").get();
const allPositions = skyDoc.data()?.positions || {};
const sortedDates = Object.keys(allPositions).sort();
const todayIdx = sortedDates.indexOf(dateStr);
const todayPos = allPositions[dateStr];
const yesterdayPos = todayIdx > 0 ? allPositions[sortedDates[todayIdx - 1]] : null;

if (!todayPos) { console.error(`No positions for ${dateStr}`); process.exit(1); }

// Only use Navagraha (filter out outer planets)
const NAVAGRAHA = new Set(PLANETS);
function filterNavagraha(positions) {
    return Object.fromEntries(
        Object.entries(positions).filter(([p]) => NAVAGRAHA.has(p))
    );
}

const todayFiltered = filterNavagraha(todayPos);
const yesterdayFiltered = yesterdayPos ? filterNavagraha(yesterdayPos) : null;

const signals = extractSignals(todayFiltered, yesterdayFiltered, dateStr);
const topSignals = getTopSignals(signals, 12);
const diff = yesterdayFiltered ? diffSky(todayFiltered, yesterdayFiltered, dateStr) : null;
const panchanga = getPanchanga(todayFiltered, dateStr);
const upcoming = scanUpcomingTransits(allPositions, sortedDates, todayIdx, 21);

const [observations, predictions, patterns] = await Promise.all([
    listMemories("observations", 5),
    listMemories("predictions", 10),
    recallMemory("current major world events", { namespace: "patterns", topK: 3, minSimilarity: 0.3 }),
]);

const headlines = await fetchNewsHeadlines({ limit: 15 });
const newsText = formatNewsForPrompt(headlines);

// ═══════════════════════════════════════════════════════════════════════════
// HOUSE LORDSHIP TABLE (Kalpurush Kundli)
// ═══════════════════════════════════════════════════════════════════════════

const HOUSE_LORDS = {
    1: "Mars", 2: "Venus", 3: "Mercury", 4: "Moon",
    5: "Sun", 6: "Mercury", 7: "Venus", 8: "Mars",
    9: "Jupiter", 10: "Saturn", 11: "Saturn", 12: "Jupiter",
};

const MUNDANE_HOUSES = {
    1: "Nation, public mood, identity",
    2: "Economy, treasury, trade",
    3: "Media, communications, transport",
    4: "Land, agriculture, opposition, weather",
    5: "Diplomacy, speculation, entertainment",
    6: "Military, health, labor, enemies",
    7: "Foreign affairs, treaties, war/peace",
    8: "Crises, death toll, intelligence, debt",
    9: "Law, religion, judiciary, philosophy",
    10: "Government, head of state, authority",
    11: "Parliament, allies, technology, gains",
    12: "Losses, espionage, prisons, hidden enemies",
};

function getHouseLordPositions() {
    const lines = [];
    for (let h = 1; h <= 12; h++) {
        const lord = HOUSE_LORDS[h];
        const data = todayFiltered[lord];
        if (!data) continue;
        const sign = ZODIAC_SIGNS[Math.floor(data.longitude / 30)];
        const housePos = Math.floor(data.longitude / 30) + 1;
        const retro = data.isRetro ? " (R)" : "";
        lines.push(`H${h} (${MUNDANE_HOUSES[h]}) → Lord ${lord} in ${sign} (H${housePos})${retro}`);
    }
    return lines.join("\n");
}

// ═══════════════════════════════════════════════════════════════════════════
// FIND THE DOMINANT CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

function findDominantConfig() {
    // Look for: closest approaching conjunction/opposition between slow planets
    const slow = ["Mars", "Jupiter", "Saturn", "Rahu", "Ketu"];
    let dominant = null;
    let smallestGap = 999;

    for (let i = 0; i < slow.length; i++) {
        for (let j = i + 1; j < slow.length; j++) {
            const p1 = slow[i], p2 = slow[j];
            if ((p1 === "Rahu" && p2 === "Ketu") || (p1 === "Ketu" && p2 === "Rahu")) continue;

            const d1 = todayFiltered[p1], d2 = todayFiltered[p2];
            if (!d1 || !d2) continue;

            const sign1 = Math.floor(d1.longitude / 30);
            const sign2 = Math.floor(d2.longitude / 30);

            // Same sign = conjunction, opposite sign = opposition
            if (sign1 === sign2 || Math.abs(sign1 - sign2) === 6) {
                const gap = Math.abs(d1.longitude - d2.longitude);
                const normGap = gap > 180 ? 360 - gap : gap;
                if (normGap < smallestGap) {
                    smallestGap = normGap;
                    const type = sign1 === sign2 ? "conjunction" : "opposition";

                    // Estimate perfection date
                    const speed1 = yesterdayFiltered?.[p1]
                        ? d1.longitude - yesterdayFiltered[p1].longitude
                        : 0;
                    const speed2 = yesterdayFiltered?.[p2]
                        ? d2.longitude - yesterdayFiltered[p2].longitude
                        : 0;
                    const closing = speed1 - speed2;
                    const daysToExact = closing !== 0 ? Math.abs(normGap / closing) : null;

                    dominant = {
                        planet1: p1, planet2: p2, type,
                        gap: normGap.toFixed(1),
                        sign: ZODIAC_SIGNS[sign1],
                        house: sign1 + 1,
                        daysToExact: daysToExact ? Math.round(daysToExact) : null,
                        closing: closing > 0,
                    };
                }
            }
        }
    }
    return dominant;
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

function formatPositions() {
    const lines = [];
    for (const [planet, data] of Object.entries(todayFiltered)) {
        const sign = ZODIAC_SIGNS[Math.floor(data.longitude / 30)];
        const deg = (data.longitude % 30).toFixed(1);
        const house = Math.floor(data.longitude / 30) + 1;
        const retro = data.isRetro ? " (R)" : "";
        const nak = getNakshatra(data.longitude);
        lines.push(`${planet}: ${deg}° ${sign} (H${house}) — ${nak.name} P${nak.pada}${retro}`);
    }
    return lines.join("\n");
}

function formatSignals() {
    return topSignals.map(s => {
        const applying = s.applying === true ? " APPLYING" : s.applying === false ? " separating" : "";
        const orb = s.orb != null ? ` (orb: ${s.orb}°)` : "";
        return `[★${s.intensity}/10] ${s.type}: ${s.planets.join(" + ")} ${s.aspect || s.dignity || ""}${orb}${applying}`;
    }).join("\n");
}

function formatUpcoming() {
    // Filter: skip Moon ingresses and daysAway=0
    return upcoming
        .filter(e => e.daysAway > 0)
        .filter(e => !(e.type === "ingress" && e.planet === "Moon"))
        .map(e => {
            if (e.type === "ingress") return `[${e.date}, +${e.daysAway}d] ${e.planet} enters ${e.toSign}`;
            if (e.type === "station") return `[${e.date}, +${e.daysAway}d] ${e.planet} goes ${e.stationType} in ${e.sign}`;
            if (e.type === "aspect_perfection" && e.orb < 5) return `[${e.date}, +${e.daysAway}d] ${e.planet1}-${e.planet2} ${e.aspect} perfects (orb: ${e.orb}°)`;
            return null;
        })
        .filter(Boolean)
        .join("\n");
}

function formatMemories() {
    const lines = [];
    if (observations.length) {
        lines.push("### Recent Observations");
        for (const o of observations.slice(0, 3)) lines.push(o.content.substring(0, 200));
    }
    if (predictions.length) {
        lines.push("\n### Pending Predictions (CHECK against news)");
        for (const p of predictions.slice(0, 8)) lines.push(`- ${p.content.substring(0, 200)}`);
    }
    return lines.join("\n");
}

function formatPanchanga() {
    if (!panchanga) return "";
    const p = panchanga;
    const mundane = getNakshatraMundane(p.nakshatra.name);
    return `Vara: ${p.vara.name} (${p.vara.lord}) | Tithi: ${p.tithi.paksha} ${p.tithi.name} #${p.tithi.index} | Moon: ${p.nakshatra.name} P${p.nakshatra.pada} (${p.nakshatra.lord}) | ${p.lunarPhase}\nMoon's mundane theme: ${mundane}`;
}

// ═══════════════════════════════════════════════════════════════════════════
// THE OUTPUT JSON SCHEMA (shared across all experiments)
// ═══════════════════════════════════════════════════════════════════════════

const OUTPUT_SCHEMA = `Return ONLY valid JSON:
{
  "worldEnergy": "2-3 paragraphs on current global energy",
  "mainEvent": "1 paragraph: THE dominant configuration and what it means",
  "predictions": [
    {
      "claim": "specific, falsifiable prediction",
      "timeframe": "by YYYY-MM-DD",
      "confidence": 0.0-1.0,
      "basedOn": "specific graha + house lord logic",
      "domains": ["domain1", "domain2"]
    }
  ],
  "predictionUpdates": [
    { "originalClaim": "...", "status": "confirmed|developing|missed|too_early", "evidence": "..." }
  ],
  "observations": "What you noticed worth remembering"
}`;

// ═══════════════════════════════════════════════════════════════════════════
// EXPERIMENT A: CURRENT SYSTEM (BASELINE)
// ═══════════════════════════════════════════════════════════════════════════

const SYSTEM_A = `You are a Vedic mundane astrologer analyzing world events through the Navagraha.
Sidereal zodiac, Lahiri ayanamsha, whole-sign houses from Aries = H1 (Kalpurush Kundli).
Make 5-8 specific, falsifiable predictions with check dates. At least 2 must be about events NOT in today's news.
${OUTPUT_SCHEMA}`;

function buildPromptA() {
    return `# Cosmic Intelligence Report — ${dateStr}

## Panchanga
${formatPanchanga()}

## Graha Positions
${formatPositions()}

## Active Signals (ranked)
${formatSignals()}

${diff ? `Changes: ${diff.summary}` : ""}

## Upcoming Transits
${formatUpcoming() || "None detected"}

## Memories
${formatMemories()}

## News Headlines
${newsText}

Generate your daily analysis as JSON.`;
}

// ═══════════════════════════════════════════════════════════════════════════
// EXPERIMENT B: "MAIN EVENT" + HOUSE LORDS
// ═══════════════════════════════════════════════════════════════════════════

const dominant = findDominantConfig();

const SYSTEM_B = `You are a senior Vedic mundane astrologer (Medini Jyotish). You think like B.V. Raman — identifying the ONE dominant planetary yoga first, then building all analysis around it.

## Your Method
1. Identify the MAIN EVENT — the single most important planetary configuration right now
2. Analyze it through HOUSE LORDSHIPS — which houses do the involved planets rule? Where are they placed? This creates a specific story.
3. Layer in secondary signals and daily triggers (Moon, fast planets)
4. Make predictions anchored to SPECIFIC DATES when transits perfect

## Key Principles
- House lords are MORE important than house occupation. "10th lord in 12th" tells a story; "Saturn in Pisces" does not.
- Slow planets set the theme; fast planets trigger events
- The Moon today TRIGGERS the emotional expression of whatever the dominant yoga represents
- Predictions must cite specific dates and specific graha configurations
- If you can't be proven wrong, you haven't said anything useful

## Kalpurush Kundli House Lords
H1=Mars, H2=Venus, H3=Mercury, H4=Moon, H5=Sun, H6=Mercury
H7=Venus, H8=Mars, H9=Jupiter, H10=Saturn, H11=Saturn, H12=Jupiter

${OUTPUT_SCHEMA}`;

function buildPromptB() {
    let mainEventSection = "";
    if (dominant) {
        const p1Lord = Object.entries(HOUSE_LORDS).filter(([,v]) => v === dominant.planet1).map(([k]) => `H${k}`).join(",");
        const p2Lord = Object.entries(HOUSE_LORDS).filter(([,v]) => v === dominant.planet2).map(([k]) => `H${k}`).join(",");
        mainEventSection = `## ⚡ DOMINANT CONFIGURATION — THIS IS THE MAIN EVENT
${dominant.planet1}-${dominant.planet2} ${dominant.type} in ${dominant.sign} (H${dominant.house})
Gap: ${dominant.gap}° ${dominant.closing ? "(CLOSING)" : "(opening)"}
${dominant.daysToExact ? `Estimated perfection: ~${dominant.daysToExact} days from today` : ""}

${dominant.planet1} rules: ${p1Lord}
${dominant.planet2} rules: ${p2Lord}

ANALYZE THIS FIRST. What story do these house lordships tell? Then layer everything else.
`;
    }

    return `# Cosmic Intelligence Report — ${dateStr}

${mainEventSection}

## Today's Flavor: Panchanga
${formatPanchanga()}

## House Lord Positions (WHERE each house's energy is directed)
${getHouseLordPositions()}

## Graha Positions
${formatPositions()}

## Key Signals
${formatSignals()}

## What's Coming (next 21 days)
${formatUpcoming() || "None detected"}

## Your Past Analysis
${formatMemories()}

## Today's World News
${newsText}

Build your analysis around the main event. Show how today's triggers connect to it. Make 5-8 predictions with specific dates.`;
}

// ═══════════════════════════════════════════════════════════════════════════
// EXPERIMENT C: "LAYERED CONTEXT" — MACRO → DAILY
// ═══════════════════════════════════════════════════════════════════════════

const SYSTEM_C = `You are a Vedic mundane astrologer who thinks in temporal layers, like K.N. Rao.

## Your Temporal Framework
1. ERA CONTEXT (years): Jupiter-Saturn cycle, Rahu-Ketu axis placement — these define the civilizational moment
2. SEASON CONTEXT (months): Which signs hold the slow planets? What's the macro pattern?
3. WEEK CONTEXT: What's building, perfecting, or separating among slow planets?
4. TODAY: Moon's nakshatra, tithi, fast planet triggers — the emotional and event trigger layer

## Prediction Anchoring
Every prediction MUST be anchored to a specific astronomical event:
- "When Mars conjuncts Saturn at ~12° Pisces around [date], expect..."
- "Mercury entering Pisces on [date] will activate the 12th house stellium, bringing..."
NOT: "Expect continued volatility" (unfalsifiable garbage)

## House Lord Logic
Always trace house lordships. "Saturn (H10+H11 lord) in H12" = Government and Parliament dealing with losses, secrets, foreign enemies. This is SPECIFIC and ACTIONABLE.

${OUTPUT_SCHEMA}`;

function buildPromptC() {
    // Compute macro context
    const jupSign = ZODIAC_SIGNS[Math.floor(todayFiltered.Jupiter.longitude / 30)];
    const satSign = ZODIAC_SIGNS[Math.floor(todayFiltered.Saturn.longitude / 30)];
    const rahuSign = ZODIAC_SIGNS[Math.floor(todayFiltered.Rahu.longitude / 30)];
    const ketuSign = ZODIAC_SIGNS[Math.floor(todayFiltered.Ketu.longitude / 30)];

    // Find planets in same sign (stelliums)
    const signGroups = {};
    for (const [planet, data] of Object.entries(todayFiltered)) {
        const sign = ZODIAC_SIGNS[Math.floor(data.longitude / 30)];
        if (!signGroups[sign]) signGroups[sign] = [];
        signGroups[sign].push(planet);
    }
    const stelliums = Object.entries(signGroups)
        .filter(([, planets]) => planets.length >= 3)
        .map(([sign, planets]) => `${sign} (H${ZODIAC_SIGNS.indexOf(sign) + 1}): ${planets.join(", ")}`)
        .join("\n");

    return `# Cosmic Intelligence Report — ${dateStr}

## LAYER 1: ERA CONTEXT (the civilizational moment)
Jupiter in ${jupSign} (H${ZODIAC_SIGNS.indexOf(jupSign) + 1}) — Jupiter rules H9 (law, religion) and H12 (losses, foreign)
Saturn in ${satSign} (H${ZODIAC_SIGNS.indexOf(satSign) + 1}) — Saturn rules H10 (government) and H11 (parliament, tech)
Rahu-Ketu axis: ${rahuSign}-${ketuSign} (H${ZODIAC_SIGNS.indexOf(rahuSign) + 1}-H${ZODIAC_SIGNS.indexOf(ketuSign) + 1})

## LAYER 2: SEASON CONTEXT (current concentrations)
${stelliums ? `Stelliums:\n${stelliums}` : "No stelliums"}

House Lord Map:
${getHouseLordPositions()}

## LAYER 3: THIS WEEK (what's building or perfecting)
${dominant ? `DOMINANT: ${dominant.planet1}-${dominant.planet2} ${dominant.type} in ${dominant.sign}, ${dominant.gap}° gap, ${dominant.closing ? "CLOSING" : "opening"}${dominant.daysToExact ? `, ~${dominant.daysToExact}d to exact` : ""}` : "No dominant slow-planet config"}

Key signals:
${formatSignals()}

What's coming:
${formatUpcoming() || "None detected"}

## LAYER 4: TODAY (triggers and flavor)
${formatPanchanga()}

Positions:
${formatPositions()}

${diff ? `Changes: ${diff.summary}` : ""}

## MEMORY (your continuity)
${formatMemories()}

## NEWS (ground truth — read LAST)
${newsText}

Analyze layer by layer. How does today's Moon trigger the weekly/seasonal themes? Make 5-8 predictions anchored to specific dates.`;
}

// ═══════════════════════════════════════════════════════════════════════════
// RUN ALL THREE EXPERIMENTS
// ═══════════════════════════════════════════════════════════════════════════

const genAI = new GoogleGenerativeAI(apiKey);

async function runExperiment(name, systemPrompt, userPrompt) {
    console.log(`\n${"█".repeat(80)}`);
    console.log(`EXPERIMENT ${name}`);
    console.log(`${"█".repeat(80)}\n`);

    // Show prompt size
    console.log(`System prompt: ${systemPrompt.length} chars`);
    console.log(`User prompt: ${userPrompt.length} chars`);
    console.log(`Total: ${(systemPrompt.length + userPrompt.length)} chars\n`);

    const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        systemInstruction: systemPrompt,
        generationConfig: {
            temperature: 0.4,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
        },
    });

    const start = Date.now();
    try {
        const result = await model.generateContent(userPrompt);
        const text = result.response.text();
        const output = JSON.parse(text);
        const elapsed = Date.now() - start;

        console.log(`Time: ${elapsed}ms\n`);

        console.log("─── WORLD ENERGY ───");
        console.log(output.worldEnergy?.substring(0, 500));

        if (output.mainEvent) {
            console.log("\n─── MAIN EVENT ───");
            console.log(output.mainEvent?.substring(0, 300));
        }

        console.log("\n─── PREDICTIONS ───");
        for (const p of (output.predictions || [])) {
            console.log(`• [conf:${p.confidence}] ${p.claim}`);
            console.log(`  timeframe: ${p.timeframe}`);
            console.log(`  basedOn: ${p.basedOn?.substring(0, 150)}`);
            console.log();
        }

        console.log("─── OBSERVATIONS ───");
        console.log(output.observations?.substring(0, 400));

        return output;
    } catch (err) {
        console.error(`FAILED: ${err.message}`);
        return null;
    }
}

// Run sequentially to avoid rate limits
const resultA = await runExperiment("A: BASELINE (signal dump)", SYSTEM_A, buildPromptA());
const resultB = await runExperiment("B: MAIN EVENT + HOUSE LORDS", SYSTEM_B, buildPromptB());
const resultC = await runExperiment("C: LAYERED CONTEXT (macro → daily)", SYSTEM_C, buildPromptC());

// ═══════════════════════════════════════════════════════════════════════════
// COMPARISON SUMMARY
// ═══════════════════════════════════════════════════════════════════════════

console.log(`\n\n${"═".repeat(80)}`);
console.log("COMPARISON SUMMARY");
console.log(`${"═".repeat(80)}\n`);

function scorePredictions(preds) {
    if (!preds?.length) return { count: 0, specific: 0, dated: 0, novel: 0 };
    let specific = 0, dated = 0;
    for (const p of preds) {
        if (p.timeframe?.match(/\d{4}-\d{2}-\d{2}/)) dated++;
        // Count as "specific" if it mentions numbers, names, or concrete actions
        if (/\$|\d+%|cross|breach|announce|sign|strike|arrest|resign/i.test(p.claim)) specific++;
    }
    return { count: preds.length, specific, dated };
}

const experiments = [
    ["A: Baseline", resultA],
    ["B: Main Event", resultB],
    ["C: Layered", resultC],
];

for (const [name, result] of experiments) {
    if (!result) { console.log(`${name}: FAILED`); continue; }
    const scores = scorePredictions(result.predictions);
    console.log(`${name}:`);
    console.log(`  Predictions: ${scores.count} total, ${scores.specific} specific/falsifiable, ${scores.dated} with exact dates`);
    console.log(`  Has mainEvent: ${!!result.mainEvent}`);
    console.log(`  worldEnergy length: ${result.worldEnergy?.length || 0} chars`);
    console.log(`  mentions house lords: ${/lord|H\d+ lord|rules H/i.test(JSON.stringify(result))}`);
    console.log();
}

console.log("Done. Read the outputs above and judge which approach produces");
console.log("the most specific, falsifiable, date-anchored predictions.");

process.exit(0);
