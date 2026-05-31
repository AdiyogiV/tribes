/**
 * Cosmic Daily — The Daily Intelligence Function
 *
 * One function. Runs once per day. Produces the complete cosmic output.
 *
 * Flow:
 *   1. Recall relevant memories (embeddings search + recent)
 *   2. Extract sky signals (pure math, no LLM)
 *   3. Fetch news headlines (Google News RSS)
 *   4. One Gemini call (signals + news + memories → structured JSON)
 *   5. Store output in Firestore (frontend reads this)
 *   6. Store observations + predictions as new memories
 *
 * Output stored at: cosmic_daily_output/{date}
 * Memories stored in: cosmic_memory (via agent_memory.js)
 */

import { HttpsError } from "firebase-functions/v2/https";
import { getVertexAI, extractText } from "../lib/vertex_client.js";
import { db, logger } from "../lib/firebase.js";
import { AI_MODELS } from "../lib/config.js";
import { extractSignals, diffSky, getTopSignals } from "../lib/signal_engine.js";
import { upsertSignals } from "../lib/signal_store.js";
import { initMemory, storeMemory, recallMemory, listMemories } from "../lib/agent_memory.js";
// News is now sourced via Gemini's Google Search grounding (nimitta discipline)
// import { fetchNewsHeadlines, formatNewsForPrompt } from "../lib/news_feed.js";
import { getPanchanga, getNakshatra, getNakshatraMundane } from "../lib/vedic_utils.js";
import { buildHouseLordContext } from "../lib/house_lords.js";
import { scanUpcomingTransits } from "../lib/upcoming_transits.js";
import { ZODIAC_SIGNS, MUNDANE_HOUSES } from "../lib/constants.js";


// =============================================================================
// SYSTEM PROMPT
// =============================================================================

