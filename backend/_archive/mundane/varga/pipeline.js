/**
 * PIPELINE — Detection → Filter → Converge → Target → Time → Effect
 *
 * The master prediction pipeline implementing Varahamihira's 6-layer system.
 * This is the "brain" that connects all varga modules into a coherent
 * prediction engine faithful to the Brihat Samhita's methodology.
 *
 * Layer 1: DETECTION     — Identify astronomical + terrestrial phenomena
 * Layer 2: FILTERING     — Seasonal validity, anomaly check, blasted/tranquil
 * Layer 3: CONVERGENCE   — Multi-signal check (12 factors), concomitant count
 * Layer 4: TARGETING     — Geographic (Kurma) + domain (Graha Bhaktiyoga)
 * Layer 5: TIMING        — Paka (phenomenon-type + nakshatra-specific + doubling)
 * Layer 6: EFFECT        — Planet-specific rules, cancellation, final output
 */

import {
  isNakshatraHurt, getAllHurtNakshatras, getAffectedDependencies
} from './nakshatra.js';

import { assessPlanetBeneficence } from './benefic.js';
import { applyCancellations, isSeasonallyDisqualified, getEarthquakeCircleCombination } from './cancel.js';
import { getPakaTiming, calculateManifestationTimeline } from './paka.js';
import { getAffectedRegions, getAffectedDependants } from './sthana.js';
import { evaluateSun } from './graha/surya.js';
import { evaluateMars } from './graha/kuja.js';
import { evaluateMercury } from './graha/budha.js';
import { evaluateJupiter, getJupiterYear } from './graha/guru.js';
import { evaluateVenus } from './graha/shukra.js';
import { evaluateSaturn } from './graha/shani.js';
import { evaluateEarthquake, classifyPortent, EARTHQUAKE_CIRCLES } from './bhumi.js';
import { evaluateMarketConditions } from './artha.js';

// ─── LAYER 1: DETECTION ─────────────────────────────────────────────────────

/**
 * Detect all active phenomena from sky state + external observations.
 *
 * @param {Object} skyState - Planetary positions, eclipses
 * @param {Object} [observations] - External observational data
 * @param {Object} [observations.sunVisual] - Sun visual observation data
 * @param {string} [observations.season] - Current ritu (season)
 * @param {Object} [observations.marsContext] - Mars emergence/retrograde context
 * @param {Object} [observations.mercuryContext] - Mercury course/motion context
 * @param {Object} [observations.venusContext] - Venus visibility context
 * @param {Object} [observations.saturnContext] - Saturn appearance context
 * @param {Object} [observations.jupiterContext] - Jupiter transit context
 * @param {Array}  [observations.earthquakes] - Earthquake events
 * @param {Array}  [observations.portents] - Portent observations
 * @param {Array}  [observations.omens] - Creature/omen observations
 * @returns {Array<Object>} Raw effects from all detection sources
 */
