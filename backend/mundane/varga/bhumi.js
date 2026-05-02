/**
 * भूमि वर्ग — Earthquake Circles & Portent Classification
 *
 * Source: Brihat Samhita
 *   Ch.32 (Bhukampa Adhyaya) — Earthquake system, 4 elemental circles
 *   Ch.46 (Utpata Adhyaya)   — Portent classification & idol portents
 *
 * The BS divides earthquakes into 4 circles based on the Moon's nakshatra
 * at the time of the tremor. Each circle has precursors, effects, affected
 * regions, timing of fruition, and area of influence.
 *
 * Portents are classified in a 3-tier system: Celestial / Atmospheric /
 * Terrestrial, with differing remediability. Idol portents map deity to
 * target with an 8-month fruition window.
 *
 * Exports:
 *   evaluateEarthquake(nakshatraAtTime, timeOfDay)
 *   classifyPortent(portentType)
 *   getIdolPortentTarget(deity)
 */

import { NAKSHATRAS } from './nakshatra.js';

// ─── EARTHQUAKE CIRCLES (Ch.32 Slokas 1-26) ────────────────────────────────
// Each circle: element, nakshatras, precursors, effects, regions, timing, area

/**
 * @typedef {Object} EarthquakeCircle
 * @property {string} name - Circle name (Sanskrit element)
 * @property {string} element - Governing element
 * @property {string[]} nakshatras - Moon nakshatras that activate this circle
 * @property {string[]} precursors - Warning signs before earthquake
 * @property {string[]} effects - Consequences of the earthquake
 * @property {string[]} regions - Affected ancient regions
 * @property {string} timing - Duration of effects
 * @property {number} timingDays - Duration in days
 * @property {number} areaYojanas - Area of destruction in yojanas
 * @property {string} source - Sloka reference
 */

export const EARTHQUAKE_CIRCLES = {
  Vayu: {
    name: 'Vayu',
    element: 'Wind',
    nakshatras: [
      'Uttaraphalguni', 'Hasta', 'Chitra', 'Swati',
      'Punarvasu', 'Mrigasira', 'Aswini'
    ],
    precursors: [
      'Smoke-covered quarters of the sky',
      'Dust-laden wind from all directions',
      'Sun appears dim and coppery'
    ],
    effects: [
      'Crops wither, water sources dry, forests decay',
      'Diseases: asthma, madness, fever spread',
      'Trading community suffers losses',
      'Wind damage to structures and vessels'
    ],
    regions: ['Saurashtra', 'Kuru', 'Magadha', 'Dasarna', 'Mathsya'],
    timing: '2 months',
    timingDays: 60,
    areaYojanas: 200,
    source: 'Ch.32 Sl.3-8'
  },

  Agni: {
    name: 'Agni',
    element: 'Fire',
    nakshatras: [
      'Pushya', 'Krittika', 'Visakha', 'Bharani',
      'Magha', 'Purvabhadra', 'Purvaphalguni'
    ],
    precursors: [
      'Falling stars and meteors in abundance',
      'Fire visible at the horizon',
      'Fire rages without apparent cause'
    ],
    effects: [
      'Clouds destroyed, rainfall ceases',
      'Lakes and water bodies dry up',
      'Kings quarrel, rulers at loggerheads',
      'Diseases: herpes, jaundice, skin ailments'
    ],
    regions: ['Asmaka', 'Anga', 'Bahleeka', 'Tangana', 'Kalinga', 'Vanga', 'Dravida'],
    timing: '45 days',
    timingDays: 45,
    areaYojanas: 110,
    source: 'Ch.32 Sl.9-14'
  },

  Indra: {
    name: 'Indra',
    element: 'Water/Rain',
    nakshatras: [
      'Abhijit', 'Sravana', 'Dhanishta', 'Rohini',
      'Jyeshta', 'Uttarashadha', 'Anuradha'
    ],
    precursors: [
      'Mountain-like thunder clouds gather suddenly',
      'Heavy rain pours in torrents',
      'Sky appears dark as collyrium'
    ],
    effects: [
      'Ruin of families, kings, and corporations',
      'Diseases: dysentery, swelling, dropsy',
      'BUT: desirable rainfall follows — land becomes fertile',
      'Mixed effect: destruction then renewal'
    ],
    regions: [
      'Kasi', 'Parava', 'Kirata', 'Kira', 'Abhisara',
      'Madra', 'Arbuda', 'Saurashtra', 'Malwa'
    ],
    timing: '1 week',
    timingDays: 7,
    areaYojanas: 160,
    source: 'Ch.32 Sl.15-20'
  },

  Varuna: {
    name: 'Varuna',
    element: 'Ocean/Water',
    nakshatras: [
      'Revati', 'Purvashadha', 'Ardra', 'Aslesha',
      'Moola', 'Uttarabhadra', 'Satabhishak'
    ],
    precursors: [
      'Huge blue clouds appear in the sky',
      'Soft rumbling sound like distant ocean',
      'Lightning without thunder, gentle glow'
    ],
    effects: [
      'Kills those dependent on sea and rivers',
      'Excessive rainfall causes flooding',
      'Peace prevails — people forget their hatreds',
      'Fishermen and sailors most affected'
    ],
    regions: ['Gonarda', 'Chedi', 'Kukura', 'Kirata', 'Videha'],
    timing: 'Same day',
    timingDays: 1,
    areaYojanas: 180,
    source: 'Ch.32 Sl.21-26'
  }
};

