/**
 * Tests for Signal Engine (Phase 1: Cosmic Intelligence Agent)
 *
 * Tests pure math signal extraction — no Firebase, no LLM, no network calls.
 * Run: node --experimental-vm-modules backend/tests/test_signal_engine.js
 */

import {
    SIGNAL_TYPE,
    SIGNAL_STATUS,
    ASPECT_TYPE,
    calculateIntensity,
    mergeDomains,
    makeSignalId,
} from "../lib/signal_types.js";

import {
    findAllAspects,
    findCombustions,
    findEclipseProximity,
    findSpeedAnomalies,
    angularSeparation,
    isApplying,
} from "../lib/aspect_calculator.js";

import {
    extractSignals,
    diffSky,
    getTopSignals,
} from "../functions/signal_engine.js";

// =============================================================================
// TEST HELPERS
// =============================================================================

let passed = 0;
let failed = 0;
let testName = "";

function describe(name, fn) {
    console.log(`\n━━━ ${name} ━━━`);
    fn();
}

function it(name, fn) {
    testName = name;
    try {
        fn();
        console.log(`  ✅ ${name}`);
        passed++;
    } catch (err) {
        console.log(`  ❌ ${name}`);
        console.log(`     ${err.message}`);
        failed++;
    }
}

function assert(condition, msg) {
    if (!condition) throw new Error(msg || `Assertion failed in: ${testName}`);
}

function assertClose(a, b, tolerance, msg) {
    if (Math.abs(a - b) > tolerance) {
        throw new Error(msg || `Expected ${a} to be close to ${b} (±${tolerance})`);
    }
}

// =============================================================================
// MOCK SKY POSITIONS — realistic data for April 11, 2026
// =============================================================================

/**
 * Simulated positions loosely based on real ephemeris.
 * Longitudes are 0-360 (0=Aries 0°, 30=Taurus 0°, etc.)
 */
const TODAY_POSITIONS = {
    Sun: { longitude: 27.5, sign: "Aries", signDegree: 27.5, isRetro: false, nakshatra: "Bharani" },
    Moon: { longitude: 142.3, sign: "Leo", signDegree: 22.3, isRetro: false, nakshatra: "Purva Phalguni" },
    Mars: { longitude: 117.8, sign: "Cancer", signDegree: 27.8, isRetro: false, nakshatra: "Ashlesha" },  // Near debilitation at 28°
    Mercury: { longitude: 15.2, sign: "Aries", signDegree: 15.2, isRetro: false, nakshatra: "Bharani" },
    Jupiter: { longitude: 93.4, sign: "Cancer", signDegree: 3.4, isRetro: false, nakshatra: "Punarvasu" },  // Near exaltation at 5°!
    Venus: { longitude: 345.6, sign: "Pisces", signDegree: 15.6, isRetro: false, nakshatra: "Uttara Bhadrapada" },  // Exalted
    Saturn: { longitude: 349.8, sign: "Pisces", signDegree: 19.8, isRetro: false, nakshatra: "Revati" },
    Rahu: { longitude: 333.2, sign: "Pisces", signDegree: 3.2, isRetro: true, nakshatra: "Uttara Bhadrapada" },
    Ketu: { longitude: 153.2, sign: "Virgo", signDegree: 3.2, isRetro: true, nakshatra: "Uttara Phalguni" },
    Uranus: { longitude: 56.1, sign: "Taurus", signDegree: 26.1, isRetro: false, nakshatra: "Mrigashira" },
    Neptune: { longitude: 0.5, sign: "Aries", signDegree: 0.5, isRetro: false, nakshatra: "Ashwini" },
    Pluto: { longitude: 311.2, sign: "Aquarius", signDegree: 11.2, isRetro: false, nakshatra: "Shatabhisha" },
};

