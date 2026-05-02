/**
 * ग्रहण — Grahana (Eclipse Effects)
 *
 * Brihat Samhita, Ch.4 (Chandra-grahana) & Ch.5 (Surya-grahana)
 *
 * Eclipses are the most dramatic mundane signals in classical Jyotish.
 * Each eclipse creates a "disruption window" lasting ~6 months.
 *
 * Key factors:
 *   1. Sign of eclipse → which Koorma regions are affected
 *   2. Nakshatra of eclipse → nature of disruption
 *   3. Duration of eclipse → severity (longer = worse)
 *   4. Visibility → strongest where eclipse is visible
 *   5. Solar vs Lunar → type of impact
 *
 * Solar eclipse = authority, government, leadership disrupted
 * Lunar eclipse = masses, emotions, public sentiment disrupted
 *
 * The axis matters: eclipse sign + opposite sign are BOTH activated.
 *
 * Manifestation timing (BS Ch.97):
 *   Solar eclipse effects manifest after ~1 year.
 *   Lunar eclipse effects manifest within ~6 months.
 *
 * Post-eclipse omens (BS Ch.5):
 *   Within 7 days of eclipse:
 *   - Dust storm → starvation
 *   - Snowfall → fear from disease
 *   - Earthquake → chief rulers die
 *   - Meteor fall → ministers die
 *   - Multi-hued clouds → various fears
 *   - Roaring clouds → miscarriage
 *   - Lightning → rulers and elephants suffer
 */

/**
 * Base eclipse effects by sign (where the eclipsed luminary falls).
 * These are ADDITIONAL to the normal planet-in-sign effects.
 *
 * classicalVictims: Direct from BS Ch.5 — who specifically suffers
 * when an eclipse occurs in this sign.
 */
