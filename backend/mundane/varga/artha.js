/**
 * अर्थ वर्ग — Economic Division: Commodities, Markets & Trade
 *
 * Source: Brihat Samhita
 *   Ch.41 (Rasi Vibhaga)     — Zodiac signs → substances/commodities
 *   Ch.41 Sl.9-13            — Planetary influence on rasi articles
 *   Ch.42 (Panyadhyaya)      — Commodity trading calendar by Sun's ingress
 *
 * The BS maps each zodiac sign to commodity classes, then evaluates whether
 * those commodities prosper or decline based on planetary positions relative
 * to the sign. Ch.42 provides a complete trading calendar — when to buy,
 * how long to hold, and expected profit — keyed to the Sun's ingress sign.
 *
 * Exports:
 *   evaluateMarketConditions(sunSign, planetPositions)
 *   getCommodityTrading(sunSign)
 *   getRasiSubstances(sign)
 */

import { NATURAL_BENEFICS, NATURAL_MALEFICS } from './benefic.js';

// ─── RASI-SUBSTANCE MAPPING (Ch.41 Slokas 2-8) ────────────────────────────
// Each zodiac sign governs specific commodity classes.

/**
 * @typedef {Object} RasiSubstance
 * @property {string} sign - Zodiac sign
 * @property {string[]} substances - Commodity classes governed by this sign
 * @property {string} source
 */

export const RASI_SUBSTANCES = {
  Aries: {
    sign: 'Aries',
    substances: ['cloths', 'wool', 'lentils', 'wheat', 'resin', 'barley', 'gold'],
    source: 'Ch.41 Sl.2'
  },
  Taurus: {
    sign: 'Taurus',
    substances: ['cloths', 'flowers', 'wheat', 'rice', 'barley', 'buffaloes'],
    source: 'Ch.41 Sl.3'
  },
  Gemini: {
    sign: 'Gemini',
    substances: ['corn', 'creepers', 'cotton'],
    source: 'Ch.41 Sl.3'
  },
  Cancer: {
    sign: 'Cancer',
    substances: ['plantains', 'coconuts', 'fragrant leaves'],
    source: 'Ch.41 Sl.4'
  },
  Leo: {
    sign: 'Leo',
    substances: ['husk-grains', 'juices', 'skins', 'jaggery'],
    source: 'Ch.41 Sl.4'
  },
  Virgo: {
    sign: 'Virgo',
    substances: ['flax', 'horse-gram', 'wheat', 'green gram', 'legumes'],
    source: 'Ch.41 Sl.5'
  },
  Libra: {
    sign: 'Libra',
    substances: ['black gram', 'barley', 'wheat', 'mustard'],
    source: 'Ch.41 Sl.5'
  },
  Scorpio: {
    sign: 'Scorpio',
    substances: ['sugarcane', 'iron', 'bell-metal', 'wool'],
    source: 'Ch.41 Sl.6'
  },
  Sagittarius: {
    sign: 'Sagittarius',
    substances: ['horses', 'salt', 'cloths', 'sesamum', 'corn'],
    source: 'Ch.41 Sl.6'
  },
  Capricorn: {
    sign: 'Capricorn',
    substances: ['trees', 'sugarcane', 'gold', 'iron'],
    source: 'Ch.41 Sl.7'
  },
  Aquarius: {
    sign: 'Aquarius',
    substances: ['water-products', 'fruits', 'flowers', 'gems'],
    source: 'Ch.41 Sl.7'
  },
  Pisces: {
    sign: 'Pisces',
    substances: ['jewels', 'pearls', 'diamonds', 'oils', 'fish-products'],
    source: 'Ch.41 Sl.8'
  }
};

// ─── ZODIAC SIGN ORDER ──────────────────────────────────────────────────────

const SIGN_ORDER = [
  'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
  'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'
];

// ─── PLANETARY INFLUENCE RULES (Ch.41 Slokas 9-13) ─────────────────────────
// Houses (bhava) counted from the rasi sign determine growth or decay.

/**
 * @typedef {Object} PlanetaryInfluence
 * @property {string} planet
 * @property {number[]} growthHouses - Houses from rasi that promote growth
 * @property {number[]} destroyHouses - Houses from rasi that destroy articles
 * @property {string} defaultEffect - Effect when in unlisted houses
 * @property {string} source
 */

