/**
 * News Archive — Historical Headlines via The Guardian Open Platform
 *
 * Fetches REAL headlines for ANY past date (back to 1999).
 * Free API, no key needed for testing (use "test" as key).
 *
 * v2: Multi-query strategy for broader domain coverage.
 * Instead of just section=world (which misses religion, refugees, health, culture),
 * we now run:
 *   1. World news (general, top headlines)
 *   2. Domain-targeted queries for weak domains (religion, refugee, health, culture)
 * This dramatically improves coverage for domains that don't make world headlines.
 *
 * Also adds basic headline sentiment scoring using keyword polarity.
 *
 * Falls back to Google News RSS for today's headlines (existing lib/news_feed.js).
 *
 * Uses curl via child_process because Node's fetch has DNS issues
 * on the corporate network, while curl resolves fine.
 */

import { execSync } from "child_process";
import { fetchNewsHeadlines } from "./news_feed.js";

const GUARDIAN_API = "https://content.guardianapis.com/search";
const GUARDIAN_KEY = "test"; // Free test key. Register at open-platform.theguardian.com for production key.

// ─── Domain-targeted queries for weak coverage areas ─────────────────────
// These domains get 0% hit rate when only fetching section=world.
// Each query targets Guardian across ALL sections to find domain-specific headlines.
const DOMAIN_QUERIES = [
    { domains: ["religion"],    query: "religion OR spiritual OR church OR mosque OR temple OR faith OR pope OR imam" },
    { domains: ["refugees"],    query: "refugee OR asylum OR migrant OR displaced OR trafficking" },
    { domains: ["health"],      query: "health OR hospital OR disease OR epidemic OR pandemic OR vaccine OR outbreak" },
    { domains: ["culture"],     query: "art OR culture OR museum OR heritage OR exhibition" },
    { domains: ["infrastructure"], query: "infrastructure OR construction OR bridge OR dam OR railway" },
    { domains: ["agriculture"], query: "agriculture OR crop OR harvest OR famine OR drought OR farming" },
];

// ─── Sentiment Keywords ──────────────────────────────────────────────────
// Simple polarity scoring. Not NLP — just high-signal words.
const NEGATIVE_WORDS = [
    "kill", "killed", "dead", "death", "attack", "bomb", "war", "crisis",
    "disaster", "collapse", "scandal", "corruption", "fraud", "trafficking",
    "exploit", "abuse", "destroy", "threat", "fear", "panic", "epidemic",
    "famine", "drought", "flood", "earthquake", "tsunami", "violence",
    "clash", "conflict", "siege", "massacre", "genocide", "terror",
    "crash", "fail", "reject", "condemn", "worst", "brutal", "fatal",
    "strike", "sanction", "tariff", "recession", "layoff", "shutdown",
    "hack", "breach", "outage", "cyberattack", "disinformation",
];

const POSITIVE_WORDS = [
    "peace", "deal", "agree", "treaty", "breakthrough", "discover",
    "cure", "vaccine", "rescue", "save", "growth", "prosper", "flourish",
    "award", "celebrate", "triumph", "victory", "reform", "progress",
    "innovate", "launch", "succeed", "record", "boost", "recovery",
    "aid", "donate", "charity", "humanitarian", "reconcile", "ceasefire",
    "freedom", "justice", "release", "acquit", "thrive", "acclaim",
];

/**
 * Score headline sentiment: -1.0 (very negative) to +1.0 (very positive).
 * Returns 0.0 for neutral/ambiguous.
 *
 * @param {string} title - Headline text
 * @returns {number} Sentiment score
 */
export function scoreHeadlineSentiment(title) {
    const lower = title.toLowerCase();
    let neg = 0, pos = 0;

    for (const w of NEGATIVE_WORDS) {
        if (lower.includes(w)) neg++;
    }
    for (const w of POSITIVE_WORDS) {
        if (lower.includes(w)) pos++;
    }

    const total = neg + pos;
    if (total === 0) return 0;

    // Range: -1.0 to +1.0, weighted by signal density
    const raw = (pos - neg) / total;
    // Clamp and round
    return Math.round(Math.max(-1, Math.min(1, raw)) * 100) / 100;
}

/**
 * Fetch world news headlines for a specific date.
 * Now with multi-query strategy for broader domain coverage.
 *
 * - For today: uses Google News RSS (existing infrastructure)
 * - For past dates: uses Guardian API (real historical headlines)
 *
 * @param {string} dateStr - "YYYY-MM-DD"
 * @param {Object} [options]
 * @param {number} [options.limit=25] - Max world headlines
 * @param {boolean} [options.domainQueries=true] - Also run domain-targeted queries
 * @returns {Promise<{title: string, source: string, pubDate: string, sentiment?: number}[]>}
 */
