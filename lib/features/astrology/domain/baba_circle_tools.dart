import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';
import 'package:aurogram/features/astrology/domain/compatibility_service.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Aurobhatt's window on the user's CIRCLE — the same Co-Star-style social layer
/// the dashboard strip shows. Two read-only tools, backed by the SAME
/// [CircleVibesService] the UI uses, so what Aurobhatt says and what the card
/// shows can never contradict:
///
///   * [getCircleToday]    — everyone's vibe word + today's connection score.
///   * [getConnectionWith] — the full transit "cosmic weather" between the user
///                           and one named friend (+ that friend's own energy,
///                           and the permanent Cosmic Match as a baseline).
///
/// Privacy is already enforced server-side: only derived numbers/phrases exist
/// on the client (a friend's private reading never crosses the wire).
class BabaCircleTools {
  BabaCircleTools._();

  static const String getCircleToday = 'getCircleToday';
  static const String getConnectionWith = 'getConnectionWith';

  static List<BabaTool> declarations() => [
        BabaTool(
          name: getCircleToday,
          description:
              "Get the user's CIRCLE for today: each mutual-follow friend's "
              'one-word vibe and how in-sync the two of them are RIGHT NOW '
              "(a 0-100 'together' score + label like In Flow / Offset). Use "
              'for "how\'s my circle / my friends today?", "who\'s having a '
              'good day?", "who should I reach out to?", or to notice who the '
              'user is most in sync with today. Read-only.',
          parameters: const {'type': 'object', 'properties': {}},
          appendsWorldState: false,
          defaultHandler: (_) async => _circleToday(),
        ),
        BabaTool(
          name: getConnectionWith,
          description:
              'Get the transit "cosmic weather for the two of you today" with '
              'ONE named friend: a 0-100 connection score + label, the '
              'classical reasons it is good or tense between you (shared and '
              'bridging transits to each other\'s Moon/Venus/7th/self), that '
              "friend's OWN energy today, and your permanent Cosmic Match as a "
              'baseline. Use for "how are <name> and I doing today?", "is today '
              'a good day to call <name>?", "why do <name> and I feel off '
              'today?". Read-only.',
          parameters: const {
            'type': 'object',
            'properties': {
              'friendName': {
                'type': 'string',
                'description':
                    "The friend's name (or part of it) as the user said it.",
              },
            },
            'required': ['friendName'],
          },
          appendsWorldState: false,
          defaultHandler: (args) async =>
              _connectionWith(args['friendName']?.toString() ?? ''),
        ),
      ];

  static Future<Map<String, dynamic>> _circleToday() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'ok': true, 'hasCircle': false, 'hint': 'User not signed in.'};
    }
    final vibes = await CircleVibesService().fetchCircleVibes();
    if (vibes.isEmpty) {
      return {
        'ok': true,
        'hasCircle': false,
        'hint':
            'No circle vibes yet — needs mutual-follow friends who have their '
            'forecast + a public vibe for today.',
      };
    }

    final friends = vibes
        .map((v) => {
              'name': v.name,
              'vibe': v.vibe,
              if (v.together != null) 'togetherScore': v.together!.score,
              if (v.together != null) 'togetherLabel': v.together!.label,
            })
        .toList();

    // Surface the most in-sync friend today for an easy conversational hook.
    final withScores =
        vibes.where((v) => v.together != null).toList()
          ..sort((a, b) => b.together!.score.compareTo(a.together!.score));

    final out = <String, dynamic>{
      'ok': true,
      'hasCircle': true,
      'friends': friends,
    };
    if (withScores.isNotEmpty) {
      out['mostInSync'] = {
        'name': withScores.first.name,
        'score': withScores.first.together!.score,
        'label': withScores.first.together!.label,
      };
    }
    AppLogger.i('[circle] getCircleToday tool', category: LogCategory.voice,
        data: {'friends': friends.length});
    return out;
  }

  static Future<Map<String, dynamic>> _connectionWith(String query) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'ok': true, 'found': false, 'hint': 'User not signed in.'};
    }
    final q = query.trim().toLowerCase();
    final vibes = await CircleVibesService().fetchCircleVibes();
    if (vibes.isEmpty) {
      return {'ok': true, 'found': false, 'hint': 'No circle vibes today.'};
    }

    CircleVibe? match;
    if (q.isNotEmpty) {
      for (final v in vibes) {
        final n = v.name.toLowerCase();
        if (n == q || n.contains(q) || q.contains(n)) {
          match = v;
          break;
        }
      }
    }
    if (match == null) {
      return {
        'ok': true,
        'found': false,
        'hint': 'No circle friend matched "$query".',
        'availableNames': vibes.map((v) => v.name).toList(),
      };
    }

    final v = match;
    final out = <String, dynamic>{
      'ok': true,
      'found': true,
      'name': v.name,
      'theirVibe': v.vibe,
    };

    // The bond today (connection-only signals — the "between you" story).
    final t = v.together;
    if (t != null) {
      out['together'] = {
        'score': t.score,
        'label': t.label,
        'connection': t.connection.map((r) => r.phrase(v.name)).toList(),
      };
    }

    // The friend's OWN transit weather today (their energy, not the bond).
    if (v.energy.isNotEmpty) {
      out['theirEnergy'] = v.energy.map((e) => e.phrase()).toList();
    }

    // Permanent Cosmic Match as a baseline ("your usual").
    try {
      final compat = await CompatibilityService().getFullCompatibility(v.uid);
      final cm = compat?.cosmicMatch;
      if (cm != null) {
        out['cosmicMatchBaseline'] = {'score': cm.score, 'label': cm.label};
      }
    } catch (_) {
      // Non-fatal — the daily bond stands on its own.
    }

    AppLogger.i('[circle] getConnectionWith tool',
        category: LogCategory.voice,
        data: {'name': v.name, 'togetherScore': t?.score});
    return out;
  }
}
