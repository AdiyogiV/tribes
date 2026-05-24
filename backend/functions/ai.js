import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../lib/firebase.js";
import { db, FieldValue } from "../lib/firebase.js";
import { geminiApiKey } from "../lib/secrets.js";
import { getChatSystemPrompt } from "./prompts/chat.js";
import { getDashaMeaning, getHouseMeaning, getTransitMeaning } from "../lib/search.js";
import { getDailySearchContext } from "../lib/astro_context.js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { checkRateLimit as checkPersistentRateLimit, RATE_LIMIT_PRESETS } from "../lib/rate_limiter.js";
import { CHAT_CONFIG, AI_MODELS } from "../lib/config.js";
import { normalizeDasha } from "../lib/astro_helpers.js";

// =============================================================================
// TOPIC-AWARE ASTROLOGY SEARCH SYSTEM
// Detects question topic and fetches relevant cached knowledge
// =============================================================================

/**
 * Detect the life area/topic from user's astrology question
 * @param {string} message - User's message
 * @returns {string} Topic: "career" | "relationships" | "health" | "children" | "wealth" | "spirituality" | "general"
 */
function detectAstroQuestionTopic(message) {
    const msg = message.toLowerCase();

    // Career & Work
    const careerPattern = /\b(job|career|work|business|profession|promotion|boss|office|company)\b/;
    const careerPattern2 = /\b(interview|resign|fired|salary|employment|entrepreneur|startup|venture)\b/;
    if (careerPattern.test(msg) || careerPattern2.test(msg)) {
        return "career";
    }

    // Relationships & Marriage
    const relPattern = /\b(marriage|married|marry|love|relationship|partner|spouse|wife|husband)\b/;
    const relPattern2 = /\b(dating|boyfriend|girlfriend|divorce|engagement|romance|soulmate|wedding)\b/;
    if (relPattern.test(msg) || relPattern2.test(msg)) {
        return "relationships";
    }

    // Health & Wellness
    const healthPattern = /\b(health|sick|disease|illness|body|energy|tired|fatigue|medical)\b/;
    const healthPattern2 = /\b(doctor|hospital|surgery|medicine|recovery|wellness|mental|anxiety|depression|stress)\b/;
    if (healthPattern.test(msg) || healthPattern2.test(msg)) {
        return "health";
    }

    // Children & Family
    const childPattern = /\b(child|children|baby|babies|pregnant|pregnancy|son|daughter)\b/;
    const childPattern2 = /\b(kids|fertility|conception|mother|father|parent|family)\b/;
    if (childPattern.test(msg) || childPattern2.test(msg)) {
        return "children";
    }

    // Wealth & Finance
    const wealthPattern = /\b(money|wealth|finance|income|rich|property|investment|savings)\b/;
    const wealthPattern2 = /\b(debt|loan|profit|loss|business|stock|crypto|inheritance|prosperity)\b/;
    if (wealthPattern.test(msg) || wealthPattern2.test(msg)) {
        return "wealth";
    }

    // Spirituality & Growth
    const spiritPattern = /\b(spiritual|spirituality|meditation|moksha|enlightenment|guru)\b/;
    const spiritPattern2 = /\b(temple|worship|mantra|karma|dharma|path|purpose|meaning|soul)\b/;
    if (spiritPattern.test(msg) || spiritPattern2.test(msg)) {
        return "spirituality";
    }

    // Education & Learning
    const eduPattern = /\b(education|study|exam|degree|college|university|school|learn|course|competitive|entrance|abroad)\b/;
    if (eduPattern.test(msg)) {
        return "education";
    }

    // Travel & Relocation
    const travelPattern = /\b(travel|abroad|foreign|move|relocate|immigration|visa|settle|country|city)\b/;
    if (travelPattern.test(msg)) {
        return "travel";
    }

    return "general";
}

/**
 * Get relevant houses for a given life topic (Vedic astrology)
 * @param {string} topic - Life area topic
 * @returns {number[]} Array of relevant house numbers
 */
