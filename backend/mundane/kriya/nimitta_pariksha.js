/**
 * क्रिया ४ — निमित्त परीक्षा (Nimitta Pariksha: Omen Observation)
 *
 * "Before speaking his reading, the Jyotishi observes the world —
 *  the flight of birds, tremors in the earth, the mood of the people.
 *  These are the Nimitta, the earthly signs that SHAPE the reading."
 *
 * Varahamihira dedicated Ch.19-95 to earthly omens. We use Google News
 * as our modern Nimitta — the world's observable signs.
 *
 * CRITICAL CHANGE: News is NOT just validation. It INFORMS predictions.
 * A real Jyotishi observes the world BEFORE speaking. Domain heat from
 * news boosts relevant astrological effects — this is how Nimitta
 * shapes the reading, not just confirms it after the fact.
 *
 * Uses existing backend lib/news_feed.js — no reinventing RSS parsing.
 */

import { DOMAINS, getNewsKeywords } from "../adhyaya/vishaya.js";
import { fetchNewsHeadlines, formatNewsForPrompt } from "../../lib/news_feed.js";

/**
 * Fetch world headlines using existing backend infrastructure.
 * Wraps lib/news_feed.js — single source of truth for news fetching.
 *
 * @param {string} [_query] - Ignored (kept for API compat). Uses top world news.
 * @param {number} [maxResults=30] - Max headlines
 * @returns {Promise<{headlines: Object[], error: string|null}>}
 */
export async function fetchHeadlines(_query, maxResults = 30) {
    try {
        const headlines = await fetchNewsHeadlines({ limit: maxResults });
        return { headlines, error: null };
    } catch (err) {
        return { error: err.message, headlines: [] };
    }
}

/**
 * Fetch headlines and compute domain heat in one call.
 * This is the MAIN entry point for Nimitta — call BEFORE the rules engine.
 *
 * @param {number} [maxHeadlines=30] - Max headlines to fetch
 * @returns {Promise<{domainHeat: Object, headlines: Object[], newsText: string, error: string|null}>}
 */
export async function observeNimitta(maxHeadlines = 30) {
    const { headlines, error } = await fetchHeadlines(null, maxHeadlines);
    const domainHeat = computeDomainHeat(headlines);
    const newsText = formatNewsForPrompt(headlines);

    return {
        domainHeat,
        headlines,
        newsText,
        headlineCount: headlines.length,
        error,
        timestamp: new Date().toISOString(),
    };
}

// ─── Domain Classification ───────────────────────────────────────────────

/**
 * Classify a headline into mundane domains using keyword matching.
 * Returns ALL matching domains with match strength.
 *
 * @param {string} headline
 * @returns {Object[]} [{ domain, label, matchCount, keywords }]
 */
export function classifyHeadline(headline) {
    const lower = headline.toLowerCase();
    const matches = [];

    for (const [domain, info] of Object.entries(DOMAINS)) {
        const keywords = info.newsKeywords || [];
        const matched = keywords.filter(kw => lower.includes(kw.toLowerCase()));

        if (matched.length > 0) {
            matches.push({
                domain,
                label: info.label,
                matchCount: matched.length,
                keywords: matched,
            });
        }
    }

    return matches.sort((a, b) => b.matchCount - a.matchCount);
}

/**
 * Compute domain "heat map" from a batch of headlines.
 * How much real-world activity is happening in each domain?
 *
 * Now includes sentiment aggregation: avgSentiment per domain tells us
 * whether the domain activity is positive or negative.
 *
 * @param {Object[]} headlines - [{ title, sentiment?, ... }]
 * @returns {Object} { domain: { count, heat, normalizedHeat, avgSentiment, headlines } }
 */
