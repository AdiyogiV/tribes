import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";
import { geminiApiKey, freeAstrologyApiKey } from "../lib/secrets.js";
import { DateTime } from "luxon";
import {
    getCacheStats,
    clearAllCaches,
    clearAIInsightCaches,
    clearOldVersionedCaches,
    getCacheVersion,
    cleanupExpiredCache,
} from "../lib/cache_utils.js";
import { getFunctions } from "firebase-admin/functions";
import { getUpcomingSignIngresses, getUpcomingRetrogrades } from "./sky_positions.js";
import { stripMarkdown } from "../lib/astro_helpers.js";
import { INSIGHT_SYSTEM_PROMPT, buildInsightUserPrompt } from "./prompts/daily_insights.js";
import { callGemini } from "../insights/engine/ai_client.js";
import { buildDashaContext, getTodayAstroData, getSearchContext } from "../lib/daily_insight_context.js";

// BATCH_SIZE removed - now using queue-based processing
// stripMarkdown and extractAscendantDegree imported from lib/astro_helpers.js
// buildDashaContext, getTodayAstroData, getSearchContext extracted to lib/daily_insight_context.js

/**
 * Generate personalized daily astrology insight using AI
 * Uses ALL available data: API + Google Search
 */
async function generateInsightWithAI(userAstroData, todayAstroData, searchContext) {
    // Extract user's core chart data
    const lagna = userAstroData.ascendant || userAstroData.lagna || "Unknown";
    const moonSign = userAstroData.moonSign || "Unknown";
    const sunSign = userAstroData.sunSign || "Unknown";
    const nakshatra = userAstroData.nakshatra || userAstroData.moonNakshatra || "Unknown";

    // Extract dasha (all levels)
    const currentDasha = userAstroData.currentDasha || {};
    const mahaDasha = currentDasha.mahadasha || currentDasha.maha_dasha || "";
    const antarDasha = currentDasha.antardasha || currentDasha.antar_dasha || "";
    const levels = currentDasha.levels || {};

    let dashaText = "";
    if (mahaDasha) dashaText += `Mahadasha: ${mahaDasha}`;
    if (antarDasha) dashaText += `, Antardasha: ${antarDasha}`;
    if (levels.pratyantar?.lord) dashaText += `, Pratyantar: ${levels.pratyantar.lord}`;
    if (levels.sookshma?.lord) dashaText += `, Sookshma: ${levels.sookshma.lord}`;

    // Extract Raj Yogas (with full details)
    const rajYogas = userAstroData.rajYogas || [];
    const yogaNames = rajYogas.map((y) => y.name || y).filter(Boolean).join(", ") || "None detected";

    // Build detailed yoga info for AI context
    const yogaDetails = rajYogas.map((y) => {
        if (typeof y === "object" && y.name) {
            let detail = y.name;
            if (y.type) detail += ` [${y.type}]`;
            if (y.strength) detail += ` (${y.strength})`;
            if (y.planets) detail += ` - ${Array.isArray(y.planets) ? y.planets.join(", ") : y.planets}`;
            return detail;
        }
        return y;
    }).join("; ");

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

    // Extract Shad Bala (planetary strength)
    const shadBala = todayAstroData.shadBala || {};
    const analysis = shadBala._analysis || {};
    const strongPlanets = (analysis.strongPlanets || []).map((p) => `${p.planet}(${p.strength}%)`).join(", ") || "Unknown";
    const weakPlanets = (analysis.weakPlanets || []).map((p) => `${p.planet}(${p.strength}%)`).join(", ") || "None";

    // Extract Panchang
    const panchang = todayAstroData.panchang || {};
    const tithi = panchang.tithi || "Unknown";
    const todayNakshatra = panchang.nakshatra || "Unknown";
    const yoga = panchang.yoga || "Unknown";
    const karana = panchang.karana || "Unknown";

    // Extract Transits (current planetary positions)
    // NOTE: Transit house numbers are calculated relative to user's natal Lagna (ascendant)
    // This is the correct Vedic astrology method for transit interpretation
    const transits = todayAstroData.transits || {};
    const transitList = Object.entries(transits)
        .filter(([name]) => name !== "Ascendant")
        .map(([name, data]) => {
            const sign = data.sign || "?";
            const house = data.house || "";
            // Transit house is relative to user's natal Lagna
            return house ? `${name} in ${sign} (transiting user's ${house}th house)` : `${name} in ${sign}`;
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
                .filter(ing => majorPlanets.includes(ing.planet))
                .slice(0, 6);

            if (relevantIngresses.length > 0) {
                const ingressText = relevantIngresses
                    .map(ing => `${ing.planet} enters ${ing.toSign} on ${ing.date}`)
                    .join("; ");
                eventParts.push(`Sign Changes: ${ingressText}`);
            }
        }

        // Format retrogrades  
        if (retrogrades.length > 0) {
            const relevantRetros = retrogrades
                .filter(r => majorPlanets.includes(r.planet))
                .slice(0, 4);

            if (relevantRetros.length > 0) {
                const retroText = relevantRetros
                    .map(r => `${r.planet} ${r.type === "retrograde_start" ? "goes retrograde" : "goes direct"} on ${r.date}`)
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

    // Extract Google Search context (if available) - SEND MAXIMUM DATA
    let searchInsights = "";
    if (searchContext) {
        const global = searchContext.global || {};
        const userSpec = searchContext.userSpecific || {};
        const panchangMeanings = searchContext.panchang || {};
        const userProfile = searchContext.userProfile || {};
        const dashaContext = searchContext.dasha || {};

        // ============ GLOBAL COSMIC WEATHER (affects everyone) ============
        searchInsights += "\n\n=== CURRENT COSMIC WEATHER ===";

        // Retrogrades - VERY important for predictions
        if (global.events?.retrogrades?.length > 0) {
            searchInsights += `\n🔄 RETROGRADES NOW: ${global.events.retrogrades.join(", ")}`;
        } else {
            searchInsights += `\n✓ NO MAJOR RETROGRADES currently`;
        }

        // Moon phase
        if (global.events?.moonPhase) {
            const mp = global.events.moonPhase;
            searchInsights += `\n🌙 MOON PHASE: ${mp.type}${mp.sign ? ` in ${mp.sign}` : ""}${mp.date ? ` (${mp.date})` : ""}`;
        }

        // Eclipse warnings
        if (global.events?.eclipse) {
            searchInsights += `\n⚠️ ECLIPSE: ${global.events.eclipse.type} on ${global.events.eclipse.date}`;
        }

        // Today's cosmic news - full context
        if (global.todayNews?.summary) {
            searchInsights += `\n📰 TODAY'S NEWS: ${global.todayNews.summary.substring(0, 500)}`;
        }

        // Weekly outlook
        if (global.weekly?.overview) {
            searchInsights += `\n📅 THIS WEEK: ${global.weekly.overview.substring(0, 400)}`;
        }

        // Monthly context
        if (global.monthly?.overview) {
            searchInsights += `\n📆 THIS MONTH: ${global.monthly.overview.substring(0, 300)}`;
        }

        // Festivals (spiritual energy peaks)
        if (global.festivals?.list) {
            searchInsights += `\n🕉️ FESTIVALS: ${global.festivals.list.substring(0, 200)}`;
        }

        // ============ TODAY'S PANCHANG MEANINGS ============
        searchInsights += "\n\n=== TODAY'S PANCHANG SIGNIFICANCE ===";

        if (panchangMeanings.tithi?.meaning) {
            searchInsights += `\n• TITHI (${tithi}): ${panchangMeanings.tithi.meaning.substring(0, 300)}`;
        }
        if (panchangMeanings.nakshatra?.characteristics) {
            searchInsights += `\n• NAKSHATRA (${todayNakshatra}): ${panchangMeanings.nakshatra.characteristics.substring(0, 300)}`;
        }
        if (panchangMeanings.yoga?.meaning) {
            searchInsights += `\n• YOGA (${yoga}): ${panchangMeanings.yoga.meaning.substring(0, 200)}`;
        }

        // ============ USER'S PROFILE KNOWLEDGE ============
        searchInsights += "\n\n=== YOUR ASTROLOGICAL PROFILE ===";

        // Lagna (ascendant) meaning - who you are
        if (userProfile.lagna?.characteristics) {
            searchInsights += `\n• YOUR ${lagna} LAGNA: ${userProfile.lagna.characteristics.substring(0, 400)}`;
        }

        // Birth nakshatra - your soul nature
        if (userProfile.nakshatra?.characteristics) {
            searchInsights += `\n• YOUR ${nakshatra} NAKSHATRA: ${userProfile.nakshatra.characteristics.substring(0, 300)}`;
        }

        // Dasha period interpretation - current life chapter
        if (dashaContext.general?.interpretation) {
            searchInsights += `\n• YOUR ${mahaDasha}-${antarDasha} DASHA: ${dashaContext.general.interpretation.substring(0, 400)}`;
        }

        // ============ USER-SPECIFIC FORECASTS ============
        searchInsights += "\n\n=== YOUR CURRENT FORECASTS ===";

        if (userSpec.lagnaForecast) {
            searchInsights += `\n• ${lagna} ASCENDANT NOW: ${userSpec.lagnaForecast.substring(0, 400)}`;
        }
        if (userSpec.moonSignForecast) {
            searchInsights += `\n• ${moonSign} MOON NOW: ${userSpec.moonSignForecast.substring(0, 400)}`;
        }
        if (userSpec.dashaForecast) {
            searchInsights += `\n• ${mahaDasha} PERIOD NOW: ${userSpec.dashaForecast.substring(0, 400)}`;
        }
        if (userSpec.majorTransitEffect) {
            searchInsights += `\n• MAJOR TRANSIT EFFECT: ${userSpec.majorTransitEffect.substring(0, 300)}`;
        }

        // ============ REMEDIES FOR WEAK PLANETS ============
        if (searchContext.remedies?.advice) {
            searchInsights += `\n\n=== REMEDIES ===`;
            searchInsights += `\n${searchContext.remedies.planet} REMEDY: ${searchContext.remedies.advice.substring(0, 300)}`;
        }

        // ============ RETROGRADE GUIDES ============
        if (searchContext.retrogradeGuides?.length > 0) {
            searchInsights += `\n\n=== RETROGRADE GUIDANCE ===`;
            for (const guide of searchContext.retrogradeGuides) {
                if (guide?.guide) {
                    searchInsights += `\n${guide.planet} RETROGRADE: ${guide.guide.substring(0, 250)}`;
                }
            }
        }
    }

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
        hasSearchContext: !!searchContext,
        searchInsightsLength: searchInsights.length,
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
        searchInsights,
    });

    // Call Gemini via shared AI client (handles retries, code-fence stripping, logging)
    // Google Search grounding enabled so Gemini can enrich with current cosmic events
    const aiResponse = await callGemini({
        systemPrompt: INSIGHT_SYSTEM_PROMPT,
        userPrompt: prompt,
        temperature: 0.92,
        maxOutputTokens: 1500,
        expectJson: true,
        googleSearch: true,
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

// REMOVED: generateInsightForUser — unused dead code (zero call sites).
// All callers (insight_worker.js, internal endpoint) use generateInsightForUserForce below,
// which has the cooldown + skipNotification logic that the deleted version lacked.

/**
 * Generate insight for user with force option
 * Key: generates NEW insight first, THEN saves (old stays visible until new is ready)
 * @exported for use by astro_sync.js to generate insights for new users
 */
export async function generateInsightForUserForce(userId, userAstroData, forceRegenerate = false) {
    const today = DateTime.now().toFormat("yyyy-MM-dd");
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

        // First-time (no existing): deliver immediately so user gets notifications now
        const immediateDelivery = !existing.exists;
        return generateNewInsight(userId, userAstroData, insightRef, today, skipNotification, immediateDelivery);
    }

    // First-time insight (no existing): deliver immediately
    return generateNewInsight(userId, userAstroData, insightRef, today, false, true);
}

/**
 * Extract predictions from insight sections and save for tracking
 * @param {string} userId - User ID
 * @param {string} insightDate - Date of the insight (yyyy-MM-dd)
 * @param {Array} sections - Processed insight sections
 */
async function extractAndSavePredictions(userId, insightDate, sections) {
    const predictionSections = sections.filter((s) =>
        s.data?.date, // Any section with a date is a prediction
    );

    if (predictionSections.length === 0) {
        logger.info("[PREDICTIONS] No predictions to extract", {
            structuredData: true,
            userId,
            insightDate,
        });
        return;
    }

    const predictionsRef = db.collection("users").doc(userId).collection("predictions");

    for (const section of predictionSections) {
        const data = section.data || {};

        // Parse the target date (try various formats including date ranges)
        let targetDate = null;
        if (data.date) {
            const dateStr = data.date.trim();
            const currentYear = DateTime.now().year;

            // Handle date RANGES like "December 10-16, 2025" or "Dec 10 - Dec 16"
            // Extract the START date from a range
            const rangePatterns = [
                // "December 10-16, 2025" or "December 10-16"
                /^([A-Za-z]+)\s+(\d{1,2})\s*[-–]\s*\d{1,2}(?:,?\s*(\d{4}))?$/,
                // "Dec 10 - Dec 16, 2025"
                /^([A-Za-z]+)\s+(\d{1,2})\s*[-–]\s*[A-Za-z]+\s+\d{1,2}(?:,?\s*(\d{4}))?$/,
                // "10-16 December 2025"
                /^(\d{1,2})\s*[-–]\s*\d{1,2}\s+([A-Za-z]+)(?:\s+(\d{4}))?$/,
            ];

            let rangeMatch = null;
            for (const pattern of rangePatterns) {
                rangeMatch = dateStr.match(pattern);
                if (rangeMatch) break;
            }

            if (rangeMatch) {
                // Extract month/day from range - use the START date
                let month; let day; let year;
                if (/^\d/.test(rangeMatch[1])) {
                    // "10-16 December 2025" format
                    day = rangeMatch[1];
                    month = rangeMatch[2];
                    year = rangeMatch[3] || currentYear;
                } else {
                    // "December 10-16, 2025" format
                    month = rangeMatch[1];
                    day = rangeMatch[2];
                    year = rangeMatch[3] || currentYear;
                }

                // Parse the extracted date
                const dateToTry = `${month} ${day}, ${year}`;
                let parsed = DateTime.fromFormat(dateToTry, "MMMM d, yyyy");
                if (!parsed.isValid) {
                    parsed = DateTime.fromFormat(dateToTry, "MMM d, yyyy");
                }
                if (parsed.isValid) {
                    if (parsed < DateTime.now()) {
                        parsed = parsed.plus({ years: 1 });
                    }
                    targetDate = parsed.toFormat("yyyy-MM-dd");
                }
            }

            // If not a range, try single date formats
            if (!targetDate) {
                const formats = [
                    "MMMM d, yyyy", // December 12, 2025
                    "MMM d, yyyy", // Dec 12, 2025
                    "MMM d", // Dec 12
                    "MMMM d", // December 12
                    "d MMM", // 12 Dec
                    "d MMMM", // 12 December
                    "yyyy-MM-dd", // 2024-12-12
                ];

                for (const format of formats) {
                    try {
                        let parsed = DateTime.fromFormat(dateStr, format);
                        if (parsed.isValid) {
                            // If year not in format, assume current or next year
                            if (!format.includes("yyyy")) {
                                parsed = parsed.set({ year: currentYear });
                                // If the date is in the past, assume next year
                                if (parsed < DateTime.now()) {
                                    parsed = parsed.plus({ years: 1 });
                                }
                            }
                            targetDate = parsed.toFormat("yyyy-MM-dd");
                            break;
                        }
                    } catch (e) {
                        // Try next format
                    }
                }
            }
        }

        if (!targetDate) {
            logger.warn("[PREDICTIONS] Could not parse target date", {
                structuredData: true,
                userId,
                rawDate: data.date,
            });
            continue;
        }

        // Create prediction document
        const predictionDoc = {
            createdAt: FieldValue.serverTimestamp(),
            targetDate,
            planet: data.planet || null,
            event: data.event || null,
            house: data.house || null,
            prediction: section.content?.substring(0, 500) || "",
            title: section.title || "",
            status: "pending", // pending | validated | expired
            insightDate,
            cardIndex: section.sectionIndex || 0,
        };

        const docRef = await predictionsRef.add(predictionDoc);

        logger.info("[PREDICTIONS] Saved prediction", {
            structuredData: true,
            userId,
            predictionId: docRef.id,
            targetDate,
            planet: data.planet,
            event: data.event,
        });
    }
}

// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
// CLOUD TASKS DISPATCH: Enqueue scheduled notification tasks
// Each card gets its own Cloud Task scheduled for specific time
// ═══════════════════════════════════════════════════════════════

/**
 * Enqueue dispatch tasks for each card notification
 * Each task is scheduled for its specific time (6 AM, 12 PM, 5 PM, 9 PM IST)
 * @param {string} userId - User ID
 * @param {string} date - Date string (yyyy-MM-dd)
 * @param {Array} sections - Processed sections with scheduledFor times
 */
async function enqueueDispatchTasks(userId, date, sections) {
    if (!sections || sections.length === 0) {
        return;
    }

    const functions = getFunctions();
    const dispatchQueue = functions.taskQueue("locations/asia-southeast2/functions/dispatchCardNotification");

    const now = DateTime.now().setZone("Asia/Kolkata");
    const todayDateStr = now.toFormat("yyyy-MM-dd");

    // Parse the date from insight (should be today's date)
    const insightDate = DateTime.fromFormat(date, "yyyy-MM-dd", { zone: "Asia/Kolkata" });

    let enqueued = 0;
    let failed = 0;

    for (let i = 0; i < sections.length; i++) {
        const section = sections[i];
        const scheduledFor = section.scheduledFor || "06:00";

        // Parse scheduled time (e.g., "06:00" -> 6 AM IST on insight date)
        const [hours, minutes] = scheduledFor.split(":").map(Number);
        let scheduledTime = insightDate.set({ hour: hours, minute: minutes, second: 0, millisecond: 0 });

        // If scheduled time is in the past, schedule for today (if generating late)
        // This handles edge case where generation happens after scheduled time
        if (scheduledTime < now) {
            scheduledTime = now.set({ hour: hours, minute: minutes, second: 0, millisecond: 0 });
            // If still in past, schedule for next occurrence (tomorrow)
            if (scheduledTime < now) {
                scheduledTime = scheduledTime.plus({ days: 1 });
            }
        }

        // Calculate seconds until scheduled time
        const delaySeconds = Math.max(0, Math.floor((scheduledTime.toMillis() - now.toMillis()) / 1000));

        try {
            await dispatchQueue.enqueue({
                userId,
                date,
                cardIndex: i,
                cardType: "insight", // Unified type
                title: section.title || "",
                content: section.content || "",
                scheduledFor,
            }, {
                scheduleDelaySeconds: delaySeconds,
            });

            enqueued++;
        } catch (error) {
            failed++;
            logger.error("[DISPATCH-ENQUEUE] Failed to enqueue dispatch task", {
                structuredData: true,
                userId,
                cardIndex: i,
                scheduledFor,
                error: String(error),
            });
        }
    }

    logger.info("[DISPATCH-ENQUEUE] Enqueued dispatch tasks", {
        structuredData: true,
        userId,
        date,
        enqueued,
        failed,
        totalCards: sections.length,
    });
}

// ═══════════════════════════════════════════════════════════════
// IMMEDIATE NOTIFICATION DELIVERY
// Sends ALL card notifications together with delays between each
// ═══════════════════════════════════════════════════════════════

/**
 * Helper to wait for specified milliseconds
 */
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Send ALL card notifications for an insight immediately
 * Cards are sent with 10 second delays between each
 * @param {string} userId - User ID
 * @param {string} today - Date string (yyyy-MM-dd)
 * @param {Array} sections - Processed sections from insight
 * @param {DocumentReference} insightRef - Reference to insight document
 */
async function sendAllCardNotifications(userId, today, sections, insightRef) {
    logger.info("[NOTIFICATIONS] Starting immediate delivery of all cards", {
        structuredData: true,
        userId,
        date: today,
        cardCount: sections.length,
    });

    const DELAY_BETWEEN_CARDS_MS = 10000; // 10 seconds between each notification
    let sentCount = 0;
    let errorCount = 0;

    for (let index = 0; index < sections.length; index++) {
        const section = sections[index];

        // Add delay between notifications (skip for first one)
        if (index > 0) {
            logger.info(`[NOTIFICATIONS] Waiting ${DELAY_BETWEEN_CARDS_MS / 1000}s before next card`, {
                structuredData: true,
                userId,
                nextCard: index,
            });
            await delay(DELAY_BETWEEN_CARDS_MS);
        }

        try {
            // Create notification document
            const notificationRef = db
                .collection("notifications")
                .doc(userId)
                .collection("notifications")
                .doc();

            const notificationData = {
                type: "dailyAstroInsight",
                cardType: "insight", // Unified type
                cardIndex: index,
                totalCards: sections.length,
                title: section.title || "",
                preview: stripMarkdown(section.content || "").substring(0, 150),
                sectionData: section.data || {},
                insightId: today,
                date: today,
                timestamp: FieldValue.serverTimestamp(),
                read: false,
            };

            await notificationRef.set(notificationData);

            // Mark this card as notified in the insight document
            await insightRef.update({
                [`cardNotifications.${index}.sent`]: true,
                [`cardNotifications.${index}.sentAt`]: FieldValue.serverTimestamp(),
            });

            sentCount++;
            logger.info(`[NOTIFICATIONS] Sent card ${index + 1}/${sections.length}`, {
                structuredData: true,
                userId,
                cardIndex: index,
                title: section.title,
            });
        } catch (cardError) {
            errorCount++;
            logger.error(`[NOTIFICATIONS] Failed to send card ${index}`, {
                structuredData: true,
                userId,
                cardIndex: index,
                error: String(cardError),
            });
        }
    }

    logger.info("[NOTIFICATIONS] Completed delivery", {
        structuredData: true,
        userId,
        date: today,
        sentCount,
        errorCount,
        totalCards: sections.length,
    });

    return { sentCount, errorCount };
}

/**
 * Core insight generation logic
 * When immediateDelivery is true (first-time insight): send all card notifications now.
 * When false: enqueue staggered tasks (6 AM, 12 PM, 5 PM, 9 PM IST).
 * @param {boolean} skipNotification - When true, skip both immediate and staggered delivery (e.g. cooldown)
 * @param {boolean} immediateDelivery - When true, deliver all cards now via sendAllCardNotifications; skip enqueue.
 */
async function generateNewInsight(userId, userAstroData, insightRef, today, skipNotification = false, immediateDelivery = false) {
    try {
        const startTime = Date.now();

        // Log what user data we have
        logger.info("🌟 Starting insight generation", {
            structuredData: true,
            userId,
            date: today,
            userDataAvailable: {
                lagna: !!(userAstroData.ascendant || userAstroData.lagna),
                moonSign: !!userAstroData.moonSign,
                sunSign: !!userAstroData.sunSign,
                nakshatra: !!(userAstroData.nakshatra || userAstroData.moonNakshatra),
                dasha: !!userAstroData.currentDasha,
                dashaLord: userAstroData.currentDasha?.mahadasha || userAstroData.currentDasha?.maha_dasha || "none",
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

        // Step 2: Get Google Search context (optional but valuable)
        const step2Start = Date.now();
        const searchContext = await getSearchContext(userAstroData, todayAstroData);
        const step2Duration = Date.now() - step2Start;

        // Step 3: Generate insight with AI using ALL data
        const step3Start = Date.now();
        const structured = await generateInsightWithAI(userAstroData, todayAstroData, searchContext);
        const step3Duration = Date.now() - step3Start;

        // Use scheduledFor from AI response (Gemini now generates this)
        // Fallback to first slot if missing
        const getScheduleFor = (section) => {
            return section.scheduledFor || "06:00"; // Default to first slot
        };

        // Process sections with scheduling info
        const processedSections = (structured.sections || []).map((section, index) => ({
            ...section,
            cardType: section.cardType || "insight", // Unified type
            scheduledFor: getScheduleFor(section),
            sectionIndex: index,
            dispatched: false, // Track if notification sent
        }));

        // Build cardNotifications tracking map
        const cardNotifications = {};
        processedSections.forEach((section, index) => {
            cardNotifications[index] = {
                sent: false,
                window: section.scheduledFor,
                cardType: "insight", // Unified type
            };
        });

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
                shadBala: todayAstroData.shadBala?._analysis || null,
                // TODAY's samvat info (lunar month, vikram year, calendar data)
                // This is for TODAY's date — distinct from profile.samvatInfo (birth date)
                todaySamvat: todayAstroData.todaySamvat || null,
            },
            // NEW: Complete context for AI chat reuse
            // This allows chat to have the SAME context used to generate the insight
            astroContext: {
                // User's birth chart (static)
                userChart: {
                    sunSign: userAstroData.sunSign,
                    moonSign: userAstroData.moonSign,
                    ascendant: userAstroData.ascendant || userAstroData.lagna,
                    nakshatra: userAstroData.nakshatra || userAstroData.moonNakshatra,
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
                    shadBala: todayAstroData.shadBala?._analysis || null,
                    muhurat: todayAstroData.muhurat,
                },
                // Search context summary (if available)
                cosmicWeather: searchContext ? {
                    retrogrades: searchContext.global?.events?.retrogrades || [],
                    moonPhase: searchContext.global?.events?.moonPhase,
                    eclipse: searchContext.global?.events?.eclipse,
                    todayNews: searchContext.global?.todayNews?.summary?.substring(0, 300),
                    weekly: searchContext.global?.weekly?.overview?.substring(0, 200),
                } : null,
                forecasts: searchContext?.userSpecific ? {
                    lagna: searchContext.userSpecific.lagnaForecast?.substring(0, 200),
                    moonSign: searchContext.userSpecific.moonSignForecast?.substring(0, 200),
                    dasha: searchContext.userSpecific.dashaForecast?.substring(0, 200),
                } : null,
            },
            notificationSent: false,
            // Staggered delivery tracking - per-card notification status
            cardNotifications: cardNotifications,
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
                step2_searchContextMs: step2Duration,
                step3_aiGenerationMs: step3Duration,
            },
        });

        // Extract predictions from prediction cards for tracking/validation
        try {
            await extractAndSavePredictions(userId, today, processedSections);
        } catch (predError) {
            logger.error("[PREDICTIONS] Failed to extract predictions", {
                structuredData: true,
                userId,
                error: String(predError),
            });
            // Don't throw - insight saved successfully
        }

        // ═══════════════════════════════════════════════════════════════
        // DELIVERY: First-time = immediate (all cards now); otherwise staggered (6/12/5/9 IST)
        // ═══════════════════════════════════════════════════════════════
        if (!skipNotification) {
            if (immediateDelivery) {
                try {
                    await sendAllCardNotifications(userId, today, processedSections, insightRef);
                    logger.info("[INSIGHT-SAVED] Insight saved, immediate delivery sent", {
                        structuredData: true,
                        userId,
                        date: today,
                        cardCount: processedSections.length,
                    });
                } catch (deliverError) {
                    logger.error("[INSIGHT-DELIVERY] Immediate delivery failed", {
                        structuredData: true,
                        userId,
                        error: String(deliverError),
                    });
                    // Don't throw - insight doc is saved, user can open app and see it
                }
            } else {
                try {
                    await enqueueDispatchTasks(userId, today, processedSections);
                    logger.info("[INSIGHT-SAVED] Insight saved, dispatch tasks enqueued", {
                        structuredData: true,
                        userId,
                        date: today,
                        cardCount: processedSections.length,
                        scheduledTimes: [...new Set(processedSections.map(s => s.scheduledFor))],
                    });
                } catch (dispatchError) {
                    logger.error("[DISPATCH-ENQUEUE] Failed to enqueue dispatch tasks", {
                        structuredData: true,
                        userId,
                        error: String(dispatchError),
                    });
                }
            }
        } else {
            logger.info("[INSIGHT-SAVED] Insight saved, delivery skipped (cooldown)", {
                structuredData: true,
                userId,
                date: today,
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

/**
 * Callable function to generate insight for current user
 */
export const generateInsightForCurrentUser = onCall({
    region: "asia-southeast2",
    secrets: [geminiApiKey, freeAstrologyApiKey],
    timeoutSeconds: 120,
    memory: "512MiB", // Reduced from 1GiB — single-user insight generation fits comfortably
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
    // AppCheck: DISABLED until Flutter client enables FirebaseAppCheck
    // TODO: Set to true after enabling AppCheck in lib/main.dart
    // enforceAppCheck: true,
}, async (request) => {
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
            const today = DateTime.now().toFormat("yyyy-MM-dd");
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
        throw new HttpsError("internal", error.message || "Failed to generate insight");
    }
});

/**
 * GENERATION: Runs ONCE daily at 5 AM IST
 * Enqueues insight generation tasks to Cloud Tasks queue for steady throughput.
 * Each task processes ONE user - this prevents quota spikes.
 * 
 * OLD: Promise.all with BATCH_SIZE=50 -> quota spikes, failures
 * NEW: Cloud Tasks with rate limiting -> smooth, reliable generation
 */
export const generateDailyAstroInsights = onSchedule({
    schedule: "0 5 * * *", // 5 AM IST - ONCE daily
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    memory: "512MiB", // Reduced - we're just enqueuing, not processing
    timeoutSeconds: 300,
    secrets: [], // No secrets needed for enqueuing
}, async (event) => {
    const today = DateTime.now().setZone("Asia/Kolkata").toFormat("yyyy-MM-dd");

    logger.info("🌅 Starting daily insights ENQUEUE (queue-based generation)", {
        structuredData: true,
        date: today,
    });

    try {
        const usersSnapshot = await db.collection("users")
            .where("astrologyData", "!=", null)
            .get();

        if (usersSnapshot.empty) {
            logger.info("No users with astrology data found");
            return { success: true, enqueued: 0 };
        }

        const users = usersSnapshot.docs.map((doc) => ({
            userId: doc.id,
            astrologyData: doc.data().astrologyData,
        }));

        logger.info(`Enqueuing ${users.length} insight generation tasks`, {
            structuredData: true,
            userCount: users.length,
            date: today,
        });

        // Initialize generation log for today
        await db.collection("insightGenerationLogs").doc(today).set({
            date: today,
            totalUsers: users.length,
            startedAt: new Date().toISOString(),
            status: "enqueuing",
        });

        // Get the task queue for the insight worker
        // Use location-specific format to specify asia-southeast2 region
        const functions = getFunctions();
        const queue = functions.taskQueue("locations/asia-southeast2/functions/processInsightTask");

        // Enqueue tasks for all users
        // Spread generation over 1 hour to avoid API rate limits and load spikes
        // Cloud Tasks handles rate limiting via the worker's rateLimits config
        let enqueued = 0;
        let enqueueFailed = 0;

        // Spread enqueue over 1 hour (3600 seconds) to distribute load
        const GENERATION_WINDOW_SECONDS = 3600; // 1 hour
        const totalUsers = users.length;

        for (let i = 0; i < users.length; i++) {
            const user = users[i];

            try {
                // Calculate delay: spread evenly over 1 hour
                // First user: 0 seconds, last user: ~3600 seconds
                const delaySeconds = Math.floor((i / totalUsers) * GENERATION_WINDOW_SECONDS);

                await queue.enqueue({
                    userId: user.userId,
                    astrologyData: user.astrologyData,
                    date: today,
                }, {
                    scheduleDelaySeconds: delaySeconds,
                });
                enqueued++;
            } catch (e) {
                enqueueFailed++;
                logger.warn("[ENQUEUE] Failed to enqueue task", {
                    structuredData: true,
                    userId: user.userId,
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
            total: users.length,
        });

        return { success: true, enqueued, enqueueFailed, total: users.length };
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
});

/**
 * DISPATCH WORKER: Sends a single card notification
 * Called by Cloud Tasks at scheduled time (6 AM, 12 PM, 5 PM, 9 PM IST)
 */
export const dispatchCardNotification = onTaskDispatched({
    retryConfig: {
        maxAttempts: 3,
        minBackoffSeconds: 30,
        maxBackoffSeconds: 300,
    },
    rateLimits: {
        maxConcurrentDispatches: 100,
        maxDispatchesPerSecond: 10,
    },
    region: "asia-southeast2",
    memory: "256MiB",
    timeoutSeconds: 30,
}, async (req) => {
    const { userId, date, cardIndex, cardType, title, content, scheduledFor } = req.data;

    if (!userId || !date || cardIndex === undefined) {
        logger.error("[DISPATCH-WORKER] Invalid task data", {
            structuredData: true,
            hasUserId: !!userId,
            hasDate: !!date,
            cardIndex,
        });
        return; // Don't retry invalid tasks
    }

    logger.info("[DISPATCH-WORKER] Dispatching card notification", {
        structuredData: true,
        userId,
        date,
        cardIndex,
        scheduledFor,
    });

    try {
        // Skip if already delivered (e.g. immediate delivery for first-time insight)
        const insightSnap = await db.collection("users").doc(userId).collection("dailyInsights").doc(date).get();
        if (insightSnap.exists) {
            const data = insightSnap.data();
            const cardNotifications = data?.cardNotifications || {};
            const cardState = cardNotifications[String(cardIndex)] || cardNotifications[cardIndex];
            if (cardState?.sent === true) {
                logger.info("[DISPATCH-WORKER] Card already sent, skipping", {
                    structuredData: true,
                    userId,
                    date,
                    cardIndex,
                });
                return;
            }
        }

        // Create notification document (triggers push notification via Firestore trigger)
        const notificationRef = db
            .collection("notifications")
            .doc(userId)
            .collection("notifications")
            .doc();

        await notificationRef.set({
            type: "dailyAstroInsight",
            cardType: "insight", // Unified type
            cardIndex: cardIndex || 0,
            totalCards: 4, // Standard 4 cards per day
            title: title || "",
            preview: stripMarkdown(content || "").substring(0, 150),
            insightId: date,
            date: date,
            timestamp: FieldValue.serverTimestamp(),
            read: false,
        });

        // Update insight document to mark card as sent
        try {
            const insightRef = db
                .collection("users")
                .doc(userId)
                .collection("dailyInsights")
                .doc(date);

            await insightRef.update({
                [`cardNotifications.${cardIndex}.sent`]: true,
                [`cardNotifications.${cardIndex}.sentAt`]: FieldValue.serverTimestamp(),
            });
        } catch (updateError) {
            // Don't fail if insight update fails - notification is already sent
            logger.warn("[DISPATCH-WORKER] Failed to update insight cardNotifications", {
                structuredData: true,
                userId,
                cardIndex,
                error: String(updateError),
            });
        }

        logger.info("[DISPATCH-WORKER] Card notification dispatched", {
            structuredData: true,
            userId,
            date,
            cardIndex,
        });
    } catch (error) {
        logger.error("[DISPATCH-WORKER] Failed to dispatch card notification", {
            structuredData: true,
            userId,
            date,
            cardIndex,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        // Re-throw to trigger Cloud Tasks retry
        throw error;
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// REMOVED FUNCTIONS (cleanup pass):
//
//   • dispatchScheduledInsights — Old cron-based 4×/day dispatcher.
//     Replaced by Cloud Tasks scheduling via `dispatchCardNotification` above,
//     which delivers per-card with exact `scheduleDelaySeconds`, retries, and
//     rate limits. Keeping both produced duplicate notifications.
//
//   • getAstroInsightSystemHealth — Diagnostics endpoint, no caller in Flutter
//     or backend. Cache stats are still introspectable via `clearAstroCaches`.
//
//   • checkPendingPredictions — Daily scheduler sending `predictionValidation`
//     notifications. Flutter has no handler for that notification type
//     (NotificationType enum lacks the case), so output was silently dropped.
//     Can be restored when a prediction-tracking UI is built.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Admin function to clear caches
 * Call with: { mode: "all" | "ai" | "old" }
 * - all: Clear ALL caches (nuclear option)
 * - ai: Clear only AI insight caches
 * - old: Clear only old versioned caches (keeps current version)
 */
export const clearAstroCaches = onCall({
    region: "asia-southeast2",
    memory: "256MiB",
    timeoutSeconds: 60,
    invoker: "public", // Allow client apps to invoke (Firebase Auth handles actual auth)
}, async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new HttpsError("unauthenticated", "Must be logged in");
    }

    // Optional: Add admin check here if you want to restrict this
    const mode = request.data?.mode || "old";

    logger.info("🗑️ Cache clear requested", {
        structuredData: true,
        userId,
        mode,
        cacheVersion: getCacheVersion(),
    });

    let result;
    switch (mode) {
        case "all":
            result = await clearAllCaches();
            break;
        case "ai":
            result = await clearAIInsightCaches();
            break;
        case "old":
        default:
            result = await clearOldVersionedCaches();
            break;
    }

    // Also get current cache stats
    const stats = await getCacheStats();

    return {
        ...result,
        cacheVersion: getCacheVersion(),
        stats,
    };
});

/**
 * CLEANUP: Remove old insightDispatch entries
 * Runs daily to prevent document accumulation
 * Keeps last 7 days of dispatch data for debugging
 */
export const cleanupOldDispatchEntries = onSchedule({
    schedule: "0 4 * * *", // Daily at 4 AM IST
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 300,
    memory: "256MiB",
}, async (event) => {
    const now = DateTime.now().setZone("Asia/Kolkata");
    const cutoffDate = now.minus({ days: 7 }).toFormat("yyyy-MM-dd");

    logger.info("🗑️ Starting insightDispatch cleanup", {
        structuredData: true,
        cutoffDate,
        currentDate: now.toFormat("yyyy-MM-dd"),
    });

    try {
        // Get all date documents older than cutoff
        const dispatchDocs = await db.collection("insightDispatch").get();

        let deletedDates = 0;
        let deletedEntries = 0;

        for (const dateDoc of dispatchDocs.docs) {
            const dateKey = dateDoc.id;

            // Skip dates newer than cutoff
            if (dateKey >= cutoffDate) {
                continue;
            }

            // Delete all time slot subcollections for this date
            const timeSlots = ["0600", "1200", "1700", "2100"];
            for (const slot of timeSlots) {
                const entriesSnapshot = await db
                    .collection("insightDispatch")
                    .doc(dateKey)
                    .collection(slot)
                    .get();

                if (!entriesSnapshot.empty) {
                    const batch = db.batch();
                    entriesSnapshot.docs.forEach((doc) => {
                        batch.delete(doc.ref);
                        deletedEntries++;
                    });
                    await batch.commit();
                }
            }

            // Delete the date document itself
            await dateDoc.ref.delete();
            deletedDates++;
        }

        logger.info("✅ insightDispatch cleanup completed", {
            structuredData: true,
            deletedDates,
            deletedEntries,
            cutoffDate,
        });

        return { success: true, deletedDates, deletedEntries };
    } catch (error) {
        logger.error("❌ insightDispatch cleanup failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

/**
 * CLEANUP: Remove expired cache entries from astroCache and astroCurrent collections
 * Runs daily to prevent stale data accumulation
 */
export const cleanupExpiredCacheEntries = onSchedule({
    schedule: "0 5 * * *", // Daily at 5 AM IST (after dispatch cleanup)
    region: "asia-southeast2",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 300,
    memory: "256MiB",
}, async (event) => {
    logger.info("🗑️ Starting expired cache cleanup", {
        structuredData: true,
        timestamp: DateTime.now().setZone("Asia/Kolkata").toISO(),
    });

    try {
        const result = await cleanupExpiredCache();

        logger.info("✅ Cache cleanup completed", {
            structuredData: true,
            deletedCount: result.deletedCount,
        });

        return result;
    } catch (error) {
        logger.error("❌ Cache cleanup failed", {
            structuredData: true,
            error: String(error),
            stack: error.stack?.substring(0, 500),
        });
        throw error;
    }
});

