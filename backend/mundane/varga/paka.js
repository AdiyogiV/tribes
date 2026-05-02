/**
 * PAKA VARGA — Complete Timing Engine
 * Source: Brihat Samhita Ch.97 (Paka Adhyaya)
 *
 * The BS assigns DIFFERENT fruition timelines to different phenomenon types.
 * Our old paka.js had 9 entries. The actual text has 17+ categories,
 * 28 nakshatra-specific timings, and a doubling rule.
 *
 * Slokas 1-3:   Planetary transit fruition
 * Slokas 4-5:   Natural reversals, catastrophic events = 6 months
 * Sloka 6:      Portents = 3 months
 * Sloka 7:      Pests, animal cries = 3 months
 * Sloka 8:      Wild-domestic crossover = 1 year+
 * Sloka 9:      Jackals/vultures = 10 days; instruments = same day; ant-hills = 15 days
 * Sloka 10:     Spontaneous fire = same day; utterances = 1.5 months
 * Sloka 11:     Sacred objects = 3.5 months
 * Sloka 12:     Unnatural alliances = 1 month
 * Sloka 13:     Aerial cities, discoloration = 1 month
 * Slokas 14-16: Nakshatra-specific timing (28 entries)
 * Sloka 17:     DOUBLING RULE
 */

import { getNakshatraPakaDays } from './nakshatra.js';

// ─── PHENOMENON-TYPE TIMING TABLE ────────────────────────────────────────────
// BS Ch.97 Slokas 1-13

