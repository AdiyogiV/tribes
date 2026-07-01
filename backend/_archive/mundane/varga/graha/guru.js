/**
 * गुरु (बृहस्पतिचार) — Jupiter's Transit Effects
 * Source: Brihat Samhita, Chapter 8 (Brihaspati-chara)
 *
 * Jupiter governs the 60-YEAR DETERMINISTIC CYCLE (Samvatsara),
 * monthly-year system, transit speed, direction, color, body-mapping,
 * and 5-year lustrum rain lords.
 *
 * The 60-year cycle is THE master clock of Vedic mundane astrology.
 * Each year carries a predetermined quality from the text.
 *
 * Key references:
 *   Slokas 1-2:   Jupiter's general signification
 *   Slokas 3-14:  Monthly-year effects (Kartika through Aswayuja)
 *   Sloka 15:     Directional rule (northern/southern/middle course)
 *   Sloka 16:     Transit speed rule (nakshatras per year)
 *   Slokas 17-18: Color rules (6 colors)
 *   Sloka 19:     Samvatsarapurusha body mapping
 *   Slokas 20-22: Saka era formula for cycle calculation
 *   Slokas 24-25: 5-year lustrum rain lords
 *   Sloka 26:     Yuga classification (best/medium/worst)
 *   Slokas 27-52: Complete 60-year cycle with named years and effects
 */

// ─── 60-YEAR SAMVATSARA CYCLE ───────────────────────────────────────────────
// BS Ch.8 Slokas 27-52
//
// The 60 years are grouped into 12 Yugas of 5 years each.
// Sloka 26 classifies Yugas:
//   Yugas 1,2,3 (Vishnu, Brihaspati, Indra)     = BEST
//   Yugas 4,5,6 (Agni, Twashta, Ahirbudhnya)    = MEDIUM
//   Yugas 7,8,9 (Manes, Viswedeva, Moon)         = MEDIUM
//   Yugas 10,11,12 (Indragni, Aswins, Bhaga)     = WORST

/** @typedef {'best'|'medium'|'worst'} YugaQuality */

/**
 * @typedef {Object} SamvatsaraYear
 * @property {number} index - 0-59 position in the cycle
 * @property {string} name - Sanskrit name of the year
 * @property {number} yuga - Yuga number (1-12)
 * @property {string} yugaLord - Deity presiding over this yuga
 * @property {YugaQuality} yugaQuality - best/medium/worst from Sl.26
 * @property {string} effect - Classical effect description
 * @property {string} dir - "pos"|"neg"|"mix"
 * @property {number} weight - 0-1 effect intensity
 * @property {string} domains - Primary domain affected
 */

const YUGA_LORDS = [
  'Vishnu', 'Brihaspati', 'Indra', 'Agni', 'Twashta', 'Ahirbudhnya',
  'Manes', 'Viswedeva', 'Moon', 'Indragni', 'Aswins', 'Bhaga'
];

const YUGA_QUALITY = [
  'best', 'best', 'best',       // 1-3
  'medium', 'medium', 'medium', // 4-6
  'medium', 'medium', 'medium', // 7-9
  'worst', 'worst', 'worst'     // 10-12
];

/**
 * Complete 60-year cycle. BS Ch.8 Slokas 27-52.
 * Each entry: [name, effect description, direction (pos/neg/mix), weight, primary domain]
 */
