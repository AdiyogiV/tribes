// NOTE: onSchedule and onTaskDispatched imports removed — the scheduler and
// task-worker entry points that lived in this file are now part of the
// unified orchestrator (unified_orchestrator.js) and task router (task_router.js).
// All work is invoked via the extracted `run*` runner functions below.
import { HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { requireAuth, getRecentlyActiveUids } from "../lib/auth_utils.js";
import { DateTime } from "luxon";
import { getFunctions } from "firebase-admin/functions";
import { getUpcomingSignIngresses, getUpcomingRetrogrades } from "./sky_positions.js";
import { stripMarkdown, normalizeChart } from "../lib/astro_helpers.js";
import { getTransitBinduScore } from "../lib/vedic_analysis.js";
import { INSIGHT_SYSTEM_PROMPT, buildInsightUserPrompt } from "./prompts/daily_insights.js";
import { callGemini } from "../lib/gemini.js";
import { buildDashaContext, getTodayAstroData } from "../lib/daily_insight_context.js";

/**
 * Single source of truth for the daily-insight document id.
 *
 * Cloud Run runs in UTC, but Aurogram is India-first and the nightly cron
 * keys insights by IST (Asia/Kolkata). Every write/read of a dailyInsights
 * doc id MUST go through here so the cron path and the on-demand generate
 * path always agree — otherwise, between 00:00–05:29 IST the two paths
 * produce different doc ids (UTC "yesterday" vs IST "today").
 */
export const todayId = () => DateTime.now().setZone("Asia/Kolkata").toFormat("yyyy-MM-dd");

/**
 * Generate personalized daily astrology insight using AI
 * Uses ALL available data: API + Google Search
 */
async function generateInsightWithAI(userAstroData, todayAstroData, forecastDay) {
    // Extract user's core chart data
    const { ascendant: lagna, moonSign, sunSign, nakshatra, currentDasha } = normalizeChart(userAstroData);
    const { mahaDasha, antarDasha, levels } = currentDasha;

    let dashaText = "";
    if (mahaDasha) dashaText += `Mahadasha: ${mahaDasha}`;
    if (antarDasha) dashaText += `, Antardasha: ${antarDasha}`;
    if (levels.pratyantar?.lord) dashaText += `, Pratyantar: ${levels.pratyantar.lord}`;
    if (levels.sookshma?.lord) dashaText += `, Sookshma: ${levels.sookshma.lord}`;

    // Extract Raj Yogas (with full details)
    const rajYogas = userAstroData.rajYogas || [];
    const yogaNames = rajYogas.map((y) => y.name || y).filter(Boolean).join(", ") || "None detected";

    // Extract Doshas (comprehensive - all calculated doshas)
    const doshas = userAstroData.doshas || {};
    const doshaList = [];
    const doshaDetails = [];

    if (doshas.mangal_dosha) {
        doshaList.push("Mangal Dosha");
        doshaDetails.push(`Mangal Dosha${doshas.mangal_dosha_house ? ` in House ${doshas.mangal_dosha_house}` : ""} - Mars influence`);
    }
    if (doshas.kaal_sarp_dosha) {
        doshaList.push("Kaal Sarp Dosha");
        doshaDetails.push("Kaal Sarp Dosha - focused karmic energy");
    }
    if (doshas.shani_dosha) {
        doshaList.push("Shani Dosha");
        doshaDetails.push(`Shani Dosha${doshas.shani_dosha_house ? ` in House ${doshas.shani_dosha_house}` : ""} - Saturn's discipline`);
    }
    if (doshas.pitra_dosha) {
        doshaList.push("Pitra Dosha");
        doshaDetails.push(`Pitra Dosha${doshas.pitra_dosha_type ? ` (${doshas.pitra_dosha_type})` : ""} - ancestral pattern`);
    }
    if (doshas.grahan_dosha) {
        doshaList.push("Grahan Dosha");
        doshaDetails.push(`Grahan Dosha${doshas.grahan_type ? ` (${doshas.grahan_type})` : ""} - eclipse influence`);
    }
    if (doshas.gandmool_dosha) {
        doshaList.push("Gandmool Dosha");
        doshaDetails.push(`Gandmool Dosha${doshas.gandmool_nakshatra ? ` (${doshas.gandmool_nakshatra})` : ""} - transformative nakshatra`);
    }
    if (doshas.has_combustion && doshas.combust_planets?.length > 0) {
        doshaList.push("Combustion");
        doshaDetails.push(`Combustion: ${doshas.combust_planets.join(", ")} planets near Sun`);
    }

    // Extract Shad Bala (natal planetary strength — stored on the user at signup).
    // Must be the user's own natal shadbala, NOT a "born-today" chart.
    const shadBala = userAstroData.shadBala || {};
    const analysis = shadBala._analysis || {};
    const strongPlanets = (analysis.strongPlanets || []).map((p) => `${p.planet}(${p.strength}%)`).join(", ") || "Unknown";
    const weakPlanets = (analysis.weakPlanets || []).map((p) => `${p.planet}(${p.strength}%)`).join(", ") || "None";

    // Extract Panchang
    const panchang = todayAstroData.panchang || {};
    const tithi = panchang.tithi || "Unknown";
    const todayNakshatra = panchang.nakshatra || "Unknown";
    const yoga = panchang.yoga || "Unknown";

    // Extract Transits (current planetary positions)
    // NOTE: Transit house numbers are calculated relative to user's natal Lagna (ascendant)
    // This is the correct Vedic astrology method for transit interpretation
    const transits = todayAstroData.transits || {};
    // Ashtakavarga transit strength (natal BAV/SAV, stored on the user).
    const ashtakavarga = userAstroData.ashtakavarga || null;
    const ZODIAC = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
        "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"];
    const BINDU_PLANETS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
    const transitList = Object.entries(transits)
        .filter(([name]) => name !== "Ascendant")
        .map(([name, data]) => {
            const sign = data.sign || "?";
            const house = data.house || "";
            // Transit house is relative to user's natal Lagna
            let line = house ? `${name} in ${sign} (transiting user's ${house}th house)` : `${name} in ${sign}`;
            const canon = BINDU_PLANETS.find((c) => name.toLowerCase().includes(c.toLowerCase()));
            if (canon && ashtakavarga) {
                const signIdx = ZODIAC.findIndex((z) => z.toLowerCase() === sign.toLowerCase());
                if (signIdx >= 0) {
                    const b = getTransitBinduScore(canon, ZODIAC[signIdx], ashtakavarga);
                    if (b) line += ` [${b.bindus}/8 bindus: ${b.quality}]`;
                }
            }
            return line;
        })
        .join(", ") || "Unknown";

    // Today's day and ruler
    const today = DateTime.now();
    const dayLords = { 1: "Moon", 2: "Mars", 3: "Mercury", 4: "Jupiter", 5: "Venus", 6: "Saturn", 7: "Sun" };
    const todayLord = dayLords[today.weekday] || "Sun";
    const todayName = today.toFormat("EEEE");

    // Fetch ACCURATE upcoming events from pre-calculated global data
    // These are AUTHORITATIVE - calculated from actual astronomical positions
    let upcomingEventsText = "";
    try {
        // Fetch both ingresses and retrogrades (just Firestore reads - instant!)
        const [ingresses, retrogrades] = await Promise.all([
            getUpcomingSignIngresses(),
            getUpcomingRetrogrades(),
        ]);

        const majorPlanets = ["Sun", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];
        const eventParts = [];

        // Format sign ingresses
        if (ingresses.length > 0) {
            const relevantIngresses = ingresses
                .filter((ing) => majorPlanets.includes(ing.planet))
                .slice(0, 6);

            if (relevantIngresses.length > 0) {
                const ingressText = relevantIngresses
                    .map((ing) => `${ing.planet} enters ${ing.toSign} on ${ing.date}`)
                    .join("; ");
                eventParts.push(`Sign Changes: ${ingressText}`);
            }
        }

        // Format retrogrades
        if (retrogrades.length > 0) {
            const relevantRetros = retrogrades
                .filter((r) => majorPlanets.includes(r.planet))
                .slice(0, 4);

            if (relevantRetros.length > 0) {
                const retroText = relevantRetros
                    .map((r) => `${r.planet} ${r.type === "retrograde_start" ? "goes retrograde" : "goes direct"} on ${r.date}`)
                    .join("; ");
                eventParts.push(`Retrogrades: ${retroText}`);
            }
        }

        if (eventParts.length > 0) {
            upcomingEventsText = eventParts.join("\n");
            logger.info("📅 Upcoming events for AI", {
                structuredData: true,
                ingressCount: ingresses.length,
                retroCount: retrogrades.length,
                eventText: upcomingEventsText.substring(0, 200),
            });
        }
    } catch (eventsError) {
        logger.warn("Failed to fetch upcoming events", { error: String(eventsError) });
    }

    // Extract Muhurat (good/bad times)
    const muhurat = todayAstroData.muhurat || {};
    const muhuratList = [];
    if (muhurat.abhijit) muhuratList.push(`★ Abhijit Muhurat: ${muhurat.abhijit.start}-${muhurat.abhijit.end}`);
    if (muhurat.amritKaal) muhuratList.push(`★ Amrit Kaal: ${muhurat.amritKaal.start}-${muhurat.amritKaal.end}`);
    if (muhurat.brahmaMuhurat) muhuratList.push(`★ Brahma Muhurat: ${muhurat.brahmaMuhurat.start}-${muhurat.brahmaMuhurat.end}`);
    if (muhurat.rahuKaal) muhuratList.push(`⚠ Rahu Kaal: ${muhurat.rahuKaal.start}-${muhurat.rahuKaal.end}`);
    if (muhurat.yamaganda) muhuratList.push(`⚠ Yama Gandam: ${muhurat.yamaganda.start}-${muhurat.yamaganda.end}`);
    if (muhurat.gulikaKala) muhuratList.push(`⚠ Gulika Kala: ${muhurat.gulikaKala.start}-${muhurat.gulikaKala.end}`);
    if (muhurat.varjyam) muhuratList.push(`⚠ Varjyam: ${muhurat.varjyam.start}-${muhurat.varjyam.end}`);

    // Log what we're sending to AI
    logger.info("📊 Insight Generation Data", {
        structuredData: true,
        userId: userAstroData.userId || "unknown",
        lagna,
        moonSign,
        sunSign,
        nakshatra,
        dashaText,
        rajYogas: yogaNames,
        doshas: doshaList.join(", ") || "None",
        strongPlanets,
        weakPlanets,
        todayTithi: tithi,
        todayNakshatra,
        todayYoga: yoga,
        todayLord,
        transitCount: Object.keys(transits).length,
    });

    const prompt = buildInsightUserPrompt({
        lagna,
        moonSign,
        sunSign,
        nakshatra,
        dashaText,
        yogaNames,
        doshaList,
        todayName,
        todayLord,
        tithi,
        todayNakshatra,
        strongPlanets,
        weakPlanets,
        transitList,
        upcomingEventsText,
        forecastDay,
    });

    // Call Gemini — all context comes from our own computed astronomical data.
    // No Google Search grounding needed: transits, panchang, dasha, shad bala,
    // and upcoming events are already in the prompt from our own calculations.
    const aiResponse = await callGemini({
        systemPrompt: INSIGHT_SYSTEM_PROMPT,
        userPrompt: prompt,
        temperature: 0.92,
        expectJson: true,
        googleSearch: false,
        flavorName: "daily_insight",
    });

    // Use parsed JSON from ai_client (handles code-fence stripping + JSON extraction)
    const FALLBACK_MESSAGE = "Your cosmic blueprint holds unique potential today. " +
        "Trust the energies aligning in your favor and take inspired action where you feel called.";
    const parsed = aiResponse.json || {
        theme: "Today's Guidance",
        message: FALLBACK_MESSAGE,
        sections: [],
    };

    // Ensure required fields
    if (!parsed.theme) parsed.theme = "Today's Guidance";
    if (!parsed.message) parsed.message = FALLBACK_MESSAGE;
    if (!parsed.sections) parsed.sections = [];

    // Ensure each section has displayOrder and scheduledFor (4 insights for full day)
    const defaultSchedules = ["06:00", "12:00", "17:00", "21:00"];
    parsed.sections = parsed.sections.slice(0, 4).map((section, index) => ({
        title: section.title || `Section ${index + 1}`,
        content: section.content || "",
        cardType: section.cardType || "insight",
        displayOrder: section.displayOrder || (index + 1),
        scheduledFor: section.scheduledFor || defaultSchedules[index] || "06:00",
    }));

    logger.info("✅ Insight generated", {
        structuredData: true,
        theme: parsed.theme,
        messageLength: parsed.message?.length,
        sectionCount: parsed.sections?.length,
    });

    return parsed;
}

