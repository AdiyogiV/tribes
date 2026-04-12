/**
 * Koorma Chakra — Geographic Mapping of Zodiac Signs to World Regions
 *
 * Source: Brihat Samhita, Chapter 14 (Varahamihira, ~550 CE)
 * Also referenced in: Saravali, Brihat Jataka
 *
 * The Koorma (tortoise) Chakra maps the 12 zodiac signs to geographic
 * regions of the world. When a planet transits a sign, its effects
 * manifest in the mapped regions.
 *
 * Classical mappings used Indian geographic names (janapadas).
 * Modern commentators (B.V. Raman, K.N. Rao, Gayatri Devi Vasudev)
 * have extended these to world regions. This file uses a CONSENSUS
 * mapping — where commentators disagree, multiple regions are listed
 * with a confidence level.
 *
 * NOTE: These mappings are debated among scholars. The system treats
 * them as probabilistic (weighted by confidence), not absolute.
 */

export const KOORMA_CHAKRA = {
    Aries: {
        classicalNames: ["Kalinga", "Panchala", "Kuru"],
        modernRegions: [
            { name: "Central India", confidence: 0.9 },
            { name: "England / UK", confidence: 0.8 },
            { name: "Germany (east)", confidence: 0.7 },
            { name: "Palestine", confidence: 0.6 },
            { name: "Denmark", confidence: 0.5 },
        ],
        direction: "East",
        element: "Fire",
        nature: "Pioneering nations, military-forward, identity-assertive",
    },
    Taurus: {
        classicalNames: ["Kamboja", "Gandhara", "Parashika"],
        modernRegions: [
            { name: "Afghanistan", confidence: 0.8 },
            { name: "Ukraine", confidence: 0.7 },
            { name: "Ireland", confidence: 0.7 },
            { name: "Cyprus", confidence: 0.6 },
            { name: "Georgia (Caucasus)", confidence: 0.6 },
        ],
        direction: "South",
        element: "Earth",
        nature: "Agricultural, resource-rich, contested border regions",
    },
    Gemini: {
        classicalNames: ["Kuru", "Panchala", "Yavana"],
        modernRegions: [
            { name: "NE United States", confidence: 0.8 },
            { name: "Belgium", confidence: 0.7 },
            { name: "Egypt (Lower)", confidence: 0.7 },
            { name: "Wales", confidence: 0.6 },
            { name: "Sardinia", confidence: 0.5 },
        ],
        direction: "West",
        element: "Air",
        nature: "Trade hubs, intellectual centers, dual-natured politics",
    },
    Cancer: {
        classicalNames: ["Kalinga", "Vanga", "Magadha"],
        modernRegions: [
            { name: "East India (Bengal)", confidence: 0.9 },
            { name: "Netherlands", confidence: 0.7 },
            { name: "Scotland", confidence: 0.7 },
            { name: "New Zealand", confidence: 0.6 },
            { name: "Paraguay", confidence: 0.5 },
        ],
        direction: "North",
        element: "Water",
        nature: "Coastal, water-connected, emotionally reactive populations",
    },
    Leo: {
        classicalNames: ["Madhya-desha", "Kosala"],
        modernRegions: [
            { name: "France", confidence: 0.8 },
            { name: "Italy (north)", confidence: 0.8 },
            { name: "Romania", confidence: 0.7 },
            { name: "Czech Republic", confidence: 0.6 },
            { name: "North India (UP/MP)", confidence: 0.7 },
        ],
        direction: "East",
        element: "Fire",
        nature: "Centers of power, royal/presidential authority, cultural capitals",
    },
    Virgo: {
        classicalNames: ["Mlechha-desha", "Yavana"],
        modernRegions: [
            { name: "Turkey", confidence: 0.8 },
            { name: "Greece", confidence: 0.7 },
            { name: "Caribbean (West Indies)", confidence: 0.7 },
            { name: "Croatia", confidence: 0.6 },
            { name: "Brazil (south)", confidence: 0.5 },
        ],
        direction: "South",
        element: "Earth",
        nature: "Service economies, health-conscious, detail-oriented governance",
    },
    Libra: {
        classicalNames: ["Sindhu", "Sauvira", "Kashmir"],
        modernRegions: [
            { name: "China (trade regions)", confidence: 0.7 },
            { name: "Japan", confidence: 0.7 },
            { name: "Argentina", confidence: 0.7 },
            { name: "Austria", confidence: 0.6 },
            { name: "Tibet / Kashmir", confidence: 0.8 },
        ],
        direction: "West",
        element: "Air",
        nature: "Trade-dependent, balance-seeking, partnership-oriented",
    },
    Scorpio: {
        classicalNames: ["Surashtra", "Maharashtra"],
        modernRegions: [
            { name: "North Africa (Libya/Algeria)", confidence: 0.7 },
            { name: "Norway", confidence: 0.7 },
            { name: "Korea (both)", confidence: 0.7 },
            { name: "Bavaria / S Germany", confidence: 0.6 },
            { name: "W India (Gujarat/Maharashtra)", confidence: 0.8 },
        ],
        direction: "North",
        element: "Water",
        nature: "Transformation zones, resource conflicts, secretive politics",
    },
    Sagittarius: {
        classicalNames: ["Yavana-desha", "Tushara"],
        modernRegions: [
            { name: "Spain", confidence: 0.8 },
            { name: "Australia", confidence: 0.7 },
            { name: "Arabia (Saudi/UAE)", confidence: 0.7 },
            { name: "Hungary", confidence: 0.6 },
            { name: "South Africa", confidence: 0.6 },
        ],
        direction: "East",
        element: "Fire",
        nature: "Expansionist, religious/philosophical centers, long-distance trade",
    },
    Capricorn: {
        classicalNames: ["Dravida", "Pandya"],
        modernRegions: [
            { name: "S India (Tamil Nadu/Kerala)", confidence: 0.9 },
            { name: "Germany (west)", confidence: 0.7 },
            { name: "Mexico", confidence: 0.7 },
            { name: "Afghanistan (south)", confidence: 0.6 },
            { name: "Bulgaria", confidence: 0.5 },
        ],
        direction: "South",
        element: "Earth",
        nature: "Structured governance, mountainous/arid, tradition-bound",
    },
    Aquarius: {
        classicalNames: ["Mleccha-desha", "Huna"],
        modernRegions: [
            { name: "Russia", confidence: 0.8 },
            { name: "Sweden", confidence: 0.7 },
            { name: "Ethiopia", confidence: 0.7 },
            { name: "Poland", confidence: 0.6 },
            { name: "Iran (north)", confidence: 0.5 },
        ],
        direction: "West",
        element: "Air",
        nature: "Revolutionary, collectivist, cold-climate, humanitarian",
    },
    Pisces: {
        classicalNames: ["Romaka-desha", "Parasika"],
        modernRegions: [
            { name: "Middle East (Gulf states)", confidence: 0.8 },
            { name: "Portugal", confidence: 0.7 },
            { name: "Oceania (Pacific islands)", confidence: 0.7 },
            { name: "SE Asia (maritime)", confidence: 0.6 },
            { name: "NW France (Normandy)", confidence: 0.5 },
        ],
        direction: "North",
        element: "Water",
        nature: "Maritime, spiritual, dissolving boundaries, refugee/exile zones",
    },
};

