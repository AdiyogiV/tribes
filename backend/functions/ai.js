import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../lib/firebase.js";
import { db } from "../lib/firebase.js";
import { getAuth } from "firebase-admin/auth";
import { DateTime } from "luxon";
import { getVertexAI, extractChunkText } from "../lib/vertex_client.js";
import { getChatSystemPrompt } from "./prompts/chat.js";
import { getUserMemory } from "./user_memory.js";
import { checkRateLimit as checkPersistentRateLimit, RATE_LIMIT_PRESETS } from "../lib/rate_limiter.js";
import { CHAT_CONFIG, AI_MODELS } from "../lib/config.js";

// =============================================================================
// CONFIGURATION
// =============================================================================

// Using centralized config from lib/config.js
const MAX_HISTORY_MESSAGES = CHAT_CONFIG.MAX_HISTORY_MESSAGES;

// =============================================================================
// SERVER-SIDE USER CONTEXT FETCH
// Fetches astrology + ayurveda data from Firestore using the user's uid.
// Called when the request carries a valid Firebase ID token.
// =============================================================================

/**
 * Build the ayurveda sub-object that buildWellnessContextString() expects.
 * Mirrors the structure produced by AstrologyContextBuilder in Flutter.
 * @param {Object} ayurvedaData - Raw ayurvedaData from Firestore
 * @returns {Object}
 */
function buildAyurvedaContext(ayurvedaData) {
    const ctx = {};

    if (ayurvedaData.prakriti) {
        ctx.prakriti = {
            type: ayurvedaData.prakriti.type,
            dominant: ayurvedaData.prakriti.dominant,
            vata: ayurvedaData.prakriti.vata,
            pitta: ayurvedaData.prakriti.pitta,
            kapha: ayurvedaData.prakriti.kapha,
        };
    }

    if (ayurvedaData.agniType) ctx.agniType = ayurvedaData.agniType;

    if (ayurvedaData.manasPrakriti) {
        ctx.manasPrakriti = {
            dominant: ayurvedaData.manasPrakriti.dominant,
            sattva: ayurvedaData.manasPrakriti.sattva,
            rajas: ayurvedaData.manasPrakriti.rajas,
            tamas: ayurvedaData.manasPrakriti.tamas,
        };
    }

    if (Array.isArray(ayurvedaData.healthVulnerabilities) && ayurvedaData.healthVulnerabilities.length) {
        // Firestore stores objects with a description field; flatten to string array
        ctx.healthVulnerabilities = ayurvedaData.healthVulnerabilities
            .map((v) => (typeof v === "string" ? v : v.description))
            .filter(Boolean);
    }

    if (ayurvedaData.vikriti) {
        ctx.vikriti = ayurvedaData.vikriti; // { vata, pitta, kapha, isBalanced, imbalances, factors }
    }

    return ctx;
}

/**
 * Fetch full user context (astrology + ayurveda + today's insight) from Firestore.
 * Mirrors AstrologyContextBuilder.buildContext() in Flutter.
 * @param {string} uid - Firebase user ID
 * @returns {Promise<Object|null>} Context map, or null if no astrology data
 */