/**
 * Generate insight for user with force option
 * Key: generates NEW insight first, THEN saves (old stays visible until new is ready)
 * @exported for use by astro_sync.js to generate insights for new users
 */
export async function generateInsightForUserForce(userId, userAstroData, forceRegenerate = false) {
    const today = todayId();
    const insightRef = db
        .collection("users")
        .doc(userId)
        .collection("dailyInsights")
        .doc(today);

    // If not forcing, check if exists
    if (!forceRegenerate) {
        const existing = await insightRef.get();
        if (existing.exists) {
            logger.info("Insight already exists", { userId, date: today });
            return { ...existing.data(), date: today, alreadyExists: true };
        }
    } else {
        // COOLDOWN CHECK: Prevent notification spam from rapid successive regeneration calls
        // If insight was generated within the last 5 minutes, skip notifications
        const existing = await insightRef.get();
        let skipNotification = false;

        if (existing.exists) {
            const data = existing.data();
            const generatedAt = data?.generatedAt?.toDate?.() || data?.generatedAt;
            if (generatedAt) {
                const generatedTime = new Date(generatedAt).getTime();
                const now = Date.now();
                const fiveMinutes = 5 * 60 * 1000;

                if (now - generatedTime < fiveMinutes) {
                    skipNotification = true;
                    logger.info("🔄 Force regenerating but SKIPPING notifications (cooldown active)", {
                        userId,
                        date: today,
                        lastGeneratedMs: now - generatedTime,
                        cooldownMs: fiveMinutes,
                    });
                } else {
                    logger.info("🔄 Force regenerating (old stays until new ready)", { userId, date: today });
                }
            }
        } else {
            logger.info("🔄 Force regenerating (no existing insight)", { userId, date: today });
        }

        return generateNewInsight(userId, userAstroData, insightRef, today, skipNotification);
    }

    // First-time insight (no existing): generate and notify
    return generateNewInsight(userId, userAstroData, insightRef, today, false);
}

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION: one "your daily reading is ready" push per day
// ═══════════════════════════════════════════════════════════════

