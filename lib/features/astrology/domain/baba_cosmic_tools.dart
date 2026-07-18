import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/astrology/data/utils/planet_utils.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Baba's window on the SHARED sky — today's Vedic date, the prahar, muhurat,
/// the moon's phase, the current Ayurvedic dosha period, and the live gochar
/// (planetary transits). None of this needs a birth chart, so Baba can open a
/// call with something fresh and true EVERY day instead of looping on the
/// daily insight.
///
/// All data comes from already-cached singletons populated at app startup
/// (SkyPositionsService, AstroCalendarService via globalMuhurat, AyurvedaService
/// dosha clock, and the pure VedicTimeUtils). Results are kept compact and
/// pre-formatted (strings, not raw numbers) so the voice brain can narrate them
/// directly.
class BabaCosmicTools {
  BabaCosmicTools._();

  static const String getToday = 'getToday';
  static const String getTransits = 'getTransits';

  static List<BabaTool> declarations() => [
        BabaTool(
          name: getToday,
          description:
              "Get TODAY's shared sky: the Vedic date (tithi, paksha, "
              'nakshatra, lunar month, samvat year), the weekday, the current '
              'prahar (Vedic watch of the day), the moon phase, the key muhurat '
              'windows (auspicious ones like Abhijit/Brahma Muhurat and what to '
              'avoid like Rahu Kala), and the Ayurvedic dosha ruling this time '
              'of day with its guidance. No birth chart needed. Call this to '
              'talk about the day, the timing, an auspicious window, or what the '
              'body wants right now.',
          parameters: const {'type': 'object', 'properties': {}},
          appendsWorldState: false,
          defaultHandler: (_) async => _today(),
        ),
        BabaTool(
          name: getTransits,
          description:
              'Get the current gochar (live planetary transits): which sign each '
              'graha is in right now, which are retrograde, and the next few '
              'upcoming sign-changes and retrogrades. If the user has a chart, '
              'also flags any planet now transiting their moon sign. Call this to '
              'talk about what the planets are doing now or an upcoming shift.',
          parameters: const {'type': 'object', 'properties': {}},
          appendsWorldState: false,
          defaultHandler: (_) async => _transits(),
        ),
      ];

  // ---------------------------------------------------------------------------
  // getToday
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _today() async {
    final now = DateTime.now();
    final sky = SkyPositionsService();
    final panchang = sky.getTodayPanchang();

    final dosha = AyurvedaService().getCurrentDoshaPeriod();

    final out = <String, dynamic>{
      'ok': true,
      'weekday': _weekdayName(now.weekday),
      'prahar': VedicTimeUtils.getVedicPrahar(now),
      'moonPhase': _moonPhaseLabel(VedicTimeUtils.getMoonPhaseFraction(now)),
      'doshaNow': {
        'dosha': dosha['dosha'],
        'period': dosha['period'],
        'guidance': dosha['guidance'],
      },
    };

    final vedicDate = VedicTimeUtils.buildFullVedicDate(panchang);
    if (vedicDate != null) out['vedicDate'] = vedicDate;
    final samvat = VedicTimeUtils.buildSamvatYearNameOnly(panchang) ??
        VedicTimeUtils.buildSamvatYear(panchang);
    if (samvat != null) out['samvat'] = samvat;
    final nakshatra = _readNakshatra(panchang);
    if (nakshatra != null) out['nakshatra'] = nakshatra;
    if (vedicDate == null && nakshatra == null) {
      out['note'] =
          'The Vedic calendar is still loading; the prahar and dosha above are '
          'from the clock and are accurate.';
    }

    final muhurat = _muhurat(sky.globalMuhurat);
    if (muhurat['auspicious'].isNotEmpty || muhurat['avoid'].isNotEmpty) {
      out['muhurat'] = muhurat;
    }

    return out;
  }

  /// Pull a compact, readable muhurat summary from the global muhurat map's
  /// unifiedTimeline events ({name, start, end, type} with minutes-from-midnight).
  static Map<String, dynamic> _muhurat(Map<String, dynamic>? m) {
    final auspicious = <Map<String, String>>[];
    final avoid = <Map<String, String>>[];
    final events = (m?['unifiedTimeline'] as Map<String, dynamic>?)?['events'];
    if (events is List) {
      for (final e in events) {
        if (e is! Map) continue;
        final name = e['name']?.toString();
        final start = e['start'];
        final end = e['end'];
        if (name == null || start is! int || end is! int) continue;
        final window = {
          'name': name,
          'from': _hhmm(start),
          'to': _hhmm(end % 1440),
        };
        if (e['type'] == 'auspicious') {
          auspicious.add(window);
        } else if (name == 'Rahu Kala') {
          // Keep only the most-known inauspicious window to stay concise.
          avoid.add(window);
        }
      }
    }
    return {'auspicious': auspicious, 'avoid': avoid};
  }

