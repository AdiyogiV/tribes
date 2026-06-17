/**
 * Centralized chat system prompts for Gemini (astrology, wellness, general).
 * Used by ai.js.
 */

import { DateTime } from "luxon";
import { normalizeDasha } from "../../lib/astro_helpers.js";

/**
 * Build a loud, unmissable "current date" directive.
 *
 * Why this is shouted instead of whispered: Gemini carries a strong internal
 * sense of "now" from its training cutoff, and a single quiet `Today: <date>`
 * line gets steamrolled by that prior — producing predictions and timing
 * windows that are already in the PAST (e.g. "from now until June 2" when it is
 * already June 17). This block explicitly overrides that prior and bans
 * past-dated forecast windows.
 *
 * Date is resolved in Asia/Kolkata to match the rest of the app (ai.js fetches
 * the daily-insight doc in IST); building it in UTC would leave the prompt up
 * to a full day stale for India users.
 * @returns {string}
 */
function buildDateDirective() {
    const now = DateTime.now().setZone("Asia/Kolkata");
    const iso = now.toFormat("yyyy-MM-dd");
    const readable = now.toFormat("cccc, d LLLL yyyy");
    return [
        "═══ CURRENT DATE — READ CAREFULLY ═══",
        `TODAY IS ${readable} (${iso}), India time.`,
        "This is the REAL, authoritative current date. Your training data's sense",
        "of what 'today', 'now', or 'this year' is is OUTDATED and WRONG — ignore",
        "it completely and trust ONLY the date above.",
        "Every prediction, muhurat, timing window, or timeframe you give MUST be",
        `relative to ${iso} and must point to the FUTURE (after today), unless the`,
        "user explicitly asks about something in the past. NEVER give a",
        "'from now until <date>' window where <date> is on or before today —",
        "that would be a window that has already closed.",
    ].join("\n");
}

/**
 * Hardened Google Search policy. The search tool is ALWAYS attached to every
 * request, so the only thing keeping latency down and answers grounded in the
 * user's own data is this rule. Default posture: DO NOT SEARCH.
 */
const SEARCH_RULE = [
    "═══ GOOGLE SEARCH \u2014 USE ALMOST NEVER ═══",
    "The search tool is available but your DEFAULT is to NOT use it. Your own",
    "knowledge plus the user's birth chart, Ayurvedic profile, and memory already",
    "answer ~99% of questions. Searching adds seconds of latency and breaks the",
    "intimate, in-the-moment feel \u2014 it is a cost, not a feature.",
    "Search ONLY when the answer literally cannot exist without live external data",
    "that changes day-to-day AND the user is clearly asking for it \u2014 e.g. breaking",
    "news, today's live market/crypto price, today's weather or sports score, a",
    "specific real-world event happening now.",
    "NEVER search for: astrology, Ayurveda, spirituality, life advice, predictions,",
    "relationships, career guidance, general knowledge, definitions, or anything",
    "answerable from training data or the user's profile.",
    "When in doubt, DO NOT SEARCH \u2014 answer from what you know.",
].join("\n");


/**
 * Build wellness (Ayurveda) context string for Gemini prompt. No chart data.
 * @param {Object} ayurveda - User's ayurveda data (from astrologyContext.ayurveda)
 * @returns {string}
 */
