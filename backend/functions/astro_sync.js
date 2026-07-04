import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { Timestamp } from "firebase-admin/firestore";
import { getFunctions } from "firebase-admin/functions";
import tzLookup from "tz-lookup";
import { DateTime } from "luxon";

import { db, FieldValue } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";
import { runEphemerisFlow } from "./ephemeris.js";
import { invalidateCompatibilityCache } from "./compatibility.js";
import { generateHouseInterpretations } from "../lib/house_interpretations.js";
import { resetAndRecalculateAyurveda } from "../lib/ayurveda_service.js";

// ============================================================================
// CONFIGURATION
// ============================================================================
const STANDARD_SYNC_DELAY_MS = 2000; // Delay before starting standard sync to avoid contention

// Sync status ordering for determining upgrade path
const SYNC_STATUS_ORDER = {
    none: 0,
    partial: 1,
    basic_complete: 2,
    standard_complete: 3,
    muhurat_complete: 3,
    full_complete: 4,
};

// Validation constants
const BIRTH_YEAR_MIN = 1900;
const LATITUDE_RANGE = { min: -90, max: 90 };
const LONGITUDE_RANGE = { min: -180, max: 180 };

const parseTimeParts = (timeString) => {
    if (!timeString || typeof timeString !== "string") {
        return [0, 0, 0];
    }
    const segments = timeString.split(":").map((segment) => parseInt(segment, 10));
    const hours = Number.isFinite(segments[0]) ? Math.min(Math.max(segments[0], 0), 23) : 0;
    const minutes = Number.isFinite(segments[1]) ? Math.min(Math.max(segments[1], 0), 59) : 0;
    const seconds = Number.isFinite(segments[2]) ? Math.min(Math.max(segments[2], 0), 59) : 0;
    return [hours, minutes, seconds];
};

const extractDateParts = (astroData) => {
    // Prefer explicit year/month/day if available (no timezone conversion)
    if (astroData.birthYear && astroData.birthMonth && astroData.birthDay) {
        return {
            year: astroData.birthYear,
            month: astroData.birthMonth,
            day: astroData.birthDay,
        };
    }

    // Fallback: legacy birthDate field (timezone-aware conversion)
    const birthDateValue = astroData.birthDate;
    if (!birthDateValue) return null;

    const date = typeof birthDateValue.toDate === "function" ?
        birthDateValue.toDate() :
        new Date(birthDateValue);

    if (Number.isNaN(date.getTime())) return null;

    const timeZoneId = determineTimeZoneId(astroData);
    try {
        const zoned = DateTime.fromJSDate(date, { zone: timeZoneId || "UTC" });
        if (!zoned.isValid) {
            logger.warn("⚠️ Invalid birth date after timezone conversion:", zoned.invalidExplanation);
            return null;
        }

        return {
            year: zoned.year,
            month: zoned.month,
            day: zoned.day,
            originalDate: date,
        };
    } catch (error) {
        logger.warn("⚠️ Failed to extract date parts with zone", timeZoneId, error.message);
        return null;
    }
};

const determineTimeZoneId = (astroData) => {
    const storedZone = typeof astroData.timeZone === "string" && astroData.timeZone.length > 0 ?
        astroData.timeZone :
        null;

    if (storedZone) return storedZone;

    const { birthLatitude, birthLongitude } = astroData;
    if (typeof birthLatitude === "number" && typeof birthLongitude === "number") {
        try {
            return tzLookup(birthLatitude, birthLongitude);
        } catch (error) {
            logger.warn("⚠️ tzLookup failed, falling back to UTC:", error.message);
        }
    }

    return "UTC";
};

const computeOffsetHours = (dateParts, timeParts, timeZoneId) => {
    try {
        const dt = DateTime.fromObject(
            {
                year: dateParts.year,
                month: dateParts.month,
                day: dateParts.day,
                hour: timeParts[0],
                minute: timeParts[1],
                second: timeParts[2],
            },
            { zone: timeZoneId },
        );

        if (!dt.isValid) {
            logger.warn("⚠️ Invalid DateTime for timezone computation:", dt.invalidExplanation);
            return 0;
        }

        return dt.offset / 60;
    } catch (error) {
        logger.warn("⚠️ Failed to compute timezone offset, defaulting to 0:", error.message);
        return 0;
    }
};

