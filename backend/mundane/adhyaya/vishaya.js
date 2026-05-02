/**
 * विषय — Vishaya (Mundane Domains)
 *
 * The 12 mundane houses and their modern equivalents.
 * Every effect in the rules engine references a "domain" — a category
 * of worldly affairs mapped to these houses.
 *
 * Also maps domains to news categories for correlation.
 */

export const DOMAINS = {
    government:       { house: 10, label: "Government & Authority", newsKeywords: ["president", "prime minister", "government", "regime", "executive order", "parliament", "congress", "legislation"] },
    military:         { house: 6,  label: "Military & Defense", newsKeywords: ["military", "army", "navy", "air force", "defense", "war", "missile", "troops", "invasion"] },
    economy:          { house: 2,  label: "Economy & Finance", newsKeywords: ["economy", "GDP", "inflation", "recession", "stock market", "interest rate", "central bank", "fiscal"] },
    banking:          { house: 2,  label: "Banking & Currency", newsKeywords: ["bank", "currency", "dollar", "euro", "forex", "federal reserve", "IMF", "world bank"] },
    trade:            { house: 7,  label: "Trade & Commerce", newsKeywords: ["trade", "tariff", "import", "export", "supply chain", "commerce", "sanctions", "trade war"] },
    agriculture:      { house: 4,  label: "Agriculture & Food", newsKeywords: ["agriculture", "crop", "harvest", "famine", "food price", "drought", "farming", "livestock"] },
    health:           { house: 6,  label: "Health & Epidemics", newsKeywords: ["health", "epidemic", "pandemic", "WHO", "vaccine", "disease", "hospital", "outbreak"] },
    media:            { house: 3,  label: "Media & Communication", newsKeywords: ["media", "press", "journalist", "censorship", "social media", "disinformation", "broadcast"] },
    religion:         { house: 9,  label: "Religion & Spirituality", newsKeywords: ["religion", "church", "mosque", "temple", "pope", "imam", "spiritual", "faith", "sect"] },
    judiciary:        { house: 9,  label: "Judiciary & Law", newsKeywords: ["court", "supreme court", "judge", "ruling", "verdict", "constitution", "law", "prosecution"] },
    education:        { house: 9,  label: "Education & Knowledge", newsKeywords: ["university", "education", "school", "research", "scholarship", "academic", "science"] },
    foreign_affairs:  { house: 7,  label: "Foreign Affairs & Diplomacy", newsKeywords: ["diplomat", "treaty", "alliance", "NATO", "UN", "embassy", "summit", "bilateral"] },
    diplomacy:        { house: 7,  label: "Diplomatic Relations", newsKeywords: ["peace", "negotiation", "ceasefire", "accord", "mediation", "reconciliation"] },
    public_mood:      { house: 1,  label: "Public Mood & Social Climate", newsKeywords: ["protest", "unrest", "poll", "approval", "sentiment", "public opinion", "civil"] },
    real_estate:      { house: 4,  label: "Real Estate & Housing", newsKeywords: ["housing", "property", "real estate", "mortgage", "construction", "building"] },
    technology:       { house: 11, label: "Technology & Innovation", newsKeywords: ["technology", "AI", "cyber", "internet", "startup", "silicon valley", "innovation"] },
    social_movements: { house: 11, label: "Social Movements & Reform", newsKeywords: ["protest", "movement", "reform", "activism", "revolution", "demonstration", "rights"] },
    humanitarian:     { house: 12, label: "Humanitarian & Aid", newsKeywords: ["refugee", "aid", "humanitarian", "NGO", "Red Cross", "asylum", "charity", "relief"] },
    refugees:         { house: 12, label: "Refugees & Migration", newsKeywords: ["refugee", "migrant", "asylum", "displacement", "immigration", "border", "exodus"] },
    maritime:         { house: 12, label: "Maritime & Naval", newsKeywords: ["ship", "naval", "port", "maritime", "coast", "ocean", "piracy", "shipping"] },
    crisis:           { house: 8,  label: "Crisis & Transformation", newsKeywords: ["crisis", "emergency", "catastrophe", "disaster", "collapse", "meltdown"] },
    mortality:        { house: 8,  label: "Death & Destruction", newsKeywords: ["death", "killed", "casualties", "massacre", "genocide", "earthquake", "tsunami"] },
    taxation:         { house: 8,  label: "Taxation & Debt", newsKeywords: ["tax", "debt", "deficit", "austerity", "spending", "budget", "fiscal"] },
    insurance:        { house: 8,  label: "Insurance & Inheritance", newsKeywords: ["insurance", "inheritance", "pension", "social security", "benefits"] },
    labor:            { house: 6,  label: "Labor & Employment", newsKeywords: ["unemployment", "jobs", "labor", "strike", "union", "workers", "wages", "layoff"] },
    infrastructure:   { house: 4,  label: "Infrastructure & Construction", newsKeywords: ["infrastructure", "bridge", "road", "building", "construction", "collapse"] },
    transport:        { house: 3,  label: "Transport & Travel", newsKeywords: ["transport", "airline", "railway", "road", "accident", "traffic", "aviation"] },
    entertainment:    { house: 5,  label: "Entertainment & Culture", newsKeywords: ["entertainment", "film", "music", "celebrity", "sports", "festival", "arts"] },
    culture:          { house: 5,  label: "Culture & Arts", newsKeywords: ["culture", "art", "museum", "heritage", "tradition", "dance", "theater"] },
    sports:           { house: 5,  label: "Sports & Competition", newsKeywords: ["sports", "olympics", "football", "cricket", "championship", "athlete"] },
    research:         { house: 8,  label: "Research & Discovery", newsKeywords: ["research", "discovery", "breakthrough", "study", "experiment", "science"] },
    terrorism:        { house: 8,  label: "Terrorism & Extremism", newsKeywords: ["terrorism", "terrorist", "extremism", "bomb", "attack", "militant", "ISIS"] },
    resources:        { house: 2,  label: "Natural Resources", newsKeywords: ["oil", "gas", "mineral", "mining", "energy", "OPEC", "coal", "lithium"] },
};

