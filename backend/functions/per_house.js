/**
 * Per-House Readings — self-contained module (reading + scheduler + callable).
 *
 * One call generates ALL 12 houses for a 14-day cycle (cheaper + coherent +
 * one cache entry per user per cycle). The reading is stored on the user doc
 * (astrologyData.skyHouseReadings) with cycle dates; the scheduler regenerates
 * when a cycle expires. No engine, no flavor object.
 *
 * Recipe (one flat pass): gatherContext -> prompt -> callGemini -> store.
 *
 * Vedic accuracy (Gochara): transits judged from BOTH Lagna and Moon sign
 * (BPHS). Each transit carries a favorability tag; Sade Sati / Kantaka Shani
 * are flagged when Saturn meets the criteria.
 *
 * Exports:
 *   generatePerHouse(uid, cycleStart, cycleEnd)  - core generator
 *   runEnqueuePerHouseReadings()                 - daily scheduler runner
 *   handleGeneratePerHouseNow(request)           - onCall force-regenerate
 *   computeCycleWindow / needsRegeneration / PER_HOUSE_CYCLE_DAYS
 */

import { HttpsError } from "firebase-functions/v2/https";
import { getFunctions } from "firebase-admin/functions";
import { DateTime } from "luxon";
import { db, FieldValue, logger } from "../lib/firebase.js";
import { requireAuth, getRecentlyActiveUids } from "../lib/auth_utils.js";
import { callGemini } from "../lib/gemini.js";
import { calculateWholeSignHouse, getTransitBinduScore } from "../lib/vedic_analysis.js";
import { getUpcomingSignIngresses } from "./sky_positions.js";
import { extractAscendantDegree, normalizeDasha } from "../lib/astro_helpers.js";

const CYCLE_DAYS = 14;
export const PER_HOUSE_CYCLE_DAYS = CYCLE_DAYS;

// Unified taskRouter queue — see backend/functions/task_router.js
const QUEUE_NAME = "locations/asia-southeast2/functions/taskRouter";
const ENQUEUE_WINDOW_SECONDS = 3600; // spread across 1h

const ZODIAC_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
];

const HOUSE_TOPICS = {
    1: "Self, identity, body, vitality",
    2: "Money, family, speech, food",
    3: "Siblings, courage, communication, short trips",
    4: "Home, mother, comfort, real estate, inner peace",
    5: "Children, creativity, romance, intelligence, speculation",
    6: "Health, work routines, debts, conflicts, service",
    7: "Marriage, partnerships, business deals, public dealings",
    8: "Transformation, longevity, hidden matters, inheritance, occult",
    9: "Higher learning, dharma, fortune, father, long travel",
    10: "Career, public reputation, authority, achievements",
    11: "Gains, friendships, networks, fulfilled wishes",
    12: "Solitude, loss, foreign lands, spirituality, expenses",
};

// Gochara favorability (BPHS): houses counted FROM NATAL MOON where each
// planet gives good results.
const GOCHARA_FAVORABLE = {
    Sun: [3, 6, 10, 11],
    Moon: [1, 3, 6, 7, 10, 11],
    Mars: [3, 6, 11],
    Mercury: [2, 4, 6, 8, 10, 11],
    Jupiter: [2, 5, 7, 9, 11],
    Venus: [1, 2, 3, 4, 5, 8, 9, 11, 12],
    Saturn: [3, 6, 11],
    Rahu: [3, 6, 10, 11],
    Ketu: [3, 6, 11],
};

// ---------------------------------------------------------------------------
// Cycle helpers
// ---------------------------------------------------------------------------

/** Current cycle window: starts today, ends CYCLE_DAYS later. */
export function computeCycleWindow(now = DateTime.now()) {
    return {
        cycleStart: now.toFormat("yyyy-MM-dd"),
        cycleEnd: now.plus({ days: CYCLE_DAYS }).toFormat("yyyy-MM-dd"),
    };
}