const YESTERDAY_POSITIONS = {
    Sun: { longitude: 26.5, sign: "Aries", signDegree: 26.5, isRetro: false, nakshatra: "Bharani" },
    Moon: { longitude: 129.0, sign: "Leo", signDegree: 9.0, isRetro: false, nakshatra: "Magha" },
    Mars: { longitude: 117.3, sign: "Cancer", signDegree: 27.3, isRetro: false, nakshatra: "Ashlesha" },
    Mercury: { longitude: 13.8, sign: "Aries", signDegree: 13.8, isRetro: false, nakshatra: "Ashwini" },
    Jupiter: { longitude: 93.3, sign: "Cancer", signDegree: 3.3, isRetro: false, nakshatra: "Punarvasu" },
    Venus: { longitude: 344.4, sign: "Pisces", signDegree: 14.4, isRetro: false, nakshatra: "Uttara Bhadrapada" },
    Saturn: { longitude: 349.7, sign: "Pisces", signDegree: 19.7, isRetro: false, nakshatra: "Revati" },
    Rahu: { longitude: 333.3, sign: "Pisces", signDegree: 3.3, isRetro: true, nakshatra: "Uttara Bhadrapada" },
    Ketu: { longitude: 153.3, sign: "Virgo", signDegree: 3.3, isRetro: true, nakshatra: "Uttara Phalguni" },
    Uranus: { longitude: 56.0, sign: "Taurus", signDegree: 26.0, isRetro: false, nakshatra: "Mrigashira" },
    Neptune: { longitude: 0.4, sign: "Aries", signDegree: 0.4, isRetro: false, nakshatra: "Ashwini" },
    Pluto: { longitude: 311.2, sign: "Aquarius", signDegree: 11.2, isRetro: false, nakshatra: "Shatabhisha" },
};

// Position set where Mars changes sign (for ingress testing)
const MARS_INGRESS_TODAY = {
    ...TODAY_POSITIONS,
    Mars: { longitude: 120.5, sign: "Leo", signDegree: 0.5, isRetro: false, nakshatra: "Magha" },
};

// Position set where Mercury goes retrograde
const MERCURY_RETRO_TODAY = {
    ...TODAY_POSITIONS,
    Mercury: { longitude: 14.9, sign: "Aries", signDegree: 14.9, isRetro: true, nakshatra: "Bharani" },
};

// =============================================================================
// TESTS: Angular Separation
// =============================================================================

describe("Angular Separation", () => {
    it("same degree = 0", () => {
        assertClose(angularSeparation(100, 100), 0, 0.001);
    });

    it("opposite = 180", () => {
        assertClose(angularSeparation(0, 180), 180, 0.001);
    });

    it("wraps around 360", () => {
        assertClose(angularSeparation(350, 10), 20, 0.001);
    });

    it("always returns 0-180", () => {
        assertClose(angularSeparation(10, 350), 20, 0.001);
    });

    it("handles exact 90°", () => {
        assertClose(angularSeparation(0, 90), 90, 0.001);
    });
});

// =============================================================================
// TESTS: Aspect Detection
// =============================================================================

