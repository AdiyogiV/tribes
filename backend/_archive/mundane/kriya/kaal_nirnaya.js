/**
 * क्रिया १ — काल निर्णय (Kaal Nirnaya: Time Determination)
 *
 * "A Jyotishi does not speak at arbitrary moments. He speaks when
 *  the sky commands it — at Purnima, at Amavasya, at ingress."
 *
 * The FIRST step of any reading: Is this the right time?
 * ~26 triggers/year, not 365. Astronomically significant moments only.
 */

/**
 * Known New Moon (Amavasya) dates for the simulation period.
 * Source: astronomical almanac data. These are approximate UTC dates.
 * In production, compute from Swiss Ephemeris.
 */
const KNOWN_NEW_MOONS_2025_2026 = [
    "2025-01-29", "2025-02-28", "2025-03-29", "2025-04-27",
    "2025-05-27", "2025-06-25", "2025-07-24", "2025-08-23",
    "2025-09-21", "2025-10-21", "2025-11-20", "2025-12-20",
    "2026-01-18", "2026-02-17", "2026-03-19", "2026-04-17",
];

const SYNODIC_MONTH = 29.53059; // days

/**
 * Generate all Purnima (Full Moon) and Amavasya (New Moon) dates
 * in a date range using the synodic month approximation.
 *
 * @param {string} startDate - "YYYY-MM-DD"
 * @param {string} endDate - "YYYY-MM-DD"
 * @returns {Object[]} [{ date, type, label }]
 */
export function getPurnimaAmavasyaDates(startDate, endDate) {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const triggers = [];

    for (const nmStr of KNOWN_NEW_MOONS_2025_2026) {
        const nm = new Date(nmStr);

        // Amavasya (New Moon)
        if (nm >= start && nm <= end) {
            triggers.push({
                date: nmStr,
                type: "amavasya",
                label: `Amavasya (New Moon) — ${nmStr}`,
                significance: "Solar/initiation energy peak. New cycles begin.",
            });
        }

        // Purnima (Full Moon) = New Moon + ~14.76 days
        const fm = new Date(nm);
        fm.setDate(fm.getDate() + Math.round(SYNODIC_MONTH / 2));
        const fmStr = fm.toISOString().split("T")[0];

        if (fm >= start && fm <= end) {
            triggers.push({
                date: fmStr,
                type: "purnima",
                label: `Purnima (Full Moon) — ${fmStr}`,
                significance: "Lunar effects peak. Results of previous cycle manifest.",
            });
        }
    }

    return triggers.sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Known slow planet ingresses in 2025-2026.
 * These are MAJOR mundane events — when Saturn, Jupiter, Rahu, or Ketu change signs.
 *
 * Source: Swiss Ephemeris / standard almanac.
 * Sidereal (Lahiri).
 */
const KNOWN_INGRESSES_2025_2026 = [
    { date: "2025-03-29", planet: "Saturn", fromSign: "Aquarius", toSign: "Pisces", significance: "critical" },
    { date: "2025-05-14", planet: "Jupiter", fromSign: "Taurus", toSign: "Gemini", significance: "major" },
    { date: "2025-01-25", planet: "Rahu", fromSign: "Aries", toSign: "Pisces", significance: "major" },
    { date: "2025-01-25", planet: "Ketu", fromSign: "Libra", toSign: "Virgo", significance: "major" },
];

/**
 * Get all mundane trigger dates for a period — the times Varahamihira would speak.
 *
 * @param {string} startDate - "YYYY-MM-DD"
 * @param {string} endDate - "YYYY-MM-DD"
 * @returns {Object[]} All trigger events sorted by date
 */
export function getAllTriggerDates(startDate, endDate) {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const triggers = [];

    // Purnima + Amavasya
    triggers.push(...getPurnimaAmavasyaDates(startDate, endDate));

    // Ingresses
    for (const ing of KNOWN_INGRESSES_2025_2026) {
        const d = new Date(ing.date);
        if (d >= start && d <= end) {
            triggers.push({
                date: ing.date,
                type: "ingress",
                planet: ing.planet,
                label: `${ing.planet} ingress: ${ing.fromSign} → ${ing.toSign}`,
                significance: ing.significance,
            });
        }
    }

    return triggers.sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Pretty-print a year's trigger calendar.
 * @param {string} startDate
 * @param {string} endDate
 * @returns {string} Human-readable trigger calendar
 */
export function formatTriggerCalendar(startDate, endDate) {
    const triggers = getAllTriggerDates(startDate, endDate);
    const lines = [`# Mundane Trigger Calendar: ${startDate} to ${endDate}`];
    lines.push(`# Total triggers: ${triggers.length} (vs 365 daily runs)\n`);

    let currentMonth = "";
    for (const t of triggers) {
        const month = t.date.substring(0, 7);
        if (month !== currentMonth) {
            currentMonth = month;
            lines.push(`\n── ${month} ──`);
        }

        const icon = t.type === "purnima" ? "🌕"
            : t.type === "amavasya" ? "🌑"
            : t.type === "ingress" ? "⚡"
            : t.type === "eclipse" ? "🌒"
            : "📌";

        lines.push(`  ${icon} ${t.date}  ${t.label}`);
    }

    return lines.join("\n");
}
