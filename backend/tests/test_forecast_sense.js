/**
 * Unit test for the forecast SENSE layer (pure compute — no Firestore).
 * Run: node tests/test_forecast_sense.js
 *
 * Verifies:
 *   1. The two impedance-mismatch fixes work:
 *        (a) sky-doc `longitude` is mapped to `fullDegree` for the engine.
 *        (b) the bindu adapter converts sign-INDEX → sign-NAME so Ashtakavarga
 *            bindus actually amplify (the old direct-index path silently no-ops).
 *   2. computeDaySignalsForUser produces 0-100 alignments that vary day to day
 *      and carry auditable classical signals.
 */

import assert from "node:assert";
import {
    signIndexToName,
    signNameToIndex,
    toDayPositions,
    binduByIndex,
    deriveNatalInputs,
} from "../functions/forecast/forecast_helpers.js";
import { computeDaySignalsForUser } from "../functions/forecast/sense.js";

let pass = 0;
const ok = (cond, msg) => {
    assert.ok(cond, msg);
    console.log(`  ✓ ${msg}`);
    pass++;
};

console.log("\n=== forecast SENSE unit test ===\n");

// ── Helper correctness ──────────────────────────────────────────────────────
console.log("helpers:");
ok(signIndexToName(0) === "Aries" && signIndexToName(7) === "Scorpio", "signIndexToName maps 0→Aries, 7→Scorpio");
ok(signNameToIndex("Scorpio") === 7, "signNameToIndex Scorpio→7");

// gotcha #1: longitude → fullDegree
const mapped = toDayPositions({ Jupiter: { longitude: 215.5, sign: "Scorpio" } });
ok(mapped.Jupiter.fullDegree === 215.5, "toDayPositions maps longitude→fullDegree");

// gotcha #2: bindu adapter uses sign NAME under the hood
const fakeAV = {
    bav: {
        Jupiter: {
            Aries: 1, Taurus: 2, Gemini: 3, Cancer: 4, Leo: 5, Virgo: 6,
            Libra: 7, Scorpio: 6, Sagittarius: 5, Capricorn: 4, Aquarius: 3, Pisces: 2,
        },
    },
    sav: {},
};
const binduScorpio = binduByIndex("Jupiter", 7, fakeAV); // index 7 = Scorpio
ok(binduScorpio === 6, "binduByIndex(Jupiter, 7=Scorpio) returns 6 (index→name adapter works)");
ok(binduByIndex("Jupiter", 99, fakeAV) === null, "binduByIndex returns null for out-of-range index");

// ── Natal derivation ────────────────────────────────────────────────────────
const astro = {
    moonSign: "Taurus",
    moonNakshatra: "Rohini", // idx 3
    ascendant: "Aries",
    ashtakavarga: fakeAV,
};
const natal = deriveNatalInputs(astro);
ok(natal.moonSignIndex === 1, "deriveNatalInputs moonSignIndex Taurus→1");
ok(natal.birthNakshatraIndex === 3, "deriveNatalInputs birthNakshatraIndex Rohini→3");

// ── Full per-user day compute ────────────────────────────────────────────────
// Two synthetic days; positions use `longitude` (as the real sky doc does).
const at = (signIdx) => signIdx * 30 + 15;
const skyDoc = {
    positions: {
        // 3rd from Taurus Moon; Jupiter 7th from Moon (favorable) + 6 bindu.
        "2026-07-20": {
            Moon: { longitude: at(3), sign: "Cancer" },
            Jupiter: { longitude: at(7), sign: "Scorpio" },
            Saturn: { longitude: at(9), sign: "Capricorn" },
            Sun: { longitude: at(3), sign: "Cancer" },
        },
        // Moon 12th from Taurus Moon (unfavorable).
        "2026-07-21": {
            Moon: { longitude: at(0), sign: "Aries" },
            Mars: { longitude: at(0), sign: "Aries" },
            Saturn: { longitude: at(6), sign: "Libra" },
        },
    },
    panchang: {
        "2026-07-20": { tithi_number: 5, yoga: "Siddhi", nakshatra: "Pushya" },
        "2026-07-21": { tithi_number: 4, yoga: "Vishkumbha", nakshatra: "Ashlesha" },
    },
};

const days = computeDaySignalsForUser(astro, skyDoc, ["2026-07-20", "2026-07-21"]);
console.log("\ncompute:");
ok(days.length === 2, "produced a signal for each of the 2 days");
for (const d of days) {
    ok(d.alignment >= 0 && d.alignment <= 100, `day ${d.date} alignment ${d.alignment} is within 0-100`);
    ok(Array.isArray(d.signals) && d.signals.length > 0, `day ${d.date} carries auditable signals (${d.signals.length})`);
}
ok(days[0].alignment !== days[1].alignment, "alignment varies day to day (not a constant placeholder)");

// Prove the bindu actually flowed into a gochara signal (amp != 1 → non-round delta).
const jupiterSignal = days[0].signals.find((s) => s.kind === "gochara" && s.planet === "Jupiter");
ok(jupiterSignal && jupiterSignal.bindu === 6, "Jupiter gochara signal carries the real 6-bindu strength");

console.log(`\nday 2026-07-20 alignment=${days[0].alignment}  + ${days[0].favorable.join(" | ")}`);
console.log(`day 2026-07-21 alignment=${days[1].alignment}  - ${days[1].unfavorable.join(" | ")}`);

console.log(`\n=== ${pass} assertions passed ===\n`);
