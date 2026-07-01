/**
 * ग्रह युद्ध — Graha Yuddha (Planetary War)
 *
 * Brihat Samhita, Chapter 17 (Grahayuddha)
 *
 * When two planets occupy the same sign, their effects combine.
 * When within 1° (Graha Yuddha / planetary war), one dominates.
 *
 * BS Ch.17 defines FOUR types of planetary war:
 *   1. Bheda (occultation)    — one planet hides the other. Drought, friends become enemies.
 *   2. Ullekha (grazing)      — planets nearly touch. Wars and quarrels, but abundant food.
 *   3. Amsumardana (ray-clash) — rays intermingle. Warfare, disease, hunger.
 *   4. Apasavya (deflection)  — planets pass each other. Rulers wage war with each other.
 *
 * Winner determination (classical):
 *   1. Planet with more northern latitude wins
 *   2. If equal latitude, brighter planet wins
 *   3. Retrograde planet is considered stronger (fighting back)
 *
 * REGIONAL EFFECTS (BS Ch.17): Each planet pair has specific regions
 * that suffer when those planets conjoin. This is NOT generic — the
 * original text names specific janapadas (nations/peoples).
 *
 * Only slow-planet pairs are tracked for mundane (they persist).
 * Fast-planet conjunctions with slow planets are TRIGGERS.
 */

// ─── WAR TYPES (BS Ch.17) ───────────────────────────────────────────────
// The type of war determines the NATURE of the disruption.
// Determined by angular separation and relative brightness.

export const WAR_TYPES = {
    bheda:       { name: "Bheda (Occultation)", sep: "<0.5°", effect: "Drought, friends become enemies, great families suffer", severity: 1.5 },
    ullekha:     { name: "Ullekha (Grazing)", sep: "<1°", effect: "Wars and quarrels among ministers, but abundant food", severity: 1.3 },
    amsumardana: { name: "Amsumardana (Ray-clash)", sep: "<3°", effect: "Warfare between nations, disease and poverty", severity: 1.1 },
    apasavya:    { name: "Apasavya (Deflection)", sep: "<5°", effect: "Rulers wage war with each other, ruling class fights", severity: 1.0 },
};

/**
 * Determine the war type based on angular separation.
 * @param {number} angSep - Angular separation in degrees
 * @returns {Object|null} War type or null if not close enough
 */
export function getWarType(angSep) {
    if (angSep < 0.5) return WAR_TYPES.bheda;
    if (angSep < 1.0) return WAR_TYPES.ullekha;
    if (angSep < 3.0) return WAR_TYPES.amsumardana;
    if (angSep < 5.0) return WAR_TYPES.apasavya;
    return null;
}

/**
 * Conjunction effects for planet pairs.
 * Key format: "Planet1-Planet2" (alphabetical order)
 *
 * Each entry has:
 *   combined  — effect when both are in same sign (always active)
 *   war       — additional effects when within 1° (planetary war)
 *   domains   — affected mundane domains
 */
