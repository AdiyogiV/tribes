/**
 * Insight Engine — runs ANY flavor through one consistent pipeline.
 *
 * Pipeline:
 *   1. Validate flavor + params
 *   2. Cache lookup (if flavor.cache configured)
 *   3. Gather context (flavor decides what it needs)
 *   4. Build prompt + call Gemini via shared ai_client
 *   5. Validate output shape (lightweight schema check)
 *   6. Persist (flavor decides where + how)
 *   7. Cache + return
 *
 * Each step is replaceable by the flavor; the engine just orchestrates.
 *
 * --- Flavor contract ---
 * A flavor is an object with:
 *   name           : string                 — for logs + telemetry
 *   gatherContext  : async (params) => ctx  — what data does this reading need?
 *   prompt         : ({ ctx, params }) => { system, user, options? }
 *   parse          : (raw, params) => result   (optional; defaults to raw.json or raw.text)
 *   validate       : (result) => boolean       (optional; defaults to truthy check)
 *   store          : async (params, result) => void   (optional)
 *   cache          : { ttlHours, key: (params) => string }   (optional)
 */

import { logger } from "../../lib/firebase.js";
import { callGemini } from "../../lib/gemini.js";
import { getCached, setCached } from "./cache.js";

/**
 * Run a flavor end-to-end.
 *
 * @param {Object} flavor   - The flavor definition (see contract above)
 * @param {Object} params   - Flavor-specific input (uid, date, house, etc.)
 * @param {Object} [opts]
 * @param {boolean} [opts.bypassCache] - Force regenerate even if cached
 * @returns {Promise<{result: Object, fromCache: boolean, latencyMs: number}>}
 */
export async function runFlavor(flavor, params, opts = {}) {
    const startTime = Date.now();
    const { bypassCache = false } = opts;

    if (!flavor?.name || typeof flavor.prompt !== "function") {
        throw new Error("Invalid flavor: must have { name, prompt }");
    }

    const flavorLog = (level, msg, extra = {}) =>
        logger[level](msg, {
            structuredData: true,
            flavor: flavor.name,
            ...extra,
        });

    // 1. Cache lookup
    let cacheKey = null;
    if (flavor.cache?.key) {
        cacheKey = flavor.cache.key(params);
        if (!bypassCache && cacheKey) {
            const cached = await getCached(cacheKey, flavor.cache.ttlHours ?? 24);
            if (cached) {
                flavorLog("info", "💾 Flavor cache hit", {
                    cacheKey,
                    latencyMs: Date.now() - startTime,
                });
                return {
                    result: cached,
                    fromCache: true,
                    latencyMs: Date.now() - startTime,
                };
            }
        }
    }

    // 2. Gather context
    let ctx = {};
    if (typeof flavor.gatherContext === "function") {
        const ctxStart = Date.now();
        ctx = (await flavor.gatherContext(params)) || {};
        flavorLog("info", "📦 Flavor context gathered", {
            ctxLatencyMs: Date.now() - ctxStart,
            ctxKeys: Object.keys(ctx),
        });
    }

    // 3. Build prompt
    const promptSpec = flavor.prompt({ ctx, params });
    if (!promptSpec?.user) {
        throw new Error(`Flavor "${flavor.name}" prompt() must return { system, user }`);
    }

    // 4. Call Gemini
    const expectJson = promptSpec.options?.expectJson ?? true;
    const aiResponse = await callGemini({
        systemPrompt: promptSpec.system || "",
        userPrompt: promptSpec.user,
        model: promptSpec.options?.model,
        temperature: promptSpec.options?.temperature,
        maxOutputTokens: promptSpec.options?.maxOutputTokens,
        expectJson,
        googleSearch: promptSpec.options?.googleSearch || false,
        flavorName: flavor.name,
    });

    // 5. Parse + validate
    const rawResult = typeof flavor.parse === "function"
        ? flavor.parse(aiResponse, params)
        : (aiResponse.json ?? { text: aiResponse.text });

    const isValid = typeof flavor.validate === "function"
        ? flavor.validate(rawResult)
        : Boolean(rawResult);

    if (!isValid) {
        flavorLog("error", "❌ Flavor result failed validation", {
            resultPreview: JSON.stringify(rawResult).substring(0, 200),
        });
        throw new Error(`Flavor "${flavor.name}" produced invalid result`);
    }

    // 6. Store (best-effort; storage failure doesn't fail the call)
    if (typeof flavor.store === "function") {
        try {
            await flavor.store(params, rawResult);
        } catch (error) {
            flavorLog("warn", "⚠️ Flavor store failed (continuing)", {
                error: String(error?.message || error),
            });
        }
    }

    // 7. Cache
    if (cacheKey) {
        await setCached(cacheKey, rawResult, flavor.cache.ttlHours ?? 24);
    }

    const latencyMs = Date.now() - startTime;
    flavorLog("info", "✅ Flavor complete", {
        latencyMs,
        aiLatencyMs: aiResponse.latencyMs,
    });

    return { result: rawResult, fromCache: false, latencyMs };
}