function detectPhenomena(skyState, observations = {}) {
  const rawEffects = [];

  // 1a. Planet-specific evaluations
  if (observations.sunVisual) {
    rawEffects.push(...evaluateSun(observations.sunVisual, observations.season || 'varsha'));
  }

  if (skyState?.positions?.Mars) {
    rawEffects.push(...evaluateMars(skyState, observations.marsContext || {}));
  }

  if (skyState?.positions?.Mercury) {
    rawEffects.push(...evaluateMercury(skyState, observations.mercuryContext || {}));
  }

  if (skyState?.positions?.Jupiter) {
    const jupCtx = observations.jupiterContext || {};
    rawEffects.push(...evaluateJupiter(skyState, jupCtx));
  }

  if (skyState?.positions?.Venus) {
    rawEffects.push(...evaluateVenus(skyState, observations.venusContext || {}));
  }

  if (skyState?.positions?.Saturn) {
    rawEffects.push(...evaluateSaturn(skyState, observations.saturnContext || {}));
  }

  // 1b. Earthquake detection — DEDUPLICATED per BS Ch.32
  //
  // BS treats earthquake circles as categories, not per-event multipliers.
  // Multiple quakes in the same circle produce ONE set of effects (not N copies).
  // Multiple quakes in DIFFERENT circles trigger circle-combination rules.
  // Magnitude and proximity modulate weight, not effect count.
  if (observations.earthquakes?.length > 0) {
    const circlesActive = new Map(); // circleName → { count, maxMag, closestKm, bestQuake }

    for (const eq of observations.earthquakes) {
      const eqResult = evaluateEarthquake(eq.nakshatra, eq.timeOfDay);
      if (!eqResult.circle) continue;

      const existing = circlesActive.get(eqResult.circle);
      if (!existing) {
        circlesActive.set(eqResult.circle, {
          circle: eqResult.circle,
          count: 1,
          maxMag: eq.magnitude || 4.0,
          effects: eqResult.effects || [],
          bestQuake: eq
        });
      } else {
        existing.count++;
        if ((eq.magnitude || 0) > existing.maxMag) {
          existing.maxMag = eq.magnitude;
          existing.bestQuake = eq;
        }
      }
    }

    // Emit ONE set of effects per circle, weighted by magnitude + count
    for (const [circleName, data] of circlesActive) {
      // Magnitude weight: M5+ = full weight, M4 = 0.7, M3 = 0.5
      const magFactor = data.maxMag >= 5.0 ? 1.0 : data.maxMag >= 4.0 ? 0.7 : 0.5;
      // Repeat factor: multiple quakes in same circle increase severity slightly
      const repeatFactor = Math.min(1.2, 1 + (data.count - 1) * 0.05);

      for (const effect of data.effects) {
        const adjusted = { ...effect };
        adjusted.weight = Math.min(1.0, effect.weight * magFactor * repeatFactor);
        adjusted.desc = effect.desc + (data.count > 1 ? ` (${data.count} quakes in ${circleName} circle, strongest M${data.maxMag})` : ` (M${data.maxMag})`);
        // Tag with circle info for cancellation engine
        adjusted._earthquakeCircle = circleName;
        // Use circle's own regions instead of letting Layer 4 overwrite with Moon lookup
        adjusted._circleRegions = EARTHQUAKE_CIRCLES[circleName]?.regions || [];
        adjusted._circleTiming = EARTHQUAKE_CIRCLES[circleName]?.timingDays || 90;
        rawEffects.push(adjusted);
      }
    }

    // Check circle-pair combinations (Ch.32 Sl.27-29)
    const activeCircleNames = [...circlesActive.keys()];
    for (let i = 0; i < activeCircleNames.length; i++) {
      for (let j = i + 1; j < activeCircleNames.length; j++) {
        const c1 = activeCircleNames[i];
        const c2 = activeCircleNames[j];
        const combo = getEarthquakeCircleCombination(c1, c2);
        if (combo.type === 'cancel') {
          // Tag ALL effects from both circles for cancellation
          for (const effect of rawEffects) {
            if (effect._earthquakeCircle === c1 || effect._earthquakeCircle === c2) {
              effect._circleCancelled = true;
              effect._cancelReason = `${c1}↔${c2} mutual cancellation (Ch.32 Sl.27)`;
            }
          }
        } else if (combo.type === 'beneficial') {
          rawEffects.push({
            domain: 'agriculture', dir: 'pos',
            desc: `Earthquake circles ${c1}+${c2}: plenty, prosperity, and bountiful rain (Ch.32 Sl.29)`,
            weight: 0.9, planet: 'Moon', sign: null,
            ruleId: `bhukampa_combo_${c1}_${c2}`, source: 'Ch.32 Sl.29',
            category: 'earthquake', manifestation: null
          });
        } else if (combo.type === 'destructive') {
          rawEffects.push({
            domain: 'government', dir: 'neg',
            desc: `Earthquake circles ${c1}+${c2}: celebrated king dies, famine and pestilence (Ch.32 Sl.28)`,
            weight: 1.0, planet: 'Moon', sign: null,
            ruleId: `bhukampa_combo_${c1}_${c2}`, source: 'Ch.32 Sl.28',
            category: 'earthquake', manifestation: null
          });
        }
      }
    }
  }

  // 1c. Market conditions
  if (skyState?.positions?.Sun?.sign) {
    const marketResult = evaluateMarketConditions(skyState.positions.Sun.sign, skyState.positions);
    if (marketResult?.effects) {
      rawEffects.push(...marketResult.effects);
    } else if (Array.isArray(marketResult)) {
      rawEffects.push(...marketResult);
    }
  }

  // 1d. Nakshatra hurt effects
  const hurtMap = getAllHurtNakshatras(skyState);
  const affected = getAffectedDependencies(hurtMap);
  for (const a of affected) {
    rawEffects.push({
      domain: 'society',
      dir: 'neg',
      desc: `${a.nakshatra} hurt (${a.reasons.join(', ')}): ${a.dependencies.slice(0, 5).join(', ')} suffer`,
      weight: 0.4,
      planet: a.reasons[0]?.includes('Sun') ? 'Sun' : a.reasons[0]?.includes('Saturn') ? 'Saturn' : 'Mars',
      sign: null,
      ruleId: `hurt_nakshatra_${a.nakshatra.toLowerCase()}`,
      source: 'BS Ch.15 Sl.31-32',
      category: 'nakshatra_affliction',
      manifestation: null
    });
  }

  return rawEffects;
}