/** True if the user needs a regeneration today (cycle expired/missing). */
export function needsRegeneration(skyHouseReadings, today = DateTime.now()) {
    if (!skyHouseReadings?.cycleEndDate) return true;
    const end = DateTime.fromISO(skyHouseReadings.cycleEndDate);
    if (!end.isValid) return true;
    return today >= end;
}

// ---------------------------------------------------------------------------
// Context gathering
// ---------------------------------------------------------------------------

async function getGlobalSkyPositions() {
    try {
        const doc = await db.collection("global_astro").doc("sky_positions").get();
        if (!doc.exists) return null;
        return doc.data().positions || null;
    } catch (error) {
        logger.warn("[per_house] Failed to read global sky positions", {
            structuredData: true, error: String(error?.message || error),
        });
        return null;
    }
}

function signNameToIndex(name) {
    if (!name) return null;
    const idx = ZODIAC_SIGNS.indexOf(name);
    return idx >= 0 ? idx : null;
}

function bucketTransitsByHouse(skyPositions, userAscendantDegree, moonSignIndex, ashtakavarga) {
    const buckets = Object.fromEntries(Array.from({ length: 12 }, (_, i) => [i + 1, []]));
    if (!skyPositions || userAscendantDegree == null) return buckets;

    for (const [name, data] of Object.entries(skyPositions)) {
        if (!data || name === "Ascendant") continue;
        const deg = data.fullDegree ?? data.full_degree ?? data.degree;
        if (deg == null) continue;

        const house = calculateWholeSignHouse(deg, userAscendantDegree);
        if (!house || house < 1 || house > 12) continue;

        const transitSignIdx = Math.floor(deg / 30) % 12;
        const canonName = Object.keys(GOCHARA_FAVORABLE).find(
            (k) => name.toLowerCase().includes(k.toLowerCase()),
        );

        let houseFromMoon = null;
        let gochara = null;
        if (moonSignIndex != null && canonName) {
            houseFromMoon = ((transitSignIdx - moonSignIndex + 12) % 12) + 1;
            gochara = GOCHARA_FAVORABLE[canonName].includes(houseFromMoon)
                ? "favorable" : "unfavorable";
        }

        let bindu = null;
        if (canonName && ashtakavarga) {
            bindu = getTransitBinduScore(canonName, transitSignIdx, ashtakavarga);
        }

        buckets[house].push({
            planet: name,
            sign: data.zodiac_sign_name || data.sign,
            degree: Math.round(deg * 10) / 10,
            isRetro: data.isRetro === true || data.isRetro === "true",
            houseFromMoon,
            gochara,
            bindus: bindu?.bindus ?? null,
            binduQuality: bindu?.quality ?? null,
        });
    }
    return buckets;
}

function detectSaturnConditions(skyPositions, moonSignIndex) {
    if (!skyPositions || moonSignIndex == null) return {};
    const conditions = {};
    for (const [name, data] of Object.entries(skyPositions)) {
        if (!name.toLowerCase().includes("saturn")) continue;
        const deg = data.fullDegree ?? data.full_degree ?? data.degree;
        if (deg == null) continue;

        const saturnSignIdx = Math.floor(deg / 30) % 12;
        const houseFromMoon = ((saturnSignIdx - moonSignIndex + 12) % 12) + 1;

        if ([12, 1, 2].includes(houseFromMoon)) {
            const phase = houseFromMoon === 12 ? "rising (1st phase)"
                : houseFromMoon === 1 ? "peak (2nd phase)" : "waning (3rd phase)";
            conditions.sadeSati = { active: true, phase, houseFromMoon };
        }
        if ([4, 7, 10].includes(houseFromMoon)) {
            conditions.kantakaShani = { active: true, houseFromMoon };
        }
        if (houseFromMoon === 8) {
            conditions.ashtamaShani = { active: true };
        }
        break; // only one Saturn
    }
    return conditions;
}

