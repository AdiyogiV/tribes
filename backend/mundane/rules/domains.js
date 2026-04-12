/**
 * Mundane Domain Taxonomy
 *
 * Every effect in the rules engine references a "domain" — a category
 * of worldly affairs. This maps to the 12 mundane houses and their
 * modern equivalents.
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
