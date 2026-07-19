import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';

/// One friend's public vibe for today — the ≤4-word forecast heading plus the
/// bits needed to render a face. This is a read-only projection; a friend's
/// private reading never crosses the wire (see backend/functions/circle_vibes.js).
class CircleVibe {
  final String uid;
  final String name;
  final String? photo;
  final String vibe;
  final String? publicNote;

  /// Transit "cosmic weather for the two of you today" — derived server-side
  /// from BOTH natal charts vs today's sky. Null when it can't be paired.
  final TodayTogether? together;

  /// The friend's OWN transit weather today (their energy card), not the bond.
  final List<EnergyReason> energy;

  const CircleVibe({
    required this.uid,
    required this.name,
    this.photo,
    required this.vibe,
    this.publicNote,
    this.together,
    this.energy = const [],
  });

  factory CircleVibe.fromMap(Map<String, dynamic> m) => CircleVibe(
        uid: m['uid']?.toString() ?? '',
        name: m['name']?.toString() ?? 'Friend',
        photo: m['photo']?.toString(),
        vibe: m['vibe']?.toString() ?? '',
        publicNote: m['publicNote']?.toString(),
        together: m['together'] is Map
            ? TodayTogether.fromMap(Map<String, dynamic>.from(m['together']))
            : null,
        energy: (m['energy'] as List?)
                ?.whereType<Map>()
                .map((e) => EnergyReason.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );

  bool get isValid => uid.isNotEmpty && vibe.isNotEmpty;
}

/// The derived, privacy-safe transit synastry-of-the-day for a pair. Every
/// [connection] reason touches BOTH charts — it's about the bond, not one person.
class TodayTogether {
  final int score; // 0-100
  final String label; // "In Flow", "Aligned", "Steady", "Offset", "Lay Low"
  final List<TogetherReason> connection; // shared + bridge signals

  const TodayTogether({
    required this.score,
    required this.label,
    this.connection = const [],
  });

  factory TodayTogether.fromMap(Map<String, dynamic> m) => TodayTogether(
        score: (m['score'] as num?)?.round() ?? 0,
        label: m['label']?.toString() ?? '',
        connection: (m['connection'] as List?)
                ?.whereType<Map>()
                .map((e) => TogetherReason.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );

  List<TogetherReason> get favorable =>
      connection.where((r) => r.benefic).toList();
  List<TogetherReason> get unfavorable =>
      connection.where((r) => !r.benefic).toList();
}

/// One CONNECTION signal — a transiting [planet] linking the two charts.
/// [kind] is "shared" (same karaka lit in both) or "bridge" (your [karakaA] ↔
/// their [karakaB]). [benefic] = lifts vs tests.
class TogetherReason {
  final String planet;
  final String kind; // "shared" | "bridge"
  final String karaka; // shared: the common karaka
  final String karakaA; // bridge: your point
  final String karakaB; // bridge: their point
  final bool benefic;

  const TogetherReason({
    required this.planet,
    required this.kind,
    this.karaka = '',
    this.karakaA = '',
    this.karakaB = '',
    required this.benefic,
  });

  factory TogetherReason.fromMap(Map<String, dynamic> m) => TogetherReason(
        planet: m['planet']?.toString() ?? '',
        kind: m['kind']?.toString() ?? 'shared',
        karaka: m['karaka']?.toString() ?? '',
        karakaA: m['karakaA']?.toString() ?? '',
        karakaB: m['karakaB']?.toString() ?? '',
        benefic: m['benefic'] == true,
      );

  /// Warm, name-aware phrasing of the bond. [friendName] is the OTHER person.
  String phrase(String friendName) {
    if (kind == 'bridge') {
      return benefic
          ? '$planet links your $karakaA to $friendName\'s $karakaB'
          : '$planet strains your $karakaA and $friendName\'s $karakaB';
    }
    // shared
    return benefic
        ? '$planet blesses the $karaka between you'
        : '$planet tests the $karaka between you';
  }
}

/// One of the friend's OWN transit signals today (for their energy card).
class EnergyReason {
  final String planet;
  final String karaka;
  final bool benefic;

  const EnergyReason({
    required this.planet,
    required this.karaka,
    required this.benefic,
  });

  factory EnergyReason.fromMap(Map<String, dynamic> m) => EnergyReason(
        planet: m['planet']?.toString() ?? '',
        karaka: m['karaka']?.toString() ?? '',
        benefic: m['benefic'] == true,
      );

  String phrase() => benefic ? '$planet favours their $karaka' : '$planet tests their $karaka';
}

/// "Friends Today" — fetches the vibe word for each mutual-follow friend.
///
/// Thin wrapper: the client computes the mutual-follow set (following ∩
/// followers) and asks the backend for today's vibe words. The backend
/// re-validates every friend (mutual-follow + block + privacy) and only ever
/// returns the public heading — the client is not trusted to gate.
class CircleVibesService {
  CircleVibesService._();
  static final CircleVibesService _singleton = CircleVibesService._();
  factory CircleVibesService() => _singleton;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast2');
  final FollowService _follows = FollowService();

  /// How many mutual-follows to consider. The backend caps its own fan-out too.
  static const int _maxFriends = 30;

  /// Returns today's vibes for the current user's mutual-follows.
  /// Never throws — returns [] on any failure so the strip just hides itself.
  Future<List<CircleVibe>> fetchCircleVibes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];

    try {
      // Mutual follow = you follow them AND they follow you.
      final results = await Future.wait([
        _follows.getFollowing(uid, limit: 100),
        _follows.getFollowers(uid, limit: 100),
      ]);
      final following = results[0].toSet();
      final followers = results[1].toSet();
      final mutual =
          following.intersection(followers).take(_maxFriends).toList();
      AppLogger.i(
          'CircleVibes: following=${following.length} '
          'followers=${followers.length} mutual=${mutual.length}',
          category: LogCategory.general);
      if (mutual.isEmpty) return const [];

      final res = await _functions
          .httpsCallable('astroGateway')
          .call({'method': 'getCircleVibes', 'friendIds': mutual});

      final data = res.data;
      if (data is! Map || data['success'] != true) {
        AppLogger.w('CircleVibes: backend returned non-success: $data',
            category: LogCategory.general);
        return const [];
      }

      final rawVibes = (data['vibes'] as List?) ?? const [];
      final vibes = rawVibes
          .whereType<Map>()
          .map((m) => CircleVibe.fromMap(Map<String, dynamic>.from(m)))
          .where((v) => v.isValid)
          .toList();

      AppLogger.i(
          'CircleVibes: backend returned ${rawVibes.length} raw, '
          '${vibes.length} valid vibes',
          category: LogCategory.general);
      return vibes;
    } catch (e) {
      AppLogger.w('Circle vibes fetch failed (non-fatal)',
          category: LogCategory.general, data: {'error': e.toString()});
      return const [];
    }
  }
}
