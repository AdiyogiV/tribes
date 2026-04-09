import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';

import '../astrology_service.dart';

/// Cloud Function calling, auth-token refresh, location search,
/// and timezone resolution for [AstrologyService].
extension AstrologyApiExtension on AstrologyService {
  /// Call a Cloud Function with primary-region first, falling back to the
  /// secondary region on transient / not-found errors.
  Future<HttpsCallableResult> callWithFunctionsFallback({
    required String functionName,
    required Map<String, dynamic> data,
    HttpsCallableOptions? options,
  }) async {
    try {
      final primaryCallable =
          functionsPrimary.httpsCallable(functionName, options: options);
      return await primaryCallable.call(data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated' && await ensureAuthToken()) {
        final primaryCallable =
            functionsPrimary.httpsCallable(functionName, options: options);
        return await primaryCallable.call(data);
      }
      if (e.code == 'unauthenticated') {
        AstrologyService.setLastAuthFailure(true);
      }
      if (!_shouldFallbackToSecondary(e)) rethrow;
      AppLogger.w(
        'Callable failed in primary region, retrying in fallback',
        category: LogCategory.network,
        data: {
          'function': functionName,
          'primaryRegion': AstrologyService.primaryFunctionsRegion,
          'fallbackRegion': AstrologyService.fallbackFunctionsRegion,
          'code': e.code,
        },
      );
      final fallbackCallable =
          functionsFallback.httpsCallable(functionName, options: options);
      return await fallbackCallable.call(data);
    }
  }

  bool _shouldFallbackToSecondary(FirebaseFunctionsException error) {
    return error.code == 'not-found' || error.code == 'unavailable';
  }

  /// Refresh the current user's Firebase ID token.
  Future<bool> ensureAuthToken() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      await user.reload();
      final refreshedUser = auth.currentUser;
      if (refreshedUser == null) return false;
      await refreshedUser.getIdToken(true);
      AstrologyService.setLastAuthFailure(false);
      return true;
    } catch (e) {
      AstrologyService.setLastAuthFailure(true);
      AppLogger.w(
        'Unable to refresh auth token before callable',
        category: LogCategory.network,
        data: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Search for locations using the geo-location Cloud Function.
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final result = await callWithFunctionsFallback(
        functionName: 'searchGeoLocation',
        data: {'query': query},
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

      if (result.data is Map) {
        final map = Map<String, dynamic>.from(result.data as Map);
        if (map['success'] == true && map['results'] is List) {
          return List<Map<String, dynamic>>.from(
            (map['results'] as List)
                .map((item) => Map<String, dynamic>.from(item as Map)),
          );
        }
      }
      return [];
    } catch (e) {
      AppLogger.w('Location search failed',
          category: LogCategory.network,
          data: {'query': query, 'error': e.toString()});
      return [];
    }
  }

  /// Resolve a timezone string from latitude/longitude.
  Future<String> resolveTimeZone(double latitude, double longitude) async {
    try {
      return latLngToTimezoneString(latitude, longitude);
    } catch (e) {
      AppLogger.w('Time zone lookup failed',
          category: LogCategory.general, data: {'error': e.toString()});
      return 'UTC';
    }
  }
}
