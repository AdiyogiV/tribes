import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Result of a namaste operation
class NamasteResult {
  final bool success;
  final String? error;
  final int? remaining;

  /// Aura points awarded to the sender (from backend). May be 0 if backend did not award.
  final int? senderPointsAwarded;

  const NamasteResult._({
    required this.success,
    this.error,
    this.remaining,
    this.senderPointsAwarded,
  });

  factory NamasteResult.success({
    required int remaining,
    int? senderPointsAwarded,
  }) {
    return NamasteResult._(
      success: true,
      remaining: remaining,
      senderPointsAwarded: senderPointsAwarded,
    );
  }

  factory NamasteResult.fromError(String errorCode, {int? remaining}) {
    return NamasteResult._(
        success: false, error: errorCode, remaining: remaining);
  }

  factory NamasteResult.error() {
    return const NamasteResult._(success: false, error: 'ERROR');
  }

  bool get quotaExceeded => error == 'QUOTA_EXCEEDED';
  bool get alreadySentToday => error == 'ALREADY_SENT_TODAY';
  bool get blocked => error == 'BLOCKED';
  bool get selfNamaste => error == 'SELF_NAMASTE';
  bool get userNotFound => error == 'USER_NOT_FOUND';
}

/// Quota information for today's namastes
class NamasteQuota {
  final int remaining;
  final int sent;
  final List<String> recipients;

  const NamasteQuota({
    required this.remaining,
    required this.sent,
    required this.recipients,
  });

  bool get canSend => remaining > 0;

  bool hasSentTo(String userId) => recipients.contains(userId);
}

/// Service for sending namastes with rate limiting
/// All logic handled by backend Cloud Functions
class NamasteService {
  // Singleton pattern
  static final NamasteService _instance = NamasteService._internal();
  factory NamasteService() => _instance;
  NamasteService._internal();

  // Use asia-southeast2 region (matches backend global default)
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  // Local cache for quota (to avoid repeated calls)
  NamasteQuota? _cachedQuota;
  DateTime? _quotaCacheTime;
  static const Duration _quotaCacheDuration = Duration(minutes: 5);

  /// Send namaste to a user
  ///
  /// [toUid] - User ID to send namaste to
  /// [dmId] - DM conversation ID (optional, sends chat message if provided)
  ///
  /// Returns [NamasteResult] with success status and remaining count
  Future<NamasteResult> sendNamaste(String toUid, {String? dmId}) async {
    try {
      AppLogger.d('🙏 Sending namaste to $toUid',
          category: LogCategory.network);

      final callable = _functions.httpsCallable('socialGateway');
      final result = await callable.call({
        'method': 'sendNamaste',
        'recipientUid': toUid,
        'sendChatMessage': dmId != null,
        'dmId': dmId,
      });

      final data = result.data as Map<String, dynamic>;

      // Invalidate cache on successful send
      if (data['success'] == true) {
        _invalidateCache();
        final senderPoints = data['senderPointsAwarded'] as int?;
        AppLogger.d(
            '✅ Namaste sent! Remaining: ${data['remaining']}, senderPointsAwarded: $senderPoints',
            category: LogCategory.network);
        return NamasteResult.success(
          remaining: data['remaining'] ?? 0,
          senderPointsAwarded: senderPoints,
        );
      }

      AppLogger.w('⚠️ Namaste failed: ${data['error']}',
          category: LogCategory.network);
      return NamasteResult.fromError(
        data['error'] ?? 'UNKNOWN',
        remaining: data['remaining'],
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogger.e('❌ Firebase function error sending namaste',
          category: LogCategory.network, error: e);
      return NamasteResult.error();
    } catch (e) {
      AppLogger.e('❌ Error sending namaste',
          category: LogCategory.network, error: e);
      return NamasteResult.error();
    }
  }

  /// Get remaining namaste quota for today
  /// Uses local cache to avoid repeated backend calls
  Future<NamasteQuota> getQuota({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh && _cachedQuota != null && _quotaCacheTime != null) {
      final cacheAge = DateTime.now().difference(_quotaCacheTime!);
      if (cacheAge < _quotaCacheDuration) {
        return _cachedQuota!;
      }
    }

    try {
      final callable = _functions.httpsCallable('socialGateway');
      final result = await callable.call({'method': 'getNamasteQuota'});

      final data = result.data as Map<String, dynamic>;
      final quota = NamasteQuota(
        remaining: data['remaining'] ?? 3,
        sent: data['sent'] ?? 0,
        recipients: List<String>.from(data['recipients'] ?? []),
      );

      // Update cache
      _cachedQuota = quota;
      _quotaCacheTime = DateTime.now();

      return quota;
    } catch (e) {
      AppLogger.w('Failed to get namaste quota', category: LogCategory.network);
      // Return default on error (assume full quota)
      return const NamasteQuota(remaining: 3, sent: 0, recipients: []);
    }
  }

  /// Quick check if can send to specific user
  /// Uses cached quota if available
  Future<bool> canSendTo(String userId) async {
    final quota = await getQuota();
    return quota.canSend && !quota.hasSentTo(userId);
  }

  /// Get just the remaining count (convenience method)
  Future<int> getRemainingToday() async {
    final quota = await getQuota();
    return quota.remaining;
  }

  /// Invalidate local cache (call after sending)
  void _invalidateCache() {
    _cachedQuota = null;
    _quotaCacheTime = null;
  }

  /// Clear cache (for logout/testing)
  void clearCache() {
    _invalidateCache();
  }
}
