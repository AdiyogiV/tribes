/**
 * Mundane Synthesis Agent — LLM-Powered Interpretation Layer
 *
 * Takes the deterministic rules engine output and synthesizes it into:
 * 1. A human-readable mundane forecast
 * 2. Structured predictions with confidence scores
 * 3. Geographic focus areas
 *
 * Uses Gemini (same as rest of the app) with a Brihat Samhita persona.
 * The LLM adds NARRATIVE and NUANCE, not rules. Rules are pre-computed.
 *
 * Cost: ~$0.001 per synthesis (Gemini Flash)
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import { logger } from "firebase-functions";

// ─── System prompt: the scholar persona ──────────────────────────────────

const SYSTEM_PROMPT = `You are a Vedic mundane astrology scholar synthesizing pre-computed signals from a Brihat Samhita rules engine into a coherent world forecast.

CRITICAL RULES:
1. You DO NOT compute astrology. The rules engine already did that. You SYNTHESIZE.
2. Never invent planetary positions or aspects. Use only what's in the context.
3. Weight your narrative by the effect weights provided (higher = more significant).
4. Be specific about domains (economy, health, governance, etc.) — never vague.
5. Include Koorma Chakra geographic references where relevant.
6. Mention nakshatra sub-themes for slow planets — these give timing precision.
7. For each major prediction, assign a confidence (0.3–0.9) and timeframe.
8. Use Brihat Samhita language flavor but remain accessible. No jargon without explanation.
9. Acknowledge mixed signals honestly — don't force a narrative.
10. Keep the total output under 2000 words.

OUTPUT FORMAT (JSON):
{
  "date": "YYYY-MM-DD",
  "headline": "One-line summary of the day's most significant mundane theme",
  "executive_summary": "2-3 paragraph overview for a busy reader",
  "domain_forecasts": [
    {
      "domain": "economy",
      "outlook": "favorable|challenging|mixed",
      "forecast": "2-3 sentences",
      "confidence": 0.7,
      "timeframe": "next 2-4 weeks"
    }
  ],
  "geographic_focus": [
    {
      "region": "South Asia",
      "planets": ["Saturn", "Rahu"],
      "theme": "Brief description"
    }
  ],
  "predictions": [
    {
      "id": "pred_001",
      "statement": "Clear, falsifiable prediction",
      "domain": "economy",
      "direction": "pos|neg|mix",
      "confidence": 0.7,
      "timeframe": "2-4 weeks",
      "basis": "Which rules/effects support this"
    }
  ],
  "key_transits": [
    {
      "transit": "Saturn in Pisces (Uttara Bhadrapada)",
      "significance": "Brief explanation",
      "duration": "Until March 2026"
    }
  ],
  "watch_items": ["Things that could shift the picture if they change"],
  "brihat_samhita_note": "A relevant classical reference if applicable"
}`;

// ─── Main synthesis function ─────────────────────────────────────────────

/**
 * Synthesize a mundane forecast from rules engine output.
 *
 * @param {string} geminiApiKeyValue - Gemini API key
 * @param {Object} analysisResult - Output from applyAllRules()
 * @param {Object} [options] - Optional overrides
 * @param {string} [options.model] - Gemini model name
 * @param {number} [options.temperature] - 0.0-1.0
 * @returns {Object} Structured forecast (parsed JSON)
 */
export async function synthesizeForecast(geminiApiKeyValue, analysisResult, options = {}) {
    const {
        model = "gemini-2.0-flash",
        temperature = 0.4,
    } = options;

    const context = buildSynthesisContext(analysisResult);

    const genAI = new GoogleGenerativeAI(geminiApiKeyValue);
    const geminiModel = genAI.getGenerativeModel({
        model,
        systemInstruction: SYSTEM_PROMPT,
        generationConfig: {
            temperature,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
        },
    });

    const startMs = Date.now();

    const result = await geminiModel.generateContent(context);
    const responseText = result.response.text();

    const durationMs = Date.now() - startMs;
    logger.info("🌍 Mundane synthesis complete", { durationMs, model, responseLength: responseText.length });

    let forecast;
    try {
        forecast = JSON.parse(responseText);
    } catch {
        logger.error("Failed to parse mundane synthesis JSON", { preview: responseText.substring(0, 500) });
        throw new Error("Gemini returned invalid JSON for mundane synthesis");
    }

    // Attach metadata
    forecast._meta = {
        generatedAt: new Date().toISOString(),
        model,
        durationMs,
        totalEffects: analysisResult.totalEffects,
        rulesEngineDate: analysisResult.date,
    };

    return forecast;
}

