/**
 * Signal Store — Structured data persistence for Cosmic Intelligence Agent
 *
 * Manages Firestore collections for:
 * - Signals (active astrological signals)
 * - Predictions (agent's claims about the future)
 * - Validations (daily validation summaries)
 * - Confidence (per-pattern accuracy tracking)
 * - Agent runs (run metadata for monitoring)
 *
 * Collections (under global_astro/):
 *   signals/{signalId}          — active/historical signals
 *   predictions/{predictionId}  — agent predictions with outcomes
 *   validations/{date}          — daily validation summaries
 *   confidence/{patternKey}     — per-pattern confidence scores
 *   agent_runs/{runId}          — execution logs
 */

import { db, logger, FieldValue } from "./firebase.js";

// Collection paths
const SIGNALS_COLLECTION = "global_astro_signals";
const PREDICTIONS_COLLECTION = "global_astro_predictions";
const VALIDATIONS_COLLECTION = "global_astro_validations";
const CONFIDENCE_COLLECTION = "global_astro_confidence";
const AGENT_RUNS_COLLECTION = "global_astro_agent_runs";

// =============================================================================
// SIGNALS — Track what's happening in the sky
// =============================================================================

/**
 * Store or update a signal.
 * Uses signal.id as the document ID for idempotent writes.
 */
export async function upsertSignal(signal) {
    try {
        const docRef = db.collection(SIGNALS_COLLECTION).doc(signal.id);
        const doc = await docRef.get();

        if (!doc.exists) {
            await docRef.set({
                ...signal,
                createdAt: new Date(),
                updatedAt: new Date(),
            });
        } else {
            // Don't overwrite createdAt on update
            const { createdAt, ...signalWithoutCreated } = signal;
            await docRef.update({
                ...signalWithoutCreated,
                updatedAt: new Date(),
            });
        }

        return signal.id;
    } catch (error) {
        logger.error("Error upserting signal", {
            structuredData: true,
            signalId: signal.id,
            error: String(error),
        });
        throw error;
    }
}

/**
 * Batch upsert multiple signals.
 */
export async function upsertSignals(signals) {
    const BATCH_SIZE = 500;
    let written = 0;

    for (let i = 0; i < signals.length; i += BATCH_SIZE) {
        const batch = db.batch();
        const chunk = signals.slice(i, i + BATCH_SIZE);

        for (const signal of chunk) {
            const docRef = db.collection(SIGNALS_COLLECTION).doc(signal.id);
            batch.set(docRef, {
                ...signal,
                updatedAt: new Date(),
            }, { merge: true });
        }

        await batch.commit();
        written += chunk.length;
    }

    return written;
}

/**
 * Get active signals (not ended).
 * @param {Object} [filter]
 * @param {string} [filter.type] - Filter by signal type
 * @param {string} [filter.status] - Filter by status
 * @param {number} [filter.minIntensity] - Minimum intensity
 * @param {number} [filter.limit=50]
 * @returns {Object[]}
 */
export async function getActiveSignals(filter = {}) {
    try {
        let queryRef = db.collection(SIGNALS_COLLECTION);

        if (filter.type) {
            queryRef = queryRef.where("type", "==", filter.type);
        }
        if (filter.status) {
            queryRef = queryRef.where("status", "==", filter.status);
        }

        const snapshot = await queryRef
            .orderBy("intensity", "desc")
            .limit(filter.limit || 50)
            .get();

        let results = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        // Client-side filter for minIntensity (Firestore can't combine inequality + orderBy on different fields easily)
        if (filter.minIntensity) {
            results = results.filter(s => s.intensity >= filter.minIntensity);
        }

        return results;
    } catch (error) {
        logger.error("Error getting active signals", {
            structuredData: true,
            error: String(error),
        });
        return [];
    }
}

/**
 * Mark signals as ended.
 */
export async function endSignals(signalIds) {
    const BATCH_SIZE = 500;
    for (let i = 0; i < signalIds.length; i += BATCH_SIZE) {
        const batch = db.batch();
        const chunk = signalIds.slice(i, i + BATCH_SIZE);
        for (const id of chunk) {
            batch.update(db.collection(SIGNALS_COLLECTION).doc(id), {
                status: "ended",
                endedAt: new Date(),
            });
        }
        await batch.commit();
    }
}

// =============================================================================
// PREDICTIONS — Agent's claims about the future
// =============================================================================

/**
 * Store a new prediction.
 *
 * @param {Object} prediction
 * @param {string} prediction.claim - The prediction text
 * @param {string[]} prediction.domains - Affected domains
 * @param {number} prediction.confidence - 0-1 confidence score
 * @param {string} prediction.signalId - Related signal ID
 * @param {string[]} prediction.searchKeywords - Keywords for validation search
 * @param {string} prediction.resolvesBy - Date by which to validate (ISO string)
 * @param {string} [prediction.reasoning] - Why the agent made this prediction
 * @returns {string} Prediction document ID
 */
