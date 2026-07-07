/**
 * Vedic day-signal — the pure, deterministic per-day alignment calculator.
 *
 * This is the foundation of the "real wheel": given a user's natal chart and a
 * single day's planetary positions + panchang, it returns a 0-100 ALIGNMENT
 * plus the exact classical signals that produced it. No AI, no network, no
 * invented astrology — every signal traces to a named Jyotish rule:
 *
 *   - Gochara (transit from natal Moon)        — BPHS favorable-house tables
 *   - ...gated by Ashtakavarga bindus (0-8)     — real strength number
 *   - ...cancelled by Vedha (obstruction)       — BPHS Gochara Vedha
 *   - Tara Bala (birth nak -> day Moon nak)     — the 9 Taras
 *   - Chandra Bala (Moon house from natal Moon) — lunar strength
 *   - Panchang quality (tithi / yoga)           — day texture
 *
 * HONESTY NOTE: the CLASSIFICATIONS (favorable/unfavorable, tara type, bindu
 * count) are 100% classical. Collapsing them into a single 0-100 number needs
 * *some* normalization — those magnitudes live in AGG below, clearly labelled
 * as a modern synthesis, NOT shastra magnitudes. Every raw signal is returned
 * so the number is always auditable.
 *
 * NOTE: GOCHARA_FAVORABLE is duplicated in functions/per_house.js. This module
 * is the canonical pure source; per_house should import from here later (it
 * currently can't without pulling in Firestore side-effects).
 */

// ── Classical constants ─────────────────────────────────────────────────────