export const PLANETARY_INFLUENCE = {
  Jupiter: {
    planet: 'Jupiter',
    growthHouses: [4, 10, 2, 11, 7, 9, 5],
    destroyHouses: [],
    defaultEffect: 'neutral',
    note: 'Jupiter promotes growth of articles from these houses',
    source: 'Ch.41 Sl.9'
  },
  Mercury: {
    planet: 'Mercury',
    growthHouses: [2, 11, 10, 5, 8],
    destroyHouses: [],
    defaultEffect: 'neutral',
    note: 'Mercury promotes growth of articles from these houses',
    source: 'Ch.41 Sl.10'
  },
  Venus: {
    planet: 'Venus',
    growthHouses: [1, 2, 3, 4, 5, 8, 9, 10, 11, 12],  // all others besides 6,7
    destroyHouses: [6, 7],
    defaultEffect: 'promotes',
    note: 'Venus in 6th or 7th from rasi destroys articles; all other houses promote',
    source: 'Ch.41 Sl.11'
  },
  Saturn: {
    planet: 'Saturn',
    growthHouses: [3, 6, 10, 11],
    destroyHouses: [1, 2, 4, 5, 7, 8, 9, 12],
    defaultEffect: 'harmful',
    note: 'Malefic — beneficial only in 3,6,10,11; harmful elsewhere',
    source: 'Ch.41 Sl.12'
  },
  Mars: {
    planet: 'Mars',
    growthHouses: [3, 6, 10, 11],
    destroyHouses: [1, 2, 4, 5, 7, 8, 9, 12],
    defaultEffect: 'harmful',
    note: 'Malefic — beneficial only in 3,6,10,11; harmful elsewhere',
    source: 'Ch.41 Sl.12'
  }
};

// Benefic aspect override rule (Ch.41 Sl.13):
// If a planet is in a bad house but aspected by a benefic, the bad effect is overridden.
export const BENEFIC_ASPECT_OVERRIDE = true;

// ─── COMMODITY TRADING CALENDAR (Ch.42 Slokas 3-12) ────────────────────────
// When the Sun enters a sign and portents are observed, buy X, hold N months,
// sell for Y% profit.

/**
 * @typedef {Object} TradingEntry
 * @property {string} sunSign - Sun's ingress sign
 * @property {string[]} commodities - What to buy
 * @property {number} holdMonths - How long to hold
 * @property {string} profit - Expected profit description
 * @property {number} profitPercent - Numeric profit estimate (100 = double)
 * @property {string|null} timingException - Loss condition if timing is wrong
 * @property {string} source
 */

export const COMMODITY_TRADING = {
  Aries: {
    sunSign: 'Aries',
    commodities: ['summer corn'],
    holdMonths: 4,
    profit: 'Much profit',
    profitPercent: 75,
    timingException: null,
    source: 'Ch.42 Sl.3'
  },
  Taurus: {
    sunSign: 'Taurus',
    commodities: ['forest roots', 'fruits'],
    holdMonths: 4,
    profit: 'Much profit',
    profitPercent: 75,
    timingException: null,
    source: 'Ch.42 Sl.4'
  },
  Gemini: {
    sunSign: 'Gemini',
    commodities: ['juices', 'corn'],
    holdMonths: 6,
    profit: 'Large profits',
    profitPercent: 80,
    timingException: null,
    source: 'Ch.42 Sl.5'
  },
  Cancer: {
    sunSign: 'Cancer',
    commodities: ['honey', 'perfumes', 'oils', 'ghee'],
    holdMonths: 2,
    profit: '100% profit',
    profitPercent: 100,
    timingException: 'If not sold within 2 months, loss is certain',
    source: 'Ch.42 Sl.6'
  },
  Leo: {
    sunSign: 'Leo',
    commodities: ['gold', 'gems', 'weapons', 'pearls'],
    holdMonths: 5,
    profit: 'Profit',
    profitPercent: 60,
    timingException: 'If not sold within 5 months, loss is certain',
    source: 'Ch.42 Sl.7'
  },
  Virgo: {
    sunSign: 'Virgo',
    commodities: ['chowries', 'donkeys', 'camels', 'horses'],
    holdMonths: 6,
    profit: '100% profit',
    profitPercent: 100,
    timingException: null,
    source: 'Ch.42 Sl.8'
  },
  Libra: {
    sunSign: 'Libra',
    commodities: ['cotton', 'jewels', 'blankets', 'corn'],
    holdMonths: 6,
    profit: '100% profit',
    profitPercent: 100,
    timingException: null,
    source: 'Ch.42 Sl.9'
  },
  Scorpio: {
    sunSign: 'Scorpio',
    commodities: ['fruits', 'bulbs', 'gems'],
    holdMonths: 24,
    profit: 'Double',
    profitPercent: 100,
    timingException: null,
    source: 'Ch.42 Sl.10'
  },
  Sagittarius: {
    sunSign: 'Sagittarius',
    commodities: ['saffron', 'corals', 'pearls'],
    holdMonths: 6,
    profit: 'Double',
    profitPercent: 100,
    timingException: null,
    source: 'Ch.42 Sl.10'
  },
  Capricorn: {
    sunSign: 'Capricorn',
    commodities: ['metal vessels', 'grains'],
    holdMonths: 1,
    profit: 'Double',
    profitPercent: 100,
    timingException: null,
    source: 'Ch.42 Sl.11'
  },
  Aquarius: {
    sunSign: 'Aquarius',
    commodities: ['metal vessels', 'grains'],
    holdMonths: 1,
    profit: 'Double',
    profitPercent: 100,
    timingException: null,
    source: 'Ch.42 Sl.11'
  },
  Pisces: {
    sunSign: 'Pisces',
    commodities: ['roots', 'fruits', 'gems'],
    holdMonths: 6,
    profit: 'As desired',
    profitPercent: 80,
    timingException: null,
    source: 'Ch.42 Sl.12'
  }
};