/**
 * Get Koorma regions for a sign.
 * @param {string} sign
 * @returns {Object|null}
 */
export function getKoormaRegions(sign) {
    return KOORMA_CHAKRA[sign] || null;
}

/**
 * Get affected region names for a sign, filtered by confidence.
 * @param {string} sign
 * @param {number} [minConfidence=0.5]
 * @returns {string[]}
 */
export function getAffectedRegions(sign, minConfidence = 0.5) {
    const entry = KOORMA_CHAKRA[sign];
    if (!entry) return [];
    return entry.modernRegions
        .filter(r => r.confidence >= minConfidence)
        .sort((a, b) => b.confidence - a.confidence)
        .map(r => r.name);
}

/**
 * Get world activation map — which regions are activated by current positions.
 * @param {Object} positions - { planet: { sign, ... } }
 * @returns {Object[]}
 */
export function getWorldActivationMap(positions) {
    const signActivations = {};

    for (const [planet, pos] of Object.entries(positions)) {
        const sign = pos?.sign;
        if (!sign || !KOORMA_CHAKRA[sign]) continue;
        if (!signActivations[sign]) {
            signActivations[sign] = { planets: [], entry: KOORMA_CHAKRA[sign] };
        }
        signActivations[sign].planets.push(planet);
    }

    return Object.entries(signActivations)
        .map(([sign, data]) => ({
            sign,
            planets: data.planets,
            regions: data.entry.modernRegions,
            element: data.entry.element,
            nature: data.entry.nature,
            direction: data.entry.direction,
        }))
        .sort((a, b) => b.planets.length - a.planets.length);
}

/**
 * Format Koorma activation as compact text for synthesis agent.
 * @param {Object} positions
 * @returns {string}
 */
export function formatKoormaContext(positions) {
    const activations = getWorldActivationMap(positions);
    if (!activations.length) return "No Koorma activations detected.";

    return activations.map(a => {
        const regionStr = a.regions
            .filter(r => r.confidence >= 0.6)
            .map(r => r.name)
            .join(", ");
        return `${a.sign} [${a.planets.join("+")}]: ${regionStr} (${a.nature})`;
    }).join("\n");
}