// Gateway-callable handler
export async function handleSyncAstroProfile(request) {
    const uid = requireAuth(request, "refresh astrology data");
    const data = request.data;
    logger.info("🧭 syncAstroProfile invoked", JSON.stringify({ uid, data }));

    const userRef = db.collection("users").doc(uid);
    const snapshot = await userRef.get();

    if (!snapshot.exists) {
        throw new HttpsError(
            "not-found",
            "User record not found",
        );
    }

    const userData = snapshot.data() || {};
    const astroData = userData.astrologyData;

    if (!astroData) {
        throw new HttpsError(
            "failed-precondition",
            "No astrology profile found. Please save birth details first.",
        );
    }

    const birthTime = astroData.birthTime;
    const latitude = astroData.birthLatitude;
    const longitude = astroData.birthLongitude;
    const timeZoneId = determineTimeZoneId(astroData);
    const dateParts = extractDateParts(astroData);
    const timeParts = parseTimeParts(birthTime);

    // Validate required fields
    if (!dateParts || !birthTime || latitude == null || longitude == null) {
        throw new HttpsError(
            "failed-precondition",
            "Birth details incomplete. Please update birth date, time, and location.",
        );
    }

    // Validate coordinate ranges
    if (typeof latitude !== "number" || typeof longitude !== "number" ||
        latitude < LATITUDE_RANGE.min || latitude > LATITUDE_RANGE.max ||
        longitude < LONGITUDE_RANGE.min || longitude > LONGITUDE_RANGE.max) {
        throw new HttpsError(
            "failed-precondition",
            "Invalid birth location coordinates.",
        );
    }

    // Validate date parts
    if (!dateParts.year || !dateParts.month || !dateParts.day ||
        dateParts.year < BIRTH_YEAR_MIN || dateParts.year > new Date().getFullYear() ||
        dateParts.month < 1 || dateParts.month > 12 ||
        dateParts.day < 1 || dateParts.day > 31) {
        throw new HttpsError(
            "failed-precondition",
            "Invalid birth date values.",
        );
    }
    const timeZoneOffset = computeOffsetHours(dateParts, timeParts, timeZoneId);
    const mode = data?.mode || "full";

    logger.info("🕰️ Computed timezone data", JSON.stringify({
        timeZoneId,
        timeZoneOffset,
        timeParts,
        dateParts,
        mode,
    }));

    const payload = {
        year: dateParts.year,
        month: dateParts.month,
        date: dateParts.day,
        hours: timeParts[0],
        minutes: timeParts[1],
        seconds: timeParts[2],
        latitude,
        longitude,
        timezone: timeZoneOffset,
        config: {
            observation_point: "geocentric",
            ayanamsha: "lahiri",
        },
    };

    // OPTIMIZATION: Start first reading generation IMMEDIATELY in parallel
    // The AI call takes ~2-3s, so start it NOW before runEphemerisFlow
    // Track promise so we can await it later if needed
    let earlyFirstReadingPromise = null;
    if (mode === "basic" && !astroData.firstReading?.content) {
        const userName = userData.name || userData.displayName || "";
        // If we have enough data from previous partial sync, start immediately
        if (astroData.sunSign && astroData.moonSign && astroData.ascendant) {
            logger.info("📖 Starting first reading generation EARLY (parallel)", { uid });
            earlyFirstReadingPromise = triggerFirstReading(uid, userName, astroData)
                .catch((e) => {
                    logger.warn("Early first reading failed, will retry after sync", { error: e.message });
                    return null; // Return null to indicate failure
                });
        }
    }

    const astroResult = await runEphemerisFlow({
        mode,
        payload,
        timeZoneId,
        timeZoneOffset,
    });

    if (!astroResult) {
        throw new HttpsError(
            "internal",
            "Astrology API returned no data",
        );
    }

    // Check if basic mode but no signs were extracted (API failure)
    if (mode === "basic" && (!astroResult.sunSign || !astroResult.moonSign)) {
        logger.error("❌ Basic sync failed - no signs extracted", {
            structuredData: true,
            syncStatus: astroResult.syncStatus,
            sunSign: astroResult.sunSign,
            moonSign: astroResult.moonSign,
        });
        throw new HttpsError(
            "internal",
            "Astrology calculation failed - unable to retrieve birth chart data. Please try again.",
        );
    }

    // Determine sync status - only upgrade, never downgrade
    // This ensures we don't lose data from a full sync when doing a basic refresh
    const currentSyncStatus = astroData.syncStatus || "none";
    const newSyncStatus = astroResult.syncStatus || "partial";
    const shouldUpdateSyncStatus = (SYNC_STATUS_ORDER[newSyncStatus] || 0) >= (SYNC_STATUS_ORDER[currentSyncStatus] || 0);

    const mergedAstroData = {
        ...astroData,
        sunSign: astroResult.sunSign ?? astroData.sunSign ?? null,
        moonSign: astroResult.moonSign ?? astroData.moonSign ?? null,
        ascendant: astroResult.ascendant ?? astroData.ascendant ?? null,
        nakshatra: astroResult.nakshatra ?? astroData.nakshatra ?? null,
        moonNakshatra: astroResult.moonNakshatra ?? astroData.moonNakshatra ?? null,
        lagnaNakshatra: astroResult.lagnaNakshatra ?? astroData.lagnaNakshatra ?? null,
        birthChartData: astroResult.birthChartData ?? astroData.birthChartData ?? null,
        chartSvgUrl: astroResult.chartSvgUrl ?? astroData.chartSvgUrl ?? null,
        samvatInfo: astroResult.samvatInfo ?? astroData.samvatInfo ?? null,
        doshas: astroResult.doshas ?? astroData.doshas ?? null,
        yogasDetailed: astroResult.yogasDetailed ?? astroData.yogasDetailed ?? null,
        panchang: astroResult.panchang ?? astroData.panchang ?? null,
        muhurat: astroResult.muhurat ?? astroData.muhurat ?? null,
        navamsa: astroResult.navamsa ?? astroData.navamsa ?? null,
        shadBala: astroResult.shadBala ?? astroData.shadBala ?? null,
        ashtakavarga: astroResult.ashtakavarga ?? astroData.ashtakavarga ?? null,
        d10Chart: astroResult.d10Chart ?? astroData.d10Chart ?? null,
        // Process yogas list if available
        yogas: astroResult.yogas && Array.isArray(astroResult.yogas.yogas) ?
            astroResult.yogas.yogas :
            (astroResult.yogas && typeof astroResult.yogas === "object" ?
                Object.values(astroResult.yogas).filter((v) => typeof v === "string") :
                (astroData.yogas ?? null)),
        // Raj Yogas calculated from planetary positions
        rajYogas: astroResult.rajYogas ?? astroData.rajYogas ?? null,
        currentDasha: astroResult.currentDasha ?? astroData.currentDasha ?? null,
        // Pre-processed planet data for frontend (if available)
        processedPlanets: astroResult.processedPlanets ?? astroData.processedPlanets ?? null,
        dashaLastUpdated: astroResult.currentDasha ?
            Timestamp.now() :
            astroData.dashaLastUpdated ?? null,
        // Preserve firstReading if it exists (spread should handle this, but explicit for clarity)
        firstReading: astroData.firstReading ?? null,
        timeZone: timeZoneId,
        timeZoneOffset,
        lastUpdated: FieldValue.serverTimestamp(),
        // Sync status tracking for tiered loading
        syncMode: mode,
        syncStatus: shouldUpdateSyncStatus ? newSyncStatus : currentSyncStatus,
        lastSyncAt: FieldValue.serverTimestamp(),
    };

    await userRef.set(
        {
            astrologyData: mergedAstroData,
        },
        { merge: true },
    );

    // Invalidate compatibility cache when astrology data is updated
    // This ensures compatibility scores are recalculated with new birth data
    try {
        await invalidateCompatibilityCache(uid);
    } catch (error) {
        logger.warn("⚠️ Failed to invalidate compatibility cache:", error);
        // Don't fail the sync if cache invalidation fails
    }

    // Only reset Ayurveda profile when birth details actually changed
    // (ascendant, birth coordinates, or nakshatra). Routine syncs that just
    // upgrade sync status / add muhurat / add house interpretations should
    // NOT nuke the user's vikriti, check-in history, and questionnaire data.
    const birthDetailsChanged = userData.ayurvedaData && (
        mergedAstroData.ascendant !== astroData.ascendant ||
        mergedAstroData.moonNakshatra !== (astroData.moonNakshatra || astroData.nakshatra) ||
        mergedAstroData.birthLatitude !== astroData.birthLatitude ||
        mergedAstroData.birthLongitude !== astroData.birthLongitude
    );

    if (birthDetailsChanged) {
        logger.info("🌿 Birth details changed - resetting Ayurveda profile", { uid });
        resetAndRecalculateAyurveda(uid, mergedAstroData)
            .catch((e) => logger.warn("Ayurveda reset failed", { error: e.message }));
    } else if (!userData.ayurvedaData && mergedAstroData.ascendant) {
        // Create Ayurveda profile automatically if it doesn't exist and astrology data is ready
        // This ensures Ayurveda is created when astrology is first calculated
        logger.info("🌿 Creating Ayurveda profile automatically", { uid });
        resetAndRecalculateAyurveda(uid, mergedAstroData)
            .catch((e) => logger.warn("Ayurveda creation failed", { error: e.message }));
    }

    logger.info("✅ Astrology profile synced successfully", JSON.stringify({
        uid,
        mode,
        syncStatus: mergedAstroData.syncStatus,
        sunSign: mergedAstroData.sunSign,
        moonSign: mergedAstroData.moonSign,
        ascendant: mergedAstroData.ascendant,
        hasDasha: Boolean(mergedAstroData.currentDasha),
    }));

    // Trigger house interpretations if birthChartData exists and interpretations don't
    if (mergedAstroData.birthChartData?.output && !mergedAstroData.houseInterpretations) {
        logger.info("🏠 Triggering house interpretations in background", { uid, mode });
        triggerHouseInterpretations(uid, mergedAstroData)
            .catch((e) => logger.warn("House interpretations trigger failed", { error: e.message }));
    }

    // After basic sync completes, generate birth + current times readings (independent, can run in parallel)
    const hasFirstReading = mergedAstroData.firstReading?.content || astroData.firstReading?.content;
    const hasCurrentTimesReading = !!mergedAstroData.currentTimesReading?.content;
    const userName = userData.name || userData.displayName || "";

    // Start current times generation in parallel when missing (no dependency on birth reading)
    let currentTimesPromise = null;
    if (mode === "basic" && mergedAstroData.sunSign && !hasCurrentTimesReading) {
        currentTimesPromise = (async () => {
            try {
                const { triggerCurrentTimesReading } = await import("./current_times_reading.js");
                return triggerCurrentTimesReading(uid, userName, mergedAstroData);
            } catch (e) {
                logger.warn("Current times reading generation failed", { error: e.message });
                return false;
            }
        })();
    }

    if (mode === "basic" && mergedAstroData.sunSign && !hasFirstReading) {
        // Generate birth reading (awaited - shown during onboarding)
        if (earlyFirstReadingPromise) {
            const earlyResult = await earlyFirstReadingPromise;
            if (earlyResult === null) {
                logger.info("📖 Retrying first reading with fresh data", { uid });
                try {
                    await triggerFirstReading(uid, userName, mergedAstroData);
                } catch (e) {
                    logger.warn("First reading retry failed", { error: e.message });
                }
            } else {
                logger.info("📖 Early first reading completed successfully", { uid });
            }
        } else {
            logger.info("📖 Generating first reading (awaited)", { uid });
            try {
                await triggerFirstReading(uid, userName, mergedAstroData);
            } catch (e) {
                logger.warn("First reading generation failed", { error: e.message });
            }
        }

        // Standard sync runs in background (not critical for onboarding)
        logger.info("⬆️ Triggering standard sync upgrade in background", { uid });
        triggerStandardSync(uid)
            .catch((e) => logger.warn("Standard sync trigger failed", { error: e.message }));
    }

    // Await current times if we started it in parallel
    if (currentTimesPromise) {
        await currentTimesPromise;
    }

    // Enqueue today's daily insight for new users so they get an insight without waiting for 5 AM job or manual load
    if (mode === "basic" && mergedAstroData.sunSign) {
        const today = DateTime.now().setZone("Asia/Kolkata").toFormat("yyyy-MM-dd");
        const todayInsightRef = db.collection("users").doc(uid).collection("dailyInsights").doc(today);
        const todayInsightSnap = await todayInsightRef.get();
        if (!todayInsightSnap.exists) {
            try {
                const functions = getFunctions();
                // Unified taskRouter — see backend/functions/task_router.js
                const queue = functions.taskQueue("locations/asia-southeast2/functions/taskRouter");
                await queue.enqueue(
                    {
                        taskType: "process_insight",
                        userId: uid,
                        astrologyData: mergedAstroData,
                        date: today,
                    },
                    { scheduleDelaySeconds: 5 },
                );
                logger.info("📬 Enqueued daily insight for new user (post-sync)", {
                    structuredData: true,
                    uid,
                    date: today,
                });
            } catch (enqueueErr) {
                logger.warn("Failed to enqueue daily insight for new user", {
                    uid,
                    error: enqueueErr?.message || String(enqueueErr),
                });
            }
        }
    }

    return {
        success: true,
        mode: mode,
        syncStatus: mergedAstroData.syncStatus,
        data: {
            sunSign: mergedAstroData.sunSign,
            moonSign: mergedAstroData.moonSign,
            ascendant: mergedAstroData.ascendant,
            nakshatra: mergedAstroData.nakshatra,
            currentDasha: mergedAstroData.currentDasha,
            chartSvgUrl: mergedAstroData.chartSvgUrl,
            samvatInfo: mergedAstroData.samvatInfo,
            // Include raj yogas count for quick display
            rajYogasCount: Array.isArray(mergedAstroData.rajYogas) ? mergedAstroData.rajYogas.length : 0,
        },
    };
}

