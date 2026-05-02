/**
 * KUJA (Mars) — Brihat Samhita Chapter 6
 * Kujacharadhyaya: The Movements of Mars
 *
 * Mars uses a RELATIVE OFFSET system based on nakshatra distance between
 * emergence from Sun conjunction and retrograde start. This is fundamentally
 * different from standard planet-in-sign evaluation.
 *
 * Structure:
 *   Slokas 1-5:   Five named courses (Vaktramushna → Asimusala) by offset
 *   Slokas 6-12:  Specific nakshatra transit effects
 *   Sloka 11:     Rain-blocking rule (clouds spoiled)
 *   Sloka 12:     Auspicious emergence override (cancels all evil)
 *   Sloka 13:     Benefic appearance rule
 *
 * @module varga/graha/kuja
 */

import { getNakshatraOffset, NAKSHATRA_BY_NAME } from '../nakshatra.js';

// ─── FIVE NAMED COURSES (Slokas 1-5) ───────────────────────────────────────
// Offset counted from emergence nakshatra to retrograde-start nakshatra

/**
 * @typedef {Object} MarsCourse
 * @property {string} name - Sanskrit name
 * @property {number[]} offsetRange - [min, max] inclusive nakshatra offset
 * @property {string} dir - Effect direction: pos, neg, mix
 * @property {string} desc - Classical description
 * @property {number} weight - Severity 0-1
 * @property {string} manifestTiming - When effects begin
 */

const MARS_COURSES = [
  {
    name: 'Vaktramushna',
    offsetRange: [7, 9],
    dir: 'neg',
    desc: 'Fire-workers suffer; those who deal with fire, smiths, goldsmiths, and all who use furnaces experience losses and calamity',
    weight: 0.6,
    manifestTiming: 'immediate',
    category: 'occupation',
    manifestation: 'fire-workers, smiths, and furnace-users face losses'
  },
  {
    name: 'Asrumukha',
    offsetRange: [10, 12],
    dir: 'neg',
    desc: 'The six tastes become vitiated; diseases prevail and drought sets in. Effects manifest at the NEXT Sun conjunction',
    weight: 0.7,
    manifestTiming: 'next_sun_conjunction',
    category: 'health_agriculture',
    manifestation: 'taste vitiation, widespread disease, drought at next Sun conjunction'
  },
  {
    name: 'Vyala',
    offsetRange: [13, 14],
    dir: 'mix',
    desc: 'Sharp-toothed creatures and serpents cause trouble; BUT general prosperity prevails otherwise',
    weight: 0.5,
    manifestTiming: 'immediate',
    category: 'fauna_prosperity',
    manifestation: 'serpent/predator menace alongside general prosperity'
  },
  {
    name: 'Rudhiranana',
    offsetRange: [15, 16],
    dir: 'mix',
    desc: 'Facial diseases and panic spread among people; BUT prosperity and abundance also manifest',
    weight: 0.5,
    manifestTiming: 'immediate',
    category: 'health_prosperity',
    manifestation: 'facial diseases and panic with concurrent prosperity'
  },
  {
    name: 'Asimusala',
    offsetRange: [17, 18],
    dir: 'neg',
    desc: 'Robber bands roam freely, drought parches the land, and weapon danger prevails. Effects begin when Mars resumes direct motion',
    weight: 0.8,
    manifestTiming: 'direct_station',
    category: 'civil_unrest',
    manifestation: 'robber bands, drought, weapon-related violence starting at Mars direct station'
  }
];

// ─── SPECIFIC NAKSHATRA TRANSIT RULES (Slokas 6-12) ────────────────────────

/**
 * @typedef {Object} MarsNakshatraRule
 * @property {string|string[]} nakshatra - Nakshatra(s) triggering the rule
 * @property {string} dir - pos, neg, mix
 * @property {string} desc - Classical description
 * @property {number} weight - Severity 0-1
 * @property {string} ruleId - Unique rule identifier
 * @property {string} category - Domain category
 */