const SAMVATSARA_DATA = [
  // ── Yuga 1: Vishnu (BEST) ── Slokas 27-28
  ['Prabhava',    'People happy, crops abundant, rulers righteous',                    'pos', 0.9, 'agriculture'],
  ['Vibhava',     'Prosperity in trade, wealth increases, learning flourishes',        'pos', 0.85, 'economy'],
  ['Sukla',       'White objects auspicious, brahmins honored, religious ceremonies',   'pos', 0.8, 'religion'],
  ['Pramoda',     'Joy pervades, festivals celebrated, cattle thrive',                 'pos', 0.85, 'public_mood'],
  ['Prajapati',   'Progeny increases, marriages auspicious, kings victorious',         'pos', 0.9, 'government'],

  // ── Yuga 2: Brihaspati (BEST) ── Slokas 29-30
  ['Angiras',     'Vedic learning prospers, sacrifices performed, sages honored',      'pos', 0.85, 'education'],
  ['Srimukha',    'Beautiful faces, auspicious omens, prosperity all around',          'pos', 0.9, 'public_mood'],
  ['Bhava',       'Creation thrives, new enterprises succeed, births increase',        'pos', 0.8, 'economy'],
  ['Yuva',        'Youth empowered, valor displayed, military success',                'pos', 0.8, 'military'],
  ['Dhatu',       'Minerals discovered, metals abundant, mining prospers',             'pos', 0.75, 'resources'],

  // ── Yuga 3: Indra (BEST) ── Slokas 31-32
  ['Easwara',     'Kings powerful, divine favor, rains plentiful',                     'pos', 0.9, 'government'],
  ['Bahudhanya',  'Abundant grain, excellent harvests, food prices low',               'pos', 0.95, 'agriculture'],
  ['Pramatthin',  'Churning of circumstances, obstacles overcome, reform succeeds',    'mix', 0.7, 'government'],
  ['Vikrama',     'Valor and courage displayed, military victories, heroes arise',     'pos', 0.85, 'military'],
  ['Vrisha',      'Good rains, bulls strong, agriculture prospers',                    'pos', 0.85, 'agriculture'],

  // ── Yuga 4: Agni (MEDIUM) ── Slokas 33-34
  ['Chitrabhanu', 'Mixed fortunes, fire-related events, some prosperity',              'mix', 0.6, 'crisis'],
  ['Subhanu',     'Moderate prosperity, rays of hope amidst difficulties',             'mix', 0.6, 'economy'],
  ['Tharana',     'People endure hardships, crossing difficulties, slow recovery',     'mix', 0.55, 'public_mood'],
  ['Parthiva',    'Earthly matters dominate, territorial disputes, land reforms',      'mix', 0.6, 'government'],
  ['Vyaya',       'Expenditure exceeds income, waste, extravagance by rulers',         'neg', 0.65, 'economy'],

  // ── Yuga 5: Twashta (MEDIUM) ── Slokas 35-36
  ['Sarvajit',    'Conquerors arise, some victories but at great cost',                'mix', 0.6, 'military'],
  ['Sarvadhari',  'All-bearing year, people endure, moderate harvests',                'mix', 0.55, 'agriculture'],
  ['Virodhin',    'Opposition and conflicts increase, political strife',               'neg', 0.65, 'government'],
  ['Vikrita',     'Deformities, abnormal events, natural anomalies',                   'neg', 0.7, 'health'],
  ['Khara',       'Harshness prevails, drought possible, rough conditions',            'neg', 0.7, 'agriculture'],

  // ── Yuga 6: Ahirbudhnya (MEDIUM) ── Slokas 37-38
  ['Nandana',     'Some joy returns, gardens flourish, moderate happiness',            'mix', 0.6, 'public_mood'],
  ['Vijaya',      'Victory in some endeavors, partial success for kings',              'mix', 0.65, 'military'],
  ['Jaya',        'Triumph of the righteous, dharma upheld in parts',                  'pos', 0.7, 'religion'],
  ['Manmatha',    'Desire and passion dominate, romantic affairs, luxury goods trade',  'mix', 0.6, 'trade'],
  ['Durmukha',    'Bad-faced year: famine threatens, ugly disputes, rulers disgraced', 'neg', 0.75, 'crisis'],

  // ── Yuga 7: Manes (MEDIUM) ── Slokas 39-40
  ['Hemalamba',   'Gold loses value, partial prosperity, ancestral rites important',   'mix', 0.55, 'economy'],
  ['Vilambi',     'Delays in all matters, slow progress, tardy justice',               'neg', 0.6, 'judiciary'],
  ['Vikari',      'Transformations and upheavals, social changes, unrest',             'neg', 0.65, 'public_mood'],
  ['Sarvari',     'Darkness prevails, night-fears, thefts increase, anxiety',          'neg', 0.7, 'crisis'],
  ['Plava',       'Floods and water-disasters, floating instability, travel disrupted','neg', 0.7, 'crisis'],

  // ── Yuga 8: Viswedeva (MEDIUM) ── Slokas 41-42
  ['Sobhakrit',   'Some splendor returns, beautiful events, arts briefly flourish',    'mix', 0.6, 'culture'],
  ['Subhakrit',   'Auspicious deeds bear fruit, good karma manifests partially',       'pos', 0.65, 'religion'],
  ['Krodhi',      'Anger pervades, violent conflicts, rulers wrathful',                'neg', 0.75, 'military'],
  ['Viswavasu',   'Universal wealth partially, some regions prosper while others decline','mix', 0.55, 'economy'],
  ['Parabhava',   'Defeat and humiliation, armies routed, kings overthrown',           'neg', 0.8, 'government'],

  // ── Yuga 9: Moon (MEDIUM) ── Slokas 43-44
  ['Plavanga',    'Monkeys and pests trouble crops, agricultural damage',              'neg', 0.65, 'agriculture'],
  ['Keelaka',     'Obstruction and impediments, projects stalled, bureaucracy',        'neg', 0.65, 'government'],
  ['Saumya',      'Gentleness returns briefly, Moon-like calm, some relief',           'mix', 0.6, 'public_mood'],
  ['Sadharana',   'Ordinary year, neither good nor bad, mediocrity prevails',          'mix', 0.5, 'economy'],
  ['Rodhakrit',   'Obstructions multiply, sieges and blockades, trade routes blocked', 'neg', 0.7, 'trade'],

  // ── Yuga 10: Indragni (WORST) ── Slokas 45-46
  ['Paridhavi',   'Surrounded by troubles, besieged on all sides, no escape',          'neg', 0.8, 'crisis'],
  ['Pramadi',     'Negligence causes disaster, carelessness in governance',            'neg', 0.75, 'government'],
  ['Ananda',      'Brief false joy, deceptive prosperity that collapses',              'neg', 0.7, 'economy'],
  ['Rakshasa',    'Demonic forces dominate, cruelty, violence, oppression',            'neg', 0.9, 'crisis'],
  ['Anala',       'Fire disasters, conflagrations, scorching heat, drought',           'neg', 0.85, 'crisis'],

  // ── Yuga 11: Aswins (WORST) ── Slokas 47-48
  ['Pingala',     'Tawny skies, drought, famine, diseases spread',                    'neg', 0.8, 'health'],
  ['Kalayukta',   'Time of reckoning, debts called in, karma ripens harshly',         'neg', 0.8, 'economy'],
  ['Siddhartha',  'Some accomplishment amidst turmoil, partial success',              'mix', 0.55, 'government'],
  ['Raudra',      'Terrible storms, violence, destruction, war',                       'neg', 0.9, 'military'],
  ['Durmati',     'Evil counsel prevails, bad decisions, foolish rulers',              'neg', 0.85, 'government'],

  // ── Yuga 12: Bhaga (WORST) ── Slokas 49-52
  ['Dundubhi',    'War drums sound, military mobilization, conflicts erupt',           'neg', 0.8, 'military'],
  ['Udgari',      'Eruptions — volcanic or social, upheaval, rebellion',               'neg', 0.85, 'crisis'],
  ['Raktaksha',   'Red-eyed year: bloodshed, epidemics, eyes afflicted',              'neg', 0.9, 'health'],
  ['Krodha',      'Wrath unleashed, major wars, destruction of cities',                'neg', 0.9, 'military'],
  ['Kshaya',      'Decay and dissolution, end of an era, complete exhaustion',         'neg', 0.95, 'crisis'],
];

