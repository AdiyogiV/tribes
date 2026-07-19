// circle_vibes.js — "Friends Today" vibe strip (Co-Star-style social layer).
//
// One read-only projection over data we ALREADY compute:
//   - each friend's `forecast[today].heading` (the ≤4-word evocative vibe word,
//     produced by the unified forecast pipeline — see forecast/narrate.js), and
//   - their profile name/photo (read anyway for the privacy gate).
//
// It invents NO new astrology, makes NO new AI/API calls, and NEVER exposes a
// friend's private first-person narrative — only their public vibe word leaves
// the server. Gating reuses the exact mutual-follow + block + astrology-privacy
// rules that compatibility.js already enforces (DRY).
//
// Scaling note: reads scale with the number of friends the client renders
// (capped at MAX_FRIENDS), not the whole social graph. If this ever becomes a
// hot, always-on surface, denormalize a tiny public vibe doc per user and read
// it directly — but that's a YAGNI problem until proven.

import { logger } from "firebase-functions/v2";
import { db } from "../lib/firebase.js";
import { requireAuth } from "../lib/auth_utils.js";
import { checkBlockedDetailed } from "../lib/utils.js";
import { checkMutualFollow } from "./compatibility.js";
import { istToday, dayKey, monthKeyOf } from "./forecast/forecast_helpers.js";
import { computePairTransitSynastry } from "../lib/vedic_pair_transit_synastry.js";

/** Cap so one call can't fan out into unbounded Firestore reads. */
export const MAX_FRIENDS = 30;

/**
 * Pure: normalize the client-supplied friend id list.
 * De-dupes, drops self + non-string/empty ids, and caps the count.
 *
 * @param {string} currentUserId
 * @param {unknown} friendIds
 * @param {number} [max]
 * @returns {string[]}
 */
export function normalizeFriendIds(currentUserId, friendIds, max = MAX_FRIENDS) {
    if (!Array.isArray(friendIds)) return [];
    const seen = new Set();
    const out = [];
    for (const id of friendIds) {
        if (typeof id !== "string") continue;
        const trimmed = id.trim();
        if (!trimmed || trimmed === currentUserId || seen.has(trimmed)) continue;
        seen.add(trimmed);
        out.push(trimmed);
        if (out.length >= max) break;
    }
    return out;
}

/**
 * Pure: project a friend's profile + forecast into a shareable vibe, or null.
 *
 * Returns null (→ friend omitted from the strip) when:
 *   - the friend has marked their astrology private, or
 *   - there is no narrated heading for today (we show a word or nothing —
 *     never a blank face).
 *
 * Crucially, this only ever surfaces the friend-SAFE fields: the heading and
 * the third-person `publicNote`. The private first-person `narrative` (and
 * action/caution/tip) are left behind on the server.
 *
 * When [pairCtx] is supplied (the current user's natal chart + today's sky) we
 * also attach a `together` block: the transit synastry-of-the-day computed from
 * BOTH people's full natal charts vs today's transiting planets. Only the
 * DERIVED numbers (score/label/reasons) cross the wire — the friend's raw chart
 * never leaves the server, same as the private narrative.
 *
 * @param {string} uid
 * @param {Object} userData         users/{uid} document data
 * @param {Array}  forecastDays     friend's forecast month doc `days` array
 * @param {string} todayKey         yyyy-MM-dd (IST)
 * @param {Object} [pairCtx]        { myNatal, transit } for the synastry pairing
 * @returns {{uid:string, name:string, photo:(string|null), vibe:string,
 *            publicNote:(string|null), together?:Object}|null}
 */
export function pickTodayVibe(uid, userData, forecastDays, todayKey, pairCtx = null) {
    const u = userData || {};
    if (u.astrologyData?.visibility === "private") return null;

    const today = (forecastDays || []).find((d) => d && d.date === todayKey);
    const vibe = today?.heading?.trim();
    if (!vibe) return null;

    const publicNote = today?.publicNote?.trim();

    const out = {
        uid,
        name: u.displayName || u.name || "Friend",
        photo: u.displayPicture || null,
        vibe,
        publicNote: publicNote || null,
    };

    // Transit "cosmic weather for the two of you today" — full-chart synastry.
    const friendNatal = u.astrologyData?.birthChartData?.output;
    if (pairCtx?.myNatal && pairCtx?.transit && friendNatal) {
        const pair = computePairTransitSynastry({
            natalA: pairCtx.myNatal,
            natalB: friendNatal,
            transit: pairCtx.transit,
        });
        if (pair.score != null) {
            // The bond: only signals that touch BOTH charts (shared + bridge).
            out.together = {
                score: pair.score,
                label: pair.label,
                connection: pair.connection,
            };
            // The friend's OWN transit weather — for their energy card, not the
            // connection card. (personalB = friend, since natalB = friend.)
            if (pair.personalB?.length) out.energy = pair.personalB;
        }
    }

    return out;
}

/**
 * onCall handler (via astroGateway `getCircleVibes`): given the friend ids the
 * client is rendering, return each mutual-follow friend's vibe word for today.
 *
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 * @returns {Promise<{success:boolean, date:string, vibes:Array}>}
 */
export async function handleGetCircleVibes(request) {
    const currentUserId = requireAuth(request, "get circle vibes");

    const ids = normalizeFriendIds(currentUserId, request.data?.friendIds);
    const todayKey = dayKey(istToday());
    const monthDocId = monthKeyOf(todayKey);

    if (ids.length === 0) return { success: true, date: todayKey, vibes: [] };

    // Read the CURRENT user's forecast once so we can pair the day's transits
    // for every friend. Non-fatal: if it's missing, friends just render without
    // a `together` block.
    let pairCtx = null;
    try {
        const [meSnap, skySnap] = await Promise.all([
            db.collection("users").doc(currentUserId).get(),
            db.collection("global_astro").doc("sky_positions").get(),
        ]);
        const myNatal = meSnap.exists ?
            meSnap.data().astrologyData?.birthChartData?.output :
            null;
        const transit = skySnap.exists ?
            (skySnap.data().positions?.[todayKey] || null) :
            null;
        if (myNatal && transit) pairCtx = { myNatal, transit };
    } catch (err) {
        logger.warn("getCircleVibes: could not load chart/sky for pairing", { error: err.message });
    }

    const results = await Promise.all(ids.map(async (fid) => {
        try {
            // Gate first (cheap-ish, and lets us skip the profile/forecast reads
            // entirely for non-friends / blocked users).
            const [mutual, block] = await Promise.all([
                checkMutualFollow(currentUserId, fid),
                checkBlockedDetailed(db, currentUserId, fid),
            ]);
            if (!mutual || block.isBlocked) return null;

            const [userSnap, fcastSnap] = await Promise.all([
                db.collection("users").doc(fid).get(),
                db.collection("users").doc(fid)
                    .collection("forecast").doc(monthDocId).get(),
            ]);
            if (!userSnap.exists) return null;

            const days = fcastSnap.exists ? (fcastSnap.data().days || []) : [];
            return pickTodayVibe(fid, userSnap.data(), days, todayKey, pairCtx);
        } catch (err) {
            // One flaky friend shouldn't sink the whole strip.
            logger.warn("getCircleVibes: skipping friend", { fid, error: err.message });
            return null;
        }
    }));

    return { success: true, date: todayKey, vibes: results.filter(Boolean) };
}