const SYSTEM_PROMPT = `You are a Vedic mundane astrologer (Medini Jyotish) analyzing world events.

You have access to Google Search. Use it freely — not just for today's headlines, but for ANYTHING that deepens your astrological analysis. You are an astrologer with a research library, not a news reader with a horoscope column.

## The Nimitta Discipline

Nimitta (निमित्त) = omens in the world that confirm the sky's speech.

YOUR ANALYSIS MUST FLOW IN THIS ORDER — NEVER REVERSE IT:
1. READ THE SKY FIRST. Form your analysis from planetary positions alone.
2. THEN research. Search for whatever you need — current events, historical parallels, specific data, verification of past predictions.
3. Where reality matches the sky → cite it as nimitta: "Mars-Saturn in H7 speaks of broken alliances — the [specific event] is its earthly echo."
4. Where the sky indicates something not yet visible in the world → that is your strongest prediction. Trust the chart.

## How to Use Google Search (your research toolkit)

Search for ANYTHING that serves your analysis. Examples:
- **Nimitta (current events)**: "major world news today", "India diplomatic developments", "global markets today"
- **Historical parallels**: "what happened when Saturn was in Pisces historically", "last Jupiter-Saturn conjunction world events"
- **Grounding predictions**: "current crude oil price", "India GDP growth latest", "upcoming world elections 2026"
- **Verifying past predictions**: Search for specific events your past predictions referenced
- **Regional context**: "Southeast Asia political situation", "European energy crisis status"
- **Specific domains**: If H2 (wealth) is afflicted, search for "banking crisis", "currency devaluation" — see if the pattern is manifesting

Do NOT limit yourself to headlines. A real astrologer researches deeply. But remember: research INFORMS the chart reading, it does not REPLACE it.

CRITICAL: Your predictions must be DERIVED FROM transits and yogas, not from news extrapolation. A prediction that could be made by anyone reading a newspaper is worthless. Your value is seeing what journalists cannot — the pattern before the event manifests.

TEST: For each prediction, ask "Could a smart person with no astrology knowledge make this prediction just from reading today's news?" If yes, it is too obvious. Dig deeper into the chart.

## Core Method
- Sidereal zodiac, Lahiri ayanamsha (pre-applied). Whole-sign houses, Aries = H1.
- Navagraha only: Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn, Rahu, Ketu.
- Vedic aspects (drishti): All planets aspect 7th. Mars also 4th/8th. Jupiter also 5th/9th. Saturn also 3rd/10th. Rahu/Ketu 5th/9th. These are FULL-STRENGTH.
- Combustion weakens a planet's significations. Retrograde intensifies and internalizes.

## THE MOST IMPORTANT RULE: HOUSE LORDSHIP
Never say "Saturn in H12." Always say "Saturn (H10/H11 lord) in H12" — meaning government and parliament are in the house of losses/exile. The LORDSHIP tells you WHAT is affected. The PLACEMENT tells you HOW. You will receive a pre-computed "House Lord Context" — USE IT for every claim.

## How to Analyze
1. **MAIN EVENT**: Identify the single most dominant yoga. This is the headline — from the SKY, not the news.
2. **Lordship trace**: Which houses are activated? This tells you which domains are under pressure.
3. **Temporal arc**: Forming (building crisis), perfecting (peak), or separating (resolving)?
4. **Triggers**: Fast planets crossing slow-planet configurations trigger events.
5. **UPCOMING TRANSITS**: What perfects in coming days? This is your predictive edge.
6. **Research**: Search for whatever context you need. Historical parallels of similar yogas. Current state of affected domains. Specific data points to anchor predictions.
7. **Nimitta synthesis**: Which current events confirm the sky? Which sky patterns have NO worldly echo yet?

## Temporal Layers
Think in layers: Era (Jupiter-Saturn cycle, Rahu-Ketu axis) → Season (slow planet aspects) → Week (what's perfecting) → Today (Panchanga + triggers).

## Prediction Rules
- 3-5 predictions. Quality over quantity.
- At least 2 must predict events NOT YET visible in the world — things the sky indicates but the world hasn't seen yet. This is where astrology earns its keep.
- Each prediction MUST reference a DIFFERENT upcoming transit or signal.
  Do NOT make 3 predictions about the same Mars-Saturn conjunction.
- Each needs: check date ("by YYYY-MM-DD"), confidence (0-1), FULL lordship trace.
- Be FALSIFIABLE — if you can't be proven wrong, you haven't said anything useful.
  BAD: "increased volatility in financial markets" (always true)
  BAD: "military escalation in regions with existing geopolitical tensions" (unfalsifiable)
  GOOD: "crude oil crosses $85/bbl by [date] as H1/H8 lord Mars conjuncts H10/H11 lord Saturn in H12"
  GOOD: "formal diplomatic protest or sanctions announced between [specific countries] by [date]"
  GOOD: "major tech company faces regulatory action or data breach by [date]"
- When two transits create contradictory effects (e.g., Mars-Saturn destruction vs Venus entering own sign), ACKNOWLEDGE the tension and explain which will dominate and why.
- Ground predictions in UPCOMING TRANSITS, not in news momentum.
- When possible, cite historical parallels: "Last time [similar yoga] occurred in [year], [what happened]."

## Memory
Use memories from previous runs. Check pending predictions against today's news — SEARCH to verify. Be honest about misses.

## Output
Return ONLY valid JSON (no markdown fences, no explanation outside the JSON):
{
  "worldEnergy": "2-3 paragraphs. Layer 1: era/season. Layer 2: this week. Layer 3: today.",
  "mainEvent": "The dominant yoga, lordship trace, whether forming/perfecting/separating.",
  "nimitta": "Current events and findings from your research that confirm, contradict, or contextualize the sky's patterns.",
  "predictions": [
    { "claim": "...", "timeframe": "by YYYY-MM-DD", "confidence": 0.0-1.0, "basedOn": "H[X] lord [Planet] in H[Y]...", "domains": ["..."], "isInNews": false, "historicalParallel": "optional — similar past yoga and what happened" }
  ],
  "predictionUpdates": [
    { "originalClaim": "...", "status": "confirmed|developing|missed|too_early", "evidence": "..." }
  ],
  "observations": "Patterns, correlations, things to watch.",
  "researchNotes": "Key findings from your searches — historical parallels, data points, context that informed your analysis."
}`;

// =============================================================================
// MAIN FUNCTION — Generate daily cosmic output
// =============================================================================

/**
 * Generate the complete daily cosmic intelligence output.
 *
 * @param {string} geminiApiKeyValue - Gemini API key
 * @param {string} [dateStr] - Target date (default: today)
 * @returns {Object} The complete daily output
 */
