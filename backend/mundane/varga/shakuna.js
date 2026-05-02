/**
 * SHAKUNA VARGA — Omen Filtering & Validation System
 * Source: Brihat Samhita Ch.86 (Shakuna Adhyaya), Ch.95-96
 *
 * This is the FILTERING layer of the omen system. Before any creature or
 * portent omen becomes a prediction, it must pass through this validation
 * engine. The BS prescribes a rigorous multi-factor check:
 *
 *   1. Blasted/Tranquil classification (Ch.86 Sl.15-16)
 *   2. Directional timing via Charcoal/Burning/Smoking (Ch.86 Sl.12)
 *   3. Creature directional strength (Ch.86 Sl.20-23)
 *   4. Seasonal disqualification (Ch.86 Sl.26-28 — delegated to cancel.js)
 *   5. Left/Right favorability (Ch.86 Sl.37-38)
 *   6. 12-factor omen strength assessment (Ch.96 Sl.1)
 *   7. Distance attenuation (Ch.95 Sl.62)
 *
 * An omen that fails any of these checks is either rejected outright
 * or attenuated so heavily that its Effect weight approaches zero.
 */

import { isSeasonallyDisqualified } from './cancel.js';
import { NAKSHATRA_BY_NAME } from './nakshatra.js';

// ─── CONSTANTS: EIGHT DIRECTIONS ────────────────────────────────────────────

const DIRECTIONS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'];

// ─── 1. BLASTED / TRANQUIL CLASSIFICATION ───────────────────────────────────
// BS Ch.86 Slokas 15-16
// 10 conditions "blasted by divine agency" — each stronger than predecessor.
// 10 conditions "blasted by action" — behavioral / physical state checks.

/**
 * Nakshatras classified as "dreadful" for omen purposes.
 * BS Ch.86 Sl.15 condition 3.
 * An omen occurring when Moon is in one of these nakshatras is blasted.
 */
export const DREADFUL_NAKSHATRAS = [
  'Moola', 'Jyeshta', 'Aslesha', 'Ardra',
  'Bharani', 'Visakha', 'Magha', 'Krittika', 'Purvaphalguni'
];

/**
 * Tithis on which omens are blasted by divine agency.
 * BS Ch.86 Sl.15 condition 2.
 * 4th, 6th, 8th, 9th, 14th of the lunar fortnight.
 */
export const BLASTED_TITHIS = [4, 6, 8, 9, 14];

/**
 * Food/state classifications for omen creatures.
 * BS Ch.86 Sl.16 tail rules.
 */
export const FOOD_CLASSIFICATION = {
  tranquil: ['grass', 'fruits', 'grains', 'seeds', 'flowers', 'water'],
  blasted:  ['meat', 'ordure', 'carrion', 'blood', 'bones', 'refuse'],
  mixed:    ['cooked food']
};

/**
 * Check all 10 "blasted by divine agency" conditions.
 * Each condition is independently evaluated. The index represents escalating
 * severity: condition 10 is stronger than condition 1.
 *
 * @param {Object} omenData - Omen observation data
 * @param {string} [omenData.direction] - Direction of omen (E/SE/S/SW/W/NW/N/NE)
 * @param {Object} skyState - Current sky state
 * @param {Object} skyState.positions - Planetary positions
 * @param {number} [skyState.tithi] - Current lunar tithi (1-30)
 * @param {string} [skyState.moonNakshatra] - Moon's current nakshatra
 * @param {string} [skyState.sunDirection] - Direction of Sun at time of omen
 * @param {Object} [omenData.wind] - Wind conditions
 * @param {string} [omenData.wind.type] - 'fierce'|'rough'|'strong'|'unfavourable'|'calm'|'gentle'
 * @returns {{ blasted: boolean, conditions: Array<{ idx: number, desc: string, severity: number }> }}
 */
