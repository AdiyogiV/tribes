/**
 * बृहत्संहिता — The Complete Mundane Reading
 *
 * Varahamihira's Brihat Samhita, encoded as a living system.
 *
 * This module orchestrates the EXACT steps a Jyotishi performs
 * when making a mundane (world-events) prediction, in the EXACT
 * order prescribed by the classical tradition:
 *
 *   १. काल निर्णय (Kaal Nirnaya)       — Is this the right time to speak?
 *   २. निमित्त अवलोकन (Nimitta Avalokan) — Observe the world's signs FIRST
 *   ३. दृक् गणित (Drik Ganita)          — Where are the grahas in the sky?
 *   ४. फल गणन (Phala Ganana)            — What do the chapters say? (+ Nimitta boost)
 *   ५. स्मृति प्रत्याहार (Smriti Pratyahara) — Recall past readings
 *   ६. फल संग्रह (Phala Sangraha)        — Weave into a single reading
 *   ७. स्मृति संचय (Smriti Sanchaya)     — Remember and learn
 *
 * KEY DESIGN: News (Nimitta) is observed BEFORE predictions, not after.
 * A real Jyotishi observes the world before speaking — domain heat from
 * news SHAPES the astrological effects, amplifying domains that are active.
 *
 * WIRED TO EXISTING BACKEND:
 * - lib/news_feed.js → Google News RSS (no reinventing)
 * - lib/agent_memory.js → Gemini embeddings semantic recall
 * - lib/signal_store.js → Prediction tracking & confidence
 * - global_astro/sky_positions → Real sidereal positions from Firestore
 *
 * Usage:
 *   import { performReading } from "./samhita.js";
 *   const reading = await performReading({ date: "2026-04-12" });
 */

// ── The Process (Kriya) ─────────────────────────────────────────────────
import { getPurnimaAmavasyaDates } from "./kriya/kaal_nirnaya.js";
import { buildSkyState, buildSkyStateFromRaw } from "./kriya/drik_ganita.js";
import { applyAllRules } from "./kriya/phala_ganana.js";
import { observeNimitta, computeDomainHeat, runValidationPipeline } from "./kriya/nimitta_pariksha.js";
import { synthesizeForecast, synthesizeFallback } from "./kriya/phala_sangraha.js";
import {
    applyConfidenceToEffects,
    batchUpdateConfidence,
    storeMundanePrediction,
    storeMundaneValidation,
} from "./kriya/smriti.js";

// ── Existing Backend Infrastructure ─────────────────────────────────────
import { initMemory, storeMemory, recallMemory } from "../lib/agent_memory.js";
import { logger } from "../lib/firebase.js";

/**
 * Perform a complete mundane reading — the full Jyotishi's process.
 *
 * @param {Object} options
 * @param {string} [options.date]          — "YYYY-MM-DD" or null for today
 * @param {string} [options.geminiApiKey]  — For LLM synthesis + memory embeddings
 * @param {boolean} [options.validate]     — Run post-hoc Nimitta validation too?
 * @param {boolean} [options.learn]        — Update confidence memory?
 * @param {boolean} [options.skipNews]     — Skip news fetch (offline/testing)
 * @param {Object} [options.rawPositions]  — Override positions (for testing)
 * @param {Object[]} [options.eclipses]    — Override eclipse windows
 * @returns {Object} The complete reading
 */
