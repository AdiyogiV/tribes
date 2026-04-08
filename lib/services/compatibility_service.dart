import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/models/compatibility/compatibility_result.dart';
import 'package:aurogram/models/compatibility/traditional_match.dart';
export 'package:aurogram/models/compatibility/cosmic_match.dart';
export 'package:aurogram/models/compatibility/life_phase.dart';
export 'package:aurogram/models/compatibility/traditional_match.dart';
export 'package:aurogram/models/compatibility/compatibility_result.dart';

// =============================================================================
// COMPATIBILITY SERVICE
// =============================================================================

/// Lightweight service for compatibility scores
///
/// Architecture:
/// - Backend handles ALL caching (30-day TTL in Firestore)
/// - Backend auto-invalidates cache when user updates astrology profile
/// - Frontend is a thin wrapper - no redundant caching
class CompatibilityService {
  CompatibilityService._();
  static final CompatibilityService _singleton = CompatibilityService._();
  factory CompatibilityService() => _singleton;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorCode;
  String? get errorCode => _errorCode;

  /// Error code for non-friends (mutual follow required)
  static const String errorCodeNotFriends = 'not_friends';

  /// Check if the last error was due to not being friends (mutual follow)
  bool get isNotFriendsError => _errorCode == errorCodeNotFriends;

  /// Get full compatibility result (cosmic + traditional)
  ///
  /// Returns cached result from backend if available (30-day cache)
  /// Returns null if: not logged in, self-comparison, missing profiles, not friends
  Future<CompatibilityResult?> getFullCompatibility(String otherUserId) async {
    _errorMessage = null;
    _errorCode = null;

    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.w('Cannot calculate compatibility: not logged in',
          category: LogCategory.general);
      return null;
    }

    if (user.uid == otherUserId) {
      return null; // Self-compatibility not meaningful
    }

    try {
      final callable = _functions.httpsCallable('calculateCompatibility');
      final result = await callable.call({'otherUserId': otherUserId});

      // Safely convert the result data to Map<String, dynamic>
      // Firebase can return _Map<Object?, Object?> which needs explicit conversion
      final rawData = result.data;
      if (rawData == null) {
        AppLogger.w('💑 Compatibility returned null data',
            category: LogCategory.general);
        return null;
      }
      
      final data = Map<String, dynamic>.from(rawData as Map);
      if (data['success'] != true) {
        AppLogger.w(
            '💑 Compatibility returned non-success: ${data.toString()}',
            category: LogCategory.general);
        _errorMessage =
            data['message']?.toString() ?? data['error']?.toString();
        return null;
      }

      final compatibility = CompatibilityResult.fromMap(data);

      AppLogger.d(
          '💑 Compatibility: cosmic=${compatibility.cosmicMatch?.score}%, '
          'traditional=${compatibility.traditionalMatch?.totalScore ?? 'N/A'}/${compatibility.traditionalMatch?.outOf ?? 'N/A'} '
          '(cached: ${compatibility.cached}, partial: ${compatibility.partial})',
          category: LogCategory.general);

      return compatibility;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = _mapErrorToUserMessage(e.code, e.message);

      AppLogger.w(
          '💑 Compatibility failed - code: ${e.code}, message: ${e.message}, mapped: $_errorMessage',
          category: LogCategory.general);
      return null;
    } catch (e) {
      AppLogger.e('Compatibility error', category: LogCategory.general, error: e);
      _errorMessage = 'Unable to calculate compatibility.';
      return null;
    }
  }

  /// Get compatibility score between current user and another user
  /// [LEGACY] - Use getFullCompatibility for new code
  ///
  /// Returns cached result from backend if available (30-day cache)
  /// Returns null if: not logged in, self-comparison, missing profiles, not friends
  Future<CompatibilityScore?> getCompatibility(String otherUserId) async {
    final result = await getFullCompatibility(otherUserId);
    if (result == null) return null;

    // Convert to legacy format - return null if traditional match unavailable
    final traditional = result.traditionalMatch;
    if (traditional == null) return null;

    return CompatibilityScore(
      totalScore: traditional.totalScore,
      outOf: traditional.outOf,
      percentage: traditional.percentage,
      details: traditional.details,
      cached: result.cached,
    );
  }

  String? _mapErrorToUserMessage(String code, String? message) {
    if (code == 'not-found') {
      return 'Compatibility feature unavailable.';
    }
    if (code == 'invalid-argument') {
      return null; // Self-compatibility - no error message needed
    }
    if (code == 'permission-denied') {
      // Check for blocked user scenarios first (more specific)
      if (message != null && message.contains('not available')) {
        return 'Compatibility not available for this user.';
      }
      _errorCode = errorCodeNotFriends;
      return 'Follow each other to unlock compatibility';
    }
    if (code == 'failed-precondition') {
      // Check for blocked user scenario
      if (message != null && message.contains('blocked')) {
        return 'Unblock this user to see compatibility.';
      }
    }
    if (message == null) {
      return 'Compatibility not available.';
    }
    if (message.contains('mutual follow') ||
        message.contains('Follow each other')) {
      _errorCode = errorCodeNotFriends;
      return 'Follow each other to unlock compatibility';
    }
    if (message.contains('blocked')) {
      return 'Unblock this user to see compatibility.';
    }
    if (message.contains('profile')) {
      return 'Both users need astrology profiles set up.';
    }
    if (message.contains('private') || message.contains('public')) {
      return 'This user\'s astrology is private.';
    }
    if (message.contains('birth')) {
      return 'Complete birth info required.';
    }
    return 'Compatibility not available.';
  }
}