/**
 * Full 60-year cycle with computed metadata.
 * @type {SamvatsaraYear[]}
 */
export const SAMVATSARA_CYCLE = SAMVATSARA_DATA.map(([name, effect, dir, weight, domains], i) => ({
  index: i,
  name,
  yuga: Math.floor(i / 5) + 1,
  yugaLord: YUGA_LORDS[Math.floor(i / 5)],
  yugaQuality: YUGA_QUALITY[Math.floor(i / 5)],
  effect,
  dir,
  weight,
  domains
}));

/** Quick lookup by year name */
export const SAMVATSARA_BY_NAME = Object.fromEntries(
  SAMVATSARA_CYCLE.map(y => [y.name, y])
);

// ─── 12 MONTHLY-YEAR EFFECTS ────────────────────────────────────────────────
// BS Ch.8 Slokas 3-14
// When Jupiter rises heliacally in a given month, that determines the
// character of the ensuing year. Month = lunar month of heliacal rising.

export const MONTHLY_YEAR_EFFECTS = {
  Kartika: {
    desc: 'Jupiter rises in Kartika: excellent crops, kings happy, people prosperous',
    dir: 'pos', weight: 0.9,
    domains: ['agriculture', 'government', 'public_mood'],
    source: 'BS Ch.8 Sl.3'
  },
  Margasira: {
    desc: 'Jupiter rises in Margasira: good rains, abundance of food, prosperity',
    dir: 'pos', weight: 0.85,
    domains: ['agriculture', 'economy'],
    source: 'BS Ch.8 Sl.4'
  },
  Pushya: {
    desc: 'Jupiter rises in Pushya: moderate prosperity, some fear from kings',
    dir: 'mix', weight: 0.6,
    domains: ['government', 'economy'],
    source: 'BS Ch.8 Sl.5'
  },
  Magha: {
    desc: 'Jupiter rises in Magha: fear of famine, cattle suffer, some diseases',
    dir: 'neg', weight: 0.7,
    domains: ['agriculture', 'health'],
    source: 'BS Ch.8 Sl.6'
  },
  Phalguna: {
    desc: 'Jupiter rises in Phalguna: mixed results, some good some evil, moderate rains',
    dir: 'mix', weight: 0.55,
    domains: ['agriculture', 'public_mood'],
    source: 'BS Ch.8 Sl.7'
  },
  Chaitra: {
    desc: 'Jupiter rises in Chaitra: fear from robbers, scanty rain, crops suffer',
    dir: 'neg', weight: 0.7,
    domains: ['agriculture', 'crisis'],
    source: 'BS Ch.8 Sl.8'
  },
  Vaisakha: {
    desc: 'Jupiter rises in Vaisakha: good harvests, happiness, religious activities thrive',
    dir: 'pos', weight: 0.8,
    domains: ['agriculture', 'religion', 'public_mood'],
    source: 'BS Ch.8 Sl.9'
  },
  Jyeshta: {
    desc: 'Jupiter rises in Jyeshta: winds destructive, crops damaged, cattle diseased',
    dir: 'neg', weight: 0.75,
    domains: ['agriculture', 'health'],
    source: 'BS Ch.8 Sl.10'
  },
  Ashadha: {
    desc: 'Jupiter rises in Ashadha: excessive rains, floods, destruction of crops',
    dir: 'neg', weight: 0.7,
    domains: ['agriculture', 'crisis'],
    source: 'BS Ch.8 Sl.11'
  },
  Sravana: {
    desc: 'Jupiter rises in Sravana: excellent rains, abundant harvests, joy',
    dir: 'pos', weight: 0.85,
    domains: ['agriculture', 'public_mood'],
    source: 'BS Ch.8 Sl.12'
  },
  Bhadrapada: {
    desc: 'Jupiter rises in Bhadrapada: moderate conditions, some fear, average crops',
    dir: 'mix', weight: 0.55,
    domains: ['agriculture', 'public_mood'],
    source: 'BS Ch.8 Sl.13'
  },
  Aswayuja: {
    desc: 'Jupiter rises in Aswayuja: famine, drought, rulers quarrel, diseases',
    dir: 'neg', weight: 0.8,
    domains: ['agriculture', 'government', 'health'],
    source: 'BS Ch.8 Sl.14'
  }
};

