import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kundali_chart/kundali_chart.dart';
import 'package:aurogram/features/astrology/data/utils/chart_utils.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/widgets/chart_blend_slider.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/widgets/timeline_slider.dart';
import 'package:aurogram/features/astrology/presentation/widgets/kundali_house_hit_test.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Card widget displaying the current sky chart with optional birth chart overlay
class CosmicSkyChartCard extends StatelessWidget {
  /// The slider's midpoint value, which represents "today".
  static const double _todaySliderValue = 0.5;

  /// Resolved planetary positions for the current slider date.
  final Map<String, dynamic> currentPositions;
  final Map<String, dynamic>? birthChartData;
  final bool isDark;
  final double sliderValue;
  final DateTime sliderDate;
  final bool skyDataLoaded;
  final bool skyDataLoading;
  final bool showTransitOverlay;
  final double chartBlendValue;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onResetToToday;
  final VoidCallback onToggleTransitOverlay;
  final ValueChanged<double> onBlendValueChanged;
  final VoidCallback? onLoadSkyPositions;
  final VoidCallback? onTriggerCachePopulation;
  final Map<String, dynamic>? Function(DateTime) getPositionsForDate;
  final Map<String, dynamic>? Function(DateTime) getInterpolatedPositions;
  /// Optional callback to navigate to the Astrology Details (birth chart) page.
  final VoidCallback? onExploreBirthChart;
  /// Optional daily insight main text. When non-empty, a small insight
  /// block is rendered at the bottom of the card.
  final String? insightText;
  /// Optional callback fired when the user taps a house in the sky chart.
  /// Receives the house number (1..12). Used by the parent to show a
  /// per-house current-state popup (HouseDetailsDialog).
  final void Function(int houseNumber, Map<String, dynamic> currentPositions)?
      onHouseTap;

  const CosmicSkyChartCard({
    super.key,
    required this.currentPositions,
    this.birthChartData,
    required this.isDark,
    required this.sliderValue,
    required this.sliderDate,
    required this.skyDataLoaded,
    required this.skyDataLoading,
    required this.showTransitOverlay,
    required this.chartBlendValue,
    required this.onSliderChanged,
    required this.onResetToToday,
    required this.onToggleTransitOverlay,
    required this.onBlendValueChanged,
    this.onLoadSkyPositions,
    this.onTriggerCachePopulation,
    required this.getPositionsForDate,
    required this.getInterpolatedPositions,
    this.onExploreBirthChart,
    this.onHouseTap,
    this.insightText,
  });