// ─── LAYER 2: FILTERING ─────────────────────────────────────────────────────

/**
 * Filter effects through seasonal validity and anomaly detection.
 * "If the phenomenon is due to the particular season, the evils
 * described would not come to pass." (Ch.86)
 *
 * @param {Array<Object>} effects - Raw effects from Layer 1
 * @param {Date} date - Current date
 * @returns {{ passed: Array<Object>, filtered: Array<{ effect: Object, reason: string }> }}
 */
function filterEffects(effects, date) {
  const passed = [];
  const filtered = [];

  for (const effect of effects) {
    // Skip seasonal-noise effects for omen-type predictions
    if (effect.category === 'omen' && effect.creature) {
      const check = isSeasonallyDisqualified(effect.creature, date);
      if (check.disqualified) {
        filtered.push({ effect, reason: check.reason });
        continue;
      }
    }

    passed.push(effect);
  }

  return { passed, filtered };
}

// ─── LAYER 3: CONVERGENCE ────────────────────────────────────────────────────

/**
 * Check for multi-signal convergence.
 * BS requires multiple independent signals pointing to the same domain
 * for high-confidence predictions.
 *
 * Rule: 5 concomitants → 100% coverage. Each missing → halves coverage. (Ch.21 Sl.31)
 *
 * @param {Array<Object>} effects
 * @returns {{ effects: Array<Object>, convergenceMap: Object }}
 */
function checkConvergence(effects) {
  // Group effects by domain
  const domainGroups = {};
  for (const e of effects) {
    if (!domainGroups[e.domain]) domainGroups[e.domain] = [];
    domainGroups[e.domain].push(e);
  }

  // Calculate convergence score per domain
  const convergenceMap = {};
  for (const [domain, domainEffects] of Object.entries(domainGroups)) {
    const uniqueSources = new Set(domainEffects.map(e => e.category));
    const signalCount = uniqueSources.size;

    // Convergence multiplier: 1 source = 0.5x, 2 = 0.75x, 3+ = 1.0x
    const convergenceMultiplier = signalCount >= 3 ? 1.0 : signalCount === 2 ? 0.75 : 0.5;

    convergenceMap[domain] = {
      signalCount,
      sources: [...uniqueSources],
      multiplier: convergenceMultiplier
    };

    // Apply convergence multiplier to effect weights
    for (const e of domainEffects) {
      e.weight *= convergenceMultiplier;
      e.convergenceSignals = signalCount;
    }
  }

  return { effects, convergenceMap };
}

// ─── LAYER 4: GEOGRAPHIC TARGETING ───────────────────────────────────────────

/**
 * Attach geographic targeting to each effect.
 *
 * @param {Array<Object>} effects
 * @param {Object} skyState
 * @returns {Array<Object>} Effects with geographic data attached
 */
function attachGeographicTargeting(effects, skyState) {
  for (const effect of effects) {
    // Earthquake effects: use circle-specific regions (already in the effect)
    // BS Ch.32 determines regions by the CIRCLE, not by Moon's Kurma position
    if (effect.category === 'earthquake' && effect._circleRegions?.length > 0) {
      effect.targetRegions = effect._circleRegions;
      effect.targetPeoples = [];
      continue;
    }

    // Non-earthquake effects: use planet-based Kurma lookup
    if (effect.planet) {
      const nakshatra = skyState?.positions?.[effect.planet]?.nakshatra;
      const regions = getAffectedRegions(effect.planet, nakshatra);
      effect.targetRegions = regions.combined.slice(0, 10);
      effect.targetPeoples = getAffectedDependants(effect.planet).peoples.slice(0, 10);
    }
  }
  return effects;
}

