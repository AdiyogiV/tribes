import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "../lib/firebase.js";

/**
 * Extract Open Graph and meta data from HTML
 * @param {string} html - Raw HTML content
 * @param {string} url - Original URL for fallbacks
 * @returns {Object} - Extracted metadata
 */
function extractMetadata(html, url) {
    const metadata = {
        title: null,
        description: null,
        image: null,
        siteName: null,
        favicon: null,
        type: null,
    };

    try {
        // Helper to extract meta content
        const getMeta = (property) => {
            // Try og: prefix first
            const ogMatch = html.match(new RegExp(`<meta[^>]*property=["']og:${property}["'][^>]*content=["']([^"']+)["']`, 'i'))
                || html.match(new RegExp(`<meta[^>]*content=["']([^"']+)["'][^>]*property=["']og:${property}["']`, 'i'));
            if (ogMatch) return ogMatch[1];

            // Try twitter: prefix
            const twitterMatch = html.match(new RegExp(`<meta[^>]*name=["']twitter:${property}["'][^>]*content=["']([^"']+)["']`, 'i'))
                || html.match(new RegExp(`<meta[^>]*content=["']([^"']+)["'][^>]*name=["']twitter:${property}["']`, 'i'));
            if (twitterMatch) return twitterMatch[1];

            // Try standard meta name
            const nameMatch = html.match(new RegExp(`<meta[^>]*name=["']${property}["'][^>]*content=["']([^"']+)["']`, 'i'))
                || html.match(new RegExp(`<meta[^>]*content=["']([^"']+)["'][^>]*name=["']${property}["']`, 'i'));
            if (nameMatch) return nameMatch[1];

            return null;
        };

        // Extract title
        metadata.title = getMeta('title');
        if (!metadata.title) {
            const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
            if (titleMatch) metadata.title = titleMatch[1].trim();
        }

        // Extract description
        metadata.description = getMeta('description');

        // Extract image
        metadata.image = getMeta('image');

        // Make image URL absolute if needed
        if (metadata.image && !metadata.image.startsWith('http')) {
            try {
                const baseUrl = new URL(url);
                if (metadata.image.startsWith('//')) {
                    metadata.image = `${baseUrl.protocol}${metadata.image}`;
                } else if (metadata.image.startsWith('/')) {
                    metadata.image = `${baseUrl.origin}${metadata.image}`;
                } else {
                    metadata.image = `${baseUrl.origin}/${metadata.image}`;
                }
            } catch (e) {
                // Keep relative URL if parsing fails
            }
        }

        // Extract site name
        metadata.siteName = getMeta('site_name');
        if (!metadata.siteName) {
            try {
                const urlObj = new URL(url);
                metadata.siteName = urlObj.hostname.replace('www.', '');
            } catch (e) {
                // Ignore
            }
        }

        // Extract favicon
        const faviconMatch = html.match(/<link[^>]*rel=["'](?:shortcut )?icon["'][^>]*href=["']([^"']+)["']/i)
            || html.match(/<link[^>]*href=["']([^"']+)["'][^>]*rel=["'](?:shortcut )?icon["']/i);
        if (faviconMatch) {
            metadata.favicon = faviconMatch[1];
            // Make absolute
            if (!metadata.favicon.startsWith('http')) {
                try {
                    const baseUrl = new URL(url);
                    if (metadata.favicon.startsWith('//')) {
                        metadata.favicon = `${baseUrl.protocol}${metadata.favicon}`;
                    } else if (metadata.favicon.startsWith('/')) {
                        metadata.favicon = `${baseUrl.origin}${metadata.favicon}`;
                    }
                } catch (e) {
                    metadata.favicon = null;
                }
            }
        }

        // Extract type (article, video, etc.)
        metadata.type = getMeta('type');

        // Decode HTML entities in text fields
        if (metadata.title) metadata.title = decodeHtmlEntities(metadata.title);
        if (metadata.description) metadata.description = decodeHtmlEntities(metadata.description);
        if (metadata.siteName) metadata.siteName = decodeHtmlEntities(metadata.siteName);

        // Truncate description
        if (metadata.description && metadata.description.length > 200) {
            metadata.description = metadata.description.substring(0, 200) + '...';
        }

    } catch (e) {
        logger.warn("Error extracting metadata", { error: String(e) });
    }

    return metadata;
}

/**
 * Decode common HTML entities
 */
function decodeHtmlEntities(text) {
    if (!text) return text;
    return text
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&#x27;/g, "'")
        .replace(/&#x2F;/g, '/')
        .replace(/&nbsp;/g, ' ');
}

/**
 * Fetch link preview metadata
 * Called by web clients to bypass CORS restrictions
 * Mobile clients use direct client-side fetching
 */
export const getLinkPreview = onCall(
    {
        maxInstances: 10,
        timeoutSeconds: 15,
        memory: "256MiB",
    },
    async (request) => {
        const { url } = request.data;

        if (!url || typeof url !== 'string') {
            throw new HttpsError('invalid-argument', 'URL is required');
        }

        // Validate URL format
        let parsedUrl;
        try {
            parsedUrl = new URL(url);
            if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
                throw new Error('Invalid protocol');
            }
        } catch (e) {
            throw new HttpsError('invalid-argument', 'Invalid URL format');
        }

        logger.info("Fetching link preview", { url: url.substring(0, 100) });

        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 10000);

            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'User-Agent': 'Mozilla/5.0 (compatible; AurogramBot/1.0; +https://aurogram.in)',
                    'Accept': 'text/html,application/xhtml+xml',
                    'Accept-Language': 'en-US,en;q=0.9',
                },
                signal: controller.signal,
                redirect: 'follow',
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new HttpsError('unavailable', `Failed to fetch URL: ${response.status}`);
            }

            const contentType = response.headers.get('content-type') || '';
            if (!contentType.includes('text/html') && !contentType.includes('application/xhtml')) {
                // Not HTML, return basic preview
                return {
                    url,
                    title: parsedUrl.hostname,
                    description: null,
                    image: null,
                    siteName: parsedUrl.hostname,
                    favicon: null,
                    type: contentType.split('/')[0] || 'link',
                };
            }

            // Read only first 50KB to avoid memory issues
            const reader = response.body.getReader();
            const chunks = [];
            let totalSize = 0;
            const maxSize = 50 * 1024;

            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                chunks.push(value);
                totalSize += value.length;

                if (totalSize >= maxSize) break;
            }

            const html = new TextDecoder().decode(
                chunks.reduce((acc, chunk) => {
                    const tmp = new Uint8Array(acc.length + chunk.length);
                    tmp.set(acc, 0);
                    tmp.set(chunk, acc.length);
                    return tmp;
                }, new Uint8Array())
            );

            // Extract metadata
            const metadata = extractMetadata(html, url);

            const preview = {
                url,
                title: metadata.title || parsedUrl.hostname,
                description: metadata.description,
                image: metadata.image,
                siteName: metadata.siteName || parsedUrl.hostname,
                favicon: metadata.favicon,
                type: metadata.type || 'link',
            };

            return preview;

        } catch (e) {
            if (e.name === 'AbortError') {
                throw new HttpsError('deadline-exceeded', 'Request timed out');
            }
            if (e instanceof HttpsError) throw e;

            logger.error("Error fetching link preview", {
                url: url.substring(0, 100),
                error: String(e)
            });
            throw new HttpsError('unavailable', 'Failed to fetch link preview');
        }
    }
);
