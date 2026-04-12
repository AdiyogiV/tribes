/**
 * Shared constants for the Tribes backend
 * Centralized location for values used across multiple modules
 */

// =============================================================================
// VEDIC ASTROLOGY CONSTANTS
// =============================================================================

/**
 * Gandmool Nakshatras - inauspicious for birth
 * Birth in these requires specific remedies
 */
export const GANDMOOL_NAKSHATRAS = [
    "Ashwini",     // 0 - Beginning of Aries
    "Ashlesha",    // 8 - End of Cancer
    "Magha",       // 9 - Beginning of Leo
    "Jyeshtha",    // 17 - End of Scorpio
    "Moola",       // 18 - Beginning of Sagittarius
    "Revati",      // 26 - End of Pisces
];

/**
 * All 27 Nakshatras in order
 */
export const NAKSHATRAS = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra",
    "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni",
    "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha", "Jyeshtha",
    "Moola", "Purva Ashadha", "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha",
    "Purva Bhadrapada", "Uttara Bhadrapada", "Revati",
];

/**
 * 12 Zodiac signs in order
 */
export const ZODIAC_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
];

/**
 * 9 Vedic planets (Navagrahas)
 */
export const PLANETS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];

/**
 * Traditional 7 planets (excluding shadow planets)
 */
export const TRADITIONAL_PLANETS = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

/**
 * House significations in Vedic astrology (Bhava Karakatwa)
 * Personal (natal chart) perspective.
 */
export const HOUSE_SIGNIFICATIONS = {
    1: "Self, personality, physical body, appearance, health, longevity",
    2: "Wealth, family, speech, food, eyes, early education, face",
    3: "Siblings, courage, communication, short journeys, hands, ears",
    4: "Mother, home, property, education, vehicles, happiness, chest",
    5: "Children, creativity, education, intelligence, speculation, stomach",
    6: "Health, enemies, service, debts, litigation, maternal uncle",
    7: "Marriage, partnerships, spouse, business, desires, travel",
    8: "Longevity, transformation, occult, inheritance, obstacles, research",
    9: "Father, dharma, higher learning, spirituality, fortune, guru",
    10: "Career, reputation, authority, status, profession, karma",
    11: "Gains, income, friends, aspirations, elder siblings, ankles",
    12: "Losses, expenses, spirituality, foreign lands, liberation, feet",
};

/**
 * House significations for Mundane (world) astrology — Medini Jyotish.
 * Kalpurush Kundli: fixed Aries ascendant.
 */
export const MUNDANE_HOUSES = {
    1:  { name: "Lagna",      domain: "nation, national identity, general public, collective mood" },
    2:  { name: "Dhana",      domain: "economy, national wealth, banks, currency, trade, revenue" },
    3:  { name: "Sahaja",     domain: "communications, media, transport, neighbors, short journeys" },
    4:  { name: "Sukha",      domain: "land, agriculture, infrastructure, opposition party, homeland, weather" },
    5:  { name: "Putra",      domain: "children, education, speculation, entertainment, diplomacy" },
    6:  { name: "Ripu",       domain: "military, health, disease, labor, service, enemies" },
    7:  { name: "Yuvati",     domain: "foreign affairs, war/peace, treaties, open enemies, partnerships" },
    8:  { name: "Randhra",    domain: "death, crisis, taxes, debt, insurance, transformation, secrets" },
    9:  { name: "Dharma",     domain: "law, religion, judiciary, philosophy, long journeys, foreign lands" },
    10: { name: "Karma",      domain: "government, ruler, authority, reputation, executive power" },
    11: { name: "Labha",      domain: "parliament, legislature, alliances, gains, aspirations" },
    12: { name: "Vyaya",      domain: "losses, exile, espionage, hospitals, prisons, foreign settlements" },
};

/**
 * Planet rulership — which signs each planet rules.
 * Standard Parashari lordship. Rahu/Ketu co-lordship per BPHS.
 */
export const PLANET_RULERSHIP = {
    Sun:     ["Leo"],
    Moon:    ["Cancer"],
    Mars:    ["Aries", "Scorpio"],
    Mercury: ["Gemini", "Virgo"],
    Jupiter: ["Sagittarius", "Pisces"],
    Venus:   ["Taurus", "Libra"],
    Saturn:  ["Capricorn", "Aquarius"],
    Rahu:    ["Aquarius"],   // co-lord with Saturn
    Ketu:    ["Scorpio"],    // co-lord with Mars
};

/**
 * Sign → house number (fixed Aries ascendant = natural zodiac).
 * Used by mundane astrology modules.
 */
