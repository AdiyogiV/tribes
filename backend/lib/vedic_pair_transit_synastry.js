/**
 * vedic_pair_transit_synastry.js — the pure, deterministic "cosmic weather for
 * the two of you TODAY", computed from BOTH people's full natal charts and the
 * day's transiting sky.
 *
 * This engine uses the complete natal charts we actually store
 * (`astrologyData.birthChartData.output` — fullDegree for all 9 grahas + the
 * Ascendant, per user) and asks the genuinely relational question:
 *
 *   "How do TODAY's transiting planets aspect each person's relationship
 *    karakas — their Moon (emotion), Venus (love), Lagna (self) and 7th house
 *    (partnership) — and where do those activations OVERLAP for the two of you?"
 *
 * Aspects are classical Vedic Graha Drishti (house/sign based, NOT degree orbs):
 *   - every planet aspects the 7th from itself (full)         (BPHS)
 *   - Mars also aspects the 4th & 8th                          (BPHS special)
 *   - Jupiter also aspects the 5th & 9th                       (BPHS special)
 *   - Saturn also aspects the 3rd & 10th                       (BPHS special)
 *   - a planet transiting the SAME sign = conjunction/association (activation)
 *   - Rahu/Ketu: conjunction + 7th only (special aspects debated; kept minimal)
 *
 * Benefics (Jupiter, Venus, Mercury, Moon) lift a karaka they touch; malefics
 * (Sun, Mars, Saturn, Rahu, Ketu) test it. When the SAME transit touches the
 * SAME karaka type in BOTH charts, that's a shared activation (bonus/penalty).
 *
 * HONESTY NOTE: the classifications (benefic/malefic, which drishti, which
 * karaka) are 100% classical. The magnitudes in MAG below are a modern
 * synthesis (clearly labelled) needed only to collapse the picture into one
 * 0-100 number. Every signal is returned so the score is always auditable.
 */

const TRACKED = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];

const BENEFIC = new Set(["Jupiter", "Venus", "Mercury", "Moon"]);
// (malefic = everything tracked that isn't benefic)

// Special Graha Drishti houses (beyond the universal 7th) counted FROM the
// aspecting planet's sign. Conjunction (1) + 7th are added for everyone below.
const SPECIAL_ASPECTS = { Mars: [4, 8], Jupiter: [5, 9], Saturn: [3, 10] };

// Relationship karakas we watch, with relative weight (modern synthesis).
const KARAKAS = [
    { key: "Moon", weight: 1.0, label: "Moon" }, // emotional core
    { key: "Venus", weight: 1.0, label: "Venus" }, // love karaka
    { key: "seventh", weight: 0.8, label: "7th house" }, // partnership
    { key: "Ascendant", weight: 0.6, label: "self" }, // identity
];

// ── Aggregation magnitudes (MODERN SYNTHESIS — tunable, not shastra) ─────────
const MAG = {
    base: 50, // neutral midpoint
    aspect: 3, // per transit→karaka activation (× karaka weight × ±)
    mutual: 4, // same transit hits the SAME karaka type in BOTH charts (shared)
    bridge: 3, // same transit hits DIFFERENT karakas across the two charts
};

const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
const round1 = (n) => Math.round(n * 10) / 10;
const signOf = (lon) => Math.floor(((lon % 360) + 360) % 360 / 30); // 0-11

function canonPlanet(name) {
    if (!name) return null;
    return TRACKED.find((k) => String(name).toLowerCase().includes(k.toLowerCase())) || null;
}

const degOf = (d) => (d == null ? null : (d.fullDegree ?? d.longitude ?? d.full_degree ?? d.degree ?? null));

/**
 * Normalize a chart map ({Planet:{fullDegree|longitude,...}} or {name,...}) into
 * `{ Sun: signIndex, ..., Ascendant: signIndex, seventh: signIndex }`.
 * Returns null if we can't find at least an Ascendant or Moon (nothing to judge).
 */
export function chartSigns(output) {
    if (!output || typeof output !== "object") return null;
    const src = Array.isArray(output) ? (output[0] || {}) : output;
    const out = {};
    for (const [key, data] of Object.entries(src)) {
        if (!data || typeof data !== "object") continue;
        const deg = degOf(data);
        if (deg == null) continue;
        // Ascendant / Lagna
        if (/ascend|lagna/i.test(key) || /ascend|lagna/i.test(data.name || "")) {
            out.Ascendant = signOf(deg);
            continue;
        }
        const planet = canonPlanet(data.name || key);
        if (planet) out[planet] = signOf(deg);
    }
    if (out.Ascendant != null) out.seventh = (out.Ascendant + 6) % 12;
    if (out.Moon == null && out.Ascendant == null) return null;
    return out;
}

/** The set of house-distances (from a planet's sign) at which it casts drishti. */
function aspectHousesFor(planet) {
    const set = new Set([1, 7]); // conjunction + universal 7th
    for (const h of SPECIAL_ASPECTS[planet] || []) set.add(h);
    return set;
}

