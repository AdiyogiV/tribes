/**
 * Ayurveda Cloud Functions
 *
 * Provides Prakriti calculation from astrology data,
 * Vikriti calculation, and wellness recommendations.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { requireAuth } from "../lib/auth_utils.js";
import { db } from "../lib/firebase.js";
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
import { DateTime } from "luxon";
import {
    calculateHouseFromDegree,
    calculateTransitAspects,
    scoreAspects,
    calculatePlanetDignity,
    calculateAshtakavarga,
    getTransitBinduScore,
} from "./vedic_analysis.js";
import { extractAscendantDegree as extractAscendantDegreeFromAstroData } from "../lib/astro_helpers.js";

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
// Called internally when birth details change (not a Cloud Function)
// ============================================================================

/**
 * Completely reset and recalculate Ayurveda profile from astrology data.
 * DELETES all existing ayurvedaData first, then creates fresh profile.
 * Called internally after astrology sync when birth details change.
 *
 * @param {string} uid - User ID
 * @param {object} astroData - Fresh astrology data
 * @returns {Promise<boolean>} - True if successful
 */
export async function resetAndRecalculateAyurveda(uid, astroData) {
    if (!astroData) {
        logger.warn("🌿 No astro data for Ayurveda reset", { uid });
        return false;
    }

    const ascendantSign = astroData.ascendant;
    const moonNakshatra = astroData.moonNakshatra || astroData.nakshatra;
    const birthLatitude = astroData.birthLatitude;
    const planets = astroData.processedPlanets || [];

    if (!ascendantSign) {
        logger.warn("🌿 No ascendant for Ayurveda calculation", { uid });
        return false;
    }

    try {
        logger.info("🌿 Resetting Ayurveda profile completely", { uid });

        // STEP 1: Delete entire ayurvedaData field first (complete clean slate)
        await db.collection("users").doc(uid).update({
            ayurvedaData: FieldValue.delete(),
        });

        logger.info("🗑️ Old ayurvedaData deleted", { uid });

        // STEP 2: Calculate fresh Prakriti
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

        // STEP 3: Build completely fresh Ayurveda profile
        const freshAyurvedaProfile = {
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
            prakritiRefined: false,
            calculatedAt: Timestamp.now(),
            version: "v1",
        };

        // STEP 4: Write fresh profile
        await db.collection("users").doc(uid).update({
            ayurvedaData: freshAyurvedaProfile,
        });

        logger.info("✅ Ayurveda profile reset and recalculated", {
            uid,
            type: prakritiResult.type,
            agniType: prakritiResult.agniType,
        });

        return true;
    } catch (error) {
        logger.error("❌ Error resetting Ayurveda profile", {
            uid,
            error: error.message,
        });
        return false;
    }
}

// ============================================================================
// RESET AYURVEDA PROFILE (User-callable)
// Allows user to manually reset and recalculate their Ayurveda profile
// ============================================================================

export const resetAyurvedaProfile = onCall({
    timeoutSeconds: 60,
    memory: "256MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
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
});

// ============================================================================
// CALCULATE AYURVEDA PROFILE
// Called to calculate/recalculate Prakriti from birth chart
// ============================================================================

export const calculateAyurvedaProfile = onCall({
    timeoutSeconds: 60,
    memory: "256MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
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
});

// ============================================================================
// CALCULATE VIKRITI (Current State)
// Called on-demand to get current dosha balance
// ============================================================================

