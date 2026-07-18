/**
 * sense.js — the SENSE layer of the unified forecast.
 *
 * "Numbers are computed, words are narrated." This layer does the computing: for
 * each user + each day in the rolling horizon it runs the pure `computeDaySignal`
 * engine (real Gochara + Ashtakavarga + Vedha + Tara/Chandra Bala + Panchang) and
 * writes the resulting 0-100 alignment + classical signals into the single
 * read-model: `users/{uid}/forecast/{yyyy-MM}`.
 *
 * No AI. No per-user ephemeris fetch (the global sky doc is read once and shared).
 * This alone makes the wheel's headline % REAL — replacing the on-phone
 * `50 + quality×47` placeholder — and, because it drives everything from canonical
 * indices, it structurally eliminates the "Mula/Moola" wrong-person fallback bug.
 *
 * NARRATE (Phase 1) later enriches the same day objects with heading + narrative;
 * this layer merges by date so it never clobbers narrated text.
 */

import { logger } from "firebase-functions/v2";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { computeDaySignal } from "../../lib/vedic_day_signal.js";
import { getRecentlyActiveUids } from "../../lib/auth_utils.js";
import {
    deriveNatalInputs,
    toDayPositions,
    dayMoonNakshatra,
    binduByIndex,
    monthKeyOf,
    horizonDayKeys,
    istToday,
    dayKey,
} from "./forecast_helpers.js";

// Lazy Firestore handle — keeps this module import-safe (no admin dependency at
// import time), so the pure `computeDaySignalsForUser` is unit-testable in
// isolation and cold starts don't pay for a client they may not use.
let _db;
function db() {
    if (!_db) _db = getFirestore();
    return _db;
}

/** Bump when the signal math or stored shape changes (staleness marker). */
export const SIGNAL_VERSION = 1;

/** Rolling window the wheel can scrub. A few days back + ~6 weeks ahead. */
const BACK_DAYS = Number(process.env.FORECAST_BACK_DAYS || 3);
const AHEAD_DAYS = Number(process.env.FORECAST_AHEAD_DAYS || 42);

/** Only recompute for users who opened the app in the last N days. */
const FORECAST_ACTIVE_DAYS = Number(process.env.FORECAST_ACTIVE_DAYS || 7);

/** Bounded parallelism for the batch (pure CPU + a couple Firestore ops each). */
const CONCURRENCY = Number(process.env.FORECAST_CONCURRENCY || 6);

/**
 * The horizon of day-keys the forecast covers on each run: a few days back
 * (so recent past scrubs have data) through several weeks ahead.
 */
export function forecastHorizon() {
    // horizonDayKeys walks forward from today; prepend the back-window.
    const forward = horizonDayKeys(AHEAD_DAYS + 1);
    const start = istToday();
    const back = [];
    for (let i = BACK_DAYS; i >= 1; i--) back.push(dayKey(start.minus({ days: i })));
    return [...back, ...forward];
}

/**
 * Compute day signals for one user over the given day-keys.
 *
 * @param {Object} astro     users/{uid}.astrologyData
 * @param {Object} skyDoc    global_astro/sky_positions data() ({ positions, panchang })
 * @param {string[]} dayKeys yyyy-MM-dd list
 * @returns {Array<{date, alignment, tara, favorable, unfavorable, signals}>}
 */
export function computeDaySignalsForUser(astro, skyDoc, dayKeys) {
    const { moonSignIndex, birthNakshatraIndex, ashtakavarga } = deriveNatalInputs(astro);
    const positions = skyDoc?.positions || {};
    const panchang = skyDoc?.panchang || {};
    const out = [];

    for (const date of dayKeys) {
        const dayPositions = toDayPositions(positions[date]);
        if (!dayPositions) continue; // no sky data for this day — skip

        const result = computeDaySignal({
            moonSignIndex,
            birthNakshatraIndex,
            dayPositions,
            dayMoonNakshatra: dayMoonNakshatra(positions[date], panchang[date]),
            ashtakavarga,
            panchang: panchang[date] || null,
            binduFn: binduByIndex,
        });

        const tara = result.signals.find((s) => s.kind === "taraBala")?.tara || null;
        out.push({
            date,
            alignment: result.alignment,
            tara,
            favorable: result.favorable,
            unfavorable: result.unfavorable,
            signals: result.signals,
        });
    }
    return out;
}

/**
 * Merge freshly-computed day signals into the month docs, preserving any
 * narrated heading/narrative already present. Groups by month and writes each
 * `users/{uid}/forecast/{yyyy-MM}` once.
 */
