/**
 * Ayurveda Cloud Functions
 *
 * Provides Prakriti calculation from astrology data,
 * Vikriti calculation, and wellness recommendations.
 */

import { HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { requireAuth } from "../lib/auth_utils.js";
import { db } from "../lib/firebase.js";
import { withLoopGuard } from "../lib/idempotency.js";
import { geminiApiKey } from "../lib/secrets.js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { AI_MODELS } from "../lib/config.js";
import {
    calculatePrakriti,
    calculateVikriti,
    analyzeHealthVulnerabilities,
    AGNI_TYPES,
    PLANET_DOSHA,
    calculateTarabala,
    calculateChandrabala,
    checkDusthanaLordship,
    isYogakaraka,
    getDignityMultiplier,
} from "../lib/ayurveda.js";
// Shared helpers — extracted to lib/ so astro domain can import without
// pulling in this Cloud Function file.
import {
    resetAndRecalculateAyurveda,
    findWeakPlanets,
    getSixthHouseSign,
    getPlanetsInHouse,
} from "../lib/ayurveda_service.js";
// Re-export so existing callers (astro_sync.js) still work via this file
export { resetAndRecalculateAyurveda };
import { DateTime } from "luxon";
import {
    calculateHouseFromDegree,
    calculateTransitAspects,
    scoreAspects,
    calculatePlanetDignity,
    calculateAshtakavarga,
    getTransitBinduScore,
} from "../lib/vedic_analysis.js";
import { extractAscendantDegree as extractAscendantDegreeFromAstroData } from "../lib/astro_helpers.js";
import { computeOjas } from "../lib/ojas_engine.js";
import { computeNadi, computeBaseline as computeNadiBaseline } from "../lib/nadi_engine.js";
import { getWeights } from "../lib/engine_weights.js";

const VIKRITI_TRANSIT_MAX_SHIFT = 12; // keep low-impact: transits refine, don't override

function getTodayDateKeyUTC() {
    return DateTime.now().setZone("UTC").toFormat("yyyy-MM-dd");
}

function buildNatalPlanetsForAspects(astroData) {
    // Use processedPlanets for consistent naming.
    const natal = {};
    const pp = astroData?.processedPlanets;
    if (!Array.isArray(pp)) return natal;

    for (const p of pp) {
        const name = p?.name;
        const fullDegree = p?.fullDegree ?? p?.full_degree;
        if (!name || fullDegree == null) continue;
        if (name === "Lagna" || name === "Ascendant") continue;
        natal[name] = { fullDegree };
    }

    return natal;
}

function getHouseWeight(house) {
    if (!house) return 0.75;
    if ([1, 4, 7, 10].includes(house)) return 1.0; // kendras
    if ([6, 8, 12].includes(house)) return 1.1; // dusthanas
    if ([5, 9].includes(house)) return 0.9; // trines
    if ([2, 11].includes(house)) return 0.8;
    return 0.7;
}

function getPlanetWeight(planet) {
    // Slow planets get a bit more weight (longer-lasting influence)
    switch (planet) {
    case "Saturn":
    case "Rahu":
    case "Ketu":
        return 1.0;
    case "Jupiter":
        return 0.9;
    case "Mars":
        return 0.85;
    case "Sun":
    case "Moon":
        return 0.8;
    case "Mercury":
    case "Venus":
        return 0.65;
    default:
        return 0.6;
    }
}

function computeTransitEffectAndFactors({ transits, ascendantDegree, dashaData, natalPlanets }) {
    if (!transits || typeof transits !== "object") {
        return { transitEffect: null, transitFactors: [] };
    }

    const raw = { vata: 0, pitta: 0, kapha: 0 };
    const perPlanet = [];

    // 1) House-based transit contributions (planet dosha * (planetWeight * houseWeight))
    for (const [planet, t] of Object.entries(transits)) {
        if (!t || typeof t !== "object") continue;
        const deg = t.degree ?? t.fullDegree ?? t.longitude;
        if (deg == null) continue;

        const house =
            t.house ||
            (ascendantDegree != null ? calculateHouseFromDegree(deg, ascendantDegree) : null);

        const doshaInfo = PLANET_DOSHA?.[planet];
        if (!doshaInfo) continue;

        const w = getPlanetWeight(planet) * getHouseWeight(house);
        raw[doshaInfo.primary] += w * 1.0;
        if (doshaInfo.secondary) raw[doshaInfo.secondary] += w * 0.5;

        perPlanet.push({
            planet,
            house: house || null,
            primaryDosha: doshaInfo.primary,
            weight: w,
        });
    }

    // 2) Transit-to-natal aspects (small additive refinements)
    // Uses degree-based aspects; we keep impact tiny.
    const hasNatal = natalPlanets && Object.keys(natalPlanets).length > 0;
    const transitAspects = hasNatal ?
        calculateTransitAspects({ planets: natalPlanets }, transits) :
        [];
    const scored = scoreAspects(transitAspects, dashaData);
    const topAspects = (scored || []).filter((a) => (a.score || a.significance || 0) >= 6).slice(0, 2);
    for (const a of topAspects) {
        const planet = a.transitPlanet;
        const doshaInfo = PLANET_DOSHA?.[planet];
        if (!doshaInfo) continue;

        const aspectStrength = Math.max(1, Math.min(3, Math.round((a.score || a.significance || 6) / 6)));
        raw[doshaInfo.primary] += aspectStrength * 0.8;
        if (doshaInfo.secondary) raw[doshaInfo.secondary] += aspectStrength * 0.4;
    }

    const sum = raw.vata + raw.pitta + raw.kapha;
    if (sum <= 0) return { transitEffect: null, transitFactors: [] };

    const scale = Math.min(1, VIKRITI_TRANSIT_MAX_SHIFT / sum);
    const transitEffect = {
        vata: Math.round(raw.vata * scale),
        pitta: Math.round(raw.pitta * scale),
        kapha: Math.round(raw.kapha * scale),
    };

    // Factors for explainability (top 2 planets + top aspects)
    perPlanet.sort((a, b) => b.weight - a.weight);
    const transitFactors = [];

    for (const p of perPlanet.slice(0, 2)) {
        const desc = p.house ?
            `${p.planet} transit (House ${p.house})` :
            `${p.planet} transit`;
        transitFactors.push({
            source: "transit",
            description: desc,
            dosha: p.primaryDosha,
            strength: Math.max(1, Math.min(10, Math.round(p.weight * 5))),
        });
    }

    for (const a of topAspects) {
        transitFactors.push({
            source: "transitAspect",
            description: `${a.transitPlanet} ${a.type} natal ${a.natalPlanet}`,
            dosha: (PLANET_DOSHA?.[a.transitPlanet]?.primary) || "vata",
            strength: Math.max(1, Math.min(10, Math.round((a.score || a.significance || 6)))),
        });
    }

    return { transitEffect, transitFactors };
}

// ============================================================================
// INTERNAL HELPER: Reset and Recalculate Ayurveda from Astrology Data
// → Moved to lib/ayurveda_service.js (imported + re-exported above)
// ============================================================================

// ============================================================================
// RESET AYURVEDA PROFILE (User-callable)
// Allows user to manually reset and recalculate their Ayurveda profile
// ============================================================================

export async function handleResetAyurvedaProfile(request) {
    const uid = requireAuth(request, "reset Ayurveda profile");
    logger.info("🌿 Manual Ayurveda profile reset requested", { uid });

    try {
        // Get user's astrology data
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const astroData = userData?.astrologyData;

        if (!astroData) {
            throw new HttpsError(
                "failed-precondition",
                "Astrology profile required for Ayurveda calculation",
            );
        }

        if (!astroData.ascendant) {
            throw new HttpsError(
                "failed-precondition",
                "Complete astrology profile with ascendant required",
            );
        }

        // Use the internal helper to reset and recalculate
        const success = await resetAndRecalculateAyurveda(uid, astroData);

        if (!success) {
            throw new HttpsError("internal", "Failed to reset Ayurveda profile");
        }

        // Fetch the fresh profile to return
        const freshDoc = await db.collection("users").doc(uid).get();
        const freshAyurvedaData = freshDoc.data()?.ayurvedaData;

        return {
            success: true,
            prakriti: freshAyurvedaData?.prakriti,
            agniType: freshAyurvedaData?.agniType,
        };
    } catch (error) {
        logger.error("❌ Error in manual Ayurveda reset", {
            uid,
            error: error.message,
        });
        throw error;
    }
}

// ============================================================================
// CALCULATE AYURVEDA PROFILE
// Called to calculate/recalculate Prakriti from birth chart
// ============================================================================

export async function handleCalculateAyurvedaProfile(request) {
    const uid = requireAuth(request, "calculate Ayurveda profile");
    logger.info("🌿 Calculating Ayurveda profile", { uid });

    try {
        // Get user's astrology data
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const astroData = userData?.astrologyData;

        if (!astroData) {
            throw new HttpsError(
                "failed-precondition",
                "Astrology profile required for Ayurveda calculation",
            );
        }

        // Extract required data
        const ascendantSign = astroData.ascendant;
        const moonNakshatra = astroData.moonNakshatra || astroData.nakshatra;
        const birthLatitude = astroData.birthLatitude;
        const planets = astroData.processedPlanets || [];

        if (!ascendantSign) {
            throw new HttpsError(
                "failed-precondition",
                "Ascendant sign required for Prakriti calculation",
            );
        }

        // Calculate Prakriti
        const prakritiResult = calculatePrakriti({
            ascendantSign,
            planets,
            moonNakshatra,
            birthLatitude,
        });

        // Analyze health vulnerabilities from chart
        const weakPlanets = findWeakPlanets(astroData);
        const sixthHouseSign = getSixthHouseSign(astroData);
        const planetsIn6th = getPlanetsInHouse(astroData, 6);

        const healthVulnerabilities = analyzeHealthVulnerabilities({
            sixthHouseSign,
            planetsIn6th,
            weakPlanets,
        });

        // Build Ayurveda profile
        const ayurvedaProfile = {
            prakriti: {
                ...prakritiResult.dosha,
                type: prakritiResult.type,
                dominant: prakritiResult.dominant,
                secondary: prakritiResult.secondary,
            },
            agniType: prakritiResult.agniType,
            agni: AGNI_TYPES[prakritiResult.agniType],
            manasPrakriti: prakritiResult.manasPrakriti,
            healthVulnerabilities,
            calculatedAt: Timestamp.now(),
            version: "v1",
        };

        // Store in user document
        await db.collection("users").doc(uid).update({
            ayurvedaData: ayurvedaProfile,
        });

        logger.info("✅ Ayurveda profile calculated", {
            uid,
            type: prakritiResult.type,
            agniType: prakritiResult.agniType,
        });

        return {
            success: true,
            prakriti: ayurvedaProfile.prakriti,
            agniType: ayurvedaProfile.agniType,
        };
    } catch (error) {
        logger.error("❌ Error calculating Ayurveda profile", {
            uid,
            error: error.message,
        });
        throw error;
    }
}

// ============================================================================
// CALCULATE VIKRITI (Current State)
// Called on-demand to get current dosha balance
// ============================================================================

export async function handleCalculateCurrentVikriti(request) {
    const uid = requireAuth(request, "calculate current vikriti");
    const { symptoms } = request.data || {};

    try {
        // Get user data
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const ayurvedaData = userData?.ayurvedaData;
        const astroData = userData?.astrologyData;

        if (!ayurvedaData?.prakriti) {
            throw new HttpsError(
                "failed-precondition",
                "Prakriti must be calculated first",
            );
        }

        const vikriti = await computeVikritiFromUserData(
            astroData, ayurvedaData.prakriti, { symptoms },
        );

        return vikriti;
    } catch (error) {
        logger.error("❌ Error calculating Vikriti", {
            uid,
            error: error.message,
        });
        throw error;
    }
}

// ============================================================================
// VIKRITI COMPUTATION HELPER
// Shared by calculateCurrentVikriti (on-demand) and onHealthSnapshotWrite (auto)
// ============================================================================

/**
 * Compute Vikriti from user's astrology + ayurveda data.
 * Assembles dasha, transits, tarabala, chandrabala, ashtakavarga inputs
 * and calls calculateVikriti.
 *
 * @param {object} astroData  - User's astrologyData from Firestore
 * @param {object} prakriti   - User's ayurvedaData.prakriti
 * @param {object} [options]  - Optional overrides (symptoms, etc.)
 * @returns {Promise<object|null>} Vikriti result or null if insufficient data
 */
async function computeVikritiFromUserData(astroData, prakriti, options = {}) {
    if (!prakriti || !astroData) return null;

    const { symptoms } = options;

    // Extract current dasha planet
    let currentDashaPlanet = null;
    let currentAntarDashaPlanet = null;

    if (astroData?.currentDasha) {
        currentDashaPlanet = astroData.currentDasha.currentMaha?.planet ||
            astroData.currentDasha.mahadasha?.planet;
        currentAntarDashaPlanet = astroData.currentDasha.currentAntar?.planet ||
            astroData.currentDasha.antardasha?.planet;
    }

    // Calculate age
    let age = null;
    if (astroData?.birthYear) {
        age = new Date().getFullYear() - astroData.birthYear;
    }

    // Current month for season
    const currentMonth = new Date().getMonth() + 1;

    // === Dasha Planet Strength (prefer Shadbala from API, fallback to dignity) ===
    let dashaPlanetDignity = null;
    if (currentDashaPlanet && astroData?.processedPlanets) {
        const dashaPlanetData = astroData.processedPlanets.find(
            (p) => (p.name || p.planet) === currentDashaPlanet,
        );

        if (dashaPlanetData) {
            const dignity = dashaPlanetData.dignity || "neutral";
            const dignityScore = dashaPlanetData.dignityScore || 50;

            const ascSign = astroData.ascendant;
            const isYK = isYogakaraka(currentDashaPlanet, ascSign);
            const dusthana = checkDusthanaLordship(currentDashaPlanet, ascSign);

            let shadBalaStrength = null;
            if (astroData.shadBala && astroData.shadBala[currentDashaPlanet]) {
                const shadBalaValue = astroData.shadBala[currentDashaPlanet];
                if (typeof shadBalaValue === "number") {
                    shadBalaStrength = shadBalaValue;
                } else if (shadBalaValue?.total || shadBalaValue?.strength) {
                    shadBalaStrength = shadBalaValue.total || shadBalaValue.strength;
                }
            }

            dashaPlanetDignity = {
                dignity,
                dignityScore,
                isYogakaraka: isYK,
                isDusthanaLord: dusthana?.isDusthanaLord || false,
                dusthanaHouses: dusthana?.houses || [],
                ...(shadBalaStrength != null && { shadBalaStrength }),
                usingShadBala: shadBalaStrength != null,
            };
        }
    }

    // === Ashtakavarga for transits ===
    let ashtakavarga = null;
    let transitBinduScores = null;
    if (astroData?.processedPlanets && astroData?.ascendant) {
        try {
            ashtakavarga = calculateAshtakavarga(astroData.processedPlanets, astroData.ascendant);
        } catch (e) {
            logger.warn("⚠️ Ashtakavarga calculation failed", { error: e?.message });
        }
    }

    // === Transits (cached) + aspects refinement ===
    let transitEffect = null;
    let transitFactors = [];
    let tarabala = null;
    let chandrabala = null;

    try {
        const todayKey = getTodayDateKeyUTC();
        const skyDoc = await db.collection("global_astro").doc("sky_positions").get();
        const skyPositions = skyDoc.exists ? (skyDoc.data()?.positions || {}) : {};
        const todayTransits = skyPositions?.[todayKey] || null;

        if (todayTransits) {
            const ascendantDegree = extractAscendantDegreeFromAstroData(astroData);
            const natalPlanets = buildNatalPlanetsForAspects(astroData);

            const computed = computeTransitEffectAndFactors({
                transits: todayTransits,
                ascendantDegree,
                dashaData: {
                    mahadasha: currentDashaPlanet,
                    antardasha: currentAntarDashaPlanet,
                },
                natalPlanets,
            });

            transitEffect = computed.transitEffect;
            transitFactors = computed.transitFactors;

            // Tarabala (Moon nakshatra relationship)
            const birthNakshatra = astroData?.moonNakshatra || astroData?.nakshatra;
            const currentMoon = todayTransits?.Moon;
            if (birthNakshatra && currentMoon?.nakshatra) {
                tarabala = calculateTarabala(birthNakshatra, currentMoon.nakshatra);
            }

            // Chandrabala (Moon sign relationship)
            const birthMoonSign = astroData?.moonSign || getBirthMoonSign(astroData);
            const currentMoonSign = currentMoon?.sign;
            if (birthMoonSign && currentMoonSign) {
                chandrabala = calculateChandrabala(birthMoonSign, currentMoonSign);
            }

            // Transit Bindu Scores using Ashtakavarga
            if (ashtakavarga) {
                transitBinduScores = {};
                const slowPlanets = ["Saturn", "Jupiter", "Rahu"];
                for (const planet of slowPlanets) {
                    const transitData = todayTransits[planet];
                    if (transitData?.sign) {
                        const score = getTransitBinduScore(planet, transitData.sign, ashtakavarga);
                        if (score) {
                            transitBinduScores[planet] = score;
                        }
                    }
                }
            }
        }
    } catch (e) {
        logger.warn("⚠️ computeVikritiFromUserData: transit refinement skipped", {
            error: e?.message || String(e),
        });
    }

    return calculateVikriti({
        prakriti,
        currentDashaPlanet,
        currentAntarDashaPlanet,
        age,
        currentMonth,
        symptoms,
        transitEffect,
        transitFactors,
        dashaPlanetDignity,
        tarabala,
        chandrabala,
        transitBinduScores,
    });
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Get birth Moon sign from astrology data
 * Extracts Moon sign from processedPlanets or birth chart
 */
function getBirthMoonSign(astroData) {
    // Try processedPlanets first
    const pp = astroData?.processedPlanets;
    if (Array.isArray(pp)) {
        const moon = pp.find((p) => (p.name || p.planet) === "Moon");
        if (moon?.sign) return moon.sign;
    }

    // Try birthChartData
    const moonData = astroData?.birthChartData?.output?.Moon ||
        Object.values(astroData?.birthChartData?.output || {}).find(
            (p) => p?.name === "Moon",
        );
    if (moonData?.sign) return moonData.sign;

    return null;
}

// findWeakPlanets, getSixthHouseSign, getPlanetsInHouse
// → Moved to lib/ayurveda_service.js (imported above)

// ============================================================================
// AI-POWERED AYURVEDA RECOMMENDATIONS
// Uses Gemini to generate personalized wellness advice
// ============================================================================

/**
 * Get AI-powered Ayurveda recommendations based on user's profile and current state
 */
export async function handleGetAyurvedaRecommendations(request) {
    const uid = requireAuth(request, "get Ayurveda recommendations");
    logger.info("🌿 Generating AI Ayurveda recommendations", { uid });

    try {
        // Get user data
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const ayurvedaData = userData?.ayurvedaData;

        if (!ayurvedaData?.prakriti) {
            throw new HttpsError(
                "failed-precondition",
                "Ayurveda profile required for recommendations",
            );
        }

        const prakriti = ayurvedaData.prakriti;
        const vikriti = ayurvedaData.vikriti;
        const agniType = ayurvedaData.agniType;
        const manasPrakriti = ayurvedaData.manasPrakriti;
        const vulnerabilities = ayurvedaData.healthVulnerabilities || [];

        // Build context for AI
        const imbalances = vikriti?.imbalances || [];
        const factors = vikriti?.factors || [];

        // Get current season
        const currentMonth = new Date().getMonth() + 1;
        const seasonMap = {
            1: "Late Winter (Shishira)", 2: "Late Winter (Shishira)",
            3: "Spring (Vasanta)", 4: "Spring (Vasanta)",
            5: "Summer (Grishma)", 6: "Summer (Grishma)",
            7: "Monsoon (Varsha)", 8: "Monsoon (Varsha)",
            9: "Autumn (Sharad)", 10: "Autumn (Sharad)",
            11: "Early Winter (Hemanta)", 12: "Early Winter (Hemanta)",
        };
        const currentSeason = seasonMap[currentMonth] || "Seasonal transition";

        // Build the prompt
        const prompt = buildAyurvedaPrompt({
            prakriti,
            vikriti: vikriti?.dosha,
            imbalances,
            factors,
            agniType,
            manasPrakriti,
            vulnerabilities,
            currentSeason,
        });

        // Call Gemini
        const apiKey = geminiApiKey.value();
        if (!apiKey) {
            throw new HttpsError("internal", "AI service not configured");
        }

        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({
            model: AI_MODELS.GEMINI_FLASH,
            generationConfig: {
                temperature: 0.7,
                maxOutputTokens: 1024,
                responseMimeType: "application/json",
            },
        });

        const result = await model.generateContent(prompt);
        const response = result.response;
        const text = response.text();

        // Parse JSON response
        let recommendations;
        try {
            recommendations = JSON.parse(text);
        } catch (parseError) {
            logger.warn("Failed to parse AI response as JSON, using raw", { text });
            recommendations = {
                diet: { favor: [], avoid: [], reasoning: text },
                lifestyle: [],
                quickRemedy: { action: "Follow your body's wisdom", reasoning: text },
            };
        }

        logger.info("✅ AI recommendations generated", { uid, hasImbalances: imbalances.length > 0 });

        return {
            success: true,
            recommendations,
            context: {
                prakritiType: prakriti.type,
                vikritiBalanced: vikriti?.balanced ?? true,
                topImbalance: imbalances[0]?.dosha || null,
                season: currentSeason,
            },
            generatedAt: new Date().toISOString(),
        };
    } catch (error) {
        logger.error("❌ Error generating AI recommendations", {
            uid,
            error: error.message,
        });
        throw error;
    }
}

/**
 * Build the Ayurveda recommendation prompt for Gemini
 */
function buildAyurvedaPrompt({
    prakriti,
    vikriti,
    imbalances,
    factors,
    agniType,
    manasPrakriti,
    vulnerabilities,
    currentSeason,
}) {
    // Format imbalances
    const imbalanceText = imbalances.length > 0 ?
        imbalances.map((i) => `${i.dosha} (shifted +${i.shift}%, ${i.severity} severity)`).join(", ") :
        "Currently balanced";

    // Format contributing factors
    const factorText = factors.length > 0 ?
        factors.map((f) => {
            const guidance = f.guidance ? ` - ${f.guidance}` : "";
            return `• ${f.description}: affects ${f.dosha}${guidance}`;
        }).join("\n") :
        "No specific factors identified";

    // Format vulnerabilities
    const vulnText = vulnerabilities.slice(0, 3).map((v) => v.description).join("; ");

    return `You are an expert Ayurvedic wellness advisor providing personalized daily guidance. Be specific, practical, and warm.

## User's Ayurvedic Profile

**Prakriti (Constitution):**
- Type: ${prakriti.type}
- Vata: ${prakriti.vata}%, Pitta: ${prakriti.pitta}%, Kapha: ${prakriti.kapha}%
- Dominant: ${prakriti.dominant}

**Current State (Vikriti):**
${vikriti ? `- Vata: ${vikriti.vata}%, Pitta: ${vikriti.pitta}%, Kapha: ${vikriti.kapha}%` : "- Not yet calculated"}
- Imbalances: ${imbalanceText}

**Digestive Fire (Agni):** ${agniType || "Unknown"}

**Mental Constitution:** ${manasPrakriti?.dominant || "Balanced"} dominant (${manasPrakriti?.guna?.sattva || 33}% Sattva, ${manasPrakriti?.guna?.rajas || 33}% Rajas, ${manasPrakriti?.guna?.tamas || 34}% Tamas)

**Health Considerations:** ${vulnText || "None identified"}

**Current Season:** ${currentSeason}

**Contributing Factors Today:**
${factorText}

## Instructions

Based on this profile, provide personalized Ayurvedic recommendations in the following JSON format:

{
  "diet": {
    "favor": ["5-6 specific foods to favor today, considering the dosha imbalances and season"],
    "avoid": ["2-3 foods to minimize or avoid"],
    "reasoning": "Brief explanation of why these foods help (1-2 sentences)"
  },
  "lifestyle": [
    "2-3 specific daily routine adjustments or practices, be actionable and practical"
  ],
  "quickRemedy": {
    "action": "One quick remedy or practice for the most pressing imbalance (or for general balance if none)",
    "reasoning": "Why this helps (1 sentence)"
  },
  "mindfulness": "A brief personalized insight or affirmation based on their mental constitution (1 sentence)"
}

Important:
- Be specific (e.g., "warm ginger tea with honey" not just "warm drinks")
- Consider the season and current factors
- Focus on the top imbalance if present
- Keep advice practical and accessible
- Use a warm, supportive tone`;
}

// ============================================================================
// Health Snapshot Analysis — processes watch health data for trend analysis
// ============================================================================

/**
 * Analyze watch health snapshots to compute weekly health trends and
 * Ayurvedic insights. Called periodically or on-demand.
 *
 * Reads the last 7 daily snapshots from healthSnapshots subcollection,
 * computes trend direction for each signal, and stores a summary.
 */
export async function handleAnalyzeHealthTrends(request) {
    const uid = requireAuth(request);

    try {
        const snapshotsRef = db
            .collection("users")
            .doc(uid)
            .collection("healthSnapshots");

        // Get last 7 days of snapshots
        const snapshot = await snapshotsRef
            .orderBy("updatedAt", "desc")
            .limit(7)
            .get();

        if (snapshot.empty) {
            return { success: true, message: "No health data available yet" };
        }

        const days = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
        days.reverse(); // oldest first for trend calculation

        // Compute trends for key signals
        const trends = {};
        const signalKeys = [
            "ojasScore", "hrv", "restingHR", "sleepHours",
            "deepSleepMins", "remSleepMins", "spO2", "steps",
            "respRate", "vo2Max", "activeEnergy",
        ];

        for (const key of signalKeys) {
            const values = days
                .map((d) => d[key])
                .filter((v) => v != null && !isNaN(v));

            if (values.length >= 2) {
                const first = values.slice(0, Math.ceil(values.length / 2));
                const second = values.slice(Math.ceil(values.length / 2));
                const avgFirst = first.reduce((a, b) => a + b, 0) / first.length;
                const avgSecond = second.reduce((a, b) => a + b, 0) / second.length;
                const change = avgSecond - avgFirst;
                const pctChange = avgFirst > 0 ? (change / avgFirst) * 100 : 0;

                trends[key] = {
                    current: values[values.length - 1],
                    avg: values.reduce((a, b) => a + b, 0) / values.length,
                    min: Math.min(...values),
                    max: Math.max(...values),
                    direction: Math.abs(pctChange) < 5 ? "stable" :
                        change > 0 ? "improving" : "declining",
                    pctChange: Math.round(pctChange * 10) / 10,
                    dataPoints: values.length,
                };
            }
        }

        // Derive dosha trend from health signals
        const doshaTrend = deriveDoshaTrend(trends);

        const analysis = {
            trends,
            doshaTrend,
            daysAnalyzed: days.length,
            latestSnapshot: days[days.length - 1]?.id,
            analyzedAt: FieldValue.serverTimestamp(),
        };

        // Store analysis
        await db.collection("users").doc(uid).update({
            "ayurvedaData.healthTrends": analysis,
        });

        logger.info(`Health trends analyzed for ${uid}: ${days.length} days, ${Object.keys(trends).length} signals`);

        return { success: true, analysis };
    } catch (error) {
        logger.error("analyzeHealthTrends error:", error);
        throw new HttpsError("internal", "Failed to analyze health trends");
    }
}

/**
 * Derive dosha trend from health signal trends.
 * Maps health changes to Ayurvedic dosha implications.
 */
function deriveDoshaTrend(trends) {
    let vataShift = 0;
    let pittaShift = 0;
    let kaphaShift = 0;

    // HRV: declining → Vata aggravation, improving → balance
    if (trends.hrv?.direction === "declining") {
        vataShift += 3;
    } else if (trends.hrv?.direction === "improving") {
        vataShift -= 2;
    }

    // Sleep: declining → Vata, excessive → Kapha
    if (trends.sleepHours) {
        if (trends.sleepHours.current < 6) vataShift += 4;
        else if (trends.sleepHours.current > 9) kaphaShift += 4;
        if (trends.sleepHours.direction === "declining") vataShift += 2;
    }

    // Resting HR: increasing → Pitta
    if (trends.restingHR?.direction === "improving") {
        // "improving" = increasing for RHR is actually worse
        pittaShift += 2;
    }

    // SpO2: declining → Kapha
    if (trends.spO2?.direction === "declining") {
        kaphaShift += 3;
    }

    // Steps: declining → Kapha
    if (trends.steps?.direction === "declining") {
        kaphaShift += 2;
    }

    // Active energy: declining → Kapha
    if (trends.activeEnergy?.direction === "declining") {
        kaphaShift += 2;
    }

    return {
        vata: vataShift,
        pitta: pittaShift,
        kapha: kaphaShift,
        dominant: vataShift >= pittaShift && vataShift >= kaphaShift ? "vata" :
            pittaShift >= vataShift && pittaShift >= kaphaShift ? "pitta" : "kapha",
        balanced: Math.max(vataShift, pittaShift, kaphaShift) < 3,
    };
}


// =============================================================================
// SCHEDULED: Nightly Health Trend Analysis
// =============================================================================

/** Extracted runner for orchestrator consolidation. */
export async function runNightlyHealthAnalysis() {
    logger.info("nightlyHealthAnalysis: starting");

    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 1); // users with data in last 24h

    // Find users with recent health snapshots
    const usersSnap = await db.collection("users")
        .where("ayurvedaData.prakriti", "!=", null)
        .limit(500)
        .get();

    let processed = 0;
    let errors = 0;

    for (const userDoc of usersSnap.docs) {
        try {
            const uid = userDoc.id;
            const snapshotsRef = db.collection("users").doc(uid).collection("healthSnapshots");
            const snapshot = await snapshotsRef.orderBy("updatedAt", "desc").limit(7).get();

            if (snapshot.empty) continue;

            const days = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
            days.reverse();

            const trends = {};
            const signalKeys = [
                "ojasScore", "hrv", "restingHR", "sleepHours",
                "deepSleepMins", "remSleepMins", "spO2", "steps",
                "respRate", "vo2Max", "activeEnergy",
            ];

            for (const key of signalKeys) {
                const values = days.map((d) => d[key]).filter((v) => v != null && !isNaN(v));
                if (values.length >= 2) {
                    const first = values.slice(0, Math.ceil(values.length / 2));
                    const second = values.slice(Math.ceil(values.length / 2));
                    const avgFirst = first.reduce((a, b) => a + b, 0) / first.length;
                    const avgSecond = second.reduce((a, b) => a + b, 0) / second.length;
                    const change = avgSecond - avgFirst;
                    const pctChange = avgFirst > 0 ? (change / avgFirst) * 100 : 0;

                    trends[key] = {
                        current: values[values.length - 1],
                        avg: Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10,
                        min: Math.min(...values),
                        max: Math.max(...values),
                        direction: Math.abs(pctChange) < 5 ? "stable" :
                            change > 0 ? "improving" : "declining",
                        pctChange: Math.round(pctChange * 10) / 10,
                        dataPoints: values.length,
                    };
                }
            }

            const doshaTrend = deriveDoshaTrend(trends);

            await db.collection("users").doc(uid).update({
                "ayurvedaData.healthTrends": {
                    trends,
                    doshaTrend,
                    daysAnalyzed: days.length,
                    latestSnapshot: days[days.length - 1]?.id,
                    analyzedAt: FieldValue.serverTimestamp(),
                },
            });

            processed++;
        } catch (err) {
            errors++;
            logger.warn(`nightlyHealthAnalysis: error for user ${userDoc.id}`, err);
        }
    }

    logger.info(`nightlyHealthAnalysis: done. processed=${processed}, errors=${errors}`);
}

/**
 * Runs every night at 23:30 UTC. For each user with recent health snapshots,
 * computes 7-day trend analysis and stores it on the user doc.
 */
// NOTE: `nightlyHealthAnalysis` was a standalone `onSchedule` export at 23:30 UTC.
// It is now invoked by `unifiedOrchestrator` Phase 5 (health) via the
// `runNightlyHealthAnalysis` runner above.


// =============================================================================
// SCHEDULED: Weekly Health Aggregation
// =============================================================================

/** Extracted runner for orchestrator consolidation. */
export async function runWeeklyHealthAggregation() {
    logger.info("weeklyHealthAggregation: starting");

    const now = DateTime.now().setZone("UTC");
    const weekKey = `${now.toFormat("yyyy")}-W${now.weekNumber.toString().padStart(2, "0")}`;
    const weekStart = now.startOf("week").minus({ weeks: 1 });
    const weekEnd = now.startOf("week");

    const usersSnap = await db.collection("users")
        .where("ayurvedaData.prakriti", "!=", null)
        .limit(500)
        .get();

    let processed = 0;

    for (const userDoc of usersSnap.docs) {
        try {
            const uid = userDoc.id;
            const snapshotsRef = db.collection("users").doc(uid).collection("healthSnapshots");

            // Get snapshots from the past week
            const snapshot = await snapshotsRef
                .where("updatedAt", ">=", Timestamp.fromDate(weekStart.toJSDate()))
                .where("updatedAt", "<", Timestamp.fromDate(weekEnd.toJSDate()))
                .orderBy("updatedAt", "asc")
                .get();

            if (snapshot.empty) continue;

            const days = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));

            // Aggregate each signal
            const signalKeys = [
                "ojasScore", "hrv", "restingHR", "sleepHours",
                "deepSleepMins", "remSleepMins", "spO2", "steps",
                "respRate", "vo2Max", "activeEnergy", "mindfulMins",
            ];

            const summary = {};
            for (const key of signalKeys) {
                const values = days.map((d) => d[key]).filter((v) => v != null && !isNaN(v));
                if (values.length > 0) {
                    summary[key] = {
                        avg: Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10,
                        min: Math.min(...values),
                        max: Math.max(...values),
                        dataPoints: values.length,
                    };
                }
            }

            // Dominant nadi dosha for the week
            const nadiDoshas = days.map((d) => d.nadiDosha).filter(Boolean);
            const doshaCounts = {};
            for (const d of nadiDoshas) {
                doshaCounts[d.toLowerCase()] = (doshaCounts[d.toLowerCase()] || 0) + 1;
            }
            const weeklyDominantDosha = Object.entries(doshaCounts)
                .sort((a, b) => b[1] - a[1])[0]?.[0] || null;

            await db.collection("users").doc(uid)
                .collection("healthTrends").doc(weekKey).set({
                    weekKey,
                    weekStart: Timestamp.fromDate(weekStart.toJSDate()),
                    weekEnd: Timestamp.fromDate(weekEnd.toJSDate()),
                    daysWithData: days.length,
                    signals: summary,
                    dominantDosha: weeklyDominantDosha,
                    doshaCounts,
                    createdAt: FieldValue.serverTimestamp(),
                });

            processed++;
        } catch (err) {
            logger.warn(`weeklyHealthAggregation: error for user ${userDoc.id}`, err);
        }
    }

    logger.info(`weeklyHealthAggregation: done. processed=${processed}, weekKey=${weekKey}`);
}

