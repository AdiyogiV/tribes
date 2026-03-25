/**
 * Ayurveda Integration Module
 * 
 * Bridges Vedic Astrology (Jyotish) with Ayurveda for personalized health insights.
 * Based on classical texts: Brihat Parashara Hora Shastra, Charaka Samhita, Ashtanga Hridaya
 * 
 * Core Concepts:
 * - Prakriti: Birth constitution (permanent, from birth chart)
 * - Vikriti: Current state/imbalance (dynamic, from dasha + season + symptoms)
 * - Agni: Digestive fire type
 * - Manas Prakriti: Mental constitution (Sattva/Rajas/Tamas)
 */

// ============================================================================
// PLANET-DOSHA MAPPINGS
// Based on classical Jyotish-Ayurveda texts
// ============================================================================

/**
 * Each planet's natural dosha affinity
 * Some planets are dual-dosha or tridoshic
 */
export const PLANET_DOSHA = {
    Sun: { primary: "pitta", secondary: null, weight: 1.0 },
    Moon: { primary: "kapha", secondary: "vata", weight: 0.6 }, // Dual nature
    Mars: { primary: "pitta", secondary: null, weight: 1.0 },
    Mercury: { primary: "vata", secondary: "pitta", weight: 0.5 }, // Tridoshic tendency
    Jupiter: { primary: "kapha", secondary: null, weight: 1.0 },
    Venus: { primary: "kapha", secondary: "vata", weight: 0.7 },
    Saturn: { primary: "vata", secondary: null, weight: 1.0 },
    Rahu: { primary: "vata", secondary: null, weight: 0.8 },
    Ketu: { primary: "pitta", secondary: null, weight: 0.8 },
};

/**
 * Planet weights for Prakriti calculation
 * Based on importance for physical constitution
 */
export const PLANET_PRAKRITI_WEIGHTS = {
    Ascendant: 6,  // Most important - physical body
    Moon: 5,       // Mind and emotions
    Sun: 4,        // Vitality and soul
    Mars: 3,
    Mercury: 3,
    Jupiter: 3,
    Venus: 3,
    Saturn: 2,
    Rahu: 1,
    Ketu: 1,
};

// ============================================================================
// SIGN-DOSHA MAPPINGS
// ============================================================================

export const SIGN_DOSHA = {
    Aries: "pitta",
    Taurus: "kapha",
    Gemini: "vata",
    Cancer: "kapha",
    Leo: "pitta",
    Virgo: "vata",
    Libra: "vata",
    Scorpio: "pitta",
    Sagittarius: "pitta",
    Capricorn: "kapha",
    Aquarius: "vata",
    Pisces: "kapha",
};

// ============================================================================
// NAKSHATRA-DOSHA MAPPINGS (27 Nakshatras)
// Primary and secondary dosha for each nakshatra
// ============================================================================

export const NAKSHATRA_DOSHA = {
    "Ashwini": { primary: "pitta", secondary: "vata" },
    "Bharani": { primary: "kapha", secondary: "vata" },
    "Krittika": { primary: "pitta", secondary: "vata" },
    "Rohini": { primary: "kapha", secondary: "vata" },
    "Mrigashira": { primary: "pitta", secondary: "kapha" },
    "Ardra": { primary: "vata", secondary: "kapha" },
    "Punarvasu": { primary: "kapha", secondary: "pitta" },
    "Pushya": { primary: "vata", secondary: "kapha" },
    "Ashlesha": { primary: "vata", secondary: "kapha" },
    "Magha": { primary: "pitta", secondary: "vata" },
    "Purva Phalguni": { primary: "kapha", secondary: "vata" },
    "Uttara Phalguni": { primary: "pitta", secondary: "vata" },
    "Hasta": { primary: "kapha", secondary: "vata" },
    "Chitra": { primary: "pitta", secondary: "kapha" },
    "Swati": { primary: "vata", secondary: "kapha" },
    "Vishakha": { primary: "kapha", secondary: "pitta" },
    "Anuradha": { primary: "vata", secondary: "kapha" },
    "Jyeshtha": { primary: "pitta", secondary: "vata" },
    "Moola": { primary: "vata", secondary: "pitta" },
    "Purva Ashadha": { primary: "kapha", secondary: "pitta" },
    "Uttara Ashadha": { primary: "pitta", secondary: "kapha" },
    "Shravana": { primary: "vata", secondary: "kapha" },
    "Dhanishta": { primary: "pitta", secondary: "vata" },
    "Shatabhisha": { primary: "vata", secondary: "pitta" },
    "Purva Bhadrapada": { primary: "kapha", secondary: "vata" },
    "Uttara Bhadrapada": { primary: "pitta", secondary: "kapha" },
    "Revati": { primary: "vata", secondary: "kapha" },
};

// ============================================================================
// PLANET-DHATU (TISSUE) MAPPINGS
// Each planet governs specific body tissues
// ============================================================================

export const PLANET_DHATU = {
    Sun: { dhatu: "asthi", english: "Bone", systems: ["skeletal", "vitality"], organs: ["heart", "eyes", "bones"] },
    Moon: { dhatu: "rasa", english: "Plasma", systems: ["fluids", "emotions"], organs: ["blood", "mind", "breasts"] },
    Mars: { dhatu: "rakta", english: "Blood", systems: ["muscular", "circulatory"], organs: ["blood", "muscles", "bone marrow"] },
    Mercury: { dhatu: "majja", english: "Marrow", systems: ["nervous"], organs: ["nerves", "skin", "speech"] },
    Jupiter: { dhatu: "meda", english: "Fat", systems: ["endocrine", "metabolic"], organs: ["liver", "fat tissue", "ears"] },
    Venus: { dhatu: "shukra", english: "Reproductive", systems: ["reproductive", "urinary"], organs: ["kidneys", "reproductive organs", "face"] },
    Saturn: { dhatu: "mamsa", english: "Muscle", systems: ["structural"], organs: ["bones", "joints", "teeth", "hair"] },
    Rahu: { dhatu: null, english: null, systems: ["psychological"], organs: ["allergies", "poisons", "skin"] },
    Ketu: { dhatu: null, english: null, systems: ["karmic"], organs: ["nerves", "infections", "mysterious ailments"] },
};

// ============================================================================
// DASHA-DOSHA EFFECTS
// How planetary periods affect current dosha balance
// ============================================================================

export const DASHA_DOSHA_EFFECT = {
    Sun: { vata: 0, pitta: 25, kapha: 0 },
    Moon: { vata: 10, pitta: 0, kapha: 15 },
    Mars: { vata: 0, pitta: 30, kapha: 0 },
    Mercury: { vata: 15, pitta: 10, kapha: 5 },
    Jupiter: { vata: 0, pitta: 0, kapha: 25 },
    Venus: { vata: 10, pitta: 0, kapha: 20 },
    Saturn: { vata: 30, pitta: 0, kapha: 0 },
    Rahu: { vata: 25, pitta: 10, kapha: 0 },
    Ketu: { vata: 15, pitta: 15, kapha: 0 },
};

