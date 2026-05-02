/**
 * सूर्य — Sun Visual Observation Rules
 * Source: Brihat Samhita Ch.3 (Aditya Chara)
 *
 * CRITICAL DISTINCTION: The Sun chapter uses NO zodiac signs, NO nakshatras.
 * ALL predictions are based on VISUAL OBSERVATION of the solar disc:
 *   - Color of the disc
 *   - Presence, shape, number, color of sunspots (Thamasa Keelakas)
 *   - Ray quality (sharp vs soft) and ray color
 *   - Disc shape anomalies (pot, broken, arch, umbrella)
 *   - Mock-sun (parhelion) position
 *   - Halo phenomena
 *
 * The RITU (season) is the only astronomical context required,
 * because the Sun's natural color changes with the season.
 *
 * Effect structure: { domain, dir, desc, weight, planet, sign, ruleId, source, category, manifestation }
 */

// ─── RITU (SEASON) DEFINITIONS ──────────────────────────────────────────────
// BS Ch.3 Slokas 23-24: Each season has a natural baseline color.
// When the Sun displays its natural color, it is AUSPICIOUS.
// Abnormal color = prediction triggered.

export const RITU_BASELINE_COLORS = {
  Sisira:   { color: 'copper',    months: ['Magha', 'Phalguna'],      desc: 'Late winter (Jan-Mar)' },
  Vasantha: { color: 'saffron',   months: ['Chaitra', 'Vaisakha'],    desc: 'Spring (Mar-May)' },
  Grishma:  { color: 'pale',      months: ['Jyeshta', 'Ashadha'],     desc: 'Summer (May-Jul)', altColor: 'golden' },
  Varsha:   { color: 'whitish',   months: ['Sravana', 'Bhadrapada'],  desc: 'Monsoon (Jul-Sep)' },
  Sarad:    { color: 'lotus',     months: ['Aswina', 'Kartika'],      desc: 'Autumn (Sep-Nov)' },
  Hemanta:  { color: 'blood-red', months: ['Margasira', 'Pushya'],    desc: 'Early winter (Nov-Jan)' }
};

// ─── THAMASA KEELAKA (SUNSPOT) SHAPE EFFECTS ────────────────────────────────
// BS Ch.3 Slokas 6-19

export const KEELAKA_SHAPE_EFFECTS = {
  stick:          { domain: 'governance',  dir: 'neg', desc: 'Death of the sovereign',               weight: 0.9 },
  headless_body:  { domain: 'health',      dir: 'neg', desc: 'Widespread diseases afflict the land',  weight: 0.8 },
  crow:           { domain: 'security',    dir: 'neg', desc: 'Thieves and robbers become rampant',    weight: 0.7 },
  wedge:          { domain: 'agriculture', dir: 'neg', desc: 'Famine and scarcity of food',           weight: 0.85 },
  flag:           { domain: 'security',    dir: 'neg', desc: 'Army mobilization and conflict',        weight: 0.7 },
  arrow:          { domain: 'security',    dir: 'neg', desc: 'Foreign attack threatens the land',     weight: 0.75 },
  trident:        { domain: 'governance',  dir: 'neg', desc: 'Strife among rulers',                   weight: 0.8 },
  serpent:        { domain: 'health',      dir: 'neg', desc: 'Poison and pestilence spread',          weight: 0.7 }
};

// ─── KEELAKA COUNT RULES ─────────────────────────────────────────────────────
// BS Ch.3 Slokas 6-7

export const KEELAKA_COUNT_EFFECTS = {
  1: { domain: 'agriculture', dir: 'neg', desc: 'Famine in the land',             weight: 0.8 },
  2: { domain: 'governance',  dir: 'neg', desc: 'Destruction of the sovereign',   weight: 0.9 },
  3: { domain: 'governance',  dir: 'neg', desc: 'Multiple rulers face downfall',  weight: 0.95 }
  // 2+ all trigger sovereign destruction; 3 listed for emphasis
};

// ─── KEELAKA COLOR → VARNA MAPPING ───────────────────────────────────────────
// BS Ch.3 Slokas 8-10: Color of the sunspot determines which caste suffers.

export const KEELAKA_COLOR_VARNA = {
  white:  { varna: 'Brahmins',   domain: 'religion',   desc: 'Brahmins (priests, scholars) suffer',     weight: 0.7 },
  red:    { varna: 'Kshatriyas', domain: 'governance',  desc: 'Kshatriyas (warriors, rulers) suffer',    weight: 0.7 },
  yellow: { varna: 'Vaisyas',    domain: 'economy',     desc: 'Vaisyas (merchants, traders) suffer',     weight: 0.7 },
  black:  { varna: 'Sudras',     domain: 'society',     desc: 'Sudras (laboring classes) suffer',        weight: 0.7 }
};

