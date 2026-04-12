/**
 * Mundane Astrology System — Top-Level Barrel Export
 *
 * Architecture:
 *   rules/     → Brihat Samhita knowledge base (deterministic)
 *   engine/    → Sky adapter + Rule applier + Synthesis agent
 *   functions/ → Cloud Functions (API endpoints + cron)
 */

// Engine (main entry points)
export { buildSkyState, buildSkyStateFromRaw, applyAllRules, detectChanges } from "./engine/index.js";
export { synthesizeForecast, synthesizeFallback } from "./engine/synthesis_agent.js";

// Cloud Functions
export { generateMundaneForecast, getMundaneForecast, refreshMundaneDaily } from "./functions/mundane_forecast.js";

// Rules (for testing and direct access)
export { getSlowPlanetEffects } from "./rules/slow_planet_effects.js";
export { getFastPlanetEffects } from "./rules/fast_planet_effects.js";
export { findActiveConjunctions } from "./rules/conjunction_effects.js";
export { evaluateEclipse } from "./rules/eclipse_effects.js";
export { getWorldActivationMap, formatKoormaContext } from "./rules/koorma_chakra.js";
export { getSlowPlanetNakshatraThemes, formatNakshatraContext } from "./rules/nakshatra_effects.js";
export { getDignity, getStrengthModifier } from "./rules/dignity_modifiers.js";
