/**
 * AI Client — the one place we talk to Gemini.
 *
 * Replaces ~6 separate copies of Gemini setup, JSON parsing, error handling,
 * and retry logic scattered across the codebase. Every flavor goes through
 * this same wrapper, so improvements (better retries, structured output,
 * telemetry, model upgrades) happen in ONE place.
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import { logger } from "../../lib/firebase.js";
import { geminiApiKey } from "../../lib/secrets.js";
import { AI_MODELS } from "../../lib/config.js";

const DEFAULTS = {
    model: AI_MODELS.GEMINI_FLASH,
    temperature: 0.85,
    maxOutputTokens: 1500,
    maxRetries: 2,
    retryDelayMs: 800,
};

/**
 * Strip markdown code fences that Gemini sometimes wraps JSON in.
 * Handles fences anywhere in the response (with preamble/trailing text),
 * and falls back to extracting bare JSON objects.
 */
function stripCodeFences(text) {
    if (!text) return text;
    let s = text.trim();

    // Match ```json ... ``` or ``` ... ``` anywhere in the response
    const fenceMatch = s.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fenceMatch) return fenceMatch[1].trim();

    // No fences — try to extract a bare JSON object
    const jsonMatch = s.match(/\{[\s\S]*\}/);
    if (jsonMatch) return jsonMatch[0].trim();

    return s;
}

/**
 * Try to parse Gemini output as JSON. If it fails, return null and let the
 * caller decide whether to retry, fallback, or surface the error.
 */
function tryParseJson(text) {
    if (!text) return null;
    try {
        return JSON.parse(stripCodeFences(text));
    } catch {
        return null;
    }
}

/**
 * Sleep helper for retry backoff.
 */
function sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
}

/**
 * Call Gemini with a system + user prompt and return either raw text
 * or parsed JSON. Handles retries, code-fence stripping, and structured
 * logging.
 *
 * @param {Object} opts
 * @param {string} opts.systemPrompt   - The system instruction
 * @param {string} opts.userPrompt     - The user prompt with the data
 * @param {string} [opts.model]        - Override model (default: GEMINI_FLASH)
 * @param {number} [opts.temperature]  - Generation temperature (default: 0.85)
 * @param {number} [opts.maxOutputTokens] - Max output tokens (default: 1500)
 * @param {boolean} [opts.expectJson]  - If true, parse output as JSON
 * @param {boolean} [opts.googleSearch] - Enable Google Search grounding tool
 * @param {string} [opts.flavorName]   - Name of calling flavor (for logs)
 * @returns {Promise<{text: string, json: Object|null, latencyMs: number}>}
 * @throws {Error} If Gemini fails after retries, content is blocked, or
 *                 expectJson=true and JSON cannot be parsed.
 */
export async function callGemini(opts) {
    const {
        systemPrompt,
        userPrompt,
        model = DEFAULTS.model,
        temperature = DEFAULTS.temperature,
        maxOutputTokens = DEFAULTS.maxOutputTokens,
        expectJson = false,
        googleSearch = false,
        flavorName = "unknown",
    } = opts;

    const apiKey = geminiApiKey.value();
    if (!apiKey) throw new Error("Gemini API key missing");

    const genAI = new GoogleGenerativeAI(apiKey);
    const modelConfig = {
        model,
        generationConfig: { temperature, maxOutputTokens },
    };
    if (googleSearch) {
        modelConfig.tools = [{ googleSearch: {} }];
    }
    const llm = genAI.getGenerativeModel(modelConfig);

    let lastError;
    for (let attempt = 0; attempt <= DEFAULTS.maxRetries; attempt++) {
        const startTime = Date.now();
        try {
            const result = await llm.generateContent([
                { text: systemPrompt },
                { text: userPrompt },
            ]);
            const response = result.response;
            const candidates = response?.candidates;
            if (!candidates?.length) {
                const reason = response?.promptFeedback?.blockReason || "unknown";
                throw new Error(`Gemini blocked content: ${reason}`);
            }

            const text = response.text()?.trim();
            if (!text) throw new Error("Gemini returned empty response");

            const latencyMs = Date.now() - startTime;
            const json = expectJson ? tryParseJson(text) : null;

            if (expectJson && !json) {
                // JSON was expected but parsing failed — retry if we can,
                // else throw so caller can decide on fallback strategy.
                lastError = new Error("Gemini returned unparseable JSON");
                logger.warn("📛 Gemini JSON parse failed", {
                    structuredData: true,
                    flavor: flavorName,
                    attempt,
                    textPreview: text.substring(0, 200),
                });
                if (attempt < DEFAULTS.maxRetries) {
                    await sleep(DEFAULTS.retryDelayMs * (attempt + 1));
                    continue;
                }
                throw lastError;
            }

            logger.info("🤖 Gemini call ok", {
                structuredData: true,
                flavor: flavorName,
                model,
                latencyMs,
                attempt,
                outputLength: text.length,
                expectJson,
            });

            return { text, json, latencyMs };
        } catch (error) {
            lastError = error;
            logger.warn("⚠️ Gemini attempt failed", {
                structuredData: true,
                flavor: flavorName,
                attempt,
                error: String(error?.message || error),
            });
            if (attempt < DEFAULTS.maxRetries) {
                await sleep(DEFAULTS.retryDelayMs * (attempt + 1));
            }
        }
    }

    throw lastError || new Error("Gemini call failed after retries");
}