export const CONJUNCTION_EFFECTS = {
    // ── SATURN-JUPITER (Great Conjunction — defines eras) ──────────────
    "Jupiter-Saturn": {
        combined: [
            { domain: "government", dir: "mix", desc: "Governance transformation, old order challenged by new wisdom", weight: 0.9 },
            { domain: "religion", dir: "mix", desc: "Religious reform, tension between orthodoxy and expansion", weight: 0.8 },
            { domain: "economy", dir: "mix", desc: "Economic restructuring, contraction meets growth", weight: 0.8 },
        ],
        war: {
            jupiterWins: "Reform prevails — institutions modernize, wisdom guides governance",
            saturnWins: "Conservatism prevails — austerity, restrictions tighten, old guard holds",
        },
        // BS Ch.17: "Women will be happy; buffaloes and the Scythians will suffer"
        affectedRegions: ["Central Asia (Scythians)", "pastoral/nomadic regions"],
        classicalVictims: "Women prosper; buffaloes and Scythians suffer (BS Ch.17)",
        cycle: "~20 years. Defines political-economic eras.",
        source: "BS Ch.17, also Hora Sara",
    },

    // ── MARS-SATURN (Most destructive conjunction) ─────────────────────
    "Mars-Saturn": {
        combined: [
            { domain: "military", dir: "neg", desc: "War, military conflict, violent confrontation", weight: 1.0 },
            { domain: "infrastructure", dir: "neg", desc: "Building collapses, engineering failures, earthquakes", weight: 0.9 },
            { domain: "mortality", dir: "neg", desc: "Mass casualty events, industrial accidents", weight: 0.9 },
            { domain: "labor", dir: "neg", desc: "Severe labor unrest, violent strikes", weight: 0.7 },
        ],
        war: {
            marsWins: "Sudden violence dominates — explosions, fires, military coups",
            saturnWins: "Slow destruction — siege, starvation, economic strangulation",
        },
        // BS Ch.17: "people of Tangana, of Andhra, of Orissa, of Benares and of Bahlika"
        affectedRegions: ["Andhra/Telangana", "Orissa/Odisha", "Benares/Varanasi", "Bahlika (NW India/Afghanistan)"],
        classicalVictims: "People of Tangana, Andhra, Orissa, Benares, and Bahlika suffer (BS Ch.17)",
        cycle: "~2 years. Most feared mundane conjunction.",
        source: "BS Ch.17",
    },

    // ── MARS-JUPITER (Military + morality) ─────────────────────────────
    "Jupiter-Mars": {
        combined: [
            { domain: "military", dir: "mix", desc: "Righteous war, military action with moral justification", weight: 0.8 },
            { domain: "religion", dir: "neg", desc: "Religious violence, crusade/jihad mentality", weight: 0.7 },
            { domain: "judiciary", dir: "pos", desc: "Justice enforced with force, law enforcement action", weight: 0.6 },
        ],
        war: {
            jupiterWins: "Moral authority prevails — peaceful resolution after conflict",
            marsWins: "Force prevails — might over right, military over law",
        },
        // BS Ch.17: "Bahlīkas, travellers and persons that live by fire will suffer" / "Madhyadesha and princes"
        affectedRegions: ["Madhyadesha (Central India)", "Bahlika (NW India/Afghanistan)"],
        classicalVictims: "Travellers, fire-workers, Madhyadesha princes, cows perish (BS Ch.17)",
        source: "BS Ch.17",
    },

    // ── SATURN-RAHU (Institutional collapse) ───────────────────────────
    "Rahu-Saturn": {
        combined: [
            { domain: "government", dir: "neg", desc: "Institutional collapse, corruption scandals, shadow governance", weight: 0.9 },
            { domain: "health", dir: "neg", desc: "Epidemics, mysterious mass illness, pollution crises", weight: 0.8 },
            { domain: "public_mood", dir: "neg", desc: "Mass fear, paranoia, conspiracy theories dominate", weight: 0.8 },
        ],
        war: {
            saturnWins: "Institutions survive but weakened — long-term structural damage",
            rahuWins: "Chaos prevails — unconventional forces overthrow established order",
        },
        affectedRegions: ["institutional centers", "technologically dependent regions"],
        classicalVictims: "Established institutions and their dependent populations (Phaladeepika)",
        source: "Phaladeepika, modern Jyotish consensus",
    },

    // ── MARS-RAHU (Sudden violence) ────────────────────────────────────
    "Mars-Rahu": {
        combined: [
            { domain: "military", dir: "neg", desc: "Terrorism, unconventional warfare, explosions", weight: 0.9 },
            { domain: "crisis", dir: "neg", desc: "Sudden catastrophic events, fires, chemical incidents", weight: 0.9 },
            { domain: "technology", dir: "neg", desc: "Cyberwarfare, tech used for destruction", weight: 0.7 },
        ],
        war: {
            marsWins: "Overt violence — bombings, military attacks",
            rahuWins: "Covert violence — poisoning, cyber attacks, biological threats",
        },
        affectedRegions: ["conflict zones", "border regions", "technologically vulnerable areas"],
        classicalVictims: "Military personnel, border peoples, those near fire and machinery (Phaladeepika)",
        source: "Phaladeepika, widely attested in Jyotish literature",
    },

    // ── JUPITER-RAHU (Guru Chandal Yoga) ───────────────────────────────
    "Jupiter-Rahu": {
        combined: [
            { domain: "religion", dir: "neg", desc: "Guru Chandal Yoga — false gurus, religious deception", weight: 0.9 },
            { domain: "education", dir: "neg", desc: "Academic fraud, degree mills, credential deception", weight: 0.7 },
            { domain: "judiciary", dir: "neg", desc: "Judicial corruption, laws manipulated", weight: 0.7 },
        ],
        war: {
            jupiterWins: "Truth eventually exposed — whistleblowers, reform movements",
            rahuWins: "Deception prevails — false narratives become mainstream",
        },
        affectedRegions: ["religious centers", "university towns", "legal capitals"],
        classicalVictims: "Brahmins, teachers, judges, the learned (classical Guru Chandal Yoga)",
        source: "Classical — Guru Chandal Yoga widely referenced",
    },

    // ── SUN-SATURN (Father-son tension, authority challenged) ──────────
    "Saturn-Sun": {
        combined: [
            { domain: "government", dir: "neg", desc: "Ruler's authority directly challenged, power struggles", weight: 0.8 },
            { domain: "public_mood", dir: "neg", desc: "Masses vs authority, civil disobedience", weight: 0.7 },
            { domain: "health", dir: "neg", desc: "Leader's health concerns, vitality of nation depleted", weight: 0.6 },
        ],
        war: {
            sunWins: "Authority holds — ruler suppresses opposition",
            saturnWins: "Authority falls — ruler replaced, regime change",
        },
        affectedRegions: ["national capitals", "seats of executive power"],
        classicalVictims: "Kings, rulers, father figures, men of authority (BS Ch.17)",
        source: "BS Ch.17, classical Sun-Saturn enmity",
    },

    // ── SUN-MARS (Military authority) ──────────────────────────────────
    "Mars-Sun": {
        combined: [
            { domain: "military", dir: "mix", desc: "Military action by government, executive military orders", weight: 0.7 },
            { domain: "government", dir: "mix", desc: "Aggressive governance, police state tendencies", weight: 0.6 },
        ],
        war: {
            sunWins: "Government controls military — ordered aggression",
            marsWins: "Military overrides government — coup potential",
        },
        affectedRegions: ["military installations", "executive capital regions"],
        classicalVictims: "Soldiers, Kshatriyas, rulers engaged in warfare (BS Ch.17)",
        source: "BS Ch.17",
    },

    // ── VENUS-SATURN (Beauty meets austerity) ──────────────────────────
    "Saturn-Venus": {
        combined: [
            { domain: "economy", dir: "neg", desc: "Luxury markets crash, artistic funding cut", weight: 0.7 },
            { domain: "agriculture", dir: "neg", desc: "Drought, famine, food shortages", weight: 0.7 },
            { domain: "culture", dir: "neg", desc: "Cultural austerity, entertainment restricted", weight: 0.6 },
        ],
        // BS Ch.17: "price of food grains will rise and snakes and birds will suffer"
        affectedRegions: ["agricultural regions", "luxury markets", "entertainment capitals"],
        classicalVictims: "Food grain prices rise; snakes, birds, chiefs of tribes suffer (BS Ch.17)",
        source: "BS Ch.17, Saturn-Venus natural enmity",
    },

    // ── MERCURY-SATURN (Communication blocked) ─────────────────────────
    "Mercury-Saturn": {
        combined: [
            { domain: "trade", dir: "neg", desc: "Commerce halted, trade sanctions, supply chain failures", weight: 0.8 },
            { domain: "media", dir: "neg", desc: "Censorship, press restrictions, communication blackouts", weight: 0.7 },
            { domain: "education", dir: "neg", desc: "Schools disrupted, educational access reduced", weight: 0.6 },
        ],
        // BS Ch.17: "People of Bengal, tradesmen, birds, animals and snakes will suffer"
        affectedRegions: ["Bengal/Bangladesh", "trading hubs", "communication centers"],
        classicalVictims: "People of Bengal, tradesmen, birds, animals and snakes suffer (BS Ch.17)",
        source: "BS Ch.17",
    },

    // ── VENUS-MARS (Passion meets aggression) ──────────────────────────
    "Mars-Venus": {
        combined: [
            { domain: "culture", dir: "mix", desc: "Passionate creative expression, art as protest", weight: 0.6 },
            { domain: "foreign_affairs", dir: "mix", desc: "Diplomatic confrontation followed by reconciliation", weight: 0.6 },
        ],
        // BS Ch.17: "Chiefs of armies will perish and princes will be at war"
        affectedRegions: ["diplomatic centers", "cultural capitals"],
        classicalVictims: "Chiefs of armies perish, princes go to war (BS Ch.17)",
        source: "BS Ch.17",
    },

    // ── JUPITER-VENUS (Two benefics — prosperity) ──────────────────────
    "Jupiter-Venus": {
        combined: [
            { domain: "economy", dir: "pos", desc: "Financial prosperity, arts and commerce flourish", weight: 0.8 },
            { domain: "diplomacy", dir: "pos", desc: "Peaceful relations, cultural exchange", weight: 0.7 },
            { domain: "religion", dir: "pos", desc: "Religious celebrations, interfaith harmony", weight: 0.6 },
        ],
        // BS Ch.17: "crops and cows will perish" (even benefics in war cause harm)
        affectedRegions: ["agricultural regions", "religious centers"],
        classicalVictims: "When in war: crops and cows perish despite benefic nature (BS Ch.17)",
        source: "BS Ch.17",
    },

    // ── MERCURY-MARS (Words as weapons) ────────────────────────────────
    "Mars-Mercury": {
        combined: [
            { domain: "media", dir: "neg", desc: "Aggressive propaganda, weaponized information", weight: 0.7 },
            { domain: "technology", dir: "mix", desc: "Military technology advances, cyber tools", weight: 0.6 },
        ],
        // BS Ch.17: "Surasenas, Kalingas, and Salvas suffer" / "trees, rivers, ascetics, northern peoples"
        affectedRegions: ["Surasena (Mathura region)", "Kalinga (Odisha)", "Northern India"],
        classicalVictims: "Surasenas, Kalingas, Salvas; trees, rivers, ascetics suffer (BS Ch.17)",
        source: "BS Ch.17",
    },

    // ── JUPITER-MERCURY (Wisdom meets intellect) ───────────────────────
    "Jupiter-Mercury": {
        combined: [
            { domain: "education", dir: "pos", desc: "Educational excellence, publishing boom, scholarships", weight: 0.7 },
            { domain: "trade", dir: "pos", desc: "Ethical commerce, fair trade initiatives", weight: 0.6 },
        ],
        // BS Ch.17: "Mlecchas, truthful men, armed soldiers and Madhyadesha"
        affectedRegions: ["Madhyadesha (Central India)", "border regions (Mleccha-desha)"],
        classicalVictims: "Mlecchas, Shudras, thieves, rich men; earthquakes possible (BS Ch.17)",
        source: "BS Ch.17",
    },
};