async function fetchUserContext(uid) {
    const today = DateTime.now().setZone("Asia/Kolkata").toFormat("yyyy-MM-dd");

    const [userSnap, insightSnap] = await Promise.all([
        db.doc(`users/${uid}`).get(),
        db.doc(`users/${uid}/dailyInsights/${today}`).get(),
    ]);

    if (!userSnap.exists) return null;

    const userData = userSnap.data();
    const astroData = userData.astrologyData || null;
    const ayurvedaData = userData.ayurvedaData || null;

    // No astrology data means no personalized context available
    if (!astroData) return null;

    // Start with all astrologyData fields (sunSign, moonSign, ascendant, nakshatra,
    // birthChartData, processedPlanets, currentDasha, doshas, yogas, etc.)
    const context = { ...astroData };

    // Add daily insight data
    if (insightSnap.exists) {
        const insight = insightSnap.data();

        // Cosmic weather and forecasts from the pre-generated insight context
        if (insight.astroContext?.cosmicWeather) {
            context.cosmicWeather = insight.astroContext.cosmicWeather;
        }
        if (insight.astroContext?.forecasts) {
            context.forecasts = insight.astroContext.forecasts;
        }

        // Today's transits, panchang, shad bala for real-time context
        if (insight.astrologicalData) {
            context.todayTransits = insight.astrologicalData.transits || null;
            context.todayPanchang = insight.astrologicalData.panchang || null;
            context.todayShadBala = insight.astrologicalData.shadBala || null;
        }

        // Display content (insight message and sections)
        if (insight.displayMessage) context.dailyInsight = insight.displayMessage;
        if (insight.displayTheme) context.insightTheme = insight.displayTheme;
        if (Array.isArray(insight.sections)) context.insightSections = insight.sections;
    }

    // Attach ayurveda context
    if (ayurvedaData?.prakriti) {
        context.ayurveda = buildAyurvedaContext(ayurvedaData);
    }

    // Attach durable memory (cross-session life threads) when present. This is
    // what lets HolyCow open with continuity instead of amnesia. Best-effort —
    // a missing/failed memory never blocks the chat.
    const memory = await getUserMemory(uid);
    if (memory) context.memory = memory;

    return context;
}

// =============================================================================
// MAIN AI CHAT ENDPOINT
// =============================================================================