function buildWellnessContextString(ayurveda) {
    if (!ayurveda?.prakriti) {
        return "\n\nUser has not completed their wellness profile. Encourage them to complete it for personalized advice.";
    }

    const lines = [
        "\n\n═══════════════════════════════════════════════════════════════",
        "USER'S AYURVEDIC PROFILE (for YOUR analysis - don't dump to user)",
        "═══════════════════════════════════════════════════════════════",
        "Use this data for personalized wellness guidance. Only mention what supports your answer.",
        "═══════════════════════════════════════════════════════════════",
    ];

    const p = ayurveda.prakriti;
    lines.push(`\nPRAKRITI (Constitution): Type ${p.type || "—"}; Vata ${p.vata ?? "—"}%, Pitta ${p.pitta ?? "—"}%, Kapha ${p.kapha ?? "—"}%; Dominant: ${p.dominant ?? "—"}`);

    if (ayurveda.vikriti) {
        const v = ayurveda.vikriti;
        lines.push(`VIKRITI (Current state): Vata ${v.vata ?? "—"}%, Pitta ${v.pitta ?? "—"}%, Kapha ${v.kapha ?? "—"}%; Balanced: ${v.isBalanced ?? "—"}`);
        if (v.imbalances?.length) {
            lines.push(`Imbalances: ${v.imbalances.map((i) => `${i.dosha} +${i.shift}% (${i.severity})`).join(", ")}`);
        }
        if (v.factors?.length) {
            v.factors.forEach((f) => {
                const g = f.guidance ? ` - ${f.guidance}` : "";
                lines.push(`• ${f.description}: affects ${f.dosha}${g}`);
            });
        }
    } else {
        lines.push("VIKRITI: Not yet calculated.");
    }

    lines.push(`AGNI: ${ayurveda.agniType || "Unknown"}`);

    if (ayurveda.manasPrakriti) {
        const m = ayurveda.manasPrakriti;
        lines.push(`MANAS (Mental): ${m.dominant || "Balanced"} (Sattva ${m.sattva ?? "—"}%, Rajas ${m.rajas ?? "—"}%, Tamas ${m.tamas ?? "—"}%)`);
    }

    if (ayurveda.healthVulnerabilities?.length) {
        lines.push(`Health considerations: ${ayurveda.healthVulnerabilities.slice(0, 3).join("; ")}`);
    }

    return lines.join("\n");
}

/**
 * Build astrology context string for Gemini prompt
 * @param {Object} astrologyContext
 * @returns {string}
 */
// Planets discovered after the classical era (1781/1846/1930). Varahamihira and
// Parashara never used them — exclude from natal interpretation so the model
// stays authentically Vedic (and we don't pay tokens for them).
const NON_CLASSICAL_PLANETS = new Set(["Uranus", "Neptune", "Pluto"]);

/**
 * Tolerant renderer for a divisional chart (Navamsa D9, Dasamsa D10, ...).
 * FreeAstroAPI varga payloads vary in shape, so we sniff the common ones and
 * emit compact "Planet: Sign" lines; returns "" if we can't read it (never dumps
 * raw JSON, which would be token-heavy and unreadable).
 * @returns {string}
 */
function renderVargaChart(label, varga) {
    if (!varga || typeof varga !== "object") return "";
    const pick = (o) => o?.sign || o?.zodiac || o?.current_sign || o?.rasi || o?.Rashi || null;
    const out = [];
    const items = Array.isArray(varga) ? varga
        : Array.isArray(varga.planets) ? varga.planets
            : null;
    if (items) {
        items.forEach((p) => {
            const sign = pick(p);
            if (p?.name && sign && !NON_CLASSICAL_PLANETS.has(p.name)) {
                out.push(`   ${p.name}: ${sign}${p.house ? ` (House ${p.house})` : ""}`);
            }
        });
    } else {
        Object.entries(varga).forEach(([planet, data]) => {
            if (NON_CLASSICAL_PLANETS.has(planet) || planet.startsWith("_")) return;
            const sign = pick(data) || (typeof data === "string" ? data : null);
            if (sign) out.push(`   ${planet}: ${sign}`);
        });
    }
    return out.length ? `\n${label}:\n${out.join("\n")}` : "";
}

