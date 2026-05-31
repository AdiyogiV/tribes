/**
 * क्रिया ५ — फल संग्रह (Phala Sangraha: Result Synthesis)
 *
 * "Finally, the Jyotishi weaves all signals into a single, coherent
 *  reading — balancing contradictions, weighing evidence, and speaking
 *  with the authority of the Samhita."
 *
 * Uses Gemini Flash for narrative synthesis. The LLM adds NARRATIVE
 * and NUANCE, not rules. Rules are pre-computed by Phala Ganana.
 */

import { getVertexAI, extractText } from "../../lib/vertex_client.js";
import { logger } from "firebase-functions";
import { normalizeDomain, getAllDomainKeys } from "../adhyaya/vishaya.js";

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

NIMITTA (MODERN OMENS — NEWS CONTEXT):
If news headlines are provided, treat them as Varahamihira's Nimitta — earthly signs
that a Jyotishi observes BEFORE speaking. The news should:
- INFORM which domains are most active right now (hot domains in news = louder signals)
- GROUND your predictions in current reality (don't ignore what's happening)
- Help you prioritize: if economy domain is hot in news AND the stars show economy effects,
  lead with economy. If a domain is active in stars but quiet in news, note the gap.
- Never let news OVERRIDE Jyotish — the stars still lead, but Nimitta provides context.

MEMORY (PAST READINGS):
If past readings are provided, use them for CONTINUITY:
- Reference what was said before and whether it manifested
- Note evolving patterns ("Last month we noted Saturn's pressure on maritime trade;
  this continues and deepens with...")
- Adjust confidence up/down based on track record

TIMING RULES (Brihat Samhita Ch.97 — Paka Adhyaya):
Effects do NOT manifest instantly. Each planet has a specific delay:
- Sun effects: manifest within 15 days (a fortnight)
- Moon effects: manifest within 1 month
- Mars effects: manifest after retrograde motion (~60 days)
- Mercury effects: manifest before disappearance (~21 days)
- Jupiter effects: peak after ~1 year
- Venus effects: peak after ~6 months
- Saturn effects: peak after ~1 year
- Rahu/Ketu effects: peak after ~6 months
- Solar eclipse effects: manifest after ~1 year
- Lunar eclipse effects: manifest within ~6 months

CRITICAL — PAKA ENFORCEMENT (DO NOT IGNORE):
Each prediction's "timeframe" field MUST match the SLOWEST planet driving the effect:
- If Saturn or Jupiter drives the domain → timeframe MUST be "~12 months"
- If Rahu, Ketu, or Venus drives the domain → timeframe MUST be "~6 months"
- If Mars drives the domain → timeframe MUST be "~60 days"
- ONLY Sun (15d), Mercury (21d), or Moon (30d) effects may use "next 2-4 weeks"
- If multiple planets affect a domain, use the SLOWEST planet's timeframe
- NEVER output "next 2-4 weeks" for a domain driven by Saturn, Jupiter, Rahu, or Venus

For each prediction, state which planet drives the timing:
Example: "Saturn entered Pisces in February 2026; per BS Ch.97, its maritime
disruption theme peaks around February 2027. Moon transiting Pisces this week
ACTIVATES this theme but the full manifestation requires ~12 months."

ANTI-ECHO RULE:
If a domain is hot in today's news AND the stars show effects there, do NOT predict
that the same news event will continue. Instead, predict the NEXT PHASE or a deeper
manifestation that hasn't happened yet. Astrology predicts what news CANNOT foresee.

PREDICTION QUALITY RULES (CRITICAL):
1. SPECIFICITY: Every prediction MUST name at least one specific entity:
   - A country or region (not just "coastal communities" — say "Indonesia" or "Bay of Bengal")
   - A sector or institution type (not just "a major organization" — say "IMO" or "WHO" or "shipping insurers")
   - A concrete mechanism (not just "disruption" — say "port closure" or "insurance rate spike")
   Bad: "A significant maritime incident will occur in a Pisces-aligned region"
   Good: "Indonesian port authorities will face cargo backlog from new environmental regulations, driving up Southeast Asian shipping rates"

2. DIRECTION BALANCE: At least ONE of your 3 predictions MUST be positive (dir="pos").
   Brihat Samhita describes both auspicious and inauspicious effects for every transit.
   If all effects are negative, find the silver lining — technology breakthrough, reform movement,
   diplomatic resolution. Never output 3 negative predictions in a row.

3. NO REPETITION (STRICTLY ENFORCED):
   Check the Prediction Ledger carefully. For EACH prediction you generate, verify:
   - Is the THEME already in the ledger? (e.g., "cyberattack on infrastructure" — if already predicted, SKIP)
   - Is the DOMAIN already saturated? (3+ pending → choose another domain)
   - Is the EVENT MECHANISM the same? (e.g., "scandal involving religious leader" — if predicted before, find a
     completely different mechanism: policy reform, archaeological discovery, interfaith summit, etc.)
   If you cannot make a genuinely novel prediction in a domain, MOVE TO A DIFFERENT DOMAIN.
   There are 35 domains — even if the top 5 are saturated, 30 remain unexplored.

4. DOMAIN DIVERSITY: Your 3 predictions MUST cover 3 DIFFERENT domains.
   Never output 2 predictions in the same domain in one reading.
   Rotate through neglected domains — the Domain Coverage Balance section shows which need attention.

5. ENTITY NAMING — every prediction MUST include ALL THREE:
   a) A specific country or city (use Koorma Chakra data to pick the RIGHT one)
   b) A specific actor (ministry, company, NGO — say "Turkish Maritime Authority" not "an agency")
   c) A specific action verb (say "will impose sanctions" or "will suspend operations",
      NOT "will face disruption" or "will experience challenges")
   Example: "Indonesia's Maritime Authority will suspend fishing licenses in the Java Sea
   following a toxic algae bloom, disrupting local food supply chains for ~60 days."
   NOT: "A significant maritime incident will occur in a Pisces-aligned region."