export function checkDivineBlasting(omenData, skyState) {
  const conditions = [];

  // Condition 1: Muhurta of dreadful asterisms (Ch.86 Sl.15)
  const moonNak = skyState?.moonNakshatra || skyState?.positions?.Moon?.nakshatra;
  const nakData = moonNak ? NAKSHATRA_BY_NAME[moonNak] : null;
  if (nakData && (nakData.classification === 'teekshna' || nakData.classification === 'ugra')) {
    conditions.push({
      idx: 1, severity: 0.1,
      desc: `Muhurta of dreadful asterism — Moon in ${moonNak} (${nakData.classification})`
    });
  }

  // Condition 2: Blasted tithis (4th, 6th, 8th, 9th, 14th)
  const tithi = skyState?.tithi;
  const tithiInFortnight = tithi ? ((tithi - 1) % 15) + 1 : null;
  if (tithiInFortnight && BLASTED_TITHIS.includes(tithiInFortnight)) {
    conditions.push({
      idx: 2, severity: 0.2,
      desc: `Blasted tithi — ${tithiInFortnight}th of fortnight`
    });
  }

  // Condition 3: Moon in specific dreadful nakshatras
  if (moonNak && DREADFUL_NAKSHATRAS.includes(moonNak)) {
    conditions.push({
      idx: 3, severity: 0.3,
      desc: `Moon in dreadful nakshatra ${moonNak}`
    });
  }

  // Condition 4: Fierce/rough/strong/unfavourable wind
  const windType = omenData?.wind?.type;
  const fierceWinds = ['fierce', 'rough', 'strong', 'unfavourable'];
  if (windType && fierceWinds.includes(windType)) {
    conditions.push({
      idx: 4, severity: 0.4,
      desc: `Fierce wind — ${windType}`
    });
  }

  // Condition 5: Direction opposite the Sun
  if (omenData?.direction && skyState?.sunDirection) {
    const omenDirIdx = DIRECTIONS.indexOf(omenData.direction);
    const sunDirIdx = DIRECTIONS.indexOf(skyState.sunDirection);
    if (omenDirIdx !== -1 && sunDirIdx !== -1) {
      const opposite = (sunDirIdx + 4) % 8;
      if (omenDirIdx === opposite) {
        conditions.push({
          idx: 5, severity: 0.5,
          desc: `Omen direction ${omenData.direction} is opposite the Sun (${skyState.sunDirection})`
        });
      }
    }
  }

  // Conditions 6-10: Higher-order divine blasting (rare celestial conditions)
  // These require external portent input and are checked as flags.
  if (omenData?.duringEclipse) {
    conditions.push({
      idx: 6, severity: 0.6,
      desc: 'Omen during eclipse — strongly blasted'
    });
  }
  if (omenData?.duringMeteorShower) {
    conditions.push({
      idx: 7, severity: 0.7,
      desc: 'Omen during meteor shower — strongly blasted'
    });
  }
  if (omenData?.duringEarthquake) {
    conditions.push({
      idx: 8, severity: 0.8,
      desc: 'Omen during earthquake — strongly blasted'
    });
  }
  if (omenData?.duringThunder) {
    conditions.push({
      idx: 9, severity: 0.9,
      desc: 'Omen during portentous thunder — strongly blasted'
    });
  }
  if (omenData?.duringAllPortents) {
    conditions.push({
      idx: 10, severity: 1.0,
      desc: 'Omen during convergence of all portents — maximally blasted'
    });
  }

  return {
    blasted: conditions.length > 0,
    conditions
  };
}

/**
 * Check all 10 "blasted by action" conditions.
 * These relate to the physical/behavioral state of the creature or omen source.
 *
 * @param {Object} omenData - Omen observation data
 * @param {string} [omenData.movementAgainst] - 'lightning'|'comet'|'sun'|'wind' if moving against
 * @param {string} [omenData.supportCondition] - 'cut'|'broken'|'crooked'|'smeared'|'dilapidated'|'withered'|'dirty'|'intact'
 * @param {string} [omenData.creatureState] - 'lifeless'|'unconscious'|'partial'|'alive'|'alert'
 * @param {string} [omenData.voiceQuality] - 'ill-pronounced'|'lengthened'|'feeble'|'broken'|'clear'|'strong'
 * @param {Object} [omenData.physicalBehavior] - Physical behavior flags
 * @param {boolean} [omenData.physicalBehavior.flapsWings] - Flapping wings
 * @param {boolean} [omenData.physicalBehavior.shakesBeak] - Shaking beak
 * @param {boolean} [omenData.physicalBehavior.aboutToFall] - About to fall
 * @param {boolean} [omenData.physicalBehavior.hoarseCry] - Hoarse cry
 * @param {boolean} [omenData.physicalBehavior.pecksAtTrees] - Pecking at trees
 * @param {string} [omenData.food] - What the creature is eating
 * @returns {{ blasted: boolean, conditions: Array<{ idx: number, desc: string, severity: number }> }}
 */
export function checkActionBlasting(omenData) {
  const conditions = [];

  // Condition 1: Runs against lightning/comet/sun/wind
  const against = omenData?.movementAgainst;
  if (against && ['lightning', 'comet', 'sun', 'wind'].includes(against)) {
    conditions.push({
      idx: 1, severity: 0.2,
      desc: `Creature moves against ${against}`
    });
  }

  // Condition 2: On damaged support
  const support = omenData?.supportCondition;
  const damagedSupports = ['cut', 'broken', 'crooked', 'smeared', 'dilapidated', 'withered', 'dirty'];
  if (support && damagedSupports.includes(support)) {
    conditions.push({
      idx: 2, severity: 0.3,
      desc: `Creature on ${support} support`
    });
  }

  // Condition 3: Creature lifeless/unconscious/partially conscious
  const state = omenData?.creatureState;
  if (state && ['lifeless', 'unconscious', 'partial'].includes(state)) {
    conditions.push({
      idx: 3, severity: 0.4,
      desc: `Creature is ${state}`
    });
  }

  // Condition 4: Ill-pronounced/lengthened/feeble/broken voice
  const voice = omenData?.voiceQuality;
  const badVoice = ['ill-pronounced', 'lengthened', 'feeble', 'broken'];
  if (voice && badVoice.includes(voice)) {
    conditions.push({
      idx: 4, severity: 0.5,
      desc: `Creature voice is ${voice}`
    });
  }

  // Condition 5: Physical behavior — flaps wings, shakes beak, about to fall, etc.
  const phys = omenData?.physicalBehavior;
  if (phys) {
    const badBehaviors = [];
    if (phys.flapsWings)   badBehaviors.push('flaps wings');
    if (phys.shakesBeak)   badBehaviors.push('shakes beak');
    if (phys.aboutToFall)  badBehaviors.push('about to fall');
    if (phys.hoarseCry)    badBehaviors.push('cries hoarse');
    if (phys.pecksAtTrees) badBehaviors.push('pecks at trees');
    if (badBehaviors.length > 0) {
      conditions.push({
        idx: 5, severity: 0.5 + (badBehaviors.length * 0.1),
        desc: `Creature behavior: ${badBehaviors.join(', ')}`
      });
    }
  }

  // Food classification check
  const food = omenData?.food?.toLowerCase();
  if (food) {
    const isBlasted = FOOD_CLASSIFICATION.blasted.some(f => food.includes(f));
    if (isBlasted) {
      conditions.push({
        idx: 6, severity: 0.4,
        desc: `Creature eating blasted food: ${food}`
      });
    }
  }

  return {
    blasted: conditions.length > 0,
    conditions
  };
}