// ─── TRANSIT SPEED RULE ─────────────────────────────────────────────────────
// BS Ch.8 Sloka 16
// Jupiter's speed measured in nakshatras traversed per year.

export const TRANSIT_SPEED_RULES = [
  {
    maxNakPerYear: 2.0,
    label: 'slow',
    desc: 'Jupiter traverses 2 nakshatras/year or less: beneficent, crops prosper, people happy',
    dir: 'pos', weight: 0.8,
    source: 'BS Ch.8 Sl.16'
  },
  {
    maxNakPerYear: 2.5,
    label: 'normal',
    desc: 'Jupiter traverses about 2.5 nakshatras/year: moderate results, neither great nor terrible',
    dir: 'mix', weight: 0.5,
    source: 'BS Ch.8 Sl.16'
  },
  {
    maxNakPerYear: Infinity,
    label: 'fast',
    desc: 'Jupiter traverses more than 2.5 nakshatras/year: destroys crops, famine, misery',
    dir: 'neg', weight: 0.8,
    source: 'BS Ch.8 Sl.16'
  }
];

// ─── DIRECTIONAL RULE ───────────────────────────────────────────────────────
// BS Ch.8 Sloka 15
// Jupiter's course: northern = uttarayana, southern = dakshinayana

export const DIRECTIONAL_RULES = {
  northern: {
    desc: 'Jupiter on northern course (uttarayana): auspicious, prosperity, good rains, kings virtuous',
    dir: 'pos', weight: 0.7,
    source: 'BS Ch.8 Sl.15'
  },
  southern: {
    desc: 'Jupiter on southern course (dakshinayana): inauspicious, famine, disease, rulers oppressive',
    dir: 'neg', weight: 0.7,
    source: 'BS Ch.8 Sl.15'
  },
  middle: {
    desc: 'Jupiter at equinoctial crossing: mixed results, partial good and partial evil',
    dir: 'mix', weight: 0.5,
    source: 'BS Ch.8 Sl.15'
  }
};

