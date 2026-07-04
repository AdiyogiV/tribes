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
    "Ashwini", // 0 - Beginning of Aries
    "Ashlesha", // 8 - End of Cancer
    "Magha", // 9 - Beginning of Leo
    "Jyeshtha", // 17 - End of Scorpio
    "Moola", // 18 - Beginning of Sagittarius
    "Revati", // 26 - End of Pisces
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
 * Planet rulership — which signs each planet rules.
 * Standard Parashari lordship. Rahu/Ketu co-lordship per BPHS.
 */
export const PLANET_RULERSHIP = {
    Sun: ["Leo"],
    Moon: ["Cancer"],
    Mars: ["Aries", "Scorpio"],
    Mercury: ["Gemini", "Virgo"],
    Jupiter: ["Sagittarius", "Pisces"],
    Venus: ["Taurus", "Libra"],
    Saturn: ["Capricorn", "Aquarius"],
    Rahu: ["Aquarius"], // co-lord with Saturn
    Ketu: ["Scorpio"], // co-lord with Mars
};

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
    OPEN: 0, // legacy open → public
    PUBLIC: 1, // public
    PRIVATE: 2, // private - must NOT appear in globalFeed
    PERSONAL: 3, // legacy personal (deprecated)
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
