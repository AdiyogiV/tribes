import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/astrology/data/utils/nakshatra_data.dart';

/// Compact daily snapshot from the astro calendar.
///
/// Fields mirror the backend's compact format:
///   n  = nakshatra index (0-26), t = tithi number (1-30),
///   p  = paksha (0=shukla, 1=krishna), y = yoga index (0-26),
///   k  = karana index (0-10), m = planet longitudes [Mo,Su,Ma,Me,Ju,Ve,Sa,Ra,Ke],
///   r  = retrograde flags (same order as m),
///   mu = muhurat {r:[s,e], g:[s,e], y:[s,e], a:[s,e], ...} in minutes.
class CalendarDay {
  final int? nakshatraIndex;
  final int? tithiNumber;
  final int? paksha; // 0=shukla, 1=krishna
  final int? yogaIndex;
  final int? karanaIndex;
  final List<double?>? longitudes; // [Mo,Su,Ma,Me,Ju,Ve,Sa,Ra,Ke]
  final List<bool>? retrogrades;

  /// Compact muhurat: keys are short codes (r, g, y, v, a, am, b, d),
  /// values are [startMinutes, endMinutes] from midnight.
  final Map<String, List<int>>? muhurat;

  /// Lunar month number (1 = Chaitra … 12 = Phalguna) from the backend.
  final int? lunarMonthNum;

  /// Raw lunar month name from API (e.g. "Adhika Jyeshtam", "Ashadam").
  /// Adhika detection = starts with "Adhika". No guesswork.
  final String? lunarMonthRaw;