// ─── COLOR RULES ────────────────────────────────────────────────────────────
// BS Ch.8 Slokas 17-18
// Jupiter's observed color indicates specific effects.

export const JUPITER_COLORS = {
  white: {
    desc: 'Jupiter appears white: happiness, abundant crops, prosperity',
    dir: 'pos', weight: 0.8,
    domains: ['agriculture', 'public_mood'],
    source: 'BS Ch.8 Sl.17'
  },
  yellow: {
    desc: 'Jupiter appears yellow (natural): normal prosperity, moderate rains',
    dir: 'pos', weight: 0.7,
    domains: ['agriculture', 'economy'],
    source: 'BS Ch.8 Sl.17'
  },
  red: {
    desc: 'Jupiter appears red: fear, war, fire disasters, kings quarrel',
    dir: 'neg', weight: 0.8,
    domains: ['military', 'crisis'],
    source: 'BS Ch.8 Sl.17'
  },
  tawny: {
    desc: 'Jupiter appears tawny/brown: famine, diseases, cattle die',
    dir: 'neg', weight: 0.75,
    domains: ['agriculture', 'health'],
    source: 'BS Ch.8 Sl.18'
  },
  variegated: {
    desc: 'Jupiter appears variegated/multi-hued: mixed results, some regions prosper, some suffer',
    dir: 'mix', weight: 0.6,
    domains: ['economy', 'public_mood'],
    source: 'BS Ch.8 Sl.18'
  },
  dark: {
    desc: 'Jupiter appears dark/smoky: destruction, death, rulers overthrown, extreme misery',
    dir: 'neg', weight: 0.9,
    domains: ['crisis', 'government', 'health'],
    source: 'BS Ch.8 Sl.18'
  }
};

// ─── SAMVATSARAPURUSHA BODY MAPPING ─────────────────────────────────────────
// BS Ch.8 Sloka 19
// Nakshatras grouped into body parts of the cosmic "year person."
// Affliction (Saturn/Mars/eclipse) in a group → that body part of the
// nation/polity suffers.

export const SAMVATSARA_PURUSHA = [
  {
    bodyPart: 'head',
    nakshatras: ['Krittika', 'Rohini', 'Mrigasira'],
    afflictionEffect: 'Rulers and leadership suffer, head of state in danger',
    domain: 'government'
  },
  {
    bodyPart: 'face',
    nakshatras: ['Ardra', 'Punarvasu', 'Pushya'],
    afflictionEffect: 'Public image of nation tarnished, diplomacy fails',
    domain: 'diplomacy'
  },
  {
    bodyPart: 'chest',
    nakshatras: ['Aslesha', 'Magha', 'Purvaphalguni'],
    afflictionEffect: 'Heart of the economy affected, treasury depleted',
    domain: 'economy'
  },
  {
    bodyPart: 'right_arm',
    nakshatras: ['Uttaraphalguni', 'Hasta', 'Chitra'],
    afflictionEffect: 'Military strength weakened, defense compromised',
    domain: 'military'
  },
  {
    bodyPart: 'left_arm',
    nakshatras: ['Swati', 'Visakha', 'Anuradha'],
    afflictionEffect: 'Trade and commerce disrupted, partnerships break',
    domain: 'trade'
  },
  {
    bodyPart: 'stomach',
    nakshatras: ['Jyeshta', 'Moola', 'Purvashadha'],
    afflictionEffect: 'Agriculture and food supply threatened, hunger rises',
    domain: 'agriculture'
  },
  {
    bodyPart: 'navel',
    nakshatras: ['Uttarashadha', 'Sravana', 'Dhanishta'],
    afflictionEffect: 'Core infrastructure damaged, transport disrupted',
    domain: 'infrastructure'
  },
  {
    bodyPart: 'groin',
    nakshatras: ['Satabhishak', 'Purvabhadra', 'Uttarabhadra'],
    afflictionEffect: 'Population growth issues, reproductive health, migration',
    domain: 'health'
  },
  {
    bodyPart: 'feet',
    nakshatras: ['Revati', 'Aswini', 'Bharani'],
    afflictionEffect: 'Common people suffer, laborers oppressed, movement restricted',
    domain: 'labor'
  }
];

// ─── 5-YEAR LUSTRUM RAIN LORDS ──────────────────────────────────────────────
// BS Ch.8 Slokas 24-25
// Within each 5-year yuga, each year has a rain lord.
// Position 1-5 within the yuga → rain quality.

