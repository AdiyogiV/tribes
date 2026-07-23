import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/domain/astro_calendar_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dashboard/sky_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dashboard/dashboard_load_state.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/balance_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/sky_house_dialog.dart';

/// The canonical stack of supporting cards for the cosmic dashboard, in their
/// single source-of-truth display order: Current Sky -> (wheel) -> Upcoming
/// Events -> Today's Balance -> Your Chart -> Mood check-in.
///
/// Rendered as a [Column] so the same instance can be dropped into either the
/// single-column mobile stack or the desktop right pane. Cards self-hide
/// (SizedBox.shrink) when their data is missing.
class AstroDashboardCards extends StatelessWidget {
  final AstrologyProfile? profile;
  final AyurvedaProfile? ayurvedaProfile;
  final DashboardLoadingState loadingState;
  final SkyPositionsService skyService;
  final AstroCalendarService? calendarService;
  final ValueNotifier<double> sliderValueNotifier;
  final ValueNotifier<DateTime> sliderDateNotifier;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onResetToToday;

  /// Steps the sky date by whole days (−1 / +1) — drives the Sky card's
  /// PREV/NEXT chevrons.
  final void Function(int deltaDays)? onStepDays;
  final Future<void> Function({bool isRetry}) onLoadSkyPositions;
  final Future<void> Function() onTriggerCachePopulation;
  final double spacing;

  /// Wheel + text-insight combo injected directly below the Current Sky card
  /// on mobile (null on desktop, where the wheel lives in its own column).
  final Widget? insertBeforeSkyCard;

  const AstroDashboardCards({
    super.key,
    required this.profile,
    required this.ayurvedaProfile,
    required this.loadingState,
    required this.skyService,
    required this.calendarService,
    required this.sliderValueNotifier,
    required this.sliderDateNotifier,
    required this.onSliderChanged,
    required this.onResetToToday,
    this.onStepDays,
    required this.onLoadSkyPositions,
    required this.onTriggerCachePopulation,
    required this.spacing,
    this.insertBeforeSkyCard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build individual cards (ignoring nulls later)
    final Widget? balanceCard = (ayurvedaProfile != null && ayurvedaProfile!.prakriti != null)
        ? GestureDetector(
            onTap: () {
              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
              context.push('${RouteNames.ayurvedaDetails}/$uid');
            },
            child: BalanceCard(
              prakriti: ayurvedaProfile!.prakriti!,
              vikriti: ayurvedaProfile!.vikriti,
              aiGuidance: ayurvedaProfile!.aiGuidance,
              isCalculating: false,
              lastCheckIn: ayurvedaProfile!.lastCheckIn,
              isDark: isDark,
            ),
          )
        : null;

    final Widget? skyCard = loadingState.isSkyLoaded
        ? ValueListenableBuilder<double>(
            valueListenable: sliderValueNotifier,
            builder: (context, sliderValue, _) {
              return ValueListenableBuilder<DateTime>(
                valueListenable: sliderDateNotifier,
                builder: (context, sliderDate, _) {
                  final skyPositions = skyService.getPositionsForDate(sliderDate);
                  Map<String, dynamic>? positions;
                  if (skyPositions != null && skyPositions.isNotEmpty) {
                    positions = skyPositions;
                  } else if (calendarService != null) {
                    positions = calendarService!.getPositionsForDate(sliderDate);
                  }
                  if (positions == null || positions.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SkyCard(
                    currentPositions: positions,
                    birthChartData: profile?.birthChartData,
                    isDark: isDark,
                    sliderValue: sliderValue,
                    sliderDate: sliderDate,
                    skyDataLoaded: loadingState.isSkyLoaded,
                    skyDataLoading: loadingState.isSkyLoading,
                    onSliderChanged: onSliderChanged,
                    onResetToToday: onResetToToday,
                    onStepDays: onStepDays,
                    onLoadSkyPositions: onLoadSkyPositions,
                    onTriggerCachePopulation: onTriggerCachePopulation,
                    getPositionsForDate: (date) {
                      return skyService.getPositionsForDate(date) ??
                          calendarService?.getPositionsForDate(date);
                    },
                    getInterpolatedPositions: (date) {
                      final interp = skyService.getInterpolatedPositions(date);
                      if (interp != null && interp.isNotEmpty) return interp;
                      return calendarService?.getPositionsForDate(date);
                    },
                    onExploreBirthChart: profile != null
                        ? () {
                            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                            context.push('${RouteNames.astrologyDetails}/$uid');
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
                    buildGocharaHouses: (positions) =>
                        buildRankedGocharaHouses(profile, positions),
                    onGocharaHouseTap: (info) =>
                        showHouseDetails(context, info, isDark),
                  );
                },
              );
            },
          )
        : null;

    final isWide = MediaQuery.of(context).size.width >= 820; // Matches AstroDashboardContent desktopBreak

    if (isWide) {
      // PREMIUM DESKTOP LAYOUT — insight cards stacked vertically.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (insertBeforeSkyCard != null) ...[
            insertBeforeSkyCard!,
            SizedBox(height: spacing),
          ],
          if (balanceCard != null) ...[
            balanceCard,
            SizedBox(height: spacing),
          ],
          if (skyCard != null) ...[
            skyCard,
            SizedBox(height: spacing),
          ],
          const SizedBox(height: AppDimensions.spacingSection),
        ],
      );
    }

    // MOBILE LAYOUT (Stack)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (insertBeforeSkyCard != null) ...[
          insertBeforeSkyCard!,
          SizedBox(height: spacing),
        ],
        if (balanceCard != null) ...[
          balanceCard,
          SizedBox(height: spacing),
        ],
        if (skyCard != null) ...[
          skyCard,
          SizedBox(height: spacing),
        ],
        const SizedBox(height: AppDimensions.spacingSection),
      ],
    );
  }
}
