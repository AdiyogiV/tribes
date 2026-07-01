/**
 * अध्याय — Adhyaya (Chapters of the Brihat Samhita)
 *
 * Pure knowledge. Zero computation. Just the ancient text encoded as data.
 */
export { readGrahaPhala, getPlanetEffects, GRAHA_PHALA, SLOW_PLANETS, FAST_PLANETS } from "./graha_phala.js";
export { findActiveConjunctions, WAR_TYPES, getWarType, CONJUNCTION_EFFECTS } from "./graha_yuddha.js";
export { evaluateEclipse, getEclipseDurationModifier, POST_ECLIPSE_OMENS, ECLIPSE_SIGN_EFFECTS } from "./grahana.js";
export { KOORMA_CHAKRA, getKoormaRegions, getAffectedRegions, getWorldActivationMap, formatKoormaContext } from "./koorma_chakra.js";
export { getSlowPlanetNakshatraThemes, getNakshatraSubTheme, formatNakshatraContext } from "./nakshatra_phala.js";
export { getDignity, getStrengthModifier, applyModifierToEffects, FRIENDSHIPS } from "./graha_bala.js";
export { DOMAINS, getDomain, getDomainsByHouse, getNewsKeywords, normalizeDomain, getAllDomainKeys } from "./vishaya.js";
export { PAKA, MANIFESTATION_TIMING } from "./paka.js";