/**
 * Classify food as tranquil, blasted, or mixed.
 * BS Ch.86 Sl.16: grass/fruits = tranquil, meat/ordure = blasted, cooked = mixed.
 *
 * @param {string} food - Description of food being consumed
 * @returns {'tranquil'|'blasted'|'mixed'|'unknown'}
 */
export function classifyFood(food) {
  if (!food) return 'unknown';
  const lower = food.toLowerCase();
  if (FOOD_CLASSIFICATION.tranquil.some(f => lower.includes(f))) return 'tranquil';
  if (FOOD_CLASSIFICATION.blasted.some(f => lower.includes(f)))  return 'blasted';
  if (FOOD_CLASSIFICATION.mixed.some(f => lower.includes(f)))    return 'mixed';
  return 'unknown';
}

/**
 * Master blasted/tranquil check combining divine and action blasting.
 *
 * @param {Object} omenData - Omen observation data
 * @param {Object} skyState - Current sky state
 * @returns {{ blasted: boolean, tranquil: boolean, divineConditions: Array, actionConditions: Array, maxSeverity: number }}
 */
export function isOmenBlasted(omenData, skyState) {
  const divine = checkDivineBlasting(omenData, skyState);
  const action = checkActionBlasting(omenData);

  const allConditions = [...divine.conditions, ...action.conditions];
  const maxSeverity = allConditions.reduce((max, c) => Math.max(max, c.severity), 0);

  // Tranquil = explicitly not blasted AND positive indicators present
  const foodClass = classifyFood(omenData?.food);
  const hasTranquilFood = foodClass === 'tranquil';
  const creatureAlert = omenData?.creatureState === 'alert' || omenData?.creatureState === 'alive';
  const voiceClear = omenData?.voiceQuality === 'clear' || omenData?.voiceQuality === 'strong';
  const supportIntact = omenData?.supportCondition === 'intact' || !omenData?.supportCondition;

  const tranquil = !divine.blasted && !action.blasted &&
    (hasTranquilFood || creatureAlert || voiceClear || supportIntact);

  return {
    blasted: divine.blasted || action.blasted,
    tranquil,
    divineConditions: divine.conditions,
    actionConditions: action.conditions,
    maxSeverity
  };
}

// ─── 2. DIRECTIONAL TIMING (CHARCOAL / BURNING / SMOKING) ──────────────────
// BS Ch.86 Sloka 12
// 8-direction x 8-watch rotation determines temporal significance.
// "Charcoal" = past event, "Burning" = present, "Smoking" = future.
// The remaining 5 directions in each watch = Tranquil.
// 5th direction from Charcoal = equally auspicious.

/**
 * Directional timing table.
 * Each watch maps to { charcoal, burning, smoking } directions.
 * Watches 1-4 are daytime (each ~3 hours from sunrise),
 * Watches 5-8 are nighttime (each ~3 hours from sunset).
 *
 * The rotation follows the 8-direction cycle: E→SE→S→SW→W→NW→N→NE.
 */
export const DIRECTIONAL_TIMING = [
  // Day watches
  { watch: 1, period: 'day',   charcoal: 'NE', burning: 'E',  smoking: 'SE' },
  { watch: 2, period: 'day',   charcoal: 'E',  burning: 'SE', smoking: 'S'  },
  { watch: 3, period: 'day',   charcoal: 'SE', burning: 'S',  smoking: 'SW' },
  { watch: 4, period: 'day',   charcoal: 'S',  burning: 'SW', smoking: 'W'  },
  // Night watches
  { watch: 5, period: 'night', charcoal: 'SW', burning: 'W',  smoking: 'NW' },
  { watch: 6, period: 'night', charcoal: 'W',  burning: 'NW', smoking: 'N'  },
  { watch: 7, period: 'night', charcoal: 'NW', burning: 'N',  smoking: 'NE' },
  { watch: 8, period: 'night', charcoal: 'N',  burning: 'NE', smoking: 'E'  }
];

/**
 * Get the temporal significance of an omen based on direction and watch.
 * BS Ch.86 Sloka 12.
 *
 * @param {string} direction - Direction of omen (E/SE/S/SW/W/NW/N/NE)
 * @param {number} watchOfDay - Watch number 1-8 (1-4 day, 5-8 night)
 * @returns {{ timing: 'charcoal'|'burning'|'smoking'|'tranquil'|'auspicious', desc: string }}
 */
