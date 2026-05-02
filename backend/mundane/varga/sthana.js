/**
 * STHANA VARGA — Geographic Targeting System
 * Source: BS Ch.14 (Kurma Vibhaga), Ch.16 (Graha Bhaktiyoga)
 *
 * Maps nakshatras → directions → regions (Ch.14)
 * Maps planets → regions, peoples, commodities (Ch.16)
 *
 * This replaces/extends the existing koorma_chakra.js with the full BS data.
 */

// ─── KURMA CHAKRA: 9 DIRECTION TRIADS ───────────────────────────────────────
// BS Ch.14 Slokas 1-31
// 27 nakshatras divided into 9 triads, each mapping to a direction.

export const KURMA_DIRECTIONS = {
  C:  { name: 'Center (Bharata)',   nakshatras: ['Krittika', 'Rohini', 'Mrigasira'] },
  E:  { name: 'East',              nakshatras: ['Ardra', 'Punarvasu', 'Pushya'] },
  SE: { name: 'South-East',        nakshatras: ['Aslesha', 'Magha', 'Purvaphalguni'] },
  S:  { name: 'South',             nakshatras: ['Uttaraphalguni', 'Hasta', 'Chitra'] },
  SW: { name: 'South-West',        nakshatras: ['Swati', 'Visakha', 'Anuradha'] },
  W:  { name: 'West',              nakshatras: ['Jyeshta', 'Moola', 'Purvashadha'] },
  NW: { name: 'North-West',        nakshatras: ['Uttarashadha', 'Sravana', 'Dhanishta'] },
  N:  { name: 'North',             nakshatras: ['Satabhishak', 'Purvabhadra', 'Uttarabhadra'] },
  NE: { name: 'North-East',        nakshatras: ['Revati', 'Aswini', 'Bharani'] }
};

// ─── REGIONS BY DIRECTION (BS Ch.14 Slokas 2-31) ────────────────────────────
// Comprehensive list of ancient regions with modern approximations where possible

export const KURMA_REGIONS = {
  C: {
    ancient: ['Bhadra', 'Arimeda', 'Mandavya', 'Salwa', 'Kuru', 'Panchala', 'Mathura', 'Surasena',
              'Vatsa', 'Ayodhya', 'Hastinapura', 'Madhyamika', 'Pariyatra mountain', 'Kapisthala',
              'Guda', 'Udumbara', 'Dharmaranya', 'Upajyotisha', 'Gouragriva'],
    modern: ['North-Central India', 'UP', 'Haryana', 'Delhi-NCR', 'Rajasthan (east)'],
    kingDestroyed: 'Panchala'  // Ch.14 Sl.32
  },
  E: {
    ancient: ['Magadha', 'Mithila', 'Samathata', 'Orissa', 'Pragjyotisha', 'Bhadra', 'Gauda',
              'Paundra', 'Utkala', 'Kasi', 'Mekala', 'Ambastha', 'Tamralipta', 'Kosala', 'Burdwan'],
    modern: ['Bihar', 'Bengal', 'Odisha', 'Assam', 'Jharkhand', 'Eastern UP'],
    kingDestroyed: 'Magadha'
  },
  SE: {
    ancient: ['Kosala', 'Kalinga', 'Vanga', 'Vidarbha', 'Vatsa', 'Andhra', 'Chedi', 'Tripuri',
              'Kishkindha', 'Dasarna', 'naked Sabaras', 'Purika'],
    modern: ['Andhra Pradesh', 'Telangana', 'Vidarbha', 'Chhattisgarh', 'Coastal Odisha'],
    kingDestroyed: 'Kalinga'
  },
  S: {
    ancient: ['Lanka', 'Kerala', 'Karnatic', 'Chola', 'Kaveri', 'Konkana', 'Bharukachcha',
              'Nasik', 'Vanavasi', 'Dandaka forest', 'Kanchi', 'Simhala', 'Tamraparni'],
    modern: ['Tamil Nadu', 'Kerala', 'Karnataka', 'Sri Lanka', 'Goa', 'Maharashtra (south)'],
    kingDestroyed: 'Avantee'
  },
  SW: {
    ancient: ['Pahlava', 'Kamboja', 'Sindhu-Sauveera', 'Anarta', 'Yavana', 'Barbara', 'Kirata',
              'Abheera', 'Dravida', 'Saurashtra', 'Raivatakas', 'great ocean'],
    modern: ['Gujarat', 'Sindh', 'Baluchistan', 'Western coast', 'Arabian peninsula contacts'],
    kingDestroyed: 'Anarta'
  },
  W: {
    ancient: ['Aparanthaka', 'Haihayas', 'Punjab (partial)', 'Ramatha', 'Parata', 'Vokkana',
              'Gold Scythians', 'western barbarians'],
    modern: ['Western India', 'Western Pakistan', 'Iran borderlands'],
    kingDestroyed: 'Sindhusauveera'
  },
  NW: {
    ancient: ['Mandavya', 'Tushara', 'Madra', 'Asmaka', 'Kuluta', 'Halada', 'kingdom of Women',
              'Saulika', 'Charmaranga'],
    modern: ['Punjab', 'Himachal', 'Kashmir (south)', 'Afghanistan (east)'],
    kingDestroyed: 'Harahura'
  },
  N: {
    ancient: ['Kailasa', 'Himalaya', 'Kuru', 'Kekaya', 'Arjunayana', 'Trigarta', 'Taxila',
              'Gandhara', 'Pushkalavata', 'Madra', 'Malwa', 'Parava', 'Huna', 'Kohala',
              'Yaudheya', 'Dasamya'],
    modern: ['Kashmir', 'Ladakh', 'Pakistan north', 'Afghanistan', 'Central Asia'],
    kingDestroyed: 'Madra'
  },
  NE: {
    ancient: ['Meruka', 'Keera', 'Kashmir', 'Abhisara', 'Darada', 'Tangana', 'Kuluta',
              'Brahmapura', 'Kirata', 'China', 'Kauninda', 'Bhalla', 'Patola', 'Kunata',
              'Khasa'],
    modern: ['Tibet', 'Nepal', 'NE India', 'China (west)', 'Bhutan'],
    kingDestroyed: 'Kuninda'
  }
};