async function getCycleIngresses(userAscendantDegree) {
    try {
        const all = await getUpcomingSignIngresses();
        if (!all?.length || userAscendantDegree == null) return [];

        const cycleEnd = DateTime.now().plus({ days: CYCLE_DAYS });
        const ascSignIndex = Math.floor(userAscendantDegree / 30);

        return all
            .filter((ing) => {
                const d = DateTime.fromISO(ing.date);
                return d.isValid && d <= cycleEnd;
            })
            .map((ing) => {
                const targetSignIdx = ZODIAC_SIGNS.indexOf(ing.toSign);
                if (targetSignIdx < 0) return null;
                const house = ((targetSignIdx - ascSignIndex + 12) % 12) + 1;
                return {
                    planet: ing.planet, toSign: ing.toSign, fromSign: ing.fromSign,
                    date: ing.date, house,
                };
            })
            .filter(Boolean);
    } catch (error) {
        logger.warn("[per_house] Failed to fetch ingresses", {
            structuredData: true, error: String(error?.message || error),
        });
        return [];
    }
}

async function gatherContext(uid, cycleStart, cycleEnd) {
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) throw new Error(`User ${uid} not found`);
    const userData = userSnap.data();
    const astro = userData.astrologyData;
    if (!astro) throw new Error(`User ${uid} has no astrologyData`);

    const userAscendantDegree = extractAscendantDegree(astro);
    const moonSignIndex = signNameToIndex(astro.moonSign);

    const skyPositions = await getGlobalSkyPositions();
    const transitsByHouse = bucketTransitsByHouse(
        skyPositions, userAscendantDegree, moonSignIndex, astro.ashtakavarga,
    );
    const saturnConditions = detectSaturnConditions(skyPositions, moonSignIndex);

    const cycleIngresses = await getCycleIngresses(userAscendantDegree);
    const ingressesByHouse = Object.fromEntries(Array.from({ length: 12 }, (_, i) => [i + 1, []]));
    for (const ing of cycleIngresses) {
        if (ingressesByHouse[ing.house]) ingressesByHouse[ing.house].push(ing);
    }

    const { mahaDasha, antarDasha } = normalizeDasha(astro.currentDasha);

    return {
        userName: userData.name || userData.displayName || "",
        lagnaSign: astro.ascendant || astro.lagna || "Unknown",
        moonSign: astro.moonSign || "Unknown",
        sunSign: astro.sunSign || "Unknown",
        mahaDasha,
        antarDasha,
        transitsByHouse,
        ingressesByHouse,
        natalHouseInterpretations: astro.houseInterpretations || null,
        saturnConditions,
        cycleStart,
        cycleEnd,
    };
}

// ---------------------------------------------------------------------------
// Prompt
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT = `You are a masterful Vedic astrologer (Jyotishi) writing personalized Gochara (transit) readings for each house.

VEDIC FRAMEWORK you follow:
- Whole-sign houses (Rashi-based) — the standard Parashara system.
- Transit results are judged primarily from the Moon sign (Chandra Rashi) per Gochara Shastra. Each transit planet is tagged "favorable" or "unfavorable" from Moon — honor this assessment.
- Ashtakavarga bindus (0-8) measure whether a transit can actually DELIVER: 5+ bindus = strong/reliable; 3-4 = mixed/moderate; 0-2 = weak. Weigh bindus together with the Moon-Gochara tag.
- When Sade Sati or Kantaka Shani is active, treat it as the dominant background theme.
- Dasha-transit alignment: a transit is most powerful when the transiting planet is also the active dasha lord or connects to it.
- Retrograde transits re-activate unfinished karma of that house — they don't simply "delay."
- You never invent yogas, aspects, or placements not in the data.

VOICE:
- Speak directly to the user ("You...") with warmth, specificity, and conviction.
- Weave multiple factors into ONE coherent narrative per house — never a bulleted list of factors.
- Use plain language. No Sanskrit terms, no "Mahadasha," no "7th aspect." Translate to felt human experience.
- Each reading should feel like a gift of self-understanding, not a textbook recitation.`;