function getRelevantHousesForTopic(topic) {
    const TOPIC_HOUSES = {
        career: [10, 6, 2, 11],
        relationships: [7, 5, 2, 8],
        health: [1, 6, 8, 12],
        children: [5, 9, 2, 7],
        wealth: [2, 11, 5, 9],
        spirituality: [9, 12, 5, 8],
        education: [4, 5, 9, 2],
        travel: [9, 12, 3, 7],
        general: [1, 10, 7, 4],
    };
    return TOPIC_HOUSES[topic] || TOPIC_HOUSES.general;
}

/**
 * Fetch topic-specific knowledge using EXISTING cached search functions
 * This is highly efficient - results are cached forever after first search
 * @param {Object} params - Parameters
 * @returns {Object} Topic-specific knowledge from cached searches
 */
async function fetchTopicSpecificKnowledge({ topic, mahaDasha, antarDasha, relevantHouses, currentTransits }) {
    const knowledge = { topic };

    const searchPromises = [];

    // 1. Topic-specific dasha interpretation (cached forever)
    if (mahaDasha && antarDasha) {
        const dashaArea = topic === "general" ? "general" : topic;
        searchPromises.push(
            getDashaMeaning(mahaDasha, antarDasha, dashaArea)
                .then((result) => {
                    knowledge.dashaForTopic = result;
                })
                .catch(() => { }),
        );
    }

    // 2. Primary house meaning for this topic (cached forever)
    const primaryHouse = relevantHouses[0];
    if (primaryHouse) {
        searchPromises.push(
            getHouseMeaning(primaryHouse)
                .then((result) => {
                    knowledge.primaryHouseMeaning = result;
                })
                .catch(() => { }),
        );
    }

    // 3. If we have current transits, get transit-to-relevant-house meanings
    if (currentTransits && relevantHouses.length > 0) {
        // Find which planets are transiting the relevant houses
        const relevantTransits = [];
        for (const [planet, data] of Object.entries(currentTransits)) {
            if (data?.house && relevantHouses.includes(data.house)) {
                relevantTransits.push({ planet, house: data.house });
            }
        }

        // Fetch transit meanings for up to 2 most relevant transits
        for (const transit of relevantTransits.slice(0, 2)) {
            searchPromises.push(
                getTransitMeaning(transit.planet, transit.house)
                    .then((result) => {
                        if (!knowledge.relevantTransitMeanings) knowledge.relevantTransitMeanings = [];
                        knowledge.relevantTransitMeanings.push(result);
                    })
                    .catch(() => { }),
            );
        }
    }

    // Execute all searches in parallel
    await Promise.all(searchPromises);

    return knowledge;
}

// House lords based on Lagna (Vedic astrology - whole sign houses)
const ZODIAC_SIGNS = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"];
const SIGN_RULERS = {
    "Aries": "Mars", "Taurus": "Venus", "Gemini": "Mercury", "Cancer": "Moon",
    "Leo": "Sun", "Virgo": "Mercury", "Libra": "Venus", "Scorpio": "Mars",
    "Sagittarius": "Jupiter", "Capricorn": "Saturn", "Aquarius": "Saturn", "Pisces": "Jupiter",
};

/**
 * Calculate house lords based on Lagna (deterministic - no API call needed)
 * @param {string} lagna - Ascendant sign
 * @returns {Object|null} House lords object
 */
function calculateHouseLords(lagna) {
    if (!lagna) return null;

    const lagnaIndex = ZODIAC_SIGNS.findIndex((sign) =>
        sign.toLowerCase() === lagna.toLowerCase(),
    );
    if (lagnaIndex === -1) return null;

    const houseLords = {};
    for (let h = 1; h <= 12; h++) {
        const signIndex = (lagnaIndex + h - 1) % 12;
        const sign = ZODIAC_SIGNS[signIndex];
        houseLords[h] = {
            sign,
            lord: SIGN_RULERS[sign],
        };
    }
    return houseLords;
}

// =============================================================================
// CONFIGURATION
// =============================================================================

