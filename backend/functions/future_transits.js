/**
 * Future Transit Calculations
 * Predict upcoming planetary movements and their effects
 */

import { DateTime } from "luxon";
import { runAstroFlow } from "./free_astro.js";
import { calculateHouseFromDegree } from "./vedic_analysis.js";

/**
 * Calculate future transits for the next N days
 * Returns array of transit events with dates
 */
export async function calculateFutureTransits(natalChart, userAstroData, daysAhead = 7) {
    const {
        birthLatitude,
        birthLongitude,
        timeZone,
        timeZoneOffset,
    } = userAstroData;

    if (!birthLatitude || !birthLongitude) {
        return [];
    }

    const ascendantDegree = typeof natalChart.ascendant === "number"
        ? natalChart.ascendant
        : (natalChart.ascendant?.fullDegree || natalChart.ascendant?.longitude);

    if (ascendantDegree == null) {
        return [];
    }

    const futureEvents = [];
    const today = DateTime.now().setZone(timeZone || "UTC");
    const natalPlanets = natalChart.planets || {};

    // Check each day for significant changes
    for (let i = 1; i <= daysAhead; i++) {
        const futureDate = today.plus({ days: i });
        
        try {
            const payload = {
                year: futureDate.year,
                month: futureDate.month,
                date: futureDate.day,
                hours: futureDate.hour,
                minutes: futureDate.minute,
                seconds: Math.floor(futureDate.second),
                latitude: birthLatitude,
                longitude: birthLongitude,
                timezone: typeof timeZoneOffset === "number" ? timeZoneOffset : 0,
            };

            const result = await runAstroFlow({
                mode: "full",
                payload,
                timeZoneId: timeZone || "UTC",
                timeZoneOffset: typeof timeZoneOffset === "number" ? timeZoneOffset : 0,
            });

            const planets = result.birthChartData?.planets || {};
            const futureTransits = {};

            // Extract transit positions
            if (planets && typeof planets === "object") {
                Object.entries(planets).forEach(([planet, data]) => {
                    if (data && typeof data === "object") {
                        const degree = data.fullDegree || data.longitude;
                        const house = calculateHouseFromDegree(degree, ascendantDegree);
                        
                        futureTransits[planet] = {
                            sign: data.sign || data.Sign,
                            degree,
                            house,
                        };
                    }
                });
            }

            // Compare with today's transits to find changes
            if (i === 1) {
                // Store tomorrow's transits for comparison
                futureEvents.push({
                    date: futureDate.toFormat("yyyy-MM-dd"),
                    transits: futureTransits,
                    type: "daily",
                });
            } else {
                // Check for significant changes (house changes, sign changes)
                const prevDate = today.plus({ days: i - 1 });
                // For now, just store daily transits
                // TODO: Compare with previous day to detect changes
                futureEvents.push({
                    date: futureDate.toFormat("yyyy-MM-dd"),
                    transits: futureTransits,
                    type: "daily",
                });
            }
        } catch (error) {
            // Skip this date if calculation fails
            continue;
        }
    }

    return futureEvents;
}

/**
 * Detect upcoming significant events:
 * - House changes (planet entering new house)
 * - Sign changes (planet entering new sign)
 * - Aspect formations (transit planet aspecting natal planet)
 */
