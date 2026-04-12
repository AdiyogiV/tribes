/**
 * Agent Memory Layer — Cosmic Intelligence Agent (Phase 2)
 *
 * Persistent memory for the agent using Firestore + Gemini embeddings.
 * Replaces Mem0 (which uses in-memory vector store — incompatible with
 * stateless Cloud Functions that lose state between invocations).
 *
 * Architecture:
 * - Firestore collection `cosmic_memory` stores memories with vector embeddings
 * - Gemini text-embedding-004 generates 768-dim embeddings
 * - Cosine similarity search for semantic recall
 * - Namespaces isolate different memory types
 *
 * Namespaces:
 *   "observations"  — what the agent noticed in the sky
 *   "predictions"   — claims the agent made
 *   "reflections"   — agent's self-assessments
 *   "research"      — findings from web searches
 *   "patterns"      — recurring signal-outcome correlations
 *
 * Cost: Gemini embedding is essentially free (~$0.00001 per call)
 */

import { db, logger } from "./firebase.js";
import { GoogleGenerativeAI } from "@google/generative-ai";

const MEMORY_COLLECTION = "cosmic_memory";
const EMBEDDING_MODEL = "text-embedding-004";
const EMBEDDING_DIMENSION = 768;
const DEFAULT_TOP_K = 10;
const MAX_MEMORY_AGE_DAYS = 365; // Keep memories for a year

// =============================================================================
// INITIALIZATION
// =============================================================================

let genAI = null;
let embeddingModel = null;

/**
 * Initialize the Gemini client for embeddings.
 * Must be called with the API key at runtime (secrets aren't available at import time).
 */
export function initMemory(geminiApiKeyValue) {
    genAI = new GoogleGenerativeAI(geminiApiKeyValue);
    embeddingModel = genAI.getGenerativeModel({ model: EMBEDDING_MODEL });
}

// =============================================================================
// EMBEDDING
// =============================================================================

/**
 * Generate embedding vector for text.
 * @param {string} text - Text to embed
 * @returns {number[]} 768-dimensional embedding vector
 */
async function embed(text) {
    if (!embeddingModel) {
        throw new Error("Memory not initialized. Call initMemory(apiKey) first.");
    }

    const result = await embeddingModel.embedContent(text);
    return result.embedding.values;
}

/**
 * Cosine similarity between two vectors.
 * @param {number[]} a
 * @param {number[]} b
 * @returns {number} -1 to 1 (1 = identical)
 */
function cosineSimilarity(a, b) {
    if (a.length !== b.length) return 0;
    let dotProduct = 0;
    let normA = 0;
    let normB = 0;
    for (let i = 0; i < a.length; i++) {
        dotProduct += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }
    const denom = Math.sqrt(normA) * Math.sqrt(normB);
    return denom === 0 ? 0 : dotProduct / denom;
}

// =============================================================================
// STORE MEMORY
// =============================================================================

/**
 * Store a memory with its embedding.
 *
 * @param {string} content - The memory text (what the agent observed/learned/predicted)
 * @param {Object} options
 * @param {string} options.namespace - One of: observations, predictions, reflections, research, patterns
 * @param {string[]} [options.tags] - Optional tags for filtering (e.g., ["mars", "square", "saturn"])
 * @param {Object} [options.metadata] - Arbitrary metadata (e.g., { signalId, confidence, date })
 * @param {string} [options.id] - Optional explicit ID (auto-generated if not provided)
 * @returns {string} The memory document ID
 */
export async function storeMemory(content, options = {}) {
    const { namespace = "observations", tags = [], metadata = {}, id = null } = options;

    try {
        const embedding = await embed(content);
        const docRef = id
            ? db.collection(MEMORY_COLLECTION).doc(id)
            : db.collection(MEMORY_COLLECTION).doc();

        const memoryDoc = {
            content,
            namespace,
            tags,
            metadata,
            embedding,
            createdAt: new Date(),
            updatedAt: new Date(),
        };

        await docRef.set(memoryDoc);

        logger.info("Stored memory", {
            structuredData: true,
            memoryId: docRef.id,
            namespace,
            contentLength: content.length,
            tags,
        });

        return docRef.id;
    } catch (error) {
        logger.error("Error storing memory", {
            structuredData: true,
            error: String(error),
            namespace,
        });
        throw error;
    }
}

// =============================================================================
// RECALL MEMORY (Semantic Search)
// =============================================================================

/**
 * Search memories by semantic similarity.
 *
 * @param {string} query - Natural language query
 * @param {Object} [options]
 * @param {string} [options.namespace] - Filter by namespace (null = all)
 * @param {string[]} [options.tags] - Filter: memory must have ALL of these tags
 * @param {number} [options.topK=10] - Max results
 * @param {number} [options.minSimilarity=0.3] - Minimum cosine similarity threshold
 * @param {number} [options.maxAgeDays] - Only return memories newer than this
 * @returns {Object[]} Array of { id, content, namespace, tags, metadata, similarity, createdAt }
 */