// Using centralized config from lib/config.js
const MAX_HISTORY_MESSAGES = CHAT_CONFIG.MAX_HISTORY_MESSAGES;

// =============================================================================
// MAIN AI CHAT ENDPOINT
// =============================================================================

export const aiChat = onRequest(
    {
        region: "asia-southeast2",
        secrets: [geminiApiKey],
        cors: [/^.*$/],
        timeoutSeconds: 300,
        memory: "512MiB",
        invoker: "public",
        cpu: 1,
        concurrency: 40,
    },
    async (req, res) => {
        if (req.method === "OPTIONS") {
            res.set("Access-Control-Allow-Origin", "*");
            res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
            return res.status(204).send("");
        }

        // Rate limiting - use IP address as identifier (public endpoint)
        const clientIp = req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
            req.connection?.remoteAddress ||
            "unknown";

        // Use persistent rate limiter that survives cold starts
        const rateLimitResult = await checkPersistentRateLimit("ai_chat", {
            ...RATE_LIMIT_PRESETS.AI_CHAT,
            identifier: clientIp,
        });

        if (!rateLimitResult.allowed) {
            const retryAfterSeconds = Math.ceil(rateLimitResult.retryAfterMs / 1000);
            logger.warn("Rate limit exceeded", {
                structuredData: true,
                clientIp,
                remaining: rateLimitResult.remaining,
                resetAt: rateLimitResult.resetAt,
            });
            res.set("Access-Control-Allow-Origin", "*");
            res.set("Retry-After", String(retryAfterSeconds));
            return res.status(429).json({
                error: "Rate limit exceeded. Please wait a moment before trying again.",
                retryAfter: retryAfterSeconds,
            });
        }

        const write = (data) => {
            res.write(`data: ${JSON.stringify(data)}\n\n`);
        };

        try {
            const body = parseBody(req);
            const messages = normaliseMessages(body.messages);

            // Log request metadata (NO message content - PII protection)
            logger.info("AI chat request received", {
                structuredData: true,
                chatId: body.chatId,
                messageCount: messages.length,
                messageLengths: messages.map((msg) => msg.content?.length || 0),
                lastMessageLength: messages[messages.length - 1]?.content?.length || 0,
            });

            if (messages.length === 0) {
                res.set("Access-Control-Allow-Origin", "*");
                return res.status(400).json({ error: "No messages provided" });
            }

            const chatId = body.chatId ? String(body.chatId) : `chat-${Date.now()}`;
            const userMessage = messages[messages.length - 1]?.content;
            const astrologyContext = body.astrologyContext || null;
            const userLocation = body.location || null;
            const audioUrl = body.audioUrl || null;
            // Preserve explicit chatSource from dedicated pages (astrology/wellness).
            // null = unified HolyCow mode (main chat with auto-loaded context).
            const chatSource = body.chatSource || null;

            logger.info("AI chat context", {
                structuredData: true,
                chatId,
                chatSource,
                hasLocation: !!userLocation,
                location: userLocation,
                hasAstrology: !!astrologyContext,
                hasAudio: !!audioUrl,
            });

            if (astrologyContext) {
                logger.info("Received astrology context", {
                    structuredData: true,
                    chatId,
                    hasAscendant: !!astrologyContext.ascendant,
                    hasMoonSign: !!astrologyContext.moonSign,
                    hasSunSign: !!astrologyContext.sunSign,
                    hasNakshatra: !!astrologyContext.nakshatra,
                    hasDasha: !!astrologyContext.currentDasha,
                    hasDailyInsight: !!astrologyContext.dailyInsight,
                });
            }

            if (!userMessage) {
                res.set("Access-Control-Allow-Origin", "*");
                return res.status(400).json({ error: "Last user message is empty" });
            }

            await initialiseSession(chatId);

            res.setHeader("Cache-Control", "no-cache");
            res.setHeader("Content-Type", "text/event-stream");
            res.setHeader("Connection", "keep-alive");
            res.flushHeaders();

            write({ event: "session", chatId, firestorePath: `ai_chat_sessions/${chatId}` });

            // Performance tracking
            const performanceMetrics = {
                startTime: Date.now(),
                synthesisStart: null,
                synthesisEnd: null,
                firstTokenTime: null,
                totalTime: null,
            };

            // Enrich astrology context only for astrology chat (not wellness)
            if (astrologyContext && chatSource !== "wellness") {
                await enrichAstrologyContext(astrologyContext, userMessage, chatId);
            }

            // Route to appropriate handler based on input type
            let accumulated = "";
            performanceMetrics.synthesisStart = Date.now();

            if (audioUrl) {
                // Audio message - use Gemini audio processing
                logger.info("Routing to Gemini for audio processing", {
                    structuredData: true,
                    chatId,
                    audioUrl,
                    hasAstrology: !!astrologyContext,
                });

                accumulated = await streamFromGemini({
                    chatId,
                    audioUrl,
                    messages,
                    write,
                    astrologyContext,
                    userLocation,
                    chatSource,
                    onFirstToken: () => {
                        if (!performanceMetrics.firstTokenTime) {
                            performanceMetrics.firstTokenTime = Date.now();
                        }
                    },
                });
            } else {
                // Text message - use Gemini text processing
                logger.info("Routing to Gemini for text processing", {
                    structuredData: true,
                    chatId,
                    hasAstrology: !!astrologyContext,
                    hasLocation: !!userLocation,
                });

                accumulated = await streamFromGeminiText({
                    chatId,
                    userMessage,
                    messages,
                    write,
                    astrologyContext,
                    userLocation,
                    chatSource,
                    onFirstToken: () => {
                        if (!performanceMetrics.firstTokenTime) {
                            performanceMetrics.firstTokenTime = Date.now();
                        }
                    },
                });
            }

            performanceMetrics.synthesisEnd = Date.now();
            performanceMetrics.totalTime = Date.now() - performanceMetrics.startTime;

            const metrics = {
                synthesis_ms: performanceMetrics.synthesisEnd - performanceMetrics.synthesisStart,
                ttft_ms: performanceMetrics.firstTokenTime ? performanceMetrics.firstTokenTime - performanceMetrics.synthesisStart : null,
                total_ms: performanceMetrics.totalTime,
                queryType: audioUrl ? "gemini_audio" : "gemini_text",
                responseLength: accumulated.length,
            };

            logger.info("Performance: Complete request metrics", {
                structuredData: true,
                chatId,
                ...metrics,
            });

            await db.collection("ai_chat_sessions").doc(chatId).update({
                status: "completed",
                response: accumulated,
                updatedAt: FieldValue.serverTimestamp(),
                completedAt: FieldValue.serverTimestamp(),
                performanceMetrics: metrics,
            });

            write({ event: "complete", content: accumulated });
            res.end();
        } catch (error) {
            logger.error("aiChat streaming failed", {
                structuredData: true,
                error: String(error),
            });

            try {
                const chatId = req.body?.chatId;
                if (chatId) {
                    await saveFailure(chatId, error.message || "Unknown error");
                }
            } catch (persistError) {
                logger.error("Failed to record streaming failure", {
                    structuredData: true,
                    error: String(persistError),
                });
            }

            write({ event: "error", error: error.message || "Unknown error" });
            res.end();
        }
    },
);

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function parseBody(req) {
    if (req.body && typeof req.body === "object") {
        return req.body;
    }

    if (req.rawBody) {
        try {
            return JSON.parse(Buffer.from(req.rawBody).toString("utf8"));
        } catch (error) {
            throw new Error("Body must be valid JSON");
        }
    }

    return {};
}