/**
 * Runs every Monday at 00:15 UTC. Rolls up the past 7 days of health snapshots
 * into a weekly summary stored in users/{uid}/healthTrends/{weekKey}.
 */
// NOTE: `weeklyHealthAggregation` was a standalone `onSchedule` export at
// 00:15 UTC on Mondays. It is now invoked by `unifiedOrchestrator` Phase 5
// (health, Monday-only branch) via the `runWeeklyHealthAggregation` runner above.


// =============================================================================
// TRIGGER: Auto-analyze on new health snapshot
// =============================================================================

/**
 * When a health snapshot is written (create or update), automatically
 * store a "recommendations" field with dosha-aware guidance based on
 * the latest signals — so the phone can sync it to the watch.
 *
 * SAFETY:
 *  - `withLoopGuard` hashes the input signal fields and stores the hash
 *    in `_meta.onHealthSnapshotWrite.inputHash`. When this function's
 *    own write-back retriggers the function, the input hash matches
 *    the stored hash, so we exit immediately — preventing the infinite
 *    loop that caused the May 2026 cost incident.
 *  - `maxInstances: 5` bounds the blast radius if the guard ever fails
 *    (was unbounded; previously hit 33M invocations / 11 days).
 *  - `concurrency: 1` (inherited from global) ensures one call per
 *    instance so retries don't compound.
 */