export function getDirectionalTiming(direction, watchOfDay) {
  if (watchOfDay < 1 || watchOfDay > 8) {
    return { timing: 'tranquil', desc: 'Invalid watch — treated as tranquil' };
  }

  const entry = DIRECTIONAL_TIMING[watchOfDay - 1];
  if (!entry) {
    return { timing: 'tranquil', desc: 'Watch data not found — treated as tranquil' };
  }

  // Check if direction matches charcoal/burning/smoking
  if (direction === entry.charcoal) {
    return { timing: 'charcoal', desc: `${direction} in watch ${watchOfDay} — past event (charcoal)` };
  }
  if (direction === entry.burning) {
    return { timing: 'burning', desc: `${direction} in watch ${watchOfDay} — present event (burning)` };
  }
  if (direction === entry.smoking) {
    return { timing: 'smoking', desc: `${direction} in watch ${watchOfDay} — future event (smoking)` };
  }

  // Check 5th direction from charcoal = equally auspicious
  const charcoalIdx = DIRECTIONS.indexOf(entry.charcoal);
  if (charcoalIdx !== -1) {
    const auspiciousIdx = (charcoalIdx + 4) % 8;
    if (direction === DIRECTIONS[auspiciousIdx]) {
      return {
        timing: 'auspicious',
        desc: `${direction} in watch ${watchOfDay} — 5th from charcoal (${entry.charcoal}), equally auspicious`
      };
    }
  }

  // Remaining 4 directions = tranquil
  return {
    timing: 'tranquil',
    desc: `${direction} in watch ${watchOfDay} — tranquil quarter (neither active nor inauspicious)`
  };
}

// ─── 3. CREATURE DIRECTIONAL STRENGTH ───────────────────────────────────────
// BS Ch.86 Slokas 20-23
// Each creature has a cardinal direction where its omens are strongest.

/**
 * Creatures strong in each cardinal direction.
 * When a creature appears in its strong direction, the omen carries full weight.
 * In opposite direction, weight is minimal. In adjacent, moderate.
 */
export const CREATURE_DIRECTION_STRENGTH = {
  E:  ['cock', 'elephant', 'peacock', 'musk-rat'],
  S:  ['jackal', 'owl', 'crow', 'ruddy goose', 'bear', 'dove'],
  W:  ['cow', 'hare', 'swan', 'cat'],
  N:  ['woodpecker', 'deer', 'rat', 'antelope', 'horse', 'cuckoo', 'blue jay', 'porcupine']
};

/** Reverse lookup: creature name → strong direction */
const _creatureToDirection = {};
for (const [dir, creatures] of Object.entries(CREATURE_DIRECTION_STRENGTH)) {
  for (const c of creatures) {
    _creatureToDirection[c] = dir;
  }
}

/**
 * Get directional strength factor for a creature appearing in a given direction.
 * BS Ch.86 Slokas 20-23.
 *
 * Returns a weight multiplier:
 *   1.0 = creature in its strong direction (full effect)
 *   0.75 = creature in adjacent direction (moderate effect)
 *   0.25 = creature in opposite direction (minimal effect)
 *   0.5 = creature not in database or neutral direction
 *
 * @param {string} creature - Creature name (lowercase)
 * @param {string} direction - Direction of sighting (E/SE/S/SW/W/NW/N/NE)
 * @returns {{ weight: number, strongDirection: string|null, desc: string }}
 */
export function getCreatureStrength(creature, direction) {
  const creatureLower = creature.toLowerCase();
  const strongDir = _creatureToDirection[creatureLower] || null;

  if (!strongDir) {
    return {
      weight: 0.5,
      strongDirection: null,
      desc: `${creature} has no specific directional strength — neutral weight`
    };
  }

  const strongIdx = DIRECTIONS.indexOf(strongDir);
  const omenIdx = DIRECTIONS.indexOf(direction);

  if (strongIdx === -1 || omenIdx === -1) {
    return { weight: 0.5, strongDirection: strongDir, desc: 'Invalid direction — neutral weight' };
  }

  // Same cardinal or within 1 step of strong direction
  const offset = Math.abs(omenIdx - strongIdx);
  const normalizedOffset = Math.min(offset, 8 - offset);

  if (normalizedOffset === 0) {
    return {
      weight: 1.0,
      strongDirection: strongDir,
      desc: `${creature} in strong direction ${strongDir} — full omen weight`
    };
  }

  if (normalizedOffset <= 2) {
    return {
      weight: 0.75,
      strongDirection: strongDir,
      desc: `${creature} adjacent to strong direction ${strongDir} — moderate weight`
    };
  }

  if (normalizedOffset === 4) {
    return {
      weight: 0.25,
      strongDirection: strongDir,
      desc: `${creature} opposite strong direction ${strongDir} — minimal weight`
    };
  }

  return {
    weight: 0.5,
    strongDirection: strongDir,
    desc: `${creature} in neutral direction relative to strong ${strongDir}`
  };
}

// ─── 4. SEASONAL DISQUALIFICATION ──────────────────────────────────────────
// Delegated to cancel.js — isSeasonallyDisqualified(creature, date)
// Re-exported here for convenience within the shakuna pipeline.
export { isSeasonallyDisqualified };

// ─── 5. LEFT / RIGHT FAVORABILITY ──────────────────────────────────────────
// BS Ch.86 Slokas 37-38
// LEFT-favourable creatures: omen on the left side is auspicious.
// RIGHT-favourable creatures: omen on the right side is auspicious.

/**
 * Creatures for which a LEFT-side appearance is favourable.
 * Also: all male-named creatures default to left-favourable.
 */
