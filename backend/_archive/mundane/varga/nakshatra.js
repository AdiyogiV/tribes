/**
 * NAKSHATRA — Universal Nakshatra Definitions
 * Foundation module used by ALL varga modules.
 *
 * Source: Brihat Samhita Ch.15 (Nakshatra Vibhaga), Ch.14 (Kurma), Ch.97 (Paka)
 * Contains: 28 nakshatras with deities, dependencies, varna, classification,
 *           paka timing, and hurt-detection logic.
 */

// ─── 28 NAKSHATRAS WITH FULL METADATA ───────────────────────────────────────
// BS Ch.15 Slokas 1-30, Ch.98 Slokas 4-11, Ch.97 Slokas 14-16

export const NAKSHATRAS = [
  {
    idx: 0, name: 'Aswini', deity: 'Aswini',
    starCount: 3,
    varna: 'merchant',
    classification: 'kshipra',  // swift
    dependencies: ['horse-dealers', 'commandants', 'physicians', 'attendants', 'horses', 'horse-riders', 'traders', 'handsome persons', 'horse-grooms'],
    pakaDays: 270,  // 9 months
    kurmaDirection: 'NE',
    kurmaTriad: 8
  },
  {
    idx: 1, name: 'Bharani', deity: 'Yama',
    starCount: 3,
    varna: 'outcaste',
    classification: 'ugra',  // dreadful
    dependencies: ['blood-flesh feeders', 'cruel men', 'slayers', 'catchers', 'cudgellers', 'husk-grain', 'low-born persons'],
    pakaDays: 30,  // 1 month
    kurmaDirection: 'NE',
    kurmaTriad: 8
  },
  {
    idx: 2, name: 'Krittika', deity: 'Agni',
    starCount: 6,
    varna: 'brahmin',
    classification: 'mridu_teekshna',  // tender-sharp (mixed)
    dependencies: ['white flowers', 'brahmins performing agnihotra', 'reciters of sacred hymns', 'grammarians', 'miners', 'barbers', 'brahmins', 'potters', 'priests', 'astrologers'],
    pakaDays: 2400,  // 80 months
    kurmaDirection: 'C',
    kurmaTriad: 0
  },
  {
    idx: 3, name: 'Rohini', deity: 'Prajapati',
    starCount: 5,
    varna: 'husbandmen',
    classification: 'dhruva',  // fixed
    dependencies: ['observers of vows', 'merchandises', 'kings', 'wealthy persons', 'yogis', 'cartmen', 'cows', 'bulls', 'aquatic animals', 'agriculturists', 'mountains', 'men in authority'],
    pakaDays: 300,  // 10 months
    kurmaDirection: 'C',
    kurmaTriad: 0
  },
  {
    idx: 4, name: 'Mrigasira', deity: 'Chandra',
    starCount: 3,
    varna: 'servant',
    classification: 'mridu',  // tender
    dependencies: ['fragrant things', 'garments', 'aquatic products', 'flowers', 'fruits', 'gems', 'foresters', 'birds', 'beasts', 'musicians', 'lovers', 'letter-bearers'],
    pakaDays: 30,  // 1 month
    kurmaDirection: 'C',
    kurmaTriad: 0
  },
  {
    idx: 5, name: 'Ardra', deity: 'Rudra',
    starCount: 1,
    varna: 'cruel',
    classification: 'teekshna',  // sharp
    dependencies: ['slayers', 'catchers', 'liars', 'adulterers', 'thieves', 'rogues', 'discord-sowers', 'husk-grain', 'cruel-minded people', 'charmers', 'sorcerers'],
    pakaDays: 180,  // 6 months
    kurmaDirection: 'E',
    kurmaTriad: 1
  },
  {
    idx: 6, name: 'Punarvasu', deity: 'Aditi',
    starCount: 5,
    varna: 'merchant',
    classification: 'chara',  // temporary
    dependencies: ['truthful', 'charitable', 'pure', 'high-born', 'handsome', 'intelligent', 'renowned', 'rich men', 'valuable grain', 'merchants', 'servants', 'artisans'],
    pakaDays: 90,  // 3 months
    kurmaDirection: 'E',
    kurmaTriad: 1
  },
  {
    idx: 7, name: 'Pushya', deity: 'Brihaspati',
    starCount: 3,
    varna: 'kshatriya',
    classification: 'kshipra',  // swift
    dependencies: ['barley', 'wheat', 'rice', 'sugarcane', 'forests', 'ministers', 'kings', 'fishermen', 'honest folk', 'sacrifice performers'],
    pakaDays: 90,  // 3 months
    kurmaDirection: 'E',
    kurmaTriad: 1
  },
  {
    idx: 8, name: 'Aslesha', deity: 'Sarpa',
    starCount: 6,
    varna: 'outcaste',
    classification: 'teekshna',  // sharp
    dependencies: ['counterfeits', 'bulbs', 'roots', 'fruits', 'worms', 'reptiles', 'poison', 'robbers', 'husk-grain', 'physicians'],
    pakaDays: 0,  // same day
    kurmaDirection: 'SE',
    kurmaTriad: 2
  },
  {
    idx: 9, name: 'Magha', deity: 'Pitrs',
    starCount: 5,
    varna: 'husbandmen',
    classification: 'ugra',  // dreadful
    dependencies: ['people rich in money and corn', 'granaries', 'mountaineers', 'men devoted to elders', 'merchants', 'heroes', 'carnivorous beings'],
    pakaDays: 30,  // 1 month
    kurmaDirection: 'SE',
    kurmaTriad: 2
  },
  {
    idx: 10, name: 'Purvaphalguni', deity: 'Bhaga',
    starCount: 1,
    varna: 'brahmin',
    classification: 'ugra',  // dreadful
    dependencies: ['actors', 'young damsels', 'amiable persons', 'musicians', 'artists', 'merchandises', 'cotton', 'salt', 'honey', 'oil', 'boys'],
    pakaDays: 180,  // 6 months
    kurmaDirection: 'SE',
    kurmaTriad: 2
  },
  {
    idx: 11, name: 'Uttaraphalguni', deity: 'Aryaman',
    starCount: 8,
    varna: 'kshatriya',
    classification: 'dhruva',  // fixed
    dependencies: ['mild persons', 'pure persons', 'modest persons', 'charitable persons', 'learned persons', 'fine corn', 'highly wealthy men', 'kings'],
    pakaDays: 180,  // 6 months
    kurmaDirection: 'S',
    kurmaTriad: 3
  },
  {
    idx: 12, name: 'Hasta', deity: 'Savita',
    starCount: 15,
    varna: 'merchant',
    classification: 'kshipra',  // swift
    dependencies: ['robbers', 'elephants', 'charioteers', 'elephant-drivers', 'artisans', 'merchandises', 'husked-grain', 'veda-scholars', 'traders', 'energetic men'],
    pakaDays: 90,  // 3 months
    kurmaDirection: 'S',
    kurmaTriad: 3
  },
  {
    idx: 13, name: 'Chitra', deity: 'Twashta',
    starCount: 5,
    varna: 'servant',
    classification: 'mridu',  // tender
    dependencies: ['persons skilled in ornamenting', 'jewelry makers', 'painters', 'writers', 'singers', 'perfumers', 'mathematicians', 'weavers', 'ophthalmic physicians'],
    pakaDays: 15,  // half month
    kurmaDirection: 'S',
    kurmaTriad: 3
  },
  {
    idx: 14, name: 'Swati', deity: 'Vayu',
    starCount: 1,
    varna: 'cruel',
    classification: 'chara',  // temporary
    dependencies: ['birds', 'beasts', 'horses', 'traders', 'corn', 'flatulence-causing produce', 'fickle-minded friends', 'ascetics'],
    pakaDays: 240,  // 8 months
    kurmaDirection: 'SW',
    kurmaTriad: 4
  },
  {
    idx: 15, name: 'Visakha', deity: 'Indragni',
    starCount: 1,
    varna: 'outcaste',
    classification: 'mridu_teekshna',  // tender-sharp (mixed)
    dependencies: ['trees with red blossoms', 'sesamum', 'green-gram', 'cotton', 'black gram', 'bengal gram', 'men devoted to Indra and Agni'],
    pakaDays: 90,  // 3 months
    kurmaDirection: 'SW',
    kurmaTriad: 4
  },
  {
    idx: 16, name: 'Anuradha', deity: 'Mitra',
    starCount: 5,
    varna: 'husbandmen',
    classification: 'mridu',  // tender
    dependencies: ['men of prowess', 'corporation heads', 'friends of good', 'travellers', 'honest people', 'autumn-growing things'],
    pakaDays: 180,  // 6 months
    kurmaDirection: 'SW',
    kurmaTriad: 4
  },
  {
    idx: 17, name: 'Jyeshta', deity: 'Indra',
    starCount: 4,
    varna: 'servant',
    classification: 'teekshna',  // sharp
    dependencies: ['great martial heroes', 'those with noble family', 'thieves', 'conquest-minded monarchs', 'commandants'],
    pakaDays: 30,  // 1 month
    kurmaDirection: 'W',
    kurmaTriad: 5
  },
  {
    idx: 18, name: 'Moola', deity: 'Nirriti',
    starCount: 3,
    varna: 'cruel',
    classification: 'teekshna',  // sharp
    dependencies: ['medicines', 'physicians', 'corporation deacons', 'flower-root-fruit dealers', 'seeds', 'very rich men'],
    pakaDays: 30,  // 1 month
    kurmaDirection: 'W',
    kurmaTriad: 5
  },
  {
    idx: 19, name: 'Purvashadha', deity: 'Apah',
    starCount: 11,
    varna: 'brahmin',
    classification: 'ugra',  // dreadful
    dependencies: ['tender-hearted men', 'navigators', 'fishermen', 'aquatic animals', 'truth-purity-wealth devotees', 'bridge constructors'],
    pakaDays: 180,  // 6 months
    kurmaDirection: 'W',
    kurmaTriad: 5
  },
  {
    idx: 20, name: 'Uttarashadha', deity: 'Visvedevas',
    starCount: 2,
    varna: 'kshatriya',
    classification: 'dhruva',  // fixed
    dependencies: ['mahouts', 'wrestlers', 'elephants', 'horses', 'god-devotees', 'immoveables', 'warriors', 'militant persons'],
    pakaDays: 180,  // 6 months
    kurmaDirection: 'NW',
    kurmaTriad: 6
  },
  {
    idx: 21, name: 'Abhijit', deity: 'Brahman',
    starCount: 8,
    varna: 'merchant',
    classification: 'kshipra',  // swift (treated like Pushya/Hasta)
    dependencies: [],
    pakaDays: 0,  // same day
    kurmaDirection: null,  // not in standard 27
    kurmaTriad: null
  },
  {
    idx: 22, name: 'Sravana', deity: 'Vishnu',
    starCount: 3,
    varna: 'outcaste',
    classification: 'chara',  // temporary
    dependencies: ['jugglers', 'ever-active', 'able', 'energetic', 'righteous men', 'vishnu-devotees', 'truthful persons'],
    pakaDays: 210,  // 7 months
    kurmaDirection: 'NW',
    kurmaTriad: 6
  },
  {
    idx: 23, name: 'Dhanishta', deity: 'Vasu',
    starCount: 5,
    varna: 'servant',
    classification: 'chara',  // temporary
    dependencies: ['men without pride', 'eunuchs', 'fickle friends', 'charitable', 'very rich', 'peace-loving persons'],
    pakaDays: 240,  // 8 months
    kurmaDirection: 'NW',
    kurmaTriad: 6
  },
  {
    idx: 24, name: 'Satabhishak', deity: 'Varuna',
    starCount: 100,
    varna: 'cruel',
    classification: 'chara',  // temporary
    dependencies: ['snarers', 'anglers', 'aquatic products', 'fish-dealers', 'boar-hunters', 'washermen', 'distillers', 'fowlers'],
    pakaDays: 45,  // 1.5 months
    kurmaDirection: 'N',
    kurmaTriad: 7
  },
  {
    idx: 25, name: 'Purvabhadra', deity: 'Ajaikapat',
    starCount: 18,
    varna: 'brahmin',
    classification: 'ugra',  // dreadful
    dependencies: ['robbers', 'cowherds', 'murderous persons', 'niggards', 'low-false-hearted people', 'duel-experts'],
    pakaDays: 90,  // 3 months
    kurmaDirection: 'N',
    kurmaTriad: 7
  },
  {
    idx: 26, name: 'Uttarabhadra', deity: 'Ahirbudhnya',
    starCount: 8,
    varna: 'kshatriya',
    classification: 'dhruva',  // fixed
    dependencies: ['brahmins', 'sacrifice-charity-penance devotees', 'very rich persons', 'hermits', 'heretics', 'monarchs', 'valuable corn'],
    pakaDays: 90,  // 3 months
    kurmaDirection: 'N',
    kurmaTriad: 7
  },
  {
    idx: 27, name: 'Revati', deity: 'Pushan',
    starCount: 32,
    varna: 'husbandmen',
    classification: 'mridu',  // tender
    dependencies: ['aquatic fruits-flowers', 'salt', 'gems', 'conch shell', 'pearls', 'lotuses', 'perfumes', 'fragrant flowers', 'traders', 'helmsmen'],
    pakaDays: 150,  // 5 months
    kurmaDirection: 'NE',
    kurmaTriad: 8
  }
];

