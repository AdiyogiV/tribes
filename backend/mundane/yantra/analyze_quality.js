/**
 * Deep Quality Analyzer for Brihat Samhita Prediction System
 * Runs against simulation_e2e_results.json and produces a comprehensive report.
 */

import { readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(join(__dirname, "..", "data", "simulation_e2e_results.json"), "utf8"));
const ps = data.predictionStore;

console.log("═".repeat(78));
console.log("  बृहत्संहिता — PREDICTION QUALITY AUDIT");
console.log("═".repeat(78) + "\n");

// ═══════════════════════════════════════════════════════════════════════════
// 1. REPETITION ANALYSIS — Semantic clustering
// ═══════════════════════════════════════════════════════════════════════════

console.log("━".repeat(50));
console.log("1. REPETITION & UNIQUENESS");
console.log("━".repeat(50));

// Extract key phrases for clustering
function extractTheme(stmt) {
    const s = (stmt || "").toLowerCase();
    const themes = [
        [/cyber.?attack|hack|data breach|ransomware/, "cyberattack"],
        [/spiritual.*scandal|religious.*leader.*scandal|faith.*institution.*scandal|pope.*scandal/, "spiritual_scandal"],
        [/maritime.*pollution|maritime.*incident|ship.*disaster|naval.*incident/, "maritime_incident"],
        [/refugee|migration wave|asylum|trafficking|displaced/, "refugee_crisis"],
        [/corruption.*scandal|embezzle|fraud.*institution/, "corruption_scandal"],
        [/waterborne|epidemic|outbreak|pandemic|disease.*spread/, "disease_outbreak"],
        [/diagnostic.*breakthrough|medical.*breakthrough|health.*technology/, "medical_breakthrough"],
        [/domestic violence|abuse.*shelter|hotline/, "domestic_violence"],
        [/trade.*agreement|trade.*deal|tariff|wto/, "trade_deals"],
        [/film|cinema|biennale|cannes|opera|gallery|museum|art.*exhibit/, "cultural_event"],
        [/military.*operation|defense.*spending|naval.*exercise|troops/, "military_ops"],
        [/insurance.*claim|insurance.*rate|lloyd/, "insurance"],
        [/infrastructure.*project|bridge|dam|railway|grid/, "infrastructure"],
        [/labor.*union|strike|wage|worker/, "labor_action"],
        [/education.*initiative|university|school|literacy/, "education"],
        [/banking.*crisis|central.*bank|financial.*institution/, "banking"],
        [/climate|renewable|solar|wind.*energy|carbon/, "energy_climate"],
        [/terror|extremis/, "terrorism"],
        [/sports|football|olympics|fifa/, "sports"],
    ];
    for (const [rx, label] of themes) {
        if (rx.test(s)) return label;
    }
    return "unique";
}

const themeCounts = {};
const themeExamples = {};
for (const p of ps) {
    const theme = extractTheme(p.statement);
    themeCounts[theme] = (themeCounts[theme] || 0) + 1;
    if (!themeExamples[theme]) themeExamples[theme] = [];
    if (themeExamples[theme].length < 3) themeExamples[theme].push(p.statement?.slice(0, 90));
}

const sortedThemes = Object.entries(themeCounts).sort((a, b) => b[1] - a[1]);
for (const [theme, count] of sortedThemes) {
    const pct = ((count / ps.length) * 100).toFixed(0);
    const bar = "█".repeat(Math.round(count / ps.length * 40));
    console.log(`  ${theme.padEnd(22)} ${String(count).padStart(3)} (${pct.padStart(2)}%) ${bar}`);
}

const trulyUnique = themeCounts["unique"] || 0;
const clusterCount = Object.keys(themeCounts).length;
const repetitionRate = (1 - trulyUnique / ps.length) * 100;
console.log(`\n  Themes: ${clusterCount} | Truly unique: ${trulyUnique}/${ps.length} | Repetition rate: ${repetitionRate.toFixed(0)}%`);

