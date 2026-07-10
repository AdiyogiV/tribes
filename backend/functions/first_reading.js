/**
 * First Reading — self-contained Cloud Function logic.
 *
 * A one-time birth-chart reading (~90-110 words markdown): who the person is
 * (identity, personality, core gifts) plus a bold, destiny-flavored closing line.
 * No dates or timed predictions—those live in the current times reading.
 *
 * Recipe (one flat pass, no engine): build context -> prompt -> callGemini ->
 * store. Cache: the reading itself on users/{uid}.astrologyData.firstReading
 * (permanent — birth data doesn't change).
 */

import { HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";
import { callGemini } from "../lib/gemini.js";
import { normalizeDasha } from "../lib/astro_helpers.js";

// ── Nakshatra lookup (pure data, no API call) ───────────────────────
const NAKSHATRA_INFO = {
    "Ashwini": { title: "The Star of Transport", description: "Swift, pioneering, and healing energy" },
    "Bharani": { title: "The Star of Restraint", description: "Creative, transformative, and intense" },
    "Krittika": { title: "The Star of Fire", description: "Sharp, purifying, and determined" },
    "Rohini": { title: "The Star of Ascent", description: "Creative, nurturing, and magnetic" },
    "Mrigashira": { title: "The Searching Star", description: "Curious, gentle, and seeking" },
    "Ardra": { title: "The Star of Sorrow", description: "Transformative, intellectual, and intense" },
    "Punarvasu": { title: "The Star of Renewal", description: "Optimistic, nurturing, and wise" },
    "Pushya": { title: "The Star of Nourishment", description: "Caring, spiritual, and supportive" },
    "Ashlesha": { title: "The Clinging Star", description: "Intuitive, mysterious, and transformative" },
    "Magha": { title: "The Star of Power", description: "Regal, ancestral, and authoritative" },
    "Purva Phalguni": { title: "The Fruit of the Tree", description: "Creative, romantic, and fortunate" },
    "Uttara Phalguni": { title: "The Later Fruit", description: "Generous, helpful, and prosperous" },
    "Hasta": { title: "The Hand Star", description: "Skillful, clever, and resourceful" },
    "Chitra": { title: "The Star of Opportunity", description: "Brilliant, creative, and visionary" },
    "Swati": { title: "The Self-Going Star", description: "Independent, flexible, and balanced" },
    "Vishakha": { title: "The Star of Purpose", description: "Determined, ambitious, and focused" },
    "Anuradha": { title: "The Star of Success", description: "Devoted, friendly, and successful" },
    "Jyeshtha": { title: "The Chief Star", description: "Protective, senior, and wise" },
    "Mula": { title: "The Root Star", description: "Investigative, transformative, and powerful" },
    "Purva Ashadha": { title: "The Invincible Star", description: "Confident, purifying, and victorious" },
    "Uttara Ashadha": { title: "The Universal Star", description: "Principled, victorious, and righteous" },
    "Shravana": { title: "The Star of Learning", description: "Listening, wise, and connected" },
    "Dhanishtha": { title: "The Star of Symphony", description: "Wealthy, musical, and adaptable" },
    "Shatabhisha": { title: "The Hundred Stars", description: "Healing, mysterious, and independent" },
    "Purva Bhadrapada": { title: "The Burning Pair", description: "Intense, transformative, and spiritual" },
    "Uttara Bhadrapada": { title: "The Warrior Star", description: "Deep, wise, and controlled" },
    "Revati": { title: "The Wealthy Star", description: "Nurturing, prosperous, and compassionate" },
};

const DASHA_DESCRIPTIONS = {
    "Sun": "A period of leadership, authority, and self-expression",
    "Moon": "A time for emotional growth, nurturing, and intuition",
    "Mars": "An era of action, courage, and determination",
    "Mercury": "A phase of learning, communication, and adaptability",
    "Jupiter": "A blessed time of wisdom, expansion, and good fortune",
    "Venus": "A period of love, creativity, and material comforts",
    "Saturn": "A time for discipline, hard work, and building foundations",
    "Rahu": "An era of worldly ambitions and unconventional paths",
    "Ketu": "A period of spiritual growth and letting go",
};

/**
 * Build 2-3 cosmic highlights from chart data (no AI call). Exported for astro_sync.
 */
export function buildCosmicHighlights(astroData) {
    const highlights = [];

    const rajYogas = astroData.rajYogas || [];
    if (rajYogas.length > 0) {
        const yoga = rajYogas[0];
        highlights.push({
            type: "yoga",
            icon: "stars",
            title: yoga.name || yoga.yoga || "Raj Yoga",
            subtitle: "Special Blessing",
            description: yoga.description || yoga.meaning || "A powerful yoga bringing success and prosperity",
            color: "#F59E0B",
        });
    }

    const { mahaDasha, antarDasha, levels } = normalizeDasha(astroData.currentDasha);

    if (mahaDasha) {
        let endInfo = "";
        if (levels.maha?.end) {
            try {
                const endYear = new Date(levels.maha.end).getFullYear();
                endInfo = ` until ${endYear}`;
            } catch (e) {
                // ignore parse error
            }
        }

        highlights.push({
            type: "dasha",
            icon: "planet",
            title: `${mahaDasha} Mahadasha${endInfo}`,
            subtitle: antarDasha ? `${antarDasha} Antardasha active` : "Current Life Phase",
            description: DASHA_DESCRIPTIONS[mahaDasha] || "A significant planetary period shaping your life",
            color: "#8B5CF6",
        });
    }

    const nakshatra = astroData.nakshatra || astroData.moonNakshatra;
    if (nakshatra) {
        const info = NAKSHATRA_INFO[nakshatra] || { title: "Moon Nakshatra", description: "Your lunar mansion shapes your inner nature" };
        highlights.push({
            type: "nakshatra",
            icon: "moon",
            title: nakshatra,
            subtitle: info.title,
            description: info.description,
            color: "#10B981",
        });
    }

    return highlights.slice(0, 3);
}

function buildPrompt(ctx) {
    const hasRajYoga = ctx.rajYogas.length > 0;
    const primaryYoga = hasRajYoga ? ctx.rajYogas[0] : null;

    return {
        system: "You are a bold, stylish astrologer who writes short, chic birth-chart readings that feel like a designer label for someone's soul. Minimal, punchy, and a little fun. You make specific, confident claims and end with a daring line about their destiny. You avoid all jargon. CRITICAL: output valid markdown—**bold** for key claims, *italics* for nuance, ### for headings, - for bullets. Your text is rendered as markdown; plain text looks flat.",

        user: `Write a short, chic BIRTH reading for ${ctx.userName || "them"}.
Capture who they are—their personality and core gifts—then end with a bold, destiny-flavored line about what they're built for. No timing, no dates, no "right now".

THEIR CHART (context only, never name these terms):
- Sun: ${ctx.sunSign} (core identity)
- Moon: ${ctx.moonSign} (emotional nature)
- Rising: ${ctx.ascendant} (how they appear)
${hasRajYoga ? `- Special blessing: ${primaryYoga.name || "a powerful alignment for success"}` : ""}

RULES:
1. NO jargon (no "Mahadasha", "Raj Yoga", "celestial bodies", etc.).
2. Be BOLD, SPECIFIC, and a little fun—they should feel seen and want to screenshot it.
3. Speak TO them ("You"). Every line earns its place—no filler.
4. The final section is a daring claim about their trajectory/what they're destined for (feels predictive, but NO dates or timing).

MARKDOWN (MANDATORY):
- **bold** for at least two key phrases.
- *italics* for a reflective line.
- Exactly these headings: ### Your Signature, ### Where You're Headed.
- Use - bullets for traits/gifts.
- Short lines. Blank line between blocks.

STRUCTURE (90–110 words):
1. Opening: one punchy sentence with a **bold** claim about who they are.
2. ### Your Signature — 2–3 crisp bullets on their core gifts and how they show up.
3. ### Where You're Headed — one bold, destiny-flavored line about what they're built for.

TONE: Confident, stylish, a little playful. No jargon. No timing.

OUTPUT: valid markdown only. Write it now:`,
    };
}

/**
 * Core: generate + store the first reading. Returns the markdown text.
 * Exported for astro_sync (called during sync with pre-loaded chart).
 */
export async function generateFirstReading(uid, userName, astroData) {
    const ctx = {
        userName: userName || "",
        sunSign: astroData.sunSign || "Unknown",
        moonSign: astroData.moonSign || "Unknown",
        ascendant: astroData.ascendant || astroData.lagna || "Unknown",
        rajYogas: astroData.rajYogas || [],
    };
    const { system, user } = buildPrompt(ctx);

    const { text } = await callGemini({
        systemPrompt: system,
        userPrompt: user,
        temperature: 0.95,
        expectJson: false,
        flavorName: "first_reading",
    });

    if (typeof text !== "string" || text.length < 50) {
        throw new Error("first_reading produced invalid result");
    }

    const highlights = buildCosmicHighlights(astroData);
    await db.collection("users").doc(uid).update({
        "astrologyData.firstReading": {
            content: text,
            highlights,
            generatedAt: FieldValue.serverTimestamp(),
            sunSign: astroData.sunSign,
            moonSign: astroData.moonSign,
            ascendant: astroData.ascendant || astroData.lagna,
        },
    });
    logger.info("First reading stored", { uid, contentLength: text.length });

    return text;
}

/**
 * onCall handler: generate the birth reading (or return the permanent cached one).
 */
export async function handleGenerateFirstReading(request) {
    const uid = requireAuth(request, "generate first reading");
    const startTime = Date.now();
    logger.info("generateFirstReading invoked", { uid });

    try {
        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();
        if (!userSnap.exists) throw new HttpsError("not-found", "User not found");

        const userData = userSnap.data();
        const astroData = userData.astrologyData;
        if (!astroData) throw new HttpsError("failed-precondition", "No astrology data found");

        // Fast path — reading already exists (permanent, never expires)
        if (astroData.firstReading?.content) {
            logger.info("First reading cache hit", { uid, latency: Date.now() - startTime });
            return {
                success: true,
                alreadyExists: true,
                data: {
                    content: astroData.firstReading.content,
                    highlights: astroData.firstReading.highlights || buildCosmicHighlights(astroData),
                    generatedAt: astroData.firstReading.generatedAt,
                },
            };
        }

        if (!astroData.sunSign) {
            return { success: false, error: "Astro data not ready yet", data: null };
        }

        const userName = userData.name || userData.displayName || "";
        const content = await generateFirstReading(uid, userName, astroData);

        logger.info("First reading complete", {
            uid, latency: Date.now() - startTime, contentLength: content?.length,
        });

        return {
            success: true,
            alreadyExists: false,
            data: {
                content,
                highlights: buildCosmicHighlights(astroData),
                generatedAt: new Date().toISOString(),
            },
        };
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("First reading failed", {
            uid, error: error.message, stack: error.stack?.substring(0, 300),
            latency: Date.now() - startTime,
        });
        return { success: false, error: error.message, data: null };
    }
}