async function writeUserForecast(uid, computedDays) {
    if (!computedDays.length) return 0;

    const byMonth = new Map();
    for (const day of computedDays) {
        const mk = monthKeyOf(day.date);
        if (!byMonth.has(mk)) byMonth.set(mk, []);
        byMonth.get(mk).push(day);
    }

    let written = 0;
    for (const [period, days] of byMonth) {
        const ref = db().collection("users").doc(uid).collection("forecast").doc(period);
        await db().runTransaction(async (transaction) => {
            const snap = await transaction.get(ref);
            const existing = snap.exists ? (snap.data().days || []) : [];

            // Merge against the transaction's latest snapshot so an overlapping
            // NARRATE write cannot be silently clobbered by stale read-modify-write.
            const merged = new Map(existing.map((d) => [d.date, d]));
            for (const day of days) {
                const prior = merged.get(day.date) || {};
                merged.set(day.date, {
                    ...prior, // preserves heading/narrative from NARRATE
                    date: day.date,
                    alignment: day.alignment,
                    tara: day.tara,
                    favorable: day.favorable,
                    unfavorable: day.unfavorable,
                    signals: day.signals,
                });
            }

            const sorted = [...merged.values()].sort((a, b) => a.date.localeCompare(b.date));
            transaction.set(ref, {
                period,
                days: sorted,
                signalVersion: SIGNAL_VERSION,
                signalsComputedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
        });
        written++;
    }
    return written;
}

/**
 * Compute + persist the forecast signals for a single user. Reusable by the
 * batch runner, the on-demand callable, and (later) the narrate worker.
 *
 * @param {string} uid
 * @param {Object} [opts]
 * @param {Object} [opts.astro]  pre-loaded astrologyData (skips a read)
 * @param {Object} [opts.skyDoc] pre-loaded global sky doc (skips a read)
 * @returns {Promise<{ ok:boolean, days:number, reason?:string }>}
 */
export async function computeForecastForUser(uid, opts = {}) {
    const skyDoc = opts.skyDoc || await loadSkyDoc();
    if (!skyDoc) return { ok: false, days: 0, reason: "no-sky-doc" };

    let astro = opts.astro;
    if (!astro) {
        const userSnap = await db().collection("users").doc(uid).get();
        astro = userSnap.exists ? userSnap.data().astrologyData : null;
    }
    if (!astro) return { ok: false, days: 0, reason: "no-chart" };

    const days = computeDaySignalsForUser(astro, skyDoc, forecastHorizon());
    const written = await writeUserForecast(uid, days);
    return { ok: true, days: days.length, months: written };
}

async function loadSkyDoc() {
    const doc = await db().collection("global_astro").doc("sky_positions").get();
    return doc.exists ? doc.data() : null;
}

/**
 * onCall handler (via astroGateway `computeMyForecast`): ensure BOTH layers of
 * the forecast exist for the current user, on demand.
 *
 *   1. SENSE — recompute the 0-100 day-alignment horizon (pure math, fast).
 *   2. NARRATE — if the woven-story runway is short, enqueue a narrate task
 *      (reuses the exact nightly path; the wheel picks up the result live).
 *
 * This is the single self-healing entry point the app calls on open: numbers
 * appear immediately, the story fills in a moment later. Idempotent and
 * cost-capped (narrate only fires when the story is actually missing/expiring),
 * so it's safe to call every session.
 */
export async function handleComputeMyForecast(request) {
    const uid = request?.auth?.uid;
    if (!uid) return { success: false, reason: "unauthenticated" };

    const res = await computeForecastForUser(uid);
    if (!res.ok) return { success: false, days: 0, reason: res.reason || null };

    // Ensure the story too. Dynamic import keeps the gateway's cold start lean
    // (the Gemini/prompt deps only load when a compute actually happens).
    let narrateQueued = false;
    try {
        const userSnap = await db().collection("users").doc(uid).get();
        const { ensureNarrateFresh } = await import("./narrate.js");
        narrateQueued = await ensureNarrateFresh(uid, userSnap.data()?.forecastNarratedThrough);
    } catch (e) {
        logger.warn("computeMyForecast: narrate ensure failed", { uid, error: String(e?.message || e) });
    }

    return { success: true, days: res.days || 0, narrateQueued };
}

/**
 * Orchestrator runner (Phase 4, after the sky refresh). Recomputes the forecast
 * signals for every recently-active user with a chart. Pure CPU — no AI, no
 * per-user network. Bounded concurrency keeps the orchestrator wall-time tight.
 */
export async function runComputeDaySignals() {
    logger.info("computeDaySignals: starting");

    const skyDoc = await loadSkyDoc();
    if (!skyDoc) {
        logger.warn("computeDaySignals: no global sky doc; aborting");
        return;
    }

    const activeUids = [...await getRecentlyActiveUids(FORECAST_ACTIVE_DAYS)];
    if (!activeUids.length) {
        logger.info("computeDaySignals: no active users");
        return;
    }

    let processed = 0;
    let skipped = 0;
    let errors = 0;

    // Process in bounded-concurrency chunks.
    for (let i = 0; i < activeUids.length; i += CONCURRENCY) {
        const chunk = activeUids.slice(i, i + CONCURRENCY);
        const settled = await Promise.allSettled(
            chunk.map((uid) => computeForecastForUser(uid, { skyDoc })),
        );
        for (const r of settled) {
            if (r.status === "rejected") errors++;
            else if (r.value.ok) processed++;
            else skipped++;
        }
    }

    logger.info("computeDaySignals: done", {
        active: activeUids.length, processed, skipped, errors,
    });
}
