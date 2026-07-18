import assert from "node:assert/strict";
import test from "node:test";
import { DateTime } from "luxon";
import { orchestratorCalendar } from "../functions/schedulers/orchestrator_clock.js";

test("uses the IST business day after the 23:00 UTC trigger", () => {
    const utcSunday = DateTime.fromISO("2026-07-19T23:00:00Z");
    const calendar = orchestratorCalendar(utcSunday);

    assert.equal(calendar.date, "2026-07-20");
    assert.equal(calendar.isMonday, true);
    assert.equal(calendar.isSunday, false);
});

test("uses the local month boundary rather than UTC's previous date", () => {
    const utcMonthEnd = DateTime.fromISO("2026-07-31T23:00:00Z");
    const calendar = orchestratorCalendar(utcMonthEnd);

    assert.equal(calendar.date, "2026-08-01");
    assert.equal(calendar.dayOfMonth, 1);
    assert.equal(calendar.isBimonthly, true);
});
