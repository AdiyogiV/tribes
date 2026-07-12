/**
 * nakshatras.js — the SINGLE source of truth for the 27 nakshatras.
 *
 * WHY THIS EXISTS
 * The 27 names were previously duplicated across constants.js, vedic_analysis.js,
 * vedic_compatibility.js, ayurveda.js (+ tests), and `normalizeNakshatra` existed
 * in 3 places. The Flutter side had its OWN list too — with a spelling mismatch
 * ("Mula" vs canonical "Moola") that silently produced WRONG readings on the wheel.
 *
 * THE RULE: names live in ONE array (constants.NAKSHATRAS). Everything else derives
 * from it. External/API strings are normalized to a canonical name OR (preferred)
 * an INDEX at the boundary, so downstream code never guesses spellings again.
 *
 *   index (0-26)  ← the canonical currency. Order = Ashwini(0) … Revati(26).
 *   name          ← constants.NAKSHATRAS[index]
 *   any spelling  ← normalizeNakshatra(s) → canonical name, or nakshatraIndex(s) → 0-26/-1
 */

import { NAKSHATRAS } from "./constants.js";

export { NAKSHATRAS };

/**
 * Every known spelling / transliteration variation we've seen from
 * FreeAstrologyAPI and regional (Tamil/Telugu/Malayalam) sources.
 * Key = lowercased variant, value = canonical name in NAKSHATRAS.
 */
export const NAKSHATRA_ALIASES = {
    // Ashwini
    "aswini": "Ashwini", "ashvini": "Ashwini", "asvini": "Ashwini",
    // Krittika
    "krithika": "Krittika", "kritika": "Krittika",
    // Mrigashira
    "mrigasira": "Mrigashira", "mrigashirsha": "Mrigashira", "mrugasira": "Mrigashira",
    // Ardra
    "aardra": "Ardra", "arudra": "Ardra", "thiruvathira": "Ardra",
    // Punarvasu
    "punarpoosam": "Punarvasu", "punartham": "Punarvasu",
    // Pushya
    "pushyami": "Pushya", "poosam": "Pushya", "pooyam": "Pushya",
    // Ashlesha
    "aaslesha": "Ashlesha", "aslesha": "Ashlesha", "ayilyam": "Ashlesha",
    // Magha
    "makha": "Magha", "makam": "Magha",
    // Purva Phalguni
    "poorva phalguni": "Purva Phalguni", "poorvaphalguni": "Purva Phalguni",
    "pubba": "Purva Phalguni", "pooram": "Purva Phalguni",
    "purva phalguni pubba": "Purva Phalguni",
    // Uttara Phalguni
    "uttaraphalguni": "Uttara Phalguni", "uttaram": "Uttara Phalguni", "uthram": "Uttara Phalguni",
    // Chitra
    "chithra": "Chitra", "chithira": "Chitra",
    // Swati
    "swathi": "Swati", "chothi": "Swati",
    // Vishakha
    "visakha": "Vishakha", "visaka": "Vishakha", "visakam": "Vishakha",
    // Anuradha
    "anusham": "Anuradha", "anizham": "Anuradha",
    // Jyeshtha
    "jyeshta": "Jyeshtha", "jyesta": "Jyeshtha", "kettai": "Jyeshtha", "thrikketta": "Jyeshtha",
    // Moola  (the bug: Flutter used "Mula")
    "mool": "Moola", "mula": "Moola", "moolam": "Moola",
    // Purva Ashadha
    "poorva ashadha": "Purva Ashadha", "poorvaashadha": "Purva Ashadha",
    "poorvaashaada": "Purva Ashadha", "purvashadha": "Purva Ashadha", "pooradam": "Purva Ashadha",
    // Uttara Ashadha
    "uttaraashadha": "Uttara Ashadha", "uttarashadha": "Uttara Ashadha", "uthradam": "Uttara Ashadha",
    // Shravana
    "sravanam": "Shravana", "shravanam": "Shravana", "shravan": "Shravana",
    "sravana": "Shravana", "thiruvonam": "Shravana", "onam": "Shravana",
    // Dhanishta
    "dhanistha": "Dhanishta", "dhanishtha": "Dhanishta", "avittam": "Dhanishta",
    // Shatabhisha
    "shatabhishak": "Shatabhisha", "shatabhishaj": "Shatabhisha", "satabisha": "Shatabhisha",
    "satabhisha": "Shatabhisha", "chathayam": "Shatabhisha", "sadayam": "Shatabhisha",
    // Purva Bhadrapada
    "poorva bhadrapada": "Purva Bhadrapada", "poorvabhadrapada": "Purva Bhadrapada",
    "poorvaabhadra": "Purva Bhadrapada", "purvabhadra": "Purva Bhadrapada",
    "poorattathi": "Purva Bhadrapada",
    // Uttara Bhadrapada
    "uttarabhadrapada": "Uttara Bhadrapada", "uttarabhadra": "Uttara Bhadrapada",
    "uttaraabhadra": "Uttara Bhadrapada", "uthratadhi": "Uttara Bhadrapada",
    // Revati
    "revathi": "Revati",
};