export async function storePrediction(prediction) {
    try {
        const docRef = db.collection(PREDICTIONS_COLLECTION).doc();
        await docRef.set({
            ...prediction,
            status: "pending",
            brierScore: null,
            validationEvidence: null,
            validatedAt: null,
            createdAt: new Date(),
        });

        logger.info("Stored prediction", {
            structuredData: true,
            predictionId: docRef.id,
            claim: prediction.claim.substring(0, 100),
            confidence: prediction.confidence,
        });

        return docRef.id;
    } catch (error) {
        logger.error("Error storing prediction", {
            structuredData: true,
            error: String(error),
        });
        throw error;
    }
}

/**
 * Get pending predictions that are due for validation.
 * @param {string} [beforeDate] - ISO date string. Predictions with resolvesBy <= this date.
 * @param {number} [limit=20]
 * @returns {Object[]}
 */
export async function getPendingPredictions(beforeDate = null, limit = 20) {
    try {
        let queryRef = db.collection(PREDICTIONS_COLLECTION)
            .where("status", "==", "pending");

        if (beforeDate) {
            queryRef = queryRef.where("resolvesBy", "<=", beforeDate);
        }

        const snapshot = await queryRef
            .orderBy("resolvesBy", "asc")
            .limit(limit)
            .get();

        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
        logger.error("Error getting pending predictions", {
            structuredData: true,
            error: String(error),
        });
        return [];
    }
}

/**
 * Get recent predictions (for display/review).
 */
export async function getRecentPredictions(limit = 20) {
    try {
        const snapshot = await db.collection(PREDICTIONS_COLLECTION)
            .orderBy("createdAt", "desc")
            .limit(limit)
            .get();

        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
        logger.error("Error getting recent predictions", {
            structuredData: true,
            error: String(error),
        });
        return [];
    }
}

/**
 * Validate a prediction with evidence and outcome.
 *
 * @param {string} predictionId
 * @param {Object} validation
 * @param {string} validation.outcome - "confirmed" | "unconfirmed" | "ambiguous"
 * @param {string} validation.evidence - Evidence text
 * @param {number} validation.actualOutcome - 1 = happened, 0 = didn't (for Brier score)
 */
export async function validatePrediction(predictionId, validation) {
    try {
        const docRef = db.collection(PREDICTIONS_COLLECTION).doc(predictionId);
        const doc = await docRef.get();
        if (!doc.exists) throw new Error(`Prediction ${predictionId} not found`);

        const prediction = doc.data();
        const confidence = prediction.confidence || 0.5;

        // Brier score: (forecast - outcome)² — lower is better
        // forecast = confidence, outcome = 1 (happened) or 0 (didn't)
        const brierScore = Math.pow(confidence - validation.actualOutcome, 2);

        await docRef.update({
            status: validation.outcome,
            validationEvidence: validation.evidence,
            actualOutcome: validation.actualOutcome,
            brierScore: Math.round(brierScore * 1000) / 1000,
            validatedAt: new Date(),
        });

        // Update pattern confidence
        if (prediction.signalId) {
            await updateConfidence(prediction.signalId, brierScore, validation.outcome);
        }

        logger.info("Validated prediction", {
            structuredData: true,
            predictionId,
            outcome: validation.outcome,
            brierScore,
        });

        return { brierScore, outcome: validation.outcome };
    } catch (error) {
        logger.error("Error validating prediction", {
            structuredData: true,
            error: String(error),
            predictionId,
        });
        throw error;
    }
}

// =============================================================================
// CONFIDENCE — Per-pattern accuracy tracking
// =============================================================================

/**
 * Update confidence score for a signal pattern.
 * Tracks running average Brier score and confirmation rate.
 */