export function computeDomainHeat(headlines) {
    const heat = {};

    for (const h of headlines) {
        const domains = classifyHeadline(h.title);
        for (const d of domains) {
            if (!heat[d.domain]) {
                heat[d.domain] = { count: 0, heat: 0, label: d.label, headlines: [], sentimentSum: 0 };
            }
            heat[d.domain].count++;
            heat[d.domain].heat += d.matchCount;
            heat[d.domain].headlines.push(h.title);
            // Accumulate sentiment if available (from news_archive.js scoreHeadlineSentiment)
            heat[d.domain].sentimentSum += (h.sentiment ?? 0);
        }
    }

    // Normalize heat to 0-1 scale + compute average sentiment per domain
    const maxHeat = Math.max(1, ...Object.values(heat).map(d => d.heat));
    for (const d of Object.values(heat)) {
        d.normalizedHeat = Math.round((d.heat / maxHeat) * 100) / 100;
        d.avgSentiment = d.count > 0 ? Math.round((d.sentimentSum / d.count) * 100) / 100 : 0;
        delete d.sentimentSum; // cleanup internal field
    }

    return heat;
}

// ─── Prediction Validation ───────────────────────────────────────────────

/**
 * Validate active predictions against real news.
 *
 * PAKA-AWARE: Only validates effects that have PASSED their manifestation
 * peak date (BS Ch.97). Saturn effects from April 2025 won't be validated
 * until April 2026. Sun effects validate within 15 days.
 *
 * Effects without manifestation data or with peakDate in the past are validated.
 * Effects whose peakDate is still in the future are SKIPPED (too early to judge).
 *
 * @param {Object[]} effects - Active effects from applyAllRules()
 * @param {Object} domainHeat - Output from computeDomainHeat()
 * @param {string} [currentDate] - ISO date for PAKA comparison. Defaults to today.
 * @returns {Object[]} Validation results for each significant effect
 */
export function validatePredictions(effects, domainHeat, currentDate = null) {
    const validations = [];
    const now = currentDate ? new Date(currentDate) : new Date();

    // Group effects by domain
    const byDomain = {};
    for (const e of effects) {
        if (!byDomain[e.domain]) byDomain[e.domain] = [];
        byDomain[e.domain].push(e);
    }

    for (const [domain, domainEffects] of Object.entries(byDomain)) {
        const heat = domainHeat[domain];
        const hasNewsActivity = heat && heat.count > 0;
        const heatLevel = heat?.normalizedHeat || 0;

        for (const effect of domainEffects) {
            // Only validate effects with significant weight
            if (effect.weight < 0.3) continue;

            // ── PAKA CHECK: Is this effect ripe for validation? ──────────
            // If effect has a peakDate and it's still in the future, skip it.
            // "Saturn's effects take ~1 year to manifest. Do not judge early."
            if (effect.manifestation?.peakDate) {
                const peakStr = effect.manifestation.peakDate;
                // peakDate can be "YYYY-MM-DD" or "~Mon YYYY"
                let peakDate;
                if (peakStr.startsWith("~")) {
                    // "~Apr 2027" → parse to first of that month
                    const parts = peakStr.slice(1).split(" ");
                    const monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
                    const monthIdx = monthNames.indexOf(parts[0]);
                    peakDate = new Date(parseInt(parts[1]), monthIdx >= 0 ? monthIdx : 0, 1);
                } else {
                    peakDate = new Date(peakStr);
                }

                if (peakDate > now) {
                    // Not yet ripe — skip validation
                    continue;
                }
            }

            let evidence, reason;
            const sentiment = heat?.avgSentiment ?? 0; // -1.0 to +1.0

            if (!hasNewsActivity) {
                // No news in this domain — weak signal either way
                evidence = 0.45; // Slightly below neutral
                reason = `No headlines matched domain "${domain}"`;
            } else if (effect.dir === "neg" && heatLevel > 0.5 && sentiment <= 0) {
                // Negative prediction + high domain activity + negative sentiment = strong confirmation
                evidence = 0.75 + heatLevel * 0.2;
                reason = `Negative prediction confirmed: ${heat.count} headlines in ${domain} (heat: ${heatLevel}, sentiment: ${sentiment})`;
            } else if (effect.dir === "neg" && heatLevel > 0.5 && sentiment > 0) {
                // Negative prediction + high domain activity + POSITIVE sentiment = contradictory
                evidence = 0.4;
                reason = `Predicted disruption in ${domain} but news sentiment is positive (${sentiment})`;
            } else if (effect.dir === "pos" && heatLevel > 0.5 && sentiment >= 0) {
                // Positive prediction + high activity + positive/neutral sentiment = confirmation
                evidence = 0.7 + sentiment * 0.15;
                reason = `Positive prediction supported: ${heat.count} headlines in ${domain} (heat: ${heatLevel}, sentiment: ${sentiment})`;
            } else if (effect.dir === "pos" && heatLevel > 0.5 && sentiment < 0) {
                // Positive prediction + high activity + negative sentiment = contradictory
                evidence = 0.35;
                reason = `Predicted growth in ${domain} but news sentiment is negative (${sentiment})`;
            } else if (effect.dir === "neg" && heatLevel < 0.2) {
                // Negative prediction + quiet domain = possible contradiction
                evidence = 0.35;
                reason = `Predicted disruption in ${domain} but domain is quiet (heat: ${heatLevel})`;
            } else {
                // Moderate activity — use sentiment to tilt
                evidence = 0.5 + (effect.dir === "neg" ? -sentiment * 0.1 : sentiment * 0.1);
                reason = `Moderate: ${heat?.count || 0} headlines, heat ${heatLevel}, sentiment ${sentiment}`;
            }

            validations.push({
                ruleId: effect.ruleId,
                domain,
                planet: effect.planet,
                sign: effect.sign,
                prediction: effect.desc,
                direction: effect.dir,
                weight: effect.weight,
                evidence: Math.round(evidence * 100) / 100,
                reason,
                headlineCount: heat?.count || 0,
                sampleHeadlines: (heat?.headlines || []).slice(0, 3),
            });
        }
    }

    return validations.sort((a, b) => Math.abs(b.evidence - 0.5) - Math.abs(a.evidence - 0.5));
}