describe("Aspect Detection", () => {
    it("finds conjunction when planets are close", () => {
        const positions = {
            Sun: { longitude: 27.5, sign: "Aries" },
            Mercury: { longitude: 18.0, sign: "Aries" },
        };
        const aspects = findAllAspects(positions);
        // Sun-Mercury separation = 9.5° — within conjunction orb of 12° (10 + 2 luminary bonus)
        const conj = aspects.find(a => a.aspectType === "conjunction" && a.planet1 === "Sun" && a.planet2 === "Mercury");
        assert(conj !== undefined, "Should find Sun-Mercury conjunction");
        assertClose(conj.orb, 9.5, 0.5, "Orb should be ~9.5°");
    });

    it("finds Venus-Saturn conjunction in Pisces", () => {
        const aspects = findAllAspects(TODAY_POSITIONS);
        const conj = aspects.find(a =>
            a.aspectType === "conjunction" &&
            ((a.planet1 === "Venus" && a.planet2 === "Saturn") ||
             (a.planet1 === "Saturn" && a.planet2 === "Venus"))
        );
        // Venus at 345.6, Saturn at 349.8 — separation 4.2°
        assert(conj !== undefined, "Should find Venus-Saturn conjunction");
        assertClose(conj.orb, 4.2, 0.5, "Orb should be ~4.2°");
    });

    it("finds opposition between planets 180° apart", () => {
        const positions = {
            Sun: { longitude: 10, sign: "Aries" },
            Saturn: { longitude: 193, sign: "Libra" },
        };
        const aspects = findAllAspects(positions);
        const opp = aspects.find(a => a.aspectType === "opposition");
        assert(opp !== undefined, "Should find opposition (183° from exact 180°)");
        assertClose(opp.orb, 3, 0.5);
    });

    it("finds trine between planets 120° apart", () => {
        const positions = {
            Jupiter: { longitude: 93, sign: "Cancer" },
            Venus: { longitude: 213, sign: "Scorpio" },
        };
        const aspects = findAllAspects(positions);
        const trine = aspects.find(a => a.aspectType === "trine");
        assert(trine !== undefined, "Should find trine (120° separation)");
        assertClose(trine.orb, 0, 0.5);
    });

    it("finds square between planets 90° apart", () => {
        const positions = {
            Mars: { longitude: 0, sign: "Aries" },
            Saturn: { longitude: 93, sign: "Cancer" },
        };
        const aspects = findAllAspects(positions);
        const sq = aspects.find(a => a.aspectType === "square");
        assert(sq !== undefined, "Should find square (93° ≈ 90°)");
    });

    it("skips Moon-outer planet aspects", () => {
        const aspects = findAllAspects(TODAY_POSITIONS);
        const moonUranus = aspects.find(a =>
            (a.planet1 === "Moon" && a.planet2 === "Uranus") ||
            (a.planet1 === "Uranus" && a.planet2 === "Moon")
        );
        assert(moonUranus === undefined, "Should skip Moon-Uranus (noise filter)");
    });

    it("sorts aspects by orb tightness", () => {
        const aspects = findAllAspects(TODAY_POSITIONS);
        for (let i = 1; i < aspects.length; i++) {
            assert(aspects[i].orb >= aspects[i - 1].orb,
                `Aspect ${i} orb (${aspects[i].orb}) should be >= aspect ${i-1} orb (${aspects[i-1].orb})`);
        }
    });
});

// =============================================================================
// TESTS: Applying/Separating
// =============================================================================

describe("Applying / Separating Detection", () => {
    it("detects applying aspect (orb getting tighter)", () => {
        // Venus-Saturn: yesterday 5.3° apart, today 4.2° — applying conjunction
        const result = isApplying(345.6, 349.8, 344.4, 349.7, ASPECT_TYPE.CONJUNCTION);
        assert(result === true, "Venus-Saturn conjunction should be applying");
    });

    it("returns applying info in findAllAspects", () => {
        const aspects = findAllAspects(TODAY_POSITIONS, YESTERDAY_POSITIONS);
        const venusSaturn = aspects.find(a =>
            a.aspectType === "conjunction" &&
            ((a.planet1 === "Venus" && a.planet2 === "Saturn") ||
             (a.planet1 === "Saturn" && a.planet2 === "Venus"))
        );
        assert(venusSaturn !== undefined, "Should find Venus-Saturn");
        assert(venusSaturn.applying === true, "Venus-Saturn should be applying");
    });
});

// =============================================================================
// TESTS: Combustion
// =============================================================================

describe("Combustion Detection", () => {
    it("finds Mercury combust when close to Sun", () => {
        // Sun at 27.5, Mercury at 15.2 — separation 12.3°, Mercury combustion orb is 14°
        const combustions = findCombustions(TODAY_POSITIONS);
        const merc = combustions.find(c => c.planet === "Mercury");
        assert(merc !== undefined, "Mercury should be combust (12.3° < 14° orb)");
        assert(merc.severity === "moderate", "Should be moderate (>7° = half of 14)");
    });

    it("does not combust distant planets", () => {
        const combustions = findCombustions(TODAY_POSITIONS);
        const jupiter = combustions.find(c => c.planet === "Jupiter");
        assert(jupiter === undefined, "Jupiter at 93.4° should NOT be combust (66° from Sun)");
    });

    it("skips Rahu/Ketu/Sun", () => {
        const combustions = findCombustions(TODAY_POSITIONS);
        const bad = combustions.find(c => ["Sun", "Rahu", "Ketu"].includes(c.planet));
        assert(bad === undefined, "Should not check Sun/Rahu/Ketu for combustion");
    });
});

