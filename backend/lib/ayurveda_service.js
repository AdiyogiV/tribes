/**
 * Ayurveda Service — shared helpers for Ayurveda profile management.
 *
 * Extracted from functions/ayurveda.js so that astro_sync.js (astro domain)
 * can call resetAndRecalculateAyurveda without importing a Cloud Function
 * file from the health domain. This avoids cross-group dependencies when
 * the codebase is split into separate Firebase codebases.
 */

import { logger } from "firebase-functions";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { db } from "./firebase.js";
import {
    calculatePrakriti,
    analyzeHealthVulnerabilities,
    AGNI_TYPES,
} from "./ayurveda.js";

// ============================================================================
// Chart Helper Functions (pure computation, no Firestore)
// ============================================================================

/**
 * Find weak planets from astrology data.
 * Looks for combust, debilitated, or low strength planets.
 */
export function findWeakPlanets(astroData) {
    const weakPlanets = [];
    const planets = astroData.processedPlanets || [];

    for (const planet of planets) {
        const name = planet.name || planet.planet;
        if (!name) continue;

        if (planet.isCombust || planet.combust) {
            weakPlanets.push({ planet: name, reason: "combust" });
        }

        if (planet.dignity === "debilitated" || planet.isDebilitated) {
            weakPlanets.push({ planet: name, reason: "debilitated" });
        }

        if (planet.strength !== undefined && planet.strength < 1) {
            weakPlanets.push({ planet: name, reason: "low strength" });
        }
    }

    return weakPlanets;
}

/**
 * Get the sign on the 6th house.
 */
export function getSixthHouseSign(astroData) {
    if (astroData.birthChartData?.output?.houses) {
        const houses = astroData.birthChartData.output.houses;
        if (houses[5]) {
            return houses[5].sign || houses[5];
        }
    }

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
            return signs[(ascIndex + 5) % 12];
        }
    }

    return null;
}

/**
 * Get planets in a specific house.
 */
export function getPlanetsInHouse(astroData, houseNumber) {
    const planets = astroData.processedPlanets || [];
    return planets
        .filter((p) => p.house === houseNumber)
        .map((p) => p.name || p.planet);
}

// ============================================================================
// Reset and Recalculate Ayurveda Profile
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