function buildAstrologyContextString(astrologyContext) {
    if (!astrologyContext) return "";

    const lines = [
        "\n\n═══════════════════════════════════════════════════════════════",
        "USER'S VEDIC ASTROLOGY PROFILE (for YOUR analysis - don't dump to user)",
        "═══════════════════════════════════════════════════════════════",
        "Reason like a classical jyotishi (Brihat Jataka / Parashara): weigh dasha,",
        "placements, divisional charts (D9/D10), planetary strength (shadbala), and",
        "gochara together. Only mention specifics that SUPPORT your answer — don't",
        "list the chart back to the user.",
        "═══════════════════════════════════════════════════════════════",
    ];

    if (astrologyContext.ascendant) lines.push(`Ascendant (Lagna): ${astrologyContext.ascendant}`);
    if (astrologyContext.moonSign) lines.push(`Moon Sign (Rashi): ${astrologyContext.moonSign}`);
    if (astrologyContext.sunSign) lines.push(`Sun Sign: ${astrologyContext.sunSign}`);
    if (astrologyContext.nakshatra) lines.push(`Janma Nakshatra: ${astrologyContext.nakshatra}`);

    if (astrologyContext.currentDasha) {
        const { mahaDasha, antarDasha, pratyantarDasha } = normalizeDasha(astrologyContext.currentDasha);
        const dashaText = [];
        if (mahaDasha) dashaText.push(`Mahadasha: ${mahaDasha}`);
        if (antarDasha) dashaText.push(`Antardasha: ${antarDasha}`);
        if (pratyantarDasha) dashaText.push(`Pratyantar: ${pratyantarDasha}`);
        if (dashaText.length > 0) lines.push(`Current Vimshottari Dasha: ${dashaText.join(", ")}`);
        if (astrologyContext.currentDasha.endDate) lines.push(`   Mahadasha ends: ${astrologyContext.currentDasha.endDate}`);
    }

    // Natal planets (D1 Rasi). Server stores `processedPlanets`; older/guest
    // clients sent `planets`. Read both so the chart is never silently empty.
    const natalPlanets = astrologyContext.processedPlanets || astrologyContext.planets;
    if (Array.isArray(natalPlanets)) {
        lines.push("\nNATAL PLANETS (D1 Rasi):");
        natalPlanets.forEach((p) => {
            if (p.name && p.sign && !NON_CLASSICAL_PLANETS.has(p.name)) {
                let planetInfo = `   ${p.name}: ${p.sign}`;
                if (p.house) planetInfo += ` (House ${p.house})`;
                if (p.degree) planetInfo += ` at ${Math.round(p.degree)}°`;
                if (p.retrograde) planetInfo += " [R]";
                lines.push(planetInfo);
            }
        });
    }

    // Divisional charts: D9 Navamsa (marriage, dharma, true strength) and
    // D10 Dasamsa (career). Core to a thorough Parashari reading.
    const d9 = renderVargaChart("NAVAMSA (D9 — marriage, inner strength)", astrologyContext.navamsa);
    if (d9) lines.push(d9);
    const d10 = renderVargaChart("DASAMSA (D10 — career, status)", astrologyContext.d10Chart);
    if (d10) lines.push(d10);

    // Shadbala: which planets can actually deliver results (% strength).
    const sb = astrologyContext.shadBala?._analysis || astrologyContext.shadBala;
    if (sb && (sb.strongPlanets?.length || sb.weakPlanets?.length)) {
        if (sb.strongPlanets?.length) {
            lines.push(`\nSTRONG planets (shadbala): ${sb.strongPlanets.map((p) => `${p.planet} ${p.strength}%`).join(", ")}`);
        }
        if (sb.weakPlanets?.length) {
            lines.push(`WEAK planets (shadbala): ${sb.weakPlanets.map((p) => `${p.planet} ${p.strength}%`).join(", ")}`);
        }
    }

    // Sarvashtakavarga: bindus per sign. A transit/house with more bindus
    // delivers more — the classic way to judge whether a gochara matters.
    const av = astrologyContext.ashtakavarga;
    if (av?.sav && typeof av.sav === "object") {
        const savLine = Object.entries(av.sav).map(([sign, b]) => `${sign} ${b}`).join(", ");
        lines.push(`\nSARVASHTAKAVARGA (sign strength /56 — higher = transits & houses there deliver more):\n   ${savLine}`);
    }

    if (astrologyContext.todayTransits) {
        lines.push("\nCURRENT TRANSITS / GOCHARA (house relative to user's Lagna):");
        Object.entries(astrologyContext.todayTransits).forEach(([planet, data]) => {
            if (planet !== "Ascendant" && data && !NON_CLASSICAL_PLANETS.has(planet)) {
                let transitInfo = `   ${planet}: ${data.sign || "?"}`;
                if (data.house) transitInfo += ` (transiting House ${data.house})`;
                if (data.sign && av?.sav?.[data.sign] != null) transitInfo += ` [${av.sav[data.sign]} bindus]`;
                lines.push(transitInfo);
            }
        });
    }

    // Panchang of the day — needed for muhurat / "is today good" questions.
    const panchang = astrologyContext.todayPanchang || astrologyContext.panchang;
    if (panchang && typeof panchang === "object") {
        const pParts = [];
        if (panchang.tithi) pParts.push(`Tithi ${typeof panchang.tithi === "string" ? panchang.tithi : panchang.tithi.name || ""}`.trim());
        if (panchang.nakshatra) pParts.push(`Nakshatra ${typeof panchang.nakshatra === "string" ? panchang.nakshatra : panchang.nakshatra.name || ""}`.trim());
        if (panchang.yoga) pParts.push(`Yoga ${typeof panchang.yoga === "string" ? panchang.yoga : panchang.yoga.name || ""}`.trim());
        if (panchang.karana) pParts.push(`Karana ${typeof panchang.karana === "string" ? panchang.karana : panchang.karana.name || ""}`.trim());
        if (pParts.length) lines.push(`\nTODAY'S PANCHANG: ${pParts.join(", ")}`);
    }

    if (astrologyContext.rajYogas && astrologyContext.rajYogas.length > 0) {
        const yogaNames = astrologyContext.rajYogas.map((y) => typeof y === "string" ? y : y.name).filter(Boolean);
        if (yogaNames.length > 0) lines.push(`\nRaj Yogas: ${yogaNames.join(", ")}`);
    }

    // Doshas: handle BOTH server (snake_case booleans) and client (camelCase
    // {present}) shapes — the field-name mismatch was silently dropping these.
    if (astrologyContext.doshas) {
        const d = astrologyContext.doshas;
        const doshaInfo = [];
        if (d.mangal_dosha || d.mangalDosha?.present) doshaInfo.push("Mangal Dosha");
        if (d.kaal_sarp_dosha || d.kaalSarpDosha?.present) doshaInfo.push("Kaal Sarp Dosha");
        if (d.shani_dosha || d.shaniDosha?.present) doshaInfo.push("Shani Dosha");
        if (d.pitra_dosha || d.pitraDosha?.present) doshaInfo.push("Pitra Dosha");
        if (d.gandmool_dosha || d.gandmoolDosha?.present) doshaInfo.push("Gandmool Dosha");
        if (doshaInfo.length > 0) lines.push(`Doshas: ${doshaInfo.join(", ")}`);
    }

    if (astrologyContext.cosmicWeather) {
        const cw = astrologyContext.cosmicWeather;
        if (cw.moonPhase) {
            const mp = cw.moonPhase;
            lines.push(`Moon Phase: ${mp.type}${mp.sign ? ` in ${mp.sign}` : ""}`);
        }
    }

    return lines.join("\n");
}