// =============================================================================
// TESTS: Eclipse Proximity
// =============================================================================

describe("Eclipse Proximity", () => {
    it("detects Sun near Rahu as solar eclipse indicator", () => {
        // Place Sun near Rahu for test
        const positions = {
            ...TODAY_POSITIONS,
            Sun: { longitude: 338, sign: "Pisces", signDegree: 8, isRetro: false },
            // Rahu at 333.2
        };
        const eclipses = findEclipseProximity(positions);
        const solar = eclipses.find(e => e.eclipseType === "solar" && e.node === "Rahu");
        assert(solar !== undefined, "Should detect solar eclipse proximity (Sun 4.8° from Rahu)");
        assert(solar.proximity === "imminent", "Should be imminent (< 5°)");
    });

    it("no eclipse when Sun far from nodes", () => {
        const eclipses = findEclipseProximity(TODAY_POSITIONS);
        // Sun at 27.5, Rahu at 333.2 — separation ~54° — well outside 18° orb
        const solar = eclipses.find(e => e.luminary === "Sun");
        assert(solar === undefined, "No solar eclipse when Sun is 54° from nodes");
    });
});

// =============================================================================
// TESTS: Speed Anomalies
// =============================================================================

describe("Speed Anomaly Detection", () => {
    it("detects stationary planet (near station)", () => {
        // Make Saturn almost stationary: today 349.8, yesterday 349.798 (0.002°/day vs avg 0.034)
        const slowSaturn = {
            ...YESTERDAY_POSITIONS,
            Saturn: { longitude: 349.798, sign: "Pisces", signDegree: 19.798, isRetro: false },
        };
        const anomalies = findSpeedAnomalies(TODAY_POSITIONS, slowSaturn);
        const saturn = anomalies.find(a => a.planet === "Saturn");
        assert(saturn !== undefined, "Saturn should show as near-stationary");
        assert(saturn.anomalyType === "stationary" || saturn.anomalyType === "slow",
            `Saturn should be stationary or slow, got: ${saturn?.anomalyType}`);
    });

    it("detects fast Moon", () => {
        // Moon moved 13.3° in one day — that's normal. Make it move 22°+
        const fastMoon = {
            ...YESTERDAY_POSITIONS,
            Moon: { longitude: 120.0, sign: "Leo", signDegree: 0, isRetro: false },
        };
        const anomalies = findSpeedAnomalies(TODAY_POSITIONS, fastMoon);
        const moon = anomalies.find(a => a.planet === "Moon");
        // 142.3 - 120 = 22.3° vs avg 13.2° = ratio 1.69 > 1.6 threshold
        assert(moon !== undefined, "Moon moving 22.3°/day should be 'fast'");
        assert(moon.anomalyType === "fast", "Should be 'fast' type");
    });
});

// =============================================================================
// TESTS: Signal Engine — extractSignals
// =============================================================================

