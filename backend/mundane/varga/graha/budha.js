/**
 * BUDHA (Mercury) — Brihat Samhita Chapter 7
 * Budhacharadhyaya: The Movements of Mercury
 *
 * Mercury uses 7 NAMED COURSES determined by the nakshatra group it occupies,
 * each with a specific duration. Additional rules cover motion types, nakshatra
 * group transit effects, monthly visibility, eclipse reversal, and benefic
 * appearance.
 *
 * Structure:
 *   Sloka 1:      Seven named courses with durations
 *   Slokas 2-7:   Six nakshatra-group transit effects
 *   Sloka 8:      Four motion-type effects
 *   Sloka 17:     Monthly visibility = fear
 *   Sloka 19:     Eclipsed reversal rule
 *   Sloka 20:     Benefic appearance rule
 *
 * @module varga/graha/budha
 */

import { NAKSHATRA_BY_NAME } from '../nakshatra.js';

// ─── SEVEN NAMED COURSES (Sloka 1) ─────────────────────────────────────────

/**
 * @typedef {Object} MercuryCourse
 * @property {string} name - Sanskrit name
 * @property {string[]} nakshatras - Nakshatras constituting this course
 * @property {number} durationDays - Duration in days
 * @property {string} dir - Effect direction
 * @property {string} desc - Classical description
 * @property {number} weight - Severity 0-1
 */

const MERCURY_COURSES = [
  {
    name: 'Prakrita',
    nakshatras: ['Swati', 'Bharani', 'Rohini', 'Krittika'],
    durationDays: 40,
    dir: 'pos',
    desc: 'Prakrita course (40 days): Good health prevails, timely rain, abundant crops, and general happiness among people',
    weight: 0.7,
    category: 'prosperity',
    manifestation: 'good health, timely rain, crop abundance, widespread happiness'
  },
  {
    name: 'Misra',
    nakshatras: ['Mrigasira', 'Ardra', 'Magha', 'Aslesha'],
    durationDays: 30,
    dir: 'mix',
    desc: 'Misra course (30 days): Mixed effects — some regions prosper while others suffer; results are uneven',
    weight: 0.5,
    category: 'mixed',
    manifestation: 'uneven prosperity, mixed results across regions'
  },
  {
    name: 'Sankshipta',
    nakshatras: ['Pushya', 'Punarvasu', 'Purvaphalguni', 'Uttaraphalguni'],
    durationDays: 22,
    dir: 'mix',
    desc: 'Sankshipta course (22 days): Brief and mixed — effects are compressed and uncertain, neither clearly good nor bad',
    weight: 0.45,
    category: 'mixed',
    manifestation: 'short-duration mixed outcomes, compressed uncertainty'
  },
  {
    name: 'Theekshna',
    nakshatras: ['Purvabhadra', 'Uttarabhadra', 'Jyeshta', 'Aswini', 'Revati'],
    durationDays: 18,
    dir: 'neg',
    desc: 'Theekshna course (18 days): Sharp and severe — quarrels, fear, and suffering afflict people and commerce',
    weight: 0.65,
    category: 'conflict',
    manifestation: 'quarrels, fear, suffering in commerce and society'
  },
  {
    name: 'Yoganta',
    nakshatras: ['Moola', 'Purvashadha', 'Uttarashadha'],
    durationDays: 9,
    dir: 'neg',
    desc: 'Yoganta course (9 days): End-of-yoga — calamities intensify, dangers from fire, and root causes of suffering manifest',
    weight: 0.7,
    category: 'calamity',
    manifestation: 'intensified calamities, fire dangers, root-cause suffering'
  },
  {
    name: 'Ghora',
    nakshatras: ['Sravana', 'Chitra', 'Dhanishta', 'Satabhishak'],
    durationDays: 15,
    dir: 'neg',
    desc: 'Ghora course (15 days): Terrible — severe afflictions, famine conditions, disease outbreaks, and great fear',
    weight: 0.75,
    category: 'famine_disease',
    manifestation: 'famine conditions, disease outbreaks, widespread fear'
  },
  {
    name: 'Papakhya',
    nakshatras: ['Hasta', 'Anuradha', 'Visakha'],
    durationDays: 11,
    dir: 'neg',
    desc: 'Papakhya course (11 days): Sin-named — robbery, fraud, deceit, and moral decay spread',
    weight: 0.7,
    category: 'moral_decay',
    manifestation: 'robbery, fraud, deceit, moral deterioration'
  }
];