6. HEADLINE DIVERSITY: Never start headlines with "Geopolitical tensions" or "Rising [X]".
   Start with a SPECIFIC event: "Vatican probe deepens" or "WHO issues Java Sea alert".
   Avoid the words: "amid", "amidst", "escalate", "intensify" in headlines.

PLANETARY WAR TYPES (BS Ch.17):
When effects include war type data, describe the specific type:
- Bheda (occultation): drought, friends become enemies
- Ullekha (grazing): wars and quarrels, but food abundant
- Amsumardana (ray-clash): warfare, disease, hunger
- Apasavya (deflection): rulers fight each other

CLASSICAL VICTIMS: When provided, mention who specifically suffers per the
original Brihat Samhita text. This adds scholarly depth and specificity.

FOREGROUND vs BACKGROUND (CRITICAL FOR NARRATIVE):
If the context separates "Foreground Effects" from "Background Effects":
- Spend 70% of your narrative on FOREGROUND (what changed since last reading)
- Spend 30% on BACKGROUND (persistent slow-planet themes)
- The headline MUST reflect what's NEW, not repeat the background
- Background provides context; foreground drives the story
- If Saturn in Pisces was discussed in every past reading, DO NOT lead with it again
  unless something specific changed (a conjunction, eclipse activation, etc.)

DOMAIN KEY CONSTRAINT (CRITICAL):
You MUST use ONLY these exact domain keys in all "domain" fields:
government, military, economy, banking, trade, agriculture, health, media, religion,
judiciary, education, foreign_affairs, diplomacy, public_mood, real_estate, technology,
social_movements, humanitarian, refugees, maritime, crisis, mortality, taxation,
insurance, labor, infrastructure, transport, entertainment, culture, sports, research,
terrorism, resources

