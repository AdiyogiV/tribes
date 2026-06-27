/**
 * AI Client — the one place we talk to Gemini.
 *
 * Replaces ~6 separate copies of Gemini setup, JSON parsing, error handling,
 * and retry logic scattered across the codebase. Every flavor goes through
 * this same wrapper, so improvements (better retries, structured output,
 * telemetry, model upgrades) happen in ONE place.
 */

import { db, logger } from "../../lib/firebase.js";
import { FieldValue } from "firebase-admin/firestore";
import { getVertexAI, extractText } from "../../lib/vertex_client.js";
import { AI_MODELS } from "../../lib/config.js";

const DEFAULTS = {
    model: AI_MODELS.GEMINI_FLASH,
    temperature: 0.85,
    maxOutputTokens: 65536, // gemini-2.5-flash max; let the prompt control actual length
    maxRetries: 2,
    retryDelayMs: 800,
};

/**
 * Fire-and-forget: track Gemini call metrics per flavor per day.
 * Writes to `geminiUsage/{yyyy-MM-dd}` with atomic increments.
 * Failures are silently swallowed — observability should never break AI calls.
 *
 * Document shape:
 * {
 *   date: "2026-05-15",
 *   totalCalls: 42,
 *   totalLatencyMs: 85000,
 *   totalErrors: 3,
 *   byFlavor: {
 *     daily_insight: { calls: 30, latencyMs: 60000, errors: 2 },
 *     first_reading: { calls: 12, latencyMs: 25000, errors: 1 },
 *   },
 *   updatedAt: <serverTimestamp>
 * }
 */
function trackUsage({ flavorName, latencyMs, failed, errorCategory }) {
    const today = new Date().toISOString().slice(0, 10); // yyyy-MM-dd
    const ref = db.collection("geminiUsage").doc(today);

    const update = {
        date: today,
        totalCalls: FieldValue.increment(1),
        totalLatencyMs: FieldValue.increment(latencyMs || 0),
        [`byFlavor.${flavorName}.calls`]: FieldValue.increment(1),
        [`byFlavor.${flavorName}.latencyMs`]: FieldValue.increment(latencyMs || 0),
        updatedAt: FieldValue.serverTimestamp(),
    };
    if (failed) {
        update.totalErrors = FieldValue.increment(1);
        update[`byFlavor.${flavorName}.errors`] = FieldValue.increment(1);
        if (errorCategory) {
            update[`errorsByCategory.${errorCategory}`] = FieldValue.increment(1);
        }
    }

    ref.set(update, { merge: true }).catch((err) => {
        logger.warn("⚠️ Gemini usage tracking failed (non-fatal)", {
            error: String(err?.message || err),
        });
    });
}

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
 * Classify a Gemini error into a filterable category for Cloud Logging.
 * Categories map to actionability:
 *   - BLOCKED: content/safety filter triggered — prompt needs review
 *   - RATE_LIMIT: 429 / quota — back off or upgrade quota
 *   - AUTH: API key invalid or missing
 *   - PARSE_FAIL: AI returned non-JSON when JSON was expected
 *   - EMPTY: AI returned empty/no candidates
 *   - NETWORK: timeout, DNS, socket errors
 *   - UNKNOWN: everything else
 */
function classifyError(error) {
    const msg = String(error?.message || error).toLowerCase();
    const status = error?.status || error?.code;

    if (msg.includes("blocked") || msg.includes("safety")) return "BLOCKED";
    if (status === 429 || msg.includes("quota") || msg.includes("rate")) return "RATE_LIMIT";
    if (status === 401 || status === 403 || msg.includes("api key")) return "AUTH";
    if (msg.includes("unparseable json") || msg.includes("parse")) return "PARSE_FAIL";
    if (msg.includes("empty response") || msg.includes("no candidates")) return "EMPTY";
    if (msg.includes("timeout") || msg.includes("econnreset") ||
        msg.includes("enotfound") || msg.includes("socket")) return "NETWORK";
    return "UNKNOWN";
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
 * @param {number} [opts.maxOutputTokens] - Max output tokens (default: 65536)
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

    const vertexAI = getVertexAI();
    const modelConfig = {
        model,
        generationConfig: {
            temperature,
            maxOutputTokens,
            // Thinking OFF. Gemini 2.5 Flash bills thinking tokens at the output
            // rate; for these structured batch generations the prompt already
            // does the reasoning, so thinking was pure wasted spend. Single
            // biggest lever on the nightly Vertex bill.
            thinkingConfig: { thinkingBudget: 0 },
        },
    };
    if (googleSearch) {
        modelConfig.tools = [{ googleSearch: {} }];
    }
    const llm = vertexAI.getGenerativeModel(modelConfig);

    let lastError;
    for (let attempt = 0; attempt <= DEFAULTS.maxRetries; attempt++) {
        const startTime = Date.now();
        try {
            const result = await llm.generateContent({
                contents: [{ role: "user", parts: [{ text: userPrompt }] }],
                systemInstruction: systemPrompt,
            });
            const response = result.response;
            const candidates = response?.candidates;
            if (!candidates?.length) {
                const reason = response?.promptFeedback?.blockReason || "unknown";
                throw new Error(`Gemini blocked content: ${reason}`);
            }

            const text = extractText(result);
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
                    errorCategory: "PARSE_FAIL",
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

            trackUsage({ flavorName, latencyMs, failed: false });
            return { text, json, latencyMs };
        } catch (error) {
            lastError = error;
            logger.warn("⚠️ Gemini attempt failed", {
                structuredData: true,
                flavor: flavorName,
                attempt,
                errorCategory: classifyError(error),
                error: String(error?.message || error),
            });
            if (attempt < DEFAULTS.maxRetries) {
                await sleep(DEFAULTS.retryDelayMs * (attempt + 1));
            }
        }
    }

    // Track the final failure (latency of last attempt is unknown, use 0)
    trackUsage({ flavorName, latencyMs: 0, failed: true, errorCategory: classifyError(lastError) });
    throw lastError || new Error("Gemini call failed after retries");
}
