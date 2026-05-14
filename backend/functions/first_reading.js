import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { geminiApiKey } from "../lib/secrets.js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { AI_MODELS } from "../lib/config.js";

// Birth reading generation parameters (personality/identity only)
const FIRST_READING_CONFIG = {
    MAX_OUTPUT_TOKENS: 600,
    TEMPERATURE: 0.95,
    WORD_LIMIT_MIN: 150,
    WORD_LIMIT_MAX: 180,
};

/**
 * Generate personalized BIRTH reading for a new user (personality/identity only).
 * This is called ONCE after birth details are saved and astro sync completes.
 * NO timing or predictions - those go in the separate "current times" reading.
 * @exported for internal use by astro_sync.js
 */
export async function generateFirstReadingContent(userName, astroData) {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
        throw new Error("Gemini API key missing");
    }

    // Extract core chart data (no dasha/life phase - that's for current times reading)
    const sunSign = astroData.sunSign || "Unknown";
    const moonSign = astroData.moonSign || "Unknown";
    const ascendant = astroData.ascendant || astroData.lagna || "Unknown";

    // Extract Raj Yogas (special blessings)
    const rajYogas = astroData.rajYogas || [];
    const hasRajYoga = rajYogas.length > 0;
    const primaryYoga = hasRajYoga ? rajYogas[0] : null;

    const prompt = `Write a bold, personalized BIRTH CHART reading for ${userName || "them"}.
Focus ONLY on who they are—their personality, identity, and core gifts. Do NOT mention current life phase, predictions, or what's coming. No timing.

THEIR CHART:
- Sun: ${sunSign} (core identity)
- Moon: ${moonSign} (emotional nature)
- Rising: ${ascendant} (how they appear to others)
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

OUTPUT: Your entire response must be valid markdown (headings, bold, bullets). Write the BIRTH reading now:`;

    const aiStartTime = Date.now();
    logger.info("🤖 Starting Gemini call for first reading", { model: AI_MODELS.GEMINI_FLASH, userName, sunSign });

    // Initialize Gemini
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: AI_MODELS.GEMINI_FLASH,
        generationConfig: {
            temperature: FIRST_READING_CONFIG.TEMPERATURE,
            maxOutputTokens: FIRST_READING_CONFIG.MAX_OUTPUT_TOKENS,
        },
    });

    const systemPrompt = "You are a bold, insightful astrologer who creates readings that feel deeply personal and transformative. You make specific, confident claims that help people understand profound truths about themselves. You avoid technical jargon and speak in plain, powerful language. CRITICAL: You must output valid markdown in every response—use **bold** for key claims, *italics* for nuance, ### for section headings (e.g. ### Your Inner Architecture), and - for bullet lists. Your raw text will be rendered as markdown; if you output plain text only, the reading will look flat and unformatted.";

    let result;
    try {
        result = await model.generateContent([
            { text: systemPrompt },
            { text: prompt },
        ]);
    } catch (apiError) {
        logger.error("🤖 Gemini API call failed", {
            error: apiError.message,
            stack: apiError.stack?.substring(0, 500),
            model: AI_MODELS.GEMINI_FLASH,
            hasApiKey: !!apiKey
        });
        throw new Error(`Gemini API error: ${apiError.message}`);
    }

    const response = result.response;

    // Check for blocked content or errors
    if (!response) {
        throw new Error("No response from Gemini API");
    }

    const candidates = response.candidates;
    if (!candidates || candidates.length === 0) {
        const finishReason = response.promptFeedback?.blockReason || "unknown";
        logger.error("🤖 Gemini returned no candidates", {
            finishReason,
            promptFeedback: response.promptFeedback
        });
        throw new Error(`Gemini blocked content: ${finishReason}`);
    }

    const content = response.text();

    logger.info("🤖 Gemini call completed", {
        latencyMs: Date.now() - aiStartTime,
        contentLength: content?.length,
        finishReason: candidates[0]?.finishReason
    });

    if (!content || !content.trim()) {
        throw new Error("Gemini returned empty content");
    }

    return content.trim();
}

/**
 * Build cosmic highlights from astro data
 * Returns 2-3 meaningful highlights to show in the UI
 * @exported for internal use by astro_sync.js
 */