export const LUSTRUM_RAIN_LORDS = [
  {
    position: 1,
    lord: 'Agni',
    rainQuality: 'Moderate rain at the beginning, fire-related issues',
    dir: 'mix', weight: 0.55,
    source: 'BS Ch.8 Sl.24'
  },
  {
    position: 2,
    lord: 'Vayu',
    rainQuality: 'Wind-driven rains, storms possible, uneven distribution',
    dir: 'mix', weight: 0.6,
    source: 'BS Ch.8 Sl.24'
  },
  {
    position: 3,
    lord: 'Indra',
    rainQuality: 'Excellent rains, Indra as lord ensures bountiful water',
    dir: 'pos', weight: 0.85,
    source: 'BS Ch.8 Sl.24'
  },
  {
    position: 4,
    lord: 'Kubera',
    rainQuality: 'Wealth-bringing rains, crops prosper, economic benefit from water',
    dir: 'pos', weight: 0.8,
    source: 'BS Ch.8 Sl.25'
  },
  {
    position: 5,
    lord: 'Brahma',
    rainQuality: 'Creative rains, new beginnings, cycle completing',
    dir: 'pos', weight: 0.75,
    source: 'BS Ch.8 Sl.25'
  }
];

// ─── SAKA ERA FORMULA ───────────────────────────────────────────────────────
// BS Ch.8 Slokas 20-22
//
// To find the current Samvatsara from a date:
//   1. Compute Saka year = Gregorian year - 78 (for dates after March)
//      or Gregorian year - 79 (for dates before March)
//   2. Add 12 to the Saka year
//   3. Divide by 60; the remainder gives the Samvatsara index (0-59)
//
// The +12 offset aligns the cycle with Varahamihira's epoch (Prabhava year).

/**
 * Calculate the current Jupiter year (Samvatsara) for a given date.
 *
 * Uses the Saka era formula from BS Ch.8 Slokas 20-22.
 * The Saka era begins in 78 CE. The 60-year cycle offset of +12
 * aligns Prabhava (year 0) with the traditional epoch.
 *
 * @param {Date|string} date - JavaScript Date or ISO string
 * @returns {{
 *   samvatsara: SamvatsaraYear,
 *   sakaYear: number,
 *   cycleNumber: number,
 *   positionInYuga: number,
 *   lustrumLord: Object,
 *   yugaInfo: { number: number, lord: string, quality: YugaQuality }
 * }}
 */
export function getJupiterYear(date) {
  const d = (typeof date === 'string') ? new Date(date) : date;
  const year = d.getFullYear();
  const month = d.getMonth(); // 0-indexed

  // Saka year: the Hindu new year (Chaitra) is roughly mid-March
  // If before mid-March, still previous Saka year
  const sakaYear = month >= 2 ? year - 78 : year - 79;

  // Apply the +12 offset per Varahamihira's instruction
  const adjusted = sakaYear + 12;

  // Cycle number and index
  const cycleNumber = Math.floor(adjusted / 60) + 1;
  const index = ((adjusted % 60) + 60) % 60; // ensure positive

  const samvatsara = SAMVATSARA_CYCLE[index];

  // Position within the 5-year lustrum (1-5)
  const positionInYuga = (index % 5) + 1;
  const lustrumLord = LUSTRUM_RAIN_LORDS[positionInYuga - 1];

  const yugaNumber = Math.floor(index / 5) + 1;

  return {
    samvatsara,
    sakaYear,
    cycleNumber,
    positionInYuga,
    lustrumLord,
    yugaInfo: {
      number: yugaNumber,
      lord: YUGA_LORDS[yugaNumber - 1],
      quality: YUGA_QUALITY[yugaNumber - 1]
    }
  };
}

/**
 * Get the effect data for a named Jupiter year.
 *
 * @param {string} yearName - Sanskrit name (e.g., "Prabhava", "Vibhava")
 * @returns {SamvatsaraYear|null}
 */
export function getJupiterYearEffect(yearName) {
  return SAMVATSARA_BY_NAME[yearName] || null;
}

// ─── HELPER: TRANSIT SPEED EVALUATION ───────────────────────────────────────

/**
 * Evaluate Jupiter's transit speed effect.
 * @param {number} nakPerYear - Nakshatras traversed per year
 * @returns {Object} Matching speed rule
 */
