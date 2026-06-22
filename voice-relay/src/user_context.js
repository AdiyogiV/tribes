/**
 * Per-user astrology context for the voice brain.
 *
 * The text chat (backend/functions/ai.js `fetchUserContext`) hands Gemini the
 * full chart JSON. A spoken reply is under 80 words, so Aryabhatt needs far
 * less: who he's talking to, the core placements, the active dasha, and today's
 * insight. We fetch a LEAN summary from the same Firestore docs and phrase it
 * as a short briefing the playbook can use silently.
 *
 * Returns a plain string (the briefing) or "" when there's nothing useful —
 * a guest, a chart-less user, or a transient read error. Best-effort: a failed
 * lookup must never break the call.
 */

import admin from "firebase-admin";

/** Today's date key in IST (matches how dailyInsights docs are keyed). */
function istDateKey() {
    // en-CA gives YYYY-MM-DD; force the Asia/Kolkata zone with no extra deps.
    return new Intl.DateTimeFormat("en-CA", {
        timeZone: "Asia/Kolkata",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    }).format(new Date());
}

/** Pull a readable mahadasha/antardasha label out of the stored dasha shape. */
function dashaLabel(dasha) {
    if (!dasha) return null;
    if (typeof dasha === "string") return dasha;
    const maha = dasha.mahadasha || dasha.maha || dasha.mahaLord || dasha.lord;
    const antar = dasha.antardasha || dasha.antar || dasha.antarLord;
    if (maha && antar) return `${maha} mahadasha, ${antar} antardasha`;
    return maha || antar || null;
}

/**
 * Build a compact spoken-context briefing for a uid.
 * @param {string} uid Firebase user id (verified by the caller).
 * @returns {Promise<string>} briefing text, or "" if none.
 */
export async function buildUserContext(uid) {
    if (!uid || uid === "anon-dev" || uid === "dev-bypass") return "";

    let userSnap;
    let insightSnap;
    try {
        const db = admin.firestore();
        const today = istDateKey();
        [userSnap, insightSnap] = await Promise.all([
            db.doc(`users/${uid}`).get(),
            db.doc(`users/${uid}/dailyInsights/${today}`).get(),
        ]);
    } catch {
        return ""; // Firestore hiccup — Aryabhatt still works, just generic.
    }

    if (!userSnap.exists) return "";
    const user = userSnap.data() || {};
    const astro = user.astrologyData || null;
    if (!astro) return ""; // no chart on file → nothing personal to add

    const name = user.nickname || user.displayName || user.name || null;

    // Core placements — only include what's actually present.
    const facts = [];
    if (astro.sunSign) facts.push(`Sun in ${astro.sunSign}`);
    if (astro.moonSign) facts.push(`Moon in ${astro.moonSign}`);
    if (astro.ascendant) facts.push(`${astro.ascendant} ascendant`);
    if (astro.nakshatra) facts.push(`${astro.nakshatra} nakshatra`);
    const dasha = dashaLabel(astro.currentDasha);
    if (dasha) facts.push(`running ${dasha}`);

    // Today's pre-generated insight gives him "right now" awareness.
    let todayLine = "";
    if (insightSnap?.exists) {
        const insight = insightSnap.data() || {};
        const weather = insight.astroContext?.cosmicWeather
            || insight.displayMessage
            || insight.displayTheme;
        if (weather) {
            todayLine = ` Today for them: ${String(weather).slice(0, 240)}`;
        }
    }

    if (!facts.length && !todayLine) return "";

    const who = name ? `You are speaking with ${name}.` : "About this person:";
    return `${who} Their chart: ${facts.join(", ")}.${todayLine}`.trim();
}