// ============================================================================
// LIFE STAGE (VAYA) DOSHA EFFECTS
// Age-based dosha adjustments
// ============================================================================

export const LIFE_STAGE_DOSHA = {
    kapha: { ageRange: [0, 16], effect: { vata: 0, pitta: 0, kapha: 20 } },
    pitta: { ageRange: [16, 50], effect: { vata: 0, pitta: 15, kapha: 0 } },
    vata: { ageRange: [50, 150], effect: { vata: 20, pitta: 0, kapha: 0 } },
};

/**
 * Get life stage from age
 */
export function getLifeStage(age) {
    if (age < 16) return "kapha";
    if (age < 50) return "pitta";
    return "vata";
}

/**
 * Get life stage dosha effect
 */
export function getLifeStageEffect(age) {
    const stage = getLifeStage(age);
    return LIFE_STAGE_DOSHA[stage].effect;
}

// ============================================================================
// SEASONAL (RITUCHARYA) DOSHA EFFECTS
// Based on Vedic 6-season calendar
// ============================================================================

export const VEDIC_SEASONS = {
    shishira: { 
        months: [1, 2], // Mid-Jan to Mid-Mar
        name: "Late Winter",
        dominantDosha: "kapha",
        effect: { vata: 0, pitta: 0, kapha: 20 },
        guidance: "Warmth and nourishment needed"
    },
    vasanta: { 
        months: [3, 4], // Mid-Mar to Mid-May
        name: "Spring",
        dominantDosha: "kapha",
        effect: { vata: 0, pitta: 0, kapha: 15 },
        guidance: "Detox and lightness recommended"
    },
    grishma: { 
        months: [5, 6], // Mid-May to Mid-Jul
        name: "Summer",
        dominantDosha: "pitta",
        effect: { vata: 10, pitta: 25, kapha: 0 },
        guidance: "Cooling and hydration essential"
    },
    varsha: { 
        months: [7, 8], // Mid-Jul to Mid-Sep
        name: "Monsoon",
        dominantDosha: "vata",
        effect: { vata: 25, pitta: 10, kapha: 0 },
        guidance: "Digestion support and warmth needed"
    },
    sharad: { 
        months: [9, 10], // Mid-Sep to Mid-Nov
        name: "Autumn",
        dominantDosha: "pitta",
        effect: { vata: 0, pitta: 20, kapha: 0 },
        guidance: "Cooling and calming practices"
    },
    hemanta: { 
        months: [11, 12], // Mid-Nov to Mid-Jan
        name: "Early Winter",
        dominantDosha: "vata",
        effect: { vata: 20, pitta: 0, kapha: 10 },
        guidance: "Grounding and warming practices"
    },
};

/**
 * Get current Vedic season from month
 */
export function getVedicSeason(month) {
    for (const [season, data] of Object.entries(VEDIC_SEASONS)) {
        if (data.months.includes(month)) {
            return { season, ...data };
        }
    }
    return { season: "hemanta", ...VEDIC_SEASONS.hemanta };
}

// ============================================================================
// CLIMATE-BASED ADJUSTMENTS
// Adjust Prakriti based on birth location climate
// ============================================================================

/**
 * Determine climate type from latitude
 */
export function getClimateFromLatitude(latitude) {
    const absLat = Math.abs(latitude);
    
    if (absLat <= 23.5) {
        return "tropical"; // Near equator - hot, humid
    } else if (absLat <= 35) {
        return "subtropical"; // Warm, variable
    } else if (absLat <= 55) {
        return "temperate"; // Moderate
    } else {
        return "cold"; // Northern/Southern extremes
    }
}

export const CLIMATE_DOSHA_ADJUSTMENT = {
    tropical: { vata: 0, pitta: 10, kapha: 10 },      // Hot + humid
    subtropical: { vata: 5, pitta: 10, kapha: 5 },    // Warm
    temperate: { vata: 5, pitta: 5, kapha: 5 },       // Balanced
    cold: { vata: 15, pitta: 0, kapha: 10 },          // Cold + dry/damp
};

// ============================================================================
// AGNI (DIGESTIVE FIRE) TYPES
// ============================================================================

export const AGNI_TYPES = {
    sama: {
        name: "Sama Agni",
        english: "Balanced Digestion",
        description: "Regular appetite, efficient digestion, no discomfort",
        dominantDosha: null,
    },
    vishama: {
        name: "Vishama Agni",
        english: "Irregular Digestion",
        description: "Variable appetite, gas, bloating, constipation tendency",
        dominantDosha: "vata",
    },
    tikshna: {
        name: "Tikshna Agni",
        english: "Sharp Digestion",
        description: "Strong hunger, acidity tendency, loose stools when imbalanced",
        dominantDosha: "pitta",
    },
    manda: {
        name: "Manda Agni",
        english: "Slow Digestion",
        description: "Low appetite, heavy after meals, slow metabolism",
        dominantDosha: "kapha",
    },
};

/**
 * Determine Agni type from dosha balance
 */
export function determineAgniType(doshaBalance) {
    const { vata, pitta, kapha } = doshaBalance;
    
    // Check if doshas are relatively balanced (within 15% of each other)
    const max = Math.max(vata, pitta, kapha);
    const min = Math.min(vata, pitta, kapha);
    
    if (max - min < 15) {
        return "sama";
    }
    
    // Determine based on dominant dosha
    if (vata >= pitta && vata >= kapha) {
        return "vishama";
    } else if (pitta >= vata && pitta >= kapha) {
        return "tikshna";
    } else {
        return "manda";
    }
}

// ============================================================================
// MANAS PRAKRITI (MENTAL CONSTITUTION)
// Based on Sattva, Rajas, Tamas gunas
// ============================================================================

export const PLANET_GUNA = {
    Sun: "sattva",
    Moon: "sattva",
    Jupiter: "sattva",
    Mercury: "rajas",
    Venus: "rajas",
    Mars: "tamas",
    Saturn: "tamas",
    Rahu: "tamas",
    Ketu: "tamas",
};

// ============================================================================
// PRAKRITI CALCULATION
// ============================================================================

/**
 * Normalize nakshatra name for lookup
 */
