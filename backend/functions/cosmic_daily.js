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

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI } from "@google/generative-ai";

import { geminiApiKey } from "../lib/secrets.js";
import { db, logger } from "../lib/firebase.js";
import { AI_MODELS } from "../lib/config.js";
import { extractSignals, diffSky, getTopSignals } from "./signal_engine.js";
import { upsertSignals } from "../lib/signal_store.js";
import { initMemory, storeMemory, recallMemory, listMemories } from "../lib/agent_memory.js";
import { fetchNewsHeadlines, formatNewsForPrompt } from "../lib/news_feed.js";
import { ZODIAC_SIGNS } from "../lib/constants.js";
import { getPanchanga, getNakshatra, getNakshatraMundane } from "../lib/vedic_utils.js";

// =============================================================================
// MUNDANE HOUSES — What each house governs in world astrology
// =============================================================================

const MUNDANE_HOUSES = {
    1:  { name: "Lagna",       domain: "Nation's general condition, public mood, national identity, health of the people" },
    2:  { name: "Dhana",       domain: "National wealth, economy, treasury, revenue, trade, banking, agriculture produce" },
    3:  { name: "Sahaja",      domain: "Communications, media, neighbors, transport, telecommunications, courage of the nation" },
    4:  { name: "Sukha",       domain: "Land, agriculture, weather, mining, opposition party, homeland, mother of the nation" },
    5:  { name: "Putra",       domain: "Diplomacy, ambassadors, speculation, entertainment, children, creativity, education" },
    6:  { name: "Ripu",        domain: "Armed forces, public health, disease, labor, service sector, enemies, debts" },
    7:  { name: "Kalatra",     domain: "Foreign affairs, treaties, alliances, open enemies, war & peace, international trade" },
    8:  { name: "Mrityu",      domain: "Death toll, national crises, debt, insurance, secret intelligence, occult, earthquakes" },
    9:  { name: "Dharma",      domain: "Judiciary, religion, higher education, long-distance travel, philosophy, dharma" },
    10: { name: "Karma",       domain: "Government, head of state, ruling party, national reputation, executive authority" },
    11: { name: "Labha",       domain: "Parliament, legislature, allies, technology, social movements, national aspirations" },
    12: { name: "Vyaya",       domain: "Losses, espionage, prisons, hospitals, foreign exile, hidden enemies, spirituality" },
};

// =============================================================================
// SYSTEM PROMPT
// =============================================================================