export const aiChat = onRequest(
    {
        region: "asia-southeast2",
        // No secrets needed — uses Vertex AI with ADC
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
            const userLocation = body.location || null;
            const audioUrl = body.audioUrl || null;
            // Preserve explicit chatSource from dedicated pages (astrology/wellness).
            // null = unified HolyCow mode (main chat with auto-loaded context).
            const chatSource = body.chatSource || null;

            // ── Context resolution ──────────────────────────────────────────
            // Prefer server-fetched context (from Firestore) when a valid Firebase
            // ID token is present — avoids sending large payloads over the wire and
            // always includes the freshest daily insight data.
            // Falls back to body.astrologyContext for old clients / guest sessions.
            let astrologyContext = null;
            let contextSource = "none";

            const authHeader = req.headers["authorization"] || "";
            const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

            if (idToken) {
                try {
                    const decoded = await getAuth().verifyIdToken(idToken);
                    astrologyContext = await fetchUserContext(decoded.uid);
                    contextSource = astrologyContext ? "server" : "server_no_data";
                } catch (authErr) {
                    // Invalid/expired token — treat as guest, don't 401
                    logger.warn("ID token verification failed — falling back to guest mode", {
                        structuredData: true,
                        chatId,
                        error: authErr.message,
                    });
                }
            }

            // Backwards compat: old clients / guest users may send context in body
            if (!astrologyContext && body.astrologyContext) {
                astrologyContext = body.astrologyContext;
                contextSource = "client";
            }

            logger.info("AI chat context", {
                structuredData: true,
                chatId,
                chatSource,
                contextSource,
                hasLocation: !!userLocation,
                location: userLocation,
                hasAstrology: !!astrologyContext,
                hasAudio: !!audioUrl,
            });

            if (astrologyContext) {
                logger.info("Resolved astrology context", {
                    structuredData: true,
                    chatId,
                    contextSource,
                    hasAscendant: !!astrologyContext.ascendant,
                    hasMoonSign: !!astrologyContext.moonSign,
                    hasSunSign: !!astrologyContext.sunSign,
                    hasNakshatra: !!astrologyContext.nakshatra,
                    hasDasha: !!astrologyContext.currentDasha,
                    hasDailyInsight: !!astrologyContext.dailyInsight,
                    hasAyurveda: !!astrologyContext.ayurveda,
                    hasTodayTransits: !!astrologyContext.todayTransits,
                });
            }

            if (!userMessage) {
                res.set("Access-Control-Allow-Origin", "*");
                return res.status(400).json({ error: "Last user message is empty" });
            }

            res.setHeader("Cache-Control", "no-cache");
            res.setHeader("Content-Type", "text/event-stream");
            res.setHeader("Connection", "keep-alive");
            res.flushHeaders();

            // SSE is the single source of truth. The `session` event just lets the
            // client correlate the stream with its chatId — no Firestore listener.
            write({ event: "session", chatId });

            // Performance tracking
            const performanceMetrics = {
                startTime: Date.now(),
                synthesisStart: null,
                synthesisEnd: null,
                firstTokenTime: null,
                totalTime: null,
            };

            // Context is fully pre-loaded from Firestore (fetchUserContext):
            //   - birth chart, dasha, planets, yogas, doshas
            //   - today's transits, panchang, shadBala
            //   - cosmicWeather + forecasts (already in dailyInsights.astroContext)
            // No enrichment needed — Gemini interprets all Vedic data natively.
            // The old enrichAstrologyContext() was redundant (cosmic weather already
            // in daily insight) and expensive (extra Gemini+search calls per message).

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

            write({ event: "complete", content: accumulated });
            res.end();
        } catch (error) {
            logger.error("aiChat streaming failed", {
                structuredData: true,
                error: String(error),
            });

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

// =============================================================================
// GEMINI STREAMING - AUDIO
// =============================================================================

/**
 * Stream response from Gemini for audio messages
 * Gemini understands the audio directly (no transcription needed)
 */
async function streamFromGemini({ chatId, audioUrl, messages, write, astrologyContext = null, userLocation = null, chatSource = "astrology", onFirstToken = null }) {
    logger.info("Starting Gemini audio processing", {
        structuredData: true,
        chatId,
        hasAudio: !!audioUrl,
        hasAstrology: !!astrologyContext,
        hasLocation: !!userLocation,
    });

    const vertexAI = getVertexAI();
    // Always include the search tool — system prompt instructs model to only invoke it
    // for genuinely live/current data needs. Rich context covers everything else.
    const model = vertexAI.getGenerativeModel({
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

    // Build proper multi-turn conversation format for Gemini API
    let contents = buildGeminiContents(messages.slice(0, -1)); // all but last (current user message)

    // Add current user message with audio
    const userParts = [
        { text: "Listen to and respond to this voice message:" },
        {
            inlineData: {
                mimeType,
                data: audioBase64,
            },
        },
    ];

    contents.push({
        role: "user",
        parts: userParts,
    });

    let accumulated = "";
    let firstTokenReceived = false;

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
// GEMINI STREAMING - TEXT
// =============================================================================

/**
 * Stream response from Gemini for text messages
 * Uses built-in Google Search grounding
 */
async function streamFromGeminiText({ chatId, userMessage, messages, write, astrologyContext = null, userLocation = null, chatSource = "astrology", onFirstToken = null }) {
    logger.info("Starting Gemini text processing", {
        structuredData: true,
        chatId,
        hasAstrology: !!astrologyContext,
        hasLocation: !!userLocation,
        messageLength: userMessage?.length || 0,
    });

    const vertexAI = getVertexAI();
    // Always include the search tool — system prompt instructs model to only invoke it
    // for genuinely live/current data needs. Rich context covers everything else.
    const model = vertexAI.getGenerativeModel({
        model: AI_MODELS.GEMINI_FLASH,
        tools: [{ googleSearch: {} }],
    });

    const systemPrompt = getChatSystemPrompt(astrologyContext, userLocation, false, chatSource);

    // Build proper multi-turn conversation format for Gemini API
    let contents = buildGeminiContents(messages.slice(0, -1)); // all but last (current user message)

    // Add current user message
    contents.push({
        role: "user",
        parts: [{ text: userMessage }],
    });

    let accumulated = "";
    let firstTokenReceived = false;

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


