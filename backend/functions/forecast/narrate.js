/**
 * narrate.js — the NARRATE + REMEMBER layers of the unified forecast.
 *
 * ONE Gemini call per user turns the horizon of computed day-signals (from
 * sense.js) into a continuous, personal story: a {heading, narrative} for each
 * upcoming day, woven with the person's memory + ongoing storyline. It then
 * folds the finished chapter back into a bounded storyline arc (REMEMBER).
 *
 * The result is written into the SAME read-model SENSE writes
 * (users/{uid}/forecast/{yyyy-MM}), so the wheel, the daily card, and Aurobhatt
 * all read one coherent source. ~1 AI call / user / month.
 */

import { getFunctions } from "firebase-admin/functions";
import { DateTime } from "luxon";
import { db, FieldValue, logger } from "../../lib/firebase.js";
import { callGemini } from "../../lib/gemini.js";
import { buildDashaContext } from "../../lib/daily_insight_context.js";
import { getRecentlyActiveUids } from "../../lib/auth_utils.js";
import { NARRATE_SYSTEM_PROMPT, buildNarratePrompt } from "../prompts/forecast_narrate.js";
import { istToday, dayKey, FORECAST_ZONE } from "./forecast_helpers.js";
import { validateNarratedDays } from "./narration_validation.js";

// Unified taskRouter queue — see backend/functions/task_router.js
const QUEUE_NAME = "locations/asia-southeast2/functions/taskRouter";
const ENQUEUE_WINDOW_SECONDS = 3600; // spread across 1h
const ENQUEUE_LEASE_MS = 2 * 60 * 60 * 1000; // covers stagger + task retries

// How many days ahead a single narrate call covers.
const NARRATE_HORIZON_DAYS = Number(process.env.NARRATE_HORIZON_DAYS || 30);
// Regenerate when fewer than this many narrated days remain ahead.
const NARRATE_MIN_LEAD_DAYS = Number(process.env.NARRATE_MIN_LEAD_DAYS || 7);
// Only narrate for users active in the last N days.
const NARRATE_ACTIVE_DAYS = Number(process.env.NARRATE_ACTIVE_DAYS || 7);
const MAX_USERS_PER_RUN = Number(process.env.NARRATE_MAX_USERS || 250);

// Storyline bounds (kept bounded forever — same discipline as user_memory).
const RECENT_BEATS_CAP = 4;
const STORYLINE_THREADS_CAP = 6;

/** Plain-English one-liner of the natal chart for the prompt (no jargon downstream). */
function chartSummary(astro) {
    if (!astro) return "(chart unavailable)";
    const moon = astro.moonSign ? `Moon in ${astro.moonSign}` : null;
    const nak = astro.moonNakshatra || astro.nakshatra;
    const moonNak = moon && nak ? `${moon} (${nak})` : moon;
    const lagna = astro.ascendant || astro.lagna;
    const rising = lagna ? `${lagna} rising` : null;
    const sun = astro.sunSign ? `Sun in ${astro.sunSign}` : null;
    return [moonNak, rising, sun].filter(Boolean).join(", ") || "(chart unavailable)";
}

/** The month-doc ids spanning [from, to] inclusive. */
function monthsBetween(fromKey, toKey) {
    const out = new Set();
    let dt = DateTime.fromISO(fromKey, { zone: FORECAST_ZONE });
    const end = DateTime.fromISO(toKey, { zone: FORECAST_ZONE });
    while (dt <= end) {
        out.add(dt.toFormat("yyyy-MM"));
        dt = dt.plus({ months: 1 }).startOf("month");
    }
    out.add(toKey.slice(0, 7));
    return [...out];
}

/**
 * Narrate the upcoming forecast horizon for one user, then compact the storyline.
 * @returns {Promise<{ ok:boolean, narrated?:number, reason?:string }>}
 */