export async function fetchHeadlinesForDate(dateStr, options = {}) {
    const { limit = 25, domainQueries = true } = options;
    const today = new Date().toISOString().split("T")[0];

    // For today, use existing Google News RSS
    if (dateStr === today) {
        const headlines = await fetchNewsHeadlines({ limit });
        return headlines.map(h => ({ ...h, sentiment: scoreHeadlineSentiment(h.title) }));
    }

    // For historical dates: world headlines + domain-specific queries
    const worldHeadlines = fetchGuardianHeadlines(dateStr, limit);

    let domainHeadlines = [];
    if (domainQueries) {
        domainHeadlines = fetchGuardianDomainHeadlines(dateStr);
    }

    // Merge and deduplicate by title
    const seen = new Set();
    const merged = [];
    for (const h of [...worldHeadlines, ...domainHeadlines]) {
        const key = h.title.toLowerCase().trim();
        if (seen.has(key)) continue;
        seen.add(key);
        merged.push({
            ...h,
            sentiment: scoreHeadlineSentiment(h.title),
        });
    }

    return merged;
}

/**
 * Fetch headlines from The Guardian Open Platform for a specific date.
 * World section — general top headlines.
 *
 * @param {string} dateStr - "YYYY-MM-DD"
 * @param {number} limit - Max results (max 50 per page)
 * @returns {{title: string, source: string, pubDate: string}[]}
 */
function fetchGuardianHeadlines(dateStr, limit = 25) {
    const pageSize = Math.min(limit, 50);
    const url = `${GUARDIAN_API}?section=world&from-date=${dateStr}&to-date=${dateStr}&page-size=${pageSize}&order-by=relevance&api-key=${GUARDIAN_KEY}`;

    try {
        const raw = execSync(`curl -s "${url}"`, {
            timeout: 15000,
            encoding: "utf-8",
        });

        const data = JSON.parse(raw);
        if (data.response?.status !== "ok" || !data.response?.results) {
            return [];
        }

        return data.response.results.map(r => ({
            title: r.webTitle,
            source: "The Guardian",
            section: r.sectionName || "World",
            pubDate: r.webPublicationDate || dateStr,
            link: r.webUrl,
        }));
    } catch (err) {
        console.warn(`Guardian API failed for ${dateStr}: ${err.message}`);
        return [];
    }
}

/**
 * Fetch domain-targeted headlines from Guardian.
 * Runs one query per weak domain to fill gaps that section=world misses.
 * Rate-limited: ~200ms between calls.
 *
 * @param {string} dateStr - "YYYY-MM-DD"
 * @returns {{title: string, source: string, section: string, pubDate: string, targetDomains: string[]}[]}
 */
function fetchGuardianDomainHeadlines(dateStr) {
    const allResults = [];

    for (const { domains, query } of DOMAIN_QUERIES) {
        const encoded = encodeURIComponent(query);
        const url = `${GUARDIAN_API}?q=${encoded}&from-date=${dateStr}&to-date=${dateStr}&page-size=5&order-by=relevance&api-key=${GUARDIAN_KEY}`;

        try {
            const raw = execSync(`curl -s "${url}"`, {
                timeout: 12000,
                encoding: "utf-8",
            });

            const data = JSON.parse(raw);
            if (data.response?.status === "ok" && data.response?.results) {
                for (const r of data.response.results) {
                    allResults.push({
                        title: r.webTitle,
                        source: "The Guardian",
                        section: r.sectionName || "General",
                        pubDate: r.webPublicationDate || dateStr,
                        link: r.webUrl,
                        targetDomains: domains, // which domains this query was targeting
                    });
                }
            }
        } catch {
            // Non-fatal — some queries may timeout
        }

        // Rate limit: be polite to Guardian's free API
        try { execSync("sleep 0.15"); } catch { /* ignore */ }
    }

    return allResults;
}

/**
 * Fetch headlines for multiple dates (with rate limiting).
 * Useful for backfilling a year of data.
 *
 * @param {string[]} dates - Array of "YYYY-MM-DD" strings
 * @param {number} [limit=25] - Headlines per date
 * @returns {Promise<Object>} { "2025-04-13": [{title, ...}], ... }
 */
export async function fetchHeadlinesForDates(dates, limit = 25) {
    const results = {};
    for (const dateStr of dates) {
        results[dateStr] = await fetchHeadlinesForDate(dateStr, { limit });
        // Rate limit between dates
        await new Promise(r => setTimeout(r, 500));
    }
    return results;
}

/**
 * Format headlines as text for LLM context.
 * Now includes sentiment indicator.
 *
 * @param {Object[]} headlines
 * @returns {string}
 */
export function formatHeadlinesForPrompt(headlines) {
    if (!headlines.length) return "No news headlines available.";
    return headlines
        .map((h, i) => {
            const sent = h.sentiment > 0.3 ? " [+]" : h.sentiment < -0.3 ? " [-]" : "";
            return `${i + 1}. "${h.title}"${sent}${h.source ? ` (${h.source})` : ""}`;
        })
        .join("\n");
}