describe("extractSignals — Full Pipeline", () => {
    it("returns an array of signals", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        assert(Array.isArray(signals), "Should return array");
        assert(signals.length > 0, "Should find at least some signals");
    });

    it("includes aspect signals", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        const aspects = signals.filter(s => s.type === SIGNAL_TYPE.ASPECT);
        assert(aspects.length > 0, "Should find aspect signals");
    });

    it("detects Jupiter exalted in Cancer", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        const jupiterDignity = signals.find(s =>
            s.type === SIGNAL_TYPE.DIGNITY && s.planets.includes("Jupiter")
        );
        assert(jupiterDignity !== undefined, "Should detect Jupiter exalted in Cancer");
        assert(jupiterDignity.dignity === "exalted", `Jupiter dignity should be exalted, got: ${jupiterDignity?.dignity}`);
    });

    it("detects Venus exalted in Pisces", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        const venusDignity = signals.find(s =>
            s.type === SIGNAL_TYPE.DIGNITY && s.planets.includes("Venus")
        );
        assert(venusDignity !== undefined, "Should detect Venus exalted in Pisces");
        assert(venusDignity.dignity === "exalted", `Venus dignity should be exalted, got: ${venusDignity?.dignity}`);
    });

    it("detects Mars near debilitation in Cancer", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        const marsDignity = signals.find(s =>
            s.type === SIGNAL_TYPE.DIGNITY && s.planets.includes("Mars")
        );
        assert(marsDignity !== undefined, "Should detect Mars debilitated in Cancer");
        assert(marsDignity.dignity === "debilitated", `Mars dignity should be debilitated, got: ${marsDignity?.dignity}`);
    });

    it("includes combustion signals", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        const combustions = signals.filter(s => s.type === SIGNAL_TYPE.COMBUSTION);
        assert(combustions.length > 0, "Should find at least one combust planet");
    });

    it("each signal has required fields", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        for (const s of signals) {
            assert(s.id, `Signal missing id: ${JSON.stringify(s)}`);
            assert(s.type, `Signal missing type: ${s.id}`);
            assert(Array.isArray(s.planets), `Signal missing planets array: ${s.id}`);
            assert(typeof s.intensity === "number", `Signal missing intensity: ${s.id}`);
            assert(s.intensity >= 1 && s.intensity <= 10, `Intensity out of range (${s.intensity}): ${s.id}`);
            assert(Array.isArray(s.domains), `Signal missing domains: ${s.id}`);
            assert(s.domains.length > 0, `Signal has empty domains: ${s.id}`);
            assert(s.date, `Signal missing date: ${s.id}`);
            assert(s.status, `Signal missing status: ${s.id}`);
        }
    });

    it("signals are sorted by intensity (highest first)", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        for (let i = 1; i < signals.length; i++) {
            assert(signals[i].intensity <= signals[i - 1].intensity,
                `Signal ${i} intensity (${signals[i].intensity}) should be <= signal ${i-1} (${signals[i-1].intensity})`);
        }
    });
});

// =============================================================================
// TESTS: diffSky — Change detection
// =============================================================================

