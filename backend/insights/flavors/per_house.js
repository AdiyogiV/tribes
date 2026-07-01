/**
 * per_house flavor — biweekly per-house current-state readings.
 *
 * One call generates ALL 12 houses for a 14-day cycle. Why one call?
 *  • ~6× cheaper than 12 separate calls
 *  • Coherent across houses (AI can cross-reference: "your 7th amplifies your 1st")
 *  • One cache entry per user per cycle
 *  • Matches the existing house_interpretations.js pattern
 *
 * What the user sees:
 *   Tap a house in Current Sky → instant read from cached field on user doc.
 *   No on-demand AI call. No spinner. No latency surprise.
 *
 * Cadence:
 *   Generated when cycleEndDate < today. The per_house_scheduler runs daily,
 *   finds users whose cycle has expired, and enqueues regeneration. Spreads
 *   load naturally across the user base.
 *
 * Vedic accuracy (Gochara):
 *   Transit results are judged from BOTH Lagna and Moon sign, following
 *   Brihat Parashara Hora Shastra. Each transit planet carries a Gochara
 *   favorability tag (favorable / unfavorable from Moon). Sade Sati and
 *   Kantaka Shani are flagged when Saturn meets the criteria.
 */

import { db, FieldValue, logger } from "../../lib/firebase.js";
import { DateTime } from "luxon";
import {
    calculateWholeSignHouse,
    getTransitBinduScore,
} from "../../lib/vedic_analysis.js";
import {
    getUpcomingSignIngresses,
} from "../../functions/sky_positions.js";
import { extractAscendantDegree, normalizeDasha } from "../../lib/astro_helpers.js";

const CYCLE_DAYS = 14;

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

// ---------------------------------------------------------------------------
// Gochara (transit) favorability — Brihat Parashara Hora Shastra
// Houses counted FROM NATAL MOON where each planet gives good results.
// ---------------------------------------------------------------------------

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
// Context gathering
// ---------------------------------------------------------------------------

/**
 * Pull global cached sky positions (today's planets in the sky).
 * Returns null if not available — caller decides what to do.
 */
async function getGlobalSkyPositions() {
    try {
        const doc = await db.collection("global_astro").doc("sky_positions").get();
        if (!doc.exists) return null;
        return doc.data().positions || null;
    } catch (error) {
        logger.warn("[per_house] Failed to read global sky positions", {
            structuredData: true,
            error: String(error?.message || error),
        });
        return null;
    }
}

/**
 * Convert a sign name ("Libra") to a 0-based index (6).
 * Returns null if sign name is unrecognised.
 */
function signNameToIndex(name) {
    if (!name) return null;
    const idx = ZODIAC_SIGNS.indexOf(name);
    return idx >= 0 ? idx : null;
}

/**
 * For each of the 12 houses (from Lagna), compute which transit planets are
 * currently in it.  Also annotates each entry with its house-from-Moon and
 * Gochara favorability so the prompt can reference it.
 */
function bucketTransitsByHouse(skyPositions, userAscendantDegree, moonSignIndex, ashtakavarga) {
    const buckets = Object.fromEntries(
        Array.from({ length: 12 }, (_, i) => [i + 1, []]),
    );
    if (!skyPositions || userAscendantDegree == null) return buckets;

    for (const [name, data] of Object.entries(skyPositions)) {
        if (!data || name === "Ascendant") continue;
        const deg = data.fullDegree ?? data.full_degree ?? data.degree;
        if (deg == null) continue;

        const house = calculateWholeSignHouse(deg, userAscendantDegree);
        if (!house || house < 1 || house > 12) continue;

        const transitSignIdx = Math.floor(deg / 30) % 12;

        // Canonical Navagraha name (for Gochara + Ashtakavarga lookups)
        const canonName = Object.keys(GOCHARA_FAVORABLE).find(
            (k) => name.toLowerCase().includes(k.toLowerCase()),
        );

        // House from Moon (Gochara reference)
        let houseFromMoon = null;
        let gochara = null;
        if (moonSignIndex != null && canonName) {
            houseFromMoon = ((transitSignIdx - moonSignIndex + 12) % 12) + 1;
            gochara = GOCHARA_FAVORABLE[canonName].includes(houseFromMoon)
                ? "favorable"
                : "unfavorable";
        }

        // Ashtakavarga transit strength: bindus (0-8) in the transited sign.
        // The classical filter for whether a transit can actually deliver.
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

/**
 * Detect major Saturn transit conditions from Moon sign:
 *  - Sade Sati (Saturn in 12th, 1st, or 2nd from Moon) — ~7.5 year karmic period
 *  - Kantaka Shani (Saturn in 4th, 7th, or 10th from Moon) — pressure on those houses
 *  - Ashtama Shani (Saturn in 8th from Moon) — hidden disruptions
 */
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
                : houseFromMoon === 1 ? "peak (2nd phase)"
                    : "waning (3rd phase)";
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

/**
 * Pull upcoming ingresses for the cycle window so the AI can mention what's
 * coming. Buckets each ingress by which house it'll affect (using the user's
 * Lagna).
 */
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
                    planet: ing.planet,
                    toSign: ing.toSign,
                    fromSign: ing.fromSign,
                    date: ing.date,
                    house,
                };
            })
            .filter(Boolean);
    } catch (error) {
        logger.warn("[per_house] Failed to fetch ingresses", {
            structuredData: true,
            error: String(error?.message || error),
        });
        return [];
    }
}