// ─── GRAHA BHAKTIYOGA: PLANET DOMAIN MAPPINGS ────────────────────────────────
// BS Ch.16 Slokas 1-39

export const GRAHA_DOMAINS = {
  Sun: {
    regions: ['Eastern Narmada', 'Sone', 'Orissa', 'Vanga', 'Kalinga', 'Balkh', 'Magadha',
              'Sabaras', 'Pragjyotisha', 'China', 'Kamboja', 'Mekala', 'Kirata', 'Pulindas',
              'Dravida (east)', 'south bank of Jumna', 'Champa', 'Chedi', 'Pundra'],
    peoples: ['robbers', 'herdsmen', 'kings', 'evil-doers', 'thieves', 'serpents', 'heroes',
              'renowned men', 'cruel men', 'marching chiefs'],
    things: ['seeds', 'husk-grain', 'pungent substances', 'jaggery', 'gold', 'fire', 'poison',
             'medicines', 'quadrupeds'],
    professions: ['physicians', 'ploughmen']
  },
  Moon: {
    regions: ['mountains', 'fortresses', 'Kosala', 'Bharukachcha', 'ocean', 'Romans',
              'Tocharians', 'Vanavasi', 'Tangana', 'Strirajya', 'ocean islands'],
    peoples: ['brahmins', 'beloved persons', 'lovers', 'young women', 'commandants',
              'agriculturists', 'sacrifice experts'],
    things: ['sweet things', 'flowers', 'fruits', 'water', 'salt', 'jewels', 'conch shells',
             'pearls', 'aquatic products', 'rice', 'barley', 'herbs', 'wheat', 'white objects',
             'horses', 'horned animals', 'clothes'],
    professions: ['kings']
  },
  Mars: {
    regions: ['Western Sone', 'Narmada', 'Godavari', 'Ganges', 'Sindhu', 'Uttara Pandya',
              'Vindhya', 'Chola', 'Dravida', 'Videha', 'Andhra', 'Asmaka', 'Konkana',
              'Kuntala', 'Kerala', 'Dandaka', 'Mlechchas', 'Nassik', 'Virata'],
    peoples: ['townspeople', 'warriors', 'foresters', 'slayers', 'arrogant fellows', 'kings',
              'boys', 'hypocrites', 'infanticides', 'shepherds', 'cruel men', 'thieves', 'rogues'],
    things: ['red fruits', 'red flowers', 'coral', 'jaggery', 'toddy', 'treasury',
             'elephants', 'fortresses'],
    professions: ['agriculturists', 'generals', 'sacred-fire keepers', 'Buddhist monks']
  },
  Mercury: {
    regions: ['Lohitya river', 'Indus', 'Sarayu', 'Ganges', 'Kausikee', 'Videha', 'Kamboja',
              'eastern Muttra', 'Himalaya region', 'Gomanta', 'Saurashtra'],
    peoples: ['cavern-dwellers', 'hillmen', 'infants', 'poets', 'imposters', 'tale-bearers',
              'eunuchs', 'buffoons', 'policemen'],
    things: ['merchandise', 'water-reservoirs', 'ghee', 'oil', 'oil-seeds', 'bitter substances',
             'mules', 'gems', 'dyes', 'perfumes'],
    professions: ['mechanics', 'songsters', 'copyists', 'painters', 'grammarians',
                  'mathematicians', 'artisans', 'spies', 'jugglers', 'actors', 'dancers',
                  'chemists', 'exorcisers', 'envoys']
  },
  Jupiter: {
    regions: ['eastern Indus', 'western Muttra', 'Bharata', 'Sauveera', 'Srughna', 'Northerners',
              'Vipasa river', 'Satadru', 'Salvva', 'Trigarta', 'Parava', 'Ambastha', 'Parata',
              'Yaudheya', 'Saraswata', 'Arjunayana', 'rural Mathsya'],
    peoples: ['kings', 'ministers', 'compassionate men', 'truthful men', 'pure men', 'pious men',
              'learned men', 'charitable men', 'righteous men', 'citizens', 'rich men'],
    things: ['elephants', 'horses', 'benzoin', 'costus', 'jatamansi', 'quicksilver',
             'Saindhava salt', 'beans', 'sweet juices', 'beeswax', 'royal equipment',
             'umbrellas', 'banners', 'chowries'],
    professions: ['royal priests', 'tonic-makers', 'grammarians', 'philologists',
                  'vedic scholars', 'exorcisers', 'politicians']
  },
  Venus: {
    regions: ['Taxila', 'Gandhara', 'Pushkalavata', 'Malwa', 'Kaikaya', 'Dasarna', 'Useenara',
              'Sibi', 'banks of Vitasta/Iravatee/Chandrabhaga'],
    peoples: ['wealthy men', 'renowned persons', 'happy persons', 'generous persons',
              'charming persons', 'scholars', 'ministers', 'merchants'],
    things: ['chariots', 'silver-mines', 'elephants', 'horses', 'fragrant things', 'flowers',
             'unguents', 'gems', 'diamonds', 'ornaments', 'lotuses', 'couches', 'aphrodisiacs',
             'silk', 'wool', 'sandalwood', 'nutmeg', 'Agaru'],
    professions: ['elephant-drivers', 'potters', 'good brides-grooms']
  },
  Saturn: {
    regions: ['Anarta', 'Arbuda', 'Pushkara', 'Saurashtra', 'Abheera', 'Raivatakas',
              'western country', 'Thaneswar', 'Prabhasa', 'Vidisa', 'Mahee river banks'],
    peoples: ['Sudras', 'rogues', 'dirty fellows', 'unrighteous men', 'cowards', 'eunuchs',
              'fishers', 'deformed persons', 'old men', 'swine-herds', 'poor men',
              'Sabaras', 'Pulindas', 'widows'],
    things: ['pungent things', 'bitter things', 'tonics', 'snakes', 'she-buffaloes', 'donkeys',
             'Bengal gram', 'flatulence-causing grains'],
    professions: ['oil-mongers', 'jailers', 'prisoners', 'fowlers', 'company foremen']
  },
  Rahu: {
    regions: ['mountain-peaks', 'dens', 'caves'],
    peoples: ['barbarian tribes', 'Sudras', 'jackal-eaters', 'Kinnaras', 'crippled persons',
              'evil-doers', 'ungrateful men', 'thieves', 'spies', 'wrathful persons',
              'children in womb', 'low people', 'hypocrites', 'giants', 'lawless men'],
    things: ['donkeys', 'black gram', 'sesamum'],
    professions: ['duelists']
  },
  Ketu: {
    regions: ['mountain-strongholds', 'Pahlava', 'Huns', 'Chola', 'Afghans', 'desert', 'China'],
    peoples: ['rich men', 'highly ambitious persons', 'energetic men', 'adulterers',
              'disputants', 'pride-elated', 'fools', 'unrighteous people', 'conquest-seekers'],
    things: [],
    professions: ['cavemen']
  }
};

