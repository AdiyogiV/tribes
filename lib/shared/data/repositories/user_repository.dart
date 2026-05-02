import 'dart:async' show Timer, TimeoutException;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Repository for user data access.
///
/// Provides a centralized, cached interface for user lookups with:
/// - LRU eviction (max 500 entries) to cap memory growth
/// - 5-minute TTL with active cleanup every 2 minutes
/// - Request deduplication for concurrent fetches of the same uid
///
/// Presentation layer should use this instead of directly accessing
/// `FirebaseFirestore.instance.collection('users')`.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    // Active cleanup of expired entries every 2 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) => _evictExpired());
  }

  final FirebaseFirestore _firestore;

  /// Maximum number of cached entries before LRU eviction kicks in.
  static const int _maxCacheSize = 500;

  /// TTL for cached entries (5 minutes).
  static const _ttl = Duration(minutes: 5);

  /// In-memory LRU cache for user documents (keyed by uid).
  /// Insertion order is maintained by [LinkedHashMap] (Dart's default Map).
  final Map<String, _CachedDoc> _cache = {};

  /// In-flight request deduplication.
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>> _pending =
      {};

  /// Timer for active cleanup of expired cache entries.
  late final Timer _cleanupTimer;

  /// Reference to the users collection.
  CollectionReference<Map<String, dynamic>> get collection =>
      _firestore.collection('users');

  // ── Single-document reads ─────────────────────────────────────────

  /// Fetch a user document by [uid], with caching + deduplication.
  ///
  /// Returns the [DocumentSnapshot] so callers can access any field.
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) async {
    // 1. Cache hit — also refreshes LRU position
    final cached = _cache[uid];
    if (cached != null && !cached.isExpired) {
      _touchLru(uid, cached);
      return cached.doc;
    }

    // 2. Deduplicate in-flight requests
    if (_pending.containsKey(uid)) return _pending[uid]!;

    // 3. Fetch
    final future = _fetchUser(uid);
    _pending[uid] = future;

    try {
      return await future;
    } finally {
      _pending.remove(uid);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUser(String uid) async {
    try {
      final doc = await collection.doc(uid).get();
      _putCache(uid, doc);
      return doc;
    } catch (e) {
      AppLogger.w('UserRepository: error fetching user',
          category: LogCategory.general,
          data: {'uid': uid, 'error': e.toString()});
      rethrow;
    }
  }

  // ── Convenience getters ───────────────────────────────────────────

  /// Returns the user's display name (checks multiple field names).
  Future<String> getDisplayName(String uid) async {
    final doc = await getUser(uid);
    final data = doc.data();
    if (data == null) return 'User';
    return (data['displayName'] as String?) ??
        (data['name'] as String?) ??
        'User';
  }

  /// Returns the user's photo URL.
  Future<String?> getPhotoUrl(String uid) async {
    final doc = await getUser(uid);
    return doc.data()?['displayPicture'] as String?;
  }

  /// Returns the raw data map for a user, or null if not found.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await getUser(uid);
    return doc.data();
  }

  // ── Streams ────────────────────────────────────────────────────────

  /// Stream a user document for real-time updates (e.g., online status).
  ///
  /// Emits null snapshot if Firestore never delivers within [timeout]
  /// (e.g. offline with empty cache, App Check failure). Callers should
  /// handle null as "data unavailable" and show cached/fallback UI.
  Stream<DocumentSnapshot<Map<String, dynamic>>?> userStream(
    String uid, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return collection.doc(uid).snapshots().timeout(
      timeout,
      onTimeout: (sink) {
        AppLogger.w('userStream($uid) timed out after ${timeout.inSeconds}s',
            category: LogCategory.general);
        sink.addError(TimeoutException('userStream timed out', timeout));
      },
    );
  }

  // ── Batch reads ────────────────────────────────────────────────────

  /// Fetch multiple users in parallel with deduplication.
  ///
  /// Individual failures are logged and skipped — the returned map
  /// contains only the uids that were successfully fetched.
  Future<Map<String, DocumentSnapshot<Map<String, dynamic>>>> getUsers(
      List<String> uids) async {
    final unique = uids.toSet().where((u) => u.isNotEmpty).toList();
    final results = await Future.wait(
      unique.map((uid) => getUser(uid).then<DocumentSnapshot<Map<String, dynamic>>?>(
        (doc) => doc,
        onError: (e) {
          AppLogger.w('UserRepository: batch getUser failed for $uid',
              category: LogCategory.general, data: {'error': e.toString()});
          return null;
        },
      )),
    );

    final map = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (var i = 0; i < unique.length; i++) {
      final doc = results[i];
      if (doc != null) map[unique[i]] = doc;
    }
    return map;
  }

  // ── Search ─────────────────────────────────────────────────────────

  /// Search users by display name prefix (case-insensitive via searchName).
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    final lower = query.toLowerCase();
    final snapshot = await collection
        .where('searchName', isGreaterThanOrEqualTo: lower)
        .where('searchName', isLessThanOrEqualTo: '$lower\uf8ff')
        .limit(limit)
        .get();
    return snapshot.docs;
  }

  // ── Writes ─────────────────────────────────────────────────────────

  /// Update fields on a user document. Invalidates cache.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await collection.doc(uid).update(data);
    _cache.remove(uid); // Invalidate
  }

  // ── Cache management ───────────────────────────────────────────────

  /// Clear all cached user data.
  void clearCache() => _cache.clear();

  /// Invalidate a specific user's cache entry.
  void invalidate(String uid) => _cache.remove(uid);

  /// Cancel the cleanup timer. Call this if the repository is ever disposed.
  void dispose() {
    _cleanupTimer.cancel();
  }

  // ── Internal cache helpers ─────────────────────────────────────────

  /// Insert into cache, enforcing max size via LRU eviction.
  void _putCache(String uid, DocumentSnapshot<Map<String, dynamic>> doc) {
    // Remove first so re-insertion moves to end (most-recently-used)
    _cache.remove(uid);
    _cache[uid] = _CachedDoc(doc, DateTime.now());

    // Evict oldest entries (front of map) if over capacity
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Move an existing entry to the end (most-recently-used position).
  void _touchLru(String uid, _CachedDoc entry) {
    _cache.remove(uid);
    _cache[uid] = entry;
  }

  /// Remove all expired entries from the cache.
  void _evictExpired() {
    final expired = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    for (final uid in expired) {
      _cache.remove(uid);
    }
  }
}

/// Internal cache entry with TTL.
class _CachedDoc {
  _CachedDoc(this.doc, this.fetchedAt);
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final DateTime fetchedAt;

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > UserRepository._ttl;
}
