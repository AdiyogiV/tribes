import 'package:aurogram/features/astrology/domain/astro_calendar_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';

/// Today's merged panchang/samvat data for the dashboard and wheel.
class ResolvedPanchang {
  final Map<String, dynamic> mergedSamvat;
  final String? todayNakshatra;

  const ResolvedPanchang(this.mergedSamvat, this.todayNakshatra);

  Map<String, dynamic>? get nakshatraSamvat =>
      mergedSamvat.isNotEmpty ? mergedSamvat : null;
}

/// Keeps global sky/calendar data as the single panchang source. The old daily
/// insight adapter no longer contributes data to this calculation.
class PanchangResolver {
  const PanchangResolver._();

  static ResolvedPanchang resolve({
    required SkyPositionsService skyService,
    required AstroCalendarService? calendarService,
  }) {
    final todayPanchang = skyService.getTodayPanchang();
    final mergedSamvat = <String, dynamic>{};

    if (todayPanchang != null) {
      todayPanchang.forEach((key, value) {
        if (value != null) mergedSamvat[key] = value;
      });
    }

    String? todayNakshatra;
    if (todayPanchang != null) {
      todayNakshatra = extractNakshatraName(todayPanchang['nakshatra']);
    }
    if (todayNakshatra == null || todayNakshatra.isEmpty) {
      for (final key in const [
        'nakshatra',
        'nakshatra_name',
        'moonNakshatra'
      ]) {
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

    return ResolvedPanchang(mergedSamvat, todayNakshatra);
  }

  static String? extractNakshatraName(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      return value['name']?.toString() ??
          value['nakshatra']?.toString() ??
          value.values.firstOrNull?.toString();
    }
    final text = value.toString();
    return text.isNotEmpty ? text : null;
  }
}