// ─── PROFIT QUALIFIER (Ch.42 Sl.13) ────────────────────────────────────────
// Profits are only realized if the Sun and Moon are conjoined with or
// aspected by friendly planets at the time of ingress.

/**
 * Friendly planets for profit qualification.
 * Sun's friends: Moon, Mars, Jupiter
 * Moon's friends: Sun, Mercury
 */
export const PROFIT_QUALIFIER = {
  rule: 'Sun and Moon must be with friendly planets for profit to materialize',
  sunFriends: ['Moon', 'Mars', 'Jupiter'],
  moonFriends: ['Sun', 'Mercury'],
  source: 'Ch.42 Sl.13'
};

// ═══════════════════════════════════════════════════════════════════════════
// EXPORTED FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Compute the house number of a planet from a given rasi sign.
 * House 1 = same sign, House 2 = next sign, etc.
 *
 * @param {string} rasiSign - The base sign (commodity sign)
 * @param {string} planetSign - The sign the planet occupies
 * @returns {number} House number 1-12
 * @private
 */
function _houseFrom(rasiSign, planetSign) {
  const rasiIdx = SIGN_ORDER.indexOf(rasiSign);
  const planetIdx = SIGN_ORDER.indexOf(planetSign);
  if (rasiIdx === -1 || planetIdx === -1) return -1;
  return ((planetIdx - rasiIdx + 12) % 12) + 1;
}

/**
 * Evaluate market conditions for a zodiac sign's commodities based on
 * current planetary positions.
 *
 * For each planet with influence rules (Jupiter, Mercury, Venus, Saturn, Mars),
 * computes whether it promotes or destroys the articles of the given sign.
 * Benefic aspect override is applied where applicable.
 *
 * @param {string} sunSign - The Sun's current zodiac sign (determines ingress period)
 * @param {Object} planetPositions - Map of planet name → { sign: string, ... }
 *   e.g. { Jupiter: { sign: 'Taurus' }, Saturn: { sign: 'Libra' }, ... }
 * @param {Object} [options={}]
 * @param {string[]} [options.aspectingBenefics] - Planets aspecting the commodity sign (for override rule)
 * @returns {Object} { sign, substances, effects: Effect[], netDirection, trading: TradingEntry|null, profitQualified: boolean }
 */