export const LEFT_FAVOURABLE = [
  'jackal', 'rabbit', 'ichneumon', 'lizard', 'sow', 'cuckoo'
];

/**
 * Creatures for which a RIGHT-side appearance is favourable.
 * Also: all female-named creatures default to right-favourable.
 */
export const RIGHT_FAVOURABLE = [
  'monkey', 'vulture', 'peacock', 'hawk'
];

/**
 * Determine favorability based on creature and side of appearance.
 * BS Ch.86 Slokas 37-38.
 *
 * @param {string} creature - Creature name
 * @param {'left'|'right'} side - Side of appearance relative to observer
 * @param {'male'|'female'|null} [genderName=null] - Gender implied by creature name
 * @returns {{ favourable: boolean, desc: string }}
 */
export function checkLeftRightFavorability(creature, side, genderName = null) {
  const lower = creature.toLowerCase();

  // Check explicit lists first
  const isLeftCreature = LEFT_FAVOURABLE.includes(lower);
  const isRightCreature = RIGHT_FAVOURABLE.includes(lower);

  if (isLeftCreature) {
    const favourable = side === 'left';
    return {
      favourable,
      desc: favourable
        ? `${creature} on LEFT — favourable (Ch.86 Sl.37)`
        : `${creature} on RIGHT — unfavourable (left-favourable creature)`
    };
  }

  if (isRightCreature) {
    const favourable = side === 'right';
    return {
      favourable,
      desc: favourable
        ? `${creature} on RIGHT — favourable (Ch.86 Sl.38)`
        : `${creature} on LEFT — unfavourable (right-favourable creature)`
    };
  }

  // Fallback: male-named → left-favourable, female-named → right-favourable
  if (genderName === 'male') {
    const favourable = side === 'left';
    return {
      favourable,
      desc: favourable
        ? `${creature} (male-named) on LEFT — favourable (Ch.86 Sl.37)`
        : `${creature} (male-named) on RIGHT — unfavourable`
    };
  }

  if (genderName === 'female') {
    const favourable = side === 'right';
    return {
      favourable,
      desc: favourable
        ? `${creature} (female-named) on RIGHT — favourable (Ch.86 Sl.38)`
        : `${creature} (female-named) on LEFT — unfavourable`
    };
  }

  // Unknown creature, unknown gender — neutral
  return {
    favourable: true,
    desc: `${creature} — no left/right preference known, treated as neutral`
  };
}

// ─── 6. 12-FACTOR OMEN STRENGTH ASSESSMENT ─────────────────────────────────
// BS Ch.96 Sloka 1
// Before declaring effects, these 12 factors must be checked.
// Each factor either strengthens or weakens the omen.

/**
 * The 12 factors that determine omen strength.
 * Each factor returns a multiplier between 0.0 and 1.0.
 */
export const OMEN_STRENGTH_FACTORS = [
  'quarter',         // Directional quarter strength (from creature table)
  'place',           // Type of place — temple, crossroads, cremation ground, etc.
  'movements',       // Creature's movement pattern — steady, erratic, purposeful
  'sound',           // Quality of cry — clear, melodious vs harsh, broken
  'weekday',         // Auspicious or inauspicious weekday
  'nakshatra',       // Moon's nakshatra classification
  'muhurta',         // Current muhurta quality
  'hora',            // Current hora ruler
  'karana',          // Current karana (half-tithi)
  'lagna',           // Ascendant sign
  'lagnaDivisions',  // Drekkana, navamsa, etc. of ascendant
  'signMutability'   // Fixed/moveable/dual nature of lagna sign
];

/** Auspicious weekdays for omen reception */
const AUSPICIOUS_WEEKDAYS = ['Monday', 'Wednesday', 'Thursday', 'Friday'];

/** Inauspicious weekdays for omen reception */
const INAUSPICIOUS_WEEKDAYS = ['Tuesday', 'Saturday'];

/** Place classification by auspiciousness */
const PLACE_QUALITY = {
  auspicious:   ['temple', 'palace', 'garden', 'river bank', 'mountain', 'cow pen', 'hermitage'],
  inauspicious: ['cremation ground', 'battlefield', 'slaughterhouse', 'ruined house', 'thorny ground'],
  neutral:      ['road', 'crossroads', 'marketplace', 'field', 'village']
};

/** Sign mutability classification */
const SIGN_MUTABILITY = {
  moveable: ['Aries', 'Cancer', 'Libra', 'Capricorn'],
  fixed:    ['Taurus', 'Leo', 'Scorpio', 'Aquarius'],
  dual:     ['Gemini', 'Virgo', 'Sagittarius', 'Pisces']
};

/**
 * Evaluate the 12-factor omen strength.
 * BS Ch.96 Sl.1.
 *
 * @param {Object} omenData - Omen observation data
 * @param {string} [omenData.creature] - Creature name
 * @param {string} [omenData.direction] - Direction of sighting
 * @param {string} [omenData.place] - Type of place
 * @param {string} [omenData.movement] - 'steady'|'erratic'|'purposeful'
 * @param {string} [omenData.sound] - 'clear'|'melodious'|'harsh'|'broken'|'silent'
 * @param {Object} skyState - Current sky state
 * @param {string} [skyState.weekday] - Day of week
 * @param {string} [skyState.moonNakshatra] - Moon's nakshatra
 * @param {string} [skyState.muhurta] - Current muhurta name
 * @param {string} [skyState.hora] - Current hora planet
 * @param {number} [skyState.karana] - Current karana number
 * @param {string} [skyState.lagna] - Ascendant sign
 * @returns {{ totalStrength: number, factors: Array<{ name: string, score: number, desc: string }> }}
 */
