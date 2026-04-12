/**
 * Agent Tools — Cosmic Intelligence Agent (Phase 3)
 *
 * All tools the agent can call during its reasoning loop.
 * Defined as Gemini Function Calling declarations + executor functions.
 *
 * No LangChain dependency — uses @google/generative-ai directly.
 *
 * Tools:
 *   1. calculate_sky     — Extract signals from sky positions (Phase 1)
 *   2. search_web        — Search the web via Tavily ($0.003/call)
 *   3. recall_memory     — Search agent's memory (semantic)
 *   4. store_memory      — Store a new memory
 *   5. read_signals      — Read active signals from Firestore
 *   6. read_predictions  — Read pending predictions
 *   7. write_prediction  — Store a new prediction
 *   8. validate_prediction — Validate an old prediction
 *   9. get_confidence    — Get historical accuracy for a pattern
 *  10. search_news       — Search recent news for specific topics
 */

import { extractSignals, diffSky, getTopSignals } from "./signal_engine.js";
import { initMemory, storeMemory, recallMemory } from "../lib/agent_memory.js";
import {
    getActiveSignals,
    getPendingPredictions,
    getRecentPredictions,
    storePrediction,
    validatePrediction,
    getConfidence,
} from "../lib/signal_store.js";
import { db } from "../lib/firebase.js";

// =============================================================================
// TOOL STATE — initialized at runtime
// =============================================================================

let tavilyApiKey = null;
let searchCallCount = 0;
let maxSearchCalls = 20;

/**
 * Initialize tools with API keys. Must be called before agent runs.
 */
export function initTools({ tavilyApiKeyValue, geminiApiKeyValue, searchBudget = 20 }) {
    tavilyApiKey = tavilyApiKeyValue;
    initMemory(geminiApiKeyValue);
    searchCallCount = 0;
    maxSearchCalls = searchBudget;
}

/**
 * Call Tavily API directly via fetch (no npm package needed).
 * @param {string} query - Search query
 * @param {Object} options - { topic, days, maxResults, includeAnswer }
 * @returns {Object} Tavily API response
 */
async function tavilySearch(query, options = {}) {
    const response = await fetch("https://api.tavily.com/search", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            api_key: tavilyApiKey,
            query,
            topic: options.topic || "news",
            days: options.days || 7,
            max_results: options.maxResults || 5,
            include_answer: options.includeAnswer !== false,
        }),
    });

    if (!response.ok) {
        throw new Error(`Tavily API error: ${response.status} ${response.statusText}`);
    }

    return response.json();
}

/**
 * Get current search call count for budget monitoring.
 */
export function getSearchCallCount() {
    return searchCallCount;
}

// =============================================================================
// TOOL EXECUTORS — async functions that implement each tool
// =============================================================================

async function executeCalculateSky({ date }) {
    try {
        const skyDoc = await db.collection("global_astro").doc("sky_positions").get();
        if (!skyDoc.exists) {
            return { error: "No sky positions data found in Firestore" };
        }
        const positions = skyDoc.data()?.positions || {};
        const positionsToday = positions[date];
        if (!positionsToday) {
            return { error: `No positions found for date ${date}`, availableDates: Object.keys(positions).slice(-5) };
        }

        const sortedDates = Object.keys(positions).sort();
        const todayIdx = sortedDates.indexOf(date);
        const positionsYesterday = todayIdx > 0 ? positions[sortedDates[todayIdx - 1]] : null;

        const signals = extractSignals(positionsToday, positionsYesterday, date);
        const diff = positionsYesterday
            ? diffSky(positionsToday, positionsYesterday, date)
            : null;
        const top = getTopSignals(signals, 10);

        return {
            date,
            totalSignals: signals.length,
            topSignals: top.map(s => ({
                id: s.id, type: s.type, planets: s.planets,
                aspect: s.aspect, dignity: s.dignity, stationType: s.stationType,
                orb: s.orb, applying: s.applying, intensity: s.intensity,
                status: s.status, domains: s.domains,
            })),
            diff: diff ? {
                summary: diff.summary,
                stats: diff.stats,
                newSignals: diff.newSignals.slice(0, 5).map(s => ({
                    id: s.id, type: s.type, planets: s.planets,
                    aspect: s.aspect, intensity: s.intensity,
                })),
            } : null,
        };
    } catch (error) {
        return { error: `Failed to calculate sky: ${String(error)}` };
    }
}

async function executeSearchWeb({ query, topic, days, maxResults }) {
    if (searchCallCount >= maxSearchCalls) {
        return { error: "Search budget exhausted", remaining: 0, budget: maxSearchCalls };
    }
    if (!tavilyApiKey) {
        return { error: "Tavily API key not initialized" };
    }

    searchCallCount++;
    try {
        const response = await tavilySearch(query, {
            topic: topic || "news",
            days: days || 7,
            maxResults: maxResults || 5,
            includeAnswer: true,
        });

        return {
            answer: response.answer,
            results: (response.results || []).map(r => ({
                title: r.title, url: r.url,
                content: r.content?.substring(0, 500),
                publishedDate: r.publishedDate || r.published_date,
                score: r.score,
            })),
            searchesRemaining: maxSearchCalls - searchCallCount,
        };
    } catch (error) {
        searchCallCount--;
        return { error: String(error) };
    }
}