// Check for near-identical statements (Levenshtein-like)
let nearDupes = 0;
for (let i = 0; i < ps.length; i++) {
    for (let j = i + 1; j < ps.length; j++) {
        const a = (ps[i].statement || "").toLowerCase().split(/\s+/).slice(0, 10).join(" ");
        const b = (ps[j].statement || "").toLowerCase().split(/\s+/).slice(0, 10).join(" ");
        if (a === b) nearDupes++;
    }
}
console.log(`  Near-duplicate first-10-words matches: ${nearDupes}`);

// ═══════════════════════════════════════════════════════════════════════════
// 2. SPECIFICITY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════

console.log("\n" + "━".repeat(50));
console.log("2. SPECIFICITY & FALSIFIABILITY");
console.log("━".repeat(50));

const countryRx = /\b(india|china|japan|france|italy|spain|australia|indonesia|iran|united states|uk|britain|russia|germany|brazil|turkey|greece|netherlands|belgium|sweden|egypt|korea|argentina|mexico|scotland|bengal|pakistan|israel|norway|thailand|czech|saudi|nigeria|kenya|south africa|canada|new zealand|singapore|philippines|portugal|cyprus|libya|afghanistan|jersey|denmark|austria|iraq|syria|yemen|lebanon|jordan|oman|qatar|bahrain|kuwait|uae|morocco|algeria|tunisia|ethiopia|somalia|myanmar|vietnam|cambodia|malaysia|colombia|venezuela|peru|chile|ukraine|poland|hungary|romania|croatia|serbia|finland|estonia|latvia|lithuania|iceland|ireland|switzerland|nepal|bangladesh|sri lanka|maldives|fiji|tonga|samoa)\b/gi;
const orgRx = /\b(WHO|IMO|IOM|UNESCO|NATO|ASEAN|EU\b|IMF|World Bank|WTO|OPEC|ICC|ICJ|IAEA|UNHCR|Red Cross|FIFA|ESA|NASA|CERN|Interpol|Vatican|Ministry|Parliament|Supreme Court|Court of Justice|Lloyd|Cannes|Biennale|Olympics|Anonymous|Home Office|Federal Reserve|ECB|Amnesty|Médecins|UNICEF|FAO|ILO)\b/gi;
const mechanismRx = /\b(strike|port closure|sanction|tariff|embargo|arrest|indictment|seizure|election|referendum|summit|treaty|regulation|legislation|investigation|bankruptcy|merger|acquisition|deployment|evacuation|quarantine|blockade|ceasefire)\b/gi;

let withCountry = 0, withOrg = 0, withMechanism = 0;
const countriesFound = new Set();
const orgsFound = new Set();

for (const p of ps) {
    const s = p.statement || "";
    const cm = s.match(countryRx);
    const om = s.match(orgRx);
    const mm = s.match(mechanismRx);
    if (cm) { withCountry++; cm.forEach(c => countriesFound.add(c.toLowerCase())); }
    if (om) { withOrg++; om.forEach(o => orgsFound.add(o)); }
    if (mm) withMechanism++;
}

console.log(`  With country:    ${withCountry}/${ps.length} (${((withCountry/ps.length)*100).toFixed(0)}%)`);
console.log(`  With org:        ${withOrg}/${ps.length} (${((withOrg/ps.length)*100).toFixed(0)}%)`);
console.log(`  With mechanism:  ${withMechanism}/${ps.length} (${((withMechanism/ps.length)*100).toFixed(0)}%)`);
console.log(`  Unique countries: ${countriesFound.size} — ${[...countriesFound].slice(0, 15).join(", ")}${countriesFound.size > 15 ? "..." : ""}`);
console.log(`  Unique orgs:     ${orgsFound.size} — ${[...orgsFound].slice(0, 10).join(", ")}${orgsFound.size > 10 ? "..." : ""}`);

