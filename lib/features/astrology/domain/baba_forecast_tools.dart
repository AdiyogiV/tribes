import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Baba's window on the UNIFIED FORECAST — the single, coherent read-model that
/// also drives the nakshatra wheel and the daily card. So when the user asks
/// "how's my week?" / "what's today like?" / "when's a good day for X?", Baba
/// reads the SAME real, server-computed day-alignments (0-100) and the SAME
/// woven narrative the wheel shows — never a separate, contradicting story.
///
/// alignment = COMPUTED (Gochara + Ashtakavarga + Vedha + Tara/Chandra Bala +
/// Panchang). heading/narrative = the AI-narrated continuous story. storyline =
/// the evolving arc of the user's chapter. All pre-formatted for narration.
class BabaForecastTools {
  BabaForecastTools._();

  static const String getMyForecast = 'getMyForecast';

  static BabaTool declaration() => BabaTool(
        name: getMyForecast,
        description:
            "Get the user's personal forecast: today's alignment score (0-100) "
            'with its heading and short narrative, plus the standout days over '
            'the next week or two (the most supportive and the most cautious), '
            'and the ongoing storyline (the arc of their current life-chapter). '
            'This is the SAME data shown on their wheel — use it to answer "how '
            'is today / this week / the days ahead?", to suggest a good day for '
            'something, or to reference the continuous story of where they are. '
            'Needs their birth chart. Prefer this over getToday for anything '
            'personal and forward-looking.',
        parameters: const {'type': 'object', 'properties': {}},
        appendsWorldState: false,
        defaultHandler: (_) async => _fetch(),
      );

  static Future<Map<String, dynamic>> _fetch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'ok': true, 'hasForecast': false, 'hint': 'User not signed in.'};
    }

    final service = ForecastService();
    final forecast = await service.fetchForecast(uid);
    // [forecast] TEMP diagnostic — remove after device verification.
    AppLogger.i('[forecast] getMyForecast tool called', category: LogCategory.voice, data: {
      'forecastDays': forecast.length,
      'hasToday': forecast.containsKey(ForecastService.dateKey(DateTime.now())),
    });
    if (forecast.isEmpty) {
      return {
        'ok': true,
        'hasForecast': false,
        'hint':
            'No forecast yet — it needs their birth chart, and is computed '
            'shortly after. Ask them to add birth details if missing.',
      };
    }

    final today = DateTime.now();
    final todayKey = ForecastService.dateKey(today);

    // Upcoming window (today .. +13 days), sorted by date.
    final upcoming = <ForecastDay>[];
    for (var i = 0; i < 14; i++) {
      final day = forecast[ForecastService.dateKey(today.add(Duration(days: i)))];
      if (day != null && day.alignment != null) upcoming.add(day);
    }

    final out = <String, dynamic>{'ok': true, 'hasForecast': true};

    final todayDay = forecast[todayKey];
    if (todayDay != null) {
      out['today'] = {
        'date': todayDay.date,
        if (todayDay.alignment != null) 'alignment': todayDay.alignment,
        if (todayDay.heading != null) 'heading': todayDay.heading,
        if (todayDay.narrative != null) 'narrative': todayDay.narrative,
        if (todayDay.favorable.isNotEmpty) 'favorable': todayDay.favorable,
        if (todayDay.unfavorable.isNotEmpty) 'caution': todayDay.unfavorable,
      };
    }

    // The upcoming week, day-by-day, so Aurobhat can walk through it or pick a
    // specific day. Compact (heading, not full narrative) to stay prompt-light.
    final week = upcoming
        .take(8)
        .map((d) => {
              'date': d.date,
              'alignment': d.alignment,
              if (d.heading != null) 'heading': d.heading,
            })
        .toList();
    if (week.isNotEmpty) out['week'] = week;

    // Standout upcoming days (skip today itself for the highlights).
    final ahead = upcoming.where((d) => d.date != todayKey).toList();
    if (ahead.isNotEmpty) {
      ahead.sort((a, b) => (b.alignment ?? 0).compareTo(a.alignment ?? 0));
      final best = ahead.first;
      final worst = ahead.last;
      out['bestDayAhead'] = {
        'date': best.date,
        'alignment': best.alignment,
        if (best.heading != null) 'heading': best.heading,
      };
      if (worst.date != best.date) {
        out['toughestDayAhead'] = {
          'date': worst.date,
          'alignment': worst.alignment,
          if (worst.heading != null) 'heading': worst.heading,
        };
      }
    }

    // The evolving storyline arc (continuity across sessions).
    final storyline = await service.fetchStoryline(uid);
    if (storyline != null) {
      final arc = storyline['arc']?.toString();
      final chapter = storyline['currentChapter'];
      if (arc != null && arc.isNotEmpty) out['storyArc'] = arc;
      if (chapter is Map && chapter['throughline'] != null) {
        out['currentChapter'] = chapter['throughline'].toString();
      }
    }

    // [forecast] TEMP diagnostic — remove after device verification.
    AppLogger.i('[forecast] getMyForecast tool result', category: LogCategory.voice, data: {
      'keys': out.keys.toList(),
      'todayAlignment': (out['today'] as Map?)?['alignment'],
      'bestDayAhead': (out['bestDayAhead'] as Map?)?['date'],
      'hasStoryArc': out.containsKey('storyArc'),
    });
    return out;
  }
}