// ─── FUNCTIONS ───────────────────────────────────────────────────────────────

/**
 * Get the Kurma direction for a nakshatra.
 * @param {string} nakshatraName
 * @returns {{ direction: string, directionName: string, regions: Object } | null}
 */
export function getKurmaDirection(nakshatraName) {
  for (const [dir, data] of Object.entries(KURMA_DIRECTIONS)) {
    if (data.nakshatras.includes(nakshatraName)) {
      return {
        direction: dir,
        directionName: data.name,
        regions: KURMA_REGIONS[dir]
      };
    }
  }
  return null;
}

/**
 * Get all regions affected by a planet being malefic/afflicted.
 * Combines Kurma (nakshatra-based) and Graha Bhaktiyoga (planet-based) targeting.
 *
 * @param {string} planet
 * @param {string} [nakshatra] - Current nakshatra of the planet
 * @returns {{ planetRegions: Object, nakshatraRegions: Object|null, combined: string[] }}
 */
export function getAffectedRegions(planet, nakshatra) {
  const planetDomains = GRAHA_DOMAINS[planet] || { regions: [], peoples: [], things: [] };
  const nakshatraRegions = nakshatra ? getKurmaDirection(nakshatra) : null;

  // Combine unique region names
  const combined = [...new Set([
    ...planetDomains.regions,
    ...(nakshatraRegions?.regions?.ancient || []),
    ...(nakshatraRegions?.regions?.modern || [])
  ])];

  return {
    planetRegions: planetDomains,
    nakshatraRegions,
    combined
  };
}

