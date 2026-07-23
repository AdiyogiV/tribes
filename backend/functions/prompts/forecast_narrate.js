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
      "publicNote": "≤12 words, THIRD-PERSON, shareable — how this person is doing today, written for a FRIEND to read (use 'they'/their name, NEVER 'you'); must match the alignment; warm, plain, no jargon, no advice",
      "action": "one concrete action for the day",
      "caution": "one practical thing to avoid or handle gently",
      "tip": "one short, grounded wellbeing or reflection tip",
      "timing": "short timing guidance grounded only in the supplied signals; say 'Move at your natural pace' when no timing signal exists",
      "goodFor": ["2-4 word phrase", "..."],
      "avoid": ["2-4 word phrase", "..."]
    }
  ],
  "ayurvedaGuidance": {
    "vata":     { "focus": "one line: what this state needs", "food": ["2-4 word item", "..."], "practice": ["2-4 word item", "..."] },
    "pitta":    { "focus": "...", "food": ["..."], "practice": ["..."] },
    "kapha":    { "focus": "...", "food": ["..."], "practice": ["..."] },
    "balanced": { "focus": "...", "food": ["..."], "practice": ["..."] }
  },
  "storylineUpdate": {
    "arc": "the whole journey so far compressed to ONE paragraph (summary-of-summaries), updated with this chapter",
    "beatGist": "one line capturing the gist of the period just narrated",
    "threads": [ { "theme": "short label", "note": "what to watch", "status": "open" } ]
  }
}

DO / AVOID (per day): goodFor and avoid are short editorial lists (2-3 items each) of what the DAY favors and what to ease off, grounded ONLY in that day's alignment and supplied signals. High alignment → expansive favors; low → restorative, protective. No jargon, no clock times.

AYURVEDA GUIDANCE: You are also given the person's Ayurvedic constitution (Prakriti — fixed baseline) and their CURRENT dosha state (Vikriti). Write practical do-guidance for EACH possible current-imbalance state (vata / pitta / kapha aggravated, and balanced). The classical rule is OPPOSITES: pacify the aggravated dosha with opposite qualities (cool a hot Pitta, ground an erratic Vata, enliven a heavy Kapha). Personalize to THIS person's Prakriti as context — the same imbalance lands differently on different constitutions. 'food' = 2-3 dietary favors; 'practice' = 2-3 lifestyle/movement/mind practices; 'focus' = one warm line naming what that state needs. Write about the guidance itself — real, concrete food and practice — never about where the data came from. Plain language, no Sanskrit, no clock times.

Return a "days" entry for EVERY date given, in order. Keep headings distinct. Every daily field is required (including goodFor and avoid). The narrative is PRIVATE (second-person "you", the reader's own diary); the publicNote is PUBLIC (third-person, safe for a friend to see) — they describe the same day but must never be swapped. Keep action, caution, tip, and timing practical and under 18 words each. Do not invent exact clock times. Include "ayurvedaGuidance" with all four buckets ONLY when Ayurveda context is provided below; otherwise omit it entirely.`;

/**
 * Build the user prompt for NARRATE.
 *
 * @param {Object} args
 * @param {Object} args.person   { chartSummary, rollingSummary, threads[], storyline }
 * @param {Array}  args.signals  [{date, alignment, tara, favorable[], unfavorable[]}]
 * @param {Object} args.dashaContext  from buildDashaContext()
 * @param {Object} [args.ayurveda]  { prakriti, vikriti, vulnerabilities } (optional)
 * @returns {string}
 */
export function buildNarratePrompt({ person, signals, dashaContext, ayurveda }) {
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

    const ayurvedaBlock = buildAyurvedaBlock(ayurveda);

    return `PERSON
${chartLine}
${memoryBlock || "(no memory yet — write a fresh, welcoming arc)"}

${dashaBlock}
${ayurvedaBlock ? `\n${ayurvedaBlock}\n` : ""}
DAY SIGNALS (ground truth — one line per day; write a matching narrative for each):
${signalLines}

Write the continuous forecast now. Output strict JSON per the schema.`;
}

/**
 * Build the optional AYURVEDA context block. Returns "" when there is no
 * constitution data (the model then omits ayurvedaGuidance entirely).
 */
function buildAyurvedaBlock(ayurveda) {
    if (!ayurveda || !ayurveda.prakriti) return "";
    const pk = ayurveda.prakriti;
    const vk = ayurveda.vikriti;
    const vuln = ayurveda.vulnerabilities;

    const lines = ["AYURVEDA (constitution context for ayurvedaGuidance):"];
    lines.push(`PRAKRITI (fixed baseline): ${pk.type || pk.dominant || "?"} — Vata ${pk.vata ?? "?"}%, Pitta ${pk.pitta ?? "?"}%, Kapha ${pk.kapha ?? "?"}%`);

    if (vk) {
        const imb = (vk.imbalances || [])
            .map((i) => `${i.dosha} +${i.shift}% (${i.severity})`).join(", ");
        lines.push(`VIKRITI (current state): Vata ${vk.vata ?? "?"}%, Pitta ${vk.pitta ?? "?"}%, Kapha ${vk.kapha ?? "?"}% — ${vk.balanced ? "balanced" : `aggravated: ${imb || "mild drift"}`}`);
    }
    if (Array.isArray(vuln) && vuln.length) {
        lines.push(`HEALTH TENDENCIES: ${vuln.slice(0, 3).map((v) => v.description || v).join("; ")}.`);
    }
    return lines.join("\n");
}
