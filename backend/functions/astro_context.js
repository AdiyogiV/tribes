/**
 * UNIFIED ASTROLOGY CONTEXT SYSTEM
 * 
 * This module provides a single source of truth for building astrology context.
 * Used by both:
 * - daily_astro_insights.js (generating daily predictions)
 * - ai.js (answering user questions in chat)
 * 
 * The goal is to ensure consistency and avoid duplicate work.
 * Web-grounded search context is cached daily and reused across all users.
 */

import { logger } from "../lib/firebase.js";
import { db } from "../lib/firebase.js";
import { DateTime } from "luxon";
import { 
    getCachedSearchContext, 
    cacheSearchContext,
    getCachedAstroKnowledge,
    cacheAstroKnowledge 
} from "./cache_utils.js";
import { buildAstroSearchContext } from "./search.js";

// =============================================================================
// CONTEXT BUILDING FUNCTIONS
// =============================================================================

/**
 * Build complete astrology context for AI interactions
 * This is THE unified context builder used by both insight generation and chat
 * 
 * @param {Object} userAstroData - User's birth chart data from Firestore
 * @param {Object} todayAstroData - Today's transits, panchang, etc. (optional for chat)
 * @param {Object} options - { includeSearch: boolean, includeStaticKnowledge: boolean }
 * @returns {Object} Complete astrology context
 */
export async function buildFullAstroContext(userAstroData, todayAstroData = null, options = {}) {
    const { 
        includeSearch = true, 
        includeStaticKnowledge = true,
        forChat = false  // If true, optimizes for chat (smaller context)
    } = options;

    const today = DateTime.now().toFormat("yyyy-MM-dd");
    const context = {
        buildDate: today,
        buildTime: new Date().toISOString(),
    };

    // 1. USER'S BIRTH CHART (static, never changes)
    context.userChart = buildUserChartContext(userAstroData);
    
    // 2. TODAY'S COSMIC WEATHER (if provided)
    if (todayAstroData) {
        context.todayData = buildTodayContext(todayAstroData);
    }
    
    // 3. GOOGLE SEARCH INTELLIGENCE (cached daily)
    if (includeSearch) {
        try {
            // First try to load from cache
            let searchContext = await getCachedSearchContext(today);
            
            if (!searchContext && todayAstroData) {
                // Cache miss - build fresh (this is expensive, only do for insight generation)
                logger.info("🔍 Building fresh search context (cache miss)", { 
                    structuredData: true,
                    forChat 
                });
                
                if (!forChat) {
                    // Only build fresh for insight generation, not for chat
                    searchContext = await buildAstroSearchContext(userAstroData, todayAstroData);
                    
                    // Cache for reuse
                    if (searchContext) {
                        await cacheSearchContext(today, searchContext);
                    }
                }
            }
            
            if (searchContext) {
                context.cosmicIntelligence = buildCosmicIntelligenceContext(searchContext, forChat);
            }
        } catch (error) {
            logger.warn("Failed to load search context, continuing without it", {
                structuredData: true,
                error: String(error),
            });
        }
    }
    
    // 4. STATIC KNOWLEDGE (from knowledge cache)
    if (includeStaticKnowledge && userAstroData) {
        context.staticKnowledge = await buildStaticKnowledgeContext(userAstroData, todayAstroData);
    }

    logger.info("📦 Built full astro context", {
        structuredData: true,
        hasUserChart: !!context.userChart,
        hasTodayData: !!context.todayData,
        hasCosmicIntelligence: !!context.cosmicIntelligence,
        hasStaticKnowledge: !!context.staticKnowledge,
        forChat,
    });

    return context;
}

/**
 * Build user's birth chart context (static data)
 */
