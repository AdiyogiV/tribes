/**
 * Cosmic Intelligence Agent — Gemini ReAct Agent (Phase 4)
 *
 * The core agent that:
 * 1. Recalls past memories
 * 2. Observes today's sky
 * 3. Reasons about what signals mean
 * 4. Researches via web search
 * 5. Makes predictions
 * 6. Validates old predictions
 * 7. Reflects and stores learnings
 *
 * Architecture: Manual ReAct loop using @google/generative-ai with function calling.
 * Model: Gemini 2.0 Flash (cheapest, fastest, already in use)
 * No LangChain dependency — direct Gemini SDK.
 */

import { GoogleGenerativeAI } from "@google/generative-ai";

import { COSMIC_AGENT_SYSTEM_PROMPT, getRunContext } from "./prompts/cosmic_agent.js";
import {
    GEMINI_TOOL_DECLARATIONS,
    TOOL_EXECUTORS,
    initTools,
    getSearchCallCount,
} from "./agent_tools.js";
import {
    logRunStart,
    logRunComplete,
    upsertSignals,
} from "../lib/signal_store.js";
import { logger } from "../lib/firebase.js";
import { extractSignals, diffSky, getTopSignals } from "./signal_engine.js";
import { AI_MODELS } from "../lib/config.js";

// =============================================================================
// COST CONTROLS — Hard limits to prevent runaway spending
// =============================================================================

const COST_LIMITS = {
    maxSearchCalls: 20,      // Tavily budget per run ($0.003 x 20 = $0.06 max)
    maxLLMCalls: 25,         // Gemini Flash calls per run (~$0.002 x 25 = $0.05 max)
    maxWallTimeMs: 240_000,  // 4 minutes max wall time
    maxIterations: 40,       // ReAct loop iterations (safety valve)
};

// =============================================================================
// RUN AGENT — Main entry point
// =============================================================================

/**
 * Execute a full agent run for a given date.
 *
 * @param {Object} options
 * @param {string} options.geminiApiKey - API key value
 * @param {string} options.tavilyApiKey - API key value
 * @param {string} [options.date] - Target date (default: today)
 * @param {Object} [options.skyPositions] - Pre-loaded sky positions
 * @returns {Object} Run results
 */
export async function runCosmicAgent({ geminiApiKey, tavilyApiKey, date = null, skyPositions = null }) {
    const startTime = Date.now();
    const dateStr = date || new Date().toISOString().split("T")[0];
    let runId = null;

    try {
        // Log run start
        runId = await logRunStart();

        // Initialize tools
        initTools({
            geminiApiKeyValue: geminiApiKey,
            tavilyApiKeyValue: tavilyApiKey,
            searchBudget: COST_LIMITS.maxSearchCalls,
        });

        // Create Gemini model with function calling
        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({
            model: AI_MODELS?.GEMINI_FLASH || "gemini-2.0-flash",
            systemInstruction: COSMIC_AGENT_SYSTEM_PROMPT,
            generationConfig: {
                temperature: 0.3,
                maxOutputTokens: 4096,
            },
            tools: [{
                functionDeclarations: GEMINI_TOOL_DECLARATIONS,
            }],
        });

        // Pre-compute sky signals to inject as context (saves LLM round-trip)
        let skyContext = "";
        if (skyPositions) {
            const sortedDates = Object.keys(skyPositions).sort();
            const todayIdx = sortedDates.indexOf(dateStr);
            const todayPos = skyPositions[dateStr];
            const yesterdayPos = todayIdx > 0 ? skyPositions[sortedDates[todayIdx - 1]] : null;

            if (todayPos) {
                const signals = extractSignals(todayPos, yesterdayPos, dateStr);
                const diff = yesterdayPos ? diffSky(todayPos, yesterdayPos, dateStr) : null;
                const top = getTopSignals(signals, 10);

                // Persist signals to Firestore
                await upsertSignals(signals);

                skyContext = formatSkyContext(dateStr, top, diff);
            }
        }

        // Build initial user message
        const runContext = getRunContext(dateStr);
        const userMessage = skyContext
            ? `${runContext}\n\nHere is today's pre-computed sky analysis:\n${skyContext}\n\nNow follow your full workflow: recall memories, reason about these signals, research if needed, make predictions if warranted, validate old predictions, and reflect.`
            : `${runContext}\n\nStart by calling calculate_sky with today's date, then follow your full workflow.`;

        // Run ReAct loop
        const result = await runReActLoop(model, userMessage, {
            maxIterations: COST_LIMITS.maxIterations,
            maxWallTimeMs: COST_LIMITS.maxWallTimeMs,
            startTime,
        });

        // Compute run stats
        const stats = {
            date: dateStr,
            totalMessages: result.messageCount,
            toolCalls: result.toolCallCount,
            searchesUsed: getSearchCallCount(),
            wallTimeMs: Date.now() - startTime,
            iterations: result.iterations,
            summary: (result.finalText || "No summary").substring(0, 1000),
        };

        // Log completion
        await logRunComplete(runId, stats);

        logger.info("Cosmic agent run completed", {
            structuredData: true,
            runId,
            date: dateStr,
            toolCalls: stats.toolCalls,
            searchesUsed: stats.searchesUsed,
            wallTimeMs: stats.wallTimeMs,
            iterations: stats.iterations,
        });

        return {
            success: true,
            runId,
            stats,
            summary: result.finalText || "No summary generated",
        };

    } catch (error) {
        const wallTime = Date.now() - startTime;

        logger.error("Cosmic agent run failed", {
            structuredData: true,
            runId,
            error: String(error),
            wallTimeMs: wallTime,
        });

        if (runId) {
            await logRunComplete(runId, { wallTimeMs: wallTime, date: dateStr }, error);
        }

        return {
            success: false,
            runId,
            error: String(error),
            wallTimeMs: wallTime,
        };
    }
}