function normalizeNakshatra(nakshatra) {
    if (!nakshatra) return null;
    
    // Handle common variations
    const normalized = nakshatra
        .trim()
        .replace(/\s+/g, " ")
        .split(" ")
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(" ");
    
    // Handle specific variations
    const variations = {
        "Purva Phalguni": ["Purva Phalguni", "Poorva Phalguni", "P.Phalguni"],
        "Uttara Phalguni": ["Uttara Phalguni", "Uttara Phalguni", "U.Phalguni"],
        "Purva Ashadha": ["Purva Ashadha", "Poorva Ashadha", "P.Ashadha"],
        "Uttara Ashadha": ["Uttara Ashadha", "Uttara Ashadha", "U.Ashadha"],
        "Purva Bhadrapada": ["Purva Bhadrapada", "Poorva Bhadrapada", "P.Bhadrapada"],
        "Uttara Bhadrapada": ["Uttara Bhadrapada", "Uttara Bhadrapada", "U.Bhadrapada"],
    };
    
    for (const [standard, variants] of Object.entries(variations)) {
        if (variants.some(v => normalized.includes(v.replace(".", "")))) {
            return standard;
        }
    }
    
    return normalized;
}

/**
 * Normalize sign name for lookup
 */
function normalizeSign(sign) {
    if (!sign) return null;
    return sign.charAt(0).toUpperCase() + sign.slice(1).toLowerCase();
}

/**
 * Calculate Prakriti (birth constitution) from birth chart data
 * 
 * @param {Object} params
 * @param {string} params.ascendantSign - Ascendant/Lagna sign
 * @param {Array} params.planets - Array of planet objects with name, sign, nakshatra
 * @param {string} params.moonNakshatra - Moon's nakshatra
 * @param {number} params.birthLatitude - Birth location latitude
 * @returns {Object} Prakriti calculation result
 */
export function calculatePrakriti({ ascendantSign, planets, moonNakshatra, birthLatitude }) {
    const doshaPoints = { vata: 0, pitta: 0, kapha: 0 };
    const gunaPoints = { sattva: 0, rajas: 0, tamas: 0 };
    
    // 1. Ascendant sign contribution (highest weight)
    if (ascendantSign) {
        const ascSign = normalizeSign(ascendantSign);
        const ascDosha = SIGN_DOSHA[ascSign];
        if (ascDosha) {
            doshaPoints[ascDosha] += PLANET_PRAKRITI_WEIGHTS.Ascendant;
        }
    }
    
    // 2. Planet sign contributions
    if (planets && Array.isArray(planets)) {
        for (const planet of planets) {
            const planetName = planet.name || planet.planet;
            const sign = normalizeSign(planet.sign);
            
            if (!planetName || !sign) continue;
            
            // Get weight for this planet
            const weight = PLANET_PRAKRITI_WEIGHTS[planetName] || 1;
            
            // Add sign's dosha contribution
            const signDosha = SIGN_DOSHA[sign];
            if (signDosha) {
                doshaPoints[signDosha] += weight;
            }
            
            // Add planet's natural dosha (half weight)
            const planetDoshaInfo = PLANET_DOSHA[planetName];
            if (planetDoshaInfo) {
                doshaPoints[planetDoshaInfo.primary] += weight * 0.5 * planetDoshaInfo.weight;
                if (planetDoshaInfo.secondary) {
                    doshaPoints[planetDoshaInfo.secondary] += weight * 0.25 * planetDoshaInfo.weight;
                }
            }
            
            // Add to guna calculation
            const guna = PLANET_GUNA[planetName];
            if (guna) {
                gunaPoints[guna] += weight;
            }
        }
    }
    
    // 3. Moon nakshatra refinement (important for mental/emotional constitution)
    if (moonNakshatra) {
        const normalizedNakshatra = normalizeNakshatra(moonNakshatra);
        const nakshatraDosha = NAKSHATRA_DOSHA[normalizedNakshatra];
        if (nakshatraDosha) {
            doshaPoints[nakshatraDosha.primary] += 3; // Nakshatra adds 3 points
            if (nakshatraDosha.secondary) {
                doshaPoints[nakshatraDosha.secondary] += 1.5;
            }
        }
    }
    
    // 4. Birth climate adjustment
    if (birthLatitude !== undefined && birthLatitude !== null) {
        const climate = getClimateFromLatitude(birthLatitude);
        const climateAdjustment = CLIMATE_DOSHA_ADJUSTMENT[climate];
        if (climateAdjustment) {
            doshaPoints.vata += climateAdjustment.vata * 0.3; // 30% weight for climate
            doshaPoints.pitta += climateAdjustment.pitta * 0.3;
            doshaPoints.kapha += climateAdjustment.kapha * 0.3;
        }
    }
    
    // Calculate percentages
    const totalDosha = doshaPoints.vata + doshaPoints.pitta + doshaPoints.kapha;
    const totalGuna = gunaPoints.sattva + gunaPoints.rajas + gunaPoints.tamas;
    
    const doshaPercentages = {
        vata: totalDosha > 0 ? Math.round((doshaPoints.vata / totalDosha) * 100) : 33,
        pitta: totalDosha > 0 ? Math.round((doshaPoints.pitta / totalDosha) * 100) : 33,
        kapha: totalDosha > 0 ? Math.round((doshaPoints.kapha / totalDosha) * 100) : 34,
    };
    
    // Ensure they sum to 100
    const sum = doshaPercentages.vata + doshaPercentages.pitta + doshaPercentages.kapha;
    if (sum !== 100) {
        const maxDosha = Object.entries(doshaPercentages).reduce((a, b) => a[1] > b[1] ? a : b)[0];
        doshaPercentages[maxDosha] += (100 - sum);
    }
    
    const gunaPercentages = {
        sattva: totalGuna > 0 ? Math.round((gunaPoints.sattva / totalGuna) * 100) : 33,
        rajas: totalGuna > 0 ? Math.round((gunaPoints.rajas / totalGuna) * 100) : 33,
        tamas: totalGuna > 0 ? Math.round((gunaPoints.tamas / totalGuna) * 100) : 34,
    };
    
    // Determine dominant and secondary doshas
    const sortedDoshas = Object.entries(doshaPercentages)
        .sort((a, b) => b[1] - a[1]);
    
    const dominant = sortedDoshas[0][0];
    const secondary = sortedDoshas[1][0];
    
    // Determine Prakriti type
    let prakritiType;
    if (sortedDoshas[0][1] - sortedDoshas[1][1] > 15) {
        // Single dosha dominant
        prakritiType = dominant.charAt(0).toUpperCase() + dominant.slice(1);
    } else if (sortedDoshas[1][1] - sortedDoshas[2][1] > 10) {
        // Dual dosha
        prakritiType = `${dominant.charAt(0).toUpperCase() + dominant.slice(1)}-${secondary.charAt(0).toUpperCase() + secondary.slice(1)}`;
    } else {
        // Tridoshic
        prakritiType = "Tridoshic";
    }
    
    // Determine Agni type
    const agniType = determineAgniType(doshaPercentages);
    
    // Determine dominant guna
    const sortedGunas = Object.entries(gunaPercentages).sort((a, b) => b[1] - a[1]);
    const dominantGuna = sortedGunas[0][0];
    
    return {
        dosha: doshaPercentages,
        type: prakritiType,
        dominant,
        secondary,
        agniType,
        agni: AGNI_TYPES[agniType],
        manasPrakriti: {
            guna: gunaPercentages,
            dominant: dominantGuna,
        },
        rawPoints: doshaPoints,
    };
}