async function updateConfidence(signalId, brierScore, outcome) {
    try {
        // Extract pattern key from signal ID (e.g., "aspect:mars-saturn-square" → "mars-saturn-square")
        const patternKey = signalId.replace(/^[^:]+:/, "");
        const docRef = db.collection(CONFIDENCE_COLLECTION).doc(patternKey);
        const doc = await docRef.get();

        if (!doc.exists) {
            // First entry for this pattern
            await docRef.set({
                signalPattern: patternKey,
                totalInstances: 1,
                confirmedInstances: outcome === "confirmed" ? 1 : 0,
                brierScoreSum: brierScore,
                brierScoreAvg: brierScore,
                currentConfidence: outcome === "confirmed" ? 0.6 : 0.4,
                lastUpdated: new Date(),
                history: [{
                    date: new Date().toISOString().split("T")[0],
                    brierScore,
                    outcome,
                }],
            });
        } else {
            const data = doc.data();
            const newTotal = (data.totalInstances || 0) + 1;
            const newConfirmed = (data.confirmedInstances || 0) + (outcome === "confirmed" ? 1 : 0);
            const newBrierSum = (data.brierScoreSum || 0) + brierScore;

            // Confidence = confirmation rate, smoothed
            const rawConfidence = newConfirmed / newTotal;
            // Bayesian smoothing: pull toward 0.5 with small sample sizes
            const smoothed = (rawConfidence * newTotal + 0.5 * 2) / (newTotal + 2);

            const history = (data.history || []).slice(-50); // Keep last 50 entries
            history.push({
                date: new Date().toISOString().split("T")[0],
                brierScore,
                outcome,
            });

            await docRef.update({
                totalInstances: newTotal,
                confirmedInstances: newConfirmed,
                brierScoreSum: newBrierSum,
                brierScoreAvg: Math.round((newBrierSum / newTotal) * 1000) / 1000,
                currentConfidence: Math.round(smoothed * 1000) / 1000,
                lastUpdated: new Date(),
                history,
            });
        }
    } catch (error) {
        logger.warn("Error updating confidence", {
            structuredData: true,
            signalId,
            error: String(error),
        });
    }
}

/**
 * Get confidence for a signal pattern.
 * @param {string} patternKey - e.g., "mars-saturn-square"
 * @returns {Object|null} Confidence data or null if no history
 */
export async function getConfidence(patternKey) {
    try {
        const doc = await db.collection(CONFIDENCE_COLLECTION).doc(patternKey).get();
        if (!doc.exists) return null;
        return { id: doc.id, ...doc.data() };
    } catch (error) {
        logger.warn("Error getting confidence", {
            structuredData: true,
            error: String(error),
        });
        return null;
    }
}

/**
 * Get all confidence scores, sorted by total instances.
 */
export async function getAllConfidence(limit = 50) {
    try {
        const snapshot = await db.collection(CONFIDENCE_COLLECTION)
            .orderBy("totalInstances", "desc")
            .limit(limit)
            .get();

        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
        logger.error("Error getting all confidence", {
            structuredData: true,
            error: String(error),
        });
        return [];
    }
}

// =============================================================================
// VALIDATIONS — Daily summary
// =============================================================================

/**
 * Store a daily validation summary.
 */
export async function storeValidationSummary(dateStr, summary) {
    try {
        await db.collection(VALIDATIONS_COLLECTION).doc(dateStr).set({
            ...summary,
            date: dateStr,
            createdAt: new Date(),
        });
    } catch (error) {
        logger.error("Error storing validation summary", {
            structuredData: true,
            error: String(error),
        });
    }
}

/**
 * Get recent validation summaries.
 */
export async function getRecentValidations(limit = 30) {
    try {
        const snapshot = await db.collection(VALIDATIONS_COLLECTION)
            .orderBy("date", "desc")
            .limit(limit)
            .get();

        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
        logger.error("Error getting recent validations", {
            structuredData: true,
            error: String(error),
        });
        return [];
    }
}

// =============================================================================
// AGENT RUNS — Execution metadata for monitoring
// =============================================================================

/**
 * Log the start of an agent run.
 * @returns {string} Run document ID
 */
export async function logRunStart() {
    const docRef = db.collection(AGENT_RUNS_COLLECTION).doc();
    await docRef.set({
        status: "running",
        startedAt: new Date(),
        completedAt: null,
        duration: null,
        stats: null,
        error: null,
    });
    return docRef.id;
}

/**
 * Log the completion of an agent run.
 */
export async function logRunComplete(runId, stats, error = null) {
    const docRef = db.collection(AGENT_RUNS_COLLECTION).doc(runId);
    const doc = await docRef.get();
    const startedAt = doc.data()?.startedAt?.toDate?.() || new Date();
    const duration = Date.now() - startedAt.getTime();

    await docRef.update({
        status: error ? "error" : "completed",
        completedAt: new Date(),
        duration,
        stats,
        error: error ? String(error) : null,
    });
}

/**
 * Get recent agent runs for monitoring.
 */
export async function getRecentRuns(limit = 10) {
    try {
        const snapshot = await db.collection(AGENT_RUNS_COLLECTION)
            .orderBy("startedAt", "desc")
            .limit(limit)
            .get();

        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
        logger.error("Error getting recent runs", {
            structuredData: true,
            error: String(error),
        });
        return [];
    }
}