export function buildCosmicHighlights(astroData) {
    const highlights = [];

    // 1. Raj Yoga (if present) - most special
    const rajYogas = astroData.rajYogas || [];
    if (rajYogas.length > 0) {
        const yoga = rajYogas[0];
        highlights.push({
            type: "yoga",
            icon: "stars",
            title: yoga.name || yoga.yoga || "Raj Yoga",
            subtitle: "Special Blessing",
            description: yoga.description || yoga.meaning || "A powerful yoga bringing success and prosperity",
            color: "#F59E0B", // Amber
        });
    }

    // 2. Current Dasha - always relevant
    const currentDasha = astroData.currentDasha || {};
    const mahaDasha = currentDasha.mahadasha || currentDasha.maha_dasha;
    const antarDasha = currentDasha.antardasha || currentDasha.antar_dasha;
    const levels = currentDasha.levels || {};

    if (mahaDasha) {
        // Calculate end year if available
        let endInfo = "";
        if (levels.maha?.end) {
            try {
                const endYear = new Date(levels.maha.end).getFullYear();
                endInfo = ` until ${endYear}`;
            } catch (e) { /* ignore */ }
        }

        const dashaDescriptions = {
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

        highlights.push({
            type: "dasha",
            icon: "planet",
            title: `${mahaDasha} Mahadasha${endInfo}`,
            subtitle: antarDasha ? `${antarDasha} Antardasha active` : "Current Life Phase",
            description: dashaDescriptions[mahaDasha] || "A significant planetary period shaping your life",
            color: "#8B5CF6", // Purple
        });
    }

    // 3. Moon Nakshatra - personal identity
    const nakshatra = astroData.nakshatra || astroData.moonNakshatra;
    if (nakshatra) {
        const nakshatraInfo = getNakshatraInfo(nakshatra);
        highlights.push({
            type: "nakshatra",
            icon: "moon",
            title: nakshatra,
            subtitle: nakshatraInfo.title || "Moon Nakshatra",
            description: nakshatraInfo.description || "Your lunar mansion reveals your inner nature",
            color: "#10B981", // Green
        });
    }

    // Limit to 3 highlights
    return highlights.slice(0, 3);
}

/**
 * Get nakshatra meanings
 */
function getNakshatraInfo(nakshatra) {
    const nakshatras = {
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

    return nakshatras[nakshatra] || { title: "Moon Nakshatra", description: "Your lunar mansion shapes your inner nature" };
}

/**
 * Generate first reading - Cloud Function
 * Called after astro sync completes for new users
 * Optimized for speed with early return on cache hit
 */
export const generateFirstReading = onCall(
    {
        secrets: [geminiApiKey],
        timeoutSeconds: 45,
        memory: "256MiB",
        region: "asia-southeast2",
        invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
        // AppCheck: DISABLED until Flutter client enables FirebaseAppCheck
        // TODO: Set to true after enabling AppCheck in lib/main.dart
        // enforceAppCheck: true,
    },
    async (request) => {
        const { auth } = request;
        if (!auth) {
            throw new HttpsError("unauthenticated", "Must be authenticated");
        }

        const uid = auth.uid;
        const startTime = Date.now();
        logger.info("📖 generateFirstReading invoked", { uid });

        try {
            // Get user data
            const userRef = db.collection("users").doc(uid);
            const userSnap = await userRef.get();

            if (!userSnap.exists) {
                throw new HttpsError("not-found", "User not found");
            }

            const userData = userSnap.data();
            const astroData = userData.astrologyData;
            const userName = userData.name || userData.displayName || "";

            if (!astroData) {
                throw new HttpsError("failed-precondition", "No astrology data found");
            }

            // Check if first reading already exists - FAST PATH
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

            // Check if we have minimum data for a reading
            if (!astroData.sunSign) {
                logger.warn("Astro data incomplete - sunSign missing", { uid, astroData: JSON.stringify(astroData).substring(0, 200) });
                return {
                    success: false,
                    error: "Astro data not ready yet",
                    data: null,
                };
            }

            // Build highlights from chart data (fast, no API call)
            const highlights = buildCosmicHighlights(astroData);
            logger.info("Built highlights", { uid, count: highlights.length });

            // Generate the personalized reading (AI call - takes 2-4s)
            const readingContent = await generateFirstReadingContent(userName, astroData);
            logger.info("AI reading generated", { uid, length: readingContent?.length });

            // Save to user's profile
            const firstReading = {
                content: readingContent,
                highlights: highlights,
                generatedAt: FieldValue.serverTimestamp(),
                sunSign: astroData.sunSign,
                moonSign: astroData.moonSign,
                ascendant: astroData.ascendant || astroData.lagna,
            };

            // Save to Firestore - await to ensure it's saved before returning
            try {
                await userRef.update({
                    "astrologyData.firstReading": firstReading,
                });
            } catch (saveError) {
                logger.warn("Failed to save first reading", { error: saveError.message });
                // Continue anyway - return the content even if save failed
            }

            logger.info("✅ First reading complete", { uid, latency: Date.now() - startTime, contentLength: readingContent?.length });

            return {
                success: true,
                alreadyExists: false,
                data: {
                    content: readingContent,
                    highlights: highlights,
                    generatedAt: new Date().toISOString(),
                },
            };
        } catch (error) {
            logger.error("❌ First reading failed", { uid, error: error.message, stack: error.stack?.substring(0, 300), latency: Date.now() - startTime });
            // Return failure response instead of throwing
            return {
                success: false,
                error: error.message,
                data: null,
            };
        }
    }
);

// REMOVED: getFirstReading callable.
// Flutter reads users/{uid}/astrologyData.firstReading directly from Firestore
// (lib/.../data_polling_mixin.dart), so this retrieval wrapper was never called
// by the app. Use generateFirstReading (above) to create the reading; the client
// reads it from Firestore once written.