/**
 * Input fields hashed for loop guard. We hash ALL health signal fields
 * that the engines read — so the function only re-runs when actual
 * health data changes, not when we write back engine results.
 *
 * IMPORTANT: Do NOT include fields the function writes (analysis.*,
 * engineOjas.*, engineNadi.*) or server timestamps.
 */
const HEALTH_INPUT_FIELDS = (d) => ({
    // Primary vitals
    hrv: d.hrv ?? null,
    restingHR: d.restingHR ?? null,
    sleepHours: d.sleepHours ?? null,
    deepSleepMins: d.deepSleepMins ?? null,
    remSleepMins: d.remSleepMins ?? null,
    spO2: d.spO2 ?? null,
    respRate: d.respRate ?? null,
    wristTemp: d.wristTemp ?? null,
    // Activity
    steps: d.steps ?? null,
    activeEnergy: d.activeEnergy ?? null,
    standHours: d.standHours ?? null,
    exerciseMins: d.exerciseMins ?? null,
    distance: d.distance ?? null,
    daylightMins: d.daylightMins ?? null,
    // Beat-to-beat HRV
    rmssd: d.rmssd ?? null,
    pnn50: d.pnn50 ?? null,
    // Fitness / recovery
    vo2Max: d.vo2Max ?? null,
    hrRecovery: d.hrRecovery ?? null,
    // Cardiac
    afibBurden: d.afibBurden ?? null,
    highHRCount: d.highHRCount ?? null,
    irregularRhythmCount: d.irregularRhythmCount ?? null,
    // Gait
    walkingHR: d.walkingHR ?? null,
    walkingAsymmetry: d.walkingAsymmetry ?? null,
    doubleSupport: d.doubleSupport ?? null,
    walkingSteadiness: d.walkingSteadiness ?? null,
    // Safety / environment
    fallCount: d.fallCount ?? null,
    sleepApneaCount: d.sleepApneaCount ?? null,
    lowCardioFitnessCount: d.lowCardioFitnessCount ?? null,
    uvExposure: d.uvExposure ?? null,
    envAudioExposure: d.envAudioExposure ?? null,
    mindfulMins: d.mindfulMins ?? null,
    // v2 signals
    heartRate: d.heartRate ?? null,
    vo2Max: d.vo2Max ?? null,
    exerciseMins: d.exerciseMins ?? null,
    coreSleepMins: d.coreSleepMins ?? null,
    walkingHR: d.walkingHR ?? null,
    walkingAsymmetry: d.walkingAsymmetry ?? null,
    doubleSupport: d.doubleSupport ?? null,
    headphoneAudio: d.headphoneAudio ?? null,
    lowHRCount: d.lowHRCount ?? null,
    bodyTemp: d.bodyTemp ?? null,
    // Watch-computed (used for comparison, not overwritten)
    watchOjasScore: d.watchOjasScore ?? null,
    watchNadiDosha: d.watchNadiDosha ?? null,
});