const NAKSHATRA_TRANSIT_RULES = [
  // Sloka 6: Mars cutting across Rohini
  {
    nakshatra: 'Rohini',
    dir: 'neg',
    desc: 'Mars cutting across Rohini causes terrible mortality among cattle and men; kings perish, earth suffers',
    weight: 0.95,
    ruleId: 'kuja-rohini-cut',
    category: 'mortality',
    manifestation: 'mass mortality of cattle and men, royal deaths, earth calamity',
    domain: 'society'
  },
  // Sloka 7: Mars through Magha
  {
    nakshatra: 'Magha',
    dir: 'neg',
    desc: 'Mars transiting Magha brings death to the Pandya king and afflicts those ruled by the Pitrs',
    weight: 0.8,
    ruleId: 'kuja-magha',
    category: 'royalty',
    manifestation: 'Pandya king or southern ruler dies; ancestral rites disrupted',
    domain: 'governance'
  },
  // Sloka 7: Mars through Chitra
  {
    nakshatra: 'Chitra',
    dir: 'neg',
    desc: 'Mars in Chitra afflicts artisans, painters, weavers, and those skilled in ornamentation',
    weight: 0.6,
    ruleId: 'kuja-chitra',
    category: 'occupation',
    manifestation: 'craftsmen, artists, and weavers suffer',
    domain: 'economy'
  },
  // Sloka 8: Mars through Dhanishta
  {
    nakshatra: 'Dhanishta',
    dir: 'neg',
    desc: 'Mars in Dhanishta afflicts those without pride and charitable persons; musical instruments go silent',
    weight: 0.55,
    ruleId: 'kuja-dhanishta',
    category: 'culture',
    manifestation: 'charitable persons suffer, cultural activities decline',
    domain: 'society'
  },
  // Sloka 8: Mars through Jyeshta
  {
    nakshatra: 'Jyeshta',
    dir: 'neg',
    desc: 'Mars in Jyeshta brings danger to great heroes and military commanders; Indra-ruled domains threatened',
    weight: 0.7,
    ruleId: 'kuja-jyeshta',
    category: 'military',
    manifestation: 'military heroes fall, commanders face danger',
    domain: 'governance'
  },
  // Sloka 9: Mars through Sravana
  {
    nakshatra: 'Sravana',
    dir: 'neg',
    desc: 'Mars in Sravana afflicts the righteous, active persons, and Vishnu devotees; truth-speakers harassed',
    weight: 0.6,
    ruleId: 'kuja-sravana',
    category: 'dharma',
    manifestation: 'righteous and truth-speaking persons suffer',
    domain: 'society'
  },
  // Sloka 9: Mars through Visakha
  {
    nakshatra: 'Visakha',
    dir: 'neg',
    desc: 'Mars in Visakha afflicts devotees of Indra and Agni; trees with red blossoms, sesamum, and legume crops fail',
    weight: 0.65,
    ruleId: 'kuja-visakha',
    category: 'agriculture',
    manifestation: 'legume crops fail, ritual observances disrupted',
    domain: 'economy'
  },
  // Sloka 10: Mars through Purvabhadra
  {
    nakshatra: 'Purvabhadra',
    dir: 'neg',
    desc: 'Mars in Purvabhadra empowers robbers and murderous persons; cowherds suffer',
    weight: 0.7,
    ruleId: 'kuja-purvabhadra',
    category: 'civil_unrest',
    manifestation: 'robberies increase, cowherds and pastoralists harmed',
    domain: 'society'
  },
  // Sloka 10: Mars through Aslesha
  {
    nakshatra: 'Aslesha',
    dir: 'neg',
    desc: 'Mars in Aslesha causes poison scares, serpent attacks, and afflicts physicians and root-dealers',
    weight: 0.65,
    ruleId: 'kuja-aslesha',
    category: 'health',
    manifestation: 'poison incidents, snake attacks, physicians and herbalists suffer',
    domain: 'health'
  },
  // Sloka 10: Mars through Krittika
  {
    nakshatra: 'Krittika',
    dir: 'neg',
    desc: 'Mars in Krittika brings fire hazards; brahmins performing agnihotra and those who work with fire suffer',
    weight: 0.7,
    ruleId: 'kuja-krittika',
    category: 'fire_hazard',
    manifestation: 'fire outbreaks, fire-ritual performers and fire-workers afflicted',
    domain: 'society'
  },
  // Sloka 11: Mars through Bharani
  {
    nakshatra: 'Bharani',
    dir: 'neg',
    desc: 'Mars in Bharani brings cruelty, slaughter, and afflicts catchers and those who handle blood and flesh',
    weight: 0.7,
    ruleId: 'kuja-bharani',
    category: 'violence',
    manifestation: 'increased cruelty and slaughter, butchers/catchers afflicted',
    domain: 'society'
  }
];