// ============================================================================
// VIKRITI (CURRENT STATE) CALCULATION
// ============================================================================

/**
 * Calculate current Vikriti (imbalance state)
 * 
 * Enhanced with authentic Vedic astrology factors:
 * - Dasha planet dignity (exalted planets = milder effects)
 * - Tarabala (daily Moon nakshatra relationship)
 * - Chandrabala (daily Moon sign position)
 * - Transit Ashtakavarga scores
 * 
 * @param {Object} params
 * @param {Object} params.prakriti - Base Prakriti dosha percentages
 * @param {string} params.currentDashaPlanet - Current Mahadasha planet
 * @param {string} params.currentAntarDashaPlanet - Current Antardasha planet (optional)
 * @param {number} params.age - Current age
 * @param {number} params.currentMonth - Current month (1-12)
 * @param {Object} params.symptoms - Optional symptom scores { vata: n, pitta: n, kapha: n }
 * @param {Object} params.transitEffect - Optional transit-based dosha deltas { vata: n, pitta: n, kapha: n }
 * @param {Array<Object>} params.transitFactors - Optional human-readable transit factors
 * @param {Object} params.dashaPlanetDignity - Dasha planet's natal dignity (e.g., { dignity: "exalted", isYogakaraka: true })
 * @param {Object} params.tarabala - Tarabala calculation result from calculateTarabala()
 * @param {Object} params.chandrabala - Chandrabala calculation result from calculateChandrabala()
 * @param {Object} params.transitBinduScores - BAV scores for slow transits { Saturn: { bindus: 3, quality: "challenging" }, ... }
 * @returns {Object} Vikriti calculation with imbalances
 */