export const ECLIPSE_SIGN_EFFECTS = {
    Aries: {
        solar: [
            { domain: "military", dir: "neg", desc: "Military leadership disrupted, defense failures", weight: 0.9 },
            { domain: "government", dir: "neg", desc: "Head of state faces sudden crisis", weight: 0.8 },
        ],
        lunar: [
            { domain: "public_mood", dir: "neg", desc: "Mass anger erupts, identity crisis in populace", weight: 0.8 },
        ],
        // BS Ch.5: "soldiers and persons who live by fire will be afflicted with miseries"
        classicalVictims: "Soldiers, fire-workers, and regional military populations",
        manifestationDays: 365,
    },
    Taurus: {
        solar: [
            { domain: "economy", dir: "neg", desc: "Financial system shock, banking crisis", weight: 0.9 },
            { domain: "agriculture", dir: "neg", desc: "Crop failure, food supply disruption", weight: 0.8 },
        ],
        lunar: [
            { domain: "economy", dir: "neg", desc: "Consumer panic, hoarding, market volatility", weight: 0.8 },
        ],
        // BS Ch.5: "Shepherds, cattle owners, and eminent individuals"
        classicalVictims: "Shepherds, cattle owners, eminent individuals, agricultural communities",
        manifestationDays: 365,
    },
    Gemini: {
        solar: [
            { domain: "media", dir: "neg", desc: "Communication blackout, major information disruption", weight: 0.8 },
            { domain: "trade", dir: "neg", desc: "Trade routes disrupted, commerce halted", weight: 0.7 },
        ],
        lunar: [
            { domain: "media", dir: "neg", desc: "Public misinformation crisis, media chaos", weight: 0.8 },
        ],
        // BS Ch.5: "Chaste women, princes, learned men, and riverbank populations"
        classicalVictims: "Princes, learned men, riverbank populations, women of virtue",
        manifestationDays: 365,
    },
    Cancer: {
        solar: [
            { domain: "public_mood", dir: "neg", desc: "Homeland security crisis, national trauma", weight: 0.9 },
            { domain: "agriculture", dir: "neg", desc: "Water disaster — flooding, tsunami, dam failure", weight: 0.9 },
        ],
        lunar: [
            { domain: "public_mood", dir: "neg", desc: "Mass grief, emotional crisis, refugee surge", weight: 0.9 },
        ],
        // BS Ch.5: "Food grains destroyed; multiple populations afflicted"
        classicalVictims: "Food grains destroyed; coastal and water-dependent populations",
        manifestationDays: 365,
    },
    Leo: {
        solar: [
            { domain: "government", dir: "neg", desc: "Ruler's fall — assassination attempt, coup, forced resignation", weight: 1.0 },
            { domain: "diplomacy", dir: "neg", desc: "International humiliation, prestige destroyed", weight: 0.8 },
        ],
        lunar: [
            { domain: "government", dir: "neg", desc: "Public turns against leadership, mass protest", weight: 0.8 },
        ],
        // BS Ch.5: "Hill dwellers, princes, and forest populations"
        classicalVictims: "Hill dwellers, princes, forest peoples, those in positions of authority",
        manifestationDays: 365,
    },
    Virgo: {
        solar: [
            { domain: "health", dir: "neg", desc: "Health crisis — epidemic, pandemic, poisoning", weight: 0.9 },
            { domain: "labor", dir: "neg", desc: "Workers' crisis, mass layoffs, industry collapse", weight: 0.8 },
        ],
        lunar: [
            { domain: "health", dir: "neg", desc: "Public health panic, hospital systems overwhelmed", weight: 0.8 },
        ],
        // BS Ch.5: "crops, poets, writers and singers will suffer; rice fields destroyed"
        classicalVictims: "Crops destroyed; poets, writers, singers, and rice-farming communities",
        manifestationDays: 365,
    },
    Libra: {
        solar: [
            { domain: "foreign_affairs", dir: "neg", desc: "Treaty collapse, war declaration, diplomatic crisis", weight: 0.9 },
            { domain: "judiciary", dir: "neg", desc: "Justice system fails, landmark wrongful rulings", weight: 0.8 },
        ],
        lunar: [
            { domain: "foreign_affairs", dir: "neg", desc: "Public demands for war, peace movements collapse", weight: 0.8 },
        ],
        // BS Ch.5: "Trading classes and border populations"
        classicalVictims: "Trading classes, border populations, merchant communities",
        manifestationDays: 365,
    },
    Scorpio: {
        solar: [
            { domain: "crisis", dir: "neg", desc: "Deep state crisis, nuclear/bio threat, underground disaster", weight: 1.0 },
            { domain: "mortality", dir: "neg", desc: "Mass death event, natural or man-made disaster", weight: 0.9 },
        ],
        lunar: [
            { domain: "crisis", dir: "neg", desc: "Public confronts hidden truth, mass emotional transformation", weight: 0.8 },
        ],
        // BS Ch.5: "Warriors and regional populations"
        classicalVictims: "Warriors, military personnel, underground workers, those in dangerous professions",
        manifestationDays: 365,
    },
    Sagittarius: {
        solar: [
            { domain: "religion", dir: "neg", desc: "Religious leader falls, temple/church crisis", weight: 0.8 },
            { domain: "judiciary", dir: "neg", desc: "Supreme court crisis, constitutional challenge", weight: 0.8 },
        ],
        lunar: [
            { domain: "religion", dir: "neg", desc: "Faith crisis in populace, mass disillusionment", weight: 0.7 },
        ],
        // BS Ch.5: "Ministers, merchants, physicians perish"
        classicalVictims: "Ministers, merchants, physicians, those in advisory and healing roles",
        manifestationDays: 365,
    },
    Capricorn: {
        solar: [
            { domain: "government", dir: "neg", desc: "Government structure collapses, regime change", weight: 0.9 },
            { domain: "economy", dir: "neg", desc: "Economic system failure, austerity crisis", weight: 0.9 },
        ],
        lunar: [
            { domain: "public_mood", dir: "neg", desc: "Loss of faith in institutions, nihilistic mood", weight: 0.8 },
        ],
        // BS Ch.5: "fishes, families of ministers, Chandalas, skilled practitioners"
        classicalVictims: "Fishermen, minister families, skilled artisans, marginalized communities",
        manifestationDays: 365,
    },
    Aquarius: {
        solar: [
            { domain: "technology", dir: "neg", desc: "Tech infrastructure failure, internet/power grid crisis", weight: 0.9 },
            { domain: "social_movements", dir: "neg", desc: "Revolution attempt, mass uprising", weight: 0.8 },
        ],
        lunar: [
            { domain: "social_movements", dir: "neg", desc: "Popular movement betrayed, collective disillusionment", weight: 0.8 },
        ],
        // BS Ch.5: "Multiple populations and animals perish"
        classicalVictims: "Multiple populations, animals, collective groups, humanitarian workers",
        manifestationDays: 365,
    },
    Pisces: {
        solar: [
            { domain: "maritime", dir: "neg", desc: "Maritime disaster, naval crisis, ocean pollution event", weight: 0.9 },
            { domain: "religion", dir: "neg", desc: "Spiritual leader exposed, faith institution scandalized", weight: 0.8 },
        ],
        lunar: [
            { domain: "refugees", dir: "neg", desc: "Refugee crisis, mass displacement, humanitarian emergency", weight: 0.9 },
        ],
        // BS Ch.5: "Maritime products destroyed; learned populations suffer"
        classicalVictims: "Maritime products destroyed; learned and scholarly populations suffer",
        manifestationDays: 365,
    },
};