// ─── CIRCLE CANCELLATION PAIRS (Ch.32 Sl.27) ───────────────────────────────
// When two earthquakes from opposing circles occur simultaneously,
// their effects cancel each other out.

const CANCELLATION_PAIRS = [
  { a: 'Indra', b: 'Vayu' },
  { a: 'Varuna', b: 'Agni' }
];

// ─── MIXED COMBINATION EFFECTS (Ch.32 Sl.28-29) ────────────────────────────

/**
 * @typedef {Object} CircleCombination
 * @property {string} circle1
 * @property {string} circle2
 * @property {string} dir - "pos"|"neg"|"mix"
 * @property {string} effect - Result of the combination
 * @property {number} weight - Severity 0-1
 * @property {string} source
 */

export const CIRCLE_COMBINATIONS = [
  {
    circle1: 'Agni', circle2: 'Vayu',
    dir: 'neg', weight: 1.0,
    effect: 'Celebrated king dies, famine and pestilence follow',
    source: 'Ch.32 Sl.28'
  },
  {
    circle1: 'Vayu', circle2: 'Agni',
    dir: 'neg', weight: 1.0,
    effect: 'Celebrated king dies, famine and pestilence follow',
    source: 'Ch.32 Sl.28'
  },
  {
    circle1: 'Varuna', circle2: 'Indra',
    dir: 'pos', weight: 0.9,
    effect: 'Plenty, prosperity, and bountiful rain for the land',
    source: 'Ch.32 Sl.29'
  },
  {
    circle1: 'Indra', circle2: 'Varuna',
    dir: 'pos', weight: 0.9,
    effect: 'Plenty, prosperity, and bountiful rain for the land',
    source: 'Ch.32 Sl.29'
  }
];

// ─── REPEAT EARTHQUAKE RULE (Ch.32 Sl.32) ──────────────────────────────────
// If earthquake recurs on 3rd, 4th, or 7th day, prominent kings are destroyed.

export const REPEAT_QUAKE_CRITICAL_DAYS = [3, 4, 7];

// ─── PORTENT 3-TIER CLASSIFICATION (Ch.46) ─────────────────────────────────

/**
 * @typedef {Object} PortentClass
 * @property {string} tier - "celestial"|"atmospheric"|"terrestrial"
 * @property {string} sanskrit - Sanskrit name
 * @property {string[]} examples - Example portent types
 * @property {string} remediability - Ease of remedy
 * @property {string} remedyNote - Conditions for remedy
 * @property {number} severityBase - Base severity weight 0-1
 * @property {string} source
 */

export const PORTENT_CLASSES = {
  celestial: {
    tier: 'celestial',
    sanskrit: 'Divya Utpata',
    examples: [
      'eclipses', 'comets', 'planetary_war', 'meteor_shower',
      'sun_anomaly', 'moon_anomaly', 'star_disappearance'
    ],
    remediability: 'with_great_effort',
    remedyNote: 'Requires elaborate ceremonies, royal patronage, and sustained Vedic rituals (Ch.46 Sl.6)',
    severityBase: 0.9,
    source: 'Ch.46 Sl.1-6'
  },

  atmospheric: {
    tier: 'atmospheric',
    sanskrit: 'Antariksha Utpata',
    examples: [
      'unusual_wind', 'strange_clouds', 'dust_storm', 'thunder_anomaly',
      'halo', 'rainbow_anomaly', 'fire_in_sky', 'twilight_glow'
    ],
    remediability: 'partial',
    remedyNote: 'Moderate ceremonies can mitigate but rarely fully avert',
    severityBase: 0.7,
    source: 'Ch.46 Sl.1-6'
  },

  terrestrial: {
    tier: 'terrestrial',
    sanskrit: 'Bhauma Utpata',
    examples: [
      'earthquake', 'idol_portent', 'animal_anomaly', 'plant_anomaly',
      'fire_portent', 'water_anomaly', 'building_crack', 'spontaneous_sound'
    ],
    remediability: 'yes',
    remedyNote: 'Standard expiatory rites and propitiations are effective',
    severityBase: 0.5,
    source: 'Ch.46 Sl.1-6'
  }
};

