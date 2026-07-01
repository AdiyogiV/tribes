/**
 * क्रिया ६ — स्मृति (Smriti: Memory & Learning)
 *
 * "A wise Jyotishi remembers which rules manifested and which did not.
 *  Over time, his readings grow more precise."
 *
 * Ashtakavarga-style confidence scoring. Each rule starts at 0.5 (neutral).
 * Validated predictions increase confidence; contradicted ones decrease it.
 * After a year, this weight table IS commentary on Brihat Samhita —
 * which rules actually manifest in 2025-2026.
 *
 * WIRED TO EXISTING INFRA:
 * - Uses lib/signal_store.js → Firestore `global_astro_confidence` collection
 * - Uses lib/agent_memory.js → Firestore `cosmic_memory` for semantic recall
 * - No local JSON files — everything persists in Firestore
 *
 * Update: newScore = oldScore + 0.15 * (evidence - oldScore)
 */

import { db, logger } from "../../lib/firebase.js";
import {
    getConfidence as getSignalConfidence,
    storePrediction,
    storeValidationSummary,
} from "../../lib/signal_store.js";

const MUNDANE_CONFIDENCE_COLLECTION = "mundane_confidence";
const DEFAULT_SCORE = 0.5;
const LEARNING_RATE = 0.15; // Conservative — takes ~7 strong confirmations to reach 0.9

/**
 * Get confidence score for a rule from Firestore.
 * Returns DEFAULT_SCORE (0.5) if unseen.
 *
 * @param {string} ruleId - e.g. "saturn_in_pisces_economy"
 * @returns {Promise<number>} 0.0 - 1.0
 */
export async function getConfidence(ruleId) {
    try {
        const doc = await db.collection(MUNDANE_CONFIDENCE_COLLECTION).doc(ruleId).get();
        if (!doc.exists) return DEFAULT_SCORE;
        return doc.data().score ?? DEFAULT_SCORE;
    } catch (err) {
        logger.warn("smriti: getConfidence failed, using default", { ruleId, error: String(err) });
        return DEFAULT_SCORE;
    }
}

/**
 * Update a rule's confidence based on evidence.
 *
 * @param {string} ruleId - e.g. "saturn_in_pisces_economy"
 * @param {number} evidence - 0.0 (strong contra) to 1.0 (strong confirm)
 * @param {string} [reason] - Why this update was made
 * @returns {Promise<{ruleId, oldScore, newScore, delta}>}
 */
export async function updateConfidence(ruleId, evidence, reason = "") {
    try {
        const docRef = db.collection(MUNDANE_CONFIDENCE_COLLECTION).doc(ruleId);
        const doc = await docRef.get();
        const oldScore = doc.exists ? (doc.data().score ?? DEFAULT_SCORE) : DEFAULT_SCORE;

        // Bayesian-lite update
        const newScore = Math.max(0.05, Math.min(0.99,
            oldScore + LEARNING_RATE * (evidence - oldScore)
        ));
        const roundedNew = Math.round(newScore * 1000) / 1000;

        const historyEntry = {
            oldScore: Math.round(oldScore * 1000) / 1000,
            newScore: roundedNew,
            evidence,
            reason,
            date: new Date().toISOString(),
        };

        if (!doc.exists) {
            await docRef.set({
                score: roundedNew,
                ruleId,
                totalUpdates: 1,
                createdAt: new Date(),
                lastUpdated: new Date(),
                history: [historyEntry],
            });
        } else {
            const history = (doc.data().history || []).slice(-99);
            history.push(historyEntry);
            await docRef.update({
                score: roundedNew,
                totalUpdates: (doc.data().totalUpdates || 0) + 1,
                lastUpdated: new Date(),
                history,
            });
        }

        return {
            ruleId,
            oldScore: Math.round(oldScore * 1000) / 1000,
            newScore: roundedNew,
            delta: Math.round((newScore - oldScore) * 1000) / 1000,
        };
    } catch (err) {
        logger.warn("smriti: updateConfidence failed", { ruleId, error: String(err) });
        return { ruleId, oldScore: DEFAULT_SCORE, newScore: DEFAULT_SCORE, delta: 0 };
    }
}