// ─── LAYER 5: TIMING ─────────────────────────────────────────────────────────

/**
 * Attach PAKA timing to each effect.
 *
 * @param {Array<Object>} effects
 * @param {Date|string} date - Observation date
 * @param {Object} skyState
 * @returns {Array<Object>} Effects with manifestation timeline attached
 */
function attachTiming(effects, date, skyState) {
  for (const effect of effects) {
    // Earthquake effects: use circle-specific timing from BS Ch.32
    // Vayu=60d, Agni=45d, Indra=7d, Varuna=1d — NOT generic paka
    if (effect.category === 'earthquake' && effect._circleTiming) {
      const d = date instanceof Date ? date : new Date(date);
      const peakDate = new Date(d);
      peakDate.setDate(peakDate.getDate() + effect._circleTiming);
      effect.manifestation = {
        delayDays: effect._circleTiming,
        peakDate: peakDate.toISOString().split('T')[0],
        peakDesc: `Effects last ${effect._circleTiming} days per ${effect._earthquakeCircle || 'unknown'} circle`,
        window: {
          start: d.toISOString().split('T')[0],
          end: peakDate.toISOString().split('T')[0]
        },
        source: `Ch.32 ${effect._earthquakeCircle} circle timing`
      };
      continue;
    }

    let phenomenonType = effect.category || 'portentous_thunder';

    // Map category to PAKA key
    if (effect.planet && effect.category?.includes('transit')) {
      phenomenonType = 'planet_transit';
    } else if (effect.category === 'eclipse') {
      phenomenonType = effect.desc?.includes('solar') ? 'solar_eclipse' : 'lunar_eclipse';
    }

    const context = {
      planet: effect.planet,
      nakshatra: skyState?.positions?.[effect.planet]?.nakshatra,
      useNakshatraPaka: false
    };

    const timeline = calculateManifestationTimeline(phenomenonType, date, context);

    effect.manifestation = {
      delayDays: timeline.pakaDays,
      peakDate: timeline.primaryPeak.toISOString().split('T')[0],
      peakDesc: `Effects peak around ${timeline.primaryPeak.toLocaleDateString()}`,
      window: {
        start: timeline.primaryWindow.start.toISOString().split('T')[0],
        end: timeline.primaryWindow.end.toISOString().split('T')[0]
      },
      doubledPeak: timeline.doubledPeak?.toISOString().split('T')[0],
      source: timeline.source
    };
  }
  return effects;
}

// ─── LAYER 6: EFFECT DETERMINATION + CANCELLATION ────────────────────────────

/**
 * Apply cancellation rules and finalize effects.
 *
 * @param {Array<Object>} effects
 * @param {Object} skyState
 * @param {Object} context
 * @returns {{ effects: Array<Object>, cancelled: Array<Object> }}
 */
function finalizeEffects(effects, skyState, context = {}) {
  // Pre-step: Remove circle-cancelled earthquake effects (from Layer 1 combo check)
  const preCancelled = [];
  const preSurviving = [];
  for (const effect of effects) {
    if (effect._circleCancelled) {
      preCancelled.push({ effect, reason: effect._cancelReason });
    } else {
      preSurviving.push(effect);
    }
  }

  // Apply standard cancellation engine (Jupiter aspects, Mars emergence, etc.)
  const { effects: surviving, cancelled } = applyCancellations(preSurviving, skyState, context);

  // Merge cancellation lists
  cancelled.push(...preCancelled);

  // Clean up internal tags before output
  for (const e of surviving) {
    delete e._earthquakeCircle;
    delete e._circleRegions;
    delete e._circleTiming;
    delete e._circleCancelled;
    delete e._cancelReason;
  }

  // Sort by weight (highest first)
  surviving.sort((a, b) => b.weight - a.weight);

  // Cap at reasonable number
  const topEffects = surviving.slice(0, 50);

  return { effects: topEffects, cancelled };
}

// ─── MASTER PIPELINE ─────────────────────────────────────────────────────────