function normaliseMessages(rawMessages) {
    if (!Array.isArray(rawMessages)) {
        return [];
    }

    return rawMessages
        .map((item) => ({
            role: item?.role === "assistant" ? "assistant" : "user",
            content: String(item?.content ?? "").trim(),
        }))
        .filter((message) => message.content.length > 0);
}

async function initialiseSession(chatId) {
    // Reset sequence counter for this chat
    stepSequenceCounters.set(chatId, 0);

    // Reset session for new request
    await db.collection("ai_chat_sessions").doc(chatId).set({
        chatId,
        status: "processing",
        thoughtSteps: [],
        response: null,
        error: null,
        searchResults: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
    }, { merge: false });
}

async function saveFailure(chatId, error) {
    await db.collection("ai_chat_sessions").doc(chatId).update({
        status: "failed",
        error,
        updatedAt: FieldValue.serverTimestamp(),
    });
}

/**
 * Enrich astrology context with cached cosmic data and topic-specific knowledge
 */
async function enrichAstrologyContext(astrologyContext, userMessage, chatId) {
    logger.info("Enriching astrology context", {
        structuredData: true,
        chatId,
        hasAscendant: !!astrologyContext.ascendant,
        hasMoonSign: !!astrologyContext.moonSign,
    });

    // Load cached GLOBAL cosmic data (retrogrades, moon phase, etc.)
    try {
        const cachedSearchContext = await getDailySearchContext();
        if (cachedSearchContext) {
            if (!astrologyContext.cosmicWeather) {
                astrologyContext.cosmicWeather = {};
            }
            astrologyContext.cosmicWeather = {
                ...astrologyContext.cosmicWeather,
                retrogrades: astrologyContext.cosmicWeather.retrogrades || cachedSearchContext.global?.events?.retrogrades || [],
                moonPhase: astrologyContext.cosmicWeather.moonPhase || cachedSearchContext.global?.events?.moonPhase,
                eclipse: astrologyContext.cosmicWeather.eclipse || cachedSearchContext.global?.events?.eclipse,
                todayNews: astrologyContext.cosmicWeather.todayNews || cachedSearchContext.global?.todayNews?.summary?.substring(0, 400),
                weekly: astrologyContext.cosmicWeather.weekly || cachedSearchContext.global?.weekly?.overview?.substring(0, 300),
            };

            if (!astrologyContext.retrogradeGuides && cachedSearchContext.retrogradeGuides) {
                astrologyContext.retrogradeGuides = cachedSearchContext.retrogradeGuides;
            }
        }
    } catch (error) {
        logger.warn("Failed to load cached cosmic intelligence", { error: String(error) });
    }

    // Topic-aware knowledge loading
    try {
        const questionTopic = detectAstroQuestionTopic(userMessage);
        const relevantHouses = getRelevantHousesForTopic(questionTopic);

        const { mahaDasha, antarDasha } = normalizeDasha(astrologyContext.currentDasha);

        const topicKnowledge = await fetchTopicSpecificKnowledge({
            topic: questionTopic,
            mahaDasha,
            antarDasha,
            relevantHouses,
            currentTransits: astrologyContext.todayTransits,
        });

        astrologyContext.topicKnowledge = topicKnowledge;
        astrologyContext.questionTopic = questionTopic;
        astrologyContext.relevantHouses = relevantHouses;

        if (astrologyContext.ascendant) {
            astrologyContext.houseLords = calculateHouseLords(astrologyContext.ascendant);
        }

        logger.info("Astrology context enriched", {
            structuredData: true,
            chatId,
            topic: questionTopic,
            hasCosmicWeather: !!astrologyContext.cosmicWeather,
            hasTopicKnowledge: !!topicKnowledge,
            hasHouseLords: !!astrologyContext.houseLords,
        });
    } catch (topicError) {
        logger.warn("Topic enrichment failed, continuing", { error: String(topicError) });
    }
}

