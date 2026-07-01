/**
 * शनि — Saturn Transit & Observation Rules
 * Source: Brihat Samhita Ch.10 (Sanaischara Chara)
 *
 * Saturn uses a CLEAN NAKSHATRA LOOKUP TABLE — each of the 27 nakshatras
 * has specific peoples, regions, and commodities affected when Saturn transits.
 *
 * Additionally:
 *   - Nakshatra-group water rules (Sl.1-2)
 *   - Jupiter-Saturn conjunction (Sl.19)
 *   - Saturn color/appearance rules (Sl.20-21)
 *
 * Effect structure: { domain, dir, desc, weight, planet, sign, ruleId, source, category, manifestation }
 */

// ─── 27-NAKSHATRA TRANSIT TABLE ──────────────────────────────────────────────
// BS Ch.10 Slokas 3-18
// Each entry: peoples/things that suffer when Saturn transits that nakshatra.
// "dir" is 'neg' for most (Saturn harms its dependencies) except Dhanishta.

export const SATURN_NAKSHATRA_TABLE = {
  Aswini: {
    affected: ['horses', 'horse-grooms', 'poets', 'physicians', 'ministers'],
    domain: 'governance',
    dir: 'neg',
    desc: 'Horses, grooms, poets, physicians, and ministers suffer',
    weight: 0.7,
    source: 'BS Ch.10 Sl.3'
  },
  Bharani: {
    affected: ['dancers', 'songsters', 'musicians', 'base men'],
    domain: 'society',
    dir: 'neg',
    desc: 'Dancers, songsters, musicians, and base men suffer',
    weight: 0.65,
    source: 'BS Ch.10 Sl.3'
  },
  Krittika: {
    affected: ['fire-workers', 'commandants'],
    domain: 'security',
    dir: 'neg',
    desc: 'Fire-workers and commandants are afflicted',
    weight: 0.7,
    source: 'BS Ch.10 Sl.4'
  },
  Rohini: {
    affected: ['Kosala', 'Madra', 'Kasi', 'Panchala', 'cartmen'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Kosala, Madra, Kasi, Panchala regions and cartmen are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.4',
    regions: ['Kosala', 'Madra', 'Kasi', 'Panchala']
  },
  Mrigasira: {
    affected: ['Vatsa', 'priests', 'nobility', 'central countries'],
    domain: 'governance',
    dir: 'neg',
    desc: 'Vatsa, priests, nobility, and central countries are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.5',
    regions: ['Vatsa', 'central countries']
  },
  Ardra: {
    affected: ['Paratas', 'Ramathas', 'oil-mongers', 'washermen', 'robbers'],
    domain: 'society',
    dir: 'neg',
    desc: 'Paratas, Ramathas, oil-mongers, washermen, and robbers are afflicted',
    weight: 0.65,
    source: 'BS Ch.10 Sl.5',
    regions: ['Paratas', 'Ramathas']
  },
  Punarvasu: {
    affected: ['Punjab', 'western tracts', 'Surashtra', 'Sindhu', 'Suveera'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Punjab, western tracts, Surashtra, Sindhu, and Suveera regions are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.6',
    regions: ['Punjab', 'Surashtra', 'Sindhu', 'Suveera']
  },
  Pushya: {
    affected: ['bell-ringers', 'Yavanas', 'traders', 'gamblers', 'flowers'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Bell-ringers, Yavanas, traders, gamblers, and flower-sellers are afflicted',
    weight: 0.7,
    source: 'BS Ch.10 Sl.6'
  },
  Aslesha: {
    affected: ['aquatic animals', 'serpents'],
    domain: 'environment',
    dir: 'neg',
    desc: 'Aquatic animals and serpents are afflicted',
    weight: 0.6,
    source: 'BS Ch.10 Sl.7'
  },
  Magha: {
    affected: ['Bahleekas', 'Chinese', 'Kandaharis', 'Sulikas', 'Vaisyas', 'traders'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Bahleekas, Chinese, Kandaharis, Sulikas, Vaisyas, and traders are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.7',
    regions: ['Bahleekas', 'China', 'Kandahar', 'Sulika']
  },
  Purvaphalguni: {
    affected: ['juice-vendors', 'courtesans', 'virgins', 'Maharashtras'],
    domain: 'society',
    dir: 'neg',
    desc: 'Juice-vendors, courtesans, virgins, and Maharashtras are afflicted',
    weight: 0.65,
    source: 'BS Ch.10 Sl.8',
    regions: ['Maharashtra']
  },
  Uttaraphalguni: {
    affected: ['kings', 'jaggery', 'salt', 'mendicants', 'water', 'Taxila people'],
    domain: 'governance',
    dir: 'neg',
    desc: 'Kings, jaggery, salt, mendicants, water supply, and Taxila people are afflicted',
    weight: 0.8,
    source: 'BS Ch.10 Sl.8',
    regions: ['Taxila']
  },
  Hasta: {
    affected: ['barbers', 'potters', 'oil-mongers', 'thieves', 'physicians', 'tailors', 'Kosala', 'garland-makers'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Barbers, potters, oil-mongers, thieves, physicians, tailors, Kosala, and garland-makers are afflicted',
    weight: 0.7,
    source: 'BS Ch.10 Sl.9',
    regions: ['Kosala']
  },
  Chitra: {
    affected: ['young women', 'writers', 'painters', 'coloured pots'],
    domain: 'society',
    dir: 'neg',
    desc: 'Young women, writers, painters, and makers of coloured pots are afflicted',
    weight: 0.6,
    source: 'BS Ch.10 Sl.9'
  },
  Swati: {
    affected: ['panegyrists', 'spies', 'couriers', 'charioteers', 'sailors', 'dancers'],
    domain: 'security',
    dir: 'neg',
    desc: 'Panegyrists, spies, couriers, charioteers, sailors, and dancers are afflicted',
    weight: 0.65,
    source: 'BS Ch.10 Sl.10'
  },
  Visakha: {
    affected: ['Trigarta', 'Chinese', 'Kuluta', 'saffron', 'lac', 'crops'],
    domain: 'agriculture',
    dir: 'neg',
    desc: 'Trigarta, Chinese, Kuluta regions; saffron, lac, and crops are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.10',
    regions: ['Trigarta', 'China', 'Kuluta']
  },
  Anuradha: {
    affected: ['Kuluta', 'Thangana', 'Khasa', 'Kashmir', 'ministers', 'potters'],
    domain: 'governance',
    dir: 'neg',
    desc: 'Kuluta, Thangana, Khasa, Kashmir, ministers, and potters are afflicted; discord among friends',
    weight: 0.75,
    source: 'BS Ch.10 Sl.11',
    regions: ['Kuluta', 'Thangana', 'Khasa', 'Kashmir'],
    specialNote: 'Discord among friends'
  },
  Jyeshta: {
    affected: ['kings', 'priests', 'heroes', 'associations', 'guilds', 'Kasi'],
    domain: 'governance',
    dir: 'neg',
    desc: 'Kings, priests, heroes, associations, guilds, and Kasi are afflicted',
    weight: 0.8,
    source: 'BS Ch.10 Sl.11',
    regions: ['Kasi']
  },
  Moola: {
    affected: ['Kosala', 'Panchala', 'fruits', 'herbs', 'warriors'],
    domain: 'security',
    dir: 'neg',
    desc: 'Kosala, Panchala, fruits, herbs, and warriors are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.12',
    regions: ['Kosala', 'Panchala']
  },
  Purvashadha: {
    affected: ['Anga', 'Vanga', 'Kosala', 'Girivraja', 'Magadha', 'Pundra', 'Mithila', 'Tamralipta'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Anga, Vanga, Kosala, Girivraja, Magadha, Pundra, Mithila, and Tamralipta regions are afflicted',
    weight: 0.8,
    source: 'BS Ch.10 Sl.12-13',
    regions: ['Anga', 'Vanga', 'Kosala', 'Girivraja', 'Magadha', 'Pundra', 'Mithila', 'Tamralipta']
  },
  Uttarashadha: {
    affected: ['Dasarna', 'Yavanas', 'Ujjain', 'Sabaras', 'Pariyatra', 'Kuntibhojas'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Dasarna, Yavanas, Ujjain, Sabaras, Pariyatra, and Kuntibhojas are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.13',
    regions: ['Dasarna', 'Ujjain', 'Pariyatra', 'Kuntibhojas']
  },
  Sravana: {
    affected: ['king\'s officers', 'leading Brahmins', 'physicians', 'priests', 'Kalinga'],
    domain: 'governance',
    dir: 'neg',
    desc: 'King\'s officers, leading Brahmins, physicians, priests, and Kalinga are afflicted',
    weight: 0.75,
    source: 'BS Ch.10 Sl.14',
    regions: ['Kalinga']
  },
  Dhanishta: {
    affected: ['Magadha king', 'usurers'],
    domain: 'governance',
    dir: 'pos',
    desc: 'Victory to the Magadha king; prosperity to usurers — POSITIVE transit',
    weight: 0.7,
    source: 'BS Ch.10 Sl.14',
    regions: ['Magadha']
  },
  Satabhishak: {
    affected: ['physicians', 'poets', 'toddy-distillers', 'traders', 'politicians'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Physicians, poets, toddy-distillers, traders, and politicians are afflicted',
    weight: 0.65,
    source: 'BS Ch.10 Sl.15'
  },
  Purvabhadra: {
    affected: ['physicians', 'poets', 'toddy-distillers', 'traders', 'politicians'],
    domain: 'economy',
    dir: 'neg',
    desc: 'Grouped with Satabhishak — physicians, poets, toddy-distillers, traders, and politicians are afflicted',
    weight: 0.65,
    source: 'BS Ch.10 Sl.15',
    note: 'Grouped with Satabhishak'
  },
  Uttarabhadra: {
    affected: ['river-bank dwellers', 'cart-wrights', 'women', 'gold'],
    domain: 'society',
    dir: 'neg',
    desc: 'River-bank dwellers, cart-wrights, women, and gold are afflicted',
    weight: 0.65,
    source: 'BS Ch.10 Sl.16'
  },
  Revati: {
    affected: ['king\'s servants', 'Krauncha island', 'autumnal crops', 'Sabaras', 'Yavanas'],
    domain: 'agriculture',
    dir: 'neg',
    desc: 'King\'s servants, Krauncha island, autumnal crops, Sabaras, and Yavanas are afflicted',
    weight: 0.7,
    source: 'BS Ch.10 Sl.16-17',
    regions: ['Krauncha', 'Sabara', 'Yavana']
  }
};

// ─── NAKSHATRA-GROUP WATER RULES ─────────────────────────────────────────────
// BS Ch.10 Slokas 1-2
// Saturn's appearance (glossy/healthy) in certain nakshatra groups governs water.

export const SATURN_WATER_GROUPS = [
  {
    nakshatras: ['Sravana', 'Swati', 'Hasta', 'Ardra', 'Bharani', 'Purvaphalguni'],
    condition: 'glossy',
    domain: 'weather',
    dir: 'pos',
    desc: 'Glossy Saturn in these nakshatras — plenty of water and good rains',
    weight: 0.75,
    ruleId: 'shani_water_plenty',
    source: 'BS Ch.10 Sl.1'
  },
  {
    nakshatras: ['Aslesha', 'Satabhishak', 'Jyeshta'],
    condition: 'glossy',
    domain: 'society',
    dir: 'pos',
    desc: 'Glossy Saturn in these nakshatras — general happiness, though rain not plentiful',
    weight: 0.6,
    ruleId: 'shani_water_happiness',
    source: 'BS Ch.10 Sl.1-2'
  },
  {
    nakshatras: ['Moola'],
    condition: 'any',
    domain: 'agriculture',
    dir: 'neg',
    desc: 'Saturn in Moola — famine, war, and drought afflict the land',
    weight: 0.85,
    ruleId: 'shani_moola_famine',
    source: 'BS Ch.10 Sl.2'
  }
];

// ─── JUPITER-SATURN CONJUNCTION RULES ────────────────────────────────────────
// BS Ch.10 Sloka 19

export const JUPITER_SATURN_CONJUNCTIONS = [
  {
    jupiter: 'Visakha',
    saturn: 'Krittika',
    domain: 'society',
    dir: 'neg',
    desc: 'Jupiter in Visakha with Saturn in Krittika — terrible calamity befalls the land',
    weight: 0.95,
    ruleId: 'shani_guru_visakha_krittika',
    source: 'BS Ch.10 Sl.19'
  },
  {
    condition: 'same_star',
    domain: 'security',
    dir: 'neg',
    desc: 'Jupiter and Saturn in the same nakshatra — civil feuds erupt in cities',
    weight: 0.8,
    ruleId: 'shani_guru_same_star',
    source: 'BS Ch.10 Sl.19'
  }
];

// ─── SATURN COLOR / APPEARANCE RULES ─────────────────────────────────────────
// BS Ch.10 Slokas 20-21

export const SATURN_COLOR_EFFECTS = {
  variegated:  { domain: 'environment', dir: 'neg', desc: 'Birds are destroyed',                          weight: 0.6 },
  yellow_rays: { domain: 'agriculture', dir: 'neg', desc: 'Famine in the land',                           weight: 0.8 },
  'blood-red': { domain: 'security',    dir: 'neg', desc: 'War and armed conflict',                       weight: 0.8 },
  ashy:        { domain: 'society',     dir: 'neg', desc: 'Strife and social discord',                    weight: 0.7 },
  bright_beryl:{ domain: 'society',     dir: 'pos', desc: 'General happiness and well-being',             weight: 0.7 },
  jet_black:   { domain: 'society',     dir: 'pos', desc: 'Auspicious — natural color of Saturn',         weight: 0.65 },
  deep_blue:   { domain: 'society',     dir: 'pos', desc: 'Auspicious and favorable conditions',          weight: 0.65 }
};

// ─── SATURN COLOR → CASTE MAPPING ────────────────────────────────────────────
// BS Ch.10 Sloka 21

export const SATURN_COLOR_VARNA = {
  white:  { varna: 'Brahmins',   domain: 'religion',   desc: 'Brahmins (priestly class) suffer',        weight: 0.65 },
  red:    { varna: 'Kshatriyas', domain: 'governance',  desc: 'Kshatriyas (warrior/ruling class) suffer', weight: 0.65 },
  yellow: { varna: 'Vaisyas',    domain: 'economy',     desc: 'Vaisyas (merchant class) suffer',         weight: 0.65 },
  dark:   { varna: 'Sudras',     domain: 'society',     desc: 'Sudras (laboring class) suffer',          weight: 0.65 }
};

// ─── HELPER: Build an Effect object ──────────────────────────────────────────

/**
 * Create a standardized Effect object for a Saturn rule.
 * @param {Object} params
 * @param {string} params.domain
 * @param {string} params.dir
 * @param {string} params.desc
 * @param {number} params.weight
 * @param {string} params.ruleId
 * @param {string} params.source
 * @param {string} [params.category]
 * @param {string} [params.manifestation]
 * @param {string} [params.sign]
 * @returns {Object} Effect
 */
function makeEffect({ domain, dir, desc, weight, ruleId, source, category = 'saturn_transit', manifestation, sign = null }) {
  return {
    domain,
    dir,
    desc,
    weight: Math.min(1, Math.max(0, weight)),
    planet: 'Saturn',
    sign,
    ruleId,
    source,
    category,
    manifestation: manifestation || null
  };
}

// ─── NAKSHATRA LOOKUP (standalone) ───────────────────────────────────────────

/**
 * Get the Saturn transit effect for a specific nakshatra.
 * Pure lookup — no sky state required.
 *
 * @param {string} nakshatra - One of the 27 standard nakshatra names
 * @returns {Object|null} Effect object, or null if nakshatra not found
 */
export function getSaturnNakshatraEffect(nakshatra) {
  const entry = SATURN_NAKSHATRA_TABLE[nakshatra];
  if (!entry) return null;

  return makeEffect({
    domain: entry.domain,
    dir: entry.dir,
    desc: `Saturn transits ${nakshatra} — ${entry.desc}`,
    weight: entry.weight,
    ruleId: `shani_nakshatra_${nakshatra.toLowerCase().replace(/\s+/g, '_')}`,
    source: entry.source,
    manifestation: entry.affected.join(', ')
  });
}

// ─── MAIN EVALUATOR ──────────────────────────────────────────────────────────

/**
 * Evaluate all Saturn observation and transit rules from Brihat Samhita Ch.10.
 *
 * @param {Object} skyState - Current sky state
 * @param {Object} skyState.positions - Planetary positions (must include Saturn; optionally Jupiter)
 * @param {string} skyState.positions.Saturn.nakshatra - Saturn's current nakshatra
 * @param {string} [skyState.positions.Saturn.sign] - Saturn's current sign (for metadata)
 * @param {string} [skyState.positions.Jupiter.nakshatra] - Jupiter's current nakshatra (for conjunction)
 * @param {Object} saturnContext - Additional observation context
 * @param {string} [saturnContext.color] - Observed color/appearance (e.g. 'blood-red', 'jet_black', 'variegated')
 * @param {string} [saturnContext.rayColor] - Ray color for caste mapping (e.g. 'white', 'red', 'yellow', 'dark')
 * @param {boolean} [saturnContext.isGlossy] - Whether Saturn appears glossy/healthy
 * @returns {Object[]} Array of Effect objects
 */
export function evaluateSaturn(skyState, saturnContext = {}) {
  const effects = [];

  const saturnPos = skyState?.positions?.Saturn;
  if (!saturnPos) return effects;

  const saturnNak = saturnPos.nakshatra;
  const saturnSign = saturnPos.sign || null;
  const jupiterPos = skyState?.positions?.Jupiter;

  // ── 1. NAKSHATRA TRANSIT EFFECTS (Sl.3-18) ────────────────────────────
  if (saturnNak) {
    const nakEffect = getSaturnNakshatraEffect(saturnNak);
    if (nakEffect) {
      // Attach sign metadata if available
      nakEffect.sign = saturnSign;
      effects.push(nakEffect);
    }
  }

  // ── 2. NAKSHATRA-GROUP WATER RULES (Sl.1-2) ──────────────────────────
  if (saturnNak) {
    for (const group of SATURN_WATER_GROUPS) {
      if (group.nakshatras.includes(saturnNak)) {
        // Moola group fires regardless; other groups require glossy appearance
        if (group.condition === 'any' || (group.condition === 'glossy' && saturnContext.isGlossy)) {
          effects.push(makeEffect({
            domain: group.domain,
            dir: group.dir,
            desc: `Saturn in ${saturnNak} — ${group.desc}`,
            weight: group.weight,
            ruleId: group.ruleId,
            source: group.source,
            sign: saturnSign
          }));
        }
      }
    }
  }

  // ── 3. JUPITER-SATURN CONJUNCTION RULES (Sl.19) ───────────────────────
  if (jupiterPos?.nakshatra && saturnNak) {
    const jupNak = jupiterPos.nakshatra;

    // Check specific Visakha-Krittika combination
    const specificRule = JUPITER_SATURN_CONJUNCTIONS[0];
    if (jupNak === specificRule.jupiter && saturnNak === specificRule.saturn) {
      effects.push(makeEffect({
        domain: specificRule.domain,
        dir: specificRule.dir,
        desc: specificRule.desc,
        weight: specificRule.weight,
        ruleId: specificRule.ruleId,
        source: specificRule.source,
        sign: saturnSign,
        category: 'saturn_jupiter_conjunction'
      }));
    }

    // Check same-star conjunction
    if (jupNak === saturnNak) {
      const sameStarRule = JUPITER_SATURN_CONJUNCTIONS[1];
      effects.push(makeEffect({
        domain: sameStarRule.domain,
        dir: sameStarRule.dir,
        desc: `Jupiter and Saturn both in ${saturnNak} — ${sameStarRule.desc}`,
        weight: sameStarRule.weight,
        ruleId: sameStarRule.ruleId,
        source: sameStarRule.source,
        sign: saturnSign,
        category: 'saturn_jupiter_conjunction'
      }));
    }
  }

  // ── 4. COLOR / APPEARANCE RULES (Sl.20-21) ────────────────────────────
  if (saturnContext.color) {
    const colorEffect = SATURN_COLOR_EFFECTS[saturnContext.color];
    if (colorEffect) {
      effects.push(makeEffect({
        domain: colorEffect.domain,
        dir: colorEffect.dir,
        desc: `Saturn appears ${saturnContext.color} — ${colorEffect.desc}`,
        weight: colorEffect.weight,
        ruleId: `shani_color_${saturnContext.color}`,
        source: 'BS Ch.10 Sl.20-21',
        sign: saturnSign,
        category: 'saturn_observation'
      }));
    }
  }

  // ── 5. RAY COLOR → CASTE MAPPING (Sl.21) ──────────────────────────────
  if (saturnContext.rayColor) {
    const varnaEffect = SATURN_COLOR_VARNA[saturnContext.rayColor];
    if (varnaEffect) {
      effects.push(makeEffect({
        domain: varnaEffect.domain,
        dir: 'neg',
        desc: `Saturn with ${saturnContext.rayColor} rays — ${varnaEffect.desc}`,
        weight: varnaEffect.weight,
        ruleId: `shani_varna_${saturnContext.rayColor}`,
        source: 'BS Ch.10 Sl.21',
        sign: saturnSign,
        category: 'saturn_observation',
        manifestation: varnaEffect.varna
      }));
    }
  }

  return effects;
}
