import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_date_time_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_insight_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_panchang_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/upcoming_events_card.dart';
import 'package:aurogram/widgets/cosmic_dashboard/widgets/cosmic_sky_chart_card.dart';
import 'package:aurogram/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Builds the full cosmic dashboard content panel with all cards.
class HolyCowCosmicContent extends StatelessWidget {
  final AstrologyProfile? profile;
  final DailyInsight? insight;
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

    final now = DateTime.now();
    final globalSkyPositions =
        loadingState.isSkyLoaded ? skyService.getPositionsForDate(now) : null;
    final insightTransits =
        insight?.astrologicalData?['transits'] as Map<String, dynamic>?;
    final currentPositions =
        globalSkyPositions != null && globalSkyPositions.isNotEmpty
            ? globalSkyPositions
            : insightTransits;

    final globalMuhurat = skyService.globalMuhurat;
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
                final Map<String, dynamic> merged = {};
                if (todaySamvat != null) merged.addAll(todaySamvat);
                if (insightPanchang != null) merged.addAll(insightPanchang);
                if (globalPanchang != null) merged.addAll(globalPanchang);
                final todayPanchang = merged.isNotEmpty ? merged : null;
                return CosmicDateTimeCard(samvat: todayPanchang, brown: brown);
              }),

              SizedBox(height: spacing),

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
                                : currentPositions;

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
              if (loadingState.isEventsLoaded &&
                  skyService.hasUpcomingEvents) ...[
                UpcomingEventsCard(
                  brown: brown,
                  events: skyService.allUpcomingEvents,
                  maxEvents: 8,
                ),
                SizedBox(height: spacing),
              ],

              // Panchang (global only)
              Builder(builder: (context) {
                final todayPanchang = skyService.getTodayPanchang();
                if (todayPanchang == null || todayPanchang.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    CosmicPanchangCard(panchang: todayPanchang, brown: brown),
                    SizedBox(height: spacing),
                  ],
                );
              }),

              // Today's Insight (Current Energy)
              if (insight != null &&
                  (insight!.displayTheme.isNotEmpty ||
                      insight!.displayMessage.isNotEmpty)) ...[
                CosmicInsightCard(insight: insight!, brown: brown),
                SizedBox(height: spacing),
              ],

              const SizedBox(height: AppDimensions.spacingSection),
            ],
          ),
        );
      },
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