NEVER use free-text labels like "Maritime & Naval" or "Health & Epidemics".
ALWAYS use the lowercase key: "maritime", "health", "foreign_affairs", etc.

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
      "statement": "Clear, falsifiable prediction about a FUTURE event (not already in the news)",
      "domain": "economy",
      "direction": "pos|neg|mix",
      "confidence": 0.7,
      "timeframe": "~12 months (Saturn-driven) | ~6 months (Rahu/Venus) | ~60 days (Mars) | ~30 days (Moon) | ~21 days (Mercury) | ~15 days (Sun)",
      "driving_planet": "Saturn",
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
        model = "gemini-2.5-flash",
        temperature = 0.4,
    } = options;

    const context = buildSynthesisContext(analysisResult);

    const vertexAI = getVertexAI();
    const geminiModel = vertexAI.getGenerativeModel({
        model,
        systemInstruction: SYSTEM_PROMPT,
        generationConfig: {
            temperature,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
        },
    });

    const startMs = Date.now();

    const result = await geminiModel.generateContent({
        contents: [{ role: "user", parts: [{ text: context }] }],
    });
    const responseText = extractText(result);

    const durationMs = Date.now() - startMs;
    logger.info("🌍 Mundane synthesis complete", { durationMs, model, responseLength: responseText.length });

    let forecast;
    try {
        forecast = JSON.parse(responseText);
    } catch {
        logger.error("Failed to parse mundane synthesis JSON", { preview: responseText.substring(0, 500) });
        throw new Error("Gemini returned invalid JSON for mundane synthesis");
    }

    // ── Post-process: normalize all domain keys ────────────────────────
    // LLM sometimes outputs "Maritime & Naval" instead of "maritime".
    // Normalize every domain field to canonical keys for validation matching.
    if (forecast.domain_forecasts) {
        for (const df of forecast.domain_forecasts) {
            if (df.domain) df.domain = normalizeDomain(df.domain);
        }
    }
    if (forecast.predictions) {
        for (const pred of forecast.predictions) {
            if (pred.domain) pred.domain = normalizeDomain(pred.domain);
        }
    }

    // ── Post-process: enforce PAKA minimum timeframes ─────────────────
    // The LLM often ignores BS Ch.97 timing and outputs "next 2-4 weeks"
    // even for Saturn effects. Override with the slowest driving planet's PAKA.
    if (forecast.predictions && analysisResult.effects) {
        const PAKA_LABELS = {
            365: "~12 months (BS Ch.97 — Saturn/Jupiter paka)",
            180: "~6 months (BS Ch.97 — Rahu/Ketu/Venus paka)",
            60: "~60 days (BS Ch.97 — Mars paka)",
            30: "~1 month (BS Ch.97 — Moon paka)",
            21: "~21 days (BS Ch.97 — Mercury paka)",
            15: "~15 days (BS Ch.97 — Sun paka)",
        };
        const PAKA_DELAYS = {
            Saturn: 365, Jupiter: 365, Rahu: 180, Ketu: 180,
            Venus: 180, Mars: 60, Moon: 30, Mercury: 21, Sun: 15,
        };

        for (const pred of forecast.predictions) {
            const domain = normalizeDomain(pred.domain);
            // Find the slowest planet driving this domain
            const domainEffects = analysisResult.effects.filter(e =>
                normalizeDomain(e.domain) === domain
            );
            let maxDelay = 0;
            for (const eff of domainEffects) {
                const planets = (eff.planet || "").split("+");
                for (const p of planets) {
                    const delay = PAKA_DELAYS[p.trim()] || 0;
                    if (delay > maxDelay) maxDelay = delay;
                }
            }
            // Override LLM timeframe if PAKA requires a longer horizon
            if (maxDelay > 30 && PAKA_LABELS[maxDelay]) {
                pred.timeframe = PAKA_LABELS[maxDelay];
                pred._pakaEnforced = true;
            }
        }
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

    // Effects split into foreground (what's NEW) and background (persistent)
    if (analysis.foregroundEffects?.length > 0) {
        lines.push("## ⚡ FOREGROUND Effects (NEW since last reading — focus 70% of narrative here)");
        lines.push("These are the CHANGES — new transits, fast planet moves, conjunctions, eclipses:");
        for (const e of analysis.foregroundEffects.slice(0, 15)) {
            const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
            const paka = e.manifestation
                ? ` [PAKA: peaks ${e.manifestation.peakDate || "~" + e.manifestation.delayDays + "d"}]`
                : "";
            lines.push(`- [${e.weight.toFixed(2)}] ${arrow} ${e.planet} in ${e.sign} | ${e.domain}: ${e.desc}${paka}`);
            if (e.nimittaBoost > 0) lines.push(`  🔥 Nimitta-boosted +${e.nimittaBoost}%`);
        }
        lines.push("");

        lines.push("## 🌊 BACKGROUND Effects (persistent slow-planet themes — 30% of narrative)");
        lines.push("These have been present for months. Only mention if something specific activated them:");
        const bgEffects = (analysis.backgroundEffects || analysis.effects).slice(0, 8);
        for (const e of bgEffects) {
            const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
            const paka = e.manifestation
                ? ` [PAKA: peaks ${e.manifestation.peakDate || "~" + e.manifestation.delayDays + "d"}]`
                : "";
            lines.push(`- [${e.weight.toFixed(2)}] ${arrow} ${e.planet} in ${e.sign} | ${e.domain}: ${e.desc}${paka}`);
        }
        lines.push("");
    } else {
        // Fallback: no foreground/background split available
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
    }

    // Domain scores
    lines.push("## Domain Scores");
    for (const d of analysis.domainScores) {
        const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
        lines.push(`- ${emoji} ${d.label} (${d.domain}): ${d.outlook}, net=${d.netScore > 0 ? "+" : ""}${d.netScore}, effects=${d.effectCount}`);
    }

    // News context (Nimitta) — what the world is showing NOW
    if (analysis.newsContext) {
        lines.push("");
        lines.push("## Current World News (Modern Nimitta)");
        lines.push("These are today's headlines — the earthly signs a Jyotishi observes:");
        lines.push(analysis.newsContext);
    }

    // Hot domains from news
    if (analysis.nimittaHotDomains?.length > 0) {
        lines.push("");
        lines.push("## Nimitta Domain Heat");
        lines.push("Domains most active in today's news (Nimitta-boosted effects):");
        for (const d of analysis.nimittaHotDomains) {
            lines.push(`  🔥 ${d.label} (${d.domain}): heat ${d.heat}, ${d.headlines} headlines`);
        }
    }

    // Past reading memory (continuity)
    if (analysis.memoryContext) {
        lines.push("");
        lines.push("## Past Readings (Smriti — Memory)");
        lines.push("Previous mundane readings for continuity:");
        lines.push(analysis.memoryContext);
    }

    // Prediction ledger — what you already predicted + outcomes
    if (analysis.predictionLedger) {
        lines.push("");
        lines.push("## Your Prediction Ledger (CRITICAL — READ BEFORE GENERATING PREDICTIONS)");
        lines.push("These are YOUR past predictions. DO NOT duplicate them.");
        lines.push("For each new prediction, it must be DIFFERENT from everything listed below.");
        lines.push("If a domain already has 3+ pending predictions, choose a DIFFERENT domain or a DIFFERENT angle.");
        lines.push(analysis.predictionLedger);
    }

    // Domain coverage gaps
    if (analysis.domainCoverage) {
        lines.push("");
        lines.push("## Domain Coverage Balance");
        lines.push(analysis.domainCoverage);
    }

    lines.push("");
    lines.push("Synthesize these signals into a coherent mundane forecast. Output valid JSON matching the specified format.");
    lines.push("Remember: News (Nimitta) INFORMS which domains to emphasize. Memory gives continuity. Stars lead.");
    lines.push("IMPORTANT: Each prediction must be UNIQUE — not a rephrasing of a pending prediction. Vary domains, angles, and specifics.");

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
    if (koormaMap && Array.isArray(koormaMap)) {
        for (const activation of koormaMap) {
            for (const region of (activation.regions || []).filter(r => r.confidence >= 0.6)) {
                geographicFocus.push({
                    region: region.name,
                    planets: activation.planets,
                    theme: `${activation.planets.join(", ")} transiting ${activation.sign}`,
                });
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