function buildPrompt(ctx) {
    const {
        userName, lagnaSign, moonSign, sunSign, mahaDasha, antarDasha,
        transitsByHouse, ingressesByHouse, natalHouseInterpretations,
        saturnConditions, cycleStart, cycleEnd,
    } = ctx;

    let user = `Generate per-house "current state" readings for ${userName || "the user"} for the 14-day window ${cycleStart} to ${cycleEnd}.

CHART:
- Lagna (Rising): ${lagnaSign}
- Moon sign: ${moonSign}
- Sun sign: ${sunSign}
- Active life period: ${mahaDasha || "Unknown"}${antarDasha ? ` -> ${antarDasha}` : ""}
`;

    if (saturnConditions?.sadeSati?.active) {
        user += `\nSADE SATI ACTIVE — ${saturnConditions.sadeSati.phase}. Saturn is ${saturnConditions.sadeSati.houseFromMoon === 12 ? "12th" : saturnConditions.sadeSati.houseFromMoon === 1 ? "1st" : "2nd"} from Moon. This is a multi-year karmic period of inner restructuring — weave this awareness into relevant house readings (especially houses touched by Saturn). Do NOT catastrophize; Sade Sati refines, it doesn't destroy.\n`;
    }
    if (saturnConditions?.kantakaShani?.active) {
        user += `\nKANTAKA SHANI — Saturn is transiting ${saturnConditions.kantakaShani.houseFromMoon}th from Moon, creating pressure on that house's themes. Acknowledge the challenge constructively.\n`;
    }
    if (saturnConditions?.ashtamaShani?.active) {
        user += `\nASHTAMA SHANI — Saturn is 8th from Moon. Hidden disruptions and transformation themes are active. Reference where relevant.\n`;
    }

    user += `
OUTPUT FORMAT — strict JSON, exactly this shape:
{
  "houses": {
    "1": {
      "headline": "string, 4-8 words, captures the energy",
      "reading": "string, 2-4 sentences. ONE coherent insight that weaves current transits (with their Gochara favorability) + dasha context + upcoming sign changes. No bullet points. Address the user as 'you'.",
      "focus": "string, ONE actionable suggestion (1 sentence)",
      "watch": "string, ONE thing to be mindful of (1 sentence) OR empty string if nothing notable"
    },
    "2": { ... }, ... up to "12"
  }
}

RULES:
- ALWAYS produce all 12 houses (keys "1" through "12")
- NO Sanskrit or technical jargon. Translate everything to plain, warm language.
- Honor the Gochara favorability tags: "favorable" transits bring support/opportunity; "unfavorable" transits bring friction/lessons. Do NOT treat every transit as positive.
- Retrograde planets intensify and internalize the house themes — they revisit old patterns.
- If a house has NO active transits AND no ingress, write a short reading from its natal significations + how the current life period tints it.
- If timing matters, mention it naturally ("over the next two weeks", "around ${cycleEnd}")
- Be specific to THIS chart, not horoscope-generic. Reference concrete life areas.

PER-HOUSE DATA:
`;

    for (let h = 1; h <= 12; h++) {
        const transits = transitsByHouse[h] || [];
        const ingresses = ingressesByHouse[h] || [];
        const natal = natalHouseInterpretations?.[h];

        user += `\n--- HOUSE ${h} (${HOUSE_TOPICS[h]}) ---\n`;

        if (natal?.interpretation) {
            user += `Natal foundation: ${natal.interpretation.substring(0, 300)}\n`;
        } else if (natal) {
            user += `Natal: sign ${natal.sign}, lord ${natal.signLord}${natal.lordPlacement ? ` placed in house ${natal.lordPlacement}` : ""}${natal.planetsInHouse?.length ? `, occupants: ${natal.planetsInHouse.join(", ")}` : ""}\n`;
        }

        if (transits.length) {
            user += `Transiting now: ${transits.map((t) => {
                let s = `${t.planet} in ${t.sign}`;
                if (t.isRetro) s += " (retrograde)";
                if (t.houseFromMoon != null) s += ` [${t.houseFromMoon}th from Moon -> ${t.gochara || "neutral"}]`;
                if (t.bindus != null) s += ` {${t.bindus}/8 bindus -> ${t.binduQuality}}`;
                return s;
            }).join("; ")}\n`;
        }

        if (ingresses.length) {
            user += `Upcoming in this window: ${ingresses.map((i) => `${i.planet} enters ${i.toSign} on ${i.date}`).join("; ")}\n`;
        }

        if (!transits.length && !ingresses.length && !natal) {
            user += `(No specific transits — give a short reading from general house significations + current life-period tint)\n`;
        }
    }

    user += `\nReturn ONLY the JSON object. No markdown fences. No preamble.`;

    return { system: SYSTEM_PROMPT, user };
}

