import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/features/astrology/data/utils/chart_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/chic_kundali_chart.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
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
  bool get isSliderOnToday => (sliderValue - _todaySliderValue).abs() < 0.01;

  @override
  Widget build(BuildContext context) {
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

    return TransparentToolbox.buildCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dateline
          Text(
            dateStr.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 3.0,
              color: c.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 10),

          // Editorial Title
          Text(
            isSliderOnToday ? 'Current Sky' : 'Time Travel',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 26,
              letterSpacing: -0.5,
              color: c,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 10),

          // Subtext / Daily Insight
          if (insightText != null && insightText!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                insightText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  height: 1.5,
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 28), // Breathing room

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

          const SizedBox(height: 28),

          // Return to Today Action (Centered, Chic)
          if (!isSliderOnToday) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onResetToToday,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.replay_circle_filled_rounded,
                    size: 14,
                    color: c.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RETURN TO TODAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: c.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
          // Only shown if we somehow don't have birth chart data and want them to add it,
          // OR it's just completely hidden now for ultra-minimalism.
          if (onExploreBirthChart != null && !hasBirthChart) ...[
            const SizedBox(height: 24),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                onExploreBirthChart!();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ADD BIRTH DETAILS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.0,
                      color: c.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: c.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ],
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
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
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
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
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
        const baseScale = 1.0;

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
                child: SizedBox(
                  width: innerSize,
                  height: innerSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Chic Kundali Chart (Handles both Sky, Birth, and "Visiting Spirits" Overlay)
                      Builder(builder: (context) {
                        // Default to showing just the Sky chart
                        List<List<String>> displayHouses = skyHouses;
                        List<String>? displayLabels = skyLabels;
                        List<List<String>>? visitingPlanets;

                        final isDarkTheme =
                            Theme.of(context).brightness == Brightness.dark;
                        final lineColor = isDarkTheme
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4);
                        final labelColor = isDarkTheme
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.5);
                        final planetColor = isDarkTheme
                            ? Colors.white.withValues(alpha: 1.0)
                            : Colors.black.withValues(alpha: 1.0);

                        Color strokeColor = lineColor;
                        double chartLineWidth = 1.0;
                        TextStyle pStyle = TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: planetColor,
                          letterSpacing: 0.5,
                          height: 1.2,
                        );

                        // The Editorial Typographical Overlap (Single Chart)
                        if (hasBirthChart && birthHouses != null) {
                          // The foundation is the Birth Chart
                          displayHouses = birthHouses;
                          displayLabels = birthLabels;
                          strokeColor = AppTheme.primaryColor
                              .withValues(alpha: 0.85); // Prominent Gold lines
                          chartLineWidth = 1.5;

                          pStyle = TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight
                                .w500, // Thinner, smaller font for birth planets
                            color: AppTheme.primaryColor.withValues(alpha: 0.8),
                            letterSpacing: 0.5,
                            height: 1.1,
                          );

                          // The transits (sky planets) stack above the birth planets inside the same house
                          // Since both birthHouses and skyHouses are indexed by SIGN (0=Aries), they align perfectly 1:1.
                          visitingPlanets = List.generate(12, (index) {
                            if (index < skyHouses.length) {
                              return skyHouses[index]; // Clean, no dots
                            }
                            return <String>[];
                          });
                        }

                        return ChicKundaliChart(
                          houses: displayHouses,
                          houseLabels: displayLabels,
                          transitHouses: visitingPlanets,
                          // Ultra-thin, chic geometry
                          strokeColor: strokeColor,
                          lineWidth: chartLineWidth,
                          houseLabelStyle: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 9.0, // Subdued but legible
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: labelColor,
                            height: 1.1,
                          ),
                          planetStyle: pStyle,
                          transitPlanetStyle: TextStyle(
                            fontSize: 11.0, // Extremely Prominent
                            fontWeight: FontWeight.w700, // Bold
                            fontStyle: FontStyle.normal, // Regular (not italic)
                            color: planetColor, // White/Black matching theme
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                        );
                      }),
                    ],
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
