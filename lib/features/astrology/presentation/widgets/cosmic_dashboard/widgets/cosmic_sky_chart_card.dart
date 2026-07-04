import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/features/astrology/data/utils/chart_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/chic_kundali_chart.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/widgets/timeline_slider.dart';
import 'package:aurogram/features/astrology/presentation/widgets/kundali_house_hit_test.dart';

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
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onResetToToday;
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
    required this.onSliderChanged,
    required this.onResetToToday,
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

    final bg = const Color(0xFF000000); // Vlack (black)
    final fgMain = Colors.white;
    final fgMuted = Colors.white54;

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chic Editorial Header
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: isSliderOnToday ? 'Current ' : 'Time ',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    color: c,
                    fontSize: 32,
                    letterSpacing: -1.2,
                  ),
                ),
                TextSpan(
                  text: isSliderOnToday ? 'Sky.' : 'Travel.',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    color: fgMain,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.2,
                  ),
                ),
              ],
            ),
          ),

          if (insightText != null && insightText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              insightText!,
              style: TextStyle(
                color: fgMuted,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],

          const SizedBox(height: 32), // Breathing room

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

          // Legend — clarifies natal vs transit planets
          if (hasBirthChart) ...[
            const SizedBox(height: 20),
            Center(child: _buildLegend(context, c)),
          ],

          const SizedBox(height: 32),

          // Return to Today Action (Centered, Chic)
          if (!isSliderOnToday) ...[
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onResetToToday,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.replay_circle_filled_rounded,
                      size: 14,
                      color: fgMain,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RETURN TO TODAY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: fgMain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Time Slider (forced dark mode)
          TimelineSlider(
            value: sliderValue,
            onChanged: skyDataLoaded ? onSliderChanged : null,
            hasData: skyDataLoaded,
            isLoading: skyDataLoading,
            onLoadData: onLoadSkyPositions,
            onForceRefresh: onTriggerCachePopulation,
            isDark: true,
          ),

          // Explore birth chart affordance
          if (onExploreBirthChart != null && !hasBirthChart) ...[
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
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
                        color: c,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: c,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Legend distinguishing natal (gold) from transit (sky) planets.
  Widget _buildLegend(BuildContext context, Color c) {
    final transitColor = Colors.white;

    Widget entry(Color dot, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: c.withValues(alpha: 0.7),
              ),
            ),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        entry(c.withValues(alpha: 0.85), 'NATAL'),
        const SizedBox(width: 20),
        entry(transitColor.withValues(alpha: 0.75), 'TRANSIT'),
      ],
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

                        // Forced dark mode since the card is stark black
                        final lineColor = Colors.white.withValues(alpha: 0.3);
                        final planetColor =
                            Colors.white.withValues(alpha: 0.85);

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
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            color: AppTheme.primaryColor.withValues(alpha: 0.8),
                            letterSpacing: 0.5,
                            height: 1.2,
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
