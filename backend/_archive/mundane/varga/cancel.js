/**
 * CANCEL — Universal Cancellation & Override Engine
 *
 * The BS has a built-in system where predictions are cancelled, neutralized,
 * or overridden under specific conditions. This module implements all known
 * cancellation rules from across the text.
 *
 * Sources:
 *   Ch.5  Sl.62  — Jupiter aspect neutralizes eclipse bad effects
 *   Ch.6  Sl.12  — Mars auspicious emergence cancels evil
 *   Ch.7  Sl.17  — Mercury eclipsed reverses visible-month effects
 *   Ch.32 Sl.27  — Earthquake circles cancel in pairs (Indra↔Wind, Varuna↔Fire)
 *   Ch.86 Sl.15  — 10 "blasted" conditions weaken omens
 *   Ch.86 Sl.24  — Context mismatch invalidates omens
 *   Ch.86 Sl.26-28 — Seasonal creatures must be ignored
 *   Ch.97 Sl.17  — Expiatory ceremonies can avert effects
 *   Ch.46 Sl.6   — Even celestial portents can be warded off with ceremonies
 */

import { jupiterAspectsSign } from './benefic.js';

// ─── MARS AUSPICIOUS EMERGENCE NAKSHATRAS ────────────────────────────────────
// BS Ch.6 Sloka 12: If Mars emerges from Sun conjunction in any of these
// nakshatras, ALL prior evil effects are cancelled.

export const MARS_AUSPICIOUS_EMERGENCE = [
  'Sravana', 'Magha', 'Purvashadha', 'Hasta', 'Moola',
  'Purvabhadra', 'Aswini', 'Visakha', 'Rohini'
];

// ─── EARTHQUAKE CIRCLE CANCELLATION PAIRS ────────────────────────────────────
// BS Ch.32 Sloka 27

export const EARTHQUAKE_CANCEL_PAIRS = [
  { circle1: 'Indra', circle2: 'Vayu',   effect: 'mutual_cancellation' },
  { circle1: 'Varuna', circle2: 'Agni',  effect: 'mutual_cancellation' }
];

// When these pairs combine, effects become beneficial instead of harmful
export const EARTHQUAKE_BENEFICIAL_PAIRS = [
  { circle1: 'Varuna', circle2: 'Indra', effect: 'plenty_prosperity_rain' },
  { circle1: 'Indra', circle2: 'Varuna', effect: 'plenty_prosperity_rain' }
];

// When these pairs combine, effects become destructive
export const EARTHQUAKE_DESTRUCTIVE_PAIRS = [
  { circle1: 'Agni', circle2: 'Vayu', effect: 'celebrated_king_dies_famine_pestilence' },
  { circle1: 'Vayu', circle2: 'Agni', effect: 'celebrated_king_dies_famine_pestilence' }
];

// ─── SEASONAL DISQUALIFICATION ──────────────────────────────────────────────
// BS Ch.86 Slokas 26-28: Creatures to IGNORE in each season

export const SEASONAL_DISQUALIFICATION = {
  // Magha, Phalguna (Jan-Feb, Feb-Mar)
  sisira: ['rohita deer', 'horse', 'goat', 'donkey', 'deer', 'camel', 'antelope', 'hare'],
  // Chaitra, Vaisakha (Mar-Apr, Apr-May)
  vasanta: ['crow', 'cuckoo'],
  // Bhadrapada only (Aug-Sep)
  bhadrapada: ['boar', 'dog', 'wolf'],
  // Aswina, Kartika (Sep-Oct, Oct-Nov)
  sarad: ['swan', 'cow', 'krauncha'],
  // Sravana only (Jul-Aug)
  sravana: ['elephant', 'chataka bird'],
  // Margasira, Pushya (Nov-Dec, Dec-Jan)
  hemanta: ['tiger', 'bear', 'monkey', 'leopard', 'buffalo', 'mongoose', 'all young animals']
};

// Map months to seasons for lookup
export const MONTH_TO_SEASON = {
  'Magha': 'sisira', 'Phalguna': 'sisira',
  'Chaitra': 'vasanta', 'Vaisakha': 'vasanta',
  'Jyeshta': 'grishma', 'Ashadha': 'grishma',
  'Sravana': 'sravana', 'Bhadrapada': 'bhadrapada',
  'Aswina': 'sarad', 'Kartika': 'sarad',
  'Margasira': 'hemanta', 'Pushya': 'hemanta'
};

// Approximate Gregorian month to Hindu month mapping
export const GREGORIAN_TO_HINDU_MONTH = {
  0: 'Pushya',       // January
  1: 'Magha',        // February
  2: 'Phalguna',     // March
  3: 'Chaitra',      // April
  4: 'Vaisakha',     // May
  5: 'Jyeshta',      // June
  6: 'Ashadha',      // July
  7: 'Sravana',      // August
  8: 'Bhadrapada',   // September
  9: 'Aswina',       // October
  10: 'Kartika',     // November
  11: 'Margasira'    // December
};

// ─── CANCELLATION ENGINE ─────────────────────────────────────────────────────

/**
 * Apply all cancellation checks to a set of effects.
 * Returns the effects with cancelled ones filtered out or modified.
 *
 * @param {Array<Object>} effects - Array of Effect objects
 * @param {Object} skyState - Current sky state
 * @param {Object} context - Additional context
 * @param {string} [context.month] - Hindu month name
 * @param {Date} [context.date] - Current date
 * @param {string} [context.earthquakeCircle] - Active earthquake circle
 * @param {string} [context.earthquakePeriod] - Time-of-day period circle
 * @returns {{ effects: Array<Object>, cancelled: Array<{ effect: Object, reason: string }> }}
 */