export function evaluate12Factors(omenData, skyState) {
  const factors = [];

  // 1. Quarter strength
  if (omenData?.creature && omenData?.direction) {
    const cs = getCreatureStrength(omenData.creature, omenData.direction);
    factors.push({ name: 'quarter', score: cs.weight, desc: cs.desc });
  } else {
    factors.push({ name: 'quarter', score: 0.5, desc: 'No creature/direction data — neutral' });
  }

  // 2. Place
  const place = omenData?.place?.toLowerCase();
  if (place) {
    if (PLACE_QUALITY.auspicious.some(p => place.includes(p))) {
      factors.push({ name: 'place', score: 1.0, desc: `Auspicious place: ${place}` });
    } else if (PLACE_QUALITY.inauspicious.some(p => place.includes(p))) {
      factors.push({ name: 'place', score: 0.2, desc: `Inauspicious place: ${place}` });
    } else {
      factors.push({ name: 'place', score: 0.6, desc: `Neutral place: ${place}` });
    }
  } else {
    factors.push({ name: 'place', score: 0.5, desc: 'No place data' });
  }

  // 3. Movements
  const movement = omenData?.movement;
  if (movement === 'steady' || movement === 'purposeful') {
    factors.push({ name: 'movements', score: 0.9, desc: `Steady/purposeful movement` });
  } else if (movement === 'erratic') {
    factors.push({ name: 'movements', score: 0.3, desc: 'Erratic movement' });
  } else {
    factors.push({ name: 'movements', score: 0.5, desc: 'No movement data' });
  }

  // 4. Sound
  const sound = omenData?.sound;
  if (sound === 'clear' || sound === 'melodious') {
    factors.push({ name: 'sound', score: 0.9, desc: `Clear/melodious sound` });
  } else if (sound === 'harsh' || sound === 'broken') {
    factors.push({ name: 'sound', score: 0.2, desc: `Harsh/broken sound` });
  } else if (sound === 'silent') {
    factors.push({ name: 'sound', score: 0.5, desc: 'Silent omen' });
  } else {
    factors.push({ name: 'sound', score: 0.5, desc: 'No sound data' });
  }

  // 5. Weekday
  const weekday = skyState?.weekday;
  if (weekday && AUSPICIOUS_WEEKDAYS.includes(weekday)) {
    factors.push({ name: 'weekday', score: 0.9, desc: `Auspicious weekday: ${weekday}` });
  } else if (weekday && INAUSPICIOUS_WEEKDAYS.includes(weekday)) {
    factors.push({ name: 'weekday', score: 0.2, desc: `Inauspicious weekday: ${weekday}` });
  } else if (weekday === 'Sunday') {
    factors.push({ name: 'weekday', score: 0.6, desc: 'Sunday — moderately auspicious' });
  } else {
    factors.push({ name: 'weekday', score: 0.5, desc: weekday ? `${weekday}` : 'No weekday data' });
  }

  // 6. Nakshatra
  const moonNak = skyState?.moonNakshatra || skyState?.positions?.Moon?.nakshatra;
  if (moonNak) {
    const nakData = NAKSHATRA_BY_NAME[moonNak];
    if (nakData) {
      const nakScore = {
        dhruva: 0.9, kshipra: 0.85, mridu: 0.8, chara: 0.6,
        mridu_teekshna: 0.5, ugra: 0.3, teekshna: 0.2
      }[nakData.classification] || 0.5;
      factors.push({ name: 'nakshatra', score: nakScore, desc: `Moon in ${moonNak} (${nakData.classification})` });
    } else {
      factors.push({ name: 'nakshatra', score: 0.5, desc: `Moon in ${moonNak} — unknown class` });
    }
  } else {
    factors.push({ name: 'nakshatra', score: 0.5, desc: 'No nakshatra data' });
  }

  // 7. Muhurta
  if (skyState?.muhurta) {
    // Simplified: presence of data = 0.6 (would need full muhurta table for accuracy)
    factors.push({ name: 'muhurta', score: 0.6, desc: `Muhurta: ${skyState.muhurta}` });
  } else {
    factors.push({ name: 'muhurta', score: 0.5, desc: 'No muhurta data' });
  }

  // 8. Hora
  const hora = skyState?.hora;
  if (hora) {
    const horaScore = NATURAL_BENEFIC_SET.has(hora) ? 0.8 : 0.4;
    factors.push({ name: 'hora', score: horaScore, desc: `Hora of ${hora}` });
  } else {
    factors.push({ name: 'hora', score: 0.5, desc: 'No hora data' });
  }

  // 9. Karana
  if (skyState?.karana !== undefined) {
    // Simplified: even karana = slightly better
    const karScore = skyState.karana % 2 === 0 ? 0.6 : 0.5;
    factors.push({ name: 'karana', score: karScore, desc: `Karana: ${skyState.karana}` });
  } else {
    factors.push({ name: 'karana', score: 0.5, desc: 'No karana data' });
  }

  // 10. Lagna
  const lagna = skyState?.lagna;
  if (lagna) {
    factors.push({ name: 'lagna', score: 0.6, desc: `Lagna: ${lagna}` });
  } else {
    factors.push({ name: 'lagna', score: 0.5, desc: 'No lagna data' });
  }

  // 11. Lagna divisions (drekkana, navamsa)
  if (skyState?.lagnaDivisions) {
    factors.push({ name: 'lagnaDivisions', score: 0.6, desc: 'Lagna division data present' });
  } else {
    factors.push({ name: 'lagnaDivisions', score: 0.5, desc: 'No lagna division data' });
  }

  // 12. Sign mutability
  if (lagna) {
    if (SIGN_MUTABILITY.fixed.includes(lagna)) {
      factors.push({ name: 'signMutability', score: 0.9, desc: `Fixed lagna (${lagna}) — strong, lasting effect` });
    } else if (SIGN_MUTABILITY.moveable.includes(lagna)) {
      factors.push({ name: 'signMutability', score: 0.5, desc: `Moveable lagna (${lagna}) — transient effect` });
    } else if (SIGN_MUTABILITY.dual.includes(lagna)) {
      factors.push({ name: 'signMutability', score: 0.7, desc: `Dual lagna (${lagna}) — moderate duration` });
    }
  } else {
    factors.push({ name: 'signMutability', score: 0.5, desc: 'No lagna — cannot assess mutability' });
  }

  // Composite strength = geometric mean of all factor scores
  const totalStrength = factors.length > 0
    ? Math.pow(
        factors.reduce((prod, f) => prod * Math.max(f.score, 0.01), 1),
        1 / factors.length
      )
    : 0.5;

  return { totalStrength, factors };
}

