/**
 * Sanity test for the canonical nakshatra module.
 * Run: node tests/test_nakshatras.js
 */
import {
    NAKSHATRAS, normalizeNakshatra, nakshatraIndex, nakshatraName,
    getNakshatraFromDegree, nakshatraIndexFromDegree,
} from "../lib/nakshatras.js";

let pass = 0, fail = 0;
function check(label, got, want) {
    if (got === want) { pass++; }
    else { fail++; console.error(`   ${label}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`); }
}

// The bug that started it all.
check("Moola → 18", nakshatraIndex("Moola"), 18);
check("Mula → 18 (Flutter's spelling)", nakshatraIndex("Mula"), 18);
check("mula lowercase → 18", nakshatraIndex("mula"), 18);

// Alias table spot checks (from the FreeAstrologyAPI wild).
check("Aardra → 5", nakshatraIndex("Aardra"), 5);
check("Satabisha → 23", nakshatraIndex("Satabisha"), 23);
check("Sravanam → 21", nakshatraIndex("Shravana"), 21);
check("Poorvaabhadra → 24", nakshatraIndex("Poorvaabhadra"), 24);
check("Poorva Phalguni(Pubba) parenthetical → 10", nakshatraIndex("Poorva Phalguni(Pubba)"), 10);

// name/index round-trip for all 27.
let roundTripOk = true;
for (let i = 0; i < 27; i++) {
    if (nakshatraIndex(nakshatraName(i)) !== i) { roundTripOk = false; console.error(`   round-trip broke at ${i} (${nakshatraName(i)})`); }
}
check("all 27 name↔index round-trip", roundTripOk, true);

// degree helpers.
check("0° → Ashwini", getNakshatraFromDegree(0), "Ashwini");
check("degree idx 240° → 18 (Moola)", nakshatraIndexFromDegree(240), 18);

// unknown / bad input.
check("garbage → -1", nakshatraIndex("Xyzzy Nakshatra"), -1);
check("null name(index) out of range", nakshatraName(99), null);
check("canonical count", NAKSHATRAS.length, 27);

console.log(`\nnakshatras: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