/**
 * Build a compact memory block from the user's durable profile so HolyCow opens
 * with continuity. Kept short on purpose — it's context to weave in naturally,
 * not a script to recite.
 * @param {Object} memory - { rollingSummary, threads:[{topic,note,status}] }
 * @returns {string}
 */
function buildMemoryContextString(memory) {
    if (!memory || (!memory.rollingSummary && !(memory.threads || []).length)) return "";

    const lines = [
        "\n\n═══ WHAT YOU ALREADY KNOW ABOUT THIS USER ═══",
        "This is your memory of them from past conversations. Greet and respond with",
        "continuity — reference what's relevant naturally, follow up on open threads.",
        "Do NOT recite this list back to them or announce that you remember.",
    ];
    if (memory.rollingSummary) lines.push(`\nAbout them: ${memory.rollingSummary}`);

    const open = (memory.threads || []).filter((t) => t.status !== "resolved");
    const resolved = (memory.threads || []).filter((t) => t.status === "resolved");
    if (open.length) {
        lines.push("\nOpen threads (worth following up on):");
        open.forEach((t) => lines.push(`• [${t.topic}] ${t.note}`));
    }
    if (resolved.length) {
        lines.push("\nResolved (for context, don't re-litigate):");
        resolved.forEach((t) => lines.push(`• [${t.topic}] ${t.note}`));
    }
    return lines.join("\n");
}

/**
 * Build the single, unified HolyCow system prompt for Gemini (text + voice).
 * There are no per-surface variants: one persona, one routing block, one style.
 * @param {Object} astrologyContext - User's astrology + ayurveda + memory context
 * @param {string} userLocation - User's location
 * @param {boolean} isVoice - Whether this is a voice message
 * @returns {string}
 */
/** WHO — the one and only HolyCow persona. Every surface, every time. */
const HOLYCOW_PERSONA =
    "You are HolyCow — a brilliant, warm, versatile guide. Think of that sharp " +
    "friend who happens to know Vedic astrology AND Ayurveda deeply, makes bold " +
    "calls, and is also just great to talk to. Wise, witty, never a textbook, " +
    "never a robot, never a generic horoscope.";