  /// Whether the time slider is parked at "today" (its midpoint).
  bool get isSliderOnToday =>
      (sliderValue - _todaySliderValue).abs() < 0.01;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1A1A1C) : Colors.white;
    final c = AppTheme.primaryColor;

    // Calculate positions based on slider
    final positions = _calculatePositions();

    if (positions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get user's lagna sign index for house numbering
    final lagnaSignIndex = ChartUtils.getLagnaSignIndex(birthChartData);

    // Build sky houses by SIGN (Aries=position 0), with house numbers from lagna
    final skyHouses = ChartUtils.buildCurrentSkyHouses(positions);
    final skyLabels = ChartUtils.getSignFixedLabels(lagnaSignIndex);
    final dateStr = DateFormat('MMM d, yyyy').format(sliderDate);

    // Birth chart data for overlay
    final birthHouses = birthChartData != null
        ? ChartUtils.extractBirthChartHouses(birthChartData!)
        : null;
    final birthLabels = birthChartData != null
        ? ChartUtils.getZodiacLabels(birthChartData!)
        : null;
    final hasBirthChart = birthHouses != null && birthLabels != null;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Column(
        children: [
          // Header with date display and birth chart toggle
          _buildHeader(c, dateStr, isSliderOnToday, hasBirthChart),

          // Chart with overlay
          _buildChart(
            context,
            positions,
            skyHouses,
            skyLabels,
            birthHouses,
            birthLabels,
            hasBirthChart,
            dateStr,
          ),

          // Blend slider when overlay is active
          if (showTransitOverlay && hasBirthChart)
            ChartBlendSlider(
              value: chartBlendValue,
              onChanged: onBlendValueChanged,
              isDark: isDark,
            ),

          // Time Slider
          TimelineSlider(
            value: sliderValue,
            onChanged: skyDataLoaded ? onSliderChanged : null,
            hasData: skyDataLoaded,
            isLoading: skyDataLoading,
            onLoadData: onLoadSkyPositions,
            onForceRefresh: onTriggerCachePopulation,
            isDark: isDark,
          ),

          // Explore birth chart affordance
          if (onExploreBirthChart != null && hasBirthChart)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onExploreBirthChart!();
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.paddingLg,
                  top: AppDimensions.spacingSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Explore birth chart',
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w600,
                        color: c.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: c.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),

          // Daily insight main text
          if (insightText != null && insightText!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                insightText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: c.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculatePositions() {
    if (skyDataLoaded && !isSliderOnToday) {
      // Use cached/interpolated positions for slider date
      final sliderPositions = getInterpolatedPositions(sliderDate);
      // Merge with current positions to fill any gaps
      if (sliderPositions != null && sliderPositions.isNotEmpty) {
        return ChartUtils.mergePositions(sliderPositions, currentPositions);
      }
    } else if (skyDataLoaded && isSliderOnToday) {
      // Even for today, prefer the cached data for consistency
      final cachedToday = getPositionsForDate(DateTime.now());
      // Merge with current positions to ensure no planets are missing
      if (cachedToday != null && cachedToday.isNotEmpty) {
        return ChartUtils.mergePositions(cachedToday, currentPositions);
      }
    }

    return currentPositions;
  }

  Widget _buildHeader(
    Color c,
    String dateStr,
    bool isSliderOnToday,
    bool hasBirthChart,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Date/Title
          Expanded(
            child: Text(
              isSliderOnToday ? 'Current Sky' : dateStr,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
          // Action buttons
          Row(
            children: [
              // Birth chart overlay toggle
              if (hasBirthChart)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onToggleTransitOverlay();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: showTransitOverlay
                          ? c.withValues(alpha: 0.15)
                          : c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Text(
                      showTransitOverlay ? 'Sky Only' : 'Show Birth',
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w600,
                        color:
                            c.withValues(alpha: showTransitOverlay ? 0.8 : 0.6),
                      ),
                    ),
                  ),
                ),
              // Reset to today button
              if (!isSliderOnToday) ...[
                const SizedBox(width: AppDimensions.spacingSm),
                GestureDetector(
                  onTap: onResetToToday,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w600,
                        color: c.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    Map<String, dynamic> positions,
    List<List<String>> skyHouses,
    List<String> skyLabels,
    List<List<String>>? birthHouses,
    List<String>? birthLabels,
    bool hasBirthChart,
    String dateStr,
  ) {
    // Use LayoutBuilder to get parent constraints instead of screen width
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 32;
        // Cap chart size for web - max 500px keeps it readable
        final chartWidth = availableWidth.clamp(200.0, 500.0);
        const padding = 12.0;
        final innerSize = chartWidth - (padding * 2);
        const baseScale = 1.23;

        return Center(
          child: RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onHouseTap == null
                  ? null
                  : (details) {
                      final houseNumber = houseFromLocalTap(
                        localX: details.localPosition.dx,
                        localY: details.localPosition.dy,
                        containerWidth: chartWidth,
                        containerHeight: chartWidth,
                        padding: padding,
                        scaleX: baseScale,
                        scaleY: baseScale,
                      );
                      if (houseNumber != null) {
                        onHouseTap!(houseNumber, positions);
                      }
                    },
              child: Container(
              width: chartWidth,
              height: chartWidth,
              padding: const EdgeInsets.all(padding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                child: Transform.scale(
                  scale: baseScale,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: innerSize,
                    height: innerSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Current Sky Chart
                        Opacity(
                          opacity: showTransitOverlay
                              ? (1 - chartBlendValue).clamp(0.15, 1.0)
                              : 1.0,
                          child: KundaliChart(
                            key: ValueKey('sky_$dateStr'),
                            houses: skyHouses,
                            strokeColor: isDark
                                ? Colors.teal.shade300
                                : Colors.teal.shade700,
                            houseLabelStyle: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.teal.shade300
                                  : Colors.teal.shade700,
                              height: 1.2,
                            ),
                            planetStyle: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.cyan.shade300
                                  : Colors.teal.shade900,
                              height: 1.2,
                            ),
                            lineWidth: 1,
                            houseLabels: skyLabels,
                          ),
                        ),

                        // Birth Chart Overlay (same size)
                        if (showTransitOverlay &&
                            birthHouses != null &&
                            birthLabels != null)
                          Opacity(
                            opacity: chartBlendValue.clamp(0.15, 1.0),
                            child: KundaliChart(
                              houses: birthHouses,
                              strokeColor: isDark
                                  ? Colors.amber.shade400
                                  : Colors.amber.shade700,
                              houseLabelStyle: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.amber.shade400
                                    : Colors.amber.shade800,
                                height: 1.2,
                              ),
                              planetStyle: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.orange.shade300
                                    : Colors.deepOrange.shade700,
                                height: 1.2,
                              ),
                              lineWidth: 1.5,
                              houseLabels: birthLabels,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