export function calculateVikriti({ 
    prakriti, 
    currentDashaPlanet, 
    currentAntarDashaPlanet,
    age, 
    currentMonth,
    symptoms,
    transitEffect,
    transitFactors,
    // New enhanced parameters
    dashaPlanetDignity,
    tarabala,
    chandrabala,
    transitBinduScores,
}) {
    // Start with Prakriti as base
    const vikriti = { 
        vata: prakriti.vata, 
        pitta: prakriti.pitta, 
        kapha: prakriti.kapha 
    };
    
    const factors = [];
    
    // 1. Apply Mahadasha effect (enhanced with Shadbala/dignity modifier)
    if (currentDashaPlanet && DASHA_DOSHA_EFFECT[currentDashaPlanet]) {
        const dashaEffect = DASHA_DOSHA_EFFECT[currentDashaPlanet];
        
        // Calculate strength multiplier (prefers Shadbala from API when available)
        let dignityMultiplier = 1.0;
        let dignityDescription = "";
        
        if (dashaPlanetDignity) {
            // Pass Shadbala to getDignityMultiplier - it will use API data if available
            dignityMultiplier = getDignityMultiplier(
                dashaPlanetDignity.dignity,
                dashaPlanetDignity.shadBalaStrength, // From API when available
            );
            
            // Note if using Shadbala (more accurate)
            if (dashaPlanetDignity.usingShadBala) {
                const strength = dashaPlanetDignity.shadBalaStrength;
                const strengthLabel = strength >= 1.2 ? "strong" : strength >= 0.8 ? "average" : "weak";
                dignityDescription = ` (Shadbala: ${strength.toFixed(2)} - ${strengthLabel})`;
            }
            
            // Yogakaraka planets reduce negative effects
            if (dashaPlanetDignity.isYogakaraka) {
                dignityMultiplier *= 0.8;
                dignityDescription += " (Yogakaraka)";
            }
            
            // Dusthana lords amplify negative effects
            if (dashaPlanetDignity.isDusthanaLord) {
                dignityMultiplier *= 1.2;
                dignityDescription += ` (rules ${dashaPlanetDignity.dusthanaHouses?.join(", ")}th)`;
            }
        }
        
        // Apply dasha effect with dignity modifier
        vikriti.vata += dashaEffect.vata * dignityMultiplier;
        vikriti.pitta += dashaEffect.pitta * dignityMultiplier;
        vikriti.kapha += dashaEffect.kapha * dignityMultiplier;
        
        if (dashaEffect.vata > 0 || dashaEffect.pitta > 0 || dashaEffect.kapha > 0) {
            const dominantEffect = Object.entries(dashaEffect).sort((a, b) => b[1] - a[1])[0];
            if (dominantEffect[1] > 0) {
                const dignityNote = dashaPlanetDignity?.dignity 
                    ? ` (${dashaPlanetDignity.dignity}${dignityDescription})`
                    : "";
                factors.push({
                    source: "dasha",
                    description: `${currentDashaPlanet} Mahadasha${dignityNote}`,
                    dosha: dominantEffect[0],
                    strength: Math.round(dominantEffect[1] * dignityMultiplier),
                    dignityMultiplier: dignityMultiplier !== 1.0 ? dignityMultiplier : undefined,
                });
            }
        }
    }
    
    // 2. Apply Antardasha effect (half strength)
    if (currentAntarDashaPlanet && DASHA_DOSHA_EFFECT[currentAntarDashaPlanet]) {
        const antarEffect = DASHA_DOSHA_EFFECT[currentAntarDashaPlanet];
        vikriti.vata += antarEffect.vata * 0.5;
        vikriti.pitta += antarEffect.pitta * 0.5;
        vikriti.kapha += antarEffect.kapha * 0.5;
    }
    
    // 3. Apply Tarabala (daily Moon nakshatra effect)
    if (tarabala && tarabala.doshaEffect) {
        vikriti.vata += tarabala.doshaEffect.vata || 0;
        vikriti.pitta += tarabala.doshaEffect.pitta || 0;
        vikriti.kapha += tarabala.doshaEffect.kapha || 0;
        
        factors.push({
            source: "tarabala",
            description: `Tarabala: ${tarabala.tara} (${tarabala.favorable ? "favorable" : "challenging"})`,
            dosha: "vata", // Tarabala primarily affects Vata (mental/nervous)
            strength: Math.abs(tarabala.doshaEffect.vata || 0),
            favorable: tarabala.favorable,
            guidance: tarabala.effect,
        });
    }
    
    // 4. Apply Chandrabala (daily Moon sign effect)
    if (chandrabala && chandrabala.doshaEffect) {
        vikriti.vata += chandrabala.doshaEffect.vata || 0;
        vikriti.pitta += chandrabala.doshaEffect.pitta || 0;
        vikriti.kapha += chandrabala.doshaEffect.kapha || 0;
        
        // Ashtama Chandra (8th from birth Moon) is particularly significant
        if (chandrabala.isAshtamaChandra) {
            factors.push({
                source: "chandrabala",
                description: "Ashtama Chandra - Moon in 8th from birth Moon",
                dosha: "vata",
                strength: 10,
                favorable: false,
                guidance: "Take extra care with stress management today. Avoid major decisions if possible.",
            });
        } else if (!chandrabala.favorable) {
            factors.push({
                source: "chandrabala",
                description: `Moon ${chandrabala.position}th from birth Moon`,
                dosha: "vata",
                strength: Math.abs(chandrabala.doshaEffect.vata || 0),
                favorable: false,
                guidance: chandrabala.effect,
            });
        }
    }
    
    // 5. Apply transit Ashtakavarga effects (for slow planets)
    if (transitBinduScores && typeof transitBinduScores === "object") {
        for (const [planet, score] of Object.entries(transitBinduScores)) {
            if (!score || typeof score.bindus !== "number") continue;
            
            const doshaInfo = PLANET_DOSHA[planet];
            if (!doshaInfo) continue;
            
            // Low bindus (0-2) = challenging transit, High (5-8) = protective
            // Calculate effect: (4 - bindus) gives us -4 to +4 range
            const transitStrength = (4 - score.bindus) * 1.5; // Scale to meaningful range
            
            if (Math.abs(transitStrength) >= 2) {
                vikriti[doshaInfo.primary] += transitStrength;
                
                factors.push({
                    source: "ashtakavarga",
                    description: `${planet} transit (${score.bindus} bindus - ${score.quality})`,
                    dosha: doshaInfo.primary,
                    strength: Math.abs(Math.round(transitStrength)),
                    favorable: score.quality === "favorable",
                    bindus: score.bindus,
                });
            }
        }
    }
    
    // 6. Apply life stage effect
    if (age !== undefined && age !== null) {
        const lifeStageEffect = getLifeStageEffect(age);
        vikriti.vata += lifeStageEffect.vata;
        vikriti.pitta += lifeStageEffect.pitta;
        vikriti.kapha += lifeStageEffect.kapha;
        
        const stage = getLifeStage(age);
        factors.push({
            source: "lifeStage",
            description: `${stage.charAt(0).toUpperCase() + stage.slice(1)} stage of life`,
            dosha: stage,
            strength: LIFE_STAGE_DOSHA[stage].effect[stage],
        });
    }
    
    // 7. Apply seasonal effect
    if (currentMonth) {
        const season = getVedicSeason(currentMonth);
        vikriti.vata += season.effect.vata;
        vikriti.pitta += season.effect.pitta;
        vikriti.kapha += season.effect.kapha;
        
        factors.push({
            source: "season",
            description: `${season.name} (${season.season})`,
            dosha: season.dominantDosha,
            strength: season.effect[season.dominantDosha],
            guidance: season.guidance,
        });
    }
    
    // 8. Apply symptom input (if provided)
    if (symptoms) {
        const symptomWeight = 5;
        vikriti.vata += (symptoms.vata || 0) * symptomWeight;
        vikriti.pitta += (symptoms.pitta || 0) * symptomWeight;
        vikriti.kapha += (symptoms.kapha || 0) * symptomWeight;
    }

    // 9. Apply transit-based adjustments (if provided)
    // Kept intentionally low-impact so transits refine rather than override.
    if (transitEffect) {
        vikriti.vata += Number(transitEffect.vata || 0);
        vikriti.pitta += Number(transitEffect.pitta || 0);
        vikriti.kapha += Number(transitEffect.kapha || 0);
    }

    if (transitFactors && Array.isArray(transitFactors) && transitFactors.length > 0) {
        for (const f of transitFactors) {
            if (f && typeof f === "object") factors.push(f);
        }
    }
    
    // Normalize to percentages
    const total = vikriti.vata + vikriti.pitta + vikriti.kapha;
    const vikritiPercentages = {
        vata: Math.round((vikriti.vata / total) * 100),
        pitta: Math.round((vikriti.pitta / total) * 100),
        kapha: Math.round((vikriti.kapha / total) * 100),
    };
    
    // Ensure sum is 100
    const sum = vikritiPercentages.vata + vikritiPercentages.pitta + vikritiPercentages.kapha;
    if (sum !== 100) {
        const maxDosha = Object.entries(vikritiPercentages).reduce((a, b) => a[1] > b[1] ? a : b)[0];
        vikritiPercentages[maxDosha] += (100 - sum);
    }
    
    // Detect imbalances (difference from Prakriti > 10%)
    const imbalances = [];
    for (const dosha of ["vata", "pitta", "kapha"]) {
        const shift = vikritiPercentages[dosha] - prakriti[dosha];
        if (shift > 10) {
            imbalances.push({
                dosha,
                shift,
                severity: shift > 20 ? "high" : "moderate",
                prakritiValue: prakriti[dosha],
                vikritiValue: vikritiPercentages[dosha],
            });
        }
    }
    
    return {
        dosha: vikritiPercentages,
        imbalances,
        factors,
        balanced: imbalances.length === 0,
    };
}

// ============================================================================
// HEALTH VULNERABILITY ANALYSIS
// ============================================================================

/**
 * Analyze health vulnerabilities from chart data
 * 
 * @param {Object} params
 * @param {string} params.sixthHouseSign - Sign on 6th house cusp
 * @param {Array} params.planetsIn6th - Planets in 6th house
 * @param {Array} params.weakPlanets - Planets that are debilitated, combust, or low Shadbala
 * @param {string} params.sixthLord - Planet ruling 6th house
 * @param {string} params.sixthLordPlacement - House where 6th lord is placed
 */
