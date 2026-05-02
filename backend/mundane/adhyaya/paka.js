/**
 * पाक — Paka (Manifestation Timing)
 *
 * Brihat Samhita, Chapter 97 (Paka Adhyaya)
 *
 * "Effects do not manifest instantly. Each graha has a specific
 *  ripening period (paka-kala) after which its transit effects
 *  become visible in the world."
 *
 * This is the TIMING LAYER — when effects actually peak.
 */

export const PAKA = {
    Saturn:  { delayDays: 365, peakDesc: "~1 year after ingress",      source: "BS Ch.97 v.1" },
    Jupiter: { delayDays: 365, peakDesc: "~1 year after ingress",      source: "BS Ch.97 v.1" },
    Rahu:    { delayDays: 180, peakDesc: "~6 months after ingress",    source: "BS Ch.97 v.8" },
    Ketu:    { delayDays: 180, peakDesc: "~6 months after ingress",    source: "BS Ch.97 v.8" },
    Mars:    { delayDays: 60,  peakDesc: "~60 days (retrograde cycle)", source: "BS Ch.97 v.3" },
    Sun:     { delayDays: 15,  peakDesc: "within a fortnight",         source: "BS Ch.97 v.1" },
    Venus:   { delayDays: 180, peakDesc: "~6 months after ingress",    source: "BS Ch.97 v.7" },
    Mercury: { delayDays: 21,  peakDesc: "~21 days (before disappearance)", source: "BS Ch.97 v.4" },
    Moon:    { delayDays: 30,  peakDesc: "within one month",           source: "BS Ch.97 v.2" },
};

// Backward-compatible alias
export const MANIFESTATION_TIMING = PAKA;