async function executeRecallMemory({ query, namespace, tags, maxResults }) {
    const results = await recallMemory(query, {
        namespace: namespace || null,
        tags: tags || [],
        topK: maxResults || 10,
        minSimilarity: 0.3,
    });

    return {
        count: results.length,
        memories: results.map(m => ({
            id: m.id, content: m.content, namespace: m.namespace,
            tags: m.tags, similarity: m.similarity,
            createdAt: m.createdAt, metadata: m.metadata,
        })),
    };
}

async function executeStoreMemory({ content, namespace, tags, metadata }) {
    const id = await storeMemory(content, {
        namespace,
        tags: tags || [],
        metadata: metadata || {},
    });
    return { success: true, memoryId: id };
}

async function executeReadSignals({ type, status, minIntensity, limit }) {
    const signals = await getActiveSignals({
        type: type || undefined,
        status: status || undefined,
        minIntensity: minIntensity || undefined,
        limit: limit || 30,
    });

    return {
        count: signals.length,
        signals: signals.map(s => ({
            id: s.id, type: s.type, planets: s.planets,
            aspect: s.aspect, dignity: s.dignity, orb: s.orb,
            intensity: s.intensity, status: s.status,
            domains: s.domains, date: s.date,
        })),
    };
}

async function executeReadPredictions({ status, beforeDate, limit }) {
    let predictions;
    if (status === "pending") {
        predictions = await getPendingPredictions(beforeDate, limit || 20);
    } else {
        predictions = await getRecentPredictions(limit || 20);
        if (status) {
            predictions = predictions.filter(p => p.status === status);
        }
    }

    return {
        count: predictions.length,
        predictions: predictions.map(p => ({
            id: p.id, claim: p.claim, confidence: p.confidence,
            domains: p.domains, signalId: p.signalId, status: p.status,
            brierScore: p.brierScore, searchKeywords: p.searchKeywords,
            resolvesBy: p.resolvesBy, createdAt: p.createdAt,
        })),
    };
}

async function executeWritePrediction({ claim, domains, confidence, signalId, searchKeywords, resolvesBy, reasoning }) {
    const predictionId = await storePrediction({
        claim, domains, confidence, signalId,
        searchKeywords, resolvesBy, reasoning,
    });
    return { success: true, predictionId };
}

async function executeValidatePrediction({ predictionId, outcome, evidence, actualOutcome }) {
    const result = await validatePrediction(predictionId, {
        outcome, evidence, actualOutcome,
    });
    return {
        success: true, predictionId,
        brierScore: result.brierScore, outcome: result.outcome,
    };
}

async function executeGetConfidence({ patternKey }) {
    const conf = await getConfidence(patternKey);
    if (!conf) {
        return {
            found: false, patternKey,
            message: "No history for this pattern. You have no basis for confidence.",
        };
    }
    return {
        found: true, patternKey,
        totalInstances: conf.totalInstances,
        confirmedInstances: conf.confirmedInstances,
        currentConfidence: conf.currentConfidence,
        brierScoreAvg: conf.brierScoreAvg,
        recentHistory: (conf.history || []).slice(-5),
    };
}

async function executeSearchNews({ query, days }) {
    if (searchCallCount >= maxSearchCalls) {
        return { error: "Search budget exhausted", remaining: 0 };
    }
    if (!tavilyApiKey) {
        return { error: "Tavily API key not initialized" };
    }

    searchCallCount++;
    try {
        const response = await tavilySearch(query, {
            topic: "news",
            days: days || 3,
            maxResults: 5,
            includeAnswer: true,
        });

        return {
            answer: response.answer,
            headlines: (response.results || []).map(r => ({
                title: r.title, url: r.url,
                snippet: r.content?.substring(0, 300),
                date: r.publishedDate || r.published_date,
            })),
            searchesRemaining: maxSearchCalls - searchCallCount,
        };
    } catch (error) {
        searchCallCount--;
        return { error: String(error) };
    }
}

// =============================================================================
// TOOL DISPATCH MAP — name → executor
// =============================================================================

export const TOOL_EXECUTORS = {
    calculate_sky: executeCalculateSky,
    search_web: executeSearchWeb,
    recall_memory: executeRecallMemory,
    store_memory: executeStoreMemory,
    read_signals: executeReadSignals,
    read_predictions: executeReadPredictions,
    write_prediction: executeWritePrediction,
    validate_prediction: executeValidatePrediction,
    get_confidence: executeGetConfidence,
    search_news: executeSearchNews,
};

// =============================================================================
// GEMINI FUNCTION DECLARATIONS — Schema for Gemini function calling
// =============================================================================

