/**
 * Eyeball test for the per-day Vedic signal calculator.
 * Run: node tests/test_vedic_day_signal.js
 *
 * Prints alignment + the exact classical signals for several days so a human
 * can verify (a) the number moves day to day, and (b) every point is traceable.
 */

import { computeDaySignal } from "../lib/vedic_day_signal.js";
import { getTransitBinduScore } from "../lib/vedic_analysis.js";

// Natal: Moon in Taurus (idx 1), birth nakshatra Rohini (idx 3).
const natal = { moonSignIndex: 1, birthNakshatraIndex: 3 };

// Helper: put a planet at the middle of a sign index.
const at = (signIdx) => ({ fullDegree: signIdx * 30 + 15 });

// Three synthetic days with the Moon (and a couple planets) moved around.
const days = [
    {
        label: "Day A — Moon 3rd from natal (favorable)",
        moonNak: 5, // Mrigashira -> tara from Rohini(3): (5-3)%9=2 -> Vipat (bad) : shows tension
        pos: {
            Moon: at(3), // Cancer = 3rd from Taurus
            Jupiter: at(7), // Scorpio = 7th from Moon -> favorable
            Saturn: at(3), // 6th from Moon? 3-1=... check
            Sun: at(3),
        },
    },
    {
        label: "Day B — Moon 6th from natal (favorable) + good tara",
        moonNak: 4, // (4-3)%9=1 -> Sampat (good)
        pos: {
            Moon: at(6), // Libra = 6th from Taurus
            Jupiter: at(5), // Virgo
            Saturn: at(9), // Capricorn
            Venus: at(1),
        },
    },
    {
        label: "Day C — Moon 12th from natal (unfavorable)",
        moonNak: 2, // (2-3)%9=8 -> AtiMitra (good) — tara good but chandra bala bad
        pos: {
            Moon: at(0), // Aries = 12th from Taurus
            Mars: at(0),
            Saturn: at(6),
        },
    },
];

console.log("\n=== PER-DAY VEDIC SIGNAL (natal Moon Taurus, Rohini) ===\n");
for (const d of days) {
    const r = computeDaySignal({
        ...natal,
        dayPositions: d.pos,
        dayMoonNakshatra: d.moonNak,
        panchang: { tithiNumber: 5, yoga: "Siddhi" },
        binduFn: getTransitBinduScore, // real bindu math (no AV here -> returns gracefully)
    });
    console.log(`${d.label}`);
    console.log(`  ALIGNMENT: ${r.alignment}/100`);
    console.log(`  + ${r.favorable.join(" | ") || "(none)"}`);
    console.log(`  - ${r.unfavorable.join(" | ") || "(none)"}`);
    console.log("");
}
