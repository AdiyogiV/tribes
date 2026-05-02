/**
 * शुक्र (शुक्रचार) — Venus's Transit Effects
 * Source: Brihat Samhita, Chapter 9 (Shukra-chara)
 *
 * Venus in mundane astrology operates through a UNIQUE 9-ROUTE (VEETHEE)
 * system where the nakshatra Venus occupies determines a "path" quality,
 * plus a 6-MANDALA system that targets specific geographic regions.
 *
 * Key references:
 *   Slokas 1-9:   9 Veethees (routes) with nakshatra assignments and quality
 *   Slokas 10-21: 6 Mandala system with regional targeting
 *   Sloka 22:     East/West Mandala modifier
 *   Sloka 23:     Visibility rules (before sunset / daytime)
 *   Slokas 24-35: 27 individual nakshatra transit effects
 *   Slokas 37-43: Planet-ahead-of-Venus rules
 *   Sloka 44:     5 color rules
 */

// ─── 9 VEETHEES (ROUTES) ────────────────────────────────────────────────────
// BS Ch.9 Slokas 1-9
//
// Venus's path through the sky is classified into 9 routes (Veethees).
// Each route is defined by which nakshatras Venus transits.
// Quality ranges from "par excellence" (Naga) to "totally destructive" (Dahana).
//
// The classification combines North (N), Middle (M), and South (S) positions:
//   Naga (N-N) → Dahana (S-S)

/**
 * @typedef {Object} Veethee
 * @property {string} name - Sanskrit name of the route
 * @property {string} code - Directional code (e.g., "N-N", "N-M")
 * @property {string} quality - Quality description
 * @property {string} dir - "pos"|"neg"|"mix"
 * @property {number} weight - 0-1 effect intensity
 * @property {string[]} nakshatras - Nakshatras belonging to this route
 * @property {string} desc - Classical effect description
 */

export const VEETHEES = [
  {
    name: 'Naga',
    code: 'N-N',
    quality: 'par excellence',
    dir: 'pos', weight: 0.95,
    nakshatras: ['Aswini', 'Bharani', 'Krittika'],
    desc: 'Naga Veethee: supreme prosperity, excellent rains, kings righteous, people joyful, all crops abundant',
    source: 'BS Ch.9 Sl.1'
  },
  {
    name: 'Gaja',
    code: 'N-M',
    quality: 'excellent',
    dir: 'pos', weight: 0.85,
    nakshatras: ['Rohini', 'Mrigasira', 'Ardra'],
    desc: 'Gaja Veethee: elephantine prosperity, good rains, agriculture thrives, wealth increases',
    source: 'BS Ch.9 Sl.2'
  },
  {
    name: 'Airavata',
    code: 'N-S',
    quality: 'very good',
    dir: 'pos', weight: 0.8,
    nakshatras: ['Punarvasu', 'Pushya', 'Aslesha'],
    desc: 'Airavata Veethee: celestial prosperity, rains timely, trade flourishes, spiritual activities thrive',
    source: 'BS Ch.9 Sl.3'
  },
  {
    name: 'Vrishabha',
    code: 'M-N',
    quality: 'good',
    dir: 'pos', weight: 0.7,
    nakshatras: ['Magha', 'Purvaphalguni', 'Uttaraphalguni'],
    desc: 'Vrishabha Veethee: bull-like steadiness, moderate prosperity, agriculture stable, some military success',
    source: 'BS Ch.9 Sl.4'
  },
  {
    name: 'Go',
    code: 'M-M',
    quality: 'moderate',
    dir: 'mix', weight: 0.55,
    nakshatras: ['Hasta', 'Chitra', 'Swati'],
    desc: 'Go Veethee: cow-like sustenance, moderate results, neither great prosperity nor suffering, average rains',
    source: 'BS Ch.9 Sl.5'
  },
  {
    name: 'Jaraddgava',
    code: 'M-S',
    quality: 'below average',
    dir: 'mix', weight: 0.45,
    nakshatras: ['Visakha', 'Anuradha', 'Jyeshta'],
    desc: 'Jaraddgava Veethee: aging-donkey path, mixed to poor results, rains uncertain, some regions suffer',
    source: 'BS Ch.9 Sl.6'
  },
  {
    name: 'Mriga',
    code: 'S-N',
    quality: 'poor',
    dir: 'neg', weight: 0.6,
    nakshatras: ['Moola', 'Purvashadha', 'Uttarashadha'],
    desc: 'Mriga Veethee: deer-like anxiety, fear pervades, crops damaged, people distressed',
    source: 'BS Ch.9 Sl.7'
  },
  {
    name: 'Khara',
    code: 'S-M',
    quality: 'very poor',
    dir: 'neg', weight: 0.75,
    nakshatras: ['Sravana', 'Dhanishta', 'Satabhishak'],
    desc: 'Khara Veethee: donkey-path harshness, drought, cattle suffer, diseases spread, military reverses',
    source: 'BS Ch.9 Sl.8'
  },
  {
    name: 'Dahana',
    code: 'S-S',
    quality: 'totally destructive',
    dir: 'neg', weight: 0.95,
    nakshatras: ['Purvabhadra', 'Uttarabhadra', 'Revati'],
    desc: 'Dahana Veethee: fire-path total destruction, famine, war, pestilence, rulers cruel, universal suffering',
    source: 'BS Ch.9 Sl.9'
  }
];

