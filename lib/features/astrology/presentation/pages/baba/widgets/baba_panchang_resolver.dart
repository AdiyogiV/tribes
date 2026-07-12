import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/domain/astro_calendar_service.dart';

/// Result of resolving today's merged panchang/samvat data.
///
/// Single source of truth for the (otherwise duplicated) merge + nakshatra
/// precedence logic that both `build()` and the wheel builder need.
class BabaPanchang {
  /// Fully merged samvat map (todaySamvat -> insightPanchang -> globalPanchang).
  /// Empty when no source carried data.
  final Map<String, dynamic> mergedSamvat;

  /// Resolved nakshatra name for today, or null if every source missed.
  final String? todayNakshatra;

  const BabaPanchang(this.mergedSamvat, this.todayNakshatra);

  /// Convenience: the merged map, or null when empty. Mirrors the old
  /// `nakshatraSamvat = mergedSamvat.isNotEmpty ? mergedSamvat : null`.
  Map<String, dynamic>? get nakshatraSamvat =>
      mergedSamvat.isNotEmpty ? mergedSamvat : null;
}

/// Pure resolver for the baba dashboard's merged panchang + today's
/// nakshatra. Extracted to kill the verbatim duplication that previously
/// lived in both `BabaCosmicContent.build` and `_buildWheelWidget`.
class BabaPanchangResolver {
  const BabaPanchangResolver._();

  /// Merge the panchang sources by priority (richest first) and resolve
  /// today's nakshatra through the full precedence chain:
  ///   1. insight panchang nakshatra
  ///   2. global (today) panchang nakshatra
  ///   3. any nakshatra-shaped key in the merged samvat
  ///   4. Moon-longitude derived nakshatra from the astro calendar
  ///      (works for all users, no auth required)
  static BabaPanchang resolve({
    required DailyInsight? insight,
    required SkyPositionsService skyService,
    required AstroCalendarService? calendarService,
  }) {
    final todayPanchang = skyService.getTodayPanchang();

    // Merge: todaySamvat (richest tithi data) -> insightPanchang -> global.
    final todaySamvatRaw = insight?.astrologicalData?['todaySamvat'];
    final todaySamvatMap = todaySamvatRaw is Map
        ? Map<String, dynamic>.from(todaySamvatRaw)
        : null;
    final insightPanchangRaw = insight?.astrologicalData?['panchang'];
    final insightPanchangMap = insightPanchangRaw is Map
        ? Map<String, dynamic>.from(insightPanchangRaw)
        : null;

    final mergedSamvat = <String, dynamic>{};
    if (todaySamvatMap != null) mergedSamvat.addAll(todaySamvatMap);
    if (insightPanchangMap != null) {
      insightPanchangMap.forEach((k, v) {
        if (v != null) mergedSamvat[k] = v;
      });
    }
    if (todayPanchang != null) {
      todayPanchang.forEach((k, v) {
        if (v != null) mergedSamvat[k] = v;
      });
    }

    // Resolve nakshatra through the full precedence chain.
    String? todayNakshatra;
    final panchangRaw = insight?.astrologicalData?['panchang'];
    if (panchangRaw is Map) {
      todayNakshatra = extractNakshatraName(panchangRaw['nakshatra']);
    }
    if (todayNakshatra == null || todayNakshatra.isEmpty) {
      if (todayPanchang != null) {
        todayNakshatra = extractNakshatraName(todayPanchang['nakshatra']);
      }
    }
    if (todayNakshatra == null || todayNakshatra.isEmpty) {
      for (final key in const ['nakshatra', 'nakshatra_name', 'moonNakshatra']) {
        final extracted = extractNakshatraName(mergedSamvat[key]);
        if (extracted != null && extracted.isNotEmpty) {
          todayNakshatra = extracted;
          break;
        }
      }
    }
    if (todayNakshatra == null || todayNakshatra.isEmpty) {
      todayNakshatra = calendarService?.getDay(DateTime.now())?.nakshatraName;
    }

    return BabaPanchang(mergedSamvat, todayNakshatra);
  }

  /// Extract a nakshatra name from panchang data which may be a plain
  /// String or a Map with a 'name'/'nakshatra' key.
  static String? extractNakshatraName(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      return value['name']?.toString() ??
          value['nakshatra']?.toString() ??
          value.values.firstOrNull?.toString();
    }
    final s = value.toString();
    return s.isNotEmpty ? s : null;
  }
}
