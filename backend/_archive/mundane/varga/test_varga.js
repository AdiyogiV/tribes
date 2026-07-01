/**
 * VARGA TEST — Runtime verification of the complete Brihat Samhita engine.
 * Tests all 16 modules through imports, unit checks, and full pipeline run.
 */

import { runPipeline, summarizePipeline } from './pipeline.js';

// ─── Module Imports ─────────────────────────────────────────────────────────
import {
  NAKSHATRAS, NAKSHATRA_BY_NAME, isNakshatraHurt, getAllHurtNakshatras,
  getAffectedDependencies, getNakshatraPakaDays, getNakshatraOffset
} from './nakshatra.js';

import {
  assessPlanetBeneficence, jupiterAspectsSign, PLANET_DIGNITY
} from './benefic.js';

import {
  applyCancellations, isSeasonallyDisqualified, getEarthquakeCircleCombination,
  MARS_AUSPICIOUS_EMERGENCE, SEASONAL_DISQUALIFICATION
} from './cancel.js';

import {
  getPakaTiming, applyDoublingRule, calculateManifestationTimeline
} from './paka.js';

import {
  getKurmaDirection, getAffectedRegions, getAffectedDependants
} from './sthana.js';

import {
  assessOmen, isOmenBlasted, getDirectionalTiming, getCreatureStrength,
  checkDivineBlasting, evaluate12Factors
} from './shakuna.js';

import {
  evaluateEarthquake, classifyPortent, getIdolPortentTarget
} from './bhumi.js';

import {
  evaluateMarketConditions, getCommodityTrading, getRasiSubstances
} from './artha.js';

import { evaluateSun } from './graha/surya.js';
import { evaluateMars } from './graha/kuja.js';
import { evaluateMercury } from './graha/budha.js';
import { evaluateJupiter, getJupiterYear, getJupiterYearEffect } from './graha/guru.js';
import { evaluateVenus, getVenusVeethee, getVenusMandala } from './graha/shukra.js';
import { evaluateSaturn, getSaturnNakshatraEffect } from './graha/shani.js';

// ─── Test Infrastructure ────────────────────────────────────────────────────
let passed = 0;
let failed = 0;
const failures = [];

function assert(condition, label) {
  if (condition) {
    passed++;
  } else {
    failed++;
    failures.push(label);
    console.error(`  ✗ FAIL: ${label}`);
  }
}

function section(name) {
  console.log(`\n── ${name} ──`);
}

// ─── 1. NAKSHATRA MODULE ────────────────────────────────────────────────────
section('Nakshatra Module');

assert(NAKSHATRAS.length === 28, 'Should have 28 nakshatras');
assert(NAKSHATRA_BY_NAME.Rohini !== undefined, 'Rohini should exist in lookup');
assert(NAKSHATRA_BY_NAME.Abhijit !== undefined, 'Abhijit (28th) should exist');

// Paka days lookup
const rohiniPaka = getNakshatraPakaDays('Rohini');
assert(typeof rohiniPaka === 'number' && rohiniPaka > 0, `Rohini paka days should be positive number, got ${rohiniPaka}`);

// Offset calculation
const offset = getNakshatraOffset('Aswini', 'Rohini');
assert(typeof offset === 'number', `Offset Aswini→Rohini should be a number, got ${offset}`);

// Hurt detection with sample sky state
const skyForHurt = {
  positions: {
    Sun: { nakshatra: 'Rohini', longitude: 45 },
    Saturn: { nakshatra: 'Rohini', longitude: 46 }
  }
};
const rohiniHurt = isNakshatraHurt('Rohini', skyForHurt);
assert(rohiniHurt.hurt === true, 'Rohini should be hurt when Sun+Saturn occupy it');

const allHurt = getAllHurtNakshatras(skyForHurt);
assert(allHurt instanceof Map, 'getAllHurtNakshatras should return a Map');

const deps = getAffectedDependencies(allHurt);
assert(Array.isArray(deps), 'getAffectedDependencies should return an array');