function buildUserChartContext(userAstroData) {
    if (!userAstroData) return null;
    
    return {
        // Core identities
        ascendant: userAstroData.ascendant || userAstroData.lagna,
        moonSign: userAstroData.moonSign,
        sunSign: userAstroData.sunSign,
        nakshatra: userAstroData.nakshatra || userAstroData.moonNakshatra,
        lagnaNakshatra: userAstroData.lagnaNakshatra,
        
        // Current life phase
        currentDasha: userAstroData.currentDasha,
        
        // Yogas and strengths
        rajYogas: userAstroData.rajYogas,
        yogas: userAstroData.yogas,
        yogasDetailed: userAstroData.yogasDetailed,
        
        // Challenges
        doshas: userAstroData.doshas,
        
        // Divisional charts
        navamsa: userAstroData.navamsa,
        
        // Planetary positions
        birthChart: userAstroData.birthChartData,
        planets: userAstroData.processedPlanets,
        
        // Birth details
        birthTime: userAstroData.birthTime,
        birthPlace: userAstroData.birthPlace,
    };
}

/**
 * Build today's cosmic weather context
 */
function buildTodayContext(todayAstroData) {
    if (!todayAstroData) return null;
    
    return {
        transits: todayAstroData.transits,
        panchang: todayAstroData.panchang,
        shadBala: todayAstroData.shadBala?._analysis || todayAstroData.shadBala,
        muhurat: todayAstroData.muhurat,
        houseActivations: todayAstroData.houseActivations,
    };
}

/**
 * Build cosmic intelligence context from Google Search results
 * @param {Object} searchContext - Raw search context from buildAstroSearchContext
 * @param {boolean} compact - If true, return smaller version for chat
 */
function buildCosmicIntelligenceContext(searchContext, compact = false) {
    if (!searchContext) return null;
    
    const context = {};
    
    // Global cosmic events (affects everyone)
    if (searchContext.global) {
        context.global = {
            retrogrades: searchContext.global.events?.retrogrades || [],
            moonPhase: searchContext.global.events?.moonPhase,
            eclipse: searchContext.global.events?.eclipse,
        };
        
        if (!compact) {
            context.global.todayNews = searchContext.global.todayNews?.summary?.substring(0, 500);
            context.global.weekly = searchContext.global.weekly?.overview?.substring(0, 400);
            context.global.monthly = searchContext.global.monthly?.overview?.substring(0, 300);
            context.global.festivals = searchContext.global.festivals?.list?.substring(0, 200);
        }
    }
    
    // User-specific forecasts
    if (searchContext.userSpecific && !compact) {
        context.userForecasts = {
            lagnaForecast: searchContext.userSpecific.lagnaForecast,
            moonSignForecast: searchContext.userSpecific.moonSignForecast,
            dashaForecast: searchContext.userSpecific.dashaForecast,
            majorTransitEffect: searchContext.userSpecific.majorTransitEffect,
        };
    }
    
    // Panchang meanings
    if (searchContext.panchang) {
        context.panchangMeanings = {
            tithi: searchContext.panchang.tithi?.meaning,
            nakshatra: searchContext.panchang.nakshatra?.characteristics,
            yoga: searchContext.panchang.yoga?.meaning,
        };
    }
    
    // User profile knowledge
    if (searchContext.userProfile && !compact) {
        context.userProfileKnowledge = {
            lagnaCharacteristics: searchContext.userProfile.lagna?.characteristics,
            nakshatraCharacteristics: searchContext.userProfile.nakshatra?.characteristics,
        };
    }
    
    // Dasha interpretation
    if (searchContext.dasha) {
        context.dashaInterpretation = searchContext.dasha.general?.interpretation;
    }
    
    // Remedies
    if (searchContext.remedies && !compact) {
        context.remedies = searchContext.remedies;
    }
    
    // Retrograde guides
    if (searchContext.retrogradeGuides && searchContext.retrogradeGuides.length > 0) {
        context.retrogradeGuides = searchContext.retrogradeGuides;
    }
    
    return context;
}

/**
 * Build static knowledge context (cached forever)
 */
async function buildStaticKnowledgeContext(userAstroData, todayAstroData) {
    // This pulls from the permanent knowledge cache
    // For now, return null - this can be expanded
    return null;
}

// =============================================================================
// AI PROMPT FORMATTING
// =============================================================================

