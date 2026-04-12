/**
 * Rule Applier Engine — The Core Brain
 *
 * Takes a sky state (planet positions) and returns ALL active effects,
 * weighted by dignity, combined with conjunctions and eclipses.
 *
 * This is pure computation. No LLM. No API. Just rules + math.
 *
 * Output: a scored, ranked list of mundane effects ready for synthesis.
 */

import { getSlowPlanetEffects } from "../rules/slow_planet_effects.js";
import { getFastPlanetEffects } from "../rules/fast_planet_effects.js";
import { findActiveConjunctions } from "../rules/conjunction_effects.js";
import { evaluateEclipse } from "../rules/eclipse_effects.js";
import { getStrengthModifier, applyModifierToEffects } from "../rules/dignity_modifiers.js";
import { getWorldActivationMap, formatKoormaContext } from "../rules/koorma_chakra.js";
import { DOMAINS } from "../rules/domains.js";
import { getSlowPlanetNakshatraThemes, formatNakshatraContext } from "../rules/nakshatra_effects.js";

/**
 * @typedef {Object} SkyState
 * @property {Object} positions - { planet: { sign, longitude, isRetrograde, sunDistance } }
 * @property {Object[]} [activeEclipses] - Currently active eclipse windows
 * @property {string} date - ISO date string
 */

/**
 * @typedef {Object} ActiveEffect
 * @property {string} ruleId
 * @property {string} planet
 * @property {string} sign
 * @property {string} domain
 * @property {string} dir - "pos" | "neg" | "mix"
 * @property {string} desc
 * @property {number} weight - Final adjusted weight (0-1)
 * @property {number} originalWeight
 * @property {string} source
 * @property {string[]} dignityDetails
 * @property {string[]} affectedRegions
 */

/**
 * Apply all rules to a sky state.
 *
 * @param {SkyState} skyState
 * @returns {Object} Full analysis result
 */
export function applyAllRules(skyState) {
    const { positions, activeEclipses = [], date } = skyState;
    const allEffects = [];

    // ── 1. Planet-in-sign effects (slow + fast) ────────────────────────
    const slowRaw = getSlowPlanetEffects(positions);
    const fastRaw = getFastPlanetEffects(positions);

    for (const effect of [...slowRaw, ...fastRaw]) {
        const strength = getStrengthModifier(effect.planet, positions[effect.planet]);
        const [adjusted] = applyModifierToEffects([effect], strength.totalModifier, strength.dignity.state);
        allEffects.push({
            ...adjusted,
            dignityDetails: strength.details,
            category: slowRaw.includes(effect) ? "slow_transit" : "fast_transit",
        });
    }

    // ── 2. Conjunction effects ─────────────────────────────────────────
    const conjunctions = findActiveConjunctions(positions);
    for (const conj of conjunctions) {
        for (const effect of conj.effects) {
            // Conjunction weight increases when planets are closer
            const proximityBoost = conj.isWar ? 1.3 : conj.isClose ? 1.1 : 1.0;
            allEffects.push({
                ...effect,
                weight: Math.min(1.0, effect.weight * proximityBoost),
                originalWeight: effect.weight,
                planet: conj.planets.join("+"),
                sign: conj.sign,
                ruleId: conj.ruleId,
                source: conj.source,
                dignityDetails: [`${conj.planets.join("+")} in ${conj.sign}, sep: ${conj.separation.toFixed(1)}°`],
                category: "conjunction",
                isWar: conj.isWar,
                warEffects: conj.warEffects,
            });
        }
    }

    // ── 3. Eclipse effects ─────────────────────────────────────────────
    for (const eclipse of activeEclipses) {
        const result = evaluateEclipse(eclipse);
        for (const effect of result.effects) {
            allEffects.push({
                ...effect,
                planet: eclipse.type === "solar" ? "Sun" : "Moon",
                sign: eclipse.sign,
                dignityDetails: [result.desc],
                category: "eclipse",
            });
        }
    }

    // ── 4. Nakshatra sub-themes (slow planets) ─────────────────────────
    const nakshatraThemes = getSlowPlanetNakshatraThemes(positions);
    for (const theme of nakshatraThemes) {
        for (const effect of theme.effects) {
            allEffects.push({
                ...effect,
                weight: Math.min(1.0, effect.weight * theme.intensityMod),
                originalWeight: effect.weight,
                planet: theme.planet,
                sign: positions[theme.planet]?.sign,
                ruleId: theme.ruleId,
                source: "Brihat Samhita + Nakshatra lordship",
                dignityDetails: [`${theme.planet} in ${theme.nakshatra} (${theme.lord}'s nak, pada ${theme.pada})`],
                category: "nakshatra_sub_theme",
            });
        }
    }
    const nakshatraText = formatNakshatraContext(positions);

    // ── 5. Get geographic activation ───────────────────────────────────
    const koormaMap = getWorldActivationMap(positions);
    const koormaText = formatKoormaContext(positions);

    // ── 6. Aggregate by domain ─────────────────────────────────────────
    const domainScores = aggregateByDomain(allEffects);

    // ── 7. Sort all effects by weight (most significant first) ────────
    allEffects.sort((a, b) => b.weight - a.weight);

    return {
        date,
        totalEffects: allEffects.length,
        effects: allEffects,
        conjunctions,
        nakshatraThemes,
        nakshatraText,
        domainScores,
        koormaMap,
        koormaText,
        summary: buildSummary(allEffects, domainScores, conjunctions, nakshatraThemes),
    };
}

