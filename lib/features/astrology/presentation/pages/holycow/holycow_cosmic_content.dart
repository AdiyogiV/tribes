import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_date_time_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_insight_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_panchang_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/upcoming_events_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/your_chart_mini_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/widgets/cosmic_sky_chart_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dialogs/house_details_dialog.dart';
import 'package:aurogram/features/astrology/data/utils/chart_utils.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Builds the full cosmic dashboard content panel with all cards.
class HolyCowCosmicContent extends StatelessWidget {
  final AstrologyProfile? profile;
  final DailyInsight? insight;
  final AyurvedaProfile? ayurvedaProfile;
  final DashboardLoadingState loadingState;
  final SkyPositionsService skyService;
  final ValueNotifier<double> sliderValueNotifier;
  final ValueNotifier<DateTime> sliderDateNotifier;
  final bool showTransitOverlay;
  final double chartBlendValue;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onResetToToday;
  final VoidCallback onToggleTransitOverlay;
  final ValueChanged<double> onBlendValueChanged;
  final Future<void> Function({bool isRetry}) onLoadSkyPositions;
  final Future<void> Function() onTriggerCachePopulation;

  const HolyCowCosmicContent({
    super.key,
    required this.profile,
    required this.insight,
    this.ayurvedaProfile,
    required this.loadingState,
    required this.skyService,
    required this.sliderValueNotifier,
    required this.sliderDateNotifier,
    required this.showTransitOverlay,
    required this.chartBlendValue,
    required this.onSliderChanged,
    required this.onResetToToday,
    required this.onToggleTransitOverlay,
    required this.onBlendValueChanged,
    required this.onLoadSkyPositions,
    required this.onTriggerCachePopulation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.primaryColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Fallback positions from insight transits (used when sky cache misses)
    final insightTransits =
        insight?.astrologicalData?['transits'] as Map<String, dynamic>?;

    final globalMuhurat = skyService.globalMuhurat;
    final todayPanchang = skyService.getTodayPanchang();
    // Check actual renderable content, not just map keys — the card
    // itself returns SizedBox.shrink() when extracted values are empty,
    // so the surrounding spread must match to avoid phantom spacing.
    final hasPanchang = todayPanchang != null &&
        todayPanchang.isNotEmpty &&
        (todayPanchang['nakshatra'] != null ||
            todayPanchang['yoga'] != null ||
            todayPanchang['karana'] != null);
    final cardColor = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final horizontalPadding = screenWidth > 700
            ? ((screenWidth - 600) / 2).clamp(16.0, 200.0)
            : 16.0;
        final spacing = screenWidth > 700 ? 16.0 : 12.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            16 + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // TODAY's Vedic Date Card
              // IMPORTANT: Only use TODAY's data sources here.
              // profile.samvatInfo is BIRTH date data -- never use it here!
              Builder(builder: (context) {
                final globalPanchang = skyService.getTodayPanchang();
                final insightPanchangRaw =
                    insight?.astrologicalData?['panchang'];
                final insightPanchang = insightPanchangRaw is Map
                    ? Map<String, dynamic>.from(insightPanchangRaw)
                    : null;
                final todaySamvatRaw =
                    insight?.astrologicalData?['todaySamvat'];
                final todaySamvat = todaySamvatRaw is Map
                    ? Map<String, dynamic>.from(todaySamvatRaw)
                    : null;
                // Smart merge: only overwrite with non-null values to prevent
                // later sources (globalPanchang) from erasing valid data
                // (e.g. lunar_month_full_name) with nulls.
                final Map<String, dynamic> merged = {};
                if (todaySamvat != null) merged.addAll(todaySamvat);
                if (insightPanchang != null) {
                  insightPanchang.forEach((k, v) {
                    if (v != null) merged[k] = v;
                  });
                }
                if (globalPanchang != null) {
                  globalPanchang.forEach((k, v) {
                    if (v != null) merged[k] = v;
                  });
                }
                final todayPanchang = merged.isNotEmpty ? merged : null;
                return CosmicDateTimeCard(samvat: todayPanchang, brown: brown);
              }),

              SizedBox(height: spacing),

              // Current Energy (tappable → Daily Insight page)
              if (insight != null &&
                  (insight!.displayTheme.isNotEmpty ||
                      insight!.displayMessage.isNotEmpty)) ...[
                CosmicInsightCard(
                  insight: insight!,
                  brown: brown,
                  onTap: () {
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    context.push(RouteNames.dailyInsight, extra: {
                      'uid': uid,
                    });
                  },
                ),
                SizedBox(height: spacing),
              ],

              // Current Sky with optional Birth Chart overlay
              if (loadingState.isSkyLoaded) ...[
                ValueListenableBuilder<double>(
                  valueListenable: sliderValueNotifier,
                  builder: (context, sliderValue, _) {
                    return ValueListenableBuilder<DateTime>(
                      valueListenable: sliderDateNotifier,
                      builder: (context, sliderDate, _) {
                        final skyPositions =
                            skyService.getPositionsForDate(sliderDate);
                        final positions =
                            skyPositions != null && skyPositions.isNotEmpty
                                ? skyPositions
                                : insightTransits;

                        if (positions == null || positions.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return CosmicSkyChartCard(
                          todayPositions: positions,
                          birthChartData: profile?.birthChartData,
                          isDark: isDark,
                          sliderValue: sliderValue,
                          sliderDate: sliderDate,
                          skyDataLoaded: loadingState.isSkyLoaded,
                          skyDataLoading: loadingState.isSkyLoading,
                          showTransitOverlay: showTransitOverlay,
                          chartBlendValue: chartBlendValue,
                          onSliderChanged: onSliderChanged,
                          onResetToToday: onResetToToday,
                          onToggleTransitOverlay: onToggleTransitOverlay,
                          onBlendValueChanged: onBlendValueChanged,
                          onLoadSkyPositions: onLoadSkyPositions,
                          onTriggerCachePopulation: onTriggerCachePopulation,
                          getPositionsForDate: skyService.getPositionsForDate,
                          getInterpolatedPositions:
                              skyService.getInterpolatedPositions,
                          // TODO: re-enable when Current Sky page is improved
                          onExploreSky: null,
                          onExploreBirthChart: profile != null
                              ? () {
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid ??
                                          '';
                                  context.push(
                                      '${RouteNames.astrologyDetails}/$uid');
                                }
                              : null,
                          onHouseTap: (houseNumber, currentPositions) {
                            _showSkyHouseDialog(
                              context,
                              profile,
                              houseNumber,
                              currentPositions,
                              isDark,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: spacing),
              ],

              // Muhurat section (time guidance)
              if (globalMuhurat != null && globalMuhurat.isNotEmpty) ...[
                MuhuratTimelineWidget(muhurat: globalMuhurat),
                SizedBox(height: spacing),
              ] else if (loadingState.isMuhuratLoading) ...[
                _HolyCowMuhuratPlaceholder(cardColor: cardColor),
                SizedBox(height: spacing),
              ],

              // Upcoming Planetary Events
              // The card internally filters to major planets and may
              // return SizedBox.shrink() — only add spacing when the
              // card will actually render content.
              if (loadingState.isEventsLoaded &&
                  skyService.hasUpcomingEvents &&
                  skyService.allUpcomingEvents.any((e) =>
                      const ['Sun', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn']
                          .contains(e.planet))) ...[
                UpcomingEventsCard(
                  brown: brown,
                  events: skyService.allUpcomingEvents,
                  maxEvents: 8,
                ),
                SizedBox(height: spacing),
              ],

              // Panchang (global only)
              if (hasPanchang) ...[
                CosmicPanchangCard(
                    panchang: todayPanchang!, brown: brown),
                SizedBox(height: spacing),
              ],

              // Current Balance (Ayurveda Vikriti) — tappable → Ayurveda Details
              if (ayurvedaProfile != null &&
                  ayurvedaProfile!.prakriti != null) ...[
                GestureDetector(
                  onTap: () {
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    context.push('${RouteNames.ayurvedaDetails}/$uid');
                  },
                  child: TodaysBalanceCard(
                    prakriti: ayurvedaProfile!.prakriti!,
                    vikriti: ayurvedaProfile!.vikriti,
                    isCalculating: false,
                    lastCheckIn: ayurvedaProfile!.lastCheckIn,
                    isDark: isDark,
                  ),
                ),
                SizedBox(height: spacing),
              ],

              // Your Birth Stars card (matches profile card style)
              if (profile != null) ...[
                YourChartMiniCard(
                  profile: profile!,
                  brown: brown,
                  onTap: () {
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    context.push('${RouteNames.astrologyDetails}/$uid');
                  },
                ),
                SizedBox(height: spacing),
              ],

              const SizedBox(height: AppDimensions.spacingSection),
            ],
          ),
        );
      },
    );
  }

  /// Build and show the per-house current-state popup for a tap on the
  /// Current Sky chart. Combines transiting planets (from [currentPositions])
  /// with the user's natal interpretation and the biweekly sky reading
  /// stored on [profile].
  void _showSkyHouseDialog(
    BuildContext context,
    AstrologyProfile? profile,
    int houseNumber,
    Map<String, dynamic> currentPositions,
    bool isDark,
  ) {
    final lagnaSignIndex =
        ChartUtils.getLagnaSignIndex(profile?.birthChartData);

    // In the sign-fixed Current Sky chart the geometric tap position maps
    // directly to a zodiac sign (1=Aries, 2=Taurus, …), NOT to the user's
    // house number.  Convert sign position → actual house number so every
    // lookup below (natal interpretation, sky reading, planet filter) uses
    // the correct house.
    final tappedSignIndex = houseNumber - 1; // 0-based (0=Aries)
    final actualHouse =
        ((tappedSignIndex - lagnaSignIndex + 12) % 12) + 1;

    final zodiacSign =
        HouseSignifications.getSignForHouse(actualHouse, lagnaSignIndex);
    final signLord = HouseSignifications.getSignLord(zodiacSign);

    // Walk current sky positions and pick those whose sign maps to this house.
    final planets = <String>[];
    currentPositions.forEach((planet, data) {
      if (data is! Map) return;
      if (planet.toLowerCase() == 'ascendant') return;

      final m = Map<String, dynamic>.from(
          data.map((k, v) => MapEntry(k.toString(), v)));
      final sign = (m['sign'] as String?)?.toLowerCase() ?? '';
      int? signIndex = ChartConstants.signToIndex[sign];
      if (signIndex == null) {
        final lon = m['longitude'];
        if (lon is num) signIndex = (lon / 30).floor() % 12;
      }
      if (signIndex == null) return;

      final h = ((signIndex - lagnaSignIndex + 12) % 12) + 1;
      if (h == actualHouse) planets.add(planet);
    });

    // Current Sky context — sky reading only, no natal interpretation.
    SkyHouseReading? skyReading;
    String? cycleEndDate;
    final houses = profile?.skyHouseReadings?['houses'];
    if (houses is Map) {
      final raw = houses['$actualHouse'] ?? houses[actualHouse];
      if (raw is Map) {
        skyReading = SkyHouseReading(
          headline: (raw['headline'] as String?)?.trim(),
          reading: (raw['reading'] as String?)?.trim(),
          focus: (raw['focus'] as String?)?.trim(),
          watch: (raw['watch'] as String?)?.trim(),
        );
      }
      cycleEndDate = profile?.skyHouseReadings?['cycleEndDate'] as String?;
    }

    HouseDetailsDialog.show(
      context,
      HouseInfo(
        houseNumber: actualHouse,
        zodiacSign: zodiacSign,
        signLord: signLord,
        planets: planets,
        skyReading: skyReading,
        cycleEndDate: cycleEndDate,
      ),
      isDark,
    );
  }
}

/// Muhurat loading placeholder
class _HolyCowMuhuratPlaceholder extends StatelessWidget {
  final Color cardColor;
  const _HolyCowMuhuratPlaceholder({required this.cardColor});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Row(
          children: [
            AppLoadingIndicator(
              size: 16,
              strokeWidth: 2,
              color: c.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(
              'Loading time guidance...',
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// HolyCowCosmicSkeleton is defined in holycow_empty_states.dart
