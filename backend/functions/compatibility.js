// compatibility.js — kundli matching / relationship compatibility.
//
// Split out of ephemeris.js: compatibility is its own product surface (two
// users, blocked/follow checks, its own cache version + scoring), distinct
// from the single-user ephemeris flow. Shares the one HTTP client.

import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { DateTime } from "luxon";
import { db, FieldValue } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";
import { FREE_ASTROLOGY_API } from "../lib/constants.js";
import { checkBlockedDetailed } from "../lib/utils.js";
import { callFreeAstro } from "./free_astro_client.js";
import {
    calculateCosmicMatch,
    calculateLifePhaseSync,
    normalizeNakshatra,
    normalizeSign,
} from "../lib/vedic_compatibility.js";

const { ASHTAKOOT: ASHTAKOOT_SCORE_ENDPOINT } = FREE_ASTROLOGY_API.ENDPOINTS;

const COMPATIBILITY_CACHE_TTL_DAYS = 30;
// Cache version - bump this when changing scoring algorithm to invalidate old cached scores
// v1 = initial
// v2 = 2026-01-06 scoring algorithm update (fixed low scores issue)
// v3 = 2026-01-06 comprehensive 8-pillar system (added sun sign, ascendant, element balance, etc.)
const COMPATIBILITY_CACHE_VERSION = "v3";
const MAX_ASHTAKOOT_SCORE = 36;

// Helper function to extract birth data for compatibility calculation
const extractBirthDataForCompatibility = (astroData) => {
    if (!astroData) return null;

    // Extract date parts
    let year; let month; let day;
    if (astroData.birthYear && astroData.birthMonth && astroData.birthDay) {
        year = astroData.birthYear;
        month = astroData.birthMonth;
        day = astroData.birthDay;
    } else if (astroData.birthDate) {
        const birthDate = astroData.birthDate?.toDate?.() || new Date(astroData.birthDate);
        if (isNaN(birthDate.getTime())) return null;
        year = birthDate.getFullYear();
        month = birthDate.getMonth() + 1;
        day = birthDate.getDate();
    } else {
        return null;
    }

    // Extract time parts
    const birthTime = astroData.birthTime;
    if (!birthTime || typeof birthTime !== "string") return null;
    const timeParts = birthTime.split(":").map((p) => parseInt(p, 10) || 0);
    const hours = timeParts[0] || 0;
    const minutes = timeParts[1] || 0;
    const seconds = timeParts[2] || 0;

    // Extract location
    const latitude = astroData.birthLatitude;
    const longitude = astroData.birthLongitude;

    // Handle timezone - use timeZoneOffset (number in hours) if available
    // Then try parsing timeZone as number, then try as IANA timezone name using Luxon
    let timeZone = null;
    if (astroData.timeZoneOffset != null) {
        // timeZoneOffset is already a number (hours offset)
        timeZone = typeof astroData.timeZoneOffset === "number" ? astroData.timeZoneOffset : parseFloat(astroData.timeZoneOffset);
        if (isNaN(timeZone)) {
            timeZone = null;
        }
    }

    if (timeZone == null && astroData.timeZone != null && astroData.timeZone !== "") {
        // First try parsing as a number (e.g., "5.5" for IST)
        const parsedTz = parseFloat(astroData.timeZone);
        if (!isNaN(parsedTz)) {
            timeZone = parsedTz;
        } else {
            // Try to parse as IANA timezone name (e.g., "Asia/Kolkata") using Luxon
            try {
                // Create a DateTime at a known date/time in the specified timezone
                // Use the user's birth date to get the correct offset (handles DST)
                const birthDateTime = DateTime.fromObject(
                    { year, month, day, hour: hours, minute: minutes },
                    { zone: astroData.timeZone }
                );
                if (birthDateTime.isValid && birthDateTime.offset != null) {
                    // Luxon offset is in minutes, convert to hours
                    timeZone = birthDateTime.offset / 60;
                }
            } catch (e) {
                // Invalid timezone name, timeZone stays null
                logger.warn("Failed to parse IANA timezone", {
                    timezone: astroData.timeZone,
                    error: e.message,
                });
            }
        }
    }

    if (latitude == null || longitude == null || timeZone == null) {
        return null;
    }

    return {
        year: parseInt(year, 10),
        month: parseInt(month, 10),
        date: parseInt(day, 10),
        hours: parseInt(hours, 10),
        minutes: parseInt(minutes, 10),
        seconds: parseInt(seconds, 10),
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        timezone: timeZone, // Already a number, no need to parseFloat again
    };
};