// ---------------------------------------------------------------------------
// Prompt building
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT = `You are a masterful Vedic astrologer (Jyotishi) writing personalized Gochara (transit) readings for each house.

VEDIC FRAMEWORK you follow:
• Whole-sign houses (Rashi-based) — the standard Parashara system.
• Transit results are judged primarily from the Moon sign (Chandra Rashi) per Gochara Shastra.  Each transit planet is tagged "favorable" or "unfavorable" from Moon — honor this assessment.
• Ashtakavarga bindus (0-8) measure whether a transit can actually DELIVER: 5+ bindus = strong/reliable (a favorable transit lands, an unfavorable one is cushioned); 3-4 = mixed/moderate; 0-2 = weak (even a favorable transit underdelivers; an unfavorable one bites harder).  Weigh bindus together with the Moon-Gochara tag — they refine each other.
• When Sade Sati or Kantaka Shani is active, treat it as the dominant background theme — it colors every house Saturn touches.
• Dasha–transit alignment: a transit is most powerful when the transiting planet is also the active dasha lord or connects to it.  Mention timing naturally when relevant.
• Retrograde transits re-activate unfinished karma of that house — they don't simply "delay."
• You never invent yogas, aspects, or placements not in the data.  Every claim ties to a provided factor.

VOICE:
• Speak directly to the user ("You…") with warmth, specificity, and conviction.
• Weave multiple factors into ONE coherent narrative per house — never a bulleted list of factors.
• Use plain language.  No Sanskrit terms, no "Mahadasha," no "7th aspect."  Translate to felt human experience.
• Each reading should feel like a gift of self-understanding, not a textbook recitation.`;

function buildPrompt({ ctx, params }) {
    const {
        userName,
        lagnaSign,
        moonSign,
        sunSign,
        mahaDasha,
        antarDasha,
        transitsByHouse,
        ingressesByHouse,
        natalHouseInterpretations,
        saturnConditions,
        cycleStart,
        cycleEnd,
    } = ctx;

    let user = `Generate per-house "current state" readings for ${userName || "the user"} for the 14-day window ${cycleStart} → ${cycleEnd}.

CHART:
- Lagna (Rising): ${lagnaSign}
- Moon sign: ${moonSign}
- Sun sign: ${sunSign}
- Active life period: ${mahaDasha || "Unknown"}${antarDasha ? ` → ${antarDasha}` : ""}
`;

    // Flag major Saturn conditions
    if (saturnConditions?.sadeSati?.active) {
        user += `\n⚠️ SADE SATI ACTIVE — ${saturnConditions.sadeSati.phase}. Saturn is ${saturnConditions.sadeSati.houseFromMoon === 12 ? "12th" : saturnConditions.sadeSati.houseFromMoon === 1 ? "1st" : "2nd"} from Moon. This is a multi-year karmic period of inner restructuring — weave this awareness into relevant house readings (especially houses touched by Saturn). Do NOT catastrophize; Sade Sati refines, it doesn't destroy.\n`;
    }
    if (saturnConditions?.kantakaShani?.active) {
        user += `\n⚠️ KANTAKA SHANI — Saturn is transiting ${saturnConditions.kantakaShani.houseFromMoon}th from Moon, creating pressure on that house's themes. Acknowledge the challenge constructively.\n`;
    }
    if (saturnConditions?.ashtamaShani?.active) {
        user += `\n⚠️ ASHTAMA SHANI — Saturn is 8th from Moon. Hidden disruptions and transformation themes are active. Reference where relevant.\n`;
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

        // Natal context (brief)
        if (natal?.interpretation) {
            user += `Natal foundation: ${natal.interpretation.substring(0, 300)}\n`;
        } else if (natal) {
            user += `Natal: sign ${natal.sign}, lord ${natal.signLord}${natal.lordPlacement ? ` placed in house ${natal.lordPlacement}` : ""}${natal.planetsInHouse?.length ? `, occupants: ${natal.planetsInHouse.join(", ")}` : ""}\n`;
        }

        // Current transits with Gochara tags
        if (transits.length) {
            user += `Transiting now: ${transits.map((t) => {
                let s = `${t.planet} in ${t.sign}`;
                if (t.isRetro) s += " (retrograde)";
                if (t.houseFromMoon != null) s += ` [${t.houseFromMoon}th from Moon -> ${t.gochara || "neutral"}]`;
                if (t.bindus != null) s += ` {${t.bindus}/8 bindus -> ${t.binduQuality}}`;
                return s;
            }).join("; ")}\n`;
        }

        // Upcoming ingresses
        if (ingresses.length) {
            user += `Upcoming in this window: ${ingresses.map((i) => `${i.planet} enters ${i.toSign} on ${i.date}`).join("; ")}\n`;
        }

        if (!transits.length && !ingresses.length && !natal) {
            user += `(No specific transits — give a short reading from general house significations + current life-period tint)\n`;
        }
    }

    user += `\nReturn ONLY the JSON object. No markdown fences. No preamble.`;

    return {
        system: SYSTEM_PROMPT,
        user,
        options: {
            expectJson: true,
            temperature: 0.85,
        },
    };
}