// Specificity score per prediction (0-5)
let specScoreTotal = 0;
const specDist = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
for (const p of ps) {
    const s = p.statement || "";
    let score = 1; // base
    if (countryRx.test(s)) score++;
    countryRx.lastIndex = 0;
    if (orgRx.test(s)) score++;
    orgRx.lastIndex = 0;
    if (mechanismRx.test(s)) score++;
    mechanismRx.lastIndex = 0;
    if (s.length > 120) score++; // longer = more detailed
    score = Math.min(5, score);
    specDist[score]++;
    specScoreTotal += score;
}
const avgSpec = (specScoreTotal / ps.length).toFixed(1);
console.log(`\n  Specificity distribution (1=vague, 5=falsifiable):`);
for (const [score, count] of Object.entries(specDist)) {
    const bar = "█".repeat(Math.round(count / ps.length * 40));
    console.log(`    Score ${score}: ${String(count).padStart(3)} (${((count/ps.length)*100).toFixed(0).padStart(2)}%) ${bar}`);
}
console.log(`  Average specificity: ${avgSpec}/5`);

// ═══════════════════════════════════════════════════════════════════════════
// 3. DIRECTION BALANCE
// ═══════════════════════════════════════════════════════════════════════════

console.log("\n" + "━".repeat(50));
console.log("3. DIRECTION BALANCE");
console.log("━".repeat(50));

const dirs = { pos: 0, neg: 0, mix: 0 };
for (const p of ps) dirs[p.direction] = (dirs[p.direction] || 0) + 1;
for (const [d, c] of Object.entries(dirs)) {
    const bar = "█".repeat(Math.round(c / ps.length * 40));
    console.log(`  ${d.padEnd(5)} ${String(c).padStart(3)} (${((c/ps.length)*100).toFixed(0).padStart(2)}%) ${bar}`);
}
const ratio = dirs.neg / Math.max(1, dirs.pos);
console.log(`  Neg/Pos ratio: ${ratio.toFixed(1)}:1 ${ratio > 2 ? "⚠️ TOO NEGATIVE" : ratio < 1 ? "⚠️ TOO POSITIVE" : "✅ BALANCED"}`);

// ═══════════════════════════════════════════════════════════════════════════
// 4. DOMAIN COVERAGE
// ═══════════════════════════════════════════════════════════════════════════

console.log("\n" + "━".repeat(50));
console.log("4. DOMAIN COVERAGE");
console.log("━".repeat(50));

const allDomains = [
    "government", "military", "economy", "banking", "trade", "agriculture",
    "health", "media", "religion", "judiciary", "education", "foreign_affairs",
    "diplomacy", "public_mood", "real_estate", "technology", "social_movements",
    "humanitarian", "refugees", "maritime", "crisis", "mortality", "taxation",
    "insurance", "labor", "infrastructure", "transport", "entertainment",
    "culture", "sports", "research", "terrorism", "resources",
];

const domCounts = {};
for (const p of ps) domCounts[p.domain] = (domCounts[p.domain] || 0) + 1;
const covered = Object.keys(domCounts);
const missing = allDomains.filter(d => !domCounts[d]);

for (const d of covered.sort((a, b) => domCounts[b] - domCounts[a])) {
    const bar = "█".repeat(domCounts[d] * 2);
    console.log(`  ${d.padEnd(22)} ${String(domCounts[d]).padStart(2)} ${bar}`);
}
console.log(`\n  Covered: ${covered.length}/${allDomains.length} (${((covered.length/allDomains.length)*100).toFixed(0)}%)`);
if (missing.length > 0) console.log(`  Missing: ${missing.join(", ")}`);

// ═══════════════════════════════════════════════════════════════════════════
// 5. PAKA COMPLIANCE
// ═══════════════════════════════════════════════════════════════════════════

console.log("\n" + "━".repeat(50));
console.log("5. PAKA COMPLIANCE (BS Ch.97)");
console.log("━".repeat(50));