/**
 * Post-eclipse omens (BS Ch.5).
 * Within 7 days of an eclipse, specific natural events intensify its effects.
 * The system should check for these confirmations (Nimitta validation).
 */
export const POST_ECLIPSE_OMENS = {
    dust_storm:   { effect: "Starvation, food scarcity", domain: "agriculture", weight: 0.8 },
    snowfall:     { effect: "Fear from disease", domain: "health", weight: 0.7 },
    earthquake:   { effect: "Chief rulers die", domain: "government", weight: 0.9 },
    meteor_fall:  { effect: "Ministers die", domain: "government", weight: 0.8 },
    colored_clouds: { effect: "Various fears in populace", domain: "public_mood", weight: 0.6 },
    roaring_clouds: { effect: "Miscarriage of pregnancy", domain: "health", weight: 0.5 },
    lightning:    { effect: "Rulers and tusked animals suffer", domain: "government", weight: 0.7 },
};

/**
 * Duration modifier for eclipse severity.
 * Longer eclipses = stronger effects.
 * BS gives specific duration thresholds.
 * @param {number} durationMinutes
 * @returns {{ modifier: number, severity: string }}
 */
export function getEclipseDurationModifier(durationMinutes) {
    if (durationMinutes >= 180) return { modifier: 1.5, severity: "extreme" };
    if (durationMinutes >= 120) return { modifier: 1.3, severity: "severe" };
    if (durationMinutes >= 60)  return { modifier: 1.1, severity: "significant" };
    if (durationMinutes >= 30)  return { modifier: 1.0, severity: "moderate" };
    return { modifier: 0.8, severity: "mild" };
}

/**
 * Evaluate an eclipse and return all active effects.
 * @param {Object} eclipse
 * @param {string} eclipse.type - "solar" | "lunar"
 * @param {string} eclipse.sign - Sign of eclipsed luminary
 * @param {number} eclipse.durationMinutes - Total duration
 * @param {string} [eclipse.nakshatra] - Nakshatra (for future sub-effects)
 * @returns {Object} { effects, oppositeSigns, severity, window }
 */
export function evaluateEclipse(eclipse) {
    const { type, sign, durationMinutes = 60 } = eclipse;
    const signEffects = ECLIPSE_SIGN_EFFECTS[sign];
    if (!signEffects) return { effects: [], severity: "unknown" };

    const typeEffects = type === "solar" ? signEffects.solar : signEffects.lunar;
    const duration = getEclipseDurationModifier(durationMinutes);

    const OPPOSITE = {
        Aries: "Libra", Taurus: "Scorpio", Gemini: "Sagittarius",
        Cancer: "Capricorn", Leo: "Aquarius", Virgo: "Pisces",
        Libra: "Aries", Scorpio: "Taurus", Sagittarius: "Gemini",
        Capricorn: "Cancer", Aquarius: "Leo", Pisces: "Virgo",
    };

    const oppositeSign = OPPOSITE[sign];

    // Apply duration modifier to all effects
    const effects = typeEffects.map(e => ({
        ...e,
        weight: Math.min(1.0, e.weight * duration.modifier),
        eclipseType: type,
        eclipseSign: sign,
        ruleId: `eclipse_${type}_in_${sign.toLowerCase()}`,
        source: `Brihat Samhita Ch.${type === "solar" ? "5" : "4"}`,
        manifestation: {
            delayDays: type === "solar" ? 365 : 180,
            peakDesc: type === "solar"
                ? "Solar eclipse effects manifest after ~1 year (BS Ch.97)"
                : "Lunar eclipse effects manifest within ~6 months (BS Ch.97)",
        },
    }));

    return {
        effects,
        activatedSigns: [sign, oppositeSign],
        severity: duration.severity,
        windowMonths: 6,
        classicalVictims: signEffects.classicalVictims || null,
        manifestationDays: signEffects.manifestationDays || 365,
        desc: `${type === "solar" ? "Solar" : "Lunar"} eclipse in ${sign} — ${duration.severity} severity, 6-month window`,
    };
}
