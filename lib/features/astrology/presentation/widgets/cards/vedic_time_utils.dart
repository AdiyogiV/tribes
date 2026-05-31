import 'package:aurogram/core/logging/app_logger.dart';

/// Utility class for Vedic time calculations.
///
/// IMPORTANT — Birth Date vs Today's Date:
/// This class has TWO distinct use cases that must NEVER be mixed:
///
/// 1. **TODAY's Vedic Date** (HolyCow page, cosmic dashboard):
///    - Data source: `DailyInsight.astrologicalData['todaySamvat']` + `['panchang']`
///    - Or: `SkyPositionsService.getTodayPanchang()` (global panchang)
///    - Use [buildFullVedicDate] and [buildSamvatYear] (validates against current year)
///
/// 2. **BIRTH Vedic Date** (astrology details page, samvat card):
///    - Data source: `AstrologyProfile.birthSamvatInfo`
///    - Use [buildFullVedicDate] and [buildBirthSamvatYear] (no year validation)
///    - Use [filterBirthSamvat] to verify data matches birth date
class VedicTimeUtils {
  /// Calculate Vedic time details (Prahar, Ghati, Pala)
  /// Uses 8 Prahar system: 8 consecutive prahars from sunrise to sunrise
  /// Each Prahar = 3 hours (180 minutes). Also shows Ghati (1 Ghati = 24 minutes)
  /// IMPORTANT: Vedic time is calculated from sunrise, not midnight
  ///
  /// KNOWN LIMITATION: Uses hardcoded sunrise (6 AM).
  /// Real sunrise varies by location and date. For accurate Prahar,
  /// we would need actual sunrise times from an astronomy API.
  /// TODO: Integrate with backend muhurat data that has actual sunrise/sunset.
  static String getVedicTimeDetails(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final second = time.second;

    // Use device's local time - this is already in the user's timezone
    // Approximate sunrise at 6 AM (equinox average)
    // NOTE: This is an approximation - actual times vary by ~2 hours seasonally
    const sunriseHour = 6;

    // Calculate seconds from sunrise (for Pala-level precision)
    var secondsFromSunrise = (hour - sunriseHour) * 3600 + minute * 60 + second;
    if (secondsFromSunrise < 0) {
      secondsFromSunrise += 24 * 3600;
    }

    final minutesFromSunrise = secondsFromSunrise / 60.0;

    // Calculate Prahar (1 Prahar = 3 hours = 180 minutes)
    final prahar = (minutesFromSunrise ~/ 180) + 1;

    // Convert to Ghati (1 Ghati = 24 minutes = 1440 seconds)
    final ghati = secondsFromSunrise ~/ 1440;
    // Calculate remaining Pala (1 Pala = 24 seconds)
    final remainingSeconds = secondsFromSunrise - (ghati * 1440);
    final pala = remainingSeconds ~/ 24;

    // Format: "8 Prahar 32 Ghati 15 Pala"
    return '$prahar Prahar $ghati Ghati $pala Pala';
  }

  // Traditional Prahar names (8 watches, starting at sunrise)
  static const _praharNames = [
    'Purvanha',   // early morning (sunrise–9 AM)
    'Madhyanha',  // midday (9 AM–12 PM)
    'Aparanha',   // afternoon (12–3 PM)
    'Sayanha',    // evening (3–6 PM)
    'Pradosha',   // early night (6–9 PM)
    'Nishitha',   // midnight (9 PM–12 AM)
    'Triyama',    // late night (12–3 AM)
    'Usha',       // dawn (3–6 AM)
  ];

  /// Current Prahar name: "Usha Prahar"
  static String getVedicPrahar(DateTime time) {
    const sunriseHour = 6;
    var secondsFromSunrise = (time.hour - sunriseHour) * 3600 + time.minute * 60 + time.second;
    if (secondsFromSunrise < 0) secondsFromSunrise += 86400;

    final minutesFromSunrise = secondsFromSunrise / 60.0;
    final praharIndex = (minutesFromSunrise ~/ 180) % 8;

    return '${_praharNames[praharIndex]} Prahar ${praharIndex + 1}';
  }

  /// Short Vedic time: "Pr6 . Gh42 . Pa48"
  static String getVedicTimeShort(DateTime time) {
    const sunriseHour = 6;
    var secondsFromSunrise = (time.hour - sunriseHour) * 3600 + time.minute * 60 + time.second;
    if (secondsFromSunrise < 0) secondsFromSunrise += 86400;

    final minutesFromSunrise = secondsFromSunrise / 60.0;
    final prahar = (minutesFromSunrise ~/ 180) % 8 + 1;

    final ghati = secondsFromSunrise ~/ 1440;
    final pala = (secondsFromSunrise - (ghati * 1440)) ~/ 24;

    return 'Pr$prahar . Gh$ghati . Pa$pala';
  }