// =============================================================================
// GEMINI STREAMING - AUDIO
// =============================================================================

/**
 * Stream response from Gemini for audio messages
 * Gemini understands the audio directly (no transcription needed)
 */
async function streamFromGemini({ chatId, audioUrl, messages, write, astrologyContext = null, userLocation = null, chatSource = "astrology", onFirstToken = null }) {
    const apiKey = geminiApiKey.value();

    if (!apiKey) {
        throw new Error("Gemini API key missing");
    }

    logger.info("Starting Gemini audio processing", {
        structuredData: true,
        chatId,
        hasAudio: !!audioUrl,
        hasAstrology: !!astrologyContext,
        hasLocation: !!userLocation,
    });

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: AI_MODELS.GEMINI_FLASH,
        tools: [{ googleSearch: {} }],
    });

    // Download audio from Firebase Storage URL
    let audioBase64;
    let mimeType = "audio/wav";

    try {
        const audioResponse = await fetch(audioUrl);
        if (!audioResponse.ok) {
            throw new Error(`Failed to fetch audio: ${audioResponse.status}`);
        }

        const audioBuffer = await audioResponse.arrayBuffer();
        audioBase64 = Buffer.from(audioBuffer).toString("base64");

        // Detect mime type from URL
        if (audioUrl.includes(".mp3")) mimeType = "audio/mp3";
        else if (audioUrl.includes(".m4a")) mimeType = "audio/mp4";
        else if (audioUrl.includes(".ogg")) mimeType = "audio/ogg";
        else if (audioUrl.includes(".webm")) mimeType = "audio/webm";

        logger.info("Audio downloaded successfully", {
            structuredData: true,
            chatId,
            audioSize: audioBuffer.byteLength,
            mimeType,
        });
    } catch (e) {
        logger.error("Failed to download audio", {
            structuredData: true,
            chatId,
            error: String(e),
            audioUrl,
        });
        throw new Error(`Failed to download audio: ${e.message}`);
    }

    const systemPrompt = getChatSystemPrompt(astrologyContext, userLocation, true, chatSource);

    const historyText = messages.slice(-MAX_HISTORY_MESSAGES).map((msg) => {
        return `${msg.role === "assistant" ? "Assistant" : "User"}: ${msg.content}`;
    }).join("\n\n");

    const parts = [
        { text: systemPrompt },
    ];

    if (historyText.trim()) {
        parts.push({ text: "\n\n=== CONVERSATION HISTORY ===\n" + historyText });
    }

    parts.push({ text: "\n\n=== USER'S VOICE MESSAGE ===\nListen to and respond to this voice message:" });
    parts.push({
        inlineData: {
            mimeType,
            data: audioBase64,
        },
    });

    let accumulated = "";
    let firstTokenReceived = false;

    try {
        const result = await model.generateContentStream(parts);

        for await (const chunk of result.stream) {
            const text = chunk.text();
            if (text) {
                if (!firstTokenReceived) {
                    firstTokenReceived = true;
                    if (onFirstToken) onFirstToken();
                }
                accumulated += text;
                write({ event: "token", content: text });
            }
        }

        // Check for grounding metadata
        const response = await result.response;
        const groundingMetadata = response.candidates?.[0]?.groundingMetadata;
        if (groundingMetadata?.searchEntryPoint?.renderedContent) {
            logger.info("Gemini used Google Search grounding", {
                structuredData: true,
                chatId,
                hasSearchResults: true,
            });
        }

    } catch (e) {
        logger.error("Gemini streaming failed", {
            structuredData: true,
            chatId,
            error: String(e),
        });
        throw e;
    }

    if (!accumulated.trim()) {
        throw new Error("Gemini returned empty response");
    }

    logger.info("Gemini response complete", {
        structuredData: true,
        chatId,
        responseLength: accumulated.length,
    });

    return accumulated;
}