export async function narrateForecastForUser(uid) {
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return { ok: false, reason: "no-user" };
    const astro = userSnap.data().astrologyData;
    if (!astro) return { ok: false, reason: "no-chart" };

    const todayKey = dayKey(istToday());
    const endKey = dayKey(istToday().plus({ days: NARRATE_HORIZON_DAYS }));

    // Load the forecast month docs covering the horizon and collect the
    // upcoming day-signals (SENSE must have run first).
    const monthIds = monthsBetween(todayKey, endKey);
    const monthDocs = new Map();
    const signals = [];
    for (const mid of monthIds) {
        const snap = await userRef.collection("forecast").doc(mid).get();
        if (!snap.exists) continue;
        const data = snap.data();
        monthDocs.set(mid, data);
        for (const d of data.days || []) {
            if (d.date >= todayKey && d.date <= endKey && d.alignment != null) {
                signals.push({
                    date: d.date,
                    alignment: d.alignment,
                    tara: d.tara,
                    favorable: d.favorable,
                    unfavorable: d.unfavorable,
                });
            }
        }
    }
    signals.sort((a, b) => a.date.localeCompare(b.date));
    if (!signals.length) return { ok: false, reason: "no-signals" };

    // Person context: memory + storyline (read the doc directly to get storyline).
    const memSnap = await userRef.collection("memory").doc("profile").get();
    const mem = memSnap.exists ? memSnap.data() : {};
    const person = {
        chartSummary: chartSummary(astro),
        rollingSummary: mem.rollingSummary || "",
        threads: mem.threads || [],
        storyline: mem.storyline || {},
    };

    const dashaContext = await buildDashaContext(uid, astro.currentDasha);

    // The one AI call.
    const { json } = await callGemini({
        systemPrompt: NARRATE_SYSTEM_PROMPT,
        userPrompt: buildNarratePrompt({ person, signals, dashaContext }),
        temperature: 0.9,
        maxOutputTokens: 8192,
        expectJson: true,
        googleSearch: false,
        flavorName: "forecast_narrate",
    });

    const validation = validateNarratedDays(json?.days, signals);
    if (!validation.ok) {
        throw new Error(`Invalid forecast narration: ${validation.reason}`);
    }
    const narratedDays = validation.days;

    // Merge headings/narratives back into the month docs by date (preserve the
    // computed alignment/signals). Group narrated days by month.
    const narrativeByDate = new Map(narratedDays.map((d) => [d.date, d]));
    let narrated = 0;

    for (const [mid] of monthDocs) {
        const ref = userRef.collection("forecast").doc(mid);
        let monthNarrated = 0;
        await db.runTransaction(async (transaction) => {
            const latest = await transaction.get(ref);
            if (!latest.exists) return;

            let touched = false;
            monthNarrated = 0;
            const days = (latest.data().days || []).map((day) => {
                const n = narrativeByDate.get(day.date);
                if (!n) return day;
                touched = true;
                monthNarrated++;
                return {
                    ...day,
                    heading: n.heading,
                    narrative: n.narrative,
                };
            });
            if (touched) {
                transaction.set(ref, {
                    period: mid,
                    days,
                    narratedAt: FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        });
        narrated += monthNarrated;
    }
    if (narrated !== signals.length) {
        throw new Error(
            `Forecast changed during narration: wrote ${narrated}/${signals.length} days`,
        );
    }

    // REMEMBER — fold this chapter into a bounded storyline arc.
    await rememberStoryline(userRef, person.storyline, json.storylineUpdate, dashaContext);

    // Cheap gating marker for the enqueue runner (no extra per-user read).
    // Validation guarantees complete, exact coverage, so this marker can never
    // leap over a missing day merely because the model returned one far date.
    await userRef.set({
        forecastNarratedThrough: validation.through,
        forecastNarrateQueuedUntil: FieldValue.delete(),
    }, { merge: true });

    logger.info("narrate: done", { uid, narrated, through: validation.through });
    return { ok: true, narrated };
}

/**
 * REMEMBER: compact the finished chapter into users/{uid}/memory/profile.storyline.
 * Bounded forever (arc = one paragraph, recentBeats capped, threads capped).
 * Uses {merge:true} so it never clobbers rollingSummary / threads / voiceNotes.
 */
async function rememberStoryline(userRef, priorStoryline, update, dashaContext) {
    if (!update) return;
    const prior = priorStoryline || {};
    const period = istToday().toFormat("yyyy-MM");

    const recentBeats = [...(prior.recentBeats || [])];
    if (update.beatGist) {
        recentBeats.push({ period, gist: update.beatGist });
    }
    while (recentBeats.length > RECENT_BEATS_CAP) recentBeats.shift();

    const threads = Array.isArray(update.threads) ?
        update.threads.slice(0, STORYLINE_THREADS_CAP) :
        (prior.threads || []);

    const storyline = {
        arc: update.arc || prior.arc || "",
        currentChapter: {
            dasha: dashaContext?.period || prior.currentChapter?.dasha || "",
            phase: dashaContext?.phase || prior.currentChapter?.phase || "ACTIVE",
            throughline: update.throughline || prior.currentChapter?.throughline || "",
        },
        recentBeats,
        threads,
        updatedAt: FieldValue.serverTimestamp(),
    };

    await userRef.collection("memory").doc("profile").set({ storyline }, { merge: true });
}

/** Enqueue one narrate task onto the shared task queue. */
export async function enqueueNarrateForUser(uid, delaySeconds = 0) {
    const queue = getFunctions().taskQueue(QUEUE_NAME);
    await queue.enqueue(
        { taskType: "process_narrate", uid },
        delaySeconds ? { scheduleDelaySeconds: delaySeconds } : undefined,
    );
}

/**
 * Story runway gate. True when the user's narrated window is missing or about
 * to run out (< NARRATE_MIN_LEAD_DAYS ahead) — i.e. a fresh narration is due.
 * The single source of truth for "does this user need a story?", shared by the
 * nightly batch AND the on-demand ensureForecast so they never disagree.
 * @param {string|null|undefined} narratedThrough  users/{uid}.forecastNarratedThrough (yyyy-MM-dd)
 */
export function narrateRunwayShort(narratedThrough) {
    const leadCutoff = dayKey(istToday().plus({ days: NARRATE_MIN_LEAD_DAYS }));
    return !narratedThrough || narratedThrough < leadCutoff;
}

/**
 * Ensure the user's woven story is fresh: if the runway is short, enqueue a
 * narrate task (fire-and-forget — the wheel picks up the result via its live
 * stream). Idempotent + cost-capped: a no-op when the story already covers the
 * lead window, so it's safe to call on every app open. Returns true iff queued.
 */
export async function ensureNarrateFresh(uid, narratedThrough) {
    if (!narrateRunwayShort(narratedThrough)) return false;
    if (!await claimNarrateEnqueue(uid)) return false;
    try {
        await enqueueNarrateForUser(uid);
        return true;
    } catch (error) {
        await releaseNarrateEnqueue(uid);
        throw error;
    }
}

async function claimNarrateEnqueue(uid) {
    const ref = db.collection("users").doc(uid);
    return db.runTransaction(async (transaction) => {
        const snap = await transaction.get(ref);
        if (!snap.exists || !narrateRunwayShort(snap.data().forecastNarratedThrough)) {
            return false;
        }
        const queuedUntil = snap.data().forecastNarrateQueuedUntil?.toMillis?.() || 0;
        if (queuedUntil > Date.now()) return false;

        transaction.set(ref, {
            forecastNarrateQueuedUntil: new Date(Date.now() + ENQUEUE_LEASE_MS),
        }, { merge: true });
        return true;
    });
}

async function releaseNarrateEnqueue(uid) {
    await db.collection("users").doc(uid).set({
        forecastNarrateQueuedUntil: FieldValue.delete(),
    }, { merge: true });
}

/**
 * Orchestrator runner (Phase 4). Enqueues a narrate task for each active user
 * whose narrated window is running low. One small check per user off the doc
 * snapshot (forecastNarratedThrough) — the heavy Gemini call happens in the
 * Cloud Task, staggered across an hour.
 */
export async function runEnqueueMonthlyNarrate() {
    logger.info("narrate enqueue: starting");

    const activeUids = await getRecentlyActiveUids(NARRATE_ACTIVE_DAYS);
    if (!activeUids.size) {
        logger.info("narrate enqueue: no active users");
        return;
    }

    const usersSnap = await db.collection("users").where("astrologyData", "!=", null).get();
    const candidates = [];
    let scanned = 0;

    usersSnap.forEach((doc) => {
        scanned++;
        if (!activeUids.has(doc.id)) return;
        // Needs narration if never narrated, expired, or the runway is short.
        if (narrateRunwayShort(doc.data().forecastNarratedThrough)) {
            candidates.push(doc.id);
        }
    });

    if (candidates.length > MAX_USERS_PER_RUN) candidates.length = MAX_USERS_PER_RUN;

    const total = candidates.length;
    let enqueued = 0;
    for (let i = 0; i < total; i++) {
        const delaySeconds = total > 0 ? Math.floor((i / total) * ENQUEUE_WINDOW_SECONDS) : 0;
        try {
            if (!await claimNarrateEnqueue(candidates[i])) continue;
            try {
                await enqueueNarrateForUser(candidates[i], delaySeconds);
                enqueued++;
            } catch (error) {
                await releaseNarrateEnqueue(candidates[i]);
                throw error;
            }
        } catch (e) {
            logger.warn("narrate enqueue failed", { uid: candidates[i], error: String(e?.message || e) });
        }
    }

    logger.info("narrate enqueue: complete", { scanned, active: activeUids.size, enqueued });
}
