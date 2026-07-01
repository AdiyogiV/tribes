/**
 * बृहत्संहिता — Brihat Samhita Mundane Astrology System
 *
 * Architecture mirrors the original text:
 *
 *   samhita.js  — The complete reading orchestrator
 *   adhyaya/    — अध्याय — Chapters of knowledge (pure BS data)
 *   kriya/      — क्रिया  — The Jyotishi's process (computation)
 *   yantra/     — यन्त्र — Instruments (infrastructure)
 *
 * A Jyotishi's reading follows these steps (Varahamihira's order):
 *   १. काल निर्णय         — Time check (Panchanga trigger)
 *   २. निमित्त अवलोकन     — Observe the world FIRST (news = modern Nimitta)
 *   ३. दृक् गणित          — Sky observation (real positions from Firestore)
 *   ४. फल गणन            — Effect calculation (rules + Nimitta boost)
 *   ५. स्मृति प्रत्याहार    — Recall past readings (Gemini embeddings memory)
 *   ६. फल संग्रह          — Synthesis (narrative with news + memory context)
 *   ७. स्मृति संचय         — Store + learn (Firestore confidence tracking)
 *
 * WIRED TO EXISTING BACKEND:
 *   lib/news_feed.js     → Google News RSS (no reinventing)
 *   lib/agent_memory.js  → Gemini embeddings semantic recall
 *   lib/signal_store.js  → Prediction tracking & confidence
 *   global_astro/sky_positions → Real sidereal positions
 */

// The Reading
export { performReading, performQuickReading } from "./samhita.js";

// Knowledge (Adhyaya)
export { readGrahaPhala, getPlanetEffects, GRAHA_PHALA } from "./adhyaya/graha_phala.js";
export { findActiveConjunctions, WAR_TYPES } from "./adhyaya/graha_yuddha.js";
export { evaluateEclipse } from "./adhyaya/grahana.js";
export { getWorldActivationMap, KOORMA_CHAKRA } from "./adhyaya/koorma_chakra.js";
export { getSlowPlanetNakshatraThemes } from "./adhyaya/nakshatra_phala.js";
export { PAKA } from "./adhyaya/paka.js";

// Process (Kriya)
export { buildSkyState, buildSkyStateFromRaw } from "./kriya/drik_ganita.js";
export { applyAllRules, detectChanges } from "./kriya/phala_ganana.js";
export { observeNimitta, computeDomainHeat, runValidationPipeline } from "./kriya/nimitta_pariksha.js";
export { synthesizeForecast, synthesizeFallback } from "./kriya/phala_sangraha.js";
export { getPurnimaAmavasyaDates, getAllTriggerDates } from "./kriya/kaal_nirnaya.js";
export { applyConfidenceToEffects, getConfidenceSummary } from "./kriya/smriti.js";

// Infrastructure (Yantra)
// NOTE: `refreshMundanePanchanga` (was an `onSchedule` export) is no longer
// re-exported here — it has been replaced by `runRefreshMundanePanchanga`
// invoked from `unifiedOrchestrator`. Import that runner directly from
// `yantra/agni_karya.js` if you need to call it programmatically.
export {
    handleGenerateMundaneForecast, handleGetMundaneForecast,
} from "./yantra/agni_karya.js";