// ─── UPWARD RAY COLOR EFFECTS ────────────────────────────────────────────────
// BS Ch.3 Slokas 21-22

export const UPWARD_RAY_EFFECTS = {
  copper:     { domain: 'security',   dir: 'neg', desc: 'Ruin of the commander-in-chief',       weight: 0.8 },
  yellow:     { domain: 'governance', dir: 'neg', desc: 'Death of the king\'s son',             weight: 0.85 },
  white:      { domain: 'religion',   dir: 'neg', desc: 'Death of the royal preceptor',         weight: 0.8 },
  variegated: { domain: 'society',    dir: 'neg', desc: 'Chaos and confusion in the kingdom',   weight: 0.9 }
};

// ─── RAINY SEASON SHARP RAY EFFECTS ─────────────────────────────────────────
// BS Ch.3 Sloka 25: In Varsha (rainy season), sharp rays indicate caste suffering.
// BUT soft rays override everything to POSITIVE.

export const VARSHA_RAY_EFFECTS = {
  whitish:   { varna: 'Brahmins',   domain: 'religion',   desc: 'Brahmins face danger in rainy season',    weight: 0.65 },
  'blood-red': { varna: 'Kshatriyas', domain: 'governance', desc: 'Kshatriyas face danger in rainy season',  weight: 0.65 },
  yellow:    { varna: 'Vaisyas',    domain: 'economy',     desc: 'Vaisyas face danger in rainy season',     weight: 0.65 },
  black:     { varna: 'Sudras',     domain: 'society',     desc: 'Sudras face danger in rainy season',      weight: 0.65 }
};

// ─── SUN DISC ANOMALIES ──────────────────────────────────────────────────────
// BS Ch.3 Slokas 27-35

export const DISC_ANOMALY_EFFECTS = {
  pot:            { domain: 'agriculture', dir: 'neg', desc: 'Hunger and food scarcity prevail',       weight: 0.8 },
  broken:         { domain: 'society',     dir: 'neg', desc: 'People perish in great numbers',         weight: 0.9 },
  without_rays:   { domain: 'society',     dir: 'neg', desc: 'Universal fear grips the land',          weight: 0.85 },
  arch:           { domain: 'governance',  dir: 'neg', desc: 'Chief city of the kingdom is ruined',    weight: 0.85 },
  umbrella:       { domain: 'governance',  dir: 'neg', desc: 'Entire country faces destruction',       weight: 0.95 },
  blood_midsky:   { domain: 'governance',  dir: 'neg', desc: 'King faces destruction (blood-color at zenith)', weight: 0.9 },
  enlarged:       { domain: 'society',     dir: 'neg', desc: 'Portent of great calamity',              weight: 0.8 },
  trembling:      { domain: 'security',    dir: 'neg', desc: 'War and unrest approach',                weight: 0.75 }
};

// ─── MOCK-SUN (PARHELION) POSITION EFFECTS ───────────────────────────────────
// BS Ch.3 Slokas 33-35

export const MOCK_SUN_EFFECTS = {
  north: { domain: 'weather',     dir: 'pos', desc: 'Abundant rain from the north',            weight: 0.7 },
  south: { domain: 'weather',     dir: 'neg', desc: 'Floods and water calamity from the south', weight: 0.8 },
  above: { domain: 'governance',  dir: 'neg', desc: 'King faces grave danger from above',       weight: 0.85 },
  below: { domain: 'society',     dir: 'neg', desc: 'People perish — misfortune from below',    weight: 0.85 }
};

// ─── OUT-OF-SEASON COLOR ANOMALIES ───────────────────────────────────────────
// BS Ch.3 Sloka 26: Specific color+season mismatches with unique effects

export const OUT_OF_SEASON_ANOMALIES = [
  { season: 'Grishma',  color: 'blood-red', domain: 'security',    dir: 'neg', desc: 'Fear and danger in the summer',      weight: 0.75 },
  { season: 'Varsha',   color: 'dark',      domain: 'agriculture', dir: 'neg', desc: 'Drought despite the monsoon season', weight: 0.85 },
  { season: 'Hemanta',  color: 'yellowish',  domain: 'health',      dir: 'neg', desc: 'Diseases spread in early winter',   weight: 0.75 }
];