// ─── QUICK LOOKUP MAPS ──────────────────────────────────────────────────────

export const NAKSHATRA_BY_NAME = Object.fromEntries(
  NAKSHATRAS.map(n => [n.name, n])
);

export const NAKSHATRA_BY_IDX = Object.fromEntries(
  NAKSHATRAS.map(n => [n.idx, n])
);

// ─── CLASSIFICATION GROUPS ──────────────────────────────────────────────────
// BS Ch.98 Slokas 6-11

export const CLASSIFICATIONS = {
  dhruva:        ['Uttaraphalguni', 'Uttarashadha', 'Uttarabhadra', 'Rohini'],
  teekshna:      ['Moola', 'Ardra', 'Jyeshta', 'Aslesha'],
  ugra:          ['Purvaphalguni', 'Purvashadha', 'Purvabhadra', 'Bharani', 'Magha'],
  kshipra:       ['Hasta', 'Aswini', 'Pushya', 'Abhijit'],
  mridu:         ['Anuradha', 'Chitra', 'Revati', 'Mrigasira'],
  mridu_teekshna: ['Krittika', 'Visakha'],
  chara:         ['Sravana', 'Dhanishta', 'Satabhishak', 'Punarvasu', 'Swati']
};

// ─── VARNA GROUPS ────────────────────────────────────────────────────────────
// BS Ch.15 Slokas 28-30