// Validate astrology data for compatibility calculation
// Note: Both users must have astrology enabled. The 'visibility' field controls
// whether others can calculate compatibility (public = allowed, private = not allowed)
const validateAstrologyDataForCompatibility = (astroData, userId, isCurrentUser = false) => {
    if (!astroData) {
        logger.warn("Compatibility validation failed: no astrology profile", {
            userId,
            isCurrentUser,
        });
        throw new HttpsError(
            "failed-precondition",
            "User must have astrology profile set up",
        );
    }

    if (!astroData.isEnabled) {
        logger.warn("Compatibility validation failed: astrology not enabled", {
            userId,
            isCurrentUser,
            isEnabled: astroData.isEnabled,
        });
        throw new HttpsError(
            "failed-precondition",
            "User must have astrology enabled",
        );
    }

    // Check visibility for the other user (not the current user making the request)
    // 'private' visibility means the user doesn't want others to calculate compatibility
    if (!isCurrentUser && astroData.visibility === "private") {
        logger.info("Compatibility validation: user profile is private", {
            userId,
            visibility: astroData.visibility,
        });
        throw new HttpsError(
            "failed-precondition",
            "User has set their astrology profile to private",
        );
    }

    const birthData = extractBirthDataForCompatibility(astroData);
    if (!birthData) {
        // Log detailed info about what's missing
        logger.warn("Compatibility validation failed: incomplete birth data", {
            userId,
            isCurrentUser,
            hasBirthYear: !!astroData.birthYear,
            hasBirthMonth: !!astroData.birthMonth,
            hasBirthDay: !!astroData.birthDay,
            hasBirthDate: !!astroData.birthDate,
            hasBirthTime: !!astroData.birthTime,
            birthTime: astroData.birthTime,
            hasBirthLatitude: astroData.birthLatitude != null,
            hasBirthLongitude: astroData.birthLongitude != null,
            hasTimeZone: astroData.timeZone != null,
            hasTimeZoneOffset: astroData.timeZoneOffset != null,
            timeZone: astroData.timeZone,
            timeZoneOffset: astroData.timeZoneOffset,
        });
        throw new HttpsError(
            "failed-precondition",
            "User must have complete birth data (date, time, location)",
        );
    }

    return birthData;
};

// Invalidate compatibility cache for a user
export const invalidateCompatibilityCache = async (userId) => {
    try {
        // Find all compatibility scores involving this user
        const cacheRef = db.collection("compatibilityScores");
        const [scoresWithUser1, scoresWithUser2] = await Promise.all([
            cacheRef.where("user1Id", "==", userId).get(),
            cacheRef.where("user2Id", "==", userId).get(),
        ]);

        const batch = db.batch();
        let deleteCount = 0;

        scoresWithUser1.forEach((doc) => {
            batch.delete(doc.ref);
            deleteCount++;
        });

        scoresWithUser2.forEach((doc) => {
            batch.delete(doc.ref);
            deleteCount++;
        });

        if (deleteCount > 0) {
            await batch.commit();
        }
    } catch (error) {
        logger.error("Error invalidating compatibility cache", {
            structuredData: true,
            userId,
            error: error.message,
        });
        // Don't throw - cache invalidation failure shouldn't break the main flow
    }
};