  // Exact month names from FreeAstrologyAPI + Sanskrit display names.
  static const _lunarMonthNumbers = <String, int>{
    // API returns these (Telugu-style)
    'chaitram': 1, 'vaisakham': 2, 'jyeshtam': 3, 'ashadam': 4,
    'sravanam': 5, 'bhadrapadam': 6, 'ashweeyujam': 7, 'karthikam': 8,
    'maargasiram': 9, 'pushyam': 10, 'maagham': 11, 'phalgunam': 12,
    // Sanskrit (used by CalendarDay.panchangMap display names)
    'chaitra': 1, 'vaishakha': 2, 'jyeshtha': 3, 'ashadha': 4,
    'shravana': 5, 'bhadrapada': 6, 'ashvina': 7, 'kartika': 8,
    'margashirsha': 9, 'pausha': 10, 'magha': 11, 'phalguna': 12,
  };

  /// Look up the month number (1–12) from a lunar month name.
  /// Strips "Adhika"/"Nija" prefix before lookup.
  static int? _lunarMonthNumber(String? monthName) {
    if (monthName == null) return null;
    var key = monthName.toLowerCase().trim();
    key = key.replaceFirst(RegExp(r'^(?:adhika?|nija)\s+'), '');
    return _lunarMonthNumbers[key];
  }

  /// Returns true when [monthName] is an Adhika (intercalary) month,
  /// i.e. the name starts with "Adhika ".
  static bool _isAdhikaMasa(String? monthName) {
    if (monthName == null) return false;
    return monthName.toLowerCase().trimLeft().startsWith('adhika ');
  }

  /// Resolve the effective lunar month name from a samvat map.
  ///
  /// Handles two backend patterns:
  ///   1. Name already includes prefix: `lunar_month_full_name: "Adhika Vaishakha"`
  ///   2. Separate flag: `lunar_month_full_name: "Vaishakha"` + `is_adhika_masa: true`
  ///
  /// Returns the name with "Adhika " prepended when appropriate.
  static String? _resolveMonthName(Map<String, dynamic> samvat) {
    final raw = samvat['lunar_month_full_name']?.toString() ??
        samvat['lunar_month_name']?.toString() ??
        samvat['lunarMonthFull']?.toString() ??
        samvat['lunarMonth']?.toString();
    if (raw == null) return null;
    // Already has the prefix — return as-is.
    if (_isAdhikaMasa(raw)) return raw;
    // Check for a separate flag field.
    final flag = samvat['is_adhika_masa'] ?? samvat['adhika_masa'] ?? samvat['adhika'];
    final isFlagged = flag == true || flag == 1 || flag?.toString() == 'true';
    return isFlagged ? 'Adhika $raw' : raw;
  }