/**
 * Format the full context into an AI-ready prompt section
 * Used by both insight generation and chat
 * 
 * @param {Object} context - The full context from buildFullAstroContext
 * @param {string} mode - 'insight' for daily insight, 'chat' for chat responses
 * @returns {string} Formatted prompt section
 */
export function formatContextForAI(context, mode = 'chat') {
    const lines = [];
    
    lines.push("\n\n═══════════════════════════════════════════════════════════════");
    lines.push("USER'S VEDIC ASTROLOGY PROFILE");
    lines.push("═══════════════════════════════════════════════════════════════");
    
    // User's birth chart
    const chart = context.userChart;
    if (chart) {
        if (chart.ascendant) lines.push(`☉ Ascendant (Lagna): ${chart.ascendant}`);
        if (chart.moonSign) lines.push(`☽ Moon Sign: ${chart.moonSign}`);
        if (chart.sunSign) lines.push(`☀ Sun Sign: ${chart.sunSign}`);
        if (chart.nakshatra) lines.push(`✧ Birth Nakshatra: ${chart.nakshatra}`);
        if (chart.lagnaNakshatra) lines.push(`✧ Lagna Nakshatra: ${chart.lagnaNakshatra}`);
        
        // Dasha with all levels
        if (chart.currentDasha) {
            const dasha = chart.currentDasha;
            const parts = [];
            if (dasha.mahadasha || dasha.maha_dasha) parts.push(`Mahadasha: ${dasha.mahadasha || dasha.maha_dasha}`);
            if (dasha.antardasha || dasha.antar_dasha) parts.push(`Antardasha: ${dasha.antardasha || dasha.antar_dasha}`);
            if (dasha.levels?.pratyantar?.lord) parts.push(`Pratyantar: ${dasha.levels.pratyantar.lord}`);
            if (dasha.levels?.sookshma?.lord) parts.push(`Sookshma: ${dasha.levels.sookshma.lord}`);
            if (parts.length > 0) lines.push(`⟳ Current Dasha: ${parts.join(", ")}`);
            if (dasha.endDate) lines.push(`   Mahadasha ends: ${dasha.endDate}`);
        }
        
        // Yogas (with details - type, strength, planets)
        if (chart.rajYogas && chart.rajYogas.length > 0) {
            const yogaNames = chart.rajYogas.map(y => typeof y === 'string' ? y : y.name).filter(Boolean);
            if (yogaNames.length > 0) lines.push(`✦ Raj Yogas: ${yogaNames.join(", ")}`);
            
            // Add detailed yoga breakdown for AI
            lines.push("\n🔮 YOGA DETAILS:");
            chart.rajYogas.forEach(y => {
                if (typeof y === 'object' && y.name) {
                    let detail = `   ${y.name}`;
                    if (y.type) detail += ` [${y.type}]`;
                    if (y.strength) detail += ` - ${y.strength}`;
                    if (y.planets) detail += ` | Planets: ${Array.isArray(y.planets) ? y.planets.join(", ") : y.planets}`;
                    if (y.description) detail += `\n      → ${y.description}`;
                    lines.push(detail);
                }
            });
        }
        
        // Doshas (comprehensive - including all calculated doshas)
        if (chart.doshas) {
            const doshaList = [];
            if (chart.doshas.mangal_dosha) {
                const house = chart.doshas.mangal_dosha_house;
                doshaList.push(`Mangal Dosha${house ? ` (House ${house})` : ""}`);
            }
            if (chart.doshas.kaal_sarp_dosha) doshaList.push("Kaal Sarp Dosha");
            if (chart.doshas.shani_dosha) {
                const house = chart.doshas.shani_dosha_house;
                doshaList.push(`Shani Dosha${house ? ` (House ${house})` : ""}`);
            }
            if (chart.doshas.pitra_dosha) {
                const type = chart.doshas.pitra_dosha_type;
                doshaList.push(`Pitra Dosha${type ? ` (${type})` : ""}`);
            }
            if (chart.doshas.grahan_dosha) {
                const type = chart.doshas.grahan_type;
                doshaList.push(`Grahan Dosha${type ? ` (${type})` : ""}`);
            }
            if (chart.doshas.gandmool_dosha) {
                const nak = chart.doshas.gandmool_nakshatra;
                doshaList.push(`Gandmool Dosha${nak ? ` (${nak})` : ""}`);
            }
            if (chart.doshas.has_combustion && chart.doshas.combust_planets?.length > 0) {
                doshaList.push(`Combustion (${chart.doshas.combust_planets.join(", ")})`);
            }
            if (doshaList.length > 0) lines.push(`⚠ Doshas: ${doshaList.join(", ")}`);
        }
        
        // Planetary positions
        if (chart.planets && Array.isArray(chart.planets)) {
            lines.push("\n📍 NATAL PLANETS:");
            chart.planets.forEach(p => {
                if (p.name && p.sign) {
                    let info = `   ${p.name}: ${p.sign}`;
                    if (p.house) info += ` (House ${p.house})`;
                    if (p.degree) info += ` at ${p.degree}°`;
                    if (p.retrograde) info += " [R]";
                    lines.push(info);
                }
            });
        }
        
        // Birth details
        if (chart.birthTime || chart.birthPlace) {
            lines.push(`\n🎂 Birth: ${chart.birthTime || "?"} at ${chart.birthPlace || "?"}`);
        }
    }
    
    // Today's cosmic weather
    const today = context.todayData;
    if (today) {
        lines.push("\n═══════════════════════════════════════════════════════════════");
        lines.push("TODAY'S COSMIC WEATHER");
        lines.push("═══════════════════════════════════════════════════════════════");
        
        // Transits
        if (today.transits) {
            lines.push("\n🔄 CURRENT TRANSITS:");
            Object.entries(today.transits).forEach(([planet, data]) => {
                if (planet !== "Ascendant" && data) {
                    let info = `   ${planet}: ${data.sign || "?"}`;
                    if (data.house) info += ` (transiting House ${data.house})`;
                    lines.push(info);
                }
            });
        }
        
        // Panchang
        if (today.panchang) {
            lines.push("\n📅 TODAY'S PANCHANG:");
            if (today.panchang.tithi) lines.push(`   Tithi: ${today.panchang.tithi}`);
            if (today.panchang.nakshatra) lines.push(`   Nakshatra: ${today.panchang.nakshatra}`);
            if (today.panchang.yoga) lines.push(`   Yoga: ${today.panchang.yoga}`);
            if (today.panchang.karana) lines.push(`   Karana: ${today.panchang.karana}`);
        }
        
        // Shad Bala
        if (today.shadBala) {
            if (today.shadBala.strongPlanets?.length > 0) {
                lines.push(`\n💪 Strong Planets: ${today.shadBala.strongPlanets.map(p => `${p.planet}(${p.strength}%)`).join(", ")}`);
            }
            if (today.shadBala.weakPlanets?.length > 0) {
                lines.push(`⚠️ Weak Planets: ${today.shadBala.weakPlanets.map(p => `${p.planet}(${p.strength}%)`).join(", ")}`);
            }
        }
        
        // Muhurat
        if (today.muhurat) {
            const m = today.muhurat;
            const muhuratInfo = [];
            if (m.abhijit) muhuratInfo.push(`Abhijit: ${m.abhijit.start}-${m.abhijit.end}`);
            if (m.rahuKaal) muhuratInfo.push(`⚠️Rahu Kaal: ${m.rahuKaal.start}-${m.rahuKaal.end}`);
            if (muhuratInfo.length > 0) {
                lines.push(`\n⏰ Today's Muhurat: ${muhuratInfo.join(" | ")}`);
            }
        }
    }
    
    // Cosmic intelligence from Google Search
    const cosmic = context.cosmicIntelligence;
    if (cosmic) {
        lines.push("\n═══════════════════════════════════════════════════════════════");
        lines.push("COSMIC INTELLIGENCE (from current astrological data)");
        lines.push("═══════════════════════════════════════════════════════════════");
        
        // Global events
        if (cosmic.global) {
            if (cosmic.global.retrogrades?.length > 0) {
                lines.push(`\n🔄 RETROGRADES NOW: ${cosmic.global.retrogrades.join(", ")}`);
            }
            if (cosmic.global.moonPhase) {
                const mp = cosmic.global.moonPhase;
                lines.push(`🌙 MOON PHASE: ${mp.type}${mp.sign ? ` in ${mp.sign}` : ""}${mp.date ? ` (${mp.date})` : ""}`);
            }
            if (cosmic.global.eclipse) {
                lines.push(`⚠️ ECLIPSE: ${cosmic.global.eclipse.type} on ${cosmic.global.eclipse.date}`);
            }
            if (cosmic.global.todayNews) {
                lines.push(`📰 TODAY: ${cosmic.global.todayNews}`);
            }
            if (cosmic.global.weekly) {
                lines.push(`📅 THIS WEEK: ${cosmic.global.weekly}`);
            }
        }
        
        // User-specific forecasts
        if (cosmic.userForecasts) {
            lines.push("\n🎯 PERSONALIZED FORECASTS:");
            if (cosmic.userForecasts.lagnaForecast) {
                lines.push(`   Lagna: ${cosmic.userForecasts.lagnaForecast}`);
            }
            if (cosmic.userForecasts.moonSignForecast) {
                lines.push(`   Moon Sign: ${cosmic.userForecasts.moonSignForecast}`);
            }
            if (cosmic.userForecasts.dashaForecast) {
                lines.push(`   Dasha: ${cosmic.userForecasts.dashaForecast}`);
            }
        }
        
        // Dasha interpretation
        if (cosmic.dashaInterpretation) {
            lines.push(`\n📖 DASHA INTERPRETATION: ${cosmic.dashaInterpretation}`);
        }
        
        // Retrograde guides
        if (cosmic.retrogradeGuides?.length > 0) {
            lines.push("\n🔄 RETROGRADE GUIDANCE:");
            for (const guide of cosmic.retrogradeGuides) {
                if (guide?.guide) {
                    lines.push(`   ${guide.planet}: ${guide.guide.substring(0, 250)}`);
                }
            }
        }
    }
    
    lines.push("\n═══════════════════════════════════════════════════════════════");
    
    // Add mode-specific instructions
    if (mode === 'chat') {
        lines.push("\n🔮 You are a trusted Vedic astrologer answering the user's question.");
        lines.push("- ALWAYS interpret questions through their Vedic astrological profile");
        lines.push("- Reference their specific signs, dashas, and planetary positions");
        lines.push("- Use current transits and today's panchang for timing predictions");
        lines.push("- Consider planetary strengths (Shad Bala) in your analysis");
        lines.push("- Be specific to THEIR chart, not generic astrology");
        lines.push("- Speak warmly and authoritatively as a trusted advisor");
    }
    
    return lines.join("\n");
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Get the context that was used to generate today's insight
 * For chat, this ensures the AI has the same context as the insight
 * 
 * @param {string} userId - User ID
 * @returns {Object|null} The saved context from the insight, or null
 */
export async function getTodayInsightContext(userId) {
    try {
        const today = DateTime.now().toFormat("yyyy-MM-dd");
        const insightDoc = await db
            .collection("users")
            .doc(userId)
            .collection("astroInsights")
            .doc(today)
            .get();
        
        if (!insightDoc.exists) {
            return null;
        }
        
        const data = insightDoc.data();
        return {
            insight: {
                theme: data.theme,
                message: data.message,
                sections: data.sections,
            },
            astroContext: data.astroContext, // The full context we saved
            astrologicalData: data.astrologicalData, // Legacy field
        };
    } catch (error) {
        logger.warn("Failed to load today's insight context", {
            structuredData: true,
            userId,
            error: String(error),
        });
        return null;
    }
}

/**
 * Load the daily cached search context
 * This is the Google Search intelligence for today
 * 
 * @returns {Object|null} The cached search context
 */
export async function getDailySearchContext() {
    const today = DateTime.now().toFormat("yyyy-MM-dd");
    return await getCachedSearchContext(today);
}





