/**
 * AI chat telemetry helpers.
 *
 * Pulls the rich, otherwise-ephemeral signals out of a Gemini response
 * (search/grounding usage + token accounting) and persists one flat,
 * queryable analytics doc per request to `aiChatMetrics`.
 *
 * Why a dedicated flat collection instead of the message subcollection:
 * subcollection scatter forces collection-group indexes and slow walks for
 * any analysis. A single top-level collection keyed by time lets us answer
 * "p95 TTFT yesterday", "search-hit rate", "thinking-token spend" with one
 * ordered query.
 */

import { FieldValue } from "firebase-admin/firestore";
import { logger } from "../lib/firebase.js";
import { CHAT_CONFIG } from "../lib/config.js";

/**
 * Extract Google Search grounding info from a Gemini response.
 * @param {Object} response - the resolved generateContentStream().response
 * @returns {{usedSearch: boolean, searchQueries: string[], sourceCount: number, sources: string[]}}
 */
export function extractGrounding(response) {
    const gm = response?.candidates?.[0]?.groundingMetadata;
    if (!gm) {
        return { usedSearch: false, searchQueries: [], sourceCount: 0, sources: [] };
    }

    // webSearchQueries is the authoritative "search actually ran" signal.
    const searchQueries = Array.isArray(gm.webSearchQueries) ? gm.webSearchQueries : [];

    // groundingChunks carry the cited web sources.
    const chunks = Array.isArray(gm.groundingChunks) ? gm.groundingChunks : [];
    const sources = chunks
        .map((c) => c?.web?.domain || c?.web?.title || c?.web?.uri || null)
        .filter(Boolean);

    const usedSearch = searchQueries.length > 0 ||
        sources.length > 0 ||
        !!gm.searchEntryPoint?.renderedContent;

    return {
        usedSearch,
        searchQueries,
        sourceCount: sources.length,
        sources: sources.slice(0, 10), // cap stored payload
    };
}

/**
 * Extract token accounting from a Gemini response.
 * thoughtsTokenCount is what 2.5 models bill for hidden "thinking" — the
 * single most useful number for diagnosing TTFT latency + cost.
 * @param {Object} response
 * @returns {{promptTokens: number, candidatesTokens: number, thoughtsTokens: number, totalTokens: number}}
 */
export function extractUsage(response) {
    const u = response?.usageMetadata || {};
    return {
        promptTokens: u.promptTokenCount || 0,
        candidatesTokens: u.candidatesTokenCount || 0,
        thoughtsTokens: u.thoughtsTokenCount || 0,
        totalTokens: u.totalTokenCount || 0,
    };
}

/**
 * Persist one analytics record. Best-effort: telemetry must never break chat.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} record - flat metrics object (see aiChat handler)
 */
export async function persistMetrics(db, record) {
    try {
        const day = new Date().toISOString().slice(0, 10); // yyyy-mm-dd bucket
        await db.collection(CHAT_CONFIG.METRICS_COLLECTION).add({
            ...record,
            day,
            createdAt: FieldValue.serverTimestamp(),
        });
    } catch (e) {
        // Never let analytics failure surface to the user.
        logger.warn("Failed to persist aiChat metrics", {
            structuredData: true,
            chatId: record?.chatId,
            error: String(e),
        });
    }
}
