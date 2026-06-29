import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_formatters.dart';

import 'muhurat_descriptions.dart';
import 'timeline_controller.dart';
import 'timeline_visual.dart';

/// Renders the pre-processed unified timeline sent by the backend.
class UnifiedTimeline extends StatefulWidget {
  final Map<String, dynamic> unifiedData;
  final bool isDark;
  final AnimationController? blinkController;
  final TimelineController? controller;

  const UnifiedTimeline({
    super.key,
    required this.unifiedData,
    required this.isDark,
    this.blinkController,
    this.controller,
  });

  @override
  State<UnifiedTimeline> createState() => _UnifiedTimelineState();
}

class _UnifiedTimelineState extends State<UnifiedTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.unifiedData['events'] as List<dynamic>? ?? [];
    final rawStartTime = (widget.unifiedData['startTime'] as num?)?.toInt() ?? 0;
    final rawEndTime = (widget.unifiedData['endTime'] as num?)?.toInt() ?? 0;
    final dateKeys = widget.unifiedData['dateKeys'] as List<dynamic>? ?? [];

    if (events.isEmpty) return const SizedBox.shrink();

    const hourWidth = 156.0;

    // Convert events to frontend format with colors
    final processedEvents = events.map<Map<String, dynamic>>((e) {
      final event = Map<String, dynamic>.from(e as Map);
      final isInauspicious = event['type'] == 'inauspicious';
      return {
        'name': event['name'],
        'start': (event['start'] as num).toInt(),
        'end': (event['end'] as num).toInt(),
        'type': event['type'],
        'color': isInauspicious
            ? (widget.isDark ? Colors.red.shade300 : Colors.red.shade600)
            : (widget.isDark ? Colors.green.shade300 : Colors.green.shade700),
        'dateKey': event['dateKey'],
      };
    }).toList();

    // Position of "now" in absolute minutes from the timeline's first date —
    // but ONLY when today actually falls within the timeline's date range.
    // For any other selected date there's no live "now" on this canvas, so we
    // leave it null (no blue dot, no auto-scroll, no canvas extension).
    final now = DateTime.now();
    final firstDateKey = dateKeys.isNotEmpty ? dateKeys[0] as String : '';
    int? currentAbsoluteMinutes;
    if (firstDateKey.isNotEmpty) {
      try {
        final parts = firstDateKey.split('-');
        if (parts.length == 3) {
          // Midnight-to-midnight offset — exact whole days, no truncation traps.
          final refDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final today = DateTime(now.year, now.month, now.day);
          final dayOffset = today.difference(refDate).inDays;
          if (dayOffset >= 0 && dayOffset < dateKeys.length) {
            currentAbsoluteMinutes =
                (dayOffset * 24 * 60) + (now.hour * 60) + now.minute;
          }
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Extend the timeline canvas so it ALWAYS includes "now" (floored/ceiled to
    // the hour so hour labels stay clean). Only applies when today is in range
    // (currentAbsoluteMinutes != null); other dates keep their natural bounds
    // so the muhurat windows render in place.
    var startTime = rawStartTime;
    var endTime = rawEndTime;
    final cam = currentAbsoluteMinutes;
    if (cam != null) {
      final nowFloorHour = (cam ~/ 60) * 60;
      final nowCeilHour = ((cam + 59) ~/ 60) * 60;
      if (nowFloorHour < startTime) startTime = nowFloorHour;
      if (nowCeilHour > endTime) endTime = nowCeilHour;
    }

    final timelineDuration = endTime - startTime;
    final hoursCount = (timelineDuration ~/ 60) + 1;
    final totalWidth = hoursCount * hourWidth;

    // X-position of the live "now" dot within the timeline (null when today
    // isn't inside the visible range — e.g. a past/future date is selected).
    final double? currentTimePosition = (currentAbsoluteMinutes != null &&
            currentAbsoluteMinutes >= startTime &&
            currentAbsoluteMinutes <= endTime)
        ? ((currentAbsoluteMinutes - startTime) / 60.0) * hourWidth
        : null;

    // Calculate day boundaries for labels
    final dayBoundaries = <int, String>{};
    for (int i = 0; i < dateKeys.length; i++) {
      final dayStartMinutes = i * 24 * 60;
      dayBoundaries[dayStartMinutes] =
          AstrologyFormatters.formatDateKey(dateKeys[i] as String);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Centre the dot using the ACTUAL scroll viewport width (the card),
        // not the full screen width — otherwise "now" lands left of centre.
        final double? scrollPosition = currentTimePosition == null
            ? null
            : currentTimePosition - (constraints.maxWidth / 2);

        // Auto-scroll to centre "now" on load / rebuild.
        if (scrollPosition != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                scrollPosition
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
                  scrollPosition
                      .clamp(0.0, _scrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              };

        return SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: totalWidth,
              child: TimelineVisual(
                events: processedEvents,
                startTime: startTime,
                endTime: endTime,
                hourWidth: hourWidth,
                isDark: widget.isDark,
                currentTimeMinutes: currentAbsoluteMinutes,
                dayBoundaries: dayBoundaries,
                blinkController: widget.blinkController,
                onEventTap: (event) => showMuhuratEventDialog(context, event),
              ),
            ),
          ),
        );
      },
    );
  }
}