/**
 * Generate and save first reading for a user.
 * Delegates to the insights engine first_reading flavor (prompt + AI + storage).
 * @returns {Promise<boolean>} True if successful, false if failed
 */
async function triggerFirstReading(uid, userName, astroData) {
    // Check if already exists
    if (astroData.firstReading?.content) {
        logger.info("First reading already exists, skipping", { uid });
        return true;
    }

    logger.info("📖 Generating first reading internally", { uid });

    try {
        const { generateFirstReading } = await import("./first_reading.js");

        // Pass pre-loaded data to avoid redundant Firestore read
        await generateFirstReading(uid, userName, astroData);

        logger.info(" First reading generated and saved", { uid });
        return true;
    } catch (error) {
        logger.error("❌ First reading generation failed", {
            uid,
            error: error.message,
            stack: error.stack?.substring(0, 500),
        });
        throw error; // Re-throw so caller can handle
    }
}

/**
 * Trigger standard sync upgrade in background.
 * Waits for basic sync to complete before starting.
 */
async function triggerStandardSync(uid) {
    // Small delay to not compete with basic sync response
    await new Promise((resolve) => setTimeout(resolve, STANDARD_SYNC_DELAY_MS));

    const userRef = db.collection("users").doc(uid);
    const snapshot = await userRef.get();

    if (!snapshot.exists) return;

    const userData = snapshot.data();
    const astroData = userData?.astrologyData;

    // Only upgrade if still at basic level
    if (astroData?.syncStatus !== "basic_complete") {
        logger.info("Skipping standard sync - already upgraded or in progress", { uid, status: astroData?.syncStatus });
        return;
    }

    logger.info("⬆️ Starting standard sync upgrade", { uid });

    // Re-run the sync with standard mode
    // This will be handled by calling the same flow internally
    const birthTime = astroData.birthTime;
    const latitude = astroData.birthLatitude;
    const longitude = astroData.birthLongitude;
    const timeZoneId = determineTimeZoneId(astroData);
    const dateParts = extractDateParts(astroData);
    const timeParts = parseTimeParts(birthTime);

    if (!dateParts || !birthTime || latitude == null || longitude == null) {
        logger.warn("⚠️ Standard sync upgrade skipped - incomplete birth data", {
            uid,
            hasBirthYear: !!astroData.birthYear,
            hasBirthMonth: !!astroData.birthMonth,
            hasBirthDay: !!astroData.birthDay,
            hasBirthDate: !!astroData.birthDate,
            birthTime: astroData.birthTime,
            birthLatitude: astroData.birthLatitude,
            birthLongitude: astroData.birthLongitude,
            timeZone: astroData.timeZone,
        });
        return;
    }

    const timeZoneOffset = computeOffsetHours(dateParts, timeParts, timeZoneId);

    const payload = {
        year: dateParts.year,
        month: dateParts.month,
        date: dateParts.day,
        hours: timeParts[0],
        minutes: timeParts[1],
        seconds: timeParts[2],
        latitude,
        longitude,
        timezone: timeZoneOffset,
        config: {
            observation_point: "geocentric",
            ayanamsha: "lahiri",
        },
    };

    try {
        const astroResult = await runEphemerisFlow({
            mode: "standard",
            payload,
            timeZoneId,
            timeZoneOffset,
        });

        if (astroResult) {
            const mergedData = {
                ...astroData,
                ...astroResult,
                syncMode: "standard",
                syncStatus: "standard_complete",
                lastSyncAt: FieldValue.serverTimestamp(),
            };

            await userRef.update({
                astrologyData: mergedData,
            });

            logger.info("✅ Standard sync upgrade completed", { uid });

            // Generate house interpretations in background (non-blocking)
            // Only if not already generated
            if (!mergedData.houseInterpretations) {
                triggerHouseInterpretations(uid, mergedData)
                    .catch((e) => logger.warn("House interpretations failed", { uid, error: e.message }));
            }
        }
    } catch (error) {
        logger.error("❌ Standard sync upgrade failed", { uid, error: error.message });
        // Don't throw - this is a background operation
    }
}