/**
 * Get domain info by key.
 */
export function getDomain(key) {
    return DOMAINS[key] || null;
}

/**
 * Get all domains for a mundane house number.
 */
export function getDomainsByHouse(house) {
    return Object.entries(DOMAINS)
        .filter(([, d]) => d.house === house)
        .map(([key, d]) => ({ key, ...d }));
}

/**
 * Get all news keywords for a domain.
 */
export function getNewsKeywords(domainKey) {
    return DOMAINS[domainKey]?.newsKeywords || [];
}

// ─── Domain Name Normalization ──────────────────────────────────────────
// LLM outputs use inconsistent domain names: "Maritime & Naval", "Health & Epidemics",
// "Foreign Affairs & Diplomacy", etc. These must be mapped back to canonical keys
// (e.g., "maritime", "health", "foreign_affairs") for validation matching.

// Pre-built reverse lookup: label → key, lowercase label → key
const _domainLabelMap = new Map();
const _domainWordMap = new Map(); // individual significant words → key

for (const [key, info] of Object.entries(DOMAINS)) {
    _domainLabelMap.set(key.toLowerCase(), key);
    _domainLabelMap.set(info.label.toLowerCase(), key);
    // Also map without " & " variants: "maritime & naval" → "maritime"
    // And just the first word: "Maritime" → "maritime"
    const words = info.label.toLowerCase().split(/[\s&,]+/).filter(w => w.length > 2);
    for (const w of words) {
        if (!_domainWordMap.has(w) || key === w) {
            _domainWordMap.set(w, key);
        }
    }
}

/**
 * Normalize a domain name to its canonical key.
 * Handles: exact key, exact label, partial match, fuzzy word match.
 *
 * "Maritime & Naval" → "maritime"
 * "Health & Epidemics" → "health"
 * "Foreign Affairs & Diplomacy" → "foreign_affairs"
 * "Refugees & Migration" → "refugees"
 * "Religion & Spirituality" → "religion"
 * "economy" → "economy" (passthrough)
 *
 * @param {string} domainStr - Free-text domain name from LLM
 * @returns {string} Canonical domain key, or original string if no match
 */
export function normalizeDomain(domainStr) {
    if (!domainStr || typeof domainStr !== "string") return domainStr;

    const trimmed = domainStr.trim();

    // 1. Exact key match
    if (DOMAINS[trimmed]) return trimmed;

    // 2. Case-insensitive key match
    const lower = trimmed.toLowerCase();
    if (DOMAINS[lower]) return lower;

    // 3. Exact label match (case-insensitive)
    const fromLabel = _domainLabelMap.get(lower);
    if (fromLabel) return fromLabel;

    // 4. Try stripping "& ..." suffix: "Foreign Affairs & Diplomacy" → "foreign affairs"
    const beforeAmp = lower.split("&")[0].trim();
    const fromPartial = _domainLabelMap.get(beforeAmp);
    if (fromPartial) return fromPartial;

    // 5. Word-level match: find the word that maps to a domain key
    const words = lower.split(/[\s&,]+/).filter(w => w.length > 2);
    for (const w of words) {
        const hit = _domainWordMap.get(w);
        if (hit) return hit;
    }

    // 6. Underscore join attempt: "foreign affairs" → "foreign_affairs"
    const underscored = words.join("_");
    if (DOMAINS[underscored]) return underscored;

    // 7. No match — return original (will miss validation, but doesn't crash)
    return trimmed;
}

/**
 * Get all canonical domain keys as an array.
 * Useful for constraining LLM output.
 */
export function getAllDomainKeys() {
    return Object.keys(DOMAINS);
}
