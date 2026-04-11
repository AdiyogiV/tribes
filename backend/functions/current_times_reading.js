import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { geminiApiKey } from "../lib/secrets.js";
import { requireAuth } from "../lib/auth_utils.js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { AI_MODELS } from "../lib/config.js";

const CURRENT_TIMES_CONFIG = {
    MAX_OUTPUT_TOKENS: 700,
    TEMPERATURE: 0.92,
    WORD_LIMIT_MIN: 180,
    WORD_LIMIT_MAX: 220,
};

const DASHA_DESCRIPTIONS = {
    Sun: "a period of leadership, clarity, and self-expression",
    Moon: "a time for emotional growth, intuition, and nurturing",
    Mars: "an era of action, courage, and initiative",
    Mercury: "a phase of learning, communication, and adaptability",
    Jupiter: "a blessed time of expansion, wisdom, and opportunity",
    Venus: "a period of love, creativity, and harmony",
    Saturn: "a time for discipline, building foundations, and maturity",
    Rahu: "an era of worldly ambitions and unconventional paths",
    Ketu: "a period of spiritual growth and letting go",
};

/**
 * Generate "current times" reading: what's happening now and what to expect (next 2–4 months).
 * Uses user's chart + current dasha. Stored under astrologyData.currentTimesReading.
 * Can be regenerated (dynamic).
 */
export const generateCurrentTimesReading = onCall(
    {
        secrets: [geminiApiKey],
        timeoutSeconds: 45,
        memory: "256MiB",
        region: "asia-southeast2",
        invoker: "public",
    },
    async (request) => {
        const uid = requireAuth(request, "generate current times reading");
        const startTime = Date.now();
        logger.info("📖 generateCurrentTimesReading invoked", { uid });

        try {
            const userRef = db.collection("users").doc(uid);
            const userSnap = await userRef.get();

            if (!userSnap.exists) {
                throw new HttpsError("not-found", "User not found");
            }

            const userData = userSnap.data();
            const astroData = userData.astrologyData;
            const userName = userData.name || userData.displayName || "";

            if (!astroData) {
                throw new HttpsError(
                    "failed-precondition",
                    "No astrology data found. Save birth details first."
                );
            }

            if (!astroData.sunSign) {
                return {
                    success: false,
                    error: "Astro data not ready yet",
                    data: null,
                };
            }

            // Optional: return cached if recent (e.g. generated in last 24h)
            const existing = astroData.currentTimesReading;
            if (existing?.content && existing.generatedAt) {
                const ts = existing.generatedAt?.toMillis?.() ?? 0;
                if (Date.now() - ts < 24 * 60 * 60 * 1000) {
                    logger.info("Current times reading cache hit", {
                        uid,
                        latency: Date.now() - startTime,
                    });
                    const generatedAtIso =
                        typeof existing.generatedAt?.toDate === "function"
                            ? existing.generatedAt.toDate().toISOString()
                            : new Date(ts).toISOString();
                    return {
                        success: true,
                        alreadyExists: true,
                        data: {
                            content: existing.content,
                            generatedAt: generatedAtIso,
                        },
                    };
                }
            }

            const content = await generateCurrentTimesContent(userName, astroData);

            const currentTimesReading = {
                content,
                generatedAt: FieldValue.serverTimestamp(),
            };

            await userRef.update({
                "astrologyData.currentTimesReading": currentTimesReading,
            });

            logger.info("✅ Current times reading complete", {
                uid,
                latency: Date.now() - startTime,
                contentLength: content?.length,
            });

            return {
                success: true,
                alreadyExists: false,
                data: {
                    content,
                    generatedAt: new Date().toISOString(),
                },
            };
        } catch (error) {
            if (error instanceof HttpsError) throw error;
            logger.error("❌ Current times reading failed", {
                uid,
                error: error.message,
                stack: error.stack?.substring(0, 300),
                latency: Date.now() - startTime,
            });
            return {
                success: false,
                error: error.message,
                data: null,
            };
        }
    }
);

/**
 * Generate and save current times reading (internal use by astro_sync).
 * Called during sync so the reading is ready when user reaches the Current Times onboarding step.
 * @param {string} uid - User ID
 * @param {string} userName - Display name
 * @param {Object} astroData - User's astrology data (from Firestore)
 * @returns {Promise<boolean>} True if saved or already existed, false on failure
 */
