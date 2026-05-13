import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import '../astrology_service.dart';

/// Daily insight streaming, fetching, generation, feedback, and
/// first-reading / current-times-reading methods for [AstrologyService].
extension AstrologyInsightsExtension on AstrologyService {
  /// Format date as YYYY-MM-DD (matches backend format).
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get daily insight for a specific date.
  Future<DailyInsight?> getDailyInsight(String uid, DateTime date) async {
    try {
      final dateString = _formatDate(date);
      AppLogger.d('Fetching daily insight',
          category: LogCategory.database,
          data: {'uid': uid, 'date': dateString});

      final doc = await firestore
          .collection('users')
          .doc(uid)
          .collection('dailyInsights')
          .doc(dateString)
          .get();

      if (!doc.exists) {
        AppLogger.d('Daily insight document does not exist',
            category: LogCategory.database, data: {'date': dateString});
        return null;
      }

      final data = doc.data();
      if (data == null) {
        AppLogger.w('Daily insight document exists but data is null',
            category: LogCategory.database);
        return null;
      }

      final insight = DailyInsight.fromMap({
        ...data,
        'date': dateString,
      });

      AppLogger.d('Successfully fetched daily insight',
          category: LogCategory.database,
          data: {
            'date': dateString,
            'hasInsight': insight.message.isNotEmpty,
          });

      return insight;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Error fetching daily insight',
        category: LogCategory.database,
        error: e,
        stackTrace: stackTrace,
        data: {'uid': uid, 'date': _formatDate(date)},
      );
      return null;
    }
  }

  /// Get today's daily insight.
  Future<DailyInsight?> getTodayInsight(String uid) async {
    return getDailyInsight(uid, DateTime.now());
  }

  /// Stream daily insight for a specific date.
  /// Uses hash-based deduplication to avoid rebuilding widgets when data
  /// hasn't actually changed (Firestore snapshots can emit metadata-only
  /// updates).
  Stream<DailyInsight?> streamDailyInsight(String uid, DateTime date) {
    final dateString = _formatDate(date);
    String? lastHash;
    DailyInsight? cached;
    return firestore
        .collection('users')
        .doc(uid)
        .collection('dailyInsights')
        .doc(dateString)
        .snapshots()
        .handleError((error, stackTrace) {
      AppLogger.e(
        'Error in daily insight stream',
        category: LogCategory.database,
        error: error,
        stackTrace: stackTrace,
      );
    }).map((doc) {
      try {
        if (!doc.exists) return null;
        final data = doc.data();
        if (data == null) return null;
        final hash = data.toString();
        if (hash == lastHash && cached != null) return cached;
        lastHash = hash;
        cached = DailyInsight.fromMap({
          ...data,
          'date': dateString,
        });
        return cached;
      } catch (e, stackTrace) {
        AppLogger.e(
          'Error parsing daily insight from stream',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    }).distinct();
  }

  /// Stream today's daily insight — queries the MOST RECENT insight.
  /// This avoids timezone mismatch issues between frontend and backend.
  /// Uses hash-based deduplication to prevent unnecessary widget rebuilds.
  Stream<DailyInsight?> streamTodayInsight(String uid) {
    String? lastHash;
    DailyInsight? cached;
    return firestore
        .collection('users')
        .doc(uid)
        .collection('dailyInsights')
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .handleError((error, stackTrace) {
      AppLogger.e(
        'Error in today insight stream',
        category: LogCategory.database,
        error: error,
        stackTrace: stackTrace,
      );
    }).map((snapshot) {
      try {
        if (snapshot.docs.isEmpty) return null;
        final doc = snapshot.docs.first;
        final data = doc.data();
        final hash = data.toString();
        if (hash == lastHash && cached != null) return cached;
        lastHash = hash;
        cached = DailyInsight.fromMap({
          ...data,
          'date': doc.id,
        });
        return cached;
      } catch (e, stackTrace) {
        AppLogger.e(
          'Error parsing today insight from stream',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    }).distinct();
  }

  /// Stream a specific date's insight (for history viewing).
  /// Uses hash-based deduplication to prevent unnecessary widget rebuilds.
  Stream<DailyInsight?> streamInsightForDate(String uid, String date) {
    String? lastHash;
    DailyInsight? cached;
    return firestore
        .collection('users')
        .doc(uid)
        .collection('dailyInsights')
        .doc(date)
        .snapshots()
        .handleError((error, stackTrace) {
      AppLogger.e(
        'Error in insight stream for date $date',
        category: LogCategory.database,
        error: error,
        stackTrace: stackTrace,
      );
    }).map((doc) {
      try {
        if (!doc.exists) return null;
        final data = doc.data();
        if (data == null) return null;
        final hash = data.toString();
        if (hash == lastHash && cached != null) return cached;
        lastHash = hash;
        cached = DailyInsight.fromMap({
          ...data,
          'date': doc.id,
        });
        return cached;
      } catch (e, stackTrace) {
        AppLogger.e(
          'Error parsing insight for date $date',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    }).distinct();
  }

  /// Generate daily insight for the current user.
  /// Set [forceRegenerate] to true to regenerate even if insight exists today.
  Future<Map<String, dynamic>?> generateDailyInsight({
    bool forceRegenerate = false,
  }) async {
    final user = currentUser;
    if (user == null) return null;

    // Clear local caches when force regenerating
    if (forceRegenerate) {
      AstrologyService.clearUserCache(user.uid);
      AppLogger.d('Force regenerate: cleared user cache',
          category: LogCategory.network);
    }

    try {
      final callableOptions =
          HttpsCallableOptions(timeout: const Duration(seconds: 120));

      // Get current location if available (for accurate today's Vedic date)
      double? currentLat;
      double? currentLng;
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          currentLat = last.latitude;
          currentLng = last.longitude;
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          );
          currentLat = position.latitude;
          currentLng = position.longitude;
        }
      } catch (e) {
        AppLogger.w(
          'Could not get current location for daily insight; falling back to birth location',
          category: LogCategory.network,
          data: {'error': e.toString()},
        );
      }

      final now = DateTime.now();
      final offsetHours = now.timeZoneOffset.inMinutes / 60.0;
      AppLogger.i(
        'Generating daily insight',
        category: LogCategory.network,
        data: {
          'forceRegenerate': forceRegenerate,
          'deviceTime': now.toIso8601String(),
          'timeZoneName': now.timeZoneName,
          'timeZoneOffsetHours': offsetHours,
          'hasCurrentLocation': currentLat != null && currentLng != null,
          'currentLat': currentLat,
          'currentLng': currentLng,
        },
      );

      final result = await callWithFunctionsFallback(
        functionName: 'generateInsightForCurrentUser',
        data: {
          'forceRegenerate': forceRegenerate,
          if (currentLat != null) 'currentLatitude': currentLat,
          if (currentLng != null) 'currentLongitude': currentLng,
          'currentTimeZoneOffset': offsetHours,
        },
        options: callableOptions,
      );

      if (result.data is Map) {
        final map = Map<String, dynamic>.from(result.data as Map);
        AppLogger.i('Daily insight generated successfully',
            category: LogCategory.network, data: map);
        return map;
      }

      AppLogger.w('Unexpected response from insight generation',
          category: LogCategory.network,
          data: {'responseType': result.data.runtimeType.toString()});
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to generate insight',
          category: LogCategory.network,
          error: e,
          data: {'stack': stackTrace.toString().substring(0, 400)});
      rethrow;
    }
  }

  /// Generate first reading for the current user.
  Future<bool> generateFirstReading() async {
    final user = currentUser;
    if (user == null) {
      AppLogger.w('Cannot generate first reading: no user',
          category: LogCategory.network);
      return false;
    }

    try {
      AppLogger.i('Calling generateFirstReading cloud function',
          category: LogCategory.network);

      final result = await callWithFunctionsFallback(
        functionName: 'generateFirstReading',
        data: <String, dynamic>{},
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final data = result.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        AppLogger.i('First reading generated successfully',
            category: LogCategory.network);
        AstrologyService.clearUserCache(user.uid);
        return true;
      } else {
        AppLogger.w('First reading generation returned failure',
            category: LogCategory.network, data: {'response': data});
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to generate first reading',
          category: LogCategory.network,
          error: e,
          data: {'stack': stackTrace.toString().substring(0, 400)});
      return false;
    }
  }

  /// Get current times reading content for a user (from Firestore).
  Future<String?> getCurrentTimesReading(String uid) async {
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      final astroData = data?['astrologyData'] as Map<String, dynamic>?;
      final currentTimes =
          astroData?['currentTimesReading'] as Map<String, dynamic>?;
      final content = currentTimes?['content']?.toString();
      return (content != null && content.isNotEmpty) ? content : null;
    } catch (e) {
      AppLogger.w('getCurrentTimesReading failed: $e',
          category: LogCategory.database);
      return null;
    }
  }

  /// Force-regenerate the biweekly per-house current-state readings
  /// (powering the per-house popup on the astro details page).
  ///
  /// Normally these are generated automatically (after first sync, then
  /// refreshed every 14 days by a backend scheduler). Use this only for a
  /// manual "refresh now" affordance in the UI.
  ///
  /// Returns a map with `success`, and on failure a `code` and `message` so
  /// callers can surface the real cloud-function error (e.g. in a snackbar)
  /// instead of a generic INTERNAL.
  Future<Map<String, dynamic>> generatePerHouseReadings({bool force = false}) async {
    final user = currentUser;
    if (user == null) {
      AppLogger.w('Cannot generate per-house readings: no user',
          category: LogCategory.network);
      return {'success': false, 'code': 'no-user', 'message': 'Not signed in'};
    }

    try {
      AppLogger.i('Calling generatePerHouseNow cloud function',
          category: LogCategory.network);

      final result = await callWithFunctionsFallback(
        functionName: 'generatePerHouseNow',
        data: <String, dynamic>{'force': force},
        options: HttpsCallableOptions(timeout: const Duration(seconds: 75)),
      );

      final data = result.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        AppLogger.i('Per-house readings generated',
            category: LogCategory.network,
            data: {'alreadyFresh': data['alreadyFresh']});
        AstrologyService.clearUserCache(user.uid);
        return {
          'success': true,
          'alreadyFresh': data['alreadyFresh'] == true,
          'houseCount': (data['houses'] is Map)
              ? (data['houses'] as Map).length
              : null,
        };
      }
      AppLogger.w('Per-house readings returned failure',
          category: LogCategory.network, data: {'response': data});
      return {
        'success': false,
        'code': 'no-success',
        'message': 'Backend returned no success flag',
      };
    } on FirebaseFunctionsException catch (e) {
      // Extract every scrap of detail the SDK gives us so we can see WHY.
      AppLogger.e('Per-house cloud function threw',
          category: LogCategory.network,
          error: e,
          data: {
            'code': e.code,
            'message': e.message,
            'details': e.details?.toString(),
          });
      return {
        'success': false,
        'code': e.code,
        'message': e.message ?? 'No message',
        'details': e.details?.toString(),
      };
    } catch (e, stackTrace) {
      AppLogger.e('Failed to generate per-house readings (non-Functions error)',
          category: LogCategory.network,
          error: e,
          data: {'stack': stackTrace.toString().substring(0, 400)});
      return {
        'success': false,
        'code': 'unknown',
        'message': e.toString(),
      };
    }
  }

  /// Generate current times reading for the current user.
  Future<bool> generateCurrentTimesReading() async {
    final user = currentUser;
    if (user == null) {
      AppLogger.w('Cannot generate current times reading: no user',
          category: LogCategory.network);
      return false;
    }

    try {
      AppLogger.i('Calling generateCurrentTimesReading cloud function',
          category: LogCategory.network);

      final result = await callWithFunctionsFallback(
        functionName: 'generateCurrentTimesReading',
        data: <String, dynamic>{},
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final data = result.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        AppLogger.i('Current times reading generated',
            category: LogCategory.network);
        AstrologyService.clearUserCache(user.uid);
        return true;
      } else {
        AppLogger.w('Current times reading returned failure',
            category: LogCategory.network, data: {'response': data});
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to generate current times reading',
          category: LogCategory.network,
          error: e,
          data: {'stack': stackTrace.toString().substring(0, 400)});
      return false;
    }
  }

  /// Submit feedback for an insight.
  Future<bool> submitInsightFeedback(String insightId,
      {String? date, String? feedback, int? rating}) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      await callWithFunctionsFallback(
        functionName: 'submitInsightFeedback',
        data: {
          'insightId': insightId,
          if (date != null) 'date': date,
          if (feedback != null) 'feedback': feedback,
          if (rating != null) 'rating': rating,
        },
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to submit feedback',
          category: LogCategory.network, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Toggle favorite status for an insight.
  Future<bool?> toggleFavoriteInsight(String insightId, {String? date}) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final result = await callWithFunctionsFallback(
        functionName: 'toggleFavoriteInsight',
        data: {
          'insightId': insightId,
          if (date != null) 'date': date,
        },
      );

      if (result.data is Map) {
        final map = Map<String, dynamic>.from(result.data as Map);
        return map['isFavorite'] as bool?;
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to toggle favorite',
          category: LogCategory.network, error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Check if insight is favorited.
  Future<bool> isInsightFavorite(String insightId) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final doc = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('favoriteInsights')
          .doc(insightId)
          .get();
      return doc.exists;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to check favorite status',
          category: LogCategory.database, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Clear backend caches.
  /// [mode] can be 'all', 'ai', or 'old' (default).
  Future<Map<String, dynamic>?> clearBackendCaches(
      {String mode = 'old'}) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final result = await callWithFunctionsFallback(
        functionName: 'clearAstroCaches',
        data: {'mode': mode},
      );

      if (result.data is Map) {
        final map = Map<String, dynamic>.from(result.data as Map);
        AppLogger.i('Backend caches cleared',
            category: LogCategory.network, data: map);

        // Also clear local caches
        AstrologyService.clearLocalCaches();

        return map;
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to clear backend caches',
          category: LogCategory.network, error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