  // ---------------------------------------------------------------------------
  // getTransits
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _transits() async {
    final now = DateTime.now();
    final sky = SkyPositionsService();
    final positions = sky.getPositionsForDate(now);

    if (positions == null || positions.isEmpty) {
      return {
        'ok': true,
        'hasTransits': false,
        'hint': 'The live sky is still loading; try again in a moment.',
      };
    }

    // Keep the classical nine grahas, in the traditional order.
    const grahas = [
      'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter',
      'Venus', 'Saturn', 'Rahu', 'Ketu',
    ];
    final transits = <Map<String, dynamic>>[];
    final retrograde = <String>[];
    for (final planet in grahas) {
      final data = positions[planet];
      if (data is! Map) continue;
      // The raw sky-positions entry carries `longitude` + `isRetro` but NOT a
      // named `sign` (the backend stores the API's `zodiac_sign_name` under a
      // key it never reads, so it's dropped). Every other consumer — the sky
      // wheel, the calendar, the chart — derives the rashi from longitude, so
      // do the same here. Fall back to an explicit `sign` if one ever appears.
      var sign = data['sign']?.toString();
      if (sign == null || sign.isEmpty) {
        final lng = data['longitude'];
        if (lng is num) sign = PlanetUtils.deriveSign(lng);
      }
      if (sign == null || sign.isEmpty) continue;
      final isRetro = data['isRetro'] == true;
      transits.add({
        'planet': planet,
        'sign': sign,
        if (isRetro) 'retrograde': true,
      });
      if (isRetro) retrograde.add(planet);
    }

    final out = <String, dynamic>{
      'ok': true,
      'hasTransits': transits.isNotEmpty,
      'transits': transits,
      if (retrograde.isNotEmpty) 'retrograde': retrograde,
    };

    // Upcoming shifts (next few ingresses / retrogrades).
    if (sky.hasUpcomingEvents) {
      out['upcoming'] = sky.allUpcomingEvents
          .take(4)
          .map((e) => {'event': e.displayText, 'when': e.formattedDate})
          .toList(growable: false);
    }

    // Personal flourish: which graha is transiting their natal moon sign.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final profile = await AstrologyService().getProfile(uid);
      final moonSign = profile?.moonSign;
      if (moonSign != null && moonSign.isNotEmpty) {
        final onMoon = transits
            .where((t) =>
                (t['sign'] as String).toLowerCase() == moonSign.toLowerCase())
            .map((t) => t['planet'])
            .toList(growable: false);
        if (onMoon.isNotEmpty) {
          out['transitingYourMoonSign'] = {
            'moonSign': moonSign,
            'planets': onMoon,
          };
        }
      }
    }

    return out;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _weekdayName(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return names[(weekday - 1) % 7];
  }

  static String _hhmm(int minutes) {
    final m = minutes % 1440;
    final h = m ~/ 60;
    final mm = m % 60;
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  static String _moonPhaseLabel(double fraction) {
    if (fraction < 0.0625 || fraction >= 0.9375) return 'New Moon';
    if (fraction < 0.1875) return 'Waxing Crescent';
    if (fraction < 0.3125) return 'First Quarter';
    if (fraction < 0.4375) return 'Waxing Gibbous';
    if (fraction < 0.5625) return 'Full Moon';
    if (fraction < 0.6875) return 'Waning Gibbous';
    if (fraction < 0.8125) return 'Last Quarter';
    return 'Waning Crescent';
  }

  /// Nakshatra can arrive as a plain string or a nested map ({name: ...}).
  static String? _readNakshatra(Map<String, dynamic>? panchang) {
    final n = panchang?['nakshatra'];
    if (n is String && n.trim().isNotEmpty) return n.trim();
    if (n is Map) {
      final name = n['name'] ?? n['nakshatra'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
    }
    return null;
  }
}