// ─── COURSE LOOKUP MAP ──────────────────────────────────────────────────────

const COURSE_BY_NAKSHATRA = {};
for (const course of MERCURY_COURSES) {
  for (const nak of course.nakshatras) {
    COURSE_BY_NAKSHATRA[nak] = course;
  }
}

// ─── FOUR MOTION TYPES (Sloka 8) ───────────────────────────────────────────

const MOTION_EFFECTS = {
  direct: {
    dir: 'pos',
    desc: 'Mercury in direct motion: commerce, communication, and trade prosper; good for all Mercury-ruled activities',
    weight: 0.6,
    category: 'commerce',
    manifestation: 'trade and communication flourish'
  },
  ativakra: {
    dir: 'neg',
    desc: 'Mercury in Ativakra (excessively retrograde/erratic): severe famine, crop failure, and scarcity of food',
    weight: 0.85,
    category: 'famine',
    manifestation: 'severe famine and crop failure'
  },
  vakra: {
    dir: 'neg',
    desc: 'Mercury in Vakra (retrograde): war, conflict between rulers, trade routes disrupted, treaties broken',
    weight: 0.75,
    category: 'war',
    manifestation: 'war, broken treaties, disrupted trade routes'
  },
  kshina: {
    dir: 'neg',
    desc: 'Mercury Kshina (diminished/faint): fear and disease spread; people suffer from anxiety and epidemics',
    weight: 0.7,
    category: 'disease',
    manifestation: 'fear, anxiety, and epidemic disease'
  }
};

// ─── SIX NAKSHATRA-GROUP TRANSIT EFFECTS (Slokas 2-7) ──────────────────────

const NAKSHATRA_GROUP_EFFECTS = [
  {
    // Sloka 2: Mercury in the Rohini-Mrigasira group
    nakshatras: ['Rohini', 'Mrigasira'],
    dir: 'pos',
    desc: 'Mercury transiting Rohini-Mrigasira group: abundant rain, fine harvests, cattle thrive, agriculture prospers',
    weight: 0.7,
    ruleId: 'budha-group-rohini-mriga',
    category: 'agriculture',
    manifestation: 'abundant rain, fine harvests, thriving cattle',
    domain: 'economy'
  },
  {
    // Sloka 3: Mercury in the Aslesha-Magha group
    nakshatras: ['Aslesha', 'Magha'],
    dir: 'neg',
    desc: 'Mercury transiting Aslesha-Magha group: serpent fears, poison incidents, fire from lightning, ancestral displeasure',
    weight: 0.65,
    ruleId: 'budha-group-aslesha-magha',
    category: 'danger',
    manifestation: 'serpent fears, poison, lightning fires, ancestral wrath',
    domain: 'society'
  },
  {
    // Sloka 4: Mercury in the Hasta-Chitra group
    nakshatras: ['Hasta', 'Chitra'],
    dir: 'neg',
    desc: 'Mercury transiting Hasta-Chitra group: artisans suffer, trade in gems and ornaments declines, skilled workers face hardship',
    weight: 0.55,
    ruleId: 'budha-group-hasta-chitra',
    category: 'occupation',
    manifestation: 'artisan suffering, gem trade decline, skilled worker hardship',
    domain: 'economy'
  },
  {
    // Sloka 5: Mercury in the Visakha-Anuradha group
    nakshatras: ['Visakha', 'Anuradha'],
    dir: 'neg',
    desc: 'Mercury transiting Visakha-Anuradha group: legume crops fail, sesamum destroyed, travellers harassed, friends turn fickle',
    weight: 0.6,
    ruleId: 'budha-group-visakha-anuradha',
    category: 'agriculture',
    manifestation: 'legume and sesamum crop failure, traveller harassment',
    domain: 'economy'
  },
  {
    // Sloka 6: Mercury in the Moola-Purvashadha group
    nakshatras: ['Moola', 'Purvashadha'],
    dir: 'neg',
    desc: 'Mercury transiting Moola-Purvashadha group: medicines become scarce or ineffective, physicians fail, root-dealers suffer, navigation imperilled',
    weight: 0.65,
    ruleId: 'budha-group-moola-pshadha',
    category: 'health',
    manifestation: 'medicine scarcity, physician failure, navigation peril',
    domain: 'health'
  },
  {
    // Sloka 7: Mercury in the Uttarabhadra-Revati group
    nakshatras: ['Uttarabhadra', 'Revati'],
    dir: 'mix',
    desc: 'Mercury transiting Uttarabhadra-Revati group: brahmins and hermits troubled, but aquatic trade and navigation may still prosper',
    weight: 0.5,
    ruleId: 'budha-group-ubhadra-revati',
    category: 'dharma',
    manifestation: 'brahmins and hermits troubled, aquatic trade mixed',
    domain: 'society'
  }
];