/** Set of natural benefic planets for hora check */
const NATURAL_BENEFIC_SET = new Set(['Jupiter', 'Venus', 'Mercury', 'Moon']);

// ─── 7. DISTANCE ATTENUATION ───────────────────────────────────────────────
// BS Ch.95 Sloka 62
// Beyond 1 Kros (~2 miles / ~3.2 km) = no effect.
// Pranayama remedy: 1st evil = 11 pranayamas, 2nd = 16, 3rd = return home.

/** One Kros in various units */
export const KROS_DISTANCE = {
  miles: 2,
  km: 3.2,
  meters: 3200
};

/** Pranayama remedies for successive evil omens */
export const PRANAYAMA_REMEDY = [
  { omenCount: 1, pranayamas: 11, desc: 'First evil omen — perform 11 pranayamas' },
  { omenCount: 2, pranayamas: 16, desc: 'Second evil omen — perform 16 pranayamas' },
  { omenCount: 3, pranayamas: null, desc: 'Third evil omen — return home immediately' }
];

/**
 * Calculate distance attenuation for an omen.
 * BS Ch.95 Sl.62: Beyond 1 Kros = no effect.
 *
 * @param {number} distanceKm - Distance to omen source in kilometers
 * @returns {{ weight: number, effective: boolean, desc: string }}
 */
export function getDistanceAttenuation(distanceKm) {
  if (distanceKm <= 0) {
    return { weight: 1.0, effective: true, desc: 'Omen at observer location — full effect' };
  }

  if (distanceKm > KROS_DISTANCE.km) {
    return {
      weight: 0,
      effective: false,
      desc: `Omen at ${distanceKm.toFixed(1)} km — beyond 1 Kros (${KROS_DISTANCE.km} km), no effect (Ch.95 Sl.62)`
    };
  }

  // Linear attenuation within 1 Kros
  const weight = 1 - (distanceKm / KROS_DISTANCE.km);
  return {
    weight: Math.max(0, Math.min(1, weight)),
    effective: true,
    desc: `Omen at ${distanceKm.toFixed(1)} km — weight ${weight.toFixed(2)} (within 1 Kros)`
  };
}

/**
 * Get the pranayama remedy for a sequence of evil omens.
 *
 * @param {number} evilOmenCount - Number of successive evil omens encountered (1-based)
 * @returns {{ pranayamas: number|null, returnHome: boolean, desc: string }}
 */
export function getPranayamaRemedy(evilOmenCount) {
  if (evilOmenCount <= 0) {
    return { pranayamas: 0, returnHome: false, desc: 'No evil omens — no remedy needed' };
  }
  if (evilOmenCount >= 3) {
    return { pranayamas: null, returnHome: true, desc: 'Third evil omen — return home immediately (Ch.95 Sl.62)' };
  }
  const remedy = PRANAYAMA_REMEDY[evilOmenCount - 1];
  return {
    pranayamas: remedy.pranayamas,
    returnHome: false,
    desc: remedy.desc
  };
}

// ─── MASTER OMEN ASSESSMENT ─────────────────────────────────────────────────