const SYSTEM_PROMPT = `You are a Vedic mundane astrologer (Medini Jyotish) analyzing world events through the Navagraha — Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn, Rahu, and Ketu. No outer planets.

## Your Vedic Framework
- Sidereal zodiac with Lahiri ayanamsha (already applied in data)
- Whole-sign houses from Aries = House 1 (Kalpurush Kundli for mundane)
- Nakshatras matter: Moon's nakshatra colors the day's emotional tone. Slow planet nakshatras mark era themes.
- Vedic special aspects: Mars aspects 4th & 8th from itself, Jupiter aspects 5th & 9th, Saturn aspects 3rd & 10th — these are FULL-STRENGTH aspects, as strong as conjunction
- Slow grahas (Jupiter, Saturn, Rahu, Ketu) set world-level themes over months
- Fast grahas (Moon, Mercury, Venus, Sun) trigger events when they contact slow graha configurations
- Combustion weakens a planet's significations. Retrograde intensifies and internalizes.
- Panchanga: Tithi shows the lunar phase energy. Nakshatra shows the daily quality.

## Prediction Methodology — SKY FIRST
1. Read the sky INDEPENDENTLY of news. What domains does the current configuration activate? What is forming or perfecting? What is separating?
2. Look at UPCOMING transits (provided). What will activate in the coming days/weeks? This is your predictive edge — seeing what hasn't happened yet.
3. THEN read the news. Which current events align with the sky's indications? Which events will intensify or resolve based on upcoming transits?
4. Make predictions about what WILL happen — events NOT YET in the news. The sky suggests the TYPE of event; the news suggests WHERE it might manifest.

## Prediction Rules
1. At least 2 of your predictions MUST be about events NOT currently in the headlines
2. Every prediction needs a CHECK DATE — the specific date by which it should be verifiable
3. Be FALSIFIABLE — if your prediction can never be proven wrong, it's useless. Not "markets may be volatile" but "crude oil crosses $85/barrel within 10 days as Mars-Saturn conjunction perfects"
4. Cite the specific graha configuration and its Vedic mundane signification
5. When you update past predictions, be HONEST. Mark as "missed" if the timeframe passed without the event.

## Memory
You have memories from previous runs. USE THEM. Reference your past observations. Check pending predictions against today's news. Your value comes from continuity.

## Output Format
Return ONLY valid JSON:
{
  "worldEnergy": "1-2 paragraphs on current global energy from the sky",
  "predictions": [
    {
      "claim": "specific, falsifiable prediction",
      "timeframe": "by YYYY-MM-DD",
      "confidence": 0.0-1.0,
      "basedOn": "specific graha configuration + Vedic reasoning",
      "domains": ["mundane domain 1", "mundane domain 2"]
    }
  ],
  "predictionUpdates": [
    {
      "originalClaim": "the prediction from memory",
      "status": "confirmed|developing|missed|too_early",
      "evidence": "what specifically in the news supports or contradicts this"
    }
  ],
  "houses": {
    "1": { "reading": "2-3 sentences connecting current transits to this bhava" },
    ...all 12 houses
  },
  "observations": "What you noticed today worth remembering: patterns, correlations, things to watch"
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
    initMemory(geminiApiKeyValue);

    // ── Step 1: Recall memories ─────────────────────────────────────────
    const [recentObservations, recentPredictions, relevantPatterns] = await Promise.all([
        listMemories("observations", 7),       // Last 7 daily observations
        listMemories("predictions", 15),        // Recent predictions (may be pending)
        recallMemory("current major world events planetary patterns", {
            namespace: "patterns",
            topK: 5,
            minSimilarity: 0.2,
        }),
    ]);

    // ── Step 2: Extract sky signals ─────────────────────────────────────
    const skyData = await loadSkyAndExtractSignals(dateStr);

    // ── Step 3: Fetch news ──────────────────────────────────────────────
    const headlines = await fetchNewsHeadlines({ limit: 20 });
    const newsText = formatNewsForPrompt(headlines);

    // ── Step 4: Build prompt and call Gemini ────────────────────────────
    const userPrompt = buildPrompt(dateStr, skyData, newsText, recentObservations, recentPredictions, relevantPatterns);

    const genAI = new GoogleGenerativeAI(geminiApiKeyValue);
    const model = genAI.getGenerativeModel({
        model: AI_MODELS?.GEMINI_FLASH || "gemini-2.0-flash",
        systemInstruction: SYSTEM_PROMPT,
        generationConfig: {
            temperature: 0.4,
            maxOutputTokens: 8192,
            responseMimeType: "application/json",
        },
    });

    const result = await model.generateContent(userPrompt);
    const responseText = result.response.text();

    let output;
    try {
        output = JSON.parse(responseText);
    } catch {
        logger.error("Failed to parse Gemini JSON response", {
            structuredData: true,
            responsePreview: responseText.substring(0, 500),
        });
        throw new Error("Gemini returned invalid JSON");
    }

    // ── Step 5: Enrich output with signal + house metadata ──────────────
    const enrichedOutput = enrichOutput(output, dateStr, skyData);

    // ── Step 6: Store in Firestore ──────────────────────────────────────
    await db.collection("cosmic_daily_output").doc(dateStr).set({
        ...enrichedOutput,
        generatedAt: new Date(),
        wallTimeMs: Date.now() - startTime,
    });

    // ── Step 7: Store memories for future runs ──────────────────────────
    await storeNewMemories(dateStr, enrichedOutput, skyData, headlines);

    const wallTime = Date.now() - startTime;
    logger.info("Cosmic daily completed", {
        structuredData: true,
        date: dateStr,
        wallTimeMs: wallTime,
        predictionsCount: enrichedOutput.predictions?.length || 0,
        newsCount: headlines.length,
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

    // Persist signals
    await upsertSignals(signals);

    return { signals, topSignals, diff, positions: todayPos, panchanga, upcoming };
}

import { scanUpcomingTransits } from "../lib/upcoming_transits.js";

// =============================================================================
// PROMPT BUILDING
// =============================================================================

function buildPrompt(dateStr, skyData, newsText, observations, predictions, patterns) {
    const sections = [];

    sections.push(`# Cosmic Intelligence Report — ${dateStr}\n`);

    // ── SECTION 1: PANCHANGA (Vedic daily quality) ───────────────────────
    if (skyData.panchanga) {
        const p = skyData.panchanga;
        sections.push("## Panchanga (Five Limbs of the Day)");
        sections.push(`  Vara: ${p.vara.name} (lord: ${p.vara.lord})`);
        sections.push(`  Tithi: ${p.tithi.name} (${p.tithi.paksha} Paksha, #${p.tithi.index}) — ${p.lunarPhase}`);
        sections.push(`  Moon Nakshatra: ${p.nakshatra.name} (pada ${p.nakshatra.pada}, lord: ${p.nakshatra.lord})`);
        const moonMundane = getNakshatraMundane(p.nakshatra.name);
        if (moonMundane) sections.push(`    → Mundane theme: ${moonMundane}`);
        sections.push(`  Yoga: ${p.yoga.name}`);
        sections.push("");
    }

    // ── SECTION 2: PLANET POSITIONS WITH NAKSHATRAS ──────────────────────
    if (skyData.positions) {
        sections.push("## Graha Positions (Sidereal, Lahiri)");
        for (const [planet, data] of Object.entries(skyData.positions)) {
            if (data?.longitude == null) continue;
            const sign = ZODIAC_SIGNS[Math.floor(data.longitude / 30)];
            const deg = (data.longitude % 30).toFixed(1);
            const retro = data.isRetro ? " (R)" : "";
            const house = Math.floor(data.longitude / 30) + 1;
            const nak = getNakshatra(data.longitude);
            sections.push(`  ${planet}: ${deg}° ${sign} (H${house}) — ${nak.name} P${nak.pada}${retro}`);
        }
        sections.push("");
    }

    // ── SECTION 3: TODAY'S ACTIVE SIGNALS ────────────────────────────────
    sections.push("## Active Sky Signals (ranked by intensity)");
    if (skyData.topSignals.length > 0) {
        for (const s of skyData.topSignals) {
            const applying = s.applying === true ? " APPLYING" : s.applying === false ? " separating" : "";
            const orb = s.orb != null ? ` (orb: ${s.orb}°)` : "";
            sections.push(`- [★${s.intensity}/10] ${s.type}: ${s.planets.join(" + ")} ${s.aspect || s.dignity || s.stationType || ""}${orb}${applying}`);
            sections.push(`    Domains: ${(s.domains || []).slice(0, 5).join(", ")}`);
        }
    } else {
        sections.push("No signals extracted (sky positions may not be available).");
    }

    if (skyData.diff) {
        sections.push(`\nChanges from yesterday: ${skyData.diff.summary}`);
    }
    sections.push("");

    // ── SECTION 4: UPCOMING TRANSITS (next 14 days) ─────────────────────
    if (skyData.upcoming?.length > 0) {
        sections.push("## ⚠️ Upcoming Transits (Next 14 Days) — YOUR PREDICTIVE EDGE");
        sections.push("These events HAVEN'T happened yet. Use them to predict what's COMING.\n");
        for (const evt of skyData.upcoming) {
            if (evt.type === "aspect_perfection") {
                sections.push(`- [${evt.date}, ${evt.daysAway}d away] ${evt.planet1}-${evt.planet2} ${evt.aspect} PERFECTS (orb: ${evt.orb}°)`);
            } else if (evt.type === "ingress") {
                sections.push(`- [${evt.date}, ${evt.daysAway}d away] ${evt.planet} enters ${evt.toSign} (from ${evt.fromSign})`);
            } else if (evt.type === "station") {
                sections.push(`- [${evt.date}, ${evt.daysAway}d away] ${evt.planet} goes ${evt.stationType} in ${evt.sign}`);
            }
        }
        sections.push("");
    }

    // ── SECTION 5: MUNDANE HOUSE REFERENCE ───────────────────────────────
    sections.push("## Mundane Bhava Domains (Kalpurush Kundli)");
    for (const [num, info] of Object.entries(MUNDANE_HOUSES)) {
        sections.push(`  H${num} ${info.name}: ${info.domain}`);
    }
    sections.push("");

    // ── SECTION 6: YOUR MEMORIES ─────────────────────────────────────────
    if (observations.length > 0 || predictions.length > 0 || patterns.length > 0) {
        sections.push("## Your Memory\n");

        if (observations.length > 0) {
            sections.push("### Recent Observations");
            for (const obs of observations) {
                const date = obs.createdAt ? new Date(obs.createdAt).toISOString().split("T")[0] : "?";
                sections.push(`[${date}] ${obs.content}`);
            }
            sections.push("");
        }

        if (predictions.length > 0) {
            sections.push("### Pending Predictions (CHECK these against today's news!)");
            for (const pred of predictions) {
                sections.push(`- ${pred.content}`);
            }
            sections.push("");
        }

        if (patterns.length > 0) {
            sections.push("### Known Patterns");
            for (const pat of patterns) {
                sections.push(`- ${pat.content}`);
            }
            sections.push("");
        }
    }

    // ── SECTION 7: NEWS (last, intentionally) ───────────────────────────
    sections.push("## Today's World News Headlines");
    sections.push("(Read AFTER analyzing the sky. Use news to ground sky-based predictions in current storylines.)\n");
    sections.push(newsText);

    // ── TASK ─────────────────────────────────────────────────────────────
    sections.push("\n## Your Task");
    sections.push("1. Analyze the sky FIRST. What domains are activated? What's forming vs separating?");
    sections.push("2. Study the UPCOMING transits. What will intensify or shift in the next 1-2 weeks?");
    sections.push("3. Cross-reference with news. Which current events align with the sky's trajectory?");
    sections.push("4. Make 5-8 predictions. At least 2 must be about events NOT in today's headlines.");
    sections.push("5. Check your pending predictions against today's news. Be honest about misses.");
    sections.push("\nGenerate your complete daily output as JSON.");

    return sections.join("\n");
}

