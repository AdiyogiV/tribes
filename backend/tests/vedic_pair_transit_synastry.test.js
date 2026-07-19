import assert from "node:assert/strict";
import test from "node:test";
import {
    computePairTransitSynastry,
    chartSigns,
    labelFor,
} from "../lib/vedic_pair_transit_synastry.js";

// Longitude at the middle of a sign index (0=Aries..11=Pisces).
const at = (sign) => ({ fullDegree: sign * 30 + 15 });

// Natal chart tuned so that a planet "parked" in sign 1 aspects NONE of the
// karakas. From sign 1, the aspect-free house-distances are {2,6,11,12}, i.e.
// signs {2,6,11,0}. So: Moon→sign 2, Venus→sign 11, Ascendant→sign 0
// (→ 7th house = sign 6). All four land on aspect-free distances.
const natal = () => ({ Moon: at(2), Venus: at(11), Ascendant: at(0) });

// A transit sky with every planet parked in sign 1 (aspects no target karaka),
// then apply overrides to move specific planets.
const parked = (overrides = {}) => {
    const base = {};
    for (const p of ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"]) {
        base[p] = at(1);
    }
    for (const [p, s] of Object.entries(overrides)) base[p] = at(s);
    return base;
};

test("chartSigns parses planets, Ascendant, and derives the 7th", () => {
    const s = chartSigns(natal());
    assert.equal(s.Moon, 2);
    assert.equal(s.Venus, 11);
    assert.equal(s.Ascendant, 0);
    assert.equal(s.seventh, 6);
});

test("null when any chart/transit is missing", () => {
    const r = computePairTransitSynastry({ natalA: natal(), natalB: natal(), transit: null });
    assert.equal(r.score, null);
    assert.equal(r.label, "Unknown");
});

test("parked sky (no karaka aspects) sits at the neutral midpoint", () => {
    const r = computePairTransitSynastry({ natalA: natal(), natalB: natal(), transit: parked() });
    assert.equal(r.score, 50);
});

test("benefic Jupiter aspecting both Moons lifts the pair + shared connection", () => {
    // Jupiter in sign 8 casts its 7th aspect onto sign 2 (both natal Moons).
    const r = computePairTransitSynastry({
        natalA: natal(), natalB: natal(), transit: parked({ Jupiter: 8 }),
    });
    assert.ok(r.score > 50, `expected > 50, got ${r.score}`);
    const shared = r.connection.filter((c) => c.kind === "shared");
    assert.ok(shared.length > 0);
    assert.ok(shared.every((c) => c.benefic === true));
    assert.ok(r.connection.some((c) => c.planet === "Jupiter"));
});

test("malefic Saturn aspecting both Moons drags the pair down", () => {
    const r = computePairTransitSynastry({
        natalA: natal(), natalB: natal(), transit: parked({ Saturn: 8 }),
    });
    assert.ok(r.score < 50, `expected < 50, got ${r.score}`);
    const shared = r.connection.filter((c) => c.kind === "shared");
    assert.ok(shared.length > 0);
    assert.ok(shared.every((c) => c.benefic === false));
});

test("a transit hitting DIFFERENT karakas across the two charts is a bridge", () => {
    // A: Moon@2 (Jupiter@8 7th aspect hits it); B: Venus@2 (same aspect). Asc@5
    // (7th=11) keeps every other karaka out of Jupiter's reach {8,2,0,4} and
    // out of the parked planets' reach, so ONLY the Moon↔Venus bridge shows.
    const A = { Moon: at(2), Venus: at(11), Ascendant: at(5) };
    const B = { Moon: at(11), Venus: at(2), Ascendant: at(5) };
    const r = computePairTransitSynastry({ natalA: A, natalB: B, transit: parked({ Jupiter: 8 }) });
    const bridge = r.connection.find((c) => c.kind === "bridge" && c.planet === "Jupiter");
    assert.ok(bridge, "expected a Jupiter bridge");
    assert.equal(bridge.karakaA, "Moon");
    assert.equal(bridge.karakaB, "Venus");
});

test("personalA / personalB carry each person's OWN transit hits", () => {
    const r = computePairTransitSynastry({ natalA: natal(), natalB: natal(), transit: parked({ Jupiter: 8 }) });
    assert.ok(Array.isArray(r.personalA) && r.personalA.length > 0);
    assert.ok(Array.isArray(r.personalB) && r.personalB.length > 0);
    assert.ok(r.personalA.every((h) => h.planet && h.karaka && typeof h.benefic === "boolean"));
});

test("benefic scenario outscores malefic scenario", () => {
    const good = computePairTransitSynastry({ natalA: natal(), natalB: natal(), transit: parked({ Jupiter: 8 }) }).score;
    const bad = computePairTransitSynastry({ natalA: natal(), natalB: natal(), transit: parked({ Saturn: 8 }) }).score;
    assert.ok(good > bad, `good(${good}) should beat bad(${bad})`);
});

test("Jupiter's special 9th aspect reaches a karaka the 7th would miss", () => {
    // Custom natal: Venus in sign 5. Jupiter in sign 9 → 9th aspect (9→5)
    // touches Venus (a plain 7th-only planet from sign 9 would miss it).
    const venusNatal = () => ({ Moon: at(0), Venus: at(5), Ascendant: at(0) });
    const r = computePairTransitSynastry({
        natalA: venusNatal(), natalB: venusNatal(), transit: parked({ Jupiter: 9 }),
    });
    assert.ok(r.connection.some((c) => c.planet === "Jupiter" &&
        (c.karaka === "Venus" || c.karakaA === "Venus" || c.karakaB === "Venus")));
});

test("score is clamped to 0-100", () => {
    const r = computePairTransitSynastry({
        natalA: natal(), natalB: natal(),
        transit: parked({ Jupiter: 8, Venus: 8, Mercury: 8, Moon: 8 }),
    });
    assert.ok(r.score <= 100 && r.score >= 0);
});

test("labelFor bands", () => {
    assert.equal(labelFor(85), "In Flow");
    assert.equal(labelFor(70), "Aligned");
    assert.equal(labelFor(55), "Steady");
    assert.equal(labelFor(40), "Offset");
    assert.equal(labelFor(20), "Lay Low");
    assert.equal(labelFor(null), "Unknown");
});