/** Quick lookup: nakshatra name → Veethee object */
const _veetheeByNakshatra = {};
for (const v of VEETHEES) {
  for (const nak of v.nakshatras) {
    _veetheeByNakshatra[nak] = v;
  }
}

/**
 * Get the Veethee (route) for a given nakshatra.
 *
 * @param {string} nakshatra - Nakshatra name
 * @returns {Veethee|null}
 */
export function getVenusVeethee(nakshatra) {
  return _veetheeByNakshatra[nakshatra] || null;
}

// ─── 6 MANDALA SYSTEM ───────────────────────────────────────────────────────
// BS Ch.9 Slokas 10-21
//
// Venus's transit through the zodiac creates 6 Mandalas, each affecting
// specific geographic regions. Each Mandala has a general effect,
// afflicted regions, and "overpowered" regions.

/**
 * @typedef {Object} Mandala
 * @property {string} name - Name of the Mandala
 * @property {number} index - 0-5 position
 * @property {string[]} nakshatras - Nakshatras in this Mandala
 * @property {string} generalEffect - Overall effect description
 * @property {string} dir - "pos"|"neg"|"mix"
 * @property {number} weight - 0-1
 * @property {string[]} afflictedRegions - Regions suffering when Venus is here
 * @property {string[]} overpoweredRegions - Regions dominated/conquered
 * @property {string} source
 */

export const MANDALAS = [
  {
    name: 'Mandala_1',
    index: 0,
    nakshatras: ['Aswini', 'Bharani', 'Krittika', 'Rohini', 'Mrigasira'],
    generalEffect: 'Northern prosperity, Brahmins honored, Vedic rituals flourish, good rains in NE',
    dir: 'pos', weight: 0.8,
    afflictedRegions: ['Madra', 'Arjunayana', 'Trigarta', 'Pushkalavata', 'Kekaya'],
    overpoweredRegions: ['Pahlava', 'China', 'Gandhara', 'Kamboja', 'Barbara'],
    source: 'BS Ch.9 Sl.10-12'
  },
  {
    name: 'Mandala_2',
    index: 1,
    nakshatras: ['Ardra', 'Punarvasu', 'Pushya', 'Aslesha', 'Magha'],
    generalEffect: 'Eastern prosperity, trade flourishes, scholarly pursuits succeed, moderate rains',
    dir: 'pos', weight: 0.7,
    afflictedRegions: ['Kosala', 'Kalinga', 'Vanga', 'Magadha', 'Pragjyotisha'],
    overpoweredRegions: ['Mithila', 'Tamralipta', 'Pundra', 'Gauda', 'Utkala'],
    source: 'BS Ch.9 Sl.13-14'
  },
  {
    name: 'Mandala_3',
    index: 2,
    nakshatras: ['Purvaphalguni', 'Uttaraphalguni', 'Hasta', 'Chitra'],
    generalEffect: 'Southern regions affected, arts and commerce impacted, heat-related issues',
    dir: 'mix', weight: 0.6,
    afflictedRegions: ['Andhra', 'Chola', 'Kerala', 'Karnatic', 'Lanka'],
    overpoweredRegions: ['Konkana', 'Vanavasi', 'Kaveri-bank dwellers', 'Simhala'],
    source: 'BS Ch.9 Sl.15-16'
  },
  {
    name: 'Mandala_4',
    index: 3,
    nakshatras: ['Swati', 'Visakha', 'Anuradha', 'Jyeshta', 'Moola'],
    generalEffect: 'Western and southwestern regions impacted, maritime issues, trade disruption',
    dir: 'neg', weight: 0.65,
    afflictedRegions: ['Sindhu', 'Sauveera', 'Anarta', 'Saurashtra', 'Raivatakas'],
    overpoweredRegions: ['Abheera', 'Dravida', 'Pahlava', 'Barbara', 'Yavana'],
    source: 'BS Ch.9 Sl.17-18'
  },
  {
    name: 'Mandala_5',
    index: 4,
    nakshatras: ['Purvashadha', 'Uttarashadha', 'Sravana', 'Dhanishta'],
    generalEffect: 'Northwestern regions affected, cold-weather crops damaged, frontier instability',
    dir: 'neg', weight: 0.7,
    afflictedRegions: ['Tushara', 'Madra', 'Kuluta', 'Halada', 'Charmaranga'],
    overpoweredRegions: ['Asmaka', 'Saulika', 'Huna', 'kingdom of Women'],
    source: 'BS Ch.9 Sl.19-20'
  },
  {
    name: 'Mandala_6',
    index: 5,
    nakshatras: ['Satabhishak', 'Purvabhadra', 'Uttarabhadra', 'Revati'],
    generalEffect: 'Northern/central regions suffer, kings troubled, general distress, water issues',
    dir: 'neg', weight: 0.75,
    afflictedRegions: ['Kuru', 'Panchala', 'Surasena', 'Mathura', 'Ayodhya'],
    overpoweredRegions: ['Kailasa dwellers', 'Himalayan people', 'Kekaya', 'Gandhara'],
    source: 'BS Ch.9 Sl.21'
  }
];