function evaluateTransitSpeed(nakPerYear) {
  for (const rule of TRANSIT_SPEED_RULES) {
    if (nakPerYear <= rule.maxNakPerYear) {
      return rule;
    }
  }
  return TRANSIT_SPEED_RULES[2]; // fallback to fast
}

/**
 * Determine Jupiter's directional course from declination.
 * @param {number|undefined} declination - Jupiter's declination in degrees
 * @returns {'northern'|'southern'|'middle'}
 */
function getJupiterCourse(declination) {
  if (declination === undefined || declination === null) return 'middle';
  if (declination > 2) return 'northern';
  if (declination < -2) return 'southern';
  return 'middle';
}

/**
 * Find body-part affliction from Samvatsarapurusha mapping.
 * @param {Object} skyState - Current sky positions
 * @returns {Object[]} Afflicted body-part effects
 */
function evaluatePurushaAffliction(skyState) {
  const effects = [];
  const positions = skyState?.positions || {};

  for (const mapping of SAMVATSARA_PURUSHA) {
    const afflictions = [];

    for (const nak of mapping.nakshatras) {
      // Saturn in this nakshatra
      if (positions.Saturn?.nakshatra === nak) {
        afflictions.push(`Saturn in ${nak}`);
      }
      // Mars in this nakshatra
      if (positions.Mars?.nakshatra === nak) {
        afflictions.push(`Mars in ${nak}`);
      }
      // Eclipse in this nakshatra
      for (const eclipse of (skyState.activeEclipses || [])) {
        if (eclipse.nakshatra === nak) {
          afflictions.push(`Eclipse in ${nak}`);
        }
      }
    }

    if (afflictions.length > 0) {
      effects.push({
        domain: mapping.domain,
        dir: 'neg',
        desc: `${mapping.bodyPart} of Samvatsarapurusha afflicted (${mapping.afflictionEffect}) — ${afflictions.join(', ')}`,
        weight: Math.min(0.9, 0.5 + afflictions.length * 0.15),
        planet: 'Jupiter',
        sign: null,
        ruleId: `guru_purusha_${mapping.bodyPart}`,
        source: 'BS Ch.8 Sl.19',
        category: 'samvatsara_purusha',
        manifestation: mapping.afflictionEffect
      });
    }
  }

  return effects;
}

// ─── MAIN EVALUATOR ─────────────────────────────────────────────────────────

/**
 * Evaluate all Jupiter-related mundane effects for the current sky state.
 *
 * Processes:
 *   1. 60-year Samvatsara cycle effect
 *   2. Monthly-year effect (if heliacal rising month provided)
 *   3. Transit speed rule
 *   4. Directional rule (northern/southern course)
 *   5. Color rule (if observed color provided)
 *   6. Samvatsarapurusha body affliction
 *   7. 5-year lustrum rain lord
 *
 * @param {Object} skyState - Current sky state with positions
 * @param {Object} [jupiterContext] - Additional Jupiter-specific context
 * @param {string} [jupiterContext.date] - ISO date string for cycle calculation
 * @param {string} [jupiterContext.heliacalMonth] - Month of Jupiter's last heliacal rising
 * @param {number} [jupiterContext.nakshatrasPerYear] - Jupiter's current transit speed
 * @param {number} [jupiterContext.declination] - Jupiter's current declination
 * @param {string} [jupiterContext.observedColor] - Observed color of Jupiter
 * @returns {Object[]} Array of Effect objects
 */
