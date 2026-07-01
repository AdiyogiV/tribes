/**
 * FULL BRIHAT SAMHITA READING — The correct process per Varahamihira.
 *
 * Step 1: OBSERVE THE EARTH (Nimitta Sangraha)
 *         → USGS earthquakes, Open-Meteo weather, NASA solar, Google News
 *
 * Step 2: OBSERVE THE SKY (Drik Ganita)
 *         → Planet positions (approximated here, real from Firestore in production)
 *
 * Step 3: APPLY ALL RULES (Phala Ganana via varga/ pipeline)
 *         → 930 rules, 6 layers, zero LLM
 *
 * This is what Varahamihira would do if he had APIs.
 */

import { collectNimitta, summarizeNimitta } from '../kriya/nimitta_sangraha.js';
import { runPipeline, summarizePipeline } from './pipeline.js';

const date = new Date();

console.log('═══════════════════════════════════════════════════════════════════');
console.log('  बृहत्संहिता — COMPLETE MUNDANE READING');
console.log(`  ${date.toDateString()}`);
console.log('═══════════════════════════════════════════════════════════════════');

// ── STEP 1: Observe the Earth ─────────────────────────────────────────────
console.log('\n⏳ Step 1: Collecting Nimitta (observing the earth)...\n');

const observations = await collectNimitta({
  lat: 28.6,   // Delhi — center of Bharatavarsha per Kurma Chakra
  lon: 77.2,
  date,
  earthquakeDays: 7,
  solarDays: 30
});

console.log(summarizeNimitta(observations));

// ── STEP 2: Observe the Sky ───────────────────────────────────────────────
// In production, these come from Firestore (drik_ganita.js).
// Here we use approximate positions for April 2026.
console.log('\n⏳ Step 2: Sky state (Drik Ganita)...\n');

const skyState = {
  positions: {
    Sun:     { sign: 'Aries',   nakshatra: 'Bharani',        longitude: 24,  sunDistance: 0 },
    Moon:    { sign: 'Gemini',  nakshatra: 'Mrigashira',     longitude: 68 },
    Mars:    { sign: 'Cancer',  nakshatra: 'Pushya',         longitude: 106, sunDistance: 82 },
    Mercury: { sign: 'Aries',   nakshatra: 'Aswini',         longitude: 12,  sunDistance: 12 },
    Jupiter: { sign: 'Gemini',  nakshatra: 'Ardra',          longitude: 72,  isRetrograde: false },
    Venus:   { sign: 'Pisces',  nakshatra: 'Revati',         longitude: 355, visibility: 'evening' },
    Saturn:  { sign: 'Pisces',  nakshatra: 'Uttara Bhadra',  longitude: 340 },
    Rahu:    { sign: 'Pisces',  nakshatra: 'Uttara Bhadra',  longitude: 338 },
    Ketu:    { sign: 'Virgo',   nakshatra: 'Hasta',          longitude: 158 }
  }
};

console.log('  Planets:');
for (const [planet, pos] of Object.entries(skyState.positions)) {
  console.log(`    ${planet.padEnd(8)} → ${pos.sign} / ${pos.nakshatra} (${pos.longitude}°)`);
}

// ── STEP 3: Apply All Rules ───────────────────────────────────────────────
console.log('\n⏳ Step 3: Running varga/ pipeline (930 rules, 6 layers)...\n');

const result = runPipeline(skyState, observations, {
  date: date.toISOString().split('T')[0],
  month: 'Vaishakha'
});

console.log(summarizePipeline(result));

// ── NIMITTA IMPACT ANALYSIS ───────────────────────────────────────────────
console.log('\n── NIMITTA IMPACT ON PREDICTIONS ──');
const eqEffects = result.effects.filter(e => e.category === 'earthquake' || e.ruleId?.includes('earthquake'));
const weatherEffects = result.effects.filter(e => e.category === 'atmospheric');
const solarEffects = result.effects.filter(e => e.ruleId?.includes('sun') || e.ruleId?.includes('surya'));

console.log(`  Earthquake-sourced predictions: ${eqEffects.length}`);
console.log(`  Weather anomaly predictions:    ${weatherEffects.length}`);
console.log(`  Solar anomaly predictions:      ${solarEffects.length}`);
console.log(`  Sky-only predictions:           ${result.effects.length - eqEffects.length - weatherEffects.length - solarEffects.length}`);

// ── TOP 5 CONVERGENT PREDICTIONS ──────────────────────────────────────────
console.log('\n── TOP CONVERGENT PREDICTIONS (multi-source confirmed) ──');
const sorted = [...result.effects]
  .filter(e => (e.convergenceSignals || 1) >= 2)
  .sort((a, b) => b.weight - a.weight);

for (let i = 0; i < Math.min(5, sorted.length); i++) {
  const e = sorted[i];
  const dir = e.dir === 'pos' ? '↑' : e.dir === 'neg' ? '↓' : '~';
  console.log(`  ${i + 1}. [${e.weight.toFixed(2)}] ${dir} ${e.desc.slice(0, 90)}`);
  if (e.targetRegions?.length) {
    console.log(`     → ${e.targetRegions.slice(0, 4).join(', ')}`);
  }
  console.log(`     ⏱ Peak: ${e.manifestation?.peakDate || '?'} | Sources: ${e.convergenceSignals || 1}`);
}

// ── SUMMARY ───────────────────────────────────────────────────────────────
console.log('\n═══════════════════════════════════════════════════════════════════');
console.log(`  READING COMPLETE`);
console.log(`  Earth observed: ${observations._meta.nimittaCount} nimitta from ${observations._meta.sources.length} sources`);
console.log(`  Sky computed:   ${Object.keys(skyState.positions).length} grahas`);
console.log(`  Rules applied:  ${result.stats.rawCount} → ${result.stats.finalCount} predictions`);
console.log(`  Convergent:     ${result.stats.convergentDomains} domains with 2+ sources`);
console.log(`  Time:           Nimitta ${observations._meta.elapsedMs}ms + Pipeline ${result.stats.elapsedMs}ms`);
console.log('═══════════════════════════════════════════════════════════════════');