// Houses (counted FROM NATAL MOON) where each planet gives good results. (BPHS)
export const GOCHARA_FAVORABLE = {
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

// Vedha (obstruction) house for each FAVORABLE house, counted from Moon. If the
// vedha house is occupied by another planet, the good result is nullified.
// (BPHS Gochara Vedha; index-aligned with GOCHARA_FAVORABLE above.)
export const GOCHARA_VEDHA = {
    Sun: { 3: 9, 6: 12, 10: 4, 11: 5 },
    Moon: { 1: 5, 3: 9, 6: 12, 7: 2, 10: 4, 11: 8 },
    Mars: { 3: 12, 6: 9, 11: 5 },
    Mercury: { 2: 5, 4: 3, 6: 9, 8: 1, 10: 8, 11: 12 },
    Jupiter: { 2: 12, 5: 4, 7: 3, 9: 10, 11: 8 },
    Venus: { 1: 8, 2: 7, 3: 1, 4: 10, 5: 9, 8: 5, 9: 11, 11: 3, 12: 6 },
    Saturn: { 3: 12, 6: 9, 11: 5 },
    Rahu: {}, Ketu: {}, // nodes: no classical vedha
};

// Vedha exceptions: these pairs never obstruct each other. (Classical.)
const VEDHA_EXEMPT = { Sun: "Saturn", Saturn: "Sun", Moon: "Mercury", Mercury: "Moon" };

// The 9 Taras (from birth nakshatra to the day's Moon nakshatra) and their
// classical favorability. (+1 good, -1 bad, 0 mixed.)
const TARA_NAMES = ["Janma", "Sampat", "Vipat", "Kshema", "Pratyari", "Sadhaka", "Vadha", "Mitra", "AtiMitra"];
const TARA_FAVOR = { Janma: 0, Sampat: 1, Vipat: -1, Kshema: 1, Pratyari: -1, Sadhaka: 1, Vadha: -1, Mitra: 1, AtiMitra: 1 };

// Rikta tithis (4,9,14) are inauspicious; Purna (5,10,15) & Nanda-Jaya are good.
const RIKTA_TITHIS = new Set([4, 9, 14]);
const PURNA_TITHIS = new Set([5, 10, 15]);

// Inauspicious yogas (of the 27). (Classical.)
const BAD_YOGAS = new Set([
    "Vishkumbha", "Atiganda", "Shula", "Ganda", "Vyaghata", "Vajra", "Vyatipata", "Parigha", "Vaidhriti",
]);

// ── Aggregation magnitudes (MODERN SYNTHESIS — tunable, not shastra) ─────────
const AGG = {
    base: 50, // neutral midpoint
    gocharaFavorable: 4, // per favorable transit...
    gocharaUnfavorable: -4, // ...or unfavorable
    binduScale: 0.6, // how much bindu strength (0-8) amplifies a transit
    tara: 6, // Tara Bala swing
    chandraBala: 5, // Moon-from-Moon swing
    tithiRikta: -4, tithiPurna: 3,
    badYoga: -3,
};

const PLANET_KEYS = Object.keys(GOCHARA_FAVORABLE);

function canonPlanet(name) {
    if (!name) return null;
    return PLANET_KEYS.find((k) => name.toLowerCase().includes(k.toLowerCase())) || null;
}

const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

/**
 * Compute one day's alignment from classical Vedic signals.
 *
 * @param {Object}  args
 * @param {number}  args.moonSignIndex        - natal Moon sign index (0-11)
 * @param {number}  args.birthNakshatraIndex  - natal Moon nakshatra (0-26)
 * @param {Object}  args.dayPositions         - {Planet: {fullDegree, ...}} for the day
 * @param {number}  [args.dayMoonNakshatra]   - the day's Moon nakshatra (0-26); derived from positions if absent
 * @param {Object}  [args.ashtakavarga]       - natal ashtakavarga (for bindu gating)
 * @param {Object}  [args.panchang]           - { tithiNumber, yoga } for the day
 * @param {Function}[args.binduFn]            - (planet, signIdx, av) => 0-8 (inject to avoid import cycle)
 * @returns {{ alignment:number, favorable:string[], unfavorable:string[], signals:Object[] }}
 */
export function computeDaySignal({
    moonSignIndex,
    birthNakshatraIndex,
    dayPositions,
    dayMoonNakshatra,
    ashtakavarga = null,
    panchang = null,
    binduFn = null,
} = {}) {
    const signals = [];
    let score = AGG.base;

    // Where is each planet, by sign index (from Moon).
    const occupiedFromMoon = {}; // house-from-moon -> [planet]
    const placed = [];
    for (const [rawName, data] of Object.entries(dayPositions || {})) {
        if (!data || rawName === "Ascendant") continue;
        const deg = data.fullDegree ?? data.full_degree ?? data.degree;
        if (deg == null) continue;
        const planet = canonPlanet(rawName);
        if (!planet) continue;
        const signIdx = Math.floor(deg / 30) % 12;
        const houseFromMoon = moonSignIndex != null ? ((signIdx - moonSignIndex + 12) % 12) + 1 : null;
        placed.push({ planet, signIdx, houseFromMoon });
        if (houseFromMoon != null) (occupiedFromMoon[houseFromMoon] ||= []).push(planet);
    }

    // 1) Gochara (from Moon), gated by bindu, cancelled by Vedha.
    //    Moon is handled separately as Chandra Bala (its gochara-from-Moon IS
    //    Chandra Bala) to avoid double-counting the same placement.
    for (const { planet, signIdx, houseFromMoon } of placed) {
        if (houseFromMoon == null || planet === "Moon") continue;
        const favorable = GOCHARA_FAVORABLE[planet].includes(houseFromMoon);

        // Vedha check (only nullifies FAVORABLE results here).
        let obstructed = false;
        if (favorable) {
            const vedhaHouse = GOCHARA_VEDHA[planet]?.[houseFromMoon];
            if (vedhaHouse && occupiedFromMoon[vedhaHouse]) {
                const blockers = occupiedFromMoon[vedhaHouse].filter((b) => VEDHA_EXEMPT[planet] !== b && b !== planet);
                obstructed = blockers.length > 0;
            }
        }

        // Bindu strength (0-8) amplifies magnitude when available.
        let bindu = null;
        if (binduFn && ashtakavarga) bindu = binduFn(planet, signIdx, ashtakavarga);
        const amp = bindu != null ? 1 + (bindu - 4) * AGG.binduScale / 4 : 1;

        let delta = 0;
        let verdict;
        if (favorable && !obstructed) { delta = AGG.gocharaFavorable * amp; verdict = "favorable"; }
        else if (favorable && obstructed) { delta = 0; verdict = "favorable-but-obstructed (Vedha)"; }
        else { delta = AGG.gocharaUnfavorable * amp; verdict = "unfavorable"; }

        score += delta;
        signals.push({ kind: "gochara", planet, houseFromMoon, bindu, verdict, delta: Math.round(delta * 10) / 10 });
    }

    // 2) Tara Bala (birth nakshatra -> day Moon nakshatra).
    let moonNak = dayMoonNakshatra;
    if (moonNak == null) {
        const mp = placed.find((p) => p.planet === "Moon");
        if (mp != null) moonNak = Math.floor((mp.signIdx * 30) / (360 / 27)); // coarse; prefer explicit
    }
    if (moonNak != null && birthNakshatraIndex != null) {
        const taraIdx = (((moonNak - birthNakshatraIndex) % 9) + 9) % 9;
        const taraName = TARA_NAMES[taraIdx];
        const favor = TARA_FAVOR[taraName];
        const delta = favor * AGG.tara;
        score += delta;
        signals.push({ kind: "taraBala", tara: taraName, favor, delta });
    }

    // 3) Chandra Bala (Moon's house from natal Moon).
    const mp = placed.find((p) => p.planet === "Moon");
    if (mp?.houseFromMoon != null) {
        const good = GOCHARA_FAVORABLE.Moon.includes(mp.houseFromMoon);
        const delta = good ? AGG.chandraBala : -AGG.chandraBala;
        score += delta;
        signals.push({ kind: "chandraBala", houseFromMoon: mp.houseFromMoon, good, delta });
    }

    // 4) Panchang quality (tithi + yoga).
    if (panchang) {
        const t = panchang.tithiNumber ?? panchang.tithi_number;
        if (t != null) {
            const tn = ((t - 1) % 15) + 1; // fold to 1-15
            if (RIKTA_TITHIS.has(tn)) { score += AGG.tithiRikta; signals.push({ kind: "tithi", tithi: tn, quality: "Rikta", delta: AGG.tithiRikta }); }
            else if (PURNA_TITHIS.has(tn)) { score += AGG.tithiPurna; signals.push({ kind: "tithi", tithi: tn, quality: "Purna", delta: AGG.tithiPurna }); }
        }
        const yoga = (panchang.yoga || "").split(" ")[0];
        if (yoga && BAD_YOGAS.has(yoga)) { score += AGG.badYoga; signals.push({ kind: "yoga", yoga, quality: "inauspicious", delta: AGG.badYoga }); }
    }

    // ── Collapse ──
    const alignment = Math.round(clamp(score, 0, 100));
    const favorable = signals.filter((s) => s.delta > 0).sort((a, b) => b.delta - a.delta);
    const unfavorable = signals.filter((s) => s.delta < 0).sort((a, b) => a.delta - b.delta);

    return {
        alignment,
        favorable: favorable.slice(0, 3).map(describe),
        unfavorable: unfavorable.slice(0, 3).map(describe),
        signals,
    };
}

const ordinal = (n) => {
    const s = ["th", "st", "nd", "rd"], v = n % 100;
    return n + (s[(v - 20) % 10] || s[v] || s[0]);
};

function describe(s) {
    switch (s.kind) {
        case "gochara": return `${s.planet} ${ordinal(s.houseFromMoon)} from Moon (${s.verdict}${s.bindu != null ? `, ${s.bindu} bindu` : ""})`;
        case "taraBala": return `${s.tara} Tara`;
        case "chandraBala": return `Moon ${ordinal(s.houseFromMoon)} from natal Moon`;
        case "tithi": return `${s.quality} tithi`;
        case "yoga": return `${s.yoga} yoga`;
        default: return s.kind;
    }
}
