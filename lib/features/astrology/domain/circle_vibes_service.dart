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

  const CircleVibe({
    required this.uid,
    required this.name,
    this.photo,
    required this.vibe,
    this.publicNote,
  });

  factory CircleVibe.fromMap(Map<String, dynamic> m) => CircleVibe(
        uid: m['uid']?.toString() ?? '',
        name: m['name']?.toString() ?? 'Friend',
        photo: m['photo']?.toString(),
        vibe: m['vibe']?.toString() ?? '',
        publicNote: m['publicNote']?.toString(),
      );

  bool get isValid => uid.isNotEmpty && vibe.isNotEmpty;
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