export const SIGN_TO_HOUSE = {
    aries: 1,    taurus: 2,   gemini: 3,    cancer: 4,
    leo: 5,      virgo: 6,    libra: 7,     scorpio: 8,
    sagittarius: 9, capricorn: 10, aquarius: 11, pisces: 12,
};

// ── Position helpers (derive sign/nakshatra from longitude) ─────────────

/** Get sign name from sidereal longitude. */
export function getSignFromLongitude(longitude) {
    if (longitude == null) return null;
    return ZODIAC_SIGNS[Math.floor(((longitude % 360) + 360) % 360 / 30)];
}

/** Get sign degree (0-30) from sidereal longitude. */
export function getSignDegree(longitude) {
    if (longitude == null) return null;
    return ((longitude % 360) + 360) % 360 % 30;
}

/** Get house number (1-12, Kalpurush) from sidereal longitude. */
export function getHouseFromLongitude(longitude) {
    if (longitude == null) return null;
    return Math.floor(((longitude % 360) + 360) % 360 / 30) + 1;
}

// =============================================================================
// SPACE TYPES (must match lib/modal/spaceTypes.dart and firestore.rules)
// =============================================================================
/**
 * Space type indices stored in Firestore. Keep in sync with:
 * - Flutter: lib/modal/spaceTypes.dart (SpaceType enum)
 * - Rules: firestore.rules isPublicSpace() (only 0 and 1 are public)
 * 0 = legacy open (public), 1 = public, 2 = private, 3 = legacy personal (deprecated)
 */
export const SPACE_TYPES = {
    OPEN: 0,       // legacy open → public
    PUBLIC: 1,     // public
    PRIVATE: 2,    // private - must NOT appear in globalFeed
    PERSONAL: 3,   // legacy personal (deprecated)
};

/** Space is eligible for global feed iff type is OPEN or PUBLIC and not limitedVisibility */
export function isPublicSpaceType(spaceType) {
    return spaceType === SPACE_TYPES.OPEN || spaceType === SPACE_TYPES.PUBLIC;
}

// =============================================================================
// FIRESTORE COLLECTIONS
// =============================================================================

export const COLLECTIONS = {
    USERS: "users",
    SPACES: "spaces",
    POSTS: "posts",
    NOTIFICATIONS: "notifications",
    ASTRO_CACHE: "astroCache",
    ASTRO_KNOWLEDGE: "astroKnowledge",
    ASTRO_CURRENT: "astroCurrent",
    AI_CHAT_SESSIONS: "ai_chat_sessions",
    FUNCTION_EVENTS: "functionEvents",
    GLOBAL_FEED: "globalFeed",
};

// =============================================================================
// NOTIFICATION TYPES
// =============================================================================

export const NOTIFICATION_TYPES = {
    REPLY: "reply",
    INVITE: "invite",
    ADDED_TO_GROUP: "addedtogroup",
    REQUEST: "request",
    NAMASTE: "namaste",
    NEW_SPACE_POST: "newSpacePost",
    LIKE: "like",
    DAILY_ASTRO_INSIGHT: "dailyAstroInsight",
    CHAT: "chat",
    MESSAGE: "message",
    ANONYMOUS_MESSAGE: "anonymousMessage",
};

// =============================================================================
// INSIGHT CARD TYPES
// =============================================================================

export const INSIGHT_CARD_TYPES = {
    HERO: "hero",
    PREDICTION: "prediction",
    STRENGTH: "strength",
    GUIDANCE: "guidance",
};

// =============================================================================
// CACHE TTL CONSTANTS (in hours)
// =============================================================================

export const CACHE_TTL = {
    TRANSIT: 6,       // Refresh every 6 hours
    AI_INSIGHT: 4,    // Insights refresh 4x daily
    SEARCH: 12,       // Search context refresh 2x daily
    DAILY: 24,        // 1 day
    WEEKLY: 168,      // 7 days
    MONTHLY: 720,     // 30 days
    FOREVER: -1,      // Never expires
};

// =============================================================================
// API CONFIGURATION
// =============================================================================