// ─── Full Validation Pipeline ────────────────────────────────────────────

/**
 * Run the full Nimitta validation pipeline:
 *   1. Fetch headlines for active domains
 *   2. Classify into domains
 *   3. Compare with predictions
 *   4. Return validation results ready for confidence updates
 *
 * @param {Object[]} effects - Active effects from applyAllRules()
 * @param {Object} [options]
 * @param {string[]} [options.extraQueries] - Additional search queries
 * @returns {Promise<Object>} { validations, domainHeat, headlineCount, errors }
 */
export async function runValidationPipeline(effects, options = {}) {
    const { extraQueries = [] } = options;

    // Determine which domains to search for
    const activeDomains = [...new Set(effects.filter(e => e.weight >= 0.3).map(e => e.domain))];
    const topDomains = activeDomains.slice(0, 8); // Don't flood with queries

    // Build search queries from domain keywords
    const queries = [
        "world news today major events",
        ...topDomains.map(d => {
            const keywords = (DOMAINS[d]?.newsKeywords || []).slice(0, 3);
            return keywords.join(" OR ");
        }).filter(q => q.length > 0),
        ...extraQueries,
    ];

    // Fetch all headlines
    const allHeadlines = [];
    const errors = [];

    for (const query of queries) {
        const result = await fetchHeadlines(query, 15);
        if (result.error) {
            errors.push({ query, error: result.error });
        }
        allHeadlines.push(...result.headlines);
    }

    // Deduplicate by title
    const seen = new Set();
    const uniqueHeadlines = allHeadlines.filter(h => {
        if (seen.has(h.title)) return false;
        seen.add(h.title);
        return true;
    });

    // Classify and compute heat
    const domainHeat = computeDomainHeat(uniqueHeadlines);

    // Validate predictions
    const validations = validatePredictions(effects, domainHeat);

    return {
        validations,
        domainHeat,
        headlineCount: uniqueHeadlines.length,
        queriesRun: queries.length,
        errors,
        timestamp: new Date().toISOString(),
    };
}