export const PHENOMENON_PAKA = {
  // Slokas 1-3: Planetary transits
  sun_transit:        { days: 15,   source: 'Ch.97 Sl.1' },
  moon_transit:       { days: 30,   source: 'Ch.97 Sl.1' },
  mars_transit:       { days: null, source: 'Ch.97 Sl.2', note: 'Period of retrograde motion (see Ch.6)' },
  mercury_transit:    { days: null, source: 'Ch.97 Sl.2', note: 'Before his disappearance' },
  jupiter_transit:    { days: 365,  source: 'Ch.97 Sl.2' },
  venus_transit:      { days: 180,  source: 'Ch.97 Sl.3' },
  saturn_transit:     { days: 365,  source: 'Ch.97 Sl.3' },
  rahu_transit:       { days: 180,  source: 'Ch.97 Sl.3' },

  // Slokas 1-3: Non-planetary astronomical
  solar_eclipse:      { days: 365,  source: 'Ch.97 Sl.1' },
  lunar_eclipse:      { days: 365,  source: 'Ch.97 Sl.1' },
  thamasa_keelaka:    { days: 0,    source: 'Ch.97 Sl.3', note: 'Same day' },
  twashta:            { days: 0,    source: 'Ch.97 Sl.3', note: 'Same day' },
  keelaka:            { days: 90,   source: 'Ch.97 Sl.3' },

  // Atmospheric
  halo:               { days: 7,    source: 'Ch.97 Sl.3' },
  rainbow:            { days: 7,    source: 'Ch.97 Sl.3' },
  twilight_anomaly:   { days: 7,    source: 'Ch.97 Sl.3' },
  cloud_shape:        { days: 7,    source: 'Ch.97 Sl.3' },
  dusky_comet:        { days: 7,    source: 'Ch.97 Sl.3' },
  white_comet:        { days: 7,    source: 'Ch.97 Sl.3' },

  // Sloka 4: Seasonal/natural reversals
  temperature_reversal:  { days: 180, source: 'Ch.97 Sl.4' },
  out_of_season_bloom:   { days: 180, source: 'Ch.97 Sl.4' },
  burning_quarters:      { days: 180, source: 'Ch.97 Sl.4' },
  abnormal_births:       { days: 180, source: 'Ch.97 Sl.4' },

  // Sloka 5: Catastrophic
  earthquake:            { days: 180, source: 'Ch.97 Sl.5' },
  agentless_action:      { days: 180, source: 'Ch.97 Sl.5' },
  festival_stoppage:     { days: 180, source: 'Ch.97 Sl.5' },
  never_dry_drying:      { days: 180, source: 'Ch.97 Sl.5' },
  streams_flowing_upward: { days: 180, source: 'Ch.97 Sl.5' },

  // Sloka 6: Portents
  pillar_portent:        { days: 90,  source: 'Ch.97 Sl.6' },
  granary_portent:       { days: 90,  source: 'Ch.97 Sl.6' },
  idol_portent:          { days: 90,  source: 'Ch.97 Sl.6' },
  speech_portent:        { days: 90,  source: 'Ch.97 Sl.6' },
  weeping_portent:       { days: 90,  source: 'Ch.97 Sl.6' },
  quaking_portent:       { days: 90,  source: 'Ch.97 Sl.6' },
  sweating_portent:      { days: 90,  source: 'Ch.97 Sl.6' },
  portentous_thunder:    { days: 90,  source: 'Ch.97 Sl.6' },

  // Sloka 7: Pests and animal cries
  pest_infestation:      { days: 90,  source: 'Ch.97 Sl.7' },
  animal_cries:          { days: 90,  source: 'Ch.97 Sl.7' },
  bird_cries:            { days: 90,  source: 'Ch.97 Sl.7' },
  floating_earth:        { days: 90,  source: 'Ch.97 Sl.7' },

  // Sloka 8: Wild-domestic crossover
  wild_domestic_crossover: { days: 365, source: 'Ch.97 Sl.8', note: '1 year or slightly more' },
  beehive_portent:        { days: 365, source: 'Ch.97 Sl.8' },
  indra_banner:           { days: 365, source: 'Ch.97 Sl.8' },

  // Sloka 9: Short-term
  jackal_vulture_group:  { days: 10,  source: 'Ch.97 Sl.9' },
  instrument_anomaly:    { days: 0,   source: 'Ch.97 Sl.9', note: 'Same day' },
  imprecation:           { days: 15,  source: 'Ch.97 Sl.9' },
  sudden_anthill:        { days: 15,  source: 'Ch.97 Sl.9' },
  earth_bursting:        { days: 15,  source: 'Ch.97 Sl.9' },

  // Sloka 10: Spontaneous phenomena
  spontaneous_fire:      { days: 0,   source: 'Ch.97 Sl.10', note: 'Same day' },
  ghee_shower:           { days: 0,   source: 'Ch.97 Sl.10', note: 'Same day' },
  utterance_portent:     { days: 45,  source: 'Ch.97 Sl.10' },

  // Sloka 11: Sacred objects
  umbrella_portent:      { days: 30,  source: 'Ch.97 Sl.11', note: 'Some say 1 month' },
  sacrificial_altar:     { days: 105, source: 'Ch.97 Sl.11', note: '7 fortnights' },
  sacred_fire:           { days: 105, source: 'Ch.97 Sl.11' },
  seed_portent:          { days: 105, source: 'Ch.97 Sl.11' },

  // Sloka 12: Unnatural alliances
  enemy_friendship:      { days: 30,  source: 'Ch.97 Sl.12' },
  predator_prey_union:   { days: 30,  source: 'Ch.97 Sl.12' },
  dry_animal_sound:      { days: 30,  source: 'Ch.97 Sl.12' },

  // Sloka 13: Atmospheric/material
  aerial_city:           { days: 30,  source: 'Ch.97 Sl.13' },
  plaster_discolor:      { days: 30,  source: 'Ch.97 Sl.13' },
  gold_discolor:         { days: 30,  source: 'Ch.97 Sl.13' },
  flag_portent:          { days: 30,  source: 'Ch.97 Sl.13' },
  dust_smoke_quarters:   { days: 30,  source: 'Ch.97 Sl.13' },

  // Ch.46 Sl.14: Idol portents specifically
  idol_temple_portent:   { days: 240, source: 'Ch.46 Sl.14', note: '8 months' },

  // Ch.11 Sl.7: Comet formula
  comet:                 { days: null, source: 'Ch.11 Sl.7', note: 'Visible N days → effects N months' }
};

