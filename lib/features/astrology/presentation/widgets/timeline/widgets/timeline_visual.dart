import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/presentation/widgets/common/pulsing_dot.dart';

/// The core visual rendering of the horizontal timeline: bars, markers,
/// hour labels, live-time dot, and event labels.
class TimelineVisual extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final int startTime;
  final int endTime;
  final double hourWidth;
  final bool isDark;
  final int? currentTimeMinutes;
  final Map<int, String>? dayBoundaries;
  final AnimationController? blinkController;
  final void Function(Map<String, dynamic> event)? onEventTap;

  const TimelineVisual({
    super.key,
    required this.events,
    required this.startTime,
    required this.endTime,
    required this.hourWidth,
    required this.isDark,
    this.currentTimeMinutes,
    this.dayBoundaries,
    this.blinkController,
    this.onEventTap,
  });

  /// Assign non-overlapping vertical lanes to event labels so they don't
  /// overlap when events cluster together.
  static List<Map<String, dynamic>> _assignLanes(
    List<Map<String, dynamic>> events,
    int startTime,
    double hourWidth,
  ) {
    final sorted = List<Map<String, dynamic>>.from(events)
      ..sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    final laneEnds = <double>[]; // rightmost occupied x per lane
    final result = <Map<String, dynamic>>[];
    const labelHalfWidth = 60.0;
    const gap = 4.0;

    for (final event in sorted) {
      final s = event['start'] as int;
      final e = event['end'] as int;
      final startHour = (s - startTime) / 60.0;
      final endHour = (e - startTime) / 60.0;
      final left = startHour * hourWidth;
      final width = (endHour - startHour) * hourWidth;
      final centerX = left + width / 2;
      final labelLeft = centerX - labelHalfWidth;
      final labelRight = centerX + labelHalfWidth;

      int lane = -1;
      for (int i = 0; i < laneEnds.length; i++) {
        if (labelLeft >= laneEnds[i] + gap) {
          lane = i;
          break;
        }
      }
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(double.negativeInfinity);
      }
      laneEnds[lane] = labelRight;

      result.add({...event, '_lane': lane, '_centerX': centerX});
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final hoursCount = ((endTime - startTime) ~/ 60) + 1;
    final timelineWidth = hoursCount * hourWidth;
    final brownColor = AppTheme.primaryColor;
    final brownLight = AppTheme.primaryColor.withValues(alpha: 0.35);

    // Pre-compute staggered label positions
    final inauspiciousLanes = _assignLanes(
      events.where((e) => e['type'] == 'inauspicious').toList(),
      startTime,
      hourWidth,
    );
    final iMaxLane = inauspiciousLanes.isEmpty
        ? 0
        : inauspiciousLanes.fold<int>(
            0, (m, e) => (e['_lane'] as int) > m ? (e['_lane'] as int) : m);

    final auspiciousLanes = _assignLanes(
      events.where((e) => e['type'] == 'auspicious').toList(),
      startTime,
      hourWidth,
    );
    final aMaxLane = auspiciousLanes.isEmpty
        ? 0
        : auspiciousLanes.fold<int>(
            0, (m, e) => (e['_lane'] as int) > m ? (e['_lane'] as int) : m);

    const laneHeight = 26.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Inauspicious labels (staggered lanes, no inline times)
        SizedBox(
          width: timelineWidth,
          height: (iMaxLane + 1) * laneHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: inauspiciousLanes.map((event) {
              final centerX = event['_centerX'] as double;
              final lane = event['_lane'] as int;
              return Positioned(
                left: centerX - 60,
                top: lane * laneHeight,
                child: SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onEventTap == null
                            ? null
                            : () => onEventTap!(event),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: (event['color'] as Color)
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSmMd),
                          ),
                          child: Text(
                            event['name'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: event['color'] as Color,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 10,
                        color: event['color'] as Color,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxxs),
        // Row 2: Timeline line with colored bars
        SizedBox(
          width: timelineWidth,
          height: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main timeline line
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: brownLight,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Hour markers (dots)
              ...List.generate(
                hoursCount,
                (index) => Positioned(
                  left: index * hourWidth - 3,
                  top: 12,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: brownColor.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // Colored highlight bars
              ...events.map((event) {
                final startMinutes = event['start'] as int;
                final endMinutes = event['end'] as int;
                final startHour = (startMinutes - startTime) / 60.0;
                final endHour = (endMinutes - startTime) / 60.0;
                final left = startHour * hourWidth;
                final width = (endHour - startHour) * hourWidth;
                const barHeight = 20.0;

                final isInauspicious = event['type'] == 'inauspicious';
                final barTop = isInauspicious
                    ? 14.0 - (barHeight / 2) - 3.0
                    : 14.0 - (barHeight / 2) + 3.0;
                final markerTop =
                    isInauspicious ? 14.0 - 6.0 - 3.0 : 14.0 - 6.0 + 3.0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: left,
                      top: barTop,
                      child: GestureDetector(
                        onTap: onEventTap == null
                            ? null
                            : () => onEventTap!(event),
                        child: Container(
                          width: width > 3 ? width : 3,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color:
                                (event['color'] as Color).withValues(alpha: 0.7),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMdSm),
                            border: Border.all(
                              color: event['color'] as Color,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Start marker
                    Positioned(
                      left: left - 6,
                      top: markerTop,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: event['color'] as Color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.black87 : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // End marker
                    Positioned(
                      left: left + width - 6,
                      top: markerTop,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: event['color'] as Color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.black87 : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              // Live time dot
              if (currentTimeMinutes != null &&
                  currentTimeMinutes! >= startTime &&
                  currentTimeMinutes! <= endTime)
                Positioned(
                  left: ((currentTimeMinutes! - startTime) / 60.0) * hourWidth -
                      6,
                  top: 9,
                  child: const PulsingDot(
                    size: 12,
                    borderWidth: 2,
                    showShadow: true,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxxs),
        // Row 3: Auspicious labels (staggered lanes, no inline times)
        SizedBox(
          width: timelineWidth,
          height: (aMaxLane + 1) * laneHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: auspiciousLanes.map((event) {
              final centerX = event['_centerX'] as double;
              final lane = event['_lane'] as int;
              return Positioned(
                left: centerX - 60,
                top: lane * laneHeight,
                child: SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        size: 10,
                        color: event['color'] as Color,
                      ),
                      GestureDetector(
                        onTap: onEventTap == null
                            ? null
                            : () => onEventTap!(event),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: (event['color'] as Color)
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSmMd),
                          ),
                          child: Text(
                            event['name'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: event['color'] as Color,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Row 4: Hour labels
        SizedBox(
          width: timelineWidth,
          height: 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ...List.generate(
                hoursCount,
                (index) {
                  final absoluteMinutes = startTime + (index * 60);
                  final hourOfDay = (absoluteMinutes % (24 * 60)) ~/ 60;
                  final hour12 = hourOfDay == 0
                      ? 12
                      : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay);
                  final ampm = hourOfDay < 12 ? 'AM' : 'PM';
                  return Positioned(
                    left: index * hourWidth - 30,
                    top: 0,
                    child: SizedBox(
                      width: 60,
                      child: Text(
                        '$hour12 $ampm',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: brownColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