export async function generateDailyOutput(geminiApiKeyValue, dateStr = null) {
    const startTime = Date.now();
    dateStr = dateStr || new Date().toISOString().split("T")[0];

    logger.info("Cosmic daily starting", { structuredData: true, date: dateStr });

    // Initialize memory with API key
    initMemory();

    // ── Step 1: Recall memories ─────────────────────────────────────────
    const [recentObservations, recentPredictions, relevantPatterns] = await Promise.all([
        listMemories("observations", 7), // Last 7 daily observations
        listMemories("predictions", 15), // Recent predictions (may be pending)
        recallMemory("current major world events planetary patterns", {
            namespace: "patterns",
            topK: 5,
            minSimilarity: 0.2,
        }),
    ]);

    // ── Step 2: Extract sky signals ─────────────────────────────────────
    const skyData = await loadSkyAndExtractSignals(dateStr);

    // ── Step 3: Build prompt and call Gemini with Google Search grounding
    // No separate news fetch needed — Gemini searches the web directly.
    // The system prompt enforces the Nimitta Discipline: analyze the sky
    // FIRST, then use Google Search to find current events as nimitta
    // (confirmations), not as the source of predictions.
    const userPrompt = buildPrompt(
        dateStr, skyData,
        recentObservations, recentPredictions, relevantPatterns,
    );

    const vertexAI = getVertexAI();
    const model = vertexAI.getGenerativeModel({
        model: AI_MODELS?.GEMINI_FLASH || "gemini-2.5-flash",
        systemInstruction: SYSTEM_PROMPT,
        tools: [{ googleSearch: {} }],
        generationConfig: {
            temperature: 0.4,
            maxOutputTokens: 8192,
        },
    });

    const result = await model.generateContent({
        contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    });
    const responseText = extractText(result);

    // Parse JSON — handle markdown code fences if present
    let output;
    try {
        const jsonStr = responseText
            .replace(/^[\s\S]*?(?=\{)/, "") // trim anything before first {
            .replace(/\}[\s\S]*$/, "}"); // trim anything after last }
        output = JSON.parse(jsonStr);
    } catch {
        // Second attempt: try stripping markdown fences
        try {
            const cleaned = responseText
                .replace(/^```json?\n?/, "")
                .replace(/\n?```$/, "")
                .trim();
            output = JSON.parse(cleaned);
        } catch {
            logger.error("Failed to parse Gemini JSON response", {
                structuredData: true,
                responsePreview: responseText.substring(0, 500),
            });
            throw new Error("Gemini returned invalid JSON");
        }
    }

    // ── Step 5: Enrich output with signal + house metadata ──────────────
    const enrichedOutput = enrichOutput(output, dateStr, skyData);

    // ── Step 6: Store in Firestore ──────────────────────────────────────
    await db.collection("cosmic_daily_output").doc(dateStr).set({
        ...enrichedOutput,
        generatedAt: new Date(),
        wallTimeMs: Date.now() - startTime,
    });

    // ── Step 5: Store memories for future runs ──────────────────────────
    // Pass empty headlines since news is now sourced via Gemini Search grounding
    await storeNewMemories(dateStr, enrichedOutput, skyData, []);

    const wallTime = Date.now() - startTime;
    logger.info("Cosmic daily completed", {
        structuredData: true,
        date: dateStr,
        wallTimeMs: wallTime,
        predictionsCount: enrichedOutput.predictions?.length || 0,
        hasNimitta: !!enrichedOutput.nimitta,
    });

    return enrichedOutput;
}

// =============================================================================
// SKY DATA LOADING
// =============================================================================

async function loadSkyAndExtractSignals(dateStr) {
    const skyDoc = await db.collection("global_astro").doc("sky_positions").get();
    if (!skyDoc.exists) {
        return { signals: [], topSignals: [], diff: null, positions: null, panchanga: null, upcoming: [] };
    }

    const positions = skyDoc.data()?.positions || {};
    const todayPos = positions[dateStr];
    if (!todayPos) {
        return { signals: [], topSignals: [], diff: null, positions: null, panchanga: null, upcoming: [] };
    }

    const sortedDates = Object.keys(positions).sort();
    const todayIdx = sortedDates.indexOf(dateStr);
    const yesterdayPos = todayIdx > 0 ? positions[sortedDates[todayIdx - 1]] : null;

    const signals = extractSignals(todayPos, yesterdayPos, dateStr);
    const diff = yesterdayPos ? diffSky(todayPos, yesterdayPos, dateStr) : null;
    const topSignals = getTopSignals(signals, 15);

    // Panchanga for today
    const panchanga = getPanchanga(todayPos, dateStr);

    // Scan upcoming transits (next 14 days)
    const upcoming = scanUpcomingTransits(positions, sortedDates, todayIdx, 14);

    // Build house lord context
    const houseLords = buildHouseLordContext(todayPos);

    // Persist signals
    await upsertSignals(signals);

    return { signals, topSignals, diff, positions: todayPos, panchanga, upcoming, houseLords };
}