// ─── HELPER: Build an Effect object ──────────────────────────────────────────

/**
 * Create a standardized Effect object for a Sun observation rule.
 * @param {Object} params
 * @param {string} params.domain
 * @param {string} params.dir
 * @param {string} params.desc
 * @param {number} params.weight
 * @param {string} params.ruleId
 * @param {string} params.source
 * @param {string} [params.category]
 * @param {string} [params.manifestation]
 * @returns {Object} Effect
 */
function makeEffect({ domain, dir, desc, weight, ruleId, source, category = 'sun_observation', manifestation }) {
  return {
    domain,
    dir,
    desc,
    weight: Math.min(1, Math.max(0, weight)),
    planet: 'Sun',
    sign: null,  // Sun chapter never uses zodiac signs
    ruleId,
    source,
    category,
    manifestation: manifestation || null
  };
}

// ─── HELPER: Check if observed color matches season baseline ─────────────────

/**
 * Determine whether the observed Sun color matches the natural seasonal color.
 * @param {string} observedColor - Observed color of the Sun disc
 * @param {string} season - Current ritu (Sisira, Vasantha, Grishma, Varsha, Sarad, Hemanta)
 * @returns {boolean} True if color is natural/expected for this season
 */
/**
 * Season name normalization — accept both 'vasanta' and 'Vasantha' etc.
 */
const SEASON_ALIASES = {
  'vasanta': 'Vasantha', 'vasantha': 'Vasantha', 'spring': 'Vasantha',
  'grishma': 'Grishma', 'summer': 'Grishma',
  'varsha': 'Varsha', 'monsoon': 'Varsha',
  'sharad': 'Sarad', 'sarad': 'Sarad', 'autumn': 'Sarad',
  'hemanta': 'Hemanta', 'winter': 'Hemanta',
  'shishira': 'Sisira', 'sisira': 'Sisira',
};

function normalizeSeason(season) {
  if (!season) return null;
  // Already a valid key
  if (RITU_BASELINE_COLORS[season]) return season;
  // Try alias lookup
  const alias = SEASON_ALIASES[season.toLowerCase()];
  if (alias) return alias;
  return null;
}

function isNaturalColor(observedColor, season) {
  const normalizedSeason = normalizeSeason(season);
  const baseline = RITU_BASELINE_COLORS[normalizedSeason];
  if (!baseline) return false;
  const observed = observedColor?.toLowerCase();
  // "normal" means the observer didn't notice anything unusual — treat as natural
  if (observed === 'normal' || observed === 'natural' || !observed) return true;
  const expected = baseline.color.toLowerCase();
  if (observed === expected) return true;
  // Grishma accepts both 'pale' and 'golden'
  if (normalizedSeason === 'Grishma' && (observed === 'pale' || observed === 'golden')) return true;
  return false;
}

// ─── MAIN EVALUATOR ──────────────────────────────────────────────────────────

/**
 * Evaluate all Sun observation rules from Brihat Samhita Ch.3.
 *
 * Unlike all other planet evaluators, this function does NOT use zodiac signs
 * or nakshatras. It operates entirely on VISUAL observations of the solar disc
 * and the current RITU (season).
 *
 * @param {Object} sunObservation - Visual observation of the Sun
 * @param {string} [sunObservation.color] - Observed disc color (e.g. 'copper', 'blood-red', 'dark')
 * @param {string} [sunObservation.rayQuality] - 'sharp' | 'soft' | 'normal'
 * @param {string} [sunObservation.rayColor] - Color of upward rays (e.g. 'copper', 'yellow', 'white', 'variegated')
 * @param {string[]} [sunObservation.spotShapes] - Array of observed keelaka shapes (e.g. ['stick', 'crow'])
 * @param {number} [sunObservation.spotsCount] - Number of sunspots observed
 * @param {string[]} [sunObservation.spotColors] - Colors of sunspots (e.g. ['black', 'red'])
 * @param {string} [sunObservation.discCondition] - Disc anomaly (e.g. 'pot', 'broken', 'without_rays', 'blood_midsky')
 * @param {string} [sunObservation.haloPosition] - Mock-sun / parhelion position ('north', 'south', 'above', 'below')
 * @param {boolean} [sunObservation.isEclipse] - If true, keelaka effects are suppressed (Sl.11)
 * @param {string} season - Current ritu: 'Sisira'|'Vasantha'|'Grishma'|'Varsha'|'Sarad'|'Hemanta'
 * @returns {Object[]} Array of Effect objects
 */
