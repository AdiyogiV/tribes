/**
 * Current Times Reading — self-contained Cloud Function logic.
 *
 * A dynamic "what's happening now" reading (~180-220 words markdown) focused on
 * present energy + near-term outlook, using the user's chart + current dasha.
 *
 * Recipe (one flat pass, no engine): build context -> prompt -> callGemini -> store.
 * Cache: the reading itself on users/{uid}.astrologyData.currentTimesReading (24h).
 */

import { HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";
import { callGemini } from "../lib/gemini.js";
import { normalizeDasha } from "../lib/astro_helpers.js";

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

// ── Dasha descriptions (plain language, no jargon) ─────────────────
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

function buildCtx(userName, astroData) {
    const { mahaDasha, antarDasha } = normalizeDasha(astroData.currentDasha);
    const lifePhase = mahaDasha
        ? DASHA_DESCRIPTIONS[mahaDasha] || "a significant life phase"
        : null;
    return {
        userName: userName || "",
        sunSign: astroData.sunSign || "Unknown",
        moonSign: astroData.moonSign || "Unknown",
        ascendant: astroData.ascendant || astroData.lagna || "Unknown",
        mahaDasha,
        antarDasha,
        lifePhase,
    };
}

function buildPrompt(ctx) {
    return {
        system: "You are a clear, supportive astrologer. You write 'current times' readings that feel relevant and actionable. You use markdown (bold, italics, headings) and avoid jargon. You never mention technical terms like Mahadasha or transits by name.",
        user: `Write a "current times" reading for ${ctx.userName || "them"}—what's happening in their life NOW and what to expect in the next 2–4 months.

THEIR CHART (for context):
- Sun: ${ctx.sunSign}, Moon: ${ctx.moonSign}, Rising: ${ctx.ascendant}
${ctx.lifePhase ? `- Current life phase: ${ctx.lifePhase}` : ""}
${ctx.mahaDasha && ctx.antarDasha ? `- Active period: ${ctx.mahaDasha}–${ctx.antarDasha}` : ""}

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

Write the current times reading now (180–220 words, rich markdown):`,
    };
}

/**
 * Core: generate + store the current times reading. Returns the markdown text.
 */
async function generateCurrentTimes(uid, userName, astroData) {
    const { system, user } = buildPrompt(buildCtx(userName, astroData));

    const { text } = await callGemini({
        systemPrompt: system,
        userPrompt: user,
        temperature: 0.92,
        expectJson: false,
        flavorName: "current_times",
    });

    if (typeof text !== "string" || text.length < 50) {
        throw new Error("current_times produced invalid result");
    }

    await db.collection("users").doc(uid).update({
        "astrologyData.currentTimesReading": {
            content: text,
            generatedAt: FieldValue.serverTimestamp(),
        },
    });
    logger.info(" Current times reading stored", { uid, contentLength: text.length });

    return text;
}

/**
 * onCall handler: generate current times reading (or return cached within 24h).
 */
export async function handleGenerateCurrentTimesReading(request) {
    const uid = requireAuth(request, "generate current times reading");
    const startTime = Date.now();
    logger.info(" generateCurrentTimesReading invoked", { uid });

    try {
        const userSnap = await db.collection("users").doc(uid).get();
        if (!userSnap.exists) throw new HttpsError("not-found", "User not found");

        const userData = userSnap.data();
        const astroData = userData.astrologyData;
        if (!astroData) {
            throw new HttpsError("failed-precondition", "No astrology data found. Save birth details first.");
        }
        if (!astroData.sunSign) {
            return { success: false, error: "Astro data not ready yet", data: null };
        }

        // Fast path — return cached if generated within 24h
        const existing = astroData.currentTimesReading;
        if (existing?.content && existing.generatedAt) {
            const ts = existing.generatedAt?.toMillis?.() ?? 0;
            if (Date.now() - ts < CACHE_TTL_MS) {
                logger.info("Current times reading cache hit", { uid, latency: Date.now() - startTime });
                const generatedAtIso = typeof existing.generatedAt?.toDate === "function"
                    ? existing.generatedAt.toDate().toISOString()
                    : new Date(ts).toISOString();
                return {
                    success: true,
                    alreadyExists: true,
                    data: { content: existing.content, generatedAt: generatedAtIso },
                };
            }
        }

        const userName = userData.name || userData.displayName || "";
        const content = await generateCurrentTimes(uid, userName, astroData);

        logger.info(" Current times reading complete", {
            uid, latency: Date.now() - startTime, contentLength: content?.length,
        });

        return {
            success: true,
            alreadyExists: false,
            data: { content, generatedAt: new Date().toISOString() },
        };
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error(" Current times reading failed", {
            uid, error: error.message, stack: error.stack?.substring(0, 300),
            latency: Date.now() - startTime,
        });
        return { success: false, error: error.message, data: null };
    }
}

/**
 * Internal (astro_sync): generate + save during sync so the reading is ready
 * when the user reaches the Current Times step. Idempotent.
 * @returns {Promise<boolean>} true if saved or already existed, false on failure
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
        logger.info(" Generating current times reading internally", { uid });
        await generateCurrentTimes(uid, userName, astroData);
        logger.info(" Current times reading generated and saved", { uid });
        return true;
    } catch (error) {
        logger.error(" Current times reading generation failed", {
            uid, error: error.message, stack: error.stack?.substring(0, 300),
        });
        return false;
    }
}
