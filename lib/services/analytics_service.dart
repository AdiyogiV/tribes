import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Analytics service for tracking user behavior and retention metrics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver get observer => 
      FirebaseAnalyticsObserver(analytics: _analytics);

  // =============================================================================
  // USER LIFECYCLE EVENTS
  // =============================================================================

  /// Track when a user signs up
  Future<void> trackSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      AppLogger.i('Analytics: sign_up', category: LogCategory.general, data: {'method': method});
    } catch (e) {
      AppLogger.e('Analytics error: sign_up', category: LogCategory.general, error: e);
    }
  }

  /// Track when a user logs in
  Future<void> trackLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      AppLogger.i('Analytics: login', category: LogCategory.general, data: {'method': method});
    } catch (e) {
      AppLogger.e('Analytics error: login', category: LogCategory.general, error: e);
    }
  }

  /// Track FTUE completion
  Future<void> trackFtueCompleted({bool birthDetailsProvided = false}) async {
    try {
      await _analytics.logEvent(
        name: 'ftue_completed',
        parameters: {
          // Firebase Analytics requires string or number values
          'birth_details_provided': birthDetailsProvided ? 1 : 0,
        },
      );
      AppLogger.i('Analytics: ftue_completed', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Analytics error: ftue_completed', category: LogCategory.general, error: e);
    }
  }

  /// Track FTUE skip / explore-first action
  Future<void> trackFtueSkipped({required bool isLoggedIn}) async {
    try {
      await _analytics.logEvent(
        name: 'ftue_skipped',
        parameters: {
          'is_logged_in': isLoggedIn ? 1 : 0,
        },
      );
      AppLogger.i('Analytics: ftue_skipped', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Analytics error: ftue_skipped', category: LogCategory.general, error: e);
    }
  }

  /// Track app open / session start
  Future<void> trackAppOpen() async {
    try {
      await _analytics.logAppOpen();
      AppLogger.i('Analytics: app_open', category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Analytics error: app_open', category: LogCategory.general, error: e);
    }
  }

  // =============================================================================
  // ENGAGEMENT EVENTS
  // =============================================================================

  /// Track when user views daily insight
  Future<void> trackDailyInsightViewed() async {
    try {
      await _analytics.logEvent(
        name: 'daily_insight_viewed',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: daily_insight_viewed', category: LogCategory.general, error: e);
    }
  }

  /// Track when user asks HolyCow AI a question
  Future<void> trackAiChatMessage({String? topic}) async {
    try {
      await _analytics.logEvent(
        name: 'ai_chat_message',
        parameters: {
          if (topic != null) 'topic': topic,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: ai_chat_message', category: LogCategory.general, error: e);
    }
  }

  /// Track when user creates a post
  Future<void> trackPostCreated({required String spaceId, String? mediaType}) async {
    try {
      await _analytics.logEvent(
        name: 'post_created',
        parameters: {
          'space_id': spaceId,
          if (mediaType != null) 'media_type': mediaType,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: post_created', category: LogCategory.general, error: e);
    }
  }

  /// Track when user views a post
  Future<void> trackPostViewed({required String postId, required String spaceId}) async {
    try {
      await _analytics.logEvent(
        name: 'post_viewed',
        parameters: {
          'post_id': postId,
          'space_id': spaceId,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: post_viewed', category: LogCategory.general, error: e);
    }
  }

  /// Track when feed is loaded/viewed
  Future<void> trackFeedViewed({required int count, required bool isAuthenticated}) async {
    try {
      await _analytics.logEvent(
        name: 'feed_viewed',
        parameters: {
          'count': count,
          'is_authenticated': isAuthenticated ? 1 : 0,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: feed_viewed', category: LogCategory.general, error: e);
    }
  }

  /// Track when user joins a space (member or request)
  Future<void> trackSpaceJoined({
    required String spaceId,
    required String role,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'space_joined',
        parameters: {
          'space_id': spaceId,
          'role': role,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: space_joined', category: LogCategory.general, error: e);
    }
  }

  // =============================================================================
  // SPACE EVENTS
  // =============================================================================

  /// Track when user creates a space
  Future<void> trackSpaceCreated({required String spaceId, required String spaceType}) async {
    try {
      await _analytics.logEvent(
        name: 'space_created',
        parameters: {
          'space_id': spaceId,
          'space_type': spaceType,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: space_created', category: LogCategory.general, error: e);
    }
  }

  // =============================================================================
  // MESSAGING EVENTS
  // =============================================================================

  /// Track when user sends a message
  Future<void> trackMessageSent({required String conversationType}) async {
    try {
      await _analytics.logEvent(
        name: 'message_sent',
        parameters: {
          'conversation_type': conversationType, // 'dm' or 'space'
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: message_sent', category: LogCategory.general, error: e);
    }
  }

  // =============================================================================
  // SHARE EVENTS
  // =============================================================================

  /// Track when user shares content
  Future<void> trackContentShared({
    required String contentType,
    required String itemId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'content_shared',
        parameters: {
          'content_type': contentType,
          'item_id': itemId,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: content_shared', category: LogCategory.general, error: e);
    }
  }

  /// Track when user starts a new DM conversation
  Future<void> trackDmStarted() async {
    try {
      await _analytics.logEvent(name: 'dm_started');
    } catch (e) {
      AppLogger.e('Analytics error: dm_started', category: LogCategory.general, error: e);
    }
  }

  // =============================================================================
  // RETENTION EVENTS
  // =============================================================================

  /// Track consecutive daily visits
  Future<void> trackDailyVisit({required int consecutiveDays}) async {
    try {
      await _analytics.logEvent(
        name: 'daily_visit',
        parameters: {
          'consecutive_days': consecutiveDays,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: daily_visit', category: LogCategory.general, error: e);
    }
  }

  /// Track feature usage for retention analysis
  Future<void> trackFeatureUsed({required String featureName}) async {
    try {
      await _analytics.logEvent(
        name: 'feature_used',
        parameters: {
          'feature_name': featureName,
        },
      );
    } catch (e) {
      AppLogger.e('Analytics error: feature_used', category: LogCategory.general, error: e);
    }
  }

  // =============================================================================
  // SHARE & INVITE EVENTS
  // =============================================================================

  /// Track when user shares/invites
  Future<void> trackInviteSent({required String method}) async {
    try {
      await _analytics.logShare(
        contentType: 'invite',
        itemId: 'app_invite',
        method: method,
      );
    } catch (e) {
      AppLogger.e('Analytics error: invite_sent', category: LogCategory.general, error: e);
    }
  }

  // =============================================================================
  // USER PROPERTIES
  // =============================================================================

  /// Set user property for segmentation
  Future<void> setUserProperty({required String name, String? value}) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      AppLogger.e('Analytics error: set_user_property', category: LogCategory.general, error: e);
    }
  }

  /// Set user ID for analytics
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      AppLogger.e('Analytics error: set_user_id', category: LogCategory.general, error: e);
    }
  }

  /// Set whether user has birth details (for segmentation)
  Future<void> setHasBirthDetails(bool hasDetails) async {
    await setUserProperty(name: 'has_birth_details', value: hasDetails.toString());
  }

  /// Set user's primary space count
  Future<void> setSpaceCount(int count) async {
    await setUserProperty(name: 'space_count', value: count.toString());
  }
}