export const calculateCurrentVikriti = onCall({
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "asia-southeast2",
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
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
                // Get natal dignity from processedPlanets (now included from API sync)
                let dignity = dashaPlanetData.dignity || "neutral";
                let dignityScore = dashaPlanetData.dignityScore || 50;

                // Check yogakaraka and dusthana lordship
                const ascSign = astroData.ascendant;
                const isYK = isYogakaraka(currentDashaPlanet, ascSign);
                const dusthana = checkDusthanaLordship(currentDashaPlanet, ascSign);

                // PREFER SHADBALA FROM API (more accurate than dignity alone)
                // Shadbala considers 6 types of strength including temporal and directional
                let shadBalaStrength = null;
                if (astroData.shadBala && astroData.shadBala[currentDashaPlanet]) {
                    const shadBalaValue = astroData.shadBala[currentDashaPlanet];
                    // Shadbala values typically range from 0.5 (weak) to 2.0+ (strong)
                    // Standard threshold is 1.0 (100% of required strength)
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
                    // Include Shadbala if available (from API)
                    ...(shadBalaStrength != null && { shadBalaStrength }),
                    // Mark if using API Shadbala (more accurate)
                    usingShadBala: shadBalaStrength != null,
                };
            }
        }

        // === NEW: Calculate Ashtakavarga for transits ===
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
        // We use globally cached sky positions (no external API calls) for a lightweight
        // "cosmic weather" refinement. This is intentionally low-impact.
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
                    // Pass simplified dasha data for correct scoring.
                    // (scoreAspects expects dashaData.mahadasha / dashaData.antardasha to be strings)
                    dashaData: {
                        mahadasha: currentDashaPlanet,
                        antardasha: currentAntarDashaPlanet,
                    },
                    natalPlanets,
                });

                transitEffect = computed.transitEffect;
                transitFactors = computed.transitFactors;

                // === NEW: Calculate Tarabala (Moon nakshatra relationship) ===
                const birthNakshatra = astroData?.moonNakshatra || astroData?.nakshatra;
                const currentMoon = todayTransits?.Moon;
                if (birthNakshatra && currentMoon?.nakshatra) {
                    tarabala = calculateTarabala(birthNakshatra, currentMoon.nakshatra);
                }

                // === NEW: Calculate Chandrabala (Moon sign relationship) ===
                const birthMoonSign = astroData?.moonSign || getBirthMoonSign(astroData);
                const currentMoonSign = currentMoon?.sign;
                if (birthMoonSign && currentMoonSign) {
                    chandrabala = calculateChandrabala(birthMoonSign, currentMoonSign);
                }

                // === NEW: Calculate Transit Bindu Scores using Ashtakavarga ===
                if (ashtakavarga) {
                    transitBinduScores = {};
                    // Focus on slow-moving planets for meaningful transit effects
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
            logger.warn("⚠️ Transit refinement skipped", {
                uid,
                error: e?.message || String(e),
            });
        }

        // Calculate Vikriti with all enhanced factors
        const vikriti = calculateVikriti({
            prakriti: ayurvedaData.prakriti,
            currentDashaPlanet,
            currentAntarDashaPlanet,
            age,
            currentMonth,
            symptoms,
            transitEffect,
            transitFactors,
            // Enhanced factors
            dashaPlanetDignity,
            tarabala,
            chandrabala,
            transitBinduScores,
        });

        return vikriti;
    } catch (error) {
        logger.error("❌ Error calculating Vikriti", {
            uid,
            error: error.message,
        });
        throw error;
    }
});

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

/**
 * Find weak planets from astrology data
 * Looks for combust, debilitated, or low strength planets
 */
function findWeakPlanets(astroData) {
    const weakPlanets = [];
    const planets = astroData.processedPlanets || [];

    for (const planet of planets) {
        const name = planet.name || planet.planet;
        if (!name) continue;

        // Check for combust
        if (planet.isCombust || planet.combust) {
            weakPlanets.push({ planet: name, reason: "combust" });
        }

        // Check for debilitated
        if (planet.dignity === "debilitated" || planet.isDebilitated) {
            weakPlanets.push({ planet: name, reason: "debilitated" });
        }

        // Check for low strength (if Shadbala available)
        if (planet.strength !== undefined && planet.strength < 1) {
            weakPlanets.push({ planet: name, reason: "low strength" });
        }
    }

    return weakPlanets;
}

/**
 * Get the sign on the 6th house
 */
function getSixthHouseSign(astroData) {
    // Try to get from houses data
    if (astroData.birthChartData?.output?.houses) {
        const houses = astroData.birthChartData.output.houses;
        if (houses[5]) { // 0-indexed, so 6th house is index 5
            return houses[5].sign || houses[5];
        }
    }

    // Fallback: calculate from ascendant (whole sign houses)
    const ascendant = astroData.ascendant;
    if (ascendant) {
        const signs = [
            "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
            "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
        ];
        const ascIndex = signs.findIndex(
            (s) => s.toLowerCase() === ascendant.toLowerCase(),
        );
        if (ascIndex >= 0) {
            return signs[(ascIndex + 5) % 12]; // 6th from ascendant
        }
    }

    return null;
}

/**
 * Get planets in a specific house
 */
function getPlanetsInHouse(astroData, houseNumber) {
    const planets = astroData.processedPlanets || [];
    return planets
        .filter((p) => p.house === houseNumber)
        .map((p) => p.name || p.planet);
}

// ============================================================================
// AI-POWERED AYURVEDA RECOMMENDATIONS
// Uses Gemini to generate personalized wellness advice
// ============================================================================

/**
 * Get AI-powered Ayurveda recommendations based on user's profile and current state
 */
export const getAyurvedaRecommendations = onCall({
    timeoutSeconds: 60,
    memory: "512MiB",
    region: "asia-southeast2",
    invoker: "public",
    secrets: [geminiApiKey],
    enforceAppCheck: false, // Disabled until Flutter client enables FirebaseAppCheck
}, async (request) => {
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
});

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
    const imbalanceText = imbalances.length > 0
        ? imbalances.map((i) => `${i.dosha} (shifted +${i.shift}%, ${i.severity} severity)`).join(", ")
        : "Currently balanced";

    // Format contributing factors
    const factorText = factors.length > 0
        ? factors.map((f) => {
            const guidance = f.guidance ? ` - ${f.guidance}` : "";
            return `• ${f.description}: affects ${f.dosha}${guidance}`;
        }).join("\n")
        : "No specific factors identified";

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
