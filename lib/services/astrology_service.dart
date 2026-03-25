import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AstrologyService {
  AstrologyService._();

  static final AstrologyService _singleton = AstrologyService._();

  factory AstrologyService() => _singleton;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _primaryFunctionsRegion = 'asia-southeast2';
  static const String _fallbackFunctionsRegion = 'us-central1';
  final FirebaseFunctions _functionsPrimary =
      FirebaseFunctions.instanceFor(region: _primaryFunctionsRegion);
  final FirebaseFunctions _functionsFallback =
      FirebaseFunctions.instanceFor(region: _fallbackFunctionsRegion);
  static bool _lastAuthFailure = false;
  bool get lastAuthFailure => _lastAuthFailure;

  static const String _predictionDateKey = 'astro_prediction_date';
  static const String _predictionTextKey = 'astro_prediction_text';
  static const String _predictionSignKey = 'astro_prediction_sign';

  static const List<String> _predictionTemplates = [
    '{sign}, align with your Lagna today and let deliberate actions speak for you.',
    'Ground yourself, {sign}. Small rituals will amplify clarity and confidence.',
    'Your moon energy needs gentle pacing today, {sign}. Protect your emotional bandwidth.',
    '{sign}, conversations carry karmic weight now—listen fully before responding.',
    'Channel your Mars drive into disciplined structure, {sign}. Focus beats force.',
    'Let Rahu-inspired curiosity guide learning today, {sign}, but keep boundaries firm.',
    'Saturn reminds you to honor commitments, {sign}. Consistency attracts the right allies.',
    '{sign}, soften your approach and invite grace—Venus rewards balanced effort.',
  ];

  User? get _user => _auth.currentUser;

  Future<AstrologyProfile?> getProfile(String uid,
      {bool forceRefresh = false}) async {
    // Return cached profile if available and not forcing refresh
    // BUT: if cached value is null, force a Firestore check (profile may have been saved)
    if (!forceRefresh && _profileCache.containsKey(uid)) {
      final cached = _profileCache[uid];
      if (cached != null) {
        return cached;
      }
      // Cached value is null - do a Firestore check in case profile was saved
      AppLogger.d('Cached profile is null, checking Firestore',
          category: LogCategory.database, data: {'uid': uid});
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        _profileCache[uid] = null;
        return null;
      }

      final data = doc.data();
      if (data == null || !data.containsKey('astrologyData')) {
        _profileCache[uid] = null;
        return null;
      }

      final profile = AstrologyProfile.fromMap(
        Map<String, dynamic>.from(
            data['astrologyData'] as Map<String, dynamic>),
      );
      _profileCache[uid] = profile;
      return profile;
    } catch (e) {
      return _profileCache[
          uid]; // Return cached on error, or null if not cached
    }
  }

  // Cache to prevent unnecessary rebuilds
  static final Map<String, AstrologyProfile?> _profileCache = {};
  static final Map<String, String> _profileHashCache = {};

  /// Clear all local caches - call after force regenerate or sync
  static void clearLocalCaches() {
    _profileCache.clear();
    _profileHashCache.clear();
    AppLogger.d('Local astrology caches cleared',
        category: LogCategory.database);
  }

  /// Clear cache for a specific user
  static void clearUserCache(String uid) {
    _profileCache.remove(uid);
    _profileHashCache.remove(uid);
    AppLogger.d('Cleared cache for user $uid', category: LogCategory.database);
  }

  Stream<AstrologyProfile?> streamProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      try {
        if (!doc.exists) {
          _profileCache[uid] = null;
          return null;
        }
        final data = doc.data();
        if (data == null || !data.containsKey('astrologyData')) {
          // Return cached profile if available, otherwise null
          return _profileCache[uid];
        }

        // Only emit if astrologyData actually changed
        final astroData = data['astrologyData'] as Map<String, dynamic>;
        final astroDataHash = astroData.toString();
        final lastHash = _profileHashCache[uid];

        // If hash matches, return cached profile to prevent rebuild
        if (lastHash == astroDataHash && _profileCache.containsKey(uid)) {
          return _profileCache[uid];
        }

        // Hash changed, update cache
        _profileHashCache[uid] = astroDataHash;
        final profile = AstrologyProfile.fromMap(
          Map<String, dynamic>.from(astroData),
        );
        _profileCache[uid] = profile;
        return profile;
      } catch (e, stackTrace) {
        AppLogger.e(
          'Error parsing astrology profile from stream',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
        );
        return _profileCache[uid]; // Return cached on error
      }
    }).handleError((error, stackTrace) {
      AppLogger.e(
        'Error in astrology profile stream',
        category: LogCategory.database,
        error: error,
        stackTrace: stackTrace,
      );
    }).distinct(); // Only emit when value actually changes
  }

  /// Get user engagement data (streak, last read, etc.)
  Future<Map<String, dynamic>?> getUserEngagement() async {
    final user = _user;
    if (user == null) return null;
    if (!await _ensureAuthToken()) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('astrology')
          .doc('engagement')
          .get();

      if (!doc.exists) {
        return {'streak': 0, 'lastRead': null};
      }

      return doc.data();
    } catch (e) {
      AppLogger.e('Error getting user engagement',
          category: LogCategory.database, error: e);
      return {'streak': 0}; // Return default on error
    }
  }

  Future<bool> saveProfile(AstrologyProfile profile) async {
    final user = _user;
    if (user == null) return false;

    try {
      // Clear ALL calculated fields when birth details change
      // This ensures _waitForAstroData polls until fresh data arrives
      // CRITICAL: ALL astrologically-derived data must be cleared to prevent
      // stale data from persisting when birth details are updated
      await _firestore.collection('users').doc(user.uid).set({
        'astrologyData': {
          ...profile.toMap(),
          // Clear calculated fields - they'll be recalculated after sync
          'sunSign': FieldValue.delete(),
          'moonSign': FieldValue.delete(),
          'ascendant': FieldValue.delete(),
          'nakshatra': FieldValue.delete(),
          'moonNakshatra': FieldValue.delete(),
          'lagnaNakshatra': FieldValue.delete(),
          'houseInterpretations': FieldValue.delete(),
          'birthChartData': FieldValue.delete(),
          'currentDasha': FieldValue.delete(),
          'dashaLastUpdated': FieldValue.delete(),
          'rajYogas': FieldValue.delete(),
          'syncStatus': FieldValue.delete(),
          // CRITICAL: Clear doshas - was missing and caused stale data bug
          'doshas': FieldValue.delete(),
          'yogas': FieldValue.delete(),
          'yogasDetailed': FieldValue.delete(),
          'processedPlanets': FieldValue.delete(),
          'navamsa': FieldValue.delete(),
          'panchang': FieldValue.delete(),
          'muhurat': FieldValue.delete(),
          'samvatInfo': FieldValue.delete(),
          'chartSvgUrl': FieldValue.delete(),
          'firstReading': FieldValue.delete(),
        },
      }, SetOptions(merge: true));

      // CRITICAL: Clear local cache so polling gets fresh data from Firestore
      // Don't cache the profile without calculated fields
      _profileCache.remove(user.uid);
      AppLogger.d('Astrology profile saved and cached',
          category: LogCategory.database,
          data: {
            'uid': user.uid,
            'isComplete': profile.isComplete,
            'birthTime': profile.birthTime,
            'birthLat': profile.birthLatitude,
            'birthLng': profile.birthLongitude,
            'cacheNowHasKey': _profileCache.containsKey(user.uid),
          });

      // Basic signs are always visible to others - update public cache
      if (profile.isEnabled && profile.hasCalculatedData) {
        await _updatePublicCache(user.uid, profile);
      }

      return true;
    } catch (e) {
      AppLogger.e('Error saving astrology profile',
          category: LogCategory.database, error: e);
      return false;
    }
  }

  Future<void> _updatePublicCache(String uid, AstrologyProfile profile) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'astrology': {
          'isEnabled': profile.isEnabled,
          'visibility': profile.visibility.toString().split('.').last,
          'sunSign': profile.sunSign,
          'moonSign': profile.moonSign,
          'ascendant': profile.ascendant,
          'nakshatra': profile.nakshatra,
        }
      });
    } catch (e) {
      AppLogger.e('Error updating public astrology cache',
          category: LogCategory.database, error: e);
    }
  }

  Future<bool> deleteProfile() async {
    final user = _user;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'astrologyData': FieldValue.delete(),
        'astrology': FieldValue.delete(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      AppLogger.e('Error deleting astrology profile',
          category: LogCategory.database, error: e);
      return false;
    }
  }

  /// Calculate and save astrology data
  ///
  /// [mode] controls how much data to fetch:
  /// - 'basic' (~3-4s): Essential data only (signs, dasha, yogas, doshas)
  ///   Best for onboarding - gets user seeing their chart fast
  /// - 'standard' (~6-8s): Basic + samvat, detailed dasha, panchang
  ///   Default for returning users
  /// - 'full' (~15-17s): Everything including muhurat (3 days), navamsa, etc.
  ///   On-demand when viewing full astro details
  Future<bool> calculateAndSaveAll(String uid, {String mode = 'basic'}) async {
    AppLogger.i('calculateAndSaveAll INVOKED',
        category: LogCategory.general, data: {'uid': uid, 'mode': mode});

    try {
      // Debug: Log cache state before fetching
      final cacheHasKey = _profileCache.containsKey(uid);
      final cachedProfile = _profileCache[uid];
      AppLogger.d('calculateAndSaveAll checking profile',
          category: LogCategory.general,
          data: {
            'uid': uid,
            'cacheHasKey': cacheHasKey,
            'cachedProfileNull': cachedProfile == null,
            'cachedIsComplete': cachedProfile?.isComplete ?? false,
            'cachedBirthTime': cachedProfile?.birthTime,
            'cachedLat': cachedProfile?.birthLatitude,
            'cachedLng': cachedProfile?.birthLongitude,
          });

      // Get profile with retry logic for timing edge cases
      AstrologyProfile? profile = await getProfile(uid);

      // If profile not found in cache, wait briefly and try Firestore directly
      if (profile == null || !profile.isComplete) {
        AppLogger.d('Profile not ready, waiting and retrying from Firestore',
            category: LogCategory.general);
        await Future.delayed(const Duration(milliseconds: 500));
        profile = await getProfile(uid, forceRefresh: true);
      }

      if (profile == null) {
        AppLogger.w('Profile is null after getProfile and retry',
            category: LogCategory.general,
            data: {'uid': uid, 'cacheHasKey': _profileCache.containsKey(uid)});
        return false;
      }

      if (!profile.isComplete) {
        AppLogger.w('Incomplete birth data',
            category: LogCategory.general,
            data: {
              'uid': uid,
              'birthDate': profile.birthDate?.toIso8601String(),
              'birthYear': profile.birthYear,
              'birthMonth': profile.birthMonth,
              'birthDay': profile.birthDay,
              'birthTime': profile.birthTime,
              'birthLat': profile.birthLatitude,
              'birthLng': profile.birthLongitude,
            });
        return false;
      }

      final synced = await syncAstroProfile(
        forceRefresh: true,
        mode: mode,
      );

      if (!synced) {
        AppLogger.w('Astrology sync returned false',
            category: LogCategory.general);
      } else {
        AppLogger.i('calculateAndSaveAll COMPLETED successfully',
            category: LogCategory.general);
      }

      return synced;
    } catch (e, stackTrace) {
      AppLogger.e('calculateAndSaveAll FAILED with exception',
          category: LogCategory.general,
          error: e,
          data: {'stack': stackTrace.toString().substring(0, 400)});
      return false;
    }
  }

  /// Trigger a lazy background sync for more complete data
  /// Call this after basic sync completes to upgrade to standard/full
  Future<void> triggerLazySync({String mode = 'standard'}) async {
    final user = _user;
    if (user == null) return;

    try {
      // Check current sync status
      final profile = await getProfile(user.uid);
      if (profile == null) return;

      // Only upgrade sync if needed
      final currentStatus = profile.syncStatus ?? 'none';
      final statusOrder = {
        'none': 0,
        'partial': 1,
        'basic_complete': 2,
        'standard_complete': 3,
        'full_complete': 4
      };
      final modeStatus = mode == 'full' ? 'full_complete' : 'standard_complete';

      final needsSamvatRefresh =
          mode == 'standard' && _isSamvatLikelyCurrent(profile);
      final shouldUpgrade =
          (statusOrder[modeStatus] ?? 0) > (statusOrder[currentStatus] ?? 0);
      if (!shouldUpgrade && !needsSamvatRefresh) {
        // Already at or above requested sync level
        return;
      }

      // Fire and forget - don't await
      syncAstroProfile(forceRefresh: needsSamvatRefresh, mode: mode)
          .catchError((_) => false);
    } catch (e) {
      AppLogger.w('Lazy sync trigger failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  bool _isSamvatLikelyCurrent(AstrologyProfile profile) {
    final samvat = profile.samvatInfo;
    if (samvat == null || samvat.isEmpty) return true;

    final birthYear = profile.birthYear ?? profile.birthDate?.year;
    final rawYear = samvat['vikram_chaitradi_number'];
    final samvatYear = rawYear is num
        ? rawYear.toInt()
        : int.tryParse(rawYear?.toString() ?? '');
    if (birthYear == null || samvatYear == null) return false;

    final expectedBirthMin = birthYear + 55;
    final expectedBirthMax = birthYear + 59;
    final currentYear = DateTime.now().year;
    final expectedCurrentMin = currentYear + 55;
    final expectedCurrentMax = currentYear + 59;

    final matchesBirth =
        samvatYear >= expectedBirthMin && samvatYear <= expectedBirthMax;
    final matchesCurrent =
        samvatYear >= expectedCurrentMin && samvatYear <= expectedCurrentMax;
    return matchesCurrent && !matchesBirth;
  }

  Future<bool> syncAstroProfile({
    bool forceRefresh = false,
    String mode = 'standard', // Default to standard - full mode rarely needed
  }) async {
    final user = _user;
    if (user == null) {
      AppLogger.e('syncAstroProfile failed - no authenticated user',
          category: LogCategory.network);
      return false;
    }
    if (!await _ensureAuthToken()) return false;

    // Clear local cache before sync to ensure fresh data
    clearUserCache(user.uid);

    AppLogger.i('syncAstroProfile calling Cloud Function',
        category: LogCategory.network,
        data: {'uid': user.uid, 'mode': mode, 'forceRefresh': forceRefresh});

    try {
      final result = await _callWithFunctionsFallback(
        functionName: 'syncAstroProfile',
        data: {
          'mode': mode,
          'forceRefresh': forceRefresh,
        },
      );

      AppLogger.i('syncAstroProfile Cloud Function returned',
          category: LogCategory.network,
          data: {'resultType': result.data.runtimeType.toString()});

      if (result.data is Map) {
        final map = Map<String, dynamic>.from(result.data as Map);
        final success = map['success'] == true;
        if (!success) {
          AppLogger.w('Astro sync returned unsuccessful response',
              category: LogCategory.network, data: map);
        } else {
          AppLogger.i('Astro sync completed successfully',
              category: LogCategory.network,
              data: {
                'syncStatus': map['syncStatus'],
                'sunSign': map['data']?['sunSign'],
              });
        }
        return success;
      }

      AppLogger.w('Astro sync returned unexpected data type',
          category: LogCategory.network,
          data: {'responseType': result.data.runtimeType.toString()});
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Astro sync Cloud Function FAILED',
          category: LogCategory.network,
          error: e,
          data: {'stack': stackTrace.toString().substring(0, 400)});
      return false;
    }
  }

  Future<String?> getDailyPrediction(String? sunSign) async {
    final normalizedSign = _normalizeSign(sunSign);
    final cached = await _getCachedPrediction(normalizedSign);
    if (cached != null) return cached;

    final prediction = _formatPrediction(normalizedSign);
    await _cachePrediction(normalizedSign, prediction);
    return prediction;
  }

  Future<String> resolveTimeZone(double latitude, double longitude) async {
    try {
      return latLngToTimezoneString(latitude, longitude);
    } catch (e) {
      AppLogger.w('Time zone lookup failed',
          category: LogCategory.general, data: {'error': e.toString()});
      return 'UTC';
    }
  }

  /// Search for locations using Free Astrology API
  /// Returns list of location results with coordinates and timezone
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final result = await _callWithFunctionsFallback(
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

  String get _todayDateString =>
      DateTime.now().toIso8601String().split('T').first;

  Future<String?> _getCachedPrediction(String sunSign) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateString;
      final cachedDate = prefs.getString(_predictionDateKey);
      final cachedPrediction = prefs.getString(_predictionTextKey);
      final cachedSign = prefs.getString(_predictionSignKey);

      if (cachedDate == today &&
          cachedSign == sunSign &&
          cachedPrediction != null) {
        AppLogger.d('Using cached daily prediction',
            category: LogCategory.general);
        return cachedPrediction;
      }
      return null;
    } catch (e) {
      AppLogger.w('Prediction cache read failed',
          category: LogCategory.general, data: {'error': e.toString()});
      return null;
    }
  }

  Future<void> _cachePrediction(String sunSign, String prediction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_predictionDateKey, _todayDateString);
      await prefs.setString(_predictionTextKey, prediction);
      await prefs.setString(_predictionSignKey, sunSign);
      AppLogger.d('Daily prediction cached', category: LogCategory.general);
    } catch (e) {
      AppLogger.w('Prediction cache write failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  String _normalizeSign(String? sunSign) {
    if (sunSign == null) return 'your sign';
    final trimmed = sunSign.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown') {
      return 'your sign';
    }
    return trimmed;
  }

  String _formatPrediction(String sunSign) {
    if (_predictionTemplates.isEmpty) {
      return 'Stay aligned with your breath today, $sunSign.';
    }
    final index =
        DateTime.now().millisecondsSinceEpoch % _predictionTemplates.length;
    return _predictionTemplates[index].replaceAll('{sign}', sunSign);
  }

  /// Format date as YYYY-MM-DD (matches backend format)
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get daily insight for a specific date
  Future<DailyInsight?> getDailyInsight(String uid, DateTime date) async {
    try {
      final dateString = _formatDate(date);
      AppLogger.d('Fetching daily insight',
          category: LogCategory.database,
          data: {'uid': uid, 'date': dateString});

      final doc = await _firestore
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
          data: {'date': dateString, 'hasInsight': insight.message.isNotEmpty});

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

  /// Get today's daily insight
  Future<DailyInsight?> getTodayInsight(String uid) async {
    return getDailyInsight(uid, DateTime.now());
  }

  /// Stream daily insight for a specific date
  Stream<DailyInsight?> streamDailyInsight(String uid, DateTime date) {
    final dateString = _formatDate(date);
    return _firestore
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
      // Don't rethrow - let the stream continue
    }).map((doc) {
      try {
        if (!doc.exists) return null;
        final data = doc.data();
        if (data == null) return null;
        return DailyInsight.fromMap({
          ...data,
          'date': dateString,
        });
      } catch (e, stackTrace) {
        AppLogger.e(
          'Error parsing daily insight from stream',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    });
  }

  /// Stream today's daily insight - queries the MOST RECENT insight
  /// This avoids timezone mismatch issues between frontend and backend
  Stream<DailyInsight?> streamTodayInsight(String uid) {
    // Query the most recent insight (last 2 days to handle timezone edge cases)
    // and let the UI display whatever the server considers "today"
    return _firestore
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
        return DailyInsight.fromMap({
          ...data,
          'date': doc.id, // Use the document ID as the date
        });
      } catch (e, stackTrace) {
        AppLogger.e(
          'Error parsing today insight from stream',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    });
  }

  /// Stream a specific date's insight (for history viewing)
  Stream<DailyInsight?> streamInsightForDate(String uid, String date) {
    return _firestore
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
        return DailyInsight.fromMap({
          ...data,
          'date': doc.id,
        });
      } catch (e, stackTrace) {
        AppLogger.e(
          'Error parsing insight for date $date',
          category: LogCategory.database,
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    });
  }

  /// Generate daily insight for current user
  /// Set [forceRegenerate] to true to regenerate even if insight exists for today
  Future<Map<String, dynamic>?> generateDailyInsight({
    bool forceRegenerate = false,
  }) async {
    final user = _user;
    if (user == null) return null;

    // Clear local caches when force regenerating
    if (forceRegenerate) {
      clearUserCache(user.uid);
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
        // Try last known first (fast), then a low-accuracy current fix.
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

      final result = await _callWithFunctionsFallback(
        functionName: 'generateInsightForCurrentUser',
        data: {
          'forceRegenerate': forceRegenerate,
          if (currentLat != null) 'currentLatitude': currentLat,
          if (currentLng != null) 'currentLongitude': currentLng,
          // Helps backend align "today" to device timezone even if birth timezone differs
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

  Future<HttpsCallableResult> _callWithFunctionsFallback({
    required String functionName,
    required Map<String, dynamic> data,
    HttpsCallableOptions? options,
  }) async {
    try {
      final primaryCallable =
          _functionsPrimary.httpsCallable(functionName, options: options);
      return await primaryCallable.call(data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated' && await _ensureAuthToken()) {
        final primaryCallable =
            _functionsPrimary.httpsCallable(functionName, options: options);
        return await primaryCallable.call(data);
      }
      if (e.code == 'unauthenticated') {
        _lastAuthFailure = true;
      }
      if (!_shouldFallbackToSecondary(e)) rethrow;
      AppLogger.w(
        'Callable failed in primary region, retrying in fallback',
        category: LogCategory.network,
        data: {
          'function': functionName,
          'primaryRegion': _primaryFunctionsRegion,
          'fallbackRegion': _fallbackFunctionsRegion,
          'code': e.code,
        },
      );
      final fallbackCallable =
          _functionsFallback.httpsCallable(functionName, options: options);
      return await fallbackCallable.call(data);
    }
  }

  bool _shouldFallbackToSecondary(FirebaseFunctionsException error) {
    return error.code == 'not-found' || error.code == 'unavailable';
  }

  Future<bool> _ensureAuthToken() async {
    try {
      final user = _user;
      if (user == null) return false;
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) return false;
      await refreshedUser.getIdToken(true);
      _lastAuthFailure = false;
      return true;
    } catch (e) {
      _lastAuthFailure = true;
      AppLogger.w(
        'Unable to refresh auth token before callable',
        category: LogCategory.network,
        data: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Generate first reading for the current user
  /// Returns true if successful, false otherwise
  Future<bool> generateFirstReading() async {
    final user = _user;
    if (user == null) {
      AppLogger.w('Cannot generate first reading: no user',
          category: LogCategory.network);
      return false;
    }

    try {
      AppLogger.i('Calling generateFirstReading cloud function',
          category: LogCategory.network);

      final result = await _callWithFunctionsFallback(
        functionName: 'generateFirstReading',
        data: <String, dynamic>{},
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final data = result.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        AppLogger.i('✅ First reading generated successfully',
            category: LogCategory.network);
        // Clear cache to force refresh
        clearUserCache(user.uid);
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
  /// Returns content string or null if not yet generated.
  Future<String?> getCurrentTimesReading(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
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

  /// Generate current times reading for the current user (present + next 2–4 months).
  /// Returns true if call succeeded, false otherwise.
  Future<bool> generateCurrentTimesReading() async {
    final user = _user;
    if (user == null) {
      AppLogger.w('Cannot generate current times reading: no user',
          category: LogCategory.network);
      return false;
    }

    try {
      AppLogger.i('Calling generateCurrentTimesReading cloud function',
          category: LogCategory.network);

      final result = await _callWithFunctionsFallback(
        functionName: 'generateCurrentTimesReading',
        data: <String, dynamic>{},
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final data = result.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        AppLogger.i('✅ Current times reading generated',
            category: LogCategory.network);
        clearUserCache(user.uid);
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

  /// Submit feedback for an insight
  Future<bool> submitInsightFeedback(String insightId,
      {String? date, String? feedback, int? rating}) async {
    final user = _user;
    if (user == null) return false;

    try {
      await _callWithFunctionsFallback(
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

  /// Toggle favorite status for an insight
  Future<bool?> toggleFavoriteInsight(String insightId, {String? date}) async {
    final user = _user;
    if (user == null) return null;

    try {
      final result = await _callWithFunctionsFallback(
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

  /// Check if insight is favorited
  Future<bool> isInsightFavorite(String insightId) async {
    final user = _user;
    if (user == null) return false;

    try {
      final doc = await _firestore
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

  /// Clear backend caches
  /// [mode] can be 'all', 'ai', or 'old' (default)
  /// - all: Clear ALL backend caches (nuclear option)
  /// - ai: Clear only AI insight caches
  /// - old: Clear only old versioned caches (keeps current version)
  Future<Map<String, dynamic>?> clearBackendCaches(
      {String mode = 'old'}) async {
    final user = _user;
    if (user == null) return null;

    try {
      final result = await _callWithFunctionsFallback(
        functionName: 'clearAstroCaches',
        data: {'mode': mode},
      );

      if (result.data is Map) {
        final map = Map<String, dynamic>.from(result.data as Map);
        AppLogger.i('Backend caches cleared',
            category: LogCategory.network, data: map);

        // Also clear local caches
        clearLocalCaches();

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