// =============================================================================
// PROMPT BUILDING
// =============================================================================

function buildPrompt(dateStr, skyData, observations, predictions, patterns) {
    const sections = [];

    sections.push(`# Cosmic Intelligence Report — ${dateStr}\n`);

    // ── SECTION 1: MEMORY (context first for continuity) ────────────────
    if (observations.length > 0 || predictions.length > 0 || patterns.length > 0) {
        sections.push("## Your Memory\n");

        if (predictions.length > 0) {
            sections.push("### Pending Predictions (CHECK against today's news!)");
            for (const pred of predictions) sections.push(`- ${pred.content}`);
            sections.push("");
        }

        if (observations.length > 0) {
            sections.push("### Recent Observations");
            for (const obs of observations) {
                const date = obs.createdAt ? new Date(obs.createdAt).toISOString().split("T")[0] : "?";
                sections.push(`[${date}] ${obs.content}`);
            }
            sections.push("");
        }

        if (patterns.length > 0) {
            sections.push("### Known Patterns");
            for (const pat of patterns) sections.push(`- ${pat.content}`);
            sections.push("");
        }
    }

    // ── SECTION 2: HOUSE LORD CONTEXT (the soul of Vedic mundane) ───────
    if (skyData.houseLords?.summary) {
        sections.push("## House Lord Context (Kalpurush Kundli)");
        sections.push("USE these lordships in ALL your analysis and predictions.\n");
        sections.push(skyData.houseLords.summary);
        sections.push("");
    }

    // ── SECTION 3: PANCHANGA ────────────────────────────────────────────
    if (skyData.panchanga) {
        const p = skyData.panchanga;
        sections.push("## Panchanga");
        sections.push(`  Vara: ${p.vara.name} (lord: ${p.vara.lord})`);
        sections.push(`  Tithi: ${p.tithi.name} (${p.tithi.paksha} Paksha) — ${p.lunarPhase}`);
        sections.push(`  Moon Nakshatra: ${p.nakshatra.name} (pada ${p.nakshatra.pada}, lord: ${p.nakshatra.lord})`);
        const moonMundane = getNakshatraMundane(p.nakshatra.name);
        if (moonMundane) sections.push(`    → Mundane theme: ${moonMundane}`);
        sections.push(`  Yoga: ${p.yoga.name}`);
        sections.push("");
    }

    // ── SECTION 4: MAIN EVENT + ALL SIGNALS ─────────────────────────────
    sections.push("## Active Sky Signals (ranked by intensity)");
    if (skyData.topSignals.length > 0) {
        const main = skyData.topSignals[0];
        sections.push(`\n### MAIN EVENT (highest intensity signal)`);
        sections.push(formatSignal(main));
        sections.push("");

        if (skyData.topSignals.length > 1) {
            sections.push("### Supporting Signals");
            for (const s of skyData.topSignals.slice(1)) {
                sections.push(formatSignal(s));
            }
        }
    } else {
        sections.push("No signals extracted.");
    }

    if (skyData.diff) {
        sections.push(`\nChanges from yesterday: ${skyData.diff.summary}`);
    }
    sections.push("");

    // ── SECTION 5: UPCOMING TRANSITS ────────────────────────────────────
    if (skyData.upcoming?.length > 0) {
        sections.push("## ⚠️ Upcoming Transits (Next 14 Days) — YOUR PREDICTIVE EDGE");
        sections.push("Anchor predictions to these dates.\n");
        for (const evt of skyData.upcoming) {
            if (evt.type === "aspect_perfection") {
                sections.push(`- [${evt.date}, ${evt.daysAway}d] ${evt.planet1}-${evt.planet2} ${evt.aspect} PERFECTS (orb: ${evt.orb}°)`);
            } else if (evt.type === "ingress") {
                sections.push(`- [${evt.date}, ${evt.daysAway}d] ${evt.planet} enters ${evt.toSign}`);
            } else if (evt.type === "station") {
                sections.push(`- [${evt.date}, ${evt.daysAway}d] ${evt.planet} goes ${evt.stationType} in ${evt.sign}`);
            }
        }
        sections.push("");
    }

    // ── SECTION 6: NIMITTA INSTRUCTION ────────────────────────────────
    sections.push("## Nimitta — Current Events as Omens");
    sections.push("Use Google Search to find today's major world news headlines.");
    sections.push("These are NIMITTA (omens) — earthly echoes of the sky's patterns.");
    sections.push("DO NOT let news drive your analysis. The sky speaks first.\n");
    sections.push("Process:");
    sections.push("1. You have already read the sky above. Hold your analysis.");
    sections.push("2. Now search for today's news.");
    sections.push("3. Where news CONFIRMS a planetary pattern → cite it as nimitta.");
    sections.push("4. Where the sky indicates something NOT yet in news → that is your strongest prediction.");
    sections.push("5. Where news contradicts the sky → note it honestly, but trust the chart.\n");

    // ── TASK ─────────────────────────────────────────────────────────────
    sections.push("## Your Task");
    sections.push("1. Identify the MAIN EVENT — the single dominant yoga/stellium and its lordship implications.");
    sections.push("2. Layer your worldEnergy: era → season → week → today.");
    sections.push("3. Search Google for today's top world news. Use them as nimitta, not as prediction sources.");
    sections.push("4. Make 3-5 predictions — each anchored to a DIFFERENT upcoming transit date. Full lordship traces.");
    sections.push("   At least 2 predictions must be about things NOT YET in the news.");
    sections.push("5. If signals create contradictory effects, ACKNOWLEDGE the tension.");
    sections.push("6. Check pending predictions against today's news. Be honest about misses.");
    sections.push("\nGenerate your JSON output. No markdown fences — raw JSON only.");

    return sections.join("\n");
}

