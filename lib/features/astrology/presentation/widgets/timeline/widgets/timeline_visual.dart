import 'package:flutter/material.dart';

/// "Solid Ribbon" timeline — a compact, Swiss-watch-minimal rendering.
///
/// Instead of floating labels on connector sticks across stacked lanes, the
/// track is a single solid ribbon split into two internal halves:
///   • top half  → auspicious events (their names embedded inside the block)
///   • bottom half → inauspicious events (names embedded inside the block)
/// The current time is a stark white needle slicing through the whole ribbon,
/// and tiny hour ticks sit immediately below. No "Time Guidance" title, no
/// connector sticks, no vertical lanes.
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

  // ── Ribbon geometry ──
  static const double _ribbonHeight = 24.0;
  static const double _halfHeight = _ribbonHeight / 2;

  double _xForMinute(int minute) =>
      ((minute - startTime) / 60.0) * hourWidth;

  /// One event block embedded inside the ribbon. [topHalf] decides which
  /// internal track it occupies.
  Widget _eventBlock(Map<String, dynamic> event, {required bool topHalf}) {
    final start = event['start'] as int;
    final end = event['end'] as int;
    final color = event['color'] as Color;
    final name = (event['name'] as String).toUpperCase();

    final left = _xForMinute(start);
    final rawWidth = _xForMinute(end) - left;
    final width = rawWidth > 2 ? rawWidth : 2.0;
    final showLabel = width > 30;

    return Positioned(
      left: left,
      top: topHalf ? 0 : _halfHeight,
      child: GestureDetector(
        onTap: onEventTap == null ? null : () => onEventTap!(event),
        child: Container(
          width: width,
          height: _halfHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
          ),
          child: showLabel
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── The Ribbon ──
        SizedBox(
          width: timelineWidth,
          height: _ribbonHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Base track surface (so empty time still reads as a ribbon).
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // Thread splitting the two halves.
              Positioned(
                left: 0,
                right: 0,
                top: _halfHeight - 1,
                child: Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.2),
                ),
              ),
              // Clip event blocks to the rounded ribbon shape.
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ...auspicious
                          .map((e) => _eventBlock(e, topHalf: true)),
                      ...inauspicious
                          .map((e) => _eventBlock(e, topHalf: false)),
                    ],
                  ),
                ),
              ),
              // The "Now" needle: a stark white vertical hairline.
              if (hasNow)
                Positioned(
                  left: _xForMinute(currentTimeMinutes!) - 0.5,
                  top: 0,
                  child: Container(
                    width: 1,
                    height: _ribbonHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // ── Hour ticks immediately below the ribbon ──
        SizedBox(
          width: timelineWidth,
          height: 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(hoursCount, (index) {
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
