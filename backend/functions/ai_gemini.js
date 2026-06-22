/**
 * Gemini streaming core for the AI chat endpoint.
 *
 * One unified streaming path for text + audio user turns, with grounding
 * (Google Search) and token telemetry extraction. Kept separate from the
 * HTTP handler in ai.js so each file stays cohesive and under the line cap.
 */

import { logger } from "../lib/firebase.js";
import { getVertexAI, extractChunkText } from "../lib/vertex_client.js";
import { getChatSystemPrompt } from "./prompts/chat.js";
import { AI_MODELS, CHAT_CONFIG } from "../lib/config.js";
import { extractGrounding, extractUsage } from "./ai_telemetry.js";

const MAX_HISTORY_MESSAGES = CHAT_CONFIG.MAX_HISTORY_MESSAGES;


// =============================================================================
// HELPER: Build proper Gemini multi-turn conversation format
// =============================================================================
function buildGeminiContents(messages, maxHistoryMessages = MAX_HISTORY_MESSAGES) {
    if (!messages || messages.length === 0) {
        return [];
    }

    const contents = [];
    const recentMessages = messages.slice(-maxHistoryMessages);

    for (const msg of recentMessages) {
        // Gemini API requires "model" role instead of "assistant"
        const role = msg.role === "assistant" ? "model" : "user";
        contents.push({
            role,
            parts: [{ text: msg.content }],
        });
    }

    return contents;
}

// =============================================================================
// GEMINI STREAMING (unified text + audio)
// =============================================================================

/**
 * Download an audio attachment and return inline-data parts for Gemini.
 * Kept separate so the streaming core stays readable.
 * @param {string} audioUrl
 * @param {string} chatId
 * @returns {Promise<Array>} Gemini `parts` array for the current user turn
 */
async function buildAudioParts(audioUrl, chatId) {
    let mimeType = "audio/wav";
    if (audioUrl.includes(".mp3")) mimeType = "audio/mp3";
    else if (audioUrl.includes(".m4a")) mimeType = "audio/mp4";
    else if (audioUrl.includes(".ogg")) mimeType = "audio/ogg";
    else if (audioUrl.includes(".webm")) mimeType = "audio/webm";

    const audioResponse = await fetch(audioUrl);
    if (!audioResponse.ok) {
        throw new Error(`Failed to fetch audio: ${audioResponse.status}`);
    }
    const audioBuffer = await audioResponse.arrayBuffer();
    const audioBase64 = Buffer.from(audioBuffer).toString("base64");

    logger.info("Audio downloaded", {
        structuredData: true, chatId, audioSize: audioBuffer.byteLength, mimeType,
    });

    return [
        { text: "Listen to and respond to this voice message:" },
        { inlineData: { mimeType, data: audioBase64 } },
    ];
}

/**
 * Stream a Gemini response for either a text or an audio user message.
 *
 * One code path for both modalities — the ONLY difference is how the final
 * user turn's `parts` are built (plain text vs. text + inline audio).
 *
 * @returns {Promise<{text: string, grounding: Object, usage: Object,
 *                     chunkCount: number, audioFetchMs: number}>}
 */
async function streamFromGemini({
    chatId, messages, write, userMessage = null, audioUrl = null,
    astrologyContext = null, userLocation = null, voiceStyle = false,
    onFirstToken = null,
}) {
    const isAudio = !!audioUrl;
    logger.info("Starting Gemini processing", {
        structuredData: true,
        chatId,
        modality: isAudio ? "audio" : "text",
        hasAstrology: !!astrologyContext,
        hasLocation: !!userLocation,
        messageLength: userMessage?.length || 0,
    });

    const vertexAI = getVertexAI();
    // Always include the search tool — the system prompt instructs the model to
    // only invoke it for genuinely live/current data needs.
    const model = vertexAI.getGenerativeModel({
        model: AI_MODELS.GEMINI_FLASH,
        tools: [{ googleSearch: {} }],
        generationConfig: {
            temperature: CHAT_CONFIG.TEMPERATURE,
            maxOutputTokens: CHAT_CONFIG.MAX_OUTPUT_TOKENS,
            // Turn off (or cap) 2.5-flash "thinking" — it otherwise burns
            // several seconds before the first visible token.
            thinkingConfig: { thinkingBudget: CHAT_CONFIG.THINKING_BUDGET },
        },
    });

    // Spoken-length style when the turn is audio OR a voice-relay text turn.
    const systemPrompt = getChatSystemPrompt(
        astrologyContext, userLocation, isAudio || voiceStyle);

    // History = everything but the current (last) user message.
    const contents = buildGeminiContents(messages.slice(0, -1));

    // Build the current user turn.
    let audioFetchMs = 0;
    let currentParts;
    if (isAudio) {
        const t0 = Date.now();
        currentParts = await buildAudioParts(audioUrl, chatId);
        audioFetchMs = Date.now() - t0;
    } else {
        currentParts = [{ text: userMessage }];
    }
    contents.push({ role: "user", parts: currentParts });

    let accumulated = "";
    let chunkCount = 0;
    let firstTokenReceived = false;
    let response;

    try {
        const result = await model.generateContentStream({
            contents,
            systemInstruction: systemPrompt,
        });

        for await (const chunk of result.stream) {
            const text = extractChunkText(chunk);
            if (text) {
                if (!firstTokenReceived) {
                    firstTokenReceived = true;
                    if (onFirstToken) onFirstToken();
                }
                chunkCount++;
                accumulated += text;
                write({ event: "token", content: text });
            }
        }
        response = await result.response;
    } catch (e) {
        logger.error("Gemini streaming failed", {
            structuredData: true, chatId, modality: isAudio ? "audio" : "text", error: String(e),
        });
        throw e;
    }

    if (!accumulated.trim()) {
        throw new Error("Gemini returned empty response");
    }

    const grounding = extractGrounding(response);
    const usage = extractUsage(response);

    logger.info("Gemini response complete", {
        structuredData: true,
        chatId,
        modality: isAudio ? "audio" : "text",
        responseLength: accumulated.length,
        chunkCount,
        usedSearch: grounding.usedSearch,
        searchQueries: grounding.searchQueries,
        sourceCount: grounding.sourceCount,
        promptTokens: usage.promptTokens,
        candidatesTokens: usage.candidatesTokens,
        thoughtsTokens: usage.thoughtsTokens,
        totalTokens: usage.totalTokens,
    });

    return { text: accumulated, grounding, usage, chunkCount, audioFetchMs };
}

export { streamFromGemini };