export async function performReading(options = {}) {
    const {
        date = null,
        geminiApiKey = null,
        validate = false,
        learn = false,
        skipNews = false,
        rawPositions = null,
        eclipses = [],
    } = options;

    const reading = { steps: {}, timestamp: new Date().toISOString() };
    const today = date || new Date().toISOString().split("T")[0];
    reading.date = today;

    // ── क्रिया १: काल निर्णय (Time Check) ────────────────────────────────
    const windowStart = new Date(today);
    windowStart.setDate(windowStart.getDate() - 1);
    const windowEnd = new Date(today);
    windowEnd.setDate(windowEnd.getDate() + 1);
    const triggers = getPurnimaAmavasyaDates(
        windowStart.toISOString().split("T")[0],
        windowEnd.toISOString().split("T")[0],
    );
    reading.steps.kaalNirnaya = {
        isTriggerDay: triggers.length > 0,
        trigger: triggers[0] || null,
        message: triggers.length > 0
            ? `${triggers[0].type} active — the sky commands a reading`
            : "No Panchanga trigger — reading proceeds by request",
    };

    // ── क्रिया २: निमित्त अवलोकन (Observe the World FIRST) ──────────────
    // Varahamihira observes the world before speaking.
    // Domain heat from news will SHAPE the astrological reading.
    let nimitta = { domainHeat: {}, headlines: [], newsText: "", headlineCount: 0 };
    if (!skipNews) {
        try {
            nimitta = await observeNimitta(30);
            reading.steps.nimittaAvalokan = {
                headlineCount: nimitta.headlineCount,
                hotDomains: Object.entries(nimitta.domainHeat)
                    .filter(([, v]) => v.normalizedHeat > 0.3)
                    .sort((a, b) => b[1].normalizedHeat - a[1].normalizedHeat)
                    .slice(0, 6)
                    .map(([domain, v]) => ({
                        domain,
                        label: v.label,
                        heat: v.normalizedHeat,
                        headlines: v.count,
                    })),
                error: nimitta.error,
            };
        } catch (err) {
            reading.steps.nimittaAvalokan = { error: err.message, headlineCount: 0 };
            logger.warn("Nimitta observation failed, proceeding without news", { error: String(err) });
        }
    } else {
        reading.steps.nimittaAvalokan = { skipped: true, message: "News skipped (offline/testing mode)" };
    }

    // ── क्रिया ३: दृक् गणित (Sky Observation) ─────────────────────────────
    let skyState;
    if (rawPositions) {
        skyState = buildSkyStateFromRaw(rawPositions, today, eclipses);
    } else {
        skyState = await buildSkyState(date);
    }

    // INJECT domain heat into sky state — so phala_ganana can use it
    skyState.domainHeat = nimitta.domainHeat;

    reading.steps.drikGanita = {
        date: skyState.date,
        planetCount: Object.keys(skyState.positions).length,
        eclipseWindows: skyState.activeEclipses.length,
        source: rawPositions ? "raw_override" : "firestore_real",
    };

    // ── क्रिया ४: फल गणन (Effect Calculation + Nimitta Boost) ───────────
    // Rules engine now receives domain heat and boosts hot-domain effects.
    const analysis = applyAllRules(skyState);

    // Apply learned confidence from past validations (Smriti shapes the present)
    analysis.effects = await applyConfidenceToEffects(analysis.effects);

    reading.steps.phalaGanana = {
        totalEffects: analysis.totalEffects,
        conjunctions: analysis.conjunctions.length,
        domains: analysis.domainScores.length,
        nimittaBoosted: analysis.domainHeatApplied || false,
        topEffects: analysis.effects.slice(0, 5).map(e => ({
            planet: e.planet, sign: e.sign, domain: e.domain,
            dir: e.dir, weight: e.weight, desc: e.desc,
            nimittaBoost: e.nimittaBoost || 0,
            confidence: e.confidence,
        })),
    };
    reading.analysis = analysis;

    // ── क्रिया ५: स्मृति प्रत्याहार (Recall Past Readings) ────────────────
    // A wise Jyotishi remembers what he said before.
    let memoryContext = null;
    if (geminiApiKey) {
        try {
            initMemory(geminiApiKey);
            const memories = await recallMemory(
                `mundane forecast ${today} planetary positions world events`,
                { namespace: "predictions", topK: 3 },
            );
            if (memories.length > 0) {
                memoryContext = memories.map(m => m.content).join("\n---\n");
                reading.steps.smritiRecall = {
                    memoriesFound: memories.length,
                    topMemory: memories[0]?.content?.slice(0, 200),
                };
            } else {
                reading.steps.smritiRecall = { memoriesFound: 0 };
            }
        } catch (err) {
            reading.steps.smritiRecall = { error: err.message };
            logger.warn("Memory recall failed", { error: String(err) });
        }
    }

    // ── क्रिया ६: फल संग्रह (Synthesis) ──────────────────────────────────
    // Weave all signals + news context + memory into a coherent reading.
    if (geminiApiKey) {
        try {
            // Enrich analysis with news and memory context for the LLM
            const enrichedAnalysis = {
                ...analysis,
                newsContext: nimitta.newsText,
                memoryContext,
                nimittaHotDomains: reading.steps.nimittaAvalokan?.hotDomains,
            };
            reading.forecast = await synthesizeForecast(geminiApiKey, enrichedAnalysis);
        } catch (err) {
            logger.warn("LLM synthesis failed, using fallback", { error: String(err) });
            reading.forecast = synthesizeFallback(analysis);
        }
    } else {
        reading.forecast = synthesizeFallback(analysis);
    }

    // Tag with Panchanga metadata
    if (reading.steps.kaalNirnaya.trigger) {
        reading.forecast._panchanga = {
            triggerType: reading.steps.kaalNirnaya.trigger.type,
            triggerDate: reading.steps.kaalNirnaya.trigger.date,
        };
    }

    // ── क्रिया ७: स्मृति संचय (Store & Learn) ────────────────────────────
    // Store this reading in memory for future recall.
    if (geminiApiKey) {
        try {
            const summaryForMemory = [
                `Mundane reading for ${today}:`,
                reading.forecast.headline || reading.forecast.executive_summary || "",
                `Top domains: ${analysis.domainScores.slice(0, 3).map(d => `${d.label}(${d.outlook})`).join(", ")}`,
                `Effects: ${analysis.totalEffects}, Conjunctions: ${analysis.conjunctions.length}`,
            ].join(" ");
            await storeMemory(summaryForMemory, {
                namespace: "predictions",
                metadata: { date: today, type: "mundane_forecast" },
            });
        } catch (err) {
            logger.warn("Memory store failed", { error: String(err) });
        }
    }

    // Store predictions for future validation tracking
    if (reading.forecast.predictions?.length > 0) {
        try {
            for (const pred of reading.forecast.predictions.slice(0, 10)) {
                await storeMundanePrediction(pred, today);
            }
            reading.steps.predictionsStored = reading.forecast.predictions.length;
        } catch (err) {
            logger.warn("Prediction store failed", { error: String(err) });
        }
    }

    // Run post-hoc validation if requested (separate from pre-reading Nimitta)
    if (validate && nimitta.headlineCount > 0) {
        try {
            const validation = await runValidationPipeline(analysis.effects);
            reading.steps.nimittaValidation = {
                headlineCount: validation.headlineCount,
                validationCount: validation.validations.length,
                topValidations: validation.validations.slice(0, 5),
                errors: validation.errors,
            };
            reading.validation = validation;

            // Learn from validation
            if (learn && validation.validations.length > 0) {
                const updates = await batchUpdateConfidence(validation.validations);
                reading.steps.smritiLearn = {
                    updatesApplied: updates.length,
                    topUpdates: updates.filter(u => Math.abs(u.delta) > 0.01).slice(0, 5),
                };
                // Store validation summary
                await storeMundaneValidation(today, {
                    validationCount: validation.validations.length,
                    updatesApplied: updates.length,
                    avgEvidence: Math.round(
                        validation.validations.reduce((s, v) => s + v.evidence, 0) /
                        validation.validations.length * 1000
                    ) / 1000,
                });
            }
        } catch (err) {
            reading.steps.nimittaValidation = { error: err.message };
        }
    }

    return reading;
}

/**
 * Quick reading — just rules engine, no LLM, no news, no memory.
 * For testing and simulation.
 */
export function performQuickReading(rawPositions, date, eclipses = []) {
    const skyState = buildSkyStateFromRaw(rawPositions, date, eclipses);
    const analysis = applyAllRules(skyState);
    const forecast = synthesizeFallback(analysis);
    return { date, analysis, forecast };
}
