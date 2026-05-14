import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/astrology/domain/upcoming_event.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_calculator.dart';

export 'package:aurogram/features/astrology/domain/upcoming_event.dart';
export 'package:aurogram/features/astrology/domain/sky_positions_calculator.dart';

/// Service to fetch and cache global sky positions AND panchang
///
/// IMPORTANT: Panchang (Vedic date) is GLOBAL data - it's the same for everyone.
/// It does NOT depend on user's birth details. This service fetches it from
/// a global cache calculated at a standard reference location (Ujjain).
class SkyPositionsService {
  static final SkyPositionsService _instance = SkyPositionsService._internal();
  factory SkyPositionsService() => _instance;
  SkyPositionsService._internal();

  static const String _cacheKey = 'sky_positions_cache';
  static const String _panchangCacheKey = 'global_panchang_cache';
  static const String _eventsCacheKey = 'upcoming_events_cache';
  static const String _cacheTimestampKey = 'sky_positions_timestamp';
  static const String _eventsCacheTimestampKey = 'upcoming_events_timestamp';
  static const Duration _cacheValidity = Duration(hours: 12);
  static const Duration _eventsCacheValidity = Duration(hours: 6);

  Map<String, Map<String, dynamic>>? _positions;
  Map<String, Map<String, dynamic>>? _panchang;
  Map<String, dynamic>? _muhurat;
  String? _muhuratDateKey; // Track which date the muhurat is for
  List<UpcomingEvent>? _signIngresses;
  List<UpcomingEvent>? _retrogrades;
  bool _isLoadingEvents = false;
  bool _isLoadingMuhurat = false;
  Completer<bool>? _positionsLoadCompleter;

  // ---------------------------------------------------------------------------
  // Public API — position lookups
  // ---------------------------------------------------------------------------

  /// Get positions for a specific date
  /// Returns null if not available
  Map<String, dynamic>? getPositionsForDate(DateTime date) {
    if (_positions == null) {
      AppLogger.w(
        'getPositionsForDate: _positions is null',
        category: LogCategory.general,
        data: {'requestedDate': date.toIso8601String()},
      );
      return null;
    }

    final dateKey = _formatDateKey(date);
    final utcDateKey = _formatDateKey(date.toUtc());
    final availableKeys = _positions!.keys.toList()..sort();
    final sampleKeys = availableKeys.length > 5
        ? availableKeys.take(5).toList()
        : availableKeys;

    final result = _positions![dateKey];
    final utcResult = _positions![utcDateKey];

    AppLogger.d(
      'getPositionsForDate: Lookup attempt',
      category: LogCategory.general,
      data: {
        'requestedDate': date.toIso8601String(),
        'localDateKey': dateKey,
        'utcDateKey': utcDateKey,
        'localKeyFound': result != null,
        'utcKeyFound': utcResult != null,
        'localKeyPlanetCount': result?.length ?? 0,
        'utcKeyPlanetCount': utcResult?.length ?? 0,
        'totalAvailableKeys': availableKeys.length,
        'sampleAvailableKeys': sampleKeys,
        'localKeyPlanets': result?.keys.toList(),
        'utcKeyPlanets': utcResult?.keys.toList(),
      },
    );

    // Return local match if found (even if empty - let caller decide)
    if (result != null) {
      if (result.isEmpty) {
        AppLogger.w(
          'getPositionsForDate: Local key found but empty',
          category: LogCategory.general,
          data: {
            'localKey': dateKey,
            'utcKey': utcDateKey,
          },
        );
      }
      return result;
    }

    // Try UTC fallback if local not found
    if (utcResult != null) {
      AppLogger.d(
        'getPositionsForDate: Using UTC fallback',
        category: LogCategory.general,
        data: {
          'localKey': dateKey,
          'utcKey': utcDateKey,
          'planets': utcResult.keys.toList(),
          'planetCount': utcResult.length,
        },
      );
      return utcResult;
    }

    AppLogger.w(
      'getPositionsForDate: No match found',
      category: LogCategory.general,
      data: {
        'localKey': dateKey,
        'utcKey': utcDateKey,
        'availableKeys': sampleKeys,
        'totalKeys': availableKeys.length,
      },
    );

    return null;
  }

