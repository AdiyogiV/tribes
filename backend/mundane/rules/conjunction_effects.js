/**
 * Conjunction Effects — Brihat Samhita Planetary War Rules
 *
 * Source: Brihat Samhita Ch.17 (Grahayuddha — Planetary War)
 * Also: Saravali, Hora Sara for additional pairs
 *
 * When two planets occupy the same sign, their effects combine.
 * When within 1° (Graha Yuddha / planetary war), one dominates.
 *
 * Winner determination (classical):
 *   1. Planet with more northern latitude wins
 *   2. If equal latitude, brighter planet wins
 *   3. Retrograde planet is considered stronger (fighting back)
 *
 * In practice for our system: we note both interpretations
 * (winner A vs winner B) and let the synthesis agent resolve
 * based on dignity and speed context.
 *
 * Only slow-planet pairs are tracked for mundane (they persist).
 * Fast-planet conjunctions with slow planets are TRIGGERS.
 */

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
        source: "BS Ch.17",
    },

    // ── VENUS-SATURN (Beauty meets austerity) ──────────────────────────
    "Saturn-Venus": {
        combined: [
            { domain: "economy", dir: "neg", desc: "Luxury markets crash, artistic funding cut", weight: 0.7 },
            { domain: "agriculture", dir: "neg", desc: "Drought, famine, food shortages", weight: 0.7 },
            { domain: "culture", dir: "neg", desc: "Cultural austerity, entertainment restricted", weight: 0.6 },
        ],
        source: "BS Ch.17, Saturn-Venus natural enmity",
    },

    // ── MERCURY-SATURN (Communication blocked) ─────────────────────────
    "Mercury-Saturn": {
        combined: [
            { domain: "trade", dir: "neg", desc: "Commerce halted, trade sanctions, supply chain failures", weight: 0.8 },
            { domain: "media", dir: "neg", desc: "Censorship, press restrictions, communication blackouts", weight: 0.7 },
            { domain: "education", dir: "neg", desc: "Schools disrupted, educational access reduced", weight: 0.6 },
        ],
        source: "General Parashari principle",
    },

    // ── VENUS-MARS (Passion meets aggression) ──────────────────────────
    "Mars-Venus": {
        combined: [
            { domain: "culture", dir: "mix", desc: "Passionate creative expression, art as protest", weight: 0.6 },
            { domain: "foreign_affairs", dir: "mix", desc: "Diplomatic confrontation followed by reconciliation", weight: 0.6 },
        ],
        source: "General Parashari principle",
    },

    // ── JUPITER-VENUS (Two benefics — prosperity) ──────────────────────
    "Jupiter-Venus": {
        combined: [
            { domain: "economy", dir: "pos", desc: "Financial prosperity, arts and commerce flourish", weight: 0.8 },
            { domain: "diplomacy", dir: "pos", desc: "Peaceful relations, cultural exchange", weight: 0.7 },
            { domain: "religion", dir: "pos", desc: "Religious celebrations, interfaith harmony", weight: 0.6 },
        ],
        source: "BS, two benefics together amplify positive effects",
    },

    // ── MERCURY-MARS (Words as weapons) ────────────────────────────────
    "Mars-Mercury": {
        combined: [
            { domain: "media", dir: "neg", desc: "Aggressive propaganda, weaponized information", weight: 0.7 },
            { domain: "technology", dir: "mix", desc: "Military technology advances, cyber tools", weight: 0.6 },
        ],
        source: "General Parashari principle",
    },

    // ── JUPITER-MERCURY (Wisdom meets intellect) ───────────────────────
    "Jupiter-Mercury": {
        combined: [
            { domain: "education", dir: "pos", desc: "Educational excellence, publishing boom, scholarships", weight: 0.7 },
            { domain: "trade", dir: "pos", desc: "Ethical commerce, fair trade initiatives", weight: 0.6 },
        ],
        source: "General Parashari, natural friendship",
    },
};

/**
 * Get the normalized key for a planet pair (alphabetical order).
 */
function getPairKey(p1, p2) {
    return [p1, p2].sort().join("-");
}

/**
 * Find all active conjunctions (same-sign) from positions.
 * @param {Object} positions - { planet: { sign, longitude, ... } }
 * @returns {Object[]} Active conjunctions with effects
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

            // Calculate angular separation for war determination
            const sep = Math.abs((pos1.longitude || 0) - (pos2.longitude || 0));
            const angSep = Math.min(sep, 360 - sep);
            const isWar = angSep < 1.0;
            const isClose = angSep < 5.0;

            results.push({
                planets: [p1, p2],
                sign: pos1.sign,
                separation: angSep,
                isWar,
                isClose,
                effects: effects.combined,
                warEffects: isWar ? effects.war : null,
                source: effects.source,
                ruleId: `conjunction_${key.toLowerCase().replace("-", "_")}`,
            });
        }
    }

    return results.sort((a, b) => a.separation - b.separation);
}