/** Format a single signal for prompt display. */
function formatSignal(s) {
    const applying = s.applying === true ? " APPLYING" : s.applying === false ? " separating" : "";
    const orb = s.orb != null ? ` (orb: ${s.orb}°)` : "";
    const detail = s.aspect || s.dignity || s.stationType || s.yogaName || (s.type === "stellium" ? `${s.count}-planet stellium in ${s.sign}` : "");
    const desc = s.detail?.description ? `\n    ${s.detail.description}` : "";
    return `- [★${s.intensity}/10] ${s.type}: ${s.planets.join(" + ")} ${detail}${orb}${applying}${desc}\n    Domains: ${(s.domains || []).slice(0, 5).join(", ")}`;
}

// =============================================================================
// OUTPUT ENRICHMENT
// =============================================================================

function enrichOutput(output, dateStr, skyData) {
    // Build house metadata from house lords
    const houses = {};
    const hlPlacements = skyData.houseLords?.placements || [];

    for (let h = 1; h <= 12; h++) {
        const sign = ZODIAC_SIGNS[(h - 1) % 12];

        // Find planets in this house from house lord data
        const planetsInHouse = hlPlacements
            .filter((p) => p.occupiedHouse === h)
            .map((p) => ({
                planet: p.planet,
                degree: p.signDegree != null ? +p.signDegree.toFixed(1) : null,
                isRetro: p.isRetro,
                lordsOf: p.lordsOf,
            }));

        const mundane = MUNDANE_HOUSES[h] || {};
        houses[h] = {
            sign,
            name: mundane.name || "",
            domain: mundane.domain || "",
            planets: planetsInHouse,
        };
    }

    return {
        date: dateStr,
        worldEnergy: output.worldEnergy || "",
        mainEvent: output.mainEvent || "",
        predictions: output.predictions || [],
        predictionUpdates: output.predictionUpdates || [],
        houses,
        observations: output.observations || "",
        panchanga: skyData.panchanga || null,
        upcomingTransits: (skyData.upcoming || []).slice(0, 10),
        signalsSummary: skyData.topSignals.slice(0, 8).map((s) => ({
            id: s.id, type: s.type, planets: s.planets,
            aspect: s.aspect, dignity: s.dignity, yogaName: s.yogaName,
            sign: s.sign, house: s.house, count: s.count,
            intensity: s.intensity, applying: s.applying,
            orb: s.orb, domains: s.domains,
        })),
    };
}