/** @see ../lib/utils.js — consolidated blocking utility */
const checkBlockedStatus = async (userId1, userId2) => {
    const result = await checkBlockedDetailed(db, userId1, userId2);
    // Map to legacy field names used by callers in this file
    return {
        isBlocked: result.isBlocked,
        blockerIsCurrentUser: result.blockerIsUser1,
        blockerIsOtherUser: result.blockerIsUser2,
    };
};

// Helper function to check mutual follow status
const checkMutualFollow = async (userId1, userId2) => {
    try {
        // Check both directions in parallel
        const [user1FollowsUser2, user2FollowsUser1] = await Promise.all([
            // Does user1 follow user2 with confirmed status?
            db.collection("userFollowing")
                .doc(userId1)
                .collection("following")
                .doc(userId2)
                .get(),
            // Does user2 follow user1?
            db.collection("userFollowers")
                .doc(userId1)
                .collection("followers")
                .doc(userId2)
                .get(),
        ]);

        // Both must exist for mutual follow
        if (!user1FollowsUser2.exists || !user2FollowsUser1.exists) {
            return false;
        }

        // User1's follow must be confirmed (status = 'following')
        const status = user1FollowsUser2.data()?.status || "following";
        return status === "following";
    } catch (error) {
        logger.warn("Error checking mutual follow", {
            userId1,
            userId2,
            error: error.message,
        });
        return false;
    }
};