function validateResult(result) {
    if (!result?.houses || typeof result.houses !== "object") return false;
    for (let h = 1; h <= 12; h++) {
        const r = result.houses[String(h)] || result.houses[h];
        if (!r?.reading || typeof r.reading !== "string") return false;
    }
    return true;
}

// ---------------------------------------------------------------------------
// Core generator: gatherContext -> prompt -> callGemini -> store
// ---------------------------------------------------------------------------

/**
 * Generate + store all 12 house readings for one user's cycle.
 * @returns {Promise<{houses: Object, latencyMs: number}>}
 */
export async function generatePerHouse(uid, cycleStart, cycleEnd) {
    const ctx = await gatherContext(uid, cycleStart, cycleEnd);
    const { system, user } = buildPrompt(ctx);

    const { json, latencyMs } = await callGemini({
        systemPrompt: system,
        userPrompt: user,
        temperature: 0.85,
        expectJson: true,
        flavorName: "per_house",
    });

    if (!validateResult(json)) {
        throw new Error("per_house produced invalid result");
    }

    await db.collection("users").doc(uid).update({
        "astrologyData.skyHouseReadings": {
            cycleStartDate: cycleStart,
            cycleEndDate: cycleEnd,
            generatedAt: FieldValue.serverTimestamp(),
            houses: json.houses,
        },
    });

    return { houses: json.houses, latencyMs };
}

// ---------------------------------------------------------------------------
// Scheduler — runs daily, enqueues users whose cycle expired
// ---------------------------------------------------------------------------

const MAX_USERS_PER_RUN = parseInt(process.env.PER_HOUSE_MAX_USERS || "0", 10);
const TEST_UID_ALLOWLIST = (process.env.PER_HOUSE_TEST_UIDS || "")
    .split(",").map((s) => s.trim()).filter(Boolean);