export const onHealthSnapshotWrite = onDocumentWritten({
    document: "users/{userId}/healthSnapshots/{dayKey}",
    region: "asia-southeast2",
    maxInstances: 5,
}, withLoopGuard("onHealthSnapshotWrite", HEALTH_INPUT_FIELDS, async (event, ctx) => {
    const { userId, dayKey } = event.params;
    const after = ctx.after;

    try {
        // Read user doc for Prakriti + stored baseline
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data() ?? {};
        const ayurveda = userData.ayurvedaData;
        const prakriti = ayurveda?.prakriti;

        if (!prakriti) {
            // Still stamp meta so we don't re-run on every retry
            // for a user who hasn't completed Prakriti onboarding.
            await event.data.after.ref.update(ctx.metaPatch);
            return;
        }

        // Load engine weights (Firestore-configurable, cached 5 min)
        const weights = await getWeights();

        // Load personal baseline from user doc (computed nightly/weekly)
        const storedBaseline = ayurveda?.healthBaseline ?? null;

        // ── Compute backend Ojas ────────────────────────────────────────
        const ojasResult = computeOjas(after, storedBaseline, weights);

        // ── Compute backend Nadi ────────────────────────────────────────
        const nadiResult = computeNadi(after, storedBaseline, weights);

        // ── Determine dominant dosha for recommendations ────────────────
        const dominant = nadiResult?.dominant?.toLowerCase() ??
            (after.watchNadiDosha?.toLowerCase()) ??
            inferDominantFallback(after);

        // ── Generate recommendations ────────────────────────────────────
        const recs = generateQuickRecommendations(dominant, {
            hrv: after.hrv,
            restingHR: after.restingHR,
            sleep: after.sleepHours,
            ojas: ojasResult?.score ?? after.watchOjasScore ?? after.ojasScore,
        });

        // ── Build update payload ────────────────────────────────────────
        // CRITICAL: ctx.metaPatch MUST be included in this single update
        // so the new inputHash is persisted atomically with the result.
        const updatePayload = {
            // Legacy analysis fields (kept for backward compat)
            "analysis.signalDosha": dominant,
            "analysis.recommendations": recs,
            "analysis.analyzedAt": FieldValue.serverTimestamp(),
            ...ctx.metaPatch,
        };

        // Backend Ojas result
        if (ojasResult) {
            updatePayload["engineOjas.score"] = ojasResult.score;
            updatePayload["engineOjas.baseScore"] = ojasResult.baseScore;
            updatePayload["engineOjas.summary"] = ojasResult.summary;
            updatePayload["engineOjas.agniType"] = ojasResult.agniType;
            updatePayload["engineOjas.agniDescription"] = ojasResult.agniDescription;
            updatePayload["engineOjas.modifierDelta"] = ojasResult.modifierDelta;
            updatePayload["engineOjas.ceiling"] = ojasResult.ceiling;
            updatePayload["engineOjas.signalCount"] = ojasResult.signalCount;
            updatePayload["engineOjas.isReliable"] = ojasResult.isReliable;
            updatePayload["engineOjas.computedAt"] = FieldValue.serverTimestamp();
            // Store contributors + modifiers as arrays for transparency
            updatePayload["engineOjas.contributors"] = ojasResult.contributors.map((c) => ({
                name: c.name,
                score: Math.round(c.score * 100) / 100,
                status: c.status,
                weight: c.weight,
            }));
            updatePayload["engineOjas.modifiers"] = ojasResult.modifiers.map((m) => ({
                name: m.name,
                delta: m.delta,
                ...(m.note ? { note: m.note } : {}),
            }));
        }

        // Backend Nadi result
        if (nadiResult) {
            updatePayload["engineNadi.vata"] = nadiResult.vata;
            updatePayload["engineNadi.pitta"] = nadiResult.pitta;
            updatePayload["engineNadi.kapha"] = nadiResult.kapha;
            updatePayload["engineNadi.dominant"] = nadiResult.dominant;
            updatePayload["engineNadi.gati"] = nadiResult.gati;
            updatePayload["engineNadi.confidence"] = nadiResult.confidence;
            updatePayload["engineNadi.signalCount"] = nadiResult.signalCount;
            updatePayload["engineNadi.computedAt"] = FieldValue.serverTimestamp();
            updatePayload["engineNadi.contributors"] = nadiResult.contributors;
        }

        // Write everything in one atomic update (loop-safe)
        await event.data.after.ref.update(updatePayload);

        // Also update user's latest results for watch sync + quick reads.
        // (Different document, no loop risk.)
        const userUpdate = {
            "ayurvedaData.latestRecommendations": {
                dosha: dominant,
                items: recs,
                basedOn: dayKey,
                updatedAt: FieldValue.serverTimestamp(),
            },
        };

        if (ojasResult) {
            userUpdate["ayurvedaData.latestOjas"] = {
                score: ojasResult.score,
                summary: ojasResult.summary,
                agniType: ojasResult.agniType,
                signalCount: ojasResult.signalCount,
                isReliable: ojasResult.isReliable,
                dayKey,
                updatedAt: FieldValue.serverTimestamp(),
            };
        }

        if (nadiResult) {
            userUpdate["ayurvedaData.latestNadi"] = {
                vata: nadiResult.vata,
                pitta: nadiResult.pitta,
                kapha: nadiResult.kapha,
                dominant: nadiResult.dominant,
                gati: nadiResult.gati,
                confidence: nadiResult.confidence,
                dayKey,
                updatedAt: FieldValue.serverTimestamp(),
            };
        }

        // ── Compute Vikriti (current balance) ───────────────────────────
        // Keeps ayurvedaData.vikriti fresh so the HolyCow dashboard card
        // always has up-to-date balance data without requiring the user
        // to visit the Ayurveda Details page.
        const astroData = userData.astrologyData;
        try {
            const vikriti = await computeVikritiFromUserData(astroData, prakriti);
            if (vikriti) {
                userUpdate["ayurvedaData.vikriti"] = {
                    vata: vikriti.dosha.vata,
                    pitta: vikriti.dosha.pitta,
                    kapha: vikriti.dosha.kapha,
                    balanced: vikriti.balanced,
                    imbalances: (vikriti.imbalances || []).map((i) => ({
                        dosha: i.dosha,
                        shift: i.shift,
                        severity: i.severity,
                        prakritiValue: i.prakritiValue,
                        vikritiValue: i.vikritiValue,
                    })),
                    factors: (vikriti.factors || []).map((f) => ({
                        source: f.source,
                        dosha: f.dosha,
                        description: f.description,
                        strength: f.strength,
                        ...(f.guidance ? { guidance: f.guidance } : {}),
                    })),
                    calculatedAt: FieldValue.serverTimestamp(),
                };
            }
        } catch (e) {
            // Non-fatal — nadi/ojas/recs still get written
            logger.warn(`onHealthSnapshotWrite: vikriti computation skipped for ${userId}`, {
                error: e?.message || String(e),
            });
        }

        await db.collection("users").doc(userId).update(userUpdate);

        logger.info(`onHealthSnapshotWrite: analyzed ${dayKey} for ${userId}`, {
            dominant,
            ojasScore: ojasResult?.score ?? null,
            nadiDominant: nadiResult?.dominant ?? null,
            nadiConfidence: nadiResult?.confidence ?? null,
            hasVikriti: !!userUpdate["ayurvedaData.vikriti"],
            signalCount: (ojasResult?.signalCount ?? 0) + (nadiResult?.signalCount ?? 0),
        });
    } catch (err) {
        logger.warn(`onHealthSnapshotWrite: error for ${userId}/${dayKey}`, err);
        // Stamp meta even on error so a retry storm doesn't loop.
        try {
            await event.data.after.ref.update(ctx.metaPatch);
        } catch (_) {/* ignore */}
    }
}));