export const VARNAS = {
  brahmin:    ['Purvaphalguni', 'Purvashadha', 'Purvabhadra', 'Krittika'],
  kshatriya:  ['Uttaraphalguni', 'Uttarashadha', 'Uttarabhadra', 'Pushya'],
  husbandmen: ['Revati', 'Rohini', 'Anuradha', 'Magha'],
  merchant:   ['Punarvasu', 'Hasta', 'Abhijit', 'Aswini'],
  cruel:      ['Moola', 'Ardra', 'Swati', 'Satabhishak'],
  servant:    ['Mrigasira', 'Jyeshta', 'Chitra', 'Dhanishta'],
  outcaste:   ['Aslesha', 'Visakha', 'Sravana', 'Bharani']
};

// ─── JOURNEY NAKSHATRAS ─────────────────────────────────────────────────────
// BS Ch.98 Sloka 12

export const JOURNEY_NAKSHATRAS = [
  'Hasta', 'Chitra', 'Swati', 'Mrigasira', 'Sravana', 'Dhanishta',
  'Satabhishak', 'Revati', 'Aswini', 'Jyeshta', 'Pushya', 'Punarvasu'
];

// ─── HURT DETECTION ─────────────────────────────────────────────────────────
// BS Ch.15 Slokas 31-32 — Universal definition of "hurt" nakshatra
// Used across ALL chapters when checking nakshatra affliction.