  const CalendarDay({
    this.nakshatraIndex,
    this.tithiNumber,
    this.paksha,
    this.yogaIndex,
    this.karanaIndex,
    this.longitudes,
    this.retrogrades,
    this.muhurat,
    this.lunarMonthNum,
    this.lunarMonthRaw,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    List<double?>? lngs;
    if (json['m'] is List) {
      lngs = (json['m'] as List).map((v) => v is num ? v.toDouble() : null).toList();
    }
    List<bool>? retros;
    if (json['r'] is List) {
      retros = (json['r'] as List).map((v) => v == true).toList();
    }
    // Parse compact muhurat: { "r": [630, 720], "g": [450, 540], ... }
    Map<String, List<int>>? mu;
    if (json['mu'] is Map) {
      mu = {};
      for (final entry in (json['mu'] as Map).entries) {
        if (entry.value is List && (entry.value as List).length >= 2) {
          final list = entry.value as List;
          final s = list[0] is num ? (list[0] as num).toInt() : 0;
          final e = list[1] is num ? (list[1] as num).toInt() : 0;
          mu[entry.key.toString()] = [s, e];
        }
      }
      if (mu.isEmpty) mu = null;
    }
    return CalendarDay(
      nakshatraIndex: json['n'] as int?,
      tithiNumber: json['t'] as int?,
      paksha: json['p'] as int?,
      yogaIndex: json['y'] as int?,
      karanaIndex: json['k'] as int?,
      longitudes: lngs,
      retrogrades: retros,
      muhurat: mu,
      lunarMonthNum: json['lm'] as int?,
      lunarMonthRaw: json['ln'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (nakshatraIndex != null) map['n'] = nakshatraIndex;
    if (tithiNumber != null) map['t'] = tithiNumber;
    if (paksha != null) map['p'] = paksha;
    if (yogaIndex != null) map['y'] = yogaIndex;
    if (karanaIndex != null) map['k'] = karanaIndex;
    if (longitudes != null) map['m'] = longitudes;
    if (retrogrades != null) map['r'] = retrogrades;
    if (muhurat != null) map['mu'] = muhurat;
    if (lunarMonthNum != null) map['lm'] = lunarMonthNum;
    if (lunarMonthRaw != null) map['ln'] = lunarMonthRaw;
    return map;
  }

  /// Effective nakshatra index — uses the backend value when available,
  /// otherwise derives it from the Moon's sidereal longitude (index 0 in
  /// [longitudes]).  Each nakshatra spans 360/27 = 13°20′.
  int? get effectiveNakshatraIndex {
    if (nakshatraIndex != null) return nakshatraIndex;
    final moonLng = (longitudes != null && longitudes!.isNotEmpty)
        ? longitudes![0]
        : null;
    if (moonLng == null) return null;
    return (moonLng / (360.0 / 27.0)).floor() % 27;
  }

  /// Get nakshatra name from index.
  String? get nakshatraName {
    final idx = effectiveNakshatraIndex;
    return idx != null && idx >= 0 && idx < 27
        ? NakshatraData.all[idx].name
        : null;
  }

  /// Build a positions map compatible with CosmicSkyChartCard.
  /// Keys are planet names, values have { longitude, sign, signDegree, isRetro }.
  Map<String, dynamic>? get positionsMap {
    if (longitudes == null) return null;
    const names = ['Moon', 'Sun', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu'];
    const signs = [
      'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
      'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
    ];
    final result = <String, dynamic>{};
    for (int i = 0; i < names.length && i < longitudes!.length; i++) {
      final lng = longitudes![i];
      if (lng == null) continue;
      final signIdx = (lng / 30).floor() % 12;
      result[names[i]] = {
        'longitude': lng,
        'sign': signs[signIdx],
        'signDegree': lng % 30,
        'isRetro': retrogrades != null && i < retrogrades!.length && retrogrades![i],
      };
    }
    return result.isNotEmpty ? result : null;
  }

  // Yoga names (must match backend YOGA_NAMES order).
  static const _yogaNames = [
    'Vishkambha', 'Priti', 'Ayushman', 'Saubhagya', 'Shobhana', 'Atiganda',
    'Sukarma', 'Dhriti', 'Shula', 'Ganda', 'Vriddhi', 'Dhruva', 'Vyaghata',
    'Harshana', 'Vajra', 'Siddhi', 'Vyatipata', 'Variyan', 'Parigha', 'Shiva',
    'Siddha', 'Sadhya', 'Shubha', 'Shukla', 'Brahma', 'Indra', 'Vaidhriti',
  ];

  // Karana names (must match backend KARANA_NAMES order).
  static const _karanaNames = [
    'Bava', 'Balava', 'Kaulava', 'Taitila', 'Gara', 'Vanija', 'Vishti',
    'Shakuni', 'Chatushpada', 'Naga', 'Kimstughna',
  ];

  /// Yoga name from index.
  String? get yogaName =>
      yogaIndex != null && yogaIndex! >= 0 && yogaIndex! < 27
          ? _yogaNames[yogaIndex!]
          : null;

  /// Karana name from index.
  String? get karanaName =>
      karanaIndex != null && karanaIndex! >= 0 && karanaIndex! < 11
          ? _karanaNames[karanaIndex!]
          : null;

  // Tithi names (1-based, 15 per paksha).
  static const _tithiNames = [
    'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami',
    'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami',
    'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi', 'Purnima',
  ];

  /// Tithi name from number.  Handles continuous 1-30 numbering:
  /// 1-15 = Shukla tithis, 16-29 = Krishna equivalents, 30 = Amavasya.
  String? get tithiName {
    if (tithiNumber == null) return null;
    if (tithiNumber == 30) return 'Amavasya';
    final n = tithiNumber! > 15 ? tithiNumber! - 15 : tithiNumber!;
    if (n >= 1 && n <= 15) return _tithiNames[n - 1];
    return null;
  }

  // Sanskrit display names (1 = Chaitra through 12 = Phalguna).
  static const _lunarMonthNames = [
    'Chaitra', 'Vaishakha', 'Jyeshtha', 'Ashadha',
    'Shravana', 'Bhadrapada', 'Ashvina', 'Kartika',
    'Margashirsha', 'Pausha', 'Magha', 'Phalguna',
  ];

  /// Whether this is an Adhika (intercalary) month — derived from raw API name.
  bool get isAdhikaMasa =>
      lunarMonthRaw?.toLowerCase().startsWith('adhika') ?? false;

  /// Sanskrit display name for the lunar month.
  /// lm=3 + "Adhika Jyeshtam" → "Adhika Jyeshtha"
  /// lm=3 + "Nija Jyeshtam"  → "Jyeshtha"
  /// lm=4 + "Ashadam"         → "Ashadha"
  String? get lunarMonthDisplayName {
    if (lunarMonthNum == null ||
        lunarMonthNum! < 1 ||
        lunarMonthNum! > 12) {
      return null;
    }
    final base = _lunarMonthNames[lunarMonthNum! - 1];
    return isAdhikaMasa ? 'Adhika $base' : base;
  }

  /// Build a panchang map compatible with VedicTimeUtils.
  Map<String, dynamic> get panchangMap {
    final map = <String, dynamic>{};
    if (nakshatraName != null) map['nakshatra'] = nakshatraName;
    if (tithiNumber != null) {
      map['tithi_number'] = tithiNumber;
      map['number'] = tithiNumber;
    }
    if (tithiName != null) map['name'] = tithiName;
    if (paksha != null) map['paksha'] = paksha == 0 ? 'Shukla' : 'Krishna';
    if (yogaName != null) map['yoga'] = yogaName;
    if (karanaName != null) map['karana'] = karanaName;

    // Lunar month — straight from backend, no guessing
    if (lunarMonthDisplayName != null) {
      map['lunar_month_full_name'] = lunarMonthDisplayName;
      map['lunar_month_number'] = lunarMonthNum;
      if (isAdhikaMasa) map['is_adhika_masa'] = true;
    }

    return map;
  }

  /// Muhurat short-code → full event name mapping.
  static const _muhuratNames = {
    'r': 'Rahu Kala',
    'g': 'Gulika Kala',
    'y': 'Yamaganda',
    'v': 'Varjyam',
    'a': 'Abhijit Muhurat',
    'am': 'Amrit Kaal',
    'b': 'Brahma Muhurat',
    'd': 'Dur Muhurat',
  };

  /// Muhurat short-code → type (auspicious/inauspicious).
  static const _muhuratTypes = {
    'r': 'inauspicious',
    'g': 'inauspicious',
    'y': 'inauspicious',
    'v': 'inauspicious',
    'd': 'inauspicious',
    'a': 'auspicious',
    'am': 'auspicious',
    'b': 'auspicious',
  };

  /// Convert minutes-from-midnight to "HH:MM" string.
  static String _minutesToTimeStr(int minutes) {
    final h = (minutes ~/ 60).clamp(0, 23);
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Build a muhurat map compatible with [MuhuratTimelineWidget].
  ///
  /// Returns a structure the widget's "days" fallback path can consume:
  /// ```
  /// { 'days': { dateKey: { 'rahuKala': {starts_at, ends_at}, ... } },
  ///   'unifiedTimeline': { events: [...], startTime, endTime, dateKeys } }
  /// ```
  ///
  /// [dateKey] is the "yyyy-MM-dd" key for the date this entry represents.
  Map<String, dynamic>? buildMuhuratWidgetMap(String dateKey) {
    if (muhurat == null || muhurat!.isEmpty) return null;

    // Build day-level data (starts_at / ends_at strings).
    final dayData = <String, dynamic>{};
    // Build unified timeline events.
    final events = <Map<String, dynamic>>[];

    // Short-code → camelCase key mapping for the days format.
    const codeToKey = {
      'r': 'rahuKala', 'g': 'gulikaKala', 'y': 'yamaganda',
      'v': 'varjyam', 'a': 'abhijit', 'am': 'amrit',
      'b': 'brahmaMuhurat', 'd': 'durMuhurat',
    };

    for (final entry in muhurat!.entries) {
      final code = entry.key;
      final pair = entry.value;
      if (pair.length < 2) continue;

      final start = pair[0];
      // Handle windows that wrap past midnight (e.g. Varjyam 23:00—01:30):
      // push the end into the next day so the bar/bounds stay sensible
      // instead of producing a negative-width bar that crushes the timeline.
      final end = pair[1] >= start ? pair[1] : pair[1] + 1440;

      final startStr = _minutesToTimeStr(start);
      final endStr = _minutesToTimeStr(pair[1]);

      final key = codeToKey[code] ?? code;
      dayData[key] = {'starts_at': startStr, 'ends_at': endStr};

      events.add({
        'name': _muhuratNames[code] ?? code,
        'start': start,
        'end': end,
        'type': _muhuratTypes[code] ?? 'inauspicious',
        'dateKey': dateKey,
      });
    }

    if (dayData.isEmpty) return null;

    // Sort events by start time.
    events.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    // Compute tight bounds from actual events (matching the backend's
    // processUnifiedTimeline behaviour).  The old hardcoded 0–1440 (full
    // 24h) wasted half the timeline as empty space because most muhurat
    // events fall between ~4 AM and ~6 PM, making them look clustered on
    // narrow phone screens.
    int minStart = 1440;
    int maxEnd = 0;
    for (final e in events) {
      final s = e['start'] as int;
      final en = e['end'] as int;
      if (s < minStart) minStart = s;
      if (en > maxEnd) maxEnd = en;
    }
    // Align to hours with 1-hour padding on each side.
    final startTime = ((minStart ~/ 60) - 1).clamp(0, 23) * 60;
    final endTime = ((maxEnd ~/ 60) + 2).clamp(1, 24) * 60;

    return {
      'days': {dateKey: dayData},
      'unifiedTimeline': {
        'events': events,
        'startTime': startTime,
        'endTime': endTime,
        'dateKeys': [dateKey],
      },
      'dateKeys': [dateKey],
      'timeZoneId': 'Asia/Kolkata',
    };
  }
}

/// Lightweight singleton that serves a full year of daily astro snapshots.
///
/// - Fetches from `astroGateway.getAstroCalendar` (one call)
/// - Caches in SharedPreferences with a 7-day TTL
/// - Provides instant lookups: `getDay(date)`, `getNakshatraIndex(date)`, etc.
/// - Falls back to sidereal-period math for dates outside the cached range.
class AstroCalendarService {
  static final AstroCalendarService _instance = AstroCalendarService._internal();
  factory AstroCalendarService() => _instance;
  AstroCalendarService._internal();

  // NOTE: cache key bumped to v3 to invalidate stale calendars that were
  // built BEFORE the full 365-day forward window (positions/panchang/muhurat)
  // was populated in Firestore — those short calendars made forward cards
  // vanish. Old 'astro_calendar_cache(_v2)' entries are ignored after this bump.
  static const String _cacheKey = 'astro_calendar_cache_v3';
  static const String _cacheTimestampKey = 'astro_calendar_timestamp_v3';
  // Shorter TTL so a partially-filled calendar self-corrects within a day
  // instead of being pinned for a week.
  static const Duration _cacheValidity = Duration(days: 1);

  /// In-memory calendar: date key → compact day.
  Map<String, CalendarDay>? _calendar;

  /// True while a fetch is in progress.
  bool _isLoading = false;
  Completer<bool>? _loadCompleter;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Whether calendar data is available.
  bool get isLoaded => _calendar != null && _calendar!.isNotEmpty;

  /// Total days of data available.
  int get availableDays => _calendar?.length ?? 0;

  /// Get the calendar entry for a specific date.
  CalendarDay? getDay(DateTime date) {
    if (_calendar == null) return null;
    final key = _formatDateKey(date);
    return _calendar![key] ?? _calendar![_formatDateKey(date.toUtc())];
  }

  /// Get the nakshatra index for a date, with sidereal-period fallback.
  ///
  /// [todayIndex] is used as the anchor for the fallback calculation.
  int getNakshatraIndex(DateTime date, {required int todayIndex}) {
    final day = getDay(date);
    if (day?.effectiveNakshatraIndex != null) return day!.effectiveNakshatraIndex!;

    // Fallback: sidereal-period approximation.
    // Moon completes 27 nakshatras in ~27.3217 days.
    final today = DateTime.now();
    final daysDelta = date.difference(DateTime(today.year, today.month, today.day)).inDays;
    final nakshatraOffset = (daysDelta * 27 / 27.3217).round();
    return (todayIndex + nakshatraOffset) % 27;
  }

  /// Get planet positions for a date (for the sky chart).
  /// Returns a map compatible with `CosmicSkyChartCard` expectations.
  Map<String, dynamic>? getPositionsForDate(DateTime date) {
    return getDay(date)?.positionsMap;
  }

  /// Get panchang data for a date, enriched with derived Vikram year.
  ///
  /// The returned map is compatible with `VedicTimeUtils` — it includes
  /// tithi name, lunar month, paksha, and Vikram Samvat year so that
  /// `buildFullVedicDate` and `buildVedicNumericDate` render correctly.
  Map<String, dynamic>? getPanchangForDate(DateTime date) {
    final day = getDay(date);
    if (day == null) return null;
    final map = day.panchangMap;
    if (map.isEmpty) return null;

    // Compute approximate Vikram Samvat year.
    // Hindu new year (Chaitra Shukla Pratipada) falls in March-April.
    // Use March 22 as a rough boundary — accurate for most years.
    final vikramYear = (date.month > 3 || (date.month == 3 && date.day >= 22))
        ? date.year + 57
        : date.year + 56;
    map['vikram_chaitradi_number'] = vikramYear;

    return map;
  }

  /// Get muhurat widget data for a date, ready for [MuhuratTimelineWidget].
  /// Returns null if no muhurat data is available for the given date.
  Map<String, dynamic>? getMuhuratForDate(DateTime date) {
    final day = getDay(date);
    if (day == null) return null;
    final key = _formatDateKey(date);
    return day.buildMuhuratWidgetMap(key);
  }

  // ---------------------------------------------------------------------------
  // Fetch & cache
  // ---------------------------------------------------------------------------

  /// Fetch the calendar from the backend. Returns true on success.
  /// Safe to call multiple times — deduplicates concurrent calls.
  Future<bool> fetchCalendar({bool forceRefresh = false}) async {
    // If already loaded and not forcing refresh, check cache freshness
    if (_calendar != null && !forceRefresh) {
      final isFresh = await _isCacheFresh();
      if (isFresh) return true;
    }

    // Deduplicate concurrent calls
    if (_isLoading && _loadCompleter != null) {
      return _loadCompleter!.future;
    }

    _isLoading = true;
    _loadCompleter = Completer<bool>();

    try {
      // Try local cache first (unless forcing refresh)
      if (!forceRefresh) {
        final cached = await _loadFromCache();
        if (cached) {
          _isLoading = false;
          _loadCompleter!.complete(true);
          return true;
        }
      }

      // Fetch from backend
      AppLogger.i('Fetching astro calendar from backend',
          category: LogCategory.general);

      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable('astroGateway');
      final result = await callable.call({'method': 'getAstroCalendar'});

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true && data['calendar'] != null) {
        final calendarMap = data['calendar'] as Map;
        _calendar = {};
        for (final entry in calendarMap.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is Map) {
            _calendar![key] = CalendarDay.fromJson(Map<String, dynamic>.from(value));
          }
        }

        await _saveToCache();

        AppLogger.i('Astro calendar loaded', category: LogCategory.general, data: {
          'days': _calendar!.length,
          'dateRange': data['dateRange'],
        });

        _isLoading = false;
        _loadCompleter!.complete(true);
        return true;
      } else {
        AppLogger.w('No astro calendar available from backend',
            category: LogCategory.general, data: {'error': data['error']});
        _isLoading = false;
        _loadCompleter!.complete(false);
        return false;
      }
    } catch (e) {
      AppLogger.e('Error fetching astro calendar',
          category: LogCategory.general, error: e);

      // Try falling back to local cache on network error
      if (_calendar == null) {
        await _loadFromCache();
      }

      _isLoading = false;
      _loadCompleter!.complete(_calendar != null);
      return _calendar != null;
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

  Future<bool> _isCacheFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return false;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime) < _cacheValidity;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheValidity) return false;

      final cached = prefs.getString(_cacheKey);
      if (cached == null) return false;

      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      _calendar = {};
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          _calendar![entry.key] = CalendarDay.fromJson(
              Map<String, dynamic>.from(entry.value as Map));
        }
      }

      AppLogger.i('Astro calendar loaded from cache',
          category: LogCategory.general, data: {'days': _calendar!.length});
      return _calendar!.isNotEmpty;
    } catch (e) {
      AppLogger.w('Failed to load astro calendar from cache',
          category: LogCategory.general);
      return false;
    }
  }

  Future<void> _saveToCache() async {
    if (_calendar == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = <String, dynamic>{};
      for (final entry in _calendar!.entries) {
        encoded[entry.key] = entry.value.toJson();
      }
      await prefs.setString(_cacheKey, jsonEncode(encoded));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.w('Failed to save astro calendar to cache',
          category: LogCategory.general);
    }
  }
}