export function evaluateJupiter(skyState, jupiterContext = {}) {
  const effects = [];
  const date = jupiterContext.date || skyState?.date || new Date().toISOString().slice(0, 10);

  // ── 1. 60-Year Samvatsara Cycle ──────────────────────────────────────
  const yearInfo = getJupiterYear(date);
  const sv = yearInfo.samvatsara;

  effects.push({
    domain: sv.domains,
    dir: sv.dir,
    desc: `Samvatsara "${sv.name}" (Yuga ${sv.yuga}, ${sv.yugaLord}): ${sv.effect}`,
    weight: sv.weight,
    planet: 'Jupiter',
    sign: skyState?.positions?.Jupiter?.sign || null,
    ruleId: `guru_samvatsara_${sv.name.toLowerCase()}`,
    source: 'BS Ch.8 Sl.27-52',
    category: 'samvatsara_cycle',
    manifestation: sv.effect
  });

  // Yuga-level quality modifier
  if (sv.yugaQuality === 'best') {
    effects.push({
      domain: 'public_mood',
      dir: 'pos',
      desc: `Yuga ${sv.yuga} (${sv.yugaLord}) is classified as BEST — general auspiciousness pervades`,
      weight: 0.6,
      planet: 'Jupiter',
      sign: null,
      ruleId: `guru_yuga_quality_best_${sv.yuga}`,
      source: 'BS Ch.8 Sl.26',
      category: 'yuga_quality',
      manifestation: 'Overall auspicious background'
    });
  } else if (sv.yugaQuality === 'worst') {
    effects.push({
      domain: 'public_mood',
      dir: 'neg',
      desc: `Yuga ${sv.yuga} (${sv.yugaLord}) is classified as WORST — general inauspiciousness pervades`,
      weight: 0.6,
      planet: 'Jupiter',
      sign: null,
      ruleId: `guru_yuga_quality_worst_${sv.yuga}`,
      source: 'BS Ch.8 Sl.26',
      category: 'yuga_quality',
      manifestation: 'Overall inauspicious background'
    });
  }

  // ── 2. Monthly-Year Effect ────────────────────────────────────────────
  if (jupiterContext.heliacalMonth && MONTHLY_YEAR_EFFECTS[jupiterContext.heliacalMonth]) {
    const monthEffect = MONTHLY_YEAR_EFFECTS[jupiterContext.heliacalMonth];
    for (const dom of monthEffect.domains) {
      effects.push({
        domain: dom,
        dir: monthEffect.dir,
        desc: monthEffect.desc,
        weight: monthEffect.weight,
        planet: 'Jupiter',
        sign: skyState?.positions?.Jupiter?.sign || null,
        ruleId: `guru_monthly_${jupiterContext.heliacalMonth.toLowerCase()}`,
        source: monthEffect.source,
        category: 'monthly_year',
        manifestation: monthEffect.desc
      });
    }
  }

  // ── 3. Transit Speed Rule ─────────────────────────────────────────────
  if (jupiterContext.nakshatrasPerYear !== undefined) {
    const speedRule = evaluateTransitSpeed(jupiterContext.nakshatrasPerYear);
    effects.push({
      domain: 'agriculture',
      dir: speedRule.dir,
      desc: speedRule.desc,
      weight: speedRule.weight,
      planet: 'Jupiter',
      sign: skyState?.positions?.Jupiter?.sign || null,
      ruleId: `guru_speed_${speedRule.label}`,
      source: speedRule.source,
      category: 'transit_speed',
      manifestation: speedRule.desc
    });
  }

  // ── 4. Directional Rule ───────────────────────────────────────────────
  const course = getJupiterCourse(jupiterContext.declination);
  const dirRule = DIRECTIONAL_RULES[course];
  effects.push({
    domain: 'public_mood',
    dir: dirRule.dir,
    desc: dirRule.desc,
    weight: dirRule.weight,
    planet: 'Jupiter',
    sign: skyState?.positions?.Jupiter?.sign || null,
    ruleId: `guru_course_${course}`,
    source: dirRule.source,
    category: 'directional',
    manifestation: dirRule.desc
  });

  // ── 5. Color Rule ─────────────────────────────────────────────────────
  if (jupiterContext.observedColor && JUPITER_COLORS[jupiterContext.observedColor]) {
    const colorRule = JUPITER_COLORS[jupiterContext.observedColor];
    for (const dom of colorRule.domains) {
      effects.push({
        domain: dom,
        dir: colorRule.dir,
        desc: colorRule.desc,
        weight: colorRule.weight,
        planet: 'Jupiter',
        sign: skyState?.positions?.Jupiter?.sign || null,
        ruleId: `guru_color_${jupiterContext.observedColor}`,
        source: colorRule.source,
        category: 'color',
        manifestation: colorRule.desc
      });
    }
  }

  // ── 6. Samvatsarapurusha Affliction ───────────────────────────────────
  const purushaEffects = evaluatePurushaAffliction(skyState);
  effects.push(...purushaEffects);

  // ── 7. Lustrum Rain Lord ──────────────────────────────────────────────
  const lustrum = yearInfo.lustrumLord;
  effects.push({
    domain: 'agriculture',
    dir: lustrum.dir,
    desc: `Rain lord for year ${yearInfo.positionInYuga} of lustrum: ${lustrum.lord} — ${lustrum.rainQuality}`,
    weight: lustrum.weight,
    planet: 'Jupiter',
    sign: null,
    ruleId: `guru_lustrum_${lustrum.lord.toLowerCase()}`,
    source: lustrum.source,
    category: 'lustrum_rain',
    manifestation: lustrum.rainQuality
  });

  return effects;
}
