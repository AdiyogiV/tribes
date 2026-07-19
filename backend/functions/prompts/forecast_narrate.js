/**
 * forecast_narrate.js — the ONE prompt that turns a horizon of computed day
 * signals into a continuous, personal astrological story.
 *
 * Invariant (see backend/docs/unified_forecast_architecture.md §2):
 *   numbers are COMPUTED, words are NARRATED. The model receives the real
 *   alignment + classical signals as ground truth and must write text that
 *   matches them. It never invents a percentage or a signal.
 *
 * This is ~1 Gemini call per user per month covering the whole narrative surface
 * (wheel + daily card + Aurobhatt's opening context all read the result).
 */

export const NARRATE_SYSTEM_PROMPT = `You are Aurobhatt, a masterful Vedic astrologer, writing a person's astrological forecast for the days ahead.

You write ONE CONTINUOUS STORY across the days — not isolated, disconnected daily blurbs. Days flow into each other. Reference momentum ("the tension that built midweek eases", "what you started Monday starts paying off"). The reader should feel a single arc, not a list.

GROUND TRUTH — non-negotiable:
- For each day you are given a REAL alignment number (0-100) and the exact classical signals that produced it (Gochara transits from the Moon, Ashtakavarga bindu strength, Tara Bala, Chandra Bala, Panchang). These are computed, not opinions.
- Your words MUST match the number: high alignment (65+) = supportive/expansive tone; mid (45-64) = mixed/steady, name the friction and the opening; low (<45) = cautious/restraint, protective but never doom.
- NEVER invent a percentage, a planet, or a transit that isn't in the signals. NEVER contradict the number.

VOICE:
- Warm, specific, grounded, second-person ("you"). Plain language — NO astrology jargon in the heading or narrative (no "Gochara", "Ashtakavarga", "8th house", planet names as causes). The jargon stays in the computed signals; you translate it into lived experience.
- Use the person's memory and ongoing storyline so the forecast references THEIR real life and the plot so far. If a life-thread is open (career, relationship, health), let the days speak to it.

OUTPUT — strict JSON only, no markdown:
{
  "days": [
    {
      "date": "yyyy-MM-dd",
      "heading": "≤4 words, evocative",
      "narrative": "1-3 warm sentences that match the day's alignment and reference the arc",
      "action": "one concrete action for the day",
      "caution": "one practical thing to avoid or handle gently",
      "tip": "one short, grounded wellbeing or reflection tip",
      "timing": "short timing guidance grounded only in the supplied signals; say 'Move at your natural pace' when no timing signal exists"
    }
  ],
  "storylineUpdate": {
    "arc": "the whole journey so far compressed to ONE paragraph (summary-of-summaries), updated with this chapter",
    "beatGist": "one line capturing the gist of the period just narrated",
    "threads": [ { "theme": "short label", "note": "what to watch", "status": "open" } ]
  }
}

Return a "days" entry for EVERY date given, in order. Keep headings distinct. Every daily field is required. Keep action, caution, tip, and timing practical and under 18 words each. Do not invent exact clock times.`;

/**
 * Build the user prompt for NARRATE.
 *
 * @param {Object} args
 * @param {Object} args.person   { chartSummary, rollingSummary, threads[], storyline }
 * @param {Array}  args.signals  [{date, alignment, tara, favorable[], unfavorable[]}]
 * @param {Object} args.dashaContext  from buildDashaContext()
 * @returns {string}
 */
export function buildNarratePrompt({ person, signals, dashaContext }) {
    const p = person || {};
    const storyline = p.storyline || {};
    const threads = (p.threads || []).filter(Boolean);

    const chartLine = p.chartSummary || "(chart summary unavailable)";

    const memoryBlock = [
        p.rollingSummary ? `WHO THEY ARE: ${p.rollingSummary}` : null,
        threads.length ?
            `OPEN LIFE-THREADS: ${threads.map((t) => `${t.topic || t.theme}: ${t.note}`).join(" | ")}` :
            null,
        storyline.arc ? `STORY SO FAR: ${storyline.arc}` : null,
        storyline.currentChapter ?
            `CURRENT CHAPTER: ${storyline.currentChapter.dasha || ""} — ${storyline.currentChapter.throughline || ""}` :
            null,
    ].filter(Boolean).join("\n");

    const dasha = dashaContext || {};
    const dashaBlock = [
        `DASHA CHAPTER: ${dasha.period || "Unknown"} (${dasha.phase || "ACTIVE"}, ${dasha.percentComplete ?? "?"}% through)`,
        dasha.phaseGuidance ? `GUIDANCE: ${dasha.phaseGuidance}` : null,
        dasha.recentThemes?.length ? `RECENT THEMES: ${dasha.recentThemes.join(", ")}` : null,
    ].filter(Boolean).join("\n");

    const signalLines = (signals || []).map((d) => {
        const fav = d.favorable?.length ? ` | good: ${d.favorable.join("; ")}` : "";
        const unfav = d.unfavorable?.length ? ` | caution: ${d.unfavorable.join("; ")}` : "";
        return `${d.date}  alignment=${d.alignment}/100  tara=${d.tara || "-"}${fav}${unfav}`;
    }).join("\n");

    return `PERSON
${chartLine}
${memoryBlock || "(no memory yet — write a fresh, welcoming arc)"}

${dashaBlock}

DAY SIGNALS (ground truth — one line per day; write a matching narrative for each):
${signalLines}

Write the continuous forecast now. Output strict JSON per the schema.`;
}