// ─── PLANETARY TRANSIT PAKA MAPPING ──────────────────────────────────────────
// Quick lookup from planet name to paka key

const PLANET_PAKA_KEY = {
  Sun: 'sun_transit', Moon: 'moon_transit', Mars: 'mars_transit',
  Mercury: 'mercury_transit', Jupiter: 'jupiter_transit',
  Venus: 'venus_transit', Saturn: 'saturn_transit',
  Rahu: 'rahu_transit', Ketu: 'rahu_transit'
};

// ─── ECLIPSE RECURRENCE TABLE ────────────────────────────────────────────────
// BS Ch.5 Sloka 63: Concurrent phenomena during eclipse → next eclipse timing

export const ECLIPSE_RECURRENCE = {
  strong_wind:    { months: 6,  source: 'Ch.5 Sl.63' },
  meteor_fall:    { months: 12, source: 'Ch.5 Sl.63' },
  dust_storm:     { months: 18, source: 'Ch.5 Sl.63' },
  earthquake:     { months: 24, source: 'Ch.5 Sl.63' },
  total_darkness: { months: 30, source: 'Ch.5 Sl.63' },
  thunderbolt:    { months: 35, source: 'Ch.5 Sl.63' }
};

// ─── EARTHQUAKE CIRCLE TIMING ────────────────────────────────────────────────
// BS Ch.32 Sloka 30

export const EARTHQUAKE_CIRCLE_TIMING = {
  Vayu:   { days: 60,  source: 'Ch.32 Sl.30', note: '2 months' },
  Agni:   { days: 45,  source: 'Ch.32 Sl.30', note: '3 fortnights' },
  Indra:  { days: 7,   source: 'Ch.32 Sl.30', note: '1 week' },
  Varuna: { days: 0,   source: 'Ch.32 Sl.30', note: 'Same day' }
};

// ─── MAIN PAKA FUNCTIONS ─────────────────────────────────────────────────────

/**
 * Get the fruition timing for a phenomenon in days.
 *
 * @param {string} phenomenonType - Key from PHENOMENON_PAKA
 * @param {Object} [context] - Additional context for variable-timing phenomena
 * @param {string} [context.planet] - Planet name (for transit timing)
 * @param {string} [context.nakshatra] - Nakshatra (for nakshatra-specific timing)
 * @param {number} [context.cometVisibleDays] - Days comet was visible
 * @param {number} [context.marsRetrogradeDays] - Mars retrograde period in days
 * @returns {{ days: number, source: string, note?: string, isDoubleable: boolean }}
 */
export function getPakaTiming(phenomenonType, context = {}) {
  // 1. Check if we have a planet-based transit
  if (phenomenonType === 'planet_transit' && context.planet) {
    const key = PLANET_PAKA_KEY[context.planet];
    if (key) {
      const entry = PHENOMENON_PAKA[key];
      let days = entry.days;

      // Mars: period of retrograde motion
      if (context.planet === 'Mars' && context.marsRetrogradeDays) {
        days = context.marsRetrogradeDays;
      } else if (context.planet === 'Mars' && days === null) {
        days = 60; // default ~2 months if retrograde period unknown
      }

      // Mercury: before disappearance
      if (context.planet === 'Mercury' && days === null) {
        days = 30; // approximate to ~1 month
      }

      return { days, source: entry.source, note: entry.note, isDoubleable: true };
    }
  }

  // 2. Comet: visible N days → N months
  if (phenomenonType === 'comet') {
    const visibleDays = context.cometVisibleDays || 1;
    return {
      days: visibleDays * 30,
      source: 'Ch.11 Sl.7',
      note: `Visible ${visibleDays} days → effects ${visibleDays} months`,
      isDoubleable: true
    };
  }

  // 3. Check nakshatra-specific timing (overrides phenomenon type for some contexts)
  if (context.nakshatra && context.useNakshatraPaka) {
    const nakDays = getNakshatraPakaDays(context.nakshatra);
    return {
      days: nakDays,
      source: 'Ch.97 Sl.14-16',
      note: `Nakshatra-specific: ${context.nakshatra}`,
      isDoubleable: true
    };
  }

  // 4. Standard phenomenon lookup
  const entry = PHENOMENON_PAKA[phenomenonType];
  if (entry) {
    return {
      days: entry.days ?? 90, // default 3 months for null entries
      source: entry.source,
      note: entry.note,
      isDoubleable: true
    };
  }

  // 5. Fallback
  return { days: 90, source: 'default', note: 'No specific paka rule found', isDoubleable: true };
}