/**
 * Create a single notification doc for today's reading. The sendPushNotification
 * Firestore trigger (functions/notifications.js) turns this into an FCM push.
 * @param {string} userId
 * @param {string} today   - yyyy-MM-dd
 * @param {Object} insightData - the saved reading (for title + preview)
 */
async function sendDailyReadyNotification(userId, today, insightData) {
    try {
        const notificationRef = db
            .collection("notifications")
            .doc(userId)
            .collection("notifications")
            .doc(`daily-astro-${today}`);

        await notificationRef.set({
            type: "dailyAstroInsight",
            title: insightData.theme || "Your daily reading is ready",
            preview: stripMarkdown(insightData.message || "").substring(0, 150),
            insightId: today,
            date: today,
            timestamp: FieldValue.serverTimestamp(),
            read: false,
        });

        logger.info("[NOTIFY] Daily reading notification sent", {
            structuredData: true, userId, date: today,
        });
    } catch (error) {
        logger.error("[NOTIFY] Failed to send daily reading notification", {
            structuredData: true, userId, error: String(error),
        });
    }
}

/**
 * Core insight generation logic. Generates today's reading, saves it, and
 * (unless skipNotification) sends ONE "your daily reading is ready" push.
 * @param {boolean} skipNotification - When true, skip the notification (e.g. cooldown on regenerate)
 */