// =============================================================================
// GEMINI STREAMING - TEXT
// =============================================================================

/**
 * Stream response from Gemini for text messages
 * Uses built-in Google Search grounding
 */
async function streamFromGeminiText({ chatId, userMessage, messages, write, astrologyContext = null, userLocation = null, chatSource = "astrology", onFirstToken = null }) {
    const apiKey = geminiApiKey.value();

    if (!apiKey) {
        throw new Error("Gemini API key missing");
    }

    logger.info("Starting Gemini text processing", {
        structuredData: true,
        chatId,
        hasAstrology: !!astrologyContext,
        hasLocation: !!userLocation,
        messageLength: userMessage?.length || 0,
    });

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: AI_MODELS.GEMINI_FLASH,
        tools: [{ googleSearch: {} }],
    });

    const systemPrompt = getChatSystemPrompt(astrologyContext, userLocation, false, chatSource);

    const historyText = messages.slice(-MAX_HISTORY_MESSAGES).map((msg) => {
        return `${msg.role === "assistant" ? "Assistant" : "User"}: ${msg.content}`;
    }).join("\n\n");

    const parts = [
        { text: systemPrompt },
    ];

    if (historyText.trim()) {
        parts.push({ text: "\n\n=== CONVERSATION HISTORY ===\n" + historyText });
    }

    parts.push({ text: "\n\n=== USER'S MESSAGE ===\n" + userMessage });

    let accumulated = "";
    let firstTokenReceived = false;

    try {
        const result = await model.generateContentStream(parts);

        for await (const chunk of result.stream) {
            const text = chunk.text();
            if (text) {
                if (!firstTokenReceived) {
                    firstTokenReceived = true;
                    if (onFirstToken) onFirstToken();
                }
                accumulated += text;
                write({ event: "token", content: text });
            }
        }

        // Check for grounding metadata
        const response = await result.response;
        const groundingMetadata = response.candidates?.[0]?.groundingMetadata;
        if (groundingMetadata?.searchEntryPoint?.renderedContent) {
            logger.info("Gemini used Google Search grounding for text", {
                structuredData: true,
                chatId,
                hasSearchResults: true,
            });
        }

    } catch (e) {
        logger.error("Gemini text streaming failed", {
            structuredData: true,
            chatId,
            error: String(e),
        });
        throw e;
    }

    if (!accumulated.trim()) {
        throw new Error("Gemini returned empty response");
    }

    logger.info("Gemini text response complete", {
        structuredData: true,
        chatId,
        responseLength: accumulated.length,
    });

    return accumulated;
}