/**
 * Batch update multiple rules from a validation result.
 *
 * @param {Object[]} validations - [{ ruleId, evidence, reason }]
 * @returns {Promise<Object[]>} Array of update results
 */
export async function batchUpdateConfidence(validations) {
    const results = [];
    for (const v of validations) {
        if (!v.ruleId) continue;
        results.push(await updateConfidence(v.ruleId, v.evidence, v.reason));
    }
    return results;
}

/**
 * Get a summary of confidence scores from Firestore.
 * @returns {Promise<Object>}
 */
export async function getConfidenceSummary() {
    try {
        const snapshot = await db.collection(MUNDANE_CONFIDENCE_COLLECTION)
            .orderBy("score", "desc")
            .limit(200)
            .get();

        if (snapshot.empty) {
            return { totalRules: 0, message: "No rules tracked yet." };
        }

        const scores = snapshot.docs.map(doc => ({
            ruleId: doc.id,
            score: doc.data().score,
            totalUpdates: doc.data().totalUpdates || 0,
        }));
        const values = scores.map(s => s.score);

        return {
            totalRules: scores.length,
            totalUpdates: scores.reduce((sum, s) => sum + s.totalUpdates, 0),
            avgScore: Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 1000) / 1000,
            highConfidence: scores.slice(0, 5),
            lowConfidence: scores.slice(-5).reverse(),
            distribution: {
                strong: values.filter(v => v >= 0.7).length,
                moderate: values.filter(v => v >= 0.4 && v < 0.7).length,
                weak: values.filter(v => v < 0.4).length,
            },
        };
    } catch (err) {
        logger.warn("smriti: getConfidenceSummary failed", { error: String(err) });
        return { totalRules: 0, message: "Error fetching summary." };
    }
}

/**
 * Apply stored confidence to engine effects — multiply effect weight by rule confidence.
 * This is how memory shapes future forecasts.
 *
 * Fetches all relevant confidence scores in ONE batch read,
 * then applies them locally.
 *
 * @param {Object[]} effects - Array of effects from applyAllRules()
 * @returns {Promise<Object[]>} Effects with confidence-adjusted weights
 */
export async function applyConfidenceToEffects(effects) {
    try {
        // Collect unique ruleIds
        const ruleIds = [...new Set(effects.map(e => e.ruleId).filter(Boolean))];
        if (ruleIds.length === 0) return effects;

        // Batch fetch confidence scores (Firestore getAll)
        const refs = ruleIds.map(id => db.collection(MUNDANE_CONFIDENCE_COLLECTION).doc(id));
        const docs = await db.getAll(...refs);

        const scoreMap = {};
        for (const doc of docs) {
            if (doc.exists) {
                scoreMap[doc.id] = doc.data().score ?? DEFAULT_SCORE;
            }
        }

        return effects.map(e => {
            const conf = scoreMap[e.ruleId] ?? DEFAULT_SCORE;
            return {
                ...e,
                rawWeight: e.weight,
                weight: Math.round(e.weight * (0.5 + conf) * 100) / 100,
                // conf 0.5 = 1.0x, conf 0.9 = 1.4x, conf 0.1 = 0.6x
                confidence: conf,
            };
        });
    } catch (err) {
        logger.warn("smriti: applyConfidenceToEffects failed, returning unmodified", { error: String(err) });
        return effects;
    }
}

/**
 * Store a mundane prediction in the shared prediction store.
 * Wires into existing lib/signal_store.js for unified tracking.
 *
 * @param {Object} prediction - { statement, domain, direction, confidence, timeframe, basis }
 * @param {string} date - ISO date
 * @returns {Promise<string>} prediction ID
 */
export async function storeMundanePrediction(prediction, date) {
    return storePrediction({
        ...prediction,
        source: "mundane_samhita",
        createdDate: date,
        status: "pending",
    });
}

/**
 * Store a validation summary for a mundane reading date.
 *
 * @param {string} date - "YYYY-MM-DD"
 * @param {Object} summary - Validation summary data
 */
export async function storeMundaneValidation(date, summary) {
    return storeValidationSummary(`mundane_${date}`, {
        ...summary,
        source: "mundane_samhita",
    });
}
