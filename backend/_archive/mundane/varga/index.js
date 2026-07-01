/**
 * VARGA — Barrel Export for All Varga Modules
 *
 * Centralized re-export of the complete Brihat Samhita rules engine.
 * Each varga module codifies a distinct analytical layer from the text.
 *
 * Usage:
 *   import { isNakshatraHurt, assessPlanetBeneficence, assessOmen } from './varga/index.js';
 */

// ─── NAKSHATRA VARGA (Ch.15, Ch.14, Ch.97) ─────────────────────────────────
// Foundation: 28 nakshatras, classifications, hurt detection, paka lookup
export {
  NAKSHATRAS,
  NAKSHATRA_BY_NAME,
  NAKSHATRA_BY_IDX,
  CLASSIFICATIONS,
  VARNAS,
  JOURNEY_NAKSHATRAS,
  isNakshatraHurt,
  getAllHurtNakshatras,
  getAffectedDependencies,
  getNakshatraPakaDays,
  getNakshatraOffset
} from './nakshatra.js';

// ─── BENEFIC VARGA (Ch.16) ──────────────────────────────────────────────────
// Planetary beneficence/maleficence assessment, dignity, aspects
export {
  PLANET_DIGNITY,
  NATURAL_BENEFICS,
  NATURAL_MALEFICS,
  assessPlanetBeneficence,
  jupiterAspectsSign
} from './benefic.js';

// ─── CANCEL VARGA (Ch.5, Ch.6, Ch.7, Ch.32, Ch.86, Ch.97) ─────────────────
// Universal cancellation engine: eclipse neutralization, seasonal filtering
export {
  MARS_AUSPICIOUS_EMERGENCE,
  EARTHQUAKE_CANCEL_PAIRS,
  EARTHQUAKE_BENEFICIAL_PAIRS,
  EARTHQUAKE_DESTRUCTIVE_PAIRS,
  SEASONAL_DISQUALIFICATION,
  MONTH_TO_SEASON,
  GREGORIAN_TO_HINDU_MONTH,
  applyCancellations,
  isSeasonallyDisqualified,
  getEarthquakeCircleCombination
} from './cancel.js';

// ─── PAKA VARGA (Ch.97) ────────────────────────────────────────────────────
// Timing/fruition engine: phenomenon-type timings, doubling rules
export * from './paka.js';

// ─── STHANA VARGA (Ch.14, Ch.16) ───────────────────────────────────────────
// Geographic targeting: Kurma Chakra, regions, planetary domain mapping
export * from './sthana.js';

// ─── SHAKUNA VARGA (Ch.86, Ch.95-96) ───────────────────────────────────────
// Omen filtering: blasted/tranquil, directional timing, creature strength
export {
  DREADFUL_NAKSHATRAS,
  BLASTED_TITHIS,
  FOOD_CLASSIFICATION,
  DIRECTIONAL_TIMING,
  CREATURE_DIRECTION_STRENGTH,
  LEFT_FAVOURABLE,
  RIGHT_FAVOURABLE,
  OMEN_STRENGTH_FACTORS,
  KROS_DISTANCE,
  PRANAYAMA_REMEDY,
  checkDivineBlasting,
  checkActionBlasting,
  classifyFood,
  isOmenBlasted,
  getDirectionalTiming,
  getCreatureStrength,
  checkLeftRightFavorability,
  evaluate12Factors,
  getDistanceAttenuation,
  getPranayamaRemedy,
  assessOmen
} from './shakuna.js';

// ─── BHUMI VARGA (Ch.32, Ch.46) ─────────────────────────────────────────────
// Earthquake circles, portents, terrestrial phenomena
export * from './bhumi.js';

// ─── ARTHA VARGA (Ch.41, Ch.42) ─────────────────────────────────────────────
// Economic predictions: commodity mapping, price fluctuation, trading calendar
export * from './artha.js';

// ─── GRAHA VARGA — Individual Planet Chapters ───────────────────────────────

// Surya (Sun) — Ch.3 Aditya Chara
export * from './graha/surya.js';

// Kuja (Mars) — Ch.6 Angaraka Chara
export * from './graha/kuja.js';

// Budha (Mercury) — Ch.7 Budha Chara
export * from './graha/budha.js';

// Guru (Jupiter) — Ch.8 Brihaspati Chara
export * from './graha/guru.js';

// Shukra (Venus) — Ch.9 Shukra Chara
export * from './graha/shukra.js';

// Shani (Saturn) — Ch.10 Shani Chara
export * from './graha/shani.js';