// ─── MONTHLY VISIBILITY RULE (Sloka 17) ────────────────────────────────────
// Mercury visible in these months = fear

const FEAR_MONTHS = ['Pausha', 'Ashadha', 'Sravana', 'Visakha', 'Magha'];

// ─── MAIN EVALUATION ────────────────────────────────────────────────────────

/**
 * Evaluate Mercury effects per Brihat Samhita Chapter 7.
 *
 * Mercury's effects depend on its current named course (determined by the
 * nakshatra it occupies), its motion type, visibility timing, and eclipse
 * status. Seven courses, four motion types, six nakshatra-group transits,
 * monthly visibility fears, eclipse reversal, and benefic appearance
 * are all assessed.
 *
 * @param {Object} skyState - Current planetary positions
 * @param {string} skyState.positions.Mercury.nakshatra - Current Mercury nakshatra
 * @param {string} [skyState.positions.Mercury.sign] - Current Mercury sign
 * @param {boolean} [skyState.positions.Mercury.isRetrograde] - Retrograde status
 * @param {Object} mercuryContext - Mercury-specific observational context
 * @param {string} [mercuryContext.currentCourse] - Override course name (if pre-computed)
 * @param {string} mercuryContext.motionType - One of: 'direct', 'ativakra', 'vakra', 'kshina'
 * @param {boolean} mercuryContext.isVisible - Whether Mercury is currently visible
 * @param {string} [mercuryContext.visibleMonth] - Hindu month name if visible
 * @param {boolean} [mercuryContext.isEclipsed] - Mercury eclipsed by Sun
 * @param {boolean} [mercuryContext.hasEmerged] - Mercury just emerged from eclipse/combustion
 * @param {boolean} [mercuryContext.isBeneficAppearance] - Large, glossy, bright appearance
 * @returns {Object[]} Array of Effect objects
 */