// =============================================================================
// OUTPUT ENRICHMENT
// =============================================================================

function enrichOutput(output, dateStr, skyData) {
    // Add house metadata (sign, planets, mundane domain)
    const houses = {};
    for (let h = 1; h <= 12; h++) {
        const signIndex = (h - 1) % 12; // natural zodiac: H1=Aries, H2=Taurus, etc.
        const sign = ZODIAC_SIGNS[signIndex];
        const mundane = MUNDANE_HOUSES[h];

        // Find planets in this house
        const planetsInHouse = [];
        if (skyData.positions) {
            for (const [planet, data] of Object.entries(skyData.positions)) {
                if (!data?.longitude && data?.longitude !== 0) continue;
                const planetHouse = Math.floor(data.longitude / 30) + 1;
                if (planetHouse === h) {
                    planetsInHouse.push({
                        planet,
                        degree: +(data.longitude % 30).toFixed(1),
                        isRetro: !!data.isRetro,
                    });
                }
            }
        }

        houses[h] = {
            sign,
            name: mundane.name,
            domain: mundane.domain,
            planets: planetsInHouse,
            reading: output.houses?.[String(h)]?.reading || "",
        };
    }

    return {
        date: dateStr,
        worldEnergy: output.worldEnergy || "",
        predictions: output.predictions || [],
        predictionUpdates: output.predictionUpdates || [],
        houses,
        observations: output.observations || "",
        panchanga: skyData.panchanga || null,
        upcomingTransits: (skyData.upcoming || []).slice(0, 10),
        signalsSummary: skyData.topSignals.slice(0, 8).map(s => ({
            id: s.id, type: s.type, planets: s.planets,
            aspect: s.aspect, dignity: s.dignity,
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
        .map(s => `${s.planets.join("-")} ${s.aspect || s.dignity || ""} (${s.intensity}/10)`)
        .join(", ");
    const topHeadlines = headlines.slice(0, 5).map(h => h.title).join("; ");

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

export const cosmicDailyScheduled = onSchedule(
    {
        schedule: "30 2 * * *",  // 2:30 AM UTC daily
        timeZone: "UTC",
        timeoutSeconds: 120,
        memory: "512MiB",
        region: "us-central1",
        secrets: [geminiApiKey],
        retryCount: 1,
    },
    async () => {
        const today = new Date().toISOString().split("T")[0];
        await generateDailyOutput(geminiApiKey.value(), today);
    }
);

export const cosmicDailyManual = onCall(
    {
        timeoutSeconds: 120,
        memory: "512MiB",
        region: "us-central1",
        secrets: [geminiApiKey],
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Authentication required");
        }

        const dateStr = request.data?.date || new Date().toISOString().split("T")[0];
        const output = await generateDailyOutput(geminiApiKey.value(), dateStr);

        return {
            success: true,
            date: dateStr,
            predictionsCount: output.predictions?.length || 0,
            worldEnergy: output.worldEnergy?.substring(0, 500),
        };
    }
);