console.log(`  ✓ Nakshatra: ${NAKSHATRAS.length} nakshatras loaded, hurt detection works`);

// ─── 2. BENEFIC MODULE ─────────────────────────────────────────────────────
section('Benefic Module');

assert(typeof PLANET_DIGNITY === 'object', 'PLANET_DIGNITY should be an object');

const jupiterAssess = assessPlanetBeneficence('Jupiter', {
  positions: {
    Jupiter: { sign: 'Cancer', nakshatra: 'Pushya', isRetrograde: false }
  }
});
assert(typeof jupiterAssess === 'object', 'assessPlanetBeneficence should return an object');
assert(typeof jupiterAssess.score === 'number', `Should have numeric score, got ${typeof jupiterAssess.score}`);
assert(jupiterAssess.score > 0, `Jupiter in Cancer should be benefic (score: ${jupiterAssess.score})`);

// Jupiter aspect check
const jupAspects = jupiterAspectsSign('Aries', {
  positions: { Jupiter: { sign: 'Sagittarius' } }
});
assert(typeof jupAspects === 'boolean', 'jupiterAspectsSign should return boolean');

console.log(`  ✓ Benefic: Jupiter in Cancer score=${jupiterAssess.score.toFixed(2)}`);

// ─── 3. CANCEL MODULE ──────────────────────────────────────────────────────
section('Cancel Module');

assert(MARS_AUSPICIOUS_EMERGENCE.length === 9, `Should have 9 auspicious nakshatras, got ${MARS_AUSPICIOUS_EMERGENCE.length}`);
assert(Object.keys(SEASONAL_DISQUALIFICATION).length >= 5, 'Should have 5+ seasonal entries');

// Seasonal disqualification
const crowInSpring = isSeasonallyDisqualified('crow', new Date('2024-04-15'));
assert(crowInSpring.disqualified === true, 'Crow should be disqualified in vasanta (April)');

const crowInWinter = isSeasonallyDisqualified('crow', new Date('2024-12-15'));
assert(crowInWinter.disqualified === false, 'Crow should NOT be disqualified in hemanta');

// Earthquake circle combination
const eqCombo = getEarthquakeCircleCombination('Indra', 'Vayu');
assert(eqCombo.type === 'cancel', `Indra+Vayu should cancel, got ${eqCombo.type}`);

const eqBeneficial = getEarthquakeCircleCombination('Varuna', 'Indra');
assert(eqBeneficial.type === 'beneficial', `Varuna+Indra should be beneficial, got ${eqBeneficial.type}`);

// Cancellation engine
const testEffects = [
  { domain: 'society', dir: 'neg', category: 'eclipse', sign: 'Aries', weight: 0.8, desc: 'test eclipse' }
];
const cancelResult = applyCancellations(testEffects, {
  positions: { Jupiter: { sign: 'Leo' } }
}, {});
assert(Array.isArray(cancelResult.effects), 'applyCancellations should return effects array');
assert(Array.isArray(cancelResult.cancelled), 'applyCancellations should return cancelled array');

console.log(`  ✓ Cancel: Seasonal disqualification, earthquake combos, cancellation engine all work`);

// ─── 4. PAKA MODULE ────────────────────────────────────────────────────────
section('Paka Module');

const thunderPaka = getPakaTiming('portentous_thunder');
assert(typeof thunderPaka === 'object', 'getPakaTiming should return object');
assert(typeof thunderPaka.days === 'number', `Should have days, got ${JSON.stringify(thunderPaka)}`);

const doubled = applyDoublingRule(30);
assert(doubled.doubledDays === 60, `Doubling 30 should give 60, got ${JSON.stringify(doubled)}`);

const timeline = calculateManifestationTimeline('solar_eclipse', '2024-06-01');
assert(timeline.primaryPeak instanceof Date, 'Timeline should have primaryPeak Date');
assert(typeof timeline.pakaDays === 'number', `Should have pakaDays number, got ${typeof timeline.pakaDays}`);