  /// Get interpolated positions for a specific datetime.
  /// Delegates to [SkyPositionsCalculator].
  Map<String, dynamic>? getInterpolatedPositions(DateTime dateTime) {
    return SkyPositionsCalculator.getInterpolatedPositions(
      dateTime,
      _positions,
      _formatDateKey,
    );
  }

  /// Check if data is loaded
  bool get isLoaded => _positions != null && _positions!.isNotEmpty;

  /// Get total days of data available
  int get availableDays => _positions?.length ?? 0;

  // ---------------------------------------------------------------------------
  // Public API — panchang
  // ---------------------------------------------------------------------------

  /// Get GLOBAL panchang (Vedic date) for today
  /// This is the SAME for all users - no birth data needed!
  Map<String, dynamic>? getTodayPanchang() {
    if (_panchang == null || _panchang!.isEmpty) return null;

    // Primary: local date key (legacy)
    final todayKey = _formatDateKey(DateTime.now());
    final localMatch = _panchang![todayKey];
    if (localMatch != null && localMatch.isNotEmpty) {
      return localMatch;
    }

    // Fallback: UTC date key (backend stores UTC keys)
    final utcKey = _formatDateKey(DateTime.now().toUtc());
    final utcMatch = _panchang![utcKey];
    if (utcMatch != null && utcMatch.isNotEmpty) {
      return utcMatch;
    }

    return localMatch ?? utcMatch;
  }

  /// Get GLOBAL panchang for a specific date
  Map<String, dynamic>? getPanchangForDate(DateTime date) {
    if (_panchang == null) return null;

    final dateKey = _formatDateKey(date);
    final localMatch = _panchang![dateKey];
    if (localMatch != null && localMatch.isNotEmpty) {
      return localMatch;
    }

    final utcKey = _formatDateKey(date.toUtc());
    final utcMatch = _panchang![utcKey];
    if (utcMatch != null && utcMatch.isNotEmpty) {
      return utcMatch;
    }

    return localMatch ?? utcMatch;
  }

  /// Check if global panchang data is available
  bool get hasPanchang => _panchang != null && _panchang!.isNotEmpty;

  /// Check if global muhurat data is available
  bool get hasMuhurat => _muhurat != null && _muhurat!.isNotEmpty;

  /// Get global muhurat data
  Map<String, dynamic>? get globalMuhurat => _muhurat;

  /// Debug helpers for global panchang
  String get todayPanchangKey => _formatDateKey(DateTime.now());
  List<String> get panchangKeys => _panchang?.keys.toList() ?? [];

  // ---------------------------------------------------------------------------
  // Public API — upcoming events
  // ---------------------------------------------------------------------------

  /// Get upcoming sign ingresses
  List<UpcomingEvent> get signIngresses => _signIngresses ?? [];

  /// Get upcoming retrogrades
  List<UpcomingEvent> get retrogrades => _retrogrades ?? [];

  /// Get all upcoming events sorted by date
  List<UpcomingEvent> get allUpcomingEvents {
    final all = <UpcomingEvent>[...signIngresses, ...retrogrades];
    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }

  /// Check if upcoming events are loaded
  bool get hasUpcomingEvents =>
      (_signIngresses != null && _signIngresses!.isNotEmpty) ||
      (_retrogrades != null && _retrogrades!.isNotEmpty);

  // ---------------------------------------------------------------------------
  // Fetch methods
  // ---------------------------------------------------------------------------