export function analyzeHealthVulnerabilities({
    sixthHouseSign,
    planetsIn6th,
    weakPlanets,
    sixthLord,
    sixthLordPlacement,
}) {
    const vulnerabilities = [];
    
    // 6th house sign indicates general disease tendency
    if (sixthHouseSign) {
        const dosha = SIGN_DOSHA[normalizeSign(sixthHouseSign)];
        vulnerabilities.push({
            type: "6thHouseSign",
            sign: sixthHouseSign,
            dosha,
            description: `${dosha.charAt(0).toUpperCase() + dosha.slice(1)}-related health challenges`,
        });
    }
    
    // Planets in 6th house indicate specific vulnerabilities
    if (planetsIn6th && planetsIn6th.length > 0) {
        for (const planet of planetsIn6th) {
            const dhatuInfo = PLANET_DHATU[planet];
            if (dhatuInfo) {
                vulnerabilities.push({
                    type: "planetIn6th",
                    planet,
                    dhatu: dhatuInfo.dhatu,
                    systems: dhatuInfo.systems,
                    organs: dhatuInfo.organs,
                    description: `${planet} in 6th house may affect ${dhatuInfo.organs.join(", ")}`,
                });
            }
        }
    }
    
    // Weak planets indicate vulnerabilities in their domains
    if (weakPlanets && weakPlanets.length > 0) {
        for (const { planet, reason } of weakPlanets) {
            const dhatuInfo = PLANET_DHATU[planet];
            if (dhatuInfo) {
                vulnerabilities.push({
                    type: "weakPlanet",
                    planet,
                    reason,
                    dhatu: dhatuInfo.dhatu,
                    organs: dhatuInfo.organs,
                    description: `${planet} (${reason}) may cause weakness in ${dhatuInfo.organs.join(", ")}`,
                });
            }
        }
    }
    
    return vulnerabilities;
}

// ============================================================================
// RECOMMENDATIONS
// ============================================================================

export const DOSHA_RECOMMENDATIONS = {
    vata: {
        foods: {
            favor: [
                "Warm soups and stews",
                "Cooked grains (rice, oats)",
                "Root vegetables",
                "Ghee and healthy oils",
                "Sweet fruits (bananas, mangoes)",
                "Warm spices (ginger, cinnamon)",
                "Dairy products",
                "Nuts and seeds",
            ],
            avoid: [
                "Raw salads and cold foods",
                "Dry snacks (crackers, chips)",
                "Carbonated drinks",
                "Excessive caffeine",
                "Beans (unless well-cooked)",
                "Cold cereals",
            ],
        },
        lifestyle: [
            "Maintain regular meal and sleep times",
            "Warm oil self-massage (Abhyanga) with sesame oil",
            "Gentle yoga and stretching",
            "Avoid excessive travel or stimulation",
            "Stay warm, avoid cold and wind",
            "Practice grounding meditation",
        ],
        exercise: "Gentle: yoga, walking, swimming",
        sleep: "Early bed (by 10 PM), 7-8 hours, keep warm",
        quickRemedies: {
            anxiety: "Warm milk with nutmeg before bed",
            constipation: "Warm water with ghee in morning",
            insomnia: "Foot massage with warm sesame oil",
            dryness: "Daily warm oil self-massage",
        },
    },
    pitta: {
        foods: {
            favor: [
                "Cooling foods (cucumber, melon)",
                "Sweet and bitter vegetables",
                "Coconut and coconut water",
                "Dairy (milk, ghee)",
                "Sweet fruits",
                "Cooling spices (coriander, fennel)",
                "Leafy greens",
                "Rice and wheat",
            ],
            avoid: [
                "Spicy foods",
                "Fermented foods",
                "Sour fruits",
                "Red meat",
                "Alcohol",
                "Excessive salt",
                "Fried foods",
            ],
        },
        lifestyle: [
            "Avoid overheating and direct sun",
            "Cooling activities and moonlight walks",
            "Moderate, non-competitive exercise",
            "Take breaks from intense work",
            "Spend time in nature",
            "Practice calming pranayama",
        ],
        exercise: "Moderate: swimming, hiking, cycling",
        sleep: "Cool room, moderate sleep (6-7 hours)",
        quickRemedies: {
            anger: "Coconut water, walk in nature",
            acidity: "Fennel tea after meals",
            skinIssues: "Aloe vera gel, avoid spicy food",
            overheating: "Rose water spray, cucumber",
        },
    },
    kapha: {
        foods: {
            favor: [
                "Light, warm foods",
                "Spicy foods (ginger, pepper)",
                "Leafy greens and vegetables",
                "Legumes and beans",
                "Honey (in moderation)",
                "Barley and millet",
                "Astringent fruits (apples, pomegranate)",
            ],
            avoid: [
                "Heavy, oily foods",
                "Dairy products",
                "Sweet foods",
                "Cold foods and drinks",
                "Excessive wheat and rice",
                "Red meat",
                "Deep-fried foods",
            ],
        },
        lifestyle: [
            "Wake before 6 AM",
            "Vigorous morning exercise",
            "Dry brushing before shower",
            "Avoid daytime sleeping",
            "Stay active and engaged",
            "Practice stimulating pranayama",
        ],
        exercise: "Vigorous: running, aerobics, weight training",
        sleep: "Early wake (before 6 AM), avoid oversleeping (6 hours sufficient)",
        quickRemedies: {
            congestion: "Ginger tea with honey",
            lethargy: "Morning exercise, skip or light breakfast",
            weight: "Warm water with honey and lemon",
            heaviness: "Light dinner, evening walk",
        },
    },
};

/**
 * Get recommendations for a dosha imbalance
 */
export function getRecommendations(dosha, severity = "moderate") {
    const recs = DOSHA_RECOMMENDATIONS[dosha];
    if (!recs) return null;
    
    return {
        dosha,
        severity,
        ...recs,
    };
}

// ============================================================================
// DOSHA CLOCK (DINACHARYA)
// Time-based dosha dominance
// ============================================================================

export const DOSHA_CLOCK = [
    { start: 2, end: 6, dosha: "vata", period: "Early morning", guidance: "Light sleep, spiritual practices, wake before 6" },
    { start: 6, end: 10, dosha: "kapha", period: "Morning", guidance: "Exercise, light breakfast, most energy for physical activity" },
    { start: 10, end: 14, dosha: "pitta", period: "Midday", guidance: "Main meal, focused work, strongest digestion" },
    { start: 14, end: 18, dosha: "vata", period: "Afternoon", guidance: "Creative work, light snack, avoid overstimulation" },
    { start: 18, end: 22, dosha: "kapha", period: "Evening", guidance: "Light dinner, wind down, relaxation" },
    { start: 22, end: 2, dosha: "pitta", period: "Night", guidance: "Deep sleep, body repairs, be asleep before 10 PM" },
];

/**
 * Get current dosha period based on hour
 */
export function getCurrentDoshaPeriod(hour) {
    for (const period of DOSHA_CLOCK) {
        if (period.start <= period.end) {
            if (hour >= period.start && hour < period.end) {
                return period;
            }
        } else {
            // Handles wrap-around (22-2)
            if (hour >= period.start || hour < period.end) {
                return period;
            }
        }
    }
    return DOSHA_CLOCK[0];
}

// ============================================================================
// TARABALA & CHANDRABALA (Daily Moon Effects)
// Classical Vedic Muhurta calculations for daily wellbeing
// ============================================================================

/**
 * 27 Nakshatras in order
 */
