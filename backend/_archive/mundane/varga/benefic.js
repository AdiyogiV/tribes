/**
 * BENEFIC — Universal Benefic/Malefic Planet Assessment
 * Source: Brihat Samhita Ch.16 Slokas 40-42
 *
 * A planet is BENEFIC to its dependencies when ALL of these hold at rising:
 *   1. Large in size
 *   2. Glossy rays
 *   3. Natural state (normal appearance)
 *   4. No portentous thunder
 *   5. No meteors disturbing it
 *   6. No dust
 *   7. No planetary conflict affecting it
 *   8. Posited in own house
 *   9. Reached exaltation point
 *  10. Aspected by benefics
 *
 * Malefic = contrary conditions. When malefic, its dependencies decay.
 */

// ─── PLANETARY DIGNITY DATA ─────────────────────────────────────────────────

export const PLANET_DIGNITY = {
  Sun:     { ownSigns: ['Leo'],          exaltation: 'Aries',       debilitation: 'Libra' },
  Moon:    { ownSigns: ['Cancer'],       exaltation: 'Taurus',      debilitation: 'Scorpio' },
  Mars:    { ownSigns: ['Aries', 'Scorpio'], exaltation: 'Capricorn', debilitation: 'Cancer' },
  Mercury: { ownSigns: ['Gemini', 'Virgo'],  exaltation: 'Virgo',     debilitation: 'Pisces' },
  Jupiter: { ownSigns: ['Sagittarius', 'Pisces'], exaltation: 'Cancer', debilitation: 'Capricorn' },
  Venus:   { ownSigns: ['Taurus', 'Libra'],  exaltation: 'Pisces',    debilitation: 'Virgo' },
  Saturn:  { ownSigns: ['Capricorn', 'Aquarius'], exaltation: 'Libra', debilitation: 'Aries' },
  Rahu:    { ownSigns: ['Aquarius'],     exaltation: 'Taurus',      debilitation: 'Scorpio' },
  Ketu:    { ownSigns: ['Scorpio'],      exaltation: 'Scorpio',     debilitation: 'Taurus' }
};

// Natural benefics and malefics
export const NATURAL_BENEFICS = ['Jupiter', 'Venus', 'Mercury', 'Moon'];
export const NATURAL_MALEFICS = ['Saturn', 'Mars', 'Rahu', 'Ketu', 'Sun'];

// ─── BENEFIC ASSESSMENT ─────────────────────────────────────────────────────

/**
 * Assess whether a planet is currently benefic or malefic per BS Ch.16 Sl.40-42.
 * Returns a score from -1.0 (fully malefic) to +1.0 (fully benefic)
 * and the individual factor checks.
 *
 * @param {string} planet - Planet name
 * @param {Object} skyState - Current sky state with positions
 * @param {Object} [conditions] - Optional environmental conditions
 * @param {boolean} [conditions.portentousThunder] - Thunder at time
 * @param {boolean} [conditions.meteors] - Meteors disturbing planet
 * @param {boolean} [conditions.dust] - Dust in atmosphere
 * @returns {{ score: number, isBenefic: boolean, factors: Object }}
 */