/**
 * Normalize any nakshatra spelling to its canonical name.
 * Handles parenthetical alternatives, alias table, then a partial-match fallback.
 * Returns the input trimmed (as-is) if nothing matches — callers that need a hard
 * signal of failure should use nakshatraIndex() and check for -1.
 * @param {string} name
 * @returns {string|null}
 */
export function normalizeNakshatra(name) {
    if (!name) return null;

    // Strip parenthetical alternatives like "Poorva Phalguni(Pubba)".
    const cleaned = String(name).trim().replace(/\s*\([^)]*\)\s*/g, "").trim();

    // Direct canonical match.
    if (NAKSHATRAS.includes(cleaned)) return cleaned;

    // Alias table (lowercased).
    const lower = cleaned.toLowerCase();
    if (NAKSHATRA_ALIASES[lower]) return NAKSHATRA_ALIASES[lower];

    // Partial-match fallback (last resort — ambiguous, kept for back-compat).
    for (const nak of NAKSHATRAS) {
        const nl = nak.toLowerCase();
        if (nl.includes(lower) || lower.includes(nl)) return nak;
    }

    return cleaned; // unknown — return as-is
}

/**
 * Canonical 0-based index (0 = Ashwini … 26 = Revati) for any spelling.
 * @param {string} name
 * @returns {number} 0-26, or -1 if unresolvable.
 */
export function nakshatraIndex(name) {
    const canonical = normalizeNakshatra(name);
    return canonical ? NAKSHATRAS.indexOf(canonical) : -1;
}

/**
 * Canonical name for a 0-based index.
 * @param {number} index 0-26
 * @returns {string|null}
 */
export function nakshatraName(index) {
    if (!Number.isInteger(index) || index < 0 || index >= NAKSHATRAS.length) return null;
    return NAKSHATRAS[index];
}

/**
 * Nakshatra from an absolute ecliptic longitude (0-360). Each spans 13°20'.
 * @param {number} degree
 * @returns {string|null}
 */
export function getNakshatraFromDegree(degree) {
    if (degree == null || Number.isNaN(degree)) return null;
    const normalized = ((degree % 360) + 360) % 360;
    return NAKSHATRAS[Math.floor(normalized / (360 / 27))] || null;
}

/**
 * Nakshatra index from an absolute ecliptic longitude (0-360).
 * @param {number} degree
 * @returns {number} 0-26, or -1.
 */
export function nakshatraIndexFromDegree(degree) {
    if (degree == null || Number.isNaN(degree)) return -1;
    const normalized = ((degree % 360) + 360) % 360;
    return Math.floor(normalized / (360 / 27));
}