export function evaluateMarketConditions(sunSign, planetPositions = {}, options = {}) {
  const rasiData = RASI_SUBSTANCES[sunSign];
  if (!rasiData) {
    return {
      sign: sunSign,
      substances: [],
      effects: [],
      netDirection: 'mix',
      trading: null,
      profitQualified: false,
      note: `Sign "${sunSign}" not found in rasi-substance mapping`
    };
  }

  const effects = [];
  let posCount = 0;
  let negCount = 0;

  // Evaluate each planet with defined influence rules
  for (const [planetName, rules] of Object.entries(PLANETARY_INFLUENCE)) {
    const pos = planetPositions[planetName];
    if (!pos || !pos.sign) continue;

    const house = _houseFrom(sunSign, pos.sign);
    if (house === -1) continue;

    const isGrowth = rules.growthHouses.includes(house);
    const isDestroy = rules.destroyHouses.includes(house);

    // Check benefic aspect override (Sl.13): bad placement overridden by benefic aspect
    let overridden = false;
    if (isDestroy && BENEFIC_ASPECT_OVERRIDE && options.aspectingBenefics) {
      const hasBeneficAspect = options.aspectingBenefics.some(
        p => NATURAL_BENEFICS.includes(p)
      );
      if (hasBeneficAspect) {
        overridden = true;
      }
    }

    let dir, desc, weight;
    if (isGrowth) {
      dir = 'pos';
      desc = `${planetName} in ${house}${_ordinal(house)} house from ${sunSign} — promotes growth of ${rasiData.substances.join(', ')}`;
      weight = _planetWeight(planetName, 'growth');
      posCount++;
    } else if (isDestroy && !overridden) {
      dir = 'neg';
      desc = `${planetName} in ${house}${_ordinal(house)} house from ${sunSign} — destroys/depresses ${rasiData.substances.join(', ')}`;
      weight = _planetWeight(planetName, 'destroy');
      negCount++;
    } else if (isDestroy && overridden) {
      dir = 'mix';
      desc = `${planetName} in ${house}${_ordinal(house)} house from ${sunSign} — bad placement overridden by benefic aspect`;
      weight = 0.3;
      posCount++;
    } else {
      // Neutral house — skip unless it is Venus (defaultEffect = promotes)
      if (rules.defaultEffect === 'promotes') {
        dir = 'pos';
        desc = `${planetName} in ${house}${_ordinal(house)} house from ${sunSign} — promotes ${rasiData.substances.join(', ')} (default beneficial)`;
        weight = 0.5;
        posCount++;
      } else {
        continue; // Truly neutral, no effect generated
      }
    }

    effects.push({
      domain: 'economy',
      dir,
      desc,
      weight,
      planet: planetName,
      sign: sunSign,
      ruleId: `artha_${planetName.toLowerCase()}_house_${house}`,
      source: rules.source,
      category: 'economy',
      manifestation: `${planetName} in house ${house} from ${sunSign}`
    });
  }

  // Net direction assessment
  let netDirection = 'mix';
  if (posCount > 0 && negCount === 0) netDirection = 'pos';
  else if (negCount > 0 && posCount === 0) netDirection = 'neg';

  // Check trading calendar
  const trading = COMMODITY_TRADING[sunSign] || null;

  // Check profit qualifier (Sl.13)
  let profitQualified = false;
  if (planetPositions.Sun && planetPositions.Moon) {
    const sunPos = planetPositions.Sun.sign;
    const moonPos = planetPositions.Moon.sign;

    // Check if Sun is with friendly planets (same sign)
    const sunWithFriend = PROFIT_QUALIFIER.sunFriends.some(friend => {
      const fp = planetPositions[friend];
      return fp && fp.sign === sunPos;
    });

    // Check if Moon is with friendly planets (same sign)
    const moonWithFriend = PROFIT_QUALIFIER.moonFriends.some(friend => {
      const fp = planetPositions[friend];
      return fp && fp.sign === moonPos;
    });

    profitQualified = sunWithFriend || moonWithFriend;
  }

  // Add trading effect if applicable
  if (trading) {
    const tradingDir = profitQualified ? 'pos' : 'mix';
    effects.push({
      domain: 'economy',
      dir: tradingDir,
      desc: profitQualified
        ? `Sun in ${sunSign}: buy ${trading.commodities.join(', ')}, hold ${trading.holdMonths} months for ${trading.profit}. Profit qualified by friendly planet conjunction.`
        : `Sun in ${sunSign}: buy ${trading.commodities.join(', ')}, hold ${trading.holdMonths} months — but profit requires Sun/Moon with friendly planets (Sl.13).`,
      weight: profitQualified ? 0.8 : 0.4,
      planet: 'Sun',
      sign: sunSign,
      ruleId: `artha_trading_${sunSign.toLowerCase()}`,
      source: trading.source,
      category: 'economy',
      manifestation: `Trading calendar — Sun ingress ${sunSign}`
    });

    // Add timing exception warning if applicable
    if (trading.timingException) {
      effects.push({
        domain: 'economy',
        dir: 'neg',
        desc: `WARNING: ${trading.timingException}`,
        weight: 0.6,
        planet: 'Sun',
        sign: sunSign,
        ruleId: `artha_trading_exception_${sunSign.toLowerCase()}`,
        source: trading.source,
        category: 'economy',
        manifestation: `Trading timing constraint — ${sunSign}`
      });
    }
  }

  return {
    sign: sunSign,
    substances: rasiData.substances,
    effects,
    netDirection,
    trading,
    profitQualified
  };
}

