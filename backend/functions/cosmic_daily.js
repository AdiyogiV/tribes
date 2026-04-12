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

// =============================================================================
// MUNDANE HOUSES — What each house governs in world astrology
// =============================================================================

const MUNDANE_HOUSES = {
    1: { name: "World State", domain: "General conditions, public mood, national identity" },
    2: { name: "Economy", domain: "Markets, wealth, resources, trade, banking" },
    3: { name: "Communications", domain: "Media, journalism, transport, neighboring relations" },
    4: { name: "Land & People", domain: "Agriculture, weather, housing, opposition, homeland" },
    5: { name: "Diplomacy", domain: "Speculation, entertainment, children, ambassadors, creativity" },
    6: { name: "Health & Military", domain: "Public health, armed forces, labor, service, disease" },
    7: { name: "Foreign Affairs", domain: "Treaties, alliances, open enemies, war, partnerships" },
    8: { name: "Crises", domain: "Death, transformation, debt, insurance, mass casualties, secrets" },
    9: { name: "Law & Religion", domain: "Courts, religion, higher education, long-distance travel, philosophy" },
    10: { name: "Government", domain: "Leadership, authority, heads of state, reputation, executive power" },
    11: { name: "Parliament & Tech", domain: "Legislature, allies, technology, social movements, aspirations" },
    12: { name: "Hidden Forces", domain: "Espionage, prisons, pandemics, hidden enemies, spirituality, exile" },
};

// =============================================================================
// SYSTEM PROMPT
// =============================================================================

