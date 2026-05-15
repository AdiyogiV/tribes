/**
 * First Reading Flavor — one-time birth chart personality reading.
 *
 * Migrated from functions/first_reading.js into the insights engine.
 * Produces a markdown birth reading (~150-180 words) focused on identity,
 * personality, and core gifts. NO timing, predictions, or life phases.
 *
 * Storage: `users/{uid}/astrologyData.firstReading.content`
 * Cache:   Permanent (birth data doesn't change). Keyed by uid.
 *          Engine cache only used for dedup; real data lives on user doc.
 */

import { db, FieldValue, logger } from "../../lib/firebase.js";
import { normalizeDasha } from "../../lib/astro_helpers.js";

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

// ── Highlight builders (kept identical to original) ─────────────────

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
 * Build 2-3 cosmic highlights from chart data (no AI call needed).
 * Exported for use by astro_sync.js.
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

// ── Flavor definition ───────────────────────────────────────────────

export const firstReadingFlavor = {
    name: "first_reading",

    // No engine cache — we check the user doc directly (permanent reading)

    async gatherContext(params) {
        const { uid } = params;

        // Support pre-loaded data from astro_sync (avoids redundant Firestore read)
        if (params.astroData && params.userName !== undefined) {
            const astroData = params.astroData;
            return {
                userName: params.userName || "",
                sunSign: astroData.sunSign || "Unknown",
                moonSign: astroData.moonSign || "Unknown",
                ascendant: astroData.ascendant || astroData.lagna || "Unknown",
                rajYogas: astroData.rajYogas || [],
                astroData,
            };
        }

        const userSnap = await db.collection("users").doc(uid).get();
        if (!userSnap.exists) throw new Error("User not found");

        const userData = userSnap.data();
        const astroData = userData.astrologyData;
        if (!astroData?.sunSign) throw new Error("Astro data not ready");

        return {
            userName: userData.name || userData.displayName || "",
            sunSign: astroData.sunSign || "Unknown",
            moonSign: astroData.moonSign || "Unknown",
            ascendant: astroData.ascendant || astroData.lagna || "Unknown",
            rajYogas: astroData.rajYogas || [],
            astroData,
        };
    },

    prompt({ ctx }) {
        const hasRajYoga = ctx.rajYogas.length > 0;
        const primaryYoga = hasRajYoga ? ctx.rajYogas[0] : null;

        return {
            system: "You are a bold, insightful astrologer who creates readings that feel deeply personal and transformative. You make specific, confident claims that help people understand profound truths about themselves. You avoid technical jargon and speak in plain, powerful language. CRITICAL: You must output valid markdown in every response—use **bold** for key claims, *italics* for nuance, ### for section headings (e.g. ### Your Inner Architecture), and - for bullet lists. Your raw text will be rendered as markdown; if you output plain text only, the reading will look flat and unformatted.",

            user: `Write a bold, personalized BIRTH CHART reading for ${ctx.userName || "them"}.
Focus ONLY on who they are—their personality, identity, and core gifts. Do NOT mention current life phase, predictions, or what's coming. No timing.

THEIR CHART:
- Sun: ${ctx.sunSign} (core identity)
- Moon: ${ctx.moonSign} (emotional nature)
- Rising: ${ctx.ascendant} (how they appear to others)
${hasRajYoga ? `- Special Blessing: ${primaryYoga.name || "A powerful alignment bringing success"}` : ""}

CRITICAL RULES:
1. NO technical astrology terms (no "Mahadasha", "Raj Yoga", "celestial bodies", etc.)
2. NO predictions or "what's coming" or "right now" or life phase—this reading is ONLY about who they are from birth.
3. Be BOLD and SPECIFIC - make claims that stand out
4. Use "You" directly - speak TO them
5. Make it EMOTIONALLY RESONANT - they should feel seen
6. Be TRANSFORMATIVE - help them understand something profound about themselves

MARKDOWN FORMATTING (MANDATORY - your response will be rendered as markdown):
- Use **bold** for at least two key phrases (e.g. **You are someone who...**).
- Use *italics* for subtle or reflective lines.
- Start sections with ### headings exactly: ### Your Inner Architecture, ### How You Move Through the World, ### A Hidden Strength.
- Use bullet points with - for lists of traits or gifts.
- Keep paragraphs short (2-3 sentences). Blank line between paragraphs.

STRUCTURE (150-180 words) - output this exact structure with markdown:
1. Opening: One sentence with **bold** claim about who they are.
2. ### Your Inner Architecture
   - 2-3 bullet points or a short paragraph on their core gift/power.
3. ### How You Move Through the World
   - 2-3 sentences on how they show up and how others experience them.
4. ### A Hidden Strength
   - One short paragraph on a quality they may not fully own yet.

TONE: Confident, personal, transformative. No jargon. No timing or predictions.

OUTPUT: Your entire response must be valid markdown (headings, bold, bullets). Write the BIRTH reading now:`,

            options: {
                expectJson: false, // Markdown output, not JSON
                temperature: 0.95,
                maxOutputTokens: 600,
            },
        };
    },

    // parse: not needed — engine defaults to raw text for non-JSON flavors
    parse(aiResponse) {
        return aiResponse.text;
    },

    validate(result) {
        return typeof result === "string" && result.length > 50;
    },

    async store(params, result) {
        const { uid } = params;
        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();
        const astroData = userSnap.data()?.astrologyData || {};

        const highlights = buildCosmicHighlights(astroData);

        await userRef.update({
            "astrologyData.firstReading": {
                content: result,
                highlights,
                generatedAt: FieldValue.serverTimestamp(),
                sunSign: astroData.sunSign,
                moonSign: astroData.moonSign,
                ascendant: astroData.ascendant || astroData.lagna,
            },
        });

        logger.info("📖 First reading stored", { uid, contentLength: result.length });
    },
};