/**
 * Get the peoples/professions affected when a planet is malefic.
 * BS Ch.16: "The more any planet is stricken, the more will he ruin
 * all that belongs to his department." (Ch.17 Sl.27)
 *
 * @param {string} planet
 * @returns {{ peoples: string[], things: string[], professions: string[] }}
 */
export function getAffectedDependants(planet) {
  const domains = GRAHA_DOMAINS[planet];
  if (!domains) return { peoples: [], things: [], professions: [] };
  return {
    peoples: domains.peoples || [],
    things: domains.things || [],
    professions: domains.professions || []
  };
}

/**
 * Map an eclipse to affected regions based on the sign where it occurs.
 * BS Ch.5 Slokas 35-42
 *
 * @param {string} sign - Zodiac sign of eclipse
 * @returns {{ peoples: string[], regions: string[] }}
 */
export function getEclipseSignRegions(sign) {
  const ECLIPSE_SIGN_MAP = {
    Aries:       { peoples: ['Panchala', 'Kalinga', 'Surasena', 'Kamboja', 'Orissa', 'hunters', 'military', 'fire-workers'] },
    Taurus:      { peoples: ['shepherds', 'cattle', 'cow-owners', 'men of eminence'] },
    Gemini:      { peoples: ['ladies of nobility', 'kings', 'powerful ministers', 'artists', 'Jumna people', 'Balkh', 'Virata'] },
    Cancer:      { peoples: ['Abheera', 'Sabara', 'Pallava', 'Malla', 'Mathsya', 'Kuru', 'Saka', 'Panchala', 'infirm people'], things: ['food grains'] },
    Leo:         { peoples: ['hunters', 'Mekala', 'valorous people', 'kings', 'forest-dwellers'] },
    Virgo:       { peoples: ['poets', 'writers', 'musicians', 'Asmaka', 'Tripura'], things: ['crops', 'paddy'] },
    Libra:       { peoples: ['Avanti', 'Aparanthya', 'trading class', 'Dasarna', 'Maru', 'Kachchapa'] },
    Scorpio:     { peoples: ['Udumbara', 'Madra', 'Chola', 'Yaudheya', 'soldiers'], things: ['trees'] },
    Sagittarius: { peoples: ['chief ministers', 'Videha', 'wrestlers', 'Panchala', 'physicians', 'traders'], things: ['horses'] },
    Capricorn:   { peoples: ['ministers and families', 'lower class', 'magic users', 'old-infirm'], things: ['fishes', 'weapons'] },
    Aquarius:    { peoples: ['mountain-interior people', 'western people', 'burden-bearers', 'thieves', 'Abheera', 'Darada', 'nobles', 'Simhapura', 'Barbara'] },
    Pisces:      { peoples: ['ocean-shore people', 'forest-dwellers', 'learned men', 'water-product workers'] }
  };

  return ECLIPSE_SIGN_MAP[sign] || { peoples: [], regions: [] };
}

/**
 * Get the king/ruler destroyed when a directional group's nakshatras are hurt.
 * BS Ch.14 Slokas 32-33
 *
 * @param {string} direction - One of C, E, SE, S, SW, W, NW, N, NE
 * @returns {string|null} - Name of kingdom whose king is destroyed
 */
export function getKingDestroyed(direction) {
  return KURMA_REGIONS[direction]?.kingDestroyed || null;
}