export function evaluateSun(sunObservation, season) {
  if (!sunObservation || !season) return [];

  const normalizedSeason = normalizeSeason(season) || season;
  season = normalizedSeason; // Use normalized from here on

  const effects = [];
  const obs = sunObservation;

  // ── 1. BENEFIC BASELINE (Sl.39): spotless, clear, bright, natural ─────
  //    If the Sun is entirely normal, produce a single positive effect.
  const isSpotless = (!obs.spotShapes || obs.spotShapes.length === 0) && (!obs.spotsCount || obs.spotsCount === 0);
  const isNormalDisc = !obs.discCondition || obs.discCondition === 'normal';
  const hasNaturalColor = isNaturalColor(obs.color, season);
  const isSoftOrNormal = !obs.rayQuality || obs.rayQuality === 'normal' || obs.rayQuality === 'soft';
  const noHaloAnomaly = !obs.haloPosition;

  if (isSpotless && isNormalDisc && hasNaturalColor && isSoftOrNormal && noHaloAnomaly) {
    effects.push(makeEffect({
      domain: 'society',
      dir: 'pos',
      desc: `Sun is spotless, clear, bright, and displays natural ${RITU_BASELINE_COLORS[season]?.color} color — auspicious to all`,
      weight: 0.7,
      ruleId: 'surya_benefic_baseline',
      source: 'BS Ch.3 Sl.39'
    }));
    return effects; // No further checks needed — all is well
  }

  // ── 2. SEASONAL COLOR CHECK (Sl.23-24 + Sl.26) ───────────────────────
  if (obs.color && !hasNaturalColor) {
    // General: abnormal color triggers a warning
    effects.push(makeEffect({
      domain: 'society',
      dir: 'neg',
      desc: `Sun displays abnormal ${obs.color} color in ${season} (expected ${RITU_BASELINE_COLORS[season]?.color}) — inauspicious`,
      weight: 0.6,
      ruleId: 'surya_abnormal_color',
      source: 'BS Ch.3 Sl.23-24'
    }));

    // Specific out-of-season anomalies (Sl.26)
    for (const anomaly of OUT_OF_SEASON_ANOMALIES) {
      if (anomaly.season === season && obs.color.toLowerCase() === anomaly.color.toLowerCase()) {
        effects.push(makeEffect({
          domain: anomaly.domain,
          dir: anomaly.dir,
          desc: anomaly.desc,
          weight: anomaly.weight,
          ruleId: `surya_oos_${season.toLowerCase()}_${anomaly.color}`,
          source: 'BS Ch.3 Sl.26'
        }));
      }
    }
  }

  // ── 3. THAMASA KEELAKAS / SUNSPOTS (Sl.6-19) ─────────────────────────
  //    EXCEPTION (Sl.11): Effects do NOT apply during eclipses.
  if (!obs.isEclipse) {

    // 3a. Shape effects
    if (obs.spotShapes && obs.spotShapes.length > 0) {
      for (const shape of obs.spotShapes) {
        const shapeEffect = KEELAKA_SHAPE_EFFECTS[shape];
        if (shapeEffect) {
          effects.push(makeEffect({
            domain: shapeEffect.domain,
            dir: shapeEffect.dir,
            desc: `Sunspot shaped like ${shape} — ${shapeEffect.desc}`,
            weight: shapeEffect.weight,
            ruleId: `surya_keelaka_shape_${shape}`,
            source: 'BS Ch.3 Sl.6-19'
          }));
        }
      }
    }

    // 3b. Count effects
    if (obs.spotsCount && obs.spotsCount >= 1) {
      if (obs.spotsCount === 1) {
        const countEffect = KEELAKA_COUNT_EFFECTS[1];
        effects.push(makeEffect({
          domain: countEffect.domain,
          dir: countEffect.dir,
          desc: countEffect.desc,
          weight: countEffect.weight,
          ruleId: 'surya_keelaka_count_1',
          source: 'BS Ch.3 Sl.6-7'
        }));
      } else {
        // 2 or more: destruction of sovereign
        const countEffect = KEELAKA_COUNT_EFFECTS[obs.spotsCount >= 3 ? 3 : 2];
        effects.push(makeEffect({
          domain: countEffect.domain,
          dir: countEffect.dir,
          desc: `${obs.spotsCount} sunspots observed — ${countEffect.desc}`,
          weight: countEffect.weight,
          ruleId: `surya_keelaka_count_${Math.min(obs.spotsCount, 3)}`,
          source: 'BS Ch.3 Sl.6-7'
        }));
      }
    }

    // 3c. Color → varna effects
    if (obs.spotColors && obs.spotColors.length > 0) {
      for (const spotColor of obs.spotColors) {
        const varnaEffect = KEELAKA_COLOR_VARNA[spotColor];
        if (varnaEffect) {
          effects.push(makeEffect({
            domain: varnaEffect.domain,
            dir: 'neg',
            desc: `${spotColor} sunspot — ${varnaEffect.desc}`,
            weight: varnaEffect.weight,
            ruleId: `surya_keelaka_varna_${spotColor}`,
            source: 'BS Ch.3 Sl.8-10',
            manifestation: varnaEffect.varna
          }));
        }
      }
    }

    // 3d. Direction of spot on disc = direction of danger
    // (Direction is implicit in the observation; recorded as metadata if provided)

  } else {
    // Eclipse active — keelaka effects suppressed per Sl.11
    if (obs.spotShapes?.length > 0 || (obs.spotsCount && obs.spotsCount > 0)) {
      effects.push(makeEffect({
        domain: 'society',
        dir: 'mix',
        desc: 'Sunspots observed during eclipse — keelaka effects suppressed per Sl.11',
        weight: 0.1,
        ruleId: 'surya_keelaka_eclipse_suppressed',
        source: 'BS Ch.3 Sl.11'
      }));
    }
  }

  // ── 4. UPWARD RAY COLOR EFFECTS (Sl.21-22) ───────────────────────────
  if (obs.rayColor) {
    const rayEffect = UPWARD_RAY_EFFECTS[obs.rayColor];
    if (rayEffect) {
      effects.push(makeEffect({
        domain: rayEffect.domain,
        dir: rayEffect.dir,
        desc: `Upward rays of ${obs.rayColor} color — ${rayEffect.desc}`,
        weight: rayEffect.weight,
        ruleId: `surya_upward_ray_${obs.rayColor}`,
        source: 'BS Ch.3 Sl.21-22'
      }));
    }
  }

  // ── 5. RAINY SEASON SHARP RAYS (Sl.25) ────────────────────────────────
  //    Only applies in Varsha ritu. Soft rays OVERRIDE to positive.
  if (season === 'Varsha' && obs.rayQuality) {
    if (obs.rayQuality === 'soft') {
      // Soft rays in rainy season = auspicious override
      effects.push(makeEffect({
        domain: 'society',
        dir: 'pos',
        desc: 'Soft rays during monsoon — auspicious for all classes',
        weight: 0.7,
        ruleId: 'surya_varsha_soft_rays',
        source: 'BS Ch.3 Sl.25'
      }));
    } else if (obs.rayQuality === 'sharp' && obs.rayColor) {
      const varshaEffect = VARSHA_RAY_EFFECTS[obs.rayColor];
      if (varshaEffect) {
        effects.push(makeEffect({
          domain: varshaEffect.domain,
          dir: 'neg',
          desc: `Sharp ${obs.rayColor} rays in monsoon — ${varshaEffect.desc}`,
          weight: varshaEffect.weight,
          ruleId: `surya_varsha_sharp_${obs.rayColor}`,
          source: 'BS Ch.3 Sl.25',
          manifestation: varshaEffect.varna
        }));
      }
    }
  }

  // ── 6. SUN DISC ANOMALIES (Sl.27-35) ──────────────────────────────────
  if (obs.discCondition && obs.discCondition !== 'normal') {
    const discEffect = DISC_ANOMALY_EFFECTS[obs.discCondition];
    if (discEffect) {
      effects.push(makeEffect({
        domain: discEffect.domain,
        dir: discEffect.dir,
        desc: discEffect.desc,
        weight: discEffect.weight,
        ruleId: `surya_disc_${obs.discCondition}`,
        source: 'BS Ch.3 Sl.27-35'
      }));
    }
  }

  // ── 7. MOCK-SUN / PARHELION POSITION (Sl.33-35) ───────────────────────
  if (obs.haloPosition) {
    const haloEffect = MOCK_SUN_EFFECTS[obs.haloPosition];
    if (haloEffect) {
      effects.push(makeEffect({
        domain: haloEffect.domain,
        dir: haloEffect.dir,
        desc: haloEffect.desc,
        weight: haloEffect.weight,
        ruleId: `surya_mocksun_${obs.haloPosition}`,
        source: 'BS Ch.3 Sl.33-35'
      }));
    }
  }

  return effects;
}
