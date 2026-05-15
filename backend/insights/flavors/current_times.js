/**
 * Current Times Flavor — dynamic "what's happening now" reading.
 *
 * Migrated from functions/current_times_reading.js into the insights engine.
 * Produces a markdown reading (~180-220 words) focused on present energy
 * and near-term outlook (next 2-4 months). Uses dasha context for timing.
 *
 * Storage: `users/{uid}/astrologyData.currentTimesReading.content`
 * Cache:   24h engine cache (keyed by uid). Can be regenerated on demand.
 */

import { db, FieldValue, logger } from "../../lib/firebase.js";
import { normalizeDasha } from "../../lib/astro_helpers.js";

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

// ── Flavor definition ───────────────────────────────────────────────

export const currentTimesFlavor = {
    name: "current_times",

    cache: {
        ttlHours: 24,
        key: (params) => `current_times:${params.uid}`,
    },

    async gatherContext(params) {
        const { uid } = params;

        // Support pre-loaded data from astro_sync (avoids redundant Firestore read)
        if (params.astroData && params.userName !== undefined) {
            const astroData = params.astroData;
            return buildCtx(params.userName, astroData);
        }

        const userSnap = await db.collection("users").doc(uid).get();
        if (!userSnap.exists) throw new Error("User not found");

        const userData = userSnap.data();
        const astroData = userData.astrologyData;
        if (!astroData?.sunSign) throw new Error("Astro data not ready");

        const userName = userData.name || userData.displayName || "";
        return buildCtx(userName, astroData);
    },

    prompt({ ctx }) {
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

            options: {
                expectJson: false,
                temperature: 0.92,
                maxOutputTokens: 700,
            },
        };
    },

    parse(aiResponse) {
        return aiResponse.text;
    },

    validate(result) {
        return typeof result === "string" && result.length > 50;
    },

    async store(params, result) {
        const { uid } = params;
        await db.collection("users").doc(uid).update({
            "astrologyData.currentTimesReading": {
                content: result,
                generatedAt: FieldValue.serverTimestamp(),
            },
        });
        logger.info("📖 Current times reading stored", { uid, contentLength: result.length });
    },
};

// ── Helper ──────────────────────────────────────────────────────────

function buildCtx(userName, astroData) {
    const { mahaDasha, antarDasha } = normalizeDasha(astroData.currentDasha);
    const lifePhase = mahaDasha ?
        DASHA_DESCRIPTIONS[mahaDasha] || "a significant life phase" :
        null;

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