/** Quick lookup: nakshatra → Mandala object */
const _mandalaByNakshatra = {};
for (const m of MANDALAS) {
  for (const nak of m.nakshatras) {
    _mandalaByNakshatra[nak] = m;
  }
}

/**
 * Get the Mandala for a given nakshatra.
 *
 * @param {string} nakshatra - Nakshatra name
 * @returns {Mandala|null}
 */
export function getVenusMandala(nakshatra) {
  return _mandalaByNakshatra[nakshatra] || null;
}

// ─── 27 INDIVIDUAL NAKSHATRA TRANSIT EFFECTS ────────────────────────────────
// BS Ch.9 Slokas 24-35
// Each nakshatra Venus transits produces a specific mundane effect.

export const NAKSHATRA_TRANSIT_EFFECTS = {
  Aswini: {
    desc: 'Venus in Aswini: horses and horse-dealers prosper, physicians successful, swift trade',
    dir: 'pos', weight: 0.7,
    domain: 'trade',
    source: 'BS Ch.9 Sl.24'
  },
  Bharani: {
    desc: 'Venus in Bharani: cruelty increases, slayers active, blood-related events, surgery advances',
    dir: 'neg', weight: 0.65,
    domain: 'crisis',
    source: 'BS Ch.9 Sl.24'
  },
  Krittika: {
    desc: 'Venus in Krittika: fire hazards, brahmins troubled but sacred fires maintained, heat intense',
    dir: 'neg', weight: 0.6,
    domain: 'crisis',
    source: 'BS Ch.9 Sl.24'
  },
  Rohini: {
    desc: 'Venus in Rohini: cows and bulls prosper, agriculture abundant, kings honored, wealth flows',
    dir: 'pos', weight: 0.85,
    domain: 'agriculture',
    source: 'BS Ch.9 Sl.25'
  },
  Mrigasira: {
    desc: 'Venus in Mrigasira: fragrant things valued, garments trade thrives, lovers happy, music flourishes',
    dir: 'pos', weight: 0.7,
    domain: 'trade',
    source: 'BS Ch.9 Sl.25'
  },
  Ardra: {
    desc: 'Venus in Ardra: storms and destruction, rogues active, discord spreads, cruel acts',
    dir: 'neg', weight: 0.75,
    domain: 'crisis',
    source: 'BS Ch.9 Sl.25'
  },
  Punarvasu: {
    desc: 'Venus in Punarvasu: truthful prosper, merchants succeed, valuable grain abundant, renewal',
    dir: 'pos', weight: 0.75,
    domain: 'trade',
    source: 'BS Ch.9 Sl.26'
  },
  Pushya: {
    desc: 'Venus in Pushya: barley, wheat, rice prosper, kings content, ministers effective, religious acts',
    dir: 'pos', weight: 0.8,
    domain: 'agriculture',
    source: 'BS Ch.9 Sl.26'
  },
  Aslesha: {
    desc: 'Venus in Aslesha: poisons and counterfeits circulate, reptile incidents, physicians busy',
    dir: 'neg', weight: 0.65,
    domain: 'health',
    source: 'BS Ch.9 Sl.26'
  },
  Magha: {
    desc: 'Venus in Magha: wealthy men and granaries prosper, mountaineers active, ancestral rites',
    dir: 'pos', weight: 0.7,
    domain: 'economy',
    source: 'BS Ch.9 Sl.27'
  },
  Purvaphalguni: {
    desc: 'Venus in Purvaphalguni: artists, musicians and actors thrive, luxury trade up, young women honored',
    dir: 'pos', weight: 0.75,
    domain: 'culture',
    source: 'BS Ch.9 Sl.27'
  },
  Uttaraphalguni: {
    desc: 'Venus in Uttaraphalguni: learned persons prosper, fine corn abundant, kings generous, charity',
    dir: 'pos', weight: 0.75,
    domain: 'economy',
    source: 'BS Ch.9 Sl.27'
  },
  Hasta: {
    desc: 'Venus in Hasta: artisans and traders thrive, elephants valued, veda-scholars honored',
    dir: 'pos', weight: 0.7,
    domain: 'trade',
    source: 'BS Ch.9 Sl.28'
  },
  Chitra: {
    desc: 'Venus in Chitra: painters, jewelry makers, and writers prosper, beautiful objects in demand',
    dir: 'pos', weight: 0.7,
    domain: 'culture',
    source: 'BS Ch.9 Sl.28'
  },
  Swati: {
    desc: 'Venus in Swati: wind-borne damage, traders affected, corn prices fluctuate, fickle outcomes',
    dir: 'mix', weight: 0.55,
    domain: 'trade',
    source: 'BS Ch.9 Sl.28'
  },
  Visakha: {
    desc: 'Venus in Visakha: sesamum and cotton trade active, green-gram abundant, Indra-Agni devotees prosper',
    dir: 'mix', weight: 0.6,
    domain: 'agriculture',
    source: 'BS Ch.9 Sl.29'
  },
  Anuradha: {
    desc: 'Venus in Anuradha: friends of good prosper, travelers safe, autumn-growing crops succeed',
    dir: 'pos', weight: 0.7,
    domain: 'trade',
    source: 'BS Ch.9 Sl.29'
  },
  Jyeshta: {
    desc: 'Venus in Jyeshta: martial heroes active, thieves and monarchs in conflict, command structures tested',
    dir: 'mix', weight: 0.6,
    domain: 'military',
    source: 'BS Ch.9 Sl.29'
  },
  Moola: {
    desc: 'Venus in Moola: medicines and physicians in demand, roots and herbs valued, corporate distress',
    dir: 'neg', weight: 0.6,
    domain: 'health',
    source: 'BS Ch.9 Sl.30'
  },
  Purvashadha: {
    desc: 'Venus in Purvashadha: navigators and fishermen prosper, aquatic trade, bridge/dam projects',
    dir: 'mix', weight: 0.6,
    domain: 'trade',
    source: 'BS Ch.9 Sl.30'
  },
  Uttarashadha: {
    desc: 'Venus in Uttarashadha: wrestlers and warriors active, elephants valued, militant events',
    dir: 'mix', weight: 0.6,
    domain: 'military',
    source: 'BS Ch.9 Sl.30'
  },
  Sravana: {
    desc: 'Venus in Sravana: righteous men prosper, Vishnu-devotees honored, truth prevails briefly',
    dir: 'pos', weight: 0.65,
    domain: 'religion',
    source: 'BS Ch.9 Sl.31'
  },
  Dhanishta: {
    desc: 'Venus in Dhanishta: charitable deeds, very rich prosper but fickle outcomes, peace-seekers rise',
    dir: 'mix', weight: 0.55,
    domain: 'economy',
    source: 'BS Ch.9 Sl.31'
  },
  Satabhishak: {
    desc: 'Venus in Satabhishak: fisheries and aquatic trade active, drunkards increase, water issues',
    dir: 'neg', weight: 0.6,
    domain: 'health',
    source: 'BS Ch.9 Sl.31'
  },
  Purvabhadra: {
    desc: 'Venus in Purvabhadra: low-born agitate, robberies increase, niggardly rulers, duels fought',
    dir: 'neg', weight: 0.7,
    domain: 'crisis',
    source: 'BS Ch.9 Sl.32'
  },
  Uttarabhadra: {
    desc: 'Venus in Uttarabhadra: brahmins and hermits prosper, sacrifices performed, monarchs righteous',
    dir: 'pos', weight: 0.7,
    domain: 'religion',
    source: 'BS Ch.9 Sl.32'
  },
  Revati: {
    desc: 'Venus in Revati: ocean trade prospers, perfumes and flowers in demand, navigators safe',
    dir: 'pos', weight: 0.7,
    domain: 'trade',
    source: 'BS Ch.9 Sl.32'
  }
};

