import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_formatters.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

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

  @override
  Widget build(BuildContext context) {
    final hoursCount = ((endTime - startTime) ~/ 60) + 1;
    final timelineWidth = hoursCount * hourWidth;
    final brownColor = AppTheme.primaryColor;
    final brownLight = AppTheme.primaryColor.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Bad times labels
        SizedBox(
          width: timelineWidth,
          height: 35,
          child: Stack(
            clipBehavior: Clip.none,
            children:
                events.where((e) => e['type'] == 'inauspicious').map((event) {
              final startMinutes = event['start'] as int;
              final endMinutes = event['end'] as int;
              final startHour = (startMinutes - startTime) / 60.0;
              final endHour = (endMinutes - startTime) / 60.0;
              final left = startHour * hourWidth;
              final width = (endHour - startHour) * hourWidth;
              final centerX = left + (width / 2);

              final startTimeText =
                  AstrologyFormatters.formatTimeWithAMPM(startMinutes);
              final endTimeText =
                  AstrologyFormatters.formatTimeWithAMPM(endMinutes);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: centerX - 60,
                    top: 3,
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
                                color:
                                    (event['color'] as Color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
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
                          const SizedBox(height: 1),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 12,
                            color: event['color'] as Color,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: left - 40,
                    top: 23,
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        startTimeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: event['color'] as Color,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Positioned(
                    left: left + width - 40,
                    top: 23,
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        endTimeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: event['color'] as Color,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
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
              // Hour markers (dots) - centered on hour marks
              ...List.generate(
                hoursCount,
                (index) => Positioned(
                  left: index * hourWidth -
                      3, // Center the 6px dot on the hour mark
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
                            color: (event['color'] as Color).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                            border: Border.all(
                              color: event['color'] as Color,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Start marker - centered at event start position
                    Positioned(
                      left: left - 6, // Center 12px marker at start position
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
                    // End marker - centered at event end position
                    Positioned(
                      left: left +
                          width -
                          6, // Center 12px marker at end position
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
              // Live time dot (if current day) - blinking, centered on timeline
              if (currentTimeMinutes != null &&
                  currentTimeMinutes! >= startTime &&
                  currentTimeMinutes! <= endTime &&
                  blinkController != null)
                Positioned(
                  left: ((currentTimeMinutes! - startTime) / 60.0) * hourWidth -
                      6,
                  top:
                      9, // Centered: line at 14 with height 2 (center=15), dot is 12px, so top=15-6=9
                  child: FadeTransition(
                    opacity: blinkController!,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade600.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxxs),
        // Row 3: Good times labels
        SizedBox(
          width: timelineWidth,
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            children:
                events.where((e) => e['type'] == 'auspicious').map((event) {
              final startMinutes = event['start'] as int;
              final endMinutes = event['end'] as int;
              final startHour = (startMinutes - startTime) / 60.0;
              final endHour = (endMinutes - startTime) / 60.0;
              final left = startHour * hourWidth;
              final width = (endHour - startHour) * hourWidth;
              final centerX = left + (width / 2);

              final startTimeText =
                  AstrologyFormatters.formatTimeWithAMPM(startMinutes);
              final endTimeText =
                  AstrologyFormatters.formatTimeWithAMPM(endMinutes);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: left - 40,
                    top: 0,
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        startTimeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: event['color'] as Color,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Positioned(
                    left: left + width - 40,
                    top: 0,
                    child: SizedBox(
                      width: 80,
                      child: Text(
                        endTimeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: event['color'] as Color,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Positioned(
                    left: centerX - 60,
                    top: 8,
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            size: 12,
                            color: event['color'] as Color,
                          ),
                          const SizedBox(height: 1),
                          GestureDetector(
                            onTap: onEventTap == null
                                ? null
                                : () => onEventTap!(event),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    (event['color'] as Color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
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
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        // Row 4: Hour labels at bottom - centered under hour marks
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
                    left: index * hourWidth -
                        30, // Center 60px label under hour mark
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
