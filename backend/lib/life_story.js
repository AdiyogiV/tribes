/**
 * Life Story spine — the top layer of the top-down astrology engine.
 *
 * Turns the (already-stored) Vimshottari dasha tree into a coherent, dated,
 * plain-English life story: which multi-year chapter you're in, what's next,
 * and a one-line "context" headline that grounds every daily reading.
 *
 * This is PURE + DETERMINISTIC: no AI, no network, no Firestore. Give it the
 * `astrologyData` you already store and it returns the story. Slow-transit
 * milestones (Saturn/Jupiter) are added only when live `skyPositions` are
 * passed in, so the core stays trivially testable.
 *
 * Why this exists: the wheel currently shows a 1-of-9 template for any day that
 * isn't today. That's fake. Real, coherent daily readings must inherit from a
 * shared multi-year frame — this file builds that frame.
 */

import { resolveActiveDasha } from "./astro_helpers.js";

// Plain-English life-theme for each dasha lord (graha). Deliberately jargon-free
// — this is what a user reads, not "Vimshottari Mahadasha of Shani."
const DASHA_THEMES = {
    Sun: { label: "recognition", line: "stepping into visibility, authority, and doing work that gets seen" },
    Moon: { label: "emotional life", line: "home, feelings, and inner comfort take the lead" },
    Mars: { label: "drive", line: "energy, courage, and pushing hard toward what you want" },
    Mercury: { label: "learning", line: "communication, skills, business, and quick thinking flourish" },
    Jupiter: { label: "growth", line: "expansion, luck, wisdom, and building something bigger" },
    Venus: { label: "relationships", line: "love, comfort, beauty, and the good things in life" },
    Saturn: { label: "the long build", line: "patience, discipline, and slow, earned rewards — no shortcuts" },
    Rahu: { label: "ambition", line: "hunger for more, bold risks, and unconventional paths" },
    Ketu: { label: "letting go", line: "turning inward, releasing what's done, and spiritual depth" },
};

// Accept common spelling variants so we never render "undefined theme".
const LORD_ALIASES = {
    Ra: "Rahu", Ke: "Ketu", Su: "Sun", Mo: "Moon", Ma: "Mars",
    Me: "Mercury", Ju: "Jupiter", Ve: "Venus", Sa: "Saturn",
    Rahu: "Rahu", Ketu: "Ketu", Sun: "Sun", Moon: "Moon", Mars: "Mars",
    Mercury: "Mercury", Jupiter: "Jupiter", Venus: "Venus", Saturn: "Saturn",
};

function themeFor(lord) {
    const key = LORD_ALIASES[lord] || lord;
    return DASHA_THEMES[key] || { label: "a new phase", line: "a shift in life's focus" };
}

const MS_PER_DAY = 86400000;

/** "Mar 2026" style short month-year. */
function monthYear(dateish) {
    const d = new Date(dateish);
    if (isNaN(d)) return "";
    return d.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
}

/** Human "when" label relative to now: "now", "in 4 months", "in 2 years". */
function relativeWhen(dateish, now) {
    const d = new Date(dateish);
    if (isNaN(d)) return "";
    const days = Math.round((d - now) / MS_PER_DAY);
    if (days <= 0) return "now";
    if (days < 45) return `in ${Math.max(1, Math.round(days / 7))} weeks`;
    const months = Math.round(days / 30);
    if (months < 18) return `in ${months} months`;
    return `in ${Math.round(months / 12)} years`;
}

/** Years-and-months duration label, e.g. "6 yr" or "8 mo". */
function durationLabel(startish, endish) {
    const start = new Date(startish);
    const end = new Date(endish);
    if (isNaN(start) || isNaN(end)) return "";
    const months = Math.round((end - start) / MS_PER_DAY / 30);
    if (months < 18) return `${months} mo`;
    return `${(months / 12).toFixed(months % 12 === 0 ? 0 : 1)} yr`;
}

/** Build one chapter object for the timeline. */
function chapter(level, node, now, active) {
    const t = themeFor(node.lord);
    return {
        level, // "maha" | "antar"
        lord: LORD_ALIASES[node.lord] || node.lord,
        theme: t.label,
        meaning: t.line,
        startDate: node.startDate,
        endDate: node.endDate,
        span: `${monthYear(node.startDate)} – ${monthYear(node.endDate)}`,
        duration: durationLabel(node.startDate, node.endDate),
        when: active ? "now" : relativeWhen(node.startDate, now),
        active,
    };
}

/**
 * Build the life story from stored astrology data.
 *
 * @param {Object} astroData - the user's stored astrologyData (needs currentDasha.tree)
 * @param {Object} [opts]
 * @param {Date}   [opts.now]        - reference instant (defaults to now)
 * @returns {{ ok: boolean, headline: string, current: Object, timeline: Object[] } | { ok: false, reason: string }}
 */
export function buildLifeStory(astroData, { now = new Date() } = {}) {
    const tree = astroData?.currentDasha?.tree;
    if (!Array.isArray(tree) || tree.length === 0) {
        return { ok: false, reason: "no dasha tree stored", headline: "", current: null, timeline: [] };
    }

    // Find the active maha + antar.
    const within = (n) => {
        const s = new Date(n.startDate);
        const e = new Date(n.endDate);
        return !isNaN(s) && !isNaN(e) && s <= now && now < e;
    };
    const activeMaha = tree.find(within);
    if (!activeMaha) {
        return { ok: false, reason: "now is outside the computed dasha range", headline: "", current: null, timeline: [] };
    }
    const antars = activeMaha.children || [];
    const activeAntar = antars.find(within) || null;

    // ── Build the timeline: current maha, current + upcoming antars, next maha ──
    const timeline = [];
    timeline.push(chapter("maha", activeMaha, now, true));

    // Current antar + the next couple of sub-periods (the near-term texture).
    const activeAntarIdx = activeAntar ? antars.indexOf(activeAntar) : -1;
    if (activeAntarIdx >= 0) {
        const upcoming = antars.slice(activeAntarIdx, activeAntarIdx + 3);
        upcoming.forEach((a, i) => timeline.push(chapter("antar", a, now, i === 0)));
    }

    // The next major chapter (what life turns toward after this maha).
    const nextMahaIdx = tree.indexOf(activeMaha) + 1;
    if (nextMahaIdx < tree.length) {
        timeline.push(chapter("maha", tree[nextMahaIdx], now, false));
    }

    // ── Headline: the one-line context that grounds every daily reading ──
    const mahaT = themeFor(activeMaha.lord);
    let headline = `${LORD_ALIASES[activeMaha.lord] || activeMaha.lord} years — ${mahaT.line}.`;
    if (activeAntar) {
        const antarT = themeFor(activeAntar.lord);
        headline = `${LORD_ALIASES[activeMaha.lord] || activeMaha.lord} years, ` +
            `${LORD_ALIASES[activeAntar.lord] || activeAntar.lord} season — ` +
            `${mahaT.label} overall, with ${antarT.label} in focus right now.`;
    }

    return {
        ok: true,
        headline,
        current: {
            maha: chapter("maha", activeMaha, now, true),
            antar: activeAntar ? chapter("antar", activeAntar, now, true) : null,
        },
        timeline,
    };
}