/**
 * Apply the DOUBLING RULE (Ch.97 Sloka 17).
 * "If effects do not manifest at the fixed time, they come with
 * greater vehemence at double the time."
 *
 * @param {number} originalDays - Original paka timing
 * @param {boolean} hasExpiatoryRites - Whether ceremonies were performed
 * @returns {{ doubledDays: number, vehemence: number, averted: boolean }}
 */
export function applyDoublingRule(originalDays, hasExpiatoryRites = false) {
  if (hasExpiatoryRites) {
    return {
      doubledDays: originalDays,
      vehemence: 0,
      averted: true,
      note: 'Averted by expiatory ceremonies + gifts of gold, gems, cows (Ch.97 Sl.17)'
    };
  }

  return {
    doubledDays: originalDays * 2,
    vehemence: 1.5, // "greater vehemence" — 1.5x intensity multiplier
    averted: false,
    note: 'Effects manifest at double time with greater vehemence (Ch.97 Sl.17)'
  };
}

/**
 * Calculate the complete manifestation timeline for an effect.
 * Returns primary window and doubled window.
 *
 * @param {string} phenomenonType
 * @param {Date|string} observationDate
 * @param {Object} [context]
 * @returns {{ primaryPeak: Date, primaryWindow: { start: Date, end: Date },
 *             doubledPeak: Date, doubledWindow: { start: Date, end: Date },
 *             pakaDays: number, source: string }}
 */
export function calculateManifestationTimeline(phenomenonType, observationDate, context = {}) {
  const date = observationDate instanceof Date ? observationDate : new Date(observationDate);
  const paka = getPakaTiming(phenomenonType, context);
  const days = paka.days;

  // Primary peak
  const primaryPeak = new Date(date);
  primaryPeak.setDate(primaryPeak.getDate() + days);

  // Primary window: ±20% of paka days (or ±3 days minimum)
  const windowDays = Math.max(3, Math.round(days * 0.2));
  const primaryStart = new Date(primaryPeak);
  primaryStart.setDate(primaryStart.getDate() - windowDays);
  const primaryEnd = new Date(primaryPeak);
  primaryEnd.setDate(primaryEnd.getDate() + windowDays);

  // Doubled peak (if effects don't manifest at primary)
  const doubledDays = days * 2;
  const doubledPeak = new Date(date);
  doubledPeak.setDate(doubledPeak.getDate() + doubledDays);
  const doubledWindowDays = Math.max(3, Math.round(doubledDays * 0.2));
  const doubledStart = new Date(doubledPeak);
  doubledStart.setDate(doubledStart.getDate() - doubledWindowDays);
  const doubledEnd = new Date(doubledPeak);
  doubledEnd.setDate(doubledEnd.getDate() + doubledWindowDays);

  return {
    primaryPeak,
    primaryWindow: { start: primaryStart, end: primaryEnd },
    doubledPeak,
    doubledWindow: { start: doubledStart, end: doubledEnd },
    pakaDays: days,
    source: paka.source,
    note: paka.note
  };
}

/**
 * Get earthquake-specific timing based on circle.
 * BS Ch.32 Sloka 30
 *
 * @param {string} circle - 'Vayu'|'Agni'|'Indra'|'Varuna'
 * @returns {{ days: number, source: string }}
 */
export function getEarthquakePakaTiming(circle) {
  return EARTHQUAKE_CIRCLE_TIMING[circle] || { days: 180, source: 'Ch.97 Sl.5' };
}