// ─── IDOL PORTENT TARGET MAPPING (Ch.46 Slokas 10-14) ──────────────────────
// When an idol of a deity sweats, weeps, moves, etc., it portends trouble
// for a specific target. Fruition: 8 months (Sl.14).

/**
 * @typedef {Object} IdolPortent
 * @property {string} deity - Name of the deity whose idol shows portent
 * @property {string} target - Who/what is affected
 * @property {string} effect - Nature of the effect
 * @property {string} source
 */

export const IDOL_PORTENT_MAP = {
  Brahma:      { target: 'brahmins',             effect: 'Brahmins face persecution or loss of privilege', source: 'Ch.46 Sl.10' },
  Vishnu:      { target: 'kings',                effect: 'Ruling authority weakened, king endangered',     source: 'Ch.46 Sl.10' },
  Siva:        { target: 'general_public',       effect: 'Mass suffering, public calamity',                source: 'Ch.46 Sl.10' },
  Surya:       { target: 'royal_family',         effect: 'Royal lineage threatened',                      source: 'Ch.46 Sl.11' },
  Chandra:     { target: 'queens_ministers',      effect: 'Queens or chief ministers endangered',           source: 'Ch.46 Sl.11' },
  Kumara:      { target: 'army_commander',       effect: 'Commander-in-chief faces defeat or death',      source: 'Ch.46 Sl.11' },
  Indra:       { target: 'kings_and_crops',      effect: 'King dies or crops fail entirely',               source: 'Ch.46 Sl.12' },
  Varuna:      { target: 'water_dependents',     effect: 'Those dependent on water face ruin',             source: 'Ch.46 Sl.12' },
  Yama:        { target: 'disease_epidemic',     effect: 'Widespread epidemic, mass death',                source: 'Ch.46 Sl.12' },
  Vayu:        { target: 'travelers_merchants',  effect: 'Travelers and trade caravans destroyed',         source: 'Ch.46 Sl.13' },
  Kubera:      { target: 'treasury_wealth',      effect: 'Royal treasury emptied, economic collapse',      source: 'Ch.46 Sl.13' },
  Agni:        { target: 'fire_dependent',       effect: 'Goldsmiths, cooks, fire-keepers face ruin',     source: 'Ch.46 Sl.13' },
  Naga:        { target: 'subterranean_beings',  effect: 'Miners, well-diggers, underground workers suffer', source: 'Ch.46 Sl.14' }
};

export const IDOL_PORTENT_FRUITION_MONTHS = 8; // Ch.46 Sl.14

// ─── FIRE PORTENT RULES (Ch.46 Slokas 18-24) ───────────────────────────────
// Specific fire manifestations and their meanings.

/**
 * @typedef {Object} FirePortent
 * @property {string} manifestation - Where/how fire appears
 * @property {string} meaning - What it portends
 * @property {string} dir - "pos"|"neg"|"mix"
 * @property {number} weight - Severity 0-1
 * @property {string} domain - Primary domain affected
 * @property {string} source
 */