// ---------------------------------------------------------------------------
// Validation + storage
// ---------------------------------------------------------------------------

function validateResult(result) {
    if (!result?.houses || typeof result.houses !== "object") return false;
    // Must have all 12 houses with at least a reading
    for (let h = 1; h <= 12; h++) {
        const r = result.houses[String(h)] || result.houses[h];
        if (!r?.reading || typeof r.reading !== "string") return false;
    }
    return true;
}

async function storeResult(params, result) {
    const { uid, cycleStart, cycleEnd } = params;
    await db.collection("users").doc(uid).update({
        "astrologyData.skyHouseReadings": {
            cycleStartDate: cycleStart,
            cycleEndDate: cycleEnd,
            generatedAt: FieldValue.serverTimestamp(),
            houses: result.houses,
        },
    });
}

// ---------------------------------------------------------------------------
// Flavor definition
// ---------------------------------------------------------------------------

export const perHouseFlavor = {
    name: "per_house",

    async gatherContext(params) {
        const { uid } = params;
        const userSnap = await db.collection("users").doc(uid).get();
        if (!userSnap.exists) {
            throw new Error(`User ${uid} not found`);
        }
        const userData = userSnap.data();
        const astro = userData.astrologyData;
        if (!astro) {
            throw new Error(`User ${uid} has no astrologyData`);
        }

        const userAscendantDegree = extractAscendantDegree(astro);
        const moonSignIndex = signNameToIndex(astro.moonSign);

        const skyPositions = await getGlobalSkyPositions();
        const transitsByHouse = bucketTransitsByHouse(
            skyPositions,
            userAscendantDegree,
            moonSignIndex,
            astro.ashtakavarga,
        );
        const saturnConditions = detectSaturnConditions(skyPositions, moonSignIndex);

        const cycleIngresses = await getCycleIngresses(userAscendantDegree);
        const ingressesByHouse = Object.fromEntries(
            Array.from({ length: 12 }, (_, i) => [i + 1, []]),
        );
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
            cycleStart: params.cycleStart,
            cycleEnd: params.cycleEnd,
        };
    },

    prompt: buildPrompt,
    validate: validateResult,
    store: storeResult,

    // We do NOT use the engine cache here — the readings are stored on the
    // user doc with cycle dates, and the scheduler decides regeneration. This
    // avoids two sources of truth for "is this still fresh?".
};

/**
 * Compute the current cycle window for a user.
 * Cycle starts on the day of last generation (or today for new users).
 * Cycle ends CYCLE_DAYS later.
 */
export function computeCycleWindow(now = DateTime.now()) {
    const start = now.toFormat("yyyy-MM-dd");
    const end = now.plus({ days: CYCLE_DAYS }).toFormat("yyyy-MM-dd");
    return { cycleStart: start, cycleEnd: end };
}

/**
 * Returns true if this user needs a regeneration today.
 */
export function needsRegeneration(skyHouseReadings, today = DateTime.now()) {
    if (!skyHouseReadings?.cycleEndDate) return true;
    const end = DateTime.fromISO(skyHouseReadings.cycleEndDate);
    if (!end.isValid) return true;
    return today >= end;
}

export const PER_HOUSE_CYCLE_DAYS = CYCLE_DAYS;
