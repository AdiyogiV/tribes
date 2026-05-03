import 'dart:async';
import 'package:flutter/services.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Bridge to Apple Watch companion app via platform channel.
///
/// Sends data TO the watch:
///   - Panchang (Vedic date, samvat year)
///   - Profile (Prakriti type, dosha percentages)
///   - Daily Insight (theme, message)
///
/// Receives data FROM the watch:
///   - Nadi readings (dominant dosha, HRV, RHR)
///   - Sync requests (watch asking for fresh data)
///
/// Usage:
///   WatchService.instance.sendPanchang(samvat);
///   WatchService.instance.onWatchData.listen((data) { ... });
///
/// Platform: iOS only. On Android, all methods are no-ops.
class WatchService {
  WatchService._();
  static final instance = WatchService._();

  static const _channel = MethodChannel('com.canay.dhaara/watch');

  /// Stream of data received from the watch.
  final _watchDataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onWatchData => _watchDataController.stream;

  bool _initialized = false;

  /// Initialize the watch service. Call once at app startup.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWatchData') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        AppLogger.i('WatchService: received data from watch',
            category: LogCategory.general,
            data: {'type': data['type'], 'keys': data.keys.toList()});
        _watchDataController.add(data);
      }
    });

    AppLogger.i('WatchService: initialized', category: LogCategory.general);
  }

  /// Check if a watch is paired and the companion app is installed.
  Future<bool> isWatchPaired() async {
    try {
      final result = await _channel.invokeMethod<bool>('isWatchPaired');
      return result ?? false;
    } on MissingPluginException {
      // Not on iOS or watch channel not available
      return false;
    } catch (e) {
      AppLogger.w('WatchService: isWatchPaired failed',
          category: LogCategory.general, data: {'error': e.toString()});
      return false;
    }
  }

  /// Send panchang data to the watch.
  ///
  /// Call this when today's panchang is loaded (from DailyInsight or SkyPositionsService).
  Future<void> sendPanchang(Map<String, dynamic>? samvat) async {
    if (samvat == null) return;
    try {
      await _channel.invokeMethod('sendPanchang', {
        'vedicDate': _buildVedicDate(samvat),
        'samvatYear': _buildSamvatYear(samvat),
        'vedicNumericDate': _buildNumericDate(samvat),
      });
    } on MissingPluginException {
      // Not on iOS
    } catch (e) {
      AppLogger.w('WatchService: sendPanchang failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Send Prakriti profile to the watch.
  ///
  /// Call this when the Ayurveda profile loads or changes.
  Future<void> sendProfile({
    required String? prakritiType,
    required int vata,
    required int pitta,
    required int kapha,
  }) async {
    try {
      await _channel.invokeMethod('sendProfile', {
        'prakritiType': prakritiType,
        'prakritiVata': vata,
        'prakritiPitta': pitta,
        'prakritiKapha': kapha,
      });
    } on MissingPluginException {
      // Not on iOS
    } catch (e) {
      AppLogger.w('WatchService: sendProfile failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Send daily insight to the watch.
  ///
  /// Call this when a new daily insight is generated or loaded.
  Future<void> sendInsight({
    required String? theme,
    required String? message,
  }) async {
    try {
      await _channel.invokeMethod('sendInsight', {
        'theme': theme,
        'message': message,
      });
    } on MissingPluginException {
      // Not on iOS
    } catch (e) {
      AppLogger.w('WatchService: sendInsight failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Send muhurat time windows to the watch.
  ///
  /// Call this when muhurat data is loaded from the backend.
  /// [windows] is a list of maps with: name, start, end, type.
  Future<void> sendMuhurat(List<Map<String, String>> windows) async {
    if (windows.isEmpty) return;
    try {
      await _channel.invokeMethod('sendMuhurat', {
        'windows': windows,
      });
    } on MissingPluginException {
      // Not on iOS
    } catch (e) {
      AppLogger.w('WatchService: sendMuhurat failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Send sky positions (planet data) to the watch.
  ///
  /// Call this when sky positions are loaded from the backend.
  /// `positions` is a map where keys are planet names.
  Future<void> sendSkyPositions(Map<String, dynamic> positions) async {
    if (positions.isEmpty) return;
    try {
      // Convert to list of planet maps for easy consumption on watch
      final planets = <Map<String, dynamic>>[];
      for (final entry in positions.entries) {
        final data = entry.value;
        if (data is Map) {
          planets.add({
            'name': entry.key,
            'longitude': data['longitude'] ?? data['fullDegree'] ?? 0.0,
            'sign': data['sign'] ?? '',
            'signDegree': data['signDegree'] ?? data['normDegree'] ?? 0.0,
            'isRetro': data['isRetro'] ?? false,
            'nakshatra': data['nakshatra'] ?? '',
          });
        }
      }
      AppLogger.i('WatchService: sending sky positions',
          category: LogCategory.general,
          data: {'planetCount': planets.length, 'planetNames': planets.map((p) => p['name']).toList()});
      await _channel.invokeMethod('sendSky', {
        'type': 'sky',
        'planets': planets,
      });
    } on MissingPluginException {
      // Not on iOS
    } catch (e) {
      AppLogger.w('WatchService: sendSkyPositions failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Send dosha-aware health recommendations to the watch.
  ///
  /// Called after the backend analyzes a health snapshot and generates
  /// personalized guidance. [recs] contains 'dosha', 'items', 'basedOn'.
  Future<void> sendRecommendations(Map<String, dynamic> recs) async {
    try {
      await _channel.invokeMethod('sendRecommendations', {
        'type': 'recommendations',
        ...recs,
      });
      AppLogger.d('WatchService: sent recommendations to watch',
          category: LogCategory.general,
          data: {'dosha': recs['dosha'], 'items': (recs['items'] as List?)?.length ?? 0});
    } on MissingPluginException {
      // Not on iOS
    } catch (e) {
      AppLogger.w('WatchService: sendRecommendations failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Dispose resources.
  void dispose() {
    _watchDataController.close();
  }

  // MARK: - Muhurat Window Extraction (shared between bootstrap and dashboard)

  /// Parse muhurat backend data into watch-friendly window list.
  /// Static so it can be called from bootstrap without a widget.
  static List<Map<String, String>> extractMuhuratWindows(
      Map<String, dynamic> muhurat) {
    final windows = <Map<String, String>>[];

    final days = muhurat['days'] as Map?;
    if (days == null || days.isEmpty) return windows;

    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    Map<String, dynamic>? dayData;
    if (days.containsKey(todayKey)) {
      dayData = Map<String, dynamic>.from(days[todayKey] as Map);
    } else if (days.isNotEmpty) {
      dayData = Map<String, dynamic>.from(days.values.first as Map);
    }
    if (dayData == null) return windows;

    final types = [
      {'key': 'rahuKala', 'name': 'Rahu Kala', 'type': 'inauspicious', 'fallback': 'rahu_kala'},
      {'key': 'gulikaKala', 'name': 'Gulika Kala', 'type': 'inauspicious', 'fallback': 'gulika_kala'},
      {'key': 'yamaganda', 'name': 'Yamaganda', 'type': 'inauspicious', 'fallback': 'yamagandaKala'},
      {'key': 'varjyam', 'name': 'Varjyam', 'type': 'inauspicious'},
      {'key': 'abhijit', 'name': 'Abhijit Muhurat', 'type': 'auspicious'},
      {'key': 'amrit', 'name': 'Amrit Kaal', 'type': 'auspicious', 'fallback': 'amritKaal'},
      {'key': 'brahmaMuhurat', 'name': 'Brahma Muhurat', 'type': 'auspicious'},
    ];

    for (final mt in types) {
      final timeData = dayData[mt['key']] ??
          (mt['fallback'] != null ? dayData[mt['fallback']] : null);
      if (timeData is! Map) continue;
      final timeMap = Map<String, dynamic>.from(timeData);
      final startsAt = timeMap['starts_at']?.toString() ??
          timeMap['startsAt']?.toString();
      final endsAt =
          timeMap['ends_at']?.toString() ?? timeMap['endsAt']?.toString();
      if (startsAt != null && endsAt != null) {
        windows.add({
          'name': mt['name']!,
          'start': _to24h(startsAt),
          'end': _to24h(endsAt),
          'type': mt['type']!,
        });
      }
    }

    return windows;
  }

  /// Convert "7:30 AM" / "02:30 PM" → "07:30" / "14:30".
  static String _to24h(String time) {
    final cleaned = time.trim().toUpperCase();
    final isPM = cleaned.contains('PM');
    final isAM = cleaned.contains('AM');
    final numPart = cleaned.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = numPart.split(':');
    if (parts.length < 2) return time;
    var h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (isPM && h != 12) h += 12;
    if (isAM && h == 12) h = 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // MARK: - Helpers (mirrors VedicTimeUtils logic for building display strings)

  String? _buildVedicDate(Map<String, dynamic> samvat) {
    final lunarMonth = samvat['lunar_month_full_name']?.toString() ??
        samvat['lunar_month_name']?.toString() ??
        samvat['lunarMonth']?.toString();
    final tithi = samvat['name']?.toString() ??
        samvat['tithi_name']?.toString() ??
        samvat['tithi']?.toString();
    final paksha = samvat['paksha']?.toString() ??
        samvat['tithiPaksha']?.toString();

    if (lunarMonth != null && tithi != null) {
      final p = paksha != null ? '$paksha ' : '';
      return '$lunarMonth $p$tithi';
    }
    return tithi;
  }

  String? _buildSamvatYear(Map<String, dynamic> samvat) {
    final name = samvat['vikram_chaitradi_year_name']?.toString();
    if (name != null) return 'Vikram Samvat $name';
    final number = samvat['vikram_chaitradi_number'];
    if (number != null) return 'Vikram Samvat $number';
    return null;
  }

  String? _buildNumericDate(Map<String, dynamic> samvat) {
    // Simplified — phone can compute and send the full numeric date
    return null;
  }
}