export function assessPlanetBeneficence(planet, skyState, conditions = {}) {
  const pos = skyState?.positions?.[planet];
  if (!pos) return { score: 0, isBenefic: false, factors: {} };

  const dignity = PLANET_DIGNITY[planet];
  if (!dignity) return { score: 0, isBenefic: false, factors: {} };

  const factors = {};
  let beneficCount = 0;
  let totalFactors = 0;

  // Factor 1-3: Size, glossy rays, natural state — approximated by non-combustion
  const isCombust = pos.sunDistance !== undefined && pos.sunDistance < 10 && planet !== 'Sun';
  factors.naturalState = !isCombust;
  if (factors.naturalState) beneficCount++;
  totalFactors++;

  // Factor 4: No portentous thunder
  factors.noThunder = !conditions.portentousThunder;
  if (factors.noThunder) beneficCount++;
  totalFactors++;

  // Factor 5: No meteors
  factors.noMeteors = !conditions.meteors;
  if (factors.noMeteors) beneficCount++;
  totalFactors++;

  // Factor 6: No dust
  factors.noDust = !conditions.dust;
  if (factors.noDust) beneficCount++;
  totalFactors++;

  // Factor 7: No planetary conflict (not in war — check if near another planet)
  // Simplified: check if any planet within 1 degree
  let inConflict = false;
  if (pos.longitude !== undefined) {
    for (const [otherPlanet, otherPos] of Object.entries(skyState.positions || {})) {
      if (otherPlanet === planet || otherPlanet === 'Sun' || otherPlanet === 'Moon') continue;
      if (otherPos.longitude !== undefined) {
        const sep = Math.abs(pos.longitude - otherPos.longitude);
        const normalizedSep = sep > 180 ? 360 - sep : sep;
        if (normalizedSep < 1) {
          inConflict = true;
          break;
        }
      }
    }
  }
  factors.noConflict = !inConflict;
  if (factors.noConflict) beneficCount++;
  totalFactors++;

  // Factor 8: In own house
  factors.inOwnHouse = dignity.ownSigns.includes(pos.sign);
  if (factors.inOwnHouse) beneficCount++;
  totalFactors++;

  // Factor 9: In exaltation
  factors.inExaltation = pos.sign === dignity.exaltation;
  if (factors.inExaltation) beneficCount++;
  totalFactors++;

  // Factor 10: Aspected by benefics
  // Simplified: check if any natural benefic is in trine/opposition
  let beneficAspect = false;
  const signs = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
    'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];
  const mySignIdx = signs.indexOf(pos.sign);
  if (mySignIdx !== -1) {
    for (const bp of NATURAL_BENEFICS) {
      if (bp === planet) continue;
      const bpPos = skyState.positions?.[bp];
      if (!bpPos?.sign) continue;
      const bpIdx = signs.indexOf(bpPos.sign);
      if (bpIdx === -1) continue;
      const diff = ((bpIdx - mySignIdx + 12) % 12);
      // Aspects: 7th (opposition), 5th, 9th (trines)
      if ([4, 6, 8].includes(diff)) {
        beneficAspect = true;
        break;
      }
    }
  }
  factors.beneficAspect = beneficAspect;
  if (factors.beneficAspect) beneficCount++;
  totalFactors++;

  // Check debilitation as a strong negative
  factors.inDebilitation = pos.sign === dignity.debilitation;

  // Retrograde as weakness
  factors.isRetrograde = !!pos.isRetrograde;

  // Calculate score
  let score = (beneficCount / totalFactors) * 2 - 1; // -1 to +1 range
  if (factors.inDebilitation) score -= 0.3;
  if (factors.isRetrograde) score -= 0.15;
  if (factors.inExaltation) score += 0.2; // bonus for exaltation
  score = Math.max(-1, Math.min(1, score));

  return {
    score,
    isBenefic: score > 0,
    factors
  };
}

/**
 * Check if Jupiter aspects a given sign (special neutralizer per Ch.5 Sl.62).
 * "As blazing fire put out by water" — Jupiter aspect on eclipsed luminary
 * neutralizes all bad effects.
 *
 * @param {string} targetSign
 * @param {Object} skyState
 * @returns {boolean}
 */
export function jupiterAspectsSign(targetSign, skyState) {
  const jupPos = skyState?.positions?.Jupiter;
  if (!jupPos?.sign) return false;

  const signs = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
    'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];
  const jupIdx = signs.indexOf(jupPos.sign);
  const targetIdx = signs.indexOf(targetSign);
  if (jupIdx === -1 || targetIdx === -1) return false;

  const diff = ((targetIdx - jupIdx + 12) % 12);
  // Jupiter aspects: 5th, 7th, 9th houses from its position
  return [4, 6, 8].includes(diff);
}