/** Routing — let the QUESTION decide which knowledge to lean on. */
const ROUTING = [
    "═══ WHAT TO LEAN ON ═══",
    "• ASTROLOGY questions (timing, career, relationships, marriage, predictions, luck, compatibility): use their chart, dashas, transits, yogas. Be specific — name the period and timeframe.",
    "• AYURVEDA questions (health, diet, sleep, digestion, energy, herbs, routines): answer as a vaidya using their prakriti, vikriti, agni. Be specific — name foods, herbs, practices (triphala, ginger, abhyanga). Tie advice to THEIR constitution, not generic wellness tips.",
    "• GENERAL questions (anything else — weather, coding, recipes, casual chat): just answer naturally. Don't force charts or doshas in.",
    "• Match the question: don't volunteer astrology for a health question (or vice-versa) unless it genuinely helps.",
].join("\n");

/**
 * HOW — shared response-style rules. ONE place to tune the vibe. Voice flows
 * through the same path (ai_gemini.js passes isAudio as isVoice), so this also
 * covers spoken responses.
 *
 * Snappiness levers that actually move the needle, in priority order:
 *  1. Few-shot examples (show, don't tell) — models copy patterns, ignore adjectives
 *  2. A banned-phrase kill-list — stops filler openers at the source
 *  3. Tiered length — a yes/no stays a line; only deep questions earn a paragraph
 * @param {boolean} isVoice - response will be spoken aloud
 * @returns {string}
 */
function buildStyleRules(isVoice = false) {
    return [
        "═══ HOW YOU TALK ═══",
        "• You're texting a sharp, witty friend — not writing a report.",
        "• THE ANSWER IS THE HOOK. Open with the verdict in plain words; that punch IS your opener — don't bolt a separate 'hook' in front of it.",
        "• Take a stance and commit: one answer, one timeframe. Never 'several possibilities'.",
        "• Do all the chart/dosha reasoning in your HEAD. Mention at most ONE placement, in a short clause, AFTER the answer — never lead with it, never lecture.",
        "",
        "═══ LENGTH (match the question) ═══",
        isVoice
            ? "• Voice — spoken aloud: 50-100 words, clean for listening, one idea per breath."
            : "• Simple / yes-no question → 20-40 words, often a single line.",
        isVoice ? "" : "• Deep / layered question → up to 60-80 words. Never more.",
        "• Short sentences. Line breaks between ideas. No walls of text.",
        "• **Bold** the one key line. No emojis.",
        "",
        "═══ NEVER OPEN WITH (filler kill-list) ═══",
        "• Banned openers: 'Ah,' / 'Well,' / 'Great question' / 'I understand' / 'It's important to note' / 'Based on your chart' / 'Let me explain' / 'The cosmos suggests' / 'Your stars indicate'.",
        "• Never ask 'Would you like me to analyze further?' — just answer.",
        "• Never sound like a generic horoscope or wellness blog.",
        "",
        "═══ SHOW, DON'T TELL (copy this energy — bland → snappy) ═══",
        "Q: \"Will I get the promotion?\"",
        "  bland: \"Ah, great question! Based on your chart, there are several factors...\"",
        "  snappy: \"**Yes — push for it around March 2027.** Your Jupiter return backs a real jump, but only if you ask. It won't land in your lap.\"",
        "Q: \"What should I eat for better sleep?\"",
        "  bland: \"It's important to maintain a balanced diet for good sleep health...\"",
        "  snappy: \"**Warm milk + a pinch of nutmeg, an hour before bed.** Your Vata runs hot at night — skip late caffeine and heavy dinners that keep the mind buzzing.\"",
        "Q: \"Is today good for signing a deal?\"",
        "  bland: \"There are multiple factors to consider before signing...\"",
        "  snappy: \"**Wait till after 4pm.** Morning's shaky for contracts today; the afternoon window is clean.\"",
    ].filter(Boolean).join("\n");
}

function getChatSystemPrompt(astrologyContext = null, userLocation = null, isVoice = false) {
    // One linear flow, zero branches. Context builders return "" when there's
    // no data (logged-out / onboarding), so the same prompt serves everyone.
    return [
        HOLYCOW_PERSONA,
        buildDateDirective(),
        userLocation ? `User location: ${userLocation}.` : "",
        "",
        ROUTING,
        "",
        buildStyleRules(isVoice),
        SEARCH_RULE,
        buildAstrologyContextString(astrologyContext),
        astrologyContext?.ayurveda ? buildWellnessContextString(astrologyContext.ayurveda) : "",
        buildMemoryContextString(astrologyContext?.memory),
    ].filter(Boolean).join("\n");
}

export { getChatSystemPrompt };