/**
 * Comprehensive omen assessment pipeline.
 * Runs ALL validation checks and returns a final Effect-compatible result.
 *
 * @param {Object} omenData - Complete omen observation data
 * @param {string} omenData.creature - Creature/source name
 * @param {string} omenData.direction - Direction of sighting (E/SE/S/SW/W/NW/N/NE)
 * @param {number} [omenData.distanceKm] - Distance to omen in km
 * @param {'left'|'right'} [omenData.side] - Side of appearance
 * @param {'male'|'female'|null} [omenData.genderName] - Gender implication of name
 * @param {string} [omenData.place] - Place type
 * @param {string} [omenData.movement] - Movement pattern
 * @param {string} [omenData.sound] - Sound quality
 * @param {string} [omenData.food] - What creature is eating
 * @param {string} [omenData.creatureState] - State of creature
 * @param {string} [omenData.voiceQuality] - Voice quality
 * @param {string} [omenData.supportCondition] - Condition of support/perch
 * @param {Object} [omenData.physicalBehavior] - Physical behavior flags
 * @param {Object} [omenData.wind] - Wind conditions
 * @param {Object} skyState - Current sky state
 * @param {number} [skyState.tithi] - Lunar tithi
 * @param {string} [skyState.moonNakshatra] - Moon's nakshatra
 * @param {string} [skyState.weekday] - Day of week
 * @param {string} [skyState.sunDirection] - Direction of Sun
 * @param {string} [skyState.lagna] - Ascendant sign
 * @param {string} [skyState.hora] - Hora planet
 * @param {Object} skyState.positions - Planetary positions
 * @param {Date|string} date - Date of observation
 * @returns {Object} Assessment result with Effect-compatible fields
 */
export function assessOmen(omenData, skyState, date) {
  const checks = [];
  let finalWeight = 1.0;
  let rejected = false;
  let rejectionReason = null;

  // ── Check 1: Distance attenuation ──
  if (omenData.distanceKm !== undefined) {
    const dist = getDistanceAttenuation(omenData.distanceKm);
    checks.push({ check: 'distance', ...dist });
    if (!dist.effective) {
      rejected = true;
      rejectionReason = dist.desc;
    }
    finalWeight *= dist.weight;
  }

  // ── Check 2: Seasonal disqualification (from cancel.js) ──
  if (omenData.creature && date) {
    const seasonal = isSeasonallyDisqualified(omenData.creature, date);
    checks.push({ check: 'seasonal', ...seasonal });
    if (seasonal.disqualified) {
      rejected = true;
      rejectionReason = seasonal.reason;
    }
  }

  // ── Check 3: Blasted / Tranquil classification ──
  const blastCheck = isOmenBlasted(omenData, skyState);
  checks.push({ check: 'blasted', ...blastCheck });
  if (blastCheck.blasted) {
    // Blasted omens are not outright rejected but severely attenuated
    finalWeight *= Math.max(0.05, 1 - blastCheck.maxSeverity);
  }
  if (blastCheck.tranquil) {
    // Tranquil omens get a modest boost
    finalWeight *= 1.15;
  }

  // ── Check 4: Directional timing ──
  if (omenData.direction && skyState?.watchOfDay) {
    const timing = getDirectionalTiming(omenData.direction, skyState.watchOfDay);
    checks.push({ check: 'directionalTiming', ...timing });
    if (timing.timing === 'charcoal') {
      // Past event — informational only, reduced weight for prediction
      finalWeight *= 0.3;
    } else if (timing.timing === 'burning') {
      // Present event — full relevance
      finalWeight *= 1.0;
    } else if (timing.timing === 'smoking') {
      // Future event — full predictive weight
      finalWeight *= 1.0;
    } else if (timing.timing === 'auspicious') {
      finalWeight *= 1.1;
    }
    // tranquil = no modification
  }

  // ── Check 5: Creature directional strength ──
  if (omenData.creature && omenData.direction) {
    const strength = getCreatureStrength(omenData.creature, omenData.direction);
    checks.push({ check: 'creatureDirection', ...strength });
    finalWeight *= strength.weight;
  }

  // ── Check 6: Left/Right favorability ──
  if (omenData.creature && omenData.side) {
    const lr = checkLeftRightFavorability(omenData.creature, omenData.side, omenData.genderName);
    checks.push({ check: 'leftRight', ...lr });
    if (!lr.favourable) {
      finalWeight *= 0.4;
    }
  }

  // ── Check 7: 12-factor strength assessment ──
  const strength12 = evaluate12Factors(omenData, skyState);
  checks.push({ check: 'twelveFactor', totalStrength: strength12.totalStrength });
  finalWeight *= strength12.totalStrength;

  // Clamp final weight
  finalWeight = Math.max(0, Math.min(1, finalWeight));

  // Determine overall direction (pos/neg/mix) from favorability signals
  const favorableSignals = checks.filter(c =>
    c.favourable === true || c.tranquil === true || c.timing === 'auspicious'
  ).length;
  const unfavorableSignals = checks.filter(c =>
    c.favourable === false || c.blasted === true
  ).length;
  const dir = rejected ? 'neg'
    : favorableSignals > unfavorableSignals ? 'pos'
    : unfavorableSignals > favorableSignals ? 'neg'
    : 'mix';

  return {
    // Effect-compatible fields
    domain: 'omen',
    dir,
    desc: rejected
      ? `Omen rejected: ${rejectionReason}`
      : `Omen from ${omenData.creature || 'unknown'} in ${omenData.direction || '?'} — assessed weight ${finalWeight.toFixed(3)}`,
    weight: finalWeight,
    planet: null,
    sign: skyState?.lagna || null,
    ruleId: 'shakuna_assessment',
    source: 'BS Ch.86, Ch.95-96',
    category: 'shakuna',
    manifestation: rejected ? 'rejected' : (blastCheck.blasted ? 'blasted' : (blastCheck.tranquil ? 'tranquil' : 'active')),

    // Extended assessment data
    rejected,
    rejectionReason,
    checks,
    twelveFactor: strength12
  };
}
