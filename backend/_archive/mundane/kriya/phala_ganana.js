/**
 * क्रिया ३ — फल गणन (Phala Ganana: Effect Calculation)
 *
 * "Now read each chapter of the Samhita and note what it says
 *  for the current positions of the grahas."
 *
 * The core computation engine. Pure rules + math. No LLM.
 * Reads from ALL adhyaya (chapters) and aggregates effects.
 *
 * Steps within:
 *   ३a. Read ग्रह फल (planet-sign effects)
 *   ३b. Apply ग्रह बल (strength modifiers)
 *   ३c. Check ग्रह युद्ध (conjunctions/wars)
 *   ३d. Evaluate ग्रहण (eclipse windows)
 *   ३e. Read नक्षत्र फल (star sub-themes)
 *   ३f. Map कूर्म चक्र (geography)
 *   ३g. Apply पाक (manifestation timing)
 *   ३h. Aggregate by विषय (domain)
 */

import { readGrahaPhala } from "../adhyaya/graha_phala.js";
import { PAKA } from "../adhyaya/paka.js";
import { findActiveConjunctions } from "../adhyaya/graha_yuddha.js";
import { evaluateEclipse } from "../adhyaya/grahana.js";
import { getStrengthModifier, applyModifierToEffects } from "../adhyaya/graha_bala.js";
import { getWorldActivationMap, formatKoormaContext } from "../adhyaya/koorma_chakra.js";
import { DOMAINS } from "../adhyaya/vishaya.js";
import { getSlowPlanetNakshatraThemes, formatNakshatraContext } from "../adhyaya/nakshatra_phala.js";

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
 * Compute a human-readable peak date from a base date + delay.
 * @param {string} baseDate - ISO date "YYYY-MM-DD"
 * @param {number} delayDays
 * @returns {string} "YYYY-MM-DD" or "~Mon YYYY" for long delays
 */
function computePeakDate(baseDate, delayDays) {
    if (!baseDate || !delayDays) return null;
    const d = new Date(baseDate);
    d.setDate(d.getDate() + delayDays);
    if (delayDays > 90) {
        // For long delays, show month+year (more honest about precision)
        const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
        return `~${months[d.getMonth()]} ${d.getFullYear()}`;
    }
    return d.toISOString().split("T")[0];
}

/**
 * Apply all rules to a sky state.
 *
 * @param {SkyState} skyState
 * @returns {Object} Full analysis result
 */
export function applyAllRules(skyState) {
    const { positions, activeEclipses = [], date } = skyState;
    const allEffects = [];

    // ── 1. Planet-in-sign effects (all planets in one call) ──────────
    // BS Ch.97 (Paka Adhyaya): EVERY effect gets manifestation timing
    // based on its driving planet. This is the core PAKA compliance fix.
    for (const effect of readGrahaPhala(positions)) {
        const strength = getStrengthModifier(effect.planet, positions[effect.planet]);
        const [adjusted] = applyModifierToEffects([effect], strength.totalModifier, strength.dignity.state);

        // Attach PAKA timing from the driving planet
        const paka = PAKA[effect.planet];
        const manifestation = effect.manifestation || (paka ? {
            delayDays: paka.delayDays,
            peakDesc: paka.peakDesc,
            source: paka.source,
        } : null);
        const peakDate = manifestation
            ? computePeakDate(date, manifestation.delayDays)
            : null;

        allEffects.push({
            ...adjusted,
            dignityDetails: strength.details,
            category: effect.layer === "slow" ? "slow_transit" : "fast_transit",
            manifestation: manifestation ? { ...manifestation, peakDate } : null,
        });
    }

    // ── 2. Conjunction effects ─────────────────────────────────────────
    const conjunctions = findActiveConjunctions(positions);
    for (const conj of conjunctions) {
        // PAKA for conjunctions: use the SLOWEST planet's timing
        // (e.g., Saturn+Mars conjunction → Saturn's 365-day PAKA)
        const conjPaka = conj.planets.reduce((slowest, p) => {
            const paka = PAKA[p];
            if (!paka) return slowest;
            return (!slowest || paka.delayDays > slowest.delayDays) ? paka : slowest;
        }, null);
        const conjManifestation = conjPaka ? {
            delayDays: conjPaka.delayDays,
            peakDesc: conjPaka.peakDesc,
            source: conjPaka.source,
        } : null;
        const conjPeakDate = conjManifestation
            ? computePeakDate(date, conjManifestation.delayDays)
            : null;

        for (const effect of conj.effects) {
            // BS Ch.17: War type severity boosts, wide distance penalizes
            const proximityBoost = conj.warType ? conj.warType.severity : 1.0;
            const distancePenalty = conj.distancePenalty || 1.0;
            allEffects.push({
                ...effect,
                weight: Math.min(1.0, effect.weight * proximityBoost * distancePenalty),
                originalWeight: effect.weight,
                planet: conj.planets.join("+"),
                sign: conj.sign,
                ruleId: conj.ruleId,
                source: conj.source,
                dignityDetails: [
                    `${conj.planets.join("+")} in ${conj.sign}, sep: ${conj.separation.toFixed(1)}°`,
                    conj.warType ? `War type: ${conj.warType.name} — ${conj.warType.effect}` : null,
                    conj.classicalVictims || null,
                ].filter(Boolean),
                category: "conjunction",
                isWar: conj.isWar,
                warType: conj.warType,
                warEffects: conj.warEffects,
                affectedRegions: conj.affectedRegions,
                manifestation: conjManifestation ? { ...conjManifestation, peakDate: conjPeakDate } : null,
            });
        }
    }

    // ── 3. Eclipse effects ─────────────────────────────────────────────
    for (const eclipse of activeEclipses) {
        const result = evaluateEclipse(eclipse);
        // Compute how far we are into the eclipse window (0-1 scale)
        const eclipseDate = eclipse.date || date;
        const daysSinceEclipse = Math.max(0, (new Date(date) - new Date(eclipseDate)) / 86400000);
        const windowDays = (result.windowMonths || 6) * 30;
        // Fade eclipse effects as window progresses (full at start, 0.5x at end)
        const windowFade = daysSinceEclipse < windowDays
            ? 1.0 - (daysSinceEclipse / windowDays) * 0.5
            : 0;

        if (windowFade <= 0) continue; // Eclipse window expired

        for (const effect of result.effects) {
            const peakDate = effect.manifestation
                ? computePeakDate(eclipseDate, effect.manifestation.delayDays)
                : null;
            allEffects.push({
                ...effect,
                weight: Math.min(1.0, effect.weight * windowFade),
                planet: eclipse.type === "solar" ? "Sun" : "Moon",
                sign: eclipse.sign,
                dignityDetails: [
                    result.desc,
                    result.classicalVictims ? `BS Ch.5: ${result.classicalVictims}` : null,
                    `Eclipse: ${eclipse.date || "unknown"}, window fade: ${(windowFade * 100).toFixed(0)}%`,
                ].filter(Boolean),
                category: "eclipse",
                manifestation: effect.manifestation ? { ...effect.manifestation, peakDate } : null,
            });
        }
    }

    // ── 4. Nakshatra sub-themes (slow planets) ─────────────────────────
    const nakshatraThemes = getSlowPlanetNakshatraThemes(positions);
    for (const theme of nakshatraThemes) {
        const timing = PAKA[theme.planet];
        const peakDate = timing ? computePeakDate(date, timing.delayDays) : null;
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
                manifestation: timing ? {
                    delayDays: timing.delayDays,
                    peakDesc: timing.peakDesc,
                    peakDate,
                } : null,
            });
        }
    }
    const nakshatraText = formatNakshatraContext(positions);

    // ── 5. Get geographic activation ───────────────────────────────────
    const koormaMap = getWorldActivationMap(positions);
    const koormaText = formatKoormaContext(positions);

    // ── 6. Apply Nimitta boost (if domain heat provided) ────────────────
    // This is the key insight: a real Jyotishi observes the world BEFORE
    // speaking. If the news shows turmoil in economy, the Saturn-in-Pisces
    // economy effects get amplified. Nimitta SHAPES the reading.
    if (skyState.domainHeat) {
        applyDomainHeat(allEffects, skyState.domainHeat);
    }

    // ── 7. Aggregate by domain ─────────────────────────────────────────
    const domainScores = aggregateByDomain(allEffects);

    // ── 8. Sort all effects by weight (most significant first) ────────
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
        domainHeatApplied: !!skyState.domainHeat,
        summary: buildSummary(allEffects, domainScores, conjunctions, nakshatraThemes),
    };
}

