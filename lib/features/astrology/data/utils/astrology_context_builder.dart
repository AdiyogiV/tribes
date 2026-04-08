import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Builds comprehensive astrology context for AI chat
/// Shared between AstrologyDetailsPage and DailyInsightPage
class AstrologyContextBuilder {
  AstrologyContextBuilder._();

  /// Build comprehensive astrology context from profile for AI chat
  /// Includes ALL available data: planetary positions, transits, panchang, Ayurveda, etc.
  static Map<String, dynamic> buildContext({
    AstrologyProfile? profile,
    DailyInsight? insight,
    AyurvedaProfile? ayurveda,
  }) {
    // Log detailed info about what data is available
    AppLogger.i('🔮 Building astrology context for chat', data: {
      'hasProfile': profile != null,
      'hasInsight': insight != null,
      'hasAyurveda': ayurveda?.hasData ?? false,
      // Profile data availability
      'ascendant': profile?.ascendant,
      'moonSign': profile?.moonSign,
      'sunSign': profile?.sunSign,
      'nakshatra': profile?.nakshatra ?? profile?.moonNakshatra,
      'hasDasha': profile?.currentDasha != null,
      'hasBirthChart': profile?.birthChartData != null,
      'hasProcessedPlanets': profile?.processedPlanets != null,
      'planetsCount': (profile?.processedPlanets as List?)?.length ?? 0,
      'hasYogas': profile?.yogas != null,
      'hasRajYogas': profile?.rajYogas != null,
      'hasDoshas': profile?.doshas != null,
      'hasNavamsa': profile?.navamsa != null,
      'hasPanchang': profile?.panchang != null,
      // Ayurveda data availability
      'prakritiType': ayurveda?.prakritiType,
      'agniType': ayurveda?.agniType,
      // Insight data availability
      'hasAstroData': insight?.astrologicalData != null,
      'hasTodayTransits': insight?.astrologicalData?['transits'] != null,
      'hasTodayPanchang': insight?.astrologicalData?['panchang'] != null,
      'hasCosmicWeather': insight?.astroContext?['cosmicWeather'] != null,
    });

    final context = <String, dynamic>{};

    // Use saved cosmic weather and forecasts from insight (if available)
    // This ensures chat has the SAME context that was used to generate the insight
    final savedContext = insight?.astroContext;
    if (savedContext != null) {
      if (savedContext['cosmicWeather'] != null) {
        context['cosmicWeather'] = savedContext['cosmicWeather'];
      }
      if (savedContext['forecasts'] != null) {
        context['forecasts'] = savedContext['forecasts'];
      }
    }

    if (profile != null) {
      // === CORE CHART DATA ===
      context['sunSign'] = profile.sunSign;
      context['moonSign'] = profile.moonSign;
      context['ascendant'] = profile.ascendant;
      context['nakshatra'] = profile.nakshatra ?? profile.moonNakshatra;
      context['lagnaNakshatra'] = profile.lagnaNakshatra;

      // === FULL DASHA (all levels, not just maha/antar) ===
      if (profile.currentDasha != null) {
        context['currentDasha'] = profile.currentDasha;
      }

      // === PLANETARY POSITIONS (critical for predictions!) ===
      if (profile.birthChartData != null) {
        context['birthChart'] = profile.birthChartData;
      }
      if (profile.processedPlanets != null) {
        context['planets'] = profile.processedPlanets;
      }

      // === YOGAS & DOSHAS ===
      context['doshas'] = profile.doshas;
      context['rajYogas'] = profile.rajYogas;
      context['yogas'] = profile.yogas;
      if (profile.yogasDetailed != null) {
        context['yogasDetailed'] = profile.yogasDetailed;
      }

      // === DIVISIONAL CHARTS ===
      if (profile.navamsa != null) {
        context['navamsa'] = profile.navamsa;
      }

      // === TIMING DATA ===
      if (profile.panchang != null) {
        context['panchang'] = profile.panchang;
      }
      if (profile.muhurat != null) {
        context['muhurat'] = profile.muhurat;
      }

      // === BIRTH DATA (for context) ===
      context['birthTime'] = profile.birthTime;
      context['birthPlace'] = profile.birthPlace;
    }

    // === AYURVEDA DATA (wellness context) ===
    if (ayurveda != null && ayurveda.hasData) {
      final ayurvedaContext = <String, dynamic>{
        'prakriti': {
          'type': ayurveda.prakritiType,
          'dominant': ayurveda.dominantDosha,
          if (ayurveda.prakriti != null) ...{
            'vata': ayurveda.prakriti!.vata,
            'pitta': ayurveda.prakriti!.pitta,
            'kapha': ayurveda.prakriti!.kapha,
          },
        },
        if (ayurveda.agniType != null) 'agniType': ayurveda.agniType,
        if (ayurveda.manasPrakriti != null)
          'manasPrakriti': {
            'dominant': ayurveda.manasPrakriti!.dominant,
            'sattva': ayurveda.manasPrakriti!.sattva,
            'rajas': ayurveda.manasPrakriti!.rajas,
            'tamas': ayurveda.manasPrakriti!.tamas,
          },
        if (ayurveda.healthVulnerabilities != null &&
            ayurveda.healthVulnerabilities!.isNotEmpty)
          'healthVulnerabilities': ayurveda.healthVulnerabilities!
              .map((v) => v.description)
              .toList(),
      };

      // === VIKRITI (Current State) with Enhanced Factors ===
      if (ayurveda.vikriti != null) {
        final vikriti = ayurveda.vikriti!;
        ayurvedaContext['vikriti'] = {
          'vata': vikriti.vata,
          'pitta': vikriti.pitta,
          'kapha': vikriti.kapha,
          'isBalanced': vikriti.isBalanced,
          if (vikriti.imbalances.isNotEmpty)
            'imbalances': vikriti.imbalances
                .map((i) => {
                      'dosha': i.dosha,
                      'shift': i.shift,
                      'severity': i.severity,
                    })
                .toList(),
          // Include factors with Tarabala, Chandrabala, etc.
          if (vikriti.factors.isNotEmpty)
            'factors': vikriti.factors
                .map((f) => {
                      'source': f.source,
                      'description': f.description,
                      'dosha': f.dosha,
                      if (f.guidance != null) 'guidance': f.guidance,
                      if (f.favorable != null) 'favorable': f.favorable,
                    })
                .toList(),
        };

        // Extract specific factor types for easy reference
        final tarabalaFactor =
            vikriti.factors.where((f) => f.source == 'tarabala').firstOrNull;
        final chandrabalaFactor =
            vikriti.factors.where((f) => f.source == 'chandrabala').firstOrNull;
        final ashtakavargaFactors =
            vikriti.factors.where((f) => f.source == 'ashtakavarga').toList();

        if (tarabalaFactor != null) {
          ayurvedaContext['tarabala'] = {
            'description': tarabalaFactor.description,
            'favorable': tarabalaFactor.favorable,
            if (tarabalaFactor.guidance != null)
              'guidance': tarabalaFactor.guidance,
          };
        }

        if (chandrabalaFactor != null) {
          ayurvedaContext['chandrabala'] = {
            'description': chandrabalaFactor.description,
            'favorable': chandrabalaFactor.favorable,
            'isAshtamaChandra':
                chandrabalaFactor.description.contains('Ashtama'),
            if (chandrabalaFactor.guidance != null)
              'guidance': chandrabalaFactor.guidance,
          };
        }

        if (ashtakavargaFactors.isNotEmpty) {
          ayurvedaContext['transitBindus'] = ashtakavargaFactors
              .map((f) => {
                    'description': f.description,
                    'favorable': f.favorable,
                  })
              .toList();
        }
      }

      context['ayurveda'] = ayurvedaContext;
    }

    // === DAILY INSIGHT DATA (includes today's transits!) ===
    if (insight != null) {
      context['dailyInsight'] = insight.displayMessage;
      context['insightTheme'] = insight.displayTheme;

      // Pass full section data with card types
      context['insightSections'] = insight.sections.map((s) {
        return {
          'title': s.title,
          'content': s.content,
          'cardType': s.cardType,
          if (s.data != null) 'data': s.data,
        };
      }).toList();

      // === TODAY'S ASTROLOGICAL DATA (transits, panchang, shad bala) ===
      if (insight.astrologicalData != null) {
        context['todayTransits'] = insight.astrologicalData!['transits'];
        context['todayPanchang'] = insight.astrologicalData!['panchang'];
        context['todayShadBala'] = insight.astrologicalData!['shadBala'];
      }
    }

    return context;
  }

  /// Build context for wellness chat only (ayurveda data, no chart).
  /// Used when opening chat from the Ayurveda page; backend uses wellness persona.
  static Map<String, dynamic> buildWellnessChatContext(
      AyurvedaProfile? ayurveda) {
    return buildContext(profile: null, insight: null, ayurveda: ayurveda);
  }
}
