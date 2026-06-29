import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_formatters.dart';

import 'muhurat_descriptions.dart';
import 'timeline_controller.dart';
import 'timeline_visual.dart';

/// Fallback timeline that processes per-day muhurat data into a single
/// horizontally-scrollable multi-day strip.
class MultiDayTimeline extends StatefulWidget {
  final Map<String, Map<String, dynamic>> daysData;
  final bool isDark;
  final AnimationController? blinkController;
  final TimelineController? controller;

  const MultiDayTimeline({
    super.key,
    required this.daysData,
    required this.isDark,
    this.blinkController,
    this.controller,
  });

  @override
  State<MultiDayTimeline> createState() => _MultiDayTimelineState();
}

class _MultiDayTimelineState extends State<MultiDayTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.daysData.isEmpty) return const SizedBox.shrink();

    final sortedDays = widget.daysData.keys.toList()..sort();
    final allEvents = <Map<String, dynamic>>[];
    final firstDateKey = sortedDays[0];
    final firstDateParts = firstDateKey.split('-');
    if (firstDateParts.length != 3) return const SizedBox.shrink();

    // Convert each day's events to absolute positions
    for (int dayIndex = 0; dayIndex < sortedDays.length; dayIndex++) {
      final dateKey = sortedDays[dayIndex];
      final dayEvents = _processDayEvents(widget.daysData[dateKey]!);

      for (final event in dayEvents) {
        final startMinutes = (event['start'] as num).toInt();
        final endMinutes = (event['end'] as num).toInt();

        final absoluteStart = (dayIndex * 24 * 60) + startMinutes;
        final absoluteEnd = (dayIndex * 24 * 60) + endMinutes;

        allEvents.add({
          'name': event['name'],
          'start': absoluteStart,
          'end': absoluteEnd,
          'type': event['type'],
          'color': event['type'] == 'inauspicious'
              ? (widget.isDark ? Colors.red.shade300 : Colors.red.shade600)
              : (widget.isDark ? Colors.green.shade300 : Colors.green.shade700),
          'dateKey': dateKey,
        });
      }
    }

    if (allEvents.isEmpty) return const SizedBox.shrink();

    int minTime =
        allEvents.map((e) => e['start'] as int).reduce((a, b) => a < b ? a : b);
    int maxTime =
        allEvents.map((e) => e['end'] as int).reduce((a, b) => a > b ? a : b);

    minTime = (minTime ~/ 60) * 60;
    maxTime = ((maxTime ~/ 60) + 1) * 60;
    minTime = minTime < 5 * 60 ? 5 * 60 : minTime;

    final timelineDuration = maxTime - minTime;
    final hoursCount = (timelineDuration ~/ 60) + 1;
    const hourWidth = 156.0;
    final totalWidth = hoursCount * hourWidth;

    // Calculate current time in absolute minutes
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayIndex = sortedDays.indexOf(todayKey);
    int? currentAbsoluteMinutes;
    if (todayIndex >= 0) {
      final todayMinutes = (now.hour * 60) + now.minute;
      currentAbsoluteMinutes = (todayIndex * 24 * 60) + todayMinutes;
    }

    double? scrollPosition;
    if (currentAbsoluteMinutes != null &&
        currentAbsoluteMinutes >= minTime &&
        currentAbsoluteMinutes <= maxTime) {
      final currentTimePosition =
          ((currentAbsoluteMinutes - minTime) / 60.0) * hourWidth;
      final viewportWidth = MediaQuery.of(context).size.width;
      scrollPosition = currentTimePosition - (viewportWidth / 2);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            scrollPosition!
                .clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
    }

    widget.controller?.scrollToNow = scrollPosition == null
        ? null
        : () {
            if (!_scrollController.hasClients) return;
            _scrollController.animateTo(
              scrollPosition!
                  .clamp(0.0, _scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          };

    final dayBoundaries = <int, String>{};
    for (int i = 0; i < sortedDays.length; i++) {
      final dayStartMinutes = i * 24 * 60;
      dayBoundaries[dayStartMinutes] =
          AstrologyFormatters.formatDateKey(sortedDays[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: totalWidth,
              child: TimelineVisual(
                events: allEvents,
                startTime: minTime,
                endTime: maxTime,
                hourWidth: hourWidth,
                isDark: widget.isDark,
                currentTimeMinutes: currentAbsoluteMinutes,
                dayBoundaries: dayBoundaries,
                blinkController: widget.blinkController,
                onEventTap: (event) => showMuhuratEventDialog(context, event),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _processDayEvents(Map<String, dynamic> dayData) {
    final timelineEvents = <Map<String, dynamic>>[];

    Map<String, int>? extractRange(dynamic timeData) {
      if (timeData == null) return null;
      final timeMap =
          timeData is Map ? Map<String, dynamic>.from(timeData) : null;
      if (timeMap == null) return null;
      final startsAt = timeMap['starts_at'] ?? timeMap['startsAt'];
      final endsAt = timeMap['ends_at'] ?? timeMap['endsAt'];
      if (startsAt != null && endsAt != null) {
        return {
          'start': AstrologyFormatters.parseTimeToMinutes(startsAt.toString()),
          'end': AstrologyFormatters.parseTimeToMinutes(endsAt.toString()),
        };
      }
      return null;
    }

    // Process inauspicious times
    final inauspiciousTypes = [
      {'key': 'rahuKala', 'name': 'Rahu Kala', 'fallback': 'rahu_kala'},
      {'key': 'gulikaKala', 'name': 'Gulika Kala', 'fallback': 'gulika_kala'},
      {'key': 'yamaganda', 'name': 'Yamaganda', 'fallback': 'yamagandaKala'},
      {'key': 'varjyam', 'name': 'Varjyam', 'fallback': null},
    ];

    for (final type in inauspiciousTypes) {
      final timeData = dayData[type['key']] ??
          (type['fallback'] != null ? dayData[type['fallback']] : null);
      final range = extractRange(timeData);
      if (range != null) {
        timelineEvents.add({
          'name': type['name'] as String,
          'start': range['start']!,
          'end': range['end']!,
          'type': 'inauspicious',
        });
      }
    }

    // Process auspicious times
    final auspiciousTypes = [
      {'key': 'abhijit', 'name': 'Abhijit Muhurat'},
      {'key': 'amrit', 'name': 'Amrit Kaal', 'fallback': 'amritKaal'},
      {'key': 'brahmaMuhurat', 'name': 'Brahma Muhurat'},
    ];

    for (final type in auspiciousTypes) {
      final timeData = dayData[type['key']] ??
          (type['fallback'] != null ? dayData[type['fallback']] : null);
      final range = extractRange(timeData);
      if (range != null) {
        timelineEvents.add({
          'name': type['name'] as String,
          'start': range['start']!,
          'end': range['end']!,
          'type': 'auspicious',
        });
      }
    }

    return timelineEvents;
  }
}