/**
 * Generate and save house interpretations for a user.
 * Called after standard/full sync completes.
 */
async function triggerHouseInterpretations(uid, astroData) {
    // Check if already exists
    if (astroData.houseInterpretations) {
        logger.info("🏠 House interpretations already exist, skipping", { uid });
        return;
    }

    // Ensure we have birth chart data
    if (!astroData.birthChartData?.output) {
        logger.warn("🏠 No birth chart data for house interpretations", { uid });
        return;
    }

    logger.info("🏠 Generating house interpretations", { uid });

    try {
        const interpretations = await generateHouseInterpretations(astroData);

        if (interpretations) {
            await db.collection("users").doc(uid).update({
                "astrologyData.houseInterpretations": interpretations,
                "astrologyData.houseInterpretationsGeneratedAt": FieldValue.serverTimestamp(),
            });

            logger.info("✅ House interpretations saved", { uid, housesGenerated: Object.keys(interpretations).length });

            // Chain into per-house biweekly readings now that natal context exists.
            // Fire-and-forget; failures here don't affect the user's main sync flow.
            triggerPerHouseReadings(uid)
                .catch((e) => logger.warn("Per-house readings trigger failed", { uid, error: e.message }));
        }
    } catch (error) {
        logger.error("❌ House interpretations failed", { uid, error: error.message });
        // Don't throw - this is a background operation
    }
}

