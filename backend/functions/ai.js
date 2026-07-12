import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../lib/firebase.js";
import { db } from "../lib/firebase.js";
import { FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { DateTime } from "luxon";
import { getUserMemory } from "./user_memory.js";
import { checkRateLimit as checkPersistentRateLimit, RATE_LIMIT_PRESETS } from "../lib/rate_limiter.js";
import { AI_MODELS } from "../lib/config.js";
import { resolveActiveDasha } from "../lib/astro_helpers.js";
import { calculateAshtakavarga } from "../lib/vedic_analysis.js";
import { persistMetrics } from "./ai_telemetry.js";
import { streamFromGemini } from "./ai_gemini.js";
import { getChatSystemPrompt } from "./prompts/chat.js";

// =============================================================================
// CONFIGURATION
// =============================================================================

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
// ── Warm-instance context cache ────────────────────────────────────────────
// fetchUserContext does 3 Firestore reads, but within a conversation the chart
// is immutable, today's insight changes once/day, and memory refreshes nightly.
// Cache per-uid on the warm instance so rapid follow-up messages skip the reads
// (concurrency:40 share one Map). TTL kept short so a same-day insight regen or
// nightly memory refresh still shows up quickly.
const CONTEXT_CACHE_TTL_MS = 3 * 60 * 1000; // 3 min
const CONTEXT_CACHE_MAX = 500;              // bound memory on busy instances
const _contextCache = new Map();           // uid -> { ctx, expires }

async function getUserContextCached(uid) {
    const hit = _contextCache.get(uid);
    if (hit && hit.expires > Date.now()) return hit.ctx;

    const ctx = await fetchUserContext(uid);
    // Only cache real context. A null (no profile yet) stays uncached so a
    // freshly onboarded user isn't locked out for the whole TTL.
    if (ctx) {
        if (_contextCache.size >= CONTEXT_CACHE_MAX) {
            _contextCache.delete(_contextCache.keys().next().value); // evict oldest
        }
        _contextCache.set(uid, { ctx, expires: Date.now() + CONTEXT_CACHE_TTL_MS });
    }
    return ctx;
}

async function fetchUserContext(uid) {
    const today = DateTime.now().setZone("Asia/Kolkata").toFormat("yyyy-MM-dd");

    // Kick off durable-memory fetch concurrently with the profile reads — it
    // only needs `uid`, so there's no reason to wait for it serially. .catch()
    // keeps it a non-throwing best-effort lookup (memory never blocks chat).
    const memoryPromise = getUserMemory(uid).catch(() => null);

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

    // The user's actual name. Without this the prompt has no authoritative name,
    // so the model would invent one or pull a stale one from durable memory
    // (the "wrong name" bug). null when unknown — the prompt then forbids guessing.
    context.userName =
        userData.name || userData.displayName || userData.nickname || null;

    // The stored currentDasha pointer is a snapshot frozen at signup and never
    // advances — so its antardasha can already be in the past, which made the
    // chat give past-dated predictions. Re-point it to the period active TODAY
    // by looking it up in the (static, never-changing) dasha timeline. Pure
    // date math, no API call, no recompute.
    if (context.currentDasha) {
        context.currentDasha = resolveActiveDasha(context.currentDasha);
    }

    // Lazy backfill: charts created before Ashtakavarga was persisted won't have
    // it. It's pure math from data we already store (no API), so compute it here
    // in-memory for the reading. The persisted copy fills in on the next sync.
    if (!context.ashtakavarga && context.processedPlanets && context.ascendant) {
        try {
            context.ashtakavarga = calculateAshtakavarga(context.processedPlanets, context.ascendant) || null;
        } catch (_) { /* best-effort: chat works fine without it */ }
    }

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
    // what lets Baba open with continuity instead of amnesia. Best-effort —
    // a missing/failed memory never blocks the chat.
    // Await the memory lookup we kicked off at the top (overlapped with reads).
    const memory = await memoryPromise;
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

        // Hoisted so the catch block can mark the streamed doc as failed.
        let failureRef = null;

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

            if (messages.length === 0 && body.promptOnly !== true) {
                res.set("Access-Control-Allow-Origin", "*");
                return res.status(400).json({ error: "No messages provided" });
            }

            const chatId = body.chatId ? String(body.chatId) : `chat-${Date.now()}`;
            const userMessage = messages[messages.length - 1]?.content;
            const userLocation = body.location || null;
            const audioUrl = body.audioUrl || null;
            // Voice relay turns arrive as already-transcribed TEXT (not audio),
            // but still want the spoken-length style. This flag forces it.
            const voiceStyle = body.voice === true;
            // Preserve explicit chatSource from dedicated pages (astrology/wellness).
            // null = unified Baba mode (main chat with auto-loaded context).
            const chatSource = body.chatSource || null;

            // ── Context resolution ──────────────────────────────────────────
            // Prefer server-fetched context (from Firestore) when a valid Firebase
            // ID token is present — avoids sending large payloads over the wire and
            // always includes the freshest daily insight data.
            // Falls back to body.astrologyContext for old clients / guest sessions.
            let astrologyContext = null;
            let contextSource = "none";
            let authedUid = null;

            const authHeader = req.headers["authorization"] || "";
            const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

            if (idToken) {
                try {
                    const decoded = await getAuth().verifyIdToken(idToken);
                    authedUid = decoded.uid;
                    astrologyContext = await getUserContextCached(decoded.uid);
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

            // ── Voice relay: prompt-only mode ───────────────────────────────
            // The Gemini Live API voice path needs the SAME assembled persona +
            // chart/ayurveda/memory context the text brain uses, but as a one-shot
            // systemInstruction (the Live model itself does STT + brain + TTS).
            // Return it as JSON and skip the chat stream entirely. This reuses the
            // whole auth + context-fetch path above with zero new Cloud Functions.
            if (body.promptOnly === true) {
                const systemPrompt = getChatSystemPrompt(
                    astrologyContext, userLocation, /* isVoice */ true);
                logger.info("Voice prompt-only request served", {
                    structuredData: true, chatId, contextSource,
                    promptChars: systemPrompt.length,
                });
                res.set("Access-Control-Allow-Origin", "*");
                return res.status(200).json({
                    systemPrompt,
                    userName: astrologyContext?.userName || null,
                    contextSource,
                });
            }

            if (!userMessage) {
                res.set("Access-Control-Allow-Origin", "*");
                return res.status(400).json({ error: "Last user message is empty" });
            }

            // ── Streaming transport = durable store (the ideal) ─────────────
            // SSE is unreliable on Flutter web + Hosting/Cloud Run (proxy buffers
            // chunked responses). So Firestore is the streaming channel AND the
            // permanent record — ONE doc, written only by the backend.
            //
            // Authed users: we stream straight into the durable assistant message
            // doc inside dmConversations. The stream IS the persistence — no
            // separate client-side save, no duplicate write, no dup-bug class.
            //
            // Guests (no token / no conversationId): fall back to an ephemeral
            // ai_chat_sessions doc (they can't write to dmConversations anyway).
            const HOLYCOW_USER_ID = "holycow_system_user";
            const conversationId = body.conversationId ? String(body.conversationId) : null;
            const userMessageId = body.userMessageId ? String(body.userMessageId) : null;
            const assistantMessageId = body.assistantMessageId ? String(body.assistantMessageId) : null;

            const durable = !!(authedUid && conversationId && assistantMessageId);

            // Resolve the doc we stream into SYNCHRONOUSLY — no reads, no writes.
            // The assistant doc is created LAZILY by the first token flush
            // (set+merge), so nothing here blocks the model call.
            let targetRef;
            let streamField;
            let firestorePath;
            let convoRef = null;
            const baseTs = Date.now();
            let firstFlushMeta;

            if (durable) {
                convoRef = db.collection("dmConversations").doc(conversationId);
                targetRef = convoRef.collection("messages").doc(assistantMessageId);
                streamField = "content";
                firestorePath = `dmConversations/${conversationId}/messages/${assistantMessageId}`;
                firstFlushMeta = {
                    senderId: HOLYCOW_USER_ID,
                    senderName: "holycow.ai",
                    timestamp: new Date(baseTs + 1),
                    type: "text",
                };
            } else {
                targetRef = db.collection("ai_chat_sessions").doc(chatId);
                streamField = "response";
                firestorePath = `ai_chat_sessions/${chatId}`;
                firstFlushMeta = { chatId, createdAt: FieldValue.serverTimestamp() };
            }

            // Conversation shell + the user's own message are INDEPENDENT docs —
            // they don't gate the first token, so write them in the BACKGROUND.
            // Awaited later (before the completion write) so the turn is durable.
            const setupPromise = (async () => {
                if (!durable) return;
                const convoSnap = await convoRef.get();
                await convoRef.set({
                    participants: [authedUid, HOLYCOW_USER_ID],
                    isAiConversation: true,
                    lastActivity: FieldValue.serverTimestamp(),
                    ...(convoSnap.exists ?
                        {} :
                        {
                            createdAt: FieldValue.serverTimestamp(),
                            ...(userMessage ? { firstUserMessage: userMessage } : {}),
                        }),
                }, { merge: true });
                if (userMessageId && userMessage) {
                    await convoRef.collection("messages").doc(userMessageId).set({
                        content: userMessage,
                        senderId: authedUid,
                        senderName: "You",
                        timestamp: new Date(baseTs),
                        type: "text",
                        ...(audioUrl ? { isVoiceMessage: true, audioUrl } : {}),
                    }, { merge: true });
                }
            })().catch((e) => logger.warn("Chat setup writes failed (non-fatal)", {
                structuredData: true, chatId, error: String(e),
            }));

            res.setHeader("Cache-Control", "no-cache");
            res.setHeader("Content-Type", "text/event-stream");
            res.setHeader("Connection", "keep-alive");
            res.flushHeaders();

            // Expose target to the catch block for failure marking.
            failureRef = targetRef;

            // Tell the client which doc to listen to for streamed tokens.
            write({ event: "session", chatId, firestorePath });

            // Throttled writer. The assistant doc is CREATED here lazily on the
            // first flush (set+merge) — no separate pre-init write. The first
            // token flushes IMMEDIATELY so the user sees life instantly; the rest
            // are throttled to ~300ms (Firestore ~1 write/sec/doc soft limit).
            let lastDocWrite = 0;
            let streamAccum = "";
            let docInitialized = false;
            const flushDoc = async (force = false) => {
                const now = Date.now();
                if (!force && now - lastDocWrite < 300) return;
                lastDocWrite = now;
                const payload = {
                    [streamField]: streamAccum,
                    status: "processing",
                    updatedAt: FieldValue.serverTimestamp(),
                };
                if (!docInitialized) {
                    Object.assign(payload, firstFlushMeta);
                    docInitialized = true;
                }
                try {
                    await targetRef.set(payload, { merge: true });
                } catch (_) {/* best-effort: completion write is authoritative */}
            };

            // Wrap `write`: every SSE token also feeds the Firestore stream.
            // First token flushes instantly; the rest are throttled.
            let firstChunkFlushed = false;
            const streamingWrite = (data) => {
                write(data);
                if (data.event === "token" && typeof data.content === "string") {
                    streamAccum += data.content;
                    if (!firstChunkFlushed) {
                        firstChunkFlushed = true;
                        void flushDoc(true);
                    } else {
                        flushDoc();
                    }
                }
            };

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

            // Route to Gemini (one unified path for text + audio).
            performanceMetrics.synthesisStart = Date.now();
            logger.info("Routing to Gemini", {
                structuredData: true,
                chatId,
                modality: audioUrl ? "audio" : "text",
                hasAstrology: !!astrologyContext,
                hasLocation: !!userLocation,
            });

            const result = await streamFromGemini({
                chatId,
                messages,
                write: streamingWrite,
                userMessage,
                audioUrl,
                astrologyContext,
                userLocation,
                voiceStyle,
                onFirstToken: () => {
                    if (!performanceMetrics.firstTokenTime) {
                        performanceMetrics.firstTokenTime = Date.now();
                    }
                },
            });
            const accumulated = result.text;

            performanceMetrics.synthesisEnd = Date.now();
            performanceMetrics.totalTime = Date.now() - performanceMetrics.startTime;

            const metrics = {
                synthesis_ms: performanceMetrics.synthesisEnd - performanceMetrics.synthesisStart,
                ttft_ms: performanceMetrics.firstTokenTime ? performanceMetrics.firstTokenTime - performanceMetrics.synthesisStart : null,
                // prep_ms = auth + context fetch + durable doc setup (everything
                // before the model call). Lets us see if Firestore prep, not the
                // model, is the latency culprit.
                prep_ms: performanceMetrics.synthesisStart - performanceMetrics.startTime,
                audio_fetch_ms: result.audioFetchMs || 0,
                total_ms: performanceMetrics.totalTime,
                queryType: audioUrl ? "gemini_audio" : "gemini_text",
                responseLength: accumulated.length,
                chunkCount: result.chunkCount,
                // Search / grounding
                usedSearch: result.grounding.usedSearch,
                groundingAttached: result.grounding.groundingAttached,
                searchQueries: result.grounding.searchQueries,
                sourceCount: result.grounding.sourceCount,
                sources: result.grounding.sources,
                // Token accounting (thoughtsTokens = hidden "thinking" spend)
                promptTokens: result.usage.promptTokens,
                candidatesTokens: result.usage.candidatesTokens,
                thoughtsTokens: result.usage.thoughtsTokens,
                totalTokens: result.usage.totalTokens,
            };

            logger.info("Performance: Complete request metrics", {
                structuredData: true,
                chatId,
                ...metrics,
            });

            // Persist one flat analytics doc per request (best-effort).
            void persistMetrics(db, {
                chatId,
                authed: !!authedUid,
                contextSource,
                chatSource,
                model: AI_MODELS.GEMINI_FLASH,
                ...metrics,
                status: "completed",
            });

            // Final authoritative write: full text + completion status. The client
            // finalizes from this; for authed users this IS the durable record.
            try {
                await flushDoc(true);
                // Make sure the background setup writes landed before we finalize
                // (preserves firstUserMessage-on-create + ensures convo exists).
                await setupPromise;
                await targetRef.set({
                    status: "completed",
                    [streamField]: accumulated,
                    ...firstFlushMeta,
                    updatedAt: FieldValue.serverTimestamp(),
                    completedAt: FieldValue.serverTimestamp(),
                    performanceMetrics: metrics,
                }, { merge: true });
                // Update the conversation summary so recent-chats list is correct.
                if (durable && convoRef) {
                    await convoRef.set({
                        lastActivity: FieldValue.serverTimestamp(),
                        lastMessage: {
                            content: accumulated,
                            senderId: HOLYCOW_USER_ID,
                            senderName: "Aryabhatt",
                            timestamp: FieldValue.serverTimestamp(),
                        },
                    }, { merge: true });
                }
            } catch (e) {
                logger.error("Failed to write completion to target doc", {
                    structuredData: true, chatId, error: String(e),
                });
            }

            write({ event: "complete", content: accumulated });
            res.end();
        } catch (error) {
            logger.error("aiChat streaming failed", {
                structuredData: true,
                error: String(error),
            });

            // Mark the streamed doc as failed so the client listener surfaces it.
            try {
                if (failureRef) {
                    await failureRef.set({
                        status: "failed",
                        error: error.message || "Unknown error",
                        updatedAt: FieldValue.serverTimestamp(),
                    }, { merge: true });
                } else {
                    // Stream never got far enough to pick a target (guest fallback).
                    const body = parseBody(req);
                    const failChatId = body?.chatId ? String(body.chatId) : null;
                    if (failChatId) {
                        await db.collection("ai_chat_sessions").doc(failChatId).set({
                            status: "failed",
                            error: error.message || "Unknown error",
                            updatedAt: FieldValue.serverTimestamp(),
                        }, { merge: true });
                    }
                }
            } catch (persistError) {
                logger.error("Failed to record streaming failure", {
                    structuredData: true, error: String(persistError),
                });
            }

            // Persist a failed analytics record so error rate + error types are
            // queryable alongside successes (best-effort).
            const msg = error.message || "Unknown error";
            // Classify the notorious dead-host bug so it's trivially countable.
            const errorType = /<!DOCTYPE|is not valid JSON/.test(msg) ? "vertex_html_response" :
                /empty response/i.test(msg) ? "empty_response" :
                    /audio/i.test(msg) ? "audio_fetch" : "other";
            void persistMetrics(db, {
                chatId: parseBody(req)?.chatId ? String(parseBody(req).chatId) : null,
                model: AI_MODELS.GEMINI_FLASH,
                status: "failed",
                error: msg,
                errorType,
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