console.log(`  ✓ Paka: Thunder=${thunderPaka.days}d, eclipse peak=${timeline.primaryPeak.toISOString().split('T')[0]}`);

// ─── 5. STHANA MODULE ──────────────────────────────────────────────────────
section('Sthana Module');

const kurmaDir = getKurmaDirection('Rohini');
assert(typeof kurmaDir === 'object', `getKurmaDirection should return object, got ${typeof kurmaDir}`);
assert(typeof kurmaDir.direction === 'string', `Should have direction string, got ${kurmaDir.direction}`);

const regions = getAffectedRegions('Jupiter', 'Pushya');
assert(typeof regions === 'object', 'getAffectedRegions should return object');
assert(Array.isArray(regions.combined), `Should have combined array, got ${typeof regions.combined}`);

const dependants = getAffectedDependants('Saturn');
assert(typeof dependants === 'object', 'getAffectedDependants should return object');
assert(Array.isArray(dependants.peoples), 'Should have peoples array');

console.log(`  ✓ Sthana: Rohini→${kurmaDir.directionName}, Jupiter+Pushya regions=${regions.combined.length}`);

// ─── 6. SHAKUNA MODULE ─────────────────────────────────────────────────────
section('Shakuna Module');

const dirTiming = getDirectionalTiming('east', 1);
assert(typeof dirTiming === 'object', 'getDirectionalTiming should return object');

const omenTest = assessOmen({
  creature: 'crow',
  direction: 'east',
  watchOfDay: 2,
  leftRight: 'left',
  distance: 'near',
  sound: 'harsh',
  repetitions: 3,
  action: 'flying',
  color: 'black',
  touchedBody: false
}, {
  positions: { Sun: { nakshatra: 'Rohini' } },
  tithi: 5
}, new Date('2024-08-15'));
assert(typeof omenTest === 'object', 'assessOmen should return object');
assert(typeof omenTest.weight === 'number', `Should have weight, got ${typeof omenTest.weight}`);
assert(typeof omenTest.dir === 'string', `Should have dir, got ${typeof omenTest.dir}`);

console.log(`  ✓ Shakuna: Omen assessment weight=${omenTest.weight?.toFixed(3)}, dir=${omenTest.dir}, rejected=${omenTest.rejected}`);

// ─── 7. BHUMI MODULE ───────────────────────────────────────────────────────
section('Bhumi Module');

const eqResult = evaluateEarthquake('Rohini', 'day');
assert(typeof eqResult === 'object', 'evaluateEarthquake should return object');
assert(typeof eqResult.circle === 'string', `Should have circle, got ${typeof eqResult.circle}`);

const portent = classifyPortent('meteor');
assert(typeof portent === 'object', 'classifyPortent should return object');

console.log(`  ✓ Bhumi: Rohini earthquake → circle=${eqResult.circle}, portent tier=${portent.tier || portent.category || '?'}`);

// ─── 8. ARTHA MODULE ───────────────────────────────────────────────────────
section('Artha Module');

const market = evaluateMarketConditions('Aries', {
  Jupiter: { sign: 'Taurus' },
  Saturn: { sign: 'Capricorn' },
  Mars: { sign: 'Aries' }
});
assert(typeof market === 'object', 'evaluateMarketConditions should return object');
assert(Array.isArray(market.effects), 'Should have effects array');

const trading = getCommodityTrading('Aries');
assert(typeof trading === 'object', 'getCommodityTrading should return object');

const rasiSubs = getRasiSubstances('Aries');
assert(typeof rasiSubs === 'object' || Array.isArray(rasiSubs), 'getRasiSubstances should return object/array');

console.log(`  ✓ Artha: Market effects=${market.effects.length}, Aries trading=${JSON.stringify(trading).slice(0, 60)}...`);

// ─── 9. GRAHA — SUN ────────────────────────────────────────────────────────
section('Graha: Sun');

