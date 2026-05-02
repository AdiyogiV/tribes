/**
 * LIVE PREDICTION — Feed a realistic April 2026 sky state into the Brihat Samhita engine.
 */
import { runPipeline, summarizePipeline } from './pipeline.js';
import { getJupiterYear } from './graha/guru.js';

// ─── Approximate planetary positions for mid-April 2026 ─────────────────────
// (Based on standard ephemeris estimates)
const skyState = {
  positions: {
    Sun:     { sign: 'Aries',       nakshatra: 'Bharani',     longitude: 24,  sunDistance: 0 },
    Moon:    { sign: 'Gemini',      nakshatra: 'Mrigashira',  longitude: 68 },
    Mars:    { sign: 'Cancer',      nakshatra: 'Pushya',      longitude: 106, sunDistance: 82 },
    Mercury: { sign: 'Aries',       nakshatra: 'Aswini',      longitude: 12,  sunDistance: 12 },
    Jupiter: { sign: 'Gemini',      nakshatra: 'Ardra',       longitude: 72,  isRetrograde: false },
    Venus:   { sign: 'Pisces',      nakshatra: 'Revati',      longitude: 355, visibility: 'evening' },
    Saturn:  { sign: 'Pisces',      nakshatra: 'Uttara Bhadra', longitude: 340 },
    Rahu:    { sign: 'Pisces',      nakshatra: 'Uttara Bhadra', longitude: 338 },
    Ketu:    { sign: 'Virgo',       nakshatra: 'Hasta',       longitude: 158 }
  }
};

const observations = {
  // Sun visual observation — normal spring appearance
  sunVisual: {
    color: 'white',
    discShape: 'normal',
    hasThamasaKeelaka: false,
    rayColors: ['white', 'golden'],
    hasMockSuns: false,
    hasHalo: false
  },
  season: 'vasanta',

  // No earthquakes currently
  earthquakes: [],

  // Planet-specific contexts
  marsContext: { justEmerged: false },
  mercuryContext: { courseName: 'Prakrita', motionType: 'direct' },
  jupiterContext: { transitSpeed: 'normal' },
  venusContext: { visibility: 'evening' },
  saturnContext: {},

  // An omen observed (hypothetical)
  omens: [
    {
      creature: 'jackal',
      direction: 'south',
      watchOfDay: 3,
      leftRight: 'right',
      distance: 'medium',
      sound: 'howling',
      repetitions: 5,
      action: 'howling_at_sun',
      color: 'brown',
      touchedBody: false
    }
  ]
};

console.log('═══════════════════════════════════════════════════════════');
console.log('  BRIHAT SAMHITA MUNDANE PREDICTION ENGINE');
console.log('  Date: April 14, 2026 (Vaishakha, Vasanta Ritu)');
console.log('═══════════════════════════════════════════════════════════\n');

// Jupiter year info
const jupYear = getJupiterYear(new Date('2026-04-14'));
console.log(`Samvatsara: ${jupYear.samvatsara.name} (Year ${jupYear.samvatsara.index + 1}/60)`);
console.log(`Yuga: ${jupYear.samvatsara.yuga}, Lord: ${jupYear.samvatsara.yugaLord}`);
console.log(`Lustrum Rain Lord: ${jupYear.lustrumLord?.lord || '?'}`);
console.log(`Saka Year: ${jupYear.sakaYear}\n`);

// Run the full pipeline
const result = runPipeline(skyState, observations, {
  date: '2026-04-14',
  month: 'Vaishakha'
});

// Print the summary
const summary = summarizePipeline(result);
console.log(summary);

// ─── Detailed convergence analysis ──────────────────────────────────────────
console.log('\n── CONVERGENCE ANALYSIS ──');
for (const [domain, signals] of Object.entries(result.convergenceMap)) {
  if (signals.length >= 2) {
    const posCount = signals.filter(s => s.dir === 'pos').length;
    const negCount = signals.filter(s => s.dir === 'neg').length;
    const avgWeight = (signals.reduce((s, e) => s + e.weight, 0) / signals.length).toFixed(2);
    console.log(`  ${domain}: ${signals.length} signals (${posCount}↑ ${negCount}↓), avg weight=${avgWeight}`);
  }
}

// ─── Hurt nakshatras ────────────────────────────────────────────────────────
console.log('\n── HURT NAKSHATRAS ──');
if (result.hurtNakshatras.size === 0) {
  console.log('  None detected — no nakshatra is currently afflicted by multiple malefics.');
} else {
  for (const [name, info] of result.hurtNakshatras) {
    console.log(`  ${name}: ${info.reasons?.join(', ') || JSON.stringify(info)}`);
  }
}

// ─── Top 5 highest-weight predictions ───────────────────────────────────────
console.log('\n── TOP 5 PREDICTIONS BY WEIGHT ──');
const sorted = [...result.effects].sort((a, b) => b.weight - a.weight);
for (let i = 0; i < Math.min(5, sorted.length); i++) {
  const e = sorted[i];
  console.log(`  ${i + 1}. [${e.weight.toFixed(2)}] ${e.dir === 'pos' ? '↑' : e.dir === 'neg' ? '↓' : '~'} ${e.desc.slice(0, 100)}`);
  if (e.targetRegions?.length) {
    console.log(`     → ${e.targetRegions.slice(0, 5).join(', ')}`);
  }
  if (e.manifestation) {
    console.log(`     ⏱ Peak: ${e.manifestation}`);
  }
}

console.log('\n═══════════════════════════════════════════════════════════');
console.log(`  Total: ${result.stats.finalCount} predictions across ${result.stats.uniqueDomains} domains in ${result.stats.elapsedMs}ms`);
console.log('═══════════════════════════════════════════════════════════');