/**
 * Check if a nakshatra is "hurt" (afflicted) given current sky state.
 * A nakshatra is hurt when ANY of these conditions hold:
 *   1. Occupied by the Sun
 *   2. Occupied by Saturn
 *   3. Mars transits through it
 *   4. Mars retrogrades in it
 *   5. Merged in an eclipse
 *   6. Hit by a meteor (not computationally detectable — external input)
 *   7. Manifestly crushed by the Moon (Moon very close, overpowering)
 *   8. Something extraordinary happens with it (portent — external input)
 *
 * @param {string} nakshatraName - Name of the nakshatra to check
 * @param {Object} skyState - Current planetary positions
 * @param {Object} [externalEvents] - Optional: { meteors: string[], portents: string[] }
 * @returns {{ hurt: boolean, reasons: string[] }}
 */
export function isNakshatraHurt(nakshatraName, skyState, externalEvents = {}) {
  const reasons = [];
  const positions = skyState?.positions || {};

  // 1. Occupied by Sun
  if (positions.Sun?.nakshatra === nakshatraName) {
    reasons.push('occupied by Sun');
  }

  // 2. Occupied by Saturn
  if (positions.Saturn?.nakshatra === nakshatraName) {
    reasons.push('occupied by Saturn');
  }

  // 3. Mars transits through it
  if (positions.Mars?.nakshatra === nakshatraName) {
    reasons.push('Mars transiting');
  }

  // 4. Mars retrogrades in it
  if (positions.Mars?.nakshatra === nakshatraName && positions.Mars?.isRetrograde) {
    reasons.push('Mars retrograde in nakshatra');
  }

  // 5. Eclipse active in this nakshatra
  const activeEclipses = skyState?.activeEclipses || [];
  for (const eclipse of activeEclipses) {
    if (eclipse.nakshatra === nakshatraName) {
      reasons.push('merged in eclipse');
    }
  }

  // 6. Meteor hit (external input)
  if (externalEvents.meteors?.includes(nakshatraName)) {
    reasons.push('hit by meteor');
  }

  // 7. Moon crushing (close conjunction)
  if (positions.Moon?.nakshatra === nakshatraName) {
    // Only counts as "crushing" if Moon is very close to yoga-tara
    // For now, flag if Moon is in same nakshatra — can refine with longitude
    reasons.push('Moon in nakshatra (potential crushing)');
  }

  // 8. Extraordinary portent (external input)
  if (externalEvents.portents?.includes(nakshatraName)) {
    reasons.push('extraordinary portent');
  }

  return {
    hurt: reasons.length > 0,
    reasons
  };
}

