/**
 * News Feed — Google News headlines via RSS + Gemini Search fallback
 *
 * Primary:  Google News RSS (free, no API key, fast)
 * Fallback: Gemini with Google Search grounding (reliable from Cloud Run)
 *
 * Why fallback? Google News blocks requests from Cloud Run/GCP IPs with
 * 503 errors. Gemini's built-in Google Search grounding is NOT blocked
 * because it uses Google's own internal search infrastructure.
 *
 * Returns ~20 headlines with title, source, and published date.
 * Used to give the cosmic daily function real-world context.
 */

import { getVertexAI, extractText } from "./vertex_client.js";

const GOOGLE_NEWS_RSS = "https://news.google.com/rss?hl=en&gl=US&ceid=US:en";

/**
 * Fetch top headlines — tries RSS first, falls back to Gemini Search.
 * @param {Object} [options]
 * @param {number} [options.limit=20] - Max headlines to return
 * @param {number} [options.timeoutMs=10000] - Fetch timeout for RSS
 * @param {string} [options.geminiApiKey] - Gemini API key for search fallback
 * @returns {Promise<Array<{title: string, source: string, pubDate: string, link: string}>>}
 */
export async function fetchNewsHeadlines(options = {}) {
    const { limit = 20, timeoutMs = 10000, geminiApiKey } = options;

    // Try RSS first (faster, free)
    const rssHeadlines = await fetchViaRSS(limit, timeoutMs);
    if (rssHeadlines.length > 0) {
        return rssHeadlines;
    }

    // RSS failed — fall back to Gemini with Google Search grounding (Vertex AI, no key needed)
    console.warn("RSS failed, falling back to Gemini Search grounding");
    return fetchViaGeminiSearch(limit);
}

/**
 * Fetch headlines via Google News RSS.
 */
async function fetchViaRSS(limit, timeoutMs) {
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), timeoutMs);

        const response = await fetch(GOOGLE_NEWS_RSS, {
            signal: controller.signal,
            headers: {"User-Agent": "CosmicAgent/1.0"},
        });
        clearTimeout(timeout);

        if (!response.ok) {
            throw new Error(`RSS fetch failed: ${response.status}`);
        }

        const xml = await response.text();
        return parseRSS(xml, limit);
    } catch (error) {
        console.warn("News feed RSS fetch failed:", error.message);
        return [];
    }
}

/**
 * Fetch headlines via Gemini with Google Search grounding.
 * Gemini's search is not blocked from Cloud Run (it uses Google's internal infra).
 */
async function fetchViaGeminiSearch(limit) {
    try {
        const vertexAI = getVertexAI();
        const model = vertexAI.getGenerativeModel({
            model: "gemini-2.5-flash",
            tools: [{googleSearch: {}}],
            generationConfig: {
                temperature: 0.1,
                maxOutputTokens: 65536,
            },
        });

        const prompt = `Return today's top ${limit} world news headlines as a JSON array. ` +
            "Focus on major global events, India/South Asia, geopolitics, markets, and technology. " +
            "Each item: {\"title\": \"headline\", \"source\": \"publication name\"}. " +
            "Use Google Search to get real, current headlines. " +
            "Return ONLY the JSON array, no explanation, no markdown fences.";

        const result = await model.generateContent({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
        });

        const text = extractText(result);
        // Parse JSON — handle markdown code blocks if present
        const jsonStr = text.replace(/^```json?\n?/, "").replace(/\n?```$/, "");
        const headlines = JSON.parse(jsonStr);

        if (!Array.isArray(headlines)) return [];

        return headlines.slice(0, limit).map((h) => ({
            title: h.title || "",
            source: h.source || "",
            pubDate: new Date().toISOString(),
            link: "",
        }));
    } catch (error) {
        console.warn("Gemini Search news fallback failed:", error.message);
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