export const FREE_ASTROLOGY_API = {
    BASE_URL: "https://json.freeastrologyapi.com",
    ENDPOINTS: {
        PLANETS_EXTENDED: "/planets/extended",
        PLANETS: "/planets",
        DASHA: "/vimsottari/maha-dasas-and-antar-dasas",
        DASHA_ALT1: "/vimsottari/maha-dasas",
        DASHA_ALT2: "/vimsottari-maha-dasas-and-antar-dasas",
        DASHA_ALT3: "/vimsottari-dasha",
        DASA_INFO: "/vimsottari/dasa-information",
        SAMVAT: "/samvatinfo",
        LUNAR_MONTH: "/lunarmonthinfo",
        TITHI: "/tithi-durations",
        NAKSHATRA_DURATIONS: "/nakshatra-durations",
        YOGA_DURATIONS: "/yoga-durations",
        VEDIC_WEEKDAY: "/vedicweekday",
        HORA_TIMINGS: "/hora-timings",
        CHOGHADIYA: "/choghadiya-timings",
        GOOD_BAD_TIMES: "/good-bad-times",
        NAVAMSA: "/navamsa-chart-info",
        D10_CHART: "/d10-chart-info",
        SHADBALA: "/shadbala/summary",
        ASHTAKOOT: "/match-making/ashtakoot-score",
    },
};

// =============================================================================
// AI CONFIGURATION
// =============================================================================

export const AI_CONFIG = {
    OPENROUTER_URL: "https://openrouter.ai/api/v1/chat/completions",
    DEFAULT_MODEL: "openai/gpt-4o-mini",
    FALLBACK_MODELS: [
        "openai/gpt-4o-mini",
        "anthropic/claude-3-haiku",
        "google/gemini-flash-1.5",
    ],
    MAX_TOKENS: 4096,
    TEMPERATURE: 0.7,
};

// =============================================================================
// RATE LIMITS
// =============================================================================

export const RATE_LIMITS = {
    // Chat notifications - max 1 notification per 3 seconds per conversation
    CHAT_NOTIFICATION_WINDOW_MS: 3000,
    CHAT_MAX_NOTIFICATIONS_PER_WINDOW: 1,
    // Rate limit cache cleanup
    RATE_LIMIT_MAX_ENTRIES: 5000,
    RATE_LIMIT_CLEANUP_INTERVAL_MS: 30000,
    // Namaste
    NAMASTE_DAILY_LIMIT: 3,
    NAMASTE_AURA_POINTS: 5,
};

// =============================================================================
// BATCH SIZES
// =============================================================================

export const BATCH_SIZES = {
    // Firestore batch operations
    FIRESTORE_WRITES: 500,
    // Insight task enqueueing
    ENQUEUE_INSIGHT_TASKS: 100,
    // User deletion cleanup
    DELETE_MESSAGES: 500,
    // Sky positions prefetch
    SKY_POSITIONS_DAYS_BACK: 30,
    SKY_POSITIONS_DAYS_AHEAD: 45,
};

// =============================================================================
// TIMEOUTS (in milliseconds)
// =============================================================================

export const TIMEOUTS = {
    // API request timeouts
    API_REQUEST_MS: 30000,
    // Stale deletion threshold (1 hour)
    STALE_DELETION_THRESHOLD_MS: 60 * 60 * 1000,
    // FCM notification TTL (24 hours)
    FCM_TTL_MS: 86400000,
    // Call notification timeout (60 seconds)
    CALL_NOTIFICATION_TIMEOUT_MS: 60000,
    // API rate limiting delay
    API_RATE_LIMIT_DELAY_MS: 100,
};

// =============================================================================
// INSIGHT SCHEDULING
// =============================================================================

export const INSIGHT_SCHEDULE = {
    // Dispatch times in 24-hour format (IST)
    DISPATCH_TIMES: ["06:00", "12:00", "17:00", "21:00"],
    // Time slots for collection names (without colon)
    TIME_SLOTS: ["0600", "1200", "1700", "2100"],
    // Days to keep dispatch entries before cleanup
    DISPATCH_RETENTION_DAYS: 7,
};

// =============================================================================
// AURA POINTS
// =============================================================================

export const AURA_POINTS = {
    NAMASTE_SENT: 1,
    NAMASTE_RECEIVED: 5,
    POST_REPLY_RECEIVED: 10,
    POST_LIKE_RECEIVED: 3,
    CREATE_POST: 2,
    CREATE_REPLY: 1,
    PROFILE_COMPLETE: 20,
    NEW_FOLLOWER: 5,
    ASTROLOGY_SETUP: 10,
    DAILY_INSIGHT_VIEW: 1,
};

// =============================================================================
// AI AGENT CONFIGURATION
// =============================================================================

/**
 * HolyCow AI user ID - used for AI profile posts and interactions
 * Must match lib/providers/ai_chat_provider.dart HOLYCOW_USER_ID
 */
export const HOLYCOW_AI_USER_ID = "holycow_system_user";