// ─── RAIN-BLOCKING RULE (Sloka 11) ─────────────────────────────────────────
// Mars in any of these nakshatras = clouds spoiled, no rain

const RAIN_BLOCKING_NAKSHATRAS = [
  'Rohini', 'Sravana', 'Moola', 'Purvabhadra',
  'Aslesha', 'Krittika', 'Bharani'
];

// ─── AUSPICIOUS EMERGENCE NAKSHATRAS (Sloka 12) ────────────────────────────
// If Mars emerges from Sun conjunction in ANY of these, all prior evil cancelled

const AUSPICIOUS_EMERGENCE_NAKSHATRAS = [
  'Sravana', 'Magha', 'Purvashadha', 'Hasta', 'Moola',
  'Purvabhadra', 'Aswini', 'Visakha', 'Rohini'
];

// ─── MAIN EVALUATION ────────────────────────────────────────────────────────

/**
 * Evaluate Mars effects per Brihat Samhita Chapter 6.
 *
 * Mars uses a unique relative-offset system: the nakshatra distance between
 * its emergence from Sun conjunction and its retrograde start determines
 * which of five named courses applies. Additional rules cover specific
 * nakshatra transits, rain blocking, auspicious emergence override, and
 * benefic appearance.
 *
 * @param {Object} skyState - Current planetary positions
 * @param {string} skyState.positions.Mars.nakshatra - Current Mars nakshatra
 * @param {string} [skyState.positions.Mars.sign] - Current Mars sign
 * @param {boolean} [skyState.positions.Mars.isRetrograde] - Retrograde status
 * @param {Object} marsContext - Mars-specific observational context
 * @param {string} marsContext.emergenceNakshatra - Nakshatra where Mars emerged from Sun conjunction
 * @param {string} marsContext.retrogradeNakshatra - Nakshatra of current Mars position (during retrograde)
 * @param {boolean} marsContext.isPostConjunction - Whether Mars has emerged from conjunction
 * @param {string} [marsContext.retrogradeStartNak] - Nakshatra where retrograde began
 * @param {boolean} [marsContext.isBeneficAppearance] - Large, glossy, bright appearance
 * @param {boolean} [marsContext.isDirectStation] - Whether Mars just stationed direct
 * @returns {Object[]} Array of Effect objects
 */