// =============================================================================
// GET CHAT PROMPT CONFIG (callable for Flutter - single source of truth)
// =============================================================================

/** Handler: Get chat prompt config. Extracted for gateway reuse. */
export function handleGetChatPromptConfig(request) {
    const { chatSource, astrologyContext, userLocation, isVoice } = request.data || {};
    const source = chatSource || null;
    const systemPrompt = getChatSystemPrompt(
        astrologyContext || null,
        userLocation || null,
        !!isVoice,
        source,
    );
    return { systemPrompt };
}

// =============================================================================
// THOUGHT STEPS (for real-time UI updates)
// =============================================================================

// Global sequence counter per chat to ensure step ordering
const stepSequenceCounters = new Map();

// REMOVED: getNextSequence — was exported "for use by search.js" but never imported anywhere.

function addThoughtStep(chatId, stepData) { // eslint-disable-line no-unused-vars
    const currentSeq = stepSequenceCounters.get(chatId) || 0;
    const newSeq = currentSeq + 1;
    stepSequenceCounters.set(chatId, newSeq);

    const step = {
        id: `step-${Date.now()}-${newSeq}-${Math.random().toString(36).slice(2, 7)}`,
        type: stepData.type || "thinking",
        message: stepData.message || "",
        query: stepData.query || null,
        timestamp: new Date().toISOString(),
        sequence: newSeq,
        metadata: stepData.metadata || {},
        ...(stepData.firestorePath && { firestorePath: stepData.firestorePath }),
        ...(stepData.results && Array.isArray(stepData.results) && stepData.results.length > 0 && {
            results: stepData.results,
        }),
    };

    const docRef = db.collection("ai_chat_sessions").doc(chatId);

    return docRef.update({
        thoughtSteps: FieldValue.arrayUnion(step),
        updatedAt: FieldValue.serverTimestamp(),
    }).catch((error) => {
        logger.error("Failed to add thought step", {
            structuredData: true,
            chatId,
            stepType: stepData.type,
            error: String(error),
        });
    });
}