const pakaBuckets = { "≤30d": 0, "31-90d": 0, "91-200d": 0, "201-365d": 0, ">365d": 0 };
for (const p of ps) {
    const d = p.pakaDelayDays || 30;
    if (d <= 30) pakaBuckets["≤30d"]++;
    else if (d <= 90) pakaBuckets["31-90d"]++;
    else if (d <= 200) pakaBuckets["91-200d"]++;
    else if (d <= 365) pakaBuckets["201-365d"]++;
    else pakaBuckets[">365d"]++;
}
for (const [bucket, count] of Object.entries(pakaBuckets)) {
    const pct = ((count / ps.length) * 100).toFixed(0);
    const bar = "█".repeat(Math.round(count / ps.length * 40));
    console.log(`  ${bucket.padEnd(10)} ${String(count).padStart(3)} (${pct.padStart(2)}%) ${bar}`);
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. HEADLINE DIVERSITY
// ═══════════════════════════════════════════════════════════════════════════

console.log("\n" + "━".repeat(50));
console.log("6. HEADLINE DIVERSITY");
console.log("━".repeat(50));

const headlines = data.results.map(r => r.headline || "");
const hlWords = {};
for (const h of headlines) {
    for (const w of h.toLowerCase().split(/\s+/).filter(w => w.length > 5)) {
        hlWords[w] = (hlWords[w] || 0) + 1;
    }
}
const overused = Object.entries(hlWords).filter(([, c]) => c >= 5).sort((a, b) => b[1] - a[1]);
if (overused.length > 0) {
    console.log(`  Overused words (5+ appearances): ${overused.map(([w, c]) => `${w}(${c})`).join(", ")}`);
} else {
    console.log("  ✅ No overused words (all < 5 appearances)");
}

// Unique headline count (case-insensitive first 40 chars)
const hlPrefixes = new Set(headlines.map(h => h.toLowerCase().slice(0, 40)));
console.log(`  Unique headline prefixes: ${hlPrefixes.size}/${headlines.length}`);

// ═══════════════════════════════════════════════════════════════════════════
// 7. VALIDATION OUTCOMES
// ═══════════════════════════════════════════════════════════════════════════

console.log("\n" + "━".repeat(50));
console.log("7. VALIDATION OUTCOMES");
console.log("━".repeat(50));

const statuses = {};
for (const p of ps) statuses[p.status] = (statuses[p.status] || 0) + 1;
for (const [s, c] of Object.entries(statuses).sort((a, b) => b[1] - a[1])) {
    const icon = s === "plausible" ? "✅" : s === "pending" ? "⏳" : s === "echo" ? "🔄" : "❌";
    console.log(`  ${icon} ${s.padEnd(15)} ${c} (${((c/ps.length)*100).toFixed(0)}%)`);
}

// ═══════════════════════════════════════════════════════════════════════════
// 8. SAMPLE BEST & WORST PREDICTIONS
// ═══════════════════════════════════════════════════════════════════════════

console.log("\n" + "━".repeat(50));
console.log("8. BEST & WORST PREDICTIONS");
console.log("━".repeat(50));

// Score each prediction
const scored = ps.map(p => {
    const s = p.statement || "";
    let score = 0;
    if (countryRx.test(s)) score += 2; countryRx.lastIndex = 0;
    if (orgRx.test(s)) score += 2; orgRx.lastIndex = 0;
    if (mechanismRx.test(s)) score += 2; mechanismRx.lastIndex = 0;
    if (s.length > 150) score += 1;
    if (extractTheme(s) === "unique") score += 2;
    return { ...p, qualityScore: score };
}).sort((a, b) => b.qualityScore - a.qualityScore);

console.log("\n  🏆 TOP 5 (most specific + unique):");
for (const p of scored.slice(0, 5)) {
    console.log(`  [${p.domain}] score=${p.qualityScore} | ${p.drivingPlanet} ${p.pakaDelayDays}d`);
    console.log(`    "${p.statement?.slice(0, 150)}"`);
}

console.log("\n  💩 BOTTOM 5 (vaguest / most generic):");
for (const p of scored.slice(-5).reverse()) {
    console.log(`  [${p.domain}] score=${p.qualityScore} | ${p.drivingPlanet} ${p.pakaDelayDays}d`);
    console.log(`    "${p.statement?.slice(0, 150)}"`);
}

console.log("\n" + "═".repeat(78));
console.log("  AUDIT COMPLETE");
console.log("═".repeat(78));