export function detectUpcomingEvents(futureTransits, natalChart, todayTransits) {
    const events = [];
    const natalPlanets = natalChart.planets || {};
    const ascendantDegree = typeof natalChart.ascendant === "number"
        ? natalChart.ascendant
        : (natalChart.ascendant?.fullDegree || natalChart.ascendant?.longitude);

    if (ascendantDegree == null) return events;

    // Track each planet's position
    const planetPositions = {};

    // Initialize with today's positions
    if (todayTransits) {
        Object.entries(todayTransits).forEach(([planet, data]) => {
            if (data) {
                planetPositions[planet] = {
                    sign: data.sign || data.Sign,
                    house: data.house || calculateHouseFromDegree(data.degree || data.fullDegree || data.longitude, ascendantDegree),
                    degree: data.degree || data.fullDegree || data.longitude,
                };
            }
        });
    }

    // Check future transits for changes
    futureTransits.forEach((dayData) => {
        Object.entries(dayData.transits).forEach(([planet, transitData]) => {
            const currentPos = planetPositions[planet];
            if (!currentPos) {
                planetPositions[planet] = {
                    sign: transitData.sign,
                    house: transitData.house,
                    degree: transitData.degree,
                };
                return;
            }

            // Check for house change
            if (transitData.house && currentPos.house && transitData.house !== currentPos.house) {
                events.push({
                    date: dayData.date,
                    type: "house_change",
                    planet,
                    fromHouse: currentPos.house,
                    toHouse: transitData.house,
                    significance: getHouseChangeSignificance(planet, transitData.house),
                });
            }

            // Check for sign change (simplified - would need sign boundaries)
            if (transitData.sign && currentPos.sign && transitData.sign !== currentPos.sign) {
                events.push({
                    date: dayData.date,
                    type: "sign_change",
                    planet,
                    fromSign: currentPos.sign,
                    toSign: transitData.sign,
                    significance: getSignChangeSignificance(planet, transitData.sign),
                });
            }

            // Update position
            planetPositions[planet] = {
                sign: transitData.sign,
                house: transitData.house,
                degree: transitData.degree,
            };
        });
    });

    return events.sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Get significance of house change
 */
function getHouseChangeSignificance(planet, newHouse) {
    const houseMeanings = {
        1: "self, personality, new beginnings",
        2: "wealth, family, speech",
        3: "siblings, courage, communication",
        4: "mother, home, property",
        5: "children, creativity, education",
        6: "health, enemies, service",
        7: "marriage, partnerships, spouse",
        8: "transformation, longevity, occult",
        9: "father, dharma, spirituality",
        10: "career, reputation, status",
        11: "gains, income, friends",
        12: "losses, expenses, spirituality",
    };

    const slowPlanets = ["Saturn", "Jupiter", "Rahu", "Ketu"];
    const isSlowPlanet = slowPlanets.includes(planet);
    const isMajorHouse = [1, 4, 7, 10].includes(newHouse);

    let significance = `Planet ${planet} entering House ${newHouse} (${houseMeanings[newHouse] || "unknown"})`;
    
    if (isSlowPlanet) {
        significance += ". This is a major transit as slow planets bring long-term changes.";
    }
    
    if (isMajorHouse) {
        significance += ". Major houses (1, 4, 7, 10) indicate significant life changes.";
    }

    return significance;
}

/**
 * Get significance of sign change
 */
function getSignChangeSignificance(planet, newSign) {
    const slowPlanets = ["Saturn", "Jupiter", "Rahu", "Ketu"];
    const isSlowPlanet = slowPlanets.includes(planet);

    let significance = `Planet ${planet} entering ${newSign}`;
    
    if (isSlowPlanet) {
        significance += ". Slow planets changing signs is a major astrological event with long-term effects.";
    } else {
        significance += ". This transit brings new energy and opportunities.";
    }

    return significance;
}

/**
 * Format upcoming events for AI prompt
 */
export function formatUpcomingEvents(upcomingEvents) {
    if (!upcomingEvents || upcomingEvents.length === 0) {
        return "No significant upcoming transit events in the next 7 days.";
    }

    const eventGroups = upcomingEvents.slice(0, 5).map((event) => {
        const date = DateTime.fromFormat(event.date, "yyyy-MM-dd");
        const dayName = date.toFormat("cccc"); // Day name
        const dateStr = date.toFormat("MMM d");
        
        return `- ${dayName}, ${dateStr}: ${event.significance}`;
    });

    return `Upcoming Significant Transits:\n${eventGroups.join("\n")}`;
}









