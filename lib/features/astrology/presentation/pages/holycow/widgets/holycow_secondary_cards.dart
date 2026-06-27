import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/domain/astro_calendar_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/upcoming_events_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/your_chart_mini_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/widgets/cosmic_sky_chart_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/features/astrology/presentation/widgets/nakshatra_ring_widget.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/widgets/holycow_sky_house_dialog.dart';

/// The canonical stack of supporting cards for the cosmic dashboard, in their
/// single source-of-truth display order: Current Sky -> (wheel) -> Upcoming
/// Events -> Today's Balance -> Your Chart -> Mood check-in.
///
/// Rendered as a [Column] so the same instance can be dropped into either the
/// single-column mobile stack or the desktop right pane. Cards self-hide
/// (SizedBox.shrink) when their data is missing.
class HolyCowSecondaryCards extends StatelessWidget {
  final AstrologyProfile? profile;
  final DailyInsight? insight;
  final AyurvedaProfile? ayurvedaProfile;
  final DashboardLoadingState loadingState;
  final SkyPositionsService skyService;
  final AstroCalendarService? calendarService;
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
  final NakshatraWheelController? nakshatraController;
  final double spacing;

  /// Wheel + text-insight combo injected directly below the Current Sky card
  /// on mobile (null on desktop, where the wheel lives in its own column).
  final Widget? insertAfterSkyCard;

  const HolyCowSecondaryCards({
    super.key,
    required this.profile,
    required this.insight,
    required this.ayurvedaProfile,
    required this.loadingState,
    required this.skyService,
    required this.calendarService,
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
    required this.nakshatraController,
    required this.spacing,
    this.insertAfterSkyCard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.primaryColor;
    final insightTransits =
        insight?.astrologicalData?['transits'] as Map<String, dynamic>?;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Current Sky with optional Birth Chart overlay
        if (loadingState.isSkyLoaded) ...[
          ValueListenableBuilder<double>(
            valueListenable: sliderValueNotifier,
            builder: (context, sliderValue, _) {
              return ValueListenableBuilder<DateTime>(
                valueListenable: sliderDateNotifier,
                builder: (context, sliderDate, _) {
                  // Position lookup chain:
                  // 1. SkyPositionsService (exact, +/-30 days)
                  // 2. AstroCalendarService (compact, +/-365 days)
                  // 3. Insight transits (today only, fallback)
                  final skyPositions =
                      skyService.getPositionsForDate(sliderDate);
                  final today = DateTime.now();
                  final isSliderToday = sliderDate.year == today.year &&
                      sliderDate.month == today.month &&
                      sliderDate.day == today.day;
                  Map<String, dynamic>? positions;
                  if (skyPositions != null && skyPositions.isNotEmpty) {
                    positions = skyPositions;
                  } else if (calendarService != null) {
                    positions =
                        calendarService!.getPositionsForDate(sliderDate);
                  }
                  positions ??= isSliderToday ? insightTransits : null;

                  if (positions == null || positions.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return CosmicSkyChartCard(
                    currentPositions: positions,
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
                    getPositionsForDate: (date) {
                      // Try exact sky positions first, then calendar.
                      return skyService.getPositionsForDate(date) ??
                          calendarService?.getPositionsForDate(date);
                    },
                    getInterpolatedPositions: (date) {
                      // Try interpolated sky positions first, then calendar.
                      final interp =
                          skyService.getInterpolatedPositions(date);
                      if (interp != null && interp.isNotEmpty) return interp;
                      return calendarService?.getPositionsForDate(date);
                    },
                    onExploreBirthChart: profile != null
                        ? () {
                            final uid =
                                FirebaseAuth.instance.currentUser?.uid ?? '';
                            context.push(
                                '${RouteNames.astrologyDetails}/$uid');
                          }
                        : null,
                    onHouseTap: (houseNumber, currentPositions) {
                      showSkyHouseDialog(
                        context,
                        profile,
                        houseNumber,
                        currentPositions,
                        isDark,
                      );
                    },
                    insightText: insight?.displayMessage,
                  );
                },
              );
            },
          ),
          SizedBox(height: spacing),
        ],

        // Wheel + text-insight combo — injected directly BELOW the Current
        // Sky card on mobile. When sky data hasn't loaded the sky block is
        // skipped and this slots in at the top instead.
        if (insertAfterSkyCard != null) ...[
          insertAfterSkyCard!,
          SizedBox(height: spacing),
        ],

        // Upcoming Planetary Events. The card internally filters to major
        // planets and may return SizedBox.shrink() — only add spacing when
        // the card will actually render content.
        if (loadingState.isEventsLoaded &&
            skyService.hasUpcomingEvents &&
            skyService.allUpcomingEvents.any((e) => const [
                  'Sun', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
                ].contains(e.planet))) ...[
          UpcomingEventsCard(
            brown: brown,
            events: skyService.allUpcomingEvents,
            maxEvents: 8,
          ),
          SizedBox(height: spacing),
        ],

        // Current Balance (Ayurveda Vikriti) — tappable -> Ayurveda Details
        if (ayurvedaProfile != null && ayurvedaProfile!.prakriti != null) ...[
          GestureDetector(
            onTap: () {
              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
              context.push('${RouteNames.astrologyDetails}/$uid');
            },
          ),
          SizedBox(height: spacing),
        ],

        // Mood check-in — bottom of page. Lives here (not inside
        // NakshatraRingWidget) so it is an independent, freely-repositionable
        // card. Collapses when the wheel is not at today.
        if (nakshatraController != null) ...[
          NakshatraMoodCheckInCard(controller: nakshatraController!),
          SizedBox(height: spacing),
        ],

        const SizedBox(height: AppDimensions.spacingSection),
      ],
    );
  }
}
