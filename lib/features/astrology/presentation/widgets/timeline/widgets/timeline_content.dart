import 'package:flutter/material.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'multi_day_timeline.dart';
import 'timeline_controller.dart';
import 'unified_timeline.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Decides which timeline variant to render based on the incoming data shape.
class TimelineContent extends StatelessWidget {
  final Map<String, dynamic> muhurat;
  final bool isDark;
  final AnimationController? blinkController;
  final TimelineController? controller;

  const TimelineContent({
    super.key,
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
          return UnifiedTimeline(
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
        padding: EdgeInsets.all(AppDimensions.paddingLg),
        child: Text('Timeline data unavailable'),
      );
    }
    return MultiDayTimeline(
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