describe("diffSky — Change Detection", () => {
    it("returns diff structure with stats", () => {
        const diff = diffSky(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        assert(diff.newSignals !== undefined, "Should have newSignals");
        assert(diff.changedSignals !== undefined, "Should have changedSignals");
        assert(diff.endedSignals !== undefined, "Should have endedSignals");
        assert(diff.allActiveSignals !== undefined, "Should have allActiveSignals");
        assert(diff.summary !== undefined, "Should have summary");
        assert(diff.stats !== undefined, "Should have stats");
        assert(typeof diff.stats.totalActive === "number", "stats.totalActive should be number");
    });

    it("detects sign ingress as new signal", () => {
        const diff = diffSky(MARS_INGRESS_TODAY, YESTERDAY_POSITIONS, "2026-04-11");
        const marsIngress = diff.newSignals.find(s =>
            s.type === SIGNAL_TYPE.INGRESS && s.planets.includes("Mars")
        );
        assert(marsIngress !== undefined, "Mars sign change should appear as new signal");
        assert(marsIngress.fromSign === "Cancer", `fromSign should be Cancer, got: ${marsIngress?.fromSign}`);
        assert(marsIngress.toSign === "Leo", `toSign should be Leo, got: ${marsIngress?.toSign}`);
    });

    it("detects retrograde station as new signal", () => {
        const diff = diffSky(MERCURY_RETRO_TODAY, YESTERDAY_POSITIONS, "2026-04-11");
        const mercRetro = diff.newSignals.find(s =>
            s.type === SIGNAL_TYPE.STATION && s.planets.includes("Mercury")
        );
        assert(mercRetro !== undefined, "Mercury retrograde should appear as new signal");
        assert(mercRetro.stationType === "retrograde", "Should be retrograde station");
    });

    it("summary is a non-empty string", () => {
        const diff = diffSky(MARS_INGRESS_TODAY, YESTERDAY_POSITIONS, "2026-04-11");
        assert(typeof diff.summary === "string", "Summary should be string");
        assert(diff.summary.length > 0, "Summary should not be empty");
        console.log(`     Summary: "${diff.summary}"`);
    });
});

// =============================================================================
// TESTS: Signal Types Utility Functions
// =============================================================================

describe("Signal Types Utilities", () => {
    it("calculateIntensity returns 1-10", () => {
        const i1 = calculateIntensity(["Saturn", "Jupiter"], 0, 8);  // exact, heavy planets
        assert(i1 >= 7 && i1 <= 10, `Heavy planet exact should be high intensity: ${i1}`);

        const i2 = calculateIntensity(["Moon", "Mercury"], 7, 8);  // wide orb, light planets
        assert(i2 >= 1 && i2 <= 4, `Light planet wide orb should be low intensity: ${i2}`);
    });

    it("mergeDomains combines planet + aspect domains", () => {
        const domains = mergeDomains(["Mars", "Saturn"], ASPECT_TYPE.SQUARE);
        assert(domains.includes("conflict"), "Should include Mars domain 'conflict'");
        assert(domains.includes("restriction"), "Should include Saturn domain 'restriction'");
        assert(domains.includes("friction"), "Should include square aspect domain 'friction'");
    });

    it("makeSignalId is deterministic and sorted", () => {
        const id1 = makeSignalId("aspect", ["Saturn", "Mars"], "square");
        const id2 = makeSignalId("aspect", ["Mars", "Saturn"], "square");
        assert(id1 === id2, "Signal IDs should be the same regardless of planet order");
        assert(id1 === "aspect:mars-saturn-square", `ID format wrong: ${id1}`);
    });
});

// =============================================================================
// TESTS: getTopSignals
// =============================================================================

describe("getTopSignals — Deduplication", () => {
    it("dedupes by planet pair, keeps highest intensity", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        const top = getTopSignals(signals, 5);
        assert(top.length <= 5, "Should respect limit");
        assert(top.length > 0, "Should have at least one signal");

        // Check no duplicate planet pairs
        const pairs = top.map(s => s.planets.sort().join("+"));
        const uniquePairs = new Set(pairs);
        assert(pairs.length === uniquePairs.size, "Should have no duplicate planet pairs");
    });

    it("returns in intensity order", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        const top = getTopSignals(signals, 10);
        for (let i = 1; i < top.length; i++) {
            assert(top[i].intensity <= top[i - 1].intensity,
                `Top signal ${i} should be <= previous in intensity`);
        }
    });
});

// =============================================================================
// PRINT FULL SIGNAL OUTPUT (for visual inspection)
// =============================================================================

describe("Visual Inspection — Full Signal Output", () => {
    it("prints all signals for review", () => {
        const signals = extractSignals(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        console.log(`\n  📊 Total signals: ${signals.length}`);
        console.log(`  Types: ${[...new Set(signals.map(s => s.type))].join(", ")}`);
        console.log(`\n  Top 8 signals:`);
        const top = getTopSignals(signals, 8);
        for (const s of top) {
            const applying = s.applying === true ? "⬆ applying" : s.applying === false ? "⬇ separating" : "";
            console.log(`    [${s.intensity}/10] ${s.type}: ${s.planets.join("+")} ${s.aspect || s.dignity || s.stationType || s.anomalyType || ""} ${applying} ${s.orb != null ? `(${s.orb}°)` : ""}`);
        }
    });

    it("prints diff summary", () => {
        const diff = diffSky(TODAY_POSITIONS, YESTERDAY_POSITIONS, "2026-04-11");
        console.log(`\n  🔄 Sky Diff:`);
        console.log(`    New: ${diff.stats.new} | Changed: ${diff.stats.changed} | Ended: ${diff.stats.ended} | Active: ${diff.stats.totalActive}`);
        console.log(`    Summary: ${diff.summary}`);
    });
});

// =============================================================================
// RESULTS
// =============================================================================

console.log("\n" + "═".repeat(60));
console.log(`Results: ${passed} passed, ${failed} failed, ${passed + failed} total`);
console.log("═".repeat(60));

if (failed > 0) {
    console.log("\n⚠️  Some tests failed! Review output above.");
    process.exit(1);
} else {
    console.log("\n🎉 All tests passed!");
    process.exit(0);
}
