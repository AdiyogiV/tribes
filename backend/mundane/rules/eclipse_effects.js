/**
 * Eclipse Effects — Brihat Samhita Ch.5 (Solar) & Ch.4 (Lunar)
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
 */

/**
 * Base eclipse effects by sign (where the eclipsed luminary falls).
 * These are ADDITIONAL to the normal planet-in-sign effects.
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
    },
    Taurus: {
        solar: [
            { domain: "economy", dir: "neg", desc: "Financial system shock, banking crisis", weight: 0.9 },
            { domain: "agriculture", dir: "neg", desc: "Crop failure, food supply disruption", weight: 0.8 },
        ],
        lunar: [
            { domain: "economy", dir: "neg", desc: "Consumer panic, hoarding, market volatility", weight: 0.8 },
        ],
    },
    Gemini: {
        solar: [
            { domain: "media", dir: "neg", desc: "Communication blackout, major information disruption", weight: 0.8 },
            { domain: "trade", dir: "neg", desc: "Trade routes disrupted, commerce halted", weight: 0.7 },
        ],
        lunar: [
            { domain: "media", dir: "neg", desc: "Public misinformation crisis, media chaos", weight: 0.8 },
        ],
    },
    Cancer: {
        solar: [
            { domain: "public_mood", dir: "neg", desc: "Homeland security crisis, national trauma", weight: 0.9 },
            { domain: "agriculture", dir: "neg", desc: "Water disaster — flooding, tsunami, dam failure", weight: 0.9 },
        ],
        lunar: [
            { domain: "public_mood", dir: "neg", desc: "Mass grief, emotional crisis, refugee surge", weight: 0.9 },
        ],
    },
    Leo: {
        solar: [
            { domain: "government", dir: "neg", desc: "Ruler's fall — assassination attempt, coup, forced resignation", weight: 1.0 },
            { domain: "diplomacy", dir: "neg", desc: "International humiliation, prestige destroyed", weight: 0.8 },
        ],
        lunar: [
            { domain: "government", dir: "neg", desc: "Public turns against leadership, mass protest", weight: 0.8 },
        ],
    },
    Virgo: {
        solar: [
            { domain: "health", dir: "neg", desc: "Health crisis — epidemic, pandemic, poisoning", weight: 0.9 },
            { domain: "labor", dir: "neg", desc: "Workers' crisis, mass layoffs, industry collapse", weight: 0.8 },
        ],
        lunar: [
            { domain: "health", dir: "neg", desc: "Public health panic, hospital systems overwhelmed", weight: 0.8 },
        ],
    },
    Libra: {
        solar: [
            { domain: "foreign_affairs", dir: "neg", desc: "Treaty collapse, war declaration, diplomatic crisis", weight: 0.9 },
            { domain: "judiciary", dir: "neg", desc: "Justice system fails, landmark wrongful rulings", weight: 0.8 },
        ],
        lunar: [
            { domain: "foreign_affairs", dir: "neg", desc: "Public demands for war, peace movements collapse", weight: 0.8 },
        ],
    },
    Scorpio: {
        solar: [
            { domain: "crisis", dir: "neg", desc: "Deep state crisis, nuclear/bio threat, underground disaster", weight: 1.0 },
            { domain: "mortality", dir: "neg", desc: "Mass death event, natural or man-made disaster", weight: 0.9 },
        ],
        lunar: [
            { domain: "crisis", dir: "neg", desc: "Public confronts hidden truth, mass emotional transformation", weight: 0.8 },
        ],
    },
    Sagittarius: {
        solar: [
            { domain: "religion", dir: "neg", desc: "Religious leader falls, temple/church crisis", weight: 0.8 },
            { domain: "judiciary", dir: "neg", desc: "Supreme court crisis, constitutional challenge", weight: 0.8 },
        ],
        lunar: [
            { domain: "religion", dir: "neg", desc: "Faith crisis in populace, mass disillusionment", weight: 0.7 },
        ],
    },
    Capricorn: {
        solar: [
            { domain: "government", dir: "neg", desc: "Government structure collapses, regime change", weight: 0.9 },
            { domain: "economy", dir: "neg", desc: "Economic system failure, austerity crisis", weight: 0.9 },
        ],
        lunar: [
            { domain: "public_mood", dir: "neg", desc: "Loss of faith in institutions, nihilistic mood", weight: 0.8 },
        ],
    },
    Aquarius: {
        solar: [
            { domain: "technology", dir: "neg", desc: "Tech infrastructure failure, internet/power grid crisis", weight: 0.9 },
            { domain: "social_movements", dir: "neg", desc: "Revolution attempt, mass uprising", weight: 0.8 },
        ],
        lunar: [
            { domain: "social_movements", dir: "neg", desc: "Popular movement betrayed, collective disillusionment", weight: 0.8 },
        ],
    },
    Pisces: {
        solar: [
            { domain: "maritime", dir: "neg", desc: "Maritime disaster, naval crisis, ocean pollution event", weight: 0.9 },
            { domain: "religion", dir: "neg", desc: "Spiritual leader exposed, faith institution scandalized", weight: 0.8 },
        ],
        lunar: [
            { domain: "refugees", dir: "neg", desc: "Refugee crisis, mass displacement, humanitarian emergency", weight: 0.9 },
        ],
    },
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
    }));

    return {
        effects,
        activatedSigns: [sign, oppositeSign],
        severity: duration.severity,
        windowMonths: 6,
        desc: `${type === "solar" ? "Solar" : "Lunar"} eclipse in ${sign} — ${duration.severity} severity, 6-month window`,
    };
}