async function generateNewInsight(userId, userAstroData, insightRef, today, skipNotification = false) {
    try {
        const startTime = Date.now();

        // Log what user data we have
        const chart = normalizeChart(userAstroData);
        logger.info("🌟 Starting insight generation", {
            structuredData: true,
            userId,
            date: today,
            userDataAvailable: {
                lagna: chart.ascendant !== "Unknown",
                moonSign: chart.moonSign !== "Unknown",
                sunSign: chart.sunSign !== "Unknown",
                nakshatra: chart.nakshatra !== "Unknown",
                dasha: !!userAstroData.currentDasha,
                dashaLord: chart.currentDasha.mahaDasha || "none",
                rajYogas: userAstroData.rajYogas?.length || 0,
                doshas: Object.keys(userAstroData.doshas || {}).length,
                location: !!(userAstroData.birthLatitude && userAstroData.birthLongitude),
            },
        });

        // Step 1: Get today's astronomical data
        const step1Start = Date.now();
        const todayAstroData = await getTodayAstroData(userAstroData);
        const step1Duration = Date.now() - step1Start;

        // Step 1.5: Build Dasha context for narrative continuity
        const dashaContext = await buildDashaContext(userId, userAstroData.currentDasha);
        logger.info("[DASHA] Built dasha context", {
            structuredData: true,
            userId,
            period: dashaContext.period,
            phase: dashaContext.phase,
            percentComplete: dashaContext.percentComplete,
            daysRemaining: dashaContext.daysRemaining,
            recentThemesCount: dashaContext.recentThemes?.length || 0,
        });

        // Step 2: Generate insight with AI using computed astronomical data
        const step2Start = Date.now();
        // Anchor the daily cards to the same computed day signal used by the
        // wheel and Aurobhatt. The prose may elaborate; it may not contradict.
        const forecastSnap = await db
            .collection("users")
            .doc(userId)
            .collection("forecast")
            .doc(today.slice(0, 7))
            .get();
        const forecastDay = forecastSnap.exists ?
            (forecastSnap.data().days || []).find((day) => day.date === today) || null :
            null;

        const structured = await generateInsightWithAI(
            userAstroData,
            todayAstroData,
            forecastDay,
        );
        const step2Duration = Date.now() - step2Start;

        // Process sections (one reading, shown together on the dashboard)
        const processedSections = (structured.sections || []).map((section, index) => ({
            ...section,
            cardType: section.cardType || "insight",
            sectionIndex: index,
        }));

        const insightData = {
            theme: structured.theme || "Today's Guidance",
            message: structured.message || "",
            sections: processedSections,
            generatedAt: FieldValue.serverTimestamp(),
            date: today,
            version: "v7", // Bumped version for staggered delivery
            // Legacy field for backward compatibility
            astrologicalData: {
                transits: todayAstroData.transits,
                panchang: todayAstroData.panchang,
                shadBala: userAstroData.shadBala?._analysis || null,
                // TODAY's samvat info (lunar month, vikram year, calendar data)
                // This is for TODAY's date — distinct from profile.samvatInfo (birth date)
                todaySamvat: todayAstroData.todaySamvat || null,
                forecastDay,
            },
            // NEW: Complete context for AI chat reuse
            // This allows chat to have the SAME context used to generate the insight
            astroContext: {
                // User's birth chart (static)
                userChart: {
                    ...normalizeChart(userAstroData),
                    currentDasha: userAstroData.currentDasha,
                    rajYogas: userAstroData.rajYogas?.map((y) => y.name || y) || [],
                    doshas: userAstroData.doshas,
                },
                // Dasha narrative context for continuity
                dashaContext: {
                    period: dashaContext.period,
                    phase: dashaContext.phase,
                    percentComplete: dashaContext.percentComplete,
                    daysRemaining: dashaContext.daysRemaining,
                    phaseGuidance: dashaContext.phaseGuidance,
                    recentThemes: dashaContext.recentThemes,
                },
                // Today's cosmic weather
                todayData: {
                    transits: todayAstroData.transits,
                    panchang: todayAstroData.panchang,
                    shadBala: userAstroData.shadBala?._analysis || null,
                    muhurat: todayAstroData.muhurat,
                    forecastDay,
                },
            },
        };

        // Save (overwrites any existing - atomic operation)
        await insightRef.set(insightData);

        const totalDuration = Date.now() - startTime;

        logger.info("✅ Insight saved", {
            structuredData: true,
            userId,
            date: today,
            theme: insightData.theme,
            sectionCount: insightData.sections?.length || 0,
            performance: {
                totalMs: totalDuration,
                step1_todayDataMs: step1Duration,
                step2_aiGenerationMs: step2Duration,
            },
        });

        // Send ONE "your daily reading is ready" push (unless cooldown).
        if (!skipNotification) {
            await sendDailyReadyNotification(userId, today, insightData);
        } else {
            logger.info("[INSIGHT-SAVED] Insight saved, notification skipped (cooldown)", {
                structuredData: true, userId, date: today,
            });
        }

        return { ...insightData, date: today };
    } catch (error) {
        logger.error("❌ Failed to generate insight", {
            structuredData: true,
            userId,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
}

/** Handler: Generate insight for current user. Extracted for gateway reuse. */
export async function handleGenerateInsightForCurrentUser(request) {
    const userId = requireAuth(request, "get daily astro insights");
    const forceRegenerate = request.data?.forceRegenerate === true;

    // Accept current location from client (for accurate today's Vedic date)
    const currentLatitude = request.data?.currentLatitude;
    const currentLongitude = request.data?.currentLongitude;
    const currentTimeZone = request.data?.currentTimeZone;
    const currentTimeZoneOffset = request.data?.currentTimeZoneOffset;

    logger.info("🔮 generateInsightForCurrentUser called", {
        structuredData: true,
        userId,
        forceRegenerate,
        hasCurrentLocation: !!(currentLatitude && currentLongitude),
    });

    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const astrologyData = userData?.astrologyData;
        if (!astrologyData) {
            logger.warn("generateInsightForCurrentUser: user has no astrologyData (complete setup first)", {
                structuredData: true,
                userId,
            });
            throw new HttpsError("failed-precondition", "Complete astrology setup first");
        }

        // RATE LIMIT CHECK: Prevent rapid successive calls from triggering notification spam
        // If force regenerate was called within the last 2 minutes, return existing insight
        if (forceRegenerate) {
            const today = todayId();
            const existingInsight = await db
                .collection("users")
                .doc(userId)
                .collection("dailyInsights")
                .doc(today)
                .get();

            if (existingInsight.exists) {
                const data = existingInsight.data();
                const generatedAt = data?.generatedAt?.toDate?.() || data?.generatedAt;
                if (generatedAt) {
                    const generatedTime = new Date(generatedAt).getTime();
                    const now = Date.now();
                    const twoMinutes = 2 * 60 * 1000;

                    if (now - generatedTime < twoMinutes) {
                        logger.info("⏱️ Rate limited: returning existing insight (generated recently)", {
                            structuredData: true,
                            userId,
                            lastGeneratedMs: now - generatedTime,
                            cooldownMs: twoMinutes,
                        });
                        return {
                            success: true,
                            date: data.date || today,
                            theme: data.theme,
                            message: data.message,
                            sections: data.sections,
                            rateLimited: true,
                        };
                    }
                }
            }
        }

        // Merge current location into astrology data if provided
        const astroDataWithLocation = {
            ...astrologyData,
            userId,
            ...(currentLatitude != null && { currentLatitude }),
            ...(currentLongitude != null && { currentLongitude }),
            ...(currentTimeZone != null && { currentTimeZone }),
            ...(currentTimeZoneOffset != null && { currentTimeZoneOffset }),
        };

        // For force regenerate: generate new insight first, THEN overwrite (so old stays visible)
        const insightData = await generateInsightForUserForce(userId, astroDataWithLocation, forceRegenerate);

        logger.info("generateInsightForCurrentUser success", {
            structuredData: true,
            userId,
            date: insightData.date,
            alreadyExists: insightData.alreadyExists === true,
        });

        return {
            success: true,
            date: insightData.date,
            theme: insightData.theme,
            message: insightData.message,
            sections: insightData.sections,
        };
    } catch (error) {
        logger.error("generateInsightForCurrentUser failed", { userId, error: String(error) });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError("internal", error.message || "Failed to generate insight");
    }
}
/**
 * GENERATION: Runs ONCE daily at 5 AM IST
 * Enqueues insight generation tasks to Cloud Tasks queue for steady throughput.
 * Each task processes ONE user - this prevents quota spikes.
 *
 * OLD: Promise.all with BATCH_SIZE=50 -> quota spikes, failures
 * NEW: Cloud Tasks with rate limiting -> smooth, reliable generation
 */
/** Extracted runner for orchestrator consolidation. */
export async function runGenerateDailyAstroInsights() {
    const today = todayId();

    logger.info("🌅 Starting daily insights ENQUEUE (queue-based generation)", {
        structuredData: true,
        date: today,
    });

    try {
        // Fetch only doc IDs (.select() with no fields). We no longer pull every
        // user's full chart into memory just to enqueue — the worker re-reads the
        // chart from the user doc when it processes each task. This keeps the
        // nightly run's memory + task-payload size flat regardless of chart size.
        const usersSnapshot = await db.collection("users")
            .where("astrologyData", "!=", null)
            .select()
            .get();

        if (usersSnapshot.empty) {
            logger.info("No users with astrology data found");
            return { success: true, enqueued: 0 };
        }

        const users = usersSnapshot.docs.map((doc) => doc.id);

        // Activity gate: only generate for users who actually opened the app
        // recently. We used to generate for EVERY user who ever finished their
        // chart (dormant accounts included), so the nightly Vertex bill scaled
        // with total registrations instead of real usage. Firebase Auth's
        // lastRefreshTime bumps on token refresh (= app open), so it's a clean
        // server-side activity signal with no client change. INSIGHT_ACTIVE_DAYS=0
        // disables the gate.
        const activeDays = parseInt(process.env.INSIGHT_ACTIVE_DAYS || "7", 10);
        let gatedUsers = users;
        if (activeDays > 0) {
            const activeUids = await getRecentlyActiveUids(activeDays);
            const before = gatedUsers.length;
            gatedUsers = gatedUsers.filter((uid) => activeUids.has(uid));
            logger.info("Daily insights activity gate applied", {
                structuredData: true,
                activeDays,
                withChart: before,
                activeWithChart: gatedUsers.length,
                skippedDormant: before - gatedUsers.length,
            });
        }

        if (gatedUsers.length === 0) {
            logger.info("No recently-active users with charts to enqueue");
            return { success: true, enqueued: 0 };
        }

        logger.info(`Enqueuing ${gatedUsers.length} insight generation tasks`, {
            structuredData: true,
            userCount: gatedUsers.length,
            date: today,
        });

        // Initialize generation log for today
        await db.collection("insightGenerationLogs").doc(today).set({
            date: today,
            totalUsers: gatedUsers.length,
            startedAt: new Date().toISOString(),
            status: "enqueuing",
        });

        // Get the task queue for the insight worker
        // Use location-specific format to specify asia-southeast2 region
        // Unified taskRouter — see backend/functions/task_router.js
        const functions = getFunctions();
        const queue = functions.taskQueue("locations/asia-southeast2/functions/taskRouter");

        // Enqueue tasks for all users
        // Spread generation over 1 hour to avoid API rate limits and load spikes
        // Cloud Tasks handles rate limiting via the worker's rateLimits config
        let enqueued = 0;
        let enqueueFailed = 0;

        // Spread enqueue over 1 hour (3600 seconds) to distribute load
        const GENERATION_WINDOW_SECONDS = 3600; // 1 hour
        const totalUsers = gatedUsers.length;

        for (let i = 0; i < gatedUsers.length; i++) {
            const uid = gatedUsers[i];

            try {
                // Calculate delay: spread evenly over 1 hour
                // First user: 0 seconds, last user: ~3600 seconds
                const delaySeconds = Math.floor((i / totalUsers) * GENERATION_WINDOW_SECONDS);

                await queue.enqueue({
                    taskType: "process_insight", // routed by task_router.js
                    userId: uid,
                    date: today,
                }, {
                    scheduleDelaySeconds: delaySeconds,
                });
                enqueued++;
            } catch (e) {
                enqueueFailed++;
                logger.warn("[ENQUEUE] Failed to enqueue task", {
                    structuredData: true,
                    userId: uid,
                    error: String(e),
                });
            }
        }

        // Update generation log
        await db.collection("insightGenerationLogs").doc(today).update({
            status: "enqueued",
            enqueuedAt: new Date().toISOString(),
            enqueuedCount: enqueued,
            enqueueFailedCount: enqueueFailed,
        });

        logger.info("✅ Daily insights enqueue completed", {
            structuredData: true,
            date: today,
            enqueued,
            enqueueFailed,
            total: gatedUsers.length,
        });

        return { success: true, enqueued, enqueueFailed, total: gatedUsers.length };
    } catch (error) {
        logger.error("Daily insights enqueue failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });

        // Update log with failure
        try {
            await db.collection("insightGenerationLogs").doc(today).update({
                status: "failed",
                error: String(error),
                failedAt: new Date().toISOString(),
            });
        } catch (e) {
            // Ignore logging errors
        }

        throw error;
    }
}
// NOTE: `generateDailyAstroInsights` was an `onSchedule` export running at
// 5:00 AM IST. It is now invoked by `unifiedOrchestrator` (see
// backend/functions/schedulers/unified_orchestrator.js Phase 4) via the
// extracted `runGenerateDailyAstroInsights` runner above.