// ─── PLANET-AHEAD-OF-VENUS RULES ────────────────────────────────────────────
// BS Ch.9 Slokas 37-43
// When another planet is ahead of Venus (in the direction of Venus's motion),
// specific mundane effects arise.

export const PLANET_AHEAD_RULES = {
  Jupiter_opposition: {
    desc: 'Venus and Jupiter in opposition: sickness pervades, no rain, crops fail, general distress',
    dir: 'neg', weight: 0.8,
    domains: ['health', 'agriculture'],
    source: 'BS Ch.9 Sl.37'
  },
  Saturn_ahead: {
    desc: 'Saturn ahead of Venus: barbarians and southerners destroyed by wind-diseases, storms ravage',
    dir: 'neg', weight: 0.75,
    domains: ['health', 'crisis'],
    regions: ['southern countries', 'barbarian lands'],
    source: 'BS Ch.9 Sl.38'
  },
  Mars_ahead: {
    desc: 'Mars ahead of Venus: fire disasters, war erupts, famine in northern countries, bloodshed',
    dir: 'neg', weight: 0.85,
    domains: ['military', 'crisis', 'agriculture'],
    regions: ['northern countries'],
    source: 'BS Ch.9 Sl.39-40'
  },
  Jupiter_ahead: {
    desc: 'Jupiter ahead of Venus: white objects, Brahmins, and eastern direction suffer; rain deficient',
    dir: 'neg', weight: 0.7,
    domains: ['religion', 'agriculture'],
    regions: ['eastern direction'],
    source: 'BS Ch.9 Sl.41'
  },
  Mercury_ahead: {
    desc: 'Mercury ahead of Venus: rain comes but bile-diseases spread, western direction affected',
    dir: 'mix', weight: 0.65,
    domains: ['health', 'agriculture'],
    regions: ['western direction'],
    source: 'BS Ch.9 Sl.42-43'
  }
};