/**
 * Get the normalized key for a planet pair (alphabetical order).
 */
function getPairKey(p1, p2) {
    return [p1, p2].sort().join("-");
}

/**
 * Maximum angular separation for a conjunction to be active.
 * Same-sign but >8° is too wide to be a meaningful conjunction.
 * Classical texts focus on close conjunctions (< 5° for war effects).
 * We allow up to 8° for "same-sign influence" with reduced weight.
 */
const MAX_CONJUNCTION_ORB = 8.0;

/**
 * Find all active conjunctions (same-sign, within orb) from positions.
 * Now includes BS Ch.17 war types and regional effects.
 * Skips conjunctions wider than MAX_CONJUNCTION_ORB degrees.
 *
 * @param {Object} positions - { planet: { sign, longitude, ... } }
 * @returns {Object[]} Active conjunctions with effects, war types, and regional data
 */
export function findActiveConjunctions(positions) {
    const results = [];
    const planets = Object.keys(positions);

    for (let i = 0; i < planets.length; i++) {
        for (let j = i + 1; j < planets.length; j++) {
            const p1 = planets[i];
            const p2 = planets[j];
            const pos1 = positions[p1];
            const pos2 = positions[p2];

            if (!pos1?.sign || !pos2?.sign || pos1.sign !== pos2.sign) continue;

            const key = getPairKey(p1, p2);
            const effects = CONJUNCTION_EFFECTS[key];
            if (!effects) continue;

            // Calculate angular separation
            const sep = Math.abs((pos1.longitude || 0) - (pos2.longitude || 0));
            const angSep = Math.min(sep, 360 - sep);

            // Skip conjunctions wider than the orb limit
            if (angSep > MAX_CONJUNCTION_ORB) continue;

            // BS Ch.17: Four types of planetary war
            const warType = getWarType(angSep);
            const isWar = angSep < 1.0;       // Classical Graha Yuddha threshold
            const isClose = angSep < 5.0;     // Any of the 4 war types

            // Wide conjunctions (5-8°) get a distance penalty
            const distancePenalty = angSep > 5.0 ? 0.7 : 1.0;

            results.push({
                planets: [p1, p2],
                sign: pos1.sign,
                separation: angSep,
                isWar,
                isClose,
                distancePenalty,
                warType,                        // Bheda/Ullekha/Amsumardana/Apasavya
                effects: effects.combined,
                warEffects: isWar ? effects.war : null,
                affectedRegions: effects.affectedRegions || [],
                classicalVictims: effects.classicalVictims || null,
                source: effects.source,
                ruleId: `conjunction_${key.toLowerCase().replace("-", "_")}`,
            });
        }
    }

    return results.sort((a, b) => a.separation - b.separation);
}