/**
 * Build the prompt context from analysis results.
 * We serialize the rules engine output into a structured text block
 * that the LLM can reason over.
 */
function buildSynthesisContext(analysis) {
    const lines = [];

    lines.push(`# Mundane Astrology Analysis for ${analysis.date}`);
    lines.push(`Total active effects: ${analysis.totalEffects}`);
    lines.push("");

    // Summary from rules engine
    lines.push(analysis.summary);
    lines.push("");

    // Koorma Chakra geographic data
    if (analysis.koormaText) {
        lines.push("## Geographic Activation (Koorma Chakra)");
        lines.push(analysis.koormaText);
        lines.push("");
    }

    // Nakshatra sub-themes
    if (analysis.nakshatraText) {
        lines.push("## Nakshatra Sub-Themes (Slow Planets)");
        lines.push(analysis.nakshatraText);
        lines.push("");
    }

    // Full effects list (top 20 to keep context manageable)
    lines.push("## Detailed Effects (top 20 by weight)");
    for (const e of analysis.effects.slice(0, 20)) {
        const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
        const retro = e.planet && analysis.effects[0]?.planet1Retro ? " (R)" : "";
        lines.push(`- [${e.weight.toFixed(2)}] ${arrow} ${e.planet}${retro} in ${e.sign} | ${e.domain}: ${e.desc}`);
        if (e.dignityDetails?.length) {
            lines.push(`  Dignity: ${e.dignityDetails.join("; ")}`);
        }
    }
    lines.push("");

    // Domain scores
    lines.push("## Domain Scores");
    for (const d of analysis.domainScores) {
        const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
        lines.push(`- ${emoji} ${d.label} (${d.domain}): ${d.outlook}, net=${d.netScore > 0 ? "+" : ""}${d.netScore}, effects=${d.effectCount}`);
    }

    lines.push("");
    lines.push("Synthesize these signals into a coherent mundane forecast. Output valid JSON matching the specified format.");

    return lines.join("\n");
}

/**
 * Generate a synthesis WITHOUT LLM — pure rules-based summary.
 * Useful as a fallback if Gemini is unavailable, or for testing.
 *
 * @param {Object} analysisResult - Output from applyAllRules()
 * @returns {Object} Simplified forecast
 */
export function synthesizeFallback(analysisResult) {
    const { date, effects, domainScores, conjunctions, koormaMap, nakshatraThemes = [] } = analysisResult;

    const topEffects = effects.slice(0, 5);
    const headline = topEffects.length > 0
        ? `${topEffects[0].planet} in ${topEffects[0].sign}: ${topEffects[0].desc}`
        : "No significant mundane signals today.";

    const domainForecasts = domainScores.slice(0, 6).map(d => ({
        domain: d.domain,
        outlook: d.outlook,
        forecast: `${d.label}: ${d.effectCount} active signals, net score ${d.netScore > 0 ? "+" : ""}${d.netScore}.`,
        confidence: Math.min(0.8, 0.3 + d.effectCount * 0.1),
        timeframe: "current transit period",
    }));

    const geographicFocus = [];
    if (koormaMap) {
        for (const [sign, data] of Object.entries(koormaMap)) {
            if (data.planets?.length > 0) {
                for (const region of (data.regions || [])) {
                    geographicFocus.push({
                        region: region.modern,
                        planets: data.planets,
                        theme: `${data.planets.join(", ")} transiting ${sign}`,
                    });
                }
            }
        }
    }

    const keyTransits = nakshatraThemes.map(t => ({
        transit: `${t.planet} in ${t.nakshatra} (${t.lord}'s nakshatra)`,
        significance: t.hasSpecificEffects
            ? t.effects.map(e => e.desc).join("; ")
            : t.composedDesc,
        duration: t.planet === "Saturn" ? "~1 year" : t.planet === "Jupiter" ? "~5 months" : "~6 months",
    }));

    return {
        date,
        headline,
        executive_summary: analysisResult.summary,
        domain_forecasts: domainForecasts,
        geographic_focus: geographicFocus.slice(0, 5),
        predictions: [],
        key_transits: keyTransits,
        watch_items: conjunctions.map(c => `${c.planets.join("+")} conjunction in ${c.sign} (${c.separation.toFixed(1)}°)`),
        _meta: {
            generatedAt: new Date().toISOString(),
            model: "fallback_rules_only",
            totalEffects: effects.length,
            rulesEngineDate: date,
        },
    };
}