/**
 * Trigger biweekly per-house current-state readings for a user.
 * Generates in-process (background) so the readings are ready the moment the
 * user opens astro details. Subsequent regenerations are handled by the daily
 * scheduler in functions/per_house.js.
 */
async function triggerPerHouseReadings(uid) {
    try {
        const { generatePerHouse, computeCycleWindow, needsRegeneration } =
            await import("./per_house.js");

        // Re-read the user doc since we just wrote to it.
        const snap = await db.collection("users").doc(uid).get();
        const astro = snap.data()?.astrologyData;
        if (!astro) return;
        if (!needsRegeneration(astro.skyHouseReadings)) {
            logger.info("Per-house readings already fresh, skipping", { uid });
            return;
        }

        const window = computeCycleWindow();
        logger.info("Generating per-house biweekly readings", { uid, ...window });
        const { latencyMs } = await generatePerHouse(uid, window.cycleStart, window.cycleEnd);
        logger.info("Per-house readings saved", { uid, latencyMs });
    } catch (error) {
        logger.error("Per-house readings failed", { uid, error: error.message });
        // Don't throw - background operation
    }
}

// NOTE: Daily insight generation is now triggered by FRONTEND as a separate
// Cloud Function call (generateInsightForCurrentUser). This ensures the insight
// generation runs as an independent Cloud Function invocation, avoiding the
// deprioritization issue that occurs with fire-and-forget within the same function.
