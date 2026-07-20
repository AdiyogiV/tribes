import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import '../astrology_service.dart';

DailyInsight _dailyInsightFromForecast(ForecastDay day) {
  final sections = <InsightSection>[
    InsightSection(
      title: (day.heading?.isNotEmpty == true ? day.heading! : 'TODAY')
          .toUpperCase(),
      content: day.narrative ?? '',
      data: {'alignment': day.alignment},
    ),
    if (day.action?.isNotEmpty == true)
      InsightSection(title: 'FOCUS', content: day.action!),
    if (day.caution?.isNotEmpty == true)
      InsightSection(title: 'HANDLE GENTLY', content: day.caution!),
    if (day.timing?.isNotEmpty == true)
      InsightSection(title: 'TIMING', content: day.timing!),
    if (day.tip?.isNotEmpty == true)
      InsightSection(title: 'PRACTICAL TIP', content: day.tip!),
  ].where((section) => section.content.trim().isNotEmpty).toList();

  return DailyInsight(
    theme: day.heading ?? "Today's Guidance",
    message: day.narrative ?? '',
    sections: sections,
    generatedAt: DateTime.now(),
    date: DateTime.tryParse(day.date),
    version: 'forecast-v1',
    astrologicalData: {
      'alignment': day.alignment,
      'tara': day.tara,
      'favorable': day.favorable,
      'unfavorable': day.unfavorable,
    },
  );
}

/// Daily insight streaming, fetching, generation, feedback, and
/// first-reading / current-times-reading methods for [AstrologyService].
extension AstrologyInsightsExtension on AstrologyService {
  /// Stream the backend's IST-keyed insight for today.
  ///
  /// Reading "latest" used to show yesterday's card when today's generation
  /// was missing. The backend keys every daily insight in Asia/Kolkata, so the
  /// client must use that same calendar contract rather than silently falling
  /// back to stale content.
  Stream<DailyInsight?> streamTodayInsight(String uid) {
    final istNow =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final date = '${istNow.year.toString().padLeft(4, '0')}-'
        '${istNow.month.toString().padLeft(2, '0')}-'
        '${istNow.day.toString().padLeft(2, '0')}';
    return streamInsightForDate(uid, date);
  }

  /// Stream a specific date from the unified forecast read-model.
  ///
  /// [DailyInsight] remains a compatibility view while older dashboard widgets
  /// are migrated; there is no separate dailyInsights collection or AI call.
  Stream<DailyInsight?> streamInsightForDate(String uid, String date) =>
      ForecastService().streamForecast(uid).map((forecast) {
        final day = forecast[date];
        return day == null ? null : _dailyInsightFromForecast(day);
      }).distinct();

  /// Refresh deterministic forecast signals and enqueue narration only when its
  /// runway is short. Kept as a compatibility method for onboarding callers.
  Future<Map<String, dynamic>?> generateDailyInsight({
    bool forceRegenerate = false,
  }) async {
    if (currentUser == null) return null;
    await ForecastService().ensureComputed();
    return const {'success': true, 'source': 'forecast'};
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
        functionName: 'insightGateway',
        data: <String, dynamic>{'method': 'generateFirstReading'},
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
  Future<Map<String, dynamic>> generatePerHouseReadings(
      {bool force = false}) async {
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
        functionName: 'insightGateway',
        data: <String, dynamic>{
          'method': 'generatePerHouseNow',
          'force': force
        },
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
          'houseCount':
              (data['houses'] is Map) ? (data['houses'] as Map).length : null,
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

  /// Submit feedback for an insight.
  Future<bool> submitInsightFeedback(String insightId,
      {String? date, String? feedback, int? rating}) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      await callWithFunctionsFallback(
        functionName: 'insightGateway',
        data: {
          'method': 'submitInsightFeedback',
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
        functionName: 'insightGateway',
        data: {
          'method': 'toggleFavoriteInsight',
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
        functionName: 'insightGateway',
        data: {'method': 'clearAstroCaches', 'mode': mode},
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