const NAKSHATRAS = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra",
    "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni",
    "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha", "Jyeshtha",
    "Moola", "Purva Ashadha", "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha",
    "Purva Bhadrapada", "Uttara Bhadrapada", "Revati",
];

/**
 * 12 Zodiac signs in order
 */
const SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
];

/**
 * Tara types and their meanings
 * Remainder from dividing nakshatra count by 9
 */
const TARA_TYPES = {
    1: { name: "Janma", favorable: false, effect: "Birth star - mental tension, avoid new ventures", doshaEffect: { vata: 8, pitta: 0, kapha: 0 } },
    2: { name: "Sampat", favorable: true, effect: "Prosperity - favorable for wealth and growth", doshaEffect: { vata: -3, pitta: 0, kapha: 0 } },
    3: { name: "Vipat", favorable: false, effect: "Danger - risk of loss or harm", doshaEffect: { vata: 6, pitta: 3, kapha: 0 } },
    4: { name: "Kshema", favorable: true, effect: "Welfare - safety and comfort", doshaEffect: { vata: -4, pitta: 0, kapha: 0 } },
    5: { name: "Pratyak", favorable: false, effect: "Obstacles - delays and hindrances", doshaEffect: { vata: 5, pitta: 0, kapha: 2 } },
    6: { name: "Sadhaka", favorable: true, effect: "Achievement - success in undertakings", doshaEffect: { vata: -3, pitta: -2, kapha: 0 } },
    7: { name: "Vadha", favorable: false, effect: "Adversity - potential for harm", doshaEffect: { vata: 7, pitta: 4, kapha: 0 } },
    8: { name: "Mitra", favorable: true, effect: "Friendship - harmony and support", doshaEffect: { vata: -4, pitta: 0, kapha: -2 } },
    9: { name: "Parama Mitra", favorable: true, effect: "Best friend - highly auspicious", doshaEffect: { vata: -5, pitta: -2, kapha: -2 } },
};

/**
 * Normalize nakshatra name for lookup
 */
function normalizeNakshatraName(nakshatra) {
    if (!nakshatra) return null;
    
    // Common variations mapping
    const variations = {
        "poorva phalguni": "Purva Phalguni",
        "uttara phalguni": "Uttara Phalguni", 
        "poorva ashadha": "Purva Ashadha",
        "uttara ashadha": "Uttara Ashadha",
        "poorva bhadrapada": "Purva Bhadrapada",
        "uttara bhadrapada": "Uttara Bhadrapada",
        "krittika": "Krittika",
        "kritika": "Krittika",
        "mrigasira": "Mrigashira",
        "mrigashirsha": "Mrigashira",
        "punarvasu": "Punarvasu",
        "purnavasu": "Punarvasu",
    };
    
    const lower = nakshatra.toLowerCase().trim();
    if (variations[lower]) return variations[lower];
    
    // Try to find exact match
    const found = NAKSHATRAS.find(n => n.toLowerCase() === lower);
    if (found) return found;
    
    // Try partial match
    const partial = NAKSHATRAS.find(n => 
        n.toLowerCase().includes(lower) || lower.includes(n.toLowerCase())
    );
    return partial || nakshatra;
}

/**
 * Get nakshatra index (0-26) from name
 */
function getNakshatraIndex(nakshatra) {
    if (!nakshatra) return -1;
    const normalized = normalizeNakshatraName(nakshatra);
    return NAKSHATRAS.findIndex(n => n.toLowerCase() === normalized.toLowerCase());
}

/**
 * Get sign index (0-11) from name
 */
function getSignIndex(sign) {
    if (!sign) return -1;
    return SIGNS.findIndex(s => s.toLowerCase() === sign.toLowerCase());
}

/**
 * Calculate Tarabala (Nakshatra relationship)
 * Based on the position of current Moon nakshatra relative to birth nakshatra
 * 
 * @param {string} birthNakshatra - User's birth (Janma) nakshatra
 * @param {string} currentMoonNakshatra - Current Moon's nakshatra
 * @returns {Object} Tarabala result with type, favorability, and dosha effect
 */
export function calculateTarabala(birthNakshatra, currentMoonNakshatra) {
    const birthIdx = getNakshatraIndex(birthNakshatra);
    const currentIdx = getNakshatraIndex(currentMoonNakshatra);
    
    if (birthIdx < 0 || currentIdx < 0) {
        return {
            tara: null,
            favorable: null,
            effect: "Could not calculate - invalid nakshatra",
            doshaEffect: { vata: 0, pitta: 0, kapha: 0 },
        };
    }
    
    // Count from birth nakshatra to current (1-indexed, inclusive)
    let count = ((currentIdx - birthIdx + 27) % 27) + 1;
    
    // Get remainder when divided by 9 (1-9)
    let remainder = count % 9;
    if (remainder === 0) remainder = 9;
    
    const taraInfo = TARA_TYPES[remainder];
    
    return {
        tara: taraInfo.name,
        count,
        remainder,
        favorable: taraInfo.favorable,
        effect: taraInfo.effect,
        doshaEffect: taraInfo.doshaEffect,
        birthNakshatra: NAKSHATRAS[birthIdx],
        currentNakshatra: NAKSHATRAS[currentIdx],
    };
}

/**
 * Calculate Chandrabala (Moon sign relationship)
 * Based on the position of current Moon sign relative to birth Moon sign
 * 
 * @param {string} birthMoonSign - User's birth Moon sign
 * @param {string} currentMoonSign - Current Moon's sign
 * @returns {Object} Chandrabala result with position and effect
 */
