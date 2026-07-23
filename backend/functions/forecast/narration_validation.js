/**
 * Validate Gemini's forecast narration before it can mutate the read model.
 * Computed signal dates are the contract: every one must appear exactly once.
 */
export function validateNarratedDays(rawDays, signals) {
    if (!Array.isArray(rawDays)) {
        return { ok: false, reason: "days-not-array", days: [] };
    }

    const expectedDates = (signals || []).map((signal) => signal.date);
    const expected = new Set(expectedDates);
    if (!expectedDates.length) {
        return { ok: false, reason: "no-expected-dates", days: [] };
    }

    const byDate = new Map();
    for (const raw of rawDays) {
        const date = typeof raw?.date === "string" ? raw.date.trim() : "";
        const heading = typeof raw?.heading === "string" ? raw.heading.trim() : "";
        const narrative = typeof raw?.narrative === "string" ? raw.narrative.trim() : "";
        const publicNote = typeof raw?.publicNote === "string" ? raw.publicNote.trim() : "";
        const action = typeof raw?.action === "string" ? raw.action.trim() : "";
        const caution = typeof raw?.caution === "string" ? raw.caution.trim() : "";
        const tip = typeof raw?.tip === "string" ? raw.tip.trim() : "";
        const timing = typeof raw?.timing === "string" ? raw.timing.trim() : "";
        // goodFor / avoid: short editorial lists for the FAVOR/AVOID columns.
        // Coerced to string arrays; tolerated-empty (card degrades gracefully).
        const toList = (v) => Array.isArray(v)
            ? v.map((x) => String(x).trim()).filter(Boolean).slice(0, 4)
            : [];
        const goodFor = toList(raw?.goodFor);
        const avoid = toList(raw?.avoid);

        if (!expected.has(date)) {
            return { ok: false, reason: `unexpected-date:${date || "missing"}`, days: [] };
        }
        if (byDate.has(date)) {
            return { ok: false, reason: `duplicate-date:${date}`, days: [] };
        }
        if (!heading || !narrative) {
            return { ok: false, reason: `missing-copy:${date}`, days: [] };
        }

        const day = { date, heading, narrative };
        // publicNote is optional: a third-person, friend-safe line. If the model
        // omits it we degrade gracefully (friend card falls back to heading)
        // rather than rejecting the whole month's narration.
        if (publicNote) day.publicNote = publicNote;
        if (action) day.action = action;
        if (caution) day.caution = caution;
        if (tip) day.tip = tip;
        if (timing) day.timing = timing;
        if (goodFor.length) day.goodFor = goodFor;
        if (avoid.length) day.avoid = avoid;
        byDate.set(date, day);
    }

    const missing = expectedDates.find((date) => !byDate.has(date));
    if (missing) {
        return { ok: false, reason: `missing-date:${missing}`, days: [] };
    }

    return {
        ok: true,
        days: expectedDates.map((date) => byDate.get(date)),
        through: expectedDates.at(-1),
    };
}