export async function handleCalculateCompatibility(request) {
    try {
        const currentUserId = requireAuth(request, "calculate compatibility");

        const { otherUserId } = request.data || {};

        if (!otherUserId || typeof otherUserId !== "string") {
            throw new HttpsError(
                "invalid-argument",
                "otherUserId is required and must be a string",
            );
        }

        if (currentUserId === otherUserId) {
            throw new HttpsError(
                "invalid-argument",
                "Cannot calculate compatibility with yourself",
            );
        }

        // Check mutual follow requirement (friends only can see compatibility)
        const isMutualFollow = await checkMutualFollow(currentUserId, otherUserId);
        if (!isMutualFollow) {
            throw new HttpsError(
                "permission-denied",
                "Compatibility requires mutual follow. Follow each other to unlock!",
            );
        }

        // Check if either user has blocked the other
        const blockStatus = await checkBlockedStatus(currentUserId, otherUserId);
        if (blockStatus.isBlocked) {
            if (blockStatus.blockerIsOtherUser) {
                // Other user blocked current user - don't reveal this explicitly
                throw new HttpsError(
                    "permission-denied",
                    "Compatibility is not available for this user.",
                );
            } else {
                // Current user blocked the other user
                throw new HttpsError(
                    "failed-precondition",
                    "You have blocked this user. Unblock to see compatibility.",
                );
            }
        }

        // Sort user IDs for consistent cache key
        const [user1Id, user2Id] = [currentUserId, otherUserId].sort();
        const cacheKey = `${user1Id}_${user2Id}`;

        // Check cache first
        const cacheRef = db.collection("compatibilityScores").doc(cacheKey);
        const cachedDoc = await cacheRef.get();

        if (cachedDoc.exists) {
            const cachedData = cachedDoc.data();
            const calculatedAt = cachedData.calculatedAt?.toDate?.() || new Date(cachedData.calculatedAt);
            const daysSinceCalculation = (Date.now() - calculatedAt.getTime()) / (1000 * 60 * 60 * 24);
            const cacheVersion = cachedData.cacheVersion;

            // Check both TTL and cache version - invalidate if version mismatch
            if (daysSinceCalculation < COMPATIBILITY_CACHE_TTL_DAYS && cacheVersion === COMPATIBILITY_CACHE_VERSION) {
                return {
                    success: true,
                    // Primary: Cosmic Match
                    cosmicMatch: cachedData.cosmicMatch,
                    // Life Phase Sync (Dasha comparison)
                    lifePhaseSync: cachedData.lifePhaseSync || null,
                    // Secondary: Traditional Ashtakoot
                    traditionalMatch: {
                        totalScore: cachedData.totalScore,
                        outOf: cachedData.outOf,
                        percentage: cachedData.percentage,
                        details: cachedData.details,
                        matchType: cachedData.matchType || "mutual",
                    },
                    // Legacy fields for backward compatibility
                    totalScore: cachedData.totalScore,
                    outOf: cachedData.outOf,
                    percentage: cachedData.percentage,
                    details: cachedData.details,
                    cached: true,
                };
            }
            // Cache miss due to version mismatch or TTL expiry - will recalculate below
        }

        // Fetch both users' astrology data
        const [currentUserDoc, otherUserDoc] = await Promise.all([
            db.collection("users").doc(currentUserId).get(),
            db.collection("users").doc(otherUserId).get(),
        ]);

        if (!currentUserDoc.exists || !otherUserDoc.exists) {
            throw new HttpsError(
                "not-found",
                "One or both users not found",
            );
        }

        const currentUserData = currentUserDoc.data() || {};
        const otherUserData = otherUserDoc.data() || {};
        const currentAstroData = currentUserData.astrologyData;
        const otherAstroData = otherUserData.astrologyData;

        // Validate astrology data (throws HttpsError if invalid)
        // Current user is always allowed (isCurrentUser = true), other user respects visibility setting
        const user1BirthData = validateAstrologyDataForCompatibility(currentAstroData, currentUserId, true);
        const user2BirthData = validateAstrologyDataForCompatibility(otherAstroData, otherUserId, false);

        // Extract gender and astro info for cosmic match calculation
        const user1Gender = currentAstroData.gender;
        const user2Gender = otherAstroData.gender;

        // Get moon signs and nakshatras for cosmic match
        const user1MoonSign = normalizeSign(currentAstroData.moonSign);
        const user2MoonSign = normalizeSign(otherAstroData.moonSign);
        const user1Nakshatra = normalizeNakshatra(currentAstroData.nakshatra || currentAstroData.moonNakshatra);
        const user2Nakshatra = normalizeNakshatra(otherAstroData.nakshatra || otherAstroData.moonNakshatra);

        // Get sun signs and ascendants for comprehensive cosmic match
        const user1SunSign = normalizeSign(currentAstroData.sunSign);
        const user2SunSign = normalizeSign(otherAstroData.sunSign);
        const user1Ascendant = normalizeSign(currentAstroData.ascendant || currentAstroData.lagna);
        const user2Ascendant = normalizeSign(otherAstroData.ascendant || otherAstroData.lagna);

        // Get current Dasha data for life phase sync
        const user1Dasha = currentAstroData.currentDasha;
        const user2Dasha = otherAstroData.currentDasha;

        // =====================================================================
        // COSMIC MATCH (Universal, Gender-Neutral, Comprehensive 8-Pillar System)
        // =====================================================================
        let cosmicMatch = null;
        if (user1MoonSign && user2MoonSign && user1Nakshatra && user2Nakshatra) {
            cosmicMatch = calculateCosmicMatch(
                {
                    moonSign: user1MoonSign,
                    nakshatra: user1Nakshatra,
                    sunSign: user1SunSign,
                    ascendant: user1Ascendant,
                },
                {
                    moonSign: user2MoonSign,
                    nakshatra: user2Nakshatra,
                    sunSign: user2SunSign,
                    ascendant: user2Ascendant,
                }
            );
        }

        // =====================================================================
        // LIFE PHASE SYNC (Dasha Comparison)
        // =====================================================================
        const lifePhaseSync = calculateLifePhaseSync(user1Dasha, user2Dasha);

        // =====================================================================
        // TRADITIONAL ASHTAKOOT MATCH
        // =====================================================================

        // Determine if we should use gender-specific or averaged calculation
        // Traditional: Male-Female pairing (single direction)
        // Mutual: Same-sex, Non-binary, or unknown (average both directions)
        // 
        // This follows Vedic tradition which recognizes tritiya-prakriti (third nature)
        // For non-binary individuals, we use mutual averaging like same-sex pairings
        let matchType = "mutual"; // Default: average both directions
        let ashtakootPayloads = [];

        // Helper to check if gender is binary (Male or Female)
        const isBinaryGender = (gender) => gender === "Male" || gender === "Female";

        // Traditional calculation only for Male-Female pairs where both are binary
        const isTraditionalPairing = user1Gender && user2Gender
            && isBinaryGender(user1Gender) && isBinaryGender(user2Gender)
            && user1Gender !== user2Gender;

        if (isTraditionalPairing) {
            // Traditional M-F pairing - use correct roles
            matchType = "traditional";
            const maleData = user1Gender === "Male" ? user1BirthData : user2BirthData;
            const femaleData = user1Gender === "Female" ? user1BirthData : user2BirthData;

            ashtakootPayloads = [{
                male: maleData,
                female: femaleData,
                config: {
                    observation_point: "geocentric",
                    language: "en",
                    ayanamsha: "lahiri",
                },
            }];
        } else {
            // Non-traditional pairing: calculate both ways and average
            // This includes: same-sex, non-binary involved, or unknown genders
            if (user1Gender === "Non-binary" || user2Gender === "Non-binary") {
                matchType = "non_binary";
            } else if (user1Gender && user2Gender && user1Gender === user2Gender) {
                matchType = "same_gender";
            } else {
                matchType = "mutual";
            }

            ashtakootPayloads = [
                {
                    male: user1BirthData,
                    female: user2BirthData,
                    config: {
                        observation_point: "geocentric",
                        language: "en",
                        ayanamsha: "lahiri",
                    },
                },
                {
                    male: user2BirthData,
                    female: user1BirthData,
                    config: {
                        observation_point: "geocentric",
                        language: "en",
                        ayanamsha: "lahiri",
                    },
                },
            ];
        }

        // Call API with retry logic for transient failures
        const callWithRetry = async (payload, retries = 2) => {
            for (let i = 0; i <= retries; i++) {
                try {
                    const response = await callFreeAstro(ASHTAKOOT_SCORE_ENDPOINT, payload);
                    if (response?.output) {
                        return response;
                    }
                    throw new Error("Invalid API response: missing output");
                } catch (error) {
                    // Don't retry on rate limits (429) - fail fast
                    const statusCode = error.statusCode || (error.code === "internal" ? 500 : null);
                    if (statusCode === 429) {
                        throw error; // Don't retry rate limits
                    }
                    // Don't retry on other client errors (4xx), only server errors (5xx) and network issues
                    if (statusCode && statusCode >= 400 && statusCode < 500) {
                        throw error; // Don't retry client errors
                    }

                    if (i === retries) {
                        throw error;
                    }
                    // Wait before retry (exponential backoff)
                    const delayMs = 1000 * Math.pow(2, i);
                    await new Promise((resolve) => setTimeout(resolve, delayMs));
                }
            }
        };

        // =====================================================================
        // ASHTAKOOT API CALL - Graceful degradation on failure
        // =====================================================================
        let traditionalMatch = null;
        let averagedScore = null;
        let primaryOutput = null;
        let ashtakootError = null;

        try {
            // Execute API calls
            const responses = await Promise.all(
                ashtakootPayloads.map(payload => callWithRetry(payload))
            );

            // Validate API responses
            if (responses.some(r => !r?.output)) {
                throw new Error("Invalid response from astrology API");
            }

            // Calculate final Ashtakoot score
            const outOf = responses[0].output.out_of || MAX_ASHTAKOOT_SCORE;

            if (responses.length === 1) {
                // Traditional (single direction)
                averagedScore = responses[0].output.total_score || 0;
                primaryOutput = responses[0].output;
            } else {
                // Averaged (both directions)
                const score1 = responses[0].output.total_score || 0;
                const score2 = responses[1].output.total_score || 0;
                averagedScore = (score1 + score2) / 2;
                primaryOutput = responses[0].output;
            }

            const percentage = (averagedScore / outOf) * 100;

            // Build traditional match result
            traditionalMatch = {
                totalScore: averagedScore,
                outOf: outOf,
                percentage: percentage,
                details: primaryOutput,
                matchType: matchType,
            };
        } catch (error) {
            // Log the Ashtakoot API failure
            const statusCode = error.statusCode || (error.message?.includes("429") ? 429 : null);
            const isRateLimited = statusCode === 429 || error.message?.includes("Too Many Requests") || error.message?.includes("Limit Exceeded");

            ashtakootError = isRateLimited ? "rate_limited" : "api_error";

            logger.warn("Ashtakoot API failed, returning Cosmic Match only", {
                structuredData: true,
                error: error.message,
                statusCode: statusCode,
                isRateLimited: isRateLimited,
                hasCosmic: !!cosmicMatch,
            });

            // Continue without Ashtakoot - we'll return partial results
        }

        // =====================================================================
        // RETURN RESULTS - Full or Partial depending on API success
        // =====================================================================

        // If we have full results (both Cosmic and Ashtakoot), cache them
        if (traditionalMatch && cosmicMatch) {
            const cacheData = {
                cacheVersion: COMPATIBILITY_CACHE_VERSION,
                cosmicMatch: cosmicMatch,
                lifePhaseSync: lifePhaseSync,
                totalScore: averagedScore,
                outOf: traditionalMatch.outOf,
                percentage: traditionalMatch.percentage,
                details: primaryOutput,
                matchType: matchType,
                calculatedAt: FieldValue.serverTimestamp(),
                user1Id: user1Id,
                user2Id: user2Id,
            };

            await cacheRef.set(cacheData);

            return {
                success: true,
                // Primary: Cosmic Match (universal)
                cosmicMatch: cosmicMatch,
                // Life Phase Sync (Dasha comparison)
                lifePhaseSync: lifePhaseSync,
                // Secondary: Traditional Ashtakoot
                traditionalMatch: traditionalMatch,
                // Legacy fields for backward compatibility
                totalScore: averagedScore,
                outOf: traditionalMatch.outOf,
                percentage: traditionalMatch.percentage,
                details: primaryOutput,
                cached: false,
            };
        }

        // Partial results - Cosmic Match available but Ashtakoot failed
        // Don't cache partial results so we can retry Ashtakoot next time
        if (cosmicMatch) {
            logger.info("Returning partial compatibility (Cosmic Match only)", {
                structuredData: true,
                cosmicScore: cosmicMatch.score,
                ashtakootError: ashtakootError,
            });

            return {
                success: true,
                partial: true, // Flag indicating partial results
                partialReason: ashtakootError === "rate_limited"
                    ? "Traditional matching temporarily unavailable due to high demand. Try again later."
                    : "Traditional matching temporarily unavailable.",
                // Primary: Cosmic Match (universal) - still available!
                cosmicMatch: cosmicMatch,
                // Life Phase Sync (Dasha comparison) - still available!
                lifePhaseSync: lifePhaseSync,
                // Secondary: Traditional Ashtakoot - unavailable
                traditionalMatch: null,
                // Legacy fields - null to indicate unavailable
                totalScore: null,
                outOf: null,
                percentage: null,
                details: null,
                cached: false,
            };
        }

        // If we have neither Cosmic nor Ashtakoot, throw error
        throw new HttpsError(
            "internal",
            "Unable to calculate compatibility. Please try again later.",
        );
    } catch (error) {
        logger.error("calculateCompatibility error", {
            structuredData: true,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });

        // Don't expose internal errors to client
        if (error instanceof HttpsError) {
            throw error;
        }

        throw new HttpsError(
            "internal",
            "Failed to calculate compatibility. Please try again later.",
        );
    }
}