/** House distance (1-12) from sign a to sign b. 1 = same sign (conjunction). */
const houseDist = (a, b) => ((b - a + 12) % 12) + 1;

/**
 * Score how today's transits activate one person's relationship karakas.
 * @returns {{delta:number, hits:Array<{planet,karaka,benefic,delta}>}}
 */
function scorePerson(transitSigns, natal) {
    let delta = 0;
    const hits = [];
    for (const planet of TRACKED) {
        const ts = transitSigns[planet];
        if (ts == null) continue;
        const houses = aspectHousesFor(planet);
        const benefic = BENEFIC.has(planet);
        for (const k of KARAKAS) {
            const gs = natal[k.key];
            if (gs == null) continue;
            if (!houses.has(houseDist(ts, gs))) continue;
            const d = MAG.aspect * k.weight * (benefic ? 1 : -1);
            delta += d;
            hits.push({ planet, karaka: k.label, karakaKey: k.key, benefic, delta: round1(d) });
        }
    }
    return { delta, hits };
}

/**
 * Compute the pair's transit synastry-of-the-day from full natal charts.
 *
 * @param {Object} args
 * @param {Object} args.natalA   user A's birthChartData.output (or already-signed map)
 * @param {Object} args.natalB   user B's birthChartData.output
 * @param {Object} args.transit  today's sky positions map ({Planet:{longitude}})
 * @returns {{score:(number|null), label:string, favorable:string[],
 *            unfavorable:string[], signals:Object[]}}
 */
export function computePairTransitSynastry({ natalA, natalB, transit } = {}) {
    const a = chartSigns(natalA);
    const b = chartSigns(natalB);
    const t = chartSigns(transit);
    if (!a || !b || !t) {
        return { score: null, label: "Unknown", favorable: [], unfavorable: [], signals: [] };
    }

    let score = MAG.base;

    const sa = scorePerson(t, a);
    const sb = scorePerson(t, b);
    score += sa.delta + sb.delta;

    // ── CONNECTION: signals that touch BOTH charts (the actual "between you") ──
    // A transiting planet that aspects a karaka in A AND a karaka in B is a
    // thread between the two of you. Same karaka on both sides = a "shared"
    // resonance; different karakas = a "bridge" linking your two points.
    const byPlanetA = groupByPlanet(sa.hits);
    const byPlanetB = groupByPlanet(sb.hits);
    const connection = [];
    for (const planet of TRACKED) {
        const hitsA = byPlanetA[planet];
        const hitsB = byPlanetB[planet];
        if (!hitsA || !hitsB) continue; // needs to touch BOTH charts
        const benefic = hitsA[0].benefic;

        // Prefer a shared karaka (same point lit in both) → strongest bond.
        const shared = hitsA.find((h) => hitsB.some((g) => g.karakaKey === h.karakaKey));
        if (shared) {
            const d = benefic ? MAG.mutual : -MAG.mutual;
            score += d;
            connection.push({
                planet, kind: "shared", karaka: shared.karaka, karakaKey: shared.karakaKey,
                benefic, delta: round1(d),
            });
        } else {
            // A bridge: your strongest point ↔ their strongest point.
            const hA = hitsA[0];
            const hB = hitsB[0];
            const d = benefic ? MAG.bridge : -MAG.bridge;
            score += d;
            connection.push({
                planet, kind: "bridge", benefic, delta: round1(d),
                karakaA: hA.karaka, karakaKeyA: hA.karakaKey,
                karakaB: hB.karaka, karakaKeyB: hB.karakaKey,
            });
        }
    }

    const finalScore = Math.round(clamp(score, 0, 100));
    connection.sort((x, y) => Math.abs(y.delta) - Math.abs(x.delta));

    // Each person's PERSONAL transit hits (their own day, not the bond). These
    // belong on each one's energy card, not the connection card.
    const personalA = sa.hits.map((h) => ({ planet: h.planet, karaka: h.karaka, benefic: h.benefic }));
    const personalB = sb.hits.map((h) => ({ planet: h.planet, karaka: h.karaka, benefic: h.benefic }));

    return {
        score: finalScore,
        label: labelFor(finalScore),
        connection, // shared + bridge signals — the "between you" story
        personalA, // current user's own transit hits
        personalB, // friend's own transit hits
    };
}

/** Group a person's hits by transiting planet, strongest-karaka first. */
function groupByPlanet(hits) {
    const m = {};
    for (const h of [...hits].sort((x, y) => Math.abs(y.delta) - Math.abs(x.delta))) {
        (m[h.planet] ||= []).push(h);
    }
    return m;
}

/** Bands for the pair score → a short, warm relational label. */
export function labelFor(score) {
    if (score == null) return "Unknown";
    if (score >= 80) return "In Flow";
    if (score >= 65) return "Aligned";
    if (score >= 50) return "Steady";
    if (score >= 35) return "Offset";
    return "Lay Low";
}