// ─── COLOR RULES ────────────────────────────────────────────────────────────
// BS Ch.9 Sloka 44
// Venus's observed color indicates specific effects.

export const VENUS_COLORS = {
  white: {
    desc: 'Venus appears white/bright: prosperity, good rains, happiness, crops flourish',
    dir: 'pos', weight: 0.8,
    domains: ['agriculture', 'public_mood'],
    source: 'BS Ch.9 Sl.44'
  },
  red: {
    desc: 'Venus appears red: war, fire hazards, fear, bloodshed, military conflict',
    dir: 'neg', weight: 0.8,
    domains: ['military', 'crisis'],
    source: 'BS Ch.9 Sl.44'
  },
  yellow: {
    desc: 'Venus appears yellow: diseases spread, especially jaundice and bile disorders',
    dir: 'neg', weight: 0.7,
    domains: ['health'],
    source: 'BS Ch.9 Sl.44'
  },
  dark: {
    desc: 'Venus appears dark/black: universal distress, famine, king endangered, epidemics',
    dir: 'neg', weight: 0.9,
    domains: ['crisis', 'government', 'health'],
    source: 'BS Ch.9 Sl.44'
  },
  variegated: {
    desc: 'Venus appears variegated/multi-hued: mixed fortunes, some regions prosper while others decay',
    dir: 'mix', weight: 0.6,
    domains: ['economy', 'public_mood'],
    source: 'BS Ch.9 Sl.44'
  }
};

// ─── VISIBILITY RULES ───────────────────────────────────────────────────────
// BS Ch.9 Sloka 23
// Whether Venus is visible before sunset or during daytime changes the reading.