export const FIRE_PORTENTS = [
  {
    manifestation: 'fire_on_water',
    meaning: 'Death of the ruling king or head of state',
    dir: 'neg', weight: 1.0, domain: 'government',
    source: 'Ch.46 Sl.18'
  },
  {
    manifestation: 'fire_on_weapons',
    meaning: 'War is imminent, military conflict inevitable',
    dir: 'neg', weight: 0.95, domain: 'military',
    source: 'Ch.46 Sl.19'
  },
  {
    manifestation: 'fire_on_granary',
    meaning: 'Famine follows, grain stores will be destroyed',
    dir: 'neg', weight: 0.9, domain: 'agriculture',
    source: 'Ch.46 Sl.20'
  },
  {
    manifestation: 'fire_on_treasury',
    meaning: 'Economic collapse, royal treasury lost',
    dir: 'neg', weight: 0.9, domain: 'economy',
    source: 'Ch.46 Sl.20'
  },
  {
    manifestation: 'fire_on_temple',
    meaning: 'Religious persecution, faith undermined',
    dir: 'neg', weight: 0.85, domain: 'religion',
    source: 'Ch.46 Sl.21'
  },
  {
    manifestation: 'fire_on_city_gate',
    meaning: 'Enemy invasion, city will be besieged',
    dir: 'neg', weight: 0.9, domain: 'military',
    source: 'Ch.46 Sl.21'
  },
  {
    manifestation: 'fire_on_cremation_ground',
    meaning: 'Epidemic, mass death in the region',
    dir: 'neg', weight: 0.95, domain: 'health',
    source: 'Ch.46 Sl.22'
  },
  {
    manifestation: 'fire_on_forest',
    meaning: 'Destruction of wildlife and forest resources',
    dir: 'neg', weight: 0.7, domain: 'environment',
    source: 'Ch.46 Sl.22'
  },
  {
    manifestation: 'fire_spontaneous_extinction',
    meaning: 'If sacred fire dies without cause, kingdom declines',
    dir: 'neg', weight: 0.85, domain: 'government',
    source: 'Ch.46 Sl.23'
  },
  {
    manifestation: 'fire_blue_flame',
    meaning: 'Danger from water — floods or naval attack',
    dir: 'neg', weight: 0.8, domain: 'disaster',
    source: 'Ch.46 Sl.24'
  },
  {
    manifestation: 'fire_pleasant_fragrance',
    meaning: 'Auspicious — prosperity and good fortune',
    dir: 'pos', weight: 0.8, domain: 'public_mood',
    source: 'Ch.46 Sl.24'
  }
];

// ─── PORTENT TYPE → TIER LOOKUP ─────────────────────────────────────────────

const PORTENT_TYPE_TO_TIER = {};
for (const [tier, data] of Object.entries(PORTENT_CLASSES)) {
  for (const example of data.examples) {
    PORTENT_TYPE_TO_TIER[example] = tier;
  }
}

// ─── NAKSHATRA → CIRCLE LOOKUP ──────────────────────────────────────────────

