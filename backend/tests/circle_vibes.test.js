import assert from "node:assert/strict";
import test from "node:test";
import { normalizeFriendIds, pickTodayVibe, MAX_FRIENDS } from "../functions/circle_vibes.js";

const ME = "me-uid";

test("normalizeFriendIds de-dupes, drops self, and skips junk", () => {
    const out = normalizeFriendIds(ME, ["a", "a", ME, "", "  ", 42, null, "b"]);
    assert.deepEqual(out, ["a", "b"]);
});

test("normalizeFriendIds trims and caps at MAX_FRIENDS", () => {
    const many = Array.from({ length: MAX_FRIENDS + 10 }, (_, i) => `u${i}`);
    const out = normalizeFriendIds(ME, many);
    assert.equal(out.length, MAX_FRIENDS);
    assert.equal(out[0], "u0");
});

test("normalizeFriendIds returns [] for non-array input", () => {
    assert.deepEqual(normalizeFriendIds(ME, undefined), []);
    assert.deepEqual(normalizeFriendIds(ME, "nope"), []);
});

const TODAY = "2026-07-19";
const days = [
    { date: "2026-07-18", heading: "Old News" },
    { date: TODAY, heading: "Quiet Reset", narrative: "SECRET first-person text", publicNote: "A quiet, inward day for them" },
];

test("pickTodayVibe surfaces heading + publicNote (never the narrative)", () => {
    const v = pickTodayVibe("f1", { displayName: "Priya", displayPicture: "p.jpg" }, days, TODAY);
    assert.deepEqual(v, {
        uid: "f1",
        name: "Priya",
        photo: "p.jpg",
        vibe: "Quiet Reset",
        publicNote: "A quiet, inward day for them",
    });
    assert.ok(!("narrative" in v));
});

test("pickTodayVibe returns publicNote null when the model omitted it", () => {
    const noNote = [{ date: TODAY, heading: "Quiet Reset" }];
    const v = pickTodayVibe("f1", { displayName: "Priya" }, noNote, TODAY);
    assert.equal(v.vibe, "Quiet Reset");
    assert.equal(v.publicNote, null);
});

test("pickTodayVibe falls back to name then 'Friend', photo null", () => {
    assert.equal(pickTodayVibe("f1", { name: "Raj" }, days, TODAY).name, "Raj");
    const anon = pickTodayVibe("f1", {}, days, TODAY);
    assert.equal(anon.name, "Friend");
    assert.equal(anon.photo, null);
});

test("pickTodayVibe returns null when astrology is private", () => {
    const v = pickTodayVibe("f1", { displayName: "Priya", astrologyData: { visibility: "private" } }, days, TODAY);
    assert.equal(v, null);
});

test("pickTodayVibe returns null when today has no narrated heading", () => {
    assert.equal(pickTodayVibe("f1", { displayName: "Priya" }, days, "2026-07-20"), null);
    assert.equal(pickTodayVibe("f1", { displayName: "Priya" }, [{ date: TODAY, heading: "  " }], TODAY), null);
    assert.equal(pickTodayVibe("f1", { displayName: "Priya" }, [], TODAY), null);
});
