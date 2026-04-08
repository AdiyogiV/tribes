import 'package:flutter/material.dart';
import 'package:aurogram/utils/astrology/astrology_formatters.dart';

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
    final startTime = widget.unifiedData['startTime'] as int? ?? 0;
    final endTime = widget.unifiedData['endTime'] as int? ?? 0;
    final dateKeys = widget.unifiedData['dateKeys'] as List<dynamic>? ?? [];

    if (events.isEmpty) return const SizedBox.shrink();

    const hourWidth = 120.0;
    final timelineDuration = endTime - startTime;
    final hoursCount = (timelineDuration ~/ 60) + 1;
    final totalWidth = hoursCount * hourWidth;

    // Convert events to frontend format with colors
    final processedEvents = events.map<Map<String, dynamic>>((e) {
      final event = Map<String, dynamic>.from(e as Map);
      final isInauspicious = event['type'] == 'inauspicious';
      return {
        'name': event['name'],
        'start': event['start'] as int,
        'end': event['end'] as int,
        'type': event['type'],
        'color': isInauspicious
            ? (widget.isDark ? Colors.red.shade300 : Colors.red.shade600)
            : (widget.isDark ? Colors.green.shade300 : Colors.green.shade700),
        'dateKey': event['dateKey'],
      };
    }).toList();

    // Get current time in absolute minutes from start
    final now = DateTime.now();
    final firstDateKey = dateKeys.isNotEmpty ? dateKeys[0] as String : '';
    int? currentAbsoluteMinutes;
    if (firstDateKey.isNotEmpty) {
      try {
        final parts = firstDateKey.split('-');
        if (parts.length == 3) {
          final refDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final diff = now.difference(refDate);
          currentAbsoluteMinutes =
              (diff.inDays * 24 * 60) + (now.hour * 60) + now.minute;
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Calculate scroll position for current time - CENTER the dot
    double? scrollPosition;
    if (currentAbsoluteMinutes != null &&
        currentAbsoluteMinutes >= startTime &&
        currentAbsoluteMinutes <= endTime) {
      final currentTimePosition =
          ((currentAbsoluteMinutes - startTime) / 60.0) * hourWidth;
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

    // Calculate day boundaries for labels
    final dayBoundaries = <int, String>{};
    for (int i = 0; i < dateKeys.length; i++) {
      final dayStartMinutes = i * 24 * 60;
      dayBoundaries[dayStartMinutes] =
          AstrologyFormatters.formatDateKey(dateKeys[i] as String);
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
        ),
      ],
    );
  }
}