// =============================================================================
// REACT LOOP — Manual implementation of tool-calling agent loop
// =============================================================================

/**
 * Run the ReAct loop: send message → get response → if tool calls, execute them
 * and send results back → repeat until the model returns plain text.
 *
 * @param {Object} model - Gemini GenerativeModel instance
 * @param {string} userMessage - Initial user message
 * @param {Object} limits - { maxIterations, maxWallTimeMs, startTime }
 * @returns {Object} { finalText, messageCount, toolCallCount, iterations }
 */
async function runReActLoop(model, userMessage, limits) {
    const { maxIterations, maxWallTimeMs, startTime } = limits;

    // Start a chat session (preserves conversation history automatically)
    const chat = model.startChat();

    let iterations = 0;
    let toolCallCount = 0;
    let messageCount = 1; // initial user message
    let finalText = "";

    // Send initial message
    let response = await chat.sendMessage(userMessage);
    messageCount++;

    while (iterations < maxIterations) {
        iterations++;

        // Check wall time
        if (Date.now() - startTime > maxWallTimeMs) {
            logger.warn("Agent hit wall time limit", { iterations, toolCallCount });
            finalText = extractText(response) || `[Stopped: wall time limit after ${iterations} iterations]`;
            break;
        }

        // Check if model wants to call tools
        const candidate = response.response.candidates?.[0];
        const parts = candidate?.content?.parts || [];

        const functionCalls = parts.filter(p => p.functionCall);

        if (functionCalls.length === 0) {
            // No tool calls — model is done, extract final text
            finalText = extractText(response);
            break;
        }

        // Execute all function calls
        const functionResponses = [];

        for (const part of functionCalls) {
            const { name, args } = part.functionCall;
            toolCallCount++;

            logger.info(`Agent tool call: ${name}`, {
                structuredData: true,
                iteration: iterations,
                args: JSON.stringify(args).substring(0, 200),
            });

            let result;
            try {
                const executor = TOOL_EXECUTORS[name];
                if (!executor) {
                    result = { error: `Unknown tool: ${name}` };
                } else {
                    result = await executor(args || {});
                }
            } catch (error) {
                result = { error: `Tool execution failed: ${String(error)}` };
                logger.warn(`Tool ${name} threw error`, {
                    structuredData: true,
                    error: String(error),
                });
            }

            functionResponses.push({
                functionResponse: {
                    name,
                    response: result,
                },
            });
        }

        // Send tool results back to the model
        response = await chat.sendMessage(functionResponses);
        messageCount += 2; // tool results + model response
    }

    if (iterations >= maxIterations) {
        logger.warn("Agent hit iteration limit", { iterations, toolCallCount });
        finalText = finalText || `[Stopped: iteration limit of ${maxIterations}]`;
    }

    return {
        finalText,
        messageCount,
        toolCallCount,
        iterations,
    };
}

/**
 * Extract text content from a Gemini response.
 */
function extractText(response) {
    try {
        return response.response.text();
    } catch {
        // If .text() fails (e.g., only function calls), try to extract from parts
        const parts = response.response.candidates?.[0]?.content?.parts || [];
        const textParts = parts.filter(p => p.text).map(p => p.text);
        return textParts.join("\n") || "";
    }
}

// =============================================================================
// HELPERS
// =============================================================================

/**
 * Format sky signals into a concise text context for the agent.
 */
function formatSkyContext(dateStr, topSignals, diff) {
    const lines = [`## Sky Analysis for ${dateStr}\n`];

    lines.push("### Top Active Signals:");
    for (const s of topSignals) {
        const applying = s.applying === true ? " (applying)" : s.applying === false ? " (separating)" : "";
        const orb = s.orb != null ? ` orb ${s.orb}°` : "";
        lines.push(`- [${s.intensity}/10] ${s.type}: ${s.planets.join(" + ")} ${s.aspect || s.dignity || s.stationType || ""}${orb}${applying} | Domains: ${(s.domains || []).slice(0, 5).join(", ")}`);
    }

    if (diff) {
        lines.push(`\n### Changes Since Yesterday:`);
        lines.push(diff.summary);
        lines.push(`Stats: ${diff.stats.new} new, ${diff.stats.changed} changed, ${diff.stats.ended} ended, ${diff.stats.totalActive} total active`);
    }

    return lines.join("\n");
}