const SYSTEM_PROMPT = `You are a Vedic mundane astrologer with a growing memory. You observe the sky daily, track world events, and make concrete predictions about what happens next in the world.

## Your Framework
- Vedic/sidereal astrology with Lahiri ayanamsha (already applied in data)
- Whole-sign houses from Aries = House 1 (natural zodiac for mundane)
- Slow planets (Jupiter, Saturn, Rahu, Ketu) drive world events
- Fast planets (Moon, Mercury) are triggers, not causes
- Aspects: conjunction, opposition, trine, square, sextile + Vedic special aspects

## Your Memory
You have memories from previous runs. USE THEM. If you predicted something before, check if the news confirms or contradicts it. If you noticed a pattern before, reference it. Your value comes from continuity — seeing the same sky over time and learning what configurations actually produce.

## Rules
1. Be SPECIFIC. Not "tension may increase" but "India-Pakistan border tension likely to escalate given Mars-Saturn square + active LOC incidents"
2. Be TIME-BOUND. Every prediction needs a timeframe: days, weeks, or months
3. Be HONEST. If you have no basis for a prediction, say so. Don't fabricate correlations
4. CONNECT sky to news. The sky shows tendencies. The news shows what's already in motion. Your job is to project where current events go based on upcoming planetary configurations
5. Each house reading should be 2-3 sentences connecting current transits to that house's mundane domain

## Output Format
Return ONLY valid JSON with this exact structure:
{
  "worldEnergy": "1-2 paragraphs describing the current global energy landscape",
  "predictions": [
    {
      "claim": "specific prediction",
      "timeframe": "days/weeks/months",
      "confidence": 0.0-1.0,
      "basedOn": "which signal + which context",
      "domains": ["domain1", "domain2"]
    }
  ],
  "predictionUpdates": [
    {
      "originalClaim": "the prediction from memory",
      "status": "confirmed|developing|missed|too_early",
      "evidence": "what in the news supports this assessment"
    }
  ],
  "houses": {
    "1": { "reading": "2-3 sentences" },
    "2": { "reading": "2-3 sentences" },
    ...all 12 houses
  },
  "observations": "What you noticed today that's worth remembering for future runs"
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
        return { signals: [], topSignals: [], diff: null, positions: null };
    }

    const positions = skyDoc.data()?.positions || {};
    const todayPos = positions[dateStr];
    if (!todayPos) {
        return { signals: [], topSignals: [], diff: null, positions: null };
    }

    const sortedDates = Object.keys(positions).sort();
    const todayIdx = sortedDates.indexOf(dateStr);
    const yesterdayPos = todayIdx > 0 ? positions[sortedDates[todayIdx - 1]] : null;

    const signals = extractSignals(todayPos, yesterdayPos, dateStr);
    const diff = yesterdayPos ? diffSky(todayPos, yesterdayPos, dateStr) : null;
    const topSignals = getTopSignals(signals, 15);

    // Persist signals
    await upsertSignals(signals);

    return { signals, topSignals, diff, positions: todayPos };
}

// =============================================================================
// PROMPT BUILDING
// =============================================================================

function buildPrompt(dateStr, skyData, newsText, observations, predictions, patterns) {
    const sections = [];

    sections.push(`# Date: ${dateStr}\n`);

    // Memory: recent observations
    if (observations.length > 0) {
        sections.push("## Your Recent Observations (from memory)");
        for (const obs of observations) {
            const date = obs.createdAt ? new Date(obs.createdAt).toISOString().split("T")[0] : "unknown";
            sections.push(`[${date}] ${obs.content}`);
        }
        sections.push("");
    }

    // Memory: pending predictions
    if (predictions.length > 0) {
        sections.push("## Your Pending Predictions (check against today's news)");
        for (const pred of predictions) {
            sections.push(`- ${pred.content}`);
        }
        sections.push("");
    }

    // Memory: patterns
    if (patterns.length > 0) {
        sections.push("## Your Known Patterns");
        for (const pat of patterns) {
            sections.push(`- ${pat.content} (similarity: ${pat.similarity})`);
        }
        sections.push("");
    }

    // Sky signals
    sections.push("## Today's Sky Signals");
    if (skyData.topSignals.length > 0) {
        for (const s of skyData.topSignals) {
            const applying = s.applying === true ? " APPLYING" : s.applying === false ? " separating" : "";
            const orb = s.orb != null ? ` (${s.orb}°)` : "";
            sections.push(`- [${s.intensity}/10] ${s.type}: ${s.planets.join(" + ")} ${s.aspect || s.dignity || s.stationType || ""}${orb}${applying} → ${(s.domains || []).slice(0, 4).join(", ")}`);
        }
    } else {
        sections.push("No signals extracted (sky positions may not be available).");
    }

    if (skyData.diff) {
        sections.push(`\nChanges: ${skyData.diff.summary}`);
    }

    // Planet positions summary for house placement
    if (skyData.positions) {
        sections.push("\n## Planet Positions (sidereal)");
        for (const [planet, data] of Object.entries(skyData.positions)) {
            if (!data?.longitude && data?.longitude !== 0) continue;
            const sign = ZODIAC_SIGNS[Math.floor(data.longitude / 30)];
            const deg = (data.longitude % 30).toFixed(1);
            const retro = data.isRetro ? " (R)" : "";
            const house = Math.floor(data.longitude / 30) + 1; // natural zodiac house
            sections.push(`  ${planet}: ${deg}° ${sign} (H${house})${retro}`);
        }
    }

    // House domains reference
    sections.push("\n## Mundane House Domains");
    for (const [num, info] of Object.entries(MUNDANE_HOUSES)) {
        sections.push(`  H${num} ${info.name}: ${info.domain}`);
    }

    // News
    sections.push("\n## Today's World News Headlines");
    sections.push(newsText);

    // Instruction
    sections.push("\n## Your Task");
    sections.push("Analyze the sky signals in context of the news and your memories. Generate your complete daily output as JSON.");

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

    // Store each new prediction
    if (output.predictions?.length) {
        for (const pred of output.predictions) {
            const predContent = `[${dateStr}] Prediction: ${pred.claim}. Timeframe: ${pred.timeframe}. Confidence: ${pred.confidence}. Based on: ${pred.basedOn}. Domains: ${(pred.domains || []).join(", ")}`;
            tasks.push(storeMemory(predContent, {
                namespace: "predictions",
                tags: pred.domains || [],
                metadata: { date: dateStr, confidence: pred.confidence, timeframe: pred.timeframe },
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