const NAKSHATRA_TO_CIRCLE = {};
for (const [circleName, circle] of Object.entries(EARTHQUAKE_CIRCLES)) {
  for (const nak of circle.nakshatras) {
    NAKSHATRA_TO_CIRCLE[nak] = circleName;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXPORTED FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Evaluate an earthquake based on the Moon's nakshatra at the time of the event.
 *
 * Returns an array of Effect objects describing the circle's consequences,
 * affected regions, timing, and any cancellation or combination effects
 * if a second circle is active.
 *
 * @param {string} nakshatraAtTime - Nakshatra the Moon occupies when the earthquake occurs
 * @param {string} [timeOfDay='day'] - "day"|"night" (currently reserved for future use)
 * @param {Object} [options={}]
 * @param {string} [options.secondNakshatra] - If a second earthquake occurred, its Moon nakshatra
 * @param {number} [options.daysSinceLast] - Days since last earthquake (for repeat rule)
 * @returns {Object} { circle, effects: Effect[], cancelled: boolean, combination: Object|null, repeatWarning: boolean }
 */
export function evaluateEarthquake(nakshatraAtTime, timeOfDay = 'day', options = {}) {
  const circleName = NAKSHATRA_TO_CIRCLE[nakshatraAtTime];

  if (!circleName) {
    return {
      circle: null,
      effects: [],
      cancelled: false,
      combination: null,
      repeatWarning: false,
      note: `Nakshatra "${nakshatraAtTime}" not found in any earthquake circle`
    };
  }

  const circle = EARTHQUAKE_CIRCLES[circleName];
  const effects = [];

  // Generate primary effects for this circle
  for (const effectDesc of circle.effects) {
    const isDesirable = effectDesc.toLowerCase().includes('but') ||
                        effectDesc.toLowerCase().includes('desirable') ||
                        effectDesc.toLowerCase().includes('peace');
    effects.push({
      domain: _inferDomain(effectDesc),
      dir: isDesirable ? 'mix' : 'neg',
      desc: effectDesc,
      weight: isDesirable ? 0.5 : 0.75,
      planet: 'Moon',
      sign: null,
      ruleId: `bhukampa_${circleName.toLowerCase()}`,
      source: circle.source,
      category: 'earthquake',
      manifestation: `${circle.element} circle earthquake — Moon in ${nakshatraAtTime}`
    });
  }

  // Add region-targeting effect
  effects.push({
    domain: 'geography',
    dir: 'neg',
    desc: `Regions affected: ${circle.regions.join(', ')}. Area: ${circle.areaYojanas} yojanas. Effects last ${circle.timing}.`,
    weight: 0.7,
    planet: 'Moon',
    sign: null,
    ruleId: `bhukampa_${circleName.toLowerCase()}_region`,
    source: circle.source,
    category: 'earthquake',
    manifestation: `${circle.element} circle geographic scope`
  });

  let cancelled = false;
  let combination = null;

  // Check for second circle interaction
  if (options.secondNakshatra) {
    const secondCircleName = NAKSHATRA_TO_CIRCLE[options.secondNakshatra];
    if (secondCircleName && secondCircleName !== circleName) {
      // Check cancellation pairs (Sl.27)
      const isCancelled = CANCELLATION_PAIRS.some(
        pair => (pair.a === circleName && pair.b === secondCircleName) ||
                (pair.b === circleName && pair.a === secondCircleName)
      );

      if (isCancelled) {
        cancelled = true;
        effects.length = 0;
        effects.push({
          domain: 'general',
          dir: 'mix',
          desc: `${circleName} and ${secondCircleName} circles cancel each other — effects neutralized (Sl.27)`,
          weight: 0.1,
          planet: 'Moon',
          sign: null,
          ruleId: 'bhukampa_cancellation',
          source: 'Ch.32 Sl.27',
          category: 'earthquake',
          manifestation: 'Circle cancellation'
        });
      }

      // Check combination effects (Sl.28-29)
      const combo = CIRCLE_COMBINATIONS.find(
        c => c.circle1 === circleName && c.circle2 === secondCircleName
      );
      if (combo && !isCancelled) {
        combination = combo;
        effects.push({
          domain: combo.dir === 'pos' ? 'agriculture' : 'government',
          dir: combo.dir,
          desc: combo.effect,
          weight: combo.weight,
          planet: 'Moon',
          sign: null,
          ruleId: `bhukampa_combo_${circleName.toLowerCase()}_${secondCircleName.toLowerCase()}`,
          source: combo.source,
          category: 'earthquake',
          manifestation: `${circleName}+${secondCircleName} combination`
        });
      }
    }
  }

  // Check repeat earthquake rule (Sl.32)
  let repeatWarning = false;
  if (options.daysSinceLast != null &&
      REPEAT_QUAKE_CRITICAL_DAYS.includes(options.daysSinceLast)) {
    repeatWarning = true;
    effects.push({
      domain: 'government',
      dir: 'neg',
      desc: `Earthquake repeated on the ${options.daysSinceLast}${_ordinal(options.daysSinceLast)} day — prominent kings and rulers will be destroyed`,
      weight: 1.0,
      planet: 'Moon',
      sign: null,
      ruleId: 'bhukampa_repeat_critical',
      source: 'Ch.32 Sl.32',
      category: 'earthquake',
      manifestation: `Repeat earthquake on critical day ${options.daysSinceLast}`
    });
  }

  return {
    circle: circleName,
    circleData: circle,
    effects,
    cancelled,
    combination,
    repeatWarning
  };
}

/**
 * Classify a portent into its 3-tier category and return remediability info.
 *
 * @param {string} portentType - One of the portent type strings from PORTENT_CLASSES examples
 * @returns {Object} { tier, sanskrit, remediability, remedyNote, severityBase, source, firePortent: FirePortent|null }
 */
export function classifyPortent(portentType) {
  const tier = PORTENT_TYPE_TO_TIER[portentType];

  if (!tier) {
    // Check if it is a fire portent manifestation
    const firePt = FIRE_PORTENTS.find(fp => fp.manifestation === portentType);
    if (firePt) {
      const terrestrial = PORTENT_CLASSES.terrestrial;
      return {
        tier: 'terrestrial',
        sanskrit: terrestrial.sanskrit,
        remediability: terrestrial.remediability,
        remedyNote: terrestrial.remedyNote,
        severityBase: terrestrial.severityBase,
        source: firePt.source,
        firePortent: firePt,
        effect: {
          domain: firePt.domain,
          dir: firePt.dir,
          desc: firePt.meaning,
          weight: firePt.weight,
          planet: null,
          sign: null,
          ruleId: `utpata_fire_${portentType}`,
          source: firePt.source,
          category: 'portent',
          manifestation: portentType
        }
      };
    }

    return {
      tier: null,
      sanskrit: null,
      remediability: null,
      remedyNote: null,
      severityBase: 0,
      source: null,
      firePortent: null,
      effect: null,
      note: `Portent type "${portentType}" not found in classification`
    };
  }

  const data = PORTENT_CLASSES[tier];
  return {
    tier: data.tier,
    sanskrit: data.sanskrit,
    remediability: data.remediability,
    remedyNote: data.remedyNote,
    severityBase: data.severityBase,
    source: data.source,
    firePortent: null,
    effect: {
      domain: 'general',
      dir: 'neg',
      desc: `${data.sanskrit} portent observed: ${portentType}. Remediability: ${data.remediability}.`,
      weight: data.severityBase,
      planet: null,
      sign: null,
      ruleId: `utpata_${tier}_${portentType}`,
      source: data.source,
      category: 'portent',
      manifestation: portentType
    }
  };
}

/**
 * Get the target and effect of an idol portent for a specific deity.
 *
 * Idol portents (sweating, weeping, moving, bleeding idols) ripen in 8 months.
 *
 * @param {string} deity - Name of the deity (e.g. "Vishnu", "Indra", "Yama")
 * @returns {Object} { deity, target, effect, fruitionMonths, source, effectObj: Effect }
 */
export function getIdolPortentTarget(deity) {
  const entry = IDOL_PORTENT_MAP[deity];

  if (!entry) {
    return {
      deity,
      target: null,
      effect: null,
      fruitionMonths: null,
      source: null,
      effectObj: null,
      note: `Deity "${deity}" not found in idol portent mapping`
    };
  }

  return {
    deity,
    target: entry.target,
    effect: entry.effect,
    fruitionMonths: IDOL_PORTENT_FRUITION_MONTHS,
    source: entry.source,
    effectObj: {
      domain: _targetToDomain(entry.target),
      dir: 'neg',
      desc: `Idol of ${deity} shows portent — ${entry.effect}. Ripens in ${IDOL_PORTENT_FRUITION_MONTHS} months.`,
      weight: 0.8,
      planet: null,
      sign: null,
      ruleId: `utpata_idol_${deity.toLowerCase()}`,
      source: entry.source,
      category: 'portent',
      manifestation: `Idol portent of ${deity}`
    }
  };
}

// ─── INTERNAL HELPERS ───────────────────────────────────────────────────────

/**
 * Infer a domain string from an effect description.
 * @param {string} desc
 * @returns {string}
 * @private
 */
function _inferDomain(desc) {
  const lower = desc.toLowerCase();
  if (lower.includes('crop') || lower.includes('forest') || lower.includes('water source') || lower.includes('lake'))
    return 'agriculture';
  if (lower.includes('disease') || lower.includes('asthma') || lower.includes('fever') ||
      lower.includes('herpes') || lower.includes('jaundice') || lower.includes('dysentery') ||
      lower.includes('epidemic'))
    return 'health';
  if (lower.includes('trading') || lower.includes('merchant'))
    return 'economy';
  if (lower.includes('king') || lower.includes('ruler') || lower.includes('corporation') || lower.includes('famil'))
    return 'government';
  if (lower.includes('rain') || lower.includes('flood'))
    return 'weather';
  if (lower.includes('peace') || lower.includes('hatred'))
    return 'public_mood';
  if (lower.includes('sea') || lower.includes('river') || lower.includes('fish') || lower.includes('sailor'))
    return 'maritime';
  if (lower.includes('cloud'))
    return 'weather';
  return 'general';
}

/**
 * Map an idol target category to a domain string.
 * @param {string} target
 * @returns {string}
 * @private
 */
function _targetToDomain(target) {
  const map = {
    brahmins: 'religion',
    kings: 'government',
    general_public: 'public_mood',
    royal_family: 'government',
    queens_ministers: 'government',
    army_commander: 'military',
    kings_and_crops: 'agriculture',
    water_dependents: 'maritime',
    disease_epidemic: 'health',
    travelers_merchants: 'economy',
    treasury_wealth: 'economy',
    fire_dependent: 'economy',
    subterranean_beings: 'resources'
  };
  return map[target] || 'general';
}

/**
 * Return ordinal suffix for a number.
 * @param {number} n
 * @returns {string}
 * @private
 */
function _ordinal(n) {
  if (n === 3) return 'rd';
  if (n === 4 || n === 7) return 'th';
  return 'th';
}