/**
 * Fallback dominant dosha inference when NadiEngine has no HRV data.
 * Uses the simple heuristic from the original implementation.
 */
function inferDominantFallback(after) {
    let vata = 0; let pitta = 0; let kapha = 0;
    if (after.hrv != null) {
        if (after.hrv < 30) vata += 3;
        else if (after.hrv > 80) kapha += 1;
    }
    if (after.restingHR != null) {
        if (after.restingHR > 80) pitta += 2;
        else if (after.restingHR < 55) kapha += 2;
    }
    if (after.sleepHours != null) {
        if (after.sleepHours < 5.5) vata += 3;
        else if (after.sleepHours > 9.5) kapha += 3;
    }
    if (vata >= pitta && vata >= kapha) return "vata";
    if (pitta >= vata && pitta >= kapha) return "pitta";
    return "kapha";
}

/**
 * Generate quick dosha-aware recommendations from health signals.
 */
function generateQuickRecommendations(dominant, signals) {
    const recs = [];

    if (dominant === "vata") {
        recs.push({ type: "food", text: "Warm soups and cooked grains. Avoid cold, raw foods." });
        recs.push({ type: "activity", text: "Gentle yoga or walking. Avoid intense exercise." });
        recs.push({ type: "routine", text: "Early bedtime. Warm oil self-massage (Abhyanga)." });
        if (signals.sleep != null && signals.sleep < 6) {
            recs.push({ type: "urgent", text: "Sleep is critically low — prioritize rest tonight." });
        }
        if (signals.hrv != null && signals.hrv < 25) {
            recs.push({ type: "urgent", text: "HRV is very low — practice Nadi Shodhana breathing." });
        }
    } else if (dominant === "pitta") {
        recs.push({ type: "food", text: "Cooling foods — cucumber, coconut water, sweet fruits." });
        recs.push({ type: "activity", text: "Swimming or moonlight walks. Avoid midday exercise." });
        recs.push({ type: "routine", text: "Sheetali pranayama. Avoid skipping meals." });
        if (signals.restingHR != null && signals.restingHR > 85) {
            recs.push({ type: "urgent", text: "Heart rate elevated — take cooling breaks." });
        }
    } else {
        recs.push({ type: "food", text: "Light, warm, spiced meals. Reduce dairy and sweets." });
        recs.push({ type: "activity", text: "Vigorous exercise — running, HIIT. Best before 10 AM." });
        recs.push({ type: "routine", text: "Kapalabhati breathing. Dry brushing before shower." });
        if (signals.sleep != null && signals.sleep > 9) {
            recs.push({ type: "urgent", text: "Excessive sleep — try waking earlier with stimulating activity." });
        }
    }

    // Universal Ojas guidance
    if (signals.ojas != null) {
        if (signals.ojas < 40) {
            recs.push({ type: "ojas", text: "Ojas is low — rest, nourish, avoid stimulants." });
        } else if (signals.ojas > 80) {
            recs.push({ type: "ojas", text: "Ojas is strong — great day for focused work or meditation." });
        }
    }

    return recs;
}