/**
 * Run the complete 6-layer Brihat Samhita prediction pipeline.
 *
 * @param {Object} skyState - Planetary positions + eclipses
 * @param {Object} [observations] - External observations (sun visual, earthquakes, etc.)
 * @param {Object} [options] - Pipeline options
 * @param {Date|string} [options.date] - Date of analysis (default: today)
 * @param {string} [options.month] - Hindu month name
 * @returns {{
 *   effects: Array<Object>,
 *   cancelled: Array<Object>,
 *   filtered: Array<Object>,
 *   convergenceMap: Object,
 *   jupiterYear: Object,
 *   hurtNakshatras: Map,
 *   stats: Object
 * }}
 */
export function runPipeline(skyState, observations = {}, options = {}) {
  const date = options.date ? new Date(options.date) : new Date();
  const startTime = Date.now();

  // Layer 1: Detection
  const rawEffects = detectPhenomena(skyState, observations);

  // Layer 2: Filtering
  const { passed: filteredEffects, filtered } = filterEffects(rawEffects, date);

  // Layer 3: Convergence
  const { effects: convergedEffects, convergenceMap } = checkConvergence(filteredEffects);

  // Layer 4: Geographic targeting
  const targetedEffects = attachGeographicTargeting(convergedEffects, skyState);

  // Layer 5: Timing
  const timedEffects = attachTiming(targetedEffects, date, skyState);

  // Layer 6: Cancellation + finalization
  const { effects: finalEffects, cancelled } = finalizeEffects(timedEffects, skyState, {
    month: options.month,
    date
  });

  // Jupiter year context
  const jupiterYear = getJupiterYear(date);

  // Hurt nakshatras
  const hurtNakshatras = getAllHurtNakshatras(skyState);

  const elapsed = Date.now() - startTime;

  return {
    effects: finalEffects,
    cancelled,
    filtered,
    convergenceMap,
    jupiterYear,
    hurtNakshatras,
    stats: {
      rawCount: rawEffects.length,
      filteredOut: filtered.length,
      cancelledCount: cancelled.length,
      finalCount: finalEffects.length,
      uniqueDomains: new Set(finalEffects.map(e => e.domain)).size,
      convergentDomains: Object.entries(convergenceMap)
        .filter(([_, v]) => v.signalCount >= 2).length,
      elapsedMs: elapsed
    }
  };
}

/**
 * Generate a human-readable summary of pipeline results.
 *
 * @param {Object} pipelineResult - Output of runPipeline()
 * @returns {string}
 */
export function summarizePipeline(pipelineResult) {
  const { effects, stats, jupiterYear, convergenceMap } = pipelineResult;
  const lines = [];

  lines.push(`═══ BRIHAT SAMHITA ANALYSIS ═══`);
  lines.push(`Jupiter Year: ${jupiterYear?.samvatsara?.name || 'unknown'} (${jupiterYear?.samvatsara?.dir || '?'})`);
  lines.push(`Pipeline: ${stats.rawCount} detected → ${stats.filteredOut} filtered → ${stats.cancelledCount} cancelled → ${stats.finalCount} final effects`);
  lines.push(`Convergent domains (2+ sources): ${stats.convergentDomains}`);
  lines.push('');

  // Top effects by domain
  const byDomain = {};
  for (const e of effects) {
    if (!byDomain[e.domain]) byDomain[e.domain] = [];
    byDomain[e.domain].push(e);
  }

  for (const [domain, domainEffects] of Object.entries(byDomain).sort((a, b) => b[1].length - a[1].length)) {
    const conv = convergenceMap[domain];
    const marker = conv?.signalCount >= 3 ? '◆' : conv?.signalCount === 2 ? '◇' : '○';
    lines.push(`${marker} ${domain.toUpperCase()} (${conv?.signalCount || 1} signals)`);
    for (const e of domainEffects.slice(0, 3)) {
      const dir = e.dir === 'pos' ? '↑' : e.dir === 'neg' ? '↓' : '~';
      lines.push(`  ${dir} ${e.desc} [w:${e.weight.toFixed(2)}, peak:${e.manifestation?.peakDate || '?'}]`);
      if (e.targetRegions?.length > 0) {
        lines.push(`    → Regions: ${e.targetRegions.slice(0, 5).join(', ')}`);
      }
    }
    lines.push('');
  }

  return lines.join('\n');
}