export function evaluateMars(skyState, marsContext) {
  const effects = [];
  const marsPos = skyState?.positions?.Mars;
  if (!marsPos) return effects;

  const currentNak = marsPos.nakshatra;
  const {
    emergenceNakshatra,
    retrogradeStartNak,
    isPostConjunction,
    isBeneficAppearance,
    isDirectStation
  } = marsContext || {};

  // ─── CHECK AUSPICIOUS EMERGENCE OVERRIDE (Sloka 12) ────────────────
  // Must check first: if Mars emerged in an auspicious nakshatra,
  // ALL evil effects are cancelled
  const auspiciousEmergence = isPostConjunction &&
    emergenceNakshatra &&
    AUSPICIOUS_EMERGENCE_NAKSHATRAS.includes(emergenceNakshatra);

  if (auspiciousEmergence) {
    effects.push({
      domain: 'universal',
      dir: 'pos',
      desc: `Mars emerged in auspicious nakshatra ${emergenceNakshatra} — all prior evil effects of Mars are cancelled`,
      weight: 1.0,
      planet: 'Mars',
      sign: marsPos.sign || null,
      ruleId: 'kuja-auspicious-emergence',
      source: 'BS Ch.6 Sl.12',
      category: 'cancellation',
      manifestation: `emergence in ${emergenceNakshatra} nullifies all Mars-related calamities`
    });

    // Still emit the benefic appearance rule if applicable, but skip all evil
    if (isBeneficAppearance) {
      effects.push(_buildBeneficAppearanceEffect(marsPos));
    }

    return effects;
  }

  // ─── FIVE NAMED COURSES (Slokas 1-5) ──────────────────────────────
  // Only apply when we have both emergence and retrograde-start nakshatras
  if (emergenceNakshatra && retrogradeStartNak) {
    const offset = getNakshatraOffset(emergenceNakshatra, retrogradeStartNak);

    for (const course of MARS_COURSES) {
      const [min, max] = course.offsetRange;
      if (offset >= min && offset <= max) {
        effects.push({
          domain: _courseDomain(course.category),
          dir: course.dir,
          desc: `${course.name} course (offset ${offset}): ${course.desc}`,
          weight: course.weight,
          planet: 'Mars',
          sign: marsPos.sign || null,
          ruleId: `kuja-course-${course.name.toLowerCase()}`,
          source: 'BS Ch.6 Sl.1-5',
          category: course.category,
          manifestation: course.manifestation
        });
        break; // Only one course can apply
      }
    }
  }

  // ─── SPECIFIC NAKSHATRA TRANSIT RULES (Slokas 6-12) ───────────────
  if (currentNak) {
    for (const rule of NAKSHATRA_TRANSIT_RULES) {
      const naks = Array.isArray(rule.nakshatra) ? rule.nakshatra : [rule.nakshatra];
      if (naks.includes(currentNak)) {
        effects.push({
          domain: rule.domain,
          dir: rule.dir,
          desc: rule.desc,
          weight: rule.weight,
          planet: 'Mars',
          sign: marsPos.sign || null,
          ruleId: rule.ruleId,
          source: 'BS Ch.6 Sl.6-12',
          category: rule.category,
          manifestation: rule.manifestation
        });
      }
    }
  }

  // ─── RAIN-BLOCKING RULE (Sloka 11) ────────────────────────────────
  if (currentNak && RAIN_BLOCKING_NAKSHATRAS.includes(currentNak)) {
    effects.push({
      domain: 'weather',
      dir: 'neg',
      desc: `Mars in ${currentNak} spoils the clouds — rain is obstructed and drought conditions develop`,
      weight: 0.7,
      planet: 'Mars',
      sign: marsPos.sign || null,
      ruleId: 'kuja-rain-block',
      source: 'BS Ch.6 Sl.11',
      category: 'rainfall',
      manifestation: `clouds spoiled by Mars in ${currentNak}, no rain expected`
    });
  }

  // ─── BENEFIC APPEARANCE RULE (Sloka 13) ────────────────────────────
  // If Mars appears large, glossy, bright, and of natural color at emergence,
  // it is benefic to its dependencies
  if (isBeneficAppearance) {
    effects.push(_buildBeneficAppearanceEffect(marsPos));
  }

  // ─── ASIMUSALA DIRECT-STATION ACTIVATION ──────────────────────────
  // Asimusala effects specifically begin when Mars stations direct
  if (isDirectStation && retrogradeStartNak && emergenceNakshatra) {
    const offset = getNakshatraOffset(emergenceNakshatra, retrogradeStartNak);
    if (offset >= 17 && offset <= 18) {
      effects.push({
        domain: 'society',
        dir: 'neg',
        desc: 'Asimusala course activates NOW — Mars has stationed direct, triggering robber bands, drought, and weapon violence',
        weight: 0.85,
        planet: 'Mars',
        sign: marsPos.sign || null,
        ruleId: 'kuja-asimusala-activation',
        source: 'BS Ch.6 Sl.5',
        category: 'civil_unrest',
        manifestation: 'Asimusala activation: immediate onset of banditry, drought, weapon danger'
      });
    }
  }

  return effects;
}

// ─── HELPERS ────────────────────────────────────────────────────────────────

/**
 * Build the benefic appearance Effect for Mars (Sloka 13).
 * @param {Object} marsPos - Mars position data
 * @returns {Object} Effect object
 */
function _buildBeneficAppearanceEffect(marsPos) {
  return {
    domain: 'society',
    dir: 'pos',
    desc: 'Mars appears large, glossy, and bright with natural color — commanders, fire-workers, warriors, and Mars-ruled occupations prosper',
    weight: 0.7,
    planet: 'Mars',
    sign: marsPos.sign || null,
    ruleId: 'kuja-benefic-appearance',
    source: 'BS Ch.6 Sl.13',
    category: 'benefic',
    manifestation: 'military commanders, smiths, surgeons, and fire-workers experience prosperity'
  };
}

/**
 * Map internal category to domain for course-based effects.
 * @param {string} category
 * @returns {string}
 */
function _courseDomain(category) {
  const MAP = {
    occupation: 'economy',
    health_agriculture: 'health',
    fauna_prosperity: 'society',
    health_prosperity: 'health',
    civil_unrest: 'society'
  };
  return MAP[category] || 'society';
}

// ─── EXPORTED DATA (for testing and cross-module use) ───────────────────────

export { MARS_COURSES, NAKSHATRA_TRANSIT_RULES, RAIN_BLOCKING_NAKSHATRAS, AUSPICIOUS_EMERGENCE_NAKSHATRAS };
