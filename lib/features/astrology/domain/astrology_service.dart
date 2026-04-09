import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'astrology/astrology_api.dart';

export 'astrology/astrology_api.dart';
export 'astrology/astrology_insights.dart';
export 'astrology/astrology_caching.dart';

class AstrologyService {
  AstrologyService._();

  static final AstrologyService _singleton = AstrologyService._();

  factory AstrologyService() => _singleton;

  // ---------------------------------------------------------------------------
  // Internal fields — exposed via getters so that `part` extension files can
  // access them (extensions cannot see class-private members).
  // ---------------------------------------------------------------------------

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String primaryFunctionsRegion = 'asia-southeast2';
  static const String fallbackFunctionsRegion = 'us-central1';

  final FirebaseFunctions _functionsPrimary =
      FirebaseFunctions.instanceFor(region: primaryFunctionsRegion);
  final FirebaseFunctions _functionsFallback =
      FirebaseFunctions.instanceFor(region: fallbackFunctionsRegion);

  static bool _lastAuthFailure = false;
  bool get lastAuthFailure => _lastAuthFailure;
  static void setLastAuthFailure(bool value) => _lastAuthFailure = value;

  /// Firestore instance (used by extension parts).
  FirebaseFirestore get firestore => _firestore;

  /// FirebaseAuth instance (used by extension parts).
  FirebaseAuth get auth => _auth;

  /// Primary Cloud Functions instance (used by extension parts).
  FirebaseFunctions get functionsPrimary => _functionsPrimary;

  /// Fallback Cloud Functions instance (used by extension parts).
  FirebaseFunctions get functionsFallback => _functionsFallback;

  /// Currently signed-in user, or `null`.
  User? get currentUser => _auth.currentUser;

  // Keep the old private getter for methods still in this file.
  User? get _user => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // Profile cache
  // ---------------------------------------------------------------------------

  static final Map<String, AstrologyProfile?> _profileCache = {};
  static final Map<String, String> _profileHashCache = {};

  /// Clear all local caches — call after force regenerate or sync.
  static void clearLocalCaches() {
    _profileCache.clear();
    _profileHashCache.clear();
    AppLogger.d('Local astrology caches cleared',
        category: LogCategory.database);
  }

  /// Clear cache for a specific user.
  static void clearUserCache(String uid) {
    _profileCache.remove(uid);
    _profileHashCache.remove(uid);
    AppLogger.d('Cleared cache for user $uid', category: LogCategory.database);
  }

  // ---------------------------------------------------------------------------
  // Profile CRUD
  // ---------------------------------------------------------------------------

  Future<AstrologyProfile?> getProfile(String uid,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _profileCache.containsKey(uid)) {
      final cached = _profileCache[uid];
      if (cached != null) return cached;
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
      return _profileCache[uid];
    }
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
          return _profileCache[uid];
        }

        final astroData = data['astrologyData'] as Map<String, dynamic>;
        final astroDataHash = astroData.toString();
        final lastHash = _profileHashCache[uid];

        if (lastHash == astroDataHash && _profileCache.containsKey(uid)) {
          return _profileCache[uid];
        }

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
        return _profileCache[uid];
      }
    }).handleError((error, stackTrace) {
      AppLogger.e(
        'Error in astrology profile stream',
        category: LogCategory.database,
        error: error,
        stackTrace: stackTrace,
      );
    }).distinct();
  }

  Future<bool> saveProfile(AstrologyProfile profile) async {
    final user = _user;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'astrologyData': {
          ...profile.toMap(),
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

  // ---------------------------------------------------------------------------
  // Sync & calculation
  // ---------------------------------------------------------------------------

  /// Calculate and save astrology data.
  ///
  /// [mode] controls how much data to fetch:
  /// - 'basic' (~3-4s): Essential data only (signs, dasha, yogas, doshas)
  /// - 'standard' (~6-8s): Basic + samvat, detailed dasha, panchang
  /// - 'full' (~15-17s): Everything including muhurat, navamsa, etc.
  Future<bool> calculateAndSaveAll(String uid, {String mode = 'basic'}) async {
    AppLogger.i('calculateAndSaveAll INVOKED',
        category: LogCategory.general, data: {'uid': uid, 'mode': mode});

    try {
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

      AstrologyProfile? profile = await getProfile(uid);

      if (profile == null || !profile.isComplete) {
        AppLogger.d('Profile not ready, waiting and retrying from Firestore',
            category: LogCategory.general);
        await Future.delayed(const Duration(milliseconds: 500));
        profile = await getProfile(uid, forceRefresh: true);
      }

      if (profile == null) {
        AppLogger.w('Profile is null after getProfile and retry',
            category: LogCategory.general,
            data: {
              'uid': uid,
              'cacheHasKey': _profileCache.containsKey(uid),
            });
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

      final synced = await syncAstroProfile(forceRefresh: true, mode: mode);

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

  /// Trigger a lazy background sync for more complete data.
  Future<void> triggerLazySync({String mode = 'standard'}) async {
    final user = _user;
    if (user == null) return;

    try {
      final profile = await getProfile(user.uid);
      if (profile == null) return;

      final currentStatus = profile.syncStatus ?? 'none';
      final statusOrder = {
        'none': 0,
        'partial': 1,
        'basic_complete': 2,
        'standard_complete': 3,
        'full_complete': 4,
      };
      final modeStatus =
          mode == 'full' ? 'full_complete' : 'standard_complete';

      final needsSamvatRefresh =
          mode == 'standard' && _isSamvatLikelyCurrent(profile);
      final shouldUpgrade =
          (statusOrder[modeStatus] ?? 0) > (statusOrder[currentStatus] ?? 0);
      if (!shouldUpgrade && !needsSamvatRefresh) return;

      syncAstroProfile(forceRefresh: needsSamvatRefresh, mode: mode)
          .catchError((_) => false);
    } catch (e) {
      AppLogger.w('Lazy sync trigger failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  bool _isSamvatLikelyCurrent(AstrologyProfile profile) {
    final samvat = profile.birthSamvatInfo;
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
    String mode = 'standard',
  }) async {
    final user = _user;
    if (user == null) {
      AppLogger.e('syncAstroProfile failed - no authenticated user',
          category: LogCategory.network);
      return false;
    }
    if (!await ensureAuthToken()) return false;

    clearUserCache(user.uid);

    AppLogger.i('syncAstroProfile calling Cloud Function',
        category: LogCategory.network,
        data: {'uid': user.uid, 'mode': mode, 'forceRefresh': forceRefresh});

    try {
      final result = await callWithFunctionsFallback(
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
}