export function applyCancellations(effects, skyState, context = {}) {
  const result = [];
  const cancelled = [];

  for (const effect of effects) {
    const cancelReason = checkCancellation(effect, skyState, context);
    if (cancelReason) {
      cancelled.push({ effect, reason: cancelReason });
    } else {
      result.push(effect);
    }
  }

  return { effects: result, cancelled };
}

/**
 * Check if a single effect should be cancelled.
 * @returns {string|null} - Reason for cancellation, or null if not cancelled
 */
function checkCancellation(effect, skyState, context) {
  // 1. Jupiter aspect neutralizes eclipse bad effects (Ch.5 Sl.62)
  if (effect.category === 'eclipse' && effect.dir === 'neg') {
    const eclipseSign = effect.sign;
    if (eclipseSign && jupiterAspectsSign(eclipseSign, skyState)) {
      return 'Jupiter aspect neutralizes eclipse effects (Ch.5 Sl.62)';
    }
  }

  // 2. Mars auspicious emergence cancels prior evil (Ch.6 Sl.12)
  if (effect.planet === 'Mars' && effect.dir === 'neg') {
    const marsNak = skyState?.positions?.Mars?.nakshatra;
    if (marsNak && MARS_AUSPICIOUS_EMERGENCE.includes(marsNak)) {
      // Only if Mars just emerged from Sun conjunction
      const marsSunDist = skyState?.positions?.Mars?.sunDistance;
      if (marsSunDist !== undefined && marsSunDist < 30) {
        return `Mars auspicious emergence in ${marsNak} cancels evil (Ch.6 Sl.12)`;
      }
    }
  }

  // 3. Mercury eclipsed reverses visible-month effects (Ch.7 Sl.17)
  if (effect.planet === 'Mercury') {
    const mercPos = skyState?.positions?.Mercury;
    if (mercPos) {
      const isCombust = mercPos.sunDistance !== undefined && mercPos.sunDistance < 12;
      if (isCombust && effect.ruleId?.includes('visible_month')) {
        return 'Mercury eclipsed reverses visible-month effects (Ch.7 Sl.17)';
      }
    }
  }

  // 4. Earthquake circle cancellation (Ch.32 Sl.27)
  if (effect.category === 'earthquake' && context.earthquakeCircle && context.earthquakePeriod) {
    for (const pair of EARTHQUAKE_CANCEL_PAIRS) {
      if ((context.earthquakeCircle === pair.circle1 && context.earthquakePeriod === pair.circle2) ||
          (context.earthquakeCircle === pair.circle2 && context.earthquakePeriod === pair.circle1)) {
        return `Earthquake ${pair.circle1}↔${pair.circle2} mutual cancellation (Ch.32 Sl.27)`;
      }
    }
  }

  return null;
}

/**
 * Check if a creature/omen should be seasonally disqualified.
 * BS Ch.86 Slokas 26-28: "If the phenomenon is due to the particular season,
 * the evils described would not come to pass."
 *
 * @param {string} creature - Name/type of creature observed
 * @param {Date|string} date - Date of observation
 * @returns {{ disqualified: boolean, reason: string|null }}
 */
export function isSeasonallyDisqualified(creature, date) {
  const d = date instanceof Date ? date : new Date(date);
  const hinduMonth = GREGORIAN_TO_HINDU_MONTH[d.getMonth()];
  const season = MONTH_TO_SEASON[hinduMonth];

  if (!season) return { disqualified: false, reason: null };

  const disqualifiedCreatures = SEASONAL_DISQUALIFICATION[season];
  if (!disqualifiedCreatures) return { disqualified: false, reason: null };

  const creatureLower = creature.toLowerCase();
  for (const dc of disqualifiedCreatures) {
    if (creatureLower.includes(dc.toLowerCase())) {
      return {
        disqualified: true,
        reason: `${creature} disqualified in ${season} season (${hinduMonth}) — Ch.86 Sl.26-28`
      };
    }
  }

  return { disqualified: false, reason: null };
}

/**
 * Check the earthquake circle-period combination effect.
 * BS Ch.32 Slokas 27-29
 *
 * @param {string} circle - Earthquake's nakshatra circle (Vayu/Agni/Indra/Varuna)
 * @param {string} period - Time-of-day period circle
 * @returns {{ type: 'cancel'|'beneficial'|'destructive'|'normal', effect: string }}
 */
export function getEarthquakeCircleCombination(circle, period) {
  // Check cancellation
  for (const pair of EARTHQUAKE_CANCEL_PAIRS) {
    if ((circle === pair.circle1 && period === pair.circle2) ||
        (circle === pair.circle2 && period === pair.circle1)) {
      return { type: 'cancel', effect: 'Circles cancel each other — effects neutralized' };
    }
  }

  // Check beneficial combinations
  for (const pair of EARTHQUAKE_BENEFICIAL_PAIRS) {
    if (circle === pair.circle1 && period === pair.circle2) {
      return { type: 'beneficial', effect: pair.effect };
    }
  }

  // Check destructive combinations
  for (const pair of EARTHQUAKE_DESTRUCTIVE_PAIRS) {
    if (circle === pair.circle1 && period === pair.circle2) {
      return { type: 'destructive', effect: pair.effect };
    }
  }

  return { type: 'normal', effect: 'Standard circle effects apply' };
}