export const GEMINI_TOOL_DECLARATIONS = [
    {
        name: "calculate_sky",
        description: "Extract astrological signals from sky positions for a given date. Loads positions automatically from the database. Returns active aspects, dignity shifts, ingresses, and what changed since yesterday.",
        parameters: {
            type: "object",
            properties: {
                date: { type: "string", description: "Date in yyyy-MM-dd format (e.g., '2026-04-12')" },
            },
            required: ["date"],
        },
    },
    {
        name: "search_web",
        description: "Search the web for current events, news, and information. Use to ground astrological signals in real-world context. Budget: limited per run.",
        parameters: {
            type: "object",
            properties: {
                query: { type: "string", description: "Search query — be specific" },
                topic: { type: "string", enum: ["news", "general"], description: "Search type" },
                days: { type: "number", description: "How far back to search (1-30, default 7)" },
                maxResults: { type: "number", description: "Max results (default 5)" },
            },
            required: ["query"],
        },
    },
    {
        name: "recall_memory",
        description: "Search your memory for past observations, research findings, reflections, and patterns. ALWAYS use this before researching something.",
        parameters: {
            type: "object",
            properties: {
                query: { type: "string", description: "What to search for in memory" },
                namespace: { type: "string", enum: ["observations", "predictions", "reflections", "research", "patterns"], description: "Filter by memory type" },
                tags: { type: "array", items: { type: "string" }, description: "Filter by tags" },
                maxResults: { type: "number", description: "Max results (default 10)" },
            },
            required: ["query"],
        },
    },
    {
        name: "store_memory",
        description: "Store an observation, finding, or reflection in memory for future recall.",
        parameters: {
            type: "object",
            properties: {
                content: { type: "string", description: "The memory content" },
                namespace: { type: "string", enum: ["observations", "predictions", "reflections", "research", "patterns"], description: "Type of memory" },
                tags: { type: "array", items: { type: "string" }, description: "Tags for filtering" },
                metadata: { type: "object", description: "Additional structured metadata" },
            },
            required: ["content", "namespace"],
        },
    },
    {
        name: "read_signals",
        description: "Read active astrological signals from the database.",
        parameters: {
            type: "object",
            properties: {
                type: { type: "string", description: "Filter by type: aspect, ingress, station, dignity, eclipse, combustion, speed" },
                status: { type: "string", description: "Filter by status: forming, active, peaked, fading" },
                minIntensity: { type: "number", description: "Minimum intensity (1-10)" },
                limit: { type: "number", description: "Max results (default 30)" },
            },
        },
    },
    {
        name: "read_predictions",
        description: "Read predictions from the database. Use to find pending predictions that need validation.",
        parameters: {
            type: "object",
            properties: {
                status: { type: "string", enum: ["pending", "confirmed", "unconfirmed", "ambiguous"], description: "Filter by status" },
                beforeDate: { type: "string", description: "For pending: only predictions due before this date" },
                limit: { type: "number", description: "Max results (default 20)" },
            },
        },
    },
    {
        name: "write_prediction",
        description: "Record a prediction about the future. Include confidence (0-1), domains, and keywords for later validation.",
        parameters: {
            type: "object",
            properties: {
                claim: { type: "string", description: "The prediction claim — specific and time-bound" },
                domains: { type: "array", items: { type: "string" }, description: "Affected domains" },
                confidence: { type: "number", description: "Confidence level 0-1" },
                signalId: { type: "string", description: "The signal ID this prediction is based on" },
                searchKeywords: { type: "array", items: { type: "string" }, description: "Keywords for later validation" },
                resolvesBy: { type: "string", description: "Date by which this should be checkable (yyyy-MM-dd)" },
                reasoning: { type: "string", description: "Why you're making this prediction" },
            },
            required: ["claim", "domains", "confidence", "signalId", "searchKeywords", "resolvesBy"],
        },
    },
    {
        name: "validate_prediction",
        description: "Validate a past prediction against evidence. Be honest — score accurately even if wrong.",
        parameters: {
            type: "object",
            properties: {
                predictionId: { type: "string", description: "ID of the prediction to validate" },
                outcome: { type: "string", enum: ["confirmed", "unconfirmed", "ambiguous"], description: "Did it happen?" },
                evidence: { type: "string", description: "Evidence supporting this outcome" },
                actualOutcome: { type: "number", description: "Binary outcome for Brier: 1=happened, 0=didn't, 0.5=ambiguous" },
            },
            required: ["predictionId", "outcome", "evidence", "actualOutcome"],
        },
    },
    {
        name: "get_confidence",
        description: "Check your historical accuracy for a specific signal pattern. Use BEFORE making predictions to calibrate.",
        parameters: {
            type: "object",
            properties: {
                patternKey: { type: "string", description: "Signal pattern key, e.g., 'mars-saturn-square'" },
            },
            required: ["patternKey"],
        },
    },
    {
        name: "search_news",
        description: "Search recent news headlines. Use for validating predictions or grounding signals in current events.",
        parameters: {
            type: "object",
            properties: {
                query: { type: "string", description: "News search query — be specific" },
                days: { type: "number", description: "How many days back (default 3)" },
            },
            required: ["query"],
        },
    },
];
