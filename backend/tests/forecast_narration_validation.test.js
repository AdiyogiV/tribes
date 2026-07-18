import assert from "node:assert/strict";
import test from "node:test";
import { validateNarratedDays } from "../functions/forecast/narration_validation.js";

const signals = [
    { date: "2026-07-19" },
    { date: "2026-07-20" },
];

const complete = [
    { date: "2026-07-19", heading: "Steady Start", narrative: "Take the first step." },
    { date: "2026-07-20", heading: "Clearer Ground", narrative: "Momentum builds gently." },
];

test("accepts exact narration coverage in signal order", () => {
    const result = validateNarratedDays([...complete].reverse(), signals);
    assert.equal(result.ok, true);
    assert.deepEqual(result.days, complete);
    assert.equal(result.through, "2026-07-20");
});

test("rejects a missing signal date", () => {
    const result = validateNarratedDays(complete.slice(0, 1), signals);
    assert.equal(result.ok, false);
    assert.equal(result.reason, "missing-date:2026-07-20");
});

test("rejects duplicate and unexpected dates", () => {
    const duplicate = validateNarratedDays([complete[0], complete[0]], signals);
    assert.equal(duplicate.reason, "duplicate-date:2026-07-19");

    const unexpected = validateNarratedDays([
        complete[0],
        { date: "2026-07-21", heading: "Nope", narrative: "Not requested." },
    ], signals);
    assert.equal(unexpected.reason, "unexpected-date:2026-07-21");
});

test("rejects empty copy", () => {
    const result = validateNarratedDays([
        complete[0],
        { date: "2026-07-20", heading: "", narrative: "Text" },
    ], signals);
    assert.equal(result.reason, "missing-copy:2026-07-20");
});