/**
 * Aggregate effects by domain, computing net direction and total weight.
 */
function aggregateByDomain(effects) {
    const domains = {};

    for (const e of effects) {
        if (!domains[e.domain]) {
            domains[e.domain] = { positive: 0, negative: 0, mixed: 0, effects: [], label: DOMAINS[e.domain]?.label || e.domain };
        }
        const d = domains[e.domain];
        d.effects.push(e);
        if (e.dir === "pos") d.positive += e.weight;
        else if (e.dir === "neg") d.negative += e.weight;
        else d.mixed += e.weight;
    }

    // Calculate net score and sort
    return Object.entries(domains)
        .map(([key, d]) => ({
            domain: key,
            label: d.label,
            positive: Math.round(d.positive * 100) / 100,
            negative: Math.round(d.negative * 100) / 100,
            mixed: Math.round(d.mixed * 100) / 100,
            netScore: Math.round((d.positive - d.negative) * 100) / 100,
            effectCount: d.effects.length,
            outlook: d.positive > d.negative * 1.3 ? "favorable"
                : d.negative > d.positive * 1.3 ? "challenging"
                : "mixed",
        }))
        .sort((a, b) => Math.abs(b.netScore) - Math.abs(a.netScore));
}

/**
 * Build a compact text summary for LLM synthesis context.
 */
function buildSummary(effects, domainScores, conjunctions, nakshatraThemes = []) {
    const lines = [];

    // Top 5 most impactful effects
    lines.push("## Top Active Effects");
    for (const e of effects.slice(0, 8)) {
        const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
        lines.push(`  ${arrow} [${e.weight.toFixed(2)}] ${e.planet} in ${e.sign}: ${e.desc}`);
    }

    // Domain outlook
    lines.push("\n## Domain Outlook");
    for (const d of domainScores.slice(0, 8)) {
        const emoji = d.outlook === "favorable" ? "🟢" : d.outlook === "challenging" ? "🔴" : "🟡";
        lines.push(`  ${emoji} ${d.label}: ${d.outlook} (net ${d.netScore > 0 ? "+" : ""}${d.netScore})`);
    }

    // Active conjunctions
    if (conjunctions.length > 0) {
        lines.push("\n## Active Conjunctions");
        for (const c of conjunctions) {
            const war = c.isWar ? " ⚔️ PLANETARY WAR" : c.isClose ? " ⚡ close" : "";
            lines.push(`  ${c.planets.join("+")} in ${c.sign} (${c.separation.toFixed(1)}°)${war}`);
        }
    }

    // Nakshatra sub-themes
    if (nakshatraThemes.length > 0) {
        lines.push("\n## Nakshatra Sub-Themes");
        for (const t of nakshatraThemes) {
            lines.push(`  ${t.planet} in ${t.nakshatra} (${t.lord}'s nak, pada ${t.pada})`);
            if (t.hasSpecificEffects) {
                for (const e of t.effects) {
                    const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
                    lines.push(`    ${arrow} ${e.desc}`);
                }
            } else {
                lines.push(`    → ${t.lordTheme}`);
            }
        }
    }

    return lines.join("\n");
}

/**
 * Compare two sky states and return what CHANGED.
 * This is the "Sky Watcher" agent's core logic.
 *
 * @param {Object} prev - Previous positions
 * @param {Object} curr - Current positions
 * @returns {Object[]} Array of change events
 */
export function detectChanges(prev, curr) {
    const changes = [];

    for (const planet of Object.keys(curr)) {
        const p = prev[planet];
        const c = curr[planet];
        if (!p || !c) continue;

        // Sign change (ingress)
        if (p.sign !== c.sign) {
            changes.push({
                type: "ingress",
                planet,
                from: p.sign,
                to: c.sign,
                desc: `${planet} moved from ${p.sign} to ${c.sign}`,
                significance: ["Saturn", "Jupiter", "Rahu", "Ketu"].includes(planet) ? "major" : "minor",
            });
        }

        // Retrograde change
        if (p.isRetrograde !== c.isRetrograde) {
            changes.push({
                type: c.isRetrograde ? "retrograde_start" : "direct_start",
                planet,
                sign: c.sign,
                desc: `${planet} turned ${c.isRetrograde ? "retrograde" : "direct"} in ${c.sign}`,
                significance: "moderate",
            });
        }
    }

    // Check for new conjunctions
    const prevConj = findActiveConjunctions(prev);
    const currConj = findActiveConjunctions(curr);

    for (const cc of currConj) {
        const key = cc.planets.join("-");
        const existed = prevConj.some(pc => pc.planets.join("-") === key && pc.sign === cc.sign);
        if (!existed) {
            changes.push({
                type: "new_conjunction",
                planets: cc.planets,
                sign: cc.sign,
                desc: `${cc.planets.join("+")} conjunction formed in ${cc.sign}`,
                significance: "major",
            });
        }
        // Check if war just started
        if (cc.isWar) {
            const prevVer = prevConj.find(pc => pc.planets.join("-") === key);
            if (prevVer && !prevVer.isWar) {
                changes.push({
                    type: "planetary_war",
                    planets: cc.planets,
                    sign: cc.sign,
                    desc: `${cc.planets.join("+")} entered planetary war in ${cc.sign}`,
                    significance: "critical",
                });
            }
        }
    }

    return changes.sort((a, b) => {
        const sigOrder = { critical: 0, major: 1, moderate: 2, minor: 3 };
        return (sigOrder[a.significance] || 4) - (sigOrder[b.significance] || 4);
    });
}