/**
 * Get all hurt nakshatras in current sky state.
 * @param {Object} skyState
 * @param {Object} [externalEvents]
 * @returns {Map<string, { hurt: boolean, reasons: string[] }>}
 */
export function getAllHurtNakshatras(skyState, externalEvents = {}) {
  const result = new Map();
  for (const n of NAKSHATRAS) {
    const check = isNakshatraHurt(n.name, skyState, externalEvents);
    if (check.hurt) {
      result.set(n.name, check);
    }
  }
  return result;
}

/**
 * Get dependencies affected by hurt nakshatras.
 * When a nakshatra is hurt, its dependencies suffer.
 * @param {Map<string, Object>} hurtMap - From getAllHurtNakshatras()
 * @returns {Array<{ nakshatra: string, dependencies: string[], reasons: string[] }>}
 */
export function getAffectedDependencies(hurtMap) {
  const affected = [];
  for (const [name, { reasons }] of hurtMap) {
    const nak = NAKSHATRA_BY_NAME[name];
    if (nak && nak.dependencies.length > 0) {
      affected.push({
        nakshatra: name,
        dependencies: nak.dependencies,
        reasons
      });
    }
  }
  return affected;
}

// ─── PAKA LOOKUP ────────────────────────────────────────────────────────────

/**
 * Get fruition timing for a nakshatra in days.
 * BS Ch.97 Slokas 14-16
 * @param {string} nakshatraName
 * @returns {number} Days until effects manifest. 0 = same day.
 */
export function getNakshatraPakaDays(nakshatraName) {
  const nak = NAKSHATRA_BY_NAME[nakshatraName];
  return nak ? nak.pakaDays : 90; // default 3 months if unknown
}

/**
 * Get the nakshatra offset between two nakshatras (used by Mars Ch.6).
 * Counts forward from 'from' to 'to' in the standard 27-nakshatra sequence.
 * @param {string} fromName
 * @param {string} toName
 * @returns {number} 1-27 offset
 */
export function getNakshatraOffset(fromName, toName) {
  const from = NAKSHATRA_BY_NAME[fromName];
  const to = NAKSHATRA_BY_NAME[toName];
  if (!from || !to) return 0;
  // Use indices but skip Abhijit (idx 21) for the standard 27 sequence
  const fromIdx27 = from.idx > 21 ? from.idx - 1 : from.idx;
  const toIdx27 = to.idx > 21 ? to.idx - 1 : to.idx;
  return ((toIdx27 - fromIdx27 + 27) % 27) + 1;
}
