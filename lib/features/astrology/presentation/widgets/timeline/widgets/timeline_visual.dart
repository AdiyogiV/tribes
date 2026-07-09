import 'package:flutter/material.dart';

/// "Modern Axis" timeline.
/// Ultra-modern, minimal, and grounded. Features a central continuous axis 
/// to anchor the events, with precise geometric blocks floating above and below.
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

  static const double _timelineHeight = 84.0;
  static const double _axisY = 34.0;

  double _xForMinute(int minute) => ((minute - startTime) / 60.0) * hourWidth;

  Widget _eventBlock(Map<String, dynamic> event, {required bool isTop}) {
    final start = event['start'] as int;
    final end = event['end'] as int;
    final color = event['color'] as Color;
    final name = (event['name'] as String).toUpperCase();

    final left = _xForMinute(start);
    final rawWidth = _xForMinute(end) - left;
    final width = rawWidth > 2 ? rawWidth : 2.0;
    final showLabel = width > 35;

    // Mathematically precise floating: 4px gap from the axis
    final top = isTop ? _axisY - 24 : _axisY + 4;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: onEventTap == null ? null : () => onEventTap!(event),
        child: Container(
          width: width,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: showLabel
              ? Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoursCount = ((endTime - startTime) ~/ 60) + 1;
    final timelineWidth = hoursCount * hourWidth;

    final auspicious = events.where((e) => e['type'] == 'auspicious');
    final inauspicious = events.where((e) => e['type'] == 'inauspicious');

    final hasNow = currentTimeMinutes != null &&
        currentTimeMinutes! >= startTime &&
        currentTimeMinutes! <= endTime;

    // Theme-aware ink for axis/nodes/labels: white on dark, black on light.
    final ink = isDark ? Colors.white : Colors.black;

    return SizedBox(
      width: timelineWidth,
      height: _timelineHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. The Central Axis Line
          Positioned(
            left: 0,
            right: 0,
            top: _axisY,
            child: Container(
              height: 1,
              color: ink.withValues(alpha: 0.15),
            ),
          ),

          // 2. Hour Nodes on the Axis
          ...List.generate(hoursCount, (index) {
            final absoluteMinutes = startTime + (index * 60);
            final hourOfDay = (absoluteMinutes % (24 * 60)) ~/ 60;
            final hour12 = hourOfDay == 0 ? 12 : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay);
            final ampm = hourOfDay < 12 ? 'AM' : 'PM';
            final x = index * hourWidth;
            
            return Positioned(
              left: x - 30,
              top: _axisY - 2,
              child: SizedBox(
                width: 60,
                child: Column(
                  children: [
                    // Node on the axis
                    Container(
                      width: 1, 
                      height: 5, 
                      color: ink.withValues(alpha: 0.3)
                    ),
                    const SizedBox(height: 30),
                    // Text at the bottom
                    Text(
                      '$hour12 $ampm',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: ink.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // 3. Floating Modern Blocks
          ...auspicious.map((e) => _eventBlock(e, isTop: true)),
          ...inauspicious.map((e) => _eventBlock(e, isTop: false)),

          // 4. The "Now" Indicator Needle
          if (hasNow) ...[
            // Subtle but visible vertical line
            Positioned(
              left: _xForMinute(currentTimeMinutes!) - 0.5,
              top: _axisY - 14,
              child: Container(
                width: 1,
                height: 28,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(0.5),
                ),
              ),
            ),
            // Clean node on the axis
            Positioned(
              left: _xForMinute(currentTimeMinutes!) - 1.5,
              top: _axisY - 1.0,
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
