import 'package:aurogram/core/logging/app_logger.dart';

/// Static utility class for astronomical position calculations.
///
/// Handles interpolation of planetary positions between known dates,
/// including longitude wrapping and sign derivation.
class SkyPositionsCalculator {
  SkyPositionsCalculator._(); // Prevent instantiation

  static const List<String> _signs = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces'
  ];

  /// Get interpolated positions for a specific datetime.
  ///
  /// Interpolates between nearest available dates for smooth slider movement.
  /// Returns null if [positions] is null or empty.
  static Map<String, dynamic>? getInterpolatedPositions(
    DateTime dateTime,
    Map<String, Map<String, dynamic>>? positions,
    String Function(DateTime) formatDateKey,
  ) {
    if (positions == null || positions.isEmpty) {
      AppLogger.w(
        'Sky positions not available for interpolation',
        category: LogCategory.general,
        data: {'dateTime': dateTime.toIso8601String()},
      );
      return null;
    }

    final dateKey = formatDateKey(dateTime);

    // If we have exact date, return it directly
    if (positions.containsKey(dateKey)) {
      final exactData = positions[dateKey];
      // Log if planets seem to be missing
      if (exactData != null && exactData.length < 9) {
        AppLogger.w(
          'Exact date has incomplete planet data',
          category: LogCategory.general,
          data: {
            'date': dateKey,
            'planetCount': exactData.length,
            'planets': exactData.keys.toList()
          },
        );
      }
      return exactData;
    }

    // Find nearest dates before and after for interpolation
    final sortedDates = positions.keys.toList()..sort();
    String? beforeDate;
    String? afterDate;

    for (final d in sortedDates) {
      if (d.compareTo(dateKey) <= 0) {
        beforeDate = d;
      } else {
        afterDate = d;
        break;
      }
    }

    // If we only have one boundary, use that
    if (beforeDate == null) {
      AppLogger.w(
        'No before date found for interpolation, using after',
        category: LogCategory.general,
        data: {'targetDate': dateKey, 'afterDate': afterDate},
      );
      return positions[afterDate];
    }
    if (afterDate == null) {
      AppLogger.w(
        'No after date found for interpolation, using before',
        category: LogCategory.general,
        data: {'targetDate': dateKey, 'beforeDate': beforeDate},
      );
      return positions[beforeDate];
    }

    // Interpolate between the two dates
    final result = interpolatePositions(
      positions[beforeDate]!,
      positions[afterDate]!,
      beforeDate,
      afterDate,
      dateKey,
    );

    // Log if result seems incomplete
    if (result.length < 9) {
      AppLogger.w(
        'Interpolation produced incomplete result',
        category: LogCategory.general,
        data: {
          'targetDate': dateKey,
          'beforeDate': beforeDate,
          'afterDate': afterDate,
          'resultPlanets': result.keys.toList(),
          'beforePlanets': positions[beforeDate]?.keys.toList(),
          'afterPlanets': positions[afterDate]?.keys.toList(),
        },
      );
    }

    return result;
  }

  /// Interpolate planetary positions between two known dates.
  ///
  /// Handles longitude wrapping at the 360/0 degree boundary and
  /// derives zodiac sign from the interpolated longitude.
  static Map<String, dynamic> interpolatePositions(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    String beforeDate,
    String afterDate,
    String targetDate,
  ) {
    // Calculate interpolation factor (0 = before, 1 = after)
    final beforeDt = DateTime.parse(beforeDate);
    final afterDt = DateTime.parse(afterDate);
    final targetDt = DateTime.parse(targetDate);

    final totalDays = afterDt.difference(beforeDt).inDays;
    final targetDays = targetDt.difference(beforeDt).inDays;
    final factor = totalDays > 0 ? targetDays / totalDays : 0.0;

    final result = <String, dynamic>{};

    // Use union of all planets from both dates (not intersection)
    final allPlanets = <String>{...before.keys, ...after.keys};

    // Interpolate each planet
    for (final planet in allPlanets) {
      final beforeData = before[planet] as Map<String, dynamic>?;
      final afterData = after[planet] as Map<String, dynamic>?;

      // If planet exists in only one date, use that data directly
      if (beforeData == null && afterData != null) {
        result[planet] = Map<String, dynamic>.from(afterData);
        continue;
      }
      if (afterData == null && beforeData != null) {
        result[planet] = Map<String, dynamic>.from(beforeData);
        continue;
      }
      if (beforeData == null || afterData == null) continue;

      final beforeLng = (beforeData['longitude'] as num?)?.toDouble() ?? 0;
      final afterLng = (afterData['longitude'] as num?)?.toDouble() ?? 0;

      // Handle longitude wrapping (when crossing 360/0 degrees)
      double interpolatedLng;
      if ((afterLng - beforeLng).abs() > 180) {
        // Wrapping case
        if (afterLng > beforeLng) {
          interpolatedLng = beforeLng + (afterLng - 360 - beforeLng) * factor;
        } else {
          interpolatedLng = beforeLng + (afterLng + 360 - beforeLng) * factor;
        }
        if (interpolatedLng < 0) interpolatedLng += 360;
        if (interpolatedLng >= 360) interpolatedLng -= 360;
      } else {
        interpolatedLng = beforeLng + (afterLng - beforeLng) * factor;
      }

      // Calculate sign from longitude
      final signIndex = (interpolatedLng / 30).floor();

      result[planet] = {
        'longitude': interpolatedLng,
        'sign': _signs[signIndex % 12],
        'signDegree': interpolatedLng % 30,
        'isRetro': beforeData['isRetro'] ?? afterData['isRetro'] ?? false,
      };
    }

    return result;
  }
}