  /// Fetch upcoming events from backend
  Future<bool> fetchUpcomingEvents({bool forceRefresh = false}) async {
    if (_isLoadingEvents) return false;

    // Check memory cache
    if (!forceRefresh && hasUpcomingEvents) {
      return true;
    }

    // Try loading from local cache
    if (!forceRefresh) {
      final cached = await _loadEventsFromCache();
      if (cached) return true;
    }

    _isLoadingEvents = true;

    try {
      AppLogger.i('Fetching upcoming events from backend',
          category: LogCategory.general);

      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable('getUpcomingEvents');
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        // Parse sign ingresses
        final ingressList = data['signIngresses'] as List<dynamic>? ?? [];
        _signIngresses = ingressList
            .map((e) =>
                UpcomingEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        // Parse retrogrades
        final retroList = data['retrogrades'] as List<dynamic>? ?? [];
        _retrogrades = retroList
            .map((e) =>
                UpcomingEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        // Cache locally
        await _saveEventsToCache();

        AppLogger.i(
          'Upcoming events loaded',
          category: LogCategory.general,
          data: {
            'signIngresses': _signIngresses!.length,
            'retrogrades': _retrogrades!.length,
          },
        );

        return true;
      } else {
        AppLogger.w(
          'No upcoming events available from backend',
          category: LogCategory.general,
          data: {'error': data['error']},
        );
        return false;
      }
    } catch (e) {
      AppLogger.e(
        'Error fetching upcoming events',
        category: LogCategory.general,
        error: e,
      );
      return false;
    } finally {
      _isLoadingEvents = false;
    }
  }

  /// Fetch global muhurat with date-based cache validation
  /// Always shows 3 days from today - refetches when date changes
  Future<bool> fetchGlobalMuhurat({bool forceRefresh = false}) async {
    if (_isLoadingMuhurat) return false;

    final todayKey = _formatDateKey(DateTime.now());

    // Check if cached muhurat is still for today (date-based validation)
    if (!forceRefresh && hasMuhurat && _muhuratDateKey == todayKey) {
      AppLogger.d('Muhurat cache valid for today',
          category: LogCategory.general);
      return true;
    }

    _isLoadingMuhurat = true;

    try {
      // Try Firestore first (fast path)
      bool firestoreSucceeded = false;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('global_astro')
            .doc('muhurat')
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final dateKeys =
              (data['dateKeys'] as List<dynamic>?)?.cast<String>() ?? [];
          final isForToday = dateKeys.isNotEmpty && dateKeys[0] == todayKey;

          if (isForToday &&
              data['muhurat'] is Map &&
              (data['muhurat'] as Map).isNotEmpty) {
            _muhurat = Map<String, dynamic>.from(data['muhurat'] as Map);
            _muhuratDateKey = todayKey;
            AppLogger.d('Muhurat loaded from Firestore (valid for today)',
                category: LogCategory.general);
            return true;
          }
        }
        firestoreSucceeded = true; // Read worked but data was stale/empty
      } catch (e) {
        // Firestore may fail (e.g. permission-denied for unauthenticated users)
        // Fall through to Cloud Function
        AppLogger.d('Firestore muhurat read failed, trying Cloud Function',
            category: LogCategory.general, data: {'error': e.toString()});
      }

      // Firestore stale, empty, or failed - call Cloud Function to get fresh data
      AppLogger.d(
          firestoreSucceeded
              ? 'Muhurat cache stale, fetching fresh data'
              : 'Fetching muhurat via Cloud Function (Firestore unavailable)',
          category: LogCategory.general);

      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable(
        'getGlobalMuhurat',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call<Map<String, dynamic>>();
      final data = result.data;

      if (data['success'] == true && data['muhurat'] is Map) {
        _muhurat = Map<String, dynamic>.from(data['muhurat'] as Map);
        _muhuratDateKey = todayKey;
        AppLogger.i('Muhurat loaded via Cloud Function',
            category: LogCategory.general);
        return true;
      }

      AppLogger.w('Cloud Function returned no muhurat data',
          category: LogCategory.general);
      return false;
    } catch (e) {
      AppLogger.e('Error fetching muhurat',
          category: LogCategory.general, error: e);
      return false;
    } finally {
      _isLoadingMuhurat = false;
    }
  }