export function calculateChandrabala(birthMoonSign, currentMoonSign) {
    const birthIdx = getSignIndex(birthMoonSign);
    const currentIdx = getSignIndex(currentMoonSign);
    
    if (birthIdx < 0 || currentIdx < 0) {
        return {
            position: null,
            favorable: null,
            effect: "Could not calculate - invalid sign",
            doshaEffect: { vata: 0, pitta: 0, kapha: 0 },
        };
    }
    
    // Calculate position from birth Moon (1-indexed)
    const position = ((currentIdx - birthIdx + 12) % 12) + 1;
    
    // Determine favorability and effect
    let favorable, effect, doshaEffect;
    
    switch (position) {
        case 1: // Same sign
            favorable = true;
            effect = "Moon in birth sign - emotional stability";
            doshaEffect = { vata: -3, pitta: 0, kapha: 0 };
            break;
        case 2: // 2nd from Moon
            favorable = true;
            effect = "Moon in 2nd - good for resources and comfort";
            doshaEffect = { vata: -2, pitta: 0, kapha: 1 };
            break;
        case 3: // 3rd from Moon
            favorable = true;
            effect = "Moon in 3rd - courage and initiative";
            doshaEffect = { vata: 0, pitta: 2, kapha: -2 };
            break;
        case 4: // 4th from Moon
            favorable = false;
            effect = "Moon in 4th - some emotional tension";
            doshaEffect = { vata: 3, pitta: 0, kapha: 2 };
            break;
        case 5: // 5th from Moon
            favorable = true;
            effect = "Moon in 5th - creativity and joy";
            doshaEffect = { vata: -2, pitta: 0, kapha: 0 };
            break;
        case 6: // 6th from Moon
            favorable = false;
            effect = "Moon in 6th - may face obstacles";
            doshaEffect = { vata: 4, pitta: 2, kapha: 0 };
            break;
        case 7: // 7th from Moon
            favorable = true;
            effect = "Moon in 7th - relationships highlighted";
            doshaEffect = { vata: -1, pitta: 1, kapha: 0 };
            break;
        case 8: // 8th from Moon (Ashtama Chandra - unfavorable)
            favorable = false;
            effect = "Ashtama Chandra - emotional turbulence, avoid major decisions";
            doshaEffect = { vata: 10, pitta: 0, kapha: 0 };
            break;
        case 9: // 9th from Moon
            favorable = true;
            effect = "Moon in 9th - spiritual and fortunate";
            doshaEffect = { vata: -4, pitta: 0, kapha: 0 };
            break;
        case 10: // 10th from Moon
            favorable = true;
            effect = "Moon in 10th - good for actions and career";
            doshaEffect = { vata: -2, pitta: 1, kapha: 0 };
            break;
        case 11: // 11th from Moon
            favorable = true;
            effect = "Moon in 11th - gains and fulfillment";
            doshaEffect = { vata: -3, pitta: 0, kapha: 1 };
            break;
        case 12: // 12th from Moon
            favorable = false;
            effect = "Moon in 12th - expenses, need for rest";
            doshaEffect = { vata: 5, pitta: 0, kapha: 3 };
            break;
        default:
            favorable = null;
            effect = "Unknown position";
            doshaEffect = { vata: 0, pitta: 0, kapha: 0 };
    }
    
    return {
        position,
        favorable,
        effect,
        doshaEffect,
        birthMoonSign: SIGNS[birthIdx],
        currentMoonSign: SIGNS[currentIdx],
        isAshtamaChandra: position === 8,
    };
}

/**
 * Get planet strength multiplier for dosha effects
 * PREFERS Shadbala from API when available (more accurate)
 * Falls back to dignity-based calculation
 * 
 * Stronger planets have more controlled effects, weaker planets more erratic
 * 
 * @param {string} dignity - Planet dignity (exalted, own_sign, mool_trikona, friendly, neutral, enemy, debilitated)
 * @param {number} shadBalaStrength - Optional Shadbala value from API (typically 0.5-2.0+, 1.0 = standard)
 * @returns {number} Multiplier (0.7 to 1.3)
 */
export function getDignityMultiplier(dignity, shadBalaStrength = null) {
    // PREFER SHADBALA (from API) - more accurate than dignity alone
    // Shadbala considers 6 types of strength: Sthana, Dig, Kaala, Cheshta, Drig, Naisargika
    if (shadBalaStrength != null && typeof shadBalaStrength === "number") {
        // Shadbala scale: < 0.7 = weak, 0.7-1.0 = below average, 1.0-1.3 = average, > 1.3 = strong
        if (shadBalaStrength >= 1.5) return 0.7;    // Very strong planet
        if (shadBalaStrength >= 1.2) return 0.85;   // Strong planet
        if (shadBalaStrength >= 1.0) return 0.95;   // Average planet
        if (shadBalaStrength >= 0.8) return 1.05;   // Below average
        if (shadBalaStrength >= 0.6) return 1.15;   // Weak planet
        return 1.3;                                   // Very weak planet
    }
    
    // FALLBACK to dignity-based calculation
    switch (dignity?.toLowerCase()) {
        case "exalted":
            return 0.7;  // Strong planet = reduced negative effect
        case "mool_trikona":
            return 0.8;
        case "own_sign":
            return 0.85;
        case "friendly":
            return 0.95;
        case "neutral":
            return 1.0;
        case "enemy":
            return 1.15;
        case "debilitated":
            return 1.3;  // Weak planet = amplified negative effect
        default:
            return 1.0;
    }
}

/**
 * Check if planet is a dusthana lord (rules 6th, 8th, or 12th house)
 * These lords can bring challenges during their periods
 * 
 * @param {string} planet - Planet name
 * @param {string} ascendant - Ascendant sign
 * @returns {Object} { isDusthanaLord: boolean, houses: number[] }
 */
export function checkDusthanaLordship(planet, ascendant) {
    const RULERSHIP = {
        Sun: ["Leo"],
        Moon: ["Cancer"],
        Mars: ["Aries", "Scorpio"],
        Mercury: ["Gemini", "Virgo"],
        Jupiter: ["Sagittarius", "Pisces"],
        Venus: ["Taurus", "Libra"],
        Saturn: ["Capricorn", "Aquarius"],
    };
    
    const SIGN_ORDER = [
        "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
        "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
    ];
    
    const ascIdx = SIGN_ORDER.findIndex(s => s.toLowerCase() === ascendant?.toLowerCase());
    if (ascIdx < 0) return { isDusthanaLord: false, houses: [] };
    
    const ruledSigns = RULERSHIP[planet] || [];
    const dusthanaHouses = [];
    
    for (const sign of ruledSigns) {
        const signIdx = SIGN_ORDER.findIndex(s => s.toLowerCase() === sign.toLowerCase());
        if (signIdx < 0) continue;
        
        // Calculate house number (1-indexed)
        const houseNum = ((signIdx - ascIdx + 12) % 12) + 1;
        
        // Check if it's a dusthana house
        if ([6, 8, 12].includes(houseNum)) {
            dusthanaHouses.push(houseNum);
        }
    }
    
    return {
        isDusthanaLord: dusthanaHouses.length > 0,
        houses: dusthanaHouses,
    };
}

/**
 * Check if planet is a yogakaraka for the ascendant
 * Yogakarakas rule both a kendra and a trikona, making them highly beneficial
 * 
 * @param {string} planet - Planet name
 * @param {string} ascendant - Ascendant sign
 * @returns {boolean}
 */
export function isYogakaraka(planet, ascendant) {
    const YOGAKARAKAS = {
        Taurus: "Saturn",
        Cancer: "Mars",
        Leo: "Mars",
        Libra: "Saturn",
        Capricorn: "Venus",
        Aquarius: "Venus",
    };
    
    const asc = ascendant?.charAt(0).toUpperCase() + ascendant?.slice(1).toLowerCase();
    return YOGAKARAKAS[asc] === planet;
}