export function evaluateMercury(skyState, mercuryContext) {
  const effects = [];
  const mercPos = skyState?.positions?.Mercury;
  if (!mercPos) return effects;

  const currentNak = mercPos.nakshatra;
  const {
    currentCourse: courseOverride,
    motionType,
    isVisible,
    visibleMonth,
    isEclipsed,
    hasEmerged,
    isBeneficAppearance
  } = mercuryContext || {};

  // ─── SEVEN NAMED COURSES (Sloka 1) ────────────────────────────────
  const resolvedCourse = _resolveCourse(courseOverride, currentNak);
  if (resolvedCourse) {
    effects.push({
      domain: _courseDomain(resolvedCourse.category),
      dir: resolvedCourse.dir,
      desc: resolvedCourse.desc,
      weight: resolvedCourse.weight,
      planet: 'Mercury',
      sign: mercPos.sign || null,
      ruleId: `budha-course-${resolvedCourse.name.toLowerCase()}`,
      source: 'BS Ch.7 Sl.1',
      category: resolvedCourse.category,
      manifestation: resolvedCourse.manifestation
    });
  }

  // ─── FOUR MOTION TYPES (Sloka 8) ──────────────────────────────────
  if (motionType && MOTION_EFFECTS[motionType]) {
    const motion = MOTION_EFFECTS[motionType];
    effects.push({
      domain: _motionDomain(motion.category),
      dir: motion.dir,
      desc: motion.desc,
      weight: motion.weight,
      planet: 'Mercury',
      sign: mercPos.sign || null,
      ruleId: `budha-motion-${motionType}`,
      source: 'BS Ch.7 Sl.8',
      category: motion.category,
      manifestation: motion.manifestation
    });
  }

  // ─── SIX NAKSHATRA-GROUP TRANSIT EFFECTS (Slokas 2-7) ────────────
  if (currentNak) {
    for (const group of NAKSHATRA_GROUP_EFFECTS) {
      if (group.nakshatras.includes(currentNak)) {
        effects.push({
          domain: group.domain,
          dir: group.dir,
          desc: group.desc,
          weight: group.weight,
          planet: 'Mercury',
          sign: mercPos.sign || null,
          ruleId: group.ruleId,
          source: 'BS Ch.7 Sl.2-7',
          category: group.category,
          manifestation: group.manifestation
        });
      }
    }
  }

  // ─── MONTHLY VISIBILITY = FEAR (Sloka 17) ────────────────────────
  if (isVisible && visibleMonth && FEAR_MONTHS.includes(visibleMonth)) {
    effects.push({
      domain: 'society',
      dir: 'neg',
      desc: `Mercury visible in month of ${visibleMonth} — widespread fear and anxiety among the populace`,
      weight: 0.6,
      planet: 'Mercury',
      sign: mercPos.sign || null,
      ruleId: 'budha-fear-month',
      source: 'BS Ch.7 Sl.17',
      category: 'fear',
      manifestation: `visibility in ${visibleMonth} generates public fear and unease`
    });
  }

  // ─── ECLIPSED REVERSAL (Sloka 19) ────────────────────────────────
  // When eclipsed: towns besieged. When emerged: siege raised.
  if (isEclipsed) {
    effects.push({
      domain: 'governance',
      dir: 'neg',
      desc: 'Mercury eclipsed (combust): towns are besieged, trade routes cut, communication fails, sieges begin',
      weight: 0.75,
      planet: 'Mercury',
      sign: mercPos.sign || null,
      ruleId: 'budha-eclipsed',
      source: 'BS Ch.7 Sl.19',
      category: 'siege',
      manifestation: 'towns besieged, trade routes severed, communication breakdown'
    });
  }

  if (hasEmerged) {
    effects.push({
      domain: 'governance',
      dir: 'pos',
      desc: 'Mercury emerged from eclipse/combustion: sieges are raised, towns liberated, trade routes reopen',
      weight: 0.7,
      planet: 'Mercury',
      sign: mercPos.sign || null,
      ruleId: 'budha-emerged',
      source: 'BS Ch.7 Sl.19',
      category: 'liberation',
      manifestation: 'sieges lifted, towns liberated, trade and communication restored'
    });
  }

  // ─── BENEFIC APPEARANCE (Sloka 20) ────────────────────────────────
  if (isBeneficAppearance) {
    effects.push({
      domain: 'economy',
      dir: 'pos',
      desc: 'Mercury appears large, glossy, and bright with natural color — trade, learning, communication, and all Mercury-ruled activities prosper',
      weight: 0.7,
      planet: 'Mercury',
      sign: mercPos.sign || null,
      ruleId: 'budha-benefic-appearance',
      source: 'BS Ch.7 Sl.20',
      category: 'benefic',
      manifestation: 'trade, scholarship, scribes, mathematicians, and merchants prosper'
    });
  }

  return effects;
}

// ─── HELPERS ────────────────────────────────────────────────────────────────

/**
 * Resolve the current Mercury course from override or nakshatra lookup.
 * @param {string|null} courseOverride - Explicit course name
 * @param {string|null} currentNak - Current nakshatra
 * @returns {Object|null} Course object or null
 */
function _resolveCourse(courseOverride, currentNak) {
  if (courseOverride) {
    return MERCURY_COURSES.find(c => c.name === courseOverride) || null;
  }
  if (currentNak) {
    return COURSE_BY_NAKSHATRA[currentNak] || null;
  }
  return null;
}

/**
 * Map course category to domain.
 * @param {string} category
 * @returns {string}
 */
function _courseDomain(category) {
  const MAP = {
    prosperity: 'economy',
    mixed: 'society',
    conflict: 'society',
    calamity: 'society',
    famine_disease: 'health',
    moral_decay: 'society'
  };
  return MAP[category] || 'society';
}

/**
 * Map motion category to domain.
 * @param {string} category
 * @returns {string}
 */
function _motionDomain(category) {
  const MAP = {
    commerce: 'economy',
    famine: 'economy',
    war: 'governance',
    disease: 'health'
  };
  return MAP[category] || 'society';
}

// ─── EXPORTED DATA (for testing and cross-module use) ───────────────────────

export {
  MERCURY_COURSES,
  COURSE_BY_NAKSHATRA,
  MOTION_EFFECTS,
  NAKSHATRA_GROUP_EFFECTS,
  FEAR_MONTHS
};
