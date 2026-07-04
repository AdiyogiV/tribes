/**
 * Runtime Configuration
 *
 * Environment-tunable values that change without a code rewrite.
 * - config.js (this file): runtime tuning — AI models, chat generation knobs
 * - constants.js: static domain constants (collections, endpoints, TTLs)
 * - secrets.js: sensitive credentials (defineSecret / defineString)
 */

// =============================================================================
// AI MODEL CONFIGURATION
// =============================================================================

export const AI_MODELS = {
    // Gemini model for insights and interpretations
    GEMINI_FLASH: "gemini-2.5-flash",
    GEMINI_PRO: "gemini-1.5-pro",
};

// =============================================================================
// CHAT CONFIGURATION
// =============================================================================

export const CHAT_CONFIG = {
    // Maximum history messages to include in AI context.
    // History rides in `contents` (variable per turn) so it is NOT covered by
    // Gemini implicit prefix caching the way the system prompt is — every extra
    // turn here is full-price input tokens, re-sent on every message. 10 keeps
    // ample continuity while ~halving multi-turn input cost vs 20.
    MAX_HISTORY_MESSAGES: 10,
    // Typing indicator timeout
    TYPING_TIMEOUT_MS: 10000,

    // ── Gemini generation tuning ────────────────────────────────────────
    // gemini-2.5-flash enables "thinking" by default, which adds multiple
    // seconds of latency BEFORE the first visible token (thoughts aren't
    // streamed as text). For an interactive chat we trade that hidden
    // reasoning for snappiness: budget 0 = thinking off. Bump to e.g. 512
    // if answer quality on complex chart interpretation regresses.
    THINKING_BUDGET: 0,
    // Sampling temperature. 0.75 is the sweet spot for snappy text-style chat:
    // warm and varied enough to feel human, cool enough that the model stops
    // creative-rambling and respects the LENGTH rules. 0.9 was producing essays
    // (53% of replies >500 chars; some 1800+); 0.75 lands in the 200-400 char
    // band the prompt actually targets. Push to 0.8 if it starts feeling flat.
    TEMPERATURE: 0.85,
    // Hard physical cap on output size. THIS IS THE LEVER that enforces "snappy".
    // Prompt-level "60 to 80 words, never more" is a soft request the model
    // overrides on deep-feeling questions. With MAX_OUTPUT_TOKENS = 2048 it had
    // ~1500 words of physical room to ramble. 220 ≈ 165 words: enough for an
    // 80-word reply with reasoning headroom, hard ceiling on essays. Bump only
    // if you genuinely need longer (e.g. structured reports).
    MAX_OUTPUT_TOKENS: 320,
    // Collection that stores one flat, queryable analytics doc per request.
    METRICS_COLLECTION: "aiChatMetrics",
};
