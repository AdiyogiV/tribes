/**
 * News Feed — Google News RSS Parser
 *
 * Fetches top world headlines from Google News RSS.
 * No API key needed. No dependencies. Just fetch + regex parse.
 *
 * Returns ~20 headlines with title, source, and published date.
 * Used to give the cosmic daily function real-world context.
 */

const GOOGLE_NEWS_RSS = "https://news.google.com/rss?hl=en&gl=US&ceid=US:en";

/**
 * Fetch top headlines from Google News RSS.
 * @param {Object} [options]
 * @param {number} [options.limit=20] - Max headlines to return
 * @param {number} [options.timeoutMs=10000] - Fetch timeout
 * @returns {Promise<Array<{title: string, source: string, pubDate: string, link: string}>>}
 */
export async function fetchNewsHeadlines(options = {}) {
    const { limit = 20, timeoutMs = 10000 } = options;

    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), timeoutMs);

        const response = await fetch(GOOGLE_NEWS_RSS, {
            signal: controller.signal,
            headers: { "User-Agent": "CosmicAgent/1.0" },
        });
        clearTimeout(timeout);

        if (!response.ok) {
            throw new Error(`RSS fetch failed: ${response.status}`);
        }

        const xml = await response.text();
        return parseRSS(xml, limit);
    } catch (error) {
        // Non-fatal — agent can still run without news
        console.warn("News feed fetch failed:", error.message);
        return [];
    }
}

/**
 * Parse RSS XML into headline objects.
 * Simple regex parsing — RSS is structured enough that we don't need an XML library.
 */
function parseRSS(xml, limit) {
    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;

    while ((match = itemRegex.exec(xml)) !== null && items.length < limit) {
        const itemXml = match[1];

        const title = extractTag(itemXml, "title");
        const link = extractTag(itemXml, "link");
        const pubDate = extractTag(itemXml, "pubDate");
        const source = extractTag(itemXml, "source");

        if (title) {
            items.push({
                title: decodeEntities(title),
                source: source ? decodeEntities(source) : "",
                pubDate: pubDate || "",
                link: link || "",
            });
        }
    }

    return items;
}

/**
 * Extract content of an XML tag.
 */
function extractTag(xml, tag) {
    const regex = new RegExp(`<${tag}[^>]*>(?:<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?<\\/${tag}>`, "s");
    const match = xml.match(regex);
    return match ? match[1].trim() : null;
}

/**
 * Decode common HTML entities.
 */
function decodeEntities(str) {
    return str
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&#x27;/g, "'");
}

/**
 * Format headlines as a compact text block for LLM context.
 * @param {Array} headlines - From fetchNewsHeadlines()
 * @returns {string} Formatted text
 */
export function formatNewsForPrompt(headlines) {
    if (!headlines.length) return "No news headlines available today.";

    return headlines
        .map((h, i) => `${i + 1}. "${h.title}"${h.source ? ` (${h.source})` : ""}`)
        .join("\n");
}