const sunEffects = evaluateSun({
  color: 'red',
  discShape: 'normal',
  hasThamasaKeelaka: false,
  rayColors: ['white', 'red'],
  hasMockSuns: false,
  hasHalo: false
}, 'grishma');
assert(Array.isArray(sunEffects), 'evaluateSun should return array');
console.log(`  ✓ Sun: ${sunEffects.length} effects from visual observation`);

// ─── 10. GRAHA — MARS ──────────────────────────────────────────────────────
section('Graha: Mars');

const marsEffects = evaluateMars({
  positions: {
    Mars: { nakshatra: 'Rohini', longitude: 45 },
    Sun: { nakshatra: 'Aswini', longitude: 10 }
  }
}, { justEmerged: false });
assert(Array.isArray(marsEffects), 'evaluateMars should return array');
console.log(`  ✓ Mars: ${marsEffects.length} effects`);

// ─── 11. GRAHA — MERCURY ───────────────────────────────────────────────────
section('Graha: Mercury');

const mercEffects = evaluateMercury({
  positions: {
    Mercury: { nakshatra: 'Pushya', longitude: 100, sunDistance: 20 }
  }
}, { courseName: 'Prakrita', motionType: 'direct' });
assert(Array.isArray(mercEffects), 'evaluateMercury should return array');
console.log(`  ✓ Mercury: ${mercEffects.length} effects`);

// ─── 12. GRAHA — JUPITER ───────────────────────────────────────────────────
section('Graha: Jupiter');

const jupEffects = evaluateJupiter({
  positions: {
    Jupiter: { sign: 'Cancer', nakshatra: 'Pushya', isRetrograde: false }
  }
}, { transitSpeed: 'normal' });
assert(Array.isArray(jupEffects), 'evaluateJupiter should return array');

const jupYear = getJupiterYear(new Date());
assert(typeof jupYear === 'object', 'getJupiterYear should return object');
assert(typeof jupYear.samvatsara === 'object', `Should have samvatsara, got ${typeof jupYear.samvatsara}`);
assert(typeof jupYear.samvatsara.name === 'string', `Should have samvatsara.name, got ${typeof jupYear.samvatsara?.name}`);

console.log(`  ✓ Jupiter: ${jupEffects.length} effects, year=${jupYear.samvatsara.name} (${jupYear.samvatsara.dir || '?'})`);

// ─── 13. GRAHA — VENUS ─────────────────────────────────────────────────────
section('Graha: Venus');

const venusEffects = evaluateVenus({
  positions: {
    Venus: { nakshatra: 'Rohini', longitude: 45 }
  }
}, { visibility: 'evening' });
assert(Array.isArray(venusEffects), 'evaluateVenus should return array');

const veethee = getVenusVeethee('Rohini');
assert(typeof veethee === 'object', 'getVenusVeethee should return object');

const mandala = getVenusMandala('Rohini');
assert(typeof mandala === 'object', 'getVenusMandala should return object');

console.log(`  ✓ Venus: ${venusEffects.length} effects, veethee=${veethee.name || veethee.grade || '?'}`);

// ─── 14. GRAHA — SATURN ────────────────────────────────────────────────────
section('Graha: Saturn');

const satEffects = evaluateSaturn({
  positions: {
    Saturn: { nakshatra: 'Rohini', longitude: 45, sign: 'Taurus' },
    Jupiter: { sign: 'Cancer', nakshatra: 'Pushya' }
  }
}, {});
assert(Array.isArray(satEffects), 'evaluateSaturn should return array');

const satNak = getSaturnNakshatraEffect('Rohini');
assert(typeof satNak === 'object', 'getSaturnNakshatraEffect should return object');

console.log(`  ✓ Saturn: ${satEffects.length} effects, Rohini → ${satNak.desc?.slice(0, 60) || '?'}`);

// ─── 15. BARREL INDEX IMPORT ────────────────────────────────────────────────
section('Barrel Index');

const barrel = await import('./index.js');
const exportedKeys = Object.keys(barrel);
assert(exportedKeys.length > 30, `Barrel should export 30+ symbols, got ${exportedKeys.length}`);
console.log(`  ✓ Barrel: ${exportedKeys.length} symbols exported`);