/**
 * Get the trading calendar entry for a given Sun ingress sign.
 *
 * Returns the commodities to buy, hold period, expected profit,
 * and any timing exceptions.
 *
 * @param {string} sunSign - The zodiac sign the Sun is entering
 * @returns {Object} { sunSign, commodities, holdMonths, profit, profitPercent, timingException, source, effect: Effect }
 */
export function getCommodityTrading(sunSign) {
  const entry = COMMODITY_TRADING[sunSign];

  if (!entry) {
    return {
      sunSign,
      commodities: [],
      holdMonths: null,
      profit: null,
      profitPercent: null,
      timingException: null,
      source: null,
      effect: null,
      note: `No trading entry for Sun in "${sunSign}"`
    };
  }

  return {
    sunSign: entry.sunSign,
    commodities: entry.commodities,
    holdMonths: entry.holdMonths,
    profit: entry.profit,
    profitPercent: entry.profitPercent,
    timingException: entry.timingException,
    source: entry.source,
    profitQualifierRule: PROFIT_QUALIFIER.rule,
    effect: {
      domain: 'economy',
      dir: 'pos',
      desc: `Sun ingress ${sunSign}: buy ${entry.commodities.join(', ')}. Hold ${entry.holdMonths} month(s) for ${entry.profit} (~${entry.profitPercent}%).${entry.timingException ? ' ' + entry.timingException : ''}`,
      weight: 0.7,
      planet: 'Sun',
      sign: sunSign,
      ruleId: `artha_trading_${sunSign.toLowerCase()}`,
      source: entry.source,
      category: 'economy',
      manifestation: `Commodity trading — Sun in ${sunSign}`
    }
  };
}

/**
 * Get the substance/commodity classes governed by a zodiac sign.
 *
 * @param {string} sign - Zodiac sign name (e.g. "Aries", "Pisces")
 * @returns {Object} { sign, substances, source, effect: Effect }
 */
export function getRasiSubstances(sign) {
  const entry = RASI_SUBSTANCES[sign];

  if (!entry) {
    return {
      sign,
      substances: [],
      source: null,
      effect: null,
      note: `Sign "${sign}" not found in rasi-substance mapping`
    };
  }

  return {
    sign: entry.sign,
    substances: entry.substances,
    source: entry.source,
    effect: {
      domain: 'economy',
      dir: 'mix',
      desc: `${sign} governs: ${entry.substances.join(', ')}. These articles respond to planetary positions relative to ${sign}.`,
      weight: 0.5,
      planet: null,
      sign,
      ruleId: `artha_rasi_${sign.toLowerCase()}`,
      source: entry.source,
      category: 'economy',
      manifestation: `Rasi substance mapping — ${sign}`
    }
  };
}

// ─── INTERNAL HELPERS ───────────────────────────────────────────────────────

/**
 * Assign weight based on planet type and effect direction.
 * @param {string} planet
 * @param {'growth'|'destroy'} type
 * @returns {number}
 * @private
 */
function _planetWeight(planet, type) {
  // Jupiter and Venus are strong benefics — their growth effect is heavier
  if (type === 'growth') {
    if (planet === 'Jupiter') return 0.85;
    if (planet === 'Venus') return 0.8;
    if (planet === 'Mercury') return 0.7;
    return 0.6;
  }
  // Malefics have strong destructive weight
  if (type === 'destroy') {
    if (planet === 'Saturn') return 0.8;
    if (planet === 'Mars') return 0.75;
    if (planet === 'Venus') return 0.65;
    return 0.6;
  }
  return 0.5;
}

/**
 * Return ordinal suffix for a number.
 * @param {number} n
 * @returns {string}
 * @private
 */
function _ordinal(n) {
  const s = ['th', 'st', 'nd', 'rd'];
  const v = n % 100;
  return s[(v - 20) % 10] || s[v] || s[0];
}
