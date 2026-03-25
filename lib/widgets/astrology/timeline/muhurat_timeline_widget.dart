import 'package:flutter/material.dart';
import 'package:aurogram/utils/astrology/astrology_formatters.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Muhurat timeline visualization widget showing auspicious/inauspicious times
/// Accepts global muhurat data directly (not via AstrologyProfile)
/// Now manages its own animation controller for the blinking current time indicator
class MuhuratTimelineWidget extends StatefulWidget {
  final Map<String, dynamic> muhurat;

  const MuhuratTimelineWidget({
    super.key,
    required this.muhurat,
  });

  @override
  State<MuhuratTimelineWidget> createState() => _MuhuratTimelineWidgetState();
}

class _MuhuratTimelineWidgetState extends State<MuhuratTimelineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  final _timelineController = _TimelineController();

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.muhurat.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with same padding as other cards (16 all sides, 12 bottom gap)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time Guidance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _timelineController.scrollToNow?.call(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showMuhuratInfoDialog(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Timeline content - edge to edge (no horizontal padding)
          _TimelineContent(
            muhurat: widget.muhurat,
            isDark: isDark,
            blinkController: _blinkController,
            controller: _timelineController,
          ),
          // Bottom padding to match top (16px)
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TimelineController {
  VoidCallback? scrollToNow;
}

void _showMuhuratInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('What is Muhurat?'),
      content: const Text(
        'Muhurat highlights favorable and less favorable time windows '
        'throughout the day. It is a simple guide to help you pick better '
        'moments for important actions, while avoiding periods traditionally '
        'seen as inauspicious.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

void _showMuhuratEventDialog(
  BuildContext context,
  Map<String, dynamic> event,
) {
  final name = (event['name'] ?? 'Muhurat') as String;
  final description = _getMuhuratDescription(name);

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(name),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _getMuhuratDescription(String name) {
  final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  const descriptions = {
    'rahukala':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'rahukaal':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'rahukalam':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'rahukaalam':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'gulikakala':
        'A challenging period linked to Gulika. Often avoided for travel, '
            'financial commitments, and starting new ventures. Better for '
            'maintenance work or closing small pending items.',
    'gulikakaal':
        'A challenging period linked to Gulika. Often avoided for travel, '
            'financial commitments, and starting new ventures. Better for '
            'maintenance work or closing small pending items.',
    'gulikakalam':
        'A challenging period linked to Gulika. Often avoided for travel, '
            'financial commitments, and starting new ventures. Better for '
            'maintenance work or closing small pending items.',
    'yamaganda':
        'A period associated with Yama, generally considered unfavorable for '
            'initiating important tasks. Prefer planning, research, or routine '
            'follow-ups instead of launches.',
    'yamagandam':
        'A period associated with Yama, generally considered unfavorable for '
            'initiating important tasks. Prefer planning, research, or routine '
            'follow-ups instead of launches.',
    'varjyam':
        'A brief inauspicious interval. Traditionally avoided for key actions '
            'like proposals, meetings with high stakes, or new starts. Use it for '
            'pause, reflection, or light tasks.',
    'varjya':
        'A brief inauspicious interval. Traditionally avoided for key actions '
            'like proposals, meetings with high stakes, or new starts. Use it for '
            'pause, reflection, or light tasks.',
    'abhijitmuhurat':
        'An auspicious window favored for fresh starts, interviews, and '
            'decisions when other timings are unclear. Good for initiating '
            'projects or important conversations.',
    'abhijitmuhurta':
        'An auspicious window favored for fresh starts, interviews, and '
            'decisions when other timings are unclear. Good for initiating '
            'projects or important conversations.',
    'amritkaal':
        'A highly favorable period for positive outcomes. Ideal for signing '
            'agreements, launching initiatives, or important personal milestones.',
    'amritkal':
        'A highly favorable period for positive outcomes. Ideal for signing '
            'agreements, launching initiatives, or important personal milestones.',
    'amritkalam':
        'A highly favorable period for positive outcomes. Ideal for signing '
            'agreements, launching initiatives, or important personal milestones.',
    'brahmamuhurat':
        'The pre-dawn window for clarity and focus. Traditionally best for '
            'meditation, study, deep work, or setting intentions for the day.',
    'brahmamuhurta':
        'The pre-dawn window for clarity and focus. Traditionally best for '
            'meditation, study, deep work, or setting intentions for the day.',
    'durmuhurat':
        'An inauspicious period often avoided for new starts, travel, or '
            'signing commitments. Favor routine work or rest instead.',
    'durmuhurta':
        'An inauspicious period often avoided for new starts, travel, or '
            'signing commitments. Favor routine work or rest instead.',
  };

  return descriptions[normalized] ??
      'This muhurat window is part of the traditional timing system. '
          'If possible, schedule major actions in favorable periods and keep '
          'this time for neutral or low-stakes tasks.';
}

class _TimelineContent extends StatelessWidget {
  final Map<String, dynamic> muhurat;
  final bool isDark;
  final AnimationController? blinkController;
  final _TimelineController? controller;

  const _TimelineContent({
    required this.muhurat,
    required this.isDark,
    this.blinkController,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Use unified timeline (pre-processed by backend)
    if (muhurat['unifiedTimeline'] != null) {
      try {
        final unifiedData = _convertToStringDynamic(muhurat['unifiedTimeline']);
        if (unifiedData != null &&
            unifiedData['events'] != null &&
            (unifiedData['events'] as List).isNotEmpty) {
          return _UnifiedTimeline(
            unifiedData: unifiedData,
            isDark: isDark,
            blinkController: blinkController,
            controller: controller,
          );
        }
      } catch (e) {
        AppLogger.e('Failed to parse unified timeline', error: e);
      }
    }

    // Fallback: process days data if unified timeline missing
    final daysData = _extractDaysData();
    if (daysData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Timeline data unavailable'),
      );
    }
    return _MultiDayTimeline(
      daysData: daysData,
      isDark: isDark,
      blinkController: blinkController,
      controller: controller,
    );
  }

  /// Safely convert any map to Map<String, dynamic>
  Map<String, dynamic>? _convertToStringDynamic(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(
            key.toString(),
            value is Map ? _convertToStringDynamic(value) : value,
          ));
    }
    return null;
  }

  Map<String, Map<String, dynamic>> _extractDaysData() {
    final daysData = <String, Map<String, dynamic>>{};
    if (muhurat['days'] != null && muhurat['days'] is Map) {
      final days = muhurat['days'] as Map;
      for (final entry in days.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          daysData[key] = value.map((k, v) => MapEntry(k.toString(), v));
        }
      }
    }
    return daysData;
  }
}

class _UnifiedTimeline extends StatefulWidget {
  final Map<String, dynamic> unifiedData;
  final bool isDark;
  final AnimationController? blinkController;
  final _TimelineController? controller;

  const _UnifiedTimeline({
    required this.unifiedData,
    required this.isDark,
    this.blinkController,
    this.controller,
  });

  @override
  State<_UnifiedTimeline> createState() => _UnifiedTimelineState();
}

class _UnifiedTimelineState extends State<_UnifiedTimeline> {
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
              child: _TimelineVisual(
                events: processedEvents,
                startTime: startTime,
                endTime: endTime,
                hourWidth: hourWidth,
                isDark: widget.isDark,
                currentTimeMinutes: currentAbsoluteMinutes,
                dayBoundaries: dayBoundaries,
                blinkController: widget.blinkController,
                onEventTap: (event) => _showMuhuratEventDialog(context, event),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MultiDayTimeline extends StatefulWidget {
  final Map<String, Map<String, dynamic>> daysData;
  final bool isDark;
  final AnimationController? blinkController;
  final _TimelineController? controller;

  const _MultiDayTimeline({
    required this.daysData,
    required this.isDark,
    this.blinkController,
    this.controller,
  });

  @override
  State<_MultiDayTimeline> createState() => _MultiDayTimelineState();
}

class _MultiDayTimelineState extends State<_MultiDayTimeline> {
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
        final startMinutes = event['start'] as int;
        final endMinutes = event['end'] as int;

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
    const hourWidth = 120.0;
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
              child: _TimelineVisual(
                events: allEvents,
                startTime: minTime,
                endTime: maxTime,
                hourWidth: hourWidth,
                isDark: widget.isDark,
                currentTimeMinutes: currentAbsoluteMinutes,
                dayBoundaries: dayBoundaries,
                blinkController: widget.blinkController,
                onEventTap: (event) => _showMuhuratEventDialog(context, event),
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

class _TimelineVisual extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final int startTime;
  final int endTime;
  final double hourWidth;
  final bool isDark;
  final int? currentTimeMinutes;
  final Map<int, String>? dayBoundaries;
  final AnimationController? blinkController;
  final void Function(Map<String, dynamic> event)? onEventTap;

  const _TimelineVisual({
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
                                    (event['color'] as Color).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
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
        const SizedBox(height: 3),
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
                      color: brownColor.withOpacity(0.6),
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
                            color: (event['color'] as Color).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
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
                            color: Colors.blue.shade600.withOpacity(0.6),
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
        const SizedBox(height: 3),
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
                                    (event['color'] as Color).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
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