// ─── 16. FULL PIPELINE RUN ──────────────────────────────────────────────────
section('Full Pipeline Run');

const skyState = {
  positions: {
    Sun: { sign: 'Aries', nakshatra: 'Aswini', longitude: 10 },
    Mars: { sign: 'Taurus', nakshatra: 'Rohini', longitude: 45, sunDistance: 90 },
    Mercury: { sign: 'Pisces', nakshatra: 'Revati', longitude: 350, sunDistance: 25 },
    Jupiter: { sign: 'Cancer', nakshatra: 'Pushya', longitude: 100, isRetrograde: false },
    Venus: { sign: 'Taurus', nakshatra: 'Krittika', longitude: 40, visibility: 'evening' },
    Saturn: { sign: 'Aquarius', nakshatra: 'Satabhisha', longitude: 310 }
  }
};

const observations = {
  sunVisual: {
    color: 'copper',
    discShape: 'normal',
    hasThamasaKeelaka: true,
    thamasaKeelaka: { count: 2, shape: 'rod', colorVarna: 'dark' },
    rayColors: ['red', 'smoky'],
    hasMockSuns: false,
    hasHalo: true,
    haloColor: 'red'
  },
  season: 'vasanta',
  earthquakes: [
    { nakshatra: 'Rohini', timeOfDay: 'day' }
  ],
  marsContext: { justEmerged: false },
  mercuryContext: { courseName: 'Prakrita', motionType: 'direct' },
  jupiterContext: { transitSpeed: 'normal' },
  venusContext: { visibility: 'evening' },
  saturnContext: {}
};

const result = runPipeline(skyState, observations, { date: '2024-06-15', month: 'Jyeshta' });

assert(typeof result === 'object', 'Pipeline should return object');
assert(Array.isArray(result.effects), 'Should have effects array');
assert(Array.isArray(result.cancelled), 'Should have cancelled array');
assert(Array.isArray(result.filtered), 'Should have filtered array');
assert(typeof result.convergenceMap === 'object', 'Should have convergenceMap');
assert(typeof result.jupiterYear === 'object', 'Should have jupiterYear');
assert(result.hurtNakshatras instanceof Map, 'Should have hurtNakshatras Map');
assert(typeof result.stats === 'object', 'Should have stats');
assert(typeof result.stats.rawCount === 'number', 'Should have rawCount');
assert(typeof result.stats.elapsedMs === 'number', 'Should have elapsedMs');
assert(result.stats.finalCount >= 0, 'finalCount should be >= 0');

console.log(`\n  Pipeline stats:`);
console.log(`    Raw detected:    ${result.stats.rawCount}`);
console.log(`    Filtered out:    ${result.stats.filteredOut}`);
console.log(`    Cancelled:       ${result.stats.cancelledCount}`);
console.log(`    Final effects:   ${result.stats.finalCount}`);
console.log(`    Unique domains:  ${result.stats.uniqueDomains}`);
console.log(`    Convergent:      ${result.stats.convergentDomains}`);
console.log(`    Elapsed:         ${result.stats.elapsedMs}ms`);
console.log(`    Jupiter year:    ${result.jupiterYear?.yearName || '?'}`);

// Test summarize
const summary = summarizePipeline(result);
assert(typeof summary === 'string', 'summarizePipeline should return string');
assert(summary.includes('BRIHAT SAMHITA'), 'Summary should contain header');

console.log(`\n${summary}`);

// ─── FINAL REPORT ───────────────────────────────────────────────────────────
console.log(`\n${'═'.repeat(60)}`);
console.log(`  RESULTS: ${passed} passed, ${failed} failed`);
if (failures.length > 0) {
  console.log(`  FAILURES:`);
  for (const f of failures) console.log(`    • ${f}`);
}
console.log(`${'═'.repeat(60)}`);

process.exit(failed > 0 ? 1 : 0);
