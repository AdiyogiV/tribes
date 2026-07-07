/**
 * Eyeball test for the life-story spine.
 * Run: node tests/test_life_story.js
 *
 * Not an assertion test — it PRINTS the story for a realistic dasha tree so a
 * human can judge whether it reads as one coherent multi-year narrative.
 */

import { buildLifeStory } from "../lib/life_story.js";

// Realistic Jupiter Mahadasha (2019–2035), with antars in Vimshottari order.
// "now" is set to mid-2026 so we land inside the Saturn sub-period.
const astroData = {
    currentDasha: {
        tree: [
            {
                lord: "Jupiter", startDate: "2019-03-10", endDate: "2035-03-10",
                children: [
                    { lord: "Jupiter", startDate: "2019-03-10", endDate: "2021-04-28" },
                    { lord: "Saturn", startDate: "2021-04-28", endDate: "2023-11-09" },
                    { lord: "Mercury", startDate: "2023-11-09", endDate: "2026-02-14" },
                    { lord: "Ketu", startDate: "2026-02-14", endDate: "2027-01-20" },
                    { lord: "Venus", startDate: "2027-01-20", endDate: "2029-09-21" },
                    { lord: "Sun", startDate: "2029-09-21", endDate: "2030-07-10" },
                    { lord: "Moon", startDate: "2030-07-10", endDate: "2031-11-09" },
                ],
            },
            {
                lord: "Saturn", startDate: "2035-03-10", endDate: "2054-03-10",
                children: [],
            },
        ],
    },
};

const now = new Date("2026-07-07T00:00:00Z");
const story = buildLifeStory(astroData, { now });

console.log("\n=== LIFE STORY (now = 2026-07-07) ===\n");
console.log("HEADLINE:\n  " + story.headline + "\n");

console.log("TIMELINE:");
for (const c of story.timeline) {
    const marker = c.active ? ">" : " ";
    const lvl = c.level.toUpperCase().padEnd(5);
    console.log(
        `${marker} [${lvl}] ${c.lord.padEnd(8)} ${c.span.padEnd(20)} (${c.duration.padStart(5)}, ${c.when})`
    );
    console.log(`        ${c.meaning}`);
}
console.log("\nCURRENT maha:", story.current.maha.lord, "| antar:", story.current.antar?.lord, "\n");