export async function triggerCurrentTimesReading(uid, userName, astroData) {
    if (astroData?.currentTimesReading?.content) {
        logger.info("Current times reading already exists, skipping", { uid });
        return true;
    }
    if (!astroData?.sunSign) {
        logger.warn("Cannot generate current times reading: no sunSign", { uid });
        return false;
    }
    try {
        logger.info("📖 Generating current times reading internally", { uid });
        const content = await generateCurrentTimesContent(userName, astroData);
        const currentTimesReading = {
            content,
            generatedAt: FieldValue.serverTimestamp(),
        };
        await db.collection("users").doc(uid).update({
            "astrologyData.currentTimesReading": currentTimesReading,
        });
        logger.info("✅ Current times reading generated and saved", { uid, contentLength: content?.length });
        return true;
    } catch (error) {
        logger.error("❌ Current times reading generation failed", {
            uid,
            error: error.message,
            stack: error.stack?.substring(0, 300),
        });
        return false;
    }
}

/**
 * Generate current times narrative using Gemini (present + next 2–4 months).
 */
async function generateCurrentTimesContent(userName, astroData) {
    const apiKey = geminiApiKey.value();
    if (!apiKey) throw new Error("Gemini API key missing");

    const sunSign = astroData.sunSign || "Unknown";
    const moonSign = astroData.moonSign || "Unknown";
    const ascendant = astroData.ascendant || astroData.lagna || "Unknown";
    const currentDasha = astroData.currentDasha || {};
    const mahaDasha = currentDasha.mahadasha || currentDasha.maha_dasha || "";
    const antarDasha = currentDasha.antardasha || currentDasha.antar_dasha || "";
    const lifePhase = mahaDasha
        ? DASHA_DESCRIPTIONS[mahaDasha] || "a significant life phase"
        : null;

    const prompt = `Write a "current times" reading for ${userName || "them"}—what's happening in their life NOW and what to expect in the next 2–4 months.

THEIR CHART (for context):
- Sun: ${sunSign}, Moon: ${moonSign}, Rising: ${ascendant}
${lifePhase ? `- Current life phase: ${lifePhase}` : ""}
${mahaDasha && antarDasha ? `- Active period: ${mahaDasha}–${antarDasha}` : ""}

RULES:
1. NO technical jargon (no "Mahadasha", "Antardasha", "transits" by name). Use plain language.
2. Speak TO them ("You"). Be specific and confident.
3. Focus on: (a) what's in the air for them right now, (b) what's likely to unfold in the next 2–4 months, (c) how to use this period well.
4. Use **bold** and *italic* and ### headings. Many short paragraphs. Bullet points where helpful.
5. One or two concrete time references (e.g. "in the next 6–8 weeks", "by mid-year").

STRUCTURE (180–220 words):
1. ### Right Now — 2–3 sentences on the current energy/theme.
2. ### What's Coming — What to expect in the next 2–4 months; use **bold** for the key prediction.
3. ### How to Navigate — 2–3 specific, actionable points.

TONE: Confident, warm, practical. No fluff.

Write the current times reading now (180–220 words, rich markdown):`;

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: AI_MODELS.GEMINI_FLASH,
        generationConfig: {
            temperature: CURRENT_TIMES_CONFIG.TEMPERATURE,
            maxOutputTokens: CURRENT_TIMES_CONFIG.MAX_OUTPUT_TOKENS,
        },
    });

    const systemPrompt =
        "You are a clear, supportive astrologer. You write 'current times' readings that feel relevant and actionable. You use markdown (bold, italics, headings) and avoid jargon. You never mention technical terms like Mahadasha or transits by name.";

    const result = await model.generateContent([
        { text: systemPrompt },
        { text: prompt },
    ]);

    const response = result.response;
    if (!response) throw new Error("No response from Gemini API");

    const candidates = response.candidates;
    if (!candidates?.length) {
        const reason = response.promptFeedback?.blockReason || "unknown";
        throw new Error(`Gemini blocked content: ${reason}`);
    }

    const content = response.text();
    if (!content?.trim()) throw new Error("Gemini returned empty content");

    return content.trim();
}