export async function recallMemory(query, options = {}) {
    const {
        namespace = null,
        tags = [],
        topK = DEFAULT_TOP_K,
        minSimilarity = 0.3,
        maxAgeDays = null,
    } = options;

    try {
        const queryEmbedding = await embed(query);

        // Build Firestore query
        let queryRef = db.collection(MEMORY_COLLECTION);

        if (namespace) {
            queryRef = queryRef.where("namespace", "==", namespace);
        }

        // Time filter
        if (maxAgeDays) {
            const cutoff = new Date();
            cutoff.setDate(cutoff.getDate() - maxAgeDays);
            queryRef = queryRef.where("createdAt", ">=", cutoff);
        }

        const snapshot = await queryRef.get();

        if (snapshot.empty) {
            return [];
        }

        // Compute similarity for each memory
        const scored = [];
        for (const doc of snapshot.docs) {
            const data = doc.data();

            // Tag filter (must have ALL specified tags)
            if (tags.length > 0) {
                const memTags = data.tags || [];
                if (!tags.every(t => memTags.includes(t))) continue;
            }

            // Compute cosine similarity
            const similarity = cosineSimilarity(queryEmbedding, data.embedding || []);

            if (similarity >= minSimilarity) {
                scored.push({
                    id: doc.id,
                    content: data.content,
                    namespace: data.namespace,
                    tags: data.tags || [],
                    metadata: data.metadata || {},
                    similarity: Math.round(similarity * 1000) / 1000,
                    createdAt: data.createdAt?.toDate?.() || data.createdAt,
                });
            }
        }

        // Sort by similarity descending, take top K
        scored.sort((a, b) => b.similarity - a.similarity);
        const results = scored.slice(0, topK);

        logger.info("Memory recall", {
            structuredData: true,
            query: query.substring(0, 100),
            namespace,
            totalScanned: snapshot.size,
            resultsReturned: results.length,
            topSimilarity: results[0]?.similarity || 0,
        });

        return results;
    } catch (error) {
        logger.error("Error recalling memory", {
            structuredData: true,
            error: String(error),
            query: query.substring(0, 100),
        });
        return [];
    }
}

// =============================================================================
// UPDATE MEMORY
// =============================================================================

/**
 * Update an existing memory's content (re-generates embedding).
 *
 * @param {string} memoryId - Document ID
 * @param {string} newContent - Updated content
 * @param {Object} [metadata] - Updated metadata (merged with existing)
 */
export async function updateMemory(memoryId, newContent, metadata = null) {
    try {
        const embedding = await embed(newContent);
        const update = {
            content: newContent,
            embedding,
            updatedAt: new Date(),
        };
        if (metadata) {
            update.metadata = metadata;
        }

        await db.collection(MEMORY_COLLECTION).doc(memoryId).update(update);

        logger.info("Updated memory", {
            structuredData: true,
            memoryId,
        });
    } catch (error) {
        logger.error("Error updating memory", {
            structuredData: true,
            error: String(error),
            memoryId,
        });
        throw error;
    }
}

// =============================================================================
// DELETE MEMORY
// =============================================================================

/**
 * Delete a specific memory.
 */
export async function deleteMemory(memoryId) {
    await db.collection(MEMORY_COLLECTION).doc(memoryId).delete();
}

// =============================================================================
// LIST MEMORIES (for debugging/inspection)
// =============================================================================

/**
 * List recent memories for a namespace.
 *
 * @param {string} namespace
 * @param {number} [limit=20]
 * @returns {Object[]}
 */
export async function listMemories(namespace, limit = 20) {
    const snapshot = await db.collection(MEMORY_COLLECTION)
        .where("namespace", "==", namespace)
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get();

    return snapshot.docs.map(doc => ({
        id: doc.id,
        content: doc.data().content,
        namespace: doc.data().namespace,
        tags: doc.data().tags || [],
        metadata: doc.data().metadata || {},
        createdAt: doc.data().createdAt?.toDate?.() || doc.data().createdAt,
    }));
}

// =============================================================================
// MEMORY STATS
// =============================================================================

/**
 * Get memory statistics.
 */
export async function getMemoryStats() {
    try {
        const namespaces = ["observations", "predictions", "reflections", "research", "patterns"];
        const stats = {};

        for (const ns of namespaces) {
            const snap = await db.collection(MEMORY_COLLECTION)
                .where("namespace", "==", ns)
                .count()
                .get();
            stats[ns] = snap.data().count;
        }

        return {
            ...stats,
            total: Object.values(stats).reduce((a, b) => a + b, 0),
            timestamp: new Date().toISOString(),
        };
    } catch (error) {
        logger.warn("Error getting memory stats", {
            structuredData: true,
            error: String(error),
        });
        return null;
    }
}

// =============================================================================
// CLEANUP — Remove old memories to prevent unbounded growth
// =============================================================================

/**
 * Clean up old memories beyond retention period.
 * Keeps reflections and patterns longer (they're the agent's learned knowledge).
 */
export async function cleanupOldMemories() {
    const BATCH_SIZE = 500;
    const now = new Date();
    let deletedCount = 0;

    const retentionDays = {
        observations: 90,     // Raw observations: 3 months
        research: 180,        // Research findings: 6 months
        predictions: 365,     // Predictions: 1 year (for validation)
        reflections: 730,     // Reflections: 2 years (core learning)
        patterns: 730,        // Patterns: 2 years (core learning)
    };

    try {
        for (const [namespace, days] of Object.entries(retentionDays)) {
            const cutoff = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
            const snapshot = await db.collection(MEMORY_COLLECTION)
                .where("namespace", "==", namespace)
                .where("createdAt", "<", cutoff)
                .get();

            if (snapshot.empty) continue;

            for (let i = 0; i < snapshot.docs.length; i += BATCH_SIZE) {
                const batch = db.batch();
                const chunk = snapshot.docs.slice(i, i + BATCH_SIZE);
                chunk.forEach(doc => batch.delete(doc.ref));
                await batch.commit();
                deletedCount += chunk.length;
            }
        }

        logger.info("Memory cleanup completed", {
            structuredData: true,
            deletedCount,
        });

        return { deletedCount };
    } catch (error) {
        logger.error("Error during memory cleanup", {
            structuredData: true,
            error: String(error),
        });
        return { deletedCount: 0, error: String(error) };
    }
}
