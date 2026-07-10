/**
 * Current Times Reading — self-contained Cloud Function logic.
 *
 * A short, chic "what's happening now" reading (~90-120 words markdown) focused
 * on present energy + a bold near-term prediction, using the user's chart + dasha.
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
        system: "You are a sharp, stylish astrologer who writes short, chic 'current times' readings that read like a witty horoscope drop from a friend who KNOWS things. Minimal but diverse—you touch love, work, money, energy, and the unexpected in quick, bold, fun little predictions. You use markdown (bold, italics, headings, bullets) and never use jargon like 'Mahadasha' or 'transits'.",
        user: `Write a short, chic, FUN "current times" reading for ${ctx.userName || "them"}—a spread of quick predictions across different corners of their life for the next few weeks.

THEIR CHART (context only, never name these terms):
- Sun: ${ctx.sunSign}, Moon: ${ctx.moonSign}, Rising: ${ctx.ascendant}
${ctx.lifePhase ? `- Current life phase: ${ctx.lifePhase}` : ""}
${ctx.mahaDasha && ctx.antarDasha ? `- Active period: ${ctx.mahaDasha}–${ctx.antarDasha}` : ""}

RULES:
1. NO jargon. Plain, confident, playful language.
2. Speak TO them ("You"). Be specific and a little daring—every line should feel predictive, not generic.
3. Cover DIVERSE areas, not one theme: e.g. love/connection, work/ambition, money, energy/health, and one wildcard surprise.
4. Keep it snappy and chic—one crisp predictive line per area. Sprinkle a light time hint or two ("this month", "in a few weeks").
5. Have fun with it—a little wink and personality.

STRUCTURE (90–120 words, rich markdown):
1. ### The Vibe Now — one punchy sentence setting the overall mood.
2. A bulleted spread of quick predictions, each a bold label + one fun line, e.g.:
   - **Love:** ...
   - **Work:** ...
   - **Money:** ...
   - **You:** ...
   - **Wildcard:** ...
3. A cheeky one-line sign-off.

TONE: Confident, stylish, playful, diverse. Short sentences. No fluff.

Write it now (90–120 words, chic markdown):`,
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