  /// Build full Vedic date string — names only.
  /// Example: "Chaitra Krishna Shashthi"
  static String? buildFullVedicDate(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;

    final lunarMonth = _resolveMonthName(samvat);

    final rawTithi = samvat['name'] ??
        samvat['tithi_name'] ??
        samvat['tithiName'] ??
        samvat['tithi'];
    final tithiStr = rawTithi?.toString();
    final parsedTithi = _parseTithi(tithiStr);
    final tithiName = parsedTithi.tithiName ??
        _tithiNameFromNumber(samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber']) ??
        tithiStr;

    final rawPaksha = samvat['paksha'] ?? samvat['tithiPaksha'];
    final pakshaStr = _normalizePaksha(rawPaksha?.toString()) ??
        parsedTithi.paksha;

    if (tithiName != null && tithiName.trim().isNotEmpty && lunarMonth != null) {
      final pakshaLabel = pakshaStr != null ? '$pakshaStr ' : '';
      return '$lunarMonth $pakshaLabel$tithiName'.trim();
    } else if (tithiName != null && tithiName.trim().isNotEmpty) {
      final pakshaLabel = pakshaStr != null ? '$pakshaStr ' : '';
      return '$pakshaLabel$tithiName'.trim();
    }
    return null;
  }

  /// Build numeric Vedic date: "month/paksha/tithi/year" (largest → smallest unit, then year)
  /// Example: "2/2/6/2083" (Vaishakha/Krishna/Shashthi/2083)
  static String? buildVedicNumericDate(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;

    final lunarMonth = _resolveMonthName(samvat);

    // Prefer the pre-computed number the backend always sends; fall back to
    // deriving it from the month name for resilience.
    final rawMonthNum = samvat['lunar_month_number'];
    int? monthNum;
    if (rawMonthNum != null) {
      monthNum = rawMonthNum is num
          ? rawMonthNum.toInt()
          : int.tryParse(rawMonthNum.toString());
    }
    monthNum ??= _lunarMonthNumber(lunarMonth);

    final rawPaksha = samvat['paksha']?.toString() ??
        samvat['tithiPaksha']?.toString();
    final pakshaNum = rawPaksha?.toLowerCase() == 'shukla' ? 1
        : rawPaksha?.toLowerCase() == 'krishna' ? 2
        : null;

    final rawTithiNum = samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber'];
    int? tithiNum;
    if (rawTithiNum != null) {
      tithiNum = rawTithiNum is num ? rawTithiNum.toInt() : int.tryParse(rawTithiNum.toString());
      if (tithiNum != null && tithiNum > 15) tithiNum -= 15;
    }
    // Fallback from tithi name
    if (tithiNum == null) {
      final rawTithi = samvat['name'] ?? samvat['tithi_name'] ?? samvat['tithiName'] ?? samvat['tithi'];
      tithiNum = _tithiNumberFromName(rawTithi?.toString());
    }

    final yearNum = samvat['vikram_chaitradi_number'] ??
        samvat['vikramYear'] ??
        samvat['year'];

    // ── Diagnostic logging ───────────────────────────────────────────────────
    // Remove once month lookup is confirmed working.
    AppLogger.d('VedicNumericDate: month lookup',
        category: LogCategory.ui,
        data: {
          'lunar_month_number': samvat['lunar_month_number'],
          'raw_lunar_month_full_name': samvat['lunar_month_full_name'],
          'raw_lunar_month_name': samvat['lunar_month_name'],
          'raw_lunarMonthFull': samvat['lunarMonthFull'],
          'raw_lunarMonth': samvat['lunarMonth'],
          'is_adhika_masa': samvat['is_adhika_masa'],
          'adhika_masa': samvat['adhika_masa'],
          'adhika': samvat['adhika'],
          'resolved_lunarMonth': lunarMonth,
          'monthNum': monthNum,
          'pakshaNum': pakshaNum,
          'tithiNum': tithiNum,
          'samvat_keys': samvat.keys.toList(),
        });
    // ─────────────────────────────────────────────────────────────────────────

    if (monthNum == null && pakshaNum == null && tithiNum == null) return null;

    // Prefix month number with 'A' for Adhika (intercalary) months,
    // e.g. Adhika Vaishakha → "A2" instead of "2".
    // Check both the resolved name AND the raw flag fields for resilience
    // (handles the case where name fields are absent but the flag is set).
    final adhikaFlag = samvat['is_adhika_masa'] ??
        samvat['adhika_masa'] ??
        samvat['adhika'];
    final isFlaggedAdhika = adhikaFlag == true ||
        adhikaFlag == 1 ||
        adhikaFlag?.toString() == 'true';
    final isAdhika = _isAdhikaMasa(lunarMonth) || isFlaggedAdhika;
    final monthStr = monthNum != null
        ? (isAdhika ? 'A$monthNum' : '$monthNum')
        : '–';

    final parts = <String>[
      monthStr,
      pakshaNum?.toString() ?? '–',
      tithiNum?.toString() ?? '–',
      if (yearNum != null) yearNum.toString(),
    ];

    return parts.join('/');
  }

  /// Reverse-lookup tithi number from its name.
  static int? _tithiNumberFromName(String? name) {
    if (name == null) return null;
    const nameToNum = {
      'pratipada': 1, 'pratipat': 1, 'dwitiya': 2, 'tritiya': 3, 'chaturthi': 4,
      'panchami': 5, 'shashthi': 6, 'saptami': 7, 'ashtami': 8,
      'navami': 9, 'dashami': 10, 'ekadashi': 11, 'dwadashi': 12,
      'trayodashi': 13, 'chaturdashi': 14, 'purnima': 15, 'amavasya': 30,
    };
    return nameToNum[name.toLowerCase().trim()];
  }

  /// Build Samvat year for TODAY's date card.
  /// Validates that the year is reasonable (should be ~56-57 years ahead of Gregorian).
  /// Returns null if year is outside expected range (prevents showing birth year on today's card).
  /// For birth date display, use [buildBirthSamvatYear] instead.
  static String? buildSamvatYear(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;

    final vikramNumber = samvat['vikram_chaitradi_number'];
    final vikramName = samvat['vikram_chaitradi_year_name'];

    if (vikramNumber != null) {
      // Validate Vikram Samvat year
      // Vikram Samvat = Gregorian Year + 56 or 57 (depending on whether before/after Chaitra)
      // For 2026 CE, it should be 2082 or 2083
      final currentGregorianYear = DateTime.now().year;
      final expectedVikramMin = currentGregorianYear + 56;
      final expectedVikramMax = currentGregorianYear + 58;

      final yearNum = vikramNumber is num
          ? vikramNumber.toInt()
          : int.tryParse(vikramNumber.toString());

      if (yearNum != null && (yearNum < expectedVikramMin - 1 || yearNum > expectedVikramMax + 1)) {
        // Year is suspiciously wrong - likely from birth date, not today
        // Return null to indicate data may be stale
        return null;
      }

      var result = 'Vikram Samvat $vikramNumber';
      if (vikramName != null) {
        result = '$result $vikramName';
      }
      return result;
    }
    if (vikramName != null) {
      return 'Vikram Samvat $vikramName';
    }
    return null;
  }

  /// Build Samvat year for TODAY's card — name only, no number.
  /// Example: "Vikram Samvat Siddharthi"
  static String? buildSamvatYearNameOnly(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;

    final vikramNumber = samvat['vikram_chaitradi_number'];
    final vikramName = samvat['vikram_chaitradi_year_name'];

    // Validate year is reasonable for today
    if (vikramNumber != null) {
      final currentGregorianYear = DateTime.now().year;
      final expectedVikramMin = currentGregorianYear + 56;
      final expectedVikramMax = currentGregorianYear + 58;
      final yearNum = vikramNumber is num
          ? vikramNumber.toInt()
          : int.tryParse(vikramNumber.toString());
      if (yearNum != null && (yearNum < expectedVikramMin - 1 || yearNum > expectedVikramMax + 1)) {
        return null; // stale birth data
      }
    }

    if (vikramName != null && vikramName.toString().isNotEmpty) {
      return 'Vikram Samvat $vikramName';
    }
    return null;
  }

  /// Build Samvat year for BIRTH DATE display (no current-year validation).
  /// Use this on the astrology details page with `profile.birthSamvatInfo`.
  /// For today's date card, use [buildSamvatYear] instead (has year validation).
  static String? buildBirthSamvatYear(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;

    final vikramNumber = samvat['vikram_chaitradi_number'];
    final vikramName = samvat['vikram_chaitradi_year_name'];
    if (vikramNumber != null) {
      var result = 'Vikram Samvat $vikramNumber';
      if (vikramName != null && vikramName.toString().isNotEmpty) {
        result = '$result $vikramName';
      }
      return result;
    }
    if (vikramName != null && vikramName.toString().isNotEmpty) {
      return 'Vikram Samvat $vikramName';
    }
    return null;
  }

  /// Filter samvat data to only match the BIRTH DATE (within 1 day).
  /// Prevents today's samvat from leaking into birth-focused views.
  /// Use with `profile.birthSamvatInfo` on the astrology details page.
  static Map<String, dynamic>? filterBirthSamvat(
    Map<String, dynamic>? samvat,
    DateTime? birthDate,
  ) {
    if (samvat == null) return null;
    if (birthDate == null) return samvat;

    final birthYear = birthDate.year;
    final samvatYearRaw = samvat['vikram_chaitradi_number'];
    final samvatYear = _parseInt(samvatYearRaw);
    if (samvatYear != null) {
      final expectedBirthMin = birthYear + 55;
      final expectedBirthMax = birthYear + 59;
      final nowYear = DateTime.now().year;
      final expectedCurrentMin = nowYear + 55;
      final expectedCurrentMax = nowYear + 59;
      final matchesBirth =
          samvatYear >= expectedBirthMin && samvatYear <= expectedBirthMax;
      final matchesCurrent =
          samvatYear >= expectedCurrentMin && samvatYear <= expectedCurrentMax;
      AppLogger.i('VedicTimeUtils: samvat year check',
          category: LogCategory.general,
          data: {
            'birthYear': birthYear,
            'samvatYear': samvatYear,
            'matchesBirth': matchesBirth,
            'matchesCurrent': matchesCurrent,
          });
      if (matchesCurrent && !matchesBirth) {
        return null;
      }
    }

    final samvatDate = _extractSamvatDate(samvat);
    AppLogger.i('VedicTimeUtils: birth samvat check',
        category: LogCategory.general,
        data: {
          'birthDate': birthDate.toIso8601String(),
          'samvatDate': samvatDate?.toIso8601String(),
        });
    if (samvatDate == null) return samvat;

    final birthDay = DateTime(birthDate.year, birthDate.month, birthDate.day);
    final samvatDay =
        DateTime(samvatDate.year, samvatDate.month, samvatDate.day);
    final dayDiff = samvatDay.difference(birthDay).inDays.abs();
    AppLogger.i('VedicTimeUtils: birth samvat diff',
        category: LogCategory.general,
        data: {'dayDiff': dayDiff});
    if (dayDiff <= 1) return samvat;

    return null;
  }

  /// Validate if a Vikram Samvat year is reasonable for today
  /// Returns true if the year is within expected range
  static bool isValidVikramYearForToday(dynamic vikramNumber) {
    if (vikramNumber == null) return false;

    final currentGregorianYear = DateTime.now().year;
    final expectedVikramMin = currentGregorianYear + 55; // Allow slight buffer
    final expectedVikramMax = currentGregorianYear + 59;

    final yearNum = vikramNumber is num
        ? vikramNumber.toInt()
        : int.tryParse(vikramNumber.toString());

    return yearNum != null && yearNum >= expectedVikramMin && yearNum <= expectedVikramMax;
  }

  static DateTime? _extractSamvatDate(Map<String, dynamic> samvat) {
    final explicitYear = samvat['gregorian_year'] ??
        samvat['gregorianYear'];
    final explicitMonth = samvat['gregorian_month'] ??
        samvat['gregorianMonth'];
    final explicitDay = samvat['gregorian_date'] ??
        samvat['gregorianDate'];

    final year = _parseInt(explicitYear);
    final month = _parseInt(explicitMonth);
    final day = _parseInt(explicitDay);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }

    final raw = samvat['gregorian_date'] ?? samvat['gregorianDate'];
    if (raw == null) return null;

    if (raw is DateTime) return raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        try {
          return DateTime.parse(trimmed);
        } catch (_) {
          // Fall through to regex parsing below
        }
        final match =
            RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(trimmed);
        if (match != null) {
          final parsedYear = int.tryParse(match.group(1) ?? '');
          final parsedMonth = int.tryParse(match.group(2) ?? '');
          final parsedDay = int.tryParse(match.group(3) ?? '');
          if (parsedYear != null && parsedMonth != null && parsedDay != null) {
            return DateTime(parsedYear, parsedMonth, parsedDay);
          }
        }
      }
    }

    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _normalizePaksha(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('shukla') || lower.contains('sukla')) return 'Shukla';
    if (lower.contains('krishna') || lower.contains('krsna') || lower.contains('krishan')) {
      return 'Krishna';
    }
    return null;
  }

  static _ParsedTithi _parseTithi(String? tithiStr) {
    if (tithiStr == null || tithiStr.trim().isEmpty) {
      return const _ParsedTithi();
    }
    final lower = tithiStr.toLowerCase();
    String? paksha;
    if (lower.contains('shukla') || lower.contains('sukla')) {
      paksha = 'Shukla';
    } else if (lower.contains('krishna') || lower.contains('krsna') || lower.contains('krishan')) {
      paksha = 'Krishna';
    }

    var cleaned = tithiStr.replaceAll(
        RegExp(r'\b(shukla|sukla|krishna|krsna|krishan)\b', caseSensitive: false),
        '');
    cleaned = cleaned.replaceAll(RegExp(r'\bpaksha\b', caseSensitive: false), '');
    cleaned = cleaned.trim();
    final name = cleaned.isNotEmpty ? cleaned : null;

    return _ParsedTithi(tithiName: name, paksha: paksha);
  }

  static String? _tithiNameFromNumber(dynamic rawNumber) {
    if (rawNumber == null) return null;
    final number = rawNumber is num ? rawNumber.toInt() : int.tryParse(rawNumber.toString());
    if (number == null) return null;
    final normalized = number > 15 && number <= 30 ? number - 15 : number;
    const names = {
      1: 'Pratipada',
      2: 'Dwitiya',
      3: 'Tritiya',
      4: 'Chaturthi',
      5: 'Panchami',
      6: 'Shashthi',
      7: 'Saptami',
      8: 'Ashtami',
      9: 'Navami',
      10: 'Dashami',
      11: 'Ekadashi',
      12: 'Dwadashi',
      13: 'Trayodashi',
      14: 'Chaturdashi',
      15: 'Purnima',
    };
    return names[normalized];
  }
}

class _ParsedTithi {
  final String? tithiName;
  final String? paksha;

  const _ParsedTithi({this.tithiName, this.paksha});
}