/**
 * Apply Nimitta (news domain heat) to astrological effects.
 *
 * Like Varahamihira observing the world before speaking:
 * - "Hot" domains in the news amplify matching astrological effects
 * - This is NOT post-hoc validation — it shapes the reading
 * - Max boost: 30% (heat 1.0) — Nimitta informs, doesn't override Jyotish
 * - Cold/absent domains get no penalty (absence of news ≠ absence of effect)
 *
 * @param {Object[]} effects - Mutable array of effects (modified in-place)
 * @param {Object} domainHeat - { domain: { normalizedHeat, count, ... } }
 */
function applyDomainHeat(effects, domainHeat) {
    for (const effect of effects) {
        const heat = domainHeat[effect.domain];
        if (!heat || !heat.normalizedHeat) continue;

        // Boost: up to 30% for domains with heat = 1.0
        // Formula: weight * (1 + 0.3 * normalizedHeat)
        const nimittaBoost = 1 + 0.3 * heat.normalizedHeat;
        effect.preNimittaWeight = effect.weight;
        effect.weight = Math.min(1.0, Math.round(effect.weight * nimittaBoost * 100) / 100);
        effect.nimittaBoost = Math.round((nimittaBoost - 1) * 100);
        effect.nimittaHeadlines = (heat.headlines || []).slice(0, 2);
    }
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

    // Top 8 most impactful effects
    lines.push("## Top Active Effects");
    for (const e of effects.slice(0, 8)) {
        const arrow = e.dir === "pos" ? "↑" : e.dir === "neg" ? "↓" : "↔";
        const timing = e.manifestation?.peakDate
            ? ` [peaks ${e.manifestation.peakDate}]`
            : e.manifestation ? ` [peaks in ~${e.manifestation.delayDays}d]` : "";
        lines.push(`  ${arrow} [${e.weight.toFixed(2)}] ${e.planet} in ${e.sign}: ${e.desc}${timing}`);
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
            const warLabel = c.warType
                ? ` ⚔️ ${c.warType.name}: ${c.warType.effect}`
                : c.isClose ? " ⚡ close" : "";
            lines.push(`  ${c.planets.join("+")} in ${c.sign} (${c.separation.toFixed(1)}°)${warLabel}`);
            if (c.affectedRegions?.length) {
                lines.push(`    Regions: ${c.affectedRegions.join(", ")}`);
            }
            if (c.classicalVictims) {
                lines.push(`    BS Ch.17: ${c.classicalVictims}`);
            }
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