export const VISIBILITY_RULES = {
  before_sunset: {
    desc: 'Venus visible before sunset (evening star appearing too early): fear spreads, anxiety among rulers',
    dir: 'neg', weight: 0.65,
    domains: ['government', 'public_mood'],
    source: 'BS Ch.9 Sl.23'
  },
  daytime: {
    desc: 'Venus visible during daytime: hunger and famine, food scarcity, people distressed',
    dir: 'neg', weight: 0.8,
    domains: ['agriculture', 'crisis'],
    source: 'BS Ch.9 Sl.23'
  },
  normal_evening: {
    desc: 'Venus as normal evening star: no abnormality, standard conditions apply',
    dir: 'mix', weight: 0.3,
    domains: ['public_mood'],
    source: 'BS Ch.9 Sl.23'
  },
  normal_morning: {
    desc: 'Venus as normal morning star: no abnormality, standard conditions apply',
    dir: 'mix', weight: 0.3,
    domains: ['public_mood'],
    source: 'BS Ch.9 Sl.23'
  }
};

// ─── EAST/WEST MANDALA MODIFIER ─────────────────────────────────────────────
// BS Ch.9 Sloka 22
// Venus in the eastern Mandala (morning star) vs western Mandala (evening star)
// modifies the overall reading.

export const EAST_WEST_MODIFIER = {
  eastern: {
    desc: 'Venus in eastern Mandala (morning star): effects manifest sooner, eastern regions more affected',
    modifier: 1.1,
    affectedDirection: 'east',
    source: 'BS Ch.9 Sl.22'
  },
  western: {
    desc: 'Venus in western Mandala (evening star): effects manifest later, western regions more affected',
    modifier: 1.1,
    affectedDirection: 'west',
    source: 'BS Ch.9 Sl.22'
  }
};

// ─── HELPERS ────────────────────────────────────────────────────────────────

/**
 * Determine if a planet is "ahead" of Venus by comparing ecliptic longitudes.
 * "Ahead" means the planet's longitude is greater than Venus's in the
 * direction of Venus's motion (direct = higher longitude).
 *
 * @param {number} venusLong - Venus's ecliptic longitude (0-360)
 * @param {number} otherLong - Other planet's ecliptic longitude (0-360)
 * @param {boolean} venusRetrograde - Whether Venus is retrograde
 * @returns {boolean}
 */
function isPlanetAheadOfVenus(venusLong, otherLong, venusRetrograde) {
  const diff = ((otherLong - venusLong + 360) % 360);
  if (venusRetrograde) {
    // Retrograde: "ahead" = smaller longitude (behind in zodiac)
    return diff > 180 && diff < 350;
  }
  // Direct: "ahead" = greater longitude, within ~30 degrees
  return diff > 0 && diff < 30;
}

/**
 * Check if Venus and Jupiter are in opposition (within 10 degrees of 180).
 *
 * @param {number} venusLong - Venus's longitude
 * @param {number} jupiterLong - Jupiter's longitude
 * @returns {boolean}
 */
function isInOpposition(venusLong, jupiterLong) {
  const diff = Math.abs(venusLong - jupiterLong);
  const normalized = diff > 180 ? 360 - diff : diff;
  return Math.abs(normalized - 180) < 10;
}

/**
 * Determine Venus's east/west position (morning star vs evening star).
 *
 * @param {Object} venusPos - Venus position with longitude and sunDistance
 * @param {Object} sunPos - Sun position with longitude
 * @returns {'eastern'|'western'|null}
 */
function getVenusEastWest(venusPos, sunPos) {
  if (!venusPos?.longitude || !sunPos?.longitude) return null;
  const diff = ((venusPos.longitude - sunPos.longitude + 360) % 360);
  // Venus ahead of Sun = evening star (western)
  // Venus behind Sun = morning star (eastern)
  if (diff > 0 && diff < 180) return 'western';
  if (diff > 180 && diff < 360) return 'eastern';
  return null;
}

// ─── MAIN EVALUATOR ─────────────────────────────────────────────────────────

/**
 * Evaluate all Venus-related mundane effects for the current sky state.
 *
 * Processes:
 *   1. Veethee (route) classification
 *   2. Mandala (regional targeting)
 *   3. Individual nakshatra transit effect
 *   4. Planet-ahead-of-Venus rules
 *   5. Color rule (if observed color provided)
 *   6. Visibility rule (if visibility status provided)
 *   7. East/West Mandala modifier
 *
 * @param {Object} skyState - Current sky state with positions
 * @param {Object} [venusContext] - Additional Venus-specific context
 * @param {string} [venusContext.observedColor] - Observed color of Venus
 * @param {string} [venusContext.visibility] - "before_sunset"|"daytime"|"normal_evening"|"normal_morning"
 * @returns {Object[]} Array of Effect objects
 */
