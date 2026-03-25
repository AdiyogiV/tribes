import 'package:aurogram/utils/logging/app_logger.dart';

/// Utility class for Vedic time calculations
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

    // Use device's local time - this is already in the user's timezone
    // Approximate sunrise at 6 AM (equinox average)
    // NOTE: This is an approximation - actual times vary by ~2 hours seasonally
    const sunriseHour = 6;

    // Calculate minutes from sunrise (Vedic timekeeping measures from sunrise to sunrise)
    var minutesFromSunrise = (hour - sunriseHour) * 60 + minute;
    if (minutesFromSunrise < 0) {
      minutesFromSunrise += 24 * 60;
    }

    // Calculate Prahar (1 Prahar = 3 hours = 180 minutes)
    // Prahar 1-8: each represents a 3-hour period starting from sunrise
    final prahar = (minutesFromSunrise ~/ 180) + 1;
    
    final praharNames = [
      'Pratham', 'Dwitiya', 'Tritiya', 'Chaturth',
      'Pancham', 'Shashth', 'Saptam', 'Ashtam'
    ];
    final praharName = praharNames[(prahar - 1) % 8];
    
    final praharOrdinal = _getOrdinal(prahar);

    // Convert to Ghatis (1 Ghati = 24 minutes)
    final totalGhatis = minutesFromSunrise / 24.0;
    final ghati = totalGhatis.floor();
    // Calculate remaining Pala (1 Ghati = 60 Pala, 1 Pala = 24 seconds = 0.4 minutes)
    final remainingMinutes = minutesFromSunrise - (ghati * 24);
    final pala = (remainingMinutes / 0.4).round();

    // Format: "8th Ashtam Prahar • 32 Ghati 15 Pala"
    return '$praharOrdinal $praharName Prahar • $ghati Ghati $pala Pala';
  }

  /// Get ordinal suffix for prahar number (1st, 2nd, 3rd, 4th, etc.)
  static String _getOrdinal(int number) {
    final num = number % 8;
    if (num == 0) return '8th';
    if (num == 1) return '1st';
    if (num == 2) return '2nd';
    if (num == 3) return '3rd';
    return '${num}th';
  }

  /// Build full Vedic date string from panchang data
  static String? buildFullVedicDate(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;

    final lunarMonth = samvat['lunar_month_full_name']?.toString() ??
        samvat['lunar_month_name']?.toString() ??
        samvat['lunarMonthFull']?.toString() ??
        samvat['lunarMonth']?.toString();

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

  /// Build Samvat year string from panchang data
  /// Validates that the year is reasonable (should be ~56-57 years ahead of Gregorian)
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
        result = '$result ($vikramName)';
      }
      return result;
    }
    if (vikramName != null) {
      return 'Vikram Samvat ($vikramName)';
    }
    return null;
  }

  /// Build Samvat year string for birth data (no current-year validation).
  static String? buildBirthSamvatYear(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;

    final vikramNumber = samvat['vikram_chaitradi_number'];
    final vikramName = samvat['vikram_chaitradi_year_name'];
    if (vikramNumber != null) {
      var result = 'Vikram Samvat $vikramNumber';
      if (vikramName != null && vikramName.toString().isNotEmpty) {
        result = '$result ($vikramName)';
      }
      return result;
    }
    if (vikramName != null && vikramName.toString().isNotEmpty) {
      return 'Vikram Samvat ($vikramName)';
    }
    return null;
  }

  /// Only use samvat data if it matches the birth date (within 1 day).
  /// Prevents showing today's samvat in birth-focused views.
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
        } catch (_) {}
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