/** Daily runner (invoked by unifiedOrchestrator). */
export async function runEnqueuePerHouseReadings() {
    const today = DateTime.now().setZone("Asia/Kolkata");
    logger.info("Per-house enqueue starting", {
        structuredData: true, date: today.toFormat("yyyy-MM-dd"),
    });

    let scanned = 0;
    let enqueued = 0;
    let skippedFresh = 0;
    let skippedNoData = 0;
    let enqueueFailed = 0;

    try {
        const usersSnap = await db.collection("users")
            .where("astrologyData", "!=", null)
            .get();

        const queue = getFunctions().taskQueue(QUEUE_NAME);
        const candidates = [];

        const activeDays = parseInt(process.env.PER_HOUSE_ACTIVE_DAYS || "14", 10);
        const activeUids = activeDays > 0 ? await getRecentlyActiveUids(activeDays) : null;
        let skippedDormant = 0;

        usersSnap.forEach((doc) => {
            scanned++;
            if (TEST_UID_ALLOWLIST.length && !TEST_UID_ALLOWLIST.includes(doc.id)) return;
            if (activeUids && !activeUids.has(doc.id)) {
                skippedDormant++;
                return;
            }
            const astro = doc.data().astrologyData;
            if (!astro?.ascendant && !astro?.lagna) {
                skippedNoData++;
                return;
            }
            if (!needsRegeneration(astro.skyHouseReadings, today)) {
                skippedFresh++;
                return;
            }
            candidates.push(doc.id);
        });

        if (MAX_USERS_PER_RUN > 0 && candidates.length > MAX_USERS_PER_RUN) {
            logger.info("[per_house] safety cap applied", {
                structuredData: true,
                originalCount: candidates.length,
                cappedTo: MAX_USERS_PER_RUN,
            });
            candidates.length = MAX_USERS_PER_RUN;
        }

        const total = candidates.length;
        for (let i = 0; i < total; i++) {
            const uid = candidates[i];
            const delaySeconds = total > 0 ? Math.floor((i / total) * ENQUEUE_WINDOW_SECONDS) : 0;
            try {
                await queue.enqueue(
                    { taskType: "process_per_house", uid, scheduledFor: today.toISO() },
                    { scheduleDelaySeconds: delaySeconds },
                );
                enqueued++;
            } catch (e) {
                enqueueFailed++;
                logger.warn("[per_house] enqueue failed", {
                    structuredData: true, uid, error: String(e?.message || e),
                });
            }
        }

        logger.info("Per-house enqueue complete", {
            structuredData: true,
            scanned, enqueued, skippedFresh, skippedNoData, skippedDormant, enqueueFailed,
            cycleDays: PER_HOUSE_CYCLE_DAYS,
        });

        return { scanned, enqueued, skippedFresh, skippedNoData, skippedDormant, enqueueFailed };
    } catch (error) {
        logger.error("Per-house enqueue failed", {
            structuredData: true,
            error: String(error?.message || error),
            stack: error?.stack?.substring(0, 500),
        });
        throw error;
    }
}

// ---------------------------------------------------------------------------
// Manual callable — first sync / force-refresh from app
// ---------------------------------------------------------------------------

/** onCall handler: generate per-house readings now (or return fresh cached). */
export async function handleGeneratePerHouseNow(request) {
    let stage = "init";
    let uid = null;
    try {
        stage = "requireAuth";
        uid = requireAuth(request, "generate per-house readings");
        const force = !!request.data?.force;
        logger.info("[per_house-callable] entered", { structuredData: true, uid, force });

        stage = "loadUser";
        const userSnap = await db.collection("users").doc(uid).get();
        if (!userSnap.exists) throw new HttpsError("not-found", "User not found");
        const astro = userSnap.data().astrologyData;
        if (!astro?.ascendant && !astro?.lagna) {
            throw new HttpsError("failed-precondition", "Astrology data not ready yet");
        }

        stage = "checkFreshness";
        if (!force && !needsRegeneration(astro.skyHouseReadings)) {
            return {
                success: true,
                alreadyFresh: true,
                cycleEndDate: astro.skyHouseReadings.cycleEndDate,
                houses: astro.skyHouseReadings.houses,
            };
        }

        stage = "generate";
        const window = computeCycleWindow();
        const { houses, latencyMs } = await generatePerHouse(uid, window.cycleStart, window.cycleEnd);

        stage = "return";
        return {
            success: true,
            alreadyFresh: false,
            cycleStartDate: window.cycleStart,
            cycleEndDate: window.cycleEnd,
            houses,
            latencyMs,
        };
    } catch (error) {
        if (error instanceof HttpsError) {
            logger.error("[per_house-callable] HttpsError thrown", {
                structuredData: true, uid, stage, code: error.code, message: error.message,
            });
            throw new HttpsError(error.code, `[stage=${stage}] ${error.message}`, error.details);
        }
        const message = String(error?.message || error || "unknown error");
        logger.error("[per_house-callable] uncaught exception", {
            structuredData: true, uid, stage, message,
            stack: error?.stack?.substring(0, 800),
        });
        throw new HttpsError("internal", `[stage=${stage}] ${message}`, { stage });
    }
}