  /// Fetch positions AND global panchang from backend
  Future<bool> fetchPositions({bool forceRefresh = false}) async {
    if (_positionsLoadCompleter != null) {
      return _positionsLoadCompleter!.future;
    }

    // Check cache first
    if (!forceRefresh && _positions != null) {
      return true;
    }

    // Try loading from local cache
    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached) return true;
    }

    _positionsLoadCompleter = Completer<bool>();
    var success = false;

    try {
      AppLogger.i('Fetching sky positions and global panchang from backend',
          category: LogCategory.general);

      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable('getSkyPositions');
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true && data['positions'] != null) {
        final positionsMap = (data['positions'] as Map);
        _positions = Map<String, Map<String, dynamic>>.from(
          positionsMap.map(
            (key, value) => MapEntry(
                key as String, Map<String, dynamic>.from(value as Map)),
          ),
        );

        // Log what keys we received from backend
        final receivedKeys = _positions!.keys.toList()..sort();
        final now = DateTime.now();
        final localKey = _formatDateKey(now);
        final utcKey = _formatDateKey(now.toUtc());
        final hasLocalKey = _positions!.containsKey(localKey);
        final hasUtcKey = _positions!.containsKey(utcKey);

        AppLogger.i(
          'Sky positions fetched from backend',
          category: LogCategory.general,
          data: {
            'totalKeysReceived': receivedKeys.length,
            'sampleKeys': receivedKeys.length > 10
                ? receivedKeys.take(10).toList()
                : receivedKeys,
            'now': now.toIso8601String(),
            'localDateKey': localKey,
            'utcDateKey': utcKey,
            'hasLocalKey': hasLocalKey,
            'hasUtcKey': hasUtcKey,
            'localKeyPlanetCount':
                hasLocalKey ? _positions![localKey]?.length : 0,
            'utcKeyPlanetCount': hasUtcKey ? _positions![utcKey]?.length : 0,
            'localKeyPlanets':
                hasLocalKey ? _positions![localKey]?.keys.toList() : null,
            'utcKeyPlanets':
                hasUtcKey ? _positions![utcKey]?.keys.toList() : null,
          },
        );

        // Also load global panchang if available
        if (data['panchang'] != null && data['panchang'] is Map) {
          final panchangMap = data['panchang'] as Map;
          if (panchangMap.isNotEmpty) {
            _panchang = Map<String, Map<String, dynamic>>.from(
              panchangMap.map(
                (key, value) => MapEntry(
                    key as String, Map<String, dynamic>.from(value as Map)),
              ),
            );
            AppLogger.i('Global panchang loaded',
                category: LogCategory.general,
                data: {
                  'panchangDays': _panchang!.length,
                  'todayPanchang': getTodayPanchang() != null,
                  'keys': _panchang!.keys.take(3).toList(),
                });
          } else {
            AppLogger.w('Backend returned empty panchang',
                category: LogCategory.general);
          }
        } else {
          AppLogger.w('Backend returned no panchang data',
              category: LogCategory.general,
              data: {'panchangType': data['panchang']?.runtimeType.toString()});
        }

        // Cache locally
        await _saveToCache();

        AppLogger.i(
          'Sky positions loaded',
          category: LogCategory.general,
          data: {
            'positionDays': _positions!.length,
            'panchangDays': _panchang?.length ?? 0,
          },
        );

        // Auto-trigger prefetch if panchang is missing or today's entry is empty
        final todayPanchang = getTodayPanchang();
        if (_panchang == null ||
            _panchang!.isEmpty ||
            todayPanchang == null ||
            todayPanchang.isEmpty) {
          _triggerPrefetchForMissingPanchang();
        }

        success = true;
        return true;
      } else {
        AppLogger.w(
          'No sky positions available from backend',
          category: LogCategory.general,
          data: {'error': data['error']},
        );
        success = false;
        return false;
      }
    } catch (e) {
      AppLogger.e(
        'Error fetching sky positions',
        category: LogCategory.general,
        error: e,
      );
      success = false;
      return false;
    } finally {
      if (_positionsLoadCompleter != null &&
          !_positionsLoadCompleter!.isCompleted) {
        _positionsLoadCompleter!.complete(success);
      }
      _positionsLoadCompleter = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool> _loadEventsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_eventsCacheTimestampKey);

      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _eventsCacheValidity) {
        return false; // Cache expired
      }

      final cached = prefs.getString(_eventsCacheKey);
      if (cached == null) return false;

      final decoded = jsonDecode(cached) as Map<String, dynamic>;

      final ingressList = decoded['signIngresses'] as List<dynamic>? ?? [];
      _signIngresses = ingressList
          .map((e) =>
              UpcomingEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final retroList = decoded['retrogrades'] as List<dynamic>? ?? [];
      _retrogrades = retroList
          .map((e) =>
              UpcomingEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveEventsToCache() async {
    if (_signIngresses == null && _retrogrades == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'signIngresses': _signIngresses
                ?.map((e) => {
                      'planet': e.planet,
                      'type': e.type,
                      'date': e.date,
                      'fromSign': e.fromSign,
                      'toSign': e.toSign,
                      'description': e.description,
                    })
                .toList() ??
            [],
        'retrogrades': _retrogrades
                ?.map((e) => {
                      'planet': e.planet,
                      'type': e.type,
                      'date': e.date,
                      'description': e.description,
                    })
                .toList() ??
            [],
      };
      await prefs.setString(_eventsCacheKey, jsonEncode(data));
      await prefs.setInt(
          _eventsCacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Ignore cache save errors
    }
  }

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheValidity) {
        return false; // Cache expired
      }

      final cached = prefs.getString(_cacheKey);
      if (cached == null) return false;

      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      _positions = Map<String, Map<String, dynamic>>.from(
        decoded.map(
          (key, value) =>
              MapEntry(key, Map<String, dynamic>.from(value as Map)),
        ),
      );

      // Log what keys we loaded from cache
      final cachedKeys = _positions!.keys.toList()..sort();
      final now = DateTime.now();
      final localKey = _formatDateKey(now);
      final utcKey = _formatDateKey(now.toUtc());
      final hasLocalKey = _positions!.containsKey(localKey);
      final hasUtcKey = _positions!.containsKey(utcKey);

      AppLogger.i(
        'Sky positions loaded from cache',
        category: LogCategory.general,
        data: {
          'totalKeysInCache': cachedKeys.length,
          'sampleKeys': cachedKeys.length > 10
              ? cachedKeys.take(10).toList()
              : cachedKeys,
          'now': now.toIso8601String(),
          'localDateKey': localKey,
          'utcDateKey': utcKey,
          'hasLocalKey': hasLocalKey,
          'hasUtcKey': hasUtcKey,
          'localKeyPlanetCount':
              hasLocalKey ? _positions![localKey]?.length : 0,
          'utcKeyPlanetCount': hasUtcKey ? _positions![utcKey]?.length : 0,
        },
      );

      // Also load panchang cache
      final panchangCached = prefs.getString(_panchangCacheKey);
      if (panchangCached != null) {
        final panchangDecoded =
            jsonDecode(panchangCached) as Map<String, dynamic>;
        _panchang = Map<String, Map<String, dynamic>>.from(
          panchangDecoded.map(
            (key, value) =>
                MapEntry(key, Map<String, dynamic>.from(value as Map)),
          ),
        );
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveToCache() async {
    if (_positions == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_positions));
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);

      // Also cache panchang
      if (_panchang != null) {
        await prefs.setString(_panchangCacheKey, jsonEncode(_panchang));
      }
    } catch (e) {
      // Ignore cache save errors
    }
  }

  /// One-time trigger to populate panchang when missing
  /// This calls prefetchSkyPositions then reloads data
  static bool _prefetchTriggered = false;

  Future<void> _triggerPrefetchForMissingPanchang() async {
    if (_prefetchTriggered) return;
    _prefetchTriggered = true;

    AppLogger.i('Triggering prefetch to populate missing panchang',
        category: LogCategory.general);

    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable('prefetchSkyPositions');
      await callable.call();

      AppLogger.i('Prefetch completed, reloading data',
          category: LogCategory.general);

      // Clear cache and reload
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_panchangCacheKey);
      await prefs.remove(_cacheTimestampKey);

      // Reload from backend
      await fetchPositions(forceRefresh: true);
    } catch (e) {
      AppLogger.e('Failed to trigger prefetch',
          category: LogCategory.general, error: e);
    }
  }
}