// =============================================================================
// MEMORY STORAGE
// =============================================================================

async function storeNewMemories(dateStr, output, skyData, headlines) {
    const tasks = [];

    // Store today's observation
    const topSignalsSummary = skyData.topSignals.slice(0, 5)
        .map((s) => `${s.planets.join("-")} ${s.aspect || s.dignity || s.yogaName || (s.type === "stellium" ? s.count + "-planet stellium" : "") || ""} (${s.intensity}/10)`)
        .join(", ");
    const topHeadlines = headlines.slice(0, 5).map((h) => h.title).join("; ");

    const observationContent = `[${dateStr}] Signals: ${topSignalsSummary}. News: ${topHeadlines}. Observations: ${output.observations || "none"}`;

    tasks.push(storeMemory(observationContent, {
        namespace: "observations",
        tags: extractSignalTags(skyData.topSignals),
        metadata: { date: dateStr, signalCount: skyData.signals.length },
    }));

    // Store each new prediction with a check-after date
    if (output.predictions?.length) {
        for (const pred of output.predictions) {
            // Parse check date from timeframe ("by YYYY-MM-DD") or default to +14 days
            let checkAfterDate = dateStr;
            const dateMatch = pred.timeframe?.match(/(\d{4}-\d{2}-\d{2})/);
            if (dateMatch) {
                checkAfterDate = dateMatch[1];
            } else {
                // Default: 14 days from now
                const d = new Date(dateStr);
                d.setDate(d.getDate() + 14);
                checkAfterDate = d.toISOString().split("T")[0];
            }

            const predContent = `[${dateStr}] Prediction (check by ${checkAfterDate}): ${pred.claim}. Confidence: ${pred.confidence}. Based on: ${pred.basedOn}. Domains: ${(pred.domains || []).join(", ")}`;
            tasks.push(storeMemory(predContent, {
                namespace: "predictions",
                tags: pred.domains || [],
                metadata: { date: dateStr, confidence: pred.confidence, checkAfterDate },
            }));
        }
    }

    // Store prediction updates as pattern observations
    if (output.predictionUpdates?.length) {
        for (const update of output.predictionUpdates) {
            if (update.status === "confirmed" || update.status === "missed") {
                const patternContent = `[${dateStr}] Prediction ${update.status}: "${update.originalClaim}". Evidence: ${update.evidence}`;
                tasks.push(storeMemory(patternContent, {
                    namespace: "patterns",
                    tags: [update.status],
                    metadata: { date: dateStr, status: update.status },
                }));
            }
        }
    }

    await Promise.all(tasks);
}

function extractSignalTags(signals) {
    const tags = new Set();
    for (const s of signals) {
        for (const p of s.planets || []) {
            tags.add(p.toLowerCase());
        }
        if (s.aspect) tags.add(s.aspect);
        if (s.type) tags.add(s.type);
    }
    return [...tags].slice(0, 15); // cap tags
}

// =============================================================================
// CLOUD FUNCTION TRIGGERS
// =============================================================================

/** Extracted runner for orchestrator consolidation. */
export async function runCosmicDailyScheduled() {
    // Quick health check — skip run entirely if Vertex AI is down
    try {
        const vertexAI = getVertexAI();
        const healthModel = vertexAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        await healthModel.generateContent("health check");
    } catch (healthErr) {
        logger.warn("⚠️ Vertex AI health check failed, skipping cosmic daily run", {
            structuredData: true,
            error: String(healthErr),
            status: healthErr.status || "unknown",
        });
        return;
    }

    const today = new Date().toISOString().split("T")[0];
    await generateDailyOutput(null, today);
}

// NOTE: `cosmicDailyScheduled` was a standalone `onSchedule` export.
// It is now invoked by `unifiedOrchestrator` Phase 3 (content generation)
// via the `runCosmicDailyScheduled` runner above.

/** Handler: Manual cosmic daily generation. Extracted for gateway reuse. */
export async function handleCosmicDailyManual(request) {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
    }

    const dateStr = request.data?.date || new Date().toISOString().split("T")[0];
    const output = await generateDailyOutput(null, dateStr);

    return {
        success: true,
        date: dateStr,
        predictionsCount: output.predictions?.length || 0,
        worldEnergy: output.worldEnergy?.substring(0, 500),
    };
}
