// geo_search.js — location autocomplete via FreeAstrologyAPI geo-details.
//
// Split out of ephemeris.js: geo lookup is a location-search concern, not an
// astrology-computation concern. Self-contained; shares the one HTTP client.

import { logger } from "firebase-functions/v2";
import { callFreeAstro } from "./free_astro_client.js";

const GEO_DETAILS_ENDPOINT = "/geo-details";

/** Handler: search for a location (city) by free-text query. */
export async function handleSearchGeoLocation(request, data) {
    try {
        const { query } = data || request.data || {};

        if (!query || typeof query !== "string" || query.trim().length < 2) {
            return { success: true, results: [] };
        }

        const searchQuery = query.trim();

        // Call the Free Astrology API geo-details endpoint
        const response = await callFreeAstro(GEO_DETAILS_ENDPOINT, {
            location: searchQuery,
        });

        // The API returns an array of results
        if (!response || !Array.isArray(response)) {
            logger.warn("Unexpected geo response format", {
                structuredData: true,
                query: searchQuery,
                responseType: typeof response,
            });
            return { success: true, results: [] };
        }

        // Transform results to a cleaner format
        const results = response.map((item) => ({
            name: item.location_name || searchQuery,
            fullName: item.complete_name || item.location_name || searchQuery,
            country: item.country || "",
            region: item.administrative_zone_1 || "",
            subRegion: item.administrative_zone_2 || "",
            latitude: item.latitude,
            longitude: item.longitude,
            timezone: item.timezone || null,
            timezoneOffset: item.timezone_offset || null,
        })).filter((item) =>
            // Filter out invalid results
            item.latitude != null &&
            item.longitude != null &&
            !isNaN(item.latitude) &&
            !isNaN(item.longitude)
        );

        logger.info("Geo search completed", {
            structuredData: true,
            query: searchQuery,
            resultsCount: results.length,
        });

        return {
            success: true,
            results: results,
        };
    } catch (error) {
        logger.error("searchGeoLocation error", {
            structuredData: true,
            error: error.message,
            query: request.data?.query,
        });

        // Return empty results instead of throwing for better UX
        return {
            success: false,
            results: [],
            error: "Location search failed. Please try again.",
        };
    }
}