export function evaluateVenus(skyState, venusContext = {}) {
  const effects = [];
  const positions = skyState?.positions || {};
  const venusPos = positions.Venus;

  if (!venusPos) return effects;

  const venusNak = venusPos.nakshatra;
  const venusSign = venusPos.sign;
  const venusLong = venusPos.longitude;

  // ── 1. Veethee (Route) Classification ─────────────────────────────────
  if (venusNak) {
    const veethee = getVenusVeethee(venusNak);
    if (veethee) {
      effects.push({
        domain: 'public_mood',
        dir: veethee.dir,
        desc: veethee.desc,
        weight: veethee.weight,
        planet: 'Venus',
        sign: venusSign,
        ruleId: `shukra_veethee_${veethee.name.toLowerCase()}`,
        source: veethee.source,
        category: 'veethee',
        manifestation: `Venus on ${veethee.name} Veethee (${veethee.quality})`
      });
    }
  }

  // ── 2. Mandala (Regional Targeting) ───────────────────────────────────
  if (venusNak) {
    const mandala = getVenusMandala(venusNak);
    if (mandala) {
      effects.push({
        domain: 'geography',
        dir: mandala.dir,
        desc: `${mandala.name}: ${mandala.generalEffect}`,
        weight: mandala.weight,
        planet: 'Venus',
        sign: venusSign,
        ruleId: `shukra_mandala_${mandala.index}`,
        source: mandala.source,
        category: 'mandala',
        manifestation: mandala.generalEffect
      });

      // Afflicted regions as separate effect
      if (mandala.afflictedRegions.length > 0) {
        effects.push({
          domain: 'geography',
          dir: 'neg',
          desc: `Regions afflicted by Venus in ${mandala.name}: ${mandala.afflictedRegions.join(', ')}`,
          weight: mandala.weight * 0.8,
          planet: 'Venus',
          sign: venusSign,
          ruleId: `shukra_mandala_${mandala.index}_afflicted`,
          source: mandala.source,
          category: 'mandala_region',
          manifestation: `${mandala.afflictedRegions.join(', ')} suffer`
        });
      }

      // Overpowered regions
      if (mandala.overpoweredRegions.length > 0) {
        effects.push({
          domain: 'geography',
          dir: 'neg',
          desc: `Regions overpowered when Venus in ${mandala.name}: ${mandala.overpoweredRegions.join(', ')}`,
          weight: mandala.weight * 0.7,
          planet: 'Venus',
          sign: venusSign,
          ruleId: `shukra_mandala_${mandala.index}_overpowered`,
          source: mandala.source,
          category: 'mandala_region',
          manifestation: `${mandala.overpoweredRegions.join(', ')} dominated`
        });
      }
    }
  }

  // ── 3. Individual Nakshatra Transit Effect ────────────────────────────
  if (venusNak && NAKSHATRA_TRANSIT_EFFECTS[venusNak]) {
    const nakEffect = NAKSHATRA_TRANSIT_EFFECTS[venusNak];
    effects.push({
      domain: nakEffect.domain,
      dir: nakEffect.dir,
      desc: nakEffect.desc,
      weight: nakEffect.weight,
      planet: 'Venus',
      sign: venusSign,
      ruleId: `shukra_nak_${venusNak.toLowerCase()}`,
      source: nakEffect.source,
      category: 'nakshatra_transit',
      manifestation: nakEffect.desc
    });
  }

  // ── 4. Planet-Ahead-of-Venus Rules ────────────────────────────────────
  if (venusLong !== undefined) {
    const venusRetro = !!venusPos.isRetrograde;

    // Jupiter opposition check
    const jupiterPos = positions.Jupiter;
    if (jupiterPos?.longitude !== undefined) {
      if (isInOpposition(venusLong, jupiterPos.longitude)) {
        const rule = PLANET_AHEAD_RULES.Jupiter_opposition;
        for (const dom of rule.domains) {
          effects.push({
            domain: dom,
            dir: rule.dir,
            desc: rule.desc,
            weight: rule.weight,
            planet: 'Venus',
            sign: venusSign,
            ruleId: 'shukra_jupiter_opposition',
            source: rule.source,
            category: 'planet_ahead',
            manifestation: rule.desc
          });
        }
      }
    }

    // Saturn ahead check
    const saturnPos = positions.Saturn;
    if (saturnPos?.longitude !== undefined && isPlanetAheadOfVenus(venusLong, saturnPos.longitude, venusRetro)) {
      const rule = PLANET_AHEAD_RULES.Saturn_ahead;
      for (const dom of rule.domains) {
        effects.push({
          domain: dom,
          dir: rule.dir,
          desc: rule.desc,
          weight: rule.weight,
          planet: 'Venus',
          sign: venusSign,
          ruleId: 'shukra_saturn_ahead',
          source: rule.source,
          category: 'planet_ahead',
          manifestation: rule.desc
        });
      }
    }

    // Mars ahead check
    const marsPos = positions.Mars;
    if (marsPos?.longitude !== undefined && isPlanetAheadOfVenus(venusLong, marsPos.longitude, venusRetro)) {
      const rule = PLANET_AHEAD_RULES.Mars_ahead;
      for (const dom of rule.domains) {
        effects.push({
          domain: dom,
          dir: rule.dir,
          desc: rule.desc,
          weight: rule.weight,
          planet: 'Venus',
          sign: venusSign,
          ruleId: 'shukra_mars_ahead',
          source: rule.source,
          category: 'planet_ahead',
          manifestation: rule.desc
        });
      }
    }

    // Jupiter ahead check (different from opposition)
    if (jupiterPos?.longitude !== undefined && !isInOpposition(venusLong, jupiterPos.longitude)
        && isPlanetAheadOfVenus(venusLong, jupiterPos.longitude, venusRetro)) {
      const rule = PLANET_AHEAD_RULES.Jupiter_ahead;
      for (const dom of rule.domains) {
        effects.push({
          domain: dom,
          dir: rule.dir,
          desc: rule.desc,
          weight: rule.weight,
          planet: 'Venus',
          sign: venusSign,
          ruleId: 'shukra_jupiter_ahead',
          source: rule.source,
          category: 'planet_ahead',
          manifestation: rule.desc
        });
      }
    }

    // Mercury ahead check
    const mercuryPos = positions.Mercury;
    if (mercuryPos?.longitude !== undefined && isPlanetAheadOfVenus(venusLong, mercuryPos.longitude, venusRetro)) {
      const rule = PLANET_AHEAD_RULES.Mercury_ahead;
      for (const dom of rule.domains) {
        effects.push({
          domain: dom,
          dir: rule.dir,
          desc: rule.desc,
          weight: rule.weight,
          planet: 'Venus',
          sign: venusSign,
          ruleId: 'shukra_mercury_ahead',
          source: rule.source,
          category: 'planet_ahead',
          manifestation: rule.desc
        });
      }
    }
  }

  // ── 5. Color Rule ─────────────────────────────────────────────────────
  if (venusContext.observedColor && VENUS_COLORS[venusContext.observedColor]) {
    const colorRule = VENUS_COLORS[venusContext.observedColor];
    for (const dom of colorRule.domains) {
      effects.push({
        domain: dom,
        dir: colorRule.dir,
        desc: colorRule.desc,
        weight: colorRule.weight,
        planet: 'Venus',
        sign: venusSign,
        ruleId: `shukra_color_${venusContext.observedColor}`,
        source: colorRule.source,
        category: 'color',
        manifestation: colorRule.desc
      });
    }
  }

  // ── 6. Visibility Rule ────────────────────────────────────────────────
  if (venusContext.visibility && VISIBILITY_RULES[venusContext.visibility]) {
    const visRule = VISIBILITY_RULES[venusContext.visibility];
    for (const dom of visRule.domains) {
      effects.push({
        domain: dom,
        dir: visRule.dir,
        desc: visRule.desc,
        weight: visRule.weight,
        planet: 'Venus',
        sign: venusSign,
        ruleId: `shukra_visibility_${venusContext.visibility}`,
        source: visRule.source,
        category: 'visibility',
        manifestation: visRule.desc
      });
    }
  }

  // ── 7. East/West Mandala Modifier ─────────────────────────────────────
  const sunPos = positions.Sun;
  const eastWest = getVenusEastWest(venusPos, sunPos);
  if (eastWest) {
    const ewMod = EAST_WEST_MODIFIER[eastWest];
    effects.push({
      domain: 'geography',
      dir: 'mix',
      desc: ewMod.desc,
      weight: 0.4,
      planet: 'Venus',
      sign: venusSign,
      ruleId: `shukra_ew_${eastWest}`,
      source: ewMod.source,
      category: 'east_west_mandala',
      manifestation: ewMod.desc
    });

    // Apply the modifier to all existing effects' weights
    // (the 1.1x multiplier for the affected direction)
    for (const eff of effects) {
      if (eff.category === 'mandala_region' || eff.category === 'mandala') {
        eff.weight = Math.min(1.0, eff.weight * ewMod.modifier);
      }
    }
  }

  return effects;
}
